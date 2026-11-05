-- Synthetic merchant events, using the same UI harness as the existing smoke tests.
dofile("tests/smoke.lua")
assert(VendorItemCheck.observations == nil, "Classic must not initialize recording")

local now = 1793847600
local character = "Player-1-PRIVATECHARACTER"
local merchant = "Creature-0-1-2-3-100001-0000000001"
local delayed = {}
local alt = false
function time() return now end
date = os.date
function GetBuildInfo() return "1.60.1", "70790", "", 16001 end
function UnitGUID(unit) return unit == "player" and character or merchant end
function UnitName(unit) return unit == "npc" and "Observed Vendor" or "PRIVATE NAME" end
function IsTestBuild() return false end
function IsAltKeyDown() return alt end
function GetMerchantPriceDiscount() return 0.95 end
C_Timer = { After = function(_, callback) delayed[#delayed + 1] = callback end }

local slots = { { itemId = 100002, price = 20, quantity = 5, stock = -1, purchasable = true, extended = false } }
function GetMerchantNumItems() return #slots end
function GetMerchantItemLink(index)
    local slot = slots[index]
    if slot and not slot.pending then return "item:" .. slot.itemId end
end
function GetMerchantItemInfo(index)
    local slot = slots[index]
    return "Item", nil, slot.price, slot.quantity, slot.stock, slot.purchasable, true, slot.extended
end
C_MerchantFrame = { GetItemInfo = function(index)
    local slot = slots[index]
    return { name = "Item", price = slot.price, stackCount = slot.quantity, numAvailable = slot.stock,
        isPurchasable = slot.purchasable, hasExtendedCost = slot.extended }
end }

local VIC = {}
for _, file in ipairs({ "Data", "DataForever", "Core", "Merchant", "Tooltip", "Options" }) do
    assert(loadfile("VendorItemCheck/" .. file .. ".lua"))("VendorItemCheck", VIC)
end
VendorItemCheckDB = { enabled = true, modifierKey = "ALT", customSetting = "preserve" }
VIC:SelectDataset()
VIC:InitializeDB()
VIC:MerchantInitialize()
VIC:TooltipInitialize()
VIC:OptionsInitialize()
local function Event(event)
    VIC.merchantFrame.scripts.OnEvent(VIC.merchantFrame, event)
end
Event("MERCHANT_SHOW")
local info = VIC:GetItemVendors(100002)
assert(info.totalCount == 1 and info.vendors[1].personal)
assert(info.vendors[1].quoteText:find("4c") and info.vendors[1].accessObserved)
assert(VIC.settings.customSetting == "preserve" and VIC.settings.recordMerchants)
assert(VIC.observations.schema == 1 and VIC.observations.reporterId:match("^vic%-%x+$"))
assert(VIC.Datasets.forever.items[100002] == nil, "Personal records must not mutate bundled data")
local tip = CreateFrame("GameTooltip", "PersonalTestTooltip")
tip:SetHyperlink("item:100002")
assert(tip.lines[2].left:find("observed") and tip.lines[2].left:find("4c"))
alt = true
tip:SetHyperlink("item:100002")
local observed, access, quote = false, false, false
for _, line in ipairs(tip.lines) do
    local text = (line.left or "") .. (line.right or "")
    observed = observed or text:find("Observed 2026", 1, true)
    access = access or text:find("Observed access", 1, true)
    quote = quote or text:find("4c", 1, true)
    assert(not text:find("Everloot", 1, true), "Personal facts must not be attributed to Everloot")
end
assert(observed and access and quote)

-- Merge by evidence time without changing the bundled registry or duplicating vendors.
local originalItems, originalVendors = VIC.Items, VIC.Vendors
VIC.Items = { [100002] = { v = { 100001 }, offers = { [100001] = {
    reporters = 3, expires = now + 100, lastSeenEpoch = now - 1,
} } } }
VIC.Vendors = { [100001] = { "Bundled Vendor", "Location unknown", "?", 0, 0, nameExpires = now + 100 } }
assert(VIC:GetItemVendors(100002).vendors[1].personal)
now = now + 2
VIC.Items[100002].offers[100001].lastSeenEpoch = now - 1
info = VIC:GetItemVendors(100002)
assert(info.totalCount == 1 and not info.vendors[1].personal and info.observedPriceText == nil)
VIC.Items, VIC.Vendors = originalItems, originalVendors

-- Legacy API fallback and exact batch quotes, including zero-price offers.
C_MerchantFrame = nil
slots[1].price, slots[1].quantity = 3, 2
now = now + 1
Event("MERCHANT_UPDATE")
assert(VIC:GetItemVendors(100002).vendors[1].quoteText:find(" / 2", 1, true))
slots[1].price = 0
Event("MERCHANT_UPDATE")
assert(VIC:GetItemVendors(100002).observedPriceText == "0c each")

-- Alternate costs are captured without inventing a pure-gold price.
slots[1].extended = true
function GetMerchantItemCostInfo() return 1 end
function GetMerchantItemCostItem() return nil, 2, "item:999" end
Event("MERCHANT_UPDATE")
info = VIC:GetItemVendors(100002)
assert(info.observedPriceText == nil and info.vendors[1].alternateCost)
local saved = VIC.observations.characters[character].offers["100001:100002"]
assert(saved.costsComplete and saved.costs[1].itemId == 999)
slots[1].extended = false

-- Missing slots never delete previously observed inventory. Delayed links are retried.
slots[2] = { itemId = 100004, price = 5, quantity = 1, stock = 0, purchasable = false, extended = false, pending = true }
Event("MERCHANT_UPDATE")
assert(VIC:GetItemVendors(100004) == nil and #delayed > 0)
slots[2].pending = false
table.remove(delayed, 1)()
assert(VIC:GetItemVendors(100004).vendors[1].stock == 0)
slots = { slots[1] }
Event("MERCHANT_UPDATE")
assert(VIC:GetItemVendors(100004), "Filtered/absent slots cannot prove removal")

-- A retry cannot write a different merchant or run after the window closes.
slots[1].pending = true
Event("MERCHANT_UPDATE")
Event("MERCHANT_CLOSED")
merchant = "Creature-0-1-2-3-100005-0000000002"
slots[1].pending = false
for _, callback in ipairs(delayed) do callback() end
assert(VIC:GetItemVendors(100002).totalCount == 1)
delayed = {}
Event("MERCHANT_SHOW")
assert(VIC:GetItemVendors(100002).totalCount == 2)

-- Quotes and observed access do not transfer to other characters.
character = "Player-1-OTHERPRIVATECHARACTER"
info = VIC:GetItemVendors(100002)
assert(info.observedPriceText == nil and not info.vendors[1].accessObserved)
assert(info.vendors[1].personal)

-- Recording off and addon off both stop collection; old observations remain readable.
SlashCmdList.VENDORITEMCHECK("recording off")
slots[1].itemId = 100006
Event("MERCHANT_UPDATE")
assert(VIC:GetItemVendors(100006) == nil and VIC:GetItemVendors(100002))
SlashCmdList.VENDORITEMCHECK("recording on")
assert(VIC:GetItemVendors(100006))
VIC.settings.enabled = false
slots[1].itemId = 100007
Event("MERCHANT_UPDATE")
assert(VIC:GetItemVendors(100007) == nil)
VIC.settings.enabled = true

-- Missing optional map/timer APIs: unknown location, event-driven retry fallback.
C_Map, C_Timer = nil, nil
slots[1].pending = true
Event("MERCHANT_SHOW")
assert(VIC.merchantFrame.scripts.OnUpdate)
slots[1].pending = false
VIC.merchantFrame.scripts.OnUpdate(VIC.merchantFrame, 1)
assert(VIC:GetItemVendors(100007).vendors[1].x == 0)
local items, vendors = VIC:CountPersonalItems()
assert(items > 0 and vendors == 2)
now = now + 31 * 86400
VIC:RebuildPersonalIndex()
assert(VIC:CountPersonalItems() == 0 and VIC:GetItemVendors(100002) == nil)
VendorItemCheckDB.observations = { schema = 999, characters = { future = true } }
local fresh = {}
assert(loadfile("VendorItemCheck/Core.lua"))("VendorItemCheck", fresh)
assert(loadfile("VendorItemCheck/Merchant.lua"))("VendorItemCheck", fresh)
fresh.client = "forever"
fresh:InitializeDB()
fresh:InitializeObservations()
assert(fresh.observations == nil and VendorItemCheckDB.observations.schema == 999)
print("=== ALL MERCHANT RECORDING SMOKE TESTS PASSED ===")
