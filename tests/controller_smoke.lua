local VIC = dofile("tests/contribution_fixture.lua")
local indices = { PADLTRIGGER = 0, PADRTRIGGER = 3, PADLSHOULDER = 5, PADRSHOULDER = 7 }
local buttons = { [1] = false, [4] = false, [6] = false, [8] = false }
local connected, enabled = true, true
local alt, shift, ctrl = false, false, false
local reads = 0
function IsAltKeyDown() return alt end
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return ctrl end
local function Forbidden() error("Tooltip expansion must never bind, capture or remap game input") end
SetBinding, SetOverrideBinding, SetOverrideBindingClick, SetCVar = Forbidden, Forbidden, Forbidden, Forbidden
C_GamePad = {
    IsEnabled = function() return enabled end,
    GetAllDeviceIDs = function() return connected and { 7 } or {} end,
    GetActiveDeviceID = function() return 7 end,
    ButtonBindingToIndex = function(binding) return indices[binding] end,
    GetDeviceMappedState = function(device)
        assert(device == 7)
        reads = reads + 1
        return connected and { buttons = buttons } or nil
    end,
    SetConfig = Forbidden, ApplyConfigs = Forbidden,
}

local originalCreate = CreateFrame
local named, created = {}, {}
CreateFrame = function(frameType, name, ...)
    local frame = originalCreate(frameType, name, ...)
    created[#created + 1] = frame
    if name then named[name] = frame end
    frame.EnableGamePadButton, frame.EnableKeyboard, frame.SetPropagateKeyboardInput = Forbidden, Forbidden, Forbidden
    if frameType == "GameTooltip" then
        local hooks = {}
        function frame:HookScript(event, callback)
            hooks[event] = hooks[event] or {}
            table.insert(hooks[event], callback)
        end
        function frame:ClearLines()
            self.lines = {}
            self.currentItemLink = nil
            for _, callback in ipairs(hooks.OnTooltipCleared or {}) do callback(self) end
        end
        local hide, setLink = frame.Hide, frame.SetHyperlink
        function frame:Hide()
            hide(self)
            for _, callback in ipairs(hooks.OnHide or {}) do callback(self) end
        end
        function frame:SetHyperlink(link)
            self:ClearLines()
            self.rebuilds = (self.rebuilds or 0) + 1
            setLink(self, link)
        end
    end
    return frame
end
VIC:TooltipInitialize()
VIC:OptionsInitialize()
assert(reads == 0 and not VIC.tooltipWatcher:GetScript("OnUpdate"), "No input polling without an item tooltip")
local function Tick()
    local update = VIC.tooltipWatcher:GetScript("OnUpdate")
    if update then update(VIC.tooltipWatcher, 0.05) end
end
local function Text(tip)
    local lines = {}
    for _, line in ipairs(tip.lines) do lines[#lines + 1] = (line.left or "") .. (line.right or "") end
    return table.concat(lines, "\n")
end
local function Expanded(tip) return Text(tip):find("Sold by vendors", 1, true) ~= nil end
local tip = CreateFrame("GameTooltip", "ControllerTooltip")
tip:SetHyperlink("item:100002")
assert(Text(tip):find("Hold ALT or LT for locations", 1, true))
assert(VIC.tooltipWatcher:GetScript("OnUpdate"))
buttons[1] = true
Tick()
assert(Expanded(tip), "LT must expand without emulating keyboard Alt")
buttons[1] = false
Tick()
assert(not Expanded(tip), "Releasing LT must collapse the item tooltip")
alt = true
VIC.tooltipWatcher.scripts.OnEvent(VIC.tooltipWatcher, "MODIFIER_STATE_CHANGED")
assert(Expanded(tip))
buttons[1] = true
alt = false
VIC.tooltipWatcher.scripts.OnEvent(VIC.tooltipWatcher, "MODIFIER_STATE_CHANGED")
assert(Expanded(tip), "Either held input keeps expansion active")
buttons[1] = false
Tick()
assert(not Expanded(tip))

-- Remap through the actual settings buttons while the tooltip remains open.
named.VICControllerModifier.scripts.OnClick()
assert(VIC.settings.controllerModifier == "RT" and named.VICControllerModifier:GetText() == "Hold RT / R2")
assert(Text(tip):find("ALT or RT", 1, true))
buttons[1] = true
Tick()
assert(not Expanded(tip), "The previously selected trigger must not remain active")
buttons[4] = true
Tick()
assert(Expanded(tip))
buttons[1], buttons[4] = false, false
for _, choice in ipairs({ { "LB", 6 }, { "RB", 8 } }) do
    named.VICControllerModifier.scripts.OnClick()
    assert(VIC.settings.controllerModifier == choice[1])
    buttons[choice[2]] = true
    Tick()
    assert(Expanded(tip))
    buttons[choice[2]] = false
    Tick()
    assert(not Expanded(tip))
end
named.VICControllerModifier.scripts.OnClick()
assert(VIC.settings.controllerModifier == "OFF" and not VIC.tooltipWatcher:GetScript("OnUpdate"))
assert(Text(tip):find("Hold ALT for locations", 1, true))
named.VICControllerModifier.scripts.OnClick()
assert(VIC.settings.controllerModifier == "LT")

-- Keyboard remapping, controller-only mode and the existing always-expanded mode.
named.VICKeyboardModifier.scripts.OnClick()
assert(VIC.settings.modifierKey == "SHIFT" and Text(tip):find("SHIFT or LT", 1, true))
shift = true
VIC.tooltipWatcher.scripts.OnEvent()
assert(Expanded(tip))
shift = false
named.VICKeyboardModifier.scripts.OnClick()
assert(VIC.settings.modifierKey == "CTRL")
ctrl = true
VIC.tooltipWatcher.scripts.OnEvent()
assert(Expanded(tip))
ctrl = false
named.VICKeyboardModifier.scripts.OnClick()
assert(VIC.settings.modifierKey == "OFF" and Text(tip):find("Hold LT for locations", 1, true))
alt = true
Tick()
assert(not Expanded(tip), "Keyboard-off mode must not respond to Alt")
alt = false
named.VICKeyboardModifier.scripts.OnClick()
assert(VIC.settings.modifierKey == "NONE" and Expanded(tip))
assert(not VIC.tooltipWatcher:GetScript("OnUpdate"), "Always-expanded mode needs no controller polling")
named.VICKeyboardModifier.scripts.OnClick()
assert(VIC.settings.modifierKey == "ALT")
VIC:InitializeDB()
assert(VIC.settings.controllerModifier == "LT" and VendorItemCheckDB.privateSetting == "PRIVATE_TOKEN")

-- Connection state and unavailable APIs must collapse safely and keep hints accurate.
buttons[1] = true
Tick()
assert(Expanded(tip))
connected = false
Tick()
assert(not Expanded(tip) and Text(tip):find("Hold ALT for locations", 1, true))
connected, buttons[1] = true, false
Tick()
assert(Text(tip):find("ALT or LT", 1, true))
local getState = C_GamePad.GetDeviceMappedState
C_GamePad.GetDeviceMappedState = function() error("Unavailable controller API") end
Tick()
assert(not Expanded(tip) and not Text(tip):find("or LT", 1, true))
C_GamePad.GetDeviceMappedState = getState
enabled = false
Tick()
assert(not Text(tip):find("or LT", 1, true))
enabled = true
Tick()

-- Multiple item tooltips refresh together; hide/clear never resurrect an old item.
local second = CreateFrame("GameTooltip", "ControllerItemRefTooltip")
second:SetHyperlink("item:100002")
buttons[1] = true
Tick()
assert(Expanded(tip) and Expanded(second))
tip:Hide()
local rebuilds = tip.rebuilds
buttons[1] = false
Tick()
assert(not Expanded(second) and tip.rebuilds == rebuilds and not tip:IsVisible())
second:ClearLines()
assert(not VIC.tooltipWatcher:GetScript("OnUpdate"))
local before = reads
Tick()
assert(reads == before)
second:SetHyperlink("item:99999999")
assert(second:NumLines() == 0 and not VIC.tooltipWatcher:GetScript("OnUpdate"))
assert(reads == before, "An unknown item must not trigger controller input reads")
second:SetHyperlink("item:100002")
local lastBuild = second.rebuilds
second.currentItemLink = "item:100002:other-variant"
Tick()
assert(second.rebuilds == lastBuild and not VIC.tooltipWatcher:GetScript("OnUpdate"), "Never restore a stale link for the same item ID")
second:SetHyperlink("item:100002")
second.currentItemLink = nil -- Some UI contexts clear the item without firing a script.
Tick()
assert(not VIC.tooltipWatcher:GetScript("OnUpdate"))

-- Disabling, resetting, saved-setting validation, and Classic fallback.
second:SetHyperlink("item:100002")
named.VICOptionenabled:SetChecked(false)
named.VICOptionenabled.scripts.OnClick(named.VICOptionenabled)
assert(second:NumLines() == 0 and not VIC.tooltipWatcher:GetScript("OnUpdate"))
named.VICOptionenabled:SetChecked(true)
named.VICOptionenabled.scripts.OnClick(named.VICOptionenabled)
second:SetHyperlink("item:100002")
VIC.settings.modifierKey, VIC.settings.controllerModifier = "CTRL", "RB"
for _, frame in ipairs(created) do
    if frame.text == "Reset Defaults" then frame.scripts.OnClick() end
end
assert(VIC.settings.modifierKey == "ALT" and VIC.settings.controllerModifier == "LT")
assert(Text(second):find("ALT or LT", 1, true))
VIC.settings.modifierKey, VIC.settings.controllerModifier = "bad", "bad"
VIC:InitializeDB()
assert(VIC.settings.modifierKey == "ALT" and VIC.settings.controllerModifier == "LT")
C_GamePad = nil
VIC:RefreshVendorTooltips(true)
assert(not VIC.tooltipWatcher:GetScript("OnUpdate") and not Text(second):find("or LT", 1, true))
local down, available = VIC:GetControllerModifierState()
assert(not down and not available)
VIC.client = "classic"
buttons[1] = true
C_GamePad = { GetDeviceMappedState = Forbidden, ButtonBindingToIndex = Forbidden }
assert(not VIC:IsExpanded(), "Classic must retain keyboard-only expansion")
print("=== ALL CONTROLLER TOOLTIP SMOKE TESTS PASSED ===")
