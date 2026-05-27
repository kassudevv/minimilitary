local Main = require("./Main")
local Research = require("./Research")
local Vide = require("./Vide")
local px = require("./utils/px")

function App()
	return Vide.create("ScreenGui")({
		Name = "Gameplay",

		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		Main(),
		Research(),
	})
end

return App
