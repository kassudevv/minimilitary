local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ImageButton = require("../Components/ImageButton")
local Ripple = require("../../../../../Packages/Ripple")
local Vide = require("../Vide")
local VideCharm = require("../../../../../Packages/VideCharm")
local accountStore = require("../../../../accounts/client/store")
local colors = require("../colors")
local fonts = require("../utils/fonts")
local gradient = require("../gradient")
local images = require("../images")
local items = require("../../../../accounts/shared/items")
local store = require("../store")
local usePreferredInput = require("../utils/usePreferredInput")
local waitFor = require("../../../shared/waitFor")
local wrapLabel = require("../utils/wrapLabel")
type Item = items.Item

local Vide = require("../Vide")

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

local auto = Enum.AutomaticSize
local fill = Enum.FillDirection
local hAlign = Enum.HorizontalAlignment
local vAlign = Enum.VerticalAlignment
local sort = Enum.SortOrder
local scale = Enum.ScaleType
local stroke = Enum.StrokeSizingMode
local border = Enum.BorderStrokePosition

function Inventory()
	local getTransition, transitionTween = Ripple.useTween(
		0,
		{
			easing = "quadOut",
			duration = 0.1,
		} :: Ripple.TweenOptions
	)

	effect(function()
		transitionTween:setGoal(store.Main.currentMenu() == "inventory" and 0 or 1080)
	end)

	return create("Frame")({
		Size = fo(1000, 800),
		AnchorPoint = v(0.5, 0.5),
		Position = function()
			return fu(0.5, 0, 0.5, -20 + getTransition())
		end,
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 16),
		}),

		create("Frame")({
			AnchorPoint = v(0.5, 0),
			Position = fs(0.5, 0),
			Size = fu(1, 0, 0, 110),
			BackgroundTransparency = 0,

			create("ImageLabel")({
				BackgroundTransparency = 1,
				Image = images.TilingDots,
				ScaleType = Enum.ScaleType.Tile,
				Size = fs(1, 1),
				TileSize = fo(256, 256),
				ImageTransparency = 0.95,
			}),

			create("UIGradient")({
				Color = gradient.create(colors.sky["200"], colors.blue["500"]),
				Rotation = 90,
			}),

			create("UICorner")({
				CornerRadius = UDim.new(0, 8),
			}),

			create("UIStroke")({
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				Thickness = 0.03,
				Color = colors.slate["950"],
				Transparency = 0,
			}),
			create("UIStroke")({
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Thickness = 0.03,
				Color = colors.slate["50"],
				Transparency = 0.8,
			}),

			ImageButton({
				Position = fu(1, -50, 0.5, 0),
				AnchorPoint = v(1, 0.5),
				Size = fo(100, 100),
				Image = images.CloseButton,
				Activated = function()
					store.Main.currentMenu("")
				end,
			}),

			create("ImageLabel")({
				BackgroundTransparency = 1,
				Image = images.Icons.Backpack,
				ScaleType = Enum.ScaleType.Fit,
				Size = fo(90, 90),
				Position = fu(0, 10, 0.5, 0),
				AnchorPoint = v(0, 0.5),
			}),

			create("TextLabel")({
				Position = fu(0, 110, 0.5, 0),
				AnchorPoint = v(0, 0.5),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				TextColor3 = colors.slate["50"],
				FontFace = fonts.inter.heavy,
				TextSize = 64,
				Text = "Inventory",

				create("UIStroke")({
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					BorderStrokePosition = Enum.BorderStrokePosition.Outer,
					Thickness = 0.05,
					Color = colors.slate["950"],
					Transparency = 0,
				}),
			}),
		}),

		create("Frame")({
			AnchorPoint = v(0.5, 0),
			Position = fs(0.5, 0),
			Size = fu(1, 0, 1, -140),
			BackgroundTransparency = 0,

			create("ImageLabel")({
				BackgroundTransparency = 1,
				Image = images.TilingDots2,
				ScaleType = Enum.ScaleType.Tile,
				Size = fs(1, 1),
				TileSize = fs(0.05, 0.05),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				ImageTransparency = 0.95,
			}),

			create("UIGradient")({
				Color = gradient.create(colors.slate["900"], colors.slate["950"]),
				Rotation = 90,
				Transparency = gradient.transparency(1, 0.5),
			}),

			create("UICorner")({
				CornerRadius = UDim.new(0, 8),
			}),

			create("UIStroke")({
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				Thickness = 0.005,
				Color = colors.slate["950"],
				Transparency = 0,
			}),
			create("UIStroke")({
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Thickness = 0.005,
				Color = colors.slate["50"],
				Transparency = 0.8,
			}),
		}),

		-- BackgroundColor3 = Color3.fromHex("#292929"),

		-- create("UIStroke")({
		-- 	StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		-- 	Thickness = 0.0075,
		-- 	BorderStrokePosition = Enum.BorderStrokePosition.Outer,
		-- 	Color = colors.slate["950"],
		-- }),
		-- create("UIStroke")({
		-- 	StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		-- 	Thickness = 0.005,
		-- 	BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		-- 	Color = colors.slate["50"],
		-- 	Transparency = 0.8,
		-- }),

		-- create("UIListLayout")({
		-- 	FillDirection = Enum.FillDirection.Vertical,
		-- 	HorizontalAlignment = Enum.HorizontalAlignment.Center,
		-- 	VerticalAlignment = Enum.VerticalAlignment.Top,
		-- 	SortOrder = Enum.SortOrder.LayoutOrder,
		-- 	Padding = UDim.new(0, 8),
		-- }),

		-- create("Frame")({
		-- 	Size = fu(1, 0, 0, 0),
		-- 	AutomaticSize = Enum.AutomaticSize.Y,
		-- 	BackgroundTransparency = 0,
		-- 	create("UIGradient")({
		-- 		Color = gradient.create(colors.blue["200"], colors.blue["400"]),
		-- 		Rotation = 90,
		-- 	}),
		-- 	create("UIStroke")({
		-- 		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		-- 		Thickness = 0.05,
		-- 		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		-- 		Color = colors.slate["50"],
		-- 		Transparency = 0.6,
		-- 	}),

		-- 	create("Frame")({
		-- 		Position = fu(0, -30, 0.5, 0),
		-- 		AnchorPoint = v(0, 0.5),
		-- 		AutomaticSize = Enum.AutomaticSize.XY,
		-- 		BackgroundTransparency = 1,

		-- 		create("UIListLayout")({
		-- 			FillDirection = Enum.FillDirection.Horizontal,
		-- 			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		-- 			VerticalAlignment = Enum.VerticalAlignment.Center,
		-- 			SortOrder = Enum.SortOrder.LayoutOrder,
		-- 			Padding = UDim.new(0, 8),
		-- 		}),

		-- 		create("ImageLabel")({
		-- 			Position = fs(0, 0.5),
		-- 			AnchorPoint = v(0, 0.5),
		-- 			Size = fo(100, 100),
		-- 			AutomaticSize = Enum.AutomaticSize.XY,
		-- 			BackgroundTransparency = 1,
		-- 			Image = images.Icons.Backpack,
		-- 		}),
		-- 		create("TextLabel")({
		-- 			Position = fs(0, 0.5),
		-- 			AnchorPoint = v(0, 0.5),
		-- 			AutomaticSize = Enum.AutomaticSize.XY,
		-- 			BackgroundTransparency = 1,
		-- 			TextColor3 = colors.slate["50"],
		-- 			FontFace = fonts.inter.bold,
		-- 			Text = "Inventory",
		-- 			TextSize = 64,
		-- 			create("UIStroke")({
		-- 				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		-- 				Thickness = 0.05,
		-- 				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		-- 				Color = colors.slate["950"],
		-- 				Transparency = 0,
		-- 			}),
		-- 		}),
		-- 	}),
		-- 	ImageButton({
		-- 		Position = fu(1, -20, 0, 20),
		-- 		AnchorPoint = v(1, 0),
		-- 		Size = fo(100, 100),
		-- 		Image = images.CloseButton,
		-- 		Activated = function()
		-- 			store.Main.currentMenu("")
		-- 		end,
		-- 	}),
		-- }),

		--btn
		-- create("Frame")({
		-- 	Size = fu(1, 0, 0, 0),
		-- 	AutomaticSize = Enum.AutomaticSize.Y,
		-- 	BackgroundTransparency = 1,

		-- 	create("Frame")({
		-- 		Position = fs(0.5, 0.5),
		-- 		AnchorPoint = v(0.5, 0.5),
		-- 		Size = fo(300, 110),

		-- 		create("UIGradient")({
		-- 			Color = gradient.create(colors.blue["200"], colors.blue["400"]),
		-- 			Rotation = 90,
		-- 		}),

		-- 		create("UIStroke")({
		-- 			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		-- 			Thickness = 0.04,
		-- 			BorderStrokePosition = Enum.BorderStrokePosition.Outer,
		-- 			Color = colors.slate["950"],
		-- 		}),

		-- 		create("UIStroke")({
		-- 			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		-- 			Thickness = 0.03,
		-- 			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		-- 			Color = colors.white,
		-- 			Transparency = 0.7,
		-- 		}),

		-- 		create("UICorner")({ CornerRadius = UDim.new(0, 16) }),
		-- 	}),
		-- }),
	})
end

return function()
	return show(function()
		return store.Main.currentMenu() == "inventory"
	end, function()
		return Inventory(), 0.333
	end)
end
