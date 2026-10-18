local _, NS = ...
-- settings/CalloutPopup_Skin.lua — paints the callout popup's window, and the icon browser's
-- (settings/IconBrowser.lua; the same settings/ModalWindow.lua chrome), in the user's EllesmereUI
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
-- Each window is built on its first Open, so S is KEPT and a window is painted when both exist:
-- from the callback, from each window's build, and from the stand-up. A paint is one-way (only a
-- reload removes it), once per window, and every primitive is idempotent and alpha-only (no Hide,
-- no SetParent), on the window's own frames.
--
-- Effective skin, per window = S held AND every gate condition (core/EUIBridge.lua) AND the window
-- built from the settings-window template AND not stood down. The fallback window (a client without
-- the template) keeps its older look: the skin is the settings window's, and that window is not it.

local Settings = NS.addon.Settings
Settings.CalloutPopupSkin = Settings.CalloutPopupSkin or {}
local Skin = Settings.CalloutPopupSkin
local Pop = Settings.CalloutPopup

local TAG = "Skin"
-- Every facade member the paint calls. A facade missing one is refused before anything is painted,
-- so a changed EllesmereUI API leaves the popup stock rather than half-skinned.
local REQUIRED = { "Shell", "FadeNineSlice", "CloseButton", "IsEnabled" }

local S              -- the facade, once EllesmereUI has called back
local painted = {}   -- [window key] = true once painted
local paintFailed    -- the error of a paint that raised: no retry, a reload drops the partial paint

-- The windows the skin paints, in order: each a key and its chrome (nil until the window is built).
local function windows()
    local browser = Settings.IconBrowser
    return { { "popup", Pop.chrome }, { "browser", browser and browser.chrome } }
end

-- Why no paint happens now, or nil when one can.
local function blocked()
    if NS.IsStoodDown() then return "stood down" end
    if not S then return "EllesmereUI has not called back" end
    if paintFailed then return "paint failed earlier: " .. paintFailed end
    for _, name in ipairs(REQUIRED) do
        if type(S[name]) ~= "function" then return "facade lacks " .. name end
    end
    local open, failing = NS.EUIBridge.GateOpen(S)
    if not open then return "condition '" .. tostring(failing) .. "' not met" end
    return nil
end

-- Why window `key` (chrome `chrome`) is not painted now, or nil when it can be.
local function windowBlocked(key, chrome)
    if painted[key] then return "already painted" end
    if not chrome then return key .. " not built yet" end
    if not chrome.template then return key .. ": no settings-window template (the fallback window)" end
    return nil
end

-- The settings window's chrome pass, on what the template drew.
local function paint(chrome)
    S.Shell(chrome.window)
    if chrome.nineSlice then S.FadeNineSlice(chrome.nineSlice) end
    if chrome.bg and chrome.bg.SetAlpha then chrome.bg:SetAlpha(0) end
    if chrome.close then S.CloseButton(chrome.close) end
end

-- Paint one window. Fail closed: a primitive that raises leaves what it painted and latches
-- paintFailed, so no later try paints the same frames twice.
local function paintWindow(key, chrome)
    local ok, err = pcall(paint, chrome)
    if not ok then
        paintFailed = tostring(err)
        NS.Debug(TAG, "%s skin failed: %s", key, paintFailed)
        return false
    end
    painted[key] = true
    NS.Debug(TAG, "%s skinned (EllesmereUI apiVersion %s)", key, tostring(S.apiVersion))
    return true
end

--- Paint every built window not painted yet, when every condition holds. Idempotent; one-way.
--- Called from the EllesmereUI callback, each window's build and the stand-up; cheap when it refuses.
--- @return boolean painted  true only on a call that painted a window
function Skin.TryApply()
    if painted.popup and painted.browser then return false end
    local why = blocked()
    if why then
        NS.DebugChanged("popupskin.skip", TAG, "callout popup skin skipped: %s", why)
        return false
    end
    local any = false
    for _, w in ipairs(windows()) do
        local key, chrome = w[1], w[2]
        local wait = windowBlocked(key, chrome)
        if wait then
            if not painted[key] then NS.DebugChanged("popupskin.skip." .. key, TAG, "skin skipped: %s", wait) end
        elseif paintWindow(key, chrome) then
            any = true
        elseif paintFailed then
            break
        end
    end
    return any
end

--- One line for the diagnostics report: the gate, the facade and the paint (`applied` is the
--- popup's, `browser` the icon browser's). `enabled` is the
--- facade's S.IsEnabled() (EllesmereUI's third-party skinning and this addon's entry together), and
--- reads n/a until EllesmereUI has called back: its switches are not read any other way.
--- @return string
function Skin.Describe()
    local B = NS.EUIBridge
    local enabled = S and tostring(B.IsEnabled(S)) or "n/a"
    return ("ellesmereui: suite=%s facade=%s enabled=%s applied=%s failed=%s browser=%s"):format(
        tostring(B.IsSuiteReady()), tostring(S ~= nil), enabled,
        tostring(painted.popup == true), tostring(paintFailed ~= nil), tostring(painted.browser == true))
end

-- A paint that waited out a stand-down happens on the way back up.
NS.STAND_UP[#NS.STAND_UP + 1] = function() Skin.TryApply() end

-- EllesmereUI's callback (it pcalls it): keep S and paint if everything holds.
NS.EUIBridge.Register(function(facade)
    S = facade
    Skin.TryApply()
end)
