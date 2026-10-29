-- tests/test_diagnostics.lua — the addon's own sections of the diagnostics report
-- (debug-logging-§14). The contract around them (both forms, append, the run turning logging on,
-- the markers, no alias) is the kit's test_diagnostics_contract.lua, run against this dispatcher.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function report(NS)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    return table.concat(NS.DebugLog.buffer, "\n")
end

test("diagnostics: the sections are the addon's, in report order", function()
    local NS = T.newAddon()
    local names = {}
    for i, s in ipairs(NS.Diagnostics.Sections()) do names[i] = s[1] end
    assertEqual(table.concat(names, ","),
        "identity,settings,registration,integrations,situation,restrictions,library,surfaces,dials,bindings,send")
end)

test("diagnostics: the report names the schema, the profile, the holds and the launcher", function()
    local NS = T.enableAddon()
    local text = report(NS)
    assertTrue(text:find("schema stored=10 code=10", 1, true) ~= nil, "identity")
    assertTrue(text:find("profile=Default", 1, true) ~= nil, text)
    assertTrue(text:find("feature events registered=true", 1, true) ~= nil, "registration")
    assertTrue(text:find("launcher: registered=true", 1, true) ~= nil, "integrations")
end)

test("diagnostics: it runs while stood down and says so, without acting", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local text = report(NS)
    assertTrue(text:find("stoodDown=true", 1, true) ~= nil)
    assertTrue(text:find("holds disabled", 1, true) ~= nil, text)
    assertTrue(NS.IsStoodDown(), "the report changed nothing")
end)

test("diagnostics: `enabled` is always listed, and a hidden minimap button is listed", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("global.minimap.shown", false)
    local text = report(NS)
    assertTrue(text:find("enabled", 1, true) ~= nil)
    assertTrue(text:find("global.minimap.shown", 1, true) ~= nil, text)
end)

test("diagnostics: the situation and library sections report the snapshot and the registry", function()
    local NS = T.enableAddon()
    local text = report(NS)
    assertTrue(text:find("lockdown=", 1, true) ~= nil, "situation")
    assertTrue(text:find("callouts=", 1, true) ~= nil and text:find("active=", 1, true) ~= nil, "library")
end)

test("diagnostics: [final 1] the restriction section names the active reasons and canSendChat", function()
    local NS, m = T.enableAddon()
    m.restrictionStates[m.Enum.AddOnRestrictionType.Encounter] = m.Enum.AddOnRestrictionState.Active
    m.chatLockdown = true
    local text = report(NS)
    assertTrue(text:find("active=chatLockdown,encounter reason=encounter canSendChat=false", 1, true) ~= nil, text)
end)

test("diagnostics: the surfaces and send sections name the pads, the armed buttons and the guard", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    -- M+ alone: In Group (active in any party, bg buttons) off, so the counts below stay M+'s
    NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.group"))
    NS.Situation.RefreshNow("test")
    local text = report(NS)
    assertTrue(text:find("p1 active=" .. T.seeded(NS, "bi.mplus") .. " stale=false", 1, true) ~= nil, text)
    -- the pad's 7 buttons, and the default dial's 8 wedges (1 group wedge, then 7 callouts on one Auto
    -- page) and its two rings' page arrows (2 each, never armed): 19 buttons, 14 armed
    assertTrue(text:find("buttons=19 armed=14", 1, true) ~= nil, text)
    assertTrue(text:find("p1:" .. T.seeded(NS, "bi.mplus.pull") .. " /p Pulling next pack", 1, true) ~= nil, text)
    assertTrue(text:find("pending -", 1, true) ~= nil, "no queued keys")
    assertTrue(text:find("window=1", 1, true) ~= nil, "the guard")
    assertTrue(text:find("sent=0 dropped=0", 1, true) ~= nil, "the echo counts")
end)

test("diagnostics: [phase 3] the surfaces section names the preview", function()
    local NS = T.enableAddon()
    NS.Situation.RefreshNow("test")
    assertTrue(report(NS):find("previewAs=off", 1, true) ~= nil)
    assertTrue(report(NS):find("previewWindow=hidden", 1, true) ~= nil)
    NS.Preview.SetPreviewAs("arena")
    assertTrue(report(NS):find("previewAs=arena", 1, true) ~= nil)
    -- red under: drop the previewWindow line from modules/Diagnostics.lua
    assertTrue(report(NS):find("previewWindow=shown", 1, true) ~= nil)
end)

