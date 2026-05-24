local items = require("@game/ReplicatedStorage/src/accounts/shared/items")

export type PlotSnapshot = {
	id: number,
	template: Model,
	area: { [string]: Model },
}

export type BuildingSnapshot = {
	guid: string,
	item: items.ItemInfo,
	data: items.ItemBuildingData,
	model: Model,
}

return {}
