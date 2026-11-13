-- Synthetic browser and waypoint behavior; no in-game verification implied.
dofile("tests/smoke.lua")
local originalCreateFrame = CreateFrame
function CreateFrame(...)
    local frame = originalCreateFrame(...)
    function frame:SetEnabled(value) self.enabled = value end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForDrag() end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    return frame
end
local VIC = VendorItemCheck
for _, file in ipairs({ "Tracking", "Browser" }) do
    assert(loadfile("VendorItemCheck/" .. file .. ".lua"))("VendorItemCheck", VIC)
end
local now = 1800000000
function time() return now end
function UnitGUID() return "owner" end
VIC.client = "forever"
VIC.Items = { [10] = { v = { 1 }, offers = { [1] = { expires = now + 100, reporters = 3, lastSeenEpoch = now - 10 } } } }
VIC.Vendors = { [1] = { "Bundled Vendor", "Zone", "?", 50, 60,
    mapID = 7, nameExpires = now + 100, locationExpires = now + 100 } }
local record = { observedAt = now, vendorName = "Personal Vendor", location = { mapId = 7, zone = "Zone", x = 51, y = 61 },
    quantity = 5, priceCopper = 20, canPurchase = true, hasExtendedCost = false, stock = 3 }
VIC.personalIndex = { [10] = { [1] = { owner = record } }, [20] = { [2] = { other = record } } }
local index = VIC:BuildBrowserIndex()
assert(index.items[10] and #index.items[10].vendors == 1, "Deduplicate overlapping offers")
assert(index.vendors[1].name == "Personal Vendor" and #index.vendors[1].items == 1)
assert(index.vendors[1].items[1].vendor.quoteText:find("4c"))
assert(not index.vendors[2].items[1].vendor.quoteText, "Other characters cannot inherit quotes")
assert(VIC:BuildBrowserIndex({ source = "bundled" }).vendors[1].name == "Bundled Vendor")
assert(VIC:BuildBrowserIndex({ source = "bundled" }).items[20] == nil)
assert(VIC:BuildBrowserIndex({ source = "personal" }).vendors[1].name == "Personal Vendor")
assert(next(VIC:BuildBrowserIndex({ zone = "Elsewhere" }).items) == nil)
assert(VIC:BrowserOfferText(index.vendors[1].items[1].vendor):find("Stock observed: 3", 1, true))
assert(not VIC:CanTrackVendor({ x = 0, y = 20 }))
assert(not VIC:CanTrackVendor({ x = 101, y = 20 }))
C_Map = nil
assert(VIC:TrackVendor(index.vendors[1].vendor), "Tracking panel works without map APIs")
assert(not VIC.trackingPanel.map.enabled and not VIC:ShowTrackedVendorOnMap())
assert(VIC.trackingPanel.text:GetText():find("~51.0", 1, true))
local waypoint
UiMapPoint = { CreateFromCoordinates = function(id, x, y)
    return { uiMapID = id, position = { GetXY = function() return x, y end } }
end }
C_Map = {
    CanSetUserWaypointOnMap = function() return true end,
    GetUserWaypoint = function() return waypoint end,
    SetUserWaypoint = function(point) waypoint = point end,
    ClearUserWaypoint = function() waypoint = nil end,
}
assert(VIC:ShowTrackedVendorOnMap())
local x, y = waypoint.position:GetXY()
assert(x == 0.51 and y == 0.61 and waypoint.uiMapID == 7)
waypoint = UiMapPoint.CreateFromCoordinates(99, 0.1, 0.2)
VIC:StopTrackingVendor()
assert(waypoint and waypoint.uiMapID == 99, "Keep user replacement waypoint")
VIC:TrackVendor(index.vendors[1].vendor)
assert(VIC:ShowTrackedVendorOnMap())
VIC:StopTrackingVendor()
assert(waypoint == nil, "Remove addon-owned waypoint")
VIC:TrackVendor(index.vendors[1].vendor)
now = now + 31 * 86400
VIC.trackingPanel.scripts.OnUpdate(VIC.trackingPanel, 1)
assert(not VIC.trackedVendor and not VIC.trackingPanel:IsVisible())
assert(next(VIC:BuildBrowserIndex().items) == nil, "Expired offers disappear")
now = 1800000000

-- UI navigation, source filtering, search, and asynchronous item-name refresh.
VIC:OpenBrowser()
local panel = VIC.browserPanel
assert(panel.rows[1].name == "Item 10")
function GetItemInfo(id) if id == 10 then return "Test Reagent" end end
panel.scripts.OnUpdate(panel, 0.3)
assert(VIC:BrowserItemName(10) == "Test Reagent")
panel.search:SetText("reagent")
VIC:RefreshBrowser()
assert(#panel.rows == 1 and panel.rows[1].id == 10)
panel.list[1].scripts.OnClick(panel.list[1])
assert(panel.details[1].row.id == 1)
panel.details[1].scripts.OnClick(panel.details[1])
assert(panel.tab == "vendors" and panel.selected == 1 and panel.details[1].row.id == 10)
panel.details[1].scripts.OnClick(panel.details[1])
assert(panel.tab == "items" and panel.selected == 10)
panel.back.scripts.OnClick()
assert(panel.tab == "vendors" and panel.selected == 1)
panel.back.scripts.OnClick()
assert(panel.tab == "items" and panel.search:GetText() == "reagent" and panel.selected == 10)
assert(#panel.history == 0)
panel.itemsTab.scripts.OnClick()
panel.vendorsTab.scripts.OnClick()
panel.search:SetText("Personal")
panel.itemsTab.scripts.OnClick()
assert(panel.search:GetText() == "reagent", "Each tab retains its search")
panel.vendorsTab.scripts.OnClick()
assert(panel.search:GetText() == "Personal")
panel.itemsTab.scripts.OnClick()
panel.source.scripts.OnClick(); VIC.choiceMenu.rows[2].scripts.OnClick()
assert(panel.filters.source == "personal")
panel.source.scripts.OnClick(); VIC.choiceMenu.rows[3].scripts.OnClick()
assert(panel.filters.source == "bundled" and not panel.index.items[20])
panel.source.scripts.OnClick(); VIC.choiceMenu.rows[1].scripts.OnClick()
assert(panel.filters.source == nil)
panel.selected = 20; panel.tab = "items"; VIC:RefreshBrowser()
assert(panel.details[1].caption:GetText():find("Price unavailable", 1, true))
assert(not panel.details[1].caption:GetText():find("Classic reference", 1, true))
panel.search:SetText("no match")
VIC:RefreshBrowser()
assert(#panel.rows == 0)
-- Resolve a previously unavailable name after its completion event.
function GetItemInfo(id) return id == 20 and "Newly Cached" or "Test Reagent" end
panel.scripts.OnEvent(panel, "GET_ITEM_INFO_RECEIVED", 20, true)
panel.filters = {}; VIC:RefreshBrowser(true)
panel.scripts.OnUpdate(panel, 0.3)
assert(VIC:BrowserItemName(20) == "Newly Cached")

VIC.client = "classic"; VIC.personalIndex = nil
VIC.Items = { [30] = { v = { 3, 4 }, p = 25 } }
VIC.Vendors = { [3] = { "Friendly", "Zone", "A", 10, 20 }, [4] = { "Enemy", "Zone", "H", 20, 30 } }
index = VIC:BuildBrowserIndex()
assert(index.vendors[3] and not index.vendors[4])
assert(VIC:BuildBrowserIndex({ allFactions = true }).vendors[4])
assert(next(VIC:BuildBrowserIndex({ source = "personal" }).items) == nil)
assert(VIC:BrowserOfferText(index.vendors[3].items[1].vendor, 25):find("Classic reference"))
assert(not VIC:CanMapVendor(index.vendors[3].vendor), "Never guess a Classic map ID")
VIC.Items = {}; VIC.Vendors = {}
assert(next(VIC:BuildBrowserIndex().items) == nil)
print("=== ALL BROWSER AND TRACKING SMOKE TESTS PASSED ===")
