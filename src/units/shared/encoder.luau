local Squash = require("../../../Packages/Squash")
local TableUtil = require("../../../Packages/TableUtil")
local stateMachine = require("./stateMachine")

local COORD_MULTIPLIER = 8
local Y_MULTIPLIER = 16 -- tighter vertical range → finer precision
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

local SMRecord = Squash.record({
	id = Squash.T(Squash.vlq()),
	state = Squash.T(Squash.literal("dead", "idle", "moving", "targeting")),
})
function encodeSM(id: number, newState: stateMachine.State, data: { [string]: any })
	local cursor = Squash.cursor()
	SMRecord.ser(cursor, {
		id = id,
		state = newState,
	})
	return Squash.tobuffer(cursor), data
end

function decodeSM(buf: buffer)
	local cursor = Squash.frombuffer(buf)
	return SMRecord.des(cursor)
end

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

return {
	encodeWaypoints = encodeWaypoints,
	decodeWaypoints = decodeWaypoints,
	encodeSM = encodeSM,
	decodeSM = decodeSM,
	encodeHealth = encodeHealth,
	decodeHealth = decodeHealth,
}
