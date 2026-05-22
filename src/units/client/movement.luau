local RunService = game:GetService("RunService")
local Promise = require("../../../Packages/PromiseTyped")
local clientTypes = require("./clientTypes")

local GLOBAL_SPEED_MULT = 1

local Movement: { [string]: (clientTypes.UnitData, Vector3) -> typeof(Promise.new(function() end)) } = {}

Movement = {
	default = function(self: clientTypes.UnitData, target: Vector3)
		return Promise.new(function(rs)
			if self.movePromise and self.movePromise:getStatus() ~= "Cancelled" then
				self.movePromise:cancel()
			end

			self.movePromise = Promise.new(function(resolve, reject, onCancel)
				self:playAnimation("RunAnim")

				local root = self.model.PrimaryPart :: BasePart
				if (root.Position - target).Magnitude < 1 then
					return reject()
				end

				local pos = root.Position
				self.pathfinder:ComputeAsync(pos, target)
				if self.pathfinder.Status ~= Enum.PathStatus.Success then
					return reject()
				end

				local waypoints = self.pathfinder:GetWaypoints()

				---do move
				local wpIdx = 1
				local wpCount = #waypoints
				local wpStart: Vector3 = root.Position
				local elapsed = 0

				while waypoints[wpIdx] and (waypoints[wpIdx].Position - root.Position).Magnitude < 5 do
					wpIdx += 1
				end

				local groundY = waypoints[wpIdx]
						and self:raycastGround(waypoints[wpIdx].Position + Vector3.new(0, 2, 0)).Y
					or wpStart.Y

				return resolve(Promise.new(function(resolve, reject, onCancel)
					local conn: RBXScriptConnection
					conn = RunService.Heartbeat:Connect(function(dt)
						elapsed += dt

						if wpIdx > wpCount then
							conn:Disconnect()
							return resolve("Finished movement")
						end

						local wp = waypoints[wpIdx]
						local wpPos = wp.Position

						local diff = wpPos - wpStart
						local dist = diff.Magnitude
						local dur = dist / (self.unit.speed * GLOBAL_SPEED_MULT)

						local alpha = math.clamp(elapsed / dur, 0, 1)

						local flatDir = Vector3.new(diff.X, 0, diff.Z)
						local lerped = wpStart:Lerp(wpPos, alpha)
						root.CFrame = CFrame.lookAt(
							Vector3.new(lerped.X, groundY, lerped.Z),
							Vector3.new(lerped.X, groundY, lerped.Z) + flatDir.Unit
						)

						if alpha == 1 then
							wpIdx += 1

							if waypoints[wpIdx] then
								wpStart = wpPos
								elapsed = 0
								groundY = self:raycastGround(waypoints[wpIdx].Position + Vector3.new(0, 1, 0)).Y
							end
						end
					end)

					onCancel(function()
						conn:Disconnect()
					end)
				end))
			end)
				:andThen(function() end)
				:finally(function()
					self:stopAnimation("RunAnim")
				end)

			return rs(self.movePromise)
		end)
	end,
	helicopter = function(self: clientTypes.UnitData, target: Vector3)
		return Promise.new(function(rs)
			if self.movePromise and self.movePromise:getStatus() ~= "Cancelled" then
				self.movePromise:cancel()
			end

			self.movePromise = Promise.new(function(resolve, reject, onCancel)
				local Y_OFFSET = 16
				local airTarget = Vector3.new(target.X, Y_OFFSET, target.Z)

				local root = self.model.PrimaryPart :: BasePart
				if (root.Position - airTarget).Magnitude < 1 then
					return reject()
				end

				self:playAnimation("RunAnim")

				local start = root.Position
				local diff = airTarget - start
				local dist = diff.Magnitude
				local elapsed = 0

				return resolve(Promise.new(function(resolve, _, onCancel)
					local conn: RBXScriptConnection
					conn = RunService.Heartbeat:Connect(function(dt)
						elapsed += dt

						local dur = dist / (self.unit.speed * GLOBAL_SPEED_MULT)
						local alpha = math.clamp(elapsed / dur, 0, 1)

						local flatDir = Vector3.new(diff.X, 0, diff.Z)
						local lerped = start:Lerp(airTarget, alpha)

						if alpha == 1 then
							conn:Disconnect()
							return resolve("Finished movement")
						end

						root.CFrame = CFrame.lookAt(
							Vector3.new(lerped.X, Y_OFFSET, lerped.Z),
							Vector3.new(lerped.X, Y_OFFSET, lerped.Z) + flatDir.Unit
						)
					end)

					onCancel(function()
						conn:Disconnect()
					end)
				end))
			end)
				:andThen(function() end)
				:finally(function()
					self:stopAnimation("RunAnim")
				end)

			return rs(self.movePromise)
		end)
	end,
}
return Movement
