local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SMUnit = require("../server/unit")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local TaskQueue = require("@game/ReplicatedStorage/src/core/shared/TaskQueue")
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
	self.targetGrid = spatialGrid.new(64)

	unitRaycast:initRaycastParams()
	unitRaycast:initLosRaycastParams()

	self.destroyCb = function(u: SMUnit.SMUnit)
		u:cleanup()
		self.units[u.guid] = nil
	end

	--state machine
	RunService.Heartbeat:Connect(function(dt)
		debug.profilebegin("SERVER-TICK")
		for _, u in self.units do
			u.stateMachine:tick(dt)
		end
		debug.profileend()
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

		local flyingFormation = unitRaycast.buildFormation(target, #flyingUnits, 4)
		local groundFormation = unitRaycast.buildFormation(target, #groundUnits, 4)

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

		-- local rand = string.lower(plr.Name) == "player1" and { "abrams", "tiger1" } or { "apache" }
		-- local rand = { "gunner", "gunner", "gunner", "juggernaut", "gunner", "tiger1", "abrams" }
		local rand =
			{ "gunner", "apache", "gunner", "gunner", "abrams", "juggernaut", "tiger1", "littlebird", "abrams" }
		for i = 1, 1000 do
			local id = rand[((i - 1) % #rand) + 1]
			assert(constants.getUnit(id) ~= nil, "invalid unitId")
			accounts.addUnit(plr, { assignedSquad = 1, unitId = id })
		end

		-- accounts.addUnit(plr, { ass gnedSquad = 1, unitId = "apache" })

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
	self.units[guid] = SMUnit.new(unitDef, options.owner, guid, options.position, self.destroyCb)

	if options.replicate then
		self:ReplicateUnits({ self.units[guid] })
	end

	return self.units[guid]
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
	targetGrid: spatialGrid.SpatialGrid,
	destroyCb: (SMUnit.SMUnit) -> (),
}

return SMUnits :: SMUnits
