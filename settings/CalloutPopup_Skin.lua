local _, NS = ...
-- settings/CalloutPopup_Skin.lua — paints the callout popup's window in the user's EllesmereUI
-- theme, the way EllesmereUI paints Blizzard's settings window (EllesmereUIBlizzardSkin's window
-- pack, "Blizzard Options (SettingsPanel)"): the shell, the border faded, the background at alpha
-- 0 and the house close X. The page inside, like the settings window's per-setting controls,
-- stays stock.
--
-- Through EllesmereUI's PUBLIC skinning API only (SKINNING_API.md: RegisterSkin, facade S), reached
-- through core/EUIBridge.lua, the one file that reads EllesmereUI's state. Registered at FILE LOAD,
-- presence-guarded and never gated on a switch: that lists this addon in EllesmereUI's
-- Third-Party Addons, whose entry is the switch, and hands over S. EllesmereUI calls back once per
-- session (at PLAYER_LOGIN, or live when a switch turns on), and only while its switches are on.
-- The popup is built on its first Open, so S is KEPT and the paint happens when both exist: from
-- the callback, from the popup's build, and from the stand-up. A paint is one-way (only a reload
-- removes it), and every primitive is idempotent and alpha-only (no Hide, no SetParent), on the
-- popup's own frames.
--
-- Effective skin = S held AND every gate condition (core/EUIBridge.lua) AND the popup built AND
-- not stood down.

local Settings = NS.addon.Settings
Settings.CalloutPopupSkin = Settings.CalloutPopupSkin or {}
local Skin = Settings.CalloutPopupSkin
local Pop = Settings.CalloutPopup

local TAG = "Skin"
-- Every facade member the paint calls. A facade missing one is refused before anything is painted,
-- so a changed EllesmereUI API leaves the popup stock rather than half-skinned.
local REQUIRED = { "Shell", "FadeNineSlice", "CloseButton" }

local S              -- the facade, once EllesmereUI has called back
local applied = false
local paintFailed    -- the error of a paint that raised: no retry, a reload drops the partial paint

function Skin.IsApplied() return applied end
function Skin.HasFacade() return S ~= nil end

-- Why the paint does not happen now, or nil when it can.
local function blocked()
    if NS.IsStoodDown() then return "stood down" end
    if not S then return "EllesmereUI has not called back" end
    if paintFailed then return "paint failed earlier: " .. paintFailed end
    for _, name in ipairs(REQUIRED) do
        if type(S[name]) ~= "function" then return "facade lacks " .. name end
    end
    local open, failing = NS.EUIBridge.GateOpen()
    if not open then return "condition '" .. tostring(failing) .. "' not met" end
    if not Pop.chrome then return "popup not built yet" end
    return nil
end

-- The settings window's chrome pass, on the popup's window: what the template drew, or the
-- fallback's dialog edge and close mark.
local function paint(chrome)
    S.Shell(chrome.window)
    if chrome.nineSlice then S.FadeNineSlice(chrome.nineSlice) end
    if chrome.bg and chrome.bg.SetAlpha then chrome.bg:SetAlpha(0) end
    if chrome.close then S.CloseButton(chrome.close) end
end

--- Paint the popup when every condition holds. Idempotent; one-way. Called from the EllesmereUI
--- callback, the popup's build and the stand-up; cheap when it refuses.
--- @return boolean painted  true only on the call that painted
function Skin.TryApply()
    if applied then return false end
    local why = blocked()
    if why then
        NS.DebugChanged("popupskin.skip", TAG, "callout popup skin skipped: %s", why)
        return false
    end
    -- Fail closed: a primitive that raises leaves what it painted and latches paintFailed, so the
    -- next try never paints the same frames twice.
    local ok, err = pcall(paint, Pop.chrome)
    if not ok then
        paintFailed = tostring(err)
        NS.Debug(TAG, "callout popup skin failed: %s", paintFailed)
        return false
    end
    applied = true
    NS.Debug(TAG, "callout popup skinned (EllesmereUI apiVersion %s)", tostring(S.apiVersion))
    return true
end

--- One line for the diagnostics report: the gate, the facade and the paint.
--- @return string
function Skin.Describe()
    local B = NS.EUIBridge
    return ("ellesmereui: suite=%s master=%s entry=%s facade=%s applied=%s failed=%s"):format(
        tostring(B.IsSuiteReady()), tostring(B.IsMasterOn()), tostring(B.IsEntryOn()),
        tostring(S ~= nil), tostring(applied), tostring(paintFailed ~= nil))
end

-- A paint that waited out a stand-down happens on the way back up.
NS.STAND_UP[#NS.STAND_UP + 1] = function() Skin.TryApply() end

-- EllesmereUI's callback (it pcalls it): keep S and paint if everything holds.
Skin.registered = NS.EUIBridge.Register(function(facade)
    S = facade
    Skin.TryApply()
end)
