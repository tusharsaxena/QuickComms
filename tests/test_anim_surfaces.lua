-- tests/test_anim_surfaces.lua — the open and close animations on the real dial and pad (#13): the
-- ghost's capture, which edges animate, the secure frames left alone, combat, the send, independence
-- of the four switches, and the stand-down.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local live, planOf, combat = D.live, D.planOf, D.combat

local function dial(NS, opts)
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, opts)))
    return NS.Dial.Instance("d2")
end

-- The default pad built and on screen, under its driver.
local function pad(NS)
    local snap = NS.Situation.Current()
    assertTrue(NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))))
    return NS.Pad.Instance("p1")
end

local function drive(NS, inst, expression)
    assertTrue(NS.SendEngine.SetVisibility(inst.root, expression))
end

test("anim dial: a key open plays over a live dial, and it lands with the real alpha back", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    assertTrue(NS.Dial.IsOpen("d2"), "the secure open did not wait")
    assertEqual(inst.track.phase, "open")
    assertEqual(inst.header:GetAlpha(), 0, "the ghost shows; the real dial waits under it")
    assertTrue(inst.track.ghost.stage:IsShown())
    NS.Anim.Step(inst.track, 1)
    assertNil(inst.track.phase)
    assertEqual(inst.header:GetAlpha(), 1)
    assertFalse(inst.track.ghost.stage:IsShown())
end)

test("anim dial: a close plays out after the header is already down", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    m.__click(inst.header, "Toggle")
    assertFalse(NS.Dial.IsOpen("d2"), "the secure close did not wait")
    assertEqual(inst.track.phase, "close")
    assertTrue(inst.track.ghost.stage:IsShown())
    NS.Anim.Step(inst.track, 1)
    assertFalse(inst.track.ghost.stage:IsShown())
    assertFalse(NS.Anim.Running())
end)

test("anim dial: the ghost mirrors the ring and takes the fills as places", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    local ghost = inst.track.ghost
    assertTrue(ghost.used > 1, "sub-frames were filled")
    assertEqual(ghost.size, inst.shownRing.qcSpec.size)
    local places = 0
    for i = 1, ghost.used do
        if ghost.subs[i].qcGroup then places = places + 1 end
    end
    assertTrue(places >= inst.shownRing.qcSpec.size, "every place is addressable")
    assertFalse(ghost.stage:IsMouseEnabled(), "the copy takes no click")
end)

test("anim dial: in combat it plays the same and nothing protected is touched", function()
    local NS, m = live()
    local inst = dial(NS)
    combat(m, true)
    local blocked = #m.blocked
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open")
    NS.Anim.Step(inst.track, 0.05)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "close", "a close mid-open")
    NS.Anim.Step(inst.track, 1)
    assertEqual(#m.blocked, blocked, "no protected call was refused")
    assertEqual(inst.header:GetAlpha(), 1)
end)

test("anim dial: a tap-and-release send fires at once, mid-open, and its slice is emphasized", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open")
    local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    m.__click(w)
    assertEqual(#m.sentMacros, 1, "the send never waits on the animation")
    assertFalse(NS.Dial.IsOpen("d2"))
    assertEqual(inst.track.phase, "close")
    assertEqual(inst.track.emphasis, w.qcGhostGroup)
    NS.Anim.Step(inst.track, 0.01)
    local ghost, swelled = inst.track.ghost, false
    for i = 1, ghost.used do
        if ghost.subs[i].qcGroup == w.qcGhostGroup and ghost.subs[i]:GetAlpha() > 0.9 then swelled = true end
    end
    assertTrue(swelled, "the chosen slice stays bright")
end)

test("anim dial: a cancel has no emphasis", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    m.__click(inst.header, "Close")
    assertEqual(inst.track.phase, "close")
    assertNil(inst.track.emphasis)
end)

test("anim dial: a page or ring change during an open snaps, with the real alpha back", function()
    local NS, m = live()
    local inst = dial(NS, { n = 8, slices = 4 })
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open")
    m.__click(inst.header, "Next")
    assertNil(inst.track.phase)
    assertEqual(inst.header:GetAlpha(), 1)
end)

test("anim dial: the way back from a hidden UIParent is no open", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    local ring = inst.shownRing
    inst.header:__fire("OnHide")
    assertNil(inst.track.phase, "its own flag is still on")
    inst.header:__fire("OnShow")
    ring:__fire("OnShow")
    assertNil(inst.track.phase, "Alt-Z coming back plays nothing")
    assertEqual(inst.header:GetAlpha(), 1)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "close", "a real close still plays")
    NS.Anim.Step(inst.track, 1)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open", "the flag was spent: so does the next real open")
end)

