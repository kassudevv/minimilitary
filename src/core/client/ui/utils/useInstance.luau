local Vide = require("../Vide")

local source = Vide.source
function useInstance(): (any, any)
	local ref: Vide.Source<any> = source(nil)

	local action = Vide.action(function(instance: Instance)
		ref(instance)
	end)

	return ref, action
end

return useInstance
