-- Reuse the modern UI harness, then start a fresh Forever addon namespace.
dofile("tests/smoke.lua")

function GetBuildInfo() return "1.60.1", "70790", "", 16001 end
local now = 1793836800
function time() return now end

local VIC = {}
assert(loadfile("VendorItemCheck/Data.lua"))("VendorItemCheck", VIC)
assert(loadfile("VendorItemCheck/DataForever.lua"))("VendorItemCheck", VIC)
assert(loadfile("VendorItemCheck/Core.lua"))("VendorItemCheck", VIC)
assert(loadfile("VendorItemCheck/Merchant.lua"))("VendorItemCheck", VIC)
assert(loadfile("VendorItemCheck/Export.lua"))("VendorItemCheck", VIC)
assert(loadfile("VendorItemCheck/Tooltip.lua"))("VendorItemCheck", VIC)
assert(loadfile("VendorItemCheck/Options.lua"))("VendorItemCheck", VIC)
VendorItemCheckDB = { enabled = true, maxVendors = 3, modifierKey = "ALT", customSetting = "preserve" }
VIC:SelectDataset()
VIC:InitializeDB()
VIC:MerchantInitialize()
VIC:TooltipInitialize()
VIC:OptionsInitialize()
assert(VIC.client == "forever")
assert(VIC.settings.maxVendors == 3 and VIC.settings.customSetting == "preserve")
assert(VIC.Items ~= VIC.Datasets.classic.items)
assert(VIC:GetItemVendors(159) == nil, "Classic water vendors must not leak into Forever")
local calledInformant = false
Informant = { GetItem = function() calledInformant = true; return { buy = 999 } end }
assert(VIC:GetItemVendors(999999) == nil and not calledInformant)

-- Synthetic test records only; no invented records are shipped in the addon data.
VIC.Items = {
    [100002] = { v = { 100001, 100003 }, p = 999999, offers = {
        [100001] = { reporters = 3, expires = now + 10, observedCopper = 500, priceContext = "unknown" },
        [100003] = { reporters = 3, expires = now + 10, observedCopper = 100, priceContext = "unknown" },
    } },
}
VIC.Vendors = {
    [100001] = { "Confirmed Vendor", "Location unknown", "?", 41, 65, mapID = 1429, approximate = true,
                 nameExpires = now + 5, locationExpires = now + 5 },
    [100003] = { "Vendor 100003", "Location unknown", "?", 0, 0 },
}
C_Map.GetMapInfo = function() return { name = "Elwynn Forest" } end
local info = VIC:GetItemVendors(100002)
assert(info.totalCount == 2 and not info.enemyOnly)
assert(info.price == nil, "Unknown quantity/discount prices must never become unit prices")
assert(info.vendors[1].zone == "Elwynn Forest" and info.vendors[1].approximate)
assert(info.vendors[2].zone == "Location unknown")

local alt = false
IsAltKeyDown = function() return alt end
local tip = CreateFrame("GameTooltip", "ForeverTestTooltip")
tip:SetHyperlink("item:100002:0:0:0")
assert(tip:NumLines() == 2, "Confirmed item should have one compact section")
assert(tip.lines[2].left:find("Sold by vendor"))
assert(not tip.lines[2].left:find("999999"))
alt = true
tip:SetHyperlink("item:100002:0:0:0")
local access, credit, approximate = false, false, false
for _, line in ipairs(tip.lines) do
    local text = (line.left or "") .. (line.right or "")
    access = access or text:find("Access unverified", 1, true)
    credit = credit or text:find("https://everloot.app", 1, true)
    approximate = approximate or text:find("~41.0", 1, true)
    assert(not text:find("[Neutral]", 1, true))
end
assert(access and credit and approximate)

now = now + 6
info = VIC:GetItemVendors(100002)
assert(info.totalCount == 2, "Inventory confirmation remains current")
assert(info.vendors[1].name == "Vendor 100001" and info.vendors[1].x == 0,
    "Names and locations must expire independently of inventory")

-- Missing map API and unknown faction must be harmless and never invent data.
C_Map = nil
UnitFactionGroup = nil
VIC.playerFaction = nil
assert(VIC:GetPlayerFaction() == nil)
info = VIC:GetItemVendors(100002)
assert(info.vendors[1].zone == "Location unknown")
assert(VIC:IsVendorFriendly("H", nil))
now = now + 5
assert(VIC:GetItemVendors(100002).totalCount == 0, "Expired observations must disappear")
tip:SetHyperlink("item:100002:0:0:0")
assert(tip:NumLines() == 0)

GetBuildInfo = nil
VIC:SelectDataset()
assert(VIC.client == "unknown" and VIC:GetItemVendors(159) == nil)
GetBuildInfo = function() error("unavailable") end
VIC:SelectDataset()
assert(VIC.client == "unknown")
GetBuildInfo = function() return "1.60.1", "70790", "", nil end
VIC:SelectDataset()
assert(VIC.client == "forever", "Version fallback must recognize Forever")
GetBuildInfo = function() return "11.0.0", "0", "", 110000 end
VIC:SelectDataset()
assert(VIC.client == "unknown")
print("=== ALL FOREVER SMOKE TESTS PASSED (synthetic offers; live coverage unverified in game) ===")
