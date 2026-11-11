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
    assertEqual(b.qcMeta.echo[1], "/s %t @ {coordinates}")
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
    assertEqual(b.qcMeta.echo[1], "/s %t @ {coordinates}")
    m.playerPos = { 0.125, 0.875 }
    m.prints = {}
    m.__click(b)
    assertEqual(m.prints[1], NS.PREFIX .. " /s <target> @ 12.5, 87.5")
end)

test("coordinates: a previewed place that is not where you are prints <coordinates>", function()
    local NS, m, rare = live()
    assertTrue(NS.Preview.SetPreviewAs("mplus:2805"))
    local b = button(NS, rare)
    m.prints = {}
    m.__click(b)
    -- red under: mockBaked answering the literal (or the live position) for a synthetic preset
    assertEqual(m.prints[1], NS.PREFIX .. " /s <target> @ <coordinates>")
end)

-- ── The re-bake refreshes the press meta (CA-M2-3, combined actions §3) ─────────────────────────

-- A Say Line that fits beside a ping at 5.2, 6.1 and runs over the macro's budget at 45.2, 61.8:
-- the ping's "/ping [@target,exists] 1" and its newline leave the Line 230 bytes, and
-- "/s " + 218 + " " + "5.2, 6.1" is 230.
local function nearBudget(over)
    local NS, m = T.enableAddon()
    m.playerMap, m.playerPos = 2393, { 0.052, 0.061 }
    NS.Situation.ReadInputs = function() return { inGroup = false } end
    NS.Situation.RefreshNow("test")
    local Lib = NS.Library
    local f = { name = "Here", text = string.rep("a", 218) .. " {coordinates}", channel = "say", ping = "attack" }
    for k, v in pairs(over or {}) do f[k] = v end
    local cid = Lib.CreateCallout(f)
    local gid = Lib.CreateGroup({ name = "Where", callouts = { cid } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    return NS, m, cid
end

local function sendResults(NS)
    local out, t = {}, NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function(_, _, _, what) out[#out + 1] = what end)
    return out
end

test("coordinates: [CA-M2-3] a re-bake that pushes the Line over budget refreshes the press meta", function()
    local NS, m, cid = nearBudget()
    local b = button(NS, cid)
    local line = string.rep("a", 218) .. " 5.2, 6.1"
    assertEqual(b:GetAttribute("macrotext"), "/s " .. line .. "\n/ping [@target,exists] 1")
    assertEqual(#b.qcMeta.actions, 2) assertEqual(b.qcMeta.chatTypes[1], "SAY")
    local out = sendResults(NS)
    m.playerPos = { 0.452, 0.618 }
    m.prints = {}
    m.__click(b)
    -- red under: rebake taking one string (the joined macro of the old meta, or nothing re-armed)
    assertEqual(b:GetAttribute("macrotext"), "/ping [@target,exists] 1", "the ping alone is re-armed")
    local meta = b.qcMeta
    assertEqual(#meta.actions, 1) assertEqual(meta.actions[1].kind, "ping")
    assertEqual(#meta.chatTypes, 0, "no chat action is left to echo")
    assertEqual(#meta.locks, 0)
    assertEqual(#meta.skipped, 1) assertEqual(meta.skipped[1].kind, "line")
    assertEqual(meta.skipped[1].reason, "tooLong")
    assertEqual(NS.SendEngine.EchoState().pending, 0, "the echo tracker waits for no Line")
    assertEqual(out[#out], "sent", "an action-only press: no false dropped")
    local said = false
    for _, p in ipairs(m.prints) do
        if p == NS.PREFIX .. " Here: the line is too long to send with its other actions." then said = true end
    end
    assertTrue(said, "the press says why the Line dropped")
    -- moved back: the Line fits again, and the meta waits for it again
    m.playerPos = { 0.052, 0.061 }
    m.__click(b)
    assertEqual(b:GetAttribute("macrotext"), "/s " .. line .. "\n/ping [@target,exists] 1")
    assertEqual(#b.qcMeta.actions, 2) assertEqual(b.qcMeta.chatTypes[1], "SAY")
    assertEqual(#b.qcMeta.skipped, 0)
end)

test("coordinates: [CA-M2-3] a re-bake where nothing bakes keeps the old macro and meta", function()
    -- a Line alone, 255 bytes at 5.2, 6.1: two more bytes at 45.2, 61.8 and it bakes nothing
    local NS, m, cid = nearBudget({ text = string.rep("a", 243) .. " {coordinates}", ping = false })
    local b = button(NS, cid)
    local before, meta = b:GetAttribute("macrotext"), b.qcMeta
    assertEqual(#before, 255)
    m.playerPos = { 0.452, 0.618 }
    m.__click(b)
    assertEqual(b:GetAttribute("macrotext"), before, "the old macro stays")
    assertTrue(b.qcMeta == meta, "and the old meta")
    assertEqual(#meta.actions, 1) assertEqual(meta.chatTypes[1], "SAY")
end)
