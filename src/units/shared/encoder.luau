local function encodeWaypoints(waypoints: { Vector3 }): buffer
	local buf = buffer.create(#waypoints * 12)
	for i, wp in waypoints do
		local offset = (i - 1) * 12

		buffer.writef32(buf, offset, wp.X)
		buffer.writef32(buf, offset + 4, wp.Y)
		buffer.writef32(buf, offset + 8, wp.Z)
	end
	return buf
end

local function decodeWaypoints(buf: buffer): { Vector3 }
	local count = buffer.len(buf) / 12
	local result: { Vector3 } = {}
	for i = 1, count do
		local offset = (i - 1) * 12
		result[i] =
			Vector3.new(buffer.readf32(buf, offset), buffer.readf32(buf, offset + 4), buffer.readf32(buf, offset + 8))
	end
	return result
end

return {
	encodeWaypoints = encodeWaypoints,
	decodeWaypoints = decodeWaypoints,
}
