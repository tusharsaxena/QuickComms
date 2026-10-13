-- tests/test_bus.lua — core/Bus.lua: the message catalog of spec §17, one name each, all prefixed.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local EXPECTED = {
    SITUATION_CHANGED     = "Ka0s_QuickComms_SituationChanged",
    RESTRICTION_CHANGED   = "Ka0s_QuickComms_RestrictionChanged",
    LIBRARY_CHANGED       = "Ka0s_QuickComms_LibraryChanged",
    ACTIVE_GROUPS_CHANGED = "Ka0s_QuickComms_ActiveGroupsChanged",
    SURFACE_REBUILT       = "Ka0s_QuickComms_SurfaceRebuilt",
    SEND_RESULT           = "Ka0s_QuickComms_SendResult",
    COMBAT_QUEUE_DRAINED  = "Ka0s_QuickComms_CombatQueueDrained",
    PROFILE_CHANGED       = "Ka0s_QuickComms_ProfileChanged",
    TEST_MODE_CHANGED     = "Ka0s_QuickComms_TestModeChanged",
}

test("bus: every spec §17 message is declared with its exact name", function()
    local NS = T.newAddon()
    for key, name in pairs(EXPECTED) do assertEqual(NS.MSG[key], name, key) end
end)

test("bus: no two constants share a name", function()
    local NS = T.newAddon()
    local seen = {}
    for key in pairs(EXPECTED) do
        local name = NS.MSG[key]
        assertTrue(not seen[name], "duplicate " .. tostring(name))
        seen[name] = true
    end
end)
