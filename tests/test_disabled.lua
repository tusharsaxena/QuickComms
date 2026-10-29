-- tests/test_disabled.lua — disabled means the addon is not running (slash-commands-§7).
--
-- Built on T.enableAddon() and the kit recorders (tests/_kit/mock_record.lua): `__registrations`,
-- `__timers()`, `__shownFrames`, `__svWrites` / `__resetSvWrites`, `__fire`. Case 1 pins the addon's
-- own declared list, and the latch's machinery is proven with a probe row appended before OnEnable:
-- the same path every feature module's row takes. The `[§7 step N]` cases then walk the standard's
-- ten steps against the live addon (slash-commands-§7, *The conformance test every addon ships*).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The game events the addon owns today, pinned as literals (sorted).
local PINNED = {
    "ADDON_RESTRICTION_STATE_CHANGED", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "CHALLENGE_MODE_START",
    "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
    "ENCOUNTER_END", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_DIFFICULTY_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ROLES_ASSIGNED", "PLAYER_SPECIALIZATION_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
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
    T.settleSkinLogin(m)   -- the client's one PLAYER_LOGIN, as T.enableAddon delivers it
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
    T.settleSkinLogin(m)
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

test("disabled: [final 1] every feature event is declared once (AceEvent keeps one handler per event)", function()
    local NS = T.newAddon()
    local seen = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        assertTrue(seen[row[1]] == nil, row[1] .. " is declared twice")
        seen[row[1]] = true
    end
end)

-- ── slash-commands-§7's ten steps against the live addon (audit QC-03) ───────────────────────
--
-- The cases above prove the latch with a probe row; these drive the real addon, every module's
-- events, receivers and frames up, in a key so the default pad and dial 1's wedges are built and
-- shown. Each step is its own case over the same baseline.

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

-- The registration set as stable strings: kind, name and the target's identity.
local function regSet(m)
    local out = {}
    for _, r in ipairs(m.__registrations()) do
        out[#out + 1] = r.kind .. ":" .. r.event .. "@" .. tostring(r.target) .. ":" .. tostring(r.unit)
    end
    table.sort(out)
    return out
end

-- A frame of the surfaces' family: a pad root (QuickCommsPad<id>), a dial header (QuickCommsDial<n>),
-- a send button (QuickCommsSend<n>), or anything parented under one. The settings canvases
-- (QuickComms<Page>Panel) are setup, which stays up while disabled (case 7 above).
local function surfaceName(n)
    return type(n) == "string" and not n:find("Panel$")
        and (n:find("^QuickCommsPad") or n:find("^QuickCommsDial") or n:find("^QuickCommsSend")) ~= nil
end
local function ofSurface(f)
    while type(f) == "table" do
        if surfaceName(f.__name) then return true end
        f = f.__parent
    end
    return false
end
-- Shown here and in every ancestor: what the client draws (the mock's IsShown is the frame's own flag).
local function drawn(f)
    while type(f) == "table" do
        if not f:IsShown() then return false end
        f = f.__parent
    end
    return true
end

-- Step 1: the addon enabled, in a key, and the three snapshots.
local function baseline()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local snap = { R = regSet(m), T = #m.__timers(), F = {}, messages = 0 }
    for _, f in ipairs(m.__shownFrames()) do
        if ofSurface(f) then snap.F[#snap.F + 1] = f end
    end
    for _, r in ipairs(m.__registrations()) do
        if r.kind == "message" then snap.messages = snap.messages + 1 end
    end
    snap.raw = m.__registrations()
    return NS, m, snap
end

-- Step 2: through the single write seam, the route the checkbox and the verb take.
local function disable(NS) NS.SchemaRuntime.Set("enabled", false) end

local function countDrawn(frames)
    local n = 0
    for _, f in ipairs(frames) do if drawn(f) then n = n + 1 end end
    return n
end

test("disabled [§7 step 1]: enabled, the registration set holds events and messages, and the surfaces are drawn", function()
    local _, _, snap = baseline()
    assertTrue(#snap.R > 0, "R_on is not empty")
    assertTrue(snap.messages > 0, "the bus receivers are in R_on")
    assertTrue(#snap.F > 0, "F_on is not empty: the pad and its buttons are shown")
    assertTrue(countDrawn(snap.F) > 0)
end)

test("disabled [§7 steps 2-4]: through the seam, nothing stays registered, events or messages, and nothing is armed", function()
    local NS, m = baseline()
    disable(NS)
    assertTrue(NS.IsStoodDown())
    local events, messages = 0, 0
    for _, r in ipairs(m.__registrations()) do
        if r.kind == "message" then messages = messages + 1 else events = events + 1 end
    end
    -- red under: drop the UnregisterEvent loop in NS.StandDown (core/QuickComms.lua)
    assertEqual(events, 0, "every game event unregistered")
    -- red under: drop NS.Bus:StandDown() in NS.StandDown
    assertEqual(messages, 0, "every bus receiver unregistered")
    assertEqual(table.concat(regSet(m), ","), "", "by name too")
    assertEqual(#m.__timers(), 0, "no timer, ticker or OnUpdate armed")
end)

test("disabled [§7 step 5]: every surface frame that was drawn is hidden", function()
    local NS, _, snap = baseline()
    disable(NS)
    -- red under: drop NS.Pad.HideAll() and NS.Dial.HideAll() from the stand-down's Teardown in modules/Surfaces.lua
    assertEqual(countDrawn(snap.F), 0)
end)

test("disabled [§7 step 6]: every event and message in R_on, fired anyway, runs nothing live; every event's handler, reached directly, writes, prints, shows and arms nothing", function()
    local NS, m, snap = baseline()
    disable(NS)
    m.__resetSvWrites()
    m.prints = {}
    local shown = #m.__shownFrames()
    local ran = 0
    for _, r in ipairs(snap.raw) do
        if r.kind == "message" then NS.addon:SendMessage(r.event) else ran = ran + m.__fire(r.event) end
    end
    -- The combat-entry event by name, live: nothing is registered to hear it.
    -- red under: register PLAYER_REGEN_DISABLED outside NS.FEATURE_EVENTS (it survives the stand-down)
    ran = ran + m.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(ran, 0, "no live handler reached")
    -- And at each registration's own target: kit 39's __fireUnconditional reaches the method the
    -- registration named (OnSituationEvent, OnRestrictionLiftEvent, OnSendEcho, ...) after the
    -- stand-down and answers 1, so reach is proven per event rather than read off a silence; what
    -- each runs must still write, print, show and arm nothing.
    local events = 0
    for _, r in ipairs(snap.raw) do
        if r.kind ~= "message" then
            events = events + 1
            -- red under: re-vendor kit 38 (its __fireUnconditional cannot reach a method-name handler, so 0)
            assertTrue(m.__fireUnconditional(r.target or NS.addon, r.event) >= 1, r.event .. " reached its handler")
        end
    end
    assertTrue(events >= #PINNED, "every pinned event was fired at its handler")
    -- red under: drop the IsStoodDown guard in modules/Situation.lua's OnSituationEvent (it arms the
    -- coalesce timer) or in modules/Restrictions.lua's handlers (they re-read and arm the late re-read)
    assertEqual(#m.__timers(), 0, "no handler armed a timer")
    assertEqual(#m.__svWrites(), 0, "no SavedVariables write")
    assertEqual(#m.prints, 0, "no chat line")
    assertEqual(#m.__shownFrames(), shown, "no frame shown")
    assertEqual(countDrawn(snap.F), 0)
    assertEqual(#m.__timers(), 0, "and still nothing armed (step 4)")
end)

-- The verbs that act on a running addon (slash-commands-§2's feature-verb SHOULD, taken).
local FEATURE_VERBS = { lock = true, unlock = true, check = true, test = true, preview = true, why = true,
    toggle = true }

test("disabled [§7 step 7]: every NS.COMMANDS entry and the bare /qc: reserved verbs answer, feature verbs refuse once and write nothing", function()
    local NS, m = baseline()
    disable(NS)
    local S = NS.SchemaRuntime
    local realSet, writes = S.Set, 0
    S.Set = function(...) writes = writes + 1; return realSet(...) end
    local seen = {}
    local verbs = { "" }
    for _, row in ipairs(NS.COMMANDS) do
        if row[1] ~= "enable" then verbs[#verbs + 1] = row[1] end
    end
    for _, verb in ipairs(verbs) do
        seen[verb] = true
        m.prints = {}
        writes = 0
        NS.addon:OnSlashCommand(verb)
        local refusals = 0
        for _, line in ipairs(m.prints) do
            if line:find("Ka0s Quick Comms is disabled", 1, true) then refusals = refusals + 1 end
        end
        if FEATURE_VERBS[verb] then
            -- red under: add "lock" to liveVerbs in settings/Slash.lua (it then acts while disabled)
            assertEqual(#m.prints, 1, verb .. ": exactly one line")
            assertEqual(refusals, 1, verb .. ": the refusal line")
            assertEqual(writes, 0, verb .. ": no write seam reached")
        elseif verb ~= "disable" and verb ~= "" and verb ~= "help" then
            assertEqual(refusals, 0, verb .. " keeps answering")
        end
        assertTrue(NS.IsStoodDown(), verb .. " left the addon stood down")
    end
    for verb in pairs(FEATURE_VERBS) do assertTrue(seen[verb], verb .. " is a registered verb") end
    S.Set = realSet
    m.prints = {}
    NS.addon:OnSlashCommand("enable")
    assertFalse(NS.IsStoodDown(), "enable, last, stands the addon up")
end)

test("disabled [§7 step 8]: the launcher's left-click opens the panel and its menu grays every entry but Enabled", function()
    local NS, m = baseline()
    disable(NS)
    local opened = 0
    local realOpen = NS.addon.OpenSettings
    NS.addon.OpenSettings = function() opened = opened + 1 end
    m.__resetSvWrites()
    local shown = #m.__shownFrames()
    m.ldbObjects.QuickComms.OnClick(m.UIParent, "LeftButton")
    NS.addon.OpenSettings = realOpen
    assertEqual(opened, 1, "the panel opener was called")
    local boxes = {}
    local root = {
        CreateTitle = function() end,
        CreateCheckbox = function(_, label, _, onClick)
            local box = { label = label, click = onClick, calls = 0 }
            box.SetEnabled = function(self, v) self.enabled = v end
            boxes[#boxes + 1] = box
            return box
        end,
    }
    m.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    m.ldbObjects.QuickComms.OnClick(m.UIParent, "RightButton")
    assertEqual(#boxes, 4)
    assertTrue(boxes[4].label:find("^Show window") ~= nil, boxes[4].label)
    assertEqual(boxes[4].enabled, false, "Show window is grayed")
    assertEqual(boxes[1].label, "Enabled")
    assertTrue(boxes[1].enabled == nil, "Enabled stays clickable")
    assertTrue(boxes[2].label:find("^Locked") ~= nil, boxes[2].label)
    assertEqual(boxes[2].enabled, false, "Locked is grayed")
    assertTrue(boxes[3].label:find("^Test mode") ~= nil, boxes[3].label)
    assertEqual(boxes[3].enabled, false, "Test mode is grayed")
    assertEqual(#m.__svWrites(), 0, "neither click wrote anything")
    assertEqual(#m.__shownFrames(), shown, "neither click showed a frame")
end)

test("disabled [§7 step 8]: the Toggle Comms Pads key, pressed while disabled, prints the one refusal line and writes and shows nothing", function()
    local NS, m = baseline()
    disable(NS)
    m.SetBinding("P", "CLICK QuickCommsTogglePads:LeftButton")
    local before = NS.db.char.padsHidden
    m.__resetSvWrites()
    m.prints = {}
    local shown = #m.__shownFrames()
    m.__pressKey("P")
    -- red under: drop the StoodDownRefusal check from settings/SlashVerbs.lua's TogglePads
    assertEqual(#m.prints, 1, "exactly one line")
    assertTrue(m.prints[1]:find(NS.SlashCommands:DisabledLine(), 1, true) ~= nil, m.prints[1])
    assertEqual(NS.db.char.padsHidden, before, "nothing toggled")
    assertEqual(#m.__svWrites(), 0, "no SavedVariables write")
    assertEqual(#m.__shownFrames(), shown, "no frame shown")
end)

test("disabled [§7 step 9]: re-enabled, R_on comes back; a setting changed while disabled is what the stand-up builds", function()
    local NS, m, snap = baseline()
    disable(NS)
    NS.SchemaRuntime.Set("enabled", true)
    assertEqual(table.concat(regSet(m), ","), table.concat(snap.R, ","), "the registration set equals R_on")
    assertTrue(countDrawn(snap.F) > 0, "the surfaces are drawn again")
    disable(NS)
    local id = NS.addon.db.profile.padOrder[1]
    -- While disabled: the only pad turned off through the seam's member row.
    assertTrue(NS.SchemaRuntime.Set("pad.enabled", false, id))
    NS.SchemaRuntime.Set("enabled", true)
    -- red under: stash State.surfacePlans at the stand-down in modules/Surfaces.lua and Pad.Sync it on the stand-up
    local drawnPads = 0
    for _, f in ipairs(snap.F) do
        if type(f.__name) == "string" and f.__name:find("^QuickCommsPad") and drawn(f) then drawnPads = drawnPads + 1 end
    end
    assertEqual(drawnPads, 0, "the pad turned off while disabled stays off on the stand-up")
end)

local function holdsCycle(NS, m, perfFirst)
    local LC = NS.Lifecycle
    if perfFirst then
        LC:Hold(NS.HOLD_PERF)
        NS.SchemaRuntime.Set("enabled", false)
        LC:Release(NS.HOLD_PERF)
    else
        NS.SchemaRuntime.Set("enabled", false)
        LC:Hold(NS.HOLD_PERF)
        NS.SchemaRuntime.Set("enabled", true)
    end
    assertTrue(NS.IsStoodDown(), "one hold released, the other still holds")
    assertEqual(#m.__registrations(), 0, "and the registration set is still empty")
    if perfFirst then NS.SchemaRuntime.Set("enabled", true) else LC:Release(NS.HOLD_PERF) end
    assertFalse(NS.IsStoodDown(), "the last hold released stands it up")
    assertTrue(#m.__registrations() > 0)
end

-- Both latches: the library's (LibKa0s-Lifecycle-1.0) and the host's library-absent stand-in
-- (core/LifecycleSetup.lua), which this repo owns and a mutation can reach.
local LATCHES = {
    { "the library latch", function() return baseline() end },
    { "the stand-in latch", function()
        local NS, _, m = T.enableAddon{ skip = T.loadAddon.libFiles }
        return NS, m
    end },
}

for _, latch in ipairs(LATCHES) do
    -- red under: (stand-in latch) make Release clear every hold in core/LifecycleSetup.lua (both orders);
    -- (library latch, the second order) also release the perf hold from the `enabled` reaction in
    -- settings/Schema.lua. The library's own latch is vendored and is not mutated here.
    test("disabled [§7 step 10]: " .. latch[1] .. ": perf, then disabled; perf released first leaves it down", function()
        local NS, m = latch[2]()
        holdsCycle(NS, m, true)
    end)

    test("disabled [§7 step 10]: " .. latch[1] .. ": disabled, then perf; enabled first leaves it down", function()
        local NS, m = latch[2]()
        holdsCycle(NS, m, false)
    end)
end

-- By hold (slash-commands-§7's by-hold refusal, launcher-§6's key press; LibKa0s#58): the dispatcher
-- gates on the stored switch, so under the perf hold alone a feature verb reaches its handler, and
-- the handler must not advise `/qc enable` (enabled is already on). It answers the capture line.
local CAPTURE = "Not available during a performance capture."

local function perfHeld()
    local NS, m = baseline()
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertTrue(NS.IsStoodDown(), "the perf hold alone stands the addon down")
    assertTrue(NS.Setting("enabled") ~= false, "and leaves the stored switch on")
    m.prints = {}
    return NS, m
end

local function oneCaptureLine(m, what)
    assertEqual(#m.prints, 1, what .. " prints one line")
    assertTrue(m.prints[1]:find(CAPTURE, 1, true) ~= nil, what .. ": " .. tostring(m.prints[1]))
    assertTrue(m.prints[1]:find("is disabled", 1, true) == nil, what .. " never advises /qc enable")
end

-- red under: restore settings/SlashVerbs.lua's `if NS.IsStoodDown() then ... DisabledLine()` refusal
test("disabled [by hold]: under the perf hold alone, /qc toggle refuses with the capture line and leaves padsHidden alone", function()
    local NS, m = perfHeld()
    local before = NS.db.char.padsHidden
    NS.addon:OnSlashCommand("toggle")
    oneCaptureLine(m, "/qc toggle")
    assertEqual(NS.db.char.padsHidden, before, "nothing toggled")
end)

test("disabled [by hold]: under the perf hold alone, the Toggle Comms Pads key press refuses as /qc toggle does", function()
    local NS, m = perfHeld()
    local before = NS.db.char.padsHidden
    m.SetBinding("P", "CLICK QuickCommsTogglePads:LeftButton")
    m.__pressKey("P")
    oneCaptureLine(m, "the Toggle Comms Pads key")
    assertEqual(NS.db.char.padsHidden, before, "nothing toggled")
    NS.Lifecycle:Release(NS.HOLD_PERF)
    m.prints = {}
    m.__pressKey("P")
    assertTrue(NS.db.char.padsHidden ~= before, "the capture finished, the key toggles the pads again")
end)

-- red under: restore modules/Preview.lua's two `NS.IsStoodDown()` -> DisabledLine() refusals
test("disabled [by hold]: under the perf hold alone, test mode and Preview as refuse with the capture line", function()
    local NS, m = perfHeld()
    assertFalse(NS.Preview.SetTestMode(true))
    oneCaptureLine(m, "test mode")
    assertFalse(NS.Preview.IsTestMode())
    m.prints = {}
    assertFalse(NS.Preview.SetPreviewAs("arena"))
    oneCaptureLine(m, "Preview as")
    assertTrue(NS.Preview.PreviewAs() == nil, "no preview started")
end)

-- a guard, green before and after: the fix must not let the capture line shadow the disabled hold
test("disabled [by hold]: with both holds the disabled line wins", function()
    local NS, m = perfHeld()
    disable(NS)
    m.prints = {}
    NS.SlashVerbs.TogglePads()
    local line = NS.SlashCommands:DisabledLine()
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find(line, 1, true) ~= nil, m.prints[1])
    m.prints = {}
    assertFalse(NS.Preview.SetTestMode(true))
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find(line, 1, true) ~= nil, m.prints[1])
end)
