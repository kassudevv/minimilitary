local Charm = require("../../../Packages/Charm")
local types = require("../shared/types")
local getAccount, setAccount = Charm.signal(types.accountTemplate)

return {
	getAccount = getAccount,
	setAccount = setAccount,
}
