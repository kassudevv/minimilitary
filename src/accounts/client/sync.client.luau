local Players = game:GetService("Players")
local CharmSync = require("../../../Packages/CharmSync")
local network = require("../../core/shared/network")
local store = require("./store")

CharmSync.client.addSignals({
	[`account-{Players.LocalPlayer.Name}`] = store.setAccount,
})

network.Accounts.Patch.OnClientEvent:Connect(function(patches)
	CharmSync.client.patch(patches)
end)
