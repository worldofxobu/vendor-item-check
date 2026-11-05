local _, VIC = ...

local SECTION_HEADER_TAG = "Sold by vendor"
local activeTooltips = {}
local isRefreshing = false

local function CleanText(text)
    if not text then return "" end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return strtrim(text)
end

local function GetTooltipItemID(tooltip, tooltipData)
    local ok, itemID = pcall(function()
        if tooltipData and type(tooltipData.id) == "number" then
            return tooltipData.id
        end

        local _, itemLink = tooltip:GetItem()
        if itemLink then
            return tonumber(string.match(itemLink, "item:(%d+)"))
        end
    end)

    return ok and itemID or nil
end

local function TooltipContainsSection(tooltip)
    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return false
    end

    local numLines = tooltip.NumLines and tooltip:NumLines() or 0
    for i = 1, numLines do
        local line = _G[tooltipName .. "TextLeft" .. i]
        if line and line.GetText then
            local text = CleanText(line:GetText())
            if string.find(text, SECTION_HEADER_TAG, 1, true) then
                return true
            end
        end
    end
    return false
end

local function AddBlankLine(tooltip)
    if GameTooltip_AddBlankLineToTooltip then
        GameTooltip_AddBlankLineToTooltip(tooltip)
    else
        tooltip:AddLine(" ")
    end
end

function VIC:IsExpanded()
    local settings = self.settings
    local mod = settings and settings.modifierKey or "ALT"

    if mod == "NONE" then
        return true
    elseif mod == "SHIFT" then
        return IsShiftKeyDown and IsShiftKeyDown() or false
    elseif mod == "CTRL" then
        return IsControlKeyDown and IsControlKeyDown() or false
    else -- "ALT"
        return IsAltKeyDown and IsAltKeyDown() or false
    end
end

local function GetFactionTag(factionCode)
    if factionCode == "?" then
        return "|cff888888[Access unverified]|r"
    elseif factionCode == "A" then
        return "|cff0070dd[Alliance]|r"
    elseif factionCode == "H" then
        return "|cffc41e3a[Horde]|r"
    else
        return "|cffffff00[Neutral]|r"
    end
end

