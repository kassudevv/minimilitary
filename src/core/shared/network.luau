local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypedRemote = require(ReplicatedStorage.Packages.TypedRemote)
local plotTypes = require("../../plots/shared/types")

type RF<T..., R...> = TypedRemote.Function<T..., R...>
type RE<T...> = TypedRemote.Event<T...>
type URE<T...> = TypedRemote.UnreliableEvent<T...>

local RF, RE, URE = TypedRemote.parent()
return {
	Accounts = {
		Patch = RE("Patch") :: RE<any>,
	},
	Plots = {
		RequestPlot = RF("RequestPlot") :: RF<(), (plotTypes.PlotSnapshot?)>,
		PlaceBuilding = RF("PlaceBuilding") :: RF<(string, number, number, number), (boolean?)>,
		ReplicateBuilding = RE("ReplicateBuilding") :: RE<plotTypes.BuildingSnapshot>,
	},
	Units = {
		RequestUnits = RE("A") :: RE<>, -- player loaded into plot, spawn units

		LoadUnits = RE("B") :: RE<buffer>, -- replicate unit to client

		RequestPath = RE("D") :: RE<Vector3>, -- request unit pathfinding target
		MoveUnit = RE("E") :: RE<buffer, any>, -- replicate unit moveTo waypoints

		ApplyPendingHit = RE("H") :: RE<number>,

		ReplicateSM = RE("I") :: RE<buffer, { [string]: any }>,
		ReplicateHealth = RE("J") :: RE<buffer>,
	},

	FireAllExcept = function(remote: any, plr: Player, ...)
		for _, p in Players:GetPlayers() do
			if p ~= plr then
				remote:FireClient(p, ...)
			end
		end
	end,
}
