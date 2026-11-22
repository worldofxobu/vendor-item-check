local _, VIC = ...

local controls = {}
local KEYBOARD_LABELS = { ALT = "Hold ALT", SHIFT = "Hold SHIFT", CTRL = "Hold CTRL", OFF = "Keyboard off", NONE = "Always expanded" }
local CONTROLLER_LABELS = { LT = "Hold LT / L2", RT = "Hold RT / R2", LB = "Hold LB / L1", RB = "Hold RB / R1", OFF = "Controller off" }

local function Text(parent, value, x, y, width, font, color, size)
    local text = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetText(value)
    if VIC.StyleBrowserText then
        local weight = font and "medium" or "regular"
        VIC:StyleBrowserText(text, size or (font == "GameFontNormalLarge" and 19 or font and 12 or 11),
            weight, color or (font and "gold" or "cream"))
    end
    return text
end

local function Button(parent, name, value, x, y, width, action, primary)
    local template = not VIC.StyleBrowserSurface and "UIPanelButtonTemplate" or nil
    local button = CreateFrame("Button", name, parent, template)
    if VIC.StyleBrowserSurface then VIC:StyleBrowserSurface(button, primary and "action" or "plate", primary and "brass" or "border") end
    if button.SetNormalFontObject then
        button:SetNormalFontObject(GameFontHighlightSmall)
        button:SetHighlightFontObject(GameFontNormalSmall)
        button:SetDisabledFontObject(GameFontDisableSmall)
    end
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 27)
    button:SetText(value)
    local label = button.GetFontString and button:GetFontString()
    if not label and button.SetFontString then
        -- A template-free button may not have a font string after SetText("").
        label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        button:SetFontString(label)
        button:SetText(value)
    end
    if VIC.StyleBrowserText and label then
        VIC:StyleBrowserText(label, 11, "medium", primary and "gold" or "cream")
    end
    button:SetScript("OnClick", action)
    return button
end

local function Help(parent, x, y, title, message, name)
    local button = CreateFrame("Button", name, parent)
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(19, 19)
    if VIC.BrowserIcon then VIC:BrowserIcon(button, "Help", 12, 3, -3)
    else button:SetText("?") end
    local function Show(owner)
        if VIC.StyleBrowserSurface then
            local hint = VIC.settingsHint
            if not hint then
                hint = CreateFrame("Frame", "VendorItemCheckSettingsHint", UIParent)
                hint:SetSize(246, 65)
                if hint.SetFrameStrata then hint:SetFrameStrata("TOOLTIP") end
                if hint.SetClampedToScreen then hint:SetClampedToScreen(true) end
                VIC:StyleBrowserSurface(hint, "inset", "brass")
                hint.title = Text(hint, "", 11, -10, 224, "GameFontNormal", "gold")
                hint.body = Text(hint, "", 11, -31, 224, nil, "cream", 11)
                VIC.settingsHint = hint
            end
            hint.owner = owner
            hint:ClearAllPoints()
            hint:SetPoint("TOPLEFT", owner, "TOPRIGHT", 6, 3)
            hint.title:SetText(title)
            hint.body:SetText(message)
            local height = hint.body.GetStringHeight and hint.body:GetStringHeight() or 22
            hint:SetHeight(math.max(65, 42 + height))
            hint:Show()
            return
        end
        if not GameTooltip or not GameTooltip.SetText then return end
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        if GameTooltip.ClearAllPoints then GameTooltip:ClearAllPoints() end
        GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 6, 3)
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(message, 0.95, 0.93, 0.88, true)
        GameTooltip:Show()
    end
    button:SetScript("OnEnter", Show)
    button:SetScript("OnClick", Show)
    if button.HasScript and button:HasScript("OnFocusGained") then button:SetScript("OnFocusGained", Show) end
    local function Hide()
        if VIC.settingsHint and VIC.settingsHint.owner == button then VIC.settingsHint:Hide() end
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end
    button:SetScript("OnLeave", Hide)
    if button.HasScript and button:HasScript("OnFocusLost") then button:SetScript("OnFocusLost", Hide) end
end

local function Rule(parent, y, width, gold)
    if not parent.CreateTexture then return end
    local line = parent:CreateTexture(nil, "ARTWORK")
    if not line.SetColorTexture then return end
    line:SetPoint("TOPLEFT", 0, y)
    line:SetSize(width, 1)
    if gold then line:SetColorTexture(136 / 255, 104 / 255, 59 / 255, 1)
    else line:SetColorTexture(61 / 255, 60 / 255, 53 / 255, 1) end
    return line
