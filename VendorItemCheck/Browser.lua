local _, VIC = ...

local function Matches(text, query)
    return string.find(string.lower(text or ""), string.lower(query or ""), 1, true) ~= nil
end

local function SortRows(rows)
    table.sort(rows, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
end

function VIC:BrowserItemName(id)
    self.browserNames = self.browserNames or {}
    return self.browserNames[id] or ("Item " .. id)
end

function VIC:BuildBrowserIndex(filters)
    filters = filters or {}
    local index = { items = {}, vendors = {}, zones = {} }
    local ids = {}
    for id in pairs(self.Items or {}) do ids[id] = true end
    if self.client == "forever" then
        for id in pairs(self.personalIndex or {}) do ids[id] = true end
    end
    for id in pairs(ids) do
        local info = self:GetItemVendors(id, filters)
        for _, vendor in ipairs(info and info.vendors or {}) do
            if not filters.zone or vendor.zone == filters.zone then
                local item = index.items[id]
                if not item then
                    item = { id = id, name = self:BrowserItemName(id), vendors = {} }
                    index.items[id] = item
                end
                item.vendors[#item.vendors + 1] = vendor
                local row = index.vendors[vendor.id]
                if not row then
                    row = { id = vendor.id, name = vendor.name, vendor = vendor, items = {} }
                    index.vendors[vendor.id] = row
                end
                row.items[#row.items + 1] = { id = id, name = item.name, vendor = vendor, price = info.price }
                index.zones[vendor.zone] = true
            end
        end
    end
    for _, row in pairs(index.vendors) do SortRows(row.items) end
    return index
end

function VIC:BrowserOfferText(vendor, price)
    local parts = { vendor.source == "personal" and "Personal" or "Bundled", vendor.zone or "Location unknown" }
    if vendor.x and vendor.x > 0 and vendor.y and vendor.y > 0 then
        parts[#parts + 1] = string.format("%s%.1f, %.1f", vendor.approximate and "~" or "", vendor.x, vendor.y)
    end
    local access = { A = "Alliance", H = "Horde", N = "Neutral", AH = "Both factions" }
    parts[#parts + 1] = vendor.accessObserved and "Observed access" or (access[vendor.faction] or "Access unverified")
    if vendor.quoteText then parts[#parts + 1] = vendor.quoteText .. " (observed quote)"
    elseif vendor.alternateCost then parts[#parts + 1] = "Alternate costs; price unavailable"
    elseif price ~= nil then parts[#parts + 1] = (self:FormatMoney(price) or "0c") .. " (Classic reference)"
    else parts[#parts + 1] = "Price unavailable" end
    if vendor.observedAt then
        parts[#parts + 1] = "Observed " .. (date and date("%Y-%m-%d", vendor.observedAt) or tostring(vendor.observedAt))
        if vendor.stock then parts[#parts + 1] = vendor.stock == -1 and "Stock: unlimited when observed" or ("Stock observed: " .. vendor.stock) end
    end
    return table.concat(parts, " | ")
end

function VIC:BrowserOfferSummary(vendor, price)
    if not vendor then return "No offer information" end
    local access = { A = "Alliance", H = "Horde", N = "Neutral", AH = "Both factions" }
    local cost = vendor.quoteText and (vendor.quoteText .. " (observed quote)")
        or vendor.alternateCost and "Alternate costs"
        or price and ((self:FormatMoney(price) or "0c") .. " (Classic reference)")
        or "Price unavailable"
    return (vendor.zone or "Location unknown")
        .. (vendor.approximate and " (approximate)" or "")
        .. " · " .. (vendor.accessObserved and "Observed access" or access[vendor.faction] or "Access unverified")
        .. "\n" .. cost
end

function VIC:ShowBrowserNotice(title, message)
    if not self.browserNotice then
        local frame = CreateFrame("Frame", "VendorItemCheckNotice", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(470, 300); frame:SetPoint("CENTER")
        if frame.SetFrameStrata then frame:SetFrameStrata("DIALOG") end
        if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
        frame.heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        frame.heading:SetPoint("TOPLEFT", 18, -35); frame.heading:SetWidth(430)
        frame.body = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        frame.body:SetPoint("TOPLEFT", 18, -65); frame.body:SetWidth(430); frame.body:SetJustifyH("LEFT")
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "VendorItemCheckNotice" end
        self.browserNotice = frame
    end
    if self.browserNotice.SetScale and UIParent and UIParent.GetWidth and UIParent.GetHeight then
        self.browserNotice:SetScale(math.min(1, (UIParent:GetWidth() - 24) / 470, (UIParent:GetHeight() - 24) / 300))
    end
    self.browserNotice.heading:SetText(title); self.browserNotice.body:SetText(message)
    self.browserNotice:Show()
end

local function Label(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Button(parent, text, x, y, width, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", action)
    return button
end

local function Search(parent, x, y, width, action)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 24)
    box:SetPoint("TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetMaxLetters(100)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", action)
    return box
end

function VIC:RefreshBrowser(rebuild)
    local panel = self.browserPanel
    if not panel or not panel:IsVisible() then return end
    if rebuild or not panel.index then panel.index = self:BuildBrowserIndex(panel.filters) end
    local rows = {}
    for _, row in pairs(panel.index[panel.tab]) do
        if Matches(row.name, panel.search:GetText()) or Matches(tostring(row.id), panel.search:GetText()) then rows[#rows + 1] = row end
    end
    SortRows(rows)
    panel.rows = rows
    panel.page = math.max(1, math.min(panel.page, math.max(1, #rows - 9)))
    local loading = false
    if panel.tab == "items" then
        for _, row in ipairs(rows) do if not (self.browserNames and self.browserNames[row.id]) then loading = true; break end end
    end
    panel.count:SetText(string.format("%d results%s", #rows, loading and " · names loading; search by ID" or " · scroll to browse"))
    for i, button in ipairs(panel.list) do
        local row = rows[panel.page - 1 + i]
        button.row = row
        if button.icon then
            if row and panel.tab == "items" then
                local api = C_Item and C_Item.GetItemIconByID or GetItemIcon
                local ok, texture = false, nil
                if api then ok, texture = pcall(api, row.id) end
                button.icon:SetTexture(ok and texture or "Interface\\Icons\\INV_Misc_QuestionMark"); button.icon:Show()
            else button.icon:Hide() end
        end
        if row then button:SetText((panel.selected == row.id and "> " or "") .. row.name .. (panel.tab == "items" and ("\n" .. #row.vendors .. " known sellers") or ("\n" .. (row.vendor.zone or "Location unknown")))); button:Show() else button:Hide() end
    end
    local previousSelection = panel.selected
    local selected = panel.selected and panel.index[panel.tab][panel.selected]
    if panel.selected and not selected then
        panel.selected = nil
        panel.description:SetText("This record is no longer available; its evidence may have expired.")
    end
    local expired = previousSelection and not selected
    local details = {}
    panel.destination = nil
    if panel.itemIcon then
        if selected and panel.tab == "items" then
            local api = C_Item and C_Item.GetItemIconByID or GetItemIcon
            local ok, texture = false, nil
            if api then ok, texture = pcall(api, selected.id) end
            panel.itemIcon:SetTexture(ok and texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            panel.itemIcon:Show()
        else panel.itemIcon:Hide() end
    end
    if selected then
        panel.heading:SetText(selected.name .. (panel.tab == "vendors" and " - Known items" or " - Known sellers"))
        if panel.tab == "vendors" then
            details = selected.items
            panel.destination = selected.vendor
            panel.description:SetText(self:BrowserOfferSummary(selected.vendor))
        else
            for _, vendor in ipairs(selected.vendors) do
                details[#details + 1] = { id = vendor.id, name = vendor.name, vendor = vendor,
                    price = (self.client == "classic" and self.Items[selected.id] and self.Items[selected.id].p) or nil }
            end
            if not self.settings.showClosestFirst then SortRows(details) end
            panel.description:SetText("Select a seller to browse its known inventory and track its location.")
        end
    else
        panel.heading:SetText(expired and "Record no longer available" or ("Select an " .. (panel.tab == "items" and "item" or "vendor")))
        panel.description:SetText(expired and "The evidence for this record may have expired. Select another result." or #rows == 0 and (panel.search:GetText() ~= "" and "No search matches. Clear the search or try an item/NPC ID."
                or (panel.filters.source or panel.filters.zone or panel.filters.allFactions) and "No records match these filters. Choose Clear filters."
                or self.client == "forever" and ("No known records yet. Visit merchants to learn their offers. Learning: " .. (self.settings.recordMerchants and "on" or "off") .. ". Missing data does not mean unavailable.")
                or self.client == "classic" and "No known records."
                or "Unsupported client: no dataset is loaded.") or "Search names or IDs. Inventories and prices reflect known records, not current stock.")
    end
    local filtered = {}
    for _, row in ipairs(details) do
        if Matches(row.name, panel.detailSearch:GetText()) or Matches(tostring(row.id), panel.detailSearch:GetText()) then filtered[#filtered + 1] = row end
    end
    panel.detailPage = math.max(1, math.min(panel.detailPage, math.max(1, #filtered - 5)))
    panel.detailCount:SetText(string.format("%d known results", #filtered))
    for i, button in ipairs(panel.details) do
        local row = filtered[panel.detailPage - 1 + i]
        button.row = row
        if row then
            button.caption:SetText(row.name .. "\n" .. self:BrowserOfferSummary(row.vendor, row.price))
            button.track:SetText(panel.tab == "items" and "Track" or "Sellers")
            button.track:SetEnabled(panel.tab == "vendors" or self:CanTrackVendor(row.vendor))
            button.track.tooltipText = self:CanTrackVendor(row.vendor) and "Track recorded vendor location" or "Location unknown or expired; tracking is unavailable."
            button.track:SetScript("OnEnter", function(b)
                if GameTooltip and GameTooltip.SetText then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(b.tooltipText); GameTooltip:Show()
                elseif b.row and GameTooltip and GameTooltip.SetText then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(b.row.name); GameTooltip:Show()
                end
            end)
            button.track:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.track:SetScript("OnClick", function()
                if panel.tab == "items" then self:TrackVendor(row.vendor)
                else button:GetScript("OnClick")(button) end
            end)
            button.track:Show(); button.info:Show()
            button:Show()
        else button:Hide(); if button.track then button.track:Hide(); button.info:Hide() end end
    end
    if panel.coverage then
        local personalItems, personalVendors = 0, 0
        if self.client == "forever" and self.CountPersonalItems then personalItems, personalVendors = self:CountPersonalItems() end
        local count = self:CountIndexedItems()
        panel.coverage:SetText(tostring(self.client) .. " · Bundled: " .. count .. " items · Personal: " .. personalItems .. " items")
    end
    panel.updating = true
    for _, pair in ipairs({ { panel.resultsScroll, #rows - 9, panel.page }, { panel.detailsScroll, #filtered - 5, panel.detailPage } }) do
        if pair[1] and pair[1].SetMinMaxValues then pair[1]:SetMinMaxValues(1, math.max(1, pair[2])); pair[1]:SetValue(pair[3]) end
    end
    panel.updating = false
    if panel.itemsTab then panel.itemsTab:SetText(panel.tab == "items" and "[Items]" or "Items"); panel.vendorsTab:SetText(panel.tab == "vendors" and "[Vendors]" or "Vendors") end
    if panel.clearFilters then panel.clearFilters:SetEnabled(panel.filters.source ~= nil or panel.filters.zone ~= nil or panel.filters.allFactions == true) end
    if selected then panel.detailSearch:Show() else panel.detailSearch:Hide() end
    if panel.expanded then panel.description:SetText(self:BrowserOfferText(panel.expanded.vendor, panel.expanded.price)) end
    if panel.back then panel.back:SetEnabled(#panel.history > 0 or (panel.compact and panel.selected ~= nil)) end
    if panel.Layout then panel:Layout() end
    panel.track:SetEnabled(self:CanTrackVendor(panel.destination))
end

function VIC:OpenBrowser()
    if not self.browserPanel then
        local panel = CreateFrame("Frame", "VendorItemCheckBrowser", UIParent, "BasicFrameTemplateWithInset")
        self.browserPanel = panel
        panel:SetSize(900, 620)
        panel:SetPoint("CENTER")
        if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
        panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "VendorItemCheckBrowser" end
        (panel.TitleText or Label(panel, "", 15, -8, 700)):SetText("Vendor Item Check - Browser")
        panel.history = {}; panel.tabStates = {}
        panel.filters = {}; panel.tab = "items"; panel.page = 1; panel.detailPage = 1
        local function Refresh() self:RefreshBrowser() end
        local function SaveState()
            return { tab = panel.tab, selected = panel.selected, page = panel.page,
                detailPage = panel.detailPage, search = panel.search:GetText(),
                detailSearch = panel.detailSearch:GetText(),
                filters = { source = panel.filters.source, zone = panel.filters.zone,
                    allFactions = panel.filters.allFactions } }
        end
        local function Restore(state)
            panel.tab = state.tab; panel.selected = state.selected
            panel.filters = state.filters or {}
            panel.search:SetText(state.search or "")
            panel.detailSearch:SetText(state.detailSearch or "")
            panel.page = state.page or 1; panel.detailPage = state.detailPage or 1
            panel.source:SetText("Source: " .. (panel.filters.source or "All"))
            panel.zone:SetText("Zone: " .. (panel.filters.zone or "All"))
            panel.faction:SetText(panel.filters.allFactions and "All factions" or "Your faction + unverified")
            self:RefreshBrowser(true)
        end
        local function ChangeTab(tab)
            panel.tabStates[panel.tab] = SaveState()
            Restore(panel.tabStates[tab] or { tab = tab })
        end
        panel.help = Button(panel, "Help", 750, -68, 120, function()
            self:ShowBrowserNotice("Find items and vendors",
                "Choose Items to find known sellers, or Vendors to explore known inventories. Search by name or ID. Use the filters to narrow results.\n\nClick a row to inspect it; click a related item or vendor to follow it. Back restores your previous view. Scroll either list with the mouse wheel or scrollbar.\n\nTrack saves one destination for this session. Locations may be approximate. Prices and stock are recorded evidence, not live availability.\n\nOn Forever, visit merchants with learning enabled to grow your local journal. /vic settings opens settings.")
        end)
        panel.back = Button(panel, "Back", 680, -35, 65, function()
            local state = table.remove(panel.history)
            if not state then panel.selected = nil; Refresh(); return end
            Restore(state)
        end)
        panel.settingsButton = Button(panel, "Settings", 750, -35, 120, function() self:OpenOptions() end)
        panel.itemsTab = Button(panel, "Items", 16, -35, 100, function() ChangeTab("items") end)
        panel.vendorsTab = Button(panel, "Vendors", 120, -35, 100, function() ChangeTab("vendors") end)
        panel.source = Button(panel, "Source: All", 230, -35, 170, function()
            self:OpenChoiceMenu(panel.source, {
                { label = "All sources", value = "all" },
                { label = "Personal observations", value = "personal" },
                { label = "Bundled data", value = "bundled" },
            }, function(value)
                panel.filters.source = value ~= "all" and value or nil
                panel.source:SetText("Source: " .. value)
                panel.page = 1; self:RefreshBrowser(true)
            end)
        end)
        panel.faction = Button(panel, "Your faction + unverified", 410, -35, 260, function()
            self:OpenChoiceMenu(panel.faction, {
                { label = "Your faction + unverified", value = false },
                { label = "All factions", value = true },
            }, function(value)
                panel.filters.allFactions = value
                panel.faction:SetText(value and "All factions" or "Your faction + unverified")
                panel.page = 1; self:RefreshBrowser(true)
            end)
        end)
        panel.zone = Button(panel, "Zone: All", 16, -68, 240, function()
            local choices = { { label = "All zones", value = false } }
            local zones = {}
            for zone in pairs(self:BuildBrowserIndex({}).zones) do zones[#zones + 1] = zone end
            table.sort(zones)
            for _, zone in ipairs(zones) do choices[#choices + 1] = { label = zone, value = zone } end
            self:OpenChoiceMenu(panel.zone, choices, function(value)
                panel.filters.zone = value or nil
                panel.zone:SetText("Zone: " .. (value or "All"))
                panel.page = 1; self:RefreshBrowser(true)
            end)
        end)
        panel.clearFilters = Button(panel, "Clear filters", 260, -68, 90, function()
            panel.filters = {}; panel.page = 1
            panel.zone:SetText("Zone: All"); panel.source:SetText("Source: All")
            panel.faction:SetText("Your faction + unverified")
            self:RefreshBrowser(true)
        end)
        Label(panel, "Search names or IDs", 22, -101, 300)
        panel.search = Search(panel, 22, -120, 310, function() panel.page = 1; Refresh() end)
        panel.clearSearch = Button(panel, "X", 310, -120, 30, function()
            panel.search:SetText(""); panel.page = 1; Refresh()
        end)
        panel.heading = Label(panel, "", 365, -76, 510)
        panel.description = Label(panel, "", 365, -99, 510)
        if panel.CreateTexture then
            panel.itemIcon = panel:CreateTexture(nil, "ARTWORK")
            panel.itemIcon:SetSize(22, 22)
        end
        panel.detailSearch = Search(panel, 372, -155, 490, function() panel.detailPage = 1; Refresh() end)
        panel.detailLabel = Label(panel, "Filter sellers or inventory", 372, -137, 490)
        panel.list = {}; panel.details = {}
        for i = 1, 10 do
            local button = Button(panel, "", 16, -155 - (i - 1) * 37, 330, function(b)
                panel.expanded = nil; panel.selected = b.row.id; panel.detailPage = 1; panel.detailSearch:SetText(""); Refresh()
            end)
            button:SetScript("OnEnter", function(b)
                if panel.tab == "items" and b.row and GameTooltip then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. b.row.id); GameTooltip:Show()
                elseif b.row and GameTooltip and GameTooltip.SetText then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(b.row.name); GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            if button.CreateTexture then
                button.icon = button:CreateTexture(nil, "ARTWORK")
                button.icon:SetSize(22, 22); button.icon:SetPoint("LEFT", 3, 0)
            end
            panel.list[i] = button
        end
        for i = 1, 6 do
            local button = CreateFrame("Button", nil, panel)
            button:SetPoint("TOPLEFT", 365, -190 - (i - 1) * 55); button:SetSize(365, 53)
            if button.SetHighlightTexture then button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD") end
            button.caption = Label(button, "", 0, 0, 355)
            button.track = Button(panel, "Track", 737, -192 - (i - 1) * 55, 65, function()
                if button.row then self:TrackVendor(button.row.vendor) end
            end)
            button.info = Button(panel, "Details", 805, -192 - (i - 1) * 55, 65, function()
                if not button.row then return end
                self:ShowBrowserNotice(button.row.name, self:BrowserOfferText(button.row.vendor, button.row.price) .. "\nID: " .. button.row.id)
            end)
            button:SetScript("OnClick", function(b)
                local id = b.row.id
                panel.history[#panel.history + 1] = SaveState()
                if #panel.history > 50 then table.remove(panel.history, 1) end
                panel.tab = panel.tab == "items" and "vendors" or "items"
                panel.selected = id; panel.page = 1; panel.detailPage = 1
                panel.search:SetText(""); panel.detailSearch:SetText(""); Refresh()
            end)
            button:SetScript("OnEnter", function(b)
                if panel.tab == "vendors" and b.row and GameTooltip then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. b.row.id); GameTooltip:Show()
                elseif b.row and GameTooltip and GameTooltip.SetText then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(b.row.name); GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            panel.details[i] = button
        end
        panel.count = Label(panel, "", 22, -535, 320)
        panel.detailCount = Label(panel, "", 370, -535, 500)
        local function Wheel(frame, detail)
            if not frame.EnableMouseWheel then return end
            frame:EnableMouseWheel(true)
            frame:SetScript("OnMouseWheel", function(_, delta)
                local key = detail and "detailPage" or "page"
                panel[key] = math.max(1, panel[key] - delta * 3)
                Refresh()
            end)
        end
        for _, row in ipairs(panel.list) do Wheel(row, false) end
        for _, row in ipairs(panel.details) do Wheel(row, true) end
        -- Native sliders offer dragging as well as wheel navigation.
        local function Scrollbar(detail)
            local bar = CreateFrame("Slider", nil, panel, "UIPanelScrollBarTemplate")
            bar:SetPoint("TOPLEFT", detail and 875 or 342, -190)
            bar:SetSize(16, 325)
            if bar.SetMinMaxValues then
                bar:SetMinMaxValues(1, 1); bar:SetValueStep(1)
                bar:SetScript("OnValueChanged", function(_, value)
                    if panel.updating then return end
                    panel[detail and "detailPage" or "page"] = math.floor(value + 0.5)
                    Refresh()
                end)
            end
            return bar
        end
        panel.resultsScroll = Scrollbar(false); panel.detailsScroll = Scrollbar(true)
        panel.data = Button(panel, "Data details", 16, -585, 120, function()
            local meta = self.dataMetadata or {}
            self:ShowBrowserNotice("Data coverage", "Client: " .. tostring(self.client)
                .. "\nSource date: " .. tostring(meta.dataAsOf or "Unknown")
                .. "\n" .. tostring(meta.credit or "Classic historical reference data")
                .. "\n\nKnown inventories may be incomplete. Personal quotes belong to the observing character. Missing data does not mean unavailable.")
        end)
        panel.coverage = Label(panel, "", 145, -589, 540)
        panel.track = Button(panel, "Track vendor", 700, -555, 175, function() self:TrackVendor(panel.destination) end)
        function panel:Layout()
            local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1024
            local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
            local compact = width < 920 or height < 640
            self.compact = compact
            local detail = compact and self.selected ~= nil
            local function Move(frame, x, y, w)
                if frame.ClearAllPoints then frame:ClearAllPoints() end
                frame:SetPoint("TOPLEFT", x, y)
                if w then frame:SetWidth(w) end
            end
            self:SetSize(compact and 700 or 900, 620)
            if self.SetScale then self:SetScale(math.min(1, (width - 24) / (compact and 700 or 900), (height - 24) / 620)) end
            Move(self.back, compact and 410 or 680, -35)
            Move(self.help, compact and 480 or 750, compact and -35 or -68, compact and 65 or 120)
            Move(self.settingsButton, compact and 560 or 750, -35)
            Move(self.source, compact and 260 or 230, compact and -68 or -35, compact and 150 or 170)
            Move(self.faction, 410, compact and -68 or -35, compact and 275 or 260)
            Move(self.zone, 16, -68, 240)
            Move(self.clearFilters, compact and 560 or 260, compact and -101 or -68)
            Move(self.search, 22, -120, compact and 510 or 280)
            Move(self.clearSearch, compact and 535 or 310, -120)
            Move(self.heading, compact and 22 or 365, compact and -155 or -76, compact and 650 or 510)
            if self.itemIcon then
                Move(self.itemIcon, compact and 22 or 365, compact and -155 or -76)
                if self.selected and self.tab == "items" then
                    Move(self.heading, compact and 50 or 393, compact and -155 or -76, compact and 620 or 480)
                end
            end
            Move(self.description, compact and 22 or 365, compact and -180 or -99, compact and 650 or 510)
            Move(self.detailSearch, compact and 22 or 372, compact and -220 or -155, compact and 510 or 490)
            Move(self.detailLabel, compact and 22 or 372, compact and -204 or -137)
            for i, row in ipairs(self.list) do
                Move(row, 16, -155 - (i - 1) * 37, compact and 650 or 320)
                if compact and detail then row:Hide() end
            end
            for i, row in ipairs(self.details) do
                local y = (compact and -250 or -190) - (i - 1) * (compact and 49 or 55)
                Move(row, compact and 22 or 365, y, compact and 490 or 365)
                row.caption:SetWidth(compact and 480 or 355)
                Move(row.track, compact and 535 or 737, y - 2)
                Move(row.info, compact and 603 or 805, y - 2)
                if compact and not detail then row:Hide(); row.track:Hide(); row.info:Hide() end
            end
            if compact and not detail then
                if self.rows and #self.rows == 0 then self.heading:Show(); self.description:Show()
                else self.heading:Hide(); self.description:Hide() end
                self.detailSearch:Hide(); self.detailLabel:Hide()
                self.detailCount:Hide(); self.detailsScroll:Hide(); self.track:Hide()
            else
                self.heading:Show(); self.description:Show()
                if self.selected then self.detailSearch:Show(); self.detailLabel:Show() else self.detailLabel:Hide() end
                self.detailCount:Show(); self.detailsScroll:Show(); self.track:Show()
            end
            if compact and detail then self.resultsScroll:Hide(); self.count:Hide()
            else self.resultsScroll:Show(); self.count:Show() end
            Move(self.resultsScroll, compact and 675 or 342, -190)
            Move(self.detailsScroll, compact and 680 or 875, compact and -250 or -190)
            Move(self.detailCount, compact and 22 or 370, -555)
            Move(self.track, compact and 510 or 700, -555)
            self.coverage:SetWidth(compact and 520 or 540)
        end
        panel:SetScript("OnShow", function() panel:Layout(); self:RefreshBrowser(true) end)
        panel:Layout()
        panel:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        panel:SetScript("OnEvent", function(_, _, id, success)
            if success and panel.requested then panel.requested[id] = nil end
        end)
        local elapsed, freshnessElapsed = 0, 0
        panel:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            freshnessElapsed = freshnessElapsed + delta
            if freshnessElapsed >= 30 then
                freshnessElapsed = 0
                self:RefreshBrowser(true)
            end
            if elapsed < 0.2 then return end
            elapsed = 0
            -- Resolve a bounded batch; avoid repeatedly requesting unavailable item IDs.
            local count, changed = 0, false
            panel.requested = panel.requested or {}
            for id in pairs(panel.index and panel.index.items or {}) do
                if not panel.requested[id] then
                    local api = C_Item and C_Item.GetItemInfo or GetItemInfo
                    local ok, name = false, nil
                    if api then ok, name = pcall(api, id) end
                    if ok and type(name) == "string" and self:BrowserItemName(id) ~= name then
                        self.browserNames = self.browserNames or {}; self.browserNames[id] = name; changed = true
                    end
                    panel.requested[id] = true; count = count + 1
                    if count >= 20 then break end
                end
            end
            if changed then self:RefreshBrowser(true) end
        end)
    end
    self.browserPanel:Show()
    self:RefreshBrowser(true)
end
