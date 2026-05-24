local Hotbar = require("./inventory/Hotbar")
local Vide = require("./Vide")
local px = require("./utils/px")

function App()
	px.usePx()

	return Vide.create("ScreenGui")({
		Name = "Gameplay",

		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		Hotbar(),
	})
end

return App