end

local function CreateCheckbox(parent, key, label, description, y)
    local template
    if not VIC.StyleBrowserSurface then template = "InterfaceOptionsCheckButtonTemplate" end
    local checkbox = CreateFrame("CheckButton", "VICOption" .. key, parent, template)
    checkbox:SetPoint("TOPLEFT", 0, y)
    checkbox:SetSize(20, 20)
    if VIC.StyleBrowserSurface then
        VIC:StyleBrowserSurface(checkbox, "inset", "brass")
        if checkbox.SetCheckedTexture then checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check") end
    end
    local nativeText = checkbox.Text or _G["VICOption" .. key .. "Text"]
    if nativeText then nativeText:SetText("") end
    local caption = Text(parent, label, 28, y - 4, 225)
    local width = caption.GetUnboundedStringWidth and caption:GetUnboundedStringWidth() or #label * 5
    Help(parent, math.min(260, 33 + width), y, label, description)
    checkbox:SetScript("OnClick", function(control)
        VIC.settings[key] = control:GetChecked() and true or false
        VIC:RefreshOptions()
    end)
    checkbox.settingKey = key
    controls[#controls + 1] = checkbox
end

local function CreateStepper(parent, y)
    Text(parent, "Maximum vendors", 0, y - 6, 145)
    Help(parent, 145, y, "Maximum vendors", "Number of sellers shown when you expand an item tooltip. Range: 1–10.", "VICMaximumVendorsHelp")
    local function Change(delta)
        local current = tonumber(VIC.settings.maxVendors) or 4
        VIC.settings.maxVendors = math.max(1, math.min(10, current + delta))
        VIC:RefreshOptions()
    end
    Button(parent, nil, "−", 203, y, 27, function() Change(-1) end, true)
    local value = Text(parent, "", 229, y - 6, 25)
    value:SetJustifyH("CENTER")
    Button(parent, nil, "+", 258, y, 27, function() Change(1) end, true)
    controls[#controls + 1] = { settingKey = "maxVendors", valueText = value }
end

local function CreateModifierSelector(parent, y, key, caption, choices, labels, buttonName, description)
    Text(parent, caption, 0, y - 6, 96)
    Help(parent, 91, y, caption, description)
    local button
    button = Button(parent, buttonName, "", 141, y, 145, function()
        local entries = {}
        for _, value in ipairs(choices) do entries[#entries + 1] = { label = labels[value], value = value } end
        VIC:OpenChoiceMenu(button, entries, function(value)
            VIC.settings[key] = value
            VIC:RefreshOptions()
        end)
    end)
    if VIC.PaintBrowserSurface then
        VIC:PaintBrowserSurface(button, "inset", "brass")
        Text(button, "▼", 132, -11, 7, nil, "gold", 5)
    end
    controls[#controls + 1] = { UpdateButton = function()
        local supported = key ~= "controllerModifier" or C_GamePad and type(C_GamePad.GetDeviceMappedState) == "function"
            and type(C_GamePad.ButtonBindingToIndex) == "function"
        button:SetText(supported and (labels[VIC.settings[key]] or labels[VIC.defaults[key]]) or "Unavailable")
        if button.SetEnabled then button:SetEnabled(supported and true or false) end
        local label = button.GetFontString and button:GetFontString()
        if label and VIC.StyleBrowserText then
            label:ClearAllPoints()
            label:SetPoint("LEFT", 8, 0)
            label:SetPoint("RIGHT", -15, 0)
            label:SetJustifyH("LEFT")
            VIC:StyleBrowserText(label, 11, "regular", supported and "cream" or "muted")
        end
    end }
end

local previewSellers = {
    { "Edna Mullby", "Stormwind City", 64.7, 71.6 },
    { "Kaita Deepforge", "Stormwind City", 63.5, 37.7 },
    { "Brooke Stonebrade", "Stormwind City", 59.3, 37.4 },
    { "Hammon Karwn", "Arathi Highlands", 46.5, 47.3 },
    { "Innkeeper Allison", "Stormwind City" },
    { "Thurman Mullby", "Stormwind City" },
    { "Bryllia Ironbrand", "Ironforge" },
    { "Bretta Goldfury", "Ironforge" },
    { "Murndan Derth", "Wetlands" },
    { "Vikki Lonsav", "Arathi Highlands" },
}

local function RefreshPreview(self)
    local card = self.optionsPreview
    local shown, y = 0, 111
    local function AddLine(left, right, r, g, b, rr, rg, rb)
        shown = shown + 1
        local row = card.lines[shown]
        if not row then
            row = { left = Text(card, "", 10, -y, 200, nil, "cream", 10), right = Text(card, "", 200, -y, 85, nil, "cream", 10) }
            row.right:SetJustifyH("RIGHT")
            card.lines[shown] = row
        end
        local width = card.GetWidth and card:GetWidth() or 303
        for i, label in ipairs({ row.left, row.right }) do
            if label.ClearAllPoints then label:ClearAllPoints() end
            label:SetPoint("TOPLEFT", i == 1 and 10 or math.max(10, width - 114), -y)
            label:SetWidth(i == 1 and math.max(50, width - (right and 105 or 20)) or 102)
        end
        row.left:SetText(left)
        row.right:SetText(right or "")
        if row.left.SetTextColor then
            row.left:SetTextColor(r or 0.95, g or 0.93, b or 0.88)
            row.right:SetTextColor(rr or 0.95, rg or 0.93, rb or 0.88)
        end
        row.left:Show()
        row.right:Show()
        y = y + (shown == 1 and 17 or 15)
    end
    if self.settings.enabled then
        local key = self.settings.modifierKey
        local hint = key ~= "OFF" and key ~= "NONE" and key or nil
        local controller = self.settings.controllerModifier
        if self.client == "forever" and key ~= "NONE" and controller ~= "OFF" and C_GamePad
            and type(C_GamePad.GetDeviceMappedState) == "function" and type(C_GamePad.ButtonBindingToIndex) == "function" then
            hint = hint and (hint .. " or " .. controller) or controller
        end
        local preview = {
            GetName = function() end,
            Show = function() end,
            AddLine = function(_, line, r, g, b) AddLine(line, nil, r, g, b) end,
            AddDoubleLine = function(_, left, right, r, g, b, rr, rg, rb) AddLine(left, right, r, g, b, rr, rg, rb) end,
        }
        local sample = { vendors = {}, totalCount = 21 }
        for i, seller in ipairs(previewSellers) do
            local row = { id = i, name = seller[1], zone = seller[2], x = seller[3], y = seller[4] }
            if i == 1 then row.copper, row.quantity, row.accessObserved = 100, 1, true end
            sample.vendors[i] = row
        end
        self:AddVendorSection(preview, nil, sample, self.previewExpanded ~= false, hint, true)
    end
    for i = shown + 1, #card.lines do
        card.lines[i].left:Hide()
        card.lines[i].right:Hide()
    end
    card.previewHeight = math.max(274, y + 9)
    if self.optionsLayout then self.optionsLayout() end
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
    if self.optionsPreview then RefreshPreview(self) end
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
    if self.StyleBrowserSurface then self:StyleBrowserSurface(canvas, "pane", "pane") end

    local header = CreateFrame("Frame", nil, canvas)
    header:SetPoint("TOPLEFT", 12, -14)
    Text(header, self.title, 0, 0, 275, "GameFontNormalLarge")
    local subtitle = Text(header, "Find NPC sellers directly from item tooltips or the browser.", 0, -32, 520, nil, "muted", 10)
    local headerRule = Rule(header, -55, 610, true)

    local form = CreateFrame("Frame", nil, canvas)
    form:SetPoint("TOPLEFT", 12, -82)
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
        self.optionsCollection = Text(form, "", 0, -305, 282, nil, "muted", 10)
        commandsY = -331
    end
    Rule(form, commandsY + 9, 282, true)
    Text(form, "Slash commands", 0, commandsY, 282, "GameFontNormal")
    Text(form, "/vic · /vendorcheck · /vic browse\n/vic settings · /vic help", 0, commandsY - 18, 282, nil, "cream", 10)

    local preview = CreateFrame("Frame", nil, canvas)
    Text(preview, "Live preview", 0, 0, 235, "GameFontNormal")
    Text(preview, "Sample data · changes immediately", 0, -23, 235, nil, "muted", 10)
    local card = CreateFrame("Frame", nil, preview)
    card:SetPoint("TOPLEFT", 0, -46)
    if self.StyleBrowserSurface then self:StyleBrowserSurface(card, "tooltip", "muted") end
    card.lines = {}
    self.optionsPreview = card
    Text(card, "Weak Flux", 10, -11, 245, "GameFontNormal", "cream", 14)
    Text(card, "|cff71a9faCrafting Reagent|r", 10, -32, 245, nil, "cream", 11)
    Text(card, "\"Used by Blacksmiths to remove impurities.\"", 10, -48, 275, nil, "gold", 11)
    Text(card, "Vendor", 10, -66, 100, nil, "gold", 11)
    Text(card, "Auction", 10, -83, 100, nil, "gold", 11)
    local vendorPreview = Text(card, self:FormatCoinIcons(25), 0, -66, 95, nil, "cream", 10)
    local auctionPreview = Text(card, self:FormatCoinIcons(307), 0, -83, 95, nil, "cream", 10)
    vendorPreview:SetJustifyH("RIGHT")
    auctionPreview:SetJustifyH("RIGHT")
    local previewRule = Rule(card, -105, 280)
    local previewHint = Text(preview, "Preview reflects your settings. Use the buttons to inspect either state.", 0, -331, 255, nil, "muted", 10)
    local collapsed = Button(preview, nil, "Collapsed", 0, -363, 74, function()
        self.previewExpanded = false
        self:RefreshOptions()
    end)
    local expanded = Button(preview, nil, "Expanded", 80, -363, 74, function()
        self.previewExpanded = true
        self:RefreshOptions()
    end, true)

    local footer = CreateFrame("Frame", nil, canvas)
    local footerRule = Rule(footer, 0, 610, true)
    Button(footer, nil, "Browse", 0, -11, 60, function() self:OpenBrowser() end, true)
    Button(footer, nil, "Data & sharing", 68, -11, 98, function() self:OpenDataView("overview") end, true)
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
        local previewY = stacked and (82 - commandsY + 54) or 82
        local cardHeight = card.previewHeight or 274
        local footerY = math.max(82 - commandsY + 67, previewY + cardHeight + 127)
        canvas:SetSize(width, footerY + 48)
        header:SetSize(contentWidth, 56)
        subtitle:SetWidth(contentWidth)
        if headerRule then headerRule:SetWidth(contentWidth) end
        preview:SetSize(previewWidth, cardHeight + 111)
        card:SetSize(previewWidth, cardHeight)
        for i, amount in ipairs({ vendorPreview, auctionPreview }) do
            if amount.ClearAllPoints then amount:ClearAllPoints() end
            amount:SetPoint("TOPLEFT", previewWidth - 106, i == 1 and -66 or -83)
        end
        if previewRule then previewRule:SetWidth(previewWidth) end
        previewHint:SetWidth(previewWidth)
        if previewHint.ClearAllPoints then previewHint:ClearAllPoints() end
        previewHint:SetPoint("TOPLEFT", 0, -(cardHeight + 55))
        for i, state in ipairs({ collapsed, expanded }) do
            if state.ClearAllPoints then state:ClearAllPoints() end
            state:SetPoint("TOPLEFT", (i - 1) * 80, -(cardHeight + 89))
            if self.PaintBrowserSurface then
                local active = (self.previewExpanded ~= false) == (i == 2)
                self:PaintBrowserSurface(state, active and "action" or "plate", active and "brass" or "border")
                local label = state.GetFontString and state:GetFontString()
                if label then self:StyleBrowserText(label, 11, "medium", active and "gold" or "muted") end
            end
        end
        if preview.ClearAllPoints then preview:ClearAllPoints() end
        preview:SetPoint("TOPLEFT", stacked and 12 or 322, -previewY)
        footer:SetSize(contentWidth, 38)
        if footer.ClearAllPoints then footer:ClearAllPoints() end
        footer:SetPoint("TOPLEFT", 12, -footerY)
        if footerRule then footerRule:SetWidth(contentWidth) end
        if reset.ClearAllPoints then reset:ClearAllPoints() end
        reset:SetPoint("TOPLEFT", math.min(contentWidth - 96, 407), -11)
    end
    scroll:SetScript("OnSizeChanged", Layout)
    self.optionsLayout = Layout
    categoryPanel:SetScript("OnShow", function()
        Layout()
        self:RefreshOptions()
    end)
    categoryPanel:SetScript("OnHide", function() if self.settingsHint then self.settingsHint:Hide() end end)
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
