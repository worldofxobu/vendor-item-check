local _, VIC = ...

local MAX_AGE = 30 * 24 * 60 * 60

local function Call(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(api, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

local function Number(value, minimum)
    return type(value) == "number" and value == value and value < math.huge and value >= minimum
end

local function Integer(value, minimum)
    return Number(value, minimum) and value % 1 == 0
end

function VIC:ObservationNow()
    local now = Call(GetServerTime) or Call(time)
    if Number(now, 1) then return math.floor(now) end
end

function VIC:IsObservationFresh(record, now)
    return type(record) == "table" and Number(record.observedAt, 1) and now and
        record.observedAt >= now - MAX_AGE and record.observedAt <= now
end

function VIC:InitializeObservations()
    if self.client ~= "forever" then return end
    local stored = VendorItemCheckDB.observations
    if stored == nil then
        local digits = {}
        for i = 1, 32 do digits[i] = string.format("%x", math.random(0, 15)) end
        stored = { schema = 1, reporterId = "vic-" .. table.concat(digits), characters = {} }
        VendorItemCheckDB.observations = stored
    end
    -- Preserve unsupported saved schemas instead of overwriting their contents.
    if type(stored) ~= "table" or stored.schema ~= 1 or type(stored.characters) ~= "table" or
        type(stored.reporterId) ~= "string" then return end
    self.observations = stored
    self:RebuildPersonalIndex()
end

function VIC:RebuildPersonalIndex()
    self.personalIndex = {}
    local now = self:ObservationNow()
    if not self.observations then return end
    for character, data in pairs(self.observations.characters) do
        if type(data) == "table" and type(data.offers) == "table" then
            for key, record in pairs(data.offers) do
                if self:IsObservationFresh(record, now) and Number(record.itemId, 1) and Number(record.vendorId, 1) then
                    local index = self.personalIndex
                    index[record.itemId] = index[record.itemId] or {}
                    index[record.itemId][record.vendorId] = index[record.itemId][record.vendorId] or {}
                    index[record.itemId][record.vendorId][character] = record
                elseif now then
                    data.offers[key] = nil
                end
            end
        end
    end
end

local function MerchantIdentity()
    local guid = Call(UnitGUID, "npc")
    if type(guid) ~= "string" then return nil end
    local kind, id = string.match(guid, "^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return guid, tonumber(id) end
end

local function ItemInfo(index)
    local modern = C_MerchantFrame and Call(C_MerchantFrame.GetItemInfo, index)
    if type(modern) == "table" then
        return modern.name, modern.price, modern.stackCount, modern.numAvailable,
            modern.isPurchasable, modern.hasExtendedCost
    end
    local name, _, price, quantity, stock, purchasable, _, extended = Call(GetMerchantItemInfo, index)
    return name, price, quantity, stock, purchasable, extended
end

local function CostInfo(index, extended)
    local costs = {}
    if not extended then return costs, extended == false end
    local count = Call(GetMerchantItemCostInfo, index)
    if not Number(count, 1) then return costs, false end
    local complete = true
    for slot = 1, math.min(count, 20) do
        local _, quantity, link = Call(GetMerchantItemCostItem, index, slot)
        local itemID = type(link) == "string" and tonumber(string.match(link, "item:(%d+)"))
        local currencyID = type(link) == "string" and tonumber(string.match(link, "currency:(%d+)"))
        if Number(quantity, 1) and (itemID or currencyID) then
            costs[#costs + 1] = { itemId = itemID, currencyId = currencyID, quantity = quantity }
        else
            complete = false
        end
    end
    return costs, complete and count <= 20
end

function VIC:ScanMerchant()
    if self.client ~= "forever" or not self.observations or not self.settings.enabled or
        not self.settings.recordMerchants or not self.merchantGUID then return end
    local guid, vendorId = MerchantIdentity()
    if guid ~= self.merchantGUID then return end
    local character = Call(UnitGUID, "player")
    local now = self:ObservationNow()
    local count = Call(GetMerchantNumItems)
    if not character or not now or not Number(count, 0) then return end
    local version, build, _, interface = Call(GetBuildInfo)
    if type(version) ~= "string" or not string.match(version, "^1%.60%.") or
        type(build) ~= "string" or not tonumber(interface) then return end
    local zone, x, y = Call(self.GetPlayerLocation, self)
    local mapID = C_Map and Call(C_Map.GetBestMapForUnit, "player")
    local testBuild = Call(IsTestBuild)
    local channel = testBuild == true and "test" or (testBuild == false and "live" or "unknown")
    local missing = false
    for index = 1, math.min(count, 1000) do
        local link = Call(GetMerchantItemLink, index)
        local itemId = type(link) == "string" and tonumber(string.match(link, "item:(%d+)"))
        local name, price, quantity, stock, purchasable, extended = ItemInfo(index)
        if itemId and type(name) == "string" and Integer(price, 0) and Integer(quantity, 1) then
            local costs, costsComplete = CostInfo(index, extended)
            local record = {
                vendorId = vendorId, itemId = itemId, vendorName = Call(UnitName, "npc"),
                observedAt = now, build = version .. "." .. build, interface = tonumber(interface),
                channel = channel, playerFaction = Call(UnitFactionGroup, "player"),
                priceCopper = price, quantity = quantity, stock = stock,
                canPurchase = purchasable, hasExtendedCost = extended,
                costs = costs, costsComplete = costsComplete,
                discount = Call(GetMerchantPriceDiscount, "npc"),
            }
            if Number(mapID, 1) and Number(x, 0) and Number(y, 0) and x > 0 and y > 0 and x <= 100 and y <= 100 then
                record.location = { mapId = mapID, x = x, y = y, approximate = true, zone = zone }
            end
            local characters = self.observations.characters
            if type(characters[character]) ~= "table" or type(characters[character].offers) ~= "table" then
                characters[character] = { offers = {} }
            end
            characters[character].offers[vendorId .. ":" .. itemId] = record
            self.personalIndex = self.personalIndex or {}
            self.personalIndex[itemId] = self.personalIndex[itemId] or {}
            self.personalIndex[itemId][vendorId] = self.personalIndex[itemId][vendorId] or {}
            self.personalIndex[itemId][vendorId][character] = record
        else
            missing = true
        end
    end
    if missing then self:ScheduleMerchantRetry() end
end

function VIC:ScheduleMerchantRetry()
    if self.merchantRetryPending or (self.merchantRetries or 0) >= 3 then return end
    self.merchantRetryPending = true
    self.merchantRetries = (self.merchantRetries or 0) + 1
    local generation = self.merchantGeneration
    local function Retry()
        if generation ~= VIC.merchantGeneration then return end
        VIC.merchantRetryPending = false
        VIC:ScanMerchant()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, Retry)
    else
        local elapsed = 0
        self.merchantFrame:SetScript("OnUpdate", function(frame, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.2 then
                frame:SetScript("OnUpdate", nil)
                Retry()
            end
        end)
    end
end

function VIC:MerchantInitialize()
    if self.client ~= "forever" then return end
    self:InitializeObservations()
    local frame = CreateFrame("Frame")
    self.merchantFrame = frame
    self.merchantGeneration = 0
    for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_LOGIN" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
            VIC.merchantGeneration = VIC.merchantGeneration + 1
            VIC.merchantRetries = 0
            VIC.merchantRetryPending = false
            frame:SetScript("OnUpdate", nil)
            VIC.merchantGUID = event == "MERCHANT_SHOW" and MerchantIdentity() or nil
            if event == "MERCHANT_SHOW" then VIC:RebuildPersonalIndex() end
        elseif event == "PLAYER_LOGIN" then
            VIC:RebuildPersonalIndex()
        end
        VIC:ScanMerchant()
    end)
end

function VIC:PersonalQuote(record)
    if record.canPurchase ~= true then return nil end
    if record.hasExtendedCost ~= false or not Number(record.quantity, 1) or not Number(record.priceCopper, 0) then return nil end
    local price = record.priceCopper
    if price % record.quantity == 0 then
        local unitPrice = price / record.quantity
        return (unitPrice == 0 and "0c" or self:FormatMoney(unitPrice)) .. " each"
    end
    return (price == 0 and "0c" or self:FormatMoney(price)) .. " / " .. record.quantity
end

function VIC:MergePersonalVendors(itemID, info)
    local entries = self.personalIndex and self.personalIndex[itemID]
    local now = self:ObservationNow()
    local character = Call(UnitGUID, "player")
    local byID = {}
    for i, vendor in ipairs(info.vendors) do byID[vendor.id] = i end
    for vendorId, characters in pairs(entries or {}) do
        local chosen, sameCharacter
        for owner, record in pairs(characters) do
            if self:IsObservationFresh(record, now) then
                local same = owner == character
                if not chosen or (same and not sameCharacter) or
                    (same == sameCharacter and record.observedAt > chosen.observedAt) then
                    chosen, sameCharacter = record, same
                end
            end
        end
        if chosen then
            local existing = byID[vendorId] and info.vendors[byID[vendorId]]
            local bundledAt = existing and existing.offer and existing.offer.lastSeenEpoch or 0
            if not existing or chosen.observedAt >= bundledAt then
                local location = chosen.location or {}
                local vendor = {
                    id = vendorId, name = chosen.vendorName or ("Vendor " .. vendorId),
                    zone = location.zone or "Location unknown", mapID = location.mapId,
                    x = location.x or 0, y = location.y or 0, approximate = true, faction = "?",
                    personal = true, observedAt = chosen.observedAt, stock = chosen.stock,
                    accessObserved = sameCharacter and chosen.canPurchase == true,
                    quoteText = sameCharacter and self:PersonalQuote(chosen) or nil,
                    alternateCost = sameCharacter and chosen.hasExtendedCost == true,
                }
                if existing then info.vendors[byID[vendorId]] = vendor
                else info.vendors[#info.vendors + 1] = vendor end
            end
        end
    end
    table.sort(info.vendors, function(a, b) return a.id < b.id end)
    info.totalCount = #info.vendors
    if info.totalCount > 0 then info.enemyOnly = false end
    local quotes = 0
    for _, vendor in ipairs(info.vendors) do
        if vendor.quoteText then quotes = quotes + 1; info.observedPriceText = vendor.quoteText end
    end
    if quotes ~= 1 then info.observedPriceText = nil end
    return info
end

function VIC:CountPersonalItems()
    local items, vendors = {}, {}
    local now = self:ObservationNow()
    for itemID, entries in pairs(self.personalIndex or {}) do
        for vendorID, characters in pairs(entries) do
            for _, record in pairs(characters) do
                if self:IsObservationFresh(record, now) then items[itemID] = true; vendors[vendorID] = true end
            end
        end
    end
    local itemCount, vendorCount = 0, 0
    for _ in pairs(items) do itemCount = itemCount + 1 end
    for _ in pairs(vendors) do vendorCount = vendorCount + 1 end
    return itemCount, vendorCount
end
