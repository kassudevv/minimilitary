local HttpService = game:GetService("HttpService")
local items = require("@game/ReplicatedStorage/src/accounts/shared/items")
local objects = require("@game/ReplicatedStorage/src/accounts/shared/utils/objects")
local store = require("@self/store")
local types = require("@game/ReplicatedStorage/src/accounts/shared/types")

type Account = types.Account
type Item = items.Item
type AccountPlotBuilding = types.AccountPlotBuilding
type AccountUnit = types.AccountUnit

local function sellItem(player: Player, guid: string)
	return store:updateImmutable(player, function(account: Account)
		local item = account.items[guid]
		if not item then
			return false
		end

		local info = items.getItem(item.itemId)
		if info.type ~= "Crop" then
			return false
		end

		local data = info.data :: items.ItemCropData
		print("Selling ", item.itemId, item.amount)

		return objects.join(account, {
			items = objects.delete(account.items, guid),
		})
	end)
end

local function addItem(player: Player, item: Item)
	return store:updateImmutable(player, function(account: Account)
		local existing: string? = nil
		for guid, curr in account.items do
			if curr.itemId == item.itemId then
				existing = guid
				break
			end
		end

		-- should stack?
		if existing then
			local updatedItem =
				{ amount = account.items[existing].amount + item.amount, itemId = account.items[existing].itemId }
			return objects.join(account, {
				items = objects.set(account.items, existing, updatedItem),
			})
		else
			return objects.join(account, {
				items = objects.set(account.items, HttpService:GenerateGUID(false), item),
			})
		end
	end)
end

local function moveItemToHotbar(player: Player, guid: string, slot: number?)
	return store:updateImmutable(player, function(account: Account)
		local item = objects.set(account.items[guid], "hotbar", slot)
		return objects.join(account, {
			items = objects.set(account.items, guid, item),
		})
	end)
end

local function addBuilding(player: Player, building: AccountPlotBuilding)
	local id = HttpService:GenerateGUID(false)
	return store:updateImmutable(player, function(account: Account)
		return objects.join(account, {
			plot = objects.join(account.plot, {
				buildings = objects.set(account.plot.buildings, id, building),
			}),
		})
	end),
		id
end

local function getBuilding(player: Player, guid: string): AccountPlotBuilding | false
	local ok, data: Account = store:get(player):await()
	return ok and data and data.plot and data.plot.buildings and data.plot.buildings[guid]
end

local function removeBuilding(player: Player, guid: string)
	return store:updateImmutable(player, function(account: Account)
		return objects.join(account, {
			plot = objects.join(account.plot, {
				buildings = objects.delete(account.plot.buildings, guid),
			}),
		})
	end)
end

local function setBuildingMeta(player: Player, guid: string, key: string, value: any)
	return store:updateImmutable(player, function(account: Account)
		return objects.join(account, {
			plot = objects.join(account.plot, {
				buildings = objects.set(
					account.plot.buildings,
					guid,
					objects.set(
						account.plot.buildings[guid],
						"meta",
						objects.set(account.plot.buildings[guid].meta, key, value)
					)
				),
			}),
		})
	end)
end

local function addUnit(player: Player, unit: AccountUnit)
	local id = HttpService:GenerateGUID(false)
	return store:updateImmutable(player, function(account: Account)
		return objects.join(account, {
			units = objects.set(account.units, id, unit),
		})
	end),
		id
end

local function removeUnit(player: Player, guid: string)
	return store:updateImmutable(player, function(account: Account)
		return objects.join(account, {
			units = objects.delete(account.units, guid),
		})
	end)
end

local function setUnitSquad(player: Player, guid: string, assignedSquad: number)
	return store:updateImmutable(player, function(account: Account)
		local unit = account.units[guid]
		if not unit then
			return false
		end

		return objects.join(account, {
			units = objects.set(
				account.units,
				guid,
				objects.join(unit, {
					assignedSquad = assignedSquad,
				})
			),
		})
	end)
end

return {
	sellItem = sellItem,
	addItem = addItem,
	moveItemToHotbar = moveItemToHotbar,
	getBuilding = getBuilding,
	addBuilding = addBuilding,
	removeBuilding = removeBuilding,
	setBuildingMeta = setBuildingMeta,
	addUnit = addUnit,
	removeUnit = removeUnit,
	setUnitSquad = setUnitSquad,
}