test("anim dial: a rebuild drops a held quiet show", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    inst.header:__fire("OnHide")
    assertTrue(NS.Dial.Release(1))
    inst = dial(NS)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open")
end)

test("anim dial: None on the open leaves the close, and None on the close leaves the open", function()
    local NS, m = live()
    local inst = dial(NS)
    local a = NS.db.profile.dials.d2.anim
    a.openStyle = "none"
    m.__click(inst.header, "Toggle")
    assertNil(inst.track.phase, "open off")
    assertEqual(inst.header:GetAlpha(), 1)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "close", "close on")
    NS.Anim.Step(inst.track, 1)
    a.openStyle, a.closeStyle = "scaleFade", "none"
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open", "open on")
    NS.Anim.Step(inst.track, 1)
    m.__click(inst.header, "Toggle")
    assertNil(inst.track.phase, "close off")
end)

test("anim dial: a rebuild closes silently, and a shut dial's rebuild plays nothing", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    dial(NS)
    assertFalse(NS.Dial.IsOpen("d2"))
    assertNil(inst.track.phase, "a rebuild is not the player closing the dial")
    assertFalse(NS.Anim.Running())
end)

test("anim dial: the preview dial animates its first open, not a rebuild's reopen", function()
    local NS = live()
    local plan = planOf(NS, { test = true })
    plan.preview = "mplus"
    NS.Dial.Sync({ d2 = plan }, { "d2" })
    local inst = NS.Dial.Instance("d2")
    assertEqual(inst.track.phase, "open", "the preview follows its surface")
    NS.Anim.Step(inst.track, 1)
    NS.Dial.Sync({ d2 = plan }, { "d2" })
    assertTrue(NS.Dial.IsOpen("d2"), "it came back")
    assertNil(inst.track.phase, "and did not flicker")
end)

