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

local function VendorContinent(vendor)
    if not vendor.mapID or not C_Map or type(C_Map.GetMapInfo) ~= "function" then return nil end
    local id = vendor.mapID
    for _ = 1, 8 do
        local ok, map = pcall(C_Map.GetMapInfo, id)
        if not ok or not map then return nil end
        if Enum and Enum.UIMapType and map.mapType == Enum.UIMapType.Continent then return map.name end
        if not map.parentMapID or map.parentMapID <= 0 or map.parentMapID == id then return nil end
        id = map.parentMapID
    end
end

function VIC:BrowserItemName(id)
    self.browserNames = self.browserNames or {}
    return self.browserNames[id] or ("Item #" .. id)
end

function VIC:BuildBrowserIndex(filters, ignoreZone)
    filters = filters or {}
    local index = { items = {}, vendors = {}, zones = {} }
    local ids = {}
    for id in pairs(self.Items or {}) do ids[id] = true end
    if self.client == "forever" then
        for id in pairs(self.personalIndex or {}) do ids[id] = true end
    end
    local zone = filters.zone
    if zone == "@current" then zone = self:GetPlayerLocation() end
    for id in pairs(ids) do
        local info = self:GetItemVendors(id, { source = filters.source, allFactions = true })
        for _, vendor in ipairs(info and info.vendors or {}) do
            if (ignoreZone or not zone or vendor.zone == zone) and
                (not filters.discounted or vendor.discount and vendor.discount > 0 and vendor.discount < 1 and vendor.copper) then
                vendor.inaccessible = not self:IsVendorFriendly(vendor.faction, self:GetPlayerFaction())
                if not filters.allFactions and vendor.inaccessible then
                    index.hidden = index.hidden or {}
                    index.hidden[id] = (index.hidden[id] or 0) + 1
                else
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
    end
    for _, item in pairs(index.items) do
        local groups = {}
        for _, vendor in ipairs(item.vendors) do
            if vendor.copper and vendor.quantity and vendor.quantity > 0 and not vendor.inaccessible then
                local context = vendor.discount or "unknown"
                local group = groups[context] or { count = 0 }
                groups[context] = group
                group.count = group.count + 1
                local best = group.best
                if not best or vendor.copper * best.quantity < best.copper * vendor.quantity then group.best = vendor end
            end
        end
        for _, vendor in ipairs(item.vendors) do
            local group = groups[vendor.discount or "unknown"]
            local best = group and group.count > 1 and group.best
            vendor.cheapest = best and vendor.copper and vendor.quantity and not vendor.inaccessible
                and vendor.copper * best.quantity == best.copper * vendor.quantity
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

local function OfferLines(self, vendor, price, inventory)
    local access = { A = "Alliance", H = "Horde", N = "Neutral", AH = "Both factions" }
    local cost = vendor.quoteText and (vendor.quoteText .. (inventory and "" or " (observed quote)"))
        or vendor.alternateCost and "Alternate costs"
        or price and ((self:FormatMoney(price) or "0c") .. (inventory and " (ref.)" or " (Classic reference)"))
        or "Price unavailable"
    local stock = vendor.stock
    local availability = stock == -1 and "Unlimited" or stock == 0 and "Sold out" or
        type(stock) == "number" and stock > 0 and (stock .. " left") or "Stock unknown"
    if vendor.quantity and vendor.quantity > 1 then availability = availability .. " · Stack " .. vendor.quantity end
    if inventory then return availability, cost end
    local location = (vendor.approximate and vendor.mapID and "~" or "") .. (vendor.zone or "Location unknown")
        .. " · " .. (vendor.accessObserved and "Observed access" or access[vendor.faction] or "Access unverified")
    return location, cost .. (vendor.cheapest and " · CHEAPEST" or "") .. " · " .. availability
end

local colors = {
    background = { 0.09, 0.11, 0.12 },
    inset = { 0.059, 0.073, 0.087 },
    header = { 0.13, 0.15, 0.17 },
    border = { 0.32, 0.29, 0.23 },
    brass = { 0.55, 0.42, 0.22 },
    selection = { 0.20, 0.16, 0.07 },
    gold = { 1, 0.80, 0.05 },
    muted = { 0.67, 0.64, 0.58 },
}

local function Fill(parent, color, inset)
    if not parent.CreateTexture then return end
    local texture = parent:CreateTexture(nil, "BACKGROUND", nil, inset > 0 and 1 or 0)
    if not texture.SetColorTexture then return end
    texture:SetPoint("TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", -inset, inset)
    texture:SetColorTexture(color[1], color[2], color[3], 1)
    return texture
end

function VIC:StyleBrowserSurface(frame, background, border)
    Fill(frame, colors[border or "border"], 0)
    frame.surface = Fill(frame, colors[background or "inset"], 1)
