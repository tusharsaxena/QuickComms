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

test("sendengine: [audit QC-06] the held stand-down registers through NS.SafeRegisterEvent, into NS.rejectedEvents", function()
    local NS, m = T.enableAddon()
    local real, calls = NS.SafeRegisterEvent, {}
    NS.SafeRegisterEvent = function(target, event, handler, rejected)
        calls[#calls + 1] = { event = event, rejected = rejected }
        return real(target, event, handler, rejected)
    end
    combat(m, true)
    local done = 0
    NS.SendEngine.Teardown(function() done = done + 1 end)
    NS.SafeRegisterEvent = real
    -- red under: register PLAYER_REGEN_ENABLED with a direct pending:RegisterEvent in SE.Teardown
    assertEqual(#calls, 1)
    assertEqual(calls[1].event, "PLAYER_REGEN_ENABLED")
    assertTrue(calls[1].rejected == NS.rejectedEvents, "a refusal is recorded where diagnostics read it")
    combat(m, false)
    assertEqual(done, 1)
end)

test("sendengine: [audit QC-06] a refused hold raises nothing and keeps the teardown held", function()
    local NS, m = T.enableAddon()
    local real = NS.SafeRegisterEvent
    NS.SafeRegisterEvent = function() return false end
    combat(m, true)
    local fn = function() end
    assertFalse(NS.SendEngine.Teardown(fn))
    NS.SafeRegisterEvent = real
    assertTrue(NS.State.pendingTeardown == fn, "still held, for the next stand-up to cancel")
    NS.SendEngine.CancelTeardown()
    combat(m, false)
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

-- The firewall's patterns: any Secure* template or handler by name, SetAttribute however it is
-- called, and every binding or state-driver write.
local FORBIDDEN = { "SetAttribute%s*%(", "[\"']SetAttribute[\"']", "SetOverrideBinding", "ClearOverrideBindings",
    "RegisterStateDriver%s*%(", "UnregisterStateDriver%s*%(", "Secure%w*Template", "SecureHandler",
    -- phase 4: a header's frame refs, wraps and snippet runs (the restricted side's GetFrameRef,
    -- RunAttribute, SetBindingClick and ClearBindings are not writes and stay allowed)
    ":SetFrameRef%s*%(", ":WrapScript%s*%(", ":Execute%s*%(" }

test("sendengine: [firewall] no other shipped file makes a secure call (spec §9)", function()
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

test("sendengine: [fix wave] the firewall's patterns catch every Secure* template and SetAttribute spelling", function()
    -- Each sample is a spelling the earlier list let through.
    local function caught(src)
        for _, pat in ipairs(FORBIDDEN) do
            if src:find(pat) then return true end
        end
        return false
    end
    for _, src in ipairs({ 'CreateFrame("Button", nil, p, "SecureUnitButtonTemplate")',
        'CreateFrame("Frame", nil, p, "SecureFrameTemplate")', "b.SetAttribute (b, 'type', 'macro')",
        'b["SetAttribute"](b, "type", "macro")', "RegisterStateDriver (f, 'visibility', 'show')",
        -- phase 4; red under: drop the three header patterns from FORBIDDEN
        'h:SetFrameRef("ring1", r)', "h:WrapScript (b, 'OnClick', pre, post)", 'h:Execute([[ x = 1 ]])' }) do
        assertTrue(caught(src), src)
    end
    assertFalse(caught("b:GetAttribute('type')"))
    -- What Dial_Secure's snippets do inside the restricted environment is not a write.
    for _, src in ipairs({ 'self:GetFrameRef("ring1"):Show()', 'owner:RunAttribute("qc-close")',
        'self:SetBindingClick(true, "ESCAPE", self, "Close")', "self:ClearBindings()", "SE.SetFrameRef(h, n, f)" }) do
        assertFalse(caught(src), src)
    end
end)

test("sendengine: [D12] nothing calls SendChatMessage: the secure button is the one send path", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        assertTrue(not read(rel):find("SendChatMessage", 1, true), rel)
    end
end)

-- ── the click, the guard and the echo (spec §9.2, §9.3) ─────────────────────────────────────

local META = { calloutId = "c1", surfaceId = "p1", chatType = "PARTY", name = "Pull" }

local function armed(NS, m, meta)
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Arm(b, "/p Pulling", meta or META)
    return b
end

local function results(NS)
    local out = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function(_, cid, sid, what) out[#out + 1] = cid .. "@" .. sid .. "=" .. what end)
    return out
end

-- A CHAT_MSG_* as the client sends it: text, sender, then nine fields, then the sender's GUID.
local function echo(m, event, sender, guid)
    m.__fire(event or "CHAT_MSG_PARTY", "never read", sender or "Testchar-Testrealm", "", "", "", "", 0, 0, "", 0, 1,
        guid or m.playerGUID)
end

test("send: one press is one send and one pending echo, though the hook hears both edges", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    m.__now = 100
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    -- red under: drop the IsActingEdge check from SE.OnClick
    assertEqual(NS.SendEngine.EchoState().pending, 1)
    m.__now = 100.6
    echo(m)
    assertEqual(table.concat(out, ","), "c1@p1=sent")
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("send: [review 3] a double press in a boss: guarded, then dropped, with one note, never canceled", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    m.__now = 100
    m.__click(b)
    m.__now = 100.3
    m.__click(b)
    assertEqual(#m.sentMacros, 2, "soft: the guard never cancels a click")
    assertEqual(table.concat(out, ","), "c1@p1=guarded")
    m.__now = 100.8
    echo(m)                               -- the game delivered only the first
    m.prints = {}
    m.__now = 102.5
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=guarded,c1@p1=sent,c1@p1=dropped")
    assertEqual(#m.prints, 1, "exactly one note")
    assertTrue(m.prints[1]:find("Pull", 1, true) ~= nil, m.prints[1])
end)

test("send: the drop note follows behavior.dropNotes", function()
    local NS, m = T.enableAddon()
    NS.SchemaRuntime.Set("behavior.dropNotes", false)
    local out = results(NS)
    m.__now = 100
    m.__click(armed(NS, m))
    m.prints = {}
    m.__now = 103
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=dropped")
    assertEqual(#m.prints, 0)
end)

test("send: presses further apart than the guard are never guarded", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    m.__now = 100
    m.__click(b)
    m.__now = 101.2
    m.__click(b)
    assertEqual(#out, 0)
end)

test("send: an unreadable sender counts as our echo and is never a drop", function()
    local NS, m = T.enableAddon()
    m.issecretvalue = T.isSecret
    local out = results(NS)
    m.__now = 100
    m.__click(armed(NS, m))
    echo(m, "CHAT_MSG_PARTY_LEADER", T.secret("Someone"), T.secret("Player-1-2"))
    m.__now = 103
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=sent")
    assertEqual(NS.SendEngine.EchoState().unknown, 1)
end)

test("send: another player's message on the channel is not our echo", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    m.__now = 100
    m.__click(armed(NS, m))
    echo(m, "CHAT_MSG_PARTY", "Other-Testrealm", "Player-1-99999999")
    m.__now = 103
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=dropped")
end)

-- A CHAT_MSG_CHANNEL: the channel index is the 8th payload field (QF-04).
local GENERAL_META = { calloutId = "c1", surfaceId = "p1", chatType = "CHANNEL", name = "Thanks" }
local function channelEcho(m, index, sender, guid)
    m.__fire("CHAT_MSG_CHANNEL", "never read", sender or "Testchar-Testrealm", "", "2. Trade", "", "", 2, index,
        "Trade", 0, 1, guid or m.playerGUID)
end

test("send: [QF-04] the player's own line on channel 1 is the General echo; on channel 2 it is not", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Arm(b, "/1 Thanks", GENERAL_META)
    m.__now = 100
    m.__click(b)
    -- red under: matching CHAT_MSG_CHANNEL by type and sender alone
    channelEcho(m, 2)
    assertEqual(NS.SendEngine.EchoState().pending, 1, "a /2 line is not the echo")
    channelEcho(m, 1, "Other-Testrealm", "Player-1-99999999")
    assertEqual(NS.SendEngine.EchoState().pending, 1, "another player's General line is not the echo")
    channelEcho(m, 1)
    assertEqual(table.concat(out, ","), "c1@p1=sent")
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("send: [QF-04] an unreadable channel index falls to the sender rule", function()
    local NS, m = T.enableAddon()
    m.issecretvalue = T.isSecret
    local out = results(NS)
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Arm(b, "/1 Thanks", GENERAL_META)
    m.__now = 100
    m.__click(b)
    channelEcho(m, T.secret(1))
    assertEqual(table.concat(out, ","), "c1@p1=sent")
end)

test("send: a disarmed button reports nothing and tracks nothing", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    NS.SendEngine.Disarm(b)
    m.__click(b)
    assertEqual(#out, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("send: a solo self-fallback prints locally and sends nothing", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Disarm(b, { calloutId = "c1", surfaceId = "p1", selfText = "Lust on this pack" })
    m.prints = {}
    m.__click(b)
    assertEqual(#m.sentMacros, 0)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Lust on this pack", 1, true) ~= nil)
end)

test("send: onPress hears the verdict and the window", function()
    local NS, m = T.enableAddon()
    local heard = {}
    local b = NS.SendEngine.NewButton(m.UIParent, function(_, verdict, window) heard[#heard + 1] = verdict .. ":" .. window end)
    NS.SendEngine.Arm(b, "/p a", META)
    m.__now = 100
    m.__click(b)
    m.__now = 100.2
    m.__click(b)
    assertEqual(table.concat(heard, ","), "ok:1,guarded:1")
end)

test("send: every echo event is a declared feature event", function()
    local NS = T.newAddon()
    local declared = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do declared[row[1]] = row[2] end
    for _, event in ipairs(NS.SendGuard.ECHO_EVENTS) do assertEqual(declared[event], "OnSendEcho", event) end
end)

test("send: the stand-down cancels the echo timers and forgets the presses", function()
    local NS, m = T.enableAddon()
    m.__click(armed(NS, m))
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(#m.__timers(), 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

-- ── the Comms Dial's secure frames and the override bindings (phase 4) ──────────────────────

test("sendengine: [phase 4] a dial header is a named click handler for the down edge, hidden; none in combat", function()
    local NS, m = T.enableAddon()
    local h = NS.SendEngine.NewDialHeader("QuickCommsDialT")
    assertEqual(h.__template, "SecureHandlerClickTemplate")
    assertEqual(h:GetName(), "QuickCommsDialT")
    assertEqual(table.concat(h.__clicks, ","), "AnyDown")
    assertFalse(h:IsShown())
    local ring = NS.SendEngine.NewDialRing(h)
    assertEqual(ring.__template, "SecureFrameTemplate")
    assertFalse(ring:IsShown())
    combat(m, true)
    assertNil(NS.SendEngine.NewDialHeader("QuickCommsDialU"))
    assertNil(NS.SendEngine.NewDialRing(h))
    assertEqual(#m.blocked, 0)
end)

test("sendengine: [phase 4] a wedge is wrapped before it is hooked, acts on the up edge, and only a left click is a press", function()
    local NS, m = T.enableAddon()
    local h = NS.SendEngine.NewDialHeader("QuickCommsDialT")
    local pre = [[ if down or button == "RightButton" then return false end return button ]]
    -- red under: hook before wrapping in SE.NewButton (the mock's wrap raises: the client discards the hook)
    local b = NS.SendEngine.NewButton(h, nil, { header = h, pre = pre })
    assertEqual(b:GetAttribute("useOnKeyDown"), false)
    NS.SendEngine.Arm(b, "/p Pulling", META)
    m.__click(b, "RightButton")
    assertEqual(#m.sentMacros, 0)
    -- red under: drop the qcLeftOnly check from SE.OnClick (the hook would track a press nothing sent)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(NS.SendEngine.EchoState().pending, 1)
end)

test("sendengine: [phase 4] attributes, frame refs and snippets are written out of combat only, never blocked", function()
    local NS, m = T.enableAddon()
    local SE = NS.SendEngine
    local h = SE.NewDialHeader("QuickCommsDialT")
    local ring = SE.NewDialRing(h)
    assertTrue(SE.SetAttributes(h, { ["qc-open"] = [[ opened = true ]], ["qc-rings"] = 1 }))
    assertTrue(SE.SetFrameRef(h, "ring1", ring))
    assertTrue(SE.RunSnippet(h, "qc-open"))
    assertTrue(h.__env.opened)
    combat(m, true)
    assertFalse(SE.SetAttributes(h, { ["qc-rings"] = 2 }))
    assertFalse(SE.SetFrameRef(h, "ring2", ring))
    assertFalse(SE.RunSnippet(h, "qc-open"))
    assertEqual(h:GetAttribute("qc-rings"), 1)
    assertEqual(#m.blocked, 0)
end)

test("sendengine: [keys] no override binding is written: a dial's key is WoW's own binding (modules/Dial.lua)", function()
    local NS, m = T.enableAddon()
    -- red under: a SendEngine.BindKeys left behind (two key systems, one of them invisible in Options)
    assertNil(NS.SendEngine.BindKeys)
    assertNil(NS.SendEngine.ClearKeys)
    assertNil(NS.Dial.BindKey, "set by WoW's menu or the library's Keybindings tab, never by Dial")
    m.SetBinding("G", "CLICK QuickCommsDial1:Toggle")
    NS.Surfaces.Request("test")
    assertNil(next(m.overrideBindings))
end)
