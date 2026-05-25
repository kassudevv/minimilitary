local Squash = require("../../../Packages/Squash")
local Index = {
	_counter = 0,
	guidToId = {},
	idToGuid = {},
}

function Index.registerNew(guid: string): number
	Index._counter += 1

	if Index._counter > 9.2 * 10 ^ 18 then
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

function Index.get(num: number): string
	return Index.idToGuid[num]
end

function Index.des(buf: buffer): number
	local cursor = Squash.frombuffer(buf)
	return Squash.vlq().des(cursor)
	-- return buffer.readu32(buf, 0)
end

function Index.ser(value: number): buffer
	local cursor = Squash.cursor()
	Squash.vlq().ser(cursor, value)
	return Squash.tobuffer(cursor)
	-- local buf = buffer.create(4)
	-- buffer.writeu32(buf, 0, value)
	-- return buf
end

type Index = typeof(Index) & {}

return Index :: Index
