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
    NS.AnimGhost.ScaleText, NS.AnimGhost.EmphasizeText = function() end, function() end
    return NS.Anim.NewTrack(spec), function() return held, released end
end

local SF = { style = "scaleInFade", duration = 0.2 }
local FADE = { style = "fade", duration = 0.1 }

test("anim: a new dial carries the shipped defaults, on for everyone, and a pad has no animation", function()
    local NS = T.enableAddon()
    local pad, dial = NS.db.profile.pads.p1, NS.db.profile.dials.d2
    assertEqual(dial.anim.openStyle, "rotateScale")
    assertEqual(dial.anim.closeStyle, "rotateScale")
    assertEqual(dial.anim.openDuration, 0.2)
    assertEqual(dial.anim.closeDuration, 0.2)
    assertNil(pad.anim, "animations are the dial's alone")
    assertNil(NS.Library.TEMPLATES.pad.anim, "a pad's shape has none to fill in")
    assertNil(NS.PadDefaults.PadAnim)
end)

test("anim: step 12 fills every stored dial, keeps a key already there, and leaves pads alone", function()
    local NS = T.enableAddon()
    local p = { pads = { a = {} }, dials = { c = { anim = 3 }, d = { anim = { openStyle = "none" } }, bad = true } }
    -- red under: no step
    NS.Library.MigrateAnim(p)
    assertEqual(p.dials.d.anim.openStyle, "none", "the player's pick stays")
    assertEqual(p.dials.d.anim.closeStyle, "rotateScale", "a missing key is filled")
    assertEqual(p.dials.c.anim.openStyle, "rotateScale", "a damaged table is replaced")
    assertNil(p.pads.a.anim, "a pad takes no animation")
    NS.Library.MigrateAnim(p)
    assertEqual(p.dials.d.anim.openStyle, "none", "idempotent")
    NS.Library.MigrateAnim({ dials = 3 })
end)

test("anim: the runner takes an old profile's dials to the defaults and writes no pad's", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    db.profile.dials.d2.anim = nil
    db.global.schemaVersion = 11
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(db.profile.dials.d2.anim.closeStyle, "rotateScale")
    assertNil(db.profile.pads.p1.anim)
end)

test("anim: step 14 takes a stored pad table from every profile that ran step 12, and nothing else", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    local stored = { openStyle = "pop", closeDirection = "left" }
    db.profile.pads.p1.anim = stored
    db.sv.profiles.other = { pads = { x = { anim = {} , name = "Kept" }, bad = 3 } }
    db.global.schemaVersion = 13
    local dialAnim = db.profile.dials.d2.anim
    dialAnim.openStyle = "fan"
    -- red under: step 12 still filling pads and no step to take it back
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertNil(db.profile.pads.p1.anim)
    assertNil(db.sv.profiles.other.pads.x.anim, "every stored profile, not the active one")
    assertEqual(db.sv.profiles.other.pads.x.name, "Kept")
    assertEqual(db.sv.profiles.other.pads.bad, 3)
    assertEqual(db.profile.dials.d2.anim, dialAnim, "a dial keeps its own")
    assertEqual(dialAnim.openStyle, "fan")
    -- once: a table that somehow came back is not walked again, and a second run changes nothing
    NS.Library.MigrateDropPadAnim(db.profile)
    assertNil(db.profile.pads.p1.anim, "idempotent")
    NS.Library.MigrateDropPadAnim(3)
    NS.Library.MigrateDropPadAnim({ pads = 3 })
    db.profile.pads.p1.anim = stored
    NS.addon:RunMigrations()
    assertEqual(db.profile.pads.p1.anim, stored, "the stamp holds: the step ran once")
    db.profile.pads.p1.anim = nil
end)

