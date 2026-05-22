local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Promise = require("../../../Packages/PromiseTyped")
local Ripple = require("../../../Packages/Ripple")
local clientTypes = require("./clientTypes")

local Attack: { [string]: (clientTypes.UnitData, Vector3) -> typeof(Promise.new(function() end)) } = {
	default = function(self: clientTypes.UnitData, target: Vector3)
		return Promise.new(function(rs)
			if self.movePromise and self.movePromise:getStatus() ~= "Cancelled" then
				self.movePromise:cancel()
			end

			if self.attackPromise and self.attackPromise:getStatus() ~= "Cancelled" then
				self.attackPromise:cancel()
			end

			self.attackPromise = Promise.new(function(resolve, reject, onCancel)
				self:faceTarget(target)

				task.delay(1 / self.unit.firerate + 0.1, function()
					resolve()
				end)

				if self.unit.animToBulletDelay then
					task.wait(self.unit.animToBulletDelay)
				end

				local spread = 20
				local angle = math.random() * math.pi * 2
				local radius = math.sqrt(math.random()) * spread
				target += Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

				local shoot = self.model:FindFirstChild("Shoot") :: BasePart
				local muzzle = ReplicatedStorage.VFX.Muzzle:Clone()
				muzzle.CFrame = shoot.CFrame
				muzzle.Parent = workspace.Terrain
				muzzle.Muzzle:Emit(5)

				-- bullet
				local p0 = shoot.Position
				local p2 = target

				-- Control point: midpoint pushed upward for the arc
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
					-- Quadratic Bézier: (1-t)²P0 + 2(1-t)tP1 + t²P2
					bullet.Position = inv * inv * p0 + 2 * inv * v * p1 + v * v * p2
				end)
				t:onComplete(function()
					local vfx = self.unit.type == "tank" and ReplicatedStorage.VFX.MissileImpact
						or ReplicatedStorage.VFX.BulletImpact
					local expl = vfx:Clone()
					expl.CFrame = bullet.CFrame
					expl.Parent = workspace.Terrain

					for _, emitter in expl:GetChildren() do
						emitter = emitter :: ParticleEmitter
						emitter:Emit()
					end

					task.delay(1, function()
						expl:Destroy()
					end)

					muzzle:Destroy()
					bullet:Destroy()

					t:destroy()
				end)
			end)
				:andThen(function() end)
				:finally(function() end)

			return rs(self.movePromise)
		end)
	end,
	helicopter_autocannon = function(self: clientTypes.UnitData, target: Vector3)
		return Promise.new(function(rs)
			rs(print("autocannon not implemented"))
		end)
	end,
	helicopter_missiles = function(self: clientTypes.UnitData, target: Vector3)
		return Promise.new(function(rs)
			if self.movePromise and self.movePromise:getStatus() ~= "Cancelled" then
				self.movePromise:cancel()
			end

			if self.attackPromise and self.attackPromise:getStatus() ~= "Cancelled" then
				self.attackPromise:cancel()
			end

			self.attackPromise = Promise.new(function(resolve, reject, onCancel)
				self:faceTarget(target)

				task.delay(1 / self.unit.firerate + 0.1, function()
					resolve()
				end)

				local spread = 20
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

				local duration = (p2 - p0).Magnitude / 50

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
					local expl = ReplicatedStorage.VFX.MissileImpact:Clone()
					expl.CFrame = missile.CFrame
					expl.Parent = Workspace.Terrain

					for _, emitter in expl:GetChildren() do
						if emitter:IsA("ParticleEmitter") then
							emitter:Emit()
						end
					end

					task.delay(1, function()
						expl:Destroy()
					end)

					missile.Transparency = 1

					task.delay(1 / self.unit.firerate * 0.2, function()
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

			return rs(self.movePromise)
		end)
	end,
}

return Attack
