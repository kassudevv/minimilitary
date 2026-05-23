-- src/units/shared/unitIndex.lua
local UnitIndex = {}

local _guidToId: { [string]: number } = {}
local _idToGuid: { [number]: string } = {}
local _counter = 0

function UnitIndex.register(guid: string): number
	if _guidToId[guid] then
		return _guidToId[guid]
	end
	_counter += 1
	_guidToId[guid] = _counter
	_idToGuid[_counter] = guid
	return _counter
end

function UnitIndex.registerExisting(guid: string, id: number)
	_guidToId[guid] = id
	_idToGuid[id] = guid
end

function UnitIndex.unregister(guid: string)
	local id = _guidToId[guid]
	if not id then
		return
	end
	_guidToId[guid] = nil
	_idToGuid[id] = nil
end

function UnitIndex.toId(guid: string): number?
	return _guidToId[guid]
end

function UnitIndex.toGuid(id: number): string?
	return _idToGuid[id]
end

return UnitIndex
