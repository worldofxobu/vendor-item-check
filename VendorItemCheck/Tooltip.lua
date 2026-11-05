local _, VIC = ...

local SECTION_HEADER_TAG = "Sold by vendor"
local activeTooltips = setmetatable({}, { __mode = "k" })
local isRefreshing = false
local UpdatePolling
local PollTooltips
local RefreshTooltip
local isPolling = false
local pollElapsed = 0

local function ForgetTooltip(tooltip)
    activeTooltips[tooltip] = nil
    tooltip._vicItemID = nil
    tooltip._vicLink = nil
    tooltip._vicWasExpanded = nil
    tooltip._vicHint = nil
    if UpdatePolling then UpdatePolling() end
end

local function CleanText(text)
    if not text then return "" end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return strtrim(text)
end

local function GetTooltipItemID(tooltip, tooltipData)
    local ok, itemID, itemLink = pcall(function()
        if tooltipData and type(tooltipData.id) == "number" then
            return tooltipData.id
        end

        local _, itemLink = tooltip:GetItem()
        if itemLink then
            return tonumber(string.match(itemLink, "item:(%d+)")), itemLink
        end
    end)

    if ok then return itemID, itemLink end
    return nil
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

local CONTROLLER_BINDINGS = {
    LT = "PADLTRIGGER", RT = "PADRTRIGGER", LB = "PADLSHOULDER", RB = "PADRSHOULDER",
}

function VIC:GetControllerModifierState()
    local choice = self.settings and self.settings.controllerModifier or self.defaults.controllerModifier
    local binding = CONTROLLER_BINDINGS[choice]
    local api = C_GamePad
    if self.client ~= "forever" or not binding or type(api) ~= "table" or
        type(api.GetDeviceMappedState) ~= "function" or type(api.ButtonBindingToIndex) ~= "function" then
        return false, false
    end
    -- Read the physical mapped state, independently of Alt/Shift/Ctrl emulation.
    -- No bindings, focus, gamepad events, or game CVars are taken over.
    local ok, pressed, available = pcall(function()
        if api.IsEnabled and not api.IsEnabled() then return false, false end
        if api.GetAllDeviceIDs then
            local devices = api.GetAllDeviceIDs()
            if type(devices) ~= "table" or next(devices) == nil then return false, false end
        end
        local deviceID
        if api.GetActiveDeviceID then deviceID = api.GetActiveDeviceID()
        elseif api.GetCombinedDeviceID then deviceID = api.GetCombinedDeviceID() end
        local state = api.GetDeviceMappedState(deviceID)
        local index = api.ButtonBindingToIndex(binding)
        if not state or type(state.buttons) ~= "table" or type(index) ~= "number" or
            index < 0 or index % 1 ~= 0 then return false, false end
        -- Binding indices are zero based; the state.buttons array is one based.
        local down = state.buttons[index + 1]
        if type(down) ~= "boolean" then return false, false end
        return down, true
    end)
    if ok then return pressed, available end
    return false, false
end

function VIC:GetExpansionState()
    local settings = self.settings
    local mod = settings and settings.modifierKey or "ALT"
    if mod == "NONE" then return true, nil end
    local keyboardDown = false
    if mod == "SHIFT" then keyboardDown = IsShiftKeyDown and IsShiftKeyDown() or false
    elseif mod == "CTRL" then keyboardDown = IsControlKeyDown and IsControlKeyDown() or false
    elseif mod == "ALT" then keyboardDown = IsAltKeyDown and IsAltKeyDown() or false end
    local controllerDown, available = self:GetControllerModifierState()
    local hint = mod ~= "OFF" and mod or nil
    if available then
        local controller = settings and settings.controllerModifier or self.defaults.controllerModifier
        hint = hint and (hint .. " or " .. controller) or controller
    end
    return keyboardDown or controllerDown, hint
end

function VIC:IsExpanded()
    local expanded = self:GetExpansionState()
    return expanded
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

