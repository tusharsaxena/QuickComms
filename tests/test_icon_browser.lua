-- tests/test_icon_browser.lua — settings/IconBrowser.lua, the adapter over LibKa0s-IconBrowser-1.0
-- (LibKa0s v1.86.0): the one browser this addon builds with `IB:New`, its host spec (the brand, the
-- modal band over the callout popup, the chat line, the combat test, the timer, the copy window and
-- the color picker's tracking), and what the host still owns: opening it through Settings.IconBrowser,
-- the popup's Escape lift, what closes it (the popup, the settings window, a profile change, a deleted
-- member, a stand-down) and the glyph helpers' aliases. The browser itself (its tabs, grid, search,
-- sets, tooltips and footer) is the library's and is tested there (LibKa0s tests/test_icon_browser.lua
-- and tests/test_icon_browser_sources.lua). Driven headlessly through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function boot()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    m.SettingsPanel:Show()
    return NS, m, P, NS.addon.Settings.IconBrowser
end

-- Open the browser on its own, as an opener does: answers the choices it hands back.
local function openOn(B, icon, color, extra)
    local chosen = {}
    local req = { icon = icon, color = color, owner = "test",
        onChoose = function(i, c) chosen[#chosen + 1] = { i, c } end }
    for k, v in pairs(extra or {}) do req[k] = v end
    assertTrue(B.Open(req))
    return chosen
end

-- The shown cell drawing `icon`, or nil.
local function cellFor(B, icon)
    for _, c in ipairs(B.cells) do
        if c:IsShown() and c.ibIcon == icon then return c end
    end
    return nil
end

-- Record the strata, and the last level, each frame created from here on is set to.
local function strata(m)
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        rawset(f, "SetFrameStrata", function(self, v) rawset(self, "__strata", v); return self end)
        local setLevel = f.SetFrameLevel
        rawset(f, "SetFrameLevel", function(self, v)
            rawset(self, "__setLevel", v)
            return setLevel(self, v)
        end)
        return f
    end
end

local function levelOf(f) return rawget(f, "__setLevel") end

local function listed(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- ── the library's browser, built with the host's spec ───────────────────────────────────────

test("icon browser: Settings.IconBrowser is one LibKa0s browser, built with the host's spec", function()
    local NS, m, _, B = boot()
    local IB = m.LibStub("LibKa0s-IconBrowser-1.0")
    -- red under: keep the browser in settings/IconBrowser.lua (no IB:New)
    assertTrue(type(B.Browser) == "function", "the adapter hands out the library's browser")
    local b = B.Browser()
    assertTrue(b ~= nil, "the library's browser")
    assertTrue(B.Browser() == b, "one browser for the session")
    assertEqual(b.owner, "QuickComms", "the addon's folder: its skin owner and its glyphs' path")
    assertEqual(b.spec.title, NS.BRAND, "titled the brand")
    assertEqual(b.name, "QuickCommsIconBrowser")
    local LAYERS = NS.Constants.LAYERS
    assertEqual(b.layers.strata, LAYERS.STRATA.MODAL, "the modals' strata")
    assertEqual(b.layers.over, LAYERS.LEVEL.MODAL_OVER, "the band over the popup's")
    assertEqual(b.layers.popup, LAYERS.STRATA.POPUP, "the link window's tier")
    assertTrue(b.helpers == NS.addon.Settings.Helpers, "the addon's Options instance")
    local keys = {}
    for i, t in ipairs(b.tabs) do keys[i] = t.key end
    assertEqual(table.concat(keys, ","), table.concat(IB.BUILTIN_TABS, ","), "the three built-in tabs, none hidden")
    assertEqual(B.COLS, 12)
    assertEqual(B.ROWS, 7)
    openOn(B, SKULL)
    assertTrue(B.frame == b.frame and B.catcher == b.catcher and B.ctx == b.ctx, "its frames read through")
    assertEqual(B.State().selected, SKULL)
    B.Cancel()
    -- red under: leave settings/IconBrowser_Sources.lua and Compat.MacroIcons behind
    assertNil(NS.addon.Settings.IconBrowserSources, "the sources are the library's")
    assertNil(NS.Compat.MacroIcons, "and so are the macro icon lists")
end)

test("icon browser: the window is the popup's chrome, stacked above the popup and its catcher", function()
    local NS, m, P, B = boot()
    strata(m)
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    assertTrue(B.IsOpen())
    assertEqual(B.frame.__template, "SettingsFrameTemplate")
    -- red under: build the browser with no spec.title (the library titles it with the owner's folder)
    assertEqual(B.frame.NineSlice.Text.text, "Ka0s Quick Comms", "the window title is the addon's")
    assertEqual(B.ctx.panel.title:GetText(), "Choose an icon", "the page header")
    assertEqual(Pop.catcher.__strata, "FULLSCREEN")
    assertEqual(Pop.frame.__strata, "FULLSCREEN")
    -- red under: no spec.layers (the library's default is DIALOG, under the popup)
    assertEqual(B.catcher.__strata, "FULLSCREEN", "the browser shares the popup's strata")
    assertEqual(B.frame.__strata, "FULLSCREEN")
    -- red under: spec.layers.level = MODAL: the two would tie, level for level
    assertTrue(levelOf(B.catcher) > levelOf(Pop.frame), "the browser's catcher is above the popup")
    assertEqual(B.frame.__parent, B.catcher, "above its own catcher")
    assertTrue(B.catcher:IsShown())
    B.frame.ClosePanelButton:__fire("OnClick")
    assertFalse(B.IsOpen(), "the close X cancels")
    assertFalse(B.catcher:IsShown())
    assertTrue(Pop.IsOpen(), "the popup stays open")
end)

-- The client's strata, bottom to top: inside one strata the higher level wins, across two the higher
-- strata wins whatever the levels.
local STRATA_ORDER = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
-- What the client sets the frames QuickComms does not create to: Blizzard's settings window.
local SETTINGS_STRATA = "HIGH"

local function above(a, b, what)
    assertTrue(STRATA_ORDER[a] ~= nil and STRATA_ORDER[b] ~= nil, what .. ": a known strata")
    assertTrue(STRATA_ORDER[a] > STRATA_ORDER[b], what .. " (" .. tostring(a) .. " over " .. tostring(b) .. ")")
end

test("icon browser: the popup and the browser stack above the preview dial by band (QC-06, #14)", function()
    local NS, m, P, B = boot()
    strata(m)
    local header = NS.SendEngine.NewDialHeader("QuickCommsStrataTestDial")
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    assertTrue(B.IsOpen())
    local LAYERS = NS.Constants.LAYERS
    local dial = header.__strata
    assertEqual(dial, LAYERS.STRATA.HUD_POPUP, "the dial's secure header keeps its strata")
    local hub = levelOf(header) + LAYERS.LEVEL.DIAL_FRONT
    for _, f in ipairs({ { Pop.catcher, "popup catcher" }, { Pop.frame, "popup" },
        { B.catcher, "browser catcher" }, { B.frame, "browser" } }) do
        assertEqual(f[1].__strata, dial, f[2] .. " shares the dial's strata")
        assertTrue(levelOf(f[1]) > hub, f[2] .. " over the dial's hub")
        above(f[1].__strata, LAYERS.STRATA.HUD, f[2] .. " over the pads")
        above(f[1].__strata, SETTINGS_STRATA, f[2] .. " over the settings window")
    end
    -- settings < popup < browser: the browser's band of levels clears the popup's, with room for
    -- the popup's nested widgets
    assertTrue(levelOf(B.catcher) - levelOf(Pop.frame) >= 50, "the browser's band")
    above("FULLSCREEN_DIALOG", B.frame.__strata, "the browser's transients")
end)

test("icon browser: a click selects, a double-click chooses; Choose hands the opener the icon", function()
    local _, _, _, B = boot()
    local chosen = openOn(B, nil)
    local cell = cellFor(B, SKULL)
    cell:__fire("OnClick")
    assertEqual(B.State().selected, SKULL)
    assertTrue(B.Widgets().name:GetText():find("Skull", 1, true) ~= nil, "named in the footer")
    assertEqual(#chosen, 0, "a click only selects")
    B.Widgets().choose:__fire("OnClick")
    assertEqual(#chosen, 1)
    assertEqual(chosen[1][1], SKULL)
    assertNil(chosen[1][2], "a marker carries no color")
    assertFalse(B.IsOpen())
    chosen = openOn(B, nil)
    cellFor(B, SKULL):__fire("OnDoubleClick")
    assertEqual(chosen[1][1], SKULL, "a double-click chooses")
    chosen = openOn(B, nil)
    local ok, why = B.Choose()
    assertFalse(ok)
    assertEqual(why, "noSelection")
    B.Widgets().cancel:__fire("OnClick")
    assertFalse(B.IsOpen())
    assertEqual(#chosen, 0, "Cancel hands nothing back")
end)

-- ── the host's hooks: the color picker, the copy window, the chat line ──────────────────────

-- A stand-in for Blizzard's ColorPickerFrame (its OnHide runs when a shown frame hides), and a click
-- on `swatch` that opens it, as AceGUI's does.
local function picker(m)
    local f = m.CreateFrame("Frame")
    local hide = f.Hide
    rawset(f, "Hide", function(self)
        local was = self:IsShown()
        hide(self)
        if was then self:__fire("OnHide") end
        return self
    end)
    f:Hide()
    m.ColorPickerFrame = f
    return f
end

local function openPicker(f, swatch)
    f:Hide()
    f:Show()
    swatch.frame:__fire("OnClick")
end

test("icon browser: the swatch is tracked by the editors' picker, which closes with the browser", function()
    local NS, m, _, B = boot()
    local f = picker(m)
    local Ed = NS.addon.Settings.Editors
    openOn(B, nil)
    B.SetTab("glyphs")
    local swatch = B.Widgets().swatch
    -- red under: no spec.trackPicker (the library tracks the swatch itself)
    assertTrue(Ed.PickerTracked(swatch), "the editors track the browser's swatch")
    openPicker(f, swatch)
    B.Cancel()
    assertFalse(f:IsShown(), "the picker goes with the browser")
    openOn(B, nil)
    f:Show()
    B.Cancel()
    assertTrue(f:IsShown(), "a picker the swatch did not open is left alone")
    m.ColorPickerFrame = nil
end)

test("icon browser: a chooser's swatch released with the picker up hides it and lets the swatch go", function()
    local NS, m, P = boot()
    local f = picker(m)
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = NS.Icon("star"), iconColor = "ff0000" })
    local AceGUI = NS.addon.Settings.Helpers.AceGUI
    local Ed = NS.addon.Settings.Editors
    local Pop = NS.addon.Settings.CalloutPopup
    local w = P.during(function() Pop.Open(gid) end)
    Pop.SetIcon(NS.Icon("star"), "ff8000")
    local swatch = P.find(w, "ColorPicker", "Icon color")
    openPicker(f, swatch)
    AceGUI:Release(swatch)
    -- red under: no OnRelease on the chooser's swatch
    assertFalse(f:IsShown(), "the picker goes with its swatch")
    assertFalse(Ed.PickerTracked(swatch), "the pooled swatch is no longer ours")
    m.ColorPickerFrame = nil
end)

test("icon browser: the Wowhead address shows in the addon's copy window, over the browser", function()
    local _, m, _, B = boot()
    strata(m)
    openOn(B, nil)
    B.SetTab("game")
    local win = B.LinkWindow()
    local shown
    local show = win.Show
    win.Show = function(self, text)
        shown = text
        return show(self, text)
    end
    B.Widgets().link:__fire("OnClick")
    assertEqual(shown, "https://www.wowhead.com/icons")
    -- red under: no spec.copyWindow (the library names the window after the browser)
    local f = m.__named.QuickCommsIconLinkWindow
    assertTrue(f ~= nil and f:IsShown())
    assertEqual(f.__strata, "FULLSCREEN_DIALOG", "above the browser")
    -- red under: no LINK_TITLE in spec.L (the library's title would read "Ka0s Quick Comms: ...")
    assertEqual(f.title:GetText(), "Quick Comms: Wowhead icons", "the window's title, as before")
    B.Cancel()
    assertFalse(f:IsShown(), "it goes with the browser")
end)

test("icon browser: Choose is refused in combat; the chat line is the addon's print", function()
    local NS, m, _, B = boot()
    local chosen = openOn(B, nil)
    B.Select(SKULL)
    m.__setCombat(true)
    local ok, why = B.Choose()
    assertFalse(ok)
    assertEqual(why, "combat")
    assertEqual(#chosen, 0)
    assertTrue(B.IsOpen(), "the browser stays open under the cover")
    -- red under: no spec.print (the library prints nothing)
    assertTrue(table.concat(m.prints, "\n"):find("cannot choose an icon during combat", 1, true) ~= nil)
    m.__setCombat(false)
    assertTrue(B.Choose())
    assertEqual(chosen[1][1], SKULL)
    assertTrue(NS.Compat.InCombat() == false)
end)

-- ── what closes it (the host's handlers) ────────────────────────────────────────────────────

test("icon browser: Escape over the popup closes the browser only; the popup's Escape comes back after", function()
    local NS, m, P, B = boot()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    assertTrue(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"))
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    assertFalse(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"), "the popup is out of Escape's list")
    assertTrue(listed(m.UISpecialFrames, "QuickCommsIconBrowser"))
    for _, name in ipairs(m.UISpecialFrames) do
        local f = m.__named[name]
        if f and f:IsShown() then
            f:Hide()
            f:__fire("OnHide")
        end
    end
    assertFalse(B.IsOpen(), "the browser closed")
    assertTrue(Pop.IsOpen(), "the popup did not")
    assertFalse(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"), "back on the next frame, not now")
    -- red under: no spec.schedule (C_Timer.After, which the harness's flush does not run)
    P.flush()
    assertTrue(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"), "the popup's Escape is back")
end)

test("icon browser: the popup closing, the settings window hiding, a profile change and a deletion close it", function()
    local NS, m, P, B = boot()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local closers = {
        function() Pop.Cancel() end,
        -- red under: drop the SettingsPanel OnHide hook in settings/IconBrowser.lua
        function() m.SettingsPanel:__fire("OnHide") end,
        -- red under: drop the PROFILE_CHANGED handler
        function() NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED) end,
        -- red under: drop the LIBRARY_CHANGED handler (Revalidate)
        function() NS.Library.DeleteGroup(gid) end,
    }
    for i, closeIt in ipairs(closers) do
        if not NS.db.profile.groups[gid] then gid = NS.Library.CreateGroup({ name = "Mine" }) end
        local w = P.during(function() Pop.Open(gid) end)
        P.find(w, "Button", "Choose icon…"):__fire("OnClick")
        B.Select(SKULL)
        closeIt()
        assertFalse(B.IsOpen(), "closer " .. i)
        assertFalse(Pop.IsOpen(), "closer " .. i)
    end
end)

test("icon browser: a popup that closes leaves a browser opened by another owner alone", function()
    local NS, _, _, B = boot()
    local Pop = NS.addon.Settings.CalloutPopup
    openOn(B, nil)
    Pop.Cancel()
    B.Cancel("popup")
    assertTrue(B.IsOpen(), "Cancel(owner) closes only that owner's browser")
    NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
    assertFalse(B.IsOpen(), "a profile change closes any")
end)

test("icon browser: a stand-down closes it and refuses an open; a stand-up lets it open again", function()
    local NS, _, _, B = boot()
    openOn(B, nil)
    NS.SchemaRuntime.Set("enabled", false)
    -- red under: drop the browser's NS.STAND_DOWN entry
    assertFalse(B.IsOpen())
    -- red under: Cancel alone on a stand-down (the library's StandDown also refuses an open)
    assertFalse(B.Open({ owner = "test", onChoose = function() end }), "refused while stood down")
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(B.Open({ owner = "test", onChoose = function() end }), "it opens again after a stand-up")
end)

-- ── the glyph helpers: aliases of the library's ─────────────────────────────────────────────

test("icon browser: Library's glyph helpers answer as the library's, with the addon's reason code", function()
    local NS, m = boot()
    local IB = m.LibStub("LibKa0s-IconBrowser-1.0")
    local Lib = NS.Library
    local star = NS.Icon("star")
    assertEqual(Lib.IsGlyph(star), IB.IsGlyph(star))
    -- red under: keep Library's own glyph map (it reads only this addon's folder)
    local other = "Interface\\AddOns\\OutfitterReborn\\libs\\LibKa0s\\media\\icons\\star"
    assertEqual(Lib.IsGlyph(other), "star", "a glyph path at another Ka0s addon's folder")
    assertEqual(Lib.IconColorFrom(1, 0.5, 0), "ff8000")
    assertEqual(Lib.IconColorFrom(1, 1, 1), false, "white is none")
    assertEqual(table.concat({ Lib.IconTint(star, "ff0000") }, ","), "1,0,0")
    assertEqual(table.concat({ Lib.IconTint(SKULL, "ff0000") }, ","), "1,1,1", "a marker is never tinted")
    local ok, why = Lib.ValidIconColor("FF0000")
    assertFalse(ok)
    assertEqual(why, "badIconColor", "the addon's reason code, not the library's badColor")
end)
