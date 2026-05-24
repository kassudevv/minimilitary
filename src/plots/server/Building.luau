local items = require("@game/ReplicatedStorage/src/accounts/shared/items")

local HttpService = game:GetService("HttpService")
local types = require("@game/ReplicatedStorage/src/plots/shared/types")
local Building = {}
Building.__index = Building

type BuildingData = {
	guid: string,
	item: items.ItemInfo,
	data: items.ItemBuildingData,
	model: Model,
}

export type Building = setmetatable<BuildingData, typeof(Building)>

function Building.new(item: items.ItemInfo): Building
	local self = setmetatable({} :: BuildingData, Building)

	self.guid = HttpService:GenerateGUID(false)
	self.item = item
	self.data = item.data :: items.ItemBuildingData

	return self
end

function Building.spawn(self: Building, position: CFrame, parent: Instance): Model
	if self.model then
		return self.model
	end
	self.model = self.data.model:Clone()
	for _, c in self.model:GetDescendants() do
		if c:IsA("BasePart") then
			c.CanCollide = false
		end
	end
	self.model:PivotTo(position)
	self.model.Parent = parent
	return self.model
end

function Building.destroy(self: Building)
	if self.model then
		self.model:Destroy()
	end
end

function Building.snapshot(self: Building): types.BuildingSnapshot
	return {
		guid = self.guid,
		item = self.item,
		data = self.data,
		model = self.model,
	}
end

return Building