function VIC:AddVendorSection(tooltip, itemID, itemInfo, isExpanded, hintKey)
    if TooltipContainsSection(tooltip) then
        return
    end

    local settings = self.settings or self.defaults
    if isExpanded == nil then isExpanded, hintKey = self:GetExpansionState() end

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
    elseif settings.showPrice and not isExpanded and itemInfo.observedPriceText then
        priceText = ": " .. itemInfo.observedPriceText .. " |cff888888(observed)|r"
    end

    if not isExpanded then
        -- Compact line
        local hintText = ""
        if hintKey then
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
                rightParts[#rightParts + 1] = v.accessObserved and "|cff888888[Observed access]|r" or GetFactionTag(v.faction)
            end

            if v.personal then
                local stamp = date and date("!%Y-%m-%d", v.observedAt) or "previous visit"
                rightParts[#rightParts + 1] = "|cff888888Observed " .. stamp .. "|r"
                if settings.showPrice and v.quoteText then
                    rightParts[#rightParts + 1] = v.quoteText
                elseif settings.showPrice and v.alternateCost then
                    rightParts[#rightParts + 1] = "Alternate cost; see merchant"
                end
                if v.stock == 0 then rightParts[#rightParts + 1] = "Out of stock when observed" end
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
            local hasBundled = false
            for _, vendor in ipairs(vendors) do if not vendor.personal then hasBundled = true end end
            if hasBundled then
                tooltip:AddLine("|cff888888Bundled access unverified; no personal price quote.|r", 0.6, 0.6, 0.6)
                local credit = self.dataMetadata and self.dataMetadata.credit or "Everloot: https://everloot.app (CC BY-SA 4.0)"
                tooltip:AddLine("|cff888888" .. credit .. "|r", 0.6, 0.6, 0.6)
            end
        end
    end

    tooltip:Show()
end

local function ProcessItemTooltip(tooltip, tooltipData)
    if not VIC.settings or not VIC.settings.enabled then
        ForgetTooltip(tooltip)
        return
    end

    local itemID = GetTooltipItemID(tooltip, tooltipData)
    if not itemID then
        ForgetTooltip(tooltip)
        return
    end

    local _, itemLink = GetTooltipItemID(tooltip)
    local itemInfo = VIC:GetItemVendors(itemID)
    if itemInfo and (itemInfo.totalCount > 0 or itemInfo.enemyOnly) then
        local expanded, hint = VIC:GetExpansionState()
        local ok = pcall(VIC.AddVendorSection, VIC, tooltip, itemID, itemInfo, expanded, hint)
        if ok then
            tooltip._vicItemID = itemID
            tooltip._vicLink = itemLink
            tooltip._vicWasExpanded = expanded
            tooltip._vicHint = hint
            activeTooltips[tooltip] = true
            if tooltip.HookScript and not tooltip._vicCleanupHooked then
                tooltip._vicCleanupHooked = true
                pcall(tooltip.HookScript, tooltip, "OnHide", ForgetTooltip)
                pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", ForgetTooltip)
            end
            if UpdatePolling then UpdatePolling() end
            return
        end
    end
    ForgetTooltip(tooltip)
end

function VIC:RefreshVendorTooltips(force)
    local visible = {}
    for tip in pairs(activeTooltips) do
        local itemID, link = GetTooltipItemID(tip)
        -- Never restore a hidden tooltip or an old item after the UI reuses it.
        if not tip:IsVisible() or not tip._vicItemID or itemID ~= tip._vicItemID or
            (tip._vicLink and tip._vicLink ~= link) then
            ForgetTooltip(tip)
        else
            visible[#visible + 1] = tip
        end
    end
    if #visible == 0 or ((not self.settings or not self.settings.enabled) and not force) then
        if UpdatePolling then UpdatePolling() end
        return
    end
    local expanded, hint = self:GetExpansionState()
    -- Rebuilding a tooltip can fire OnTooltipCleared and change activeTooltips.
    for _, tip in ipairs(visible) do
        if force or tip._vicWasExpanded ~= expanded or tip._vicHint ~= hint then RefreshTooltip(tip) end
    end
    if UpdatePolling then UpdatePolling() end
end

PollTooltips = function(_, elapsed)
    pollElapsed = pollElapsed + elapsed
    if pollElapsed < 0.05 then return end
    pollElapsed = 0
    VIC:RefreshVendorTooltips(false)
end

UpdatePolling = function()
    local watcher = VIC.tooltipWatcher
    if not watcher then return end
    local settings = VIC.settings
    local shouldPoll = VIC.client == "forever" and settings and settings.enabled and
        settings.modifierKey ~= "NONE" and settings.controllerModifier ~= "OFF" and
        type(C_GamePad) == "table" and type(C_GamePad.GetDeviceMappedState) == "function" and
        type(C_GamePad.ButtonBindingToIndex) == "function" and next(activeTooltips) ~= nil
    shouldPoll = shouldPoll and true or false
    if shouldPoll ~= isPolling then
        isPolling = shouldPoll
        pollElapsed = 0
        watcher:SetScript("OnUpdate", shouldPoll and PollTooltips or nil)
    end
end

RefreshTooltip = function(tooltip)
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
            end
        end

        HookTooltip(GameTooltip)
        HookTooltip(ItemRefTooltip)
    else
        self:Print("Tooltip API unavailable; could not attach to item tooltips.")
    end

    -- Dynamic refresh on modifier state change
    local keyWatcher = CreateFrame("Frame")
    self.tooltipWatcher = keyWatcher
    keyWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    keyWatcher:SetScript("OnEvent", function()
        VIC:RefreshVendorTooltips(false)
    end)
    UpdatePolling()
end
