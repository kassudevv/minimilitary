local Charm = require("../../../Packages/Charm")
-- outposts/shared/atoms.luau

type Status = "uncontested" | "contested" | "claimed"

-- keyed by outpost guid
local atoms = {
	outpostOwner = Charm.atom({} :: { [string]: string }),
	outpostStatus = Charm.atom({} :: { [string]: Status }),
}

return atoms
