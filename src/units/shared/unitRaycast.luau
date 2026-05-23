local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local types = require("./types")

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

function buildFormation(center: Vector3, units: { any }, padding: number): { Vector3 }
	local nodes: {
		{
			index: number,
			x: number,
			y: number,
			radius: number,
		}
	} = {}
	local positions: { Vector3 } = {}

	for i, unit in units do
		local angle = i * math.pi * 2 / math.max(#units, 1)
		local spawnRadius = math.sqrt(i) * 2

		table.insert(nodes, {
			index = i,
			x = math.cos(angle) * spawnRadius,
			y = math.sin(angle) * spawnRadius,
			radius = math.abs(unit.unit.boundsRadius),
		})
	end

	local function resolveCollisions(alpha: number)
		for i = 1, #nodes do
			local a = nodes[i]

			for j = i + 1, #nodes do
				local b = nodes[j]

				local dx = b.x - a.x
				local dy = b.y - a.y
				local dist = math.sqrt(dx * dx + dy * dy)
				local minDist = a.radius + b.radius + padding

				if dist < minDist then
					if dist <= 0.0001 then
						dx = math.random() - 0.5
						dy = math.random() - 0.5
						dist = math.sqrt(dx * dx + dy * dy)
					end

					local push = (minDist - dist) / dist * alpha
					local pushX = dx * push * 0.5
					local pushY = dy * push * 0.5

					a.x -= pushX
					a.y -= pushY
					b.x += pushX
					b.y += pushY
				end
			end
		end
	end

	local function pullToCenter(alpha: number)
		for _, node in nodes do
			node.x -= node.x * alpha
			node.y -= node.y * alpha
		end
	end

	for step = 1, 80 do
		local alpha = 1 - step / 80

		pullToCenter(0.03 * alpha)
		resolveCollisions(0.8)
	end

	for _, node in nodes do
		positions[node.index] = center + Vector3.new(node.x, 0, node.y)
	end

	return positions
end

local function getPathLength(waypoints: { Vector3 }): number
	local total = 0

	for i = 2, #waypoints do
		total += (waypoints[i] - waypoints[i - 1]).Magnitude
	end

	return total
end

local function samplePath(waypoints: { Vector3 }, distance: number): (Vector3, Vector3?)
	if #waypoints == 0 then
		return Vector3.zero, nil
	end

	if #waypoints == 1 then
		return waypoints[1], nil
	end

	local remaining = distance

	for i = 2, #waypoints do
		local a = waypoints[i - 1]
		local b = waypoints[i]
		local segment = b - a
		local length = segment.Magnitude

		if length <= 0.001 then
			continue
		end

		if remaining <= length then
			local alpha = remaining / length
			return a:Lerp(b, alpha), segment.Unit
		end

		remaining -= length
	end

	local last = waypoints[#waypoints]
	local prev = waypoints[#waypoints - 1]
	local dir = last - prev

	return last, dir.Magnitude > 0.001 and dir.Unit or nil
end

local function calculateGroundOffset(model: Model): number
	local pivot = model:GetPivot()
	local boxCFrame, boxSize = model:GetBoundingBox()

	local bottomY = boxCFrame.Position.Y - boxSize.Y / 2
	local pivotY = pivot.Position.Y

	return pivotY - bottomY
end

local function setUnitPositionWithOrientationFromSampledPath(
	pawn: BasePart | Model,
	waypoints: { Vector3 },
	distance: number,
	pOffset: number?
)
	local offset: number = pOffset or 1.7
	local pos = samplePath(waypoints, distance)

	local pawnPos = Vector3.new(pos.X, pos.Y + offset, pos.Z)
	local nextPos = samplePath(waypoints, (distance + 0.05))
	local dir2 = nextPos - pos

	if dir2.Magnitude > 0 then
		local dir3 = Vector3.new(dir2.X, 0, dir2.Z).Unit

		if pawn:IsA("Model") then
			pawn:PivotTo(CFrame.lookAt(pawnPos, pawnPos + dir3))
		else
			pawn.CFrame = CFrame.lookAt(pawnPos, pawnPos + dir3)
		end
	else
		if pawn:IsA("Model") and pawn.PrimaryPart then
			local rot = pawn.PrimaryPart.CFrame.Rotation
			pawn:PivotTo(CFrame.new(pawnPos) * rot)
		else
			pawn.Position = pawnPos
		end
	end
end

return {
	initRaycastParams = initRaycastParams,
	getRaycastParams = getRaycastParams,
	buildFormation = buildFormation,
	getPathLength = getPathLength,
	samplePath = samplePath,
	setUnitPositionWithOrientationFromSampledPath = setUnitPositionWithOrientationFromSampledPath,
	calculateGroundOffset = calculateGroundOffset,
}
