local Promise = require("@game/ReplicatedStorage/Packages/Promise")
local types = require("@game/ReplicatedStorage/src/units/shared/types")

export type UnitData = {
	owner: number,
	unit: types.Unit,
	guid: string,
	model: Model,
	pawn: Part,

	health: number,
	pathfinder: Path,

	movePromise: Promise.Class,
	targetingPromise: Promise.Class,
	attackPromise: Promise.Class,
	lastAttackTs: number,

	callbacks: { [string]: (string, any) -> () },

	pendingHits: { number },
}

return {}
