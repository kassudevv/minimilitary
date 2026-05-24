local Hotbar = require("../inventory/Hotbar")
local Hud = require("../hud/Hud")
local Vide = require("../Vide")
local px = require("../utils/px")

return function(target: Instance)
	return Vide.mount(function()
		px.usePx()
		px.setScale(1)
		return Hotbar()
	end, target)
end
