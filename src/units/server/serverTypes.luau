local types = require("@game/ReplicatedStorage/src/units/shared/types")

export type UnitData = {
	owner: Player,
	unit: types.Unit,
	guid: string,
	model: Model,
	pawn: Part,
	pathfinder: Path,
}

return {}
