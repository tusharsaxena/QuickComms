-- tests/test_anim.lua — the open and close animations' settings and state machine (#13): the schema
-- rows, the migration, the pure pose math, and a track through interrupts and the stand-down.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function near(a, b, what)
    assertTrue(math.abs(a - b) < 1e-6, (what or "near") .. ": " .. tostring(a) .. " vs " .. tostring(b))
end

-- A track on a counted fake surface, its ghost stubbed: only the state machine runs.
local function track(NS, cfgs)
    local held, released = 0, 0
    local spec = { src = {}, roots = function() return {} end,
        config = function(phase) return cfgs[phase] end, restAlpha = function() return 1 end,
        hold = function() held = held + 1 end, release = function() released = released + 1 end }
    NS.AnimGhost.New = function() return {} end
    NS.AnimGhost.Capture = function() return cfgs.captured ~= false end
    NS.AnimGhost.Pose, NS.AnimGhost.Show, NS.AnimGhost.Hide = function() end, function() end, function() end
    return NS.Anim.NewTrack(spec), function() return held, released end
end

local SF = { style = "scaleFade", duration = 0.2 }
local FADE = { style = "fade", duration = 0.1 }

test("anim: a new pad and dial carry the shipped defaults, on for everyone", function()
    local NS = T.enableAddon()
    local pad, dial = NS.db.profile.pads.p1, NS.db.profile.dials.d2
    assertEqual(pad.anim.openStyle, "fadeScale")
    assertEqual(pad.anim.closeStyle, "fadeScale")
    assertEqual(pad.anim.openDuration, 0.15)
    assertEqual(pad.anim.closeDuration, 0.1)
    assertEqual(dial.anim.openStyle, "scaleFade")
    assertEqual(dial.anim.closeStyle, "scaleFade")
end)

test("anim: step 12 fills every stored surface and keeps a key already there", function()
    local NS = T.enableAddon()
    local p = { pads = { a = { anim = { openStyle = "none" } }, b = {}, bad = true }, dials = { c = { anim = 3 } } }
    -- red under: no step
    NS.Library.MigrateAnim(p)
    assertEqual(p.pads.a.anim.openStyle, "none", "the player's pick stays")
    assertEqual(p.pads.a.anim.closeStyle, "fadeScale", "a missing key is filled")
    assertEqual(p.pads.b.anim.closeDirection, "down")
    assertEqual(p.dials.c.anim.openStyle, "scaleFade", "a damaged table is replaced")
    NS.Library.MigrateAnim(p)
    assertEqual(p.pads.a.anim.openStyle, "none", "idempotent")
    NS.Library.MigrateAnim({ pads = 3 })
end)

test("anim: the runner takes an old profile's pads and dials to the defaults", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    db.profile.pads.p1.anim, db.profile.dials.d2.anim = nil, nil
    db.global.schemaVersion = 11
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(db.profile.pads.p1.anim.openStyle, "fadeScale")
    assertEqual(db.profile.dials.d2.anim.closeStyle, "scaleFade")
end)

