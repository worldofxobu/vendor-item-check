-- An actual scanner-to-export fixture, never loaded by addon TOCs.
local originalPrint = print
print = function() end
dofile("tests/smoke.lua")
print = originalPrint

local now = tonumber(arg and arg[2]) or 1793847600
function GetBuildInfo() return "1.60.1", "70790", "", 16001 end
function time() return now end
function IsTestBuild() return false end
function UnitGUID(unit)
    if unit == "npc" then return "Creature-0-1-2-3-100001-0000000001" end
    return "Player-1-PRIVATE_CHARACTER_GUID"
end
function UnitName(unit) return unit == "npc" and 'Éowyn "Vendor"' or "PRIVATE_CHARACTER_NAME" end
function GetMerchantNumItems() return 1 end
function GetMerchantItemLink() return "item:100002" end
function GetMerchantItemInfo() return "Item", nil, 20, 5, -1, true, true, false end
function GetMerchantPriceDiscount() return 0.95 end

local VIC = {}
for _, file in ipairs({ "Data", "DataForever", "Core", "Merchant", "Export", "Tooltip", "Options" }) do
    assert(loadfile("VendorItemCheck/" .. file .. ".lua"))("VendorItemCheck", VIC)
end
VendorItemCheckDB = { privateSetting = "PRIVATE_TOKEN", accountName = "PRIVATE_ACCOUNT", realmName = "PRIVATE_REALM" }
VIC:SelectDataset()
VIC:InitializeDB()
VIC:MerchantInitialize()
VIC.observations.reporterId = (arg and arg[1]) or ("vic-" .. string.rep("1", 32))
VIC.merchantFrame.scripts.OnEvent(VIC.merchantFrame, "MERCHANT_SHOW")
VIC.observations.characters[UnitGUID("player")].offers["100001:100002"].privateNote = "PRIVATE_NOTE"
if arg and arg[0] and string.match(arg[0], "contribution_fixture%.lua$") then
    print(assert(VIC:BuildContribution()))
end
return VIC
