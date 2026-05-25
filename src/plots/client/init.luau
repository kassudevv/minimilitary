local Building = require("@self/Building")
local area = require("./shared/area")
local conf = require("@game/ReplicatedStorage/src/plots/shared/conf")
local grid = require("@game/ReplicatedStorage/src/plots/shared/grid")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local types = require("@game/ReplicatedStorage/src/plots/shared/types")

local Plot = {}
Plot.__index = Plot

type PlotData = {
	snapshot: types.PlotSnapshot,
	tileGrid: grid.Grid,
	buildGrid: grid.Grid,
	buildSnapGrid: grid.Grid,
	area: area.Area,
	buildings: { [string]: Building.Building },
}

export type Plot = setmetatable<PlotData, typeof(Plot)>

function Plot.new(snapshot: types.PlotSnapshot): Plot
	local self = setmetatable({} :: PlotData, Plot)

	self.snapshot = snapshot

	print(snapshot)
	local gridStart = self.snapshot.template:WaitForChild("StartGrid") :: BasePart

	self.buildGrid = grid.new(gridStart.CFrame * CFrame.new(0, 0, 0), conf.GRID_BUILD_SIZE)
	self.buildSnapGrid = grid.new(gridStart.CFrame * CFrame.new(0, 0, 0), conf.GRID_BUILD_SNAP_SIZE)
	self.tileGrid = grid.new(gridStart.CFrame * CFrame.new(0, 0, 0), conf.GRID_TILE_SIZE)

	self.area = area.new()
	self.area:setLocked(snapshot.area)

	print(`Received plot snapshot`, snapshot)

	return self
end

function Plot.isValidPlacement(self: Plot, col: number, row: number, size: Vector2): boolean
	local eps = 0.01
	local halfX, halfY = size.X / 2, size.Y / 2
	local corners = {
		{ col + halfX - eps, row + halfY - eps },
		{ col - halfX + eps, row - halfY + eps },
		{ col + halfX - eps, row - halfY + eps },
		{ col - halfX + eps, row + halfY - eps },
	}

	local v = true
	for _, p in corners do
		local snapped = self.buildGrid:localToWorld(p[1], p[2])
		local tileCol, tileRow = self.tileGrid:worldToLocal(snapped.Position)

		if
			not self.tileGrid:inBounds(tileCol, tileRow, conf.GRID_HEIGHT, conf.GRID_WIDTH)
			or not self.area:isUnlocked(tileCol, tileRow)
		then
			v = false
			break
		end
	end
	return v
end

function Plot.connectBuilding(self: Plot, snapshot: types.BuildingSnapshot)
	self.buildings[snapshot.guid] = Building.new(snapshot)
end

function Plot.init(self: Plot)
	self.buildings = {}
end

local Plots = {}

function Plots.init(self: Plots)
	local p = network.Plots.RequestPlot:InvokeServer()
	if not p then
		return
	end

	self.plot = Plot.new(p)
	self.plot:init()

	network.Plots.ReplicateBuilding.OnClientEvent:Connect(function(snapshot: types.BuildingSnapshot)
		self.plot:connectBuilding(snapshot)
	end)
end

type Plots = typeof(Plots) & { plot: Plot }

return Plots :: Plots
