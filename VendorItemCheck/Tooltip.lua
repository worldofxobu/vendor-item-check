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

local function TooltipPrice(self, vendor, reference, showEach)
    if reference ~= nil then return self:FormatCoinIcons(reference) .. " (reference)" end
    local quantity = vendor.quantity
    if quantity == 1 and not showEach then quantity = nil end
    return self:FormatOfferPrice(vendor.copper, quantity, self.FormatCoinIcons)
end

local function CollapsedPrice(self, info)
    if info.price ~= nil then return TooltipPrice(self, nil, info.price) end
    local best, context, comparable, different
    local count = 0
    for _, vendor in ipairs(info.vendors) do
        if vendor.copper and vendor.accessObserved and vendor.stock ~= 0 then
            count = count + 1
            if not best then
                best, context, comparable = vendor, vendor.discount, vendor.discount ~= nil
            elseif context ~= vendor.discount then
                comparable = false
            else
                local price = vendor.copper * best.quantity
                local lowest = best.copper * vendor.quantity
                if price ~= lowest then different = true end
                if price < lowest then best = vendor end
            end
        end
    end
    if count == 1 or count > 1 and comparable then
        return (different and "from " or "") .. TooltipPrice(self, best, nil, true)
    end
end

local controllerCaptions = { LT = "LT / L2", RT = "RT / R2", LB = "LB / L1", RB = "RB / R1" }

function VIC:AddVendorSection(tooltip, itemID, itemInfo, isExpanded, hintKey, preview)
    if TooltipContainsSection(tooltip) then return end

    local settings = self.settings or self.defaults
    if isExpanded == nil then isExpanded, hintKey = self:GetExpansionState() end
    if not itemInfo.enemyOnly and (not itemInfo.vendors or #itemInfo.vendors == 0) then return end
    if not preview then AddBlankLine(tooltip) end
    if itemInfo.enemyOnly then
        tooltip:AddLine(("Sold by vendor (%s only)"):format(itemInfo.enemyFaction or "Enemy"), 1, 0.4, 0.4)
        tooltip:Show()
        return
    end

    if not isExpanded then
        local price = settings.showPrice and CollapsedPrice(self, itemInfo)
        tooltip:AddLine("|cff1eff00Sold by vendor" .. (price and ":|r " .. price or "|r"), 1, 1, 1)
        if hintKey then
            local caption = hintKey:gsub("%u+", controllerCaptions)
            tooltip:AddLine("Hold " .. caption .. " for locations", 0.67, 0.64, 0.59, true)
        end
    else
        local vendors = itemInfo.vendors
        if settings.showClosestFirst and not preview then
            local zone, x, y = self:GetPlayerLocation()
            self:SortVendorsByProximity(vendors, zone, x, y)
        end
        local header = "|cff1eff00Sold by vendors|r"
        if settings.showClosestFirst then header = header .. "  |cffa8a195(nearest first)|r" end
        tooltip:AddLine(header, 1, 1, 1)

        local maxShown = math.max(1, tonumber(settings.maxVendors) or 4)
        local count = math.min(#vendors, maxShown)
        local screenWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth()
        local narrow = not preview and screenWidth and screenWidth < 560
        for i = 1, count do
            local vendor = vendors[i]
            tooltip:AddLine(vendor.name, 0.95, 0.93, 0.88, true)
            local location = vendor.zone or "Location unavailable"
            if settings.showCoordinates and vendor.x and vendor.x > 0 and vendor.y and vendor.y > 0 then
                location = string.format("%s (%s%.1f, %.1f)", location, vendor.approximate and "~" or "", vendor.x, vendor.y)
            end
            local price = settings.showPrice and TooltipPrice(self, vendor, itemInfo.price)
            if price and not narrow then
                tooltip:AddDoubleLine(location, price, 0.67, 0.64, 0.59, 0.95, 0.93, 0.88)
            else
                tooltip:AddLine(location, 0.67, 0.64, 0.59, true)
                if price then tooltip:AddLine(price, 0.95, 0.93, 0.88, true) end
            end
        end
        local remaining = (preview and itemInfo.totalCount or #vendors) - count
        if remaining > 0 then tooltip:AddLine("+" .. remaining .. " more vendors", 0.67, 0.64, 0.59) end
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

    if not link or not tooltip.SetHyperlink then return end
    isRefreshing = true
    pcall(tooltip.SetHyperlink, tooltip, link)
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
