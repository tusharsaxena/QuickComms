-- tests/test_reports.lua — the report verbs through LibKa0s's D:Report (LibKa0s#79, AD-79-QC).
--
-- The owner's ruling of 2026-11-08 on report routing: a REPORT, a multi-line read-out the player asks
-- for to inspect or share, is written to the debug console whether or not logging is on, a hidden
-- console is shown, and chat gets exactly one pointer line. Acknowledgments, short one-line answers,
-- refusals and usage lines stay in chat and write nothing. Here: `/qc why`, `/qc check <id>`,
-- `/qc probe`, `/qc probe ids` and `/qc preview list` are reports; `/qc check` of a gone id,
-- `/qc probe clear`, the probe's combat refusal, `/qc preview off` and a one-line check verdict are not.
-- Without the library the stub prints a report's lines in chat with no pointer.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local POINTER = "lines written to the debug console. Use Copy to share it."

-- Logging off and the console hidden, chat and the console's buffer emptied.
local function fresh(NS, m)
    NS.DebugLog:SetEnabled(false)
    NS.DebugLog:Hide()
    NS.DebugLog:Clear()
    m.prints = {}
end

local function console(NS) return table.concat(NS.DebugLog.buffer, "\n") end

-- The run was a report titled `title`: one chat line, the pointer, counting what the console holds;
-- the console shown, its first line the `/qc <title>` header under `tag`. Returns the console text.
local function assertReport(NS, m, tag, title)
    assertEqual(#m.prints, 1, "exactly one chat line: " .. table.concat(m.prints, " | "))
    local n = m.prints[1]:match(title:gsub("%p", "%%%0") .. ": (%d+) " .. POINTER:gsub("%p", "%%%0"))
    assertTrue(n ~= nil, m.prints[1])
    assertEqual(tonumber(n), #NS.DebugLog.buffer, "the pointer counts the lines written, the header included")
    assertTrue(NS.DebugLog.buffer[1]:find("[" .. tag .. "] /qc " .. title, 1, true) ~= nil, NS.DebugLog.buffer[1])
    assertTrue(NS.DebugLog:IsShown(), "a hidden console is shown")
    assertFalse(NS.DebugLog:IsEnabled(), "a report never turns logging on")
    return console(NS)
end

-- The run answered in chat with one line and wrote nothing to the console.
local function assertChatOnly(NS, m, want)
    assertEqual(#m.prints, 1, table.concat(m.prints, " | "))
    assertTrue(m.prints[1]:find(want, 1, true) ~= nil, m.prints[1])
    assertEqual(#NS.DebugLog.buffer, 0, "nothing written to the console")
    assertFalse(NS.DebugLog:IsShown(), "the console stays hidden")
end

local function mplus(NS)
    NS.Situation.Current = function()
        return { content = "mythicPlus", group = "party", instanceGroup = false, lockdown = { chat = true } }
    end
end

test("reports: [AD-79-QC] /qc why is a report in the console, with one pointer in chat", function()
    local NS, _, m = T.enableAddon()
    fresh(NS, m)
    NS.addon:OnSlashCommand("why")
    -- red under: V.Why printing its lines in chat
    local text = assertReport(NS, m, "Why", "why")
    assertTrue(text:find("Your role: ", 1, true) ~= nil, text)
end)

test("reports: [AD-79-QC] /qc check <id> is a report; a gone id is refused in chat", function()
    local NS, _, m = T.enableAddon()
    mplus(NS)
    local lust = T.seeded(NS, "bi.mplus.lust")
    fresh(NS, m)
    NS.addon:OnSlashCommand("check " .. lust)
    -- red under: V.Check printing its lines in chat
    local text = assertReport(NS, m, "Check", "check " .. lust)
    assertTrue(text:find(lust .. " -> /p Lust on this pack", 1, true) ~= nil, text)
    assertTrue(text:find("channel: party", 1, true) ~= nil, text)
    fresh(NS, m)
    NS.addon:OnSlashCommand("check c999")
    assertChatOnly(NS, m, "No callout with id c999.")
end)

test("reports: [AD-79-QC] a one-line check verdict is a short answer and stays in chat", function()
    local NS, _, m = T.enableAddon()
    mplus(NS)
    local id = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    fresh(NS, m)
    NS.addon:OnSlashCommand("check " .. id)
    -- red under: every check routed to the console, its one line and a pointer
    assertChatOnly(NS, m, "not sent here (startsWithSlash)")
end)

test("reports: [AD-79-QC] /qc probe and /qc probe ids are reports; clear and the combat refusal stay in chat", function()
    local NS, env, m = T.enableAddon()
    env.GetServerTime = function() return 1762790400 end
    fresh(NS, m)
    NS.addon:OnSlashCommand("probe")
    -- red under: V.Probe printing the summary in chat
    local text = assertReport(NS, m, "Probe", "probe")
    assertTrue(text:find("Probe 1 saved for " .. NS.Compat.ClientKey(), 1, true) ~= nil, text)
    fresh(NS, m)
    NS.addon:OnSlashCommand("probe ids")
    text = assertReport(NS, m, "Probe", "probe ids")
    assertTrue(text:find("Ids probe 2 saved for " .. NS.Compat.ClientKey(), 1, true) ~= nil, text)
    fresh(NS, m)
    NS.addon:OnSlashCommand("probe clear")
    assertChatOnly(NS, m, "Probes cleared: 2 removed.")
    fresh(NS, m)
    NS.addon:OnSlashCommand("probe bogus")
    assertChatOnly(NS, m, "/qc probe clear")
    m.inCombat = true
    fresh(NS, m)
    NS.addon:OnSlashCommand("probe")
    assertChatOnly(NS, m, "not available in combat")
    m.inCombat = false
end)

test("reports: [AD-79-QC] /qc preview list is a report; preview off and a bad name stay in chat", function()
    local NS, _, m = T.enableAddon()
    fresh(NS, m)
    NS.addon:OnSlashCommand("preview list")
    -- red under: V.Preview printing the menu in chat
    local text = assertReport(NS, m, "Preview", "preview list")
    assertTrue(text:find("Preview as (now: Off):", 1, true) ~= nil, text)
    assertTrue(text:find("raid:2912", 1, true) ~= nil, text)
    fresh(NS, m)
    NS.addon:OnSlashCommand("preview off")
    assertChatOnly(NS, m, "Preview off.")
    fresh(NS, m)
    NS.addon:OnSlashCommand("preview nowhere")
    assertChatOnly(NS, m, "No situation named nowhere.")
end)

test("reports: [AD-79-QC] a report with logging on lands once and leaves logging on", function()
    local NS, _, m = T.enableAddon()
    fresh(NS, m)
    NS.DebugLog:SetEnabled(true)
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    assertEqual(#m.prints, 1, table.concat(m.prints, " | "))
    assertTrue(m.prints[1]:find("why: %d+ " .. POINTER:gsub("%p", "%%%0")) ~= nil, m.prints[1])
    assertTrue(NS.DebugLog:IsEnabled(), "logging stays on")
end)

test("reports: [AD-79-QC] without LibKa0s a report prints its lines in chat, with no pointer", function()
    local NS, _, m = T.enableAddon({ skip = T.loadAddon.libFiles })
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    -- red under: a stub Report that writes nothing (the read-out lost with the console)
    assertTrue(#m.prints >= 2, table.concat(m.prints, " | "))
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Your role: ", 1, true) ~= nil, text)
    assertTrue(text:find(POINTER, 1, true) == nil, "no pointer: there is no console")
end)
