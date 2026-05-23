-- local function encodeWaypoints(waypoints: { Vector3 }): buffer
-- 	local buf = buffer.create(#waypoints * 12)
-- 	for i, wp in waypoints do
-- 		local offset = (i - 1) * 12

-- 		buffer.writef32(buf, offset, wp.X)
-- 		buffer.writef32(buf, offset + 4, wp.Y)
-- 		buffer.writef32(buf, offset + 8, wp.Z)
-- 	end
-- 	return buf
-- end

-- local function decodeWaypoints(buf: buffer): { Vector3 }
-- 	local count = buffer.len(buf) / 12
-- 	local result: { Vector3 } = {}
-- 	for i = 1, count do
-- 		local offset = (i - 1) * 12
-- 		result[i] =
-- 			Vector3.new(buffer.readf32(buf, offset), buffer.readf32(buf, offset + 4), buffer.readf32(buf, offset + 8))
-- 	end
-- 	return result
-- end

-- return {
-- 	encodeWaypoints = encodeWaypoints,
-- 	decodeWaypoints = decodeWaypoints,
-- }

local COORD_MULTIPLIER = 4
local Y_MULTIPLIER = 8 -- tighter vertical range → finer precision

local function encodeWaypoints(waypoints: { Vector3 }): buffer
	local buf = buffer.create(#waypoints * 6)
	for i, wp in waypoints do
		local offset = (i - 1) * 6
		buffer.writei16(buf, offset, math.floor(wp.X * COORD_MULTIPLIER + 0.5))
		buffer.writei16(buf, offset + 2, math.floor(wp.Y * Y_MULTIPLIER + 0.5))
		buffer.writei16(buf, offset + 4, math.floor(wp.Z * COORD_MULTIPLIER + 0.5))
	end
	return buf
end

local function decodeWaypoints(buf: buffer): { Vector3 }
	local count = buffer.len(buf) / 6
	local result: { Vector3 } = {}
	for i = 1, count do
		local offset = (i - 1) * 6
		result[i] = Vector3.new(
			buffer.readi16(buf, offset) / COORD_MULTIPLIER,
			buffer.readi16(buf, offset + 2) / Y_MULTIPLIER,
			buffer.readi16(buf, offset + 4) / COORD_MULTIPLIER
		)
	end
	return result
end

return {
	encodeWaypoints = encodeWaypoints,
	decodeWaypoints = decodeWaypoints,
}
