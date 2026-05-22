local Vide = require("../Vide")
local VideCharm = require("../../../../../Packages/VideCharm")
local accountStore = require("../../../../accounts/client/store")
local fonts = require("../utils/fonts")
local images = require("../images")
local plotStore = require("../..//../../plots/client/store")
local px = require("../utils/px")
local unitStore = require("../../../../units/client/store")
local units = require("../../../../units/client")
local create = Vide.create

return function()
	-- return create("Frame")({

	-- 	AnchorPoint = Vector2.new(0.5, 0.5),
	-- 	Position = UDim2.fromScale(0.5, 0.5),
	-- 	Size = UDim2.fromScale(1, 1),
	-- 	BackgroundTransparency = 1,
	-- 	create("TextLabel")({
	-- 		Text = function()
	-- 			local itemCount = 0
	-- 			for _, v in account().items do
	-- 				itemCount += v.amount
	-- 			end
	-- 			return `CASH: {account().gold}`
	-- 		end,
	-- 		TextSize = 64,
	-- 		AnchorPoint = Vector2.new(0.5, 0.5),
	-- 		Position = UDim2.fromScale(0.5, 0.5),
	-- 	}),
	-- })

	local account = VideCharm.useSignalState(accountStore.getAccount)
	local x = VideCharm.useAtom(unitStore.squadControlModeEnabled)

	return Vide.create("Frame")({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.98),
			Position = function()
				local Position = UDim2.fromScale(0.5, 0.98)
				return Position
			end,

			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,

			create("Frame")({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),

				create("ImageButton")({
					Size = px.offset(64, 64),
					Image = images.Icons.Player,
					ScaleType = Enum.ScaleType.Fit,
					BackgroundTransparency = 1,
					LayoutOrder = 69,
					Activated = function()
						unitStore.squadControlModeEnabled(not unitStore.squadControlModeEnabled())
					end,
				}),
				create("ImageButton")({
					Size = px.offset(64, 64),
					Image = images.Icons.Backpack,
					ScaleType = Enum.ScaleType.Fit,
					BackgroundTransparency = 1,
					LayoutOrder = 69,
					Activated = function()
						plotStore.buildingModeEnabled(not plotStore.buildingModeEnabled())
					end,
				}),
			}),

			Vide.show(x, function()
				return create("TextLabel")({
					TextSize = px(32),
					FontFace = fonts.inter.bold,
					-- Position = UDim2.fromScale(0, 300),
					Position = UDim2.new(0.5, 0, 0.5, -120),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromHex("#FFFFFF"),
					Text = function()
						return `Controlling Squad #1 (x{#units.units})`
					end,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end),
		}),
	})
end
