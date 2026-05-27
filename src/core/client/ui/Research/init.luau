local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ImageButton = require("./Components/ImageButton")
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local UpgradeNode = require(script.UpgradeNode)
local Vide = require("./Vide")
local colors = require("./colors")
local fonts = require("./utils/fonts")
local gradient = require("./gradient")
local images = require("./images")
local store = require("./store")
local upgradeTreeUtil = require("@self/upgradeTreeUtil")
local useInstance = require("./utils/useInstance")
local useSpringFrom = require("./utils/useSpringFrom")
local useTransparency = require("./utils/useTransparency")

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

function CloseButton()
	local hovered = source(false)
	local pressed = source(false)

	local scaleGoal = derive(function()
		if pressed() then
			return 0.92
		end

		if hovered() then
			return 1.2
		end

		return 1
	end)
	local scale = spring(scaleGoal, 0.1, 0.8)

	return create("ImageButton")({
		Size = fo(150, 64),
		AnchorPoint = v(0.5, 0.5),
		Position = fu(0.5, 0, 1, -60),
		ZIndex = 1,

		create("UIScale")({
			Scale = scale,
		}),

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

		Activated = function()
			store.Main.currentMenu("")
		end,

		create("UICorner")({
			CornerRadius = UDim.new(0, 16),
		}),

		create("UIGradient")({
			Color = gradient.create(colors.blue["200"], colors.blue["400"]),
			Rotation = 90,
		}),

		create("UIStroke")({
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			BorderStrokePosition = Enum.BorderStrokePosition.Outer,
			Thickness = 0.1,
			Color = colors.slate["950"],
			Transparency = 0,
		}),

		create("UIStroke")({
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Thickness = 0.07,
			Color = colors.slate["50"],
			Transparency = 0.7,
		}),

		create("TextLabel")({
			AnchorPoint = v(0.5, 0.5),
			Position = fs(0.5, 0.5),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			TextColor3 = colors.slate["50"],
			FontFace = fonts.inter.semibold,
			TextSize = 40,
			Text = "Close",

			create("UIStroke")({
				Color = colors.slate["950"],
				Thickness = 2,
				Transparency = 0,
			}),
		}),
	})
end

function UpgradeTree()
	local transparency = useSpringFrom(function()
		return if store.Main.currentMenu() == "research" then 0 else 1
	end, 1, 0.25)

	local width = source(224 - 16)

	-- local pos = useSpringFrom(function(), 1, 0.25)

	local targetPosition = source(Vector2.zero)

	local smoothPosition = useSpringFrom(function()
		return targetPosition()
	end, Vector2.zero, 0.3)
	local isHolding = false

	local dragStartMouse = Vector2.zero
	local dragStartPosition = Vector2.zero

	-- store.Research.page("main")
	upgradeTreeUtil.upgradeTreeSetPage("main")

	local buttonRef, buttonAction = useInstance()

	effect(function()
		local button = buttonRef()
		if not button then
			return
		end

		local began = UserInputService.InputBegan:Connect(function(input, gp)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isHolding = true

				local inset = GuiService:GetGuiInset()
				local mouse = UserInputService:GetMouseLocation() - inset
				dragStartMouse = mouse
				dragStartPosition = targetPosition()
			end
		end)

		local ended = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isHolding = false
			end
		end)

		local changed = UserInputService.InputChanged:Connect(function(input)
			if not isHolding then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local mousePos = Vector2.new(input.Position.X, input.Position.Y)

				local delta = mousePos - dragStartMouse

				targetPosition(dragStartPosition + delta)
			end
		end)

		local swheel = button.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local isForward = input.Position.Z > 0

				width(math.clamp(width() + (isForward and 16 or -16), 96, 256))
			end
		end)

		local cleanups: { RBXScriptConnection } = { began, ended, changed, swheel }
		cleanup(function()
			for _, c in cleanups do
				c:Disconnect()
			end
		end)
	end)

	return create("Frame")({
		buttonAction,

		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = useTransparency(0.05, transparency),
		-- BackgroundColor3 = colors.slate["950"],
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),

		create("UIGradient")({
			Color = gradient.create(colors.slate["800"], colors.slate["950"]),
			Rotation = 90,
		}),

		create("TextButton")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 1000,

			create("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),

				Position = function()
					local pos = smoothPosition()

					return UDim2.new(0.5, pos.X, 0.5, pos.Y)
				end,

				values(store.Research.items, function(node)
					return UpgradeNode(node, width)
				end),
			}),

			CloseButton(),
		}),
	})
end

return function()
	return Vide.show(function()
		return store.Main.currentMenu() == "research"
	end, function()
		return UpgradeTree(), 0.1
	end)
end