test("anim: each knob writes its own key and nothing else, on the surface it names", function()
    local NS = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    local a = NS.db.profile.dials.d2.anim
    -- red under: one row writing two keys (the owner's four independent switches, two left)
    assertTrue(Set("dial.anim.closeStyle", "none", "d2"))
    assertEqual(a.closeStyle, "none")
    assertEqual(a.openStyle, "rotateScale", "the open is untouched")
    assertTrue(Set("dial.anim.openStyle", "fan", "d2"))
    assertEqual(a.closeStyle, "none", "the close is untouched")
end)

test("anim: a style or duration out of range is refused or clamped", function()
    local NS = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    for _, gone in ipairs({ "fadeScale", "sideways" }) do
        assertFalse(Set("dial.anim.openStyle", gone, "d2"), gone .. " is no style")
    end
    assertTrue(Set("dial.anim.openDuration", 9, "d2"))
    assertEqual(NS.db.profile.dials.d2.anim.openDuration, 2)
end)

test("anim: the hidden poses match the owner's rulings", function()
    local A = T.enableAddon().Anim
    assertNil(A.Hidden("none"))
    assertEqual(A.Hidden("scaleInFade").scale, 0.25)
    assertEqual(A.Hidden("fan").fan, 0)
    assertEqual(A.Hidden("fade").scale, 1)
    for _, gone in ipairs({ "fadeScale", "scaleFade", "sideways" }) do assertNil(A.Hidden(gone), gone) end
end)

test("anim: an ease lands exactly, decelerating into an open and accelerating out of a close", function()
    local A = T.enableAddon().Anim
    for _, phase in ipairs({ "open", "close" }) do
        near(A.Ease(phase, 0), 0, phase)
        near(A.Ease(phase, 1), 1, phase)
    end
    near(A.Ease("open", 0.5), 0.75, "quick first")
    near(A.Ease("close", 0.5), 0.25, "slow first")
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
    assertEqual(t.phase, "open")
    assertEqual((counts()), 1, "held")
    A.Step(t, 0.1)
    assertTrue(t.pose.scale > 0.25 and t.pose.scale < 1)
    A.Step(t, 0.1)
    assertNil(t.phase, "landed")
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

test("anim: a reopen during a send starts the sent slice from where it stands, at rest", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = { style = "spiralIn", duration = 1 }, close = { style = "spiralOut", duration = 1 } })
    NS.AnimGhost.New = function() return { size = 4 } end
    local drawn
    NS.AnimGhost.Pose = function(_, pose) drawn = drawn or pose.places[2].radius end
    A.Close(t)
    A.Step(t, 0.6)
    A.Emphasize(t, 2)
    A.Step(t, 0.1)
    local other = t.pose.places[1].radius
    assertTrue(other > 1, "the rest are on their way out")
    drawn = nil
    A.Open(t)
    -- red under: the sent slice drew at rest through the close, and the pose never knew
    near(drawn, 1, "the first frame draws it there")
    local p = t.pose.places[2]
    near(p.radius, 1)
    near(p.angle, 0)
    near(p.scale, 1)
    near(p.spin, 0)
    near(p.alpha, 1)
    near(t.pose.places[1].radius, other, "the rest go on from their own pose")
end)

test("anim: settling a place a pose does not have is nothing to do", function()
    local A = T.enableAddon().Anim
    A.SettlePlace(A.Rest(), 2)
    local pose = A.Pose("spiralOut", 0, 4)
    A.SettlePlace(pose, 9)
    assertEqual(pose.places[1].radius, 2.1)
end)

