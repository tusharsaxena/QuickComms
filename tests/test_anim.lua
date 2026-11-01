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

test("anim: a new dial carries the shipped defaults, on for everyone, and a pad has no animation", function()
    local NS = T.enableAddon()
    local pad, dial = NS.db.profile.pads.p1, NS.db.profile.dials.d2
    assertEqual(dial.anim.openStyle, "scaleFade")
    assertEqual(dial.anim.closeStyle, "scaleFade")
    assertEqual(dial.anim.openDuration, 0.15)
    assertEqual(dial.anim.closeDuration, 0.1)
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
    assertEqual(p.dials.d.anim.closeStyle, "scaleFade", "a missing key is filled")
    assertEqual(p.dials.c.anim.openStyle, "scaleFade", "a damaged table is replaced")
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
    assertEqual(db.profile.dials.d2.anim.closeStyle, "scaleFade")
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
    assertEqual(db.global.schemaVersion, 14)
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
    assertEqual(a.openStyle, "scaleFade", "the open is untouched")
    assertTrue(Set("dial.anim.openStyle", "fan", "d2"))
    assertEqual(a.closeStyle, "none", "the close is untouched")
end)

test("anim: a style or duration out of range is refused or clamped", function()
    local NS = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    for _, gone in ipairs({ "pop", "slide", "fadeScale" }) do
        assertFalse(Set("dial.anim.openStyle", gone, "d2"), gone .. " was a pad's")
    end
    assertTrue(Set("dial.anim.openDuration", 9, "d2"))
    assertEqual(NS.db.profile.dials.d2.anim.openDuration, 2)
end)

test("anim: the hidden poses match the owner's rulings", function()
    local A = T.enableAddon().Anim
    assertNil(A.Hidden("none"))
    assertEqual(A.Hidden("scaleFade").scale, 0.8, "about 80%")
    assertEqual(A.Hidden("fan").fan, 0)
    assertEqual(A.Hidden("fade").scale, 1)
    for _, gone in ipairs({ "pop", "slide", "fadeScale" }) do assertNil(A.Hidden(gone), gone) end
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
    assertTrue(t.pose.scale > 0.8 and t.pose.scale < 1)
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

-- ── the rest of the sweep (#13) ──────────────────────────────────────────────────────────────────

test("anim: a missing key reads its own phase's default", function()
    local A = T.enableAddon().Anim
    local defaults = { openDuration = 0.15, closeDuration = 0.1, openStyle = "fade", closeStyle = "fan" }
    local cfg = A.Config({}, defaults, "close")
    assertEqual(cfg.duration, 0.1)
    assertEqual(cfg.style, "fan")
    assertEqual(A.Config({ openStyle = "none" }, defaults, "open").style, "none")
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
    assertEqual(p.dials.good.anim.openStyle, "scaleFade")
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
    assertEqual(db.sv.profiles.other.dials.x.anim.openStyle, "scaleFade")
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
    assertNil(row("dial.anim.closeDirection"), "a dial has no Slide")
    for _, key in ipairs({ "openStyle", "openDuration", "openDirection", "closeStyle", "closeDuration", "closeDirection" }) do
        assertNil(row("pad.anim." .. key), "no pad row: " .. key)
    end
    local values = {}
    for _, c in ipairs(row("dial.anim.openStyle").values) do
        values[#values + 1] = c.value
        if c.value == "scaleFade" then assertEqual(c.text, NS.L["Scale and fade"]) end
    end
    assertEqual(table.concat(values, ","), "none,fade,scaleFade,fan")
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
