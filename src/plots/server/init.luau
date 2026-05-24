local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Janitor = require("@game/ReplicatedStorage/Packages/Janitor")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local accountStore = require("../accounts/server/accountStore")
local accountTypes = require("@game/ReplicatedStorage/src/accounts/shared/types")
local area = require("@game/ReplicatedStorage/src/plots/shared/area")
local conf = require("@game/ReplicatedStorage/src/plots/shared/conf")
local grid = require("@game/ReplicatedStorage/src/plots/shared/grid")
local items = require("@game/ReplicatedStorage/src/accounts/shared/items")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local store = require("../accounts/server/store")
local types = require("@game/ReplicatedStorage/src/plots/shared/types")

--* ────────────────────────────────────────────────────────────────────────────
--* TILES OBJECT
--* ────────────────────────────────────────────────────────────────────────────

--* PLOT
local Plot = {}
Plot.__index = Plot

type PlotData = {
	index: number,
	template: Model,
	plotSpawn: BasePart,
	janitor: Janitor.Janitor,
	tileGrid: grid.Grid,
	buildGrid: grid.Grid,

	owner: Player?,
	area: area.Area,
}

export type Plot = setmetatable<PlotData, typeof(Plot)>

function Plot.new(plotSpawn: BasePart, index): Plot
	local self = setmetatable({} :: PlotData, Plot)

	self.janitor = Janitor.new()

	self.index = index
	self.plotSpawn = plotSpawn
	self.area = area.new()

	-- cast to avoid weird error
	local casted = self :: Plot
	casted:loadTemplate()

	local gridStart = self.template:WaitForChild("StartGrid") :: BasePart
	self.buildGrid = grid.new(gridStart.CFrame, conf.GRID_BUILD_SIZE)
	self.tileGrid = grid.new(gridStart.CFrame, conf.GRID_TILE_SIZE)

	return self
end

function Plot.loadTemplate(self: Plot)
	if self.template then
		self.template:Destroy()
	end

	self.template = Workspace.Template:Clone() :: Model
	self.template:PivotTo(self.plotSpawn.CFrame)
	self.template.Parent = workspace
	self.template.Name = `template_{self.index}`
end

function Plot.reset(self: Plot)
	self.janitor:Cleanup()
	self.template:Destroy()
	self.area:cleanup()
	self.owner = nil

	self:loadTemplate()
end

function Plot.claim(self: Plot, plr: Player)
	self.owner = plr

	self:loadState(plr)
	self:charInit()
end

local defaultArea: any = {}
for row = 3, conf.GRID_WIDTH - 4 do
	table.insert(defaultArea, { x = 0, y = row })
end
for row = 3, conf.GRID_WIDTH - 4 do
	table.insert(defaultArea, { x = 1, y = row })
end

function Plot.loadState(self: Plot, plr: Player)
	local ok, data: accountStore.Account = store:get(plr):await()
	if ok then
		-- create area locks
		for col = 0, conf.GRID_HEIGHT - 1 do
			for row = 0, conf.GRID_WIDTH - 1 do
				local lockedTile = Workspace.LockedTile:Clone() :: Model
				local cf = self.tileGrid:localToWorld(col, row)
				lockedTile:PivotTo(CFrame.new(cf.X, cf.Y - 0.5, cf.Z) * cf.Rotation)
				lockedTile.Parent = self.template:FindFirstChild("Misc")
				self.area:lock(col, row, lockedTile)
			end
		end

		-- clear area
		for _, t in TableUtil.Extend(defaultArea, data.plot.tiles) do
			self.area:unlock(t.x, t.y)
		end
	end
end

function Plot.snapshot(self: Plot): types.PlotSnapshot
	return { id = self.index, template = self.template, area = self.area:getLocked() }
end

