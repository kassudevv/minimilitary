--!optimize 2
-- server/targeting.luau
local SMUnit = require("./unit")
local spatialGrid = require("./spatialGrid")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

local function getAttackPosition(unit: SMUnit.SMUnit, target, hasLos: boolean): Vector3?
	local range = unit.def.range * 0.85
	local dist = (unit.pawn.Position - target.pawn.Position).Magnitude
	range = math.min(range, dist)

	if not hasLos then
		range = unit.def.range * 0.05
	end

	-- flying units don't need LoS pathing
	if unit.def.movementMode == "flying" or hasLos then
		return unitRaycast.closestPointOnCircle(target.pawn.Position, range, unit.pawn.Position)
	end

	return unitRaycast.closestPointOnCircleWithLos(target.pawn.Position, range, unit.pawn.Position)
end

local function scanTargets(unit: SMUnit.SMUnit, targetGrid: spatialGrid.SpatialGrid, now: number)
	local attackRange = unit.def.range
	local targetRange = attackRange * (unit.owner ~= "pve" and 2 or 1.1)

	-- aggro mode
	if (now - unit.lastProjectileTs) < 30 then
		targetRange *= 3
	end

	local bestLoS, bestLoSDist = nil, math.huge
	local bestAny, bestAnyDist = nil, math.huge

	targetGrid:forEachEnemyInRange(unit, targetRange, function(target: SMUnit.SMUnit, distSq)
		if target.stateMachine.state == "dead" then
			return
		end

		if distSq < bestAnyDist then
			bestAny = target
			bestAnyDist = distSq
		end

		if distSq < bestLoSDist and unit:hasLineOfSight(target) then
			bestLoS = target
			bestLoSDist = distSq
		end
	end)

	return {
		losTarget = bestLoS,
		losDist = math.sqrt(bestLoSDist),
		anyTarget = bestAny,
		anyDist = math.sqrt(bestAnyDist),
		attackRange = attackRange,
		targetRange = targetRange,
	}
end

function tickUnit(unit: SMUnit.SMUnit, targetGrid: spatialGrid.SpatialGrid)
	unit = unit :: SMUnit.SMUnit

	if unit.isThinking or unit.stateMachine.state == "dead" or unit.stateMachine.state == "targeting" then
		return
	end

	local now = os.clock()
	local s = scanTargets(unit, targetGrid, now)

	-- 1. LoS target in attack range → fire
	if s.losTarget and s.losDist <= s.attackRange then
		-- unit was moving but found a valid target in line of sight
		if unit.stateMachine.state == "moving" then
			if os.clock() - unit.lastMoveInterruptTs > 3 then
				unit.lastMoveInterruptTs = os.clock()
			else
				return
			end
		end

		unit:target(s.losTarget)
		return
	end

	-- unit is already moving
	if unit.stateMachine.state == "moving" then
		return
	end

	-- 2. LoS target in targeting range → move into position
	if s.losTarget and s.losDist <= s.targetRange then
		local pos = getAttackPosition(unit, s.losTarget, true)
		if pos then
			unit:move(pos)
		end
		return
	end

	-- 3. No target at all
	if not s.anyTarget then
		return
	end

	-- 4. Close enough to attack but no LOS
	if unit.owner == "pve" then
		return
	end
	if s.anyDist <= s.targetRange then
		local pos = getAttackPosition(unit, s.anyTarget, false)
		if pos then
			unit:move(pos)
		end
		return
	end
end

return {
	tickUnit = tickUnit,
}
