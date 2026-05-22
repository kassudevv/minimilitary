local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gt = require(ReplicatedStorage.Packages.gt)
local types = require("@game/ReplicatedStorage/src/accounts/shared/types")

type Account = types.Account

local accountSchema: Account = gt.table({
	cash = gt.number(),
	plot = gt.table({
		tiles = gt.array(gt.table({ -- tiles unlocked other than the default ones
			x = gt.number(),
			y = gt.number(),
		})),

		buildings = {
			[gt.string()] = gt.table({
				x = gt.number(),
				y = gt.number(),
				rot = gt.number(),
				meta = { [gt.string()] = gt.any() },
			}),
		},
	}),
	units = {
		[gt.string()] = gt.table({
			unitId = gt.string(),
			assignedSquad = gt.number(),
		}),
	},
	items = {
		[gt.string()] = gt.table({
			itemId = gt.string(),
			amount = gt.number(),
		}),
	},
}) :: Account

return gt.build(accountSchema)
