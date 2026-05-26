local Vide = require("../Vide")
local useViewportSize = require("./useViewportSize")

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
local action = Vide.action

local STUDIO_SIZE = Vector2.new(1920, 1080)

export type AutoScaledFrameProps = {
	ScaleFactor: number?,
	MinSize: Vector2?,
	Size: UDim2,
	Position: UDim2?,
	Rotation: number?,
	AnchorPoint: Vector2?,
	BackgroundTransparency: number?,
	ZIndex: number?,
	Children: { (Instance | () -> any)? },
	Name: string?,
	action: (Instance) -> ()?,
}

return function(props: AutoScaledFrameProps)
	local screenSize = useViewportSize() -- Get Screen Size
	local minSize = props.MinSize or Vector2.zero
	local scaleFactor = props.ScaleFactor or 1
	local scaleBinding = source(scaleFactor)

	local minScale = derive(function()
		return math.max(minSize.X / props.Size.X.Offset, minSize.Y / props.Size.Y.Offset)
	end)

	effect(function()
		local newScale = scaleFactor * math.min(screenSize().X / STUDIO_SIZE.X, screenSize().Y / STUDIO_SIZE.Y)
		scaleBinding(math.max(newScale, minScale()))
	end)

	return create("Frame")({
		Name = props.Name or "Frame",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Rotation = props.Rotation or 0,
		ZIndex = props.ZIndex or 1,
		BackgroundTransparency = props.BackgroundTransparency or 1,

		action(function(instance: Instance)
			if props.action then
				props.action(instance)
			end
		end),

		create("UIScale")({
			Scale = scaleBinding,
		}),

		table.unpack(props.Children or {}),
	})
end
