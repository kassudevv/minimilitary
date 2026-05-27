local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local UpgradeConfig = require(script.Parent.UpgradeConfig)
local Vide = require("../Vide")
local fonts = require("../utils/fonts")
local images = require("../images")
local store = require("../store")
local types = require("./types")
local upgradeTreeUtil = require("./upgradeTreeUtil")
local useTransparency = require("../utils/useTransparency")

local source = Vide.source
local create = Vide.create
local show = Vide.show
local effect = Vide.effect
local cleanup = Vide.cleanup
local derive = Vide.derive
local values = Vide.values
local changed = Vide.changed

local fo = UDim2.fromOffset
local fu = UDim2.new
local fs = UDim2.fromScale
local v = Vector2.new

local SPACING = -4

function Tooltip(node: types.RuntimeNode)
	return create("Frame")({
		AnchorPoint = Vector2.new(0, 0.5),
		Size = fo(300, 200),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = UDim2.new(1, 12, 0.5, 0),
		BackgroundTransparency = 1,

		create("ImageLabel")({
			Image = images.ContainerBG,
			-- AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.XY,

			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(16, 23, 240, 233),

			create("UIPadding")({}),

			create("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			create("TextLabel")({
				Text = string.upper(node.Data.Label),
				Name = "Text",
				FontFace = fonts.inter.semibold,
				TextColor3 = Color3.fromHex("#ffffff"),
				BackgroundTransparency = 1,
				TextTransparency = 0,
				TextScaled = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				TextSize = 40,
				TextWrapped = false,
				create("UIStroke")({
					Thickness = 4,
					Transparency = 0,
					Color = Color3.fromHex("#000000"),
				}),
				create("UIPadding")({
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 32),
					PaddingRight = UDim.new(0, 32),
				}),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),

			create("TextLabel")({
				Text = node.Data.Description,
				Name = "Text",
				FontFace = fonts.inter.semibold,
				TextColor3 = Color3.fromHex("#ffffff"),
				BackgroundTransparency = 1,
				TextTransparency = 0,
				TextScaled = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				TextSize = 32,
				TextWrapped = false,
				create("UIStroke")({
					Thickness = 4,
					Transparency = 0,
					Color = Color3.fromHex("#000000"),
				}),
				create("UIPadding")({
					PaddingTop = UDim.new(0, 16),
					PaddingBottom = UDim.new(0, 16),
					PaddingLeft = UDim.new(0, 32),
					PaddingRight = UDim.new(0, 32),
				}),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),

			create("TextLabel")({
				Text = "OWNED",
				Name = "Text",
				FontFace = fonts.inter.semibold,
				TextColor3 = Color3.fromHex("#9dffab"),
				BackgroundTransparency = 1,
				TextTransparency = 0,
				TextScaled = false,
				AutomaticSize = Enum.AutomaticSize.XY,
				TextSize = 32,
				TextWrapped = false,
				create("UIStroke")({
					Thickness = 4,
					Transparency = 0,
					Color = Color3.fromHex("#000000"),
				}),
				create("UIPadding")({
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 32),
					PaddingRight = UDim.new(0, 32),
				}),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),
		}),
	})
end

type Variant = "redirect" | "locked" | "owned" | "hidden"