function Plot.charInit(self: Plot)
	if not self.owner then
		return
	end

	local char = self.owner.Character or self.owner.CharacterAdded:Wait()
	char:PivotTo(self.template:GetPivot() * CFrame.new(0, 20, 0))
	local h = char:WaitForChild("Humanoid") :: Humanoid
	h.WalkSpeed = 70

	self.janitor:Add(self.owner.CharacterAdded:Connect(function(newChar)
		newChar:PivotTo(self.template:GetPivot() * CFrame.new(0, 20, 0))
		h = newChar:WaitForChild("Humanoid") :: Humanoid
		h.WalkSpeed = 70
	end))
end

--* PLOTS
local Plots = {}

function Plots.init(self: Plots)
	self.plots = {}

	for _, plotSpawn: BasePart in CollectionService:GetTagged("PlotSpawn") do
		local index = plotSpawn:GetAttribute("Index") :: number
		self.plots[index] = Plot.new(plotSpawn, index)
	end

	network.Plots.RequestPlot.OnServerInvoke = function(plr: Player)
		if self:getPlayerPlot(plr) then
			return nil
		end

		local result = nil
		for _, plot in TableUtil.Shuffle(self.plots) do
			if not plot.owner then
				plot:claim(plr)
				result = plot:snapshot()
				break
			end
		end
		return result
	end

	network.Plots.PlaceBuilding.OnServerInvoke = function(
		plr: Player,
		buildingId: string,
		col: number,
		row: number
	): boolean?
		local plot = self:getPlayerPlot(plr)
		if not plot then
			return nil
		end

		local building = items.getItem(buildingId)

		local data = building.data :: items.ItemBuildingData

		local posInWorld = plot.buildGrid:localToWorld(col, row)
		local m = data.model:Clone()
		for _, c in m:GetDescendants() do
			if c:IsA("BasePart") then
				c.CanCollide = false
			end
		end
		m:PivotTo(posInWorld)
		m.Parent = Workspace

		return true
	end

	Players.PlayerRemoving:Connect(function(player)
		local p = self:getPlayerPlot(player)
		if p then
			p:reset()
		end
	end)
end

function Plots.getPlayerPlot(self: Plots, plr: Player): Plot?
	for _, plot in self.plots do
		if plot.owner == plr then
			return plot
		end
	end
	return nil
end

type Plots = typeof(Plots) & {
	plots: { Plot },
}

return Plots :: Plots

-- local function checkCollision(posInWorld, data: items.ItemBuildingData, height)
-- 		task.delay(0.2, function()
-- 			-- anti stuck
-- 			local params = OverlapParams.new()
-- 			params.FilterType = Enum.RaycastFilterType.Include
-- 			local filterPlrs = {}
-- 			for _, p in Players:GetPlayers() do
-- 				local c = p.Character
-- 				if c then
-- 					table.insert(filterPlrs, c)
-- 				end
-- 			end
-- 			local completed = {}
-- 			params.FilterDescendantsInstances = filterPlrs
-- 			params.RespectCanCollide = false

-- 			local colls =
-- 				Workspace:GetPartBoundsInBox(posInWorld, Vector3.new(data.size.X, height, data.size.Y), params)
-- 			for _, coll in colls do
-- 				local collidingChar = coll:FindFirstAncestorOfClass("Model")
-- 				if not collidingChar then
-- 					continue
-- 				end

-- 				local collidingPlr = Players:GetPlayerFromCharacter(collidingChar)
-- 				if not collidingPlr or table.find(completed, collidingPlr) then
-- 					continue
-- 				end

-- 				table.insert(completed, collidingPlr)

-- 				local result =
-- 					Workspace:Raycast(collidingChar:GetPivot().Position + Vector3.new(0, 100, 0), -Vector3.yAxis * 1000)
-- 				if result then
-- 					collidingChar:PivotTo(CFrame.new(result.Position.X, result.Position.Y + 10, result.Position.Z))
-- 				end
-- 			end
-- 		end)
-- 	end
