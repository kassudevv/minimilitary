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
		task.delay(10, function()
			self:DestroyUnit(u)
		end)
	end

	--state machine
	Tick.every(0, function(dt)
		for _, u in self.unitsArr do
			u.stateMachine:tick(dt)
		end
	end)

	local tick_rate = 1 / 10
	Tick.every(tick_rate, function()
		self.targetGrid:rebuild(self.units)
		for _, u in self.unitsArr do
			targeting.tickUnit(u, self.targetGrid)
		end
	end)

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

		local flyingFormation = unitRaycast.buildFormation(target, #flyingUnits, 16)
		local groundFormation = unitRaycast.buildFormation(target, #groundUnits, 16)

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

		local rand: { constants.UnitId } = {
			"abrams",
			"tiger",
			"apache",
			"gunner",
			"gunner",
		}
		for i = 1, 5 do
			local id = rand[((i - 1) % #rand) + 1]
			accounts.addUnit(plr, { assignedSquad = 1, unitId = id })
		end

		-- accounts.addUnit(plr, { assignedSquad = 1, unitId = "abrams" })
		-- accounts.addUnit(plr, { assignedSquad = 1, unitId = "tiger" })
		-- accounts.addUnit(plr, { assignedSquad = 1, unitId = "apache" })

		local account = accountStore.getAccount(plr.Name)
		if account then
			local char = plr.Character or plr.CharacterAdded:Wait()

			local target = char:GetPivot()
			local groundFormation = unitRaycast.buildFormation(target.Position, #TableUtil.Keys(account.units), 8)

			local counter = 1
			local batchReplicate = {}
			for guid, uData in account.units do
				table.insert(
					batchReplicate,
					self:SpawnUnit({
						guid = guid,
						unitId = uData.unitId,
						position = CFrame.new(groundFormation[counter]) * target.Rotation,
						replicate = false,
						owner = plr,
					})
				)
				counter += 1
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
		unitId: constants.UnitId,
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
		local n = #self.unitsArr
		self.unitsArr[idx] = self.unitsArr[n]
		self.unitsArr[n] = nil
	end
	self.units[unit.guid] = nil

	unit:cleanup()

	network.Units.DestroyUnits:FireAllClients({ unit.id })
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
