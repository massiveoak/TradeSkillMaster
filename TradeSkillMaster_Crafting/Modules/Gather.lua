-- ------------------------------------------------------------------------------ --
--                            TradeSkillMaster_Crafting                           --
--            http://www.curse.com/addons/wow/tradeskillmaster_crafting           --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

--load the parent file (TSM) into a local variable and register this file as a module
local TSM = select(2, ...)
local Gather = TSM:NewModule("Gather", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Crafting") -- loads the localization table

local next = next
local private = { shoppingItems = {} }
private.boltConversions = {
	["item:2996:0:0:0:0:0:0"] = { itemString = "item:2589:0:0:0:0:0:0", quantity = 2 }, -- Bolt of Linen Cloth
	["item:2997:0:0:0:0:0:0"] = { itemString = "item:2592:0:0:0:0:0:0", quantity = 3 }, -- Bolt of Woolen Cloth
	["item:4305:0:0:0:0:0:0"] = { itemString = "item:4306:0:0:0:0:0:0", quantity = 4 }, -- Bolt of Silk Cloth
	["item:4339:0:0:0:0:0:0"] = { itemString = "item:4338:0:0:0:0:0:0", quantity = 5 }, -- Bolt of Mageweave
	["item:14048:0:0:0:0:0:0"] = { itemString = "item:14047:0:0:0:0:0:0", quantity = 5 }, -- Bolt of Runecloth
	["item:21840:0:0:0:0:0:0"] = { itemString = "item:21877:0:0:0:0:0:0", quantity = 6 }, -- Bolt of Netherweave
	["item:41510:0:0:0:0:0:0"] = { itemString = "item:33470:0:0:0:0:0:0", quantity = 5 }, -- Bolt of Frostweave
	["item:53643:0:0:0:0:0:0"] = { itemString = "item:53010:0:0:0:0:0:0", quantity = 5 }, -- Bolt of Embersilk
	["item:82441:0:0:0:0:0:0"] = { itemString = "item:72988:0:0:0:0:0:0", quantity = 5 }, -- Bolt of Windwool Cloth
}

local function AddShoppingItem(items, itemString, quantity, conversion)
	if not itemString or not quantity or quantity <= 0 then return end
	for _, item in ipairs(items) do
		if item.itemString == itemString and item.ignoreMaxQty == conversion.ignoreMaxQty and item.sourceBolt == conversion.sourceBolt then
			item.quantity = item.quantity + quantity
			return item
		end
	end
	local item = {
		itemString = itemString,
		quantity = quantity,
		ignoreMaxQty = conversion.ignoreMaxQty,
		sourceBolt = conversion.sourceBolt,
		rawItemString = conversion.rawItemString,
		rawPerBolt = conversion.rawPerBolt,
	}
	tinsert(items, item)
	return item
end

local function BuildShoppingItems(items, ignoreMaxQty)
	local shoppingItems = {}
	for itemString, quantity in pairs(items) do
		local boltConversion = private.boltConversions[itemString]
		AddShoppingItem(shoppingItems, itemString, quantity, {
			ignoreMaxQty = ignoreMaxQty,
			rawItemString = boltConversion and boltConversion.itemString,
			rawPerBolt = boltConversion and boltConversion.quantity,
		})
	end
	return shoppingItems
end

local function GetSearchQuery(item)
	local itemName = TSMAPI:GetSafeItemInfo(item.itemString)
	local query = itemName .. "/exact"
	if not item.ignoreMaxQty then
		query = query .. "/x" .. item.quantity
	end

	if item.rawItemString and item.rawPerBolt then
		local rawName = TSMAPI:GetSafeItemInfo(item.rawItemString)
		local rawQuery = rawName .. "/exact"
		if not item.ignoreMaxQty then
			rawQuery = rawQuery .. "/x" .. (item.quantity * item.rawPerBolt)
		end
		query = query .. "; " .. rawQuery
	end

	return query
end

local function RemoveEmptyShoppingItems()
	for i = #private.shoppingItems, 1, -1 do
		if private.shoppingItems[i].quantity <= 0 then
			tremove(private.shoppingItems, i)
		end
	end
end

local function AdjustRawClothSearch(boltItemString, rawItemString, rawPerBolt, boltsBought)
	if not boltItemString or not rawItemString or not rawPerBolt or not boltsBought then return end
	local rawBought = boltsBought * rawPerBolt
	for _, item in ipairs(private.shoppingItems) do
		if item.sourceBolt == boltItemString and item.itemString == rawItemString then
			item.quantity = max((item.quantity or 0) - rawBought, 0)
			break
		end
	end
	RemoveEmptyShoppingItems()
end

function Gather:BuyFromMerchant(neededMats)
	for i = 1, GetMerchantNumItems() do
		local itemString = TSMAPI:GetItemString(GetMerchantItemLink(i))
		if neededMats[itemString] then
			local maxStack = GetMerchantItemMaxStack(i)
			local toBuy = neededMats[itemString]
			while toBuy > 0 do
				BuyMerchantItem(i, math.min(toBuy, maxStack))
				toBuy = toBuy - maxStack
				TSM.db.realm.gathering.gatheredMats = true
			end
		end
	end
end

function Gather:gatherItems(source, task)
	local items = TSM.db.realm.gathering.availableMats

	if source == L["Vendor"] then
		Gather:BuyFromMerchant(items)
	elseif (source == UnitName("player") or source == L["Realm Bank"]) and (task == L["Visit Bank"] or task == L["Visit Guild Bank"] or task == L["Visit Personal Bank"] or task == L["Visit Realm Bank"]) then
		Gather:GatherBank(items)
	elseif source == UnitName("player") and task == L["Mail Items"] then
		Gather:MailItems(items)
	elseif source == L["Auction House"] then
		if TSMAPI:AHTabIsVisible("Shopping") then
			private.shoppingItems = BuildShoppingItems(items)
			Gather:ShoppingSearch()
		else
			TSM:Printf(L["Please switch to the Shopping Tab to perform the gathering search."])
		end
	end
end

function Gather:GatherBank(moveItems)
	local next = next
	if next(moveItems) == nil then
		TSM:Print(L["Nothing to Gather"])
	else
		TSM:Print(L["Gathering Crafting Mats"])
		TSMAPI:MoveItems(moveItems, Gather.PrintMsg)
		TSM.db.realm.gathering.gatheredMats = true
	end
end

function Gather.PrintMsg(message)
	if message then
		TSM:Print(message)
	end
end

function Gather:MerchantSells(neededItem)
	for i = 1, GetMerchantNumItems() do
		local itemString = TSMAPI:GetItemString(GetMerchantItemLink(i))
		if neededItem == itemString then
			return true
		end
	end
	return false
end

function Gather:MailItems(neededItems)
	local next = next
	if next(neededItems) == nil then
		TSM:Print(L["Nothing to Mail"])
	else
		local crafter = TSM.db.realm.gathering.crafter
		if crafter then
			TSM:Print(format(L["Mailing Craft Mats to %s"], crafter))
			TSMAPI:ModuleAPI("Mailing", "mailItems", neededItems, crafter, Gather.PrintMsg)
			TSM.db.realm.gathering.gatheredMats = true
		end
	end
end

local function ShoppingNextSearch()
	RemoveEmptyShoppingItems()
	if next(private.shoppingItems) then
		Gather:ShoppingSearch()
	end
end

local function ShoppingCallback(remainingQty, boughtItem, stackSize)
	local currentItem = private.shoppingItems[1]
	if not boughtItem then
		if next(private.shoppingItems) then
			local name = TSMAPI:GetSafeItemInfo(private.shoppingItems[1].itemString)
			TSM:Print("No Auctions found for", name)
			tremove(private.shoppingItems, 1)
			TSMAPI:CreateTimeDelay("shoppingSearchThrottle", 0.5, ShoppingNextSearch)
		end
	else
		if currentItem and boughtItem == currentItem.itemString then
			AdjustRawClothSearch(currentItem.itemString, currentItem.rawItemString, currentItem.rawPerBolt, stackSize)
		end
		if currentItem and boughtItem == currentItem.rawItemString then
			remainingQty = ceil((remainingQty or 0) / currentItem.rawPerBolt)
		end
		TSM.Inventory.gatherQuantity = remainingQty
		if TSM.Inventory.gatherItem and boughtItem ~= TSM.Inventory.gatherItem then
			for itemString, data in pairs(TSMAPI.Conversions[TSM.Inventory.gatherItem] or {}) do
				if itemString == boughtItem then
					TSM.db.realm.gathering.destroyingMats[boughtItem] = (TSM.db.realm.gathering.destroyingMats[boughtItem] or 0) + stackSize
				end
			end
		end
		if max(TSM.Inventory.gatherQuantity, 0) == 0 and next(private.shoppingItems) then
			tremove(private.shoppingItems, 1)
			TSMAPI:CreateTimeDelay("shoppingSearchThrottle", 0.5, ShoppingNextSearch)
		end
	end
end

function Gather:ShoppingSearch(itemString, need, ignoreMaxQty)
	if itemString then
		private.shoppingItems = BuildShoppingItems({ [itemString] = need }, ignoreMaxQty)
	end

	RemoveEmptyShoppingItems()
	if not next(private.shoppingItems) then return end

	itemString = private.shoppingItems[1].itemString
	need = private.shoppingItems[1].quantity
	ignoreMaxQty = private.shoppingItems[1].ignoreMaxQty
	TSM.Inventory.gatherQuantity = nil
	local matPrice = TSMAPI:FormatTextMoney(TSM.Cost:GetMatCost(itemString))
	if not TSM.db.realm.gathering.destroyDisable then
		if TSMAPI.InkConversions[itemString] then
			TSM.Inventory.gatherItem = itemString
			if TSM.db.realm.gathering.evenStacks then
				if ignoreMaxQty then
					TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/even", ShoppingCallback)
				else
					TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/even/x" .. need, ShoppingCallback)
				end
			elseif ignoreMaxQty then
				TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString), ShoppingCallback)
			else
				TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/x" .. need, ShoppingCallback)
			end
		elseif TSMAPI:GetDisenchantData(itemString) then
			TSM.Inventory.gatherItem = itemString
			if ignoreMaxQty then
				TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/exact", ShoppingCallback)
			else
				TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/exact/x" .. need, ShoppingCallback)
			end
		elseif TSMAPI.Conversions[itemString] then
			TSM.Inventory.gatherItem = itemString
			local convertSource
			for _, data in pairs(TSMAPI.Conversions[itemString]) do
				convertSource = data.source
				break
			end
			if convertSource == "mill" or convertSource == "prospect" then
				if TSM.db.realm.gathering.evenStacks then
					if ignoreMaxQty then
						TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/even", ShoppingCallback)
					else
						TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/even/x" .. need, ShoppingCallback)
					end
				elseif ignoreMaxQty then
					TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString), ShoppingCallback)
				else
					TSMAPI:ModuleAPI("Shopping", "runDestroySearch", TSMAPI:GetSafeItemInfo(itemString) .. "/x" .. need, ShoppingCallback)
				end
			else
				TSMAPI:ModuleAPI("Shopping", "runSearch", TSMAPI:GetSafeItemInfo(itemString) .. "/exact/x" .. need, ShoppingCallback)
			end
		else
			TSM.Inventory.gatherItem = nil
			if ignoreMaxQty then
				TSMAPI:ModuleAPI("Shopping", "runSearch", GetSearchQuery(private.shoppingItems[1]), ShoppingCallback)
			else
				TSMAPI:ModuleAPI("Shopping", "runSearch", GetSearchQuery(private.shoppingItems[1]), ShoppingCallback)
			end
		end

	else
		TSM.Inventory.gatherItem = nil
		if ignoreMaxQty then
			TSMAPI:ModuleAPI("Shopping", "runSearch", GetSearchQuery(private.shoppingItems[1]), ShoppingCallback)
		else
			TSMAPI:ModuleAPI("Shopping", "runSearch", GetSearchQuery(private.shoppingItems[1]), ShoppingCallback)
		end
	end
end
