--!nonstrict
local UpgradeConfig = require("./UpgradeConfig")
local store = require("../store")
local types = require("./types")

local DirectionOffsets = {
	Top = Vector2.new(0, -2),
	Bottom = Vector2.new(0, 2),
	Left = Vector2.new(-2, 0),
	Right = Vector2.new(2, 0),

	TopLeft = Vector2.new(-1, -1),
	TopRight = Vector2.new(1, -1),

	BottomLeft = Vector2.new(-1, 1),
	BottomRight = Vector2.new(1, 1),
}

local function getGridPositionKey(position: Vector2): string
	return `{position.X},{position.Y}`
end

local function verifyTree(nodesById)
	local issues = {}
	local roots = {}
	local occupiedPositions = {}

	local function addIssue(message: string)
		table.insert(issues, message)
	end

	for id, node in nodesById do
		if node.Id ~= id then
			addIssue(`Node "{node.Id}" is stored under key "{id}".`)
		end

		if node.ParentId then
			local parent = nodesById[node.ParentId]

			if not parent then
				addIssue(`Node "{node.Id}" connects from missing parent "{node.ParentId}".`)
			elseif node.Parent ~= parent then
				addIssue(`Node "{node.Id}" has ParentId "{node.ParentId}", but its Parent reference does not match.`)
			end

			if node.ParentId == node.Id then
				addIssue(`Node "{node.Id}" cannot be its own parent.`)
			end

			if not node.Location then
				addIssue(`Node "{node.Id}" connects from "{node.ParentId}" but has no Location.`)
			elseif not DirectionOffsets[node.Location] then
				addIssue(`Node "{node.Id}" has invalid Location "{node.Location}".`)
			end
		else
			table.insert(roots, node)
		end

		if typeof(node.GridPosition) ~= "Vector2" then
			addIssue(`Node "{node.Id}" has an invalid GridPosition.`)
		else
			local positionKey = getGridPositionKey(node.GridPosition)
			local existingNode = occupiedPositions[positionKey]

			if existingNode then
				addIssue(`Nodes "{existingNode.Id}" and "{node.Id}" collide at GridPosition {positionKey}.`)
			else
				occupiedPositions[positionKey] = node
			end
		end
	end

	if #roots == 0 then
		addIssue("Tree has no root node.")
	elseif #roots > 1 then
		local rootIds = {}

		for _, root in roots do
			table.insert(rootIds, root.Id)
		end

		addIssue(`Tree has multiple root nodes: {table.concat(rootIds, ", ")}.`)
	end

	for _, parent in nodesById do
		for _, child in parent.Children do
			if not child.Id or nodesById[child.Id] ~= child then
				addIssue(`Node "{parent.Id}" contains an unknown child reference.`)
			elseif child.Parent ~= parent then
				addIssue(`Node "{parent.Id}" lists "{child.Id}" as a child, but that child points to another parent.`)
			end
		end
	end

	local visiting = {}
	local visited = {}

	local function checkParentChain(node)
		if visiting[node] then
			addIssue(`Node "{node.Id}" is part of a parent cycle.`)
			return
		end

		if visited[node] then
			return
		end

		visiting[node] = true

		if node.Parent then
			checkParentChain(node.Parent)
		end

		visiting[node] = nil
		visited[node] = true
	end

	for _, node in nodesById do
		checkParentChain(node)
	end

	if #roots == 1 then
		local reachable = {}

		local function visitChildren(node)
			if reachable[node] then
				return
			end

			reachable[node] = true

			for _, child in node.Children do
				visitChildren(child)
			end
		end

		visitChildren(roots[1])

		for _, node in nodesById do
			if not reachable[node] then
				addIssue(`Node "{node.Id}" is not reachable from root "{roots[1].Id}".`)
			end
		end
	end

	if #issues > 0 then
		error("Invalid upgrade tree:\n- " .. table.concat(issues, "\n- "), 2)
	end
end

local cache: { [string]: any } = {}

local function compileTree(config: { types.Node }, page: string)
	if cache[page] then
		store.Research.items(cache[page])
		return cache[page]
	end

	local nodesById = {}

	for _, data in config do
		nodesById[data.Id] = {
			Id = data.Id,
			Location = data.Location,
			ParentId = data.ConnectsFromId,
			Children = {},
			GridPosition = Vector2.zero,
			Depth = 0,
			Data = data,
		}
	end

	-- First pass: wire up parents and compute depths only
	for _, node in nodesById do
		if node.ParentId then
			local parent = nodesById[node.ParentId]

			if parent then
				node.Parent = parent
				table.insert(parent.Children, node)
			end
		end
	end

	-- Compute depths from root downward
	local visitedDepthNodes = {}
	local function computeDepth(node, depth)
		if visitedDepthNodes[node] then
			return
		end

		visitedDepthNodes[node] = true
		node.Depth = depth

		for _, child in node.Children do
			computeDepth(child, depth + 1)
		end
	end

	-- Find roots (no parent) and recurse
	for _, node in nodesById do
		if not node.ParentId then
			computeDepth(node, 0)
		end
	end

	-- Second pass: sort by depth so parents are always resolved before children
	local ordered = {}
	for _, node in nodesById do
		table.insert(ordered, node)
	end
	table.sort(ordered, function(a, b)
		return a.Depth < b.Depth
	end)

	for _, node in ordered do
		if node.Parent then
			local offset = DirectionOffsets[node.Location]

			if offset then
				node.GridPosition = node.Parent.GridPosition + offset
			end
		end
	end

	verifyTree(nodesById)

	cache[page] = nodesById
	store.Research.items(nodesById)
	return nodesById
end

local function upgradeTreeSetPage(page: string)
	page = UpgradeConfig[page] and page or "main"
	compileTree(UpgradeConfig[page].Nodes, page)
end

return { upgradeTreeSetPage = upgradeTreeSetPage, verifyTree = verifyTree }
