local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Charm = require("../../../Packages/Charm")
local Janitor = require("../../../Packages/Janitor")
local Ripple = require("../../../Packages/Ripple")
local items = require("../../accounts/shared/items")
local network = require("../../core/shared/network")
local plots = require("../client")
local store = require("./store")
local unitRaycast = require("../../units/shared/unitRaycast")
local units = require("../../units/client")
local Building = {}

local paramsCache: RaycastParams? = nil
local getRaycastParams = function(): RaycastParams
	if paramsCache ~= nil then
		return paramsCache :: RaycastParams
	end

	local nParams = RaycastParams.new()
	nParams.FilterType = Enum.RaycastFilterType.Include

	local plate = plots.plot.snapshot.template:WaitForChild("BuildPlate")
	if plate then
		nParams.FilterDescendantsInstances = { plate }
		print("found")
	end

	paramsCache = nParams
	return nParams
end

function Building.init(self: Building)
	self.janitor = Janitor.new()

	local previewTarget: Ripple.Spring<CFrame> =
		Ripple.createSpring(CFrame.new(), { start = true, frequency = 20 } :: Ripple.SpringOptions<CFrame>)

	local plot = plots.plot
	Charm.effect(function()
		local enabled = store.buildingModeEnabled()
		if not enabled then
			self.janitor:Cleanup()
		end
		if enabled then
			local rot = 0
			local mouse = Players.LocalPlayer:GetMouse()

			local building = items.getItem("academy1")
			local data = building.data :: items.ItemBuildingData

			local previewProp = data.model:Clone()
			for _, c in previewProp:GetDescendants() do
				if c:IsA("BasePart") then
					c.CanCollide = false
				end
			end
			previewProp.Parent = plot.snapshot.template
			self.janitor:Add(previewProp)

			previewTarget:setPosition(CFrame.new(mouse.Hit.Position))

			self.janitor:Add(previewTarget:onChange(function(value, dt)
				previewProp:PivotTo(value)
			end))

			self.janitor:Add(RunService.Heartbeat:Connect(function()
				local params = getRaycastParams()
				local mLoc = UserInputService:GetMouseLocation()
				local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)
				local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

				if result then
					local hit = result.Position

					local snapCol, snapRow = plot.buildSnapGrid:worldToLocal(hit)
					local snapped = plot.buildSnapGrid:localToWorld(snapCol, snapRow)
					local col, row = plot.buildGrid:worldToLocal(snapped.Position)
					local isValidPlacement = plot:isValidPlacement(col, row, data.size)

					previewTarget:setGoal(
						CFrame.new(snapped.X, snapped.Y, snapped.Z)
							* snapped.Rotation
							* CFrame.Angles(0, math.rad(rot), 0)
					)

					for _, c in previewProp:GetDescendants() do
						if c:IsA("BasePart") then
							c.Transparency = isValidPlacement and 0 or 0.8
						end
					end
				end
			end))
			self.janitor:Add(UserInputService.InputBegan:Connect(function(input, gp)
				if gp then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					-- rot += 90
					local params = getRaycastParams()
					local mLoc = UserInputService:GetMouseLocation()
					local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)
					local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

					if not result then
						return
					end
					local hit = result.Position

					local snapCol, snapRow = plot.buildSnapGrid:worldToLocal(hit)
					local snapped = plot.buildSnapGrid:localToWorld(snapCol, snapRow)
					local col, row = plot.buildGrid:worldToLocal(snapped.Position)
					local isValidPlacement = plot:isValidPlacement(col, row, data.size)

					if isValidPlacement then
						network.Plots.PlaceBuilding:InvokeServer("academy1", col, row)
					end
				end
			end))
		end
	end)
end

type Building = typeof(Building) & { janitor: Janitor.Janitor }

return Building :: Building
