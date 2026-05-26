local Hotbar = require("./inventory/Hotbar")
local Main = require("./Main")
local Vide = require("./Vide")
local fonts = require("./utils/fonts")
local px = require("./utils/px")

function App()
	px.usePx()

	return Vide.create("ScreenGui")({
		Name = "Gameplay",

		ResetOnSpawn = false,
		IgnoreGuiInset = true,

		Main(),

		-- Hotbar(),

		-- Vide.create("Frame")({
		-- 	Name = "Frame",
		-- 	AnchorPoint = Vector2.new(0.5, 1),
		-- 	Position = UDim2.new(0.5, 0, 1, 50),
		-- 	Size = UDim2.fromOffset(200, 100),
		-- 	BackgroundColor3 = Color3.fromHex("#FFFFFF"),
		-- 	BackgroundTransparency = 1,

		-- 	Vide.create("TextLabel")({
		-- 		TextSize = px(24),
		-- 		FontFace = fonts.inter.bold,
		-- 		-- Position = UDim2.fromScale(0, 300),
		-- 		Position = UDim2.new(0.5, 0, 0.5, -260),
		-- 		AnchorPoint = Vector2.new(0.5, 0.5),
		-- 		TextColor3 = Color3.fromHex("#FFFFFF"),
		-- 		Text = function()
		-- 			return `Controlling Squad #1 `
		-- 		end,
		-- 		TextXAlignment = Enum.TextXAlignment.Center,
		-- 	}),
		-- }),
	})
end

return App
