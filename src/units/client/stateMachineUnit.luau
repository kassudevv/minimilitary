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
local TaskQueue = require("../../core/shared/TaskQueue")
local Tick = require("../../core/shared/Tick")
local constants = require("../shared/constants")
local draw = require("../../core/shared/draw")
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

	LOD: UnitLOD,
}

local bulkMoveQueue: any = TaskQueue.new(function(moves: { any })
	local parts = {}
	local cframes = {}
	for _, m in moves do
		table.insert(parts, m[1])
		table.insert(cframes, m[2])
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)

type UnitLOD = "HOT" | "WARM" | "COLD"
local UnitLODPoints = {
	HOT_ENTER = 350 ^ 2,
	HOT_EXIT = 500 ^ 2,

	WARM_ENTER = 600 ^ 2,
	WARM_EXIT = 650 ^ 2,
}
local function getLOD(currentLod: UnitLOD, unitPos: Vector3, cameraPos: Vector3): UnitLOD
	local delta = unitPos - cameraPos
	local distSq = delta:Dot(delta)

	if currentLod == "HOT" then
		if distSq > UnitLODPoints.HOT_EXIT then
			return "WARM"
		end
	elseif currentLod == "WARM" then
		if distSq < UnitLODPoints.HOT_ENTER then
			return "HOT"
		elseif distSq > UnitLODPoints.WARM_EXIT then
			return "COLD"
		end
	elseif currentLod == "COLD" then
		if distSq < UnitLODPoints.WARM_ENTER then
			return "WARM"
		end
	end

	return currentLod
end

local bodyColors = { "#d5a386", "#d59678", "#d59a70", "#bd8963", "#8c6549" }

