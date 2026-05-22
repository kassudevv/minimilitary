local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Promise = require("@game/ReplicatedStorage/Packages/Promise")
local accountStore = require("../accounts/server/accountStore")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
local encoder = require("@game/ReplicatedStorage/src/units/shared/encoder")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local serverTypes = require("@self/serverTypes")
local types = require("@game/ReplicatedStorage/src/units/shared/types")

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
		AgentRadius = 0.5,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentMaxSlope = 90,
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
	return Promise.new(function(resolve, reject, onCancel)
		self.pathfinder:ComputeAsync(self.pawn.Position, target)
		if self.pathfinder.Status ~= Enum.PathStatus.Success then
			return reject()
		end

		local waypoints = self.pathfinder:GetWaypoints()
		self.pawn.Position = waypoints[#waypoints].Position

		local result = encoder.encodeWaypoints(waypoints)
		for _ = 1, 10 do
			network.Units.MoveUnit:FireAllClients(self.guid, result)
		end
	end)
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

	local account = accountStore.getAccount(plr.Name)
	if account then
		for guid, uData in account.units do
			print(guid, uData)

			local unitDef = constants.getUnit(uData.unitId)
			local char = self.owner.Character or self.owner.CharacterAdded:Wait()
			table.insert(
				self.units,
				Unit.new(
					self.owner,
					unitDef,
					char:GetPivot() * CFrame.new(math.random() * 5, 0, math.random() * 5),
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
	for _, u in self.units do
		u:moveTo(target)
	end
end

local Units = {}

function Units.init(self: Units)
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
