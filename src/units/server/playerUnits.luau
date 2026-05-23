local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

local Unit = require("./unit")
local accountStore = require("../../accounts/server/accountStore")
local accounts = require("../../accounts/server")

--* ────────────────────────────────────────────────────────────────────────────
--* UNITS
--* ────────────────────────────────────────────────────────────────────────────
local PlayerUnits = {}
PlayerUnits.__index = PlayerUnits

type PlayerUnitsData = {
	owner: Player,
	units: { Unit.Unit },
}

export type PlayerUnits = setmetatable<PlayerUnitsData, typeof(PlayerUnits)>

function PlayerUnits.new(plr: Player, unitCallbacks: { [string]: (string) -> () }): PlayerUnits
	local self = setmetatable({} :: PlayerUnitsData, PlayerUnits)

	self.owner = plr
	self.units = {}

	local rand = { "juggernaut" }
	-- local rand = { "apache", "gunner", "gunner", "gunner", "abrams", "juggernaut", "tiger1", "littlebird", "abrams" }
	for i = 1, 15 do
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
					guid,
					unitCallbacks
				)
			)
		end
	end

	return self
end

function PlayerUnits.moveTo(self: PlayerUnits, target: Vector3)
	local flyingUnits = TableUtil.Filter(self.units, function(u: Unit.Unit)
		return u.unit.movementMode == "flying"
	end)
	local groundUnits = TableUtil.Filter(self.units, function(u: Unit.Unit)
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

return PlayerUnits