export type SMUnit = setmetatable<SMUnitData, typeof(SMUnit)>
function SMUnit.new(def: types.Unit, snapshot: types.UnitSnapshot): SMUnit
	local self = setmetatable({} :: SMUnitData, SMUnit)

	self.def = def
	self.owner = snapshot.owner

	self.id = snapshot.id

	self.health = def.health
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

					local t = self.def.type
					if self.LOD ~= "COLD" and (t == "helicopter" or t == "plane" or t == "tank") then
						particles.emit({
							vfx = "MissileImpactBig",
							position = self.model:GetPivot().Position,
							spread = 3,
						})
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
				onExit = function(next)
					self:stopAnimation("Idle")
				end,
			},
			moving = {
				onEnter = function(prev)
					self:playAnimation("RunAnim")

					local state = self.stateMachine.data
					state.segment = 1
					state.distanceInSegment = 0
					state.accum = 0
					state.root = self.model.PrimaryPart

					local beam = ReplicatedStorage.ArrowBeam:Clone()
					beam.Parent = Workspace.Terrain
					beam.A0.WorldCFrame = self.model:GetPivot()
					beam.A1.WorldCFrame = CFrame.new(
						state.path.segments[#state.path.segments].b
							+ Vector3.new(
								0,
								(self.def.offset or 0) + (self.def.movementMode == "flying" and 24 or 0),
								0
							)
					)
					self.cache["beam"] = beam
				end,
				tick = function(dt)
					local state = self.stateMachine.data
					state.accum += dt

					local tickRate = if self.LOD == "HOT" then 0.0 elseif self.LOD == "WARM" then 1 / 10 else 1
					if state.accum < tickRate then
						return
					end
					local delta = state.accum
					state.accum = 0

					local path = state.path :: unitRaycast.Path
					local seg = path.segments[self.stateMachine.data.segment]

					if not seg then
						self.stateMachine:transition("idle", {})
						return
					end

					if not state.rotation then
						state.rotation = CFrame.lookAt(Vector3.zero, seg.dir) - Vector3.zero
					end

					self.stateMachine.data.distanceInSegment += self.def.speed * delta
					while state.distanceInSegment > seg.length do
						state.distanceInSegment -= seg.length
						state.segment += 1

						seg = path.segments[state.segment]
						if not seg then
							self.stateMachine:transition("idle", {})
							return
						end
						state.rotation = CFrame.lookAt(Vector3.zero, seg.dir) - Vector3.zero
					end

					local alpha = state.distanceInSegment / seg.length
					local pos = seg.a:Lerp(seg.b, alpha)
						+ Vector3.new(0, (self.def.offset or 0) + (self.def.movementMode == "flying" and 24 or 0), 0)

					local cf = CFrame.new(pos) * state.rotation

					if self.cache["beam"] then
						self.cache["beam"].A0.WorldCFrame = cf
					end

					bulkMoveQueue:Add({ state.root, cf })
				end,
				onExit = function(next)
					self:stopAnimation("RunAnim")
					if self.cache["beam"] then
						self.cache["beam"]:Destroy()
					end
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

						local allowProjectile = self.LOD == "HOT"
							and (not ClientConfig.PERFORMANCE_MODE or math.random(1, 3) == 1)

						if allowProjectile then
							self:projectile(targetPos):await()
						end

						if
							self.owner == Players.LocalPlayer.Name
							or (self.owner == "pve" and target.owner == Players.LocalPlayer.Name)
						then
							network.Units.ApplyPendingHit:FireServer(target.id, self.def.damage)
						end

						if self.LOD == "HOT" and (not ClientConfig.PERFORMANCE_MODE or math.random(1, 3) == 1) then
							if table.find({ "tank", "plane", "helicopter" }, self.def.type or "troop") then
								particles.emit({
									vfx = "MissileImpactBig",
									position = targetPos,
									spread = 3,
								})
							end

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

	local bc = self.model:FindFirstChildWhichIsA("BodyColors")
	if bc then
		local color = bodyColors[math.random(1, #bodyColors)]
		bc.HeadColor3 = Color3.fromHex(color)
		bc.LeftArmColor3 = Color3.fromHex(color)
		bc.LeftLegColor3 = Color3.fromHex(color)
		bc.RightArmColor3 = Color3.fromHex(color)
		bc.RightLegColor3 = Color3.fromHex(color)
		bc.TorsoColor3 = Color3.fromHex(color)
	end

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
	self.healthBarGui.MaxDistance = self.owner == Players.LocalPlayer.Name and 64 or 1
	self.healthBarGui.Parent = self.model.PrimaryPart

	self.LOD = "HOT"

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
			Workspace:Raycast(snapshot.position.Position + Vector3.new(0, 10, 0), -Vector3.yAxis * 50, params)
		if ground then
			self.model:PivotTo(
				CFrame.new(
					ground.Position
						+ Vector3.new(0, (self.def.offset or 0) + (self.def.movementMode == "flying" and 24 or 0), 0)
				) * snapshot.position.Rotation
			)
		end

		self:playAnimation("Core")
	end)

	return self
end

function SMUnit.setHealth(self: SMUnit, amt: number)
	self.health = amt
	local p = (self.healthBarGui:FindFirstChild("HB") :: Frame):FindFirstChild("Progress") :: Frame
	p.Size = UDim2.fromScale(self.health / self.def.health, 1)
	if self.LOD == "HOT" then
		self.healthBarGui.MaxDistance = 64
	end
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
	self.unitsArr = {}

	unitRaycast:initRaycastParams()
	unitRaycast:initLosRaycastParams()

	self:InitControls()
	self:StartTicking()
	self:InitNetwork()

	return Promise.new(function(resolve, reject, onCancel)
		network.Units.LoadUnits.OnClientEvent:Once(function(buf: buffer)
			resolve()
		end)

		network.Units.RequestUnits:FireServer()
	end)
end

function SMUnits.InitNetwork(self: SMUnits)
	network.Units.LoadUnits.OnClientEvent:Connect(function(buf: buffer)
		local snapshots = encoder.decodeUnits(buf)
		for _, snapshot in snapshots do
			if self.units[snapshot.id] then
				print("attempted duplicate unit load")
				continue
			end

			local unit = constants.getUnit(snapshot.itemId :: constants.UnitId)
			assert(unit ~= nil, "unit is nil")

			local u = SMUnit.new(unit, snapshot)
			table.insert(self.unitsArr, u)
			self.units[snapshot.id] = u
			task.wait(math.random())
		end
	end)

	network.Units.ReplicateHealth.OnClientEvent:Connect(function(buf: buffer)
		local values = encoder.decodeHealth(buf)

		if not self.units[values.id] then
			return
		end

		self.units[values.id]:setHealth(values.health)
	end)

	network.Units.ReplicateSM.OnClientEvent:Connect(function(buf: buffer, data: { [string]: any })
		local values = encoder.decodeSM(buf)

		local u = self.units[values.id]
		if not u then
			return
		end

		if values.state == "moving" then
			data["path"] = unitRaycast.buildPathData(encoder.decodeWaypoints(data["waypoints"]))
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

		u.stateMachine:transition(values.state, data)
		return
	end)

	network.Units.DestroyUnits.OnClientEvent:Connect(function(ids: { number })
		for _, id in ids do
			local u = self.units[id]
			if u then
				self:DestroyUnit(u)
			end
		end
	end)
end

function SMUnits.StartTicking(self: SMUnits)
	Tick.every(0, function(dt)
		for _, u in self.unitsArr do
			u.stateMachine:tick(dt)
		end
	end)

	local cursor = 1
	Tick.every(0, function()
		local processed = 0
		local maxPerTick = 3
		local to = Workspace.Camera.CFrame.Position

		while processed < maxPerTick do
			local k = self.unitsArr[cursor]
			if not k then
				cursor = 1
				break
			end
			local u = self.unitsArr[cursor]

			u.LOD = getLOD(u.LOD, u.model:GetPivot().Position, to)

			if u.LOD == "COLD" and u.model.Parent ~= nil then
				u.model.Parent = nil
				for _, p in u.model:GetDescendants() do
					if p:IsA("BasePart") then
						p.CanCollide = false
						p.Anchored = true
					end
				end
			elseif u.LOD ~= "COLD" and u.model.Parent == nil then
				u.model.Parent = Workspace.NPCs
				for _, p in u.model:GetDescendants() do
					if p:IsA("BasePart") then
						p.CanCollide = false
						p.Anchored = p.Name == "HumanoidRootPart"
					end
				end
			end

			cursor += 1
			processed += 1
		end
	end)
end

function SMUnits.DestroyUnit(self: SMUnits, unit: SMUnit)
	local idx = table.find(self.unitsArr, unit)
	if idx then
		local n = #self.unitsArr
		self.unitsArr[idx] = self.unitsArr[n]
		self.unitsArr[n] = nil
	end
	self.units[unit.id] = nil

	unit:cleanup()
end

-- local p: BasePart
function SMUnits.InitControls(self: SMUnits)
	-- UserInputService.InputBegan:Connect(function(input, gp)
	-- 	local enabled = store.movementMode()

	-- 	if gp or not enabled then
	-- 		return
	-- 	end
	-- 	if input.UserInputType == Enum.UserInputType.MouseButton1 then
	-- 		local params = unitRaycast.getRaycastParams()
	-- 		local mLoc = UserInputService:GetMouseLocation()
	-- 		local ray = Workspace.Camera:ViewportPointToRay(mLoc.X, mLoc.Y)

	-- 		local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	-- 		if not result then
	-- 			return
	-- 		end

	-- 		for _, u in self.unitsArr do
	-- 			if u.owner == Players.LocalPlayer.Name then
	-- 				u.stateMachine:transition("idle", {})
	-- 			end
	-- 		end

	-- 		if p then
	-- 			p:Destroy()
	-- 		end
	-- 		p = draw.labelledPoint(result.Position, "[debug] rally point")

	-- 		network.Units.RequestPath:FireServer(result.Position)
	-- 	end
	-- end)
end

type SMUnits = typeof(SMUnits) & {
	units: { [number]: SMUnit },
	unitsArr: { SMUnit },
}

return SMUnits :: SMUnits
