-- _dev/QCSpike/QCSpike.lua — throwaway in-game checks C1-C9 (spec §19). Not part of the addon.
-- /qcs               show or hide the panel (out of combat)
-- /qcs where         print instance info (confirm battleground instance IDs)
-- /qcs rebake        rewrite button P's macrotext with a counter (C4: works between pulls in a key?)
-- /qcs bind KEY      bind KEY to the spike dial (C7), /qcs unbind to clear
-- /qcs echo on|off   print whether the sender of your own returning messages is readable (C6)

local function say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100QCSpike|r " .. tostring(msg)) end

local panel = CreateFrame("Frame", "QCSpikePanel", UIParent, "BackdropTemplate")
panel:SetSize(240, 330)
panel:SetPoint("CENTER", -300, 0)
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
panel:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
panel:SetBackdropBorderColor(0, 0, 0, 1)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -6)
title:SetText("QC spike: C1-C9")

-- C1, C2, C3, C9: one secure macro button per channel. Each logs its click time.
local CHANNEL_BUTTONS = {
    { "P",    "/p QC spike party" },
    { "I",    "/i QC spike instance" },
    { "RAID", "/raid QC spike raid" },
    { "RW",   "/rw QC spike raid warning" },
    { "S",    "/s QC spike say" },
    { "Y",    "/y QC spike yell" },
    { "W%t",  "/w %t QC spike whisper to target" },
    { "%f",   "/p QC spike focus=%f" },
}
local buttons = {}
for i, def in ipairs(CHANNEL_BUTTONS) do
    local b = CreateFrame("Button", "QCSpikeBtn" .. i, panel, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    b:SetSize(105, 22)
    b:SetPoint("TOPLEFT", 10 + ((i - 1) % 2) * 115, -26 - math.floor((i - 1) / 2) * 26)
    b:SetText(def[1])
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", def[2])
    b:HookScript("OnClick", function(_, _, down)
        if down == false then say(("click %s at %.2f"):format(def[1], GetTime())) end
    end)
    buttons[def[1]] = b
end

-- C5: a guard snippet on its own button. Does GetTime() exist in the restricted environment, and
-- does returning false cancel a send? Press G fast during a boss: at most one send per second.
local header = CreateFrame("Frame", "QCSpikeHeader", UIParent, "SecureHandlerBaseTemplate")
local guard = CreateFrame("Button", "QCSpikeGuard", panel, "UIPanelButtonTemplate,SecureActionButtonTemplate")
guard:SetSize(220, 22)
guard:SetPoint("TOPLEFT", 10, -134)
guard:SetText("G: guarded /p (1 s)")
guard:RegisterForClicks("AnyUp", "AnyDown")
guard:SetAttribute("type", "macro")
guard:SetAttribute("macrotext", "/p QC spike guarded")
SecureHandlerWrapScript(guard, "OnClick", header, [[
    if down then return end
    local now = GetTime()
    local last = owner:GetAttribute("qc-last") or 0
    if now - last < 1.0 then return false end
    owner:SetAttribute("qc-last", now)
]])
guard:HookScript("OnClick", function(_, _, down)
    if down == false then say(("click G at %.2f"):format(GetTime())) end
end)

-- C8: a pad with two tab containers, each holding a secure button. Mouse wheel over the pad
-- swaps them through a restricted snippet. Does it work in combat?
local pad = CreateFrame("Frame", "QCSpikePad", panel)
pad:SetSize(220, 50)
pad:SetPoint("TOPLEFT", 10, -162)
pad:EnableMouseWheel(true)
local tabs = {}
for i, label in ipairs({ "Tab A: /p tab A", "Tab B: /p tab B" }) do
    local c = CreateFrame("Frame", "QCSpikeTab" .. i, pad)
    c:SetAllPoints(pad)
    local b = CreateFrame("Button", "QCSpikeTabBtn" .. i, c, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    b:SetSize(200, 22)
    b:SetPoint("CENTER")
    b:SetText(label .. " (wheel)")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", i == 1 and "/p QC spike tab A" or "/p QC spike tab B")
    tabs[i] = c
end
tabs[2]:Hide()
header:SetFrameRef("tabA", tabs[1])
header:SetFrameRef("tabB", tabs[2])
SecureHandlerWrapScript(pad, "OnMouseWheel", header, [[
    local a, b = owner:GetFrameRef("tabA"), owner:GetFrameRef("tabB")
    if a:IsShown() then a:Hide() b:Show() else b:Hide() a:Show() end
]])

-- C7: the spike dial. A full-screen secure button bound to a key. Key down records the cursor
-- origin; key up picks N/E/S/W and remaps the click to a slot button through `type-slotN` /
-- `clickbutton-slotN` attributes set out of combat. No attribute is written in combat except
-- the origin on the dial's own handle.
local slots = {}
for i, dir in ipairs({ "N", "E", "S", "W" }) do
    local s = CreateFrame("Button", "QCSpikeSlot" .. i, UIParent, "SecureActionButtonTemplate")
    s:RegisterForClicks("AnyUp", "AnyDown")
    s:SetAttribute("type", "macro")
    s:SetAttribute("macrotext", "/p QC spike dial " .. dir)
    slots[i] = s
end
local dial = CreateFrame("Button", "QCSpikeDial", UIParent, "SecureActionButtonTemplate")
dial:SetAllPoints(UIParent)
dial:EnableMouse(false)
dial:RegisterForClicks("AnyUp", "AnyDown")
for i = 1, 4 do
    dial:SetAttribute("type-slot" .. i, "click")
    dial:SetAttribute("clickbutton-slot" .. i, slots[i])
end
SecureHandlerWrapScript(dial, "OnClick", header, [[
    local x, y = self:GetMousePosition()
    if down then
        self:SetAttribute("qc-ox", x)
        self:SetAttribute("qc-oy", y)
        return false
    end
    local ox, oy = self:GetAttribute("qc-ox"), self:GetAttribute("qc-oy")
    if not (x and ox) then return false end
    local dx, dy = (x - ox) * 16, (y - oy) * 9
    if dx * dx + dy * dy < 0.25 then return false end
    local ax = dx < 0 and -dx or dx
    local ay = dy < 0 and -dy or dy
    if ay >= ax then
        if dy > 0 then return "slot1" end
        return "slot3"
    end
    if dx > 0 then return "slot2" end
    return "slot4"
]])
local marker = CreateFrame("Frame", nil, UIParent)
marker:SetSize(160, 160)
marker:Hide()
local mtex = marker:CreateTexture(nil, "OVERLAY")
mtex:SetAllPoints()
mtex:SetTexture("Interface\\Minimap\\Ping\\ping5")
dial:HookScript("OnClick", function(_, _, down)
    if down then
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        marker:Show()
    else
        marker:Hide()
        say(("dial released at %.2f"):format(GetTime()))
    end
end)

-- C6: are our own returning messages' senders readable?
local echoOn = false
local echo = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER_INFORM" }) do
    echo:RegisterEvent(e)
end
echo:SetScript("OnEvent", function(_, event, _, sender)
    if not echoOn then return end
    local secret = issecretvalue and issecretvalue(sender)
    if secret then
        say(("%s at %.2f: sender is SECRET"):format(event, GetTime()))
    else
        say(("%s at %.2f: sender=%s"):format(event, GetTime(), tostring(sender)))
    end
end)

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("BOTTOM", 0, 8)
local elapsed = 0
panel:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0
    local lock = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    status:SetText(("lockdown %s  combat %s"):format(lock and "ON" or "off", InCombatLockdown() and "yes" or "no"))
end)

local rebakes = 0
SLASH_QCSPIKE1 = "/qcs"
SlashCmdList.QCSPIKE = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "where" then
        local name, itype, diff, diffName, _, _, _, instanceID = GetInstanceInfo()
        say(("instance=%s type=%s difficulty=%s (%s) instanceID=%s"):format(
            tostring(name), tostring(itype), tostring(diff), tostring(diffName), tostring(instanceID)))
        if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
            say(("challengeMapID=%s"):format(tostring(C_ChallengeMode.GetActiveChallengeMapID())))
        end
    elseif cmd == "rebake" then
        if InCombatLockdown() then say("in combat: refused (expected)") return end
        rebakes = rebakes + 1
        buttons.P:SetAttribute("macrotext", "/p QC spike rebake #" .. rebakes)
        say("P now sends rebake #" .. rebakes .. " (lockdown " ..
            tostring(C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) .. ")")
    elseif cmd == "bind" and arg ~= "" then
        if InCombatLockdown() then say("leave combat first") return end
        SetOverrideBindingClick(panel, true, arg:upper(), "QCSpikeDial", "LeftButton")
        say("bound " .. arg:upper() .. " to the spike dial: hold, flick N/E/S/W, release")
    elseif cmd == "unbind" then
        if InCombatLockdown() then say("leave combat first") return end
        ClearOverrideBindings(panel)
        say("bindings cleared")
    elseif cmd == "echo" then
        echoOn = arg == "on"
        say("echo " .. (echoOn and "on" or "off"))
    elseif cmd == "" then
        if InCombatLockdown() then say("leave combat first") return end
        panel:SetShown(not panel:IsShown())
    else
        say("usage: /qcs | where | rebake | bind KEY | unbind | echo on|off")
    end
end
