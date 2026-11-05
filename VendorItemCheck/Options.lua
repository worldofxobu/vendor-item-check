local _, VIC = ...

local controls = {}
local KEYBOARD_LABELS = { ALT = "Hold ALT", SHIFT = "Hold SHIFT", CTRL = "Hold CTRL", OFF = "Keyboard off", NONE = "Always expanded" }
local CONTROLLER_LABELS = { LT = "Hold LT / L2", RT = "Hold RT / R2", LB = "Hold LB / L1", RB = "Hold RB / R1", OFF = "Controller off" }

local function SetCheckboxText(checkbox, text)
    if checkbox.Text then
        checkbox.Text:SetText(text)
    else
        local label = _G[checkbox:GetName() .. "Text"]
        if label then
            label:SetText(text)
        end
    end
end

local function CreateCheckbox(panel, key, label, description, anchor)
    local name = "VICOption" .. key
    local checkbox = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    SetCheckboxText(checkbox, label)
    checkbox.tooltipText = label
    checkbox.tooltipRequirement = description
    checkbox:SetScript("OnClick", function(self)
        VIC.settings[key] = self:GetChecked() and true or false
        VIC:RefreshOptions()
    end)
    checkbox.settingKey = key
    controls[#controls + 1] = checkbox
    return checkbox
end

local function CreateStepper(panel, key, label, minimum, maximum, step, anchor)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(420, 28)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)

    local labelText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetText(label)

    local minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    minus:SetSize(28, 22)
    minus:SetPoint("LEFT", 240, 0)
    minus:SetText("-")

    local value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    value:SetSize(40, 20)
    value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    value:SetJustifyH("CENTER")

    local plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    plus:SetSize(28, 22)
    plus:SetPoint("LEFT", value, "RIGHT", 4, 0)
    plus:SetText("+")

    local function Change(delta)
        local current = tonumber(VIC.settings[key]) or minimum
        VIC.settings[key] = math.max(minimum, math.min(maximum, current + delta))
        value:SetText(VIC.settings[key])
    end

    minus:SetScript("OnClick", function() Change(-step) end)
    plus:SetScript("OnClick", function() Change(step) end)

    row.settingKey = key
    row.valueText = value
    controls[#controls + 1] = row
    return row
end

local function CreateModifierCycle(panel, anchor, key, caption, choices, labels, buttonName)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(460, 28)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(caption)

    local btn = CreateFrame("Button", buttonName, row, "UIPanelButtonTemplate")
    btn:SetSize(180, 22)
    btn:SetPoint("LEFT", 240, 0)

    local function GetCurrentIndex()
        local current = VIC.settings[key] or VIC.defaults[key]
        for i, k in ipairs(choices) do
            if k == current then return i end
        end
        return 1
    end

    local function UpdateButton()
        local current = VIC.settings[key] or VIC.defaults[key]
        btn:SetText(labels[current] or labels[VIC.defaults[key]])
    end

    btn:SetScript("OnClick", function()
        local idx = GetCurrentIndex()
        idx = (idx % #choices) + 1
        VIC.settings[key] = choices[idx]
        VIC:RefreshOptions()
    end)

    row.UpdateButton = UpdateButton
    controls[#controls + 1] = row
    return row
end

function VIC:RefreshOptions()
    if not self.settings then return end

    for _, ctrl in ipairs(controls) do
        if ctrl.settingKey then
            if ctrl.GetChecked then
                ctrl:SetChecked(self.settings[ctrl.settingKey] and true or false)
            elseif ctrl.valueText then
                ctrl.valueText:SetText(self.settings[ctrl.settingKey] or "")
            end
        elseif ctrl.UpdateButton then
            ctrl.UpdateButton()
        end
    end
    if self.RefreshVendorTooltips then self:RefreshVendorTooltips(true) end
end

function VIC:OpenOptions()
    if Settings and Settings.OpenToCategory and self.settingsCategoryID then
        Settings.OpenToCategory(self.settingsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end

function VIC:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "VendorItemCheckOptionsPanel", UIParent)
    panel.name = self.title

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(self.title)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    version:SetText("v" .. self.version)

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Enhances item tooltips by showing if an item can be bought from an NPC vendor.")

    local enabled = CreateCheckbox(panel, "enabled", "Enable Vendor Item Check", "Show vendor information on item tooltips.", subtitle)
    local recording = enabled
    if self.client == "forever" then
        recording = CreateCheckbox(panel, "recordMerchants", "Learn from merchants I visit", "Saves observed Forever offers locally. Sharing is manual.", enabled)
    end
    local modCycle = CreateModifierCycle(panel, recording, "modifierKey", "Keyboard expansion modifier:",
        VIC.keyboardModifiers, KEYBOARD_LABELS, "VICKeyboardModifier")
    if self.client == "forever" then
        modCycle = CreateModifierCycle(panel, modCycle, "controllerModifier", "Controller expansion modifier:",
            VIC.controllerModifiers, CONTROLLER_LABELS, "VICControllerModifier")
    end
    local maxVendors = CreateStepper(panel, "maxVendors", "Max vendors shown:", 1, 10, 1, modCycle)
    local closestFirst = CreateCheckbox(panel, "showClosestFirst", "Sort closest vendors first", "Shows vendors in your current zone and nearest coordinates first.", maxVendors)
    local coords = CreateCheckbox(panel, "showCoordinates", "Show vendor coordinates", "Shows (x, y) coordinates for vendor locations.", closestFirst)
    local price = CreateCheckbox(panel, "showPrice", "Show vendor purchase price", "Displays the vendor buy price in the tooltip.", coords)
    local faction = CreateCheckbox(panel, "showFaction", "Show vendor faction tag", "Displays [Alliance], [Horde], or [Neutral] tags.", price)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPLEFT", faction, "BOTTOMLEFT", 0, -20)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(VIC.defaults) do
            VIC.settings[k] = v
        end
        VIC:RefreshOptions()
        VIC:Print("Settings reset to defaults.")
    end)

    panel:SetScript("OnShow", function()
        VIC:RefreshOptions()
    end)

    self.optionsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    self:RefreshOptions()
end

function VIC:OptionsInitialize()
    self:CreateOptionsPanel()

    SLASH_VENDORITEMCHECK1 = "/vic"
    SLASH_VENDORITEMCHECK2 = "/vendorcheck"

    SlashCmdList.VENDORITEMCHECK = function(msg)
        msg = strtrim(string.lower(msg or ""))
        local cmd, arg = string.match(msg, "^(%S+)%s*(.*)$")
        cmd = cmd or ""

        if cmd == "toggle" then
            VIC.settings.enabled = not VIC.settings.enabled
            VIC:RefreshOptions()
            VIC:Print("Addon is now %s.", VIC.settings.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
        elseif cmd == "status" then
            local items, vendors = VIC:CountIndexedItems()
            VIC:Print("%d items and %d vendors indexed. Enabled: %s, Modifier: %s, Max: %d",
                items, vendors,
                VIC.settings.enabled and "Yes" or "No",
                VIC.settings.modifierKey,
                VIC.settings.maxVendors)
            local metadata = VIC.dataMetadata or {}
            VIC:Print("Dataset: %s. Source: %s. Data as of: %s. Build: %s.",
                metadata.client or "Unknown", metadata.source or "Unknown",
                metadata.dataAsOf or "Unknown", metadata.build or "Unknown")
            if VIC.client == "forever" then
                VIC:Print("Controller modifier: %s (observes held input; game controls are unchanged).",
                    CONTROLLER_LABELS[VIC.settings.controllerModifier] or "Controller off")
                local personalItems, personalVendors = 0, 0
                if VIC.CountPersonalItems then personalItems, personalVendors = VIC:CountPersonalItems() end
                VIC:Print("Personal observations: %d items, %d vendors. Recording: %s.", personalItems, personalVendors,
                    VIC.observations and VIC.settings.recordMerchants and "On" or "Off/unavailable")
                VIC:Print("Personal prices are observed quotes for this character. Missing data is unknown.")
                VIC:Print("%s", metadata.credit or "Data from Everloot (https://everloot.app), CC BY-SA 4.0.")
            end
        elseif cmd == "export" and VIC.OpenExport then
            VIC:OpenExport()
        elseif cmd == "recording" then
            if VIC.client ~= "forever" then VIC:Print("Merchant recording is available on Forever.")
            elseif arg == "on" or arg == "off" then
                VIC.settings.recordMerchants = arg == "on"
                VIC:RefreshOptions()
                if VIC.ScanMerchant then VIC:ScanMerchant() end
                VIC:Print("Merchant recording is %s.", arg)
            else VIC:Print("Usage: /vic recording on|off") end
        elseif cmd == "max" and tonumber(arg) then
            local n = math.max(1, math.min(10, tonumber(arg)))
            VIC.settings.maxVendors = n
            VIC:RefreshOptions()
            VIC:Print("Max vendors set to %d.", n)
        elseif cmd == "help" then
            VIC:Print("Commands:")
            VIC:Print("  /vic - Open settings")
            VIC:Print("  /vic toggle - Toggle enabled state")
            VIC:Print("  /vic status - Display index count and configuration")
            VIC:Print("  /vic max <1-10> - Set maximum vendors shown in tooltip")
            VIC:Print("  /vic recording on|off - Learn from Forever merchants")
            VIC:Print("  /vic export - Prepare a manual observation contribution")
        else
            VIC:OpenOptions()
        end
    end
end
