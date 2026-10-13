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

test("dials page: General has Preview as first; Enabled off takes the dial down", function()
    local NS, _, P = open()
    local w = P.redraw("dials")
    assertTrue(P.find(w, "Dropdown", "Preview as") ~= nil, "Preview as is page-wide, first")
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
    local NS, _, P = open()
    local S = NS.SchemaRuntime
    S.Set("dial.slices", 8, "d2")
    S.Set("dial.mode", "flat", "d2")
    S.Set("dial.key", "G", "d2")
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
    -- red under: drop dial.key or dial.point from settings/Schema.lua's resetExempt
    assertEqual(NS.db.profile.dials.d2.key, "G")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
end)

test("dials page: [review 4] the Binding tab binds the key; another dial's is refused naming it; a WoW key warns and binds", function()
    local NS, m, P = open()
    key(P):__fire("OnKeyChanged", "SHIFT-G")
    assertEqual(NS.db.profile.dials.d2.key, "SHIFT-G")
    assertEqual(m.overrideBindings["SHIFT-G"].name, "QuickCommsDial1")
    assertTrue(P.hasText(P.tab("dials", "Binding"), "SHIFT-G opens and closes this dial."))
    local id = NS.addon.Settings.Dials.Create()
    P.flush()
    m.prints = {}
    key(P):__fire("OnKeyChanged", "SHIFT-G")
    assertNil(NS.db.profile.dials[id].key)
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("SHIFT-G already opens Comms Dial.", 1, true) ~= nil, text)
    m.bindingActions.TAB = "TARGETNEARESTENEMY"
    key(P):__fire("OnKeyChanged", "TAB")
    assertEqual(NS.db.profile.dials[id].key, "TAB")
    assertEqual(m.overrideBindings.TAB.name, "QuickCommsDial2", "it still binds")
    assertTrue(P.hasText(P.tab("dials", "Binding"), "TAB is also TARGETNEARESTENEMY in WoW's key bindings."))
    key(P):__fire("OnKeyChanged", "")
    assertEqual(NS.db.profile.dials[id].key, false, "Escape in the box clears the key")
    assertNil(m.overrideBindings.TAB)
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
    assertTrue(P.hasText(w, "Arathi Basin (1 of 2) (opens here)"))
    assertTrue(P.hasText(w, "  2 E: Lumber Mill, opens a ring"))
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
