--!nocheck
-- FIXME: Remove nocheck when createPlayerStore() no longer incorrectly reports
-- that the code is too complex to typecheck

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lyra = require(ReplicatedStorage.Packages.Lyra)
local accountStore = require("./accountStore")
local schema = require("./schema")
local types = require("@game/ReplicatedStorage/src/accounts/shared/types")

type Account = types.Account

local function onAccountChanged(key: string, account: Account)
	local player = Players:GetPlayerByUserId(tonumber(key) :: number)
	if player then
		accountStore.setAccount(player.Name, account)
	end
end

return Lyra.createPlayerStore({
	name = "PRE2_",
	template = types.accountTemplate,
	schema = function(value)
		local ok, reason = schema:matches(value)
		return ok, tostring(reason)
	end,
	changedCallbacks = { onAccountChanged },
	useMock = RunService:IsStudio(),
	-- memoryStoreService = if RunService:IsStudio() then Lyra.MockMemoryStoreService.new() else nil,
	-- dataStoreService = if RunService:IsStudio() then Lyra.MockDataStoreService.new() else nil,
})
