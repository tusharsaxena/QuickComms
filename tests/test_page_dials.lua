-- tests/test_page_dials.lua — settings/Dials.lua (spec §11, §13.1): the dial picker and New dial,
-- General's acts, Groups (Categories or Flat, the priority list), Wheel with the X/Y position, the
-- Binding tab's key capture and its line, and the Preview tab. Driven headlessly through
-- tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Comms Dial")
    NS.addon.Settings.Editors.Select("dial", "d2")
    return NS, m, P
end

local function key(P)
    return P.find(P.tab("dials", "Binding"), "Keybinding", "Key")
end

test("dials page: New dial makes a second dial holding every built-in, selects it, and builds QuickCommsDial2", function()
    local NS, _, P = open()
    P.bannerAction(P.ctx("dials")):__fire("OnClick")
    P.flush()
    local id = NS.State.editing.dial
    assertTrue(id ~= "d2" and NS.db.profile.dials[id] ~= nil)
    assertEqual(NS.db.profile.dials[id].name, "Comms Dial 2")
    assertEqual(#NS.db.profile.dials[id].groups, #NS.BuiltIns.order)
    assertEqual(NS.Dial.Instance(id).header:GetName(), "QuickCommsDial2")
end)

test("dials page: New dial takes the lowest free number, so a delete never leads to two names alike", function()
    local NS = open()
    local Dials = NS.addon.Settings.Dials
    local two = Dials.Create()
    local three = Dials.Create()
    assertEqual(NS.db.profile.dials[three].name, "Comms Dial 3")
    NS.Library.DeleteSurface("dial", two)
    -- red under: name a new dial after the dial count ("Comms Dial 3" twice)
    local again = Dials.Create()
    assertEqual(NS.db.profile.dials[again].name, "Comms Dial 2")
end)

test("dials page: General has no Preview as (it is in Master controls); Enabled off takes the dial down", function()
    local NS, _, P = open()
    local w = P.redraw("dials")
    -- red under: draw state.previewAs on the dial's General tab again
    assertTrue(P.find(w, "Dropdown", "Preview as") == nil, "Preview as is in General › Master controls")
    P.find(w, "CheckBox", "Enabled"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.dials.d2.enabled)
    assertNil(NS.Dial.Instance("d2"), "a disabled dial is not built")
end)

test("dials page: Wheel writes wedges per ring and where it opens; X and Y move the dial; Reset puts it back", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Wheel")
    P.find(w, "Dropdown", "Wedges per ring"):__fire("OnValueChanged", 8)
    w = P.tab("dials", "Wheel")
    P.find(w, "Dropdown", "Open at"):__fire("OnValueChanged", "cursor")
    assertEqual(NS.db.profile.dials.d2.slices, 8)
    assertEqual(NS.db.profile.dials.d2.openAt, "cursor")
    w = P.tab("dials", "Wheel")
    P.find(w, "EditBox", "Y offset"):__fire("OnEnterPressed", "120")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
    assertEqual(select(5, NS.Dial.Instance("d2").header:GetPoint(1)), 120)
    w = P.tab("dials", "Wheel")
    P.find(w, "Button", "Reset this dial's position"):__fire("OnClick")
    assertNil(NS.db.profile.dials.d2.point)
end)

test("dials page: a refused X or Y says why and puts the box back to the stored offset", function()
    local NS, m, P = open()
    P.find(P.tab("dials", "Wheel"), "EditBox", "X offset"):__fire("OnEnterPressed", "40")
    local xbox = P.find(P.tab("dials", "Wheel"), "EditBox", "X offset")
    m.prints = {}
    xbox:SetText("90000")   -- as the player's typing leaves it
    xbox:__fire("OnEnterPressed", "90000")
    assertEqual(NS.db.profile.dials.d2.point[3], 40, "off the screen: refused")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, "with its reason")
    -- red under: leave a refused box holding the refused text
    assertEqual(xbox.text, "40")
end)

test("dials page: Defaults puts the dial's rows back as one act, and keeps its key and position", function()
    local NS, m, P = open()
    local S = NS.SchemaRuntime
    S.Set("dial.slices", 8, "d2")
    S.Set("dial.mode", "flat", "d2")
    assertTrue(NS.Dial.BindKey("d2", "G"))
    S.Set("dial.point", { "CENTER", "CENTER", 0, 120 }, "d2")
    local applied = 0
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) applied = applied + 1 return apply(...) end
    P.ctx("dials").panel.defaultsOnClick()
    NS.Surfaces.ApplyAll = apply
    assertEqual(NS.db.profile.dials.d2.slices, 4)
    assertEqual(NS.db.profile.dials.d2.mode, "categories")
    -- red under: drop Library.Batch from the page's Defaults (one rebuild, and one re-bind, per row)
    assertEqual(applied, 1)
    -- red under: drop dial.point from settings/Schema.lua's resetExempt
    assertEqual(m.bindingActions.G, "CLICK QuickCommsDial1:Toggle", "WoW's binding: no row, nothing to reset")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
