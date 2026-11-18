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

function VIC:OwnsVendorWaypoint(vendor)
    if not self.vendorWaypoint or not C_Map then return false end
    if not SamePoint(Call(C_Map.GetUserWaypoint), self.vendorWaypoint) then
        self.vendorWaypoint = nil
        return false
    end
    if not vendor or not self:CanTrackVendor(vendor) or type(vendor.mapID) ~= "number" then return false end
    local point = UiMapPoint and Call(UiMapPoint.CreateFromCoordinates, vendor.mapID, vendor.x / 100, vendor.y / 100)
    return SamePoint(point, self.vendorWaypoint)
end

function VIC:TrackVendor(vendor)
    if self:OwnsVendorWaypoint(vendor) then
        self:StopTrackingVendor()
        return true
    end
    if not self:CanMapVendor(vendor) then return false end
    self.trackedVendor = vendor
    return self:ShowTrackedVendorOnMap()
end
