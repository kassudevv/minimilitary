local types = require("../shared/types")
local Building = {}
Building.__index = Building

type BuildingData = {}

export type Building = setmetatable<BuildingData, typeof(Building)>

function Building.new(snapshot: types.BuildingSnapshot): Building
	local self = setmetatable({} :: BuildingData, Building)

	print("Created client building")

	return self
end

return Building
