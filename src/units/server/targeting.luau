-- server/targeting.luau
local SMUnit = require("./unit")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")

local function getAttackPosition(unit: SMUnit.SMUnit, target, hasLos: boolean): Vector3?
	local range = unit.def.range * math.random(75, 85) * 0.01

	local dist = (unit.pawn.Position - target.pawn.Position).Magnitude
	range = math.min(range, dist)

	-- flying units don't need LoS pathing
	if unit.def.movementMode == "flying" or hasLos then
		return unitRaycast.closestPointOnCircle(target.pawn.Position, range, unit.pawn.Position)
	end

	return unitRaycast.closestPointOnCircleWithLos(target.pawn.Position, range, unit.pawn.Position)
end

local function scanTargets(unit: SMUnit.SMUnit, targetGrid)
	local attackRange = unit.def.range
	local targetRange = attackRange * (unit.owner ~= "pve" and 1.2 or 1.05)

	-- aggro mode
	if (os.clock() - unit.lastProjectileTs) < 30 then
		targetRange *= 2
	end

	local bestLoS, bestLoSDist = nil, math.huge
	local bestAny, bestAnyDist = nil, math.huge

	targetGrid:forEachEnemyInRange(unit, targetRange, function(target: SMUnit.SMUnit, distSq)
		if target.stateMachine.state == "dead" then
			return
		end

		local dist = math.sqrt(distSq)

		if dist < bestAnyDist then
			bestAny = target
			bestAnyDist = dist
		end

		if dist < bestLoSDist and unit:hasLineOfSight(target) then
			bestLoS = target
			bestLoSDist = dist
		end
	end)

	return {
		losTarget = bestLoS,
		losDist = bestLoSDist,
		anyTarget = bestAny,
		anyDist = bestAnyDist,
		attackRange = attackRange,
		targetRange = targetRange,
	}
end

local function tickUnit(unit: SMUnit.SMUnit, targetGrid)
	if unit.stateMachine.state ~= "idle" or unit.isThinking then
		return
	end

	local s = scanTargets(unit, targetGrid)

	-- 1. LoS target in attack range → fire
	if s.losTarget and s.losDist <= s.attackRange then
		-- Give player troops a chance to attack first
		-- if unit.owner == "pve" and #unit.damageQueue == 0 then
		-- 	return
		-- end

		unit:target(s.losTarget)
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

	-- -- 5. Out of attack range, no LoS — PvE holds position
	-- if unit.owner == "pve" then
	-- 	return
	-- end

	-- -- 6. Player unit — find a LoS position and move there
	-- if s.anyDist <= s.targetRange then
	-- 	local pos = getAttackPosition(unit, s.anyTarget, false)
	-- 	if pos then
	-- 		unit:move(pos)
	-- 	end
	-- end
end

return {
	tickUnit = tickUnit,
}
