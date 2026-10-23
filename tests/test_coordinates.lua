-- tests/test_coordinates.lua — the {coordinates} token (QF-03, owner 2026-10-23): a live button bakes
-- your map position, re-bakes it at the press out of combat (SendEngine's PreClick hook) and once at the
-- combat edge, never writes in combat, drops it where the map does not show you, and a preview echo
-- fills it at the click (or prints <coordinates> for a previewed place that is not where you are).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function combat(m, on)
    m.__setCombat(false)
    if on then
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

-- The open world at 45.2, 61.8, with a user group on pad p1 (an empty When: it shows) holding a
-- rare-spotted callout and a plain one.
local function live()
    local NS, m = T.enableAddon()
    m.playerMap, m.playerPos = 2393, { 0.452, 0.618 }
    NS.Situation.ReadInputs = function() return { inGroup = false } end
    NS.Situation.RefreshNow("test")
    local Lib = NS.Library
    local rare = Lib.CreateCallout({ name = "Rare", text = "{target} @ {coordinates}", channel = "say" })
    local hello = Lib.CreateCallout({ name = "Hi", text = "Hello", channel = "say" })
    local gid = Lib.CreateGroup({ name = "Where", callouts = { rare, hello } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    return NS, m, rare, hello, gid
end

local function button(NS, cid) return NS.Pad.ButtonsFor("p1", cid)[1] end

-- Counts the button's macrotext writes from here on.
local function countWrites(b)
    local n, inner = { macrotext = 0 }, b.SetAttribute
    b.SetAttribute = function(self, key, ...)
        if key == "macrotext" then n.macrotext = n.macrotext + 1 end
        return inner(self, key, ...)
    end
    return n
end

test("coordinates: a live button bakes your position, and only a button that uses it re-bakes", function()
    local NS, _, rare, hello = live()
    local b = button(NS, rare)
    -- red under: no `coordinates` in Surfaces.BakeContext for the live snapshot
    assertEqual(b:GetAttribute("macrotext"), "/s %t @ 45.2, 61.8")
    assertEqual(type(b.qcMeta.rebake), "function")
    -- red under: every armed button carrying a rebake
    assertTrue(button(NS, hello).qcMeta.rebake == nil, "no token: no re-bake")
end)

test("coordinates: a press after you moved re-arms through PreClick and sends where you are now", function()
    local NS, m, rare = live()
    local b = button(NS, rare)
    m.playerPos = { 0.5, 0.25 }
    m.__click(b)
    -- red under: no PreClick re-bake in SendEngine (the line baked with the plan is sent)
    assertEqual(b:GetAttribute("macrotext"), "/s %t @ 50.0, 25.0")
    assertEqual(m.sentMacros[#m.sentMacros].text, "/s %t @ 50.0, 25.0")
    local writes = countWrites(b)
    m.__click(b)
    -- red under: re-arming on every press whether or not the line changed
    assertEqual(writes.macrotext, 0, "an unchanged position writes nothing")
    assertEqual(#m.blocked, 0)
end)

test("coordinates: in combat a press writes nothing and sends the line it holds", function()
    local NS, m, rare = live()
    local b = button(NS, rare)
    m.__setCombat(true)
    m.playerPos = { 0.1, 0.2 }
    local writes = countWrites(b)
    m.__click(b)
    -- red under: the PreClick hook not returning at once in combat (the mock records a refusal)
    assertEqual(#m.blocked, 0)
    assertEqual(writes.macrotext, 0)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/s %t @ 45.2, 61.8")
    m.__setCombat(false)
end)

test("coordinates: the combat edge re-arms each re-baking button once, so a press in combat sends the pull's place", function()
    local NS, m, rare, hello = live()
    local b, h = button(NS, rare), button(NS, hello)
    m.playerPos = { 0.3, 0.7 }
    local writes, other = countWrites(b), countWrites(h)
    combat(m, true)
    -- red under: no SE.RefreshRebakes at the RESTRICTION_CHANGED edge into combat
    assertEqual(b:GetAttribute("macrotext"), "/s %t @ 30.0, 70.0")
    assertEqual(writes.macrotext, 1, "once")
    assertEqual(other.macrotext, 0, "a button without the token is not touched")
    assertEqual(#m.blocked, 0)
    m.__click(b)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/s %t @ 30.0, 70.0")
    assertEqual(#m.blocked, 0)
    combat(m, false)
end)

test("coordinates: where the map does not show you, the token is dropped as any missing one", function()
    local NS, m, rare = live()
    m.playerMap = nil
    local b = button(NS, rare)
    m.__click(b)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/s %t @")
end)

test("coordinates: a Current preview's echo fills the position at the click", function()
    local NS, m, rare = live()
    assertTrue(NS.Preview.SetPreviewAs("current"))
    local b = button(NS, rare)
    assertTrue(b:GetAttribute("macrotext") == nil, "disarmed")
    -- red under: SlotEcho keeping ctx.coordinates from BakeContext (the plan-time position is baked in)
    assertEqual(b.qcMeta.echo, "/s %t @ {coordinates}")
    m.playerPos = { 0.5, 0.25 }
    m.prints = {}
    m.__click(b)
    assertEqual(m.prints[1], NS.PREFIX .. " /s <target> @ 50.0, 25.0")
    m.playerMap = nil
    m.prints = {}
    m.__click(b)
    assertEqual(m.prints[1], NS.PREFIX .. " /s <target> @ <coordinates>", "no position at the click")
end)

test("coordinates: an edit preview's echo fills the position at the click", function()
    local NS, m, rare, _, gid = live()
    assertTrue(NS.Preview.SetEditPreview(gid))
    local b = button(NS, rare)
    assertEqual(b.qcMeta.echo, "/s %t @ {coordinates}")
    m.playerPos = { 0.125, 0.875 }
    m.prints = {}
    m.__click(b)
    assertEqual(m.prints[1], NS.PREFIX .. " /s <target> @ 12.5, 87.5")
end)

test("coordinates: a previewed place that is not where you are prints <coordinates>", function()
    local NS, m, rare = live()
    assertTrue(NS.Preview.SetPreviewAs("mplus"))
    local b = button(NS, rare)
    m.prints = {}
    m.__click(b)
    -- red under: mockBaked answering the literal (or the live position) for a synthetic preset
    assertEqual(m.prints[1], NS.PREFIX .. " /s <target> @ <coordinates>")
end)
