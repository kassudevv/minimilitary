local Players = game:GetService("Players")

local App = require("@self/ui/App")
local Outposts = require("../outposts/client")
local Placement = require("../plots/client/placement")
local Plots = require("../plots/client")
local SMUnits = require("../units/client/stateMachineUnit")
local Vide = require("@self/ui/Vide")
local observers = require("../accounts/shared/utils/observers")

local isLoaded = false
observers.observeCharacter(Players.LocalPlayer, function(char)
	if not isLoaded then
		isLoaded = true
		task.wait(1)
		Plots:init():andThen(function()
			SMUnits:init():andThen(function()
				Placement:init()
				Outposts:init()
			end)
		end)
	end

	return function() end
end)

Vide.mount(App, Players.LocalPlayer.PlayerGui)