-- ── the rest of the sweep (#13) ──────────────────────────────────────────────────────────────────

test("anim: a missing key reads its own phase's default", function()
    local A = T.enableAddon().Anim
    local defaults = { openDuration = 0.15, closeDuration = 0.1, openStyle = "fade", closeStyle = "fan" }
    local cfg = A.Config({}, defaults, "close")
    assertEqual(cfg.duration, 0.1)
    assertEqual(cfg.style, "fan")
    assertEqual(A.Config({ openStyle = "none" }, defaults, "open").style, "none")
end)

test("anim: every leg hands the text its scale, a reversal from where it stands", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    local legs, shown = {}, false
    NS.AnimGhost.Show = function() shown = true end
    NS.AnimGhost.ScaleText = function(_, from, to, duration, phase)
        legs[#legs + 1] = { from = from.scale, to = to.scale, duration = duration, phase = phase, shown = shown }
    end
    A.Open(t)
    assertEqual(legs[1].from, 0.25)
    assertEqual(legs[1].to, 1)
    assertEqual(legs[1].duration, 0.2)
    assertEqual(legs[1].phase, "open")
    assertTrue(legs[1].shown, "a hidden string would not play")
    A.Step(t, 0.05)
    local scale = t.pose.scale
    A.Close(t)
    local way = legs[2]
    assertEqual(way.from, scale, "no jump")
    assertEqual(way.to, 0.25)
    assertEqual(way.duration, t.duration, "the reversal's own time")
    assertEqual(way.phase, "close")
end)

test("anim: the emphasis tells the text once, over the close's time left", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    local heard = {}
    NS.AnimGhost.EmphasizeText = function(_, place, left) heard[#heard + 1] = { place, left } end
    A.Open(t)
    A.Emphasize(t, 3)
    assertEqual(#heard, 0, "not on an open")
    A.Snap(t)
    A.Close(t)
    A.Step(t, 0.05)
    A.Emphasize(t, 3)
    assertEqual(heard[1][1], 3)
    near(heard[1][2], 0.15, "the time left")
    A.Emphasize(t, 3)
    assertEqual(#heard, 1, "the hook and the close both name it: once")
end)

test("anim: a Snap leaves no emphasis behind", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    A.Close(t)
    A.Emphasize(t, 2)
    A.Snap(t)
    assertNil(t.emphasis)
end)

test("anim: a step draws with how far along it is, so the pulse moves", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = SF, close = SF })
    local got
    NS.AnimGhost.Pose = function(_, _, _, _, f) got = f end
    A.Close(t)
    A.Step(t, 0.1)
    assertEqual(got, 0.5)
end)

test("anim: step 12 walks past a damaged surface and a damaged list", function()
    local NS = T.enableAddon()
    local p = { dials = { bad = 3, good = {} } }
    NS.Library.MigrateAnim(p)
    assertEqual(p.dials.bad, 3)
    assertEqual(p.dials.good.anim.openStyle, "rotateScale")
end)

test("anim: step 12 reads a stored false as kept", function()
    local NS = T.enableAddon()
    local p = { dials = { a = { anim = { openStyle = false } } } }
    NS.Library.MigrateAnim(p)
    assertEqual(p.dials.a.anim.openStyle, false)
end)

test("anim: step 12 runs for every stored profile, not the active one", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    db.sv.profiles.other = { dials = { x = {} } }
    db.global.schemaVersion = 11
    NS.addon:RunMigrations()
    assertEqual(db.sv.profiles.other.dials.x.anim.openStyle, "rotateScale")
end)

test("anim: two dials never share their anim table", function()
    local NS = T.enableAddon()
    assertTrue(NS.db.profile.dials.d2.anim ~= NS.Library.TEMPLATES.dial.anim, "a dial's table is its own")
end)

test("anim: the rows are the owner's: Open and Close on the dial's Animation tab, knobs only while they apply", function()
    local NS = T.enableAddon()
    local function row(path)
        for _, r in ipairs(NS.addon.Settings.Schema) do
            if r.path == path then return r end
        end
    end
    local style = row("dial.anim.closeStyle")
    assertEqual(style.group, NS.L["Animation"])
    assertEqual(style.subgroup, NS.L["Close"])
    assertEqual(row("dial.anim.openStyle").subgroup, NS.L["Open"])
    local d = row("dial.anim.closeDuration")
    assertEqual(d.shownWhen.path, "dial.anim.closeStyle", "its own style hides it")
    for _, v in ipairs(d.shownWhen.equals) do assertTrue(v ~= "none", "None hides it") end
    for _, key in ipairs({ "openStyle", "openDuration", "openDirection", "closeStyle", "closeDuration", "closeDirection" }) do
        assertNil(row("pad.anim." .. key), "no pad row: " .. key)
    end
    local values = {}
    for _, c in ipairs(row("dial.anim.openStyle").values) do
        values[#values + 1] = c.value
        if c.value == "fan" then assertEqual(c.text, NS.L["Fan"]) end
        assertTrue(c.value ~= "scaleFade", "redundant with Scale in and fade (the owner, 2026-11-01)")
    end
    assertEqual(#values, 20)
    assertEqual(values[3], "fan")
    assertNil(rawget(NS.L, "Scale and fade"), "the label went with the style")
    assertEqual(row("dial.anim.openDuration").normalize(9), 2)
    assertFalse(NS.SchemaRuntime.Set("dial.anim.closeStyle", "sideways", "d2"))
end)

test("anim: a close never holds a frame that is already down, and a snap off no track releases nothing", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t, counts = track(NS, { open = SF, close = SF })
    A.Snap(t)
    assertEqual(select(2, counts()), 0, "nothing was held")
    A.Close(t)
    assertEqual((counts()), 0, "a close holds nothing")
end)

test("anim: step 12 takes a value that is no profile quietly", function()
    local NS = T.enableAddon()
    NS.Library.MigrateAnim(3)
    NS.Library.MigrateAnim(nil)
end)

-- ── the pose engine (#13, the dial styles): the mockup's motion as pure functions ───────────────────

local function clamp(v) return math.max(0, math.min(1, v)) end

-- The mockup's Inward spiral, as a style's `w`: the shape every per-place style takes.
local function spiral(NS)
    NS.Anim.STYLES.testSpiral = { w = function(e, _, _, p)
        p.radius, p.angle, p.alpha = e, (1 - e) * -2.4, clamp(e * 2.5)
    end }
    return "testSpiral"
end

test("anim pose: every style is hidden at 0 and whole at 1, and rests as A.Rest", function()
    local A = T.enableAddon().Anim
    local rest = A.Rest()
    for name in pairs(A.STYLES) do
        local p = A.Pose(name, 1, 4)
        for _, k in ipairs({ "alpha", "scale", "scaleX", "scaleY", "fan", "hub" }) do near(p[k], 1, name .. " " .. k) end
        for _, k in ipairs({ "rot", "dx", "dy", "flash" }) do near(p[k], rest[k], name .. " " .. k) end
        local hidden = A.Hidden(name, 4)
        assertEqual(hidden.alpha * hidden.hub * hidden.fan, 0, name .. " hides")
    end
end)

test("anim pose: Rotate and scale is the mockup's", function()
    local A = T.enableAddon().Anim
    local p = A.Pose("rotateScale", 0.2, 8)
    near(p.scale, 0.45 + 0.55 * 0.2)
    near(p.rot, 0.8 * -2.1, "about 120 degrees at the start")
    near(p.alpha, 0.5)
    near(A.Pose("rotateScale", 0.6, 8).alpha, 1, "whole well before it lands")
    assertNil(p.places, "a whole-dial style has none")
end)

test("anim pose: Back overshoots and Bounce rebounds, both landing exactly, as the mockup's", function()
    local A = T.enableAddon().Anim
    near(A.Back(0), 0)
    near(A.Back(1), 1)
    assertTrue(A.Back(0.7) > 1, "past it")
    near(A.Back(0.7), 1 + 0.09 * (2.9 * -0.3 + 1.9))
    near(A.Bounce(0), 0)
    near(A.Bounce(1), 1)
    near(A.Bounce(0.5), 7.5625 * (0.5 - 1.5 / 2.75) ^ 2 + 0.75)
    assertTrue(A.Bounce(0.72) < A.Bounce(0.6) or A.Bounce(0.8) < A.Bounce(0.72), "it comes back down")
end)

test("anim pose: a per-place style fills one entry per place, zero-based as the mockup, and fades the hub on its own", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local seen = {}
    A.STYLES.testSeen = { w = function(e, i, n, p) seen[#seen + 1] = i .. "/" .. n; p.alpha = e end }
    local p = A.Pose("testSeen", 0.25, 3)
    assertEqual(table.concat(seen, ","), "0/3,1/3,2/3")
    assertEqual(p.count, 3)
    near(p.places[2].alpha, 0.25)
    assertEqual(p.places[2].radius, 1, "the rest keeps its rest value")
    assertEqual(p.alpha, 1, "the whole dial stays whole")
    near(p.hub, 0.5, "the mockup's hub")
    A.STYLES.testSeen = nil
end)

test("anim pose: a style hears its config, for a direction", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local heard
    A.STYLES.testDir = { g = function(_, _, cfg) heard = cfg end }
    A.Pose("testDir", 0.5, 1, nil, { direction = "up" })
    assertEqual(heard.direction, "up")
    A.STYLES.testDir = nil
    assertEqual(A.Config({ openDirection = "left" }, {}, "open").direction, "left")
end)

test("anim pose: A.Pose and A.Lerp write into a buffer, with no table per tick", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local name = spiral(NS)
    local into, other = A.Rest(), A.Rest()
    A.Pose(name, 0.5, 8, into)
    A.Pose(name, 0.1, 8, other)
    assertEqual(A.Pose(name, 0.2, 8, into), into)
    local places = into.places[3]
    collectgarbage("stop")
    local before = collectgarbage("count")
    for i = 1, 1000 do
        A.Pose(name, (i % 10) / 10, 8, into)
        A.Pose("rotateScale", (i % 10) / 10, 8, other)
        A.Lerp(into, other, 0.5, into)
        A.Pose(name, 0.5, 8, into)
    end
    local grown = collectgarbage("count") - before
    collectgarbage("restart")
    assertEqual(into.places[3], places, "the same place table")
    assertTrue(grown < 1, "kilobytes grown: " .. grown)
end)

test("anim pose: a buffer left by a per-place style answers no places for a whole-dial one", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local into = A.Pose(spiral(NS), 0.5, 8)
    assertTrue(into.places ~= nil)
    A.Pose("fade", 0.5, 8, into)
    assertNil(into.places)
    assertEqual(into.hub, 1)
end)

test("anim pose: A.Lerp walks every key and every place, a missing side at rest", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local name = spiral(NS)
    local a, b = A.Pose(name, 0, 2), A.Rest()
    b.rot, b.dy, b.flash, b.scaleX = 2, 1, 1, 0.5
    local m = A.Lerp(a, b, 0.5)
    near(m.rot, 1)
    near(m.dy, 0.5)
    near(m.flash, 0.5)
    near(m.scaleX, 0.75)
    near(m.places[2].radius, 0.5, "toward its rest")
    near(m.places[2].angle, -1.2)
    assertEqual(m.count, 2)
    assertNil(A.Lerp(A.Rest(), A.Rest(), 0.5).places)
end)

test("anim pose: A.Unease undoes A.Ease in e, and a knot is found each way", function()
    local A = T.enableAddon().Anim
    for _, f in ipairs({ 0, 0.2, 0.5, 1 }) do
        near(A.Unease("open", A.Ease("open", f)), f, "open")
        near(A.Unease("close", 1 - A.Ease("close", f)), f, "close")
    end
    local knots = { 0.25, 0.5 }
    assertEqual(A.NextKnot(knots, 0, "open"), 0.25)
    assertEqual(A.NextKnot(knots, 0.25, "open"), 0.5)
    assertEqual(A.NextKnot(knots, 0.5, "open"), 1)
    assertEqual(A.NextKnot(knots, 1, "close"), 0.5)
    assertEqual(A.NextKnot(knots, 0.25, "close"), 0)
end)

test("anim pose: a track plays a style's curve on the same e as the mockup, up an open and down a close", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local t = track(NS, { open = { style = "rotateScale", duration = 1 }, close = { style = "rotateScale", duration = 1 } })
    A.Open(t)
    A.Step(t, 0.5)
    near(t.pose.scale, A.Pose("rotateScale", 0.75, 1).scale, "1 - (1 - f)^2")
    A.Step(t, 1)
    A.Close(t)
    near(t.pose.scale, 1, "a close starts whole")
    A.Step(t, 0.5)
    near(t.pose.scale, A.Pose("rotateScale", 0.75, 1).scale, "1 - f^2")
    A.Snap(t)
end)

test("anim pose: a reversal between two styles starts from the pose, every place of it, and lands on the new one", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local name = spiral(NS)
    local t = track(NS, { open = { style = name, duration = 1 }, close = { style = "rotateScale", duration = 1 } })
    NS.AnimGhost.New = function() return { size = 8 } end
    A.Open(t)
    A.Step(t, 0.3)
    local angle, radius = t.pose.places[4].angle, t.pose.places[4].radius
    local e = t.e
    assertTrue(A.Close(t))
    near(t.pose.places[4].angle, angle, "no jump")
    near(t.pose.places[4].radius, radius)
    near(t.duration, e, "the way back's share")
    A.Step(t, t.duration * 0.5)
    assertTrue(math.abs(t.pose.places[4].angle) < math.abs(angle), "easing out of it")
    assertTrue(t.pose.rot < 0, "and into the new style")
    A.Step(t, 1)
    assertNil(t.phase)
    A.STYLES[name] = nil
end)

test("anim pose: a reversal's time is the e left to travel, floored", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    local cfg = { style = "scaleInFade", duration = 1 }
    local t = track(NS, { open = cfg, close = cfg })
    A.Open(t)
    A.Close(t)
    near(t.duration, A.REVERSE_FLOOR, "barely open")
    A.Snap(t)
end)

test("anim pose: knots break a fresh curve into linear legs, each from its own pose, and turn once", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    A.STYLES.testKnots = { knots = { 0.5 }, g = function(e, p) p.alpha, p.scaleX = e, 0.5 + 0.5 * e end }
    local cfg = { style = "testKnots", duration = 1 }
    local t = track(NS, { open = cfg, close = cfg })
    local legs = {}
    NS.AnimGhost.ScaleText = function(_, from, to, duration, phase)
        legs[#legs + 1] = { from.scaleX, to.scaleX, duration, phase }
    end
    A.Open(t)
    assertEqual(#legs, 1)
    near(legs[1][1], 0.5)
    near(legs[1][2], 0.75, "to the knot")
    near(legs[1][3], A.Unease("open", 0.5), "over its share of the time")
    assertEqual(legs[1][4], "linear")
    A.Step(t, 0.1)
    assertEqual(#legs, 1, "not yet")
    A.Step(t, 0.3)
    assertEqual(#legs, 2, "past the knot")
    near(legs[2][2], 1)
    A.Step(t, 0.1)
    assertEqual(#legs, 2, "once")
    A.Snap(t)
    A.Close(t)
    assertEqual(#legs, 3)
    near(legs[3][1], 1)
    near(legs[3][2], 0.75, "down to the knot")
    A.Snap(t)
    A.STYLES.testKnots = nil
end)

test("anim pose: a reversal is one plain leg, whatever the knots", function()
    local NS = T.enableAddon()
    local A = NS.Anim
    A.STYLES.testKnots = { knots = { 0.5 }, g = function(e, p) p.alpha = e end }
    local cfg = { style = "testKnots", duration = 1 }
    local t = track(NS, { open = cfg, close = cfg })
    A.Open(t)
    local phase
    NS.AnimGhost.ScaleText = function(_, _, _, _, leg) phase = leg end
    A.Close(t)
    assertEqual(phase, "close")
    assertNil(t.legEnd)
    A.Snap(t)
    A.STYLES.testKnots = nil
end)

test("anim pose: Rotate and scale is offered for both phases, knobs included", function()
    local NS = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("dial.anim.openStyle", "rotateScale", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.anim.closeStyle", "rotateScale", "d2"))
    for _, r in ipairs(NS.addon.Settings.Schema) do
        if r.path == "dial.anim.closeDuration" then
            local shown = false
            for _, v in ipairs(r.shownWhen.equals) do shown = shown or v == "rotateScale" end
            assertTrue(shown, "its Duration shows")
        end
    end
end)
