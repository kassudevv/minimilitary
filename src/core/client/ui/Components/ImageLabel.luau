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

return function(props: { Position: UDim2, AnchorPoint: Vector2, Size: UDim2, Image: string })
	return create("ImageButton")({
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		Image = props.Image,
		ScaleType = Enum.ScaleType.Fit,
	})
end
