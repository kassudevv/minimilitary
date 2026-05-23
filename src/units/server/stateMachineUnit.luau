local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local accountStore = require("../../accounts/server/accountStore")
local accounts = require("../../accounts/server")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
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
function SMUnit.new(def: types.Unit, owner: Player?, guid: string, position: CFrame): SMUnit
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
						local state: "idle" | "moving" | "targeting" = "idle"
						self:replicatedTransition(state, {})
					end
				end,
				onExit = function(next) end,
			},
			targeting = {
				onEnter = function(prev)
					local target = self.stateMachine.data.target
					self.stateMachine.data.start = 0
					self.stateMachine.data.isReadyToFire = false
					-- self.lastProjectileTs = os.clock()
				end,
				tick = function(dt)
					if os.clock() < self.stateMachine.data.firstShotTs then
						return
					end

					local target = self.stateMachine.data.target
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

						table.insert(target.damageQueue, self.def.damage)
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
	return { unitId = self.def.id or "gunner", position = self.pawn.CFrame, guid = self.guid }
end

function SMUnit.move(self: SMUnit, target: Vector3)
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
		waypoints = wps,
		totalLength = unitRaycast.getPathLength(wps),
		startTime = os.clock(),
	})
end

function SMUnit.target(self: SMUnit, target: SMUnit)
	local firstShotDelay = math.random() * 0.35
	self:replicatedTransition("targeting", {
		startTime = os.clock(),
		target = target.guid,
		firstShotDelay = firstShotDelay,
		firstShotTs = os.clock() + firstShotDelay,
	})
	self.stateMachine.data.target = target
end

function SMUnit.replicatedTransition(self: SMUnit, newState: "idle" | "moving" | "targeting", data: { [string]: any })
	self.stateMachine:transition(newState, data)
	network.Units.ReplicateSM:FireAllClients(self.guid, newState, data)
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

		local idleUnits = TableUtil.Filter(self.units, function(u: SMUnit)
			return u.stateMachine.state == "idle"
		end)

		self.targetGrid:rebuild(self.units)

		for _, u in idleUnits do
			local attackRange = u.def.range
			local targetRange = attackRange * 1.4

			local nearest, nearestDist = nil, math.huge
			self.targetGrid:forEachEnemyInRange(u, targetRange, function(target, distSq)
				local dist = math.sqrt(distSq)

				if dist < nearestDist then
					nearest = target
					nearestDist = dist
					return
				end
			end)

			if nearest and nearestDist <= attackRange then
				task.spawn(function()
					u:target(nearest)
				end)
				-- u:startTargeting(nearest)
				continue
			end

			if nearest and nearestDist <= targetRange then
				-- if u.owner ~= "pve" and nearest.owner == "pve" then
				-- 	local closest = closestPointOnCircle(
				-- 		nearest.pawn.Position,
				-- 		attackRange * math.random(50, 90) * 0.01,
				-- 		unit.pawn.Position
				-- 	)
				-- 	unit:moveTo(closest)
				-- end
			end
		end
	end)

	network.Units.RequestPath.OnServerEvent:Connect(function(plr: Player, target: Vector3)
		local flyingUnits = TableUtil.Filter(self.units, function(u: SMUnit)
			return u.owner == plr.Name and u.def.movementMode == "flying"
		end)
		local groundUnits = TableUtil.Filter(self.units, function(u: SMUnit)
			return u.owner == plr.Name and u.def.movementMode ~= "flying"
		end)

		local flyingFormation = unitRaycast.buildFormation(target, flyingUnits, 0)
		local groundFormation = unitRaycast.buildFormation(target, groundUnits, 0)

		for i, u in groundUnits do
			local state: "idle" | "moving" | "targeting" = "idle"
			u.stateMachine:transition(state, {})

			task.spawn(function()
				u:move(groundFormation[i])
			end)
		end

		for i, u in flyingUnits do
			local state: "idle" | "moving" | "targeting" = "idle"
			u.stateMachine:transition(state, {})

			task.spawn(function()
				u:move(flyingFormation[i])
			end)
		end
	end)

	network.Units.ApplyPendingHit.OnServerEvent:Connect(function(plr: Player, target: string)
		for _, u in self.units do
			if u.guid == target then
				local dmg = table.remove(u.damageQueue, 1)
				assert(dmg ~= nil, "couldn't apply pend hit")
				u.health -= dmg
				return
			end
		end
	end)

	network.Units.RequestUnits.OnServerEvent:Connect(function(plr: Player)
		local rand = { "gunner" }
		-- local rand = { "apache", "gunner", "gunner", "gunner", "abrams", "juggernaut", "tiger1", "littlebird", "abrams" }
		for i = 1, 15 do
			local id = rand[((i - 1) % #rand) + 1]
			assert(constants.getUnit(id) ~= nil, "invalid unitId")
			accounts.addUnit(plr, { assignedSquad = 1, unitId = id })
		end

		local account = accountStore.getAccount(plr.Name)

		if account then
			for guid, uData in account.units do
				local unitDef = constants.getUnit(uData.unitId) :: types.Unit
				local char = plr.Character or plr.CharacterAdded:Wait()
				table.insert(self.units, SMUnit.new(unitDef, plr, guid, char:GetPivot()))
			end
		end

		local unitDef = constants.getUnit("gunner") :: types.Unit
		table.insert(
			self.units,
			SMUnit.new(
				unitDef,
				nil,
				HttpService:GenerateGUID(false),
				CFrame.new(Vector3.new(-38 + (math.random() * 120) - 60, 4.5, -183.5 + ((math.random() * 60) - 30)))
			)
		)

		local sp = {}
		for _, u in self.units do
			table.insert(sp, u:snapshot())
		end
		network.Units.LoadUnits:FireAllClients(sp)
	end)
end

type SMUnits = typeof(SMUnits) & {
	units: { SMUnit },
	targetGrid: spatialGrid.SpatialGrid,
}

return SMUnits :: SMUnits
