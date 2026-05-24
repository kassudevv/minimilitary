local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SMUnit = require("../server/unit")
local accountStore = require("../../accounts/server/accountStore")
local accounts = require("../../accounts/server")
local attribute = require("@game/ReplicatedStorage/src/accounts/shared/utils/attribute")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local spatialGrid = require("./spatialGrid")
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
	local tickRate = 1 / 2
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
			local pveTargetRange = attackRange * 1.025
			local targetRange = attackRange * 1.3

			local nearest, nearestDist = nil, math.huge
			local nearestWithLoS, nearestDistWithLoS = nil, math.huge

			self.targetGrid:forEachEnemyInRange(u, targetRange, function(target, distSq)
				local dist = math.sqrt(distSq)

				if dist < nearestDist and target.stateMachine.state ~= "dead" then
					nearest = target
					nearestDist = dist

					if u:hasLineOfSight(nearest) then
						nearestWithLoS = target
						nearestDistWithLoS = dist
					end
				end
			end)

			if nearestWithLoS then
				if nearestDistWithLoS <= attackRange then
					u:target(nearestWithLoS)
					continue
				end

				if nearestDistWithLoS <= targetRange then
					local closest = unitRaycast.closestPointOnCircle(
						nearestWithLoS.pawn.Position,
						attackRange * math.random(50, 90) * 0.01,
						u.pawn.Position
					)
					u:move(closest)
					continue
				end
			end

			if nearest and nearestDist <= attackRange then
				u:target(nearest)
				continue
			end

			if nearest and nearestDist <= targetRange then
				if
					(u.owner ~= "pve" and nearest.owner == "pve")
					or (u.owner == "pve" and nearestDist <= pveTargetRange)
				then
					if u.owner == "pve" and not u:hasLineOfSight(nearest) then
						continue
					end

					if u.def.movementMode == "flying" then
						local closest = unitRaycast.closestPointOnCircle(
							nearest.pawn.Position,
							attackRange * math.random(50, 90) * 0.01,
							u.pawn.Position
						)
						u:move(closest)
						continue
					end

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

		local rand =
			{ "gunner", "gunner", "gunner", "gunner", "abrams", "juggernaut", "tiger1", "littlebird", "abrams" }
		for i = 1, 1 do
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
