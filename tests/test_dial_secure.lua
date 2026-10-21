-- tests/test_dial_secure.lua — modules/Dial_Secure.lua (spec §11.2, Relaxed mode): a dial built by hand
-- from its header, ring containers and wedges opens on the key, switches rings, sends once and closes,
-- in and out of combat, with Escape, the number keys and the wheel bound only while it is open.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

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

-- Ring 1 holds a ring wedge (to ring 2) and a callout; ring 2 holds two callouts, goes up to ring 1 and
-- pages on to ring 3; ring 3 holds one callout and goes back to ring 2.
local function built(opts)
    opts = opts or {}
    local NS, m = T.enableAddon()
    local DS, SE = NS.DialSecure, NS.SendEngine
    local h = DS.NewHeader(7)
    local function wedge(ring, line, target)
        local b = DS.NewWedge(h, ring)
        if line then SE.Arm(b, line, { calloutId = "c-" .. line, surfaceId = "d9", chatType = "PARTY", name = line }) end
        return { button = b, target = target or 0 }
    end
    local frames = { DS.NewRing(h), DS.NewRing(h), DS.NewRing(h) }
    local rings = {
        { frame = frames[1], parent = 0, prev = 0, next = 0, wedges = { wedge(frames[1], nil, 2), wedge(frames[1], "/p one") } },
        { frame = frames[2], parent = 1, prev = 0, next = 3, wedges = { wedge(frames[2], "/p two"), wedge(frames[2], "/p three") } },
        { frame = frames[3], parent = 2, prev = 2, next = 0, wedges = { wedge(frames[3], "/p four") } },
    }
    local screen = opts.screen and DS.NewScreen(h) or nil
    assertTrue(DS.Load(h, rings, { openRing = opts.openRing or 1, openAt = opts.openAt, screen = screen }))
    return NS, m, h, frames, rings, screen
end

local function shown(frames)
    for r, f in ipairs(frames) do
        if f:IsShown() then return r end
    end
    return nil
end

test("dial secure: the header is QuickCommsDial<n>, hidden until the toggle opens it; open, the dial owns Escape and 1-8", function()
    local _, m, h, frames, rings = built()
    assertEqual(h:GetName(), "QuickCommsDial7")
    assertFalse(h:IsShown())
    m.__click(h, "Toggle")
    assertTrue(h:IsShown())
    assertEqual(shown(frames), 1)
    assertTrue(m.restrictedBindings.ESCAPE ~= nil)
    assertEqual(m.restrictedBindings["2"].target, rings[1].wedges[2].button:GetName())
    m.__click(h, "Toggle")
    assertFalse(h:IsShown())
    assertNil(shown(frames))
    -- red under: drop `self:ClearBindings()` from the close snippet
    assertNil(m.restrictedBindings.ESCAPE, "released on close")
end)

test("dial secure: [exit] a group wedge opens its ring (the two-stroke); a callout wedge sends once and closes", function()
    local _, m, h, frames, rings = built()
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button)
    assertEqual(shown(frames), 2)
    assertEqual(#m.sentMacros, 0, "a group wedge sends nothing")
    m.__click(rings[2].wedges[2].button)
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, "/p three")
    assertFalse(h:IsShown(), "the dial closes after a send")
end)

test("dial secure: [review 2] right click, Escape and the hub close without sending; the hub goes up a ring first", function()
    local NS, m, h, frames, rings = built()
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button)
    m.__click(h, "LeftButton")
    assertEqual(shown(frames), 1, "the hub goes up a ring")
    m.__click(rings[1].wedges[2].button, "RightButton")
    assertFalse(h:IsShown())
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0, "a right click is no press")
    m.__click(h, "Toggle")
    assertTrue(m.__pressKey("ESCAPE"))
    assertFalse(h:IsShown())
    m.__click(h, "Toggle")
    m.__click(h, "LeftButton")
    assertFalse(h:IsShown(), "the hub on the first ring closes")
    assertEqual(#m.sentMacros, 0)
end)

