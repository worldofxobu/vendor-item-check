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

local function PublicRecord(record)
    -- Explicit field lists keep account/character keys and unrelated settings local.
    local public = {}
    for _, key in ipairs({ "vendorId", "itemId", "vendorName", "observedAt", "build", "interface", "channel",
        "playerFaction", "priceCopper", "quantity", "stock", "canPurchase", "hasExtendedCost", "discount", "costsComplete" }) do
        public[key] = record[key]
    end
    local costs = {}
    for _, cost in ipairs(record.costs or {}) do
        costs[#costs + 1] = { itemId = cost.itemId, currencyId = cost.currencyId, quantity = cost.quantity }
    end
    public.costs = Array(costs)
    if record.location then
        public.location = {}
        for _, key in ipairs({ "mapId", "x", "y", "approximate", "zone" }) do
            public.location[key] = record.location[key]
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
    table.sort(encoded)
    local header = JSON({ schema = "vic.observations/1", client = "forever", licence = "CC BY-SA 4.0",
        reporterId = self.observations.reporterId, exportedAt = now })
    return string.sub(header, 1, -2) .. ',"records":[' .. table.concat(encoded, ",") .. "]}"
end

function VIC:OpenExport()
    if self.client ~= "forever" or not self.observations then
        self:Print("No supported Forever observations are available.")
        return
    end
    if not self.exportPanel then
        local panel = CreateFrame("Frame", "VendorItemCheckExport", UIParent, "BasicFrameTemplateWithInset")
        panel:SetSize(640, 450)
        panel:SetPoint("CENTER")
        local title = panel.TitleText or panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetText("Vendor Item Check - Share observations")
        local notice = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        notice:SetPoint("TOPLEFT", 18, -38)
        notice:SetWidth(594)
        notice:SetJustifyH("LEFT")
        notice:SetText("Sharing is optional. Prepare an export only if you agree to share these observations under CC BY-SA 4.0 (creativecommons.org/licenses/by-sa/4.0/). Character/account names and GUIDs are excluded. Dates, NPC locations and a stable installation pseudonym are included. Nothing is uploaded.")
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -130)
        scroll:SetPoint("BOTTOMRIGHT", -38, 55)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        box:SetWidth(570)
        box:SetHeight(260)
        box:SetMaxLetters(0)
        box:SetScript("OnEscapePressed", function(edit) edit:ClearFocus(); panel:Hide() end)
        box:SetScript("OnTextChanged", function() scroll:UpdateScrollChildRect() end)
        scroll:SetScrollChild(box)
        local prepare = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        prepare:SetSize(180, 24)
        prepare:SetPoint("BOTTOMLEFT", 18, 18)
        prepare:SetText("Prepare CC BY-SA export")
        prepare:SetScript("OnClick", function()
            local ok, document, message = pcall(VIC.BuildContribution, VIC)
            if ok and document then
                box:SetText(document)
                box:SetFocus()
                box:HighlightText()
            else
                VIC:Print("%s", ok and message or "Could not encode the stored observations.")
            end
        end)
        local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("LEFT", prepare, "RIGHT", 12, 0)
        hint:SetText("Copy with Ctrl+C; save as a .json file.")
        self.exportPanel, self.exportBox, self.exportPrepare = panel, box, prepare
    end
    self.exportBox:SetText("")
    self.exportPanel:Show()
end
