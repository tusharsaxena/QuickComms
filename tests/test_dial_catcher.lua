-- tests/test_dial_catcher.lua — split off tests/test_dial.lua at the layout-§1 band (FX-QC-SIZE): select
-- to the hub (dial polish T3), where the secure catcher clicks and the insecure tracker hovers.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local AB, live, planOf, wedgeTitled =
    D.AB, D.live, D.planOf, D.wedgeTitled

-- ── select to the hub (dial polish T3): the catcher clicks, the tracker hovers ───────────────

-- The default dial on a fixed four with planOf's first `n` callouts, open from its header (as its
-- key opens it) on that callout ring; answers the ring and a function that puts the cursor (dx, dy)
-- from the hub's center.
local function openPolish(NS, m, n)
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, { n = n })))
    local inst = NS.Dial.Instance("d2")
    local h = inst.header
    m.__click(h, "Toggle")
    local ring = inst.rings.active[NS.Dial.ShownRing("d2")]
    local cx, cy = h:GetCenter()
    local function cursor(dx, dy)
        m.cursor.x, m.cursor.y = (cx + dx) * h:GetEffectiveScale(), (cy + dy) * h:GetEffectiveScale()
    end
    return ring, cursor, h
end

test("dial: [polish] a click near the hub sends the lit slice, in combat", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    local south = ring.qcPlaceWedge[3]
    assertTrue(south ~= nil and south.qcItem == ring.qcSpec.items[2], "two items on four places: the second is S")
    m.inCombat = true
    cursor(0, -25)   -- 25 px south: inside the old dead band between the hub and the wedge's square
    -- red under: no catcher (a click lands only on a wedge's own square)
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, south:GetAttribute("macrotext"))
    assertTrue(m.sentMacros[1].frame == south, "forwarded to the S wedge's own button")
    assertFalse(NS.Dial.IsOpen("d2"), "the dial closes on the send")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a click with a modifier held still sends the slice, in combat", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    local south = ring.qcPlaceWedge[3]
    m.inCombat = true
    for _, mod in ipairs({ "shift", "ctrl", "alt" }) do
        m.modifiers = { [mod] = true }
        if not NS.Dial.IsOpen("d2") then m.__click(NS.Dial.Instance("d2").header, "Toggle") end
        cursor(0, -40)
        local before = #m.sentMacros
        -- red under: the catcher's plain type-w<j> / clickbutton-w<j> (never read with a modifier held)
        m.__click(ring.qcCatcher)
        assertEqual(#m.sentMacros, before + 1, mod .. " held: the slice sends")
        assertTrue(m.sentMacros[#m.sentMacros].frame == south, mod .. ": forwarded to the S wedge")
    end
    m.modifiers = {}
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] just outside the hub's circle, on a diagonal, the slice lights and clicks, in combat", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    local south = ring.qcPlaceWedge[3]
    local dx, dy = 10, -18   -- 20.6 px out (hub 40: outside its circle), bearing ~151 degrees (S)
    local dist, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dx, dy)
    -- red under: the hub as a square in DL.SliceAt (|dx|, |dy| <= hub / 2)
    assertEqual(NS.DialLayout.SliceAt(angle, dist, 4, 0, 40, 300), 3, "the round hub ends at 20: S")
    assertFalse(NS.DialLayout.InHub(dist, 40), "off the hub")
    NS.DialSlices.Track(ring, angle, dist)
    assertEqual(ring.qcLit, 3, "the tracker lights S there")
    m.inCombat = true
    cursor(dx, dy)
    -- red under: the hub as a square in CATCHER_PRE
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 1, "the catcher forwards it")
    assertTrue(m.sentMacros[1].frame == south, "to the S wedge, the slice that lit")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a click inside the hub's circle runs the hub, any modifier held, in combat", function()
    local NS, m = live()
    local ring, cursor, h = openPolish(NS, m, 2)
    local inst = NS.Dial.Instance("d2")
    -- red under: the header taking the mouse (its square would hold the corners past the circle)
    assertFalse(h:IsMouseEnabled(), "the header takes no mouse: the catcher is the hub's mouse")
    local dx, dy = 12, 9   -- 15 px out: inside the circle
    assertNil(NS.DialLayout.SliceAt(math.atan2(dx, dy), 15, 4, 270, 40, 300), "no slice there")
    assertTrue(NS.DialLayout.InHub(15, 40))
    m.inCombat = true
    for _, mod in ipairs({ "none", "shift", "ctrl", "alt" }) do
        m.modifiers = mod == "none" and {} or { [mod] = true }
        if not NS.Dial.IsOpen("d2") then m.__click(h, "Toggle") end
        -- the dial opens where it was closed: the first ring after the first pass
        if NS.Dial.ShownRing("d2") == 1 then m.__click(wedgeTitled(NS, 1, "Dungeon")) end
        assertEqual(NS.Dial.ShownRing("d2"), 2, mod .. ": on the callout ring, a child of the groups")
        cursor(dx, dy)
        -- red under: CATCHER_PRE answering nothing inside the hub (no qc-up)
        m.__click(ring.qcCatcher)
        assertEqual(NS.Dial.ShownRing("d2"), 1, mod .. ": the hub goes up a ring")
        local top = inst.rings.active[1]
        m.__click(top.qcCatcher)
        assertFalse(NS.Dial.IsOpen("d2"), mod .. ": on the first ring the hub closes")
    end
    m.modifiers = {}
    assertEqual(#m.sentMacros, 0, "the hub sends nothing")
    assertEqual(#m.blocked, 0)
end)

test("dial: a right click on a slice goes up a ring, and does nothing on the first ring, in combat", function()
    local NS, m = live()
    local _, cursor, h = openPolish(NS, m, 8)
    local inst = NS.Dial.Instance("d2")
    m.inCombat = true
    m.__click(h, "Next")
    assertEqual(NS.Dial.ShownRing("d2"), 3, "the callout ring's second page")
    cursor(40, 0)
    -- red under: CATCHER_PRE closing on any button but the left
    m.__click(inst.rings.active[3].qcCatcher, "RightButton")
    assertTrue(NS.Dial.IsOpen("d2"), "a right click on a slice keeps the dial open")
    assertEqual(NS.Dial.ShownRing("d2"), 1, "up to the ring of groups, from any page")
    m.__click(inst.rings.active[1].qcCatcher, "RightButton")
    assertTrue(NS.Dial.IsOpen("d2"), "the first ring: nothing")
    assertEqual(NS.Dial.ShownRing("d2"), 1)
    cursor(0, 0)
    m.__click(inst.rings.active[1].qcCatcher, "RightButton")
    assertFalse(NS.Dial.IsOpen("d2"), "a right click on the hub still closes")
    assertEqual(#m.sentMacros, 0, "a right click sends nothing")
    assertEqual(#m.blocked, 0)
end)

test("dial: a key open shows the ring and page the dial was last closed on, through a rebuild", function()
    local NS, m = live()
    local _, _, h = openPolish(NS, m, 8)
    assertEqual(NS.Dial.ShownRing("d2"), 2, "first open: the ring it opens on")
    m.__click(h, "Next")
    m.__click(h, "Toggle")
    m.inCombat = true
    m.__click(h, "Toggle")
    -- red under: OPEN showing qc-openRing alone
    assertEqual(NS.Dial.ShownRing("d2"), 3, "the same ring, its second page, in combat")
    m.__click(h, "Close")
    m.inCombat = false
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, { n = 8 })))
    m.__click(h, "Toggle")
    assertEqual(NS.Dial.ShownRing("d2"), 3, "a rebuild keeps it: rings are found by key and page")
    m.__click(h, "Toggle")
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, { n = 4 })))
    m.__click(h, "Toggle")
    assertEqual(NS.Dial.ShownRing("d2"), 2, "that page gone: the same ring's first page")
    m.__click(h, "LeftButton")
    assertEqual(NS.Dial.ShownRing("d2"), 1)
    m.__click(h, "Toggle")
    NS.DialSecure.Open(h)
    assertEqual(NS.Dial.ShownRing("d2"), 2, "an insecure open (test mode) shows the ring it opens on")
    NS.DialSecure.Close(h)
    m.__click(h, "Toggle")
    assertEqual(NS.Dial.ShownRing("d2"), 1, "and leaves what a key open remembers alone")
