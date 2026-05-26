--// GradientHelper.lua

local GradientHelper = {}

-- Convert hex string (#RRGGBB or RRGGBB) → Color3
function GradientHelper.hexToColor3(hex: string)
	hex = hex:gsub("#", "")

	assert(#hex == 6, "Hex must be 6 characters long")

	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)

	return Color3.fromRGB(r, g, b)
end

-- Tailwind-style gradient builder
-- fromColor (required)
-- viaColor (optional)
-- toColor (optional)
function GradientHelper.create(fromColor: Color3, viaColor: Color3?, toColor: Color3?)
	if viaColor and not toColor then
		toColor = viaColor
		viaColor = nil
	end

	-- Only FROM → solid (no fade)
	if not viaColor and not toColor then
		return ColorSequence.new(fromColor)
	end

	local keypoints = {}

	-- start
	table.insert(keypoints, ColorSequenceKeypoint.new(0, fromColor))

	-- middle (via)
	if viaColor then
		table.insert(keypoints, ColorSequenceKeypoint.new(0.5, viaColor))
	end

	-- end (to)
	if toColor then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, toColor))
	else
		table.insert(keypoints, ColorSequenceKeypoint.new(1, fromColor))
	end

	return ColorSequence.new(keypoints)
end

return GradientHelper
