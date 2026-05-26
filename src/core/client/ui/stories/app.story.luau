local Main = require("../Main")
local Vide = require("../Vide")

return function(target: Instance)
	return Vide.mount(function()
		return Main()
	end, target)
end
