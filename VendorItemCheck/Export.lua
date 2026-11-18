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
    return string.sub(header, 1, -2) .. ',"records":[' .. table.concat(encoded, ",") .. "]}"
end

function VIC:RefreshDataView()
    local panel = self.exportPanel
    if not panel or not self.browserPanel.dataView then return end
    local view = self.browserPanel.dataView
    local items, vendors, offers, latest = self:CountPersonalItems()
    local bundledItems, bundledVendors = self:CountIndexedItems()
    local meta = self.dataMetadata or {}
    local revision = meta.dataAsOf or "Unavailable"
    local eligible = self.client == "forever" and offers > 0
    local heading, body
    if view == "overview" then
        heading = "Data & sharing"
        body = offers == 0 and "No personal observations yet." or "Your locally collected vendor data and bundled directory coverage."
        panel.metrics[1].value:SetText(tostring(vendors))
        panel.metrics[2].value:SetText(tostring(items))
        panel.metrics[3].value:SetText(tostring(offers))
        panel.directory.text:SetText(("%d vendors      %d items      Data updated: %s"):format(bundledVendors, bundledItems, revision))
    elseif view == "status" then
        local version, build, _, interface
        if type(GetBuildInfo) == "function" then
            local ok
            ok, version, build, _, interface = pcall(GetBuildInfo)
            if not ok then version = nil end
        end
        local recording = self.client == "forever" and self.observations and (self.settings.recordMerchants and "On" or "Off") or "Unavailable"
        heading = "Data status"
        body = ("Active dataset: %s\nClient build: %s\nInterface: %s\nBundled data revision: %s\nBundled inventory: %d vendors / %d items\nPersonal observations: %d offers\nMerchant learning: %s\nLast merchant learned: %s\n\nCoverage does not mean live availability.")
            :format(meta.client or self.client or "Unavailable", version and (version .. " / " .. tostring(build)) or "Unavailable",
                tostring(interface or "Unavailable"), revision, bundledVendors, bundledItems, offers, recording,
                latest and (date and date("!%Y-%m-%d %H:%M UTC", latest) or tostring(latest)) or "Unavailable")
    else
        heading = "Contribute your vendor data"
        body = "Shared: vendor/item IDs, offers, prices, locations, times and a stable installation pseudonym.\nPrivate: character, account and realm identifiers.\nCC BY-SA 4.0 applies if you share. Nothing is sent automatically."
        if not eligible and not panel.document then body = body .. "\n\nNo eligible observations to export." end
        if panel.message then body = body .. "\n\n" .. panel.message end
    end
    panel.heading:SetText(heading)
    panel.body:SetText(body)
    panel.back:SetText(view == "overview" and "Back to Browse" or "Back to Data")
    local function Show(widget, visible) if visible then widget:Show() else widget:Hide() end end
    Show(panel.status, view == "overview")
    for _, card in ipairs(panel.metrics) do Show(card, view == "overview") end
    Show(panel.directory, view == "overview")
    Show(panel.contribute, view ~= "contribute")
    panel.contribute:SetEnabled(eligible)
    Show(self.exportPrepare, view == "contribute" and not panel.document)
    self.exportPrepare:SetEnabled(eligible)
    Show(panel.scroll, view == "contribute" and panel.document)
    Show(panel.select, view == "contribute" and panel.document)
    Show(panel.contact, view == "contribute" and panel.document)
end

function VIC:OpenDataView(view)
    self:OpenBrowser()
    local browser = self.browserPanel
    if self.choiceMenu then self.choiceMenu:Hide() end
    if not self.exportPanel then
        local panel = CreateFrame("Frame", nil, browser)
        panel:SetPoint("TOPLEFT", 5, -32)
        panel:SetSize(560, 380)
        self:StyleBrowserSurface(panel, "background", "brass")
        if panel.EnableMouse then panel:EnableMouse(true) end
        if panel.SetFrameLevel and browser.GetFrameLevel then panel:SetFrameLevel(browser:GetFrameLevel() + 15) end
        self.exportPanel = panel
        panel.heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        panel.heading:SetPoint("TOPLEFT", 14, -36)
        panel.body = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        panel.body:SetPoint("TOPLEFT", 14, -65)
        panel.body:SetWidth(530)
        panel.body:SetJustifyH("LEFT")
        panel.back = self:CreateBrowserButton(panel, "Back", 10, -5, 122, function()
            if browser.dataView ~= "overview" then self:OpenDataView("overview"); return end
            browser.dataView = nil
            panel:Hide()
            self:RefreshBrowser(true)
        end)
        panel.metrics = {}
        for i, label in ipairs({ "Vendors", "Items", "Recorded offers" }) do
            local card = self:CreateBrowserSurface(panel, 12 + 178 * (i - 1), -95, 170, 55, "inset", "brass")
            card.value = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            card.value:SetPoint("TOPLEFT", 10, -9)
            local caption = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            caption:SetPoint("TOPLEFT", 10, -33)
            caption:SetText(label)
            panel.metrics[i] = card
        end
        panel.directory = self:CreateBrowserSurface(panel, 12, -165, 526, 57, "inset")
        local directoryHeading = panel.directory:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        directoryHeading:SetPoint("TOPLEFT", 10, -9)
        directoryHeading:SetText("Bundled directory")
        panel.directory.text = panel.directory:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        panel.directory.text:SetPoint("TOPLEFT", 10, -33)
        panel.status = self:CreateBrowserButton(panel, "View status", 410, -245, 130, function() self:OpenDataView("status") end)
        panel.contribute = self:CreateBrowserButton(panel, "Contribute data", 410, -285, 130, function() self:OpenExport() end)
        panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        panel.scroll:SetPoint("TOPLEFT", 15, -157)
        panel.scroll:SetSize(506, 132)
        local box = CreateFrame("EditBox", nil, panel.scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        box:SetWidth(502)
        box:SetHeight(132)
        box:SetMaxLetters(0)
        box:SetScript("OnEscapePressed", function(edit) edit:ClearFocus(); browser:Hide() end)
        box:SetScript("OnTextChanged", function(edit)
            local expected = panel.document or ""
            if edit:GetText() ~= expected then edit:SetText(expected) end
            panel.scroll:UpdateScrollChildRect()
        end)
        panel.scroll:SetScrollChild(box)
        self.exportBox = box
        self.exportPrepare = self:CreateBrowserButton(panel, "Generate contribution data", 15, -170, 210, function()
            local ok, document, message = pcall(self.BuildContribution, self)
            if ok and document then panel.document = document; box:SetText(document)
            else panel.message = ok and message or "Could not encode the stored observations." end
            self:RefreshDataView()
        end)
        panel.select = self:CreateBrowserButton(panel, "Select JSON to copy", 15, -295, 166, function()
            box:SetFocus()
            box:HighlightText()
        end)
        panel.contact = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        panel.contact:SetPoint("TOPLEFT", 15, -325)
        panel.contact:SetText("Press Ctrl+C, then send it on CurseForge. Project contact link unavailable.")
    end
    browser.dataView = view
    self.exportPanel.document, self.exportPanel.message = nil, nil
    self.exportBox:ClearFocus()
    self.exportBox:SetText("")
    self.exportPanel:Show()
    self:RefreshDataView()
end

function VIC:OpenExport()
    self:OpenDataView("contribute")
end