test("dial secure: [review 5] the wheel turns pages; the number keys pick the shown ring's wedges", function()
    local _, m, h, frames = built({ openRing = 2 })
    m.__click(h, "Toggle")
    assertEqual(shown(frames), 2, "opens on the ring it is told")
    m.__pressKey("MOUSEWHEELDOWN")
    assertEqual(shown(frames), 3)
    m.__pressKey("MOUSEWHEELUP")
    assertEqual(shown(frames), 2)
    m.__pressKey("1")
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p two")
    assertFalse(h:IsShown())
    assertFalse(m.__pressKey("1"), "the number keys are released with the dial")
end)

test("dial secure: [exit] in combat the dial opens, switches rings and sends, with nothing blocked", function()
    local NS, m, h, _, rings = built()
    combat(m, true)
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button)
    m.__click(rings[2].wedges[1].button)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p two")
    assertFalse(h:IsShown())
    assertEqual(#m.blocked, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 1, "tracked like a button's send")
end)

test("dial secure: open at the cursor anchors the hub to it; a dial with no ring opens nothing", function()
    local NS, m, h = built({ openAt = "cursor" })
    m.__click(h, "Toggle")
    local _, rel = h:GetPoint(1)
    assertEqual(rel, "$cursor")
    m.__click(h, "Toggle")
    assertTrue(NS.DialSecure.Load(h, {}, {}))
    m.__click(h, "Toggle")
    assertFalse(h:IsShown())
end)

