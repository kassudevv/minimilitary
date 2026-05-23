local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Promise = require("../../../Packages/Promise")
local TableUtil = require("../../../Packages/TableUtil")
local constants = require("../shared/constants")
local network = require("../../core/shared/network")
local projectiles = require("./projectiles")
local stateMachine = require("../shared/stateMachine")
local store = require("./store")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("../shared/unitRaycast")

local SMUnit = {}
SMUnit.__index = SMUnit

type SMUnitData = {
	def: types.Unit,
	guid: string,

	stateMachine: stateMachine.StateMachine,
	state: "moving" | "targeting" | "idle",
	stateData: { [string]: any },

	model: Model,
	lastProjectileTs: number,
	projectile: (SMUnit, Vector3) -> Promise.Class,

	animator: Animator,
	loadedAnims: { [string]: Animation },
	loadedTracks: { [string]: AnimationTrack },
}

export type SMUnit = setmetatable<SMUnitData, typeof(SMUnit)>
function SMUnit.new(def: types.Unit, snapshot: types.UnitSnapshot): SMUnit
	local self = setmetatable({} :: SMUnitData, SMUnit)

	self.def = def
	self.guid = snapshot.guid
	self.lastProjectileTs = 0
	self.projectile = projectiles.default
	self.stateMachine = stateMachine.new({
		state = "idle",
		data = {},
		handlers = {
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
					local startTime = self.stateMachine.data.startTime
					local elapsed = os.clock() - startTime
					local distance = math.max(elapsed * self.def.speed, 0)

					unitRaycast.setUnitPositionWithOrientationFromSampledPath(
						self.model,
						self.stateMachine.data.waypoints,
						distance,
						self.def.offset
					)

					if distance > self.stateMachine.data.totalLength then
						local state: "idle" | "moving" | "targeting" = "idle"
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
					if os.clock() < self.stateMachine.data.firstShotTs then
						return
					end

					local target = self.stateMachine.data.target
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

						self.projectile(self, target.model:GetPivot().Position):andThen(function()
							network.Units.ApplyPendingHit:FireServer(target.guid)
						end)
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
	self.model:PivotTo(snapshot.position)
	self.model.Parent = Workspace.NPCs
	self.stateMachine:transition("idle", {})

	task.defer(function()
		for _, p in self.model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Anchored = p.Name == "HumanoidRootPart"
			end
		end
	end)

	return self
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

local SMUnits = {}

function SMUnits.init(self: SMUnits)
	self.units = {}

	unitRaycast:initRaycastParams()
	self:initControls()

	RunService.Heartbeat:Connect(function(dt)
		for _, u in self.units do
			u.stateMachine:tick(dt)
		end
	end)

	network.Units.ReplicateSM.OnClientEvent:Connect(
		function(guid: string, state: "idle" | "moving" | "targeting", data: { [string]: any })
			for _, u in self.units do
				if u.guid ~= guid then
					continue
				end

				if state == "moving" then
					data["startTime"] = os.clock()
				end

				if state == "targeting" then
					data["target"] = TableUtil.Find(self.units, function(u: SMUnit)
						return u.guid == data.target
					end)
					data["firstShotTs"] = os.clock() + data.firstShotDelay
				end

				u.stateMachine:transition(state, data)

				return
			end
		end
	)

	network.Units.LoadUnits.OnClientEvent:Connect(function(snapshots: { types.UnitSnapshot })
		for _, snapshot in snapshots do
			local unit = constants.getUnit(snapshot.unitId)
			assert(unit ~= nil, "unit is nil")
			table.insert(self.units, SMUnit.new(unit, snapshot))
		end
	end)
	task.wait(1)
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
				local state: "idle" | "moving" | "targeting" = "idle"
				u.stateMachine:transition(state, {})
			end

			network.Units.RequestPath:FireServer(result.Position)
		end
	end)
end

type SMUnits = typeof(SMUnits) & {
	units: { SMUnit },
}

return SMUnits :: SMUnits