return function(node: types.RuntimeNode, width: Vide.Source<number>)
	local visible = source(false)
	local hovered = source(false)
	local pressed = source(false)

	task.delay(node.Depth * 0.1, function()
		visible(true)
	end)

	local getScale, scaleTween = Ripple.useTween(
		0,
		{
			easing = "quadOut",
			duration = 0.05,
		} :: Ripple.TweenOptions
	)

	local getTransition, transitionTween = Ripple.useTween(
		0,
		{
			easing = "quadOut",
			duration = 0.1,
		} :: Ripple.TweenOptions
	)
	effect(function()
		transitionTween:setGoal(store.Main.currentMenu() == "research" and visible() and 1 or 0)
	end)

	local variant: Variant = node.Data.RedirectsToPage and "redirect" or "owned"
	local hexbg = variant == "redirect" and images.HexSpecial or images.HexBG
	hexbg = node.Data.IsBackButton and images.HexRed or hexbg
	hexbg = node.Data.Label == "Bonus Chance" and images.HexLocked or hexbg

	-- fix losing focus sometimes
	effect(function()
		if hovered() and store.Research.selected() == nil then
			store.Research.selected(node)
		end
	end)

	effect(function()
		if pressed() then
			scaleTween:setGoal(0.95)
		elseif store.Research.selected() == node then
			scaleTween:setGoal(1.1)
		else
			scaleTween:setGoal(1)
		end
	end)

	return show(visible, function()
		return create("ImageButton")({
			ZIndex = function()
				return store.Research.selected() and store.Research.selected() == node and 67 or 0
			end,

			BackgroundTransparency = 1,
			Image = hexbg,
			AnchorPoint = Vector2.new(0.5, 0.5),

			Position = function()
				local size = width() / 2 + SPACING
				local x = 3 / 2 * node.GridPosition.X
				local y = math.sqrt(3) / 2 * node.GridPosition.Y
				x = x * size
				y = y * size
				return fo(x, y)
			end,
			Size = function()
				local w = width()

				local roll = getTransition()
				local scale = getScale()

				local size = math.lerp(0, 1, roll) * scale

				return fo(w * size, w * size)
			end,
			ImageTransparency = useTransparency(0, getTransition()),

			Activated = function()
				if variant == "redirect" then
					upgradeTreeUtil.upgradeTreeSetPage(node.Data.RedirectsToPage or "Main")
				end
			end,

			changed("GuiState", function(state: Enum.GuiState)
				if state == Enum.GuiState.Hover then
					hovered(true)
					pressed(false)
					store.Research.selected(node)
				elseif state == Enum.GuiState.Press then
					hovered(true)
					pressed(true)
					store.Research.selected(node)
				else
					hovered(false)
					pressed(false)

					local existing = store.Research.selected()
					if existing and existing.Id == node.Id then
						store.Research.selected(nil)
					end
				end
			end),

			create("UIAspectRatioConstraint")({
				AspectRatio = 1.155,
			}),

			create("ImageLabel")({
				Name = "Image",
				Size = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = node.Data.Icon or images.Icons.Luck,
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),

			create("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromHex("#FFFFFF"),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					Padding = UDim.new(0, 2),
				}),
				create("UIPadding")({
					PaddingTop = UDim.new(0, 0),
					PaddingBottom = UDim.new(0, 32),
					PaddingLeft = UDim.new(0, 0),
					PaddingRight = UDim.new(0, 0),
				}),

				create("TextLabel")({
					Name = "Label",
					BackgroundTransparency = 1,
					Text = node.Data.Label,
					TextColor3 = Color3.fromHex("#FFFFFF"),
					TextSize = function()
						local w = width()
						local h = getScale()
						local b = 1 - getTransition()
						local scale = math.lerp(1, 1.1, h)

						return (w / 8) * scale * (1 - b)
					end,
					AutomaticSize = Enum.AutomaticSize.XY,
					FontFace = fonts.fredoka.regular,
					create("UIStroke")({
						Thickness = 2,
						Transparency = 0,
						Color = Color3.fromHex("#000000"),
					}),
				}),
				variant == "redirect" and create("TextLabel")({
					Name = "Label",
					BackgroundTransparency = 1,
					Text = node.Data.IsBackButton and "Back" or "Open",
					TextColor3 = Color3.fromHex("#ffe138"),
					TextSize = function()
						local w = width()
						local h = getScale()
						local b = 1 - getTransition()
						local scale = math.lerp(1, 1.1, h)

						return (w / 7) * scale * (1 - b)
					end,
					AutomaticSize = Enum.AutomaticSize.XY,
					FontFace = fonts.fredoka.regular,
					create("UIStroke")({
						Thickness = 2,
						Transparency = 0,
						Color = Color3.fromHex("#000000"),
					}),
				}),
			}),

			show(function()
				if
					store.Research.selected() ~= nil
					and store.Research.selected().Id == node.Id
					and not store.Research.selected().RedirectsToPage
				then
					return true
				else
					return false
				end
			end, function()
				return Tooltip(node)
			end),
		})
	end)

	-- return create("ImageButton")({
	-- 	ZIndex = function()
	-- 		return appStore.upgradeTreeSelectedOption() and appStore.upgradeTreeSelectedOption() == node and 67 or 0
	-- 	end,

	-- 	BackgroundTransparency = 1,
	-- 	Image = hexbg,
	-- 	AnchorPoint = Vector2.new(0.5, 0.5),

	-- 	Position = function()
	-- 		local size = width() / 2 + SPACING
	-- 		local x = 3 / 2 * node.GridPosition.X
	-- 		local y = math.sqrt(3) / 2 * node.GridPosition.Y
	-- 		x = x * size
	-- 		y = y * size
	-- 		return px.offset(x, y)()
	-- 	end,
	-- 	Size = function()
	-- 		local w = width()

	-- 		local roll = getTransition()
	-- 		local scale = getScale()

	-- 		local size = math.lerp(0, 1, roll) * scale

	-- 		return px.offset(w * size, w * size)()
	-- 	end,
	-- 	ImageTransparency = useTransparency(0, getTransition()),

	-- 	Activated = function()
	-- 		if variant == "redirect" then
	-- 			appStore.upgradeTreeSetPage(node.Data.RedirectsToPage or "Main")
	-- 		end
	-- 	end,

	-- 	changed("GuiState", function(state: Enum.GuiState)
	-- 		if state == Enum.GuiState.Hover then
	-- 			appStore.upgradeTreeSelectedOption(node)
	-- 			scaleTween:setGoal(1.1)
	-- 		elseif state == Enum.GuiState.Press then
	-- 			scaleTween:setGoal(0.95)
	-- 		else
	-- 			scaleTween:setGoal(1)

	-- 			local existing = appStore.upgradeTreeSelectedOption()
	-- 			if existing and existing.Id == node.Id then
	-- 				appStore.upgradeTreeSelectedOption(nil)
	-- 			end
	-- 		end
	-- 	end),

	-- 	create("UIAspectRatioConstraint")({
	-- 		AspectRatio = 1.155,
	-- 	}),

	-- 	create("ImageLabel")({
	-- 		Name = "Image",
	-- 		Size = UDim2.fromScale(0.8, 0.8),
	-- 		BackgroundTransparency = 1,
	-- 		Image = node.Data.Icon or images.IconLuck,
	-- 		ScaleType = Enum.ScaleType.Fit,
	-- 		AnchorPoint = Vector2.new(0.5, 0.5),
	-- 		Position = UDim2.fromScale(0.5, 0.5),
	-- 	}),

	-- 	create("Frame")({
	-- 		AnchorPoint = Vector2.new(0.5, 0.5),
	-- 		Position = UDim2.fromScale(0.5, 0.5),
	-- 		Size = UDim2.fromScale(1, 1),
	-- 		BackgroundColor3 = Color3.fromHex("#FFFFFF"),
	-- 		BackgroundTransparency = 1,
	-- 		create("UIListLayout")({
	-- 			HorizontalAlignment = Enum.HorizontalAlignment.Center,
	-- 			VerticalAlignment = Enum.VerticalAlignment.Bottom,
	-- 			Padding = UDim.new(0, 2),
	-- 		}),
	-- 		create("UIPadding")({
	-- 			PaddingTop = UDim.new(0, 0),
	-- 			PaddingBottom = px.udim(0, 32),
	-- 			PaddingLeft = UDim.new(0, 0),
	-- 			PaddingRight = UDim.new(0, 0),
	-- 		}),

	-- 		create("TextLabel")({
	-- 			Name = "Label",
	-- 			BackgroundTransparency = 1,
	-- 			Text = node.Data.Label,
	-- 			TextColor3 = Color3.fromHex("#FFFFFF"),
	-- 			TextSize = function()
	-- 				local w = width()
	-- 				local h = getScale()
	-- 				local b = 1 - getTransition()
	-- 				local scale = math.lerp(1, 1.1, h)

	-- 				return (w / 4) * scale * (1 - b)
	-- 			end,
	-- 			AutomaticSize = Enum.AutomaticSize.XY,
	-- 			FontFace = fonts.fredoka.regular,
	-- 			create("UIStroke")({
	-- 				Thickness = px.scale(2),
	-- 				Transparency = 0,
	-- 				Color = Color3.fromHex("#000000"),
	-- 			}),
	-- 		}),
	-- 		variant == "redirect" and create("TextLabel")({
	-- 			Name = "Label",
	-- 			BackgroundTransparency = 1,
	-- 			Text = node.Data.IsBackButton and "Back" or "Open",
	-- 			TextColor3 = Color3.fromHex("#ffe138"),
	-- 			TextSize = function()
	-- 				local w = width()
	-- 				local h = getScale()
	-- 				local b = 1 - getTransition()
	-- 				local scale = math.lerp(1, 1.1, h)

	-- 				return (w / 6) * scale * (1 - b)
	-- 			end,
	-- 			AutomaticSize = Enum.AutomaticSize.XY,
	-- 			FontFace = fonts.fredoka.regular,
	-- 			create("UIStroke")({
	-- 				Thickness = px.scale(2),
	-- 				Transparency = 0,
	-- 				Color = Color3.fromHex("#000000"),
	-- 			}),
	-- 		}),

	-- 		-- TextSize = function()
	-- 		-- 	local w = width()
	-- 		-- 	local h = hoverScale()
	-- 		-- 	local b = transparency()
	-- 		-- 	local scale = math.lerp(1, 1.1, h)

	-- 		-- 	return (w / 6) * scale * (1 - b)
	-- 		-- end,
	-- 	}),

	-- 	show(function()
	-- 		return appStore.upgradeTreeSelectedOption() and appStore.upgradeTreeSelectedOption().Id == node.Id
	-- 	end, function()
	-- 		if node.Data.RedirectsToPage ~= nil then
	-- 			return nil
	-- 		end
	-- 		return Tooltip(node)
	-- 	end),
	-- })
end
