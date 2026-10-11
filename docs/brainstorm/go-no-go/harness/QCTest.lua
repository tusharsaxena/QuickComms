-- QCTest: throwaway go/no-go harness for QuickComms issue #6. Delete after testing.
-- /qct            show or hide the panel
-- /qct ch p|i|raid|rw   set the channel (out of combat)
-- /qct bind KEY   bind KEY to button A (out of combat), /qct unbind to clear
-- /qct status     print lockdown state and the forcing console variables

local CHANNELS = {
    p    = { slash = "/p",    chatType = "PARTY" },
    i    = { slash = "/i",    chatType = "INSTANCE_CHAT" },
    raid = { slash = "/raid", chatType = "RAID" },
    rw   = { slash = "/rw",   chatType = "RAID_WARNING" },
}
local MACRO_NAME = "QCTEST_B"
local ch = "p"

local function say(msg) print("|cffffd100QCTest|r " .. msg) end

local function lockdownText()
    local chat = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    return ("chat lockdown: %s   combat: %s   channel: %s"):format(
        chat and "|cffff4040ON|r" or "|cff40ff40off|r",
        InCombatLockdown() and "|cffff4040yes|r" or "no",
        CHANNELS[ch].slash)
end

-- Panel -------------------------------------------------------------------
local panel = CreateFrame("Frame", "QCTestPanel", UIParent, "BackdropTemplate")
panel:SetSize(260, 190)
panel:SetPoint("CENTER", 0, 200)
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
panel:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
panel:SetBackdropBorderColor(0, 0, 0, 1)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("QuickComms go/no-go (#6)")

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("BOTTOM", 0, 8)

local function makeButton(name, label, y, template)
    local b = CreateFrame("Button", name, panel, template and ("UIPanelButtonTemplate," .. template) or "UIPanelButtonTemplate")
    b:SetSize(230, 26)
    b:SetPoint("TOP", 0, y)
    b:SetText(label)
    return b
end

-- 0: baseline, plain addon Lua. Expected to be blocked during lockdown.
local b0 = makeButton("QCTest0", "0  Baseline (addon Lua)", -30)
b0:SetScript("OnClick", function()
    say(("click 0 at %.2f"):format(GetTime()))
    C_ChatInfo.SendChatMessage("QC test 0 (addon Lua)", CHANNELS[ch].chatType)
end)

-- A: secure button running macro text.
local bA = makeButton("QCTestA", "A  Secure macrotext", -60, "SecureActionButtonTemplate")
bA:RegisterForClicks("AnyUp", "AnyDown")
bA:SetAttribute("type", "macro")

-- B: secure button running a real macro.
local bB = makeButton("QCTestB", "B  Real macro (" .. MACRO_NAME .. ")", -90, "SecureActionButtonTemplate")
bB:RegisterForClicks("AnyUp", "AnyDown")
bB:SetAttribute("type", "macro")

-- T: tokens through the secure path.
local bT = makeButton("QCTestT", "T  Tokens: %t {rt8} {g1}", -120, "SecureActionButtonTemplate")
bT:RegisterForClicks("AnyUp", "AnyDown")
bT:SetAttribute("type", "macro")

for _, b in ipairs({ bA, bB, bT }) do
    local label = b:GetName():sub(-1)
    b:HookScript("OnClick", function(_, _, down)
        if down ~= false then say(("click %s at %.2f"):format(label, GetTime())) end
    end)
end

-- Writes the real macro and the button attributes. Out of combat only.
local function apply()
    if InCombatLockdown() then say("|cffff4040in combat, leave combat first|r") return end
    local slash = CHANNELS[ch].slash
    bA:SetAttribute("macrotext", slash .. " QC test A (secure macrotext)")
    bT:SetAttribute("macrotext", slash .. " QC tokens: target=%t mark={rt8} g1={g1}")

    local body = slash .. " QC test B (real macro)"
    local index = GetMacroIndexByName(MACRO_NAME)
    if index and index > 0 then
        EditMacro(index, MACRO_NAME, "INV_MISC_QUESTIONMARK", body)
    else
        index = CreateMacro(MACRO_NAME, "INV_MISC_QUESTIONMARK", body, true)
    end
    if index and index > 0 then
        bB:SetAttribute("macro", MACRO_NAME)
    else
        say("|cffff4040could not create macro " .. MACRO_NAME .. " (character macro slots full?)|r")
    end
    status:SetText(lockdownText())
end

-- Arrival log: our own messages coming back from the server.
local events = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" }) do
    events:RegisterEvent(e)
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
pcall(events.RegisterEvent, events, "ADDON_RESTRICTION_STATE_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        apply()
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if arg1 == "QCTest" then say(("|cffff4040%s|r %s"):format(event, tostring(arg2))) end
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        say("restriction state changed: " .. lockdownText())
    else
        -- Chat payloads can be secret values in lockdown, so don't touch the text.
        say(("%s arrived at %.2f"):format(event:gsub("CHAT_MSG_", ""), GetTime()))
    end
end)

local elapsed = 0
panel:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed > 0.5 then elapsed = 0 status:SetText(lockdownText()) end
end)

-- Slash command -----------------------------------------------------------
SLASH_QCTEST1 = "/qct"
SlashCmdList.QCTEST = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "ch" and CHANNELS[arg:lower()] then
        ch = arg:lower()
        apply()
        say("channel set to " .. CHANNELS[ch].slash)
    elseif cmd == "bind" and arg ~= "" then
        if InCombatLockdown() then say("leave combat first") return end
        SetOverrideBindingClick(panel, true, arg:upper(), "QCTestA")
        say("bound " .. arg:upper() .. " to button A")
    elseif cmd == "unbind" then
        if InCombatLockdown() then say("leave combat first") return end
        ClearOverrideBindings(panel)
        say("bindings cleared")
    elseif cmd == "status" then
        say(lockdownText())
        -- List every console variable whose name mentions "restriction", so we use the real names.
        local ok, err = pcall(function()
            local found = 0
            local getAll = (C_Console and C_Console.GetAllCommands) or ConsoleGetAllCommands
            if not getAll then
                -- No listing API: probe likely names instead.
                for _, name in ipairs({ "addonChatRestrictionsForced", "addonChallengeModeRestrictionsForced",
                    "addonEncounterRestrictionsForced", "addonPvPMatchRestrictionsForced",
                    "addonCombatRestrictionsForced", "addonMapRestrictionsForced",
                    "secretEncounterRestrictionsForced", "secretChallengeModeRestrictionsForced",
                    "secretCombatRestrictionsForced", "secretPvPMatchRestrictionsForced" }) do
                    local value = GetCVar(name)
                    if value ~= nil then found = found + 1 say(("%s = %s"):format(name, value)) end
                end
                say(found .. " known console variables found (no listing API)")
                return
            end
            for _, c in pairs(getAll()) do
                local name = type(c) == "table" and c.command
                if type(name) == "string" and name:lower():find("restrict") then
                    found = found + 1
                    local okValue, value = pcall(GetCVar, name)
                    say(("%s = %s"):format(name, okValue and tostring(value) or "?"))
                end
            end
            say(found .. " matching console variables")
        end)
        if not ok then say("|cffff4040could not list console variables:|r " .. tostring(err)) end
    elseif cmd == "" then
        if InCombatLockdown() then say("leave combat first") return end
        panel:SetShown(not panel:IsShown())
    else
        say("usage: /qct | /qct ch p|i|raid|rw | /qct bind KEY | /qct unbind | /qct status")
    end
end
