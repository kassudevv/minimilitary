export type ItemCropData = {
	read value: number,
}

export type ItemBuildingData = {
	read size: Vector2,
	read model: Model,
}

export type ItemInfo = {
	read type: "Crop" | "Building",
	read name: string,
	read icon: string,
	read data: ItemCropData | ItemBuildingData | nil,
}

export type Item = {
	read itemId: string,
	read amount: number,
	read hotbar: number?,
}

return {}
