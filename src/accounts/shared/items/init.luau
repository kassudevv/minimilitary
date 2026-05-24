local constants = require("@self/constants")
local types = require("@self/types")

export type Item = types.Item
export type ItemInfo = types.ItemInfo
export type ItemCropData = types.ItemCropData
export type ItemBuildingData = types.ItemBuildingData
local function stringifyItem(item: Item): string
	local tokens: { string } = {}

	table.insert(tokens, constants.getItem(item.itemId).name)

	return table.concat(tokens, "")
end

local function getItemValue(item: Item): number
	local info = constants.getItem(item.itemId)
	return info.type == "Crop" and 69 or 0
end

return {
	itemsById = constants.itemsById,
	getItem = constants.getItem,
	stringifyItem = stringifyItem,
	getItemValue = getItemValue,
}
