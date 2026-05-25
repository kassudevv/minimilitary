local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Ripple = require("../../../../../Packages/Ripple")
local Vide = require("../Vide")
local VideCharm = require("../../../../../Packages/VideCharm")
local accountStore = require("../../../../accounts/client/store")
local hotbarStore = require("../../stores/hotbar")
local items = require("../../../../accounts/shared/items")
local px = require("../utils/px")
local waitFor = require("../../../shared/waitFor")
local create = Vide.create
type Item = items.Item

local create = Vide.create
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

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

return function()
	local accountCharm = VideCharm.useSignalState(accountStore.getAccount)
	local equippedItem = VideCharm.useAtom(hotbarStore.equippedItem)

	local function getItems(): { [string]: Item }
		local account = accountCharm()
		return if account then account.items else {}
	end

	return Vide.create("Frame")({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = px.offset(800, 100),
		BackgroundTransparency = 1,

		create("UIGridLayout")({
			CellSize = px.offset(100, 100),
			CellPadding = px.offset(16, 16),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.Name,
		}),

		Vide.values(getItems, function(item: Item, i)
			local def = items.getItem(item.itemId)
			return create("ImageButton")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 0.4,

				Activated = function()
					local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
					waitFor.Descendant(char, "Humanoid"):andThen(function(hum: Humanoid)
						if equippedItem() ~= item.itemId then
							waitFor.Descendant(Players.LocalPlayer.Backpack, item.itemId):andThen(function(tool: Tool)
								hum:EquipTool(tool)
								hotbarStore.equippedItem(item.itemId)
							end)
						else
							hum:UnequipTools()
							hotbarStore.equippedItem("")
						end
					end)
				end,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
				create("UIStroke")({
					Color = function()
						return equippedItem() == item.itemId and Color3.fromHex("#ffffff") or Color3.fromHex("#271e1b")
					end,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.03,
					Transparency = 0,
				}),

				create("Frame")({
					Name = i(),
					Size = UDim2.fromScale(0.96, 0.96),
					BackgroundTransparency = 0,
					BackgroundColor3 = Color3.fromHex("#363636"),

					create("UIGradient")({
						-- Color = ColorSequence.new({
						-- 	ColorSequenceKeypoint.new(0, Color3.fromHex("#ffffff")),
						-- 	ColorSequenceKeypoint.new(1, Color3.fromHex("#000000")),
						-- }),
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.2),
							NumberSequenceKeypoint.new(1, 0.6),
						}),
						Rotation = 90,
					}),

					create("UICorner")({ CornerRadius = UDim.new(0, 8) }),

					create("TextLabel")({
						Name = "Item",
						Size = UDim2.fromScale(1, 0),
						Position = UDim2.fromScale(0, 0.1),
						BackgroundTransparency = 1,
						Text = def.name,
						TextColor3 = Color3.fromHex("#FFFFFF"),
						TextSize = px(16),
						Font = Enum.Font.Gotham,

						create("UIStroke")({
							Color = Color3.fromHex("#271e1b"),
							Thickness = px(2),
							Transparency = 0,
						}),
					}),
				}),
			})
		end),
	})
end

-- local Vide = require("../Vide")
-- local fonts = require("../utils/fonts")
-- local images = require("../images")
-- local plotStore = require("../../../../plots/client/store")
-- local px = require("../utils/px")
-- local unitStore = require("../../../../units/client/store")
-- local create = Vide.create

-- return function()
-- 	-- local account = VideCharm.useSignalState(accountStore.getAccount)
-- 	-- local x = VideCharm.useAtom(unitStore.squadControlModeEnabled)

-- 	return Vide.create("Frame")({
-- 		AnchorPoint = Vector2.new(0.5, 1),
-- 		Position = UDim2.fromScale(0.5, 1),
-- 		Size = UDim2.fromScale(1, 1),
-- 		BackgroundTransparency = 1,

-- 		create("Frame")({
-- 			AnchorPoint = Vector2.new(0.5, 0.98),
-- 			Position = function()
-- 				local Position = UDim2.fromScale(0.5, 0.98)
-- 				return Position
-- 			end,

-- 			BackgroundTransparency = 1,
-- 			AutomaticSize = Enum.AutomaticSize.XY,

-- 			create("Frame")({
-- 				AnchorPoint = Vector2.new(0.5, 1),
-- 				Position = UDim2.fromScale(0.5, 1),
-- 				BackgroundTransparency = 1,
-- 				AutomaticSize = Enum.AutomaticSize.XY,

-- 				create("UIListLayout")({
-- 					FillDirection = Enum.FillDirection.Horizontal,
-- 					HorizontalAlignment = Enum.HorizontalAlignment.Center,
-- 					VerticalAlignment = Enum.VerticalAlignment.Center,
-- 					SortOrder = Enum.SortOrder.LayoutOrder,
-- 					Padding = UDim.new(0, 8),
-- 				}),

-- 				create("ImageButton")({
-- 					Size = px.offset(64, 64),
-- 					Image = images.Icons.Player,
-- 					ScaleType = Enum.ScaleType.Fit,
-- 					BackgroundTransparency = 1,
-- 					LayoutOrder = 69,
-- 					Activated = function()
-- 						unitStore.movementMode(not unitStore.movementMode())
-- 					end,
-- 				}),
-- 				create("ImageButton")({
-- 					Size = px.offset(64, 64),
-- 					Image = images.Icons.Backpack,
-- 					ScaleType = Enum.ScaleType.Fit,
-- 					BackgroundTransparency = 1,
-- 					LayoutOrder = 69,
-- 					Activated = function()
-- 						plotStore.buildingModeEnabled(not plotStore.buildingModeEnabled())
-- 					end,
-- 				}),
-- 			}),

-- 			Vide.show(function()
-- 				return false
-- 			end, function()
-- 				return create("TextLabel")({
-- 					TextSize = px(32),
-- 					FontFace = fonts.inter.bold,
-- 					-- Position = UDim2.fromScale(0, 300),
-- 					Position = UDim2.new(0.5, 0, 0.5, -120),
-- 					AnchorPoint = Vector2.new(0.5, 0.5),
-- 					TextColor3 = Color3.fromHex("#FFFFFF"),
-- 					Text = function()
-- 						return `Controlling Squad #1 `
-- 					end,
-- 					TextXAlignment = Enum.TextXAlignment.Center,
-- 				})
-- 			end),
-- 		}),
-- 	})
-- end
