export type UnitSnapshot = {
	guid: string,
	id: number,
	owner: string,
	unitId: string,
	position: CFrame,
}

export type Unit = {
	id: string?,
	name: string,

	maxHealth: number,
	damage: number,
	range: number,

	model: Model,
	speed: number,
	scale: number,
	firerate: number,

	animToBulletDelay: number?,
	offset: number?,
	boundsRadius: number,

	type: Type?,

	movementMode: "ground" | "flying" | nil,
	attackOverride: string?,
}

export type Type = "troop" | "tank" | "helicopter" | "plane"

export type Anim = "Idle" | "Shoot" | "Run"

return {}
