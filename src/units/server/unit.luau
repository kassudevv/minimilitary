local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local TaskQueue = require("@game/ReplicatedStorage/src/core/shared/TaskQueue")
local attribute = require("@game/ReplicatedStorage/src/accounts/shared/utils/attribute")
local encoder = require("@game/ReplicatedStorage/src/units/shared/encoder")
local index = require("@game/ReplicatedStorage/src/units/shared/index")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local stateMachine = require("@game/ReplicatedStorage/src/units/shared/stateMachine")
local types = require("@game/ReplicatedStorage/src/units/shared/types")
local unitRaycast = require("@game/ReplicatedStorage/src/units/shared/unitRaycast")
local waitFor = require("@game/ReplicatedStorage/src/core/shared/waitFor")

local guidAttr = attribute<<string?>>("UnitGuid", "")

local bulkMoveQueue: any = TaskQueue.new(function(moves: { any })
	local parts = {}
	local cframes = {}
	for _, m in moves do
		table.insert(parts, m[1])
		table.insert(cframes, m[2])
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)

local SMUnit = {}
SMUnit.__index = SMUnit

type SMUnitData = {
	def: types.Unit,
	guid: string,
	id: number,
	owner: string,
	pawn: BasePart,
	stateMachine: stateMachine.StateMachine,
	pathfinder: Path,
	lastProjectileTs: number,

	health: number,
	damageQueue: { [number]: number },
	lastMoveInterruptTs: number,
	isThinking: boolean,
	nextActionTs: number,
}

export type SMUnit = setmetatable<SMUnitData, typeof(SMUnit)>
function SMUnit.new(def: types.Unit, owner: Player?, guid: string, position: CFrame, destroyCb: (SMUnit) -> ()): SMUnit
	local self = setmetatable({} :: SMUnitData, SMUnit)

	self.def = def
	self.guid = guid
	self.owner = owner and owner.Name or "pve"
	self.id = index.registerNew(guid)

	self.health = def.health
	self.damageQueue = {}
	self.lastMoveInterruptTs = 0
	self.nextActionTs = os.clock() + math.random() * 3

	self.stateMachine = stateMachine.new({
		state = "idle",
		data = {},
		handlers = {
			dead = {
				onEnter = function(prev)
					destroyCb(self)
				end,
				tick = function(dt) end,
				onExit = function(next) end,
			},
			idle = {
				onEnter = function(prev) end,
				tick = function(dt) end,
				onExit = function(next) end,
			},
			moving = {
				onEnter = function(prev)
					local state = self.stateMachine.data
					state.segment = 1
					state.distanceInSegment = 0
					state.accum = 0
				end,
				tick = function(delta)
					local state = self.stateMachine.data

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
					bulkMoveQueue:Add({ self.pawn, cf })
				end,
				onExit = function(next) end,
			},
			targeting = {
				onEnter = function(prev)
					self.stateMachine.data.start = 0
					self.stateMachine.data.isReadyToFire = false
				end,
				tick = function(dt)
					local target = self.stateMachine.data.target

					local distance = target.stateMachine.state ~= "dead"
							and unitRaycast.getPlanarDistance(self.pawn.Position, target.pawn.Position)
						or 0
					if target.stateMachine.state == "dead" or (distance > self.def.range) then
						self:replicatedTransition("idle" :: stateMachine.State, {})
						return
					end

					if os.clock() < self.stateMachine.data.firstShotTs then
						return
					end

					if
						not self.stateMachine.data.isReadyToFire
						and (os.clock() - self.lastProjectileTs) > 1 / self.def.firerate
					then
						self.stateMachine.data.isReadyToFire = true
						self.stateMachine.data.start = os.clock()
					end

					if self.stateMachine.data.isReadyToFire then
						if (os.clock() - self.stateMachine.data.start) < (self.def.shotDelay or 0) then
							return
						end

						if not self:hasLineOfSight(target) then
							self:replicatedTransition("idle" :: stateMachine.State, {})
							return
						end

						self.lastProjectileTs = self.stateMachine.data.start
						self.stateMachine.data.isReadyToFire = false

						target:addToDamageQueue(self.def.damage * (self.owner == "pve" and 0.002 or 1))
					end
				end,
				onExit = function(next) end,
			},
		},
	})
	self.stateMachine:transition("idle", {})

	self.lastProjectileTs = 0

	self.pathfinder = PathfindingService:CreatePath({
		AgentRadius = 4, -- Increases the NPC's collision footprint (default is 2)
		AgentHeight = 1,
		AgentCanJump = true,
		WaypointSpacing = 64,
	})

	self.pawn = Instance.new("Part") :: Part
	self.pawn.Anchored = true
	self.pawn.CFrame = position
	self.pawn.CanCollide = false
	self.pawn.Size = Vector3.new(1.5, 3, 1.5)
	self.pawn.Color = Color3.fromHex("#ffaa00")
	guidAttr.set(self.pawn, self.guid)

	local Camera = Workspace:FindFirstChild("Camera")
	if Camera then
		waitFor.Descendant(Camera, "NPCs"):andThen(function(NPCs: Folder)
			self.pawn.Parent = NPCs
		end)
	end

	return self
