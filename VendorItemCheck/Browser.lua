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
    panel.page = math.max(1, math.min(panel.page, math.max(1, math.ceil(#rows / 10))))
    panel.count:SetText(string.format("%d results | Page %d/%d", #rows, panel.page, math.max(1, math.ceil(#rows / 10))))
    for i, button in ipairs(panel.list) do
        local row = rows[(panel.page - 1) * 10 + i]
        button.row = row
        if row then button:SetText(row.name .. " (" .. row.id .. ")"); button:Show() else button:Hide() end
    end
    local selected = panel.selected and panel.index[panel.tab][panel.selected]
    local details = {}
    panel.destination = nil
    if selected then
        panel.heading:SetText(selected.name .. (panel.tab == "vendors" and " - Known items" or " - Known sellers"))
        if panel.tab == "vendors" then
            details = selected.items
            panel.destination = selected.vendor
            panel.description:SetText(self:BrowserOfferText(selected.vendor))
        else
            for _, vendor in ipairs(selected.vendors) do
                details[#details + 1] = { id = vendor.id, name = vendor.name, vendor = vendor,
                    price = (self.client == "classic" and self.Items[selected.id] and self.Items[selected.id].p) or nil }
            end
            SortRows(details)
            panel.description:SetText("Select a seller to browse its known inventory and track its location.")
        end
    else
        panel.heading:SetText("Select an item or vendor")
        panel.description:SetText(#rows == 0 and "No matching records. On Forever, visit merchants to learn their offers. Missing data does not mean unavailable." or "Search names or IDs. Inventories and prices reflect known records, not current stock.")
    end
    local filtered = {}
    for _, row in ipairs(details) do
        if Matches(row.name, panel.detailSearch:GetText()) or Matches(tostring(row.id), panel.detailSearch:GetText()) then filtered[#filtered + 1] = row end
    end
    panel.detailPage = math.max(1, math.min(panel.detailPage, math.max(1, math.ceil(#filtered / 6))))
    panel.detailCount:SetText(string.format("%d known results | Page %d/%d", #filtered, panel.detailPage, math.max(1, math.ceil(#filtered / 6))))
    for i, button in ipairs(panel.details) do
        local row = filtered[(panel.detailPage - 1) * 6 + i]
        button.row = row
        if row then
            button.caption:SetText(row.name .. " (" .. row.id .. ")\n" .. self:BrowserOfferText(row.vendor, row.price))
            button:Show()
        else button:Hide() end
    end
    panel.track:SetEnabled(self:CanTrackVendor(panel.destination))
end

function VIC:OpenBrowser()
    if not self.browserPanel then
        local panel = CreateFrame("Frame", "VendorItemCheckBrowser", UIParent, "BasicFrameTemplateWithInset")
        self.browserPanel = panel
        panel:SetSize(900, 620)
        panel:SetPoint("CENTER")
        panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "VendorItemCheckBrowser" end
        (panel.TitleText or Label(panel, "", 15, -8, 700)):SetText("Vendor Item Check - Browser")
        panel.filters = {}; panel.tab = "items"; panel.page = 1; panel.detailPage = 1
        local function Refresh() self:RefreshBrowser() end
        local function ChangeTab(tab)
            panel.tab = tab; panel.page = 1; panel.selected = nil; panel.detailPage = 1
            panel.search:SetText(""); panel.detailSearch:SetText(""); Refresh()
        end
        Button(panel, "Items", 16, -35, 100, function() ChangeTab("items") end)
        Button(panel, "Vendors", 120, -35, 100, function() ChangeTab("vendors") end)
        local sources = { "all", "personal", "bundled" }; local sourceIndex = 1
        panel.source = Button(panel, "Source: All", 230, -35, 170, function()
            sourceIndex = sourceIndex % #sources + 1
            panel.filters.source = sources[sourceIndex]
            if panel.filters.source == "all" then panel.filters.source = nil end
            panel.source:SetText("Source: " .. sources[sourceIndex]); panel.page = 1
            self:RefreshBrowser(true)
        end)
        panel.faction = Button(panel, "Access: compatible / unknown", 410, -35, 260, function()
            panel.filters.allFactions = not panel.filters.allFactions
            panel.faction:SetText(panel.filters.allFactions and "Access: all factions" or "Access: compatible / unknown")
            self:RefreshBrowser(true)
        end)
        panel.zone = Button(panel, "Zone: All", 16, -68, 330, function()
            local zones = {}; local filters = { source = panel.filters.source, allFactions = panel.filters.allFactions }
            for zone in pairs(self:BuildBrowserIndex(filters).zones) do zones[#zones + 1] = zone end
            table.sort(zones)
            local nextZone = zones[1]
            if panel.filters.zone then
                nextZone = nil
                for i, zone in ipairs(zones) do if zone == panel.filters.zone then nextZone = zones[i + 1]; break end end
            end
            panel.filters.zone = nextZone; panel.zone:SetText("Zone: " .. (nextZone or "All"))
            self:RefreshBrowser(true)
        end)
        Label(panel, "Search names or IDs", 22, -101, 300)
        panel.search = Search(panel, 22, -120, 310, function() panel.page = 1; Refresh() end)
        panel.heading = Label(panel, "", 365, -76, 510)
        panel.description = Label(panel, "", 365, -99, 510)
        panel.detailSearch = Search(panel, 372, -155, 490, function() panel.detailPage = 1; Refresh() end)
        Label(panel, "Filter selected inventory / sellers by name or ID", 372, -137, 490)
        panel.list = {}; panel.details = {}
        for i = 1, 10 do
            local button = Button(panel, "", 16, -155 - (i - 1) * 37, 330, function(b)
                panel.selected = b.row.id; panel.detailPage = 1; panel.detailSearch:SetText(""); Refresh()
            end)
            button:SetScript("OnEnter", function(b)
                if panel.tab == "items" and b.row and GameTooltip then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. b.row.id); GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            panel.list[i] = button
        end
        for i = 1, 6 do
            local button = CreateFrame("Button", nil, panel)
            button:SetPoint("TOPLEFT", 365, -190 - (i - 1) * 55); button:SetSize(510, 53)
            button.caption = Label(button, "", 0, 0, 510)
            button:SetScript("OnClick", function(b)
                local id = b.row.id
                panel.tab = panel.tab == "items" and "vendors" or "items"
                panel.selected = id; panel.page = 1; panel.detailPage = 1
                panel.search:SetText(""); panel.detailSearch:SetText(""); Refresh()
            end)
            button:SetScript("OnEnter", function(b)
                if panel.tab == "vendors" and b.row and GameTooltip then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. b.row.id); GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            panel.details[i] = button
        end
        panel.count = Label(panel, "", 22, -535, 320)
        panel.detailCount = Label(panel, "", 370, -535, 500)
        Button(panel, "Previous", 16, -555, 100, function() panel.page = math.max(1, panel.page - 1); Refresh() end)
        Button(panel, "Next", 122, -555, 100, function() panel.page = panel.page + 1; Refresh() end)
        Button(panel, "Previous", 365, -555, 100, function() panel.detailPage = math.max(1, panel.detailPage - 1); Refresh() end)
        Button(panel, "Next", 471, -555, 100, function() panel.detailPage = panel.detailPage + 1; Refresh() end)
        panel.track = Button(panel, "Track vendor", 700, -555, 175, function() self:TrackVendor(panel.destination) end)
        panel:SetScript("OnShow", function() self:RefreshBrowser(true) end)
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
