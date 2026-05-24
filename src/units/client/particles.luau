local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local attribute = require("../../accounts/shared/utils/attribute")

local emitCountAttr = attribute<<number?>>("EmitCount", 1)

export type ParticleData = {
	vfx: string | Instance,
	position: Vector3?,
	cframe: CFrame?,
	parent: Instance?,

	emitCount: number?,
	lifetime: number?,

	spread: number?,
}

local function getSpreadOffset(radius: number?): Vector3
	if not radius or radius <= 0 then
		return Vector3.zero
	end

	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * radius

	return Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function getTemplate(vfx: string | Instance): Instance
	if typeof(vfx) == "string" then
		return ReplicatedStorage.VFX:WaitForChild(vfx)
	end

	return vfx
end

local function emit(data: ParticleData): Instance
	local template = getTemplate(data.vfx)
	local effect = template:Clone() :: Attachment

	local position = data.position
	if position then
		position += getSpreadOffset(data.spread)
	end

	if data.cframe then
		effect.CFrame = data.cframe + getSpreadOffset(data.spread)
	elseif position then
		if effect:IsA("BasePart") then
			effect.Position = position
		elseif effect:IsA("Model") then
			effect:PivotTo(CFrame.new(position))
		else
			local part = effect :: any
			if part.Position then
				part.Position = position
			end
		end
	end

	effect.Parent = data.parent or Workspace.Terrain

	for _, descendant in effect:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			-- descendant:Emit(data.emitCount or emitCountAttr.get(descendant))
			descendant:Emit(1)
		end
	end

	Debris:AddItem(effect, data.lifetime or 5)

	return effect
end

return {
	emit = emit,
}
