local addonName, VIC = ...
_G.VendorItemCheck = VIC

VIC.title = "Vendor Item Check"
VIC.version = "0.1.0"

VIC.defaults = {
    enabled = true,
    recordMerchants = true,
    modifierKey = "ALT",      -- "ALT", "SHIFT", "CTRL", "NONE"
    maxVendors = 4,           -- 1 to 10
    showClosestFirst = true,
    showCoordinates = true,
    showPrice = true,
    showFaction = true,
}

function VIC:SelectDataset()
    local client = "unknown"
    if GetBuildInfo then
        local ok, version, _, _, interface = pcall(GetBuildInfo)
        if ok then
            interface = tonumber(interface)
            if (interface and interface >= 16000 and interface < 17000) or
                (type(version) == "string" and string.match(version, "^1%.60%.")) then
                client = "forever"
            elseif (interface and interface >= 11500 and interface < 11600) or
                (type(version) == "string" and string.match(version, "^1%.15%.")) then
                client = "classic"
            end
        end
    end
    self.client = client
    local dataset = self.Datasets and self.Datasets[client]
    self.Vendors = dataset and dataset.vendors or {}
    self.Items = dataset and dataset.items or {}
    self.dataMetadata = dataset and dataset.metadata or {
        client = "Unsupported or unknown client", source = "None", dataAsOf = "Unknown", build = "Unknown",
    }
end

function VIC:Print(formatString, ...)
    local message = string.format(formatString, ...)
    local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
    if chatFrame and chatFrame.AddMessage then
        chatFrame:AddMessage("|cff00ff00[" .. VIC.title .. "]|r " .. message)
    end
end

function VIC:GetPlayerFaction()
    if not self.playerFaction then
        local factionGroup = UnitFactionGroup and UnitFactionGroup("player")
        if factionGroup == "Alliance" or factionGroup == "Horde" then
            self.playerFaction = factionGroup
        end
    end
    return self.playerFaction
end

function VIC:GetPlayerLocation()
    local zoneName = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    local playerX, playerY = nil, nil

    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local position = C_Map.GetPlayerMapPosition(mapID, "player")
            if position and position.GetXY then
                local rawX, rawY = position:GetXY()
                if rawX and rawY and rawX > 0 and rawY > 0 then
                    playerX = rawX * 100
                    playerY = rawY * 100
                end
            end
        end
    end

    return zoneName, playerX, playerY
end

local function NormalizeZone(zone)
    if not zone or zone == "" then
        return ""
    end
    return string.lower(strtrim(zone))
end

function VIC:IsVendorFriendly(vendorFaction, playerFaction)
    if vendorFaction == "?" then
        return true -- Availability is reported separately; this is not a neutral faction tag.
    end
    if not vendorFaction or vendorFaction == "N" or vendorFaction == "AH" or vendorFaction == "" then
        return true
    end

    if not playerFaction then
        return true -- The player's faction is not available yet.
    end
    local isAlliance = (playerFaction == "Alliance")
    if vendorFaction == "A" and isAlliance then
        return true
    elseif vendorFaction == "H" and not isAlliance then
        return true
    end

    return false
end

