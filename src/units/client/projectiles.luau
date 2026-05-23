local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Promise = require("../../../Packages/PromiseTyped")
local Ripple = require("../../../Packages/Ripple")
local clientTypes = require("./clientTypes")
local network = require("../../core/shared/network")

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
				local vfx = self.def.type == "tank" and ReplicatedStorage.VFX.MissileImpact
					or ReplicatedStorage.VFX.BulletImpact
				local expl = vfx:Clone()
				expl.CFrame = bullet.CFrame
				expl.Parent = workspace.Terrain
				for _, emitter in expl:GetChildren() do
					emitter = emitter :: ParticleEmitter
					emitter:Emit()
				end
				Debris:AddItem(expl, 3)
				Debris:AddItem(muzzle, 3)
				Debris:AddItem(bullet, 3)

				resolve()

				t:destroy()
			end)
		end)
	end,
}

return Projectiles