test("diagnostics: [final 21] the settings section lists no member row", function()
    local NS = T.enableAddon()
    local cid = NS.Library.CreateCallout({ name = "Lust", text = "Lust", channel = "party", icon = 136012 })
    NS.Library.CreateGroup({ name = "Mine", callouts = { cid } })
    local text = report(NS)
    -- red under: run nonDefaults over every schema row (the first member's fields read as settings)
    for _, prefix in ipairs({ "callout.", "group.", "pad.", "dial." }) do
        assertTrue(text:find(" " .. prefix, 1, true) == nil, prefix .. "\n" .. text)
    end
end)
test("diagnostics: [phase 4] the dials and bindings sections name each dial, its key and each entry's WoW binding", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    -- M+ alone: In Group (active in any party, bg buttons) off, so the counts below stay M+'s
    NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.group"))
    NS.Situation.RefreshNow("test")
    m.SetBinding("G", "CLICK QuickCommsDial1:Toggle")
    local text = report(NS)
    assertTrue(text:find("d2 QuickCommsDial1 key=G rings=2 openRing=2 open=false active=" .. T.seeded(NS, "bi.mplus") .. " stale=false", 1, true)
        ~= nil, text)
    assertTrue(text:find("G -> CLICK QuickCommsDial1:Toggle", 1, true) ~= nil, text)
    assertTrue(text:find("none -> CLICK QuickCommsDial2:Toggle", 1, true) ~= nil, text)
    assertTrue(text:find("d2:" .. T.seeded(NS, "bi.mplus.pull") .. " /p Pulling next pack", 1, true) ~= nil, "the armed wedges")
end)

test("diagnostics: [dial rework] the report names the pads' hidden state, each dial's look, the ring shown and every ring", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    local text = report(NS)
    -- red under: drop the dial look and ring lines from modules/Diagnostics.lua dials
    assertTrue(text:find("padsHidden=false (this character)", 1, true) ~= nil, text)
    assertTrue(text:find("d2 shown=closed", 1, true) ~= nil, text)
    assertTrue(text:find("d2 look mode=categories slices=0 radius=120 iconOffset=0 openAt=center", 1, true) ~= nil, text)
    -- red under: keep border= (the retired slice border) in modules/Diagnostics.lua dialLook
    assertTrue(text:find("d2 slices gap=0 pointer=true size=24 offset=24 labels=true size=12 offset=0 tooltip=top/8", 1, true)
        ~= nil, text)
    assertTrue(text:find("d2 paging offset=6 arrow=24 gap=10 dot=8 pill=18 dotGap=6 back=true pad=4 border=2", 1, true) ~= nil, text)
    -- red under: drop the hub line or the group labels' show from modules/Diagnostics.lua dialLook
    assertTrue(text:find("d2 hub style=solid size=32 circle=24 line=4 border=1 groupLabels=true", 1, true) ~= nil, text)
    assertTrue(text:find("d2 ring 1 Comms Dial page=1/1", 1, true) ~= nil, "the ring of groups, M+ and In Group")
end)

test("diagnostics: [debug] the log follows a dial open, a ring shown, a press and a close, once each", function()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    report(NS)   -- a run turns logging on
    NS.DebugLog:Clear()
    m.SetBinding("G", "CLICK QuickCommsDial1:Toggle")
    m.__pressKey("G")
    local inst = NS.Dial.Instance("d2")
    local groups = inst.rings.active[1].qcWedges.active
    m.__click(groups[1])
    m.__click(NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1])
    local log = table.concat(NS.DebugLog.buffer, "\n")
    local function once(needle)
        local n = select(2, log:gsub(needle:gsub("%p", "%%%0"), ""))
        assertEqual(n, 1, needle .. "\n" .. log)
    end
    -- red under: no OnShow/OnHide debug hooks on the dial's header in modules/Dial.lua
    once("d2 opened")
    once("d2 shows Comms Dial")
    once("d2 shows Dungeon")
    -- red under: no press line in modules/SendEngine.lua press
    once("press " .. T.seeded(NS, "bi.mplus.pull") .. " on d2 -> PARTY")
    once("d2 closed")
end)

test("diagnostics: [shine] the pad's button line and the dial's slices line print the look and strength", function()
    local NS = T.enableAddon()
    NS.Situation.RefreshNow("test")
    local text = report(NS)
    -- red under: no button line in modules/Diagnostics.lua surfaces, or no shine= on dialLook's slices line
    assertTrue(text:find("p1 button shine=glossfade 80", 1, true) ~= nil, text)
    assertTrue(text:find("d2 slices gap=0 pointer=true size=24 offset=24 labels=true size=12 offset=0 tooltip=top/8 shine=orb 85",
        1, true) ~= nil, text)
    NS.SchemaRuntime.Set("pad.button.shineLook", "orb", "p1")
    NS.SchemaRuntime.Set("pad.button.shineStrength", 40, "p1")
    NS.SchemaRuntime.Set("dial.slice.shineLook", "bevel", "d2")
    text = report(NS)
    assertTrue(text:find("p1 button shine=orb 40", 1, true) ~= nil, text)
    assertTrue(text:find("tooltip=top/8 shine=bevel 85", 1, true) ~= nil, text)
end)
