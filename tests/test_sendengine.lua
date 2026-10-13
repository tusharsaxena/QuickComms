-- tests/test_sendengine.lua — modules/SendEngine.lua, the only secure writer (spec §9): send
-- buttons, arm and disarm, the combat-end queue, the held stand-down, and the firewall that keeps
-- every secure call in this one file.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function read(rel)
    local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("%-%-[^\r\n]*", ""))   -- comments may name a call; only code is checked
end

-- The two combat edges as the client delivers them: PLAYER_REGEN_DISABLED fires while secure
-- writes are still allowed, then lockdown begins; lockdown ends before PLAYER_REGEN_ENABLED fires.
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

test("sendengine: a send button is a named secure button registered for both edges", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    assertEqual(b.__template, "SecureActionButtonTemplate")
    assertTrue(b:GetName():match("^QuickCommsSend%d+$") ~= nil, b:GetName())
    assertEqual(table.concat(b.__clicks, ","), "AnyUp,AnyDown")
    assertEqual(NS.SendEngine.ButtonCount(), 1)
end)

test("sendengine: Arm sends exactly the line; Disarm clears both attributes and sends nothing", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    assertTrue(NS.SendEngine.Arm(b, "/p Pulling next pack", { calloutId = "c1" }))
    assertEqual(b:GetAttribute("type"), "macro")
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, "/p Pulling next pack")
    assertEqual(#NS.SendEngine.ArmedButtons(), 1)
    assertTrue(NS.SendEngine.Disarm(b))
    assertNil(b:GetAttribute("type"))
    assertNil(b:GetAttribute("macrotext"))
    assertTrue(b:IsEnabled(), "never :Disable()")
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
end)

test("sendengine: in combat, building, arming and disarming are declined, so nothing is blocked", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Arm(b, "/p a", {})
    combat(m, true)
    assertNil(NS.SendEngine.NewButton(m.UIParent))
    assertFalse(NS.SendEngine.Arm(b, "/p b", {}))
    assertFalse(NS.SendEngine.Disarm(b))
    assertEqual(b:GetAttribute("macrotext"), "/p a", "frozen in combat")
    assertEqual(#m.blocked, 0)
end)

test("sendengine: RunOrQueue runs now out of combat", function()
    local NS = T.enableAddon()
    local ran = 0
    assertTrue(NS.SendEngine.RunOrQueue("k", function() ran = ran + 1 end))
    assertEqual(ran, 1)
    assertEqual(#NS.SendEngine.Snapshot(), 0)
end)

test("sendengine: in combat the queue keeps the last write per key and drains once at combat end", function()
    local NS, m = T.enableAddon()
    local ran, drained = {}, {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.COMBAT_QUEUE_DRAINED, function(_, n) drained[#drained + 1] = n end)
    combat(m, true)
    assertFalse(NS.SendEngine.RunOrQueue("k", function() ran[#ran + 1] = "first" end))
    NS.SendEngine.RunOrQueue("k", function() ran[#ran + 1] = "second" end)
    assertEqual(table.concat(NS.SendEngine.Snapshot(), ","), "k")
    assertEqual(#ran, 0)
    combat(m, false)
    -- red under: drop the RESTRICTION_CHANGED receiver in modules/SendEngine.lua
    assertEqual(table.concat(ran, ","), "second")
    assertEqual(table.concat(drained, ","), "1")
    assertEqual(#NS.SendEngine.Snapshot(), 0)
end)

test("sendengine: Drop empties the queue and nothing runs at combat end", function()
    local NS, m = T.enableAddon()
    local ran = 0
    combat(m, true)
    NS.SendEngine.RunOrQueue("k", function() ran = ran + 1 end)
    assertEqual(NS.SendEngine.Drop("test"), 1)
    combat(m, false)
    assertEqual(ran, 0)
end)

test("sendengine: a failing queued entry is reported and the others still run", function()
    local NS, m = T.enableAddon()
    local ran = 0
    combat(m, true)
    NS.SendEngine.RunOrQueue("bad", function() error("boom") end)
    NS.SendEngine.RunOrQueue("good", function() ran = ran + 1 end)
    m.prints = {}
    combat(m, false)
    assertEqual(ran, 1)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("bad", 1, true) ~= nil, m.prints[1])
end)

test("sendengine: Teardown in combat holds one PLAYER_REGEN_ENABLED and releases it when it fires", function()
    local NS, m = T.enableAddon()
    local function held()
        local n = 0
        for _, r in ipairs(m.__registrations()) do
            if r.event == "PLAYER_REGEN_ENABLED" and r.target ~= NS.addon then n = n + 1 end
        end
        return n
    end
    combat(m, true)
    local done = 0
    assertFalse(NS.SendEngine.Teardown(function() done = done + 1 end))
    assertEqual(held(), 1)
    combat(m, false)
    assertEqual(done, 1)
    assertEqual(held(), 0, "released the moment it fired")
end)

test("sendengine: CancelTeardown releases the held registration without running it", function()
    local NS, m = T.enableAddon()
    combat(m, true)
    local done = 0
    NS.SendEngine.Teardown(function() done = done + 1 end)
    NS.SendEngine.CancelTeardown()
    combat(m, false)
    assertEqual(done, 0)
end)

test("sendengine: the visibility driver is set out of combat and declined in it", function()
    local NS, m = T.enableAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    assertTrue(NS.SendEngine.SetVisibility(root, "hide"))
    assertFalse(root:IsShown())
    assertTrue(NS.SendEngine.SetVisibility(root, "show"))
    assertTrue(root:IsShown())
    combat(m, true)
    assertFalse(NS.SendEngine.SetVisibility(root, "hide"))
    assertFalse(NS.SendEngine.ClearVisibility(root))
    assertEqual(#m.blocked, 0)
    combat(m, false)
    assertTrue(NS.SendEngine.ClearVisibility(root))
    assertFalse(root:IsShown())
    assertNil(m.stateDrivers[root].visibility)
end)

test("sendengine: [firewall] no other shipped file makes a secure call (spec §9)", function()
    local FORBIDDEN = { "SetAttribute%(", "SetOverrideBinding", "ClearOverrideBindings", "RegisterStateDriver%(",
        "UnregisterStateDriver%(", "SecureActionButtonTemplate", "SecureHandler" }
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "modules/SendEngine.lua" then
            local src = read(rel)
            for _, pat in ipairs(FORBIDDEN) do
                assertTrue(not src:find(pat), rel .. " makes a secure call: " .. pat)
            end
        end
    end
    assertTrue(read("modules/SendEngine.lua"):find("SetAttribute%(") ~= nil, "the firewall file is the writer")
end)

test("sendengine: [D12] nothing calls SendChatMessage: the secure button is the one send path", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        assertTrue(not read(rel):find("SendChatMessage", 1, true), rel)
    end
end)
