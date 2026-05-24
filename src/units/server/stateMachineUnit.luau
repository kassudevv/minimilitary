local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SMUnit = require("../server/unit")
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
		self:LoadAllUnitsForPlayer(plr)

		local rand = { "gunner", "gunner", "gunner", "juggernaut", "apache" }
		-- local rand =
		-- 	{ "gunner", "apache", "gunner", "gunner", "abrams", "juggernaut", "tiger1", "littlebird", "abrams" }
		for i = 1, 8 do
			local id = rand[((i - 1) % #rand) + 1]
			assert(constants.getUnit(id) ~= nil, "invalid unitId")
			accounts.addUnit(plr, { assignedSquad = 1, unitId = id })
		end

		local account = accountStore.getAccount(plr.Name)

		if account then
			local newUnits = {}
			for guid, uData in account.units do
				local unitDef = constants.getUnit(uData.unitId) :: types.Unit
				local char = plr.Character or plr.CharacterAdded:Wait()
				self.units[guid] = SMUnit.new(unitDef, plr, guid, char:GetPivot(), self.destroyCb)
				table.insert(newUnits, self.units[guid])
			end
			self:ReplicateNewUnits(newUnits)
		end
	end)
end

function SMUnits.SpawnUnit(self: SMUnits, unitId: string, position: CFrame): SMUnit.SMUnit
	local guid = HttpService:GenerateGUID(false)
	local unitDef = constants.getUnit(unitId) :: types.Unit
	self.units[guid] = SMUnit.new(unitDef, nil, guid, position, self.destroyCb)
	network.Units.LoadUnits:FireAllClients({ self.units[guid]:snapshot() })
	return self.units[guid]
end

function SMUnits.ReplicateNewUnits(self: SMUnits, units: { SMUnit.SMUnit })
	local loadQueue = {}
	for _, u in self.units do
		table.insert(loadQueue, u:snapshot())
	end
	network.Units.LoadUnits:FireAllClients(loadQueue)
end

function SMUnits.LoadAllUnitsForPlayer(self: SMUnits, plr: Player)
	local loadQueue = {}
	for _, u in self.units do
		table.insert(loadQueue, u:snapshot())
	end
	network.Units.LoadUnits:FireClient(plr, loadQueue)
end

type SMUnits = typeof(SMUnits) & {
	units: { [string]: SMUnit.SMUnit },
	targetGrid: spatialGrid.SpatialGrid,
	destroyCb: (SMUnit.SMUnit) -> (),
}

return SMUnits :: SMUnits
