local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local accountStore = require("../../accounts/server/accountStore")
local accounts = require("../../accounts/server")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
local encoder = require("@game/ReplicatedStorage/src/units/shared/encoder")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local spatialGrid = require("./spatialGrid")
local stateMachine = require("@game/ReplicatedStorage/src/units/shared/stateMachine")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

local SMUnit = {}
SMUnit.__index = SMUnit

type SMUnitData = {
	def: types.Unit,
	guid: string,
	owner: string,
	pawn: BasePart,
	stateMachine: stateMachine.StateMachine,
	pathfinder: Path,
	lastProjectileTs: number,

	health: number,
	damageQueue: { number },
}

export type SMUnit = setmetatable<SMUnitData, typeof(SMUnit)>
function SMUnit.new(def: types.Unit, owner: Player?, guid: string, position: CFrame, destroyCb: (SMUnit) -> ()): SMUnit
	local self = setmetatable({} :: SMUnitData, SMUnit)

	self.def = def
	self.guid = guid
	self.owner = owner and owner.Name or "pve"

	self.health = def.maxHealth
	self.damageQueue = {}

	self.stateMachine = stateMachine.new({
		state = "idle",
		data = {},
		handlers = {
			dead = {
				onEnter = function(prev)
					destroyCb(self)
				end,
				tick = function(dt) end,
				onExit = function(next) end,
			},
			idle = {
				onEnter = function(prev) end,
				tick = function(dt) end,
				onExit = function(next) end,
			},
			moving = {
				onEnter = function(prev) end,
				tick = function(dt)
					local startTime = self.stateMachine.data.startTime
					local elapsed = os.clock() - startTime
					local distance = math.max(elapsed * self.def.speed, 0)

					unitRaycast.setUnitPositionWithOrientationFromSampledPath(
						self.pawn,
						self.stateMachine.data.waypoints,
						distance,
						self.def.offset
					)

					if distance > self.stateMachine.data.totalLength then
						local state: stateMachine.State = "idle"
						self:replicatedTransition(state, {})
					end
				end,
				onExit = function(next) end,
			},
			targeting = {
				onEnter = function(prev)
					self.stateMachine.data.start = 0
					self.stateMachine.data.isReadyToFire = false
				end,
				tick = function(dt)
					local target = self.stateMachine.data.target
					local distance = (self.pawn.Position - target.pawn.Position).Magnitude
					if target.stateMachine.state == "dead" or (distance > self.def.range) then
						self:replicatedTransition("idle" :: stateMachine.State, {})
						return
					end

					if os.clock() < self.stateMachine.data.firstShotTs then
						return
					end

					if
						not self.stateMachine.data.isReadyToFire
						and (os.clock() - self.lastProjectileTs) > 1 / self.def.firerate
					then
						self.stateMachine.data.isReadyToFire = true
						self.stateMachine.data.start = os.clock()
					end

					if self.stateMachine.data.isReadyToFire then
						if (os.clock() - self.stateMachine.data.start) < (self.def.shotDelay or 0) then
							return
						end

						self.lastProjectileTs = self.stateMachine.data.start
						self.stateMachine.data.isReadyToFire = false

						table.insert(target.damageQueue, self.def.damage * (self.owner == "pve" and 0.001 or 10))
					end
				end,
				onExit = function(next) end,
			},
		},
	})
	self.stateMachine:transition("idle", {})

	self.lastProjectileTs = 0

	self.pathfinder = PathfindingService:CreatePath({
		AgentRadius = 1,
		AgentHeight = 1,
		AgentCanJump = true,
		AgentMaxSlope = 32,
		WaypointSpacing = 16,
	})

	self.pawn = Instance.new("Part") :: Part
	self.pawn.Anchored = true
	self.pawn.CFrame = position
	self.pawn.CanCollide = false
	self.pawn.Size = Vector3.new(1.5, 3, 1.5)
	self.pawn.Color = Color3.fromHex("#ffaa00")
	self.pawn.Parent = Workspace.Camera

	return self
