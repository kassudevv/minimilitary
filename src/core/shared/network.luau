local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypedRemote = require(ReplicatedStorage.Packages.TypedRemote)
local types = require("../../plots/shared/types")
local unitTypes = require("../../units/shared/types")

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
		RequestUnits = RE("RequestUnits") :: RE<>, -- player loaded into plot, spawn units

		LoadUnits = RE("LoadUnits") :: RE<any>, -- replicate unit to client
		DestroyUnits = RE("DestroyUnits") :: RE<{ string }>, -- remove unit from client

		RequestPath = RE("RequestPath") :: RE<Vector3>, -- request unit pathfinding target
		MoveUnit = RE("MoveUnit") :: RE<string, any>, -- replicate unit moveTo waypoints

		StartTargeting = RE("StartTargeting") :: RE<string, string>, -- replicates targeting for clients
		ApplyPendingHit = RE("ApplyPendingHit") :: RE<string>,
	},

	FireAllExcept = function(remote: any, plr: Player, ...)
		for _, p in Players:GetPlayers() do
			if p ~= plr then
				remote:FireClient(p, ...)
			end
		end
	end,
}
