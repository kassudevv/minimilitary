local Promise = require("../../../Packages/PromiseTyped")
local types = require("../shared/types")

export type UnitData = {
	move: (UnitData, { Vector3 }) -> Promise.Class,
	moveTo: (UnitData, Vector3) -> typeof(Promise.new(function() end)),
	attack: (UnitData, Vector3) -> typeof(Promise.new(function() end)),
	playAnimation: (UnitData, string) -> (),
	stopAnimation: (UnitData, string) -> (),
	raycastGround: (UnitData, Vector3) -> Vector3,
	faceTarget: (UnitData, Vector3) -> (),

	unit: types.Unit,
	owner: number?,
	guid: string,
	model: Model,

	animator: Animator,
	loadedAnims: { [string]: Animation },
	loadedTracks: { [string]: AnimationTrack },

	pathfinder: Path,

	isMoving: boolean,
	movePromise: typeof(Promise.new(function() end)),
	attackPromise: typeof(Promise.new(function() end)),
	targetingPromise: typeof(Promise.new(function() end)),

	cache: { [string]: any },
}

return {}
