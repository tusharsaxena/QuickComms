-- tests/test_anim_styles.lua — every dial animation style (#13, the owner's rulings of 2026-11-01), each
-- taken the same way: the mockup's motion, then the real dial through an open, a close, a reversal, a
-- send, combat and the stand-down, with nothing left on the ghost for the next style to inherit.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local live, planOf, combat = D.live, D.planOf, D.combat

local function near(a, b, what)
    assertTrue(math.abs(a - b) < 1e-5, (what or "near") .. ": " .. tostring(a) .. " vs " .. tostring(b))
end

-- The shipped list, in the dropdown's order.
local STYLES = { "fade", "fan", "scale", "scaleAndFade", "rotateScale",
    "spiralOut", "spiralIn", "orbit", "burst", "stagger", "pop", "slide", "drop", "squash", "flip", "shatter",
    "flash" }

-- The approved mockup's own numbers, computed from its `S` at two values of `e`, with its pixel `dy` in
-- dial radii and turned up-positive. Places 1, 4 and 8 of a ring of 8.
local MOCK = {
    { style = "scale", e = 0.25, alpha = 1, scale = 0.4375 },
    { style = "scale", e = 0.6, alpha = 1, scale = 0.7 },
    { style = "rotateScale", e = 0.25, alpha = 0.625, scale = 0.5875, rot = -1.575 },
    { style = "rotateScale", e = 0.6, alpha = 1, scale = 0.78, rot = -0.84 },
    { style = "spiralOut", e = 0.25, places = { [1] = { alpha = 0.4, radius = 1.825, angle = 1.35 }, [4] = { alpha = 0.4, radius = 1.825, angle = 1.35 }, [8] = { alpha = 0.4, radius = 1.825, angle = 1.35 } } },
    { style = "spiralOut", e = 0.6, places = { [1] = { alpha = 0.96, radius = 1.44, angle = 0.72 }, [4] = { alpha = 0.96, radius = 1.44, angle = 0.72 }, [8] = { alpha = 0.96, radius = 1.44, angle = 0.72 } } },
    { style = "spiralIn", e = 0.25, places = { [1] = { alpha = 0.625, radius = 0.25, angle = -1.8 }, [4] = { alpha = 0.625, radius = 0.25, angle = -1.8 }, [8] = { alpha = 0.625, radius = 0.25, angle = -1.8 } } },
    { style = "spiralIn", e = 0.6, places = { [1] = { alpha = 1, radius = 0.6, angle = -0.96 }, [4] = { alpha = 1, radius = 0.6, angle = -0.96 }, [8] = { alpha = 1, radius = 0.6, angle = -0.96 } } },
    { style = "orbit", e = 0.25, places = { [1] = { alpha = 0.75, angle = 0 }, [4] = { alpha = 0.75, angle = -1.767146 }, [8] = { alpha = 0.75, angle = -4.12334 } } },
    { style = "orbit", e = 0.6, places = { [1] = { alpha = 1, angle = 0 }, [4] = { alpha = 1, angle = -0.942478 }, [8] = { alpha = 1, angle = -2.199115 } } },
    { style = "burst", e = 0.25, places = { [1] = { alpha = 0.75, radius = 0.845313 }, [4] = { alpha = 0.75, radius = 0.845313 }, [8] = { alpha = 0.75, radius = 0.845313 } } },
    { style = "burst", e = 0.6, places = { [1] = { alpha = 1, radius = 1.1184 }, [4] = { alpha = 1, radius = 1.1184 }, [8] = { alpha = 1, radius = 1.1184 } } },
    { style = "stagger", e = 0.25, places = { [1] = { alpha = 1, scale = 1.07687 }, [4] = { alpha = 0.4875, scale = 0.629131 }, [8] = { alpha = 0, scale = 0 } } },
    { style = "stagger", e = 0.6, places = { [1] = { alpha = 1, scale = 1 }, [4] = { alpha = 1, scale = 1.070376 }, [8] = { alpha = 1, scale = 1.063804 } } },
    { style = "pop", e = 0.25, alpha = 0.75, scale = 0.953594 },
    { style = "pop", e = 0.6, alpha = 1, scale = 1.03552 },
    { style = "slide", e = 0.25, alpha = 0.25, dy = -0.318182 },
    { style = "slide", e = 0.6, alpha = 0.6, dy = -0.169697 },
    { style = "drop", e = 0.25, alpha = 1, dy = 0.479403 },
    { style = "drop", e = 0.6, alpha = 1, dy = 0.206818 },
    { style = "squash", e = 0.25, alpha = 1, scaleX = 0.55, scaleY = 0.015 },
    { style = "squash", e = 0.6, alpha = 1, scaleX = 1, scaleY = 0.12 },
    { style = "flip", e = 0.25, alpha = 1, scaleX = 0.382683 },
    { style = "flip", e = 0.6, alpha = 1, scaleX = 0.809017 },
    { style = "shatter", e = 0.25, places = { [1] = { alpha = 0.35, radius = 1.6075, angle = 0.645, spin = -0.57 }, [4] = { alpha = 0.35, radius = 2.0725, angle = 0.24, spin = 1.29 }, [8] = { alpha = 0.35, radius = 2.005, angle = -0.57, spin = 1.02 } } },
    { style = "shatter", e = 0.6, places = { [1] = { alpha = 0.84, radius = 1.324, angle = 0.344, spin = -0.304 }, [4] = { alpha = 0.84, radius = 1.572, angle = 0.128, spin = 0.688 }, [8] = { alpha = 0.84, radius = 1.536, angle = -0.304, spin = 0.544 } } },
    { style = "flash", e = 0.25, alpha = 0.5, scale = 0.94, flash = 0.565685 },
    { style = "flash", e = 0.6, alpha = 1, scale = 0.968, flash = 0.760845 },
}

local function row(NS, path)
    for _, r in ipairs(NS.addon.Settings.Schema) do
        if r.path == path then return r end
    end
end

local function matches(got, want, what)
    for k, v in pairs(want) do
        if type(v) == "number" and k ~= "e" then near(got[k], v, what .. " " .. k) end
    end
end

test("anim style: the dropdown offers None and every style, the same list for the open and the close", function()
    local NS = T.enableAddon()
    for _, key in ipairs({ "open", "close" }) do
        local values = {}
        for _, c in ipairs(row(NS, "dial.anim." .. key .. "Style").values) do
            values[#values + 1] = c.value
            assertTrue(type(c.text) == "string" and c.text ~= "" and c.text ~= c.value, c.value .. " has a label")
        end
        assertEqual(table.concat(values, ","), "none," .. table.concat(STYLES, ","))
    end
    for _, style in ipairs(STYLES) do assertTrue(NS.Anim.STYLES[style] ~= nil, style) end
end)

test("anim style: the labels are the owner's", function()
    local NS = T.enableAddon()
    local text = {}
    for _, c in ipairs(row(NS, "dial.anim.openStyle").values) do text[c.value] = c.text end
    local want = { scale = "Scale", scaleAndFade = "Scale and fade",
        rotateScale = "Rotate and scale", spiralOut = "Inward spiral",
        spiralIn = "Outward spiral", orbit = "Orbit", burst = "Burst", stagger = "Stagger pop", pop = "Pop",
        slide = "Slide", drop = "Drop", squash = "Squash", flip = "Flip", shatter = "Shatter", flash = "Flash" }
    for value, label in pairs(want) do assertEqual(text[value], label) end
end)

test("anim style: every moving style's Duration shows, on both phases, and None hides it", function()
    local NS = T.enableAddon()
    for _, key in ipairs({ "open", "close" }) do
        local listed = {}
        for _, v in ipairs(row(NS, "dial.anim." .. key .. "Duration").shownWhen.equals) do listed[v] = true end
        for _, style in ipairs(STYLES) do assertTrue(listed[style], style) end
        assertNil(listed.none)
    end
end)

test("anim style: the defaults are the owner's, on a slider still 0.1 to 2 in 0.1 steps", function()
    local NS = T.enableAddon()
    local a = NS.db.profile.dials.d2.anim
    assertEqual(a.openStyle, "rotateScale")
    assertEqual(a.closeStyle, "rotateScale")
    assertEqual(a.openDuration, 0.2)
    assertEqual(a.closeDuration, 0.2)
    assertEqual(a.openDirection, "up", "a Slide rises into place")
    assertEqual(a.closeDirection, "down", "and drops away, as the mockup")
    for _, key in ipairs({ "open", "close" }) do
        local r = row(NS, "dial.anim." .. key .. "Duration")
        assertEqual(r.min, 0.1)
        assertEqual(r.max, 2)
        assertEqual(r.step, 0.1)
    end
end)

test("anim style: every value of the mockup's motion, up to the extras", function()
    local A = T.enableAddon().Anim
    for _, want in ipairs(MOCK) do
        local what = want.style .. " at " .. want.e
        local p = A.Pose(want.style, want.e, 8)
        matches(p, want, what)
        for i, place in pairs(want.places or {}) do matches(p.places[i], place, what .. " place " .. i) end
    end
end)

test("anim style: Scale and fade is the Scale pose with a full-length fade", function()
    local A = T.enableAddon().Anim
    for _, pair in ipairs({ { "scale", "scaleAndFade" } }) do
        for _, e in ipairs({ 0, 0.1, 0.5, 0.9, 1 }) do
            local plain, faded = A.Pose(pair[1], e, 8), A.Pose(pair[2], e, 8)
            near(faded.scale, plain.scale, pair[2] .. " scale")
            near(faded.alpha, e, pair[2] .. " fades the whole way")
        end
    end
end)

test("anim style: Shatter wraps its seeds on a ring wider than the mockup's eight", function()
    local A = T.enableAddon().Anim
    local p = A.Pose("shatter", 0.5, 12)
    near(p.places[10].radius, p.places[2].radius)
    near(p.places[10].angle, p.places[2].angle)
    near(p.places[10].spin, p.places[2].spin)
end)

test("anim style: an overshoot's text overshoots: Pop and Stagger pop declare their knots", function()
    local NS, _ = T.enableAddon()
    local A = NS.Anim
    for _, name in ipairs({ "pop", "stagger", "squash", "flip" }) do
        assertTrue(A.STYLES[name].knots ~= nil, name)
        local last = 0
        for _, k in ipairs(A.STYLES[name].knots) do
            assertTrue(k > last and k < 1, name .. " rises inside 0 to 1")
            last = k
        end
    end
    local peak = 0
    for _, k in ipairs(A.STYLES.pop.knots) do peak = math.max(peak, A.Pose("pop", k, 8).scale) end
    near(peak, 0.7 + 0.3 * A.Back(1 - 3.8 / 8.7), "a knot at its peak")
    assertTrue(peak > 1)
    peak = 0
    for _, k in ipairs(A.STYLES.stagger.knots) do peak = math.max(peak, A.Pose("stagger", k, 8).places[1].scale) end
    assertTrue(peak > 1, "a leg's end stands past whole")
end)

-- ── Slide's Direction ───────────────────────────────────────────────────────────────────────────

test("anim style: Slide's Direction reads as motion: Up rises into place and leaves upward", function()
    local A = T.enableAddon().Anim
    local reach = 70 / 165
    local function at(phase, direction)
        local cfg = A.Config({ [phase .. "Direction"] = direction }, {}, phase)
        return A.Pose("slide", 0, 8, nil, cfg)
    end
    near(at("open", "up").dy, -reach, "starts below")
    near(at("close", "up").dy, reach, "ends above")
    near(at("open", "down").dy, reach)
    near(at("close", "down").dy, -reach)
    near(at("open", "left").dx, reach, "starts on the right")
    near(at("close", "left").dx, -reach)
    near(at("open", "right").dx, -reach)
    near(at("close", "right").dx, reach)
    near(at("open", "up").dx, 0)
    near(at("open", "left").dy, 0)
end)

test("anim style: a Slide with no direction, or a damaged one, rises as the mockup does", function()
    local A = T.enableAddon().Anim
    near(A.Hidden("slide", 8).dy, -70 / 165)
    near(A.Pose("slide", 0, 8, nil, { direction = "sideways", phase = "open" }).dy, -70 / 165)
end)

test("anim style: Direction is a row per phase, shown only on Slide, each writing its own key", function()
    local NS = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    for _, key in ipairs({ "open", "close" }) do
        local r = row(NS, "dial.anim." .. key .. "Direction")
        assertEqual(r.group, NS.L["Animation"])
        assertEqual(r.subgroup, NS.L[key == "open" and "Open" or "Close"])
        assertEqual(r.label, NS.L["Direction"])
        assertEqual(r.shownWhen.path, "dial.anim." .. key .. "Style", "its own style")
        assertEqual(#r.shownWhen.equals, 1)
        assertEqual(r.shownWhen.equals[1], "slide")
        local values = {}
        for _, c in ipairs(r.values) do values[#values + 1] = c.value end
        assertEqual(table.concat(values, ","), "up,down,left,right")
        assertTrue(type(r.desc) == "string" and r.desc ~= "", "it has a tooltip")
    end
    local a = NS.db.profile.dials.d2.anim
    assertTrue(Set("dial.anim.openDirection", "left", "d2"))
    assertEqual(a.openDirection, "left")
    assertEqual(a.closeDirection, "down", "the close is untouched")
    assertFalse(Set("dial.anim.closeDirection", "sideways", "d2"))
end)

-- ── the migration ───────────────────────────────────────────────────────────────────────────────

test("anim style: step 15 moves a phase only as a pair, its style and duration both on the old default", function()
    local NS = T.enableAddon()
    local p = { dials = { old = { anim = { openStyle = "scaleFade", closeStyle = "scaleFade",
        openDuration = 0.15, closeDuration = 0.1 } },
        mixed = { anim = { openStyle = "fan", closeStyle = "scaleFade", openDuration = 0.7, closeDuration = 0.1 } },
        off = { anim = { openStyle = "none", closeStyle = "none", openDuration = 2, closeDuration = 0.2 } },
        lone = { anim = { openStyle = "scaleFade", closeStyle = "fan", openDuration = 0.5, closeDuration = 0.1 } },
        loneToo = { anim = { openStyle = "fade", closeStyle = "scaleFade", openDuration = 0.15, closeDuration = 0.4 } },
        bad = 3, damaged = { anim = 3 }, empty = {} }, pads = { p = { name = "Kept" } } }
    -- red under: no step, so a profile from this branch keeps the old default forever
    NS.Library.MigrateAnimDefaults(p)
    local old, mixed, off = p.dials.old.anim, p.dials.mixed.anim, p.dials.off.anim
    assertEqual(old.openStyle, "rotateScale")
    assertEqual(old.closeStyle, "rotateScale")
    assertEqual(old.openDuration, 0.2)
    assertEqual(old.closeDuration, 0.2)
    assertEqual(mixed.openStyle, "fan", "a pick stays")
    assertEqual(mixed.closeStyle, "rotateScale")
    assertEqual(mixed.openDuration, 0.7, "a pick stays")
    assertEqual(mixed.closeDuration, 0.2)
    assertEqual(off.openStyle, "none")
    assertEqual(off.closeStyle, "none")
    assertEqual(off.openDuration, 2)
    assertEqual(off.closeDuration, 0.2)
    -- red under: key by key, a lone match is taken for the default and the pick beside it says otherwise
    local lone, loneToo = p.dials.lone.anim, p.dials.loneToo.anim
    assertEqual(lone.openStyle, "scaleFade", "0.5 shows Scale and fade was chosen")
    assertEqual(lone.openDuration, 0.5)
    assertEqual(lone.closeStyle, "fan")
    assertEqual(lone.closeDuration, 0.1, "Fan shows 0.1 was chosen")
    assertEqual(loneToo.openStyle, "fade")
    assertEqual(loneToo.openDuration, 0.15)
    assertEqual(loneToo.closeStyle, "scaleFade")
    assertEqual(loneToo.closeDuration, 0.4)
    assertEqual(p.dials.bad, 3)
    assertEqual(p.dials.damaged.anim, 3, "a damaged value is left as it was found")
    assertNil(p.dials.empty.anim)
    assertNil(p.pads.p.anim)
    NS.Library.MigrateAnimDefaults(p)
    assertEqual(old.openStyle, "rotateScale", "idempotent")
    assertEqual(old.closeDuration, 0.2)
    assertEqual(mixed.openDuration, 0.7)
    NS.Library.MigrateAnimDefaults(3)
    NS.Library.MigrateAnimDefaults({ dials = 3 })
end)

test("anim style: step 16 moves the spiral pair to the new default, and every other Scale and fade to Scale in and fade", function()
    local NS = T.enableAddon()
    local p = { dials = { spirals = { anim = { openStyle = "spiralIn", closeStyle = "spiralOut",
        openDuration = 0.5, closeDuration = 0.3, openDirection = "left", closeDirection = "right" } },
        retired = { anim = { openStyle = "scaleFade", closeStyle = "scaleFade", openDuration = 0.15, closeDuration = 2 } },
        noDuration = { anim = { openStyle = "scaleFade" } },
        lone = { anim = { openStyle = "spiralIn", closeStyle = "spiralOut", openDuration = 0.7, closeDuration = 0.1 } },
        half = { anim = { openStyle = "spiralIn", closeStyle = "fan", openDuration = 0.5, closeDuration = 0.3 } },
        crossed = { anim = { openStyle = "spiralOut", closeStyle = "spiralIn", openDuration = 0.5, closeDuration = 0.3 } },
        off = { anim = { openStyle = "none", closeStyle = "scaleInFade", openDuration = 0.5, closeDuration = 0.3 } },
        bad = 3, damaged = { anim = 3 }, empty = {} }, pads = { p = { name = "Kept" } } }
    -- red under: no step, so a stored Scale and fade names a style that no longer exists
    NS.Library.MigrateRotateDefaults(p)
    local d = p.dials
    assertEqual(d.spirals.anim.openStyle, "rotateScale")
    assertEqual(d.spirals.anim.closeStyle, "rotateScale")
    assertEqual(d.spirals.anim.openDuration, 0.2)
    assertEqual(d.spirals.anim.closeDuration, 0.2)
    assertEqual(d.spirals.anim.openDirection, "left", "a direction is the player's")
    assertEqual(d.spirals.anim.closeDirection, "right")
    assertEqual(d.retired.anim.openStyle, "scaleInFade", "even on the older default's duration")
    assertEqual(d.retired.anim.openDuration, 0.15, "its duration is kept")
    assertEqual(d.retired.anim.closeStyle, "scaleInFade")
    assertEqual(d.retired.anim.closeDuration, 2)
    assertEqual(d.noDuration.anim.openStyle, "scaleInFade")
    assertNil(d.noDuration.anim.openDuration)
    -- red under: a style matched alone, or the duration not read, takes a pick for the default
    assertEqual(d.lone.anim.openStyle, "spiralIn", "0.7 shows the spiral was chosen")
    assertEqual(d.lone.anim.openDuration, 0.7)
    assertEqual(d.lone.anim.closeStyle, "spiralOut")
    assertEqual(d.lone.anim.closeDuration, 0.1)
    assertEqual(d.half.anim.openStyle, "rotateScale", "each phase is read on its own")
    assertEqual(d.half.anim.closeStyle, "fan")
    assertEqual(d.half.anim.closeDuration, 0.3)
    assertEqual(d.crossed.anim.openStyle, "spiralOut", "never a default of the other phase")
    assertEqual(d.crossed.anim.closeStyle, "spiralIn")
    assertEqual(d.crossed.anim.openDuration, 0.5)
    assertEqual(d.off.anim.openStyle, "none")
    assertEqual(d.off.anim.closeStyle, "scaleInFade")
    assertEqual(d.off.anim.closeDuration, 0.3)
    assertEqual(d.bad, 3)
    assertEqual(d.damaged.anim, 3, "a damaged value is left as it was found")
    assertNil(d.empty.anim)
    assertNil(p.pads.p.anim)
    NS.Library.MigrateRotateDefaults(p)
    assertEqual(d.spirals.anim.openDuration, 0.2, "idempotent")
    assertEqual(d.retired.anim.openDuration, 0.15)
    assertEqual(d.lone.anim.openStyle, "spiralIn")
    NS.Library.MigrateRotateDefaults(3)
    NS.Library.MigrateRotateDefaults({ dials = 3 })
end)

test("anim style: 15 then 16 lands a pre-15 profile on the new defaults, with nothing naming a retired style", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    local a = db.profile.dials.d2.anim
    a.openStyle, a.closeStyle, a.openDuration, a.closeDuration = "scaleFade", "scaleFade", 0.15, 0.7
    db.global.schemaVersion = 14
    NS.addon:RunMigrations()
    assertEqual(a.openStyle, "rotateScale", "step 15's pair lands on today's default")
    assertEqual(a.openDuration, 0.2)
    assertEqual(a.closeStyle, "scaleAndFade", "a pick step 15 left, through steps 16 and 17")
    assertEqual(a.closeDuration, 0.7)
end)

test("anim style: the runner moves every stored profile once, and the stamp holds a later pick", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    local a = db.profile.dials.d2.anim
    a.openStyle, a.closeStyle, a.openDuration, a.closeDuration = "scaleFade", "scaleFade", 0.15, 0.1
    db.sv.profiles.other = { dials = { x = { anim = { openStyle = "scaleFade", openDuration = 0.15, closeStyle = "fan" } } } }
    db.global.schemaVersion = 14
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, 18)
    assertEqual(NS.SCHEMA_VERSION, 18)
    assertEqual(a.openStyle, "rotateScale")
    assertEqual(a.closeDuration, 0.2)
    assertEqual(db.sv.profiles.other.dials.x.anim.openStyle, "rotateScale", "not only the active profile")
    assertEqual(db.sv.profiles.other.dials.x.anim.closeStyle, "fan")
    a.openStyle, a.openDuration, a.closeStyle, a.closeDuration = "spiralIn", 0.5, "spiralOut", 0.3
    NS.addon:RunMigrations()
    assertEqual(a.openStyle, "spiralIn", "picked since: the step ran once")
    assertEqual(a.openDuration, 0.5)
    assertEqual(a.closeStyle, "spiralOut")
    assertEqual(a.closeDuration, 0.3)
end)

test("anim style: Prepare fills a stored dial's Direction, so a settings read never finds it missing", function()
    local NS = T.enableAddon()
    local a = NS.db.profile.dials.d2.anim
    a.openDirection, a.closeDirection = nil, nil
    NS.Library.Prepare()
    local Get = NS.SchemaRuntime.Get
    assertEqual(Get("dial.anim.openDirection", "d2"), "up")
    assertEqual(Get("dial.anim.closeDirection", "d2"), "down")
end)

test("anim style: a profile from before step 12 lands on the new defaults, not the old", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    db.profile.dials.d2.anim = nil
    db.global.schemaVersion = 11
    NS.addon:RunMigrations()
    assertEqual(db.profile.dials.d2.anim.openStyle, "rotateScale")
    assertEqual(db.profile.dials.d2.anim.closeDuration, 0.2)
    assertEqual(db.profile.dials.d2.anim.closeDirection, "down")
end)

-- ── each style on the real dial ─────────────────────────────────────────────────────────────────

local function dial(NS, open, close, duration)
    local a = NS.db.profile.dials.d2.anim
    a.openStyle, a.closeStyle = open, close or open
    a.openDuration, a.closeDuration = duration or 0.5, duration or 0.5
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    return NS.Dial.Instance("d2")
end

local function land(NS, inst)
    for _ = 1, 40 do
        if not inst.track.phase then return end
        NS.Anim.Step(inst.track, 0.1)
    end
end

local function assertLanded(NS, inst, what)
    assertNil(inst.track.phase, what)
    assertFalse(NS.Anim.Running(), what)
    assertFalse(inst.track.ghost.stage:IsShown(), what)
    assertFalse(inst.track.ghost.text:IsShown(), what)
    assertEqual(inst.header:GetAlpha(), 1, what)
end

-- The ghost's state, for a comparison across a reversal.
local KEYS = { "alpha", "scale", "scaleX", "scaleY", "rot", "dx", "dy", "fan", "hub", "flash" }
local PLACE_KEYS = { "alpha", "radius", "angle", "scale", "spin" }

local function copyPose(pose)
    local out = { places = {} }
    for _, k in ipairs(KEYS) do out[k] = pose[k] end
    for i = 1, pose.count or 0 do
        out.places[i] = {}
        for _, k in ipairs(PLACE_KEYS) do out.places[i][k] = pose.places[i][k] end
    end
    return out
end

local function samePose(pose, kept, what)
    for _, k in ipairs(KEYS) do near(pose[k], kept[k], what .. " " .. k) end
    for i, place in ipairs(kept.places) do
        for _, k in ipairs(PLACE_KEYS) do near(pose.places[i][k], place[k], what .. " place " .. k) end
    end
end

for _, style in ipairs(STYLES) do
    test("anim style " .. style .. ": rests whole at 1 and shows nothing at 0", function()
        local A = T.enableAddon().Anim
        local rest, restPlace = A.Rest(), A.RestPlace()
        local whole = A.Pose(style, 1, 8)
        for k, v in pairs(rest) do near(whole[k], v, k) end
        for i = 1, whole.count or 0 do
            for k, v in pairs(restPlace) do near(whole.places[i][k], v, "place " .. k) end
        end
        local hidden = A.Hidden(style, 8)
        near(hidden.alpha * hidden.hub * hidden.fan, 0, "what has no place")
        for i = 1, 8 do
            local placeAlpha = hidden.places and hidden.places[i].alpha or 1
            near(hidden.alpha * placeAlpha * A.FanAlpha(hidden.fan, (i - 1) / 8), 0, "place " .. i)
        end
    end)

    test("anim style " .. style .. ": an open and a close each land with nothing stuck", function()
        local NS, m = live()
        local inst = dial(NS, style)
        m.__click(inst.header, "Toggle")
        assertTrue(NS.Dial.IsOpen("d2"), "the secure open did not wait")
        assertEqual(inst.track.phase, "open")
        assertEqual(inst.header:GetAlpha(), 0)
        NS.Anim.Step(inst.track, 0.2)
        assertEqual(inst.track.phase, "open", "still under way")
        land(NS, inst)
        assertLanded(NS, inst, "the open")
        m.__click(inst.header, "Toggle")
        assertFalse(NS.Dial.IsOpen("d2"), "the secure close did not wait")
        assertEqual(inst.track.phase, "close")
        NS.Anim.Step(inst.track, 0.2)
        land(NS, inst)
        assertLanded(NS, inst, "the close")
    end)

    test("anim style " .. style .. ": a reversal starts from the pose, both ways, and lands", function()
        local NS, m = live()
        local inst = dial(NS, style)
        m.__click(inst.header, "Toggle")
        NS.Anim.Step(inst.track, 0.1)
        local kept = copyPose(inst.track.pose)
        m.__click(inst.header, "Toggle")
        assertEqual(inst.track.phase, "close")
        samePose(inst.track.pose, kept, "open to close")
        NS.Anim.Step(inst.track, 0.05)
        kept = copyPose(inst.track.pose)
        m.__click(inst.header, "Toggle")
        assertEqual(inst.track.phase, "open")
        samePose(inst.track.pose, kept, "close to open")
        land(NS, inst)
        assertLanded(NS, inst, "the way back")
    end)

    test("anim style " .. style .. ": a send fires at once and its slice stays bright where it rests", function()
        local NS, m = live()
        local inst = dial(NS, style)
        m.__click(inst.header, "Toggle")
        land(NS, inst)
        m.__click(inst.header, "Toggle")
        NS.Anim.Snap(inst.track)
        m.__click(inst.header, "Toggle")
        local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[2]
        m.__click(w)
        assertEqual(#m.sentMacros, 1, "the send never waits")
        assertEqual(inst.track.emphasis, w.qcGhostGroup)
        NS.Anim.Step(inst.track, 0.02)
        local ghost, sent = inst.track.ghost, 0
        for i = 1, ghost.used do
            local sub = ghost.subs[i]
            if sub.qcGroup == w.qcGhostGroup then
                sent = sent + 1
                near(sub:GetAlpha(), 1, "bright")
                assertEqual(sub.qcTurned, 0, "where it rests")
                assertTrue(sub.qcScaled >= 1 / math.max(inst.track.pose.scale, 0.01) - 1e-6, "and whole")
            end
        end
        assertTrue(sent > 0)
        land(NS, inst)
        assertLanded(NS, inst, "the send's close")
    end)

    test("anim style " .. style .. ": combat is the same, with nothing refused, and a stand-down lands it", function()
        local NS, m = live()
        local inst = dial(NS, style)
        combat(m, true)
        local blocked = #m.blocked
        m.__click(inst.header, "Toggle")
        assertEqual(inst.track.phase, "open")
        NS.Anim.Step(inst.track, 0.1)
        m.__click(inst.header, "Toggle")
        assertEqual(inst.track.phase, "close")
        land(NS, inst)
        assertLanded(NS, inst, "in combat")
        assertEqual(#m.blocked, blocked)
        combat(m, false)
        m.__click(inst.header, "Toggle")
        NS.Anim.Step(inst.track, 0.1)
        NS.SchemaRuntime.Set("enabled", false)
        assertFalse(NS.Anim.Running())
        assertEqual(inst.header:GetAlpha(), 1, "no held alpha")
    end)

    test("anim style " .. style .. ": leaves nothing on the ghost for the next style, and never touches it", function()
        local NS, m = live()
        local inst = dial(NS, style, "fade")
        assertEqual(inst.track.spec.config("close").style, "fade", "the open's pick is the open's")
        m.__click(inst.header, "Toggle")
        NS.Anim.Step(inst.track, 0.1)
        m.__click(inst.header, "Toggle")
        land(NS, inst)
        inst = dial(NS, "fade", style)
        assertEqual(inst.track.spec.config("open").style, "fade", "the close's pick is the close's")
        m.__click(inst.header, "Toggle")
        local ghost = inst.track.ghost
        NS.Anim.Step(inst.track, 0.1)
        assertEqual(ghost.offX, 0)
        assertEqual(ghost.offY, 0)
        for i = 1, ghost.used do
            local sub = ghost.subs[i]
            assertEqual(sub.qcScaled, 1)
            assertEqual(sub.qcOffX, 0)
            assertEqual(sub.qcOffY, 0)
            assertEqual(sub.qcTurned, 0)
        end
        assertFalse(ghost.flashOn == true, "no glow left on")
        land(NS, inst)
        assertLanded(NS, inst, "the plain open after it")
    end)

    test("anim style " .. style .. ": text keeps the Vertex route, with no width", function()
        local NS, m = live()
        local inst = dial(NS, style)
        m.__click(inst.header, "Toggle")
        local ghost, seen = inst.track.ghost, 0
        for i = 1, ghost.textUsed do
            local sub = ghost.textSubs[i]
            for j = 1, sub.qcFontUsed do
                local fs = sub.qcFont[j]
                seen = seen + 1
                assertEqual(fs:GetParent(), sub, "under no stage: no pose scales a string")
                assertEqual(fs.__scaleMode, m.Enum.FontStringScaleAnimationMode.Vertex)
                assertNil(fs.__size, "a size is what truncated the title")
            end
        end
        assertTrue(seen > 0)
        land(NS, inst)
    end)
end

test("anim style: Flash blooms through the ring and goes out with the landing", function()
    local NS, m = live()
    local inst = dial(NS, "flash")
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 0.1)
    local ghost = inst.track.ghost
    assertTrue(ghost.flashOn, "the glow is up")
    assertTrue(ghost.flash:GetAlpha() > 0.3)
    land(NS, inst)
    assertLanded(NS, inst, "the flash")
end)

test("anim style: the shipped defaults open and close by Rotate and scale, on the dial", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.duration, 0.2)
    near(inst.track.pose.scale, 0.45, "from under half size")
    near(inst.track.pose.rot, -2.1, "turned")
    land(NS, inst)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.duration, 0.2)
    NS.Anim.Step(inst.track, 0.1)
    assertTrue(inst.track.pose.scale < 1, "shrinking")
    assertTrue(inst.track.pose.rot < 0, "turning away")
    land(NS, inst)
    assertLanded(NS, inst, "the defaults")
end)

test("anim style: a Slide's direction reaches the real track, phase by phase", function()
    local NS, m = live()
    local inst = dial(NS, "slide")
    local a = NS.db.profile.dials.d2.anim
    a.openDirection, a.closeDirection = "left", "up"
    m.__click(inst.header, "Toggle")
    near(inst.track.pose.dx, 70 / 165, "starts on the right")
    land(NS, inst)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 0.25)
    assertTrue(inst.track.pose.dy > 0, "leaves upward")
    near(inst.track.pose.dx, 0)
    land(NS, inst)
end)

test("anim style: step 17 merges the scales, keeps durations and everything else, and is idempotent", function()
    local NS = T.enableAddon()
    local p = { dials = {
        a = { anim = { openStyle = "scaleIn", closeStyle = "scaleOut", openDuration = 0.4, closeDuration = 0.6 } },
        b = { anim = { openStyle = "scaleInFade", closeStyle = "scaleOutFade", openDuration = 0.3, closeDuration = 0.1 } },
        c = { anim = { openStyle = "rotateScale", closeStyle = "none", openDuration = 0.2 } },
        bad = 3, damaged = { anim = 3 }, empty = {} }, pads = { p = { name = "Kept" } } }
    NS.Library.MigrateMergeScales(p)
    local d = p.dials
    assertEqual(d.a.anim.openStyle, "scale")
    assertEqual(d.a.anim.closeStyle, "scale")
    assertEqual(d.a.anim.openDuration, 0.4)
    assertEqual(d.a.anim.closeDuration, 0.6)
    assertEqual(d.b.anim.openStyle, "scaleAndFade")
    assertEqual(d.b.anim.closeStyle, "scaleAndFade")
    assertEqual(d.b.anim.closeDuration, 0.1)
    assertEqual(d.c.anim.openStyle, "rotateScale")
    assertEqual(d.c.anim.closeStyle, "none")
    assertEqual(d.bad, 3)
    assertEqual(d.damaged.anim, 3)
    assertNil(d.empty.anim)
    NS.Library.MigrateMergeScales(p)
    assertEqual(d.a.anim.openStyle, "scale", "idempotent")
    assertEqual(d.b.anim.closeStyle, "scaleAndFade")
    NS.Library.MigrateMergeScales(3)
    NS.Library.MigrateMergeScales({ dials = 3 })
end)
