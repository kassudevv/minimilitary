local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local CharmSync = require("@game/ReplicatedStorage/Packages/CharmSync")
local Ripple = require("@game/ReplicatedStorage/Packages/Ripple")
local SMUnit = require("../units/server/unit")
local SMUnits = require("../units/server/stateMachineUnit")
local TableUtil = require("@game/ReplicatedStorage/Packages/TableUtil")
local Tick = require("@game/ReplicatedStorage/src/core/shared/Tick")
local attribute = require("@game/ReplicatedStorage/src/accounts/shared/utils/attribute")
local flags = require("@game/ReplicatedStorage/src/units/client/flags")
local fonts = require("@game/ReplicatedStorage/src/core/client/ui/utils/fonts")
local network = require("@game/ReplicatedStorage/src/core/shared/network")
local types = require("@game/ReplicatedStorage/src/outposts/shared/types")
local waitFor = require("@game/ReplicatedStorage/src/core/shared/waitFor")

local unitSpawnAttr = attribute<<string?>>("Unit", "gunner")
local outpostTitleAttr = attribute<<string?>>("Title", "Fortress")
local guidAttr = attribute<<string?>>("UnitGuid", "")

local CAPTURE_TIME = 1

local Outpost = {}
Outpost.__index = Outpost

type Status = types.Status

type OutpostData = {
	root: Folder,
	guid: string,

	spawners: { [Part]: { units: { SMUnit.SMUnit }, pendingRespawn: boolean } },
	colliders: { BasePart },

	atoms: {
		owner: Charm.Atom<string>,
		status: Charm.Atom<Status>,
		captureProgress: Charm.Atom<number>,
	},

	units: { [string]: SMUnit.SMUnit },

	capturePoint: Vector3,
}

export type Outpost = setmetatable<OutpostData, typeof(Outpost)>

function Outpost.new(guid: string, root: Folder): Outpost
	print("Init outpost", root)

	local self = setmetatable({} :: OutpostData, Outpost)

	self.guid = guid
	self.root = root
	self.spawners = {}
	self.colliders = {}

	self.units = {}

	self.atoms = {
		owner = Charm.atom(types.outpostTemplate.owner),
		status = Charm.atom(types.outpostTemplate.status),
		captureProgress = Charm.atom(types.outpostTemplate.captureProgress),
	}

	Charm.effect(function()
		local owner = self.atoms.owner()

		waitFor.Descendants(root, { "FlagImg", "FlagImg2" }):andThen(function(objs: { ImageLabel })
			local code = "XX"

			local plr: Player = Players:FindFirstChild(owner) :: Player
			if owner ~= "pve" and plr then
				local result, nCode =
					pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, plr)
				if result then
					code = nCode
				end
			end

			local img = (flags.get(code) or flags.flags.US).Flag
			for _, o in objs do
				o.Image = `rbxassetid://{img}`
			end
		end)
	end)

	-- init unit spawners
	waitFor.Descendant(root, "Spawns"):andThen(function(spawns: Folder)
		for _, spawn in spawns:GetDescendants() do
			if not spawn:IsA("Part") then
				continue
			end
			spawn.Parent = nil
			self.spawners[spawn] = { units = {}, pendingRespawn = false }
		end
	end)

	-- init capture circle
	waitFor.Descendant(root, "CaptureMesh"):andThen(function(obj: Part)
		CollectionService:AddTag(obj, "NoUnitRaycast")
		self.capturePoint = obj.Position
	end)

	-- load colliders and env parts
	waitFor.Descendant(Workspace, "LineOfSightBlockers"):andThen(function(LOSBlockers: Folder)
		local env = root:FindFirstChild("Env") :: Folder
		for _, p in env:GetDescendants() do
			if not p:IsA("BasePart") then
				continue
			end

			p.Parent = LOSBlockers
			if p.Name == "Collider" then
				p.Transparency = 1
				table.insert(self.colliders, p)
			end
		end
	end)

	-- load control stuff
	local title = outpostTitleAttr.get(self.root)

	waitFor.Descendants(self.root, { "Owner", "Object" }):andThen(function(objs: { TextLabel })
		local owner, object = table.unpack(objs)

		owner.FontFace = fonts.inter.bold
		object.FontFace = fonts.inter.bold
		object.Text = title or "Undefined"
	end)

	self:spawnUnits()

	return self
end

function Outpost.spawnUnits(self: Outpost)
	local batchReplicate = {}
	for spawner, data in self.spawners do
		local unit = SMUnits:SpawnUnit({
			unitId = unitSpawnAttr.get(spawner) or "gunner",
			position = spawner.CFrame,
			replicate = false,
		})
		table.insert(batchReplicate, unit)
		table.insert(data.units, unit)
	end
	SMUnits:ReplicateUnits(batchReplicate)
