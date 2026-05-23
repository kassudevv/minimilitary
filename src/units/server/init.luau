local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Promise = require("@game/ReplicatedStorage/Packages/Promise")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local accountStore = require("../accounts/server/accountStore")
local accounts = require("../accounts/server")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
local encoder = require("@game/ReplicatedStorage/src/units/shared/encoder")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local serverTypes = require("@self/serverTypes")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

--* ────────────────────────────────────────────────────────────────────────────
--* UNIT
--* ────────────────────────────────────────────────────────────────────────────
local Unit = {}
Unit.__index = Unit

export type Unit = setmetatable<serverTypes.UnitData, typeof(Unit)>

function Unit.new(owner: Player, unitDef: types.Unit, position: CFrame, guid: string): Unit
	local self = setmetatable({} :: serverTypes.UnitData, Unit) :: Unit

	self.unit = unitDef
	self.owner = owner
	self.guid = guid

	self.pawn = Instance.new("Part") :: Part
	self.pawn.Anchored = true
	self.pawn.CFrame = position
	self.pawn.CanCollide = false
	self.pawn.Size = Vector3.new(1.5, 3, 1.5)
	self.pawn.Color = Color3.fromHex("#ffaa00")
	self.pawn.Parent = Workspace.Camera

	self.pathfinder = PathfindingService:CreatePath({
		AgentRadius = 1,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentMaxSlope = 90,
		WaypointSpacing = 10,
	})

	return self
end

function Unit.getSnapshot(self: Unit): types.UnitSnapshot
	return {
		guid = self.guid,
		owner = self.owner,
		unitId = self.unit.id or "",
		position = self.pawn.CFrame,
	}
end

function Unit.moveTo(self: Unit, target: Vector3): Promise.Class
	return Promise.new(function(rs, rj)
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
				local distance = math.max(elapsed * self.unit.speed * 1, 0)

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

		network.Units.MoveUnit:FireAllClients(self.guid, encoder.encodeWaypoints(wps))
	end)
end

function Unit.attack(self: Unit, target: Vector3): Promise.Class
	return Promise.new(function(rs) end)
end

--* ────────────────────────────────────────────────────────────────────────────
--* UNITS
--* ────────────────────────────────────────────────────────────────────────────
local PlayerUnits = {}
PlayerUnits.__index = PlayerUnits

type PlayerUnitsData = {
	owner: Player,
	units: { Unit },
}

export type PlayerUnits = setmetatable<PlayerUnitsData, typeof(PlayerUnits)>

function PlayerUnits.new(plr: Player): PlayerUnits
	local self = setmetatable({} :: PlayerUnitsData, PlayerUnits)

	self.owner = plr
	self.units = {}

	task.wait(1)

	-- local rand = { "apache" }
	local rand = { "gunner", "gunner", "gunner", "juggernaut", "apache", "abrams", "tiger1", "littlebird", "abramsx" }
	for i = 1, 3 do
		local id = rand[((i - 1) % #rand) + 1]
		if not constants.getUnit(id) then
			print(`not found {id}`)
			return self
		end
		accounts.addUnit(plr, { assignedSquad = 1, unitId = id })
	end

	local account = accountStore.getAccount(plr.Name)
	if account then
		for guid, uData in account.units do
			local unitDef = constants.getUnit(uData.unitId) :: types.Unit
			local char = self.owner.Character or self.owner.CharacterAdded:Wait()
			table.insert(
				self.units,
				Unit.new(
					self.owner,
					unitDef,
					char:GetPivot() * CFrame.new(math.random() * 20, 0, math.random() * 20),
					guid
				)
			)
		end

		local snapshot: { types.UnitSnapshot } = {}
		for _, u in self.units do
			table.insert(snapshot, u:getSnapshot())
		end
		network.Units.LoadUnits:FireAllClients(snapshot)
	end

	return self
end

function PlayerUnits.moveTo(self: PlayerUnits, target: Vector3)
	local flyingUnits = TableUtil.Filter(self.units, function(u: Unit)
		return u.unit.movementMode == "flying"
	end)
	local groundUnits = TableUtil.Filter(self.units, function(u: Unit)
		return u.unit.movementMode ~= "flying"
	end)

	local flyingFormation = unitRaycast.buildFormation(target, flyingUnits, 0)
	local groundFormation = unitRaycast.buildFormation(target, groundUnits, 0)

	for i, u in flyingUnits do
		u:moveTo(flyingFormation[i]):andThen(function()
			print("[unit] movement action resolved")
		end)
	end
	for i, u in groundUnits do
		u:moveTo(groundFormation[i]):andThen(function()
			print("[unit] movement action resolved")
		end)
	end
end

local Units = {}

function Units.init(self: Units)
	unitRaycast.initRaycastParams()

	self.PlayerUnits = {}
	network.Units.RequestUnits.OnServerEvent:Connect(function(plr: Player)
		self.PlayerUnits[plr.Name] = PlayerUnits.new(plr)
	end)
	network.Units.RequestPath.OnServerEvent:Connect(function(plr: Player, target: Vector3)
		local plrUnits = self.PlayerUnits[plr.Name]
		plrUnits:moveTo(target)
	end)
end

type Units = typeof(Units) & { PlayerUnits: { [string]: PlayerUnits } }

return Units :: Units
