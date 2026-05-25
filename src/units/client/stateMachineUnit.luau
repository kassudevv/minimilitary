local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ClientConfig = require("../../core/client/ClientConfig")
local Promise = require("../../../Packages/PromiseTyped")
local TableUtil = require("../../../Packages/TableUtil")
local constants = require("../shared/constants")
local encoder = require("../shared/encoder")
local flags = require("./flags")
local network = require("../../core/shared/network")
local particles = require("./particles")
local projectiles = require("./projectiles")
local stateMachine = require("../shared/stateMachine")
local store = require("./store")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("../shared/unitRaycast")

local SMUnit = {}
SMUnit.__index = SMUnit

type SMUnitData = {
	def: types.Unit,
	id: number,
	owner: string,

	stateMachine: stateMachine.StateMachine,

	model: Model,
	lastProjectileTs: number,
	projectile: (SMUnit, Vector3) -> Promise.Class,

	animator: Animator,
	loadedAnims: { [string]: Animation },
	loadedTracks: { [string]: AnimationTrack },
	cache: { [string]: any },

	health: number,
	healthBarGui: BillboardGui,
}

export type SMUnit = setmetatable<SMUnitData, typeof(SMUnit)>
function SMUnit.new(def: types.Unit, snapshot: types.UnitSnapshot): SMUnit
	local self = setmetatable({} :: SMUnitData, SMUnit)

	self.def = def
	self.owner = snapshot.owner

	self.id = snapshot.id

	self.health = def.maxHealth
	self.lastProjectileTs = 0
	self.cache = {}
	self.projectile = def.attackOverride and projectiles[def.attackOverride] or projectiles.default
	self.stateMachine = stateMachine.new({
		state = "idle",
		data = {},
		handlers = {
			dead = {
				onEnter = function(prev)
					local gravestone = ReplicatedStorage.Gravestone:Clone()

					local params = unitRaycast.getRaycastParams()
					local ground = Workspace:Raycast(
						self.model:GetPivot().Position + Vector3.new(0, 10, 0),
						-Vector3.yAxis * 20,
						params
					)
					if ground then
						gravestone:PivotTo(
							CFrame.new(ground.Position + Vector3.new(0, 0.7, 0))
								* self.model:GetPivot().Rotation
								* CFrame.Angles(0, math.rad(180), 0)
						)
					end
					self.model.Parent = Lighting
					gravestone.Parent = Workspace.Camera
					self.stateMachine.data.gravestone = gravestone

					if table.find({ "helicopter", "tank", "plane" }, self.def.type or "troop") then
						local vfx = ReplicatedStorage.VFX.MissileImpactBig
						local expl = vfx:Clone()
						expl.Position = self.model:GetPivot().Position
						expl.Parent = workspace.Terrain
						for _, emitter in expl:GetChildren() do
							emitter = emitter :: ParticleEmitter
							emitter:Emit()
						end
						Debris:AddItem(expl, 3)
					end
				end,
				tick = function(dt)
					for _, c in self.stateMachine.data.gravestone:GetChildren() do
						c.Transparency = math.min(c.Transparency + dt * 1 / 10, 1)
					end
				end,
				onExit = function(next) end,
			},
			idle = {
				onEnter = function(prev)
					self:playAnimation("Idle")
				end,
				tick = function(dt) end,
				onExit = function(next) end,
			},
			moving = {
				onEnter = function(prev)
					self:playAnimation("RunAnim")
				end,
				tick = function(dt)
					-- self.stateMachine.data.lastUpdate = self.stateMachine.data.lastUpdate or 0
					-- if os.clock() - self.stateMachine.data.lastUpdate < 2 then
					-- 	return
					-- end
					-- self.stateMachine.data.lastUpdate = os.clock()

					local startTime = self.stateMachine.data.startTime
					local elapsed = os.clock() - startTime
					local distance = math.max(elapsed * self.def.speed, 0)

					unitRaycast.setUnitPositionWithOrientationFromSampledPath(
						self.model,
						self.stateMachine.data.waypoints,
						distance,
						(self.def.offset or 0) + (self.def.movementMode == "flying" and 24 or 0)
					)

					if distance > self.stateMachine.data.totalLength then
						local state: stateMachine.State = "idle"
						self.stateMachine:transition(state, {})
					end
				end,
				onExit = function(next)
					self:stopAnimation("RunAnim")
				end,
			},
			targeting = {
				onEnter = function(prev)
					local target = self.stateMachine.data.target :: SMUnit
					self:faceTarget(target.model:GetPivot().Position)

					self.stateMachine.data.start = 0
					self.stateMachine.data.isReadyToFire = false
				end,
				tick = function(dt)
					local target = self.stateMachine.data.target :: SMUnit
					local distance = target.stateMachine.state ~= "dead"
							and unitRaycast.getPlanarDistance(
								self.model:GetPivot().Position,
								target.model:GetPivot().Position
							)
						or 0
					if target.stateMachine.state == "dead" or (distance > self.def.range) then
						self.stateMachine:transition("idle" :: stateMachine.State, {})
						return
					end

					if os.clock() < self.stateMachine.data.firstShotTs then
						return
					end

					if
						not self.stateMachine.data.isReadyToFire
						and (os.clock() - self.lastProjectileTs) > 1 / self.def.firerate
					then
						self:playAnimation("Shoot")
						self.stateMachine.data.isReadyToFire = true
						self.stateMachine.data.start = os.clock()
					end

					if self.stateMachine.data.isReadyToFire then
						if (os.clock() - self.stateMachine.data.start) < (self.def.shotDelay or 0) then
							return
						end

						self.lastProjectileTs = self.stateMachine.data.start
						self.stateMachine.data.isReadyToFire = false

						local targetPos = target.model:GetPivot().Position

						self:faceTarget(targetPos)

						local doProjectile = if ClientConfig.PERFORMANCE_MODE then math.random(1, 10) == 1 else true
						if doProjectile then
							self:projectile(targetPos):await()
						end

						if target.stateMachine.state ~= "dead" then
							-- target impact effect depending on target type
							if table.find({ "troop" }, target.def.type or "troop") then
								particles.emit({
									vfx = "Blood",
									position = targetPos,
									spread = 0.1,
								})
							end
							if table.find({ "helicopter", "tank", "plane" }, target.def.type or "troop") then
								particles.emit({
									vfx = "BulletImpact",
									position = targetPos,
									spread = 3,
								})
							end

							-- tank projectile explosion
							if table.find({ "tank" }, self.def.type or "troop") then
								particles.emit({
									vfx = "MissileImpactBig",
									position = targetPos,
									spread = 3,
								})
							end
						end

						if
							self.owner == Players.LocalPlayer.Name
							or (self.owner == "pve" and target.owner == Players.LocalPlayer.Name)
						then
							network.Units.ApplyPendingHit:FireServer(target.id)
						end
					end
				end,
				onExit = function(next)
					self:stopAnimation("Shoot")
				end,
			},
		},
	})

	self.model = def.model:Clone() :: Model
	local humanoid = self.model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.EvaluateStateMachine = false
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	self.animator = humanoid:WaitForChild("Animator") :: Animator
	self.loadedAnims = {}
	self.loadedTracks = {}
	for _, p in self.model:GetDescendants() do
		if p:IsA("Animation") then
			self.loadedAnims[p.Name] = p
		end
	end

	self.model:ScaleTo(self.def.scale)

	self.model.Parent = Workspace.NPCs
	self.stateMachine:transition("idle", {})

	self.healthBarGui = ReplicatedStorage.VFX.UnitInfo:Clone()
	self.healthBarGui.MaxDistance = self.owner == Players.LocalPlayer.Name and 1 or 1
	self.healthBarGui.Parent = self.model.PrimaryPart

	task.spawn(function()
		local code = "FI"

		if self.owner ~= "pve" then
			local result, nCode =
				pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, Players.LocalPlayer)
			if result then
				code = nCode
			end
		end

		local img = (flags.get(code) or flags.flags.US).Flag

		local il = (self.healthBarGui:FindFirstChild("Flag") :: Frame):FindFirstChild("ImageLabel") :: ImageLabel
		il.Image = `rbxassetid://{img}`
	end)

	task.defer(function()
		for _, p in self.model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Anchored = p.Name == "HumanoidRootPart"
			end
		end

		local params = unitRaycast.getRaycastParams()
		local ground =
			Workspace:Raycast(snapshot.position.Position + Vector3.new(0, 100, 0), -Vector3.yAxis * 150, params)
		if ground then
			self.model:PivotTo(
				CFrame.new(
					ground.Position
						+ Vector3.new(0, (self.def.offset or 0) + (self.def.movementMode == "flying" and 24 or 0), 0)
				) * snapshot.position.Rotation
			)
		end
	end)

	return self
