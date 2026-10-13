local _, NS = ...
-- modules/Pad_Render.lua — what a Comms Pad chip and the pad's header show (spec §10.1). INSECURE
-- visuals only: textures and font strings on the chips and the header, their text, color and
-- visibility, which the client allows in combat too. It never touches a secure attribute, a
-- protected frame's geometry or a protected frame's Show/Hide; modules/Pad.lua does the protected
-- work, out of combat. A chip shows a square icon tile, its label, the channel tag in WoW's chat
-- color (a smart kind shows the channel it resolved to), a padlock when locked, a dim veil when its
-- bake was refused, a dim veil during the spam guard's window, a gold hover and a flash per send
-- result. The tooltip names the line it sends, or why it sends nothing, and any lock.

NS.PadRender = NS.PadRender or {}
local R = NS.PadRender
local PL = NS.PadLayout
local L = NS.L

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local DOT = " \194\183 "

-- Why a chip sends nothing (Bake's and Channels' reasons, spec §8.3/§18; test mode).
R.REASON_TEXT = {
    startsWithSlash = L["Callout text cannot start with /."],
    tooLong = L["Too long: a chat line holds 255 bytes."],
    empty = L["This callout has no text."],
    solo = L["You are not in a group."],
    badChannel = L["This callout has no valid channel."],
    badCallout = L["This callout is damaged."],
    noCallout = L["This callout no longer exists."],
    testMode = L["Test mode: a placeholder that sends nothing."],
}

-- Why a locked chip may not reach anyone (Channels.LockState, spec §8.4).
R.LOCK_TEXT = {
    notInRaid = L["Locked: you are not in a raid."],
    notLeader = L["Locked: needs raid leader or assist."],
    notInGroup = L["Locked: you are not in a group."],
    notInInstanceGroup = L["Locked: you are not in an instance group."],
    lockdown = L["Locked: Say and Yell are blocked during this encounter."],
}

R.CONTENT = {
    mythicPlus = L["M+"], raid = L["Raid"], dungeon = L["Dungeon"], arena = L["Arena"],
    battleground = L["Battleground"], delve = L["Delve"], scenario = L["Scenario"], housing = L["Housing"],
    openWorld = L["World"],
}

--- The header's situation chip: "M+ · Windrunner Spire +14".
function R.SituationText(snap, dungeon)
    snap = type(snap) == "table" and snap or {}
    local text = R.CONTENT[snap.content] or R.CONTENT.openWorld
    if type(dungeon) == "string" and dungeon ~= "" then text = text .. DOT .. dungeon end
    if snap.content == "mythicPlus" and type(snap.keyLevel) == "number" then
        text = text .. " +" .. snap.keyLevel
    end
    return text
end