end)

test("dial: [polish] the hub's hover shows from the tracker inside its circle and clears outside", function()
    local NS, m = live(AB)
    local _, cursor, h = openPolish(NS, m, 2)
    local tip = m.GameTooltip
    local rest = h.qcHubDot.__color[4]
    cursor(12, 9)   -- 15 px out: on the hub
    NS.DialRender.PointerUpdate(h.qcPointer)
    -- red under: the hub's hover only from the header's OnEnter (it takes no mouse)
    assertTrue(h.qcHubDot.__color[4] > rest, "the circle brightens")
    assertTrue(tip.__owner == h and tip:IsShown(), "the hub owns the tooltip")
    assertEqual(tip.__lines[1][1], "Why is this showing?")
    cursor(10, -18)   -- 20.6 px out: on S
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertEqual(h.qcHubDot.__color[4], rest, "off the hub: dims back")
    assertFalse(tip.__owner == h, "the hub's tooltip gone")
    cursor(0, 0)
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertTrue(tip.__owner == h and tip:IsShown(), "back on the hub")
    m.__click(h, "Toggle")
    assertEqual(h.qcHubDot.__color[4], rest, "closing clears the hub's hover")
    assertFalse(tip:IsShown())
end)

test("dial: [polish] the dial's key still opens and closes it with the header's mouse off, in combat", function()
    local NS, m = live()
    m.SetBinding("G", "CLICK QuickCommsDial1:Toggle")
    local h = NS.Dial.Instance("d2").header
    -- red under: the header taking the mouse
    assertFalse(h:IsMouseEnabled())
    m.inCombat = true
    assertTrue(m.__pressKey("G"))
    assertTrue(NS.Dial.IsOpen("d2"), "the key opens it")
    m.__pressKey("ESCAPE")
    assertFalse(NS.Dial.IsOpen("d2"), "Escape closes it")
    m.__pressKey("G")
    m.__pressKey("G")
    assertFalse(NS.Dial.IsOpen("d2"), "the key closes it")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a click on an empty place does nothing; in the hub it sends nothing", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    m.inCombat = true
    cursor(40, 0)   -- E: place 2, empty with two items (N, S)
    -- red under: write type-w<j> for every place in DS.Load, used or not
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 0)
    assertTrue(NS.Dial.IsOpen("d2"), "an empty place does nothing")
    cursor(5, 5)
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.Dial.ShownRing("d2"), 1, "the hub goes up a ring, through the catcher")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] hovering anywhere in a slice shows its tooltip", function()
    local NS, m = live()
    local ring, cursor, h = openPolish(NS, m, 2)
    local south = ring.qcPlaceWedge[3]
    local tip = m.GameTooltip
    cursor(0, -25)
    NS.DialRender.PointerUpdate(h.qcPointer)
    -- red under: show a wedge's tooltip only from its own OnEnter
    assertTrue(tip.__owner == south, "the lit slice's wedge owns the tooltip")
    assertTrue(tip:IsShown())
    assertEqual(tip.__lines[1][1], NS.DialRender.WedgeLines(south.qcItem)[1])
    cursor(0, 25)
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertTrue(tip.__owner == ring.qcPlaceWedge[1], "N next")
    cursor(3, 3)
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertFalse(tip.__owner == ring.qcPlaceWedge[1], "into the hub: the wedge's tooltip is gone")
    assertNil(ring.qcLit, "and no slice is lit")
