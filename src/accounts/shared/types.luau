local items = require("./items")
local types = require("./items/types")

type Item = items.Item
type ItemInfo = types.ItemInfo

export type AccountPlotTile = {
	read x: number,
	read y: number,
}

export type AccountPlotBuilding = {
	read x: number,
	read y: number,
	read rot: number,
	read meta: { [string]: any },
}

export type AccountUnit = {
	read unitId: string,
	read assignedSquad: number,
}

export type Account = {
	read cash: number,
	read plot: {
		read tiles: { AccountPlotTile },
		read buildings: {
			[string]: AccountPlotBuilding,
		},
	},
	read units: { [string]: AccountUnit },
	read items: { [string]: Item },
}

local accountTemplate: Account = {
	cash = 0,
	plot = {
		tiles = {},
		buildings = {},
	},
	units = {
		-- ["774b9d34-083d-4b93-b3e7-755780d3b688"] = { unitId = "gunner", assignedSquad = 1 },
		-- ["774b9d34-083d-4b93-b3e7-755780d3b689"] = { unitId = "gunner", assignedSquad = 1 },
		-- ["774b9d34-083d-4b93-b3e7-755780d3b687"] = { unitId = "tiger1", assignedSquad = 1 },
		-- ["774b9d34-083d-4b93-b3e7-755780d3b686"] = { unitId = "tiger1", assignedSquad = 1 },
		-- ["774b9d34-083d-4b93-b3e7-755780d3b685"] = { unitId = "tiger1", assignedSquad = 1 },
		-- ["774b9d34-083d-4b93-b3e7-755780d3b684"] = { unitId = "tiger1", assignedSquad = 1 },
		-- ["774b9d34-083d-4b93-b3e7-755780d3b683"] = { unitId = "tiger1", assignedSquad = 1 },
	},
	items = {
		["1"] = { amount = 6, itemId = "wheat", hotbar = 6 },
		["2"] = { amount = 1, itemId = "wheat_farm", hotbar = 5 },
		["3"] = { amount = 3, itemId = "housing1", hotbar = 3 },
		["4"] = { amount = 3, itemId = "academy1", hotbar = 4 },
	},
}

return {
	accountTemplate = accountTemplate,
}