function VIC:AddVendorSection(tooltip, itemID, itemInfo)
    if TooltipContainsSection(tooltip) then
        return
    end

    local settings = self.settings or self.defaults
    local isExpanded = self:IsExpanded()

    AddBlankLine(tooltip)

    if itemInfo.enemyOnly then
        local enemyTag = itemInfo.enemyFaction or "Enemy"
        tooltip:AddLine(string.format("|cffff6666Sold by vendor (%s only)|r", enemyTag), 1.0, 0.4, 0.4)
        tooltip:Show()
        return
    end

    local vendors = itemInfo.vendors
    if not vendors or #vendors == 0 then
        return
    end

    local priceText = ""
    if settings.showPrice and itemInfo.price and itemInfo.price > 0 then
        priceText = ": " .. (self:FormatMoney(itemInfo.price) or "")
    end

    if not isExpanded then
        -- Compact line
        local hintKey = settings.modifierKey or "ALT"
        local hintText = ""
        if hintKey ~= "NONE" then
            hintText = string.format("  |cff888888(Hold %s for locations)|r", hintKey)
        end

        tooltip:AddLine("|cff00ff00Sold by vendor|r" .. priceText .. hintText, 1.0, 1.0, 1.0)
    else
        -- Expanded view
        local playerZone, playerX, playerY = self:GetPlayerLocation()
        if settings.showClosestFirst then
            vendors = self:SortVendorsByProximity(vendors, playerZone, playerX, playerY)
        end

        local header = "|cff00ff00Sold by vendors|r"
        if settings.showClosestFirst then
            header = header .. " |cff888888(closest first)|r"
        end
        if priceText ~= "" then
            header = header .. priceText
        end

        tooltip:AddLine(header, 1.0, 1.0, 1.0)

        local maxShown = math.max(1, tonumber(settings.maxVendors) or 4)
        local count = math.min(#vendors, maxShown)

        for i = 1, count do
            local v = vendors[i]
            local left = "  |cffffffff" .. v.name .. "|r"

            local rightParts = {}
            local zoneStr = v.zone or "Azeroth"
            if settings.showCoordinates and v.x > 0 and v.y > 0 then
                zoneStr = string.format("%s (%s%.1f, %.1f)", zoneStr, v.approximate and "~" or "", v.x, v.y)
            end
            rightParts[#rightParts + 1] = "|cffb0b0b0" .. zoneStr .. "|r"

            if settings.showFaction then
                rightParts[#rightParts + 1] = GetFactionTag(v.faction)
            end

            local right = table.concat(rightParts, " ")
            tooltip:AddDoubleLine(left, right, 1, 1, 1, 0.8, 0.8, 0.8)
        end

        if #vendors > count then
            tooltip:AddLine(
                string.format("  |cff888888+%d more vendors across Azeroth|r", #vendors - count),
                0.6, 0.6, 0.6
            )
        end
        if self.client == "forever" then
            tooltip:AddLine("|cff888888Access unverified; price unavailable.|r", 0.6, 0.6, 0.6)
            tooltip:AddLine("|cff888888Everloot: https://everloot.app (CC BY-SA 4.0)|r", 0.6, 0.6, 0.6)
        end
    end

    tooltip:Show()
end

local function ProcessItemTooltip(tooltip, tooltipData)
    if not VIC.settings or not VIC.settings.enabled then
        return
    end

    local itemID = GetTooltipItemID(tooltip, tooltipData)
    if not itemID then
        tooltip._vicItemID = nil
        tooltip._vicLink = nil
        return
    end

    local itemLink
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        itemLink = link
    end
    tooltip._vicItemID = itemID
    tooltip._vicLink = itemLink
    tooltip._vicWasExpanded = VIC:IsExpanded()
    activeTooltips[tooltip] = true

    local itemInfo = VIC:GetItemVendors(itemID)
    if itemInfo and (itemInfo.totalCount > 0 or itemInfo.enemyOnly) then
        pcall(VIC.AddVendorSection, VIC, tooltip, itemID, itemInfo)
    end
end

local function RefreshTooltip(tooltip)
    if isRefreshing or not tooltip or not tooltip:IsVisible() then
        return
    end

    local link = tooltip._vicLink
    if not link then
        local _, itemLink
        if tooltip.GetItem then
            _, itemLink = tooltip:GetItem()
        end
        link = itemLink
    end

    if not link then
        return
    end

    isRefreshing = true
    pcall(function()
        if tooltip.SetHyperlink then
            tooltip:SetHyperlink(link)
        end
    end)
    isRefreshing = false
end

function VIC:TooltipInitialize()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ProcessItemTooltip)
    elseif GameTooltip and GameTooltip.HookScript then
        local function HookTooltip(tip)
            if tip and tip.HookScript then
                tip:HookScript("OnTooltipSetItem", function(self)
                    ProcessItemTooltip(self)
                end)
                tip:HookScript("OnHide", function(self)
                    self._vicItemID = nil
                    self._vicLink = nil
                    activeTooltips[self] = nil
                end)
            end
        end

        HookTooltip(GameTooltip)
        HookTooltip(ItemRefTooltip)
    else
        self:Print("Tooltip API unavailable; could not attach to item tooltips.")
    end

    -- Dynamic refresh on modifier state change
    local keyWatcher = CreateFrame("Frame")
    keyWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    keyWatcher:SetScript("OnEvent", function()
        if not VIC.settings or not VIC.settings.enabled then
            return
        end

        local currentExpanded = VIC:IsExpanded()

        for tip in pairs(activeTooltips) do
            if tip:IsVisible() and tip._vicItemID then
                if tip._vicWasExpanded ~= currentExpanded then
                    RefreshTooltip(tip)
                end
            else
                activeTooltips[tip] = nil
            end
        end
    end)
end