end

function SMUnit.snapshot(self: SMUnit): types.UnitSnapshot
	return {
		itemId = self.def.itemId,
		position = self.pawn.CFrame,
		guid = self.guid,
		owner = self.owner,
		id = self.id,
	}
end

function SMUnit.move(self: SMUnit, target: Vector3)
	if self.stateMachine.state == "dead" then
		return
	end

	self.isThinking = true
	self:replicatedTransition("idle")

	local wps: { Vector3 } = {}
	if self.def.movementMode == "flying" then
		table.insert(wps, self.pawn.Position)
		table.insert(wps, target)
	else
		self.pathfinder:ComputeAsync(self.pawn.Position, target)
		if self.pathfinder.Status ~= Enum.PathStatus.Success then
			print("Pathfinding fail: ", self.pathfinder.Status)
			self.isThinking = false
			return
		end

		local waypoints = self.pathfinder:GetWaypoints()
		for _, wp in waypoints do
			table.insert(wps, Vector3.new(wp.Position.X, wp.Position.Y, wp.Position.Z))
		end
	end

	for i, wp in wps do
		local params = unitRaycast.getRaycastParams()
		local rcResult = Workspace:Raycast(wp, -Vector3.yAxis * 30, params)
		if rcResult then
			wps[i] = Vector3.new(wp.X, rcResult.Position.Y, wp.Z)
		end
	end

	self:replicatedTransition("moving", {
		waypoints = encoder.encodeWaypoints(wps),
	})
	self.stateMachine.data.path = unitRaycast.buildPathData(wps)

	self.isThinking = false
end

function SMUnit.hasLineOfSight(self: SMUnit, target: SMUnit): boolean
	if
		table.find({ "helicopter", "plane" }, self.def.type or "troop")
		or table.find({ "helicopter", "plane" }, target.def.type or "troop")
	then
		return true
	end

	local from = self.pawn.Position + Vector3.new(0, 2, 0)
	local to = target.pawn.Position + Vector3.new(0, 2, 0)
	local delta = to - from

	if delta.Magnitude < 1 then
		return true
	end

	local losRc = Workspace:Raycast(from, delta, unitRaycast.getLosRaycastParams())
	return not losRc
end

function SMUnit.target(self: SMUnit, target: SMUnit)
	if self.stateMachine.state == "dead" then
		return
	end

	local firstShotDelay = math.random() * 0.35
	self:replicatedTransition("targeting", {
		target = target.id,
		firstShotDelay = firstShotDelay,
	})
	self.stateMachine.data.startTime = os.clock()
	self.stateMachine.data.firstShotTs = os.clock() + firstShotDelay
	self.stateMachine.data.target = target
end

function SMUnit.replicatedTransition(self: SMUnit, newState: stateMachine.State, data: { [string]: any })
	self.stateMachine:transition(newState, data)

	local encoded = encoder.encodeSM(self.id, newState)

	network.Units.ReplicateSM:FireAllClients(encoded, data)
end

function SMUnit.damage(self: SMUnit, amt: number)
	if self.stateMachine.state == "dead" then
		return
	end

	self.health -= amt
	network.Units.ReplicateHealth:FireAllClients(encoder.encodeHealth(self.id, self.health))

	if self.health <= 0 then
		print("do dead transition")
		self.replicatedTransition(self, "dead", {})
		return
	end

	if self.stateMachine.state == "moving" and os.clock() - self.lastMoveInterruptTs > 3 then
		self.lastMoveInterruptTs = os.clock()
		self.replicatedTransition(self, "idle", {})
	end
end

local damageQueueIncr: number = 0
function SMUnit.addToDamageQueue(self: SMUnit, amt: number)
	damageQueueIncr += 1
	local id = damageQueueIncr
	self.damageQueue[id] = amt

	task.delay(5, function()
		if self.damageQueue[id] then
			self.damageQueue[id] = nil
			self:damage(amt)
		end
	end)
end
function SMUnit.applyFromDamageQueue(self: SMUnit, amt: number)
	for i, nxt in self.damageQueue do
		self.damageQueue[i] = nil
		self:damage(amt)
		return
	end
end

function SMUnit.cleanup(self: SMUnit)
	self.pawn:Destroy()
end

return SMUnit