end)

test("dials page: [keys] the Key box sets WoW's own binding and shows what WoW binds; a refusal puts it back", function()
    local NS, m, P = open()
    key(P):__fire("OnKeyChanged", "SHIFT-G")
    -- red under: DD.SetKey writing a profile field (Options -> Keybindings would never show it)
    assertEqual(m.bindingActions["SHIFT-G"], "CLICK QuickCommsDial1:Toggle")
    assertNil(NS.db.profile.dials.d2.key, "never a profile field")
    assertTrue(P.hasText(P.tab("dials", "Binding"), "SHIFT-G opens and closes this dial."))
    assertEqual(key(P).shownKey, "SHIFT-G", "the box shows WoW's binding")
    local id = NS.addon.Settings.Dials.Create()
    P.flush()
    local kb = key(P)
    assertEqual(kb.shownKey, "", "the second dial has no key yet")
    P.pressKey(kb, "1")
    assertEqual(kb.shownKey, "", "an unmodified 1 is refused, and the box goes back")
    assertNil(m.bindingActions["1"])
    m.bindingActions.TAB = "TARGETNEARESTENEMY"
    key(P):__fire("OnKeyChanged", "TAB")
    assertEqual(m.bindingActions.TAB, "CLICK QuickCommsDial2:Toggle", "taken from Target Nearest Enemy")
    assertEqual(NS.Dial.KeyOf(id), "TAB")
    key(P):__fire("OnKeyChanged", "")
    assertNil(m.bindingActions.TAB, "Escape in the box clears the key")
    assertNil(NS.Dial.KeyOf(id))
end)

test("dials page: [keys] a key set in Options -> Keybindings shows in the box when the page is shown again", function()
    local NS, m, P = open()
    local kb = key(P)
    assertEqual(kb.shownKey, "")
    m.SetBinding("F", "CLICK QuickCommsDial1:Toggle")   -- the game's own Keybindings page
    -- red under: no OnShow hook on the Comms Dial page (the box keeps the old key)
    P.ctx("dials").panel:__fire("OnShow")
    assertEqual(kb.shownKey, "F")
    assertEqual(NS.addon.Settings.Dials.KeyLine("d2"), "F opens and closes this dial.")
end)

