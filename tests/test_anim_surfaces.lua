-- tests/test_anim_surfaces.lua — the open and close animations on the real dial (#13): the ghost's
-- capture, which edges animate, the secure frames left alone, combat, the send, independence of the
-- two switches and the stand-down; and a pad, which has no animation (the owner's ruling, 2026-11-01).

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
    a.openStyle, a.closeStyle = "scaleInFade", "none"
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

-- ── the text on the real dial: no shimmer, no truncation ─────────────────────────────────────────

local function strings(track)
    local ghost, out = track.ghost, {}
    for i = 1, ghost.textUsed do
        for j = 1, ghost.textSubs[i].qcFontUsed do out[#out + 1] = ghost.textSubs[i].qcFont[j] end
    end
    return out
end

-- A whole-dial scale with no turn, the shipped defaults turning too.
local function scaling(NS)
    local a = NS.db.profile.dials.d2.anim
    a.openStyle, a.closeStyle, a.openDuration, a.closeDuration = "scaleInFade", "scaleInFade", 0.15, 0.1
end

test("anim dial: an open scales the text by its own animation, and the landing stops it", function()
    local NS, m = live()
    local inst = dial(NS)
    scaling(NS)
    m.__click(inst.header, "Toggle")
    local list = strings(inst.track)
    assertTrue(#list > 0, "the labels were copied")
    for _, fs in ipairs(list) do
        assertEqual(fs.__scaleMode, m.Enum.FontStringScaleAnimationMode.Vertex)
        assertTrue(fs.__scaleGroup.__playing, "it plays")
        assertEqual(fs.__scaleAnim.__from, 0.25)
        assertEqual(fs.__scaleAnim.__to, 1)
        assertEqual(fs.__scaleAnim.__duration, inst.track.duration)
    end
    NS.Anim.Step(inst.track, 1)
    for _, fs in ipairs(list) do assertFalse(fs.__scaleGroup.__playing, "nothing left running") end
end)

test("anim dial: a reversal restarts the text from the art's scale, with the art", function()
    local NS, m = live()
    local inst = dial(NS)
    scaling(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 0.05)
    local scale = inst.track.pose.scale
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "close")
    for _, fs in ipairs(strings(inst.track)) do
        assertEqual(fs.__scaleAnim.__from, scale)
        assertEqual(fs.__scaleAnim.__to, 0.25)
        assertTrue(fs.__scaleGroup.__playing)
    end
end)

test("anim dial: a send's slice swells its own text, and the rest keep collapsing", function()
    local NS, m = live()
    local inst = dial(NS)
    scaling(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    m.__click(w)
    assertEqual(inst.track.emphasis, w.qcGhostGroup)
    local ghost, swelled, collapsed = inst.track.ghost, 0, 0
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        for j = 1, sub.qcFontUsed do
            local to = sub.qcFont[j].__scaleAnim.__to
            if sub.qcGroup == w.qcGhostGroup then
                assertTrue(to > 1, "the sent place swells")
                swelled = swelled + 1
            elseif to == 0.25 then
                collapsed = collapsed + 1
            end
        end
    end
    assertTrue(swelled > 0 and collapsed > 0, "both happened")
end)

test("anim dial: the stand-down leaves no text scaling running", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    local list = strings(inst.track)
    NS.SchemaRuntime.Set("enabled", false)
    for _, fs in ipairs(list) do assertFalse(fs.__scaleGroup.__playing) end
end)

test("anim dial: a Fan moves no text at all", function()
    local NS, m = live()
    local inst = dial(NS)
    NS.db.profile.dials.d2.anim.openStyle = "fan"
    m.__click(inst.header, "Toggle")
    for _, fs in ipairs(strings(inst.track)) do assertFalse(fs.__scaleGroup.__playing == true) end
end)

test("anim dial: the ghost's text never carries a width", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    for _, fs in ipairs(strings(inst.track)) do assertNil(fs.__size, "a size is what truncated the title") end
end)

test("anim compat: the Vertex shim answers nothing when any piece is missing", function()
    local NS, m = live()
    local C = NS.Compat
    assertNil((C.VertexScaleAnimation({})), "a string with no methods")
    local noop = function() end
    local fs = { SetScaleAnimationMode = noop, CreateAnimationGroup = function() return {} end }
    assertNil((C.VertexScaleAnimation(fs)), "a group with no CreateAnimation")
    local partial = { SetScaleAnimationMode = noop, CreateAnimationGroup = function()
        return { Play = noop, Stop = noop, CreateAnimation = function() return { SetScaleFrom = noop } end }
    end }
    assertNil((C.VertexScaleAnimation(partial)), "an animation short of a setter")
    local mode, whole
    whole = { SetScaleAnimationMode = function(_, v) mode = v end, CreateAnimationGroup = function()
        return { Play = noop, Stop = noop, CreateAnimation = function()
            return { SetScaleFrom = noop, SetScaleTo = noop, SetOrigin = noop, SetDuration = noop, SetSmoothing = noop }
        end }
    end }
    local group, anim = C.VertexScaleAnimation(whole)
    assertTrue(group ~= nil and anim ~= nil)
    assertEqual(mode, 1)
    local saved = m.Enum
    m.Enum = nil
    assertNil((C.VertexScaleAnimation(whole)), "no Enum at all")
    m.Enum = saved
end)

test("anim compat: the stretch shim answers nothing when any piece is missing", function()
    local NS = live()
    local C = NS.Compat
    assertNil((C.StretchAnimation({})), "a frame with no groups")
    local noop = function() end
    local origin
    local anim = { SetScaleFrom = noop, SetScaleTo = noop, SetDuration = noop, SetSmoothing = noop }
    local frame = { CreateAnimationGroup = function()
        return { Play = noop, Stop = noop, CreateAnimation = function() return anim end }
    end }
    assertNil((C.StretchAnimation(frame)), "an animation short of a setter")
    anim.SetOrigin = function(_, point) origin = point end
    local group, got = C.StretchAnimation(frame)
    assertTrue(group ~= nil)
    assertEqual(got, anim)
    assertEqual(origin, "CENTER")
end)

local function rotating(NS)
    local a = NS.db.profile.dials.d2.anim
    a.openStyle, a.closeStyle, a.openDuration, a.closeDuration = "rotateScale", "rotateScale", 0.5, 0.5
end

test("anim dial: Rotate and scale turns the real ring's fills on the ghost and leaves its icons upright", function()
    local NS, m = live()
    rotating(NS)
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    local ghost = inst.track.ghost
    assertEqual(ghost.radius, inst.shownRing.qcShape.disc / 2, "the ring's own disc")
    NS.Anim.Step(inst.track, 0.1)
    local turned, moved = 0, 0
    for i = 1, ghost.used do
        local sub = ghost.subs[i]
        if sub.qcGroup and sub.qcTurned ~= 0 then moved = moved + 1 end
        for j = 1, sub.qcTexUsed do
            if sub.qcTex[j].qcTurn then turned = turned + 1 end
        end
        if not sub.qcGroup then assertEqual(sub.qcTurned, 0, "the hub stays level") end
    end
    assertTrue(turned >= inst.shownRing.qcSpec.size, "every fill turns")
    assertTrue(moved >= inst.shownRing.qcSpec.size)
    NS.Anim.Step(inst.track, 1)
    assertNil(inst.track.phase)
    assertEqual(inst.header:GetAlpha(), 1)
end)

test("anim dial: Rotate and scale reverses, sends and stands down as every style does, in combat too", function()
    local NS, m = live()
    rotating(NS)
    local inst = dial(NS)
    combat(m, true)
    local blocked = #m.blocked
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 0.1)
    local rot = inst.track.pose.rot
    assertTrue(rot < 0)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "close")
    assertEqual(inst.track.pose.rot, rot, "no jump")
    NS.Anim.Step(inst.track, 1)
    assertEqual(#m.blocked, blocked)
    combat(m, false)
    m.__click(inst.header, "Toggle")
    local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    m.__click(w)
    assertEqual(#m.sentMacros, 1, "the send never waits")
    NS.Anim.Step(inst.track, 0.01)
    local ghost = inst.track.ghost
    for i = 1, ghost.used do
        if ghost.subs[i].qcGroup == w.qcGhostGroup then assertEqual(ghost.subs[i].qcTurned, 0, "the sent slice stays put") end
    end
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Anim.Running())
    assertEqual(inst.header:GetAlpha(), 1)
end)

test("anim dial: a lit slice's highlight goes with its place on the ghost", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    local ring = inst.shownRing
    NS.DialSlices.Track(ring, 0, ring.qcShape.disc * 0.4)
    assertEqual(ring.qcHighlight.qcGhostGroup, ring.qcLit)
    assertTrue(ring.qcHighlight.qcGhostTurn, "and turns with it")
end)

-- ── a pad does not animate (the owner's ruling, 2026-11-01): its behavior as before #13 ───────────

test("anim pad: a pad has no track, and its driver shows and hides it at once", function()
    local NS = live()
    local inst = pad(NS)
    assertNil(inst.track, "no track")
    local n = { open = 0, close = 0 }
    local open, close = NS.Anim.Open, NS.Anim.Close
    NS.Anim.Open = function(...) n.open = n.open + 1 return open(...) end
    NS.Anim.Close = function(...) n.close = n.close + 1 return close(...) end
    drive(NS, inst, "hide")
    assertFalse(inst.root:IsShown())
    drive(NS, inst, "show")
    assertTrue(inst.root:IsShown())
    assertEqual(n.open + n.close, 0, "nothing played")
    assertFalse(NS.Anim.Running())
    assertEqual(inst.root:GetAlpha(), 1, "and no alpha held")
end)

test("anim pad: its alpha paths answer as before: master opacity, fade, hover, and combat", function()
    local NS, m = live()
    local inst = pad(NS)
    NS.db.profile.alpha = 0.6
    NS.Pad.ApplyAlpha("p1")
    assertEqual(inst.root:GetAlpha(), 0.6)
    local look = NS.db.profile.pads.p1.look
    look.fade, look.fadeAlpha = "mouseover", 0.4
    NS.Pad.ApplyAlpha("p1")
    assertEqual(inst.root:GetAlpha(), NS.PadLayout.Alpha(0.6, look, false, false))
    NS.Pad.SetHover("p1", true)
    assertEqual(inst.root:GetAlpha(), NS.PadLayout.Alpha(0.6, look, false, true), "a hover lifts it at once")
    NS.Pad.SetHover("p1", false)
    combat(m, true)
    NS.Pad.ApplyAlpha("p1")
    assertEqual(inst.root:GetAlpha(), NS.PadLayout.Alpha(0.6, look, true, false), "SetAlpha is allowed in combat")
    look.fade = "outOfCombat"
    NS.Pad.ApplyAlpha("p1")
    assertEqual(inst.root:GetAlpha(), 0.6, "out of combat's fade lifts in combat")
    combat(m, false)
    NS.Pad.ApplyAlpha("p1")
    assertEqual(inst.root:GetAlpha(), NS.PadLayout.Alpha(0.6, look, false, false), "and comes back after")
end)

test("anim pad: a release and a rebuild touch no animation state", function()
    local NS = live()
    local inst = pad(NS)
    assertTrue(NS.Pad.Release("p1"))
    assertNil(inst.silent)
    pad(NS)
    assertNil(inst.track)
    assertFalse(NS.Anim.Running())
end)

test("anim pad: nothing in a pad's code names the animations", function()
    for _, path in ipairs({ "modules/Pad.lua", "modules/Pad_Render.lua", "settings/Pads.lua" }) do
        local f = assert(io.open(path, "rb"))
        local src = f:read("*a")
        f:close()
        assertNil(src:find("NS.Anim", 1, true), path)
        assertNil(src:find("qcGhost", 1, true), path)
        assertNil(src:find("pad.anim", 1, true), path)
    end
end)

test("anim ghost: no rect yet snaps instead of guessing", function()
    local NS, m = live()
    local inst = dial(NS)
    local center = inst.header.GetCenter
    inst.header.GetCenter = function() return nil end
    m.__click(inst.header, "Toggle")
    assertNil(inst.track.phase)
    assertEqual(inst.header:GetAlpha(), 1, "never left invisible")
    inst.header.GetCenter = center
end)

-- ── the rest of the sweep (#13): each case below is red under a mutant the suite let through ─────────

local function counted(NS)
    local n = { open = 0, close = 0 }
    local open, close = NS.Anim.Open, NS.Anim.Close
    NS.Anim.Open = function(...) n.open = n.open + 1 return open(...) end
    NS.Anim.Close = function(...) n.close = n.close + 1 return close(...) end
    return n
end

test("anim surfaces: a dial reads its own instance's settings, and the kind's defaults when it has none", function()
    local NS = live()
    local di = dial(NS)
    NS.db.profile.dials.other = { anim = { openStyle = "none" } }
    di.id = "other"
    assertEqual(di.track.spec.config("open").style, "none", "a second dial's own switch")
    assertEqual(di.track.spec.config("close").style, "rotateScale", "a dial's missing key is a dial's default")
    assertEqual(di.track.spec.config("close").duration, 0.2)
end)

test("anim surfaces: a rebuild's close starts no close at all", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    local n = counted(NS)
    dial(NS)
    -- red under: the ring's later show snapping away a close that had already started
    assertEqual(n.close, 0)
    assertEqual(n.open, 0)
end)

test("anim surfaces: a rebuild snaps a track that was playing", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open")
    local held = inst.track
    NS.Dial.Release(1)
    assertNil(held.phase)
    assertEqual(inst.header:GetAlpha(), NS.Setting("alpha") or 1)
end)

test("anim surfaces: a dial with no ring on screen plays no close", function()
    local NS = live()
    local inst = dial(NS)
    local n = counted(NS)
    inst.shownRing = nil
    inst.header:__fire("OnHide")
    assertEqual(n.close, 0)
end)

test("anim surfaces: an open interrupted by a hide does not arm the next ring's show", function()
    local NS, m = live()
    local inst = dial(NS)
    inst.opening = true
    NS.Dial.Closed(inst)
    assertNil(inst.opening)
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.phase, "open")
end)

test("anim surfaces: a silent reopen's ring leaves a track alone, and a stood-down ring plays nothing", function()
    local NS, m = live()
    local inst = dial(NS)
    local snaps, snap = 0, NS.Anim.Snap
    NS.Anim.Snap = function(...) snaps = snaps + 1 return snap(...) end
    inst.silent = true
    NS.Dial.RingShown(inst, inst.shownRing)
    assertEqual(snaps, 0, "a silent reopen is no page turn")
    inst.silent = nil
    local n = counted(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    local stood = NS.IsStoodDown
    NS.IsStoodDown = function() return true end
    inst.opening = true
    NS.Dial.RingShown(inst, inst.shownRing)
    assertEqual(n.open, 1, "only the player's open")
    NS.IsStoodDown = stood
end)

test("anim surfaces: a stood-down dial plays no close", function()
    local NS, m = live()
    local di = dial(NS)
    m.__click(di.header, "Toggle")
    NS.Anim.Step(di.track, 1)
    local n = counted(NS)
    local stood = NS.IsStoodDown
    NS.IsStoodDown = function() return true end
    di.header:Hide()
    assertEqual(n.close, 0, "a dial's close")
    NS.IsStoodDown = stood
end)

test("anim surfaces: a test mode reopen is silent only for its own show", function()
    local NS = live()
    local plan = planOf(NS, { test = true })
    NS.Dial.Sync({ d2 = plan }, { "d2" })
    local inst = NS.Dial.Instance("d2")
    NS.Dial.Sync({ d2 = plan }, { "d2" })
    assertNil(inst.silent, "red under: a rebuild's silence outliving the rebuild")
end)

test("anim surfaces: the close names the sent place whichever way round the click ran", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[2]
    -- the hook first, the wrap's close after: the stamp carries the place into the close
    NS.Dial.Sent(inst, w)
    assertNil(inst.track.emphasis, "no close yet to hear it")
    m.__click(inst.header, "Toggle")
    assertEqual(inst.track.emphasis, w.qcGhostGroup)
end)

test("anim surfaces: a stale stamp emphasizes nothing, and a guarded press none", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    inst.sentAt, inst.sentPlace = m.GetTime() - 5, 2
    m.__click(inst.header, "Toggle")
    assertNil(inst.track.emphasis, "a send long ago is not this close's")
    NS.Anim.Step(inst.track, 1)
    local sent, sendsTo = 0, NS.Dial.Sent
    NS.Dial.Sent = function(...) sent = sent + 1 return sendsTo(...) end
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    m.__click(w)
    assertEqual(sent, 1, "a press the guard let through")
    m.__click(inst.header, "Toggle")
    NS.Anim.Step(inst.track, 1)
    w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    m.__click(w)
    assertEqual(sent, 1, "a guarded press is no send")
end)

test("anim surfaces: a track rests at the dial's alpha, the master opacity included", function()
    local NS, m = live()
    local di = dial(NS)
    NS.db.profile.alpha = 0.6
    assertEqual(di.track.spec.restAlpha(), 0.6)
    m.__click(di.header, "Toggle")
    NS.Anim.Step(di.track, 1)
    assertEqual(di.header:GetAlpha(), 0.6, "the dial lands at it, not at 1")
end)

test("anim surfaces: the dial's ghost mirrors the hub and pointer, and each slice's fill by its place", function()
    local NS, m = live()
    local inst = dial(NS)
    m.__click(inst.header, "Toggle")
    local roots = inst.track.spec.roots()
    assertEqual(roots[2], inst.header.qcPointer, "the hub is on the front frame, over the ring")
    local placed = {}
    for _, t in ipairs(inst.shownRing.qcFills) do
        if t.qcGhostGroup then placed[t.qcGhostGroup] = true end
    end
    for j = 1, inst.shownRing.qcSpec.size do assertTrue(placed[j], "the fill of place " .. j) end
    local shineTagged = false
    for _, t in pairs(inst.shownRing.qcShine[1]) do
        if type(t) == "table" and t.qcGhostGroup == 1 then shineTagged = true end
    end
    assertTrue(shineTagged, "a slice's shine goes with its fill")
end)