end

function SMUnit.setHealth(self: SMUnit, amt: number)
	self.health = amt
	local p = (self.healthBarGui:FindFirstChild("HB") :: Frame):FindFirstChild("Progress") :: Frame
	p.Size = UDim2.fromScale(self.health / self.def.maxHealth, 1)
	-- self.healthBarGui.MaxDistance = 256
end

function SMUnit.faceTarget(self: SMUnit, target: Vector3)
	local root = self.model.PrimaryPart :: BasePart
	local pos = root.Position

	local dir = target - pos
	dir = Vector3.new(dir.X, 0, dir.Z)

	if dir.Magnitude == 0 then
		return
	end

	dir = dir.Unit

	local look = CFrame.lookAt(pos, pos + dir)

	self.model:PivotTo(look)
end

function SMUnit.playAnimation(self: SMUnit, anim: string)
	local a = self.loadedAnims[anim]
	if not a then
		return
	end

	self.loadedTracks[anim] = self.loadedTracks[anim] or self.animator:LoadAnimation(a)
	if not self.loadedTracks[anim].IsPlaying then
		self.loadedTracks[anim]:Play()
	end
end

function SMUnit.stopAnimation(self: SMUnit, anim: string)
	if self.loadedTracks[anim] then
		self.loadedTracks[anim]:Stop()
	end
