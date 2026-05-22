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

	unitRaycast.initRaycastParams()
	self:initControls()

	network.Units.LoadUnits.OnClientEvent:Connect(function(snapshots: { types.UnitSnapshot })
		for _, snapshot in snapshots do
			local unitDef = constants.getUnit(snapshot.unitId)
			assert(unitDef ~= nil, "invalid unitDef")

			table.insert(self.units, Unit.new(unitDef, snapshot.guid, snapshot.owner, snapshot.position))
		end
	end)
	network.Units.RequestUnits:FireServer()
	network.Units.MoveUnit.OnClientEvent:Connect(function(guid: string, waypoints: buffer)
		for _, u in self.units do
			if u.guid ~= guid then
				continue
			end

			local result = encoder.decodeWaypoints(waypoints)
			u:moveTo()

			return
		end
	end)

	-- local unitDef = {
	-- 	-- constants.getUnit("gunner"),
	-- 	-- constants.getUnit("abramsx"),
	-- 	-- constants.getUnit("juggernaut"),
	-- 	constants.getUnit("apache"),
	-- 	-- constants.getUnit("littlebird"),
	-- 	-- constants.getUnit("tiger"),
	-- }

	-- local c = Players.LocalPlayer.Character :: Model
	-- local p = c.PrimaryPart :: BasePart
	-- local s = p.CFrame

	-- for i = 1, 2 do
	-- 	table.insert(self.units, Unit.new(unitDef[(i % #unitDef) + 1], s))
	-- end
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

					for _, u in self.units do
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
			for _, u in self.units do
				local hl = u.model:FindFirstChild("TroopHighlight") :: Highlight
				if hl then
					hl.Enabled = false
				end
			end

			movementJanitor:Cleanup()
		end

		if enabled then
			for _, u in self.units do
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

						-- local formation = unitRaycast.buildFormation(result.Position, self.units, 0)
						-- for i, u in self.units do
						-- 	u:moveTo(formation[i]):andThen(function(msg)
						-- 		print("[UNIT] MoveTo promise resolved")

						-- 		u:attack(result.Position + u.model:GetPivot().LookVector.Unit * 100):andThen(function()
						-- 			print("attack complete")
						-- 		end)
						-- 	end)
						-- end
					end))
				end
			end))
		end
	end)
end

type Units = typeof(Units) & { units: { Unit.Unit }, janitor: Janitor.Janitor }

return Units :: Units
