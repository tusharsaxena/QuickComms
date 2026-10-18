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
    -- red under: keep the Suggested tab in B.TABS
    assertEqual(table.concat(keys, ","), "markers,game,glyphs")
    local cases = {
        { nil, "markers" }, { SKULL, "markers" }, { NS.Icon("star"), "glyphs" }, { 136116, "game" },
    }
    for _, case in ipairs(cases) do
        openOn(B, case[1])
        -- red under: open every browser on the first tab
        assertEqual(B.State().tab, case[2], tostring(case[1]))
        assertEqual(B.State().selected, case[1])
        if case[1] then assertTrue(cellFor(B, case[1]).selected:IsShown(), "drawn selected") end
        B.Cancel()
    end
    -- an icon no tab lists (a built-in set's spell icon, a typed path): Markers, nothing selected
    for _, icon in ipairs({ "Interface\\Icons\\Spell_Nature_Bloodlust", "Interface\\Icons\\Whatever" }) do
        openOn(B, icon)
        assertEqual(B.State().tab, "markers", icon)
        -- red under: keep req.icon as the selection when Src.TabFor finds no tab for it
        assertNil(B.State().selected, icon)
        assertTrue(B.Widgets().choose.disabled, "Choose waits for a click")
        B.Cancel()
    end
    -- a key that is not a tab is refused
    openOn(B, nil)
    B.SetTab("suggested")
    assertEqual(B.State().tab, "markers")
    B.Cancel()
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

test("icon browser: Markers is the eight raid markers, in order; no Suggested list is left", function()
    local NS, _, _, _, Src = boot()
    local list = Src.Markers()
    assertEqual(list[1], "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    assertEqual(list[8], SKULL)
    assertEqual(#list, 8)
    -- red under: keep Src.Suggested in settings/IconBrowser_Sources.lua
    assertNil(Src.Suggested)
    assertNil(Src.TabFor("Interface\\Icons\\Spell_Nature_Bloodlust"), "a built-in set's spell icon is on no tab")
    assertEqual(Src.Label(SKULL), "Skull", "a raid marker carries its localized name")
    assertEqual(Src.Label(NS.Icon("speech-bubble")), "Speech bubble", "a curated glyph its localized label")
end)

test("icon browser: the grid sits a section gap under the toolbar's row", function()
    local _, _, _, B = boot()
    openOn(B, nil)
    local grid, area = B.Widgets().grid, B.Widgets().area
    local point, rel, relPoint, x, y = grid:GetPoint(1)
    assertEqual(point, "TOPLEFT")
    assertEqual(rel, area)
    assertEqual(relPoint, "TOPLEFT")
    assertEqual(x, 0)
    -- red under: put the grid straight under the 30px toolbar band (the swatch row touched it)
    assertTrue(-y >= 30 + 8, "at least 8px between the toolbar band and the grid, got " .. tostring(-y))
    assertEqual(-y, B.GRID_TOP)
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

test("icon browser: a scroll under the pointer re-says the hovered cell's tooltip, or hides it", function()
    local _, m, _, B = boot()
    local spells = {}
    for i = 1, 500 do spells[i] = 300000 + i end
    m.macroIcons, m.macroItemIcons = spells, {}
    local tip, said, owner = m.GameTooltip, {}, nil
    rawset(tip, "SetOwner", function(_, o) owner = o end)
    rawset(tip, "GetOwner", function() return owner end)
    rawset(tip, "SetText", function(_, text) said[#said + 1] = text end)
    openOn(B, nil)
    B.SetTab("game")
    local cell = B.cells[#B.cells]
    cell:__fire("OnEnter")
    assertEqual(said[#said], "Texture id " .. cell.qcIcon)
    B.Widgets().grid:__fire("OnMouseWheel", -1)
    -- red under: leave the tooltip as OnEnter said it (draw() not refreshing the owner's tooltip)
    assertEqual(said[#said], "Texture id " .. cell.qcIcon, "the tooltip follows the cell's new icon")
    assertTrue(tip:IsShown())
    -- the last page leaves the last cell empty (500 is not a whole number of rows): the tooltip goes
    assertTrue(500 % B.COLS ~= 0, "the fixture leaves the last row short")
    B.Widgets().slider:__fire("OnValueChanged", 99999)
    assertFalse(cell:IsShown())
    assertFalse(tip:IsShown(), "an emptied cell keeps no tooltip")
end)

test("icon browser: a long name in the footer stops at the Choose button, on one line", function()
    local _, m, _, B = boot()
    -- Record what the browser asks of its font strings (the harness does not record their points).
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        local make = f.CreateFontString
        f.CreateFontString = function(...)
            local fs = make(...)
            fs.__pts = {}
            fs.SetPoint = function(self, ...) self.__pts[#self.__pts + 1] = { ... }; return self end
            fs.SetWordWrap = function(self, v) self.__wrap = v; return self end
            return fs
        end
        return f
    end
    openOn(B, "Interface\\Icons\\Ability_Warrior_BattleShout")
    m.CreateFrame = create
    local w = B.Widgets()
    local right
    for _, p in ipairs(w.name.__pts or {}) do if p[1] == "RIGHT" then right = p end end
    -- red under: anchor the name on its left side only
    assertTrue(right ~= nil, "the name has a right edge")
    assertEqual(right[2], w.choose.frame, "at the Choose button")
    assertEqual(w.name.__wrap, false, "a long name is cut, not wrapped")
end)

test("icon browser: the wheel over the scrollbar scrolls the grid too", function()
    local _, m, _, B = boot()
    local spells = {}
    for i = 1, 500 do spells[i] = 200000 + i end
    m.macroIcons, m.macroItemIcons = spells, {}
    openOn(B, nil)
    B.SetTab("game")
    local slider = B.Widgets().slider
    -- red under: enable the wheel on the grid alone (the scrollbar is its sibling, not its child)
    assertTrue(slider.__scripts.OnMouseWheel ~= nil, "the scrollbar takes the wheel")
    slider:__fire("OnMouseWheel", -2)
    assertEqual(B.State().offset, 2)
    slider:__fire("OnMouseWheel", 1)
    assertEqual(B.State().offset, 1)
end)

test("icon browser: a filtered game list holds each icon once (the loose lists overlap the full ones)", function()
    local _, m, _, B, Src = boot()
    m.macroIcons, m.macroItemIcons = { 1, 2 }, { 4 }
    m.GetLooseMacroIcons = function(t) t[#t + 1] = 9; t[#t + 1] = 1 end
    -- red under: hand the Spells filter source("spells") as it is
    assertEqual(table.concat(Src.GameIcons("spells"), ","), "9,1,2")
    assertEqual(table.concat(Src.GameIcons("all"), ","), "9,1,2,4")
    openOn(B, nil)
    B.SetTab("game")
    B.SetFilter("spells")
    assertEqual(B.State().count, 3, "the count is of distinct icons")
    m.GetLooseMacroIcons = nil
end)

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

test("icon browser: the color picker its swatch opened closes with the browser, and only that one", function()
    local _, m, _, B = boot()
    local f = picker(m)
    openOn(B, nil)
    B.SetTab("glyphs")
    openPicker(f, B.Widgets().swatch)
    B.Cancel()
    -- red under: leave ColorPickerFrame up in close()
    assertFalse(f:IsShown(), "the picker goes with the browser")
    -- a picker the swatch did not open (another addon's) is left alone
    openOn(B, nil)
    f:Show()
    B.Cancel()
    assertTrue(f:IsShown())
    f:Hide()
    -- the picker closed by its own OK/Cancel first: nothing is left to hide later
    openOn(B, nil)
    B.SetTab("glyphs")
    openPicker(f, B.Widgets().swatch)
    f:Hide()
    f:Show()                 -- someone else's, now
    B.Cancel()
    assertTrue(f:IsShown(), "the OnHide forgot the swatch")
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
    B.SetTab("markers")
    -- red under: show the swatch on Markers (SWATCH_TABS)
    assertFalse(w.swatch.frame:IsShown(), "Markers holds no glyph")
    assertEqual(table.concat(cellFor(B, SKULL).icon.__color, ",", 1, 3), "1,1,1", "a marker stays white")
    B.SetTab("glyphs")
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

test("icon browser: the area follows the tab band when the chrome learns its width (first open)", function()
    local NS, _, _, B = boot()
    openOn(B, nil)
    local area = B.Widgets().area
    local before = area.__points[1][5]
    local gap = NS.addon.Settings.Helpers.CHROME_GAP or 8
    -- the chrome had no width, so every tab took its own row; the width arrives and the library
    -- re-places the strip on one row (SetChromeHeight)
    B.ctx.chrome:__fire("OnSizeChanged", 700, B.ctx.chromeHeight)
    -- red under: anchor the area once in drawTabs with no OnSizeChanged hook on the chrome
    assertEqual(area.__points[1][5], -(gap + B.ctx.chromeHeight), "the area sits under the new band")
    assertTrue(area.__points[1][5] > before, "the band got shorter, so the area moved up")
end)

test("icon browser: Compat.MacroIcons reads the loose lists first, as the macro icon selector does", function()
    local NS, m = boot()
    m.macroIcons = { 1, 2 }
    m.GetLooseMacroIcons = function(t) t[#t + 1] = 9; t[#t + 1] = 1 end
    -- red under: read GetMacroIcons alone, or the loose list after it
    assertEqual(table.concat(NS.Compat.MacroIcons("spells"), ","), "9,1,1,2")
    m.GetLooseMacroItemIcons = function() return { 5 } end
    assertEqual(table.concat(NS.Compat.MacroIcons("items"), ","), "5,134400,133784,136243")
    m.GetLooseMacroIcons = function() error("changed API") end
    assertEqual(table.concat(NS.Compat.MacroIcons("spells"), ","), "1,2", "a raising loose reader adds nothing")
    m.GetLooseMacroIcons, m.GetLooseMacroItemIcons = nil, nil
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

-- ── search ──────────────────────────────────────────────────────────────────────────────────

test("icon browser: Src.Search matches a marker by name, a glyph by key or label, a game icon by id", function()
    local NS, _, _, _, Src = boot()
    local markers = Src.Markers()
    -- red under: no Src.Search in settings/IconBrowser_Sources.lua
    assertEqual(table.concat(Src.Search(markers, "markers", "sk"), ","), SKULL)
    assertEqual(table.concat(Src.Search(markers, "markers", "SKULL"), ","), SKULL, "case-insensitive")
    assertEqual(#Src.Search(markers, "markers", "  "), 8, "a blank search keeps every icon")
    assertEqual(#Src.Search(markers, "markers", nil), 8)
    local glyphs, thumb = Src.Glyphs(), NS.Icon("thumb-up")
    -- red under: match a glyph by its shown label alone ("Thumbs up" holds no "thumb-up")
    assertTrue(listed(Src.Search(glyphs, "glyphs", "thumb-up"), thumb), "by its catalog key")
    -- red under: match a glyph by its catalog key alone ("thumb-up" holds no "thumbs up")
    assertTrue(listed(Src.Search(glyphs, "glyphs", "Thumbs up"), thumb), "by its shown label")
    assertTrue(#Src.Search(glyphs, "glyphs", "thumb") < #glyphs)
    local game = { 132092, 99, 51320, "Interface\\Icons\\Ability_CheapShot" }
    -- red under: compare the typed text with the whole id (no substring)
    assertEqual(table.concat(Src.Search(game, "game", "132"), ","), "132092,51320", "by the id's digits")
    assertEqual(table.concat(Src.Search(game, "game", " 99 "), ","), "99", "trimmed")
    assertEqual(Src.Search(game, "game", "cheapshot")[1], game[4], "a texture path by its name")
    assertEqual(#Src.Search(game, "game", "icons"), 0, "the name only, not the folder")
    assertEqual(#Src.Search(game, "game", "%["), 0, "plain text, never a pattern")
end)

test("icon browser: the search box filters the tab as you type; the count says N of M", function()
    local _, m, _, B = boot()
    local spells = { 132092, 99, 51320, 136116 }
    for i = 1, 2000 do
        if not tostring(700000 + i):find("132", 1, true) then spells[#spells + 1] = 700000 + i end
    end
    m.macroIcons, m.macroItemIcons = spells, {}
    openOn(B, nil)
    B.SetTab("game")
    local w = B.Widgets()
    -- red under: no search box on the toolbar
    assertTrue(w.search ~= nil and w.search.frame:IsShown(), "the search box")
    assertTrue(w.search.buttonDisabled, "no Okay button: it filters as you type")
    assertEqual(w.count:GetText(), #spells .. " icons", "unfiltered, the count is the tab's")
    assertFalse(w.clear:IsShown(), "no clear mark while empty")
    B.ScrollTo(10)
    w.search:__fire("OnTextChanged", "132")
    assertEqual(B.State().search, "132")
    assertEqual(B.State().count, 2)
    assertEqual(B.State().total, #spells)
    -- red under: keep "%d icons" while a search narrows the tab
    assertEqual(w.count:GetText(), "2 of " .. #spells .. " icons")
    assertEqual(B.State().offset, 0, "the results from the top")
    assertTrue(cellFor(B, 51320) ~= nil)
    assertNil(cellFor(B, 99))
    -- the clear mark empties the box and the search
    assertTrue(w.clear:IsShown())
    w.clear:__fire("OnClick")
    assertEqual(B.State().search, "")
    assertEqual(w.search.text, "", "the box is emptied")
    assertFalse(w.clear:IsShown())
    assertEqual(B.State().count, #spells)
    -- nothing matches: the grid says so
    B.SetSearch("zzz")
    assertEqual(shownCells(B), 0)
    assertTrue(w.status:IsShown())
    assertEqual(w.status:GetText(), "No icon matches your search.")
end)

test("icon browser: the search box keeps its text inset clear of the magnifier after AceGUI resets it", function()
    local _, _, _, B = boot()
    openOn(B, nil)
    B.SetTab("glyphs")
    local w = B.Widgets()
    local input = w.search.editbox or w.search.frame
    local left
    input.SetTextInsets = function(_, l) left = l end
    -- AceGUI's EditBox runs HideButton (insets 0, 0, 3, 3) from SetText, Enter and a drop
    local setText = w.search.SetText
    w.search.SetText = function(self, ...)
        setText(self, ...)
        input:SetTextInsets(0, 0, 3, 3)
    end
    B.SetSearch("x")
    B.SetSearch("")
    -- red under: set the insets once in buildSearch
    assertEqual(left, 14 + 4, "after the clear mark's SetText")
    for _, script in ipairs({ "OnEnterPressed", "OnReceiveDrag" }) do
        input:SetTextInsets(0, 0, 3, 3)
        input:__fire(script)
        assertEqual(left, 14 + 4, "after " .. script)
    end
end)

test("icon browser: Src.Search narrows its last results and memoizes each icon's text", function()
    local Src = select(5, boot())
    local list = { 132092, 99, 51320, 136116, 13209 }
    assertEqual(table.concat(Src.Search(list, "game", "13"), ","), "132092,51320,136116,13209")
    assertEqual(table.concat(Src.Search(list, "game", "1320"), ","), "132092,51320,13209", "narrowed")
    assertEqual(table.concat(Src.Search(list, "game", "2"), ","), "132092,51320,13209", "widened again: the whole list")
    list[#list + 1] = 1320
    assertEqual(table.concat(Src.Search(list, "game", "1320"), ","), "132092,51320,13209,1320", "a grown list")
end)

test("icon browser: the search is kept across tabs and the session's opens, and re-filters each tab", function()
    local NS, _, _, B, Src = boot()
    openOn(B, nil)
    B.SetSearch("star")
    assertEqual(B.State().count, 1, "Markers: the Star")
    assertTrue(cellFor(B, Src.MarkerPath(1)) ~= nil)
    B.SetTab("glyphs")
    -- red under: clear the search on a tab switch
    assertEqual(B.State().search, "star")
    assertEqual(B.State().count, #Src.Search(Src.Glyphs(), "glyphs", "star"))
    assertTrue(cellFor(B, NS.Icon("star")) ~= nil)
    B.Cancel()
    openOn(B, nil)
    -- red under: reset the search in B.Open
    assertEqual(B.State().search, "star", "kept for the session")
    assertEqual(B.Widgets().search.text, "star", "and shown in the box")
    assertEqual(B.State().count, 1)
end)

test("icon browser: Game icons carries the Wowhead hint; its button shows the address in a copy window", function()
    local _, m, _, B = boot()
    strata(m)
    openOn(B, nil)
    local w = B.Widgets()
    -- red under: no hint row
    assertTrue(w.hint ~= nil)
    assertFalse(w.hint:IsShown(), "not on Markers")
    B.SetTab("game")
    assertTrue(w.hint:IsShown(), "on Game icons")
    local said = w.hintText:GetText()
    assertTrue(said:find("Search by texture id.", 1, true) ~= nil)
    assertTrue(said:find("ability_cheapshot", 1, true) ~= nil)
    assertTrue(said:find("Wowhead", 1, true) ~= nil)
    -- between the grid and the footer
    local point, rel, relPoint = w.hint:GetPoint(1)
    assertEqual(point, "TOPLEFT")
    assertEqual(rel, w.grid)
    assertEqual(relPoint, "BOTTOMLEFT")
    B.SetTab("glyphs")
    assertFalse(w.hint:IsShown())
    B.SetTab("game")
    local win = B.LinkWindow()
    local shown
    local show = win.Show
    win.Show = function(self, text)
        shown = text
        return show(self, text)
    end
    w.link:__fire("OnClick")
    -- red under: a link button that shows nothing
    assertEqual(shown, "https://www.wowhead.com/icons")
    local f = m.__named.QuickCommsIconLinkWindow
    assertTrue(f ~= nil and f:IsShown())
    -- red under: leave the copy window in FULLSCREEN, under the browser's catcher
    assertEqual(f.__strata, "FULLSCREEN_DIALOG", "above the browser")
    B.Cancel()
    assertFalse(f:IsShown(), "it goes with the browser")
end)