--- A chip's tooltip: its name, then the line it sends or why it sends nothing, then any lock.
function R.TooltipLines(slot)
    local lines = { slot.name or "?" }
    if slot.line then
        lines[2] = slot.line
    elseif slot.selfText then
        lines[2] = L["Solo: prints to you, sends nothing."]
    else
        lines[2] = R.REASON_TEXT[slot.reason] or L["Not available here."]
    end
    if slot.lock then lines[#lines + 1] = R.LOCK_TEXT[slot.lock] or tostring(slot.lock) end
    if slot.preview then lines[#lines + 1] = L["Preview: this chip sends nothing."] end
    return lines
end

--- A section's label; a tab names its place ("Raid (2 of 3)").
function R.SectionTitle(item)
    if item.tabCount then return L["%s (%d of %d)"]:format(item.text, item.tabIndex, item.tabCount) end
    return item.text
end

local function tagColor(chatType)
    local r, g, b = NS.Compat.ChatColor(chatType)
    if r then return r, g, b end
    local c = NS.Constants.CHAT_COLORS[chatType] or NS.Constants.CHAT_COLORS.SAY
    return c[1], c[2], c[3]
end

local function veil(btn, r, g, b, a)
    local t = btn:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(btn)
    t:SetColorTexture(r, g, b, a)
    t:Hide()
    return t
end

function R.ShowTooltip(btn)
    local slot = btn.qcSlot
    if not slot then return end
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    for i, line in ipairs(R.TooltipLines(slot)) do
        if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end

--- Build a chip's regions and hover hooks, once per button.
function R.Dress(btn, onEnter, onLeave)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.qcBg:SetAllPoints(btn)
    btn.qcBg:SetColorTexture(0.10, 0.10, 0.12, 0.90)
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetSize(PL.ICON, PL.ICON)
    btn.qcIcon:SetPoint("LEFT", btn, "LEFT", 2, 0)
    btn.qcLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.qcLabel:SetJustifyH("LEFT")
    btn.qcTag = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.qcTag:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.qcLock = btn:CreateTexture(nil, "OVERLAY")
    btn.qcLock:SetSize(12, 12)
    btn.qcLock:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    btn.qcLock:SetTexture(LOCK_ICON)
    btn.qcDim = veil(btn, 0, 0, 0, 0.55)
    btn.qcCool = veil(btn, 0, 0, 0, 0.35)
    btn.qcFlash = veil(btn, 1.0, 0.82, 0.0, 0.45)
    local gold = NS.Constants.GOLD
    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(btn)
    hover:SetColorTexture(gold.r, gold.g, gold.b, 0.25)
    btn:HookScript("OnEnter", function(self)
        R.ShowTooltip(self)
        if onEnter then onEnter(self) end
    end)
    btn:HookScript("OnLeave", function(self)
        GameTooltip:Hide()
        if onLeave then onLeave(self) end
    end)
    return btn
end

--- Show one slot on a chip. `style` is the pad's layout style.
function R.Paint(btn, slot, style)
    btn.qcSlot = slot
    local live = slot.line ~= nil or slot.selfText ~= nil or slot.reason == "testMode"
    btn.qcIcon:SetTexture(slot.icon or DEFAULT_ICON)
    btn.qcIcon:SetShown(style ~= "label")
    btn.qcLabel:ClearAllPoints()
    if style == "label" then
        btn.qcLabel:SetPoint("LEFT", btn, "LEFT", 4, 0)
    else
        btn.qcLabel:SetPoint("LEFT", btn.qcIcon, "RIGHT", 4, 0)
    end
    btn.qcLabel:SetText(style == "icon" and "" or (slot.name or "?"))
    btn.qcTag:SetText(PL.Tag(slot.concrete) or "")
    btn.qcTag:SetTextColor(tagColor(slot.chatType or NS.Channels.ChatType(slot.concrete)))
    btn.qcLock:SetShown(slot.lock ~= nil)
    btn.qcDim:SetShown(not live)
    btn.qcCool:Hide()
    btn.qcFlash:Hide()
end

function R.RefreshLock(btn)
    btn.qcLock:SetShown(btn.qcSlot ~= nil and btn.qcSlot.lock ~= nil)
end

function R.Flash(btn, what)
    local c = NS.Constants.FLASH[what] or NS.Constants.FLASH.sent
    btn.qcFlash:SetColorTexture(c[1], c[2], c[3], 0.45)
    btn.qcFlash:Show()
end

function R.Unflash(btn)
    btn.qcFlash:Hide()
end

function R.SetCooling(btn, on)
    btn.qcCool:SetShown(on and true or false)
end

--- Build the header row: the situation chip, the lockdown chip, the test label, the stale hint and
--- the collapse toggle.
function R.DressHeader(header, onCollapse)
    header.qcSituation = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.qcSituation:SetPoint("LEFT", header, "LEFT", 6, 0)
    header.qcLockdown = header:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    header.qcLockdown:SetPoint("LEFT", header.qcSituation, "RIGHT", 6, 0)
    header.qcLockdown:SetText(L["LOCKDOWN"])
    header.qcTest = header:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    header.qcTest:SetPoint("LEFT", header.qcLockdown, "RIGHT", 6, 0)
    header.qcTest:SetText(L["TEST MODE"])
    local collapse = CreateFrame("Button", nil, header)
    collapse:SetSize(16, 16)
    collapse:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    collapse.qcText = collapse:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    collapse.qcText:SetAllPoints(collapse)
    collapse:SetScript("OnClick", function() onCollapse() end)
    header.qcCollapse = collapse
    header.qcStale = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.qcStale:SetPoint("RIGHT", collapse, "LEFT", -4, 0)
    header.qcStale:SetText(L["updates after combat"])
    header.qcLockdown:Hide()
    header.qcTest:Hide()
    header.qcStale:Hide()
end

function R.PaintHeader(header, state)
    header.qcSituation:SetText(state.situation or "")
    header.qcLockdown:SetShown(state.lockdown == true)
    header.qcTest:SetShown(state.test == true)
    header.qcTest:SetText(state.testText or L["TEST MODE"])
    header.qcStale:SetShown(state.stale == true)
    header.qcCollapse.qcText:SetText(state.collapsed and "+" or "-")
end