test("anim dial: the stand-down leaves the dial's track off and its alpha whole", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open")
    NS.SchemaRuntime.Set("enabled", false)
    assertNil(inst.track.phase)
    assertFalse(NS.Anim.Running())
    assertEqual(inst.header:GetAlpha(), 1)
    assertEqual(#m.__timers(), 0)
end)

test("anim dial: nothing here writes a protected call on the header", function()
    for _, path in ipairs({ "modules/Anim.lua", "modules/Anim_Ghost.lua" }) do
        local f = assert(io.open(path, "rb"))
        local src = f:read("*a")
        f:close()
        -- red under: an animation that scales or moves the real frame, not its copy
        assertNil(src:find("src:SetScale", 1, true), path)
        assertNil(src:find("src:SetPoint", 1, true), path)
        assertNil(src:find("src:Show", 1, true), path)
        assertNil(src:find("src:Hide", 1, true), path)
        assertNil(src:find("SetAttribute", 1, true), path)
    end
end)

test("anim pad: the driver's show plays, and the real root lands at its rest alpha", function()
    local NS = live()
    local inst = pad(NS)
    drive(NS, inst, "hide")
    NS.Anim.Snap(inst.track)
    drive(NS, inst, "show")
    assertTrue(inst.root:IsShown(), "the driver did not wait")
    assertEqual(inst.track.phase, "open")
    assertEqual(inst.root:GetAlpha(), 0)
    NS.Anim.Step(inst.track, 1)
    assertNil(inst.track.phase)
    assertEqual(inst.root:GetAlpha(), 1)
end)

test("anim pad: the driver's hide plays out on the copy", function()
    local NS = live()
    local inst = pad(NS)
    drive(NS, inst, "hide")
    assertFalse(inst.root:IsShown(), "the driver did not wait")
    assertEqual(inst.track.phase, "close")
    assertTrue(inst.track.ghost.used > 0, "the buttons were mirrored after the hide")
    NS.Anim.Step(inst.track, 1)
    assertFalse(NS.Anim.Running())
end)

test("anim pad: hover and fade reach the rest alpha, and never lift a held root", function()
    local NS = live()
    local inst = pad(NS)
    drive(NS, inst, "hide")
    NS.Anim.Snap(inst.track)
    drive(NS, inst, "show")
    NS.Pad.SetHover("p1", true)
    assertEqual(inst.root:GetAlpha(), 0, "still under the ghost")
    NS.Pad.SetHover("p1", false)
    NS.db.profile.pads.p1.look.fade = "mouseover"
    NS.db.profile.pads.p1.look.fadeAlpha = 0.4
    NS.Anim.Step(inst.track, 1)
    assertEqual(inst.root:GetAlpha(), 0.4, "the alpha it rests at, not 1")
end)

test("anim pad: in combat the driver's hide and show play, refusing nothing", function()
    local NS, m = live()
    local inst = pad(NS)
    combat(m, true)
    local blocked = #m.blocked
    m.stateDrivers[inst.root].visibility = "hide"
    m.__applyStateDrivers()
    assertEqual(inst.track.phase, "close")
    m.stateDrivers[inst.root].visibility = "show"
    m.__applyStateDrivers()
    assertEqual(inst.track.phase, "open", "a reopen mid-close")
    NS.Anim.Step(inst.track, 1)
    assertEqual(#m.blocked, blocked)
end)

test("anim pad: each of the pad's switches is its own, and leaves the dial's alone", function()
    local NS, m = live()
    local inst, di = pad(NS), dial(NS)
    NS.db.profile.pads.p1.anim.openStyle = "none"
    drive(NS, inst, "hide")
    assertEqual(inst.track.phase, "close", "the pad's close is on")
    NS.Anim.Step(inst.track, 1)
    drive(NS, inst, "show")
    assertNil(inst.track.phase, "the pad's open is off")
    assertEqual(inst.root:GetAlpha(), 1)
    m.__click(di.header, "Toggle")
    assertEqual(di.track.phase, "open", "the dial's open is untouched")
    NS.Anim.Step(di.track, 1)
    NS.db.profile.dials.d2.anim.closeStyle = "none"
    NS.db.profile.pads.p1.anim.openStyle = "pop"
    drive(NS, inst, "hide")
    assertEqual(inst.track.phase, "close", "the dial's switch left the pad's close")
end)

test("anim pad: a pad its driver hides at login plays no close", function()
    local NS = live()
    local inst = pad(NS)
    inst.applied = nil   -- as a root just built: shown, its driver not yet set
    NS.SchemaRuntime.Set("visibility", "never")
    pad(NS)
    assertFalse(inst.root:IsShown())
    -- red under: the first Apply's driver hide on the track
    assertNil(inst.track.phase)
    assertFalse(NS.Anim.Running())
end)

test("anim pad: a hidden UIParent is no close", function()
    local NS = live()
    local inst = pad(NS)
    inst.root:__fire("OnHide")
    assertNil(inst.track.phase, "its own flag is still on")
end)

test("anim pad: the way back from a hidden UIParent is no open", function()
    local NS = live()
    local inst = pad(NS)
    NS.Anim.Step(inst.track, 1)
    local rest = inst.root:GetAlpha()
    inst.root:__fire("OnHide")
    inst.root:__fire("OnShow")
    assertNil(inst.track.phase, "Alt-Z coming back plays nothing")
    assertEqual(inst.root:GetAlpha(), rest, "no alpha held")
    drive(NS, inst, "hide")
    assertEqual(inst.track.phase, "close", "the flag was spent: a real close still plays")
    NS.Anim.Step(inst.track, 1)
    drive(NS, inst, "show")
    assertEqual(inst.track.phase, "open", "and so does the next real open")
end)

test("anim pad: a release drops a held quiet show", function()
    local NS = live()
    local inst = pad(NS)
    NS.Anim.Step(inst.track, 1)
    inst.root:__fire("OnHide")
    assertTrue(NS.Pad.Release("p1"))
    pad(NS)
    drive(NS, inst, "hide")
    NS.Anim.Step(inst.track, 1)
    drive(NS, inst, "show")
    assertEqual(inst.track.phase, "open")
end)

test("anim pad: a release snaps, and a stand-down leaves nothing running", function()
    local NS, m = live()
    local inst = pad(NS)
    drive(NS, inst, "hide")
    assertEqual(inst.track.phase, "close")
    assertTrue(NS.Pad.Release("p1"))
    assertNil(inst.track.phase)
    pad(NS)
    drive(NS, inst, "show")
    assertEqual(inst.track.phase, "open")
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Anim.Running())
    assertEqual(#m.__timers(), 0)
end)

test("anim ghost: a color texture copies from what its painter recorded, a file from the client", function()
    local NS = live()
    local inst = pad(NS)
    local btn = inst.buttons.active[1]
    assertTrue(btn.qcBg.qcGhostColor ~= nil, "the fill records its color")
    drive(NS, inst, "hide")
    assertTrue(inst.track.ghost.used > 0)
end)

test("anim ghost: no rect yet snaps instead of guessing, and the strip stays out", function()
    local NS = live()
    local inst = pad(NS)
    assertTrue(inst.handle.qcNoGhost, "the strip keeps its own alpha")
    local center = inst.root.GetCenter
    inst.root.GetCenter = function() return nil end
    drive(NS, inst, "hide")
    assertNil(inst.track.phase)
    inst.root.GetCenter = center
end)
