local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Promise = require("../../../Packages/Promise")
local attack = require("./attack")
local clientTypes = require("./clientTypes")
local movement = require("./movement")
local types = require("../shared/types")
local unitRaycast = require("../shared/unitRaycast")

--* ────────────────────────────────────────────────────────────────────────────
--* UNIT
--* ────────────────────────────────────────────────────────────────────────────
local Unit = {}
Unit.__index = Unit

export type Unit = setmetatable<clientTypes.UnitData, typeof(Unit)>

function Unit.new(unit: types.Unit, guid: string, owner: Player, position: CFrame): Unit
	local self = setmetatable({} :: clientTypes.UnitData, Unit) :: Unit

	self.guid = guid
	self.owner = owner
	self.unit = unit

	self.loadedAnims = {}
	self.loadedTracks = {}
	self.cache = {}
	self.isMoving = false

	self.pathfinder = PathfindingService:CreatePath({
		AgentRadius = 0.5,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentMaxSlope = 90,
	})

	self.model = unit.model:Clone() :: Model

	local humanoid = self.model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.EvaluateStateMachine = false
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	self.animator = humanoid:WaitForChild("Animator") :: Animator

	self.move = function(unitData: clientTypes.UnitData, wps: { Vector3 }): Promise.Class
		return Promise.new(function(rs)
			if self.targetingPromise and self.targetingPromise:getStatus() ~= "Cancelled" then
				self.targetingPromise:cancel()
			end
			if self.attackPromise and self.attackPromise:getStatus() ~= "Cancelled" then
				self.attackPromise:cancel()
			end
			if self.movePromise and self.movePromise:getStatus() ~= "Cancelled" then
				self.movePromise:cancel()
			end

			local totalLength = unitRaycast.getPathLength(wps)

			self.movePromise = Promise.new(function(resolve, reject, onCancel)
				self:playAnimation("RunAnim")

				local conn: RBXScriptConnection
				local startTime = os.clock()
				conn = RunService.Heartbeat:Connect(function(dt)
					local elapsed = os.clock() - startTime
					local distance = math.max(elapsed * self.unit.speed * 1, 0)

					local primaryPart = self.model.PrimaryPart
					assert(primaryPart ~= nil, "primarypart is nil")
					unitRaycast.setUnitPositionWithOrientationFromSampledPath(self.model :: Model, wps, distance)

					if distance >= totalLength then
						conn:Disconnect()
						resolve()
					end
				end)

				onCancel(function()
					conn:Disconnect()
				end)
			end)
				:andThen(function() end)
				:finally(function()
					self:stopAnimation("RunAnim")
				end)

			return rs(self.movePromise)
		end)
	end

	self.attack = self.unit.attackOverride and attack[self.unit.attackOverride] or attack.default

	self.model:ScaleTo(self.unit.scale)
	self.model.Parent = Workspace.NPCs

	task.defer(function()
		for _, p in self.model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Anchored = p.Name == "HumanoidRootPart"
			end
			if p:IsA("Animation") then
				self.loadedAnims[p.Name] = p
			end
		end

		self:playAnimation("Idle")

		task.wait()
		local ground = self:raycastGround(position.Position)
		if ground then
			self.model:PivotTo(CFrame.new(ground))
		end
	end)

	return self
end

function Unit.startTargeting(self: Unit)
	if self.targetingPromise and self.targetingPromise:getStatus() ~= "Cancelled" then
		self.targetingPromise:cancel()
	end
	self.targetingPromise = Promise.new(function(resolve, reject, onCancel)
		local tConn: RBXScriptConnection
		local elapsed = 0
		local lastAttack = -100000
		tConn = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if (elapsed - lastAttack) >= (1 / self.unit.firerate) then
				lastAttack = elapsed

				if self.unit.id == "apache" then
					lastAttack += 10
					local p: Promise.Class? = nil
					for _ = 1, 4 do
						p = self:attack(
							self.model:GetPivot().Position
								- Vector3.new(0, 16, 0)
								+ self.model:GetPivot().LookVector.Unit * 250
						)
						task.wait(0.1)
					end
					if p then
						p:andThen(function()
							lastAttack = elapsed
						end)
					end

					return
				end
				self:attack(self.model:GetPivot().Position + self.model:GetPivot().LookVector.Unit * 250)
			end
		end)

		onCancel(function()
			tConn:Disconnect()
		end)
	end)
end

function Unit.faceTarget(self: Unit, target: Vector3)
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

function Unit.raycastGround(self: Unit, origin: Vector3): Vector3
	local params = unitRaycast.getRaycastParams()

	local model = self.model
	if not self.cache["boundingBox"] then
		local _, size = model:GetBoundingBox()
		self.cache["boundingBox"] = size
	end

	local size = self.cache["boundingBox"]
	local offset = size.Y / 2

	local rayResult = workspace:Raycast(origin, -Vector3.yAxis * 1000, params)
	if not rayResult then
		print("No ray result")
		return origin
	end
	return Vector3.new(origin.X, rayResult.Position.Y + offset, origin.Z)
end

function Unit.playAnimation(self: Unit, anim: string)
	local a = self.loadedAnims[anim]
	if not a then
		return
	end

	self.loadedTracks[anim] = self.loadedTracks[anim] or self.animator:LoadAnimation(a)
	if not self.loadedTracks[anim].IsPlaying then
		self.loadedTracks[anim]:Play()
	end
end

function Unit.stopAnimation(self: Unit, anim: string)
	if self.loadedTracks[anim] then
		self.loadedTracks[anim]:Stop()
	end
end

function Unit.destroy(self: Unit)
	self.model:Destroy()
end

return Unit
