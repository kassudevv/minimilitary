local ReplicatedStorage = game:GetService("ReplicatedStorage")
local types = require("./types")
local unitRaycast = require("./unitRaycast")
type Unit = types.Unit
type Type = types.Type

local unitsById: { [string]: Unit } = {
	gunner = {
		name = "Gunner",
		model = ReplicatedStorage.NPCs.Gunner,

		maxHealth = 60,
		damage = 6,
		range = 64,

		speed = 12,
		scale = 0.8,
		firerate = 6,

		boundsRadius = 2,
	},
	juggernaut = {
		name = "Juggernaut",
		model = ReplicatedStorage.NPCs.Juggernaut,

		maxHealth = 5000,
		damage = 12,
		range = 64,

		speed = 10,
		scale = 1,
		firerate = 16,

		boundsRadius = 3,
	},
	abrams = {
		name = "Tiger I Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankAbrams,
		maxHealth = 100,
		damage = 50,
		range = 58,
		speed = 10,
		scale = 1.8,
		firerate = 0.4,

		shotDelay = 0.48,
		boundsRadius = 8,
	},
	abramsx = {
		name = "Abrams X Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankX,
		maxHealth = 10,
		damage = 1,
		range = 58,
		speed = 12,
		scale = 2,
		firerate = 0.5,
		boundsRadius = 8,
	},
	tiger1 = {
		name = "Tiger I Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankTiger1,
		maxHealth = 100,
		damage = 250,
		range = 58,
		speed = 10,
		scale = 1.8,
		firerate = 0.4,
		boundsRadius = 8,
		shotDelay = 0.48,
	},
	abramsghost = {
		name = "Abrams Ghost Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankGhost,
		maxHealth = 10,
		damage = 1,
		range = 58,
		speed = 12,
		scale = 1.6,
		firerate = 0.25,
		shotDelay = 0.3555,
		boundsRadius = 8,
	},
	apache = {
		name = "AH-64 Apache",
		type = "helicopter",
		model = ReplicatedStorage.NPCs.Apache,
		maxHealth = 200,
		damage = 100,
		range = 72,
		speed = 14,
		scale = 1.6,
		firerate = 0.25,
		boundsRadius = 8,
		attackOverride = "helicopter_missiles",
		movementMode = "flying",
	},
	littlebird = {
		name = "MH-6 Little Bird",
		type = "helicopter",
		model = ReplicatedStorage.NPCs.LittleBird,
		maxHealth = 10,
		damage = 1,
		range = 72,
		speed = 12,
		scale = 1.4,
		firerate = 5,
		boundsRadius = 4,
		movementMode = "flying",
	},
}

for _, u in unitsById do
	u.offset = unitRaycast.calculateGroundOffset(u.model, u.scale)
	u.speed = 50
end

local function getUnit(itemId: string): Unit?
	local u = unitsById[itemId]
	if not u then
		return nil
	end
	u.id = itemId
	return u
end

return {
	unitsById = unitsById,
	getUnit = getUnit,
}
