local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local waitFor = require("../../core/shared/waitFor")

local losParams = RaycastParams.new()
local losInitialized = false

local function initLosRaycastParams()
	if losInitialized then
		return
	end
	losInitialized = true

	local blockers = Workspace.PVE:WaitForChild("LineOfSightBlockers")

	local function refresh()
		losParams.FilterType = Enum.RaycastFilterType.Include
		losParams.FilterDescendantsInstances = { blockers }
	end

	refresh()

	-- re-include if folder is replaced entirely (edge case)
	Workspace.PVE.ChildAdded:Connect(function(child)
		if child.Name == "LineOfSightBlockers" then
			refresh()
		end
	end)
end

local function getLosRaycastParams(): RaycastParams
	return losParams
end

local raycastParams = RaycastParams.new()

local function getRaycastParams(): RaycastParams
	return raycastParams
end

local initialized = false
local ignored: { [Instance]: boolean } = {}
local playerCharacters: { [Player]: Model? } = {}

local function refreshRaycastParams()
	local exclude: { Instance } = {}
	for instance in ignored do
		table.insert(exclude, instance)
	end

	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = exclude
end

local function addIgnored(instance: Instance?)
	if not instance then
		return
	end

	ignored[instance] = true
	refreshRaycastParams()
end

local function removeIgnored(instance: Instance?)
	if not instance then
		return
	end

	ignored[instance] = nil
	refreshRaycastParams()
end

local function trackPlayer(player: Player)
	local function setCharacter(character: Model)
		removeIgnored(playerCharacters[player])
		playerCharacters[player] = character
		addIgnored(character)
	end

	if player.Character then
		setCharacter(player.Character)
	end

	player.CharacterAdded:Connect(setCharacter)
	player.CharacterRemoving:Connect(function(character)
		if playerCharacters[player] == character then
			playerCharacters[player] = nil
		end

		removeIgnored(character)
	end)
end

local CollectionService = game:GetService("CollectionService")
local IGNORE_TAG = "NoUnitRaycast"

local function initTaggedIgnored()
	for _, instance in CollectionService:GetTagged(IGNORE_TAG) do
		addIgnored(instance)
	end

	CollectionService:GetInstanceAddedSignal(IGNORE_TAG):Connect(addIgnored)
	CollectionService:GetInstanceRemovedSignal(IGNORE_TAG):Connect(removeIgnored)
end

local function initRaycastParams()
	if initialized then
		refreshRaycastParams()
		return
	end
	initialized = true

	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local npcs = Workspace:WaitForChild("NPCs")
	for _, npc in npcs:GetChildren() do
		addIgnored(npc)
	end

	for _, p in Workspace.Camera:GetChildren() do
		addIgnored(p)
	end
	Workspace.Camera.ChildAdded:Connect(function(npc)
		addIgnored(npc)
	end)
	Workspace.Camera.ChildRemoved:Connect(function(npc)
		removeIgnored(npc)
	end)

	npcs.ChildAdded:Connect(function(npc)
		addIgnored(npc)
	end)
	npcs.ChildRemoved:Connect(function(npc)
		removeIgnored(npc)
	end)

	waitFor.Descendant(Workspace, "LineOfSightBlockers"):andThen(function(obj: Folder)
		for _, p in obj:GetDescendants() do
			addIgnored(p)
		end
		obj.ChildAdded:Connect(function(npc)
			addIgnored(npc)
		end)
		obj.ChildRemoved:Connect(function(npc)
			removeIgnored(npc)
		end)
	end)

	initTaggedIgnored()

	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end

	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(function(player)
		removeIgnored(playerCharacters[player])
		playerCharacters[player] = nil
	end)

	refreshRaycastParams()
end

function buildFormation(center: Vector3, amt: number, padding: number): { Vector3 }
	local positions: { Vector3 } = {}

	local spacing: number = 5 + padding
	local width: number = math.ceil(math.sqrt(amt))

	for i = 1, amt do
		local row = math.floor((i - 1) / width)
		local col = (i - 1) % width

		local x = (col - width / 2) * spacing
		local z = row * spacing

		positions[i] = center + Vector3.new(x, 0, z)
	end

	return positions
end

local function calculateGroundOffset(model: Model, scale: number): number
	model:ScaleTo(scale)
	local pivot = model:GetPivot()
	local boxCFrame, boxSize = model:GetBoundingBox()

	local bottomY = boxCFrame.Position.Y - boxSize.Y / 2
	local pivotY = pivot.Position.Y

	return pivotY - bottomY
end

export type Path = {
	segments: { { a: Vector3, b: Vector3, dir: Vector3, length: number, cumulative: number } },
	totalLength: number,
}

@native
local function buildPathData(waypoints: { Vector3 }): Path
	local segments: { { a: Vector3, b: Vector3, dir: Vector3, length: number, cumulative: number } } = {}
	local total: number = 0

	for i = 2, #waypoints do
		local a: Vector3 = waypoints[i - 1]
		local b: Vector3 = waypoints[i]

		local delta = (b - a)
		local length = delta.Magnitude

		segments[i - 1] = {
			a = a,
			b = b,
			dir = delta / length,
			length = length,
			cumulative = total,
		}

		total += length
	end

	return {
		segments = segments,
		totalLength = total,
	}
end

@native
local function closestPointOnCircle(
	center: Vector3, -- enemy position
	radius: number, -- max_range in world units
	point: Vector3 -- your unit's position
): Vector3
	local dir = point - center

	-- If the unit is exactly on top of the enemy (degenerate case),
	-- just pick an arbitrary direction
	if dir.Magnitude < 0.001 then
		dir = Vector3.new(1, 0, 0)
	end

	-- Normalize then scale to radius — that lands you ON the circle
	return center + dir.Unit * radius
end

local function hasLineOfSight(from: Vector3, to: Vector3): boolean
	local origin = from + Vector3.new(0, 2, 0)
	local target = to + Vector3.new(0, 2, 0)
	local delta = target - origin

	if delta.Magnitude < 0.001 then
		return true
	end

	local result = Workspace:Raycast(origin, delta, getLosRaycastParams())

	-- Because your raycast params exclude NPCs / player characters,
	-- a clear shot should return nil. Anything hit is cover/terrain.
	return result == nil
end

local function closestPointOnCircleWithLos(center: Vector3, radius: number, point: Vector3): Vector3?
	local samples = 8

	local closest = closestPointOnCircle(center, radius, point)

	if hasLineOfSight(closest, center) then
		return closest
	end

	local dir = point - center
	local baseAngle = math.atan2(dir.Z, dir.X)

	local bestPoint: Vector3? = nil
	local bestDist = math.huge

	for i = 1, samples do
		local side = if i % 2 == 0 then 1 else -1
		local step = math.ceil(i / 2)
		local angleOffset = (step / samples) * math.pi * 2 * side
		local angle = baseAngle + angleOffset

		local candidate = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		if hasLineOfSight(candidate, center) then
			local dist = (candidate - point).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestPoint = candidate
			end
		end
	end

	return bestPoint
end

@native
function getPlanarDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z

	return math.sqrt(dx * dx + dz * dz)
end

return {
	initRaycastParams = initRaycastParams,
	getRaycastParams = getRaycastParams,
	initLosRaycastParams = initLosRaycastParams,
	getLosRaycastParams = getLosRaycastParams,

	buildFormation = buildFormation,

	calculateGroundOffset = calculateGroundOffset,
	closestPointOnCircle = closestPointOnCircle,
	closestPointOnCircleWithLos = closestPointOnCircleWithLos,

	getPlanarDistance = getPlanarDistance,
	buildPathData = buildPathData,
}
