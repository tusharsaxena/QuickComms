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

local function arenaButton(NS)
    return NS.Pad.ButtonsFor("p1", NS.Library.Group(T.seeded(NS, "bi.arena")).callouts[1])[1]
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

test("preview: [phase 3] Preview as Arena builds the pad from the arena snapshot, every button disarmed", function()
    local NS = live()
    assertTrue(NS.SchemaRuntime.Set("locked", true))
    local out = heard(NS)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    assertEqual(table.concat(out, ","), "true")
    local plan = NS.Surfaces.Plans().p1
    assertEqual(plan.preview, "arena")
    assertEqual(plan.order[1], T.seeded(NS, "bi.arena"))
    local button = arenaButton(NS)
    assertTrue(button ~= nil, "the arena set is drawn in the open world")
    -- red under: drop `and not slot.preview` from Pad's arm (the previewed button is armed)
    assertTrue(button:GetAttribute("macrotext") == nil)
    local header = NS.Pad.Instance("p1").header
    assertEqual(header.qcSituation:GetText(), "Preview: Arena")
    -- red under: PREVIEW left in the header instead of the drag strip
    local handle = NS.Pad.Instance("p1").handle
    assertEqual(handle.label:GetText(), "Comms Pad  |cff19ff19PREVIEW|r")
    assertTrue(handle:IsShown(), "locked, the strip still shows to carry PREVIEW")
    NS.Preview.SetPreviewAs(nil)
    assertEqual(handle.label:GetText(), "Comms Pad")
    assertFalse(handle:IsShown(), "locked and live again: no strip")
end)

test("preview: [review 3] a previewed button sends nothing and reports nothing", function()
    local NS, m = live()
    NS.Preview.SetPreviewAs("arena")
    local results = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() results = results + 1 end)
    local before = #m.sentMacros
    m.__click(arenaButton(NS))
    assertEqual(#m.sentMacros, before)
    assertEqual(results, 0)
end)

