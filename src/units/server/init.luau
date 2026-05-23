local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local PlayerUnits = require("@self/playerUnits")
local SpatialGrid = require("@self/spatialGrid")
local Unit = require("@self/unit")
local constants = require("@game/ReplicatedStorage/src/units/shared/constants")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

local TICK_RATE = 1 / 5
local TARGET_GRID_CELL_SIZE = 32

local Units = {}

function Units.init(self: Units)
	self.units = {}
	self.playerUnits = {}
	self.targetGrid = SpatialGrid.new(TARGET_GRID_CELL_SIZE)

	local unitCallbacks = {
		onDeath = function(guid: string)
			local unit = self.units[guid]
			if not unit then
				return
			end

			-- print(`[unit] destroyed {guid}`)
			self:destroyUnit(unit.guid)
		end,

		onDamage = function(guid: string, amount: number)
			local unit = self.units[guid]
			if not unit then
				return
			end

			-- print(`[unit] dealt {amount} damage to {guid}`)
		end,
	}

	unitRaycast.initRaycastParams()

	network.Units.RequestUnits.OnServerEvent:Connect(function(plr: Player)
		self.playerUnits[plr.Name] = PlayerUnits.new(plr, unitCallbacks)
		for _, u in self.playerUnits[plr.Name].units do
			self.units[u.guid] = u
		end

		self:replicateUnits(plr)
	end)
	network.Units.RequestPath.OnServerEvent:Connect(function(plr: Player, target: Vector3)
		local plrUnits = self.playerUnits[plr.Name]
		plrUnits:moveTo(target)
	end)
	network.Units.ApplyPendingHit.OnServerEvent:Connect(function(plr: Player, guid: string)
		local u = self.units[guid]
		if u then
			u:applyPendingHit()
		end
	end)

	for _ = 1, 300 do
		local unit = constants.getUnit("gunner")
		assert(unit ~= nil, "unit is nil")
		local pveUnitGuid = HttpService:GenerateGUID(false)
		self.units[pveUnitGuid] = Unit.new(
			nil,
			unit,
			CFrame.new(Vector3.new(-38 + (math.random() * 120) - 60, 4.5, -183.5 + ((math.random() * 60) - 30))),
			pveUnitGuid,
			unitCallbacks
		)
	end

	do
		local unit = constants.getUnit("gunner")
		assert(unit ~= nil, "unit is nil")
		local pveUnitGuid = HttpService:GenerateGUID(false)
		self.units[pveUnitGuid] = Unit.new(
			nil,
			unit,
			CFrame.new(Vector3.new(-38 + (math.random() * 120) - 60, 4.5, -183.5 + ((math.random() * 60) - 30))),
			pveUnitGuid,
			unitCallbacks
		)
	end

	do
		local unit = constants.getUnit("apache")
		assert(unit ~= nil, "unit is nil")
		local pveUnitGuid = HttpService:GenerateGUID(false)
		self.units[pveUnitGuid] = Unit.new(
			nil,
			unit,
			CFrame.new(Vector3.new(-38 + (math.random() * 120) - 60, 4.5, -183.5 + ((math.random() * 60) - 30))),
			pveUnitGuid,
			unitCallbacks
		)
	end

	do
		local unit = constants.getUnit("littlebird")
		assert(unit ~= nil, "unit is nil")
		local pveUnitGuid = HttpService:GenerateGUID(false)
		self.units[pveUnitGuid] = Unit.new(
			nil,
			unit,
			CFrame.new(Vector3.new(-38 + (math.random() * 120) - 60, 4.5, -183.5 + ((math.random() * 60) - 30))),
			pveUnitGuid,
			unitCallbacks
		)
	end

	do
		local unit = constants.getUnit("abramsx")
		assert(unit ~= nil, "unit is nil")
		local pveUnitGuid = HttpService:GenerateGUID(false)
		self.units[pveUnitGuid] = Unit.new(
			nil,
			unit,
			CFrame.new(Vector3.new(-38 + (math.random() * 120) - 60, 4.5, -183.5 + ((math.random() * 60) - 30))),
			pveUnitGuid,
			unitCallbacks
		)
	end

	self:startTick()
end

local function closestPointOnCircle(
	center: Vector3, -- enemy position
	radius: number, -- max_range in world units
	point: Vector3 -- your unit's position
): Vector3
	local dir = point - center

	-- If the unit is exactly on top of the enemy (degenerate case),
	-- just pick an arbitrary direction
	if dir.Magnitude < 0.001 then
		dir = Vector3.new(1, 0, 0)
	end

	-- Normalize then scale to radius — that lands you ON the circle
	return center + dir.Unit * radius
end

function Units.scanTargets(self: Units)
	self.targetGrid:rebuild(self.units)

	for _, unit in self.units do
		if unit.movePromise and unit.movePromise:getStatus() == "Started" then
			continue
		end
		if unit.targetingPromise and unit.targetingPromise:getStatus() == "Started" then
			continue
		end

		local attackRange = unit.unit.range
		local targetRange = attackRange * 1.4

		local nearest, nearestDist = nil, math.huge
		self.targetGrid:forEachEnemyInRange(unit, targetRange, function(target, distSq)
			local dist = math.sqrt(distSq)

			if dist < nearestDist then
				nearest = target
				nearestDist = dist
				return
			end
		end)

		if nearest and nearestDist <= attackRange then
			unit:startTargeting(nearest)
			continue
		end

		if nearest and nearestDist <= targetRange then
			if unit.owner ~= -1 then
				local closest = closestPointOnCircle(
					nearest.pawn.Position,
					attackRange * math.random(50, 90) * 0.01,
					unit.pawn.Position
				)
				unit:moveTo(closest)
			end
		end
	end
end

function Units.startTick(self: Units)
	local lastTick = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - lastTick
		if elapsed < TICK_RATE then
			return
		end
		lastTick = os.clock()

		self:scanTargets()
	end)
	return conn
end

function Units.destroyUnit(self: Units, guid: string)
	for _, u in self.units do
		if u.guid ~= guid then
			continue
		end

		u:cleanup()
		self.units[u.guid] = nil
		network.Units.DestroyUnits:FireAllClients({ u.guid })
		return
	end
end

function Units.replicateUnits(self: Units, player: Player)
	local snapshot: { types.UnitSnapshot } = {}
	for _, u in self.units do
		table.insert(snapshot, u:getSnapshot())
	end
	network.Units.LoadUnits:FireAllClients(snapshot)
end

type Units = typeof(Units) & {
	playerUnits: { [string]: PlayerUnits.PlayerUnits },
	targetGrid: SpatialGrid.SpatialGrid,
	units: { [string]: Unit.Unit },
}

return Units :: Units
