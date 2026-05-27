local RunService = game:GetService("RunService")
local objects = require("../shared/utils/objects")
local store = require("./store")

function moveItemToHotbar(guid: string, slot: number?)
	if RunService:IsRunning() then
		local network = require("../../core/shared/network")
		network.Accounts.MoveItemToHotbar:FireServer(guid, slot)
	end
	store.setAccount(function(account)
		local item = objects.set(account.items[guid], "hotbar", slot)
		return objects.join(account, {
			items = objects.set(account.items, guid, item),
		})
	end)
end

return {
	moveItemToHotbar = moveItemToHotbar,
}
