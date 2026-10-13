-- tests/test_preview.lua — test mode (spec §10.4, preview-mode, options-ui-§15): session-only,
-- refused in combat with one line, ended when combat starts, ended silently by the stand-down.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local function heard(NS)
    local out = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.TEST_MODE_CHANGED, function(_, on) out[#out + 1] = tostring(on) end)
    return out
end

test("preview: test mode turns on and off, announcing each edge once", function()
    local NS = T.enableAddon()
    local out = heard(NS)
    assertTrue(NS.Preview.SetTestMode(true))
    assertTrue(NS.Preview.IsTestMode())
    assertFalse(NS.Preview.SetTestMode(true), "already on: no edge")
    assertTrue(NS.Preview.ToggleTestMode())
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(table.concat(out, ","), "true,false")
end)

test("preview: a start in combat is refused with one line", function()
    local NS, m = T.enableAddon()
    combat(m, true)
    m.prints = {}
    assertFalse(NS.Preview.SetTestMode(true))
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("not available in combat", 1, true) ~= nil, m.prints[1])
end)

test("preview: the start of combat ends test mode, with one line", function()
    local NS, m = T.enableAddon()
    local out = heard(NS)
    NS.Preview.SetTestMode(true)
    m.prints = {}
    combat(m, true)
    -- red under: drop the RESTRICTION_CHANGED receiver in modules/Preview.lua
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(table.concat(out, ","), "true,false")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("entered combat", 1, true) ~= nil, m.prints[1])
end)

test("preview: test mode still ends when lockdown has already begun at the combat edge", function()
    local NS, m = T.enableAddon()
    NS.Preview.SetTestMode(true)
    m.__setCombat(true)                    -- InCombatLockdown() is already true when the edge fires
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.blocked, 0)
end)

test("preview: the stand-down ends test mode silently, and stood down a start is refused", function()
    local NS, m = T.enableAddon()
    NS.Preview.SetTestMode(true)
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Preview.IsTestMode())
    m.prints = {}
    assertFalse(NS.Preview.SetTestMode(true))
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("is disabled", 1, true) ~= nil, m.prints[1])
end)
