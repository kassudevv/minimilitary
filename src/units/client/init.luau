local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Charm = require("../../Packages/Charm")
local Janitor = require("../../Packages/Janitor")
local TableUtil = require("../../Packages/TableUtil")
local Unit = require("./client/unit")
local constants = require("./shared/constants")
local encoder = require("./shared/encoder")
local index = require("./shared/index")
local network = require("../core/shared/network")
local store = require("./client/store")
local types = require("./shared/types")
local unitRaycast = require("./shared/unitRaycast")

--* ────────────────────────────────────────────────────────────────────────────
--* UNITS
--* ────────────────────────────────────────────────────────────────────────────
local Units = {}

function Units.init(self: Units)
	self.units = {}
	self.localUnits = {}

	unitRaycast.initRaycastParams()
	self:initControls()

	network.Units.LoadUnits.OnClientEvent:Connect(function(snapshots: { types.UnitSnapshot })
		task.spawn(function()
			for i, snapshot in snapshots do
				if self.units[snapshot.guid] then
					continue
				end

				local unitDef = constants.getUnit(snapshot.unitId)
				assert(unitDef ~= nil, "invalid unitDef")
				local u = Unit.new(unitDef, snapshot)
				self.units[u.guid] = u

				if snapshot.owner == Players.LocalPlayer.Name then
					self.localUnits[u.guid] = u
				end
				task.wait()
			end
		end)
	end)
	network.Units.MoveUnit.OnClientEvent:Connect(function(id: buffer, waypoints: buffer)
		local guid = index.get(id)
		for _, u in self.units do
			if u.guid ~= guid then
				continue
			end

			local result = encoder.decodeWaypoints(waypoints)
			u:move(result)

			return
		end
	end)
	network.Units.DestroyUnits.OnClientEvent:Connect(function(guids: { string })
		for _, g in guids do
			if self.units[g] then
				self.units[g]:destroy()
				self.units[g] = nil

				if self.localUnits[g] then
					self.localUnits[g] = nil
				end
			end
		end
	end)

	network.Units.StartTargeting.OnClientEvent:Connect(function(from: buffer, to: buffer)
		local u = self.units[index.get(from)]
		local t = self.units[index.get(to)]
		if u and t then
			u:startTargeting(t)
		end
	end)
	network.Units.StopTargeting.OnClientEvent:Connect(function(id: buffer)
		local u = self.units[index.get(id)]
		if u then
			if u.targetingPromise and u.targetingPromise:getStatus() ~= "Cancelled" then
				u.targetingPromise:cancel()
			end
		end
	end)

	network.Units.RequestUnits:FireServer()
end

function Units.initControls(self: Units)
	local selectionJanitor = Janitor.new()
	Charm.effect(function()
		local enabled = store.squadControlModeEnabled()
		if enabled then
			selectionJanitor:Cleanup()
		else
			selectionJanitor:Add(UserInputService.InputBegan:Connect(function(input, gp)
				if gp then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					local mLoc = UserInputService:GetMouseLocation()
					local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)

					local result = Workspace:Raycast(ray.Origin, ray.Direction * 200)
					if not result then
						return
					end

					for _, u in self.localUnits do
						if result.Instance:IsDescendantOf(u.model) then
							store.squadControlModeEnabled(true)
							return
						end
					end
				end
			end))
		end
	end)

	local movementJanitor = Janitor.new()
	local attackingTask
	Charm.effect(function()
		local enabled = store.squadControlModeEnabled()
		if not enabled then
			for _, u in self.localUnits do
				local hl = u.model:FindFirstChild("TroopHighlight") :: Highlight
				if hl then
					hl:Destroy()
				end
			end

			movementJanitor:Cleanup()
		end

		if enabled then
			for _, u in self.localUnits do
				local hl = u.model:FindFirstChild("TroopHighlight") :: Highlight
				if not hl then
					hl = ReplicatedStorage.VFX.TroopHighlight:Clone()
					hl.Parent = u.model
				end
				hl.Enabled = true
			end

			movementJanitor:Add(UserInputService.InputBegan:Connect(function(input, gp)
				if gp then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					movementJanitor:Add(task.spawn(function()
						local params = unitRaycast.getRaycastParams()
						local mLoc = UserInputService:GetMouseLocation()
						local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)

						local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
						if not result then
							return
						end

						if attackingTask then
							task.cancel(attackingTask)
							attackingTask = nil
						end

						network.Units.RequestPath:FireServer(result.Position)
					end))
				end
			end))
		end
	end)
end

type Units =
	typeof(Units)
	& { units: { [string]: Unit.Unit }, localUnits: { [string]: Unit.Unit }, janitor: Janitor.Janitor }

return Units :: Units
