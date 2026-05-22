local Grid = {}
Grid.__index = Grid

type GridData = {
	origin: CFrame,
	cellSize: number,
}

export type Grid = typeof(setmetatable({} :: GridData, Grid))

function Grid.new(origin: CFrame, cellSize: number): Grid
	local self = setmetatable({
		origin = origin,
		cellSize = cellSize,
	}, Grid)
	return self
end

function Grid.worldToLocal(self: Grid, worldPos: Vector3): (number, number)
	local localPos = self.origin:PointToObjectSpace(Vector3.new(worldPos.X, self.origin.Y, worldPos.Z))
	local col = math.floor((localPos.X + self.cellSize / 2) / self.cellSize)
	local row = math.floor((localPos.Z + self.cellSize / 2) / self.cellSize)
	return col, row
end

function Grid.localToWorld(self: Grid, col: number, row: number): CFrame
	local localPos = Vector3.new(col * self.cellSize, 0, row * self.cellSize)
	return self.origin * CFrame.new(localPos)
end

function Grid.inBounds(self: Grid, col: number, row: number, width: number, height: number): boolean
	return col >= 0 and col < width and row >= 0 and row < height
end

return Grid
