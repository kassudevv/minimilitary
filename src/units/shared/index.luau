local Index = {
	_counter = 0,
	guidToId = {},
	idToGuid = {},
}

function Index.registerNew(guid: string): number
	Index._counter += 1

	if Index._counter > 4.2 * 10 ^ 9 then
		Index._counter = 1
	end

	Index.guidToId[guid] = Index._counter
	Index.idToGuid[Index._counter] = guid

	return Index._counter
end

function Index.register(guid: string, id: number): number
	Index.guidToId[guid] = id
	Index.idToGuid[id] = guid

	return Index._counter
end

function Index.get(buf: buffer): string
	local num = Index.readBuf(buf)
	return Index.idToGuid[num]
end

function Index.readBuf(buf: buffer): number
	return buffer.readu32(buf, 0)
end

function Index.writeBuf(value: number): buffer
	local buf = buffer.create(4)
	buffer.writeu32(buf, 0, value)
	return buf
end

type Index = typeof(Index) & {}

return Index :: Index
