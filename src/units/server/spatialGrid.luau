local SpatialGrid = {}
SpatialGrid.__index = SpatialGrid

export type SpatialGrid = {
	cellSize: number,
	cells: { [string]: { any } },

	clear: (self: SpatialGrid) -> (),
	insert: (self: SpatialGrid, unit: any) -> (),
	rebuild: (self: SpatialGrid, units: { [string]: any }) -> (),
	forEachEnemyInRange: (
		self: SpatialGrid,
		sourceUnit: any,
		range: number,
		callback: (target: any, dist: number) -> ()
	) -> (),
	getEnemiesInRange: (self: SpatialGrid, sourceUnit: any, range: number) -> { any },
}

local function getCellCoord(pos: Vector3, cellSize: number): (number, number)
	return math.floor(pos.X / cellSize), math.floor(pos.Z / cellSize)
end

local function getCellKey(x: number, z: number): string
	return x .. ":" .. z
end

local function getDistanceSq(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z

	return dx * dx + dz * dz
end

function SpatialGrid.new(cellSize: number): SpatialGrid
	return setmetatable({
		cellSize = cellSize,
		cells = {},
	}, SpatialGrid) :: SpatialGrid
end

function SpatialGrid.clear(self: SpatialGrid)
	table.clear(self.cells)
end

function SpatialGrid.insert(self: SpatialGrid, unit: any)
	local x, z = getCellCoord(unit.pawn.Position, self.cellSize)
	local key = getCellKey(x, z)

	local cell = self.cells[key]
	if not cell then
		cell = {}
		self.cells[key] = cell
	end

	table.insert(cell, unit)
end

function SpatialGrid.rebuild(self: SpatialGrid, units: { [string]: any })
	self:clear()

	for _, unit in units do
		self:insert(unit)
	end
end

function SpatialGrid.forEachEnemyInRange(
	self: SpatialGrid,
	sourceUnit: any,
	range: number,
	callback: (target: any, dist: number) -> ()
)
	local sourcePos = sourceUnit.pawn.Position
	local sourceCellX, sourceCellZ = getCellCoord(sourcePos, self.cellSize)
	local cellRadius = math.ceil(range / self.cellSize)
	local rangeSq = range * range

	for x = sourceCellX - cellRadius, sourceCellX + cellRadius do
		for z = sourceCellZ - cellRadius, sourceCellZ + cellRadius do
			local cell = self.cells[getCellKey(x, z)]
			if not cell then
				continue
			end

			for _, target in cell do
				if target == sourceUnit or target.owner == sourceUnit.owner then
					continue
				end

				local dist = getDistanceSq(sourcePos, target.pawn.Position)
				if dist <= rangeSq then
					callback(target, dist)
				end
			end
		end
	end
end

function SpatialGrid.getEnemiesInRange(self: SpatialGrid, sourceUnit: any, range: number): { any }
	local results = {}

	self:forEachEnemyInRange(sourceUnit, range, function(target)
		table.insert(results, target)
	end)

	return results
end

return SpatialGrid
