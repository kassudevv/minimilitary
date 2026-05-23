local Promise = require("@game/ReplicatedStorage/Packages/Promise")
local types = require("@game/ReplicatedStorage/src/units/shared/types")

export type UnitData = {
	ownerId: string,
	owner: Player,
	unit: types.Unit,
	guid: string,
	model: Model,
	pawn: Part,

	pathfinder: Path,
	movePromise: Promise.Class,
}

return {}
