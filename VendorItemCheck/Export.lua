local _, VIC = ...

local function Array(values)
    return setmetatable(values, { jsonArray = true })
end

local function JSON(value)
    local kind = type(value)
    if kind == "string" then
        local escaped = string.gsub(value, '[%z\1-\31\\"]', function(char)
            if char == '"' then return '\\"' end
            if char == '\\' then return '\\\\' end
            return string.format("\\u%04x", string.byte(char))
        end)
        return '"' .. escaped .. '"'
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error("Invalid numeric observation") end
        local format = value % 1 == 0 and "%.0f" or "%.17g"
        return (string.gsub(string.format(format, value), ",", "."))
    elseif kind == "boolean" then
        return value and "true" or "false"
    elseif kind == "table" then
        local parts = {}
        if getmetatable(value) and getmetatable(value).jsonArray then
            for _, entry in ipairs(value) do parts[#parts + 1] = JSON(entry) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do parts[#parts + 1] = JSON(key) .. ":" .. JSON(value[key]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("Unsupported observation value")
end

local function PublicValue(value)
    local kind = type(value)
    if kind == "string" or kind == "boolean" or kind == "number" then return value end
end

local function PublicRecord(record)
    -- Explicit field lists keep account/character keys and unrelated settings local.
    local public = {}
    for _, key in ipairs({ "vendorId", "itemId", "vendorName", "observedAt", "build", "interface", "channel",
        "playerFaction", "priceCopper", "quantity", "stock", "canPurchase", "hasExtendedCost", "discount", "costsComplete" }) do
        public[key] = PublicValue(record[key])
    end
    local costs = {}
    for _, cost in ipairs(record.costs or {}) do
        costs[#costs + 1] = { itemId = PublicValue(cost.itemId), currencyId = PublicValue(cost.currencyId), quantity = PublicValue(cost.quantity) }
    end
    public.costs = Array(costs)
    if record.location then
        public.location = {}
        for _, key in ipairs({ "mapId", "x", "y", "approximate", "zone" }) do
            public.location[key] = PublicValue(record.location[key])
        end
    end
    return public
end

function VIC:BuildContribution()
    if self.client ~= "forever" or not self.observations then return nil, "No supported Forever observations are available." end
    local now = self:ObservationNow()
    if not now then return nil, "The observation clock is unavailable." end
    local encoded, unique = {}, {}
    for _, character in pairs(self.observations.characters) do
        for _, record in pairs(character.offers or {}) do
            if self:IsObservationFresh(record, now) then
                local row = JSON(PublicRecord(record))
                if not unique[row] then encoded[#encoded + 1] = row; unique[row] = true end
            end
        end
    end
    if #encoded == 0 then return nil, "No eligible observations to share." end
    table.sort(encoded)
    local header = JSON({ schema = "vic.observations/1", client = "forever", licence = "CC BY-SA 4.0",
        reporterId = self.observations.reporterId, exportedAt = now })
    return string.sub(header, 1, -2) .. ',"records":[\n' .. table.concat(encoded, ",\n") .. "\n]}"
end

local function Text(parent, value, x, y, width, size, weight, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, -y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(value)
    return VIC:StyleBrowserText(label, size, weight, color)
end

local function Show(widget, visible)
    if visible then widget:Show() else widget:Hide() end
end

local function Action(parent, label, x, y, width, click, primary)
    local button = VIC:CreateBrowserButton(parent, label, x, -y, width, click, 28,
        primary and "selection" or "plate", primary and "brass" or "border")
    if primary and button.GetFontString then VIC:StyleBrowserText(button:GetFontString(), 10, "medium", "gold") end
    return button
end

local function Tag(parent, text, x, y, width, color)
    local tag = VIC:CreateBrowserSurface(parent, x, -y, width, 21, "inset", "border")
    local label = Text(tag, text, 0, 5, width, 9, "medium", color)
    label:SetJustifyH("CENTER")
    return tag
end

local function License()
    local url = "https://creativecommons.org/licenses/by-sa/4.0/"
    if not StaticPopupDialogs or not StaticPopup_Show then
        VIC:Print("%s", url)
        return
    end
    if not StaticPopupDialogs.VIC_CONTRIBUTION_LICENSE then
        StaticPopupDialogs.VIC_CONTRIBUTION_LICENSE = {
            text = "CC BY-SA 4.0 — copy the license link with Ctrl+C.",
            button1 = CLOSE or "Close",
            hasEditBox = true,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnShow = function(popup)
                local edit = popup.GetEditBox and popup:GetEditBox() or popup.editBox or popup.EditBox
                if edit then edit:SetText(url); edit:SetFocus(); edit:HighlightText() end
            end,
        }
    end
    StaticPopup_Show("VIC_CONTRIBUTION_LICENSE")
end

function VIC:RefreshDataView()
    local panel = self.exportPanel
    local view = self.browserPanel and self.browserPanel.dataView
    if not panel or not view then return end
    local items, vendors, offers, latest = self:CountPersonalItems()
    local bundledItems, bundledVendors = self:CountIndexedItems()
    local meta = self.dataMetadata or {}
    local revision = meta.dataAsOf or "Unavailable"
    local revisionDate = revision:match("^%d%d%d%d%-%d%d%-%d%d") or revision
    local eligible = self.client == "forever" and offers > 0
    for name, body in pairs(panel.views) do Show(body, name == view) end
    local crumbs = { overview = "Data & sharing", status = "Status details", contribute = "Contribute" }
    panel.breadcrumb:SetText(crumbs[view])
    panel.back:SetText(view == "overview" and (self.browserPanel.tab == "vendors" and "‹ Vendors" or "‹ Items") or "‹ Data")
    panel.statusShare:SetEnabled(eligible)
    if view == "overview" then
        panel.overviewIntro:SetText(offers == 0 and "No personal observations yet. Visit NPC merchants with learning enabled to collect offers."
            or "Your locally collected vendor data and bundled directory coverage.")
        panel.metrics[1].value:SetText(tostring(vendors))
        panel.metrics[2].value:SetText(tostring(items))
        panel.metrics[3].value:SetText(tostring(offers))
        panel.retention:SetText(offers == 0 and "Bundled items are still available to browse while your collection is empty."
            or "Personal observations are retained for 30 days.")
        panel.directory.text:SetText(("Vendors   |cffffd100%d|r     Items   |cffffd100%d|r     Data updated   |cffffd100%s|r")
            :format(bundledVendors, bundledItems, revisionDate))
        panel.shareMessage:SetText(eligible and "Export observations manually. Nothing is uploaded for you."
            or "No eligible observations are available for export yet.")
        panel.contribute:SetText(eligible and "Contribute data ›" or "Nothing to export")
        panel.contribute:SetEnabled(eligible)
    elseif view == "status" then
        local ok, version, build, _, interface
        if type(GetBuildInfo) == "function" then ok, version, build, _, interface = pcall(GetBuildInfo) end
        local recording = self.client == "forever" and self.observations and (self.settings.recordMerchants and "On" or "Off") or "Unavailable"
        local values = {
            self.client == "forever" and "WoW Forever  •  current client"
                or self.client == "classic" and "Classic Era  •  current client" or "Unavailable",
            ok and version and ("%s / %s · %s"):format(version, tostring(build), tostring(interface or "—")) or "Unavailable",
            revision,
            ("%d vendors / %d items"):format(bundledVendors, bundledItems),
            ("%d offers · Learning %s"):format(offers, recording),
            latest and (date and date("!%Y-%m-%d %H:%M UTC", latest) or tostring(latest)) or "—",
        }
        for i, value in ipairs(values) do panel.statusRows[i]:SetText(value) end
    else
        self.exportPrepare:SetEnabled(eligible)
        panel.prepareHint:SetText(panel.message or (eligible and "Your data has not been generated yet." or "No eligible observations to export."))
        Show(panel.prepare, not panel.document)
        Show(panel.generated, panel.document)
        Show(panel.select, panel.document)
        Show(panel.copyHint, panel.document)
        Show(panel.contact, panel.document)
    end
end

function VIC:OpenDataView(view)
    self:OpenBrowser(true)
    local browser = self.browserPanel
    if self.choiceMenu then self.choiceMenu:Hide() end
    if browser.menu then browser.menu:Hide() end
    if browser.advanced then browser.advanced:Hide() end
    if not self.exportPanel then
        local panel = self:CreateBrowserSurface(browser, 1, -38, 568, 381, "pane", "brass")
        if panel.EnableMouse then panel:EnableMouse(true) end
        if panel.SetFrameLevel and browser.GetFrameLevel then panel:SetFrameLevel(browser:GetFrameLevel() + 15) end
        self.exportPanel = panel

        local bar = self:CreateBrowserSurface(panel, 1, -1, 566, 33, "plate", "plate")
        local function Back()
            if browser.dataView ~= "overview" then self:OpenDataView("overview"); return end
            browser.dataView = nil
            panel:Hide()
            browser.workspace:Show()
            self:RefreshBrowser(true)
        end
        panel.back = self:CreateBrowserButton(bar, "‹ Items", 6, -5, 56, Back, 24, "plate", "plate")
        if panel.back.GetFontString then self:StyleBrowserText(panel.back:GetFontString(), 10, "medium", "gold") end
        Text(bar, "/", 67, 10, 9, 11, "regular", "muted")
        panel.breadcrumb = Text(bar, "Data & sharing", 77, 9, 280, 12, "bold", "gold")

        local function View()
            local body = CreateFrame("Frame", nil, panel)
            body:SetPoint("TOPLEFT", 0, -34)
            body:SetSize(568, 345)
            return body
        end
        local overview, status, contribute = View(), View(), View()
        panel.views = { overview = overview, status = status, contribute = contribute }

        Text(overview, "Your vendor data", 8, 10, 420, 16, "medium", "gold")
        Tag(overview, "PRIVATE · LOCAL", 455, 10, 89, "teal")
        panel.overviewIntro = Text(overview, "", 8, 40, 535, 10, "regular", "muted")
        panel.metrics = {}
        for i, label in ipairs({ "Vendors", "Items", "Recorded offers" }) do
            local card = self:CreateBrowserSurface(overview, 8 + 181 * (i - 1), -59, 171, 55, "inset", "brass")
            card.value = Text(card, "", 10, 8, 151, 18, "medium", "gold")
            Text(card, label, 10, 32, 151, 10, "regular", "muted")
            panel.metrics[i] = card
        end
        panel.retention = Text(overview, "", 11, 126, 520, 10, "regular", "muted")
        self:CreateBrowserSurface(overview, 8, -145, 536, 1, "brass", "brass")
        panel.directory = self:CreateBrowserSurface(overview, 8, -154, 536, 55, "inset", "border")
        Text(panel.directory, "Bundled directory", 10, 12, 240, 11, "medium", "gold")
        panel.directory.text = Text(panel.directory, "", 10, 34, 455, 10, "regular", "muted")
        Tag(panel.directory, "READ-ONLY", 459, 8, 67, "gold")
        Text(overview, "Dataset status", 8, 217, 260, 11, "medium", "gold")
        Text(overview, "Client, source date, version, and record counts", 8, 233, 440, 10, "regular", "muted")
        panel.status = Action(overview, "View status ›", 460, 217, 84, function() self:OpenDataView("status") end)
        local share = self:CreateBrowserSurface(overview, 8, -253, 536, 47, "inset", "brass")
        Text(share, "Help improve the directory", 10, 8, 380, 11, "medium", "gold")
        panel.shareMessage = Text(share, "", 10, 25, 403, 10, "regular", "muted")
        panel.contribute = Action(share, "Contribute data ›", 422, 9, 103, function() self:OpenExport() end, true)

        Text(status, "Data status", 8, 10, 400, 16, "medium", "gold")
        Tag(status, "READ-ONLY", 477, 10, 67, "muted")
        Text(status, "Technical details are available here, away from the main browser and item tooltips.", 8, 40, 530, 10, "regular", "muted")
        local dataset = self:CreateBrowserSurface(status, 8, -61, 536, 195, "pane", "border")
        Text(dataset, "Active dataset", 10, 10, 500, 11, "medium", "gold")
        panel.statusRows = {}
        for i, field in ipairs({ "Client", "Client build", "Bundled data revision", "Bundled inventory", "Personal observations", "Last merchant learned" }) do
            local row = self:CreateBrowserSurface(dataset, 10, -26 - (i - 1) * 27, 516, 24, "inset", "inset")
            Text(row, field, 8, 5, 160, 10, "regular", "muted")
            local value = Text(row, "", 169, 5, 347, 10, "medium")
            value:SetJustifyH("RIGHT")
            panel.statusRows[i] = value
        end
        Text(status, "Coverage does not mean live availability.", 8, 264, 460, 10, "medium", "gold")
        Text(status, "Prices and stock reflect observations. Each client uses its own dataset.", 8, 281, 536, 10, "regular", "muted")
        Action(status, "Back to overview", 8, 302, 103, Back)
        panel.statusShare = Action(status, "Contribute data ›", 441, 302, 103, function() self:OpenExport() end, true)

        Text(contribute, "Contribute your vendor data", 13, 7, 522, 16, "medium", "gold")
        Text(contribute, "Share information from merchants you've visited. Nothing is sent automatically.", 13, 34, 522, 11, "regular", "muted")
        local privacy = self:CreateBrowserSurface(contribute, 13, -53, 526, 66, "inset", "border")
        Text(privacy, "SHARED", 11, 9, 50, 10, "medium", "gold")
        Text(privacy, "Vendor/item IDs, offers, prices, locations & a pseudonym", 59, 9, 447, 10)
        Text(privacy, "PRIVATE", 11, 27, 50, 10, "medium", "gold")
        Text(privacy, "No character, account or realm identifiers", 59, 27, 447, 10)
        Text(privacy, "CC BY-SA 4.0 applies if you share", 11, 45, 420, 10, "regular", "muted")
        local license = self:CreateBrowserButton(privacy, "View license ↗", 437, -41, 79, License, 20, "inset", "inset")
        if license.GetFontString then self:StyleBrowserText(license:GetFontString(), 10, "medium", "gold") end

        panel.prepare = self:CreateBrowserSurface(contribute, 13, -126, 526, 125, "inset", "brass")
        panel.prepareHint = Text(panel.prepare, "", 13, 25, 500, 11, "regular", "muted")
        panel.prepareHint:SetJustifyH("CENTER")
        local prepareCaption = Text(panel.prepare, "Creates JSON from saved merchant observations.", 13, 87, 500, 10, "regular", "muted")
        prepareCaption:SetJustifyH("CENTER")
        panel.generated = self:CreateBrowserSurface(contribute, 13, -124, 526, 110, "inset", "brass")
        Text(panel.generated, "Generated JSON", 11, 12, 350, 11, "medium", "gold")
        local ready = Text(panel.generated, "Ready to copy", 408, 13, 108, 10, "regular", "muted")
        ready:SetJustifyH("RIGHT")
        local field = self:CreateBrowserSurface(panel.generated, 11, -29, 506, 79, "background", "border")
        panel.scroll = CreateFrame("ScrollFrame", nil, field, "UIPanelScrollFrameTemplate")
        panel.scroll:SetPoint("TOPLEFT", 5, -3)
        panel.scroll:SetSize(475, 73)
        panel.scroll.scrollBarHideIfUnscrollable = true
        local box = CreateFrame("EditBox", nil, panel.scroll)
        box:SetPoint("TOPLEFT", 0, 0)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        if box.SetJustifyV then box:SetJustifyV("TOP") end
        box:SetWidth(475)
        box:SetHeight(73)
        box:SetMaxLetters(0)
        if box.SetMaxBytes then box:SetMaxBytes(0) end
        box:SetScript("OnEscapePressed", function(edit) edit:ClearFocus(); browser:Hide() end)
        local function UpdateDocumentSize(edit)
            local expected = panel.document or ""
            if edit:GetText() ~= expected then edit:SetText(expected); return end
            local _, size
            if edit.GetFont then _, size = edit:GetFont() end
            local lines = edit.GetNumLines and edit:GetNumLines() or 1
            if lines <= 1 and #expected > 90 then lines = math.ceil(#expected / 88) end
            edit:SetHeight(math.max(73, lines * ((size or 11) + 2)))
            panel.scroll:UpdateScrollChildRect()
        end
        box:SetScript("OnTextChanged", UpdateDocumentSize)
        panel.scroll:SetScrollChild(box)
        self.exportBox = box

        self.exportPrepare = Action(panel.prepare, "Generate contribution data", 177, 47, 172, function()
            local ok, document, message = pcall(self.BuildContribution, self)
            if ok and document then
                panel.document = document
                box:SetText(document)
            else
                panel.message = ok and message or "Could not encode the stored observations."
            end
            self:RefreshDataView()
            UpdateDocumentSize(box)
            if box.SetCursorPosition then box:SetCursorPosition(0) end
            if panel.scroll.SetVerticalScroll then panel.scroll:SetVerticalScroll(0) end
        end, true)
        self.exportPrepare:SetHeight(31)
        panel.select = Action(contribute, "Select JSON to copy", 13, 240, 133, function()
            box:SetFocus()
            box:HighlightText()
        end, true)
        panel.copyHint = Text(contribute, "Press Ctrl+C, then send it on CurseForge.", 156, 249, 380, 10, "regular", "muted")
        panel.contact = self:CreateBrowserSurface(contribute, 13, -275, 526, 47, "inset", "brass")
        Text(panel.contact, "Message me on CurseForge", 8, 8, 340, 11, "medium", "gold")
        Text(panel.contact, "Link not configured", 8, 25, 340, 10, "regular", "muted")
        for i, caption in ipairs({ "Copy link", "Open link" }) do
            local button = Action(panel.contact, caption, 354 + (i - 1) * 84, 8, 78)
            button:SetEnabled(false)
            if button.GetFontString then self:StyleBrowserText(button:GetFontString(), 10, "medium", "muted") end
        end
    end
    browser.dataView = view
    browser.workspace:Hide()
    browser.search:ClearFocus()
    browser.detailSearch:ClearFocus()
    self.exportPanel.document, self.exportPanel.message = nil, nil
    self.exportBox:ClearFocus()
    self.exportBox:SetText("")
    self.exportPanel:Show()
    self:RefreshDataView()
end

function VIC:OpenExport()
    self:OpenDataView("contribute")
end
