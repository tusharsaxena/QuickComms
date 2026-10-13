-- tests/test_disabled.lua — disabled means the addon is not running (slash-commands-§7).
--
-- Built on T.enableAddon() and the kit recorders (tests/_kit/mock_record.lua): `__registrations`,
-- `__timers()`, `__svWrites` / `__resetSvWrites`, `__fire`. Case 1 pins the addon's own
-- declared list, and the latch's machinery is proven with a probe row appended
-- before OnEnable: the same path every feature module's row takes.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The game events the addon owns today, pinned as literals (sorted).
local PINNED = {
    "ADDON_RESTRICTION_STATE_CHANGED", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "CHALLENGE_MODE_START", "GROUP_ROSTER_UPDATE",
    "PARTY_LEADER_CHANGED", "PLAYER_DIFFICULTY_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_SPECIALIZATION_CHANGED", "ZONE_CHANGED_NEW_AREA",
}

local PROBE_EVENT = "PLAYER_LEAVING_WORLD"

-- What an instance carrying the probe row registers: the pinned events plus the probe, sorted.
local PROBED = (function()
    local all = { PROBE_EVENT }
    for _, e in ipairs(PINNED) do all[#all + 1] = e end
    table.sort(all)
    return table.concat(all, ",")
end)()

-- Game-event registrations only; bus receivers are asserted by what they hear.
local function registered(m)
    local out = {}
    for _, r in ipairs(m.__registrations()) do
        if r.kind ~= "message" then out[#out + 1] = r.event end
    end
    table.sort(out)
    return table.concat(out, ",")
end

local function declared(NS)
    local out = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do out[#out + 1] = row[1] end
    table.sort(out)
    return table.concat(out, ",")
end

-- An enabled addon carrying one probe feature: an event row, a bus receiver and a teardown and
-- rebuild step, each appended the way a feature module appends its own.
local function probed()
    local NS, _, m = T.bootAddon()
    local probe = { events = 0, messages = 0, downs = 0, ups = 0 }
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { PROBE_EVENT, "OnProbe" }
    NS.addon.OnProbe = function() probe.events = probe.events + 1 end
    NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function() probe.downs = probe.downs + 1 end
    NS.STAND_UP[#NS.STAND_UP + 1] = function() probe.ups = probe.ups + 1 end
    NS.addon:OnEnable()
    local target = NS.Bus:NewTarget()
    target:RegisterMessage(NS.MSG.PROFILE_CHANGED, function() probe.messages = probe.messages + 1 end)
    return NS, m, probe
end

-- The two ways a player disables the addon: the slash verb, and the write seam the Master
-- controls checkbox and the launcher's Enabled entry use.
local DISABLES = {
    { "/qc disable", function(NS) NS.addon:OnSlashCommand("disable") end },
    { "the write seam", function(NS) NS.SchemaRuntime.Set("enabled", false) end },
}

test("disabled 1: enabled, the addon registers exactly the events it declares", function()
    local NS, _, m = T.enableAddon()
    assertEqual(registered(m), declared(NS))
    assertEqual(registered(m), table.concat(PINNED, ","))
end)

for _, way in ipairs(DISABLES) do
    test("disabled 2: through " .. way[1] .. ", nothing is registered, heard or scheduled", function()
        local NS, m, probe = probed()
        assertEqual(registered(m), PROBED)
        way[2](NS)
        assertTrue(NS.IsStoodDown())
        assertFalse(NS.addon.db.profile.enabled, "the stored setting is the source")
        -- red under: drop the UnregisterEvent loop in NS.StandDown (core/QuickComms.lua)
        assertEqual(registered(m), "", "every feature event unregistered")
        assertEqual(m.__fire(PROBE_EVENT), 0, PROBE_EVENT)
        assertEqual(probe.events, 0)
        NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
        assertEqual(probe.messages, 0, "the tracked receiver is down")
        assertEqual(probe.downs, 1, "the module's teardown ran once")
        assertEqual(#m.__timers(), 0, "no live timer")
    end)
end

test("disabled 3: no SavedVariables write from a game event while disabled", function()
    local NS, m = probed()
    NS.addon:OnSlashCommand("disable")
    m.__resetSvWrites()
    m.__fireUnconditional(NS.addon, PROBE_EVENT)
    assertEqual(#m.__svWrites(), 0)
end)

test("disabled 4: every reserved verb keeps answering while disabled", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    for _, verb in ipairs({ "help", "version", "list", "get enabled", "diagnostics", "profile", "perf" }) do
        m.prints = {}
        NS.addon:OnSlashCommand(verb)
        local refused = false
        for _, line in ipairs(m.prints) do
            if line:find("is disabled", 1, true) and not line:find("slash commands", 1, true) then
                refused = verb ~= "help"
            end
        end
        assertFalse(refused, verb .. " was refused")
    end
end)

test("disabled 5: a feature verb answers with the one refusal line and does nothing", function()
    local NS, _, m = T.enableAddon()
    local ran = 0
    -- The dispatcher holds NS.COMMANDS by reference, so a feature task's row is gated the same way.
    NS.COMMANDS[#NS.COMMANDS + 1] = { "probe", "a feature verb", function() ran = ran + 1 end }
    NS.addon:OnSlashCommand("disable")
    m.prints = {}
    NS.addon:OnSlashCommand("probe")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Ka0s Quick Comms is disabled", 1, true) ~= nil, m.prints[1])
    assertEqual(ran, 0)
end)

test("disabled 6: the stand-up re-registers from current state and replays the receivers", function()
    local NS, m, probe = probed()
    NS.addon:OnSlashCommand("disable")
    NS.addon:OnSlashCommand("enable")
    assertFalse(NS.IsStoodDown())
    assertEqual(registered(m), PROBED)
    assertEqual(probe.ups, 1, "the module's rebuild ran once")
    NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
    assertEqual(probe.messages, 1, "the tracked receiver is back")
end)

test("disabled 7: a disabled profile loads stood down, with nothing registered", function()
    local NS, _, m = T.bootAddon()
    NS.addon.db.profile.enabled = false
    NS.addon:OnEnable()
    assertTrue(NS.IsStoodDown())
    assertEqual(registered(m), "")
    assertTrue(m.ldbObjects.QuickComms ~= nil, "setup stays up: the launcher is registered")
    assertTrue(NS.addon._settingsRegistered == true, "and so is the settings category")
end)

test("disabled 8: the launcher's Enabled entry stays live while disabled", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local boxes = {}
    local root = {
        CreateTitle = function() end,
        CreateCheckbox = function(_, label, _, onClick)
            local box = { label = label, click = onClick }
            box.SetEnabled = function(self, v) self.enabled = v end
            boxes[#boxes + 1] = box
            return box
        end,
    }
    m.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    m.ldbObjects.QuickComms.OnClick(m.UIParent, "RightButton")
    assertEqual(boxes[1].label, "Enabled")
    assertTrue(boxes[1].enabled == nil, "Enabled stays live")
    boxes[1].click()
    assertFalse(NS.IsStoodDown(), "and turns the addon back on")
end)
