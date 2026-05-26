local Players = game:GetService("Players")
local Charm = require("../../Packages/Charm")
local CharmSync = require("../../Packages/CharmSync")
local Ripple = require("../../Packages/Ripple")
local TableUtil = require("../../Packages/TableUtil")
local network = require("../core/shared/network")
local types = require("./shared/types")
local waitFor = require("../core/shared/waitFor")

local Outpost = {}
Outpost.__index = Outpost

type OutpostData = {
	root: Model,
	setState: any,
	getState: any,
}

export type Outpost = setmetatable<OutpostData, typeof(Outpost)>

function Outpost.new(snapshot: types.OutpostSnapshot): Outpost
	local self = setmetatable({} :: OutpostData, Outpost)

	self.getState, self.setState = Charm.signal(types.outpostTemplate)

	local err, root: Model = waitFor.Descendant(workspace, snapshot.rootName):await()
	self.root = root

	local flagTween = Ripple.createTween(
		0,
		{
			easing = "linear",
			duration = 1,
			start = true,
		} :: Ripple.TweenOptions
	)

	local prev: types.Outpost?
	Charm.effect(function()
		local state = self.getState() :: types.Outpost

		flagTween:setGoal(math.abs((state.captureProgress / 2) - 1) * 15)

		task.defer(function()
			prev = state
		end)
	end)

	waitFor.Descendant(self.root, "Env"):andThen(function(env: Model)
		for _, p in env:GetDescendants() do
			if not p:IsA("BasePart") then
				continue
			end

			if p.Name == "Collider" then
				p.Transparency = 1
				p.CanCollide = false
			end
		end
	end)

	local colors: { [string]: Color3 } = {
		green = Color3.fromHex("#00ff77"),
		orange = Color3.fromHex("#ffb300"),
		red = Color3.fromHex("#ff0000"),
	}

	waitFor.Descendants(self.root, { "CaptureBeam", "CaptureMesh", "Owner" }):andThen(function(obj: { any })
		local captureBeam = obj[1] :: Beam
		local captureMesh = obj[2] :: MeshPart
		local ownerLbl = obj[3] :: TextLabel

		Charm.effect(function()
			local state = self.getState() :: types.Outpost

			if state.status == "idle" then
				if state.captureProgress == 2 and state.owner ~= "pve" then
					ownerLbl.Text = string.upper(state.owner)
					ownerLbl.TextColor3 = state.owner == Players.LocalPlayer.Name and colors.green or colors.red
				else
					ownerLbl.Text = "UNCLAIMED"
					ownerLbl.TextColor3 = colors.red
				end
			else
				ownerLbl.Text = "CONTESTED"
				ownerLbl.TextColor3 = colors.orange
			end

			if state.owner == Players.LocalPlayer.Name and state.captureProgress == 2 then
				captureMesh.Color = colors.green
				captureBeam.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, colors.green),
					ColorSequenceKeypoint.new(1, colors.green),
				})
			elseif state.status == "capturing" or state.status == "contested" or state.status == "neutralizing" then
				captureMesh.Color = colors.orange
				captureBeam.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, colors.orange),
					ColorSequenceKeypoint.new(1, colors.orange),
				})
			else
				captureMesh.Color = colors.red
				captureBeam.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, colors.red),
					ColorSequenceKeypoint.new(1, colors.red),
				})
			end
		end)
	end)
	-- init flag visuals
	waitFor.Descendant(self.root, "Flag"):andThen(function(obj: Part)
		local basePosition = obj.Position
		flagTween:onChange(function(value, dt)
			obj.Position = basePosition - Vector3.new(0, value, 0)
		end)
	end)

	return self
end

local Outposts = {}

function Outposts.init(self: Outposts)
	self.outposts = {}
	network.Outposts.RequestOutposts:FireServer()
	network.Outposts.LoadOutposts.OnClientEvent:Connect(function(outposts: { types.OutpostSnapshot })
		for _, outpost in outposts do
			local newOutpost = Outpost.new(outpost)
			table.insert(self.outposts, newOutpost)

			CharmSync.client.addSignals({
				[`outpost-{outpost.guid}`] = newOutpost.setState,
			})
		end
	end)
end

type Outposts = typeof(Outposts) & {

	outposts: { Outpost },
}

return Outposts :: Outposts
