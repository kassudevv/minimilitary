local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Promise = require("../../../Packages/PromiseTyped")
local Ripple = require("../../../Packages/Ripple")

local Projectiles: { [string]: (any, Vector3) -> Promise.Class } = {
	default = function(self: any, target: Vector3)
		return Promise.new(function(resolve, reject, onCancel)
			local spread = 2
			local angle = math.random() * math.pi * 2
			local radius = math.sqrt(math.random()) * spread
			target += Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

			local shoot = self.model:FindFirstChild("Shoot") :: BasePart
			local muzzle = ReplicatedStorage.VFX.Muzzle:Clone()
			muzzle.CFrame = shoot.CFrame
			muzzle.Parent = workspace.Terrain
			muzzle.Muzzle:Emit()

			local p0 = shoot.Position
			local p2 = target

			local mid = p0:Lerp(p2, 0.5)
			local p1 = mid + Vector3.new(0, (p0 - p2).Magnitude * 0.15, 0)

			local bullet = math.random(1, 10) == 1 and ReplicatedStorage.VFX.BulletTrailbb:Clone()
				or ReplicatedStorage.VFX.BulletTrail:Clone()

			bullet.Parent = Workspace.Terrain
			bullet.Position = p0

			local duration = (p2 - p0).Magnitude / 300

			local t: Ripple.Tween<number> = Ripple.createTween(
				0,
				{ easing = "linear", duration = duration, start = true } :: Ripple.TweenOptions<number>
			)
			t:setGoal(1)
			t:onChange(function(v: number)
				local inv = 1 - v
				bullet.Position = inv * inv * p0 + 2 * inv * v * p1 + v * v * p2
			end)
			t:onComplete(function()
				Debris:AddItem(muzzle, 0)
				Debris:AddItem(bullet, 0)

				resolve()

				t:destroy()
			end)
		end)
	end,
	helicopter_missiles = function(self: any, target: Vector3, isOwner: boolean, targetGuid: string)
		return Promise.new(function(resolve, reject, onCancel)
			self:faceTarget(target)

			local spread = 2
			local angle = math.random() * math.pi * 2
			local radius = math.sqrt(math.random()) * spread
			target += Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

			local torso = self.model:FindFirstChild("torso")
			if not torso then
				return
			end

			if not self.cache["missiles"] then
				local missiles = {}
				for _, c in torso:GetChildren() do
					if c:IsA("Motor6D") and c.Name:sub(1, #"missile") == "missile" then
						table.insert(missiles, c)
					end
				end
				self.cache["missiles"] = missiles
			end

			local count = #self.cache["missiles"]
			assert(count > 0, "no missiles found under torso. name must start with 'missile'")

			self.cache["nextMissileIdx"] = self.cache["nextMissileIdx"] or 1
			local nextMissileIdx = self.cache["nextMissileIdx"]

			if nextMissileIdx > count then
				nextMissileIdx = 1
			end

			self.cache["nextMissileIdx"] = nextMissileIdx + 1
			local joint = self.cache["missiles"][nextMissileIdx]

			local missile = joint.Part1

			missile.Parent = Workspace

			joint.C1 = CFrame.new(Vector3.new(0, 0, 0))

			local p0 = missile.Position
			local p2 = target

			local mid = p0:Lerp(p2, 0.5)
			local arcHeight = math.max((p0 - p2).Magnitude * 0.05, 20)
			local p1 = mid + Vector3.new(0, arcHeight, 0)

			local duration = (p2 - p0).Magnitude / 100

			local t: Ripple.Tween<number> = Ripple.createTween(
				0,
				{ easing = "linear", duration = duration, start = true } :: Ripple.TweenOptions<number>
			)

			t:setGoal(1)

			t:onChange(function(v)
				local inv = 1 - v

				local pos = inv * inv * p0 + 2 * inv * v * p1 + v * v * p2
				local tangent = 2 * inv * (p1 - p0) + 2 * v * (p2 - p1)

				if tangent.Magnitude <= 0 then
					return
				end

				if not joint.Part0 then
					return
				end
				joint.C1 = CFrame.lookAt(pos, pos + tangent.Unit):Inverse() * joint.Part0.CFrame * joint.C0
			end)

			t:onComplete(function()
				resolve()

				local vfx = ReplicatedStorage.VFX.MissileImpact
				local expl = vfx:Clone()
				expl.Position = target
				expl.Parent = workspace.Terrain
				for _, emitter in expl:GetChildren() do
					emitter = emitter :: ParticleEmitter
					emitter:Emit()
				end
				Debris:AddItem(expl, 3)

				missile.Transparency = 1

				task.delay(1 / self.def.firerate, function()
					joint.C1 = CFrame.new(Vector3.new(0, 0, 0))

					missile.Transparency = 0
					missile.Parent = self.model
				end)
			end)
		end)
			:andThen(function() end)
			:finally(function()
				self:stopAnimation("Shoot")
			end)
	end,
}

return Projectiles
