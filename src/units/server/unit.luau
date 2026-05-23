local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Promise = require("@game/ReplicatedStorage/Packages/Promise")
local encoder = require("@game/ReplicatedStorage/src/units/shared/encoder")
local index = require("@game/ReplicatedStorage/src/units/shared/index")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local serverTypes = require("./serverTypes")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

--* ────────────────────────────────────────────────────────────────────────────
--* UNIT
--* ────────────────────────────────────────────────────────────────────────────
local Unit = {}
Unit.__index = Unit

export type Unit = setmetatable<serverTypes.UnitData, typeof(Unit)>

function Unit.new(
	owner: Player?,
	unitDef: types.Unit,
	position: CFrame,
	guid: string,
	unitCallbacks: { [string]: (any) -> () }
): Unit
	local self = setmetatable({} :: serverTypes.UnitData, Unit) :: Unit

	self.unit = unitDef
	self.owner = owner and owner.UserId or -1
	self.guid = guid
	self.id = index.registerNew(guid)

	self.health = unitDef.maxHealth

	self.pawn = Instance.new("Part") :: Part
	self.pawn.Anchored = true
	self.pawn.CFrame = position
	self.pawn.CanCollide = false
	self.pawn.Size = Vector3.new(1.5, 3, 1.5)
	self.pawn.Color = Color3.fromHex("#ffaa00")
	self.pawn.Parent = Workspace.Camera

	self.callbacks = unitCallbacks
	self.lastAttackTs = 0

	self.pathfinder = PathfindingService:CreatePath({
		AgentRadius = 1,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentMaxSlope = 90,
		WaypointSpacing = 32,
	})

	self.pendingHits = {}

	return self
end

function Unit.getSnapshot(self: Unit): types.UnitSnapshot
	return {
		guid = self.guid,
		owner = self.owner,
		unitId = self.unit.id or "",
		position = self.pawn.CFrame,
		id = self.id,
	}
end

function Unit.isPve(self: Unit)
	return self.owner == -1
end

function Unit.applyPendingHit(self: Unit)
	local nextHit = table.remove(self.pendingHits)
	if nextHit then
		self:damage(nextHit)
	end
end

function Unit.addPendingDamage(self: Unit, amount: number)
	table.insert(self.pendingHits, amount)
end

function Unit.damage(self: Unit, amount: number)
	self.health -= amount

	local damageCb = self.callbacks["onDamage"]
	if damageCb then
		damageCb(self.guid, amount)
	end

	local deathCb = self.callbacks["onDeath"]
	if self.health <= 0 and deathCb then
		deathCb(self.guid)
	end
end

function Unit.startTargeting(self: Unit, target: Unit)
	return Promise.new(function(rs)
		if self.targetingPromise and self.targetingPromise:getStatus() ~= "Cancelled" then
			self.targetingPromise:cancel()
		end

		self.targetingPromise = Promise.new(function(resolve, reject, onCancel)
			local cancelled = false
			local conn: RBXScriptConnection

			onCancel(function()
				cancelled = true
				network.Units.StopTargeting:FireAllClients(index.writeBuf(self.id))
				conn:Disconnect()
			end)

			task.wait(math.random() * 0.1)

			if cancelled then
				return
			end

			network.Units.StartTargeting:FireAllClients(index.writeBuf(self.id), index.writeBuf(target.id))
			conn = RunService.Heartbeat:Connect(function(dt)
				local elapsed = os.clock() - self.lastAttackTs
				if elapsed < 1 / self.unit.firerate then
					return
				end
				if not target.pawn.Parent or target.health <= 0 then
					network.Units.StopTargeting:FireAllClients(index.writeBuf(self.id))
					conn:Disconnect()
					return resolve()
				end
				if (self.pawn.Position - target.pawn.Position).Magnitude > self.unit.range then
					network.Units.StopTargeting:FireAllClients(index.writeBuf(self.id))
					conn:Disconnect()
					return resolve()
				end

				self.lastAttackTs = os.clock()
				target:addPendingDamage(self.unit.damage)
			end)
		end)
		return rs(self.targetingPromise)
	end)
end

function Unit.attack(self: Unit, target: Vector3): Promise.Class
	return Promise.new(function(rs)
		if self.movePromise and self.movePromise:getStatus() ~= "Cancelled" then
			self.movePromise:cancel()
		end
		if self.attackPromise and self.attackPromise:getStatus() ~= "Cancelled" then
			self.attackPromise:cancel()
		end

		self.attackPromise = Promise.new(function(resolve, reject, onCancel)
			local conn: RBXScriptConnection
			local startTime = os.clock()
			conn = RunService.Heartbeat:Connect(function(dt)
				local elapsed = os.clock() - startTime
				if elapsed < (1 / self.unit.firerate) then
					return
				end
				startTime = elapsed
			end)

			onCancel(function()
				conn:Disconnect()
			end)
		end)
		return rs(self.attackPromise)
	end)
end

function Unit.moveTo(self: Unit, target: Vector3): Promise.Class
	return Promise.new(function(rs, rj, oc)
		if self.targetingPromise and self.targetingPromise:getStatus() ~= "Cancelled" then
			self.targetingPromise:cancel()
		end
		if self.movePromise and self.movePromise:getStatus() ~= "Cancelled" then
			self.movePromise:cancel()
		end

		local wps: { Vector3 } = {}
		local isFlying = self.unit.movementMode == "flying"
		-- ground troop
		if not isFlying then
			self.pathfinder:ComputeAsync(self.pawn.Position, target)
			if self.pathfinder.Status ~= Enum.PathStatus.Success then
				return rj()
			end
			local waypoints = self.pathfinder:GetWaypoints()
			for _, wp in waypoints do
				table.insert(wps, Vector3.new(wp.Position.X, wp.Position.Y, wp.Position.Z))
			end
		else
			table.insert(wps, Vector3.new(self.pawn.Position.X, self.pawn.Position.Y, self.pawn.Position.Z))
			table.insert(wps, Vector3.new(target.X, target.Y, target.Z))
		end

		for i, wp in wps do
			local params = unitRaycast.getRaycastParams()
			local rcResult = Workspace:Raycast(wp + Vector3.new(0, 900, 0), -Vector3.yAxis * 1000, params)
			if rcResult then
				wps[i] = Vector3.new(wp.X, rcResult.Position.Y + (isFlying and 16 or 0), wp.Z)
			end
		end

		local totalLength = unitRaycast.getPathLength(wps)

		self.movePromise = Promise.new(function(resolve, reject, onCancel)
			local conn: RBXScriptConnection
			local startTime = os.clock()
			conn = RunService.Heartbeat:Connect(function(dt)
				local elapsed = os.clock() - startTime
				local distance = math.max(elapsed * self.unit.speed, 0)

				unitRaycast.setUnitPositionWithOrientationFromSampledPath(self.pawn, wps, distance, self.unit.offset)

				if distance >= totalLength then
					conn:Disconnect()
					resolve()
				end
			end)

			onCancel(function()
				conn:Disconnect()
			end)
		end)
		rs(self.movePromise)

		network.Units.MoveUnit:FireAllClients(index.writeBuf(self.id), encoder.encodeWaypoints(wps))
	end)
end

function Unit.cleanup(self: Unit)
	if self.movePromise then
		self.movePromise:cancel()
	end
	if self.pawn then
		self.pawn:Destroy()
	end
end

return Unit
