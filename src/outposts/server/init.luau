local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local SMUnit = require("../units/server/unit")
local SMUnits = require("../units/server/stateMachineUnit")
local attribute = require("@game/ReplicatedStorage/src/accounts/shared/utils/attribute")
local draw = require("@game/ReplicatedStorage/src/core/shared/draw")
local fonts = require("@game/ReplicatedStorage/src/core/client/ui/utils/fonts")
local waitFor = require("@game/ReplicatedStorage/src/core/shared/waitFor")

local unitSpawnAttr = attribute<<string?>>("Unit", "gunner")

local Outpost = {}
Outpost.__index = Outpost

type OutpostData = {
	root: Folder,
	guid: string,
	units: { SMUnit.SMUnit },
}

export type Outpost = setmetatable<OutpostData, typeof(Outpost)>

function Outpost.new(guid: string, root: Folder): Outpost
	print("Init outpost", root)

	local self = setmetatable({} :: OutpostData, Outpost)

	self.guid = guid
	self.root = root

	waitFor.Descendant(root, "Spawns"):andThen(function(spawns: Folder)
		local batchReplicate = {}
		for _, spawn in spawns:GetDescendants() do
			if not spawn:IsA("Part") then
				continue
			end
			spawn.Parent = workspace.Camera

			table.insert(
				batchReplicate,
				SMUnits:SpawnUnit({
					unitId = unitSpawnAttr.get(spawn) or "gunner",
					position = spawn.CFrame,
					replicate = false,
				})
			)

			-- draw.text(
			-- 	spawn.Position + Vector3.new(0, 10, 0),
			-- 	`{unitSpawnAttr.get(spawn) or "attr missing"}`,
			-- 	Color3.fromHex("#000000")
			-- )
		end
		SMUnits:ReplicateUnits(batchReplicate)
	end)

	local env = root:FindFirstChild("Env") :: Folder
	for _, p in env:GetDescendants() do
		if p:IsA("BasePart") then
			p.Parent = Workspace.PVE:FindFirstChild("LineOfSightBlockers")
		end
	end

	waitFor.Descendant(root, "ControlPointOverhead"):andThen(function(obj)
		obj = obj :: BillboardGui

		waitFor.Descendants(obj, { "Status", "Owner", "Object" }):andThen(function(objs: { TextLabel })
			local status, owner, object = table.unpack(objs)

			status.FontFace = fonts.inter.bold
			owner.FontFace = fonts.inter.bold
			object.FontFace = fonts.inter.bold

			owner.Text = "UNCLAIMED"
			object.Text = "Lv.1 Fortress"
		end)
	end)

	waitFor.Descendants(root, { "FlagGui1", "FlagGui2" }):andThen(function(objs: { BillboardGui })
		local flagGui1, flagGui2 = table.unpack(objs)
	end)

	return self
end
local Outposts = {}

function Outposts.init(self: Outposts)
	self.outposts = {}

	local Outposts = Workspace.Outposts
	for _, c in Outposts:GetChildren() do
		local guid = HttpService:GenerateGUID(false)
		self.outposts[guid] = Outpost.new(guid, c :: Folder)
	end
end

type Outposts = typeof(Outposts) & {
	outposts: { [string]: Outpost },
}

return Outposts :: Outposts