end)

test("dial: [polish] wedges take no mouse; keys still click by name", function()
    local NS, m = live()
    local ring = openPolish(NS, m, 8)
    for _, r in ipairs(NS.Dial.Instance("d2").rings.active) do
        for _, w in ipairs(r.qcWedges.active) do
            -- red under: keep the wedges mouse-enabled (their grown hit squares)
            assertFalse(w:IsMouseEnabled(), "a wedge takes no mouse")
        end
    end
    local first = ring.qcWedges.active[1]
    m.__pressKey("1")
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, first:GetAttribute("macrotext"), "the number key clicks item 1 by name")
end)

test("dial: [polish] a built dial closes on a click outside it, in combat", function()
    local NS, m = live()
    openPolish(NS, m, 2)
    local screen = NS.Dial.Instance("d2").screen
    -- red under: no screen catcher made in build / no `screen` ref handed to DS.Load
    assertTrue(screen ~= nil and screen:IsShown(), "open from its key, the screen catcher is up")
    m.inCombat = true
    m.__click(screen, "RightButton")
    assertFalse(NS.Dial.IsOpen("d2"))
    assertEqual(#m.sentMacros, 0)
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a ring hidden under the hover clears its slice, tooltip and hover glow", function()
    local NS, m = live()
    local ring, cursor, h = openPolish(NS, m, 8)
    local inst = NS.Dial.Instance("d2")
    local tip = m.GameTooltip
    cursor(25, 0)
    NS.DialRender.PointerUpdate(h.qcPointer)
    local lit = ring.qcLit
    local wedge = ring.qcPlaceWedge[lit]
    assertTrue(wedge ~= nil and tip.__owner == wedge and tip:IsShown(), "a slice of page 1 hovered")
    assertTrue(wedge.qcHovered, "its hover glow on")
    m.__click(ring.qcNext)   -- the arrow snippet hides page 1 and shows page 2
    assertEqual(NS.Dial.ShownRing("d2"), 3, "page 2 on screen")
    -- red under: no OnHide hook on a ring (only the header's OnHide clears the hover)
    assertFalse(tip:IsShown(), "page 1's tooltip hidden with its ring")
    assertNil(ring.qcLit, "page 1 has no slice lit")
    assertNil(wedge.qcHovered, "its wedge's hover glow off")
    m.__click(inst.header, "LeftButton")   -- the hub goes up a ring
    assertNil(ring.qcLit)
end)
