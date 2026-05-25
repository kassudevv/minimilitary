local network = require("../core/shared/network")
local types = require("./shared/types")

local Outpost = {}
Outpost.__index = Outpost

type OutpostData = {}

export type Outpost = setmetatable<OutpostData, typeof(Outpost)>

function Outpost.new(snapshot: types.OutpostSnapshot): Outpost
	local self = setmetatable({} :: OutpostData, Outpost)

	for _, c in snapshot.colliders do
		c.CanCollide = false
	end

	return self
end

local Outposts = {}

function Outposts.init(self: Outposts)
	self.outposts = {}
	network.Outposts.RequestOutposts:FireServer()
	network.Outposts.LoadOutposts.OnClientEvent:Connect(function(outposts: { types.OutpostSnapshot })
		for _, outpost in outposts do
			print("Outpost: ", outpost)
			table.insert(self.outposts, Outpost.new(outpost))
		end
	end)
end

type Outposts = typeof(Outposts) & {

	outposts: { Outpost },
}

return Outposts :: Outposts
