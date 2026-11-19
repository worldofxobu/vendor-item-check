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
                (not filters.discounted or vendor.accessObserved and vendor.discount and vendor.discount < 1 and vendor.copper) then
                vendor.inaccessible = not self:IsVendorFriendly(vendor.faction, self:GetPlayerFaction())
                if not filters.allFactions and vendor.inaccessible then
                    index.hidden = index.hidden or {}
                    index.hidden[id] = (index.hidden[id] or 0) + 1
                else
                local item = index.items[id]
                if not item then
                    item = { id = id, name = self:BrowserItemName(id), vendors = {}, price = info.price }
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
            if vendor.copper and vendor.accessObserved and vendor.discount and vendor.stock ~= 0 and not vendor.inaccessible then
                local context = vendor.discount
                local group = groups[context] or { count = 0 }
                groups[context] = group
                group.count = group.count + 1
                local best = group.best
                if not best or vendor.copper * best.quantity < best.copper * vendor.quantity then group.best = vendor end
            end
        end
        for _, vendor in ipairs(item.vendors) do
            local group = vendor.discount and groups[vendor.discount]
            local best = group and group.count > 1 and group.best
            vendor.cheapest = best and vendor.copper and vendor.accessObserved and vendor.stock ~= 0 and not vendor.inaccessible
                and vendor.copper * best.quantity == best.copper * vendor.quantity
        end
    end
    for _, row in pairs(index.vendors) do SortRows(row.items) end
    return index
end

local function MissingPrice(vendor)
    if vendor.offer and vendor.offer.priceContext == "unknown" then
        return "Reported price has unknown purchase quantity and pricing context"
    end
    if vendor.personal then
        return "No recorded coin price for this character"
    end
    return "Price not recorded"
end

