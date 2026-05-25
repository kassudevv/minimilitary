local Squash = require("../../../Packages/Squash")
local TableUtil = require("../../../Packages/TableUtil")
local stateMachine = require("./stateMachine")
local unitTypes = require("./types")

--* ENCODE WAYPOINTS TO BUF
local COORD_MULTIPLIER = 16
local Y_MULTIPLIER = 32 -- tighter vertical range → finer precision
local function encodeWaypoints(waypoints: { Vector3 }): buffer
	local serArr = Squash.array(Squash.Vector3int16())
	local cursor = Squash.cursor()

	local arr: { Vector3int16 } = TableUtil.Map(waypoints, function(wp: Vector3)
		return Vector3int16.new(
			math.floor(wp.X * COORD_MULTIPLIER + 0.5),
			math.floor(wp.Y * Y_MULTIPLIER + 0.5),
			math.floor(wp.Z * COORD_MULTIPLIER + 0.5)
		)
	end)

	serArr.ser(cursor, arr)
	return Squash.tobuffer(cursor)
end

local function decodeWaypoints(buf: buffer): { Vector3 }
	local serArr = Squash.array(Squash.Vector3int16())
	local cursor = Squash.frombuffer(buf)

	local arr = serArr.des(cursor)

	return TableUtil.Map(arr, function(wp: Vector3int16): Vector3
		return Vector3.new(wp.X / COORD_MULTIPLIER, wp.Y / Y_MULTIPLIER, wp.Z / COORD_MULTIPLIER)
	end)
end

--*REPLICATE STATE MACHINE TRANSITION
local SMRecord = Squash.record({
	id = Squash.T(Squash.vlq()),
	state = Squash.T(Squash.literal("dead", "idle", "moving", "targeting")),
})
function encodeSM(id: number, newState: stateMachine.State)
	local cursor = Squash.cursor()
	SMRecord.ser(cursor, {
		id = id,
		state = newState,
	})
	return Squash.tobuffer(cursor)
end

function decodeSM(buf: buffer)
	local cursor = Squash.frombuffer(buf)
	return SMRecord.des(cursor)
end

--*REPLICATE HEALTH
local HealthRecord = Squash.record({
	id = Squash.T(Squash.vlq()),
	health = Squash.T(Squash.vlq()),
})
function encodeHealth(id: number, health: number)
	local cursor = Squash.cursor()
	HealthRecord.ser(cursor, {
		id = id,
		health = health,
	})
	return Squash.tobuffer(cursor)
end
function decodeHealth(buf: buffer)
	local cursor = Squash.frombuffer(buf)
	return HealthRecord.des(cursor)
end

local unitSerializer = Squash.record({
	itemId = Squash.T(Squash.string()),
	owner = Squash.T(Squash.string()),
	position = Squash.T(Squash.CFrame(Squash.i32(8))),
	id = Squash.T(Squash.vlq()),
})

local unitArraySerializer = Squash.array(unitSerializer)
function encodeUnits(units: { unitTypes.UnitSnapshot })
	local cursor = Squash.cursor()
	unitArraySerializer.ser(cursor, units)
	return Squash.tobuffer(cursor)
end
function decodeUnits(buf: buffer): { unitTypes.UnitSnapshot }
	local cursor = Squash.frombuffer(buf)
	return unitArraySerializer.des(cursor)
end

-- local UnitRecord = Squash.record({
-- 	itemId = Squash.T(Squash.string()),
-- 	owner = Squash.T(Squash.string()),
-- 	position = Squash.T(Squash.CFrame(Squash.vlq())),
-- 	id = Squash.T(Squash.vlq()),
-- })
-- function encodeUnits(units: { unitTypes.UnitSnapshot })
-- 	local cursor = Squash.cursor()

-- 	local buffs = TableUtil.Map(units, function(unit: unitTypes.UnitSnapshot)
-- 		local uCursor = Squash.cursor()
-- 		UnitRecord.ser(uCursor, {
-- 			itemId = unit.itemId,
-- 			owner = unit.owner,
-- 			position = unit.position,
-- 			id = unit.id,
-- 		})
-- 		return Squash.tobuffer(uCursor)
-- 	end)

-- 	local buffArr = Squash.array(Squash.buffer())
-- 	buffArr.ser(cursor, buffs)

-- 	return Squash.tobuffer(cursor)
-- end
-- function decodeUnits(buf: buffer)
-- 	local cursor = Squash.frombuffer(buf)
-- 	return UnitRecord.des(cursor)
-- end

return {
	encodeWaypoints = encodeWaypoints,
	decodeWaypoints = decodeWaypoints,

	encodeSM = encodeSM,
	decodeSM = decodeSM,

	encodeHealth = encodeHealth,
	decodeHealth = decodeHealth,

	encodeUnits = encodeUnits,
	decodeUnits = decodeUnits,
}
