local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local accountStore = require("./accountStore")
local types = require("@game/ReplicatedStorage/src/accounts/shared/types")

type Account = types.Account

Charm.observe(accountStore.getAccounts, function(initialAccount: Account, username: string)
	local player = Players:FindFirstChild(username) :: Player?

	if not player then
		return
	end

	local getAccount = Charm.computed(function(prevAccount: Account?)
		return accountStore.getAccount(username) or prevAccount or initialAccount
	end)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Parent = leaderstats

	Charm.effect(function()
		local account = getAccount()
		gold.Value = account.cash
	end)

	return function()
		leaderstats:Destroy()
	end
end)
