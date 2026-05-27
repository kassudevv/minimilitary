local Vide = require("./Vide")
local types = require("./Research/types")

local source = Vide.source
local derive = Vide.derive

return {
	Main = {
		currentMenu = source("research"),
	},
	Inventory = {
		equippedItem = source(""),
		selectedSlot = source(0),
	},
	Research = {
		page = source("main"),
		items = source({}) :: any,

		selected = source(nil) :: any,
	},
}
