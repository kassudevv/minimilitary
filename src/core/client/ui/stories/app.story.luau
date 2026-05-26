local Hotbar = require("../inventory/Hotbar")
local Hud = require("../hud/Hud")
local Main = require("../Main")
local Vide = require("../Vide")
local px = require("../utils/px")

return function(target: Instance)
	return Vide.mount(function()
		px.usePx()
		px.setScale(1)
		return Main()
	end, target)
end