end

function SMUnit.cleanup(self: SMUnit)
	self.model:Destroy()
end

function SMUnit.hasLineOfSight(self: SMUnit, target: SMUnit): boolean
	local startPos = self.model:GetPivot().Position
	local endPos = target.model:GetPivot().Position

	local from = startPos + Vector3.new(0, 2, 0)
	local to = endPos + Vector3.new(0, 2, 0)
	local delta = to - from

	if delta.Magnitude < 0.001 then
		return true
	end

	local losRc = Workspace:Raycast(from, delta, unitRaycast.getLosRaycastParams())
	return not losRc
end

local SMUnits = {}

function SMUnits.init(self: SMUnits)
	self.units = {}

	unitRaycast:initRaycastParams()
	unitRaycast:initLosRaycastParams()

	self:initControls()

	RunService.Heartbeat:Connect(function(dt)
		for _, u in self.units do
			u.stateMachine:tick(dt)
		end
	end)

	-- perf
	-- local lastPerfTick = 0
	-- RunService.Heartbeat:Connect(function(dt)
	-- 	if os.clock() - lastPerfTick > 1 then
	-- 		lastPerfTick = os.clock()
	-- 		local char = Players.LocalPlayer.Character
	-- 		if not char then
	-- 			return
	-- 		end

	-- 		local pos = char:GetPivot()
	-- 		for _, u in self.units do
	-- 			local dist = (u.model:GetPivot().Position - pos.Position).Magnitude
	-- 			local shouldShow = dist < 100
	-- 			if not shouldShow then
	-- 				local animator = u.model:FindFirstChild("Animator", true) :: Animator
	-- 				if animator then
	-- 					for _, track in animator:GetPlayingAnimationTracks() do
	-- 						track:Stop()
	-- 					end
	-- 				end
	-- 			end
	-- 			-- if not shouldShow and u.model.Parent ~= ReplicatedStorage then
	-- 			-- 	u.model.Parent = ReplicatedStorage
	-- 			-- elseif shouldShow and u.model.Parent == ReplicatedStorage then
	-- 			-- 	u.model.Parent = Workspace.NPCs
	-- 			-- end
	-- 		end
	-- 	end
	-- end)
	--

	network.Units.ReplicateHealth.OnClientEvent:Connect(function(buf: buffer)
		local values = encoder.decodeHealth(buf)

		if not self.units[values.id] then
			return
		end

		self.units[values.id]:setHealth(values.health)
	end)

	network.Units.ReplicateSM.OnClientEvent:Connect(function(buf: buffer, data: { [string]: any })
		local values = encoder.decodeSM(buf)

		for _, u in self.units do
			if u.id ~= values.id then
				continue
			end

			if values.state == "moving" then
				data["startTime"] = os.clock()
				data["waypoints"] = encoder.decodeWaypoints(data["waypoints"])
				data["totalLength"] = unitRaycast.getPathLength(data["waypoints"])
			end

			if values.state == "targeting" then
				data["target"] = TableUtil.Find(self.units, function(u: SMUnit)
					return u.id == data.target
				end)
				data["firstShotTs"] = os.clock() + data.firstShotDelay
				data["startTime"] = os.clock()

				if not data["target"] then
					return
				end
			end

			if values.state == "dead" then
				task.delay(10, function()
					self.units[values.id]:cleanup()
					self.units[values.id] = nil
				end)
			end

			u.stateMachine:transition(values.state, data)
			return
		end
	end)

	network.Units.LoadUnits.OnClientEvent:Connect(function(buf: buffer)
		local snapshots = encoder.decodeUnits(buf)
		for _, snapshot in snapshots do
			if self.units[snapshot.id] then
				print("attempted duplicate unit load")
				continue
			end

			local unit = constants.getUnit(snapshot.itemId)
			assert(unit ~= nil, "unit is nil")

			self.units[snapshot.id] = SMUnit.new(unit, snapshot)
			task.wait()
		end
	end)
	task.wait()
	network.Units.RequestUnits:FireServer()
end

function SMUnits.initControls(self: SMUnits)
	UserInputService.InputBegan:Connect(function(input, gp)
		local enabled = store.movementMode()

		if gp or not enabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local params = unitRaycast.getRaycastParams()
			local mLoc = UserInputService:GetMouseLocation()
			local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)

			local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
			if not result then
				return
			end

			for _, u in self.units do
				if u.owner == Players.LocalPlayer.Name then
					u.stateMachine:transition("idle", {})
				end
			end

			network.Units.RequestPath:FireServer(result.Position)
		end
	end)
end

type SMUnits = typeof(SMUnits) & {
	units: { [number]: SMUnit },
}

return SMUnits :: SMUnits