test("preview: [review 3] a previewed solo button prints nothing, even with the self fallback", function()
    local NS, m = live()
    NS.SchemaRuntime.Set("behavior.soloFallback", "self")
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "smartGroup" })
    local gid = Lib.CreateGroup({ name = "Mine", callouts = { cid } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    assertTrue(NS.Preview.SetPreviewAs("world"))
    local button = NS.Pad.ButtonsFor("p1", cid)[1]
    assertTrue(button ~= nil, "the user group (an empty When) shows in the previewed open world")
    m.prints = {}
    m.__click(button)
    -- red under: keep `slot.selfText` in a previewed button's meta (modules/Pad.lua arm)
    assertEqual(#m.prints, 0)
end)

test("preview: [review 3] combat ends it with one line, and the live buttons come back armed", function()
    local NS, m = live(MPLUS)
    NS.Preview.SetPreviewAs("arena")
    m.prints = {}
    combat(m, true)
    -- red under: drop the preview branch from Preview's onRestrictionChanged
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview ended: you entered combat.", 1, true) ~= nil, m.prints[1])
    assertEqual(NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]:GetAttribute("macrotext"), "/p Pulling next pack")
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
    assertTrue(arenaButton(NS) == nil, "back to the open world, where the arena set is not active")
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

test("preview: [phase 3] the menu: Current, one M+ dungeon, each raid difficulty, Arena, each battleground, Solo", function()
    local NS = live()
    local P = NS.Preview
    local keys = {}
    for i, e in ipairs(P.Presets()) do keys[i] = e.key end
    assertEqual(keys[1], "current")
    -- red under: one entry per season dungeon (owner, 2026-10-22: one M+ entry, one dungeon)
    assertEqual(table.concat(keys, ",", 2, 6), "mplus,raid:lfr,raid:normal,raid:heroic,raid:mythic")
    for _, key in ipairs({ "arena", "bg:ab", "bg:wsg", "world" }) do
        assertTrue(P.FindPreset(key) ~= nil, key)
    end
    assertEqual(keys[#keys], "world", "Solo last")
    assertEqual(P.FindPreset("bg:ab").snapshot.instanceID, 529, "the battleground's lowest id")
    assertEqual(P.FindPreset("raid:heroic").snapshot.difficulty, "heroic")
    assertEqual(P.FindPreset("raid:heroic").snapshot.instanceID, NS.GameIds.RAIDS[1], "the tier's first raid")
    assertEqual(P.FindPreset("mplus").snapshot.instanceID, 2805, "a current-season dungeon: Windrunner Spire")
    assertTrue(P.FindPreset("nope") == nil)
end)

test("preview: the menu's labels: one dungeon, each difficulty with the raid, BG - <name>, Solo", function()
    local NS = live()
    NS.Compat.SpecName = function() return "Frost" end
    NS.Compat.InstanceName = function(id)
        return ({ [2805] = "Windrunner Spire", [2912] = "The Voidspire" })[id]
    end
    local P, DOT = NS.Preview, " \194\183 "
    assertEqual(P.FindPreset("raid:lfr").label, "Raid" .. DOT .. "LFR" .. DOT .. "The Voidspire")
    assertEqual(P.FindPreset("raid:mythic").label, "Raid" .. DOT .. "Mythic" .. DOT .. "The Voidspire")
    -- red under: the battleground's name alone
    assertEqual(P.FindPreset("bg:ab").label, "BG - Arathi Basin")
    -- red under: "World · Solo"
    assertEqual(P.FindPreset("world").label, "Solo")
end)

test("preview: [phase 3] a dungeon entry reads M+ · <dungeon> · <spec> (spec §13.3)", function()
    local NS = live()
    NS.Compat.SpecName = function() return "Frost" end
    NS.Compat.InstanceName = function(id) return id == 2805 and "Windrunner Spire" or nil end
    local DOT = " \194\183 "
    assertEqual(NS.Preview.FindPreset("mplus").label, "M+" .. DOT .. "Windrunner Spire" .. DOT .. "Frost")
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

test("preview: [final 10] a dungeon preview fills {dungeon}, and the header names the preview as its menu does", function()
    local NS = live()
    NS.Compat.InstanceName = function(id) return id == 2805 and "Windrunner Spire" or nil end
    local cid = NS.Library.CreateCallout({ name = "Go", text = "Go {dungeon} +{key}", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { cid }, when = { content = { mythicPlus = true } } })
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    assertTrue(NS.Preview.SetPreviewAs("mplus"))
    -- red under: Surfaces.BakeContext reads only the challengeMapID, which a preview has none of
    assertEqual(NS.Surfaces.BakeContext(NS.Preview.PreviewSnapshot()).dungeon, "Windrunner Spire")
    local slot = NS.Surfaces.Plans().p1.sections[1].slots[1]
    assertEqual(slot.line, "/p Go Windrunner Spire +10")
    local DOT = " \194\183 "
    -- red under: the preview header reads SituationText (no dungeon, and every raid reads "Raid")
    local header = NS.Pad.Instance("p1").header.qcSituation:GetText()
    assertEqual(header, "Preview: " .. NS.Preview.Label("mplus"))
    assertTrue(header:find("M+" .. DOT .. "Windrunner Spire", 1, true) ~= nil, header)
    NS.Preview.SetPreviewAs("raid:mythic")
    assertTrue(NS.Pad.Instance("p1").header.qcSituation:GetText():find("Preview: Raid" .. DOT .. "Mythic", 1, true) ~= nil)
end)

-- ── the preview echo (2026-10-20): a previewed press prints the line it would have sent ──────

-- A user group with one callout, shown in the previewed open world (an empty When).
local function echoGroup(NS, text, channel)
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Echo", text = text, channel = channel })
    local gid = Lib.CreateGroup({ name = "Echoes", callouts = { cid } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    Lib.AddGroupToSurface("dial", "d2", gid, 1)
    return cid, gid
end

test("preview: [echo] a previewed button prints [QC] /<slash> <resolved text>, and still sends nothing", function()
    local NS, m = live()
    local cid = echoGroup(NS, "Go {me}", "yell")
    assertTrue(NS.Preview.SetPreviewAs("world"))
    local button = NS.Pad.ButtonsFor("p1", cid)[1]
    assertTrue(button ~= nil)
    local results = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() results = results + 1 end)
    local before = #m.sentMacros
    m.prints = {}
    m.__click(button)
    -- red under: drop `echo = preview and slot.line` from Pad's arm (modules/Pad.lua)
    assertEqual(#m.prints, 1)
    assertEqual(m.prints[1], NS.PREFIX .. " /y Go " .. NS.Compat.PlayerName())
    assertEqual(#m.sentMacros, before, "nothing reaches chat")
    assertEqual(results, 0, "nothing reported")
    assertTrue(button:GetAttribute("macrotext") == nil, "still disarmed")
end)

test("preview: [echo] the slash follows the channel the previewed situation resolves", function()
    local NS, m = live()
    local cid = echoGroup(NS, "Incoming", "smartGroup")
    assertTrue(NS.Preview.SetPreviewAs("raid:heroic"))
    m.prints = {}
    m.__click(NS.Pad.ButtonsFor("p1", cid)[1])
    assertEqual(m.prints[1], NS.PREFIX .. " /raid Incoming")
end)

test("preview: [echo review 3] a padlocked previewed button echoes its line, naming no lock", function()
    local NS, m = live()
    local cid = echoGroup(NS, "Pull", "raid")
    assertTrue(NS.Preview.SetPreviewAs("world"))
    local button = NS.Pad.ButtonsFor("p1", cid)[1]
    assertTrue(button ~= nil)
    m.prints = {}
    m.__click(button)
    -- locks read the real group, not the previewed situation: the echo is what it would send
    assertEqual(m.prints[1], NS.PREFIX .. " /raid Pull")
end)

test("preview: [echo] a live button prints nothing extra", function()
    local NS, m = live()
    local cid = echoGroup(NS, "Hello", "say")
    local button = NS.Pad.ButtonsFor("p1", cid)[1]
    assertEqual(button:GetAttribute("macrotext"), "/s Hello")
    m.prints = {}
    m.__click(button)
    assertEqual(#m.prints, 0)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/s Hello")
end)

test("preview: [echo] the edit preview echoes too, and a press in combat prints without writing", function()
    local NS, m = live()
    local cid, gid = echoGroup(NS, "Stack", "party")
    assertTrue(NS.Preview.SetEditPreview(gid))
    local button = NS.Pad.ButtonsFor("p1", cid)[1]
    m.prints = {}
    m.__click(button)
    assertEqual(m.prints[1], NS.PREFIX .. " /p Stack")
    -- In combat (the meta is already baked): a press prints and changes no secure attribute.
    m.__setCombat(true)
    local type0, text0 = button:GetAttribute("type"), button:GetAttribute("macrotext")
    NS.SendEngine.OnClick(button, "LeftButton", false)
    NS.SendEngine.OnClick(button, "LeftButton", true)
    assertEqual(#m.prints, 2)
    assertEqual(button:GetAttribute("type"), type0)
    assertEqual(button:GetAttribute("macrotext"), text0)
    assertEqual(#m.blocked, 0)
    m.__setCombat(false)
end)

test("preview: [echo] a previewed dial wedge prints the line too", function()
    local NS, m = live()
    local cid = echoGroup(NS, "Lust now", "instance")
    assertTrue(NS.Preview.SetPreviewAs("mplus"))
    local w = NS.Dial.WedgesFor("d2", cid)[1]
    assertTrue(w ~= nil, "the previewed dial draws the wedge")
    assertTrue(w:GetAttribute("macrotext") == nil, "disarmed")
    local before = #m.sentMacros
    m.prints = {}
    m.__click(w)
    assertEqual(m.prints[#m.prints], NS.PREFIX .. " /i Lust now")
    assertEqual(#m.sentMacros, before)
end)
