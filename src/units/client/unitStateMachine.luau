local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local constants = require("../shared/constants")
local stateMachine = require("../shared/stateMachine")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")
local SMUnit = {}
SMUnit.__index = SMUnit

type SMUnitData = {
	def: types.Unit,

	stateMachine: stateMachine.StateMachine,
	state: "moving" | "targeting" | "idle",
	stateData: { [string]: any },

	model: Model,

	animator: Animator,
	loadedAnims: { [string]: Animation },
	loadedTracks: { [string]: AnimationTrack },
}

export type SMUnit = setmetatable<SMUnitData, typeof(SMUnit)>
function SMUnit.new(def: types.Unit, position: CFrame): SMUnit
	local self = setmetatable({} :: SMUnitData, SMUnit)

	self.def = def
	self.stateMachine = stateMachine.new({
		state = "idle",
		data = {},
		handlers = {
			idle = {
				onEnter = function(prev)
					self:playAnimation("Idle")
				end,
				onExit = function(next) end,
			},
			moving = {
				onEnter = function(prev)
					self:playAnimation("RunAnim")
				end,
				onExit = function(next)
					self:stopAnimation("RunAnim")
				end,
			},
			targeting = {
				onEnter = function(prev)
					self:playAnimation("Shoot")
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
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.Anchored = p.Name == "HumanoidRootPart"
		end
		if p:IsA("Animation") then
			self.loadedAnims[p.Name] = p
		end
	end
	self.model:ScaleTo(self.def.scale)
	self.model:PivotTo(position)
	self.model.Parent = Workspace.NPCs
	self.stateMachine:transition("idle", {})

	return self
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

	RunService.Heartbeat:Connect(function(dt)
		for _, u in self.units do
			u.stateMachine:tick(dt)
		end
	end)

	for _ = 1, 1 do
		local p = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
		local hrp = p:WaitForChild("HumanoidRootPart") :: BasePart
		local unit = constants.getUnit("gunner") :: types.Unit
		print(unit)
		table.insert(self.units, SMUnit.new(unit, hrp.CFrame))

		task.wait(1)
		self.units[1].stateMachine:transition("moving", {})
	end
end

type SMUnits = typeof(SMUnits) & {
	units: { SMUnit },
}

return SMUnits :: SMUnits
