local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local objects = require("@game/ReplicatedStorage/src/accounts/shared/utils/objects")
local types = require("@game/ReplicatedStorage/src/accounts/shared/types")

export type Account = types.Account

type Accounts = {
	[string]: Account,
}

local getAccounts, setAccounts = Charm.signal({} :: Accounts)

local function getAccount(username: string): Account?
	return getAccounts()[username]
end

local function setAccount(username: string, account: Account)
	setAccounts(function(state: Accounts)
		return objects.set(state, username, account)
	end)
end

local function removeAccount(username: string)
	setAccounts(function(state: Accounts)
		return objects.delete(state, username)
	end)
end

return {
	getAccounts = getAccounts,
	getAccount = getAccount,
	setAccount = setAccount,
	removeAccount = removeAccount,
}