end

local NPCOverlapParams = OverlapParams.new()
function Outpost.tick(self: Outpost, elapsed: number)
	self:tickCaptureProgress(elapsed)

	local alive = 0
	for i, s in self.spawners do
		for _, u in s.units do
			if not u or u.stateMachine.state == "dead" then
				table.remove(self.spawners[i].units, table.find(self.spawners[i].units, u))
			else
				alive += 1
			end
		end
	end

	for s, u in self.spawners do
		if #u.units == 0 and not u.pendingRespawn then
			u.pendingRespawn = true
			task.delay(math.random(10, 15), function()
				table.insert(
					u.units,
					SMUnits:SpawnUnit({
						unitId = unitSpawnAttr.get(s) or "gunner",
						position = s.CFrame,
						replicate = false,
					})
				)
			end)
		end
	end
end

function Outpost.tickCaptureProgress(self: Outpost, elapsed: number)
	local pawns = Workspace:GetPartBoundsInRadius(self.capturePoint, 75, NPCOverlapParams)

	local overlappingByPlayer: { [string]: { SMUnit.SMUnit } } = {}
	for _, pawn in pawns do
		local guid = guidAttr.get(pawn)
		if not guid then
			continue
		end

		local unit = SMUnits.units[guid]

		if not overlappingByPlayer[unit.owner] then
			overlappingByPlayer[unit.owner] = {}
		end

		table.insert(overlappingByPlayer[unit.owner], unit)
	end

	local contestingPlrs = TableUtil.Keys(overlappingByPlayer)
	if #contestingPlrs > 1 then
		self.atoms.status("contested")
	elseif #contestingPlrs == 1 then
		local plr = contestingPlrs[1]

		if self.atoms.owner() ~= plr then
			if self.atoms.captureProgress() > 0 then
				self.atoms.status("neutralizing")
			else
				self.atoms.status("capturing")
				self.atoms.owner(plr)
			end
		else
			self.atoms.status("capturing")
		end
	else
		self.atoms.status("idle")
	end

	local status = self.atoms.status()
	if status == "neutralizing" then
		if self.atoms.captureProgress() == 0 then
			self.atoms.status("capturing")
			return
		end

		self.atoms.captureProgress(function(curr: number)
			return math.max(curr - (1 / CAPTURE_TIME / 2 * elapsed), 0)
		end)
	elseif status == "capturing" then
		if self.atoms.captureProgress() == 2 then
			self.atoms.status("idle")
			return
		end

		self.atoms.captureProgress(function(curr: number)
			return math.min(curr + (1 / CAPTURE_TIME / 2 * elapsed), 2)
		end)
	end
end

function Outpost.getSyncAtoms(self: Outpost)
	return {
		owner = self.atoms.owner,
		status = self.atoms.status,
		captureProgress = self.atoms.captureProgress,
	}
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

	local Camera = Workspace:WaitForChild("Camera")
	if Camera then
		waitFor.Descendant(Camera, "NPCs"):andThen(function(NPCs: Folder)
			NPCOverlapParams.FilterType = Enum.RaycastFilterType.Include
			NPCOverlapParams.FilterDescendantsInstances = { NPCs }
		end)
	end

	-- load outposts
	local Outposts = Workspace:WaitForChild("Outposts")
	for _, c in Outposts:GetChildren() do
		local guid = HttpService:GenerateGUID(false)
		self.outposts[guid] = Outpost.new(guid, c :: Folder)
	end

	Tick.every(1, function(dt)
		for _, o in self.outposts do
			o:tick(dt)
		end
	end)

	-- charms
	local syncAtoms = {}

	for guid, outpost in self.outposts do
		syncAtoms[`outpost-{guid}`] = Charm.computed(function()
			return {
				owner = outpost.atoms.owner(),
				status = outpost.atoms.status(),
				captureProgress = outpost.atoms.captureProgress(),
			}
		end)
	end

	-- network
	network.Outposts.RequestOutposts.OnServerEvent:Connect(function(plr: Player)
		network.Outposts.LoadOutposts:FireClient(
			plr,
			TableUtil.Map(TableUtil.Values(self.outposts :: any), function(o: Outpost): types.OutpostSnapshot
				return o:snapshot()
			end)
		)

		CharmSync.server.addSignalsToClient(plr, syncAtoms)
	end)
end

type Outposts = typeof(Outposts) & {
	outposts: { [string]: Outpost },
}

return Outposts :: Outposts
