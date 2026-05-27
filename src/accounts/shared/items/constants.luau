local ReplicatedStorage = game:GetService("ReplicatedStorage")
local images = require("../../../core/client/ui/images")
local types = require("./types")

type ItemInfo = types.ItemInfo
type ItemCropData = types.ItemCropData
type ItemBuildingData = types.ItemBuildingData

local itemsById: { [string]: ItemInfo } = {
	-- Crops
	wheat = {
		name = "Wheat",
		type = "Crop",
		icon = images.Icons.DiceGold,
		data = {
			value = 10,
		} :: ItemCropData,
	},
	-- Factories
	wheat_farm = {
		name = "Wheat Farm",
		type = "Building",
		icon = "",
		data = {
			size = Vector2.new(4, 4),
		} :: ItemBuildingData,
	},
	-- Housing
	housing1 = {
		name = "Housing I",
		type = "Building",
		icon = "",

		data = {
			size = Vector2.new(8, 8),
		} :: ItemBuildingData,
	},
	-- Units
	academy1 = {
		name = "Academy I",
		type = "Building",
		icon = images.Icons.Dice,

		data = {
			size = Vector2.new(16, 16),
			model = ReplicatedStorage.Buildings.barracks1,
		} :: ItemBuildingData,
	},
}

local function getItem(itemId: string): ItemInfo
	-- assert(itemsById[itemId], `itemId {itemId} is missing`)
	return itemsById[itemId]
end

return {
	itemsById = itemsById,
	getItem = getItem,
}
