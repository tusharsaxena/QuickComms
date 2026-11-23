-- tests/test_autothank_testmode.lua — /qc test shows a sample auto-thank toast (FB-QC-02, owner
-- feedback 2026-11-24: "Toast does not show in /qc test"). modules/AutoThank_Toast.lua hears
-- TEST_MODE_CHANGED: test mode proper (not Preview as) puts up one sample "buffed you" toast through
-- the library's Toast:Preview (sticky, at the head, under Toast.PREVIEW), its Thank button a plain
-- placeholder (no secure child, so the combat edge can always take it down) and its note saying so; whether Auto-thank is on or off (the lead's decision Q). Ending
-- test mode takes it down. The pump, the cooldown and the host's pending list are never touched.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertNil, T.assertTrue, T.assertFalse

local function live()
    local NS, _, m = T.enableAddon()
    m.issecretvalue = T.isSecret
    m.EMOTE98_TOKEN, m.EMOTE98_CMD1 = "THANK", "/thank"   -- the client's emote globals
    NS.Emotes.Reset()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    m.__now = 1000
    local TH = NS.AutoThankToast
    return NS, m, TH, m.LibStub("LibKa0s-Toast-1.0").PREVIEW
end

test("autothank test mode: /qc test shows one sample toast, its Thank button a placeholder", function()
    local NS, m, TH, KEY = live()
    assertNil(TH.toast:FrameFor(KEY), "no sample before test mode")
    NS.addon:OnSlashCommand("test")
    assertTrue(NS.Preview.IsTestMode())
    local f = TH.toast:FrameFor(KEY)
    -- red under: nothing in test mode raises a toast (the owner's report)
    assertTrue(f ~= nil, "the sample toast is on screen")
    assertEqual(TH.toast:Stats().visible, 1)
    assertEqual(f.qcText:GetText(), NS.L["%s buffed you with %s"]:format(NS.L["A stranger"], NS.L["a sample buff"]))
    assertEqual(f.qcNote:GetText(), NS.L["Test mode: a placeholder that sends nothing."])
    local b = f.qcSample
    assertTrue(b ~= nil and b:IsShown(), "it carries a Thank button")
    assertEqual(b.qcLabel:GetText(), NS.L["Thank"])
    assertNil(f.qcThank, "no secure Thank button made for the sample")
    m.prints = {}
    m.__click(b)
    assertEqual(#m.sentMacros, 0, "a click sends nothing")
    local said = m.prints[#m.prints] or ""
    assertTrue(said:find(NS.Preview.TestEcho(NS.L["Thank"]), 1, true) ~= nil, "it says so: " .. said)
end)

test("autothank test mode: a frame that carried a real toast hides and disarms its secure button for the sample", function()
    local NS, m, TH, KEY = live()
    local guid = "Player-2-00000103"
    m.players[guid] = { name = "Caster3", realm = "Mock Realm" }
    local a = m.addAura{ casterGUID = guid, spellId = 1459 }
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { a } })
    local f = TH.toast:FrameFor(guid .. ":1459")
    assertTrue(f.qcThank.qcArmed)
    TH.toast:Dismiss()
    NS.Preview.SetTestMode(true)
    assertTrue(TH.toast:FrameFor(KEY) == f, "the pool frame is reused")
    assertFalse(f.qcThank.qcArmed, "disarmed")
    assertFalse(f.qcThank:IsShown(), "hidden")
    assertTrue(f.qcSample:IsShown(), "the placeholder stands in its place")
end)

test("autothank test mode: test mode ended after lockdown began takes the sample down unblocked", function()
    local NS, m, TH, KEY = live()
    NS.Preview.SetTestMode(true)
    m.__setCombat(true)                    -- InCombatLockdown() is already true when the edge fires
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.blocked, 0, "red under: a secure Thank button on the sample's frame")
    assertNil(TH.toast:FrameFor(KEY))
end)

test("autothank test mode: the sample shows whether Auto-thank is on or off", function()
    local NS, _, TH, KEY = live()
    NS.db.profile.thank.enabled = false
    NS.Preview.SetTestMode(true)
    assertTrue(TH.toast:FrameFor(KEY) ~= nil, "a preview, so the setting does not hide it")
end)

test("autothank test mode: ending test mode takes the sample down", function()
    local NS, _, TH, KEY = live()
    NS.Preview.SetTestMode(true)
    assertTrue(TH.toast:FrameFor(KEY) ~= nil)
    NS.Preview.SetTestMode(false)
    assertNil(TH.toast:FrameFor(KEY), "red under: a sample left up after test mode")
    assertEqual(TH.toast:Stats().visible, 0)
    assertEqual(TH.toast:Stats().waiting, 0, "nothing queued behind")
end)

test("autothank test mode: Preview as shows no sample, and switching to it takes one down", function()
    local NS, _, TH, KEY = live()
    NS.Preview.SetTestMode(true)
    assertTrue(TH.toast:FrameFor(KEY) ~= nil)
    NS.Preview.SetPreviewAs("arena")
    assertFalse(NS.Preview.IsTestMode())
    assertNil(TH.toast:FrameFor(KEY), "Preview as is not test mode proper")
end)

test("autothank test mode: the sample never fades away while test mode is on", function()
    local NS, m, TH, KEY = live()
    NS.Preview.SetTestMode(true)
    local f = TH.toast:FrameFor(KEY)
    assertNil(f.qcDue, "no fade clock on the sample")
    m.__now = m.__now + NS.Constants.THANK.DURATION * 2
    f:GetScript("OnUpdate")(f, 1)
    assertEqual(f:GetAlpha(), 1, "still at full alpha")
    assertTrue(TH.toast:FrameFor(KEY) == f, "sticky: still on screen")
end)

test("autothank test mode: real offers, the pump and the cooldowns are untouched", function()
    local NS, m, TH, KEY = live()
    local guid = "Player-2-00000101"
    m.players[guid] = { name = "Caster1", realm = "Mock Realm" }
    NS.Preview.SetTestMode(true)
    assertEqual(#TH.pending, 0, "the sample is not in the host's list")
    assertNil(TH.pumpTimer, "and arms no pump")
    local a = m.addAura{ casterGUID = guid, spellId = 1459 }
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { a } })
    local f = TH.toast:FrameFor(guid .. ":1459")
    assertTrue(f ~= nil, "a real buff still toasts beside the sample")
    assertTrue(f.qcThank.qcArmed, "and its Thank button is armed")
    assertTrue(TH.toast:FrameFor(KEY) ~= nil, "the sample stays up")
    NS.Preview.SetTestMode(false)
    assertTrue(TH.toast:FrameFor(guid .. ":1459") ~= nil, "ending test mode leaves the real toast")
end)

test("autothank test mode: a reused pool frame is armed again for a real offer after the sample", function()
    local NS, m, TH, KEY = live()
    NS.Preview.SetTestMode(true)
    local f = TH.toast:FrameFor(KEY)
    NS.Preview.SetTestMode(false)
    local guid = "Player-2-00000102"
    m.players[guid] = { name = "Caster2", realm = "Mock Realm" }
    local a = m.addAura{ casterGUID = guid, spellId = 1459 }
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { a } })
    local g = TH.toast:FrameFor(guid .. ":1459")
    assertTrue(g == f, "the pool frame is reused")
    assertTrue(g.qcThank.qcArmed, "armed for the real caster")
    assertTrue(g.qcThank:IsShown() and not g.qcSample:IsShown(), "the secure button back, the placeholder hidden")
    assertEqual(g.qcNote:GetText() or "", "", "the placeholder note is gone")
    assertTrue(g.qcDue ~= nil, "the real toast fades")
end)

test("autothank test mode: test mode refused in combat shows no sample", function()
    local NS, m, TH, KEY = live()
    m.inCombat = true
    NS.Preview.SetTestMode(true)
    assertFalse(NS.Preview.IsTestMode())
    assertNil(TH.toast:FrameFor(KEY))
end)