test("dials page: Groups switches Categories and Flat, and reorders the dial's groups", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local w = P.tab("dials", "Groups")
    P.find(w, "Dropdown", "Show groups as"):__fire("OnValueChanged", "flat")
    assertEqual(NS.db.profile.dials.d2.mode, "flat")
    local groups = NS.db.profile.dials.d2.groups
    local count, last = #groups, groups[#groups]
    P.tab("dials", "Groups")
    lists[#lists].opts.onMove(count, 1)
    assertEqual(NS.db.profile.dials.d2.groups[1], last)
end)

test("dials page: the remove glyph takes a group off the dial without asking and keeps the group", function()
    local NS, m, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddGroupToSurface("dial", "d2", gid)
    P.flush()
    local groups = NS.db.profile.dials.d2.groups
    local count, asked = #groups, #m.popupsShown
    local w = P.tab("dials", "Groups")
    assertNil(P.find(w, "Button", "Remove"), "no red button remains")
    assertNil(P.glyph(w, "edit"), "a dial's group row has no edit glyph")
    -- red under: draw the remove as the red L["Remove"] Button in Ed.ReorderRows
    P.glyph(w, "remove", count):__fire("OnClick")
    assertEqual(#NS.db.profile.dials.d2.groups, count - 1)
    assertEqual(#m.popupsShown, asked, "it does not ask first")
    assertTrue(NS.Library.Group(gid) ~= nil, "the group is kept")
end)

test("dials page: [phase 4] Groups warns when a node set would open three rings deep, and not once it is first", function()
    local NS, _, P = open()
    local Dials = NS.addon.Settings.Dials
    assertNil(Dials.DepthWarning("d2"), "the shipped order: every node set opens into itself")
    local cid = NS.Library.CreateCallout({ name = "Inc", text = "INC", channel = "smartGroup" })
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.OfferGroup(gid)   -- an always-on group, now at the top of every dial
    P.flush()
    local warning = Dials.DepthWarning("d2")
    -- red under: answer nil from DD.DepthWarning (spec §11.3: depth 3 needs the editor warning)
    assertTrue(warning ~= nil and warning:find("Arathi Basin", 1, true) ~= nil, tostring(warning))
    assertTrue(P.hasText(P.tab("dials", "Groups"), warning))
    NS.SchemaRuntime.Set("dial.mode", "flat", "d2")
    assertNil(Dials.DepthWarning("d2"), "Flat has no depth")
    NS.SchemaRuntime.Set("dial.mode", "categories", "d2")
    NS.Library.RemoveGroupFromSurface("dial", "d2", gid)
    assertNil(Dials.DepthWarning("d2"))
end)

test("dials page: Preview lists the rings wedge by wedge, marking the one the dial opens on", function()
    local _, _, P = open(AB)
    local w = P.tab("dials", "preview")
    -- phase 5: the nodes are pinned to their winds, on one eight-wedge ring (spec §12.1)
    assertTrue(P.hasText(w, "Arathi Basin (opens here)"))
    -- the set's own map-wide callouts take the first free wind (groups polish)
    assertTrue(P.hasText(w, "  3 E: Arathi Basin, opens a ring"))
    assertTrue(P.hasText(w, "  5 SW: Lumber Mill, opens a ring"))
end)

test("dials page: [final 20] at 12 wedges per ring the Preview names each wedge by its clock position", function()
    local NS, _, P = open()
    assertTrue(NS.SchemaRuntime.Set("dial.mode", "flat", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 12, "d2"))
    -- M+ alone (In Group's twelve would page the ring, and a paged ring holds eight)
    assertTrue(NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.group")))
    local w = P.tab("dials", "preview")
    assertTrue(P.hasText(w, "  2 1 o'clock: "), "wedge 2 at 1 o'clock")
    assertTrue(P.hasText(w, "  3 2 o'clock: "))
end)

test("dials page: Delete dial asks, then the dial is gone, its header released, and the page heals", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Dials.Create()
    P.flush()
    assertTrue(NS.Dial.Instance(id) ~= nil)
    local w = P.redraw("dials")
    P.find(w, "Button", "Delete dial"):__fire("OnClick")
    assertTrue(NS.db.profile.dials[id] ~= nil, "asks first")
    P.accept()
    assertNil(NS.db.profile.dials[id])
    assertNil(NS.Dial.Instance(id), "released by Dial.Sync")
    P.flush()
    P.redraw("dials")
    assertEqual(NS.State.editing.dial, "d2")
end)

-- ── final review fixes ──────────────────────────────────────────────────────────────────────

test("dials page: [final 7] a key taken from another WoW binding names it as WoW's key bindings menu shows it", function()
    local NS, m, P = open()
    m.BINDING_NAME_TARGETNEARESTENEMY = "Target Nearest Enemy"
    m.bindingActions.TAB = "TARGETNEARESTENEMY"
    m.prints = {}
    key(P):__fire("OnKeyChanged", "TAB")
    -- red under: print the raw token in Dial.BindKey
    assertTrue(table.concat(m.prints, "\n"):find("TAB was Target Nearest Enemy in WoW's key bindings; now it opens this dial.", 1, true)
        ~= nil, table.concat(m.prints, "\n"))
    m.bindingActions.J = "SOMETHING_UNNAMED"
    m.prints = {}
    key(P):__fire("OnKeyChanged", "J")
    assertTrue(table.concat(m.prints, "\n"):find("J was SOMETHING_UNNAMED", 1, true) ~= nil, "no label: the token")
    assertNil(m.bindingActions.TAB, "the dial's old key went back to nothing")
    assertEqual(NS.Dial.KeyOf("d2"), "J")
end)

test("dials page: [final 8] the Binding tab names this dial's Open Comms Dial entry, and what its key does", function()
    local NS, m, P = open()
    local Dials = NS.addon.Settings.Dials
    -- red under: show the fixed "also lists Open Comms Dial 1 to 4" line
    assertTrue(P.hasText(P.tab("dials", "Binding"), "In WoW's key bindings, under Ka0s Quick Comms, this dial is Open Comms Dial 1."))
    assertTrue(P.hasText(P.tab("dials", "Binding"), "The key is for every character, unless you tick Character Specific Keybindings there."))
    assertEqual(Dials.KeyLine("d2"), "No key yet. Click the box and press one, or bind Open Comms Dial 1 in WoW's key bindings: it is the same key.")
    m.bindingKeys["CLICK QuickCommsDial1:Toggle"] = "F"
    assertEqual(Dials.KeyLine("d2"), "F opens and closes this dial.")
    -- red under: DD.KeyLine skipping the dial.enabled and stood-down checks
    assertTrue(NS.SchemaRuntime.Set("dial.enabled", false, "d2"))
    assertEqual(Dials.KeyLine("d2"), "F is bound to Open Comms Dial 1 in WoW's key bindings, but this dial is off: it opens nothing until the dial is enabled.")
    assertTrue(NS.SchemaRuntime.Set("dial.enabled", true, "d2"))
    local stood = NS.IsStoodDown
    NS.IsStoodDown = function() return true end
    assertEqual(Dials.KeyLine("d2"), "F is bound to Open Comms Dial 1 in WoW's key bindings, but Quick Comms is off: it opens nothing until Quick Comms is enabled.")
    NS.IsStoodDown = stood
    local ids = {}
    for i = 1, 4 do ids[i] = Dials.Create() end
    P.flush()
    assertEqual(Dials.PlaceLine(ids[4]), "This dial is number 5 in the dial list.")
    assertEqual(Dials.KeyLine(ids[4]), "No key: WoW's key bindings list Open Comms Dial 1 to 4 only. Move this dial into the first 4 to give it one.")
    -- red under: an enabled Key box on a dial past the menu's entries
    assertTrue(key(P).disabled, "the fifth dial's Key box is disabled")
end)

test("dials page: [final 11] the page's own plan builds are not timed as a surface's bake", function()
    local NS = open(AB)
    local Dials = NS.addon.Settings.Dials
    local notes = 0
    NS.Perf.on = true
    local note = NS.Perf.Note
    NS.Perf.Note = function(k, ...)
        if k == "bakeSurface" then notes = notes + 1 end
        return note(k, ...)
    end
    local ok, err = pcall(function()
        NS.Library.MoveGroupOnSurface("dial", "d2", #NS.db.profile.dials.d2.groups, 1)
        notes = 0
        Dials.DepthWarning("d2")
        Dials.PreviewLines("d2")
    end)
    NS.Perf.Note, NS.Perf.on = note, false
    assertTrue(ok, tostring(err))
    -- red under: build the page's plans through S.BuildDialPlan's bracket
    assertEqual(notes, 0)
end)

-- ── the Icons tab (B9) ──────────────────────────────────────────────────────────────────────

test("dials page: [B9] Icons follows Wheel, carries its headings once each, and writes the dial", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Icons")
    for _, heading in ipairs({ "Size and crop", "Color", "Border", "Glow", "Offset" }) do
        assertEqual(#P.all(w, "Heading", heading), 1, heading .. " drawn once")
    end
    -- red under: Dials' renderIcons without Settings.ShownIconRows
    assertEqual(#P.all(w, "Heading", "Pixel border"), 0, "the glow is off by default: no style's knobs")
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 3)
    local order, seen = {}, {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("dials")) do
        if row.group and not seen[row.group] then seen[row.group] = true order[#order + 1] = row.group end
    end
    -- The Binding tab has no row (a dial's key is WoW's own binding): the page draws it after Icons.
    assertEqual(table.concat(order, ","), "General,Groups,Wheel,Icons", "the rows' tabs, in order")
    assertTrue(P.tab("dials", "Binding") ~= nil, "and the Binding tab is still on the strip")
    P.find(w, "Slider", "Icon size"):__fire("OnMouseUp", 24)
    P.find(w, "CheckBox", "Show border"):__fire("OnValueChanged", true)
    assertEqual(NS.db.profile.dials.d2.icon.size, 24)
    assertTrue(NS.db.profile.dials.d2.icon.borderShow)
    NS.SchemaRuntime.Set("dial.icon.zoom", 0.1, "d2")
    P.ctx("dials").panel.defaultsOnClick()
    assertEqual(NS.db.profile.dials.d2.icon.zoom, 0)
    assertTrue(P.ctx("dials").panel.defaultsTooltip:find("icons", 1, true) ~= nil)
end)

test("dials page: [glow knobs] only the selected style's knobs show, and a Glow or Glow style write repaints", function()
    local _, _, P = open()
    local w = P.tab("dials", "Icons")
    P.find(w, "CheckBox", "Glow"):__fire("OnValueChanged", true)
    w = P.during(P.flush)
    assertEqual(#P.all(w, "Heading", "Pixel border"), 1, "the repaint draws the default style's knobs")
    assertEqual(#P.all(w, "Heading", "Auto cast sparkles"), 0)
    P.find(w, "Dropdown", "Glow style"):__fire("OnValueChanged", "autocast")
    w = P.during(P.flush)
    assertEqual(#P.all(w, "Heading", "Auto cast sparkles"), 1)
    assertEqual(#P.all(w, "Heading", "Pixel border"), 0)
    assertEqual(#P.all(w, "Heading", "Offset"), 1, "Offset always shows")
end)