function VIC:BrowserOfferText(vendor, price)
    local parts = { vendor.source == "personal" and "Personal" or "Bundled", vendor.zone or "Location unknown" }
    if vendor.x and vendor.x > 0 and vendor.y and vendor.y > 0 then
        parts[#parts + 1] = string.format("%s%.1f, %.1f", vendor.approximate and "~" or "", vendor.x, vendor.y)
    end
    local access = { A = "Alliance", H = "Horde", N = "Neutral", AH = "Both factions" }
    parts[#parts + 1] = vendor.accessObserved and "Observed access" or (access[vendor.faction] or "Access unverified")
    if vendor.quoteText then parts[#parts + 1] = vendor.quoteText .. " (observed quote)"
    elseif vendor.alternateCost then parts[#parts + 1] = "Alternate costs apply"
    elseif price ~= nil then parts[#parts + 1] = (self:FormatMoney(price) or "0c") .. " (Classic reference)"
    else parts[#parts + 1] = MissingPrice(vendor) end
    if vendor.observedAt then
        parts[#parts + 1] = "Observed " .. (date and date("%Y-%m-%d", vendor.observedAt) or tostring(vendor.observedAt))
        if vendor.stock then parts[#parts + 1] = vendor.stock == -1 and "Stock: unlimited when observed" or ("Stock observed: " .. vendor.stock) end
    end
    if vendor.quantity and vendor.quantity > 1 then parts[#parts + 1] = "Purchase stack: " .. vendor.quantity end
    return table.concat(parts, " | ")
end

local function OfferPrice(self, vendor, reference)
    return self:FormatOfferPrice(vendor.copper, vendor.quantity ~= 1 and vendor.quantity or nil, self.FormatCoinIcons)
        or (vendor.alternateCost and "Alternate cost")
        or self:FormatCoinIcons(reference)
        or "—"
end

local function StockText(stock)
    if stock == -1 then return "∞", "muted" end
    if stock == 0 then return "Sold out", "alert" end
    if type(stock) == "number" and stock > 0 then return stock .. " left", "gold" end
    return "?", "muted"
end

local function SellerLocation(vendor)
    local zone = vendor.zone or "Location unknown"
    if vendor.x and vendor.x > 0 and vendor.y and vendor.y > 0 then
        return string.format("%s · %s%.1f, %.1f", zone, vendor.approximate and "approx. " or "", vendor.x, vendor.y)
    end
    if vendor.locationExpired then return "Last known location expired" end
    return zone == "Location unknown" and "Location unavailable" or zone
end

local function RGB(red, green, blue)
    return { red / 255, green / 255, blue / 255 }
end

local colors = {
    background = RGB(17, 21, 25), pane = RGB(23, 27, 31), inset = RGB(14, 17, 21),
    header = RGB(34, 39, 43), plate = RGB(36, 39, 42), border = RGB(61, 60, 53),
    brass = RGB(136, 104, 59), selection = RGB(51, 43, 20), gold = RGB(255, 209, 0),
    cream = RGB(243, 236, 224), muted = RGB(168, 161, 149), teal = RGB(131, 200, 162),
    alert = RGB(255, 119, 97), action = RGB(80, 35, 22), black = RGB(0, 0, 0),
    tooltip = RGB(12, 16, 27),
}

local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local mediaFolder = getMetadata and getMetadata("VendorItemCheck", "X-VIC-Media-Folder")
local media = "Interface\\AddOns\\VendorItemCheck\\" .. (mediaFolder or "Media") .. "\\"
local fonts = { regular = "Inter-Regular", medium = "Inter-SemiBold", bold = "Inter-Bold", title = "Cinzel-Bold" }
local locale = GetLocale and GetLocale()
local nativeLocalizedFont = locale == "koKR" or locale == "zhCN" or locale == "zhTW"

function VIC:StyleBrowserText(region, size, weight, color)
    if region.SetFont and not nativeLocalizedFont then
        pcall(region.SetFont, region, media .. fonts[weight or "regular"] .. ".ttf", size)
    end
    if region.SetTextColor then region:SetTextColor(unpack(colors[color or "cream"])) end
    return region
end

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
    frame.outline = Fill(frame, colors[border or "border"], 0)
    frame.surface = Fill(frame, colors[background or "inset"], 1)
end

function VIC:PaintBrowserSurface(frame, background, border)
    if frame.surface then
        local color = colors[background]
        frame.surface:SetColorTexture(color[1], color[2], color[3], 1)
    end
    if frame.outline then
        local color = colors[border]
        frame.outline:SetColorTexture(color[1], color[2], color[3], 1)
    end
end

local function SetSelected(frame, selected, selectedBorder)
    VIC:PaintBrowserSurface(frame, selected and "selection" or "inset", selected and (selectedBorder or "gold") or "border")
end

function VIC:BrowserIcon(parent, asset, size, x, y)
    if not parent.CreateTexture then return end
    local icon = parent:CreateTexture(nil, "ARTWORK")
    if asset then icon:SetTexture(media .. asset .. ".tga") end
    icon:SetSize(size, size)
    icon:SetPoint("TOPLEFT", x, y)
    return icon
end

function VIC:BrowserIconAsset(icon, asset)
    if icon then icon:SetTexture(media .. asset .. ".tga") end
end

function VIC:CreateBrowserSurface(parent, x, y, width, height, background, border)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", x, y)
    panel:SetSize(width, height)
    if panel.SetFrameLevel and parent.GetFrameLevel then panel:SetFrameLevel(parent:GetFrameLevel()) end
    self:StyleBrowserSurface(panel, background, border)
    return panel
end

local function Label(parent, text, x, y, width, size, weight, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return VIC:StyleBrowserText(label, size or 10, weight, color)
end

local function SingleLine(label)
    if label.SetMaxLines then label:SetMaxLines(1) end
    if label.SetWordWrap then label:SetWordWrap(false) end
end

function VIC:CreateBrowserButton(parent, text, x, y, width, action, height, background, border)
    local button = CreateFrame("Button", nil, parent)
    self:StyleBrowserSurface(button, background, border)
    if button.SetNormalFontObject then
        button:SetNormalFontObject(GameFontHighlightSmall)
        button:SetHighlightFontObject(GameFontNormalSmall)
        button:SetDisabledFontObject(GameFontDisableSmall)
    end
    if button.SetHighlightTexture and button.CreateTexture then
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        if highlight.SetAllPoints and highlight.SetColorTexture then
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.65, 0.51, 0.21, 0.13)
            button:SetHighlightTexture(highlight, "ADD")
        end
    end
    button:SetSize(width, height or 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    if button.GetFontString and button:GetFontString() then
        self:StyleBrowserText(button:GetFontString(), 10, "medium")
        SingleLine(button:GetFontString())
    end
    button:SetScript("OnClick", action)
    return button
end

local function Button(...)
    return VIC:CreateBrowserButton(...)
end

local function Search(parent, x, y, width, action, height)
    local box = CreateFrame("EditBox", nil, parent)
    VIC:StyleBrowserSurface(box, "inset", "brass")
    if box.SetTextInsets then box:SetTextInsets(25, 23, 0, 0) end
    box:SetFontObject(GameFontHighlightSmall)
    VIC:StyleBrowserText(box, 10)
    box.searchIcon = VIC:BrowserIcon(box, "Search", 12, 8, height and -10 or -7)
    box.placeholder = Label(box, "", 25, height and -11 or -7, width - 46, 10, "regular", "muted")
    box:SetSize(width, height or 27)
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

local function Show(widget, shown)
    if shown then widget:Show() else widget:Hide() end
end

local function Move(widget, x, y, width)
    if widget.ClearAllPoints then widget:ClearAllPoints() end
    widget:SetPoint("TOPLEFT", x, -y)
    if width then widget:SetWidth(width) end
end

local function Hover(owner, title, body)
    if not GameTooltip or not GameTooltip.SetText then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if body then GameTooltip:AddLine(body, 0.9, 0.88, 0.8, true) end
    GameTooltip:Show()
end

local function EndHover(owner)
    if GameTooltip and (not GameTooltip.IsOwned or GameTooltip:IsOwned(owner)) then GameTooltip:Hide() end
end

local function ItemArt(icon, border, id, unnamed)
    if not icon then return end
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    local ok, _, _, quality, _, _, _, _, _, _, texture
    if info and not unnamed then ok, _, _, quality, _, _, _, _, _, _, texture = pcall(info, id) end
    if not texture and not unnamed then
        local getIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon
        if getIcon then local success, asset = pcall(getIcon, id); if success then texture = asset end end
    end
    if unnamed and icon.SetColorTexture then icon:SetColorTexture(0.067, 0.082, 0.098, 1)
    else icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark") end
    local qualityColor = ok and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if border then
        local color = qualityColor or { r = colors.brass[1], g = colors.brass[2], b = colors.brass[3] }
        border:SetColorTexture(color.r, color.g, color.b, 1)
    end
    icon:Show()
    if border then border:Show() end
    return qualityColor and quality ~= 1 and qualityColor.hex
end

local function SetWaypointButton(self, button, vendor)
    local owned = self:OwnsVendorWaypoint(vendor)
    local available = self:CanMapVendor(vendor)
    button:SetText(owned and "Remove Waypoint" or "Set Waypoint")
    button:SetWidth(owned and 120 or button.waypointWidth)
    button:SetEnabled(owned or available)
    self:PaintBrowserSurface(button, owned and "selection" or available and "action" or "plate", available and "black" or "border")
    if button.GetFontString then
        self:StyleBrowserText(button:GetFontString(), button.waypointWidth == 91 and 8 or 9, "bold",
            (owned or available) and "gold" or "muted")
    end
    button.tooltipText = owned and "Remove the waypoint set by Vendor Item Check."
        or available and "Set a waypoint at the recorded vendor location."
        or vendor and vendor.locationExpired and "Location expired — waypoint unavailable."
        or "No usable location or waypoint support on this map."
    return owned, available
end

local function SellerHeight(row, expandedID, minimal)
    if row.id == expandedID then return 75 end
    if not minimal and row.vendor.cheapest then return 46 end
    return minimal and 44 or 38
end

function VIC:RefreshBrowser(rebuild)
    local panel = self.browserPanel
    if not panel or not panel:IsVisible() or panel.restoring then return end
    panel:UpdateScale()
    if panel.dataView then if self.RefreshDataView then self:RefreshDataView() end; return end
    local inventory = panel.tab == "vendors"
    local otherTab = inventory and "items" or "vendors"
    if rebuild or not panel.index then
        local filters = panel.filters
        local otherFilters = (panel.tabStates[otherTab] or {}).filters or {}
        panel.index = self:BuildBrowserIndex(filters)
        local sameIndex = filters.zone == otherFilters.zone and filters.source == otherFilters.source
            and filters.discounted == otherFilters.discounted and filters.allFactions == otherFilters.allFactions
        panel.otherIndex = sameIndex and panel.index or self:BuildBrowserIndex(otherFilters)
    end
    local query = panel.search:GetText()
    local rows, selected = {}, nil
    for _, row in pairs(panel.index[panel.tab]) do
        if Matches(row.name, query) or Matches(tostring(row.id), query) then
            rows[#rows + 1] = row
            if panel.selected == row.id then selected = row end
        end
    end
    SortRows(rows)
    panel.rows = rows
    if not selected and not panel.compact then selected = rows[1] end
    if panel.selected ~= (selected and selected.id) then
        panel.selected = selected and selected.id
        panel.expanded, panel.detailPage, panel.expandFirst = nil, 1, true
        panel.restoring = true
        panel.detailSearch:SetText("")
        panel.restoring = nil
    end
    local unnamed = selected and not inventory and not (self.browserNames and self.browserNames[selected.id])
    local numericMatch = not inventory and #rows == 1 and query == tostring(rows[1].id)
    local countLabel = #rows .. " " .. (#rows == 1 and (inventory and "vendor" or "item") or panel.tab)
    panel.count:SetText(countLabel .. (numericMatch and " · ID match" or ""))
    if panel.revealSelection and selected then
        for i, row in ipairs(rows) do
            if row.id == selected.id then
                if i < panel.page or i >= panel.page + #panel.list then panel.page = i end
                break
            end
        end
    end
    panel.revealSelection = nil
    panel.page = math.max(1, math.min(panel.page, math.max(1, #rows - #panel.list + 1)))

    UpdateSearchHint(panel.search, inventory and "Search vendor name or NPC ID" or "Search item name or ID")
    Show(panel.clearSearch, query ~= "")
    local showResults = #rows > 0 and (not panel.compact or not selected)
    local listWidth = panel.compact and 558 or 182
    panel.resultsInset:SetWidth(listWidth)
    panel.resultsHeader:SetWidth(listWidth - 4)
    Move(panel.sortLabel, listWidth - 43, 6)
    Move(panel.sortArrow, listWidth - 15, 9)
    Show(panel.resultsInset, showResults)
    for i, button in ipairs(panel.list) do
        local row = rows[panel.page + i - 1]
        button.row = row
        if row then
            button:SetWidth(listWidth - 4)
            button.nameLabel:SetWidth(listWidth - 48)
            button.subtitle:SetWidth(listWidth - 48)
            local checked = panel.selected == row.id
            SetSelected(button, checked)
            local quality
            local unknown = not inventory and not (self.browserNames and self.browserNames[row.id])
            if inventory then
                self:BrowserIconAsset(button.icon, "Shop")
                if button.icon then
                    button.icon:SetSize(15, 15)
                    Move(button.icon, 13, 10)
                end
            else
                if button.icon then
                    button.icon:SetSize(25, 25)
                    Move(button.icon, 8, 5)
                end
                quality = ItemArt(button.icon, button.iconBorder, row.id, unknown)
            end
            if button.iconBorder then Show(button.iconBorder, not inventory) end
            if button.vendorRing then
                local color = colors[checked and "gold" or "brass"]
                if button.vendorRing.SetVertexColor then button.vendorRing:SetVertexColor(unpack(color)) end
                Show(button.vendorRing, inventory)
            end
            Show(button.question, unknown)
            local color = checked and "|cffffd100" or quality or (not inventory and row.name == "Item #" .. row.id and "|cffa8a195")
            button.nameLabel:SetText(color and color .. row.name .. "|r" or row.name)
            local subtitle = inventory and (row.vendor.locationExpired and "Location unverified"
                or (row.vendor.zone or "Location unverified") .. " · " .. #row.items .. " items")
                or (unknown and ("Unnamed · %d %s"):format(#row.vendors, #row.vendors == 1 and "seller" or "sellers")
                    or "Known sellers · " .. #row.vendors)
            button.subtitle:SetText(subtitle)
        end
        Show(button, row and showResults)
    end

    local right = panel.compact and 8 or 196
    local width = 566 - right
    Move(panel.detailsInset, right, 109)
    panel.detailsInset:SetSize(width, 306)
    Show(panel.detailsInset, selected ~= nil)
    Show(panel.heading, selected ~= nil)
    Show(panel.description, selected ~= nil)
    Show(panel.empty, #rows == 0)
    Show(panel.allZones, false)
    if #rows == 0 then
        local title = query ~= "" and string.format("No %s match “%s”", panel.tab, query) or "No known " .. panel.tab
        local description = query ~= "" and "No matches for the current search and filters."
            or (self.client == "forever" and "Visit NPC merchants with learning enabled to collect offers." or "No records match the selected filters.")
        if panel.filters.zone then
            local alternative = self:BuildBrowserIndex(panel.filters, true)[panel.tab]
            local count = 0
            for id, row in pairs(alternative) do
                if Matches(row.name, query) or Matches(tostring(id), query) then count = count + 1 end
            end
            if count > 0 then
                description = ("No matches in the selected zone. %d %s in other zones."):format(
                    count, count == 1 and "match" or "matches")
                panel.allZones:SetText("Show all zones (" .. count .. ")")
                panel.allZones:Show()
            end
        end
        panel.emptyTitle:SetText(title)
        panel.emptyDescription:SetText(description)
        panel.emptyTip:SetText(inventory and "You can also search by NPC ID." or "You can also search by item ID.")
        Show(panel.emptyClear, query ~= "")
        Move(panel.emptyClear, panel.allZones:IsVisible() and 297 or 239, 180)
    end

    local filtered, hidden = {}, 0
    panel.destination = inventory and selected and selected.vendor or nil
    local rowSearch = panel.detailSearch:GetText()
    local owned, waypointAvailable = false, false
    local expiredLocation = panel.destination and panel.destination.locationExpired
    if selected then
        local title = selected.name
        local quality
        if inventory then
            if panel.itemIcon then
                self:BrowserIconAsset(panel.itemIcon, "Shop")
                local guid = UnitGUID and UnitGUID("npc")
                local npc = type(guid) == "string" and (not issecretvalue or not issecretvalue(guid))
                    and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
                local hasPortrait = selected.id == npc and SetPortraitTexture and pcall(SetPortraitTexture, panel.itemIcon, "npc")
                panel.itemIcon:SetSize(hasPortrait and 37 or 18, hasPortrait and 37 or 18)
                Move(panel.itemIcon, hasPortrait and 7 or 16, hasPortrait and 5 or 14)
                Show(panel.itemIcon, not expiredLocation)
            end
        else
            if panel.itemIcon then panel.itemIcon:SetSize(37, 37); Move(panel.itemIcon, 7, 5) end
            quality = ItemArt(panel.itemIcon, panel.itemIconBorder, selected.id, unnamed)
        end
        if panel.itemIconBorder then Show(panel.itemIconBorder, not inventory) end
        if panel.portraitRing then Show(panel.portraitRing, inventory and not expiredLocation) end
        Show(panel.itemQuestion, unnamed)
        self:StyleBrowserText(panel.heading, inventory and 13 or 14, "bold", inventory and "gold" or "cream")
        panel.heading:SetText(quality and quality .. title .. "|r" or title)
        panel.description:SetText(inventory and (selected.vendor.locationExpired and "Last known location expired"
            or SellerLocation(selected.vendor))
            or unnamed and "Name not available yet" or ("Item information · " .. #selected.vendors .. " known sellers"))
        if inventory then
            owned, waypointAvailable = SetWaypointButton(self, panel.track, panel.destination)
            for _, row in ipairs(selected.items) do
                local stock = row.vendor.stock
                local mode = panel.filters.stock
                if (Matches(row.name, rowSearch) or Matches(tostring(row.id), rowSearch))
                    and (not mode or mode == "available" and (stock == -1 or type(stock) == "number" and stock > 0)
                    or mode == "soldout" and stock == 0 or mode == "unknown" and stock == nil) then
                    filtered[#filtered + 1] = row
                end
            end
            UpdateSearchHint(panel.detailSearch, "Search " .. #selected.items .. " items")
        else
            if self.settings.showClosestFirst then
                local zone, x, y = self:GetPlayerLocation()
                self:SortVendorsByProximity(selected.vendors, zone, x, y)
            end
            for _, vendor in ipairs(selected.vendors) do
                if (Matches(vendor.name, rowSearch) or Matches(tostring(vendor.id), rowSearch))
                    and (not panel.filters.sellerZone or vendor.zone == panel.filters.sellerZone)
                    and (not panel.filters.continent or VendorContinent(vendor) == panel.filters.continent) then
                    filtered[#filtered + 1] = { id = vendor.id, name = vendor.name, vendor = vendor, price = selected.price }
                end
            end
            if not self.settings.showClosestFirst then SortRows(filtered) end
            if panel.expandFirst then panel.expanded = not unnamed and filtered[1] and filtered[1].id end
            panel.expandFirst = nil
            UpdateSearchHint(panel.detailSearch, "Search sellers")
            hidden = panel.index.hidden and panel.index.hidden[selected.id] or 0
        end
    end

    local banner = inventory and selected and (owned or not waypointAvailable)
    local pageSize = banner and 6 or 8
    local top = inventory and (banner and 110 or 84) or (unnamed and 144 or 108)
    local bottom = hidden > 0 and 274 or 301
    local maxDetail = inventory and math.max(1, math.ceil(#filtered / pageSize)) or 1
    if not inventory and #filtered > 0 then
        local span = 0
        for i = #filtered, 1, -1 do
            span = span + SellerHeight(filtered[i], panel.expanded, unnamed) + 3
            if span > bottom - top + 3 then maxDetail = i + 1; break end
        end
    end
    panel.detailMax = maxDetail
    if inventory and panel.revealLinkedItem then
        for i, row in ipairs(filtered) do
            if row.id == panel.linkedItem then panel.detailPage = math.ceil(i / pageSize); break end
        end
        panel.revealLinkedItem = nil
    end
    local opening = panel.openingSeller
    panel.openingSeller = nil
    if not inventory and opening and filtered[opening] then
        local occupied = 0
        for i = panel.detailPage, opening do
            occupied = occupied + SellerHeight(filtered[i], panel.expanded, unnamed) + 3
        end
        while panel.detailPage < opening and occupied > bottom - top + 3 do
            occupied = occupied - SellerHeight(filtered[panel.detailPage], panel.expanded, unnamed) - 3
            panel.detailPage = panel.detailPage + 1
        end
    end
    panel.detailPage = math.max(1, math.min(panel.detailPage, maxDetail))
    local offset = (panel.detailPage - 1) * (inventory and pageSize or 1)
    panel.detailHeader:SetWidth(width - 12)
    local headerTextWidth = width - (inventory and (expiredLocation and 123 or owned and 198 or 175) or 63)
    Move(panel.heading, expiredLocation and 4 or 54, 8, headerTextWidth)
    Move(panel.description, expiredLocation and 4 or 54, 27, headerTextWidth)
    self:StyleBrowserText(panel.description, 10, "regular", expiredLocation and "alert" or "muted")
    panel.detailCount = inventory and panel.pageCount or panel.sellerCount
    panel.detailCount:SetText(inventory and ("Page " .. panel.detailPage .. " of " .. maxDetail) or ("SELLERS  " .. #filtered))
    Move(panel.pageCount, (width - 132) / 2, 8)
    Move(panel.sellerCount, 12, unnamed and 126 or 89)
    Show(panel.sellerCount, selected and not inventory)
    Move(panel.priceHeading, width - 87, 89)
    Move(panel.stockHeading, width - 44, 89)
    Show(panel.priceHeading, selected and not inventory and not unnamed)
    Show(panel.stockHeading, selected and not inventory and not unnamed)
    Show(panel.unnamed, unnamed)
    panel.unnamed:SetWidth(width - 12)
    panel.unnamedBody:SetWidth(width - 30)
    Show(panel.detailSearch, selected and not unnamed)
    Move(panel.detailSearch, inventory and 6 or 237, inventory and (banner and 79 or 53) or 54,
        inventory and width - 133 or width - 243)
    panel.detailSearch.placeholder:SetWidth(inventory and width - 179 or width - 289)
    Show(panel.detailClear, selected and not unnamed and rowSearch ~= "")
    Move(panel.detailClear, inventory and width - 154 or width - 27, inventory and (banner and 80 or 54) or 55)
    Move(panel.track, width - (owned and 131 or expiredLocation and 93 or 108), 14)
    if expiredLocation and not owned then panel.track:SetWidth(83) end
    if panel.track.icon then Show(panel.track.icon, not expiredLocation or owned) end
    if panel.track.GetFontString and panel.track:GetFontString() then
        local action = panel.track:GetFontString()
        action:ClearAllPoints()
        local disabled = expiredLocation and not owned
        action:SetPoint("LEFT", disabled and 4 or 21, 0)
        action:SetPoint("RIGHT", -3, 0)
        action:SetJustifyH(disabled and "CENTER" or "LEFT")
    end
    Show(panel.track, inventory and selected)
    Move(panel.stock, width - 120, banner and 79 or 53)
    Show(panel.stock, inventory and selected)
    Show(panel.continent, selected and not inventory and not unnamed)
    Show(panel.sellerZone, selected and not inventory and not unnamed)
    local filterLabels = { available = "In stock", soldout = "Sold out", unknown = "Unknown", }
    panel.stock:SetText("Show: " .. (filterLabels[panel.filters.stock] or "All"))
    panel.continent:SetText("Continent: " .. (panel.filters.continent or "All"))
    panel.sellerZone:SetText("Zone: " .. (panel.filters.sellerZone or "All"))
    Show(panel.waypointBanner, banner)
    panel.waypointBanner:SetWidth(width - 12)
    panel.waypointStatus:SetText(owned and "✓  Waypoint set" or panel.track.tooltipText or "")
    self:StyleBrowserText(panel.waypointStatus, 10, "medium", owned and "teal" or "alert")
    Show(panel.pager, inventory and selected)
    Move(panel.pager, 6, banner and 252 or 273)
    panel.pager:SetWidth(width - 12)
    Move(panel.next, width - 44, 2)
    Move(panel.nextLabel, width - 109, 8)
    panel.previous:SetEnabled(panel.detailPage > 1)
    panel.next:SetEnabled(panel.detailPage < maxDetail)
    Show(panel.disclosure, not inventory and selected and hidden > 0)
    panel.disclosure:SetWidth(width - 12)
    panel.hiddenCount:SetText(hidden .. (hidden == 1 and " other seller hidden by access" or " other sellers hidden by access"))
    Move(panel.reveal, width - 52, 1)

    local sellerListFull = false
    for i, button in ipairs(panel.details) do
        local row = filtered[offset + i]
        local expanded = row and not inventory and row.id == panel.expanded
        local height = inventory and 44 or row and SellerHeight(row, panel.expanded, unnamed) or 38
        if not inventory and top + height > bottom then sellerListFull = true end
        local isVisible = selected and (inventory and i <= pageSize or not inventory and row and not sellerListFull)
        if GameTooltip and GameTooltip.IsOwned and button.row
            and (not isVisible or not row or button.row.id ~= row.id) then EndHover(button) end
        button.row = isVisible and row or nil
        button.detailIndex = offset + i
        Show(button, isVisible)
        if isVisible then
            local slotWidth = inventory and math.floor((width - 20) / 2) or width - 12
            local column = inventory and (i - 1) % 2 or 0
            local y = inventory and top + math.floor((i - 1) / 2) * 47 or top
            Move(button, 6 + column * (slotWidth + 8), y)
            button:SetSize(slotWidth, height)
            if not inventory then top = top + height + 3 end
            SetSelected(button, expanded or inventory and row and panel.linkedItem == row.id, "brass")
            local quality
            if inventory and row then
                quality = ItemArt(button.icon, button.iconBorder, row.id, row.name == "Item #" .. row.id)
            end
            if button.icon then Show(button.icon, inventory and row) end
            if button.iconBorder then Show(button.iconBorder, inventory and row) end
            Show(button.slot, inventory)
            local price = row and OfferPrice(self, row.vendor, row.price) or ""
            local stock, stockColor = StockText(row and row.vendor.stock)
            local minimal = unnamed and price == "—" and (not row or row.vendor.stock == nil)
            button.caption:SetText(row and (quality and quality .. row.name .. "|r" or row.name) or "")
            button.location:SetText(row and not inventory and SellerLocation(row.vendor) or "")
            button.offer:SetText(price)
            button.stock:SetText(row and stock or "")
            self:StyleBrowserText(button.offer, 11, "bold", price == "—" and "muted" or "cream")
            self:StyleBrowserText(button.stock, 9, "medium", stockColor)
            button.iconCount:SetText(inventory and row and (row.vendor.stock and row.vendor.stock >= 0 and row.vendor.stock
                or row.vendor.quantity and row.vendor.quantity > 1 and row.vendor.quantity) or "")
            local textLeft = inventory and 44 or 6
            Move(button.caption, textLeft, inventory and 8 or 9, slotWidth - (inventory and 49 or minimal and 76 or 113))
            Move(button.location, textLeft, 26, slotWidth - (minimal and 76 or 90))
            Move(button.offer, inventory and textLeft or slotWidth - 139, inventory and 23 or 6, inventory and slotWidth - 49 or 95)
            if button.offer.SetJustifyH then button.offer:SetJustifyH(inventory and "LEFT" or "RIGHT") end
            local rendered = inventory and button.offer.GetUnboundedStringWidth and button.offer:GetUnboundedStringWidth() or 0
            local stockWidth = inventory and button.stock.GetUnboundedStringWidth and button.stock:GetUnboundedStringWidth() or 0
            local stockLeft = inventory and textLeft + rendered + 6 or slotWidth - 41
            local separateStock = inventory and stockLeft + stockWidth > slotWidth - 5
            if separateStock then stockLeft = textLeft end
            if inventory and not separateStock and rendered > 0 then button.offer:SetWidth(math.ceil(rendered) + 1) end
            Move(button.stock, stockLeft, inventory and (separateStock and 35 or 25) or 8, slotWidth - stockLeft - 5)
            if button.stock.SetJustifyH then button.stock:SetJustifyH(inventory and "LEFT" or "RIGHT") end
            Show(button.offer, row and not minimal)
            Show(button.stock, row and not minimal)
            Show(button.badge, row and not inventory and row.vendor.cheapest)
            Move(button.badge, slotWidth - 62, 22)
            Show(button.summary, expanded)
            if expanded then
                button.summary:SetText(row.vendor.observedAt and "Last recorded · " .. (row.vendor.stock == -1 and "unlimited stock"
                    or row.vendor.stock == 0 and "sold out" or row.vendor.stock and "limited stock" or "stock unknown") or "Bundled directory")
                button.summary:SetWidth(slotWidth - 196)
                local hasWaypoint = SetWaypointButton(self, button.track, row.vendor)
                button.linkOffset = hasWaypoint and 214 or 191
                button.trackOffset = hasWaypoint and 125 or 97
            end
            local showLink = not inventory and (expanded or minimal)
            Show(button.vendorLink, showLink)
            Show(button.track, expanded)
            Move(button.vendorLink, slotWidth - (expanded and button.linkOffset or 67), expanded and 45 or 8)
            Move(button.track, slotWidth - (button.trackOffset or 102), 45)
        end
    end

    panel.updating = true
    for _, pair in ipairs({ { panel.resultsScroll, #rows - #panel.list + 1, panel.page }, { panel.detailsScroll, maxDetail, panel.detailPage } }) do
        if pair[1].SetMinMaxValues then
            pair[1]:SetMinMaxValues(1, math.max(1, pair[2]))
            pair[1]:SetValue(pair[3])
        end
    end
    panel.updating = false
    Move(panel.detailsScroll, width - 6, unnamed and 144 or 108)
    Show(panel.detailsScroll, selected and not inventory and maxDetail > 1)
    Show(panel.resultsScroll, showResults and #rows > #panel.list)
    for name, tab in pairs({ items = panel.itemsTab, vendors = panel.vendorsTab }) do
        local active = panel.tab == name
        local count = 0
        local tabQuery = active and query or (panel.tabStates[name] or {}).search or ""
        local tabIndex = active and panel.index or panel.otherIndex
        for id, row in pairs(tabIndex[name]) do
            if Matches(row.name, tabQuery) or Matches(tostring(id), tabQuery) then count = count + 1 end
        end
        self:PaintBrowserSurface(tab, active and "selection" or "inset", "brass")
        self:BrowserIconAsset(tab.icon, (name == "items" and "Items" or "Vendors") .. (active and "Active" or ""))
        tab.count:SetText(tostring(count))
        self:StyleBrowserText(tab.caption, 11, "bold", active and "gold" or "cream")
        self:StyleBrowserText(tab.count, 9, "bold", active and "gold" or "muted")
    end
    local history = panel.history[#panel.history]
    panel.back:SetText(history and "Back: " .. history.label or "Back")
    local backWidth = history and math.min(168, math.max(114, 45 + #history.label * 5)) or 54
    Move(panel.back, 565 - backWidth, 42, backWidth)
    panel.back:SetEnabled(history ~= nil or (panel.compact and selected ~= nil))
    if panel.back.GetFontString then self:StyleBrowserText(panel.back:GetFontString(), 9, "bold") end
    local zone = panel.filters.zone
    panel.zone:SetText("Zone: " .. (zone == "@current" and "Current" or zone or "Any"))
    panel.faction:SetText(panel.filters.allFactions and "All access" or "Friendly +?")
    self:PaintBrowserSurface(panel.source, (panel.filters.source or panel.filters.discounted or panel.filters.allFactions) and "selection" or "plate", "border")
end

local function ButtonIcon(button, asset, size, x, y, hint)
    button.icon = VIC:BrowserIcon(button, asset, size, x, y)
    if hint then
        button:SetScript("OnEnter", function(owner) Hover(owner, hint) end)
        button:SetScript("OnLeave", EndHover)
    end
end

local function LeftButtonText(button, offset)
    local label = button.GetFontString and button:GetFontString()
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", offset, 0)
        label:SetPoint("RIGHT", -3, 0)
        label:SetJustifyH("LEFT")
    end
end

local function Dropdown(button, width)
    LeftButtonText(button, 8)
    Label(button, "▼", width - 13, -11, 8, 5, "medium", "gold")
    local label = button.GetFontString and button:GetFontString()
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", -15, 0)
        VIC:StyleBrowserText(label, 10)
    end
end

local function OpenPicker(panel, owner, title, x, y, width, choices, choose, searchable)
    if panel.advanced then panel.advanced:Hide() end
    local menu = panel.menu
    if menu and menu:IsVisible() and menu.owner == owner then menu:Hide(); return end
    if not menu then
        menu = VIC:CreateBrowserSurface(panel, 0, 0, width, 305, "background", "brass")
        panel.menu = menu
        if menu.SetFrameLevel and panel.GetFrameLevel then menu:SetFrameLevel(panel:GetFrameLevel() + 20) end
        if menu.SetClampedToScreen then menu:SetClampedToScreen(true) end
        menu:EnableMouse(true)
        menu.header = VIC:CreateBrowserSurface(menu, 8, -8, width - 16, 26, "header", "header")
        menu.title = Label(menu.header, "", 7, -7, width - 40, 10, "bold", "gold")
        menu.close = Button(menu, "×", width - 30, -10, 22, function() menu:Hide() end, 22, "header", "header")
        menu.search = Search(menu, 9, -36, width - 18, function() end, 33)
        menu.search:SetScript("OnEscapePressed", function() menu:Hide() end)
        menu.rows = {}
        for i = 1, 8 do
            local row = Button(menu, "", 9, 0, width - 18, function() end, 26)
            row.entryLabel = Label(row, "", 7, -7, width - 60)
            SingleLine(row.entryLabel)
            row.entryCount = Label(row, "", width - 60, -7, 33, 9, nil, "muted")
            row.entryCount:SetJustifyH("RIGHT")
            menu.rows[i] = row
        end
        menu.down = Button(menu, "↓  Scroll for more", 9, 0, width - 18, function() end, 20, "header", "header")
        LeftButtonText(menu.down, 7)
        menu:SetScript("OnHide", function() menu.search:ClearFocus() end)
    end
    menu.owner = owner
    Move(menu, x, y)
    menu:SetWidth(width)
    menu.header:SetWidth(width - 16)
    menu.title:SetWidth(width - 40)
    menu.title:SetText(title)
    Move(menu.close, width - 30, 10)
    menu.search:SetWidth(width - 18)
    menu.search.placeholder:SetWidth(width - 64)
    menu.search:SetScript("OnTextChanged", nil)
    menu.search:SetText("")
    UpdateSearchHint(menu.search, title == "FILTER BY ZONE" and "Type a zone name…" or "Type a name…")
    Show(menu.search, searchable)
    if menu.search.ClearFocus then menu.search:ClearFocus() end
    local available, offset = choices, 0
    local limit = title == "FILTER BY ZONE" and 8 or searchable and 7 or math.min(8, #choices)
    local startY = searchable and 70 or 36
    local function RefreshMenu()
        local currentY = startY
        for i, row in ipairs(menu.rows) do
            local entry = i <= limit and available[offset + i]
            Show(row, entry)
            if entry then
                Move(row, 9, currentY, width - 18)
                local rowHeight = entry.header and 20 or 26
                row:SetHeight(rowHeight)
                currentY = currentY + rowHeight
                row:SetEnabled(not entry.header)
                VIC:PaintBrowserSurface(row, entry.header and "header" or entry.selected and "selection" or "inset",
                    entry.header and "header" or entry.selected and "selection" or "inset")
                row.entryLabel:SetText((entry.selected and "✓  " or "") .. entry.label)
                row.entryLabel:SetWidth(width - 41 - (entry.count and 26 or 0))
                VIC:StyleBrowserText(row.entryLabel, entry.header and 9 or 11, entry.header and "bold" or entry.selected and "medium" or "regular",
                    (entry.header or entry.selected) and "gold" or "cream")
                Move(row.entryCount, width - 61, 7)
                row.entryCount:SetText(entry.count or "")
                row:SetScript("OnClick", function()
                    if entry.header then return end
                    menu:Hide()
                    choose(entry.value)
                end)
            end
        end
        local canScroll = #available > limit
        Show(menu.down, canScroll)
        Move(menu.down, 9, currentY + 3, width - 18)
        menu.down:SetText(offset + limit < #available and "↓  Scroll for more" or "↑  Scroll up")
        menu:SetHeight(title == "FILTER BY ZONE" and math.max(87, currentY + (canScroll and 31 or 9))
            or math.max(64, currentY + (canScroll and 31 or 9)))
    end
    local function Scroll(delta)
        offset = math.max(0, math.min(math.max(0, #available - limit), offset + delta))
        RefreshMenu()
    end
    if menu.EnableMouseWheel then
        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", function(_, delta) Scroll(-delta) end)
    end
    menu.down:SetScript("OnClick", function() Scroll(offset + limit < #available and limit or -limit) end)
    if searchable then
        menu.search:SetScript("OnTextChanged", function(box)
            local query = box:GetText()
            available, offset = {}, 0
            for _, entry in ipairs(choices) do
                if query == "" or not entry.header and Matches(entry.label, query) then available[#available + 1] = entry end
            end
            UpdateSearchHint(box, title == "FILTER BY ZONE" and "Type a zone name…" or "Type a name…")
            RefreshMenu()
        end)
    end
    RefreshMenu()
    menu:Show()
end

local function ZoneChoices(self, panel)
    local options = {}
    local index = self:BuildBrowserIndex(panel.filters, true)
    local count = 0
    local query = panel.search:GetText()
    for id, row in pairs(index[panel.tab]) do
        if Matches(row.name, query) or Matches(tostring(id), query) then
            count = count + 1
            local visited = {}
            for _, vendor in ipairs(row.vendors or { row.vendor }) do
                local zone = vendor.zone
                if zone and zone ~= "Location unknown" and not visited[zone] then
                    visited[zone] = true
                    local choice = options[zone] or { label = zone, value = zone, count = 0 }
                    choice.count = choice.count + 1
                    choice.continent = choice.continent or VendorContinent(vendor)
                    choice.selected = panel.filters.zone == zone
                    options[zone] = choice
                end
            end
        end
    end
    local current = options[self:GetPlayerLocation()]
    local choices = {
        { label = "Current zone", value = "@current", count = current and current.count or 0, selected = panel.filters.zone == "@current" },
        { label = "Any zone", count = count, selected = panel.filters.zone == nil },
    }
    local sorted = {}
    for _, choice in pairs(options) do
        choice.continent = choice.continent or "Other zones"
        sorted[#sorted + 1] = choice
    end
    table.sort(sorted, function(a, b)
        if a.continent ~= b.continent then return a.continent < b.continent end
        return a.label < b.label
    end)
    local previous
    for _, choice in ipairs(sorted) do
        if previous ~= choice.continent then
            previous = choice.continent
            choices[#choices + 1] = { header = true, label = string.upper(previous) }
        end
        choices[#choices + 1] = choice
    end
    return choices
end

function VIC:OpenBrowser(keepData)
    if not self.browserPanel then
        local panel = CreateFrame("Frame", "VendorItemCheckBrowser", UIParent)
        self.browserPanel = panel
        panel:SetSize(570, 420)
        panel:SetPoint("CENTER")
        if panel.SetFrameStrata then panel:SetFrameStrata("DIALOG") end
        if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
        panel:SetMovable(true)
        panel:EnableMouse(true)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "VendorItemCheckBrowser" end
        self:StyleBrowserSurface(panel, "background", "brass")
        panel.titleBar = self:CreateBrowserSurface(panel, 1, -1, 568, 37, "header", "brass")
        panel.titleBar:EnableMouse(true)
        panel.titleBar:RegisterForDrag("LeftButton")
        panel.titleBar:SetScript("OnDragStart", function() panel:StartMoving() end)
        panel.titleBar:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
        Label(panel.titleBar, "Vendor Item Check", 38, -9, 365, 15, "title", "gold")
        local insignia = self:CreateBrowserSurface(panel.titleBar, 9, -7, 22, 22, "selection", "brass")
        self:BrowserIcon(insignia, "Insignia", 14, 4, -4)
        panel.data = Button(panel.titleBar, "Data", 454, -7, 53, function() self:OpenDataView("overview") end, 22, "inset", "brass")
        ButtonIcon(panel.data, "Data", 12, 7, -5)
        LeftButtonText(panel.data, 22)
        if panel.data.GetFontString then self:StyleBrowserText(panel.data:GetFontString(), 10, "medium", "gold") end
        panel.settingsButton = Button(panel.titleBar, "", 512, -7, 23, function() self:OpenOptions() end, 22, "header", "header")
        ButtonIcon(panel.settingsButton, "Settings", 14, 5, -4, "Settings")
        panel.close = Button(panel.titleBar, "", 541, -7, 22, function() panel:Hide() end, 22, "action", "black")
        ButtonIcon(panel.close, "Close", 12, 5, -5, "Close")

        local content = CreateFrame("Frame", nil, panel)
        content:SetPoint("TOPLEFT", 0, 0)
        content:SetSize(570, 420)
        panel.workspace = content
        panel.history, panel.tabStates = {}, {}
        panel.filters, panel.tab, panel.page, panel.detailPage = {}, "items", 1, 1

        function panel:UpdateScale()
            local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1024
            local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
            self.compact = width < 560 or height < 420
            if self.SetScale then self:SetScale(math.max(0.1, math.min(1, (width - 12) / 570, (height - 12) / 420))) end
        end

        local function ClosePickers()
            if panel.menu then panel.menu:Hide() end
            if panel.advanced then panel.advanced:Hide() end
        end

        local function Refresh() self:RefreshBrowser() end
        local function CopyFilters(source)
            local result = {}
            for key, value in pairs(source or {}) do result[key] = value end
            return result
        end
        local function SaveState()
            local row = panel.index and panel.index[panel.tab][panel.selected]
            return { tab = panel.tab, selected = panel.selected, page = panel.page, detailPage = panel.detailPage,
                search = panel.search:GetText(), detailSearch = panel.detailSearch:GetText(),
                filters = CopyFilters(panel.filters), expanded = panel.expanded, linkedItem = panel.linkedItem,
                label = row and row.name or (panel.tab == "items" and "Items" or "Vendors") }
        end
        local function Restore(state)
            ClosePickers()
            panel.restoring = true
            panel.tab, panel.selected = state.tab, state.selected
            panel.expanded, panel.expandFirst = state.expanded, state.expandFirst
            panel.linkedItem, panel.revealLinkedItem = state.linkedItem, state.revealLinkedItem
            panel.revealSelection = state.revealSelection
            panel.filters = CopyFilters(state.filters)
            panel.search:SetText(state.search or "")
            panel.detailSearch:SetText(state.detailSearch or "")
            panel.search:ClearFocus()
            panel.detailSearch:ClearFocus()
            panel.page, panel.detailPage = state.page or 1, state.detailPage or 1
            panel.restoring = nil
            self:RefreshBrowser(true)
        end
        local function ChangeTab(tab)
            if panel.tab == tab then return end
            panel.tabStates[panel.tab] = SaveState()
            Restore(panel.tabStates[tab] or { tab = tab, expandFirst = true })
        end
        local function Follow(id)
            local state = SaveState()
            panel.tabStates[panel.tab] = state
            panel.history[#panel.history + 1] = state
            if #panel.history > 50 then table.remove(panel.history, 1) end
            local target = panel.tab == "items" and "vendors" or "items"
            Restore({ tab = target, selected = id, expandFirst = true, revealSelection = true,
                linkedItem = target == "vendors" and panel.selected or nil, revealLinkedItem = target == "vendors",
                filters = { source = panel.filters.source, allFactions = panel.filters.allFactions } })
        end
        panel.back = Button(content, "Back", 511, -42, 54, function()
            local state = table.remove(panel.history)
            if state then Restore(state)
            else
                panel.selected, panel.expanded = nil, nil
                Refresh()
            end
        end, 24, "plate", "border")
        ButtonIcon(panel.back, "Back", 12, 8, -6)
        LeftButtonText(panel.back, 24)

        local function Tab(title, key, x, width, countX)
            local tab = Button(content, "", x, -40, width, function() ChangeTab(key) end, 27, "inset", "brass")
            ButtonIcon(tab, title, 13, 10, -7)
            tab.caption = Label(tab, title, 28, -7, 56, 11, "bold")
            SingleLine(tab.caption)
            tab.count = Label(tab, "", countX, -8, width - countX - 4, 9, "bold", "muted")
            SingleLine(tab.count)
            return tab
        end
        panel.itemsTab = Tab("Items", "items", 9, 97, 69)
        panel.vendorsTab = Tab("Vendors", "vendors", 109, 111, 83)
        panel.search = Search(content, 9, -73, 279, function()
            if panel.restoring then return end
            panel.page = 1
            Refresh()
        end)
        local function ClearSearch()
            panel.search:SetText("")
            panel.search:ClearFocus()
            panel.page = 1
            Refresh()
        end
        panel.clearSearch = Button(content, "×", 266, -75, 20, ClearSearch, 22, "inset", "inset")
        panel.zone = Button(content, "Zone: Any", 293, -73, 94, function()
            OpenPicker(panel, panel.zone, "FILTER BY ZONE", 293, 103, 238, ZoneChoices(self, panel), function(value)
                panel.filters.zone = value
                panel.page = 1
                self:RefreshBrowser(true)
            end, true)
        end, 27, "inset", "brass")
        Dropdown(panel.zone, 94)

        local function RefreshAdvanced()
            local menu = panel.advanced
            local source = panel.filters.source or "all"
            for _, choice in ipairs(menu.sources) do
                local selected = source == choice.value
                choice:SetText((selected and "●   " or "○   ") .. choice.label)
                self:PaintBrowserSurface(choice, selected and "selection" or "inset", selected and "selection" or "inset")
                if choice.GetFontString then self:StyleBrowserText(choice:GetFontString(), 11, "medium", selected and "gold" or "cream") end
            end
            menu.discount.mark:SetText(panel.filters.discounted and "✓" or "")
            menu.access.mark:SetText(panel.filters.allFactions and "✓" or "")
        end

        local function ResetFilters()
            panel.filters = {}
            panel.page, panel.detailPage = 1, 1
            self:RefreshBrowser(true)
            if panel.advanced then RefreshAdvanced() end
        end

        local function Advanced()
            if panel.menu then panel.menu:Hide() end
            local menu = panel.advanced
            if menu and menu:IsVisible() then menu:Hide(); return end
            if not menu then
                menu = self:CreateBrowserSurface(panel, 333, -103, 225, 280, "background", "brass")
                if menu.SetFrameLevel and panel.GetFrameLevel then menu:SetFrameLevel(panel:GetFrameLevel() + 20) end
                menu:EnableMouse(true)
                panel.advanced = menu
                local bar = self:CreateBrowserSurface(menu, 8, -8, 209, 26, "header", "header")
                Label(bar, "ADVANCED FILTERS", 6, -7, 175, 10, "bold", "gold")
                Button(bar, "×", 188, -2, 20, function() menu:Hide() end, 21, "header", "header")
                Label(menu, "DATA SOURCE", 8, -38, 180, 8, "bold", "muted")
                menu.sources = {}
                for i, source in ipairs({ { "All records", "all" }, { "Personal", "personal" }, { "Bundled", "bundled" } }) do
                    local row = Button(menu, source[1], 8, -53 - (i - 1) * 31, 209, function()
                        panel.filters.source = source[2] ~= "all" and source[2] or nil
                        panel.page = 1
                        self:RefreshBrowser(true)
                        RefreshAdvanced()
                    end, 27, "inset", "inset")
                    row.label, row.value = source[1], source[2]
                    LeftButtonText(row, 8)
                    menu.sources[i] = row
                end
                self:CreateBrowserSurface(menu, 8, -146, 209, 1, "brass", "brass")
                local function Toggle(filter, caption, y)
                    local row = Button(menu, caption, 8, -y, 209, function()
                        panel.filters[filter] = not panel.filters[filter] or nil
                        panel.page = 1
                        self:RefreshBrowser(true)
                        RefreshAdvanced()
                    end, 27, "inset", "inset")
                    LeftButtonText(row, 30)
                    local check = self:CreateBrowserSurface(row, 7, -5, 16, 16, "inset", "brass")
                    row.mark = Label(check, "", 3, -1, 13, 12, "bold", "gold")
                    return row
                end
                menu.discount = Toggle("discounted", "Discounted only", 153)
                menu.access = Toggle("allFactions", "Show inaccessible vendors", 187)
                Label(menu, "Default: friendly, neutral and unknown access.", 8, -221, 196, 10, "regular", "muted")
                panel.clearFilters = Button(menu, "Reset to default", 8, -247, 209, ResetFilters, 25, "header", "header")
                LeftButtonText(panel.clearFilters, 6)
                if panel.clearFilters.GetFontString then self:StyleBrowserText(panel.clearFilters:GetFontString(), 11, "bold", "gold") end
            end
            RefreshAdvanced()
            menu:Show()
        end
        panel.faction = Button(content, "Friendly +?", 392, -73, 105, Advanced, 27, "inset", "brass")
        ButtonIcon(panel.faction, "Access", 14, 7, -6)
        LeftButtonText(panel.faction, 24)
        panel.source = Button(content, "", 502, -75, 34, Advanced, 24, "plate", "border")
        ButtonIcon(panel.source, "Filters", 12, 10, -6, "Advanced filters")

        panel.resultsInset = self:CreateBrowserSurface(content, 8, -109, 182, 306, "inset", "brass")
        panel.resultsHeader = self:CreateBrowserSurface(panel.resultsInset, 2, -2, 178, 24, "header", "header")
        if panel.resultsHeader.SetFrameLevel and panel.resultsInset.GetFrameLevel then
            panel.resultsHeader:SetFrameLevel(panel.resultsInset:GetFrameLevel() + 1)
        end
        panel.count = Label(panel.resultsHeader, "", 7, -6, 137, 10, "bold")
        panel.sortLabel = Label(panel.resultsHeader, "Name", 141, -6, 31, 9, "regular", "muted")
        SingleLine(panel.sortLabel)
        panel.sortArrow = Label(panel.resultsHeader, "▼", 167, -9, 7, 5, "medium", "muted")
        panel.detailsInset = self:CreateBrowserSurface(content, 196, -109, 370, 306, "pane", "brass")
        local details = panel.detailsInset
        panel.detailHeader = self:CreateBrowserSurface(details, 6, -5, 358, 46, "header", "header")
        panel.itemIconBorder = self:BrowserIcon(panel.detailHeader, nil, 41, 5, -3)
        panel.portraitRing = self:BrowserIcon(panel.detailHeader, "PortraitRing", 41, 4, -1)
        if panel.portraitRing and panel.portraitRing.SetVertexColor then panel.portraitRing:SetVertexColor(unpack(colors.brass)) end
        panel.itemIcon = self:BrowserIcon(panel.detailHeader, nil, 37, 7, -5)
        panel.itemQuestion = Label(panel.detailHeader, "?", 7, -9, 37, 21, "bold", "muted")
        panel.itemQuestion:SetJustifyH("CENTER")
        panel.heading = Label(panel.detailHeader, "", 54, -8, 275, 14, "bold")
        panel.description = Label(panel.detailHeader, "", 54, -27, 273, 10, "regular", "muted")
        SingleLine(panel.heading)
        SingleLine(panel.description)
        panel.unnamed = self:CreateBrowserSurface(details, 6, -54, 358, 62, "inset", "brass")
        Label(panel.unnamed, "The game has not returned an item name.", 9, -9, 325, 11, "medium", "gold")
        panel.unnamedBody = Label(panel.unnamed, "The item remains searchable by ID. Its name will appear when available.",
            9, -28, 325, 10, "regular", "muted")
        panel.waypointBanner = self:CreateBrowserSurface(details, 6, -51, 358, 23, "inset", "brass")
        panel.waypointStatus = Label(panel.waypointBanner, "", 8, -5, 337, 10, "medium", "teal")

        local function WaypointButton(parent, click, width)
            local button = Button(parent, "Set Waypoint", 0, 0, width, click, 24, "action", "black")
            button.waypointWidth = width
            ButtonIcon(button, "Waypoint", 12, 6, -6)
            LeftButtonText(button, width == 91 and 19 or 21)
            button:SetScript("OnEnter", function(owner) Hover(owner, owner.tooltipText) end)
            button:SetScript("OnLeave", EndHover)
            return button
        end
        panel.track = WaypointButton(details, function()
            if panel.destination then self:TrackVendor(panel.destination); Refresh() end
        end, 97)
        panel.detailSearch = Search(details, 6, -53, 237, function()
            if panel.restoring then return end
            panel.detailPage = 1
            Refresh()
        end)
        panel.detailClear = Button(details, "×", 225, -54, 20, function()
            panel.detailSearch:SetText("")
            panel.detailSearch:ClearFocus()
        end, 24, "inset", "inset")
        panel.stock = Button(details, "Show: All", 250, -53, 114, function()
            local choices = {
                { label = "All stock", selected = not panel.filters.stock },
                { label = "In stock", value = "available" }, { label = "Sold out", value = "soldout" },
                { label = "Unknown stock", value = "unknown" },
            }
            for _, choice in ipairs(choices) do if choice.value then choice.selected = choice.value == panel.filters.stock end end
            OpenPicker(panel, panel.stock, "SHOW STOCK", 421, 190, 141, choices, function(value)
                panel.filters.stock, panel.detailPage = value, 1
                Refresh()
            end)
        end, 27, "inset", "brass")
        Dropdown(panel.stock, 114)

        local function SellerFilter(key, title, x, width, getValue)
            local button
            button = Button(details, title .. ": All", x, -54, width, function()
                local item = panel.index.items[panel.selected]
                local values, seen = {}, {}
                for _, vendor in ipairs(item and item.vendors or {}) do
                    local value = getValue(vendor)
                    if value and value ~= "Location unknown" and not seen[value] then
                        seen[value] = true
                        values[#values + 1] = value
                    end
                end
                table.sort(values)
                local choices = { { label = "All", selected = not panel.filters[key] } }
                for _, value in ipairs(values) do
                    choices[#choices + 1] = { label = value, value = value, selected = panel.filters[key] == value }
                end
                OpenPicker(panel, button, "FILTER BY " .. string.upper(title), (panel.compact and 8 or 196) + x, 192, 205,
                    choices, function(value)
                        panel.filters[key] = value
                        if key == "continent" then panel.filters.sellerZone = nil end
                        panel.detailPage = 1
                        Refresh()
                    end, true)
            end, 27, "inset", "brass")
            Dropdown(button, width)
            return button
        end
        panel.continent = SellerFilter("continent", "Continent", 6, 117, VendorContinent)
        panel.sellerZone = SellerFilter("sellerZone", "Zone", 128, 104, function(vendor)
            if not panel.filters.continent or VendorContinent(vendor) == panel.filters.continent then return vendor.zone end
        end)

        panel.empty = self:CreateBrowserSurface(content, 8, -109, 558, 306, "inset", "brass")
        local emptyIcon = self:CreateBrowserSurface(panel.empty, 259, -74, 40, 40, "background", "brass")
        self:BrowserIcon(emptyIcon, "Search", 18, 11, -11)
        panel.emptyTitle = Label(panel.empty, "", 24, -127, 510, 14, "medium", "gold")
        panel.emptyTitle:SetJustifyH("CENTER")
        SingleLine(panel.emptyTitle)
        panel.emptyDescription = Label(panel.empty, "", 29, -157, 500, 11, "regular", "muted")
        panel.emptyDescription:SetJustifyH("CENTER")
        panel.allZones = Button(panel.empty, "Show all zones", 182, -180, 107, function()
            panel.filters.zone = nil
            panel.page = 1
            self:RefreshBrowser(true)
        end, 28, "selection", "brass")
        if panel.allZones.GetFontString then self:StyleBrowserText(panel.allZones:GetFontString(), 10, "medium", "gold") end
        panel.emptyClear = Button(panel.empty, "Clear search", 297, -180, 80, ClearSearch, 28, "plate", "brass")
        panel.emptyTip = Label(panel.empty, "", 24, -222, 510, 10, "regular", "muted")
        panel.emptyTip:SetJustifyH("CENTER")

        panel.list, panel.details = {}, {}
        for i = 1, 7 do
            local row = Button(panel.resultsInset, "", 2, -26 - (i - 1) * 36, 178, function(button)
                if not button.row then return end
                ClosePickers()
                panel.selected, panel.expanded, panel.expandFirst = button.row.id, nil, true
                panel.linkedItem, panel.revealLinkedItem = nil, nil
                panel.filters.sellerZone, panel.filters.continent = nil, nil
                panel.detailPage = 1
                panel.detailSearch:SetText("")
                panel.search:ClearFocus()
                Refresh()
            end, 36, "inset", "border")
            row.iconBorder = self:BrowserIcon(row, nil, 27, 7, -4)
            row.vendorRing = self:BrowserIcon(row, "PortraitRing", 27, 7, -4)
            row.icon = self:BrowserIcon(row, nil, 25, 8, -5)
            row.question = Label(row, "?", 8, -7, 25, 16, "bold", "muted")
            row.question:SetJustifyH("CENTER")
            row.nameLabel = Label(row, "", 39, -5, 134, 11, "bold")
            row.subtitle = Label(row, "", 39, -20, 134, 9, "regular", "muted")
            SingleLine(row.nameLabel)
            SingleLine(row.subtitle)
            row:SetScript("OnEnter", function(button)
                if button.row then Hover(button, button.row.name, button.subtitle:GetText()) end
            end)
            row:SetScript("OnLeave", EndHover)
            panel.list[i] = row
        end
        for i = 1, 8 do
            local row = Button(details, "", 0, 0, 175, function(button)
                if not button.row then return end
                if panel.tab == "vendors" then Follow(button.row.id)
                else
                    panel.expanded = panel.expanded ~= button.row.id and button.row.id or nil
                    panel.openingSeller = panel.expanded and button.detailIndex or nil
                    Refresh()
                end
            end, 44, "inset", "border")
            row.slot = self:CreateBrowserSurface(row, 4, -4, 36, 36, "background", "border")
            row.iconBorder = self:BrowserIcon(row.slot, nil, 36, 0, 0)
            row.icon = self:BrowserIcon(row.slot, nil, 34, 1, -1)
            row.iconCount = Label(row.slot, "", 2, 0, 34, 11, "bold", "gold")
            row.caption = Label(row, "", 0, 0, 130, 11, "bold")
            row.location = Label(row, "", 0, 0, 175, 9, "regular", "muted")
            row.offer = Label(row, "", 0, 0, 110, 11, "bold")
            row.stock = Label(row, "", 0, 0, 56, 9, "medium")
            row.summary = Label(row, "", 6, -53, 150, 9, "regular", "muted")
            for _, label in ipairs({ row.caption, row.location, row.offer, row.stock, row.summary }) do SingleLine(label) end
            row.badge = self:CreateBrowserSurface(row, 0, 0, 55, 17, "inset", "gold")
            Label(row.badge, "CHEAPEST", 5, -3, 49, 8, "bold", "gold")
            row.vendorLink = Button(row, "Vendor ›", 0, 0, 60, function() if row.row then Follow(row.row.id) end end, 24, "plate", "border")
            row.track = WaypointButton(row, function()
                if row.row then self:TrackVendor(row.row.vendor); Refresh() end
            end, 91)
            row:SetScript("OnEnter", function(button)
                if not button.row then return end
                if panel.tab == "vendors" and GameTooltip then
                    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. button.row.id)
                    local vendor = button.row.vendor
                    if vendor.quantity and vendor.quantity > 1 then
                        GameTooltip:AddLine("Purchase stack: " .. vendor.quantity, 0.67, 0.64, 0.59)
                    end
                    GameTooltip:Show()
                else
                    Hover(button, button.row.name, self:BrowserOfferText(button.row.vendor, button.row.price))
                end
            end)
            row:SetScript("OnLeave", EndHover)
            panel.details[i] = row
        end
        panel.priceHeading = Label(details, "PRICE", 0, 0, 40, 9, "regular", "muted")
        panel.stockHeading = Label(details, "STOCK", 0, 0, 36, 9, "regular", "muted")
        panel.disclosure = self:CreateBrowserSurface(details, 6, -275, 358, 22, "background", "background")
        panel.hiddenCount = Label(panel.disclosure, "", 5, -5, 270, 9, "regular", "muted")
        panel.reveal = Button(panel.disclosure, "Show", 0, 0, 39, function()
            panel.filters.allFactions = true
            self:RefreshBrowser(true)
        end, 20, "background", "background")
        if panel.reveal.GetFontString then self:StyleBrowserText(panel.reveal:GetFontString(), 10, "bold", "gold") end

        panel.pager = self:CreateBrowserSurface(details, 6, -273, 358, 29, "inset", "brass")
        if panel.pager.SetFrameLevel and details.GetFrameLevel then
            panel.pager:SetFrameLevel(details:GetFrameLevel() + 1)
        end
        panel.sellerCount = Label(details, "", 12, -89, 120, 10, "title", "gold")
        panel.pageCount = Label(panel.pager, "", 0, -8, 120, 10, "title", "gold")
        panel.pageCount:SetJustifyH("CENTER")
        function panel:PageDetail(delta)
            self.detailPage = self.detailPage + delta
            Refresh()
        end
        panel.previous = Button(panel.pager, "◀", 6, -2, 26, function() panel:PageDetail(-1) end, 25, "selection", "brass")
        Label(panel.pager, "Prev", 79, -8, 35, 10, "regular", "gold")
        panel.next = Button(panel.pager, "▶", 326, -2, 26, function() panel:PageDetail(1) end, 25, "plate", "border")
        panel.nextLabel = Label(panel.pager, "Next", 251, -8, 44, 10, "regular", "muted")

        local function Wheel(frame, detail)
            if not frame.EnableMouseWheel then return end
            frame:EnableMouseWheel(true)
            frame:SetScript("OnMouseWheel", function(_, delta)
                if detail then panel:PageDetail(-delta)
                else panel.page = panel.page - delta; Refresh() end
            end)
        end
        Wheel(panel.resultsInset, false)
        Wheel(details, true)
        for _, row in ipairs(panel.list) do Wheel(row, false) end
        for _, row in ipairs(panel.details) do Wheel(row, true) end
        local function Scrollbar(parent, height, detail)
            local bar = CreateFrame("Slider", nil, parent)
            bar:SetPoint("TOPRIGHT", -1, -26)
            bar:SetSize(5, height)
            if bar.SetOrientation then bar:SetOrientation("VERTICAL") end
            if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
            if bar.SetValueStep then bar:SetValueStep(1) end
            if bar.SetMinMaxValues then bar:SetMinMaxValues(1, 1) end
            if bar.SetThumbTexture and bar.CreateTexture then
                local thumb = bar:CreateTexture(nil, "ARTWORK")
                thumb:SetColorTexture(unpack(colors.brass))
                thumb:SetSize(4, 20)
                bar:SetThumbTexture(thumb)
            end
            bar:SetScript("OnValueChanged", function(_, value)
                if panel.updating then return end
                local page = math.floor(value + 0.5)
                if detail then panel.detailPage = page else panel.page = page end
                Refresh()
            end)
            return bar
        end
        panel.resultsScroll = Scrollbar(panel.resultsInset, 251, false)
        panel.detailsScroll = Scrollbar(details, 180, true)

        panel:SetScript("OnShow", function() self:RefreshBrowser(true) end)
        panel:SetScript("OnHide", function()
            ClosePickers()
            if self.choiceMenu then self.choiceMenu:Hide() end
            if self.exportPanel then
                self.exportPanel.document = nil
                self.exportBox:SetText("")
                self.exportBox:ClearFocus()
                self.exportPanel:Hide()
            end
            panel.dataView = nil
            panel.workspace:Show()
        end)
        panel:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        panel:RegisterEvent("DISPLAY_SIZE_CHANGED")
        pcall(panel.RegisterEvent, panel, "USER_WAYPOINT_UPDATED")
        panel:SetScript("OnEvent", function(_, event, id, success)
            if event == "DISPLAY_SIZE_CHANGED" or event == "USER_WAYPOINT_UPDATED" then Refresh()
            elseif success and panel.requested then panel.requested[id] = nil end
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
            local count, changed = 0, false
            panel.requested = panel.requested or {}
            for id in pairs(panel.index and panel.index.items or {}) do
                if not panel.requested[id] then
                    local api = C_Item and C_Item.GetItemInfo or GetItemInfo
                    local ok, name = false, nil
                    if api then ok, name = pcall(api, id) end
                    if ok and type(name) == "string" and self:BrowserItemName(id) ~= name then
                        self.browserNames[id] = name
                        changed = true
                    end
                    panel.requested[id] = true
                    count = count + 1
                    if count >= 20 then break end
                end
            end
            if changed then self:RefreshBrowser(true) end
        end)
    end
    if self.browserPanel.dataView and not keepData then
        self.browserPanel.dataView = nil
        self.exportPanel:Hide()
        self.exportBox:ClearFocus()
        self.browserPanel.workspace:Show()
    end
    self.browserPanel:Show()
    self:RefreshBrowser(true)
end
