local Ripple = require("../../../../../Packages/Ripple")
local Vide = require("../Vide")
local fonts = require("../utils/fonts")

local create = Vide.create
local changed = Vide.changed

return function(
	props: { Size: UDim2, Icon: string, Activated: (InputObject, number) -> (), Text: string, TextSize: number }
)
	local getSize, sizeTween = Ripple.useTween(
		1,
		{
			easing = "quadOut",
			duration = 0.05,
		} :: Ripple.TweenOptions
	)

	return create("ImageButton")({
		Size = props.Size,
		BackgroundTransparency = 1,
		Image = props.Icon,
		ScaleType = Enum.ScaleType.Fit,

		create("UIScale")({
			Scale = function()
				return getSize()
			end,
		}),

		changed("GuiState", function(state: Enum.GuiState)
			if state == Enum.GuiState.Hover then
				sizeTween:setGoal(1.05)
			elseif state == Enum.GuiState.Press then
				sizeTween:setGoal(0.95)
			else
				sizeTween:setGoal(1)
			end
		end),

		Activated = props.Activated,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),

		create("TextLabel")({
			Name = "Label",
			BackgroundTransparency = 1,
			Text = props.Text or "ROLL",
			TextColor3 = Color3.fromHex("#ffffff"),
			TextSize = props.TextSize or 24,
			AutomaticSize = Enum.AutomaticSize.XY,
			FontFace = fonts.inter.semibold,
			create("UIStroke")({
				Thickness = 4,
				Transparency = 0,
				Color = Color3.fromHex("#000000"),
			}),
		}),
	})
end