test("anim: each knob writes its own key and nothing else, on the surface it names", function()
    local NS = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    local a = NS.db.profile.pads.p1.anim
    -- red under: one row writing two keys (the owner's four independent switches)
    assertTrue(Set("pad.anim.closeStyle", "none", "p1"))
    assertEqual(a.closeStyle, "none")
    assertEqual(a.openStyle, "fadeScale", "the open is untouched")
    assertEqual(NS.db.profile.dials.d2.anim.closeStyle, "scaleFade", "the dial is untouched")
    assertTrue(Set("dial.anim.openStyle", "none", "d2"))
    assertEqual(NS.db.profile.dials.d2.anim.closeStyle, "scaleFade", "the dial's close is untouched")
    assertEqual(a.openStyle, "fadeScale", "the pad is untouched")
end)

test("anim: a style or duration out of range is refused or clamped", function()
    local NS = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    assertFalse(Set("dial.anim.openStyle", "pop", "d2"), "Pop is a pad's")
    assertFalse(Set("pad.anim.openStyle", "fan", "p1"), "Fan is a dial's")
    assertTrue(Set("pad.anim.openDuration", 9, "p1"))
    assertEqual(NS.db.profile.pads.p1.anim.openDuration, 0.3)
end)

test("anim: the hidden poses match the owner's rulings", function()
    local A = T.enableAddon().Anim
    assertNil(A.Hidden("none", "open"))
    assertEqual(A.Hidden("scaleFade", "open").scale, 0.8, "about 80%")
    assertEqual(A.Hidden("fan", "open").fan, 0)
    assertEqual(A.Hidden("fade", "close").scale, 1)
    local up = A.Hidden("slide", "open", "up")
    assertEqual(up.y, -A.SLIDE, "Up on open starts below")
    assertEqual(A.Hidden("slide", "close", "up").y, A.SLIDE, "Up on close leaves upward")
    assertEqual(A.Hidden("slide", "open", "left").x, A.SLIDE)
end)

test("anim: every ease lands exactly, and Pop overshoots", function()
    local A = T.enableAddon().Anim
    for _, style in ipairs({ "fade", "pop" }) do
        for _, phase in ipairs({ "open", "close" }) do
            near(A.Ease(style, phase, 0), 0, style)
            near(A.Ease(style, phase, 1), 1, style)
        end
    end
    assertTrue(A.Ease("pop", "open", 0.7) > 1, "the overshoot")
    assertTrue(A.Ease("pop", "close", 0.2) < 0, "the wind-up")
end)

test("anim: the Fan is whole at rest, gone when hidden, and sweeps in order", function()
    local A = T.enableAddon().Anim
    assertEqual(A.FanAlpha(1, 0.9), 1)
    assertEqual(A.FanAlpha(0, 0), 0)
    assertTrue(A.FanAlpha(0.3, 0) > A.FanAlpha(0.3, 0.5), "the first place leads")
end)

test("anim: an open plays, holds the real frame and lands with it back", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t, counts = track(NS, { open = SF, close = FADE })
    assertTrue(A.Open(t))
    assertTrue(A.Holding(t))
    assertEqual((counts()), 1, "held")
    A.Step(t, 0.1)
    assertTrue(t.pose.scale > 0.8 and t.pose.scale < 1)
    A.Step(t, 0.1)
    assertNil(t.phase, "landed")
    assertFalse(A.Holding(t))
    assertFalse(A.Running())
    assertEqual(select(2, counts()), 1, "released once")
end)

test("anim: a close mid-open reverses from where it stands, with no jump", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    A.Open(t)
    A.Step(t, 0.05)
    local alpha, scale = t.pose.alpha, t.pose.scale
    assertTrue(A.Close(t))
    assertEqual(t.pose.alpha, alpha, "the alpha carries over")
    assertEqual(t.pose.scale, scale, "the scale carries over")
    assertTrue(t.duration < SF.duration, "only the way back")
    A.Step(t, 1)
    assertNil(t.phase, "landed closed")
end)

test("anim: a reopen mid-close reverses from where it stands and lands at rest", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    assertTrue(A.Close(t))
    A.Step(t, 0.05)
    local alpha = t.pose.alpha
    assertTrue(alpha < 1)
    assertTrue(A.Open(t))
    assertEqual(t.pose.alpha, alpha)
    assertTrue(t.to.alpha == 1 and t.to.scale == 1)
    A.Step(t, 1)
    assertNil(t.phase)
end)

test("anim: rapid toggling ends on the last call, nothing left held", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    for _ = 1, 25 do
        A.Open(t)
        A.Step(t, 0.01)
        A.Close(t)
        A.Step(t, 0.01)
    end
    A.Step(t, 5)
    assertNil(t.phase)
    assertFalse(A.Holding(t))
    assertFalse(A.Running())
end)

test("anim: None on one phase snaps that phase and leaves the other playing", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = { style = "none", duration = 0.1 }, close = SF })
    -- red under: one switch for both
    assertFalse(A.Open(t), "open off")
    assertFalse(A.Running())
    assertTrue(A.Close(t), "close still on")
    A.Snap(t)
    t = track(NS, { open = SF, close = { style = "none", duration = 0.1 } })
    assertTrue(A.Open(t), "open still on")
    assertFalse(A.Close(t), "close off: mid-open it lands closed at once")
    assertNil(t.phase)
end)

test("anim: a capture with nothing to draw snaps, and never holds the frame", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t, counts = track(NS, { open = SF, close = SF, captured = false })
    assertFalse(A.Open(t))
    assertEqual((counts()), 0, "never held invisible")
end)

test("anim: the stand-down leaves no track and no OnUpdate running", function()
    local NS, m = T.enableAddon()
    local A = NS.Anim
    local t, counts = track(NS, { open = SF, close = SF })
    A.Open(t)
    assertTrue(A.Running())
    local before = #m.__timers()
    assertTrue(before > 0, "the driver ticks")
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(A.Running())
    assertNil(t.phase)
    assertEqual(select(2, counts()), 1, "the frame came back")
    assertEqual(#m.__timers(), 0, "no OnUpdate left armed")
end)

test("anim: the emphasis is heard only on a close, and an open clears it", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    A.Open(t)
    A.Emphasize(t, 3)
    assertNil(t.emphasis, "not while opening")
    A.Close(t)
    A.Emphasize(t, 3)
    assertEqual(t.emphasis, 3)
    A.Open(t)
    assertNil(t.emphasis, "a reopen drops it")
end)
