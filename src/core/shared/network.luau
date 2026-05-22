local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypedRemote = require(ReplicatedStorage.Packages.TypedRemote)
local types = require("../../plots/shared/types")

type RF<T..., R...> = TypedRemote.Function<T..., R...>
type RE<T...> = TypedRemote.Event<T...>
type URE<T...> = TypedRemote.UnreliableEvent<T...>

local RF, RE, URE = TypedRemote.parent()
return {
	Accounts = {
		Patch = RE("Patch") :: RE<any>,
	},
	Plots = {
		RequestPlot = RF("RequestPlot") :: RF<(), (types.PlotSnapshot?)>,
		PlaceBuilding = RF("PlaceBuilding") :: RF<(string, number, number), (boolean?)>,
	},
	Units = {
		RequestUnits = RE("RequestUnits") :: RE<>,
		LoadUnits = RE("LoadUnits") :: RE<any>,
		RequestPath = RE("RequestPath") :: RE<Vector3>,
		MoveUnit = RE("MoveUnit") :: RE<string, any>,
	},

	FireAllExcept = function(remote: any, plr: Player, ...)
		for _, p in Players:GetPlayers() do
			if p ~= plr then
				remote:FireClient(p, ...)
			end
		end
	end,
}
