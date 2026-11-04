local addonName, NS = ...
-- settings/IconBrowser.lua — the icon browser (icon browser spec), the library's: an adapter over
-- LibKa0s-IconBrowser-1.0 (LibKa0s v1.86.0, promoted out of this file). It builds the one browser
-- with `IB:New` (core/IconBrowserSetup.lua's seam) and keeps Settings.IconBrowser's surface, so its
-- openers (settings/Editors.lua's chooser, settings/CalloutPopup.lua) did not change.
--
-- The browser (the window, the tabs Markers / Game icons / Glyphs, the toolbar, the virtualized
-- grid, search, the glyph sets and color, the Wowhead hint, the footer, Choose and Cancel, Escape and
-- the opener's `lift`) is the library's: its document is LibKa0s docs/api/IconBrowser/
-- version-1.1.1-docs.md. What is this addon's is the spec handed to it:
--
--     title    NS.BRAND, the window's title
--     layers   the modals' strata and the band over the callout popup's (core/Constants.lua LAYERS:
--              STRATA.MODAL, LEVEL.MODAL_OVER), and POPUP for the link window over it (QC-06, #14;
--              settings/ModalWindow.lua STACKING)
--     helpers  the addon's Options instance (settings/OptionsSetup.lua)
--     print    NS.Print: the combat refusal's gray chat line
--     inCombat NS.Compat.InCombat
--     schedule the addon's AceTimer: an Escape's lift is put back on the next frame
--     copyWindow  NS.MakeCopyWindow, under the window names and title it had here
--     trackPicker / releasePicker  settings/Editors.lua's, so the color picker the swatch opened
--              closes with the browser as a chooser's does
--
-- And what closes it, as Cancel, stays this addon's: its opener closing (the popup's close calls
-- Cancel("popup")), the settings window hiding, a profile change, the opener's member ceasing to
-- exist (LIBRARY_CHANGED, the request's `valid`: Revalidate) and a stand-down (StandDown, which also
-- refuses an Open until the stand-up). The library registers no bus message.
--
-- THE SKIN. The browser draws through this addon's skin owner; its four owner tokens (ib.selStrong,
-- ib.note, ib.markGray, ib.modalDim) are laid onto the owner by the library on the first build, with
-- the values this file's qc.* tokens had.

local QC = NS.addon
local Settings = QC.Settings
local L = NS.L
local LAYERS = NS.Constants.LAYERS

Settings.IconBrowser = Settings.IconBrowser or {}
local B = Settings.IconBrowser

local browser
local down = false
local cancel   -- what closes it, below

-- The words this addon shows differently from the library's English (spec.L, read with rawget).
local WORDS = { LINK_TITLE = L["Quick Comms: Wowhead icons"] }

-- The Wowhead copy window, under the names it had before the promotion.
local function copyWindow(d)
    d.name, d.scrollName = addonName .. "IconLinkWindow", addonName .. "IconLinkScroll"
    return NS.MakeCopyWindow(d)
end

--- The library's browser, built on the first ask, or nil without the major or the Options instance.
--- @return table|nil
function B.Browser()
    if browser then return browser end
    local IB, helpers = NS.IconBrowserLib, Settings.Helpers
    if not (IB.New and type(helpers) == "table") then return nil end
    browser = IB:New({
        owner = addonName, name = addonName .. "IconBrowser", title = NS.BRAND, helpers = helpers, L = WORDS,
        layers = { strata = LAYERS.STRATA.MODAL, over = LAYERS.LEVEL.MODAL_OVER, popup = LAYERS.STRATA.POPUP },
        print = function(line) NS.Print(line) end,
        inCombat = function() return NS.Compat.InCombat() end,
        schedule = function(sec, fn) return QC:ScheduleTimer(fn, sec) end,
        copyWindow = copyWindow,
        trackPicker = function(swatch) Settings.Editors.TrackPicker(swatch) end,
        releasePicker = function(swatch) Settings.Editors.ReleasePicker(swatch) end,
    })
    if down then browser:StandDown() end
    -- The settings window hiding closes it, as Cancel. Hooked when the browser is made, as the
    -- browser was built here before: its openers live in that window, so it exists by then.
    local settingsWindow = _G.SettingsPanel
    if settingsWindow and settingsWindow.HookScript then settingsWindow:HookScript("OnHide", cancel) end
    return browser
end

-- ── the surface, as it was: each call reaches the browser ───────────────────────────────────

-- A method of the browser under Settings.IconBrowser's dot-called name, answering `...` without one.
local function pass(method, ...)
    local fallback = { ... }
    B[method] = function(...)
        local b = B.Browser()
        if not b then return unpack(fallback) end
        return b[method](b, ...)
    end
end

pass("Open", false)
pass("Choose", false, "notOpen")
pass("Cancel")
pass("IsOpen", false)
pass("Select")
pass("SetTab")
pass("SetFilter")
pass("SetGlyphSet")
pass("SetSearch")
pass("SetColor")
pass("ScrollTo")
pass("State")
pass("Widgets")
pass("LinkWindow")

-- The browser's fields, read through: its cells and grid size, and once built its frames.
local FIELDS = { cells = true, COLS = true, ROWS = true, GRID_TOP = true, frame = true, catcher = true,
    chrome = true, ctx = true, tabs = true }
setmetatable(B, { __index = function(_, k)
    if not FIELDS[k] then return nil end
    local b = B.Browser()
    return b and b[k] or nil
end })

-- ── what closes it ──────────────────────────────────────────────────────────────────────────

cancel = function() if browser then browser:Cancel() end end

local HANDLERS = {
    { NS.MSG.LIBRARY_CHANGED, function() if browser then browser:Revalidate() end end },
    { NS.MSG.PROFILE_CHANGED, cancel },
}

-- Its own target (core/Bus.lua): one target holds several different messages.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if not receiver then return end
    for _, h in ipairs(HANDLERS) do receiver:RegisterMessage(h[1], h[2]) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    down = true
    if browser then browser:StandDown() end
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    down = false
    if browser then browser:StandUp() end
    if not NS.Bus.tracked then listen() end
end
