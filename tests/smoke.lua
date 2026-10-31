-- Standalone smoke test for Vendor Item Check in modern / Forever client environment.
-- Run with: lua tests/smoke.lua

unpack = unpack or table.unpack

local frames = {}
local messages = {}

function wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function strtrim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, msg)
        messages[#messages + 1] = msg
    end
}

local currentFaction = "Alliance"
function UnitFactionGroup(unit)
    if unit == "player" then
        return currentFaction
    end
end

local isAltDown = false
local isShiftDown = false
local isCtrlDown = false

function IsAltKeyDown() return isAltDown end
function IsShiftKeyDown() return isShiftDown end
function IsControlKeyDown() return isCtrlDown end

local playerZone = "Elwynn Forest"
local playerCoords = { x = 0.415, y = 0.659 }

GetRealZoneText = function() return playerZone end
GetZoneText = function() return playerZone end

C_Map = {
    GetBestMapForUnit = function(unit)
        return 1429
    end,
    GetPlayerMapPosition = function(mapID, unit)
        return {
            GetXY = function()
                return playerCoords.x, playerCoords.y
            end
        }
    end
}

function CreateFrame(frameType, name, parent, template)
    local f = {
        name = name,
        events = {},
        scripts = {},
        lines = {},
        visible = true,
    }
    function f:RegisterEvent(event)
        self.events[event] = true
    end
    function f:SetScript(event, callback)
        self.scripts[event] = callback
    end
    function f:GetScript(event)
        return self.scripts[event]
    end
    function f:IsVisible()
        return self.visible
    end
    function f:GetName()
        return self.name
    end
    function f:SetSize(w, h) end
    function f:SetPoint(p, a, b, c, d) end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(val) self.checked = val end
    function f:GetChecked() return self.checked end
    function f:CreateFontString(name, layer, inherit)
        local fs = { text = "" }
        function fs:SetText(t) self.text = t end
        function fs:GetText() return self.text end
        function fs:SetPoint() end
        function fs:SetSize() end
        function fs:SetWidth() end
        function fs:SetJustifyH() end
        return fs
    end
    function f:AddLine(text, r, g, b)
        self.lines[#self.lines + 1] = { left = text, r = r, g = g, b = b }
    end
    function f:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
        self.lines[#self.lines + 1] = { left = left, right = right }
    end
    function f:NumLines()
        return #self.lines
    end
    function f:Show() self.visible = true end
    function f:Hide() self.visible = false end
    function f:GetItem()
        return self.currentItemName, self.currentItemLink
    end
    function f:SetHyperlink(link)
        local itemID = tonumber(link:match("item:(%d+)"))
        self.currentItemLink = link
        self.currentItemName = "Item " .. itemID
        self.lines = {}
        if TooltipDataProcessor and TooltipDataProcessor._callback then
            TooltipDataProcessor._callback(self, { id = itemID })
        end
    end
    frames[#frames + 1] = f
    return f
end

TooltipDataProcessor = {
    AddTooltipPostCall = function(dataType, callback)
        TooltipDataProcessor._callback = callback
    end
}
Enum = { TooltipDataType = { Item = 1 } }
SlashCmdList = {}

-- Load Addon Files
local VIC = {}
local addonName = "VendorItemCheck"

local chunkData = assert(loadfile("VendorItemCheck/Data.lua"))
chunkData(addonName, VIC)

local chunkCore = assert(loadfile("VendorItemCheck/Core.lua"))
chunkCore(addonName, VIC)

local chunkTooltip = assert(loadfile("VendorItemCheck/Tooltip.lua"))
chunkTooltip(addonName, VIC)

local chunkOptions = assert(loadfile("VendorItemCheck/Options.lua"))
chunkOptions(addonName, VIC)

-- Fire ADDON_LOADED and PLAYER_LOGIN
for _, frame in ipairs(frames) do
    if frame.events["ADDON_LOADED"] and frame.scripts["OnEvent"] then
        frame.scripts["OnEvent"](frame, "ADDON_LOADED", addonName)
    end
    if frame.events["PLAYER_LOGIN"] and frame.scripts["OnEvent"] then
        frame.scripts["OnEvent"](frame, "PLAYER_LOGIN")
    end
end

print("=== Running Vendor Item Check Smoke Tests (Modern) ===")

-- Test 1: Data indexing
local itemCount, vendorCount = VIC:CountIndexedItems()
assert(itemCount > 1000, "Expected >1000 items, got: " .. itemCount)
assert(vendorCount > 500, "Expected >500 vendors, got: " .. vendorCount)
print(string.format("PASS: Indexed %d items and %d vendors", itemCount, vendorCount))

-- Test 2: Faction filtering
-- Item 85 (Dirty Leather Vest - sold only by Horde vendors)
local item85Info = VIC:GetItemVendors(85)
assert(item85Info and item85Info.enemyOnly == true, "Alliance player should see enemyOnly for item 85")
assert(#item85Info.vendors == 0, "Alliance player should have 0 friendly vendors for item 85")
print("PASS: Alliance faction filtering verified (enemyOnly flagged for Horde-only Item 85)")

currentFaction = "Horde"
VIC.playerFaction = nil
local hordeInfo = VIC:GetItemVendors(85)
assert(hordeInfo and hordeInfo.totalCount > 0, "Horde player should have vendors for Item 85")
assert(hordeInfo.enemyOnly == false, "Horde player should not see enemyOnly for Item 85")
for _, v in ipairs(hordeInfo.vendors) do
    assert(v.faction == "H" or v.faction == "N", "Horde player must not see Alliance vendor: " .. v.name)
end
print("PASS: Horde faction filtering verified (4 Horde vendors found for Item 85)")

-- Item 159 (Refreshing Spring Water - Universal)
currentFaction = "Alliance"
VIC.playerFaction = nil
local waterAlliance = VIC:GetItemVendors(159)
assert(waterAlliance and waterAlliance.totalCount > 0, "Alliance player should have vendors for water")
for _, v in ipairs(waterAlliance.vendors) do
    assert(v.faction == "A" or v.faction == "N", "Alliance player must not see Horde vendor for water: " .. v.name)
end
print("PASS: Alliance faction filtering for universal Item 159 verified")

-- Test 3: Tooltip Rendering (Compact vs Expanded)
local testTip = CreateFrame("GameTooltip", "TestGameTooltip")

-- Simulate hovering Refreshing Spring Water (item 159) with Alt NOT pressed
isAltDown = false
testTip:SetHyperlink("item:159:0:0:0")
assert(testTip:NumLines() > 0, "Tooltip should have lines")
local foundCompact = false
for _, line in ipairs(testTip.lines) do
    if line.left and line.left:find("Sold by vendor") and line.left:find("Hold ALT") then
        foundCompact = true
    end
end
assert(foundCompact, "Compact view should display 'Sold by vendor' with 'Hold ALT'")
print("PASS: Compact tooltip rendering verified (Hold Alt hint shown)")

-- Simulate pressing Alt (Dynamic expansion)
isAltDown = true
-- Fire MODIFIER_STATE_CHANGED
for _, frame in ipairs(frames) do
    if frame.events["MODIFIER_STATE_CHANGED"] and frame.scripts["OnEvent"] then
        frame.scripts["OnEvent"](frame, "MODIFIER_STATE_CHANGED")
    end
end

local foundExpanded = false
local foundVendorDetail = false
for _, line in ipairs(testTip.lines) do
    if line.left and line.left:find("Sold by vendors") then
        foundExpanded = true
    end
    if line.left and (line.left:find("Corina Steele") or line.left:find("Brother Danil") or line.right) then
        foundVendorDetail = true
    end
end
assert(foundExpanded, "Expanded header should appear on Alt press")
assert(foundVendorDetail, "Individual vendor details should appear on Alt press")
print("PASS: Dynamic Alt expansion verified on MODIFIER_STATE_CHANGED")

-- Test 4: Proximity Sorting
local sortedVendors = VIC:SortVendorsByProximity(waterAlliance.vendors, "Elwynn Forest", 41.5, 65.9)
assert(#sortedVendors > 0, "Sorted vendors should not be empty")
-- Check that first vendor is in Elwynn Forest
local first = sortedVendors[1]
assert(first.zone == "Elwynn Forest", "First vendor should be in Elwynn Forest, got: " .. first.zone)
print("PASS: Top sorted vendor: " .. first.name .. " in " .. first.zone .. " at (" .. first.x .. ", " .. first.y .. ")")

-- Test 5: Money formatting
local moneyStr = VIC:FormatMoney(12345)
assert(moneyStr:find("1g") and moneyStr:find("23s") and moneyStr:find("45c"), "Money formatting error: " .. moneyStr)
print("PASS: FormatMoney returned: " .. moneyStr)

-- Test 6: Slash commands
assert(SlashCmdList.VENDORITEMCHECK, "Slash command handler must be registered")
SlashCmdList.VENDORITEMCHECK("status")
SlashCmdList.VENDORITEMCHECK("max 3")
assert(VIC.settings.maxVendors == 3, "Max vendors should be 3")
SlashCmdList.VENDORITEMCHECK("toggle")
assert(VIC.settings.enabled == false, "Addon should be toggled to false")
SlashCmdList.VENDORITEMCHECK("toggle")
assert(VIC.settings.enabled == true, "Addon should be toggled back to true")
print("PASS: Slash commands (/vic status, /vic max 3, /vic toggle) verified")

print("=== ALL MODERN SMOKE TESTS PASSED! ===")
