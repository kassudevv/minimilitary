local Vide = require("../Vide")
local items = require("../../../../accounts/shared/items")
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

return function(props: { Position: UDim2, AnchorPoint: Vector2, Size: UDim2, Image: string, Activated: () -> () })
	local hovered = source(false)
	local pressed = source(false)

	local scaleGoal = derive(function()
		if pressed() then
			return 0.92
		end

		if hovered() then
			return 1.05
		end

		return 1
	end)
	local scale = spring(scaleGoal, 0.1, 0.8)

	return create("Frame")({
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,

		create("ImageButton")({
			AnchorPoint = v(0.5, 0.5),
			Position = fs(0.5, 0.5),
			Size = props.Size,
			BackgroundTransparency = 1,
			Image = props.Image,
			ScaleType = Enum.ScaleType.Fit,

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
					props.Activated()
				else
					hovered(false)
					pressed(false)
				end
			end),
		}),
	})
end
