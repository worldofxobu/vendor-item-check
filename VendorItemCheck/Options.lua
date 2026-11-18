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
    minus:SetPoint("LEFT", 175, 0)
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
        VIC:RefreshOptions()
    end

    minus:SetScript("OnClick", function() Change(-step) end)
    plus:SetScript("OnClick", function() Change(step) end)

    row.settingKey = key
    row.valueText = value
    controls[#controls + 1] = row
    return row
end

local function CreateModifierSelector(panel, anchor, key, caption, choices, labels, buttonName)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(460, 28)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(caption)

    local btn = CreateFrame("Button", buttonName, row, "UIPanelButtonTemplate")
    btn:SetSize(180, 22)
    btn:SetPoint("LEFT", 240, 0)

    local function UpdateButton()
        local current = VIC.settings[key] or VIC.defaults[key]
        btn:SetText(labels[current] or labels[VIC.defaults[key]])
    end

    btn:SetScript("OnClick", function()
        local entries = {}
        for _, value in ipairs(choices) do entries[#entries + 1] = { label = labels[value], value = value } end
        VIC:OpenChoiceMenu(btn, entries, function(value)
            VIC.settings[key] = value
            VIC:RefreshOptions()
        end)
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
    if self.optionsPreview then
        local lines = { "Live preview · Sample data", "Weak Flux" }
        if self.settings.enabled then
            local key = self.settings.modifierKey
            local hint = key ~= "OFF" and key ~= "NONE" and key or nil
            local controller = self.settings.controllerModifier
            if self.client == "forever" and key ~= "NONE" and controller ~= "OFF" and C_GamePad then
                hint = hint and (hint .. " or " .. controller) or controller
            end
            local preview = {
                GetName = function() end,
                Show = function() end,
                AddLine = function(_, line) lines[#lines + 1] = line end,
                AddDoubleLine = function(_, left, right) lines[#lines + 1] = left .. "\n  " .. right end,
            }
            local sample = { vendors = {} }
            for i, vendor in ipairs({ "Edna Mullby", "Kaita Deepforge", "Brooke Stonebrade", "Hammon Karwn" }) do
                sample.vendors[i] = { id = i, name = vendor, zone = "Example zone", x = 30 + i, y = 55 + i,
                    quoteText = "1s (example)" }
            end
            sample.observedPriceText = "1s (example)"
            self:AddVendorSection(preview, nil, sample, self.previewExpanded ~= false, hint, true)
        end
        self.optionsPreview:SetText(table.concat(lines, "\n"))
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
    local categoryPanel = panel
    local scroll = CreateFrame("ScrollFrame", nil, categoryPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0); scroll:SetPoint("BOTTOMRIGHT", -30, 0)
    panel = CreateFrame("Frame", nil, scroll)
    panel:SetSize(560, 850)
    scroll:SetScrollChild(panel)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(self.title)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    version:SetText("v" .. self.version)

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Enhances item tooltips by showing if an item can be bought from an NPC vendor.")

    local function Heading(text, anchor)
        local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        heading:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)
        heading:SetWidth(500); heading:SetJustifyH("LEFT"); heading:SetText(text)
        return heading
    end
    local tips = Heading("Tooltips", subtitle)
    local enabled = CreateCheckbox(panel, "enabled", "Enable tooltip enhancements", "Show known vendor information on item tooltips.", tips)
    local maxVendors = CreateStepper(panel, "maxVendors", "Maximum vendors:", 1, 10, 1, enabled)
    local closest = CreateCheckbox(panel, "showClosestFirst", "Prioritize nearby vendors", "Prioritizes your current zone; distances across zones are not comparable.", maxVendors)
    local coords = CreateCheckbox(panel, "showCoordinates", "Show coordinates", "Approximate locations retain their marker.", closest)
    local price = CreateCheckbox(panel, "showPrice", "Show qualified purchase prices", "Classic reference values or this character's observed quotes.", coords)
    local controlsHeading = Heading("Expansion controls", price)
    local modifier = CreateModifierSelector(panel, controlsHeading, "modifierKey", "Keyboard expansion:",
        VIC.keyboardModifiers, KEYBOARD_LABELS, "VICKeyboardModifier")
    if self.client == "forever" then
        modifier = CreateModifierSelector(panel, modifier, "controllerModifier", "Controller expansion:",
            VIC.controllerModifiers, CONTROLLER_LABELS, "VICControllerModifier")
        local hint = Heading("Controller expansion requires supported gamepad APIs; keyboard input remains available.", modifier)
        modifier = hint
    end
    local data = Heading("Merchant learning & data", modifier)
    if self.client == "forever" then
        data = CreateCheckbox(panel, "recordMerchants", "Learn from merchants I visit", "Saved locally. Sharing is optional and manual.", data)
    end
    local function Action(text, width, x, callback)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(width, 24); button:SetPoint("TOPLEFT", data, "BOTTOMLEFT", x, -18)
        button:SetText(text); button:SetScript("OnClick", callback)
        return button
    end
    Action("Browse", 90, 0, function() VIC:OpenBrowser() end)
    Action("Data & sharing", 155, 95, function() VIC:OpenDataView("overview") end)
    local reset = Action("Reset settings", 130, 260, function(button)
        VIC:OpenChoiceMenu(button or VIC.optionsPanel, {
            { label = "Cancel — keep settings", value = false },
            { label = "Reset settings; preserve observations", value = true },
        }, function(confirm)
            if not confirm then return end
            for key, value in pairs(VIC.defaults) do VIC.settings[key] = value end
            VIC:RefreshOptions()
        end)
    end)
    self.optionsPreview = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.optionsPreview:SetPoint("TOPLEFT", 325, -100)
    self.optionsPreview:SetWidth(210); self.optionsPreview:SetJustifyH("LEFT")
    for i, label in ipairs({ "Collapsed", "Expanded" }) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", 325 + (i - 1) * 96, -325)
        button:SetSize(90, 24)
        button:SetText(label)
        button:SetScript("OnClick", function()
            self.previewExpanded = label == "Expanded"
            self:RefreshOptions()
        end)
    end
    local commands = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    commands:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", -260, -15)
    commands:SetText("/vic · /vendorcheck · /vic browse · /vic settings · /vic help")

    categoryPanel:SetScript("OnShow", function()
        VIC:RefreshOptions()
    end)

    self.optionsPanel = categoryPanel

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(categoryPanel, categoryPanel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(categoryPanel)
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
            VIC:Print("Tooltip enhancement is now %s.", VIC.settings.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
        elseif cmd == "status" then
            if VIC.OpenBrowser and VIC.OpenDataView then VIC:OpenDataView("status")
            else
                local items, vendors = VIC:CountIndexedItems()
                VIC:Print("%d items and %d vendors indexed.", items, vendors)
            end
        elseif cmd == "settings" then
            VIC:OpenOptions()
        elseif cmd == "browse" or cmd == "" then
            VIC:OpenBrowser()
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
            local n = math.max(1, math.min(10, math.floor(tonumber(arg))))
            VIC.settings.maxVendors = n
            VIC:RefreshOptions()
            VIC:Print("Max vendors set to %d.", n)
        elseif cmd == "help" then
            VIC:Print("Commands:")
            VIC:Print("  /vic - Browse known items and vendors")
            VIC:Print("  /vic settings - Open settings")
            VIC:Print("  /vic browse - Browse known items and vendors")
            VIC:Print("  /vic toggle - Toggle tooltip enhancements")
            VIC:Print("  /vic status - Display index count and configuration")
            VIC:Print("  /vic max <1-10> - Set maximum vendors shown in tooltip")
            VIC:Print("  /vic recording on|off - Learn from Forever merchants")
            VIC:Print("  /vic export - Prepare a manual observation contribution")
        else
            VIC:OpenOptions()
        end
    end
end
