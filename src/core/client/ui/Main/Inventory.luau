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
		Size = fo(1000, 700),
		AnchorPoint = v(0.5, 0.5),
		Position = function()
			return fu(0.5, 0, 0.5, getTransition())
		end,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromHex("#292929"),

		create("UIGradient")({
			Color = gradient.create(colors.slate["50"], colors.slate["300"]),
			Rotation = 90,
		}),

		create("UIStroke")({
			Color = colors.black,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.01,
			Transparency = 0,
		}),

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),

		create("Frame")({
			Size = fu(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			ImageButton({
				Position = fu(1, -20, 0, 20),
				AnchorPoint = v(1, 0),
				Size = fo(100, 100),
				Image = images.CloseButton,
				Activated = function()
					store.Main.currentMenu("")
				end,
			}),
		}),
	})
end

return function()
	return show(function()
		return store.Main.currentMenu() == "inventory"
	end, function()
		return Inventory(), 0.333
	end)
end
