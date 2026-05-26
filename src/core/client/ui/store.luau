local Vide = require("./Vide")

local source = Vide.source
local derive = Vide.derive

return {
	Main = {
		currentMenu = source("inventory"),
	},
	Inventory = {
		equippedItem = source(""),
	},
}
