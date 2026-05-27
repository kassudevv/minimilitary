local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ImageButton = require("../Components/ImageButton")
local Ripple = require("../../../../../Packages/Ripple")
local VideCharm = require("../../../../../Packages/VideCharm")
local accountActions = require("../../../../accounts/client/actions")
local accountStore = require("../../../../accounts/client/store")
local colors = require("../colors")
local fonts = require("../utils/fonts")
local gradient = require("../gradient")
local images = require("../images")
local items = require("../../../../accounts/shared/items")
local store = require("../store")
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

local function InventoryItem(item: Item, i: any, props: { moveItemToHotbar: (string) -> () })
	local def: items.ItemInfo = items.getItem(item.itemId)

	local hovered = source(false)
	local pressed = source(false)

	local equipped = derive(function()
		return store.Inventory.equippedItem() == item.itemId
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
		if equipped() then
			return colors.slate["50"]
		end

		if hovered() then
			return colors.slate["900"]
		end

		return colors.slate["950"]
	end)

	local backgroundColor = derive(function()
		if equipped() then
			return colors.slate["50"]
		end

		if hovered() then
			return colors.slate["900"]
		end

		return colors.slate["950"]
	end)

	return create("ImageButton")({
		AnchorPoint = v(0.5, 0.5),
		Position = fs(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = fs(1, 1),

		create("UIScale")({
			Scale = scale,
		}),

		BackgroundTransparency = 0.8,
		BackgroundColor3 = colors.slate["950"],
		LayoutOrder = (item.hotbar or 10) + 10,

		Activated = function()
			props.moveItemToHotbar(i())
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
				Image = def.icon or "",
				ScaleType = Enum.ScaleType.Fit,
			}),

			create("TextLabel")({
				Name = "Item",
				AutomaticSize = Enum.AutomaticSize.XY,
				AnchorPoint = v(0.5, 0),
				Position = fs(0.5, 0.025),
				BackgroundTransparency = 1,
				Text = wrapLabel(def.name),
				TextColor3 = colors.slate["200"],
				TextSize = 24,
				FontFace = fonts.inter.semibold,

				create("UIStroke")({
					Color = colors.slate["950"],
					Thickness = 2,
					Transparency = 0,
				}),
			}),

			create("TextLabel")({
				AnchorPoint = v(0, 1),
				Position = fs(0, 1),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				TextColor3 = colors.slate["400"],
				FontFace = fonts.inter.semibold,
				TextSize = 22,
				Text = `x{item.amount}`,
			}),
		}),
	})
end

function Inventory()
	local getTransition, transitionTween = Ripple.useTween(
		1080,
		{
			easing = "quadOut",
			duration = 0.15,
		} :: Ripple.TweenOptions
	)
	effect(function()
		transitionTween:setGoal(store.Main.currentMenu() == "inventory" and 0 or 1080)
	end)

	local accountCharm = VideCharm.useSignalState(accountStore.getAccount)

	local function getInventoryItems(): { [string]: Item }
		local account = accountCharm()
		if not account then
			return {}
		end
		local items: { [string]: Item } = {}
		for guid, item in account.items do
			if item.hotbar then
				continue
			end
			items[guid] = item
		end
		return items
	end

	local function moveItemToHotbar(guid: string)
		local takenSlots = {}

		local account = accountCharm()
		for guid, item in account and account.items or {} do
			if item.hotbar then
				takenSlots[item.hotbar] = true
			end
		end

		for i = 4, 9 do
			if not takenSlots[i] then
				accountActions.moveItemToHotbar(guid, i)
				return
			end
		end
	end

	return create("Frame")({
		Size = fo(1200, 700),
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
				TileSize = fo(400, 400),
				ImageTransparency = 0.9,
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
					Thickness = 0.1,
					Color = colors.slate["950"],
					Transparency = 0,
				}),
			}),
		}),

		create("Frame")({
			AnchorPoint = v(0.5, 0),
			Position = fs(0.5, 0),
			Size = fu(1, 0, 1, -150),
			BackgroundTransparency = 0,

			-- container base
			create("ImageLabel")({
				BackgroundTransparency = 1,
				Image = images.TilingDots2,
				ScaleType = Enum.ScaleType.Tile,
				Size = fs(1, 1),
				TileSize = fo(64, 64),
				SizeConstraint = Enum.SizeConstraint.RelativeXY,
				ImageTransparency = 0.97,
				ImageColor3 = colors.slate["50"],
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

			create("ScrollingFrame")({
				create("UIPadding")({
					PaddingTop = UDim.new(0, 16),
					PaddingBottom = UDim.new(0, 16),
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
				}),

				SizeConstraint = Enum.SizeConstraint.RelativeXY,

				Size = fu(1, 0, 1, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = fu(1, -20, 1, 0),

				Name = "GridHoold",
				AnchorPoint = v(0.5, 0),
				Position = fs(0.5, 0),
				BackgroundTransparency = 1,

				create("UIGridLayout")({
					CellPadding = fo(16, 16),
					CellSize = fo(130, 130),
				}),

				values(getInventoryItems, function(item: Item, i)
					return InventoryItem(item, i, { moveItemToHotbar = moveItemToHotbar })
				end),
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
