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
		RequestUnits = RE("A") :: RE<>, -- player loaded into plot, spawn units

		LoadUnits = RE("B") :: RE<any>, -- replicate unit to client
		DestroyUnits = RE("C") :: RE<{ string }>, -- remove unit from client

		RequestPath = RE("D") :: RE<Vector3>, -- request unit pathfinding target
		MoveUnit = RE("E") :: RE<buffer, any>, -- replicate unit moveTo waypoints

		StartTargeting = RE("F") :: RE<buffer, buffer>, -- replicates targeting for clients
		StopTargeting = RE("G") :: RE<buffer>, -- replicates targeting for clients

		ApplyPendingHit = RE("H") :: RE<string>,

		ReplicateSM = RE("I") :: RE<string, "idle" | "moving" | "targeting", { [string]: any }>,
	},

	FireAllExcept = function(remote: any, plr: Player, ...)
		for _, p in Players:GetPlayers() do
			if p ~= plr then
				remote:FireClient(p, ...)
			end
		end
	end,
}
