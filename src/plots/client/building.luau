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

			local lastTick = 0
			self.janitor:Add(RunService.Heartbeat:Connect(function()
				if os.clock() - lastTick > 1 / 3 then
					lastTick = os.clock()
				end

				local params = unitRaycast.getRaycastParams()
				local mLoc = UserInputService:GetMouseLocation()
				local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)
				local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

				if result then
					local hit = result.Position
					local col, row = plot.buildGrid:worldToLocal(hit)
					local snapped = plot.buildGrid:localToWorld(col, row)
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
					local params = unitRaycast.getRaycastParams()
					local mLoc = UserInputService:GetMouseLocation()
					local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)
					local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

					if not result then
						return
					end
					local hit = result.Position
					local col, row = plot.buildGrid:worldToLocal(hit)
					local isValidPlacement = plot:isValidPlacement(col, row, data.size)
					if not isValidPlacement then
						return
					end

					network.Plots.PlaceBuilding:InvokeServer("academy1", col, row)
				end
			end))
		end
	end)
end

type Building = typeof(Building) & { janitor: Janitor.Janitor }

return Building :: Building
