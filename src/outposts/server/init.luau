local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local CharmSync = require("@game/ReplicatedStorage/Packages/CharmSync")
local SMUnit = require("../units/server/unit")
local SMUnits = require("../units/server/stateMachineUnit")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local attribute = require("@game/ReplicatedStorage/src/accounts/shared/utils/attribute")
local fonts = require("@game/ReplicatedStorage/src/core/client/ui/utils/fonts")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local types = require("@game/ReplicatedStorage/src/outposts/shared/types")
local waitFor = require("@game/ReplicatedStorage/src/core/shared/waitFor")

local unitSpawnAttr = attribute<<string?>>("Unit", "gunner")
local outpostTitleAttr = attribute<<string?>>("Title", "Fortress")

local Outpost = {}
Outpost.__index = Outpost

type Status = "uncontested" | "contested" | "claimed"

type OutpostData = {
	root: Folder,
	guid: string,
	units: { SMUnit.SMUnit },
	spawners: { Part },
	colliders: { BasePart },

	visuals: {
		status: TextLabel,
		owner: TextLabel,
		object: TextLabel,
	},

	atoms: {
		owner: Charm.Atom<string>,
		status: Charm.Atom<Status>,
	},
}

export type Outpost = setmetatable<OutpostData, typeof(Outpost)>

function Outpost.new(guid: string, root: Folder): Outpost
	print("Init outpost", root)

	local self = setmetatable({} :: OutpostData, Outpost)

	self.guid = guid
	self.root = root
	self.spawners = {}
	self.colliders = {}

	self.atoms.owner = Charm.atom("")
	self.atoms.status = Charm.atom("uncontested" :: Status)

	-- self.visuals = {}

	-- Charm.effect(function()
	-- 	local owner = self.owner()
	-- 	if owner == "" then
	-- 		return
	-- 	end
	-- end)

	-- local statusColors: { [Status]: Color3 } = {
	-- 	uncontested = Color3.fromHex("#FFFFFF"),
	-- 	contested = Color3.fromHex("#FFFFFF"),
	-- 	claimed = Color3.fromHex("#FFFFFF"),
	-- }
	-- Charm.effect(function()
	-- 	local newStatus = self.status()
	-- 	waitFor.Descendant(self.root, "Status"):andThen(function(status: TextLabel)
	-- 		status.Text = string.upper(newStatus)
	-- 		status.TextColor3 = statusColors[newStatus]
	-- 	end)
	-- end)

	-- init unit spawners
	waitFor.Descendant(root, "Spawns"):andThen(function(spawns: Folder)
		for _, spawn in spawns:GetDescendants() do
			if not spawn:IsA("Part") then
				continue
			end
			spawn.Parent = nil
			table.insert(self.spawners, spawn)
		end

		local batchReplicate = {}
		for _, spawner in self.spawners do
			table.insert(
				batchReplicate,
				SMUnits:SpawnUnit({
					unitId = unitSpawnAttr.get(spawner) or "gunner",
					position = spawner.CFrame,
					replicate = false,
				})
			)
		end
		SMUnits:ReplicateUnits(batchReplicate)
	end)

	-- load colliders and env parts
	local env = root:FindFirstChild("Env") :: Folder
	for _, p in env:GetDescendants() do
		if not p:IsA("BasePart") then
			continue
		end

		p.Parent = Workspace.PVE:FindFirstChild("LineOfSightBlockers")
		if p.Name == "Collider" then
			p.Transparency = 1
			table.insert(self.colliders, p)
		end
	end

	-- load control stuff
	local title = outpostTitleAttr.get(self.root)
	waitFor.Descendant(root, "ControlPointOverhead"):andThen(function(obj)
		obj = obj :: BillboardGui

		waitFor.Descendants(obj, { "Status", "Owner", "Object" }):andThen(function(objs: { TextLabel })
			local status, owner, object = table.unpack(objs)

			status.FontFace = fonts.inter.bold
			owner.FontFace = fonts.inter.bold
			object.FontFace = fonts.inter.bold

			owner.Text = "UNCLAIMED"
			object.Text = title or "Unknown"
		end)
	end)

	waitFor.Descendants(root, { "FlagGui1", "FlagGui2" }):andThen(function(objs: { BillboardGui })
		local flagGui1, flagGui2 = table.unpack(objs)
	end)

	return self
end

function Outpost.snapshot(self: Outpost): types.OutpostSnapshot
	return {
		guid = self.guid,
		root = self.root,
		colliders = self.colliders,
	}
end

local Outposts = {}

function Outposts.init(self: Outposts)
	self.outposts = {}

	-- load outposts
	local Outposts = Workspace.Outposts
	for _, c in Outposts:GetChildren() do
		local guid = HttpService:GenerateGUID(false)
		self.outposts[guid] = Outpost.new(guid, c :: Folder)
	end

	-- charms

	-- network
	network.Outposts.RequestOutposts.OnServerEvent:Connect(function(plr: Player)
		network.Outposts.LoadOutposts:FireClient(
			plr,
			TableUtil.Map(TableUtil.Values(self.outposts), function(o: Outpost)
				return o:snapshot()
			end)
		)
	end)
end

type Outposts = typeof(Outposts) & {
	outposts: { [string]: Outpost },
}

return Outposts :: Outposts
