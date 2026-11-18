local _, VIC = ...

local controls = {}
local KEYBOARD_LABELS = { ALT = "Hold ALT", SHIFT = "Hold SHIFT", CTRL = "Hold CTRL", OFF = "Keyboard off", NONE = "Always expanded" }
local CONTROLLER_LABELS = { LT = "Hold LT / L2", RT = "Hold RT / R2", LB = "Hold LB / L1", RB = "Hold RB / R1", OFF = "Controller off" }

local function Text(parent, value, x, y, width, font)
    local text = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetText(value)
    return text
end

local function Button(parent, name, value, x, y, width, action)
    local template = not VIC.StyleBrowserSurface and "UIPanelButtonTemplate" or nil
    local button = CreateFrame("Button", name, parent, template)
    if VIC.StyleBrowserSurface then VIC:StyleBrowserSurface(button, "header") end
    if button.SetNormalFontObject then
        button:SetNormalFontObject(GameFontHighlightSmall)
        button:SetHighlightFontObject(GameFontNormalSmall)
        button:SetDisabledFontObject(GameFontDisableSmall)
    end
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(value)
    button:SetScript("OnClick", action)
    return button
end

local function Help(parent, x, y, message)
    local button = Button(parent, nil, "?", x, y, 19)
    local function Show(owner)
        if not GameTooltip or not GameTooltip.SetText then return end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(message, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
    button:SetScript("OnEnter", Show)
    button:SetScript("OnClick", Show)
    button:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end)
end

local function Rule(parent, y, width, gold)
    if not parent.CreateTexture then return end
    local line = parent:CreateTexture(nil, "ARTWORK")
    if not line.SetColorTexture then return end
    line:SetPoint("TOPLEFT", 0, y)
    line:SetSize(width, 1)
    if gold then line:SetColorTexture(0.55, 0.42, 0.22, 1)
    else line:SetColorTexture(0.32, 0.29, 0.23, 1) end
    return line
end

