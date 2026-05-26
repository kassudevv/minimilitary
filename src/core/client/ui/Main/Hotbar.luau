local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Inventory = require("./Inventory")
local Ripple = require("../../../../../Packages/Ripple")
local Vide = require("../Vide")
local VideCharm = require("../../../../../Packages/VideCharm")
local accountStore = require("../../../../accounts/client/store")
local fonts = require("../utils/fonts")
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

local HOTBAR_BUTTON_SIZE = fo(128, 128)

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local function HotbarItem(item: Item, special: { icon: string, title: string, cb: () -> (), isOpen: any }?)
	local def: items.ItemInfo? = not special and items.getItem(item.itemId) or nil
	local store = store.Inventory

	local hovered = source(false)
	local pressed = source(false)

	local equipped = derive(function()
		return store.equippedItem() == item.itemId
	end)

	local scaleGoal = derive(function()
		if pressed() then
			return 0.92
		end

		if hovered() or equipped() then
			return 1.05
		end

		return 1
	end)
	local scale = spring(scaleGoal, 0.1, 0.8)

	local strokeColor = derive(function()
		if equipped() or special and special.isOpen() then
			return Color3.fromHex("#ffffff")
		end

		if hovered() then
			return Color3.fromHex("#2e2c46")
		end

		return Color3.fromHex("#0d0d15")
	end)

	local getPreferredInput = usePreferredInput()

	return create("ImageButton")({
		AnchorPoint = v(0.5, 1),

		create("UIScale")({
			Scale = scale,
		}),

		BackgroundTransparency = 0.4,
		LayoutOrder = (item.hotbar or 10) + 10,

		Activated = function()
			if special then
				special.cb()
				return
			end
			if not def then
				return
			end
			local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
			waitFor.Descendant(char, "Humanoid"):andThen(function(hum: Humanoid)
				if store.equippedItem() ~= item.itemId then
					waitFor.Descendant(Players.LocalPlayer.Backpack, item.itemId):andThen(function(tool: Tool)
						hum:EquipTool(tool)
						store.equippedItem(item.itemId)
					end)
				else
					hum:UnequipTools()
					store.equippedItem("")
				end
			end)
		end,

		changed("GuiState", function(state: Enum.GuiState)
			if state == Enum.GuiState.Hover then
				hovered(true)
				pressed(false)
			elseif state == Enum.GuiState.Press then
				hovered(true)
				pressed(true)
			else
				hovered(false)
				pressed(false)
			end
		end),

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		create("UIStroke")({
			Color = strokeColor,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.03,
			Transparency = 0,
		}),

		create("Frame")({
			Size = UDim2.fromScale(0.96, 0.96),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromHex("#363636"),

			create("UIGradient")({
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 0.8),
				}),
				Rotation = 90,
			}),

			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),

			create("ImageLabel")({
				Size = fs(1, 1),
				BackgroundTransparency = 1,
				Image = def and "" or special and special.icon or "",
				ScaleType = Enum.ScaleType.Fit,
			}),

			create("TextLabel")({
				Name = "Item",
				AutomaticSize = Enum.AutomaticSize.XY,
				AnchorPoint = special and v(0.5, 0.5) or v(0.5, 0),
				Position = special and fs(0.5, 0.5) or fs(0.5, 0.025),
				BackgroundTransparency = 1,
				Text = wrapLabel(def and def.name or special and special.title or item.itemId),
				TextColor3 = Color3.fromHex("#FFFFFF"),
				TextSize = special and 34 or 24,
				FontFace = special and fonts.inter.bold or fonts.inter.semibold,

				create("UIStroke")({
					Color = Color3.fromHex("#000000"),
					Thickness = special and 3 or 2,
					Transparency = 0,
				}),
			}),

			show(function()
				return getPreferredInput() == Enum.PreferredInput.KeyboardAndMouse
			end, function()
				return create("Frame")({
					Position = fu(0, 8, 1, -8),
					AnchorPoint = v(0, 1),
					BackgroundTransparency = 0.8,
					BackgroundColor3 = Color3.fromHex("#05070e"),
					Size = fo(24, 24),

					create("UIStroke")({
						Color = Color3.fromHex("#ffffff"),
						Thickness = 2,
						Transparency = 0.7,
					}),

					create("UICorner")({ CornerRadius = UDim.new(0, 8) }),

					create("TextLabel")({
						Name = "Item",
						AnchorPoint = v(0.5, 0.5),
						Position = fs(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = `{item and item.hotbar or 0}`,
						TextColor3 = Color3.fromHex("#FFFFFF"),
						TextSize = 20,
						FontFace = special and fonts.inter.bold or fonts.inter.semibold,
					}),
				}),
					0
			end),
		}),
	})
end

return function()
	local accountCharm = VideCharm.useSignalState(accountStore.getAccount)

	local function getHotbarItems(): { [string]: Item }
		local account = accountCharm()
		if not account then
			return {}
		end
		local items: { [string]: Item } = {}
		for guid, item in account.items do
			if not item.hotbar then
				continue
			end
			print("Item:", item)
			items[guid] = item
		end
		return items
	end

	return create("Frame")({
		AnchorPoint = v(0.5, 1),
		Position = fu(0.5, 0, 1, 0),
		Size = fs(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		create("UIGridLayout")({
			CellSize = HOTBAR_BUTTON_SIZE,
			CellPadding = fo(16, 16),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		HotbarItem({
			itemId = "army",
			amount = 1,
			hotbar = 1,
		}, {
			icon = images.Icons.Army,
			title = "Army",
			cb = function()
				store.Main.currentMenu(if store.Main.currentMenu() ~= "army" then "army" else "")
			end,
			isOpen = Vide.derive(function()
				return store.Main.currentMenu() == "army"
			end),
		}),

		HotbarItem({
			itemId = "inventory",
			amount = 1,
			hotbar = 2,
		}, {
			icon = images.Icons.Backpack,
			title = "Inventory",
			cb = function()
				store.Main.currentMenu(if store.Main.currentMenu() ~= "inventory" then "inventory" else "")
			end,
			isOpen = Vide.derive(function()
				return store.Main.currentMenu() == "inventory"
			end),
		}),

		values(getHotbarItems, function(item: Item, i)
			return HotbarItem(item)
		end),
	})
end
