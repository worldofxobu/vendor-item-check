local _, VIC = ...

local function Call(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, value = pcall(api, ...)
    if ok then return value end
end

function VIC:CanTrackVendor(vendor)
    if not vendor or type(vendor.x) ~= "number" or type(vendor.y) ~= "number" or
        vendor.x <= 0 or vendor.x > 100 or vendor.y <= 0 or vendor.y > 100 then return false end
    if vendor.locationExpires then
        local now = self:ObservationNow()
        if not now or now > vendor.locationExpires then return false end
    end
    return true
end

function VIC:CanMapVendor(vendor)
    return self:CanTrackVendor(vendor) and type(vendor.mapID) == "number" and vendor.mapID > 0 and
        C_Map and type(C_Map.SetUserWaypoint) == "function" and type(C_Map.GetUserWaypoint) == "function" and
        type(C_Map.ClearUserWaypoint) == "function" and UiMapPoint and
        type(UiMapPoint.CreateFromCoordinates) == "function" and
        Call(C_Map.CanSetUserWaypointOnMap, vendor.mapID) == true or false
end

local function SamePoint(a, b)
    if not a or not b or a.uiMapID ~= b.uiMapID or not a.position or not b.position then return false end
    local ax, ay = a.position:GetXY()
    local bx, by = b.position:GetXY()
    return math.abs(ax - bx) < 0.000001 and math.abs(ay - by) < 0.000001
end

function VIC:StopTrackingVendor()
    if self.vendorWaypoint and C_Map and SamePoint(Call(C_Map.GetUserWaypoint), self.vendorWaypoint) then
        Call(C_Map.ClearUserWaypoint)
    end
    self.vendorWaypoint = nil
    self.trackedVendor = nil
    if self.trackingPanel then self.trackingPanel:Hide() end
end

function VIC:ShowTrackedVendorOnMap()
    local vendor = self.trackedVendor
    if not self:CanMapVendor(vendor) then return false end
    local point = Call(UiMapPoint.CreateFromCoordinates, vendor.mapID, vendor.x / 100, vendor.y / 100)
    if not point then return false end
    Call(C_Map.SetUserWaypoint, point)
    if not SamePoint(Call(C_Map.GetUserWaypoint), point) then return false end
    self.vendorWaypoint = point
    -- Open the map only after an explicit click, without changing supertracking.
    if OpenWorldMap then Call(OpenWorldMap, vendor.mapID)
    elseif WorldMapFrame and WorldMapFrame.SetMapID then
        Call(WorldMapFrame.Show, WorldMapFrame); Call(WorldMapFrame.SetMapID, WorldMapFrame, vendor.mapID)
    end
    return true
end

function VIC:TrackVendor(vendor)
    if not self:CanTrackVendor(vendor) then return false end
    self:StopTrackingVendor()
    self.trackedVendor = {}
    for key, value in pairs(vendor) do self.trackedVendor[key] = value end
    if not self.trackingPanel then
        local panel = CreateFrame("Frame", "VendorItemCheckTracking", UIParent, "BasicFrameTemplateWithInset")
        self.trackingPanel = panel
        panel:SetSize(310, 155); panel:SetPoint("CENTER", UIParent, "CENTER", 330, 0)
        panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        if panel.TitleText then panel.TitleText:SetText("Tracked vendor") end
        panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        panel.text:SetPoint("TOPLEFT", 14, -35); panel.text:SetWidth(272); panel.text:SetJustifyH("LEFT")
        panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.status:SetPoint("BOTTOMLEFT", 12, 42); panel.status:SetWidth(286); panel.status:SetJustifyH("LEFT")
        if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
        local map = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        map:SetPoint("BOTTOMLEFT", 12, 12); map:SetSize(130, 24); map:SetText("Show on map")
        map:SetScript("OnClick", function()
            if not self:ShowTrackedVendorOnMap() then panel.status:SetText("Map waypoint unavailable; use coordinates.") end
        end)
        panel.map = map
        local stop = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        stop:SetPoint("BOTTOMRIGHT", -12, 12); stop:SetSize(130, 24); stop:SetText("Stop tracking")
        stop:SetScript("OnClick", function() self:StopTrackingVendor() end)
        if panel.CloseButton then panel.CloseButton:SetScript("OnClick", function() self:StopTrackingVendor() end) end
        local elapsed = 0
        panel:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= 1 then
                elapsed = 0
                if not self:CanTrackVendor(self.trackedVendor) then self:StopTrackingVendor() end
            end
        end)
    end
    local panel = self.trackingPanel
    panel.text:SetText(string.format("%s\n%s %s%.1f, %.1f%s", vendor.name, vendor.zone or "Location unknown",
        vendor.approximate and "~" or "", vendor.x, vendor.y,
        ""))
    panel.status:SetText(self:CanMapVendor(vendor) and "" or "Map waypoint unavailable; use coordinates.")
    panel.map:SetEnabled(self:CanMapVendor(vendor)); panel:Show()
    return true
end