end

function SMUnit.snapshot(self: SMUnit): types.UnitSnapshot
	return { unitId = self.def.id or "gunner", position = self.pawn.CFrame, guid = self.guid, owner = self.owner }
end

function SMUnit.move(self: SMUnit, target: Vector3)
	if self.stateMachine.state == "dead" then
		return
	end

	self:replicatedTransition("idle")

	self.pathfinder:ComputeAsync(self.pawn.Position, target)
	if self.pathfinder.Status ~= Enum.PathStatus.Success then
		return
	end

	local wps: { Vector3 } = {}
	local waypoints = self.pathfinder:GetWaypoints()
	for _, wp in waypoints do
		table.insert(wps, Vector3.new(wp.Position.X, wp.Position.Y, wp.Position.Z))
	end

	for i, wp in wps do
		local params = unitRaycast.getRaycastParams()
		local rcResult = Workspace:Raycast(wp + Vector3.new(0, 50, 0), -Vector3.yAxis * 100, params)
		if rcResult then
			wps[i] = Vector3.new(wp.X, rcResult.Position.Y, wp.Z)
		end
	end

	self:replicatedTransition("moving", {
		waypoints = encoder.encodeWaypoints(wps),
		totalLength = unitRaycast.getPathLength(wps),
		startTime = os.clock(),
	})
	self.stateMachine.data.waypoints = wps
end

function SMUnit.target(self: SMUnit, target: SMUnit)
	if self.stateMachine.state == "dead" then
		return
	end

	local firstShotDelay = math.random() * 0.35
	self:replicatedTransition("targeting", {
		startTime = os.clock(),
		target = target.guid,
		firstShotDelay = firstShotDelay,
		firstShotTs = os.clock() + firstShotDelay,
	})
	self.stateMachine.data.target = target
end

function SMUnit.replicatedTransition(self: SMUnit, newState: stateMachine.State, data: { [string]: any })
	self.stateMachine:transition(newState, data)
	network.Units.ReplicateSM:FireAllClients(self.guid, newState, data)
end

function SMUnit.damage(self: SMUnit, amt: number)
	if self.stateMachine.state == "dead" then
		return
	end

	self.health -= amt
	if self.health <= 0 then
		self.replicatedTransition(self, "dead", {})
	end
end

function SMUnit.cleanup(self: SMUnit)
	self.pawn:Destroy()
end

local SMUnits = {}

