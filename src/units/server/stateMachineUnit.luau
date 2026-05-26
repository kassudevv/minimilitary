--!optimize 2
local HttpService = game:GetService("HttpService")
local SMUnit = require("../server/unit")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local Tick = require("@game/ReplicatedStorage/src/core/shared/Tick")
local accountStore = require("../../accounts/server/accountStore")
local accounts = require("../../accounts/server")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
local encoder = require("@game/ReplicatedStorage/src/units/shared/encoder")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local spatialGrid = require("./spatialGrid")
local targeting = require("./targeting")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

local SMUnits = {}

function SMUnits.init(self: SMUnits)
	self.units = {}
	self.unitsArr = {}
	self.targetGrid = spatialGrid.new(64)

	unitRaycast:initRaycastParams()
	unitRaycast:initLosRaycastParams()

	self.destroyCb = function(u: SMUnit.SMUnit)
		self:DestroyUnit(u)
	end

	--state machine
	Tick.every(0, function(dt)
		for _, u in self.units do
			u.stateMachine:tick(dt)
		end
	end)

	local tick_rate = 1 / 5
	Tick.every(tick_rate, function()
		self.targetGrid:rebuild(self.units)
		debug.profilebegin("allticker")
		for _, u in self.units do
			targeting.tickUnit(u, self.targetGrid)
		end
		debug.profileend()
	end)

	-- local cursor = 1
	-- Tick.every(1 / 2, function()
	-- 	debug.profilebegin("spreadticke")

	-- 	local processed = 0
	-- 	local maxUnits = 64

	-- 	while processed < maxUnits do
	-- 		local u = self.unitsArr[cursor]

	-- 		if not u then
	-- 			cursor = 1
	-- 			break
	-- 		end

	-- 		targeting.tickUnit(u, self.targetGrid)

	-- 		cursor += 1
	-- 		processed += 1
	-- 	end

	-- 	debug.profileend()
	-- end)

	--networking events
	network.Units.RequestPath.OnServerEvent:Connect(function(plr: Player, target: Vector3)
		local flyingUnits: { SMUnit.SMUnit }, groundUnits: { SMUnit.SMUnit } = {}, {}
		for k, u in self.units do
			if u.owner ~= plr.Name then
				continue
			end
			local tbl = u.def.movementMode == "flying" and flyingUnits or groundUnits
			table.insert(tbl, u)
		end

		local flyingFormation = unitRaycast.buildFormation(target, #flyingUnits, 1)
		local groundFormation = unitRaycast.buildFormation(target, #groundUnits, 1)

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

	network.Units.ApplyPendingHit.OnServerEvent:Connect(function(plr: Player, target: number, amt: number)
		for _, u in self.units do
			if u.id ~= target then
				continue
			end

			u:applyFromDamageQueue(amt)

			return
		end
	end)

	network.Units.RequestUnits.OnServerEvent:Connect(function(plr: Player)
		self:ReplicateUnitsToPlayer(plr, TableUtil.Values(self.units))

		local rand = {
			"gunner",
		}
		for i = 1, 300 do
			local id = rand[((i - 1) % #rand) + 1]
			assert(constants.getUnit(id) ~= nil, "invalid unitId")
			accounts.addUnit(plr, { assignedSquad = 1, unitId = id })
		end

		local account = accountStore.getAccount(plr.Name)
		if account then
			local batchReplicate = {}
			local char = plr.Character or plr.CharacterAdded:Wait()
			for guid, uData in account.units do
				table.insert(
					batchReplicate,
					self:SpawnUnit({
						guid = guid,
						unitId = uData.unitId,
						position = char:GetPivot(),
						replicate = false,
						owner = plr,
					})
				)
			end
			self:ReplicateUnits(batchReplicate)
		end
	end)
end

function SMUnits.SpawnUnit(
	self: SMUnits,
	options: {
		guid: string?,
		owner: Player?,
		unitId: string,
		position: CFrame,
		replicate: boolean,
	}
): SMUnit.SMUnit
	local guid = options.guid or HttpService:GenerateGUID(false)

	local unitDef = constants.getUnit(options.unitId) :: types.Unit
	local unit = SMUnit.new(unitDef, options.owner, guid, options.position, self.destroyCb)

	if options.replicate then
		self:ReplicateUnits({ unit })
	end

	table.insert(self.unitsArr, unit)
	self.units[guid] = unit

	return self.units[guid]
end

function SMUnits.DestroyUnit(self: SMUnits, unit: SMUnit.SMUnit)
	local idx = table.find(self.unitsArr, unit)
	if idx then
		table.remove(self.unitsArr, idx)
	end
	self.units[unit.guid] = nil

	unit:cleanup()
end

function SMUnits.ReplicateUnits(self: SMUnits, units: { SMUnit.SMUnit })
	network.Units.LoadUnits:FireAllClients(
		encoder.encodeUnits(TableUtil.Map(units, function(u: SMUnit.SMUnit): types.UnitSnapshot
			return u:snapshot()
		end))
	)
end

function SMUnits.ReplicateUnitsToPlayer(self: SMUnits, plr: Player, units: { SMUnit.SMUnit })
	network.Units.LoadUnits:FireClient(
		plr,
		encoder.encodeUnits(TableUtil.Map(units, function(u: SMUnit.SMUnit): types.UnitSnapshot
			return u:snapshot()
		end))
	)
end

type SMUnits = typeof(SMUnits) & {
	units: { [string]: SMUnit.SMUnit },
	unitsArr: { SMUnit.SMUnit },
	targetGrid: spatialGrid.SpatialGrid,
	destroyCb: (SMUnit.SMUnit) -> (),
}

return SMUnits :: SMUnits
