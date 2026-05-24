local Players = game:GetService("Players")

local App = require("@self/ui/App")
local Building = require("../plots/client/building")
local Plots = require("../plots/client")
local SMUnits = require("../units/client/stateMachineUnit")
local Vide = require("@self/ui/Vide")

Plots:init()
Building:init()
SMUnits:init()

Vide.mount(App, Players.LocalPlayer.PlayerGui)