local function CreateCheckbox(parent, key, label, description, y)
    local checkbox = CreateFrame("CheckButton", "VICOption" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 0, y)
    checkbox:SetSize(21, 21)
    local nativeText = checkbox.Text or _G["VICOption" .. key .. "Text"]
    if nativeText then nativeText:SetText("") end
    Text(parent, label, 29, y - 5, 226)
    Help(parent, 263, y + 1, description)
    checkbox:SetScript("OnClick", function(control)
        VIC.settings[key] = control:GetChecked() and true or false
        VIC:RefreshOptions()
    end)
    checkbox.settingKey = key
    controls[#controls + 1] = checkbox
end

local function CreateStepper(parent, y)
    Text(parent, "Maximum vendors", 0, y - 6, 145)
    Help(parent, 149, y, "Number of sellers shown on the expanded tooltip, from 1 to 10.")
    local function Change(delta)
        local current = tonumber(VIC.settings.maxVendors) or 4
        VIC.settings.maxVendors = math.max(1, math.min(10, current + delta))
        VIC:RefreshOptions()
    end
    Button(parent, nil, "-", 201, y, 25, function() Change(-1) end)
    local value = Text(parent, "", 229, y - 6, 25)
    value:SetJustifyH("CENTER")
    Button(parent, nil, "+", 257, y, 25, function() Change(1) end)
    controls[#controls + 1] = { settingKey = "maxVendors", valueText = value }
end

local function CreateModifierSelector(parent, y, key, caption, choices, labels, buttonName, description)
    Text(parent, caption, 0, y - 6, 96)
    Help(parent, 100, y, description)
    local button
    button = Button(parent, buttonName, "", 136, y, 146, function()
        local entries = {}
        for _, value in ipairs(choices) do entries[#entries + 1] = { label = labels[value], value = value } end
        VIC:OpenChoiceMenu(button, entries, function(value)
            VIC.settings[key] = value
            VIC:RefreshOptions()
        end)
    end)
    controls[#controls + 1] = { UpdateButton = function()
        button:SetText(labels[VIC.settings[key]] or labels[VIC.defaults[key]])
    end }
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
        local lines = { "|cffffffffWeak Flux|r", "|cff71a9faCrafting Reagent|r",
            "|cffffcc00Used by Blacksmiths to remove impurities.|r", " ", "|cffffcc00Vendor|r   25c", " " }
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
                    quoteText = i == 1 and "1s" or nil }
            end
            sample.observedPriceText = "1s"
            self:AddVendorSection(preview, nil, sample, self.previewExpanded ~= false, hint, true)
        end
        self.optionsPreview:SetText(table.concat(lines, "\n"))
    end
    if self.optionsCollection then
        local items, vendors, offers = self:CountPersonalItems()
        self.optionsCollection:SetText(("%d vendors · %d items · %d offers"):format(vendors, items, offers))
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
    controls = {}
    self.optionsCollection = nil
    local categoryPanel = CreateFrame("Frame", "VendorItemCheckOptionsPanel", UIParent)
    categoryPanel.name = self.title
    local scroll = CreateFrame("ScrollFrame", nil, categoryPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)

    local canvas = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(canvas)
    if self.StyleBrowserSurface then self:StyleBrowserSurface(canvas, "background") end

    local header = CreateFrame("Frame", nil, canvas)
    header:SetPoint("TOPLEFT", 12, -12)
    Text(header, self.title, 0, 0, 275, "GameFontNormalLarge")
    local subtitle = Text(header, "Find NPC sellers from item tooltips or the browser.", 0, -32, 520)
    local headerRule = Rule(header, -52, 610, true)

    local form = CreateFrame("Frame", nil, canvas)
    form:SetPoint("TOPLEFT", 12, -76)
    form:SetSize(286, 383)
    Text(form, "Item tooltips", 0, 0, 282, "GameFontNormal")
    CreateCheckbox(form, "enabled", "Enable tooltip enhancements", "Show known sellers on item tooltips.", -19)
    CreateStepper(form, -47)
    CreateCheckbox(form, "showClosestFirst", "Prioritize nearby vendors", "List current-zone vendors first.", -78)
    CreateCheckbox(form, "showCoordinates", "Show coordinates", "Include known or approximate coordinates.", -104)
    CreateCheckbox(form, "showPrice", "Show purchase prices", "Include Classic reference prices or this character's observed quotes.", -130)

    Rule(form, -155, 282)
    Text(form, "Expansion controls", 0, -164, 282, "GameFontNormal")
    CreateModifierSelector(form, -185, "modifierKey", "Keyboard", self.keyboardModifiers, KEYBOARD_LABELS,
        "VICKeyboardModifier", "Hold the selected modifier to expand the vendor section.")
    local commandsY = -225
    if self.client == "forever" then
        CreateModifierSelector(form, -216, "controllerModifier", "Controller", self.controllerModifiers, CONTROLLER_LABELS,
            "VICControllerModifier", "Use a supported trigger or shoulder button. Normal controller actions stay available.")
        Rule(form, -247, 282)
        Text(form, "Merchant data", 0, -257, 282, "GameFontNormal")
        CreateCheckbox(form, "recordMerchants", "Learn from merchants I visit", "Observations stay on this computer. Sharing is optional.", -277)
        self.optionsCollection = Text(form, "", 0, -305, 282)
        commandsY = -331
    end
    Rule(form, commandsY + 9, 282, true)
    Text(form, "Slash commands", 0, commandsY, 282, "GameFontNormal")
    Text(form, "/vic · /vendorcheck · /vic browse\n/vic settings · /vic help", 0, commandsY - 18, 282)

    local preview = CreateFrame("Frame", nil, canvas)
    Text(preview, "Live preview", 0, 0, 235, "GameFontNormal")
    Text(preview, "Sample data · changes immediately", 0, -22, 235)
    local card = CreateFrame("Frame", nil, preview)
    card:SetPoint("TOPLEFT", 0, -44)
    if self.StyleBrowserSurface then self:StyleBrowserSurface(card, "inset", "brass") end
    self.optionsPreview = Text(card, "", 10, -10, 255)
    local previewHint = Text(preview, "Choose a preview state below.", 0, -322, 255)
    Button(preview, nil, "Collapsed", 0, -345, 84, function()
        self.previewExpanded = false
        self:RefreshOptions()
    end)
    Button(preview, nil, "Expanded", 90, -345, 84, function()
        self.previewExpanded = true
        self:RefreshOptions()
    end)

    local footer = CreateFrame("Frame", nil, canvas)
    local footerRule = Rule(footer, 0, 610, true)
    Button(footer, nil, "Browse", 0, -11, 66, function() self:OpenBrowser() end)
    Button(footer, nil, "Data & sharing", 73, -11, 106, function() self:OpenDataView("overview") end)
    local reset = Button(footer, nil, "Reset settings", 0, -11, 96, function(button)
        self:OpenChoiceMenu(button or footer, {
            { label = "Cancel — keep settings", value = false },
            { label = "Reset settings; preserve observations", value = true },
        }, function(confirm)
            if not confirm then return end
            for key, value in pairs(self.defaults) do self.settings[key] = value end
            self:RefreshOptions()
        end)
    end)

    local function Layout()
        local viewportWidth = scroll.GetWidth and scroll:GetWidth() or 634
        if viewportWidth < 1 then viewportWidth = 634 end
        local width = math.max(308, math.min(760, viewportWidth - 2))
        local contentWidth = width - 24
        local stacked = contentWidth < 548
        local previewWidth = stacked and contentWidth or contentWidth - 310
        local previewY = stacked and (76 - commandsY + 58) or 76
        local footerY = math.max(76 - commandsY + 55, previewY + 385)
        canvas:SetSize(width, footerY + 48)
        header:SetSize(contentWidth, 56)
        subtitle:SetWidth(contentWidth)
        if headerRule then headerRule:SetWidth(contentWidth) end
        preview:SetSize(previewWidth, 371)
        card:SetSize(previewWidth, 266)
        self.optionsPreview:SetWidth(previewWidth - 20)
        previewHint:SetWidth(previewWidth)
        if preview.ClearAllPoints then preview:ClearAllPoints() end
        preview:SetPoint("TOPLEFT", stacked and 12 or 322, -previewY)
        footer:SetSize(contentWidth, 38)
        if footer.ClearAllPoints then footer:ClearAllPoints() end
        footer:SetPoint("TOPLEFT", 12, -footerY)
        if footerRule then footerRule:SetWidth(contentWidth) end
        if reset.ClearAllPoints then reset:ClearAllPoints() end
        reset:SetPoint("TOPLEFT", contentWidth - 96, -11)
    end
    scroll:SetScript("OnSizeChanged", Layout)
    categoryPanel:SetScript("OnShow", function()
        Layout()
        self:RefreshOptions()
    end)
    Layout()

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
