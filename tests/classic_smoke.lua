-- Standalone smoke test for Vendor Item Check in Classic Era / legacy environment.
-- Run with: lua tests/classic_smoke.lua

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
function IsAltKeyDown() return isAltDown end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end

-- Pure Classic Era: No C_Map, legacy zone text only
C_Map = nil
Enum = nil
TooltipDataProcessor = nil

GetRealZoneText = function() return "Stormwind City" end
GetZoneText = function() return "Stormwind City" end

function CreateFrame(frameType, name, parent, template)
    local f = {
        name = name,
        events = {},
        scripts = {},
        lines = {},
        hooks = {},
        visible = true,
    }
    function f:RegisterEvent(event)
        self.events[event] = true
    end
    function f:SetScript(event, callback)
        self.scripts[event] = callback
    end
    function f:HookScript(event, callback)
        self.hooks[event] = callback
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
        if self.hooks["OnTooltipSetItem"] then
            self.hooks["OnTooltipSetItem"](self)
        end
    end
    frames[#frames + 1] = f
    return f
end

GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
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

print("=== Running Vendor Item Check Smoke Tests (Classic Era Legacy) ===")

-- Verify GameTooltip Hooked
assert(GameTooltip.hooks["OnTooltipSetItem"], "GameTooltip must be hooked via OnTooltipSetItem in Classic Era")
print("PASS: OnTooltipSetItem hook registered on GameTooltip")

-- Simulate hovering item 85 (Horde only for Alliance player)
GameTooltip:SetHyperlink("item:85:0:0:0")
assert(GameTooltip:NumLines() > 0, "Tooltip must have lines")

local foundHordeOnly = false
for _, line in ipairs(GameTooltip.lines) do
    if line.left and line.left:find("Sold by vendor") and line.left:find("Horde only") then
        foundHordeOnly = true
    end
end
assert(foundHordeOnly, "GameTooltip must show 'Sold by vendor (Horde only)' for Alliance player")
print("PASS: Enemy-faction item correctly flagged in Classic Era tooltip")

-- Simulate hovering item 159 (Refreshing Spring Water)
GameTooltip:SetHyperlink("item:159:0:0:0")
assert(GameTooltip:NumLines() > 0, "Tooltip must have lines")

local foundSold = false
for _, line in ipairs(GameTooltip.lines) do
    if line.left and line.left:find("Sold by vendor") then
        foundSold = true
    end
end
assert(foundSold, "GameTooltip must show 'Sold by vendor' for water in Classic Era")
print("PASS: Classic Era item tooltip populated via OnTooltipSetItem")

-- Test Alt Expansion in Classic
isAltDown = true
for _, frame in ipairs(frames) do
    if frame.events["MODIFIER_STATE_CHANGED"] and frame.scripts["OnEvent"] then
        frame.scripts["OnEvent"](frame, "MODIFIER_STATE_CHANGED")
    end
end

local foundExpanded = false
for _, line in ipairs(GameTooltip.lines) do
    if line.left and line.left:find("Sold by vendors") then
        foundExpanded = true
    end
end
assert(foundExpanded, "Classic Era tooltip must expand on Alt press")
print("PASS: Classic Era tooltip dynamic Alt expansion verified")

print("=== ALL CLASSIC ERA SMOKE TESTS PASSED! ===")
