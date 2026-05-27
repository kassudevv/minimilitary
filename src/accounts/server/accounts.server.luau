print("Load server")

local Players = game:GetService("Players")

local accountStore = require("./accountStore")
local network = require("@game/ReplicatedStorage/src/core/shared/network")

local accounts = require("../server")
local store = require("./store")

Players.PlayerAdded:Connect(function(player)
	store:load(player)

	task.delay(1, function()
		accounts.addItem(player, { amount = math.random(1, 10), itemId = "wheat" })
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	store:unload(player)
	accountStore.removeAccount(player.Name)
end)

game:BindToClose(function()
	store:closeAsync()
end)

network.Accounts.MoveItemToHotbar.OnServerEvent:Connect(function(plr: Player, guid: string, slot: number?)
	accounts.moveItemToHotbar(plr, guid, slot)
end)
