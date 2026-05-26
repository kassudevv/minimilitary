local Main = require("./Main")
local Vide = require("./Vide")
local px = require("./utils/px")

function App()
	px.usePx()

	return Vide.create("ScreenGui")({
		Name = "Gameplay",

		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		Main(),
	})
end

return App