end

local function SetSelected(frame, selected)
    if frame.surface then
        local color = colors[selected and "selection" or "inset"]
        frame.surface:SetColorTexture(color[1], color[2], color[3], 1)
    end
end

function VIC:CreateBrowserSurface(parent, x, y, width, height, background, border)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", x, y)
    panel:SetSize(width, height)
    if panel.SetFrameLevel and parent.GetFrameLevel then panel:SetFrameLevel(parent:GetFrameLevel()) end
    self:StyleBrowserSurface(panel, background, border)
    return panel
end

local function Label(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function SingleLine(label)
    if label.SetMaxLines then label:SetMaxLines(1) end
    if label.SetWordWrap then label:SetWordWrap(false) end
end

function VIC:CreateBrowserButton(parent, text, x, y, width, action)
    local button = CreateFrame("Button", nil, parent)
    self:StyleBrowserSurface(button)
    if button.SetNormalFontObject then
        button:SetNormalFontObject(GameFontHighlightSmall)
        button:SetHighlightFontObject(GameFontNormalSmall)
        button:SetDisabledFontObject(GameFontDisableSmall)
        button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    end
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", action)
    return button
end

local function Button(parent, text, x, y, width, action)
    return VIC:CreateBrowserButton(parent, text, x, y, width, action)
end

local function Search(parent, x, y, width, action)
    local box = CreateFrame("EditBox", nil, parent)
    VIC:StyleBrowserSurface(box, "inset", "brass")
    if box.SetTextInsets then box:SetTextInsets(9, 6, 0, 0) end
    box:SetFontObject(GameFontHighlightSmall)
    box.placeholder = Label(box, "", 9, -6, width - 15)
    if box.placeholder.SetTextColor then box.placeholder:SetTextColor(unpack(colors.muted)) end
    box:SetSize(width, 24)
    box:SetPoint("TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetMaxLetters(100)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", action)
    return box
end

local function UpdateSearchHint(box, prompt)
    box.placeholder:SetText(prompt)
    if (box:GetText() or "") == "" then box.placeholder:Show() else box.placeholder:Hide() end
end

function VIC:RefreshBrowser(rebuild)
    local panel = self.browserPanel
    if panel and panel.dataView then if self.RefreshDataView then self:RefreshDataView() end; return end
    if not panel or not panel:IsVisible() then return end
    if rebuild or not panel.index then panel.index = self:BuildBrowserIndex(panel.filters) end
    local rows = {}
    for _, row in pairs(panel.index[panel.tab]) do
        if Matches(row.name, panel.search:GetText()) or Matches(tostring(row.id), panel.search:GetText()) then rows[#rows + 1] = row end
    end
    SortRows(rows)
    panel.rows = rows
    panel.page = math.max(1, math.min(panel.page, math.max(1, #rows - 6)))
    if panel.selectFirst and #rows > 0 and not panel.compact then
        panel.selected = panel.selected or rows[1].id
        panel.selectFirst = nil
    end
    local rowType = #rows == 1 and (panel.tab == "items" and "item" or "vendor") or panel.tab
    panel.count:SetText(string.format("%d %s", #rows, rowType))
    UpdateSearchHint(panel.search, panel.tab == "items" and "Search item name or ID" or "Search vendor name or NPC ID")
    UpdateSearchHint(panel.detailSearch, panel.tab == "items" and "Search sellers" or "Search inventory")
    for i, button in ipairs(panel.list) do
        local row = rows[panel.page - 1 + i]
        button.row = row
        if button.icon then
            if row and panel.tab == "items" then
                local api = C_Item and C_Item.GetItemIconByID or GetItemIcon
                local ok, texture = false, nil
                if api then ok, texture = pcall(api, row.id) end
                button.icon:SetTexture(ok and texture or "Interface\\Icons\\INV_Misc_QuestionMark"); button.icon:Show()
            elseif row then
                button.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
                button.icon:Show()
            else button.icon:Hide() end
        end
        if row then
            local selected = panel.selected == row.id
            SetSelected(button, selected)
            button.nameLabel:SetText(selected and ("|cffffcc00" .. row.name .. "|r") or row.name)
            local subtitle = panel.tab == "items" and (#row.vendors .. " known sellers")
                or ((row.vendor.zone or "Location unknown") .. " · " .. #row.items .. " items")
            button.subtitle:SetText(subtitle)
            button:Show()
        else button:Hide() end
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
        elseif selected then
            panel.itemIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            panel.itemIcon:Show()
        else panel.itemIcon:Hide() end
    end
    if selected then
        panel.heading:SetText(selected.name)
        if panel.tab == "vendors" then
            details = selected.items
            panel.destination = selected.vendor
            panel.description:SetText((selected.vendor.zone or "Location unknown") .. " · " .. #details .. " known items")
        else
            if self.settings.showClosestFirst then
                local zone, x, y = self:GetPlayerLocation()
                self:SortVendorsByProximity(selected.vendors, zone, x, y)
            end
            for _, vendor in ipairs(selected.vendors) do
                details[#details + 1] = { id = vendor.id, name = vendor.name, vendor = vendor,
                    price = (self.client == "classic" and self.Items[selected.id] and self.Items[selected.id].p) or nil }
            end
            if not self.settings.showClosestFirst then SortRows(details) end
            panel.description:SetText(#details .. " known sellers")
        end
    else
        panel.heading:SetText(expired and "Record no longer available" or #rows == 0
            and (panel.search:GetText() ~= "" and "No " .. panel.tab .. " match your search" or "No " .. panel.tab .. " to display")
            or ("Select " .. (panel.tab == "items" and "an item" or "a vendor")))
        panel.description:SetText(expired and "The evidence for this record may have expired. Select another result." or #rows == 0 and (panel.search:GetText() ~= "" and "No search matches. Clear the search or try an item/NPC ID."
                or (panel.filters.source or panel.filters.zone or panel.filters.allFactions) and "No records match these filters. Choose Clear filters."
                or self.client == "forever" and ("No known records yet. Visit merchants to learn their offers. Learning: " .. (self.settings.recordMerchants and "on" or "off") .. ". Missing data does not mean unavailable.")
                or self.client == "classic" and "No known records."
                or "Unsupported client: no dataset is loaded.") or "Search names or IDs. Inventories and prices reflect known records, not current stock.")
    end
    local filtered = {}
    for _, row in ipairs(details) do
        local matches = Matches(row.name, panel.detailSearch:GetText()) or Matches(tostring(row.id), panel.detailSearch:GetText())
        if panel.tab == "items" then
            matches = matches and (not panel.filters.sellerZone or row.vendor.zone == panel.filters.sellerZone)
                and (not panel.filters.continent or VendorContinent(row.vendor) == panel.filters.continent)
        end
        local stock = row.vendor.stock
        if matches and (panel.tab ~= "vendors" or not panel.filters.stock or
            panel.filters.stock == "available" and (stock == -1 or type(stock) == "number" and stock > 0) or
            panel.filters.stock == "soldout" and stock == 0 or panel.filters.stock == "unknown" and stock == nil) then
            filtered[#filtered + 1] = row
        end
    end
    local inventory = panel.tab == "vendors"
    local maxDetail = inventory and math.max(1, math.ceil(#filtered / 8)) or math.max(1, #filtered - 3)
    panel.detailMax = maxDetail
    panel.detailPage = math.max(1, math.min(panel.detailPage, maxDetail))
    panel.detailCount:SetText(inventory and ("Page " .. panel.detailPage .. " of " .. maxDetail)
        or string.format("%d sellers", #filtered))
    panel.previous:SetEnabled(panel.detailPage > 1)
    panel.next:SetEnabled(panel.detailPage < maxDetail)
    panel.reveal:Hide()
    if panel.index.hidden and panel.index.hidden[panel.selected] and not inventory then
        panel.reveal:Show()
        panel.detailCount:SetText(panel.detailCount:GetText() .. " · " .. panel.index.hidden[panel.selected] .. " hidden by access")
    end
    for i, button in ipairs(panel.details) do
        local row = (inventory or i <= 4) and filtered[(panel.detailPage - 1) * (inventory and 8 or 1) + i]
        button.row = row
        if row then
            local caption = row.name
            if inventory and type(GetItemInfo) == "function" then
                local ok, _, _, quality = pcall(GetItemInfo, row.id)
                local color = ok and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                if color and color.hex then caption = color.hex .. caption .. "|r" end
            end
            local location, offer = OfferLines(self, row.vendor, row.price, inventory)
            button.caption:SetText(caption)
            button.location:SetText(location)
            button.offer:SetText(offer)
            if button.icon then
                if inventory then
                    local api = C_Item and C_Item.GetItemIconByID or GetItemIcon
                    local ok, icon = false, nil
                    if api then ok, icon = pcall(api, row.id) end
                    button.icon:SetTexture(ok and icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    button.icon:Show()
                else button.icon:Hide() end
            end
            button.track:SetText(panel.tab == "items" and (self:OwnsVendorWaypoint(row.vendor) and "Remove" or "Waypoint") or "Sellers")
            button.track:SetEnabled(panel.tab == "vendors" or self:CanMapVendor(row.vendor))
            button.track.tooltipText = self:CanMapVendor(row.vendor) and "Track recorded vendor location" or "Location unknown or expired; tracking is unavailable."
            button.track:SetScript("OnEnter", function(b)
                if GameTooltip and GameTooltip.SetText then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(b.tooltipText); GameTooltip:Show()
                elseif b.row and GameTooltip and GameTooltip.SetText then
                    GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(b.row.name); GameTooltip:Show()
                end
            end)
            button.track:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.track:SetScript("OnClick", function()
                if panel.tab == "items" then self:TrackVendor(row.vendor); self:RefreshBrowser()
                else button:GetScript("OnClick")(button) end
            end)
            if inventory then button.track:Hide(); button.info:Hide()
            else button.track:Show(); button.info:Show() end
            button:Show()
        else
            if button.icon then button.icon:Hide() end
            button.caption:SetText("")
            button.location:SetText("")
            button.offer:SetText("")
            if inventory and selected then button:Show() else button:Hide() end
            button.track:Hide()
            button.info:Hide()
        end
    end
    if panel.coverage then
        local personalItems, personalVendors = 0, 0
        if self.client == "forever" and self.CountPersonalItems then personalItems, personalVendors = self:CountPersonalItems() end
        local count = self:CountIndexedItems()
        panel.coverage:SetText(tostring(self.client) .. " · Bundled: " .. count .. " items · Personal: " .. personalItems .. " items")
    end
    panel.updating = true
    for _, pair in ipairs({ { panel.resultsScroll, #rows - 6, panel.page }, { panel.detailsScroll, maxDetail, panel.detailPage } }) do
        if pair[1] and pair[1].SetMinMaxValues then pair[1]:SetMinMaxValues(1, math.max(1, pair[2])); pair[1]:SetValue(pair[3]) end
    end
    panel.updating = false
    for name, tab in pairs({ items = panel.itemsTab, vendors = panel.vendorsTab }) do
        local count = 0
        local query = name == panel.tab and panel.search:GetText() or (panel.tabStates[name] or {}).search or ""
        for id, row in pairs(panel.index[name]) do
            if Matches(row.name, query) or Matches(tostring(id), query) then count = count + 1 end
        end
        SetSelected(tab, panel.tab == name)
        tab:SetText((name == "items" and "Items" or "Vendors") .. "  " .. count)
    end
    panel.clearFilters:SetEnabled(next(panel.filters) ~= nil)
    if selected then panel.detailSearch:Show() else panel.detailSearch:Hide() end
    panel.expandedSummary:Hide()
    if panel.expanded then
        local expanded
        for _, row in ipairs(filtered) do if row.id == panel.expanded.id then expanded = row; break end end
        panel.expanded = expanded
        if expanded then
            panel.expandedSummary:SetText(self:BrowserOfferText(expanded.vendor, expanded.price))
            panel.expandedSummary:Show()
        end
    end
    if panel.back then panel.back:SetEnabled(#panel.history > 0 or (panel.compact and panel.selected ~= nil)) end
    panel.allZones:Hide()
    if #rows == 0 and panel.filters.zone then
        local alternative = self:BuildBrowserIndex(panel.filters, true)[panel.tab]
        local count = 0
        for id, row in pairs(alternative) do
            if Matches(row.name, panel.search:GetText()) or Matches(tostring(id), panel.search:GetText()) then count = count + 1 end
        end
        if count > 0 then
            panel.description:SetText(count .. " matches in other zones.")
            panel.allZones:SetText("Show all zones (" .. count .. ")")
            panel.allZones:Show()
        end
    end
    if panel.Layout then panel:Layout() end
    panel.track:SetText(self:OwnsVendorWaypoint(panel.destination) and "Remove Waypoint" or "Set Waypoint")
    local waypointAvailable = self:CanMapVendor(panel.destination) or self:OwnsVendorWaypoint(panel.destination)
    panel.track:SetEnabled(waypointAvailable)
    if inventory and selected and not waypointAvailable then
        panel.description:SetText(panel.destination.locationExpired and "Location expired · waypoint unavailable" or (panel.destination.zone or "Location unknown") .. " · waypoint unavailable")
    end
end

function VIC:OpenBrowser()
    if not self.browserPanel then
        local panel = CreateFrame("Frame", "VendorItemCheckBrowser", UIParent)
        self.browserPanel = panel
        panel:SetSize(570, 420)
        panel:SetPoint("CENTER")
        if panel.SetFrameStrata then panel:SetFrameStrata("DIALOG") end
        if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
        panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "VendorItemCheckBrowser" end
        self:StyleBrowserSurface(panel, "background", "brass")
        panel.titleBar = self:CreateBrowserSurface(panel, 2, -2, 566, 35, "header", "brass")
        local title = Label(panel.titleBar, "Vendor Item Check", 37, -8, 365)
        if title.SetFontObject then title:SetFontObject(GameFontNormalLarge) end
        if title.SetTextColor then title:SetTextColor(unpack(colors.gold)) end
        local crest = self:CreateBrowserSurface(panel.titleBar, 8, -6, 22, 22, "selection", "brass")
        if crest.CreateTexture then
            local icon = crest:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
        end
        Button(panel, "×", 543, -7, 20, function() panel:Hide() end)
        panel.resultsInset = self:CreateBrowserSurface(panel, 8, -109, 182, 305, "inset", "brass")
        panel.detailsInset = self:CreateBrowserSurface(panel, 196, -109, 368, 305, "inset", "brass")
        panel.detailHeader = self:CreateBrowserSurface(panel.detailsInset, 5, -4, 358, 44, "header")
        -- Keep inset text in front of the surfaces while anchoring it to the browser.
        local detailText = CreateFrame("Frame", nil, panel.detailsInset)
        detailText:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        detailText:SetSize(570, 420)
        panel.history = {}; panel.tabStates = {}
        panel.selectFirst = true
        panel.filters = {}; panel.tab = "items"; panel.page = 1; panel.detailPage = 1
        local function Refresh() self:RefreshBrowser() end
        local function SaveState()
            return { tab = panel.tab, selected = panel.selected, page = panel.page,
                detailPage = panel.detailPage, search = panel.search:GetText(),
                detailSearch = panel.detailSearch:GetText(),
                filters = { source = panel.filters.source, zone = panel.filters.zone,
                    allFactions = panel.filters.allFactions, discounted = panel.filters.discounted, stock = panel.filters.stock, sellerZone = panel.filters.sellerZone, continent = panel.filters.continent }, expanded = panel.expanded and panel.expanded.id }
        end
        local function Restore(state)
            panel.tab = state.tab; panel.selected = state.selected; panel.expanded = nil
            panel.filters = state.filters or {}
            panel.search:SetText(state.search or "")
            panel.detailSearch:SetText(state.detailSearch or "")
            panel.page = state.page or 1; panel.detailPage = state.detailPage or 1
            panel.source:SetText((panel.filters.source or panel.filters.discounted) and "Filters •" or "Filters")
            panel.zone:SetText("Zone: " .. (panel.filters.zone == "@current" and "Current" or panel.filters.zone or "Any"))
            panel.faction:SetText(panel.filters.allFactions and "All factions" or "Friendly +?")
            self:RefreshBrowser(true)
            if state.expanded then
                for _, row in ipairs(panel.details) do
                    if row.row and row.row.id == state.expanded then panel.expanded = row.row; Refresh(); break end
                end
            end
        end
        local function ChangeTab(tab)
            panel.tabStates[panel.tab] = SaveState()
            Restore(panel.tabStates[tab] or { tab = tab })
        end
        panel.back = Button(panel, "Back", 680, -35, 65, function()
            local state = table.remove(panel.history)
            if not state then panel.selected = nil; Refresh(); return end
            Restore(state)
        end)
        panel.settingsButton = Button(panel, "Settings", 750, -35, 120, function() self:OpenOptions() end)
        panel.itemsTab = Button(panel, "Items", 10, -38, 94, function() ChangeTab("items") end)
        panel.vendorsTab = Button(panel, "Vendors", 107, -38, 105, function() ChangeTab("vendors") end)
        panel.source = Button(panel, "Filters", 230, -35, 170, function()
            self:OpenChoiceMenu(panel.source, {
                { label = "All sources", value = "all" },
                { label = "Personal observations", value = "personal" },
                { label = "Bundled data", value = "bundled" },
                { label = "Toggle discounted only", value = "discount" },
            }, function(value)
                if value == "discount" then panel.filters.discounted = not panel.filters.discounted
                else panel.filters.source = value ~= "all" and value or nil end
                panel.source:SetText((panel.filters.source or panel.filters.discounted) and "Filters •" or "Filters")
                panel.page = 1; self:RefreshBrowser(true)
            end)
        end)
        panel.faction = Button(panel, "Friendly +?", 410, -35, 260, function()
            self:OpenChoiceMenu(panel.faction, {
                { label = "Your faction + unverified", value = false },
                { label = "All factions", value = true },
            }, function(value)
                panel.filters.allFactions = value
                panel.faction:SetText(value and "All factions" or "Friendly +?")
                panel.page = 1; self:RefreshBrowser(true)
            end)
        end)
        panel.zone = Button(panel, "Zone: Any", 16, -68, 240, function()
            local choices = { { label = "Any zone", value = false }, { label = "Current zone", value = "@current" } }
            local zones = {}
            for zone in pairs(self:BuildBrowserIndex({}).zones) do zones[#zones + 1] = zone end
            table.sort(zones)
            for _, zone in ipairs(zones) do choices[#choices + 1] = { label = zone, value = zone } end
            self:OpenChoiceMenu(panel.zone, choices, function(value)
                panel.filters.zone = value or nil
                panel.zone:SetText("Zone: " .. (value == "@current" and "Current" or value or "Any"))
                panel.page = 1; self:RefreshBrowser(true)
            end, true)
        end)
        panel.clearFilters = Button(panel, "Clear filters", 260, -68, 90, function()
            panel.filters = {}; panel.page = 1
            panel.zone:SetText("Zone: All"); panel.source:SetText("Filters")
            panel.faction:SetText("Friendly +?")
            self:RefreshBrowser(true)
        end)

        panel.search = Search(panel, 22, -120, 310, function() panel.page = 1; Refresh() end)
        panel.clearSearch = Button(panel, "X", 310, -120, 30, function()
            panel.search:SetText(""); panel.page = 1; Refresh()
        end)
        panel.heading = Label(detailText, "", 365, -76, 510)
        panel.description = Label(detailText, "", 365, -99, 510)
        SingleLine(panel.heading)
        if panel.description.SetMaxLines then panel.description:SetMaxLines(2) end
        panel.expandedSummary = Label(detailText, "", 200, -391, 350)
        if panel.expandedSummary.SetMaxLines then panel.expandedSummary:SetMaxLines(3) end
        panel.expandedSummary:Hide()
        if detailText.CreateTexture then
            panel.itemIcon = detailText:CreateTexture(nil, "ARTWORK")
            panel.itemIcon:SetSize(35, 35)
        end
        panel.detailSearch = Search(panel, 372, -155, 490, function() panel.detailPage = 1; Refresh() end)
        panel.detailLabel = Label(panel, "Search sellers or inventory", 372, -137, 490)
        panel.stock = Button(panel, "Show: All", 450, -155, 105, function()
            self:OpenChoiceMenu(panel.stock, {
                { label = "All stock", value = false }, { label = "In stock", value = "available" },
                { label = "Sold out", value = "soldout" }, { label = "Unknown stock", value = "unknown" },
            }, function(value)
                panel.filters.stock = value
                panel.detailPage = 1
                Refresh()
            end)
        end)
        local function SellerFilter(key, title, getValue)
            local button
            button = Button(panel, title, 0, 0, 97, function()
                local item = panel.index.items[panel.selected]
                local values, seen = {}, {}
                for _, vendor in ipairs(item and item.vendors or {}) do
                    local value = getValue(vendor)
                    if value and not seen[value] then
                        seen[value] = true
                        values[#values + 1] = value
                    end
                end
                table.sort(values)
                local choices = { { label = "All", value = false } }
                for _, value in ipairs(values) do choices[#choices + 1] = { label = value, value = value } end
                self:OpenChoiceMenu(button, choices, function(value)
                    panel.filters[key] = value or nil
                    if key == "continent" then panel.filters.sellerZone = nil end
                    panel.detailPage = 1
                    Refresh()
                end, true)
            end)
            return button
        end
        panel.continent = SellerFilter("continent", "Continent: All", VendorContinent)
        panel.sellerZone = SellerFilter("sellerZone", "Zone: All", function(vendor)
            if not panel.filters.continent or VendorContinent(vendor) == panel.filters.continent then return vendor.zone end
        end)
        panel.reveal = Button(panel, "Show", 503, -384, 55, function()
            panel.filters.allFactions = true
            panel.faction:SetText("All access")
            self:RefreshBrowser(true)
        end)
        panel.allZones = Button(panel, "Show all zones", 224, -235, 128, function()
            panel.filters.zone = nil
            panel.zone:SetText("Zone: Any")
            self:RefreshBrowser(true)
        end)
        panel.list = {}; panel.details = {}
        for i = 1, 7 do
            local button = Button(panel, "", 16, -155 - (i - 1) * 37, 330, function(b)
                panel.expanded = nil; panel.filters.sellerZone = nil; panel.filters.continent = nil; panel.selected = b.row.id; panel.detailPage = 1; panel.detailSearch:SetText(""); Refresh()
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
            button.nameLabel = Label(button, "", 38, -5, 125)
            button.subtitle = Label(button, "", 38, -19, 125)
            SingleLine(button.nameLabel)
            SingleLine(button.subtitle)
            if button.subtitle.SetTextColor then button.subtitle:SetTextColor(unpack(colors.muted)) end
            panel.list[i] = button
        end
        for i = 1, 8 do
            local button = CreateFrame("Button", nil, panel)
            button:SetPoint("TOPLEFT", 365, -190 - (i - 1) * 55); button:SetSize(365, 53)
            if button.SetHighlightTexture then button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD") end
            self:StyleBrowserSurface(button)
            button.caption = Label(button, "", 0, 0, 355)
            button.location = Label(button, "", 0, 0, 355)
            button.offer = Label(button, "", 0, 0, 355)
            SingleLine(button.caption)
            SingleLine(button.location)
            SingleLine(button.offer)
            if button.location.SetTextColor then button.location:SetTextColor(unpack(colors.muted)) end
            if button.CreateTexture then
                button.icon = button:CreateTexture(nil, "ARTWORK")
                button.icon:SetSize(32, 32)
                button.icon:SetPoint("LEFT", 4, 0)
            end
            button.track = Button(panel, "Track", 737, -192 - (i - 1) * 55, 65, function()
                if button.row then self:TrackVendor(button.row.vendor) end
            end)
            button.info = Button(panel, "Details", 805, -192 - (i - 1) * 55, 65, function()
                if not button.row then return end
                if panel.expanded and panel.expanded.id == button.row.id then panel.expanded = nil
                else panel.expanded = button.row end
                Refresh()
            end)
            button.info:SetScript("OnEnter", function(owner)
                if button.row and GameTooltip and GameTooltip.SetText then
                    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self:BrowserOfferText(button.row.vendor, button.row.price), 1, 1, 1, 1, true)
                    GameTooltip:Show()
                end
            end)
            button.info:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button:SetScript("OnClick", function(b)
                if not b.row then return end
                local id = b.row.id
                panel.tabStates[panel.tab] = SaveState()
                panel.history[#panel.history + 1] = SaveState()
                if #panel.history > 50 then table.remove(panel.history, 1) end
                local target = panel.tab == "items" and "vendors" or "items"
                Restore({ tab = target, selected = id, filters = { source = panel.filters.source, allFactions = panel.filters.allFactions } })
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
        panel.count = Label(panel.resultsInset, "", 8, -7, 166)
        panel.detailCount = Label(detailText, "", 370, -535, 500)
        local function Wheel(frame, detail)
            if not frame.EnableMouseWheel then return end
            frame:EnableMouseWheel(true)
            frame:SetScript("OnMouseWheel", function(_, delta)
                local key = detail and "detailPage" or "page"
                panel[key] = math.max(1, panel[key] - delta * (detail and panel.tab == "vendors" and 1 or 3))
                Refresh()
            end)
        end
        for _, row in ipairs(panel.list) do Wheel(row, false) end
        for _, row in ipairs(panel.details) do Wheel(row, true) end
        -- Native sliders offer dragging as well as wheel navigation.
        local function Scrollbar(detail)
            local bar = CreateFrame("Slider", nil, panel)
            bar:SetPoint("TOPLEFT", detail and 875 or 342, -190)
            bar:SetSize(6, 325)
            if bar.SetOrientation then bar:SetOrientation("VERTICAL") end
            if bar.SetThumbTexture and bar.CreateTexture then
                local thumb = bar:CreateTexture(nil, "ARTWORK")
                thumb:SetColorTexture(colors.brass[1], colors.brass[2], colors.brass[3], 1)
                thumb:SetSize(6, 18)
                bar:SetThumbTexture(thumb)
            end
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
        panel.data = Button(panel, "Data", 430, -4, 55, function() self:OpenDataView("overview") end)
        panel.track = Button(panel, "Set Waypoint", 420, -110, 140, function() self:TrackVendor(panel.destination); Refresh() end)
        panel.previous = Button(panel, "Prev", 205, -385, 55, function() panel.detailPage = panel.detailPage - 1; Refresh() end)
        panel.next = Button(panel, "Next", 496, -385, 55, function() panel.detailPage = panel.detailPage + 1; Refresh() end)
        function panel:Layout()
            local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1024
            local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
            self.compact = width < 560 or height < 420
            local detail = self.selected ~= nil
            local inventory = self.tab == "vendors"
            local function Visible(frame, shown) if shown then frame:Show() else frame:Hide() end end
            local function Move(frame, x, y, w)
                if frame.ClearAllPoints then frame:ClearAllPoints() end
                frame:SetPoint("TOPLEFT", x, y)
                if w then frame:SetWidth(w) end
            end
            self:SetSize(570, 420)
            if self.SetScale then self:SetScale(math.max(0.1, math.min(1, (width - 12) / 570, (height - 12) / 420))) end
            Move(self.back, 485, -37, 75)
            Move(self.settingsButton, 497, -7, 42)
            Move(self.data, 439, -7, 53)
            self.settingsButton:SetText("Setup")
            Move(self.zone, 283, -71, 92)
            Move(self.faction, 378, -71, 100)
            Move(self.source, 480, -71, 80)
            Move(self.clearFilters, 220, -38, 84)
            Move(self.search, 12, -71, 237)
            Move(self.clearSearch, 248, -71)
            local left = self.compact and 12 or 197
            local paneWidth = 558 - left
            Move(self.detailsInset, left - 1, -109)
            self.detailsInset:SetSize(paneWidth + 7, 305)
            self.detailHeader:SetSize(paneWidth - 1, 44)
            self.resultsInset:SetSize(self.compact and 552 or 182, 305)
            Visible(self.resultsInset, not self.compact or not detail)
            Visible(self.detailsInset, not self.compact or detail)
            Visible(self.detailHeader, detail)
            if not detail and self.rows and #self.rows == 0 then
                Move(self.detailsInset, 8, -109)
                self.detailsInset:SetSize(556, 305)
                Visible(self.resultsInset, false)
                Move(self.heading, 126, -193, 320)
                Move(self.description, 126, -216, 320)
            else
                Move(self.heading, left + 49, -118, paneWidth - 57)
                Move(self.description, left + 49, -134, paneWidth - (inventory and 183 or 57))
            end
            if self.itemIcon then Move(self.itemIcon, left + 8, -116) end
            Move(self.track, 430, -130, 126)
            Move(self.detailSearch, left + (inventory and 6 or 208), -157, paneWidth - (inventory and 119 or 214))
            Move(self.continent, left + 2, -155)
            Move(self.sellerZone, left + 104, -155)
            self.continent:SetText(self.filters.continent or "Continent: All")
            self.sellerZone:SetText(self.filters.sellerZone or "Zone: All")
            Visible(self.continent, detail and not inventory)
            Visible(self.sellerZone, detail and not inventory)
            self.stock:SetText(({ available = "In stock", soldout = "Sold out", unknown = "Unknown" })[self.filters.stock] or "Show: All")
            Visible(self.stock, inventory and detail)
            Move(self.detailLabel, left, -160, 100)
            Move(self.detailCount, left + 76, -388, paneWidth - 150)
            Visible(self.track, inventory and detail)
            Visible(self.previous, inventory and detail)
            Visible(self.next, inventory and detail)
            for i, row in ipairs(self.list) do
                Move(row, 10, -135 - (i - 1) * 36, self.compact and 530 or 179)
                row:SetSize(self.compact and 530 or 179, 36)
                row.nameLabel:SetWidth(self.compact and 480 or 134)
                row.subtitle:SetWidth(self.compact and 480 or 134)
                if self.compact and detail then row:Hide() end
            end
            for i, row in ipairs(self.details) do
                local column = inventory and (i - 1) % 2 or 0
                local line = inventory and math.floor((i - 1) / 2) or i - 1
                local y = -188 - line * 48
                local slotWidth = inventory and math.floor(paneWidth / 2) - 5 or paneWidth - 8
                Move(row, left + column * (slotWidth + 5), y, slotWidth)
                row:SetSize(slotWidth, 46)
                local textLeft = inventory and 42 or 7
                local textWidth = inventory and slotWidth - 48 or slotWidth - 150
                Move(row.caption, textLeft, inventory and -4 or -5, textWidth)
                Move(row.location, textLeft, inventory and -31 or -18, textWidth)
                Move(row.offer, textLeft, inventory and -17 or -31, slotWidth - textLeft - 6)
                Move(row.track, 416, y - 7, 67)
                Move(row.info, 487, y - 7, 59)
            end
            Move(self.resultsScroll, self.compact and 550 or 182, -135)
            self.resultsScroll:SetSize(6, 250)
            Visible(self.resultsScroll, self.rows and #self.rows > 7 and (not self.compact or not detail))
            Visible(self.count, self.rows and #self.rows > 0 and (not self.compact or not detail))
            Move(self.detailsScroll, 556, -188)
            self.detailsScroll:SetSize(6, 190)
            Visible(self.detailsScroll, detail and not inventory and (self.detailMax or 1) > 1)
            Move(self.expandedSummary, left + 7, -386, paneWidth - 14)
            Visible(self.heading, detail or not self.compact or not self.rows or #self.rows == 0)
            Visible(self.description, detail or not self.compact or not self.rows or #self.rows == 0)
            Visible(self.detailCount, detail and not self.expanded)
            self.detailLabel:Hide()
        end
        panel:SetScript("OnShow", function() panel:Layout(); self:RefreshBrowser(true) end)
        panel:SetScript("OnHide", function()
            if self.choiceMenu then self.choiceMenu:Hide() end
            if self.exportPanel then
                self.exportPanel.document = nil
                self.exportBox:SetText("")
                self.exportBox:ClearFocus()
                self.exportPanel:Hide()
            end
            panel.dataView = nil
        end)
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
