local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SMUnit = require("../server/unit")
local Squash = require("@game/ReplicatedStorage/Packages/Squash")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local accountStore = require("../../accounts/server/accountStore")
local accounts = require("../../accounts/server")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
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
			targeting.tickUnit(u, self.targetGrid)
		end
	end)

	--networking events
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
		self:ReplicateUnitsToPlayer(plr, TableUtil.Values(self.units))

		local rand = { "gunner", "gunner", "gunner", "juggernaut", "apache" }
		-- local rand = { "gunner", "apache", "gunner", "gunner", "abrams", "juggernaut", "tiger1", "littlebird", "abrams" }
		for i = 1, 10 do
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
	self.units[guid] = SMUnit.new(unitDef, options.owner, guid, options.position, self.destroyCb)

	if options.replicate then
		network.Units.LoadUnits:FireAllClients({ self.units[guid]:snapshot() })
	end

	print(`Spawned unit {unitDef.itemId}`)

	return self.units[guid]
end

function SMUnits.ReplicateUnits(self: SMUnits, units: { SMUnit.SMUnit })
	network.Units.LoadUnits:FireAllClients(TableUtil.Map(units, function(u: SMUnit.SMUnit): types.UnitSnapshot
		return u:snapshot()
	end))
end

function SMUnits.ReplicateUnitsToPlayer(self: SMUnits, plr: Player, units: { SMUnit.SMUnit })
	network.Units.LoadUnits:FireClient(
		plr,
		TableUtil.Map(units, function(u: SMUnit.SMUnit): types.UnitSnapshot
			return u:snapshot()
		end)
	)
end

type SMUnits = typeof(SMUnits) & {
	units: { [string]: SMUnit.SMUnit },
	targetGrid: spatialGrid.SpatialGrid,
	destroyCb: (SMUnit.SMUnit) -> (),
}

return SMUnits :: SMUnits