function SMUnits.init(self: SMUnits)
	self.units = {}
	self.targetGrid = spatialGrid.new(64)
	unitRaycast:initRaycastParams()
	RunService.Heartbeat:Connect(function(dt)
		for _, u in self.units do
			u.stateMachine:tick(dt)
		end
	end)
	local lastTick = 0
	local tickRate = 1 / 10
	RunService.Heartbeat:Connect(function(dt)
		if (os.clock() - lastTick) < tickRate then
			return
		end
		lastTick = os.clock()

		self.targetGrid:rebuild(self.units)

		for _, u in self.units do
			if u.stateMachine.state ~= "idle" then
				continue
			end

			local attackRange = u.def.range
			local pveTargetRange = attackRange * 1.1
			local targetRange = attackRange * 1.3

			local nearest, nearestDist = nil, math.huge
			self.targetGrid:forEachEnemyInRange(u, targetRange, function(target, distSq)
				local dist = math.sqrt(distSq)

				if dist < nearestDist and target.stateMachine.state ~= "dead" then
					nearest = target
					nearestDist = dist
				end
			end)

			if nearest and nearestDist <= attackRange then
				u:target(nearest)
				continue
			end

			if nearest and nearestDist <= targetRange then
				if (u.owner ~= "pve" and nearest.owner == "pve") or (nearestDist <= pveTargetRange) then
					if u.def.movementMode == "flying" then
						local closest = unitRaycast.closestPointOnCircle(
							nearest.pawn.Position,
							attackRange * math.random(50, 90) * 0.01,
							u.pawn.Position
						)
						u:move(closest)
					else
						local closest = unitRaycast.closestPointOnCircleWithLos(
							nearest.pawn.Position,
							attackRange * math.random(50, 90) * 0.01,
							u.pawn.Position
						)

						if closest then
							u:move(closest)
						end
					end
				end
			end
		end
	end)

	--network
	local destroyCb = function(u: SMUnit)
		u:cleanup()
		self.units[u.guid] = nil
	end

	network.Units.RequestPath.OnServerEvent:Connect(function(plr: Player, target: Vector3)
		local flyingUnits, groundUnits = {}, {}
		for k, u in self.units do
			if u.owner ~= plr.Name then
				continue
			end
			local tbl = u.def.movementMode == "flying" and flyingUnits or groundUnits
			table.insert(tbl, u)
		end

		local flyingFormation = unitRaycast.buildFormation(target, flyingUnits, 0)
		local groundFormation = unitRaycast.buildFormation(target, groundUnits, 0)

		for i, u in groundUnits do
			task.spawn(function()
				u:move(groundFormation[i])
			end)
		end

		for i, u in flyingUnits do
			task.spawn(function()
				u:move(flyingFormation[i])
			end)
		end
	end)

	network.Units.ApplyPendingHit.OnServerEvent:Connect(function(plr: Player, target: string)
		for _, u in self.units do
			if u.guid == target then
				local dmg = table.remove(u.damageQueue, 1)
				if not dmg then
					return
				end
				u:damage(dmg)
				return
			end
		end
	end)

	network.Units.RequestUnits.OnServerEvent:Connect(function(plr: Player)
		local rand =
			{ "gunner", "gunner", "gunner", "gunner", "abrams", "juggernaut", "tiger1", "littlebird", "abrams" }
		for i = 1, 1 do
			local id = rand[((i - 1) % #rand) + 1]
			assert(constants.getUnit(id) ~= nil, "invalid unitId")
			accounts.addUnit(plr, { assignedSquad = 1, unitId = id })
		end

		local account = accountStore.getAccount(plr.Name)

		local loadQueue = {}
		if account then
			for guid, uData in account.units do
				local unitDef = constants.getUnit(uData.unitId) :: types.Unit
				local char = plr.Character or plr.CharacterAdded:Wait()
				self.units[guid] = SMUnit.new(unitDef, plr, guid, char:GetPivot(), destroyCb)
				table.insert(loadQueue, self.units[guid]:snapshot())
			end
		end
		self:LoadAllUnitsForPlayer(plr)
		network.FireAllExcept(network.Units.LoadUnits, plr, loadQueue)
	end)

	local n = {}
	for _ = 1, 10 do
		local unitDef = constants.getUnit(math.random(1, 2) == 1 and "gunner" or "gunner") :: types.Unit
		local guid = HttpService:GenerateGUID(false)
		self.units[guid] = SMUnit.new(
			unitDef,
			nil,
			guid,
			CFrame.new(Vector3.new(-38 + (math.random() * 120) - 60, 4.5, -183.5 + ((math.random() * 60) - 30))),
			destroyCb
		)
		table.insert(n, self.units[guid]:snapshot())
	end
	network.Units.LoadUnits:FireAllClients(n)
end

function SMUnits.LoadAllUnitsForPlayer(self: SMUnits, plr: Player)
	local loadQueue = {}
	for _, u in self.units do
		table.insert(loadQueue, u:snapshot())
	end
	network.Units.LoadUnits:FireClient(plr, loadQueue)
end

type SMUnits = typeof(SMUnits) & {
	units: { [string]: SMUnit },
	targetGrid: spatialGrid.SpatialGrid,
}

return SMUnits :: SMUnits
