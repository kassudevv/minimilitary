export type UnitSnapshot = {
	itemId: string,
	owner: string,
	position: CFrame,
	id: number,
}

export type Unit = {
	itemId: string,
	model: Model,

	name: string,

	health: number,
	damage: number,
	range: number,

	speed: number,
	scale: number,
	firerate: number,

	shotDelay: number?,
	offset: number?,

	type: Type,
	variant: string?,

	movementMode: "ground" | "flying" | nil,
	attackOverride: string?,
}

export type Type = "troop" | "tank" | "helicopter" | "plane"

export type Anim = "Idle" | "Shoot" | "Run"

return {}
