local ReplicatedStorage = game:GetService("ReplicatedStorage")
local types = require("./types")
local unitRaycast = require("./unitRaycast")
type Unit = types.Unit
type Type = types.Type

local unitsById: { [string]: Unit } = {
	gunner = {
		name = "Gunner",
		type = "troop",
		model = ReplicatedStorage.NPCs.Gunner,

		health = 1,
		scale = 0.8,
		range = 0.7,
		speed = 1,
		damage = 1,
		firerate = 1,
	},
	juggernaut = {
		name = "Juggernaut",
		type = "troop",
		model = ReplicatedStorage.NPCs.Juggernaut,

		health = 5,
		scale = 0.9,
		range = 0.7,
		speed = 0.8,
		damage = 0.3,
		firerate = 1.5,
	},
	abrams = {
		name = "Abrams Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankAbrams,
		shotDelay = 0.48,

		health = 1,
		scale = 2.2,
		range = 1,
		speed = 1,
		damage = 1,
		firerate = 1,
	},
	tiger1 = {
		name = "Tiger I Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankTiger1,
		shotDelay = 0.48,

		health = 0.8,
		scale = 1.8,
		range = 1,
		speed = 1,
		damage = 1,
		firerate = 1,
	},
	apache = {
		name = "AH-64 Apache",
		type = "helicopter",
		variant = "missiles",
		model = ReplicatedStorage.NPCs.Apache,
		movementMode = "flying",

		health = 1,
		scale = 1.2,
		range = 1,
		speed = 1,
		damage = 1,
		firerate = 1,
	},
	littlebird = {
		name = "MH-6 Little Bird",
		type = "helicopter",
		variant = "cannon",
		model = ReplicatedStorage.NPCs.LittleBird,
		movementMode = "flying",

		health = 1,
		scale = 1.1,
		range = 1,
		speed = 1,
		damage = 1,
		firerate = 1,
	},
} :: { [string]: Unit }

type StatDefinition = {
	health: number,
	range: number,
	speed: number,
	damage: number,
	firerate: number,
}

type Variant = { [string]: StatDefinition }

type StatDefinitionOrVariant = StatDefinition | Variant

local typeToStats: { [Type]: StatDefinitionOrVariant } = {
	troop = {
		health = 108,
		range = 64,
		speed = 14,
		damage = 6,
		firerate = 6,
	},
	tank = {
		health = 1440,
		range = 52,
		speed = 10,
		damage = 130,
		firerate = 1 / 3,
	},
	helicopter = {
		cannon = {
			health = 465,
			range = 70,
			speed = 14,
			damage = 6,
			firerate = 8,
		},
		missiles = {
			health = 950,
			range = 58,
			speed = 12,
			damage = 300,
			firerate = 1 / 5,
		},
	} :: Variant,
}

-- apply base stats to unit stats
for _, u in unitsById do
	u.scale = u.scale or 1
	u.offset = unitRaycast.calculateGroundOffset(u.model, u.scale)

	local variant = u.variant

	local base = if not variant
		then typeToStats[u.type] :: StatDefinition
		else typeToStats[u.type][u.variant] :: StatDefinition

	u.range = base.range * u.range
	u.speed = base.speed * u.speed
	u.damage = base.damage * u.damage
	u.firerate = base.firerate * u.firerate
	u.health = base.health * u.health
end

local function getUnit(itemId: string): Unit?
	local u = unitsById[itemId]
	if not u then
		return nil
	end
	u.itemId = itemId
	return u
end

return {
	unitsById = unitsById,
	getUnit = getUnit,
}
