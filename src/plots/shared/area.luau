local conf = require("@game/ReplicatedStorage/src/plots/shared/conf")

local Janitor = require("../../../Packages/Janitor")
local Area = {}
Area.__index = Area
type AreaData = { tiles: { [string]: Model }, janitor: Janitor.Janitor }
export type Area = setmetatable<AreaData, typeof(Area)>
function Area.new()
	local self = setmetatable({} :: AreaData, Area)
	self.tiles = {}
	self.janitor = Janitor.new()
	return self
end

function Area.key(self: Area, col: number, row: number)
	return `{col},{row}}`
end

function Area.isUnlocked(self: Area, col: number, row: number)
	return not self.tiles[self:key(col, row)]
end

function Area.setLocked(self: Area, tbl: { [string]: Model })
	self.tiles = tbl
end
function Area.getLocked(self: Area)
	return self.tiles
end

function Area.lock(self: Area, col: number, row: number, tile: any)
	self.tiles[self:key(col, row)] = tile
	self.janitor:Add(tile)
end

function Area.unlock(self: Area, col: number, row: number)
	local key = self:key(col, row)
	if not self.tiles[key] then
		return
	end
	self.tiles[key]:Destroy()
	self.tiles[key] = nil
end

function Area.cleanup(self: Area)
	self.janitor:Cleanup()
	self.tiles = {}
end
return Area