function VIC:GetItemVendors(itemID)
    if not itemID or not self.Items then
        return nil
    end

    local itemData = self.Items[itemID]
    local bundledItem = itemData ~= nil
    if not itemData and self.client == "forever" then itemData = { v = {} } end
    if not itemData then
        -- Optional external integration: Informant
        if self.client == "classic" and Informant and Informant.GetItem then
            local inf = Informant.GetItem(itemID)
            if inf and inf.buy then
                itemData = { v = {}, p = inf.buy }
            end
        end
    end

    if not itemData or not itemData.v then
        return nil
    end

    local playerFaction = self:GetPlayerFaction()
    local friendlyVendors = {}
    local totalVendors = 0
    local enemyVendorsCount = 0

    for _, vendorID in ipairs(itemData.v) do
        local rawVendor = self.Vendors and self.Vendors[vendorID]
        local offer = itemData.offers and itemData.offers[vendorID]
        if self.client == "forever" then
            if not offer or not offer.expires or not offer.reporters or offer.reporters < 3 or
                (time and time() > offer.expires) then
                rawVendor = nil
            end
        end
        if rawVendor then
            totalVendors = totalVendors + 1
            local vFac = rawVendor[3] or "N"
            if self:IsVendorFriendly(vFac, playerFaction) then
                local locationValid = self.client ~= "forever" or
                    (rawVendor.locationExpires and (not time or time() <= rawVendor.locationExpires))
                local nameValid = self.client ~= "forever" or
                    (rawVendor.nameExpires and (not time or time() <= rawVendor.nameExpires))
                local zone = locationValid and rawVendor[2] or "Location unknown"
                if locationValid and rawVendor.mapID and C_Map and C_Map.GetMapInfo then
                    local ok, info = pcall(C_Map.GetMapInfo, rawVendor.mapID)
                    if ok and info and info.name then
                        zone = info.name
                    end
                end
                friendlyVendors[#friendlyVendors + 1] = {
                    id = vendorID,
                    name = nameValid and rawVendor[1] or ("Vendor " .. vendorID),
                    zone = zone,
                    faction = vFac,
                    x = locationValid and rawVendor[4] or 0.0,
                    y = locationValid and rawVendor[5] or 0.0,
                    mapID = locationValid and rawVendor.mapID or nil,
                    approximate = rawVendor.approximate,
                    offer = offer,
                }
            else
                enemyVendorsCount = enemyVendorsCount + 1
            end
        end
    end

    local isEnemyOnly = (#friendlyVendors == 0 and enemyVendorsCount > 0)

    local result = {
        vendors = friendlyVendors,
        totalCount = #friendlyVendors,
        -- Forever's current source omits quantities, currencies and discounts.
        price = self.client == "classic" and itemData.p or nil,
        enemyOnly = isEnemyOnly,
        enemyFaction = playerFaction and ((playerFaction == "Alliance") and "Horde" or "Alliance") or nil,
    }
    if self.client == "forever" and self.MergePersonalVendors then
        self:MergePersonalVendors(itemID, result)
    end
    if not bundledItem and result.totalCount == 0 and not result.enemyOnly then return nil end
    return result
end

function VIC:SortVendorsByProximity(vendors, playerZone, playerX, playerY)
    if not vendors or #vendors <= 1 then
        return vendors
    end

    local normPlayerZone = NormalizeZone(playerZone)
    local hasPlayerCoords = (playerX ~= nil and playerY ~= nil and playerX > 0 and playerY > 0)

    for _, v in ipairs(vendors) do
        local normVZone = NormalizeZone(v.zone)
        local isSameZone = (normPlayerZone ~= "" and normPlayerZone == normVZone)

        if v.mapID and C_Map and C_Map.GetBestMapForUnit then
            isSameZone = C_Map.GetBestMapForUnit("player") == v.mapID
        end
        if isSameZone then
            if hasPlayerCoords and v.x > 0 and v.y > 0 then
                local dx = v.x - playerX
                local dy = v.y - playerY
                v._sortDist = math.sqrt(dx * dx + dy * dy)
            else
                v._sortDist = 0.001
            end
        else
            v._sortDist = 1000.0
        end
    end

    table.sort(vendors, function(a, b)
        if a._sortDist ~= b._sortDist then
            return a._sortDist < b._sortDist
        end
        if a.zone ~= b.zone then
            return a.zone < b.zone
        end
        return a.name < b.name
    end)

    return vendors
end

function VIC:FormatMoney(copper)
    if not copper or copper <= 0 then
        return nil
    end

    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = copper % 100

    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = string.format("|cffffd700%dg|r", gold)
    end
    if silver > 0 or gold > 0 then
        parts[#parts + 1] = string.format("|cffc7c7cf%ds|r", silver)
    end
    parts[#parts + 1] = string.format("|cffeda55f%dc|r", c)

    return table.concat(parts, " ")
end

function VIC:CountIndexedItems()
    local itemCount = 0
    if self.Items then
        for _ in pairs(self.Items) do
            itemCount = itemCount + 1
        end
    end
    local vendorCount = 0
    if self.Vendors then
        for _ in pairs(self.Vendors) do
            vendorCount = vendorCount + 1
        end
    end
    return itemCount, vendorCount
end

function VIC:InitializeDB()
    if not VendorItemCheckDB or type(VendorItemCheckDB) ~= "table" then
        VendorItemCheckDB = {}
    end

    for key, defaultValue in pairs(self.defaults) do
        if VendorItemCheckDB[key] == nil then
            VendorItemCheckDB[key] = defaultValue
        end
    end

    self.settings = VendorItemCheckDB
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        VIC:SelectDataset()
        VIC:InitializeDB()
        if VIC.MerchantInitialize then VIC:MerchantInitialize() end
        if VIC.OptionsInitialize then
            VIC:OptionsInitialize()
        end
        if VIC.TooltipInitialize then
            VIC:TooltipInitialize()
        end
    elseif event == "PLAYER_LOGIN" then
        VIC:GetPlayerFaction()
    end
end)
