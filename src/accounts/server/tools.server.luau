local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local accountStore = require("./accountStore")
local accounts = require("../server")
local attribute = require("@game/ReplicatedStorage/src/accounts/shared/utils/attribute")
local items = require("@game/ReplicatedStorage/src/accounts/shared/items")
local observers = require("@game/ReplicatedStorage/src/accounts/shared/utils/observers")
local guidAttribute = attribute<<string?>>("ItemGuid")
type Item = items.Item

function createItemTool(item, guid)
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false

	tool.Name = item.itemId
	tool.ToolTip = guid

	guidAttribute.set(tool, guid)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2, 2, 2)
	handle.Parent = tool
	return tool
end

observers.observePlayers(function(player)
	return observers.observeChildWhichIsA(player, "Backpack", function(backpack: Backpack)
		local function getItems(): { [string]: Item }
			local account = accountStore.getAccount(player.Name)
			return if account then account.items else {}
		end

		return Charm.observe(getItems, function(item, guid)
			local tool = createItemTool(item, guid)
			tool.Parent = backpack
			return function()
				tool:Destroy()
			end
		end)
	end)
end)

local function getEquippedItemGuid(player: Player): string?
	local character = player.Character
	local tool = character and character:FindFirstChildWhichIsA("Tool")
	return tool and guidAttribute.get(tool)
end

observers.observeTag("SellPrompt", function(prompt: ProximityPrompt)
	local triggered = prompt.Triggered:Connect(function(player)
		local guid = getEquippedItemGuid(player)
		if guid then
			accounts.sellItem(player, guid)
		end
	end)

	return function()
		triggered:Disconnect()
	end
end)
