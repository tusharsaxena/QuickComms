-- tests/test_keybinds.lua — the key bindings (item 015; launcher-§6, options-ui-§20): NS.BINDINGS,
-- the General page's Keybindings tab (LibKa0s-Options-1.0's O.KeybindingsTab, OptionsKeybinds
-- minor 4), and the two ways round it syncs with Options -> Keybindings. The capture, slot, conflict
-- and sync mechanics are the library's cases (testing-§8); these pin this addon's half: the strip
-- ends in Keybindings, the rows are NS.BINDINGS in order with the BINDING_NAME_ labels, a key bound
-- through the tab is WoW's binding (and the key then does its job), a key set in WoW's menu shows on
-- the tab, and combat refuses. The Bindings.xml shape check is tests/test_dial.lua's.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local TOGGLE = "CLICK QuickCommsTogglePads:LeftButton"
local function dialCommand(i) return ("CLICK QuickCommsDial%d:Toggle"):format(i) end

--- The General page drawn on its Keybindings tab. Answers NS, m, the strip's tab keys (the first
--- render's) and the row records the tab drew (captured around the library's O.KeybindRows, which
--- the tab's render looks up at call time).
local function openTab()
    local NS, m = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local keys, rows
    local render, draw = H.RenderTabbedSchema, H.KeybindRows
    H.RenderTabbedSchema = function(...)
        local groups, tabKeys = render(...)
        keys = keys or tabKeys
        return groups, tabKeys
    end
    H.KeybindRows = function(...)
        rows = draw(...)
        return rows
    end
    P.show("General")
    local ctx = P.ctx("general")
    ctx.activeTab = "Keybindings"
    ctx._renderFn(ctx)
    H.RenderTabbedSchema, H.KeybindRows = render, draw
    return NS, m, keys, rows, ctx
end

local function slotText(row, slot)
    local w = row.slots[slot]
    return w.text or (w.GetText and w:GetText())
end

test("keybinds: NS.BINDINGS is Toggle Comms Pads, then Open Comms Dial 1 to 4, each with a tooltip", function()
    local NS, m = T.newAddon()
    -- red under: the dials first and Toggle Comms Pads last (the order before item 015)
    assertEqual(#NS.BINDINGS, 1 + NS.Dial.BINDINGS)
    assertEqual(NS.BINDINGS[1].command, TOGGLE)
    assertEqual(m["BINDING_NAME_" .. TOGGLE], "Toggle Comms Pads")
    for i = 1, NS.Dial.BINDINGS do
        local b = NS.BINDINGS[1 + i]
        assertEqual(b.command, dialCommand(i))
        assertEqual(b.command, NS.Dial.Command(i), "one spelling of a dial's command")
        assertEqual(m["BINDING_NAME_" .. b.command], ("Open Comms Dial %d"):format(i))
    end
    for _, b in ipairs(NS.BINDINGS) do
        assertTrue(type(b.tooltip) == "string" and b.tooltip ~= "", b.command .. " has a tooltip")
    end
end)

test("keybinds: the General page's strip ends in Keybindings, after every group tab", function()
    local _, _, keys = openTab()
    assertTrue(type(keys) == "table" and #keys >= 2, "the strip was drawn")
    -- red under: drop the tabs entry from settings/Panel.lua's RenderTabbedSchema call
    assertEqual(keys[#keys], "Keybindings")
    assertEqual(keys[1], "Master controls", "Master controls stays first (options-ui-§15)")
end)

test("keybinds: the tab's rows are NS.BINDINGS in order, each labeled with its BINDING_NAME_ global", function()
    local NS, m, _, rows = openTab()
    assertTrue(type(rows) == "table", "the Keybindings tab drew its rows")
    assertEqual(#rows, #NS.BINDINGS)
    for i, b in ipairs(NS.BINDINGS) do
        assertEqual(rows[i].command, b.command)
        assertEqual(rows[i].label.text, m["BINDING_NAME_" .. b.command])
    end
end)

test("keybinds: a key bound through the tab is WoW's binding, saved to the set in force, and the key toggles the pads", function()
    local NS, m, _, rows = openTab()
    m.bindingSet = 2   -- Character Specific Keybindings ticked
    local line = T.keybindThroughTab(rows[1], 1, "P")
    assertEqual(m.GetBindingKey(TOGGLE), "P")
    assertEqual(m.bindingSaves[#m.bindingSaves], 2, "saved to the character's set, the one in force")
    assertTrue(line ~= nil and line ~= "", "the outcome line says what happened")
    local before = NS.db.char.padsHidden == true
    assertTrue(m.__pressKey("P"))
    assertEqual(NS.db.char.padsHidden == true, not before, "the key runs /qc toggle's handler")
end)

test("keybinds: a key set in Options -> Keybindings shows on the tab after UPDATE_BINDINGS", function()
    local _, m, _, rows = openTab()
    assertTrue(slotText(rows[2], 1) ~= "G")
    m.SetBinding("G", dialCommand(1))   -- what the game's own menu does
    m.SaveBindings(m.GetCurrentBindingSet())
    m.__fire("UPDATE_BINDINGS")
    m.__fireTimers()
    assertEqual(slotText(rows[2], 1), "G")
end)

test("keybinds: in combat the tab refuses: no capture starts, no key is bound and nothing is saved", function()
    local _, m, _, rows = openTab()
    local saves = #m.bindingSaves
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_DISABLED")
    m.__setCombat(true)
    rows[1].slots[1]:__fire("OnClick", "LeftButton")
    assertTrue(slotText(rows[1], 1) ~= "Press a key...", "the slot does not listen")
    assertEqual(rows[1].status.text, "Key bindings can be changed after combat.")
    rows[1].clear:__fire("OnClick", "LeftButton")
    assertNil(m.GetBindingKey(TOGGLE))
    assertEqual(#m.bindingSaves, saves, "no SaveBindings in combat")
end)
