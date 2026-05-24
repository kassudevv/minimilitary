local Players = game:GetService("Players")

local App = require("@self/ui/App")
local Placement = require("../plots/client/placement")
local Plots = require("../plots/client")
local SMUnits = require("../units/client/stateMachineUnit")
local Vide = require("@self/ui/Vide")

Plots:init()
Placement:init()
SMUnits:init()

Vide.mount(App, Players.LocalPlayer.PlayerGui)
