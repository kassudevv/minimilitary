local function encodeWaypoints(waypoints: { PathWaypoint }): buffer
	local buf = buffer.create(#waypoints * 4)
	for i, wp in waypoints do
		local offset = (i - 1) * 4
		buffer.writei16(buf, offset, wp.Position.X)
		buffer.writei16(buf, offset + 2, wp.Position.Z)
	end
	return buf
end

-- decode: buffer → Vector2 array (client reconstructs XZ, raycasts Y itself)
local function decodeWaypoints(buf: buffer): { Vector2 }
	local count = buffer.len(buf) / 4
	local result: { Vector2 } = {}
	for i = 1, count do
		local offset = (i - 1) * 4
		result[i] = Vector2.new(buffer.readi16(buf, offset), buffer.readi16(buf, offset + 2))
	end
	return result
end

return {
	encodeWaypoints = encodeWaypoints,
	decodeWaypoints = decodeWaypoints,
}