test("dial secure: [review 6] Open from the insecure side takes no key; the key still closes it; out of combat only", function()
    local NS, m, h, frames, rings = built({ openRing = 2 })
    assertTrue(NS.DialSecure.Open(h))
    assertTrue(h:IsShown())
    assertEqual(shown(frames), 2, "on the ring Load named (qc-openRing)")
    -- red under: drop the `if not display` guard from the show snippet
    assertNil(next(m.restrictedBindings), "Escape, 1-8 and the wheel stay the game's (the settings window may be open)")
    m.__click(rings[2].wedges[1].button)
    assertEqual(#m.sentMacros, 1, "a wedge still works")
    assertFalse(h:IsShown())
    assertTrue(NS.DialSecure.Open(h))
    m.__click(h, "Toggle")
    assertFalse(h:IsShown(), "the key closes it")
    m.__click(h, "Toggle")
    assertTrue(m.restrictedBindings.ESCAPE ~= nil, "opened by the key, it takes them again")
    m.__click(h, "Toggle")
    assertTrue(NS.DialSecure.Open(h))
    combat(m, true)
    assertFalse(NS.DialSecure.Close(h))
    assertTrue(h:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("dial secure: [final 1] a middle or side click on a callout wedge sends nothing and closes; on the hub it closes", function()
    local NS, m, h, frames, rings = built()
    for _, b in ipairs({ "MiddleButton", "Button4", "Button5" }) do
        m.__click(h, "Toggle")
        -- red under: close only on RightButton in WEDGE_PRE
        m.__click(rings[1].wedges[2].button, b)
        assertFalse(h:IsShown(), b)
        assertEqual(#m.sentMacros, 0, b)
    end
    assertEqual(NS.SendEngine.EchoState().pending, 0)
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button, "MiddleButton")
    assertFalse(h:IsShown(), "a ring wedge too")
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button)
    assertEqual(shown(frames), 2)
    -- red under: let any button but Right be the hub in ONCLICK
    m.__click(h, "MiddleButton")
    assertFalse(h:IsShown(), "a middle click on the hub closes, never up a ring")
end)

test("dial secure: [final 12] the down edge alone does nothing: no send, no ring switch, the dial stays open", function()
    local _, m, h, frames, rings = built()
    m.__click(h, "Toggle")
    -- red under: drop `if down then return false end` from WEDGE_PRE
    rings[1].wedges[2].button:__fire("OnClick", "LeftButton", true)
    assertTrue(h:IsShown())
    assertEqual(#m.sentMacros, 0)
    rings[1].wedges[1].button:__fire("OnClick", "LeftButton", true)
    assertEqual(shown(frames), 1, "a ring wedge switches on the up edge")
end)

test("dial secure: [final 13] a page turn releases the number keys the new page has no wedge for", function()
    local _, m, h = built({ openRing = 2 })
    m.__click(h, "Toggle")
    m.__pressKey("MOUSEWHEELDOWN")
    -- red under: drop the `self:ClearBindings()` before the show snippet's rebinding
    assertFalse(m.__pressKey("2"), "ring 3 has one wedge")
    assertEqual(#m.sentMacros, 0)
end)

test("dial secure: [final 2] opening one dial closes another that is open; closing it leaves no key bound", function()
    local NS, m, h = built()
    local DS, SE = NS.DialSecure, NS.SendEngine
    local h2 = DS.NewHeader(8)
    local f = DS.NewRing(h2)
    local b = DS.NewWedge(h2, f)
    SE.Arm(b, "/p other", { calloutId = "c-o", surfaceId = "d8", chatType = "PARTY", name = "o" })
    assertTrue(DS.Load(h2, { { frame = f, parent = 0, prev = 0, next = 0, wedges = { { button = b, target = 0 } } } }, {}))
    assertTrue(DS.Link({ h, h2 }))
    m.__click(h, "Toggle")
    m.__click(h2, "Toggle")
    -- red under: drop the sibling close from the open snippet
    assertFalse(h:IsShown(), "the first dial closed")
    assertTrue(h2:IsShown())
    m.__click(h2, "Toggle")
    assertNil(next(m.restrictedBindings), "no key left to a closed dial")
    m.__click(h, "Toggle")
    assertTrue(h:IsShown())
    assertTrue(DS.Open(h2))
    assertFalse(h:IsShown(), "an insecure open closes it too")
end)

test("dial secure: [firewall] no snippet writes an attribute; the ring on screen lives in the header's environment", function()
    local NS = T.newAddon()
    for name, body in pairs(NS.DialSecure.SNIPPETS) do
        assertTrue(not body:find("SetAttribute", 1, true), name)
    end
end)

-- One ring of `size` places (place 1 at W) with a catcher over its disc and a callout wedge on each of
-- `places`, loaded by hand as modules/Dial.lua loads it.
local function caught(size, places)
    local NS, m = T.enableAddon()
    local DS, SE, DL = NS.DialSecure, NS.SendEngine, NS.DialLayout
    local h = DS.NewHeader(8)
    local frame = DS.NewRing(h)
    frame:SetPoint("CENTER", h, "CENTER", 0, 0)
    local disc = DL.Geometry(100).disc
    local catcher = DS.NewCatcher(h, frame)
    catcher:SetSize(disc, disc)
    catcher:SetPoint("CENTER", frame, "CENTER", 0, 0)
    local wedges = {}
    for i, place in ipairs(places) do
        local b = DS.NewWedge(h, frame)
        SE.Arm(b, "/p " .. place, { calloutId = "c" .. i, surfaceId = "d9", chatType = "PARTY", name = "w" .. place })
        wedges[i] = { button = b, target = 0, place = place }
    end
    assertTrue(DS.Load(h, { { frame = frame, parent = 0, prev = 0, next = 0, wedges = wedges, catcher = catcher,
        shape = { size = size, start = DL.START, hub = DL.HUB, disc = disc } } }, {}))
    return NS, m, h, catcher, disc
end

test("dial secure: [polish] catcher and SliceAt agree", function()
    for _, case in ipairs({ { 4, { 1, 3 } }, { 8, { 1, 2, 3 } } }) do
        local size, places = case[1], case[2]
        local NS, m, h, catcher, disc = caught(size, places)
        local DL = NS.DialLayout
        local used = {}
        for _, p in ipairs(places) do used[p] = true end
        local hits = 0
        for k = 0, 71 do
            local a = math.rad((k + 0.5) * 5)   -- off every slice edge
            for _, dist in ipairs({ DL.HUB / 2 + 1, (DL.HUB / 2 + disc / 2) / 2, disc / 2 - 1 }) do
                m.cursor.x, m.cursor.y = dist * math.sin(a), dist * math.cos(a)
                local got = m.__runSnippet(h, "self, button, down, owner", NS.DialSecure.SNIPPETS.catcher, catcher,
                    "LeftButton", false, h)
                local j = DL.SliceAt(a, dist, size, DL.START, DL.HUB, disc)
                local want = (j and used[j]) and ("w" .. j) or false
                -- red under: count the catcher's places from N (drop qc-start) in CATCHER_PRE
                assertEqual(got, want, ("%d slices, bearing %s, %s px"):format(size, (k + 0.5) * 5, dist))
                if want then hits = hits + 1 end
            end
        end
        assertTrue(hits > 0, size .. ": some points land on a used slice")
        assertEqual(catcher:GetAttribute("type-w" .. places[1]), "click")
        assertTrue(catcher:GetAttribute("clickbutton-w" .. places[1]) ~= nil, "a used place forwards to its wedge")
        if size == 4 then assertNil(catcher:GetAttribute("type-w2"), "an empty place has no type") end
    end
end)

test("dial secure: [polish] an outside click closes a key-opened dial, in combat", function()
    local NS, m, h, _, _, screen = built({ screen = true })
    assertTrue(screen ~= nil and screen.__parent == h, "the screen catcher is the header's child")
    assertFalse(screen:IsShown(), "hidden until the dial opens")
    combat(m, true)
    for _, b in ipairs({ "LeftButton", "RightButton" }) do
        m.__click(h, "Toggle")
        -- red under: drop the screen's Show from the show snippet
        assertTrue(screen:IsShown(), b .. ": open from its key, the screen catcher is up")
        m.__click(screen, b)
        -- red under: drop `owner:RunAttribute("qc-close")` from the screen snippet
        assertFalse(h:IsShown(), b .. ": an outside click closes the dial")
        assertFalse(screen:IsShown(), b)
    end
    assertEqual(#m.sentMacros, 0, "and sends nothing")
    assertEqual(NS.SendEngine.EchoState().pending, 0)
    assertEqual(#m.blocked, 0)
end)

test("dial secure: [polish] display open shows no screen catcher", function()
    local NS, m, h, _, _, screen = built({ screen = true })
    assertTrue(NS.DialSecure.Open(h))
    assertTrue(h:IsShown())
    -- red under: show the screen in the show snippet whether or not `display` is set
    assertFalse(screen:IsShown(), "an insecure open (the settings window may be open) leaves the screen clear")
    m.__click(h, "Toggle")
    m.__click(h, "Toggle")
    assertTrue(screen:IsShown(), "opened by the key, the screen catcher is up")
    m.__click(h, "Toggle")
    assertTrue(NS.DialSecure.Open(h))
    assertFalse(screen:IsShown(), "an insecure open after a key open hides it again")
end)

test("dial secure: [polish] closing hides the screen catcher", function()
    local _, m, h, _, rings, screen = built({ screen = true })
    m.__click(h, "Toggle")
    m.__click(h, "Toggle")
    -- red under: drop the screen's Hide from the close snippet
    assertFalse(screen:IsShown(), "the key closes it")
    m.__click(h, "Toggle")
    assertTrue(m.__pressKey("ESCAPE"))
    assertFalse(screen:IsShown(), "Escape closes it")
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[2].button)
    assertEqual(#m.sentMacros, 1)
    assertFalse(screen:IsShown(), "a send closes it")
    m.__click(h, "Toggle")
    screen:__fire("OnClick", "LeftButton", true)
    assertTrue(h:IsShown(), "the down edge alone does nothing")
end)
