local AutoScaledFrame = require("./utils/AutoScaledFrame")
local Hotbar = require("@self/Hotbar")
local IconButton = require("./Components/IconButton")
local Inventory = require("@self/Inventory")
local Ripple = require("../../../../Packages/Ripple")
local Vide = require("./Vide")
local fonts = require("./utils/fonts")
local images = require("./images")

local create = Vide.create
local changed = Vide.changed
local source = Vide.source
local derive = Vide.derive
local effect = Vide.effect
local cleanup = Vide.cleanup
local show = Vide.show
local values = Vide.values
local indexes = Vide.indexes
local spring = Vide.spring
local mount = Vide.mount
local batch = Vide.batch

local fo = UDim2.fromOffset
local fu = UDim2.new
local fs = UDim2.fromScale
local v = Vector2.new

local UI_PADDING = 50
return function()
	return AutoScaledFrame({
		Size = fo(1920 - UI_PADDING, 1080 - UI_PADDING),
		Position = fs(0.5, 0.5),
		AnchorPoint = v(0.5, 0.5),
		Name = "Main",
		Children = {
			Hotbar(),
			Inventory(),
			-- create("Frame")({
			-- 	Position = fs(0, 0.5),
			-- 	AnchorPoint = v(0, 0.5),
			-- 	BackgroundTransparency = 1,
			-- 	AutomaticSize = Enum.AutomaticSize.XY,

			-- 	create("UIListLayout")({
			-- 		FillDirection = Enum.FillDirection.Vertical,
			-- 		HorizontalAlignment = Enum.HorizontalAlignment.Left,
			-- 		VerticalAlignment = Enum.VerticalAlignment.Center,
			-- 		SortOrder = Enum.SortOrder.LayoutOrder,
			-- 		Padding = UDim.new(0, 16),
			-- 	}),

			-- 	IconButton({
			-- 		Text = "RESEARCH",
			-- 		TextSize = 24,
			-- 		Size = fo(80, 80),
			-- 		Icon = images.Icons.Research,
			-- 		Activated = function(a, b) end,
			-- 	}),

			-- 	IconButton({
			-- 		Text = "RESEARCH",
			-- 		TextSize = 24,
			-- 		Size = fo(80, 80),
			-- 		Icon = images.Icons.Research,
			-- 		Activated = function(a, b) end,
			-- 	}),

			-- 	IconButton({
			-- 		Text = "RESEARCH",
			-- 		TextSize = 24,
			-- 		Size = fo(80, 80),
			-- 		Icon = images.Icons.Research,
			-- 		Activated = function(a, b) end,
			-- 	}),
			-- }),

			-- create("Frame")({
			-- 	Position = fu(0.5, 0, 1, 0),
			-- 	AnchorPoint = v(0.5, 1),
			-- 	BackgroundTransparency = 1,
			-- 	AutomaticSize = Enum.AutomaticSize.XY,

			-- 	create("UIListLayout")({
			-- 		FillDirection = Enum.FillDirection.Horizontal,
			-- 		HorizontalAlignment = Enum.HorizontalAlignment.Center,
			-- 		VerticalAlignment = Enum.VerticalAlignment.Bottom,
			-- 		SortOrder = Enum.SortOrder.LayoutOrder,
			-- 		Padding = UDim.new(0, 8),
			-- 	}),

			-- 	IconButton({
			-- 		Text = "RESEARCH",
			-- 		TextSize = 24,
			-- 		Size = fo(120, 120),
			-- 		Icon = images.Icons.Research,
			-- 		Activated = function(a, b) end,
			-- 	}),

			-- 	IconButton({
			-- 		Text = "ARMY",
			-- 		TextSize = 32,
			-- 		Size = fo(160, 160),
			-- 		Icon = images.Icons.Army,
			-- 		Activated = function(a, b) end,
			-- 	}),

			-- 	IconButton({
			-- 		Text = "OIL",
			-- 		TextSize = 24,
			-- 		Size = fo(120, 120),
			-- 		Icon = images.Icons.Oil,
			-- 		Activated = function(a, b) end,
			-- 	}),
			-- }),
		},
	})
end
