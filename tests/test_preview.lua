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

local WORLD = { inGroup = false }
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or WORLD end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function arenaChip(NS)
    return NS.Pad.ChipsFor("p1", NS.Library.Group("bi.arena").callouts[1])[1]
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

test("preview: [phase 3] Preview as Arena builds the pad from the arena snapshot, every chip disarmed", function()
    local NS = live()
    local out = heard(NS)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    assertEqual(table.concat(out, ","), "true")
    local plan = NS.Surfaces.Plans().p1
    assertEqual(plan.preview, "arena")
    assertEqual(plan.order[1], "bi.arena")
    local chip = arenaChip(NS)
    assertTrue(chip ~= nil, "the arena set is drawn in the open world")
    -- red under: drop `and not slot.preview` from Pad's arm (the previewed chip is armed)
    assertTrue(chip:GetAttribute("macrotext") == nil)
    local header = NS.Pad.Instance("p1").header
    assertEqual(header.qcSituation:GetText(), "Preview: Arena")
    assertTrue(header.qcTest:IsShown())
    assertEqual(header.qcTest:GetText(), "PREVIEW")
end)

test("preview: [review 3] a previewed chip sends nothing and reports nothing", function()
    local NS, m = live()
    NS.Preview.SetPreviewAs("arena")
    local results = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() results = results + 1 end)
    local before = #m.sentMacros
    m.__click(arenaChip(NS))
    assertEqual(#m.sentMacros, before)
    assertEqual(results, 0)
end)

test("preview: [review 3] a previewed solo chip prints nothing, even with the self fallback", function()
    local NS, m = live()
    NS.SchemaRuntime.Set("behavior.soloFallback", "self")
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "smartGroup" })
    local gid = Lib.CreateGroup({ name = "Mine", callouts = { cid } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    assertTrue(NS.Preview.SetPreviewAs("world"))
    local chip = NS.Pad.ChipsFor("p1", cid)[1]
    assertTrue(chip ~= nil, "the user group (an empty When) shows in the previewed open world")
    m.prints = {}
    m.__click(chip)
    -- red under: keep `slot.selfText` in a previewed chip's meta (modules/Pad.lua arm)
    assertEqual(#m.prints, 0)
end)

test("preview: [review 3] combat ends it with one line, and the live chips come back armed", function()
    local NS, m = live(MPLUS)
    NS.Preview.SetPreviewAs("arena")
    m.prints = {}
    combat(m, true)
    -- red under: drop the preview branch from Preview's onRestrictionChanged
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview ended: you entered combat.", 1, true) ~= nil, m.prints[1])
    assertEqual(NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1]:GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(#m.blocked, 0)
end)

test("preview: [phase 3] refused in combat and while disabled, with one line each", function()
    local NS, m = live()
    combat(m, true)
    m.prints = {}
    assertFalse(NS.Preview.SetPreviewAs("arena"))
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview is not available in combat.", 1, true) ~= nil, m.prints[1])
    combat(m, false)
    NS.addon:OnSlashCommand("disable")
    m.prints = {}
    assertFalse(NS.Preview.SetPreviewAs("arena"))
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("is disabled", 1, true) ~= nil, m.prints[1])
end)

test("preview: [review 3] the stand-down ends it silently, and so does closing the settings window", function()
    local NS, m = live()
    NS.Preview.SetPreviewAs("arena")
    NS.SchemaRuntime.Set("enabled", false)
    assertTrue(NS.Preview.PreviewAs() == nil)
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    -- red under: drop the WatchPanel call from Settings.Register in settings/Panel.lua
    m.SettingsPanel:__fire("OnHide")
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertTrue(arenaChip(NS) == nil, "back to the open world, where the arena set is not active")
end)

test("preview: [phase 3] test mode and Preview as are one switch at a time", function()
    local NS = live()
    local P = NS.Preview
    P.SetPreviewAs("arena")
    assertTrue(P.SetTestMode(true))
    assertTrue(P.PreviewAs() == nil, "test mode replaces the preview")
    assertTrue(P.SetPreviewAs("world"))
    assertFalse(P.IsTestMode(), "the preview replaces test mode")
    assertEqual(NS.Surfaces.Plans().p1.preview, "world")
    assertTrue(P.SetPreviewAs("current"))
    assertTrue(P.PreviewAs() == nil)
    assertFalse(P.SetPreviewAs("nope"))
end)

test("preview: [phase 3] the menu: Current, M+, each dungeon, each raid difficulty, Arena, each battleground, World", function()
    local NS = live()
    local P = NS.Preview
    assertEqual(P.Presets()[1].key, "current")
    for _, key in ipairs({ "mplus", "mplus:2526", "raid:lfr", "raid:normal", "raid:heroic", "raid:mythic",
        "arena", "bg:ab", "bg:wsg", "world" }) do
        assertTrue(P.FindPreset(key) ~= nil, key)
    end
    assertEqual(P.FindPreset("bg:ab").snapshot.instanceID, 529, "the battleground's lowest id")
    assertEqual(P.FindPreset("raid:heroic").snapshot.difficulty, "heroic")
    assertEqual(P.FindPreset("mplus:2526").snapshot.instanceID, 2526)
    assertTrue(P.FindPreset("nope") == nil)
end)

test("preview: [phase 3] a dungeon entry reads M+ · <dungeon> · <spec> (spec §13.3)", function()
    local NS = live()
    NS.Compat.SpecName = function() return "Frost" end
    NS.Compat.InstanceName = function(id) return id == 2526 and "Algeth'ar Academy" or nil end
    local DOT = " \194\183 "
    assertEqual(NS.Preview.FindPreset("mplus:2526").label, "M+" .. DOT .. "Algeth'ar Academy" .. DOT .. "Frost")
end)

test("preview: [phase 3] the Preview as row and `/qc preview` drive the same switch", function()
    local NS, m = live()
    local S = NS.SchemaRuntime
    assertEqual(S.Get("state.previewAs"), "current")
    assertTrue(S.Set("state.previewAs", "arena"))
    assertEqual(NS.Preview.PreviewAs(), "arena")
    assertFalse((S.Set("state.previewAs", "nope")), "not a situation")
    m.prints = {}
    NS.addon:OnSlashCommand("preview off")
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertTrue(m.prints[#m.prints]:find("Preview off.", 1, true) ~= nil, m.prints[#m.prints])
    m.prints = {}
    NS.addon:OnSlashCommand("preview")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("raid:heroic", 1, true) ~= nil, text)
    NS.addon:OnSlashCommand("preview bg:ab")
    assertEqual(NS.Preview.PreviewAs(), "bg:ab")
    m.prints = {}
    NS.addon:OnSlashCommand("preview nope")
    assertTrue(m.prints[1]:find("No situation named nope", 1, true) ~= nil, m.prints[1])
end)

test("preview: [final 13] `/qc preview` reads the situation's name without regard to case", function()
    local NS, m = live()
    -- red under: FindPreset on the key as typed (Arena is not arena)
    NS.addon:OnSlashCommand("preview Arena")
    assertEqual(NS.Preview.PreviewAs(), "arena")
    m.prints = {}
    NS.addon:OnSlashCommand("preview OFF")
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertTrue(m.prints[#m.prints]:find("Preview off.", 1, true) ~= nil, m.prints[#m.prints])
end)
