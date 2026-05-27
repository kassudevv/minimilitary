local Research = require("../Research")
local Vide = require("../Vide")

return function(target: Instance)
	return Vide.mount(function()
		return Research()
	end, target)
end
