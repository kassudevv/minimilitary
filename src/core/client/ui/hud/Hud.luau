local Vide = require("../Vide")
local VideCharm = require("../../../../../Packages/VideCharm")
local accountStore = require("../../../../accounts/client/store")
local images = require("../images")
local objects = require("../../../../accounts/shared/utils/objects")
local plotStore = require("../../../../plots/client/store")
local px = require("../utils/px")

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
	local x = VideCharm.useAtom(plotStore.buildingModeEnabled)

	return Vide.create("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = function()
				local Position = UDim2.fromScale(0.5, 0.98)
				return Position
			end,

			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,

			create("ImageButton")({
				Size = px.offset(32, 32),
				Image = images.Icons.Arrow,
				ScaleType = Enum.ScaleType.Fit,
				BackgroundTransparency = 1,
				Activated = function()
					accountStore.setAccount(objects.join(accountStore.getAccount(), {
						cash = accountStore.getAccount().cash + 100,
					}))
				end,
			}),

			Vide.show(x, function()
				return create("TextLabel")({
					TextSize = px(32),
					-- Position = UDim2.fromScale(0, 300),
					Position = UDim2.new(0.5, 0, 0.5, -40),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromHex("#FFFFFF"),
					Text = function()
						local itemCount = 0
						for _, v in account().items do
							itemCount += v.amount
						end
						return `CASH: {account().cash}`
					end,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end),
		}),
	})
end
