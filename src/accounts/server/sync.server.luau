local Players = game:GetService("Players")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local CharmSync = require("@game/ReplicatedStorage/Packages/CharmSync")
local accountStore = require("./accountStore")
local network = require("@game/ReplicatedStorage/src/core/shared/network")

local function onPlayerAdded(player: Player)
	CharmSync.server.addSignalsToClient(player, {
		[`account-{player.Name}`] = Charm.computed(function()
			return accountStore.getAccount(player.Name)
		end),
	})
end

local function onPlayerRemoving(player: Player)
	CharmSync.server.removeClient(player)
end

CharmSync.server.connect(function(player, patches)
	network.Accounts.Patch:FireClient(player, patches)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Charm.observe(accountStore.getAccounts, function(initialAccount: accountStore.Account, username: string)
	local player = Players:FindFirstChild(username) :: Player?

	if not player then
		return
	end

	local getAccount = Charm.computed(function(prevAccount: accountStore.Account?)
		return accountStore.getAccount(username) or prevAccount or initialAccount
	end)

	Charm.effect(function()
		local account = getAccount()
		-- print(`[accounts] state: `, account)
	end)
end)
