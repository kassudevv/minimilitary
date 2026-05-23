export type UnitSnapshot = {
	guid: string,
	owner: Player,
	unitId: string,
	position: CFrame,
}

export type Unit = {
	id: string?,
	name: string,
	model: Model,
	speed: number,
	scale: number,
	firerate: number,

	animToBulletDelay: number?,
	offset: number?,
	boundsRadius: number,

	type: Type?,

	movementMode: "ground" | "flying" | nil,
	movementOverride: string?,
	attackOverride: string?,
}

export type Type = "troop" | "tank" | "helicopter" | "plane"

export type Anim = "Idle" | "Shoot" | "Run"

return {}
