local accountActions = require("../../../../accounts/client/actions")
local accountStore = require("../../../../accounts/client/store")
local colors = require("../colors")
local fonts = require("../utils/fonts")
local gradient = require("../gradient")
local images = require("../images")
local items = require("../../../../accounts/shared/items")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local store = require("../store")
local usePreferredInput = require("../utils/usePreferredInput")
local UserInputService = game:GetService("UserInputService")
local Ripple = require("../../../../../Packages/Ripple")
local Vide = require("../Vide")
local VideCharm = require("../../../../../Packages/VideCharm")
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
local spring = Vide.spring

local fo = UDim2.fromOffset
local fu = UDim2.new
local fs = UDim2.fromScale
local v = Vector2.new

local HOTBAR_BUTTON_SIZE = fo(128, 128)

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local function removeItemFromHotbar(guid: string)
	accountActions.moveItemToHotbar(guid, nil)
end

local function equipItem(item: items.Item)
	task.spawn(function()
		local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
		waitFor.Descendant(char, "Humanoid"):andThen(function(hum: Humanoid)
			if store.Inventory.equippedItem() ~= item.itemId then
				waitFor.Descendant(Players.LocalPlayer.Backpack, item.itemId):andThen(function(tool: Tool)
					hum:EquipTool(tool)
					store.Inventory.equippedItem(item.itemId)
					store.Inventory.selectedSlot(item.hotbar or 0)
					store.Main.currentMenu("")
				end)
			else
				hum:UnequipTools()
				store.Inventory.equippedItem("")
				store.Inventory.selectedSlot(0)
			end
		end)
	end)
end

local function unequipItem()
	task.spawn(function()
		local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
		waitFor.Descendant(char, "Humanoid"):andThen(function(hum: Humanoid)
			hum:UnequipTools()
			store.Inventory.equippedItem("")
			store.Inventory.selectedSlot(0)
		end)
	end)
end

local function toggleMenu(name: string)
	local new = if store.Main.currentMenu() ~= name then name else ""
	if new ~= "" then
		unequipItem()
	end
	store.Main.currentMenu(new)
end

type Binding = { label: string, link: string, icon: string }
local SPECIAL_BINDS: { Binding } = {
	{ label = "Inventory", link = "inventory", icon = images.Icons.Backpack },
	{ label = "Research", link = "research", icon = images.Icons.Research },
	{ label = "Army", link = "army", icon = images.Icons.Army },
}

local function HotbarItem(item: Item, binding: Binding?, i: any)
	local def: items.ItemInfo? = not binding and items.getItem(item.itemId) or nil

	local hovered = source(false)
	local pressed = source(false)

	local equipped = derive(function()
		return (store.Inventory.selectedSlot() == item.hotbar) or (binding and store.Main.currentMenu() == binding.link)
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
		if equipped() or binding and store.Main.currentMenu() == binding.link then
			return colors.slate["50"]
		end

		if hovered() then
			return colors.slate["900"]
		end

		return colors.slate["950"]
	end)

	local backgroundColor = derive(function()
		if equipped() or binding and store.Main.currentMenu() == binding.link then
			return colors.slate["50"]
		end

		if hovered() then
			return colors.slate["900"]
		end

		return colors.slate["950"]
	end)

	local getPreferredInput = usePreferredInput()

	return create("ImageButton")({
		AnchorPoint = v(0.5, 1),

		create("UIScale")({
			Scale = scale,
		}),

		BackgroundTransparency = 0.8,
		BackgroundColor3 = colors.slate["950"],
		LayoutOrder = (item.hotbar or 10) + 10,

		Activated = function()
			if store.Main.currentMenu() == "inventory" and not binding then
				removeItemFromHotbar(i())
				return
			end

			if binding then
				store.Inventory.selectedSlot(0)
				toggleMenu(binding.link)
				return
			end

			if not def then
				return
			end

			store.Main.currentMenu("")
			equipItem(item)
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
			BackgroundColor3 = backgroundColor,

			create("UIGradient")({
				Transparency = gradient.transparency(1, 0.5),
				Rotation = 90,
			}),

			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),

			create("ImageLabel")({
				Size = fs(1, 1),
				BackgroundTransparency = 1,
				Image = def and def.icon or binding and binding.icon or "",
				ScaleType = Enum.ScaleType.Fit,
			}),

			create("TextLabel")({
				Name = "Item",
				AutomaticSize = Enum.AutomaticSize.XY,
				AnchorPoint = binding and v(0.5, 0.5) or v(0.5, 0),
				Position = binding and fs(0.5, 0.5) or fs(0.5, 0.025),
				BackgroundTransparency = 1,
				Text = wrapLabel(def and def.name or binding and binding.label or item.itemId),
				TextColor3 = if binding then colors.slate["50"] else colors.slate["200"],
				TextSize = binding and 30 or 24,
				FontFace = binding and fonts.inter.bold or fonts.inter.semibold,

				create("UIStroke")({
					Color = colors.slate["950"],
					Thickness = binding and 3 or 2,
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
					BackgroundColor3 = colors.slate["950"],
					Size = fo(24, 24),

					create("UIStroke")({
						Color = colors.slate["50"],
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
						TextColor3 = colors.slate["50"],
						TextSize = 20,
						FontFace = fonts.inter.semibold,
					}),
				}),
					0
			end),
		}),
	})
end

local INDEX_TO_KEYCODE = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
	Enum.KeyCode.Zero,
}

return function()
	local accountCharm = VideCharm.useSignalState(accountStore.getAccount)
	local getPreferredInput = usePreferredInput()

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
			items[guid] = item
		end
		return items
	end

	effect(function()
		local preferredInput = getPreferredInput()

		if preferredInput == Enum.PreferredInput.KeyboardAndMouse then
			local conn: RBXScriptConnection
			conn = UserInputService.InputBegan:Connect(function(input, gp)
				if gp then
					return
				end

				for i, kc in INDEX_TO_KEYCODE do
					if input.KeyCode == kc then
						if SPECIAL_BINDS[i] then
							toggleMenu(SPECIAL_BINDS[i].link)
							unequipItem()
						end

						for guid, item in getHotbarItems() do
							if item.hotbar == i then
								store.Main.currentMenu("")
								if store.Inventory.selectedSlot() == item.hotbar then
									unequipItem(item)
									store.Inventory.selectedSlot(0)
								else
									equipItem(item)
									store.Inventory.selectedSlot(i)
								end
								break
							end
						end

						return
					end
				end
			end)

			cleanup(function()
				conn:Disconnect()
			end)
		end
	end)

	local getTransition, transitionTween = Ripple.useTween(
		1080,
		{
			easing = "quadOut",
			duration = 0.15,
		} :: Ripple.TweenOptions
	)
	effect(function()
		transitionTween:setGoal(store.Main.currentMenu() == "research" and 1080 or 0)
	end)

	return create("Frame")({
		AnchorPoint = v(0.5, 1),
		Position = function()
			return fu(0.5, 0, 1, getTransition())
		end,
		Size = fs(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		create("UIGridLayout")({
			CellSize = HOTBAR_BUTTON_SIZE,
			CellPadding = fo(16, 16),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		values(function()
			return SPECIAL_BINDS
		end, function(binding: Binding, i)
			return HotbarItem({
				itemId = binding.label,
				amount = 1,
				hotbar = i(),
			}, binding)
		end),

		values(getHotbarItems, function(item: Item, i)
			return HotbarItem(item, nil, i)
		end),
	})
end
