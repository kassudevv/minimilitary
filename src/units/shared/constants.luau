local ReplicatedStorage = game:GetService("ReplicatedStorage")
local types = require("./types")
type Unit = types.Unit
type Type = types.Type

local unitsById: { [string]: Unit } = {
	gunner = {
		name = "Gunner",
		model = ReplicatedStorage.NPCs.Gunner,
		speed = 10,
		scale = 0.6,
		firerate = 4,
		groundOffset = 3,
		boundsRadius = 2,
	},
	juggernaut = {
		name = "Juggernaut",
		model = ReplicatedStorage.NPCs.Juggernaut,
		speed = 6,
		scale = 0.8,
		firerate = 5,
		groundOffset = 3,
		boundsRadius = 3,
	},
	abrams = {
		name = "Abrams Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankAbrams,
		speed = 9,
		scale = 2,
		firerate = 0.5,
		groundOffset = 1,

		-- animation params
		animToBulletDelay = 0.3555,
		boundsRadius = 8,
	},
	abramsx = {
		name = "Abrams X Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankX,
		speed = 11,
		scale = 1.6,
		firerate = 0.5,
		groundOffset = 1,

		-- animation params
		animToBulletDelay = 0.3555,
		boundsRadius = 8,
	},
	tiger1 = {
		name = "Tiger I Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankTiger1,
		speed = 7,
		scale = 1.8,
		firerate = 0.4,
		groundOffset = 1,

		-- animation params
		animToBulletDelay = 0.3555,
		boundsRadius = 8,
	},
	abramsghost = {
		name = "Abrams Ghost Tank",
		type = "tank",
		model = ReplicatedStorage.NPCs.TankGhost,
		speed = 12,
		scale = 1.5,
		firerate = 0.25,
		groundOffset = 1,

		-- animation params
		animToBulletDelay = 0.3555,
		boundsRadius = 8,
	},
	apache = {
		name = "AH-64 Apache",
		type = "helicopter",
		model = ReplicatedStorage.NPCs.Apache,
		speed = 12,
		scale = 1.3,
		firerate = 0.25,
		groundOffset = 1,

		-- animation params
		animToBulletDelay = 0,
		boundsRadius = 8,

		attackOverride = "helicopter_missiles",
		movementOverride = "helicopter",
	},
	littlebird = {
		name = "MH-6 Little Bird",
		type = "helicopter",
		model = ReplicatedStorage.NPCs.LittleBird,
		speed = 9,
		scale = 1.3,
		firerate = 5,
		groundOffset = 1,

		-- animation params
		animToBulletDelay = 0,
		boundsRadius = 8,

		attackOverride = "ground",
		movementOverride = "helicopter",
	},
}

local function getUnit(itemId: string): Unit
	local u = unitsById[itemId]
	u.id = itemId
	return u
end

return {
	unitsById = unitsById,
	getUnit = getUnit,
}
