local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local network = require("../core/shared/network")
local store = require("@self/store")

print("Load client")

Charm.effect(function()
	local account = store.getAccount()
	-- print(account)
end)
