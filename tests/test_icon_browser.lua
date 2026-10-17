-- tests/test_icon_browser.lua — settings/IconBrowser.lua and settings/IconBrowser_Sources.lua (icon
-- browser spec): the window over the callout popup or a group's General tab, its four tabs, the
-- virtualized grid, the glyph color, Choose and Cancel, Escape, and what closes it. Driven
-- headlessly through tests/page_helpers.lua.

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
    local S = NS.addon.Settings
    return NS, m, P, S.IconBrowser, S.IconBrowserSources
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
        if c:IsShown() and c.qcIcon == icon then return c end
    end
    return nil
end

local function shownCells(B)
    local n = 0
    for _, c in ipairs(B.cells) do if c:IsShown() then n = n + 1 end end
    return n
end

local function indexOf(list, v)
    for i, x in ipairs(list) do if x == v then return i end end
    return nil
end

-- Record the strata each frame created from here on is set to.
local function strata(m)
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        rawset(f, "SetFrameStrata", function(self, v) rawset(self, "__strata", v); return self end)
        return f
    end
end

local function listed(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- ── the window ──────────────────────────────────────────────────────────────────────────────

test("icon browser: the window is the popup's chrome, stacked above the popup and its catcher", function()
    local NS, m, P, B = boot()
    strata(m)
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    assertTrue(B.IsOpen())
    -- red under: build the browser's window as a plain frame
    assertEqual(B.frame.__template, "SettingsFrameTemplate")
    assertEqual(B.frame.NineSlice.Text.text, "Ka0s Quick Comms", "the window title is the addon's")
    assertEqual(B.ctx.panel.title:GetText(), "Choose an icon", "the page header")
    assertEqual(Pop.catcher.__strata, "DIALOG")
    -- red under: build the browser in the popup's strata (DIALOG): it would share the popup's levels
    assertEqual(B.catcher.__strata, "FULLSCREEN", "the browser's catcher is above the popup")
    assertEqual(B.frame.__strata, "FULLSCREEN")
    assertEqual(B.frame.__parent, B.catcher, "above its own catcher")
    assertTrue(B.catcher:IsShown())
    B.frame.ClosePanelButton:__fire("OnClick")
    assertFalse(B.IsOpen(), "the close X cancels")
    assertFalse(B.catcher:IsShown())
    assertTrue(Pop.IsOpen(), "the popup stays open")
end)

test("icon browser: tabs in order; the stored icon is preselected and its tab opened", function()
    local NS, _, _, B = boot()
    local keys = {}
    for i, t in ipairs(B.TABS) do keys[i] = t.key end
    assertEqual(table.concat(keys, ","), "suggested,markers,game,glyphs")
    local cases = {
        { nil, "suggested" }, { SKULL, "markers" }, { NS.Icon("star"), "glyphs" }, { 136116, "game" },
        { "Interface\\Icons\\Spell_Nature_Bloodlust", "suggested" },
    }
    for _, case in ipairs(cases) do
        openOn(B, case[1])
        -- red under: open every browser on Suggested
        assertEqual(B.State().tab, case[2], tostring(case[1]))
        assertEqual(B.State().selected, case[1])
        if case[1] then assertTrue(cellFor(B, case[1]).selected:IsShown(), "drawn selected") end
        B.Cancel()
    end
    -- the strip is the library's: a tab click shows that tab
    openOn(B, nil)
    local clicked
    for _, b in ipairs(B.ctx.__tabKids) do
        if b.__ka0sTabTipLabel == "Glyphs" then clicked = b end
    end
    -- red under: draw no tab strip (H.TabStrip) in settings/IconBrowser.lua
    assertTrue(clicked ~= nil, "a Glyphs tab")
    clicked:__fire("OnClick")
    assertEqual(B.State().tab, "glyphs")
    B.Cancel()
    -- a color is kept only for a glyph, and only a valid one
    openOn(B, NS.Icon("star"), "ff0000")
    assertEqual(B.State().color, "ff0000")
    B.Cancel()
    openOn(B, SKULL, "ff0000")
    assertNil(B.State().color, "a marker takes no color")
    B.Cancel()
end)

test("icon browser: a click selects, a double-click chooses; Choose hands the opener the icon", function()
    local _, _, _, B = boot()
    local chosen = openOn(B, nil)
    local cell = cellFor(B, SKULL)
    cell:__fire("OnClick")
    assertEqual(B.State().selected, SKULL)
    assertTrue(cell.selected:IsShown(), "highlighted")
    assertTrue(B.Widgets().name:GetText():find("Skull", 1, true) ~= nil, "named in the footer")
    assertFalse(B.Widgets().choose.disabled)
    assertEqual(#chosen, 0, "a click only selects")
    B.Widgets().choose:__fire("OnClick")
    assertEqual(#chosen, 1)
    assertEqual(chosen[1][1], SKULL)
    assertNil(chosen[1][2], "a marker carries no color")
    assertFalse(B.IsOpen())
    chosen = openOn(B, nil)
    cellFor(B, SKULL):__fire("OnDoubleClick")
    assertEqual(chosen[1][1], SKULL, "a double-click chooses")
    assertFalse(B.IsOpen())
    -- nothing selected: Choose is idle
    chosen = openOn(B, nil)
    assertTrue(B.Widgets().choose.disabled)
    local ok, why = B.Choose()
    assertFalse(ok)
    assertEqual(why, "noSelection")
    B.Widgets().cancel:__fire("OnClick")
    assertFalse(B.IsOpen())
    assertEqual(#chosen, 0, "Cancel hands nothing back")
end)

test("icon browser: hovering an icon names it, or gives a game icon's texture id", function()
    local _, m, _, B = boot()
    local said = {}
    rawset(m.GameTooltip, "SetText", function(_, text) said[#said + 1] = text end)
    openOn(B, nil)
    cellFor(B, SKULL):__fire("OnEnter")
    assertEqual(said[#said], "Skull")
    B.SetTab("game")
    cellFor(B, 136116):__fire("OnEnter")
    assertEqual(said[#said], "Texture id 136116")
end)

-- ── the tabs' icons ─────────────────────────────────────────────────────────────────────────

test("icon browser: Suggested is the markers, the built-in sets' icons and the curated glyphs; Markers the eight", function()
    local NS, _, _, _, Src = boot()
    local list = Src.Suggested()
    assertEqual(list[1], "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    assertEqual(list[8], SKULL)
    assertTrue(indexOf(list, "Interface\\Icons\\Spell_Nature_Bloodlust") ~= nil, "a built-in set's own icon")
    assertTrue(indexOf(list, NS.Icon("chat")) ~= nil, "a curated glyph")
    assertNil(indexOf(list, NS.Icon("close")), "the catalog's window chrome is not suggested")
    assertNil(indexOf(list, "Interface\\Icons\\INV_Misc_QuestionMark"))
    assertEqual(#Src.Markers(), 8)
    assertEqual(Src.Label(SKULL), "Skull", "a raid marker carries its localized name")
    assertEqual(Src.Label(NS.Icon("speech-bubble")), "Speech bubble", "a curated glyph its localized label")
end)

test("icon browser: Glyphs is every catalog icon, labeled from its key", function()
    local NS, _, _, B, Src = boot()
    local names = NS.IconNames()
    assertTrue(#names > 100, "the vendored catalog")
    -- red under: offer only the curated glyphs (GLYPH_LABELS) on the Glyphs tab
    assertEqual(#Src.Glyphs(), #names)
    assertEqual(Src.Label(NS.Icon("arrow-circle-down")), "Arrow circle down")
    assertEqual(Src.Label(NS.Icon("close")), "Close")
    assertEqual(Src.Label(NS.Icon("thumb-up")), "Thumbs up", "the curated label where there is one")
    openOn(B, nil)
    B.SetTab("glyphs")
    assertEqual(B.State().count, #names)
    assertEqual(B.Widgets().count:GetText(), #names .. " icons")
end)

test("icon browser: Game icons is both macro lists, filtered All / Spells / Items", function()
    local _, m, _, B, Src = boot()
    m.macroIcons, m.macroItemIcons = { 1, 2, 3 }, { 3, 4, "Interface\\Icons\\X" }
    local all = Src.GameIcons("all")
    -- red under: read GetMacroIcons alone
    assertEqual(table.concat(all, ","), "1,2,3,4", "spells, then items, each once, texture ids only")
    assertEqual(table.concat(Src.GameIcons("spells"), ","), "1,2,3")
    assertEqual(table.concat(Src.GameIcons("items"), ","), "3,4")
    openOn(B, nil)
    B.SetTab("game")
    assertTrue(B.Widgets().filter.frame:IsShown(), "the filter shows on Game icons")
    assertFalse(B.Widgets().swatch.frame:IsShown(), "game icons take no color")
    assertEqual(B.State().count, 4)
    B.Widgets().filter:__fire("OnValueChanged", "items")
    assertEqual(B.State().filter, "items")
    assertEqual(B.State().count, 2)
    assertTrue(cellFor(B, 4) ~= nil)
    assertNil(cellFor(B, 1))
    B.SetTab("markers")
    assertFalse(B.Widgets().filter.frame:IsShown())
end)

test("icon browser: the game list not loaded yet says so, and loads on a later visit", function()
    local _, m, _, B = boot()
    m.macroIcons, m.macroItemIcons = {}, {}
    openOn(B, nil)
    B.SetTab("game")
    assertFalse(B.State().loaded)
    assertEqual(shownCells(B), 0)
    -- red under: say "Nothing to show here." for a list the client has not loaded
    assertTrue(B.Widgets().status:IsShown())
    assertTrue(B.Widgets().status:GetText():find("not loaded yet", 1, true) ~= nil)
    -- review focus 2: an empty answer is not kept; the next visit asks again
    m.macroIcons = { 10, 11 }
    B.SetTab("markers")
    B.SetTab("game")
    assertTrue(B.State().loaded)
    assertEqual(B.State().count, 2)
    assertFalse(B.Widgets().status:IsShown())
end)

test("icon browser: the grid is virtualized: a fixed set of cells re-dressed as it scrolls", function()
    local _, m, _, B = boot()
    local spells = {}
    for i = 1, 5000 do spells[i] = 100000 + i end
    m.macroIcons, m.macroItemIcons = spells, {}
    openOn(B, nil)
    local cells = #B.cells
    B.SetTab("game")
    -- red under: build a cell per icon
    assertEqual(#B.cells, cells, "no cell is built for a longer list")
    assertEqual(#B.cells, B.COLS * B.ROWS)
    assertEqual(B.cells[1].qcIcon, 100001)
    local w = B.Widgets()
    w.grid:__fire("OnMouseWheel", -1)
    assertEqual(B.State().offset, 1, "the wheel scrolls a row")
    assertEqual(B.cells[1].qcIcon, 100001 + B.COLS)
    w.slider:__fire("OnValueChanged", 10)
    assertEqual(B.State().offset, 10, "so does the scrollbar")
    assertEqual(B.cells[1].icon.__texture, 100001 + 10 * B.COLS)
    w.slider:__fire("OnValueChanged", 99999)
    local last = math.ceil(5000 / B.COLS) - B.ROWS
    assertEqual(B.State().offset, last, "clamped to the last page")
    w.grid:__fire("OnMouseWheel", 5)
    assertEqual(B.State().offset, last - 5)
    -- the stored icon deep in the list: its row is scrolled to
    B.Cancel()
    openOn(B, 100001 + 40 * B.COLS)
    assertEqual(B.State().offset, 40)
    assertTrue(cellFor(B, 100001 + 40 * B.COLS).selected:IsShown())
end)

-- ── the glyph color ─────────────────────────────────────────────────────────────────────────

test("icon browser: the swatch tints every glyph; Choose hands a glyph its color, white as none", function()
    local NS, _, _, B = boot()
    local star = NS.Icon("star")
    local chosen = openOn(B, star)
    local w = B.Widgets()
    assertTrue(w.swatch.frame:IsShown(), "the swatch shows on Glyphs")
    w.swatch:__fire("OnValueChanged", 0, 1, 0, 1)
    assertEqual(B.State().color, "00ff00")
    local cell = cellFor(B, star)
    -- red under: draw every cell white (no IconTint in dressCell)
    assertEqual(table.concat(cell.icon.__color, ",", 1, 3), "0,1,0")
    assertEqual(table.concat(w.preview.__color, ",", 1, 3), "0,1,0", "the selection is drawn in it")
    B.SetTab("suggested")
    assertTrue(w.swatch.frame:IsShown(), "Suggested holds glyphs too")
    assertEqual(table.concat(cellFor(B, NS.Icon("chat")).icon.__color, ",", 1, 3), "0,1,0")
    assertEqual(table.concat(cellFor(B, SKULL).icon.__color, ",", 1, 3), "1,1,1", "a marker stays white")
    B.Choose()
    assertEqual(chosen[1][1], star)
    assertEqual(chosen[1][2], "00ff00")
    chosen = openOn(B, star, "ff0000")
    B.Widgets().swatch:__fire("OnValueConfirmed", 1, 1, 1, 1)
    assertNil(B.State().color, "white is none")
    B.Choose()
    assertNil(chosen[1][2])
    -- a non-glyph chosen carries no color, whatever the swatch says
    chosen = openOn(B, star, "ff0000")
    B.Select(SKULL)
    B.Choose()
    assertNil(chosen[1][2])
end)

-- ── what closes it ──────────────────────────────────────────────────────────────────────────

test("icon browser: Escape over the popup closes the browser only; the popup's Escape comes back after", function()
    local NS, m, P, B = boot()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    assertTrue(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"))
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    -- red under: leave the popup's special frame listed (Escape hides every shown one)
    assertFalse(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"), "the popup is out of Escape's list")
    assertTrue(listed(m.UISpecialFrames, "QuickCommsIconBrowser"))
    -- Escape, as the client does it: every listed special frame that is shown is hidden
    for _, name in ipairs(m.UISpecialFrames) do
        local f = m.__named[name]
        if f and f:IsShown() then
            f:Hide()
            f:__fire("OnHide")
        end
    end
    assertFalse(B.IsOpen(), "the browser closed")
    assertTrue(Pop.IsOpen(), "the popup did not")
    -- red under: put the name back at once (inside the client's walk of the list)
    assertFalse(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"), "back on the next frame, not now")
    P.flush()
    assertTrue(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"), "the popup's Escape is back")
    -- opened and closed again before the next frame: listed once
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    B.Cancel()
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    assertFalse(listed(m.UISpecialFrames, "QuickCommsCalloutPopup"), "still out while open")
    B.Cancel()
    P.flush()
    local n = 0
    for _, name in ipairs(m.UISpecialFrames) do if name == "QuickCommsCalloutPopup" then n = n + 1 end end
    assertEqual(n, 1)
end)

test("icon browser: the popup closing closes it as Cancel", function()
    local NS, m, P, B = boot()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local closers = {
        function() Pop.Cancel() end,
        function() m.SettingsPanel:__fire("OnHide") end,
        function() NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED) end,
        function() NS.Library.DeleteGroup(gid) end,
    }
    for i, closeIt in ipairs(closers) do
        if not NS.db.profile.groups[gid] then gid = NS.Library.CreateGroup({ name = "Mine" }) end
        local w = P.during(function() Pop.Open(gid) end)
        P.find(w, "Button", "Choose icon…"):__fire("OnClick")
        B.Select(SKULL)
        closeIt()
        -- red under: drop the Cancel("popup") in settings/CalloutPopup.lua's close
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

test("icon browser: Choose is refused in combat; nothing is written", function()
    local NS, m, _, B = boot()
    local chosen = openOn(B, nil)
    B.Select(SKULL)
    m.__setCombat(true)
    local ok, why = B.Choose()
    -- red under: drop the combat refusal in B.Choose
    assertFalse(ok)
    assertEqual(why, "combat")
    assertEqual(#chosen, 0)
    assertTrue(B.IsOpen(), "the browser stays open under the cover")
    assertTrue(table.concat(m.prints, "\n"):find("cannot choose an icon during combat", 1, true) ~= nil)
    m.__setCombat(false)
    assertTrue(B.Choose())
    assertEqual(chosen[1][1], SKULL)
    assertTrue(NS.Compat.InCombat() == false)
end)

test("icon browser: a stand-down closes it", function()
    local NS, _, _, B = boot()
    openOn(B, nil)
    NS.SchemaRuntime.Set("enabled", false)
    -- red under: drop the browser's NS.STAND_DOWN entry
    assertFalse(B.IsOpen())
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(B.Open({ owner = "test", onChoose = function() end }), "it opens again after a stand-up")
end)

test("icon browser: Compat.MacroIcons reads both lists, plain texture ids only, never raising", function()
    local NS, m = boot()
    m.macroIcons = { 1, "path", 2 }
    assertEqual(table.concat(NS.Compat.MacroIcons("spells"), ","), "1,2")
    assertEqual(table.concat(NS.Compat.MacroIcons("items"), ","), "134400,133784,136243")
    -- a reader that returns its list instead of filling the table
    m.GetMacroIcons = function() return { 7, 8 } end
    assertEqual(table.concat(NS.Compat.MacroIcons("spells"), ","), "7,8")
    m.GetMacroIcons = function() error("changed API") end
    -- red under: call the reader without pcall
    assertEqual(#NS.Compat.MacroIcons("spells"), 0)
    m.GetMacroItemIcons = nil
    assertEqual(#NS.Compat.MacroIcons("items"), 0)
    assertEqual(#NS.Compat.MacroIcons("other"), 0)
end)

test("icon browser: Library.IconColorFrom stores a picked color as hex, white as none", function()
    local NS = boot()
    local From = NS.Library.IconColorFrom
    assertEqual(From(1, 0, 0), "ff0000")
    assertEqual(From(0, 0.5, 1), "0080ff")
    assertEqual(From(2, -1, 0), "ff0000", "clamped")
    -- red under: store white as "ffffff"
    assertEqual(From(1, 1, 1), false)
end)
