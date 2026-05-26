local Vide = require("../Vide")

local source = Vide.source
local effect = Vide.effect
local cleanup = Vide.cleanup

return function()
	local value = source(workspace.CurrentCamera.ViewportSize)

	local conn

	effect(function()
		conn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			value(workspace.CurrentCamera.ViewportSize)
		end)
	end)

	cleanup(function()
		if conn then
			conn:Disconnect()
		end
	end)

	return value
end
