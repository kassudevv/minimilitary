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
		["774b9d34-083d-4b93-b3e7-755780d3b688"] = { unitId = "apache", assignedSquad = 1 },
		["774b9d34-083d-4b93-b3e7-755780d3b689"] = { unitId = "apache", assignedSquad = 1 },
		["774b9d34-083d-4b93-b3e7-755780d3b687"] = { unitId = "apache", assignedSquad = 1 },
		["774b9d34-083d-4b93-b3e7-755780d3b686"] = { unitId = "apache", assignedSquad = 1 },
		["774b9d34-083d-4b93-b3e7-755780d3b685"] = { unitId = "apache", assignedSquad = 1 },
		["774b9d34-083d-4b93-b3e7-755780d3b684"] = { unitId = "apache", assignedSquad = 1 },
		["774b9d34-083d-4b93-b3e7-755780d3b683"] = { unitId = "apache", assignedSquad = 1 },
	},
	items = {},
}

return {
	accountTemplate = accountTemplate,
}
