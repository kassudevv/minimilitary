local Players = game:GetService("Players")

local App = require("@self/ui/App")
local Building = require("../plots/client/building")
local Plots = require("../plots/client")
local Units = require("../units/client")
local Vide = require("@self/ui/Vide")

Plots:init()
Units:init()
Building:init()

Vide.mount(App, Players.LocalPlayer.PlayerGui)
