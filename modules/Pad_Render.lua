local _, NS = ...
-- modules/Pad_Render.lua — what a Comms Pad button and the pad's header show (spec §10.1). INSECURE
-- visuals only: textures and font strings on the buttons and the header, their text, color and
-- visibility, which the client allows in combat too. It never touches a secure attribute, a
-- protected frame's geometry or a protected frame's Show/Hide; modules/Pad.lua does the protected
-- work, out of combat. A button shows a square icon tile (a glyph in its color), its label, a padlock
-- when locked, a dim veil when its bake was refused, a dim veil during the spam guard's window, a
-- gold hover and a flash per send result. The tooltip names the line it sends and the channel it
-- goes to in WoW's chat color (a smart kind shows the channel it resolved to), or why it sends
-- nothing, and any lock. The pad's three window tabs (the Window tab until 2026-10-20, the Look tab
-- before that) are read here as plain values, which modules/Pad.lua applies out of combat: Main
-- window's skin (SkinFor, for the pad), Pad header's look (HeaderLook: the header row's height, font
-- and skin; its situation text starts at the section titles' left edge, PL.PAD, whatever the growth)
-- and Section header's (SectionLook: each title row's height, font, and a band of background and
-- border behind it, ApplySectionBand).
-- The Buttons tab (ButtonLook) dresses each button: its body, an edge on a plain child laid over it, its
-- label's font, a glow around the whole button (modules/Glow.lua Glow.Button) and its Shine heading's
-- overlay over the whole button (modules/Shine.lua NS.Shine.Apply; shine overlay, 2026-10-21). The Icons tab (B9) styles the icon through
-- modules/IconStyle.lua (size, crop, desaturation, alpha, tint, border) and modules/Glow.lua (the
-- glow, whose On hover trigger the button's OnEnter and OnLeave hooks drive).

NS.PadRender = NS.PadRender or {}
local R = NS.PadRender
local PL = NS.PadLayout
local IS = NS.IconStyle
local Glow = NS.Glow
local L = NS.L
local LV = NS.Constants.LAYERS.LEVEL

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- The padlock is the shared catalog's `lock` mark (library-stack-§8), resolved at draw time; this
-- Blizzard texture is drawn only when the catalog answers nil (the library absent).
local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local DOT = " \194\183 "

-- Why a button sends nothing (Bake's and Channels' reasons, spec §8.3/§18; test mode).
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

-- Why a locked button may not reach anyone (Channels.LockState, spec §8.4).
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

-- The channel a button's line goes to, by name (the button shows no channel letter; its tooltip does).
local CHANNEL_NAME = {
    party = L["Party"], raid = L["Raid"], instance = L["Instance"], raidWarning = L["Raid warning"],
    say = L["Say"], yell = L["Yell"], general = L["General"],
}

local function channelLine(concrete)
    local name = CHANNEL_NAME[concrete]
    if not name then return nil end
    local r, g, b = R.ChannelColor(NS.Channels.ColorType(concrete))
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return L["Channel: %s"]:format(("|cff%02x%02x%02x%s|r"):format(byte(r), byte(g), byte(b), name))
end

--- A button's tooltip: its name, then the line it sends and its channel, or why it sends nothing, then
--- any lock.
function R.TooltipLines(slot)
    local lines = { slot.name or "?" }
    if slot.line then
        lines[2] = slot.line
        lines[3] = channelLine(slot.concrete)
    elseif slot.selfText then
        lines[2] = L["Solo: prints to you, sends nothing."]
    else
        lines[2] = R.REASON_TEXT[slot.reason] or L["Not available here."]
    end
    if slot.lock then lines[#lines + 1] = R.LOCK_TEXT[slot.lock] or tostring(slot.lock) end
    if slot.preview then
        lines[#lines + 1] = L["Preview: this sends nothing."]
        if slot.line then lines[#lines + 1] = L["Click to print its line."] end
    end
    return lines
end

--- A section's label; a tab names its place ("Raid (2 of 3)").
function R.SectionTitle(item)
    if item.tabCount then return L["%s (%d of %d)"]:format(item.text, item.tabIndex, item.tabCount) end
    return item.text
end

--- A chat type's color (the game's ChatTypeInfo, else Constants.CHAT_COLORS, else SAY's): a button's
--- channel in its tooltip, and a callout row's channel on the Groups page.
function R.ChannelColor(chatType)
    local r, g, b = NS.Compat.ChatColor(chatType)
    if r then return r, g, b end
    local c = NS.Constants.CHAT_COLORS[chatType] or NS.Constants.CHAT_COLORS.SAY
    return c[1], c[2], c[3]
end

-- A state veil over the whole button, drawn on its overlay frame `over` (R.Overlay) at OVERLAY
-- sublevel `sub`, over the label and padlock (sublevel 0).
local function veil(btn, over, sub, r, g, b, a)
    local t = over:CreateTexture(nil, "OVERLAY", nil, sub)
    t:SetAllPoints(btn)
    t:SetColorTexture(r, g, b, a)
    t:Hide()
    return t
end

--- Whether a slot wears the dim veil (qcDim): only a live slot whose bake was refused, one that sends and
--- prints nothing. A test-mode placeholder and every previewed slot (spec §13.3: the edit preview and
--- Preview as) draw as live, because a preview is disarmed whatever it baked and only its PREVIEW
--- labels may differ from live (QC-05: a solo preview veiled every party button and wedge).
function R.Veiled(slot)
    if type(slot) ~= "table" then return false end
    if slot.preview == true or slot.reason == "testMode" then return false end
    return slot.line == nil and slot.selfText == nil
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

--- A titled tooltip of plain lines over `owner` (the pad header's "Why is this showing?").
function R.ShowLines(owner, title, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title)
    for _, line in ipairs(lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:Show()
end

--- A button's or a wedge's overlay frame (frame-layering-§3, QUI-Z03/Z04): a plain, mouse-off child at
--- `offset` over `btn`, above its border and glow frames, holding every region that must read over
--- them (the label, the padlock and the state veils). Mouse off, so the secure button under it keeps
--- every click. Made once, out of combat (a button is dressed when it is built).
function R.Overlay(btn, offset)
    local over = CreateFrame("Frame", nil, btn)
    over:SetAllPoints(btn)
    over:SetFrameLevel(btn:GetFrameLevel() + offset)
    over:EnableMouse(false)
    btn.qcOver = over
    return over
end

--- Build a button's regions and hover hooks, once per button. The ladder (core/Constants.lua LAYERS):
--- the fill and icon on the button, the edge frame at BTN_EDGE, the icon frame at BTN_ICON
--- (IconStyle.IconFrame), each glow one over its host, and the overlay frame at BTN_OVER on top.
function R.Dress(btn, onEnter, onLeave)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcIconLevel = LV.BTN_ICON
    btn.qcBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.qcBg:SetAllPoints(btn)
    btn.qcBg:SetColorTexture(0.10, 0.10, 0.12, 0.90)
    -- The Buttons tab's edge and glow host: a plain child laid over the button, mouse off (ApplyButtonLook).
    btn.qcEdge = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.qcEdge:SetAllPoints(btn)
    btn.qcEdge:SetFrameLevel(btn:GetFrameLevel() + LV.BTN_EDGE)
    btn.qcEdge:EnableMouse(false)
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetSize(PL.ICON, PL.ICON)
    btn.qcIcon:SetPoint("LEFT", btn, "LEFT", 2, 0)
    local over = R.Overlay(btn, LV.BTN_OVER)
    btn.qcLabel = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.qcLabel:SetJustifyH("LEFT")
    btn.qcLock = over:CreateTexture(nil, "OVERLAY")
    btn.qcLock:SetSize(12, 12)
    btn.qcLock:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    local lockMark = NS.Icon("lock")
    btn.qcLock:SetTexture(lockMark or LOCK_ICON)
    if lockMark then
        local gold = NS.Constants.GOLD   -- the catalog art is white; gold as the Blizzard padlock reads
        btn.qcLock:SetVertexColor(gold.r, gold.g, gold.b, 1)
    end
    btn.qcDim = veil(btn, over, 1, 0, 0, 0, 0.55)
    btn.qcCool = veil(btn, over, 2, 0, 0, 0, 0.35)
    btn.qcFlash = veil(btn, over, 3, 1.0, 0.82, 0.0, 0.45)
    local gold = NS.Constants.GOLD
    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(btn)
    hover:SetColorTexture(gold.r, gold.g, gold.b, 0.25)
    btn:HookScript("OnEnter", function(self)
        R.ShowTooltip(self)
        Glow.SetHover(self, true)
        if onEnter then onEnter(self) end
    end)
    btn:HookScript("OnLeave", function(self)
        GameTooltip:Hide()
        Glow.SetHover(self, false)
        if onLeave then onLeave(self) end
    end)
    return btn
end

-- A labeled button's fixed insets around its label (Dress's anchors): the icon at LEFT+2 and its 4px
-- gap, or the label-only 4px; RIGHT_INSET from the button's right edge.
local LABEL_INSET = { label = 4 }
local RIGHT_INSET = 4
-- On a locked button the label ends at the padlock (12 wide at TOPRIGHT -1) and a 1px gap, not under it.
local LOCK_INSET = 14

-- The label's two anchors: from the icon (or the button's left edge, label only) to the button's right
-- edge, or to the padlock's left edge while it shows. Paint and RefreshLock both call it, so a lock
-- that comes or goes in combat moves the label's end too.
local function anchorLabel(btn, locked)
    local label = btn.qcLabel
    label:ClearAllPoints()
    if btn.qcLabelOnly then
        label:SetPoint("LEFT", btn, "LEFT", 4, 0)
    else
        label:SetPoint("LEFT", btn.qcIcon, "RIGHT", 4, 0)
    end
    label:SetPoint("RIGHT", btn, "RIGHT", -(locked and LOCK_INSET or RIGHT_INSET), 0)
end

--- The room a button `w` wide leaves its label, beside the icon `iconSize` wide (unless `style` is label
--- only). Zero or less: no room.
function R.LabelRoom(w, style, iconSize)
    local left = LABEL_INSET[style] or (2 + (tonumber(iconSize) or PL.ICON) + 4)
    return (tonumber(w) or 0) - left - RIGHT_INSET
end

-- The Icons tab's defaults, for a paint that names no config (IconStyle.Config of none).
local DEFAULT_LOOK

--- Show one slot on a button. `style` is the pad's layout style, `w` the button's width (B3: the label
--- is one line that truncates, hidden when the button leaves it no room; no width, no check), `icfg`
--- the pad's Icons tab (IconStyle.Config; none is the defaults).
function R.Paint(btn, slot, style, w, icfg)
    btn.qcSlot = slot
    DEFAULT_LOOK = DEFAULT_LOOK or IS.Config(nil, "pad")
    icfg = icfg or DEFAULT_LOOK
    btn.qcIcon:SetTexture(slot.icon or DEFAULT_ICON)
    btn.qcIcon:SetSize(icfg.size, icfg.size)
    IS.ApplyIcon(btn.qcIcon, icfg, NS.Library.IconTint(slot.icon, slot.iconColor))
    btn.qcIcon:SetShown(style ~= "label")
    IS.PaintBorder(btn, icfg, style ~= "label")
    Glow.Bind(btn, style ~= "label" and icfg.glow or false, slot.calloutId)
    btn.qcLabelOnly = style == "label"
    -- One line to the button's right edge (the padlock's, while locked), whatever the Buttons tab's font size.
    -- No channel letter beside it: the channel is in the tooltip (TooltipLines).
    anchorLabel(btn, slot.lock ~= nil)
    btn.qcLabel:SetWordWrap(false)
    btn.qcLabel:SetMaxLines(1)
    btn.qcLabel:SetText(style == "icon" and "" or (slot.name or "?"))
    btn.qcLabel:SetShown(w == nil or R.LabelRoom(w, style, icfg.size) > 0)
    btn.qcLock:SetShown(slot.lock ~= nil)
    btn.qcDim:SetShown(R.Veiled(slot))
    btn.qcCool:Hide()
    btn.qcFlash:Hide()
end

function R.RefreshLock(btn)
    local locked = btn.qcSlot ~= nil and btn.qcSlot.lock ~= nil
    btn.qcLock:SetShown(locked)
    anchorLabel(btn, locked)
end

-- ── the pad's Look (spec §10.3; options-ui-§16, §17) ────────────────────────────────────────

local FLAT_EDGE = "Interface\\Buttons\\WHITE8x8"

--- A font block's font (the Section header tab's, the Pad header's, the Buttons tab's): { path, size,
--- flags, r, g, b, a, shadow }. A face this machine does not have is the standard one; "Use class
--- color" takes the player's class color, keeping the swatch's alpha (NS.ResolveColor). A missing
--- swatch is `fallback` when given, else white.
function R.LabelFont(look, fallback)
    look = type(look) == "table" and look or {}
    local r, g, b, a = NS.ResolveColor(look.fontColor or fallback, look.useClassColorFont)
    return { path = NS.MediaFetch("font", look.font) or STANDARD_TEXT_FONT, size = tonumber(look.fontSize) or 10,
        flags = type(look.fontFlags) == "string" and look.fontFlags or "", r = r, g = g, b = b, a = a,
        shadow = look.fontShadow ~= false }
end

-- The gold of GameFontNormalSmall: the section titles' and the header's default color.
R.TITLE_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }

--- The section titles' font: the Section header tab's (`pad.section`; gold by default, as the titles
--- always were).
function R.TitleFont(section)
    return R.LabelFont(section, R.TITLE_COLOR)
end

--- Draw a font string in a pad's font (R.LabelFont). A face the client refuses falls back to the
--- standard one.
function R.ApplyFont(fs, font)
    if not (fs and font) then return end
    if not fs:SetFont(font.path, font.size, font.flags) then fs:SetFont(STANDARD_TEXT_FONT, font.size, font.flags) end
    fs:SetTextColor(font.r, font.g, font.b, font.a)
    if font.shadow then fs:SetShadowOffset(1, -1) else fs:SetShadowOffset(0, 0) end
end

-- The inner line, made clear: the frame keeps the child LibKa0s built at its first skin, so a skin
-- with no innerBorder would leave it drawn; this one hides it.
local NO_INNER = { 0, 0, 0, 0 }

--- The skin a pad wears, from its Main window tab: the Ka0s skin (NS.SKIN) with the border's art (a
--- LibSharedMedia border by name; "None", or one this machine does not have, is the flat edge), its
--- thickness (0 is no edge) and color, and the background color, each through its class-color
--- companion. The Ka0s 1px inner line belongs to the pad's flat 1px edge only: at thickness 0 it would
--- be an edge after all, and over a thicker edge or border art it is a gray line that ignores the
--- border's color; `plain` (the header, a section band, a button's edge) never takes it. Art insets the background by a
--- quarter of its size, so the body reaches under the art's soft inner edge.
function R.SkinFor(look, plain)
    look = type(look) == "table" and look or {}
    local skin = {}
    for k, v in pairs(NS.SKIN or {}) do skin[k] = v end
    local size = math.max(0, math.min(16, tonumber(look.borderSize) or 1))
    local art = look.borderStyle ~= "None" and NS.MediaFetch("border", look.borderStyle) or nil
    skin.edgeFile = size > 0 and (art or FLAT_EDGE) or nil
    skin.edgeSize = size
    local inset = art and math.floor(size / 4 + 0.5) or size
    skin.insets = { left = inset, right = inset, top = inset, bottom = inset }
    if plain or art or size ~= 1 then skin.innerBorder = NO_INNER end
    skin.border = { NS.ResolveColor(look.borderColor, look.useClassColorBorder) }
    skin.bg = { NS.ResolveColor(look.background, look.useClassColorBackground) }
    return skin
end

-- The header's other texts keep their own colors over the header's face, size, flags and shadow: the
-- lockdown chip GameFontRedSmall's red, the stale hint GameFontDisableSmall's gray. The collapse
-- button is GameFontNormal's: two points over the header's size, in the header's color.
local LOCKDOWN_COLOR = { 1, 0.1, 0.1, 1 }
local STALE_COLOR = { 0.5, 0.5, 0.5, 1 }

local function recolor(font, c, grow)
    local t = {}
    for k, v in pairs(font) do t[k] = v end
    if c then t.r, t.g, t.b, t.a = c[1], c[2], c[3], c[4] end
    t.size = t.size + (grow or 0)
    return t
end

-- A header or button table's signature: every leaf its look reads, and the media its names resolve to
-- now, so a rebuild that changed none of it reuses the look it built last time and repaints nothing
-- (HeaderLook, ButtonLook and their Apply). The class color is the player's, fixed for the session.
local SIG_KEYS = { "height", "width", "font", "fontSize", "fontFlags", "fontShadow", "useClassColorFont",
    "borderStyle", "borderSize", "useClassColorBorder", "useClassColorBackground", "glowEnabled", "glowType",
    "useClassColorGlow", "shineLook", "shineStrength", "useClassColorShineTint", "useClassColorShineBloomA",
    "useClassColorShineBloomB" }
local SIG_COLORS = { "fontColor", "borderColor", "background", "glowColor", "shineTint", "shineBloomA", "shineBloomB" }

local function lookSig(t)
    local parts = {}
    for _, k in ipairs(SIG_KEYS) do parts[#parts + 1] = tostring(t[k]) end
    for _, k in ipairs(SIG_COLORS) do
        local c = t[k]
        if type(c) == "table" then
            parts[#parts + 1] = ("%s,%s,%s,%s"):format(tostring(c.r or c[1]), tostring(c.g or c[2]),
                tostring(c.b or c[3]), tostring(c.a or c[4]))
        else
            parts[#parts + 1] = "-"
        end
    end
    parts[#parts + 1] = tostring(NS.MediaFetch("font", t.font))
    parts[#parts + 1] = tostring(NS.MediaFetch("border", t.borderStyle))
    return table.concat(parts, "|")
end

--- The header's look, from the pad's `header` table: { height, font, skin, sig }. The font is the
--- header block's (gold by default, GameFontNormalSmall's); the skin its background and edge, plain
--- (no Ka0s inner line); the defaults draw no background and no edge. `prev`, the look the last
--- rebuild built, is answered again while its signature still holds.
function R.HeaderLook(header, prev)
    header = type(header) == "table" and header or {}
    local sig = lookSig(header)
    if type(prev) == "table" and prev.sig == sig then return prev end
    return { sig = sig, height = PL.HeaderHeight(header.height), font = R.LabelFont(header, R.TITLE_COLOR),
        skin = R.SkinFor({ borderStyle = header.borderStyle or "None", borderSize = header.borderSize or 0,
            borderColor = header.borderColor, useClassColorBorder = header.useClassColorBorder,
            background = header.background or { 0, 0, 0, 0 },
            useClassColorBackground = header.useClassColorBackground }, true) }
end

--- Dress the header row in its look (R.HeaderLook): its skin, and every text in its font. A look the
--- header already wears (its signature) is not painted again.
function R.ApplyHeaderLook(header, hl)
    if header.qcLookSig == hl.sig then return end
    header.qcLookSig = hl.sig
    NS.ApplySkin(header, hl.skin)
    R.ApplyFont(header.qcSituation, hl.font)
    R.ApplyFont(header.qcLockdown, recolor(hl.font, LOCKDOWN_COLOR))
    R.ApplyFont(header.qcStale, recolor(hl.font, STALE_COLOR))
    if header.qcCollapse then R.ApplyFont(header.qcCollapse.qcText, recolor(hl.font, nil, 2)) end
end

--- The section headers' look, from the pad's `section` table: { height (0 automatic), font, skin (the
--- band behind each title: its background and edge, plain), inset (the band's edge, which the title
--- text keeps clear of), sig }. The defaults draw no band, the text at the titles' old left edge.
--- `prev` is answered again while its signature still holds, as R.HeaderLook's.
function R.SectionLook(section, prev)
    section = type(section) == "table" and section or {}
    local sig = lookSig(section)
    if type(prev) == "table" and prev.sig == sig then return prev end
    local skin = R.SkinFor({ borderStyle = section.borderStyle or "None", borderSize = section.borderSize or 0,
        borderColor = section.borderColor, useClassColorBorder = section.useClassColorBorder,
        background = section.background or { 0, 0, 0, 0 },
        useClassColorBackground = section.useClassColorBackground }, true)
    return { sig = sig, height = math.max(0, math.floor(tonumber(section.height) or 0)), font = R.TitleFont(section),
        skin = skin, inset = skin.edgeFile and skin.insets.left or 0 }
end

--- Dress a section title's band in its look (R.SectionLook); a band already wearing it is not painted
--- again.
function R.ApplySectionBand(band, sl)
    if band.qcLookSig == sl.sig then return end
    band.qcLookSig = sl.sig
    NS.ApplySkin(band, sl.skin)
end

-- ── the Buttons tab (2026-10-20) ───────────────────────────────────────────────────────────────

local BUTTON_BG = { 0.10, 0.10, 0.12, 0.90 }
local CLEAR = { 0, 0, 0, 0 }

--- A button's look, from the pad's `button` table: { bg = {r,g,b,a}, edge (a plain skin: the border only,
--- over no background), font, glow (IconStyle.GlowConfig, false while off), shine (NS.Shine.Resolve of
--- its Shine leaves), sig }. The defaults are the button as it always was: the 0.10, 0.10, 0.12, 0.90
--- body, no edge, the small white label, no glow, no shine.
--- `prev` is answered again while its signature still holds, as R.HeaderLook's.
function R.ButtonLook(button, prev)
    button = type(button) == "table" and button or {}
    local sig = lookSig(button)
    if type(prev) == "table" and prev.sig == sig then return prev end
    local bg = { NS.ResolveColor(button.background or BUTTON_BG, button.useClassColorBackground) }
    local edge = R.SkinFor({ borderStyle = button.borderStyle or "None", borderSize = button.borderSize or 0,
        borderColor = button.borderColor, useClassColorBorder = button.useClassColorBorder, background = CLEAR }, true)
    return { sig = sig, bg = bg, edge = edge, font = R.LabelFont(button), glow = IS.GlowConfig(button,
        tostring(button.width) .. "x" .. tostring(button.height)), shine = NS.Shine.Resolve(button) }
end

-- The button glow for a button drawn `w` x `h`: the look's glow, its signature carrying that size, so a
-- button the Layout's Button style or the Icons tab's icon size resized restarts a pixel or autocast glow
-- whose lines were laid out for its old size. One per size, kept on the look.
local function sizedGlow(cl, w, h)
    local g = cl.glow
    if not (g and w and h) then return g end
    local key = tostring(w) .. "x" .. tostring(h)
    cl.glowBySize = cl.glowBySize or {}
    local sized = cl.glowBySize[key]
    if not sized then
        sized = setmetatable({ sig = tostring(g.sig) .. "|" .. key }, { __index = g })
        cl.glowBySize[key] = sized
    end
    return sized
end

--- Dress a button in its look (R.ButtonLook): its body, its edge, its label's font, its glow and its shine.
--- A look the button already wears (its signature) is not painted again; the glow is handed over every time,
--- since a button's release puts its glow out (Glow.Release), and Glow.Button keeps an unchanged one. The
--- shine is painted every time too, over the whole button `w` x `h` (its drawn size, part of its glow's
--- signature too), whatever the slot's style.
function R.ApplyButtonLook(btn, cl, w, h)
    if btn.qcLookSig ~= cl.sig then
        btn.qcLookSig = cl.sig
        btn.qcBg:SetColorTexture(cl.bg[1], cl.bg[2], cl.bg[3], cl.bg[4])
        NS.ApplySkin(btn.qcEdge, cl.edge)
        R.ApplyFont(btn.qcLabel, cl.font)
    end
    Glow.Button(btn, sizedGlow(cl, w, h))
    NS.Shine.Apply(btn, cl.shine, w, h)
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

-- The header row's collapse button (square) and its inset from the row's right edge, the gap
-- before it, and the lockdown chip's gap after the situation text (R.HeaderMinWidth measures with them).
local COLLAPSE_W, COLLAPSE_INSET, HEADER_GAP, LOCKDOWN_GAP = 16, 2, 4, 6

--- Build the header row: the situation chip, the lockdown chip, the stale hint and the collapse
--- toggle (its button, or a left click anywhere on the row). PREVIEW and TEST MODE are not here: they
--- ride the drag strip's label (R.StripLabel).
function R.DressHeader(header, onCollapse)
    header.qcSituation = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- At the section titles' left edge (Pad_Layout places them at PL.PAD), in every growth direction:
    -- the header spans the pad, and no growth moves a title off it.
    header.qcSituation:SetPoint("LEFT", header, "LEFT", PL.PAD, 0)
    header.qcLockdown = header:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    header.qcLockdown:SetPoint("LEFT", header.qcSituation, "RIGHT", LOCKDOWN_GAP, 0)
    header.qcLockdown:SetText(L["LOCKDOWN"])
    local collapse = CreateFrame("Button", nil, header)
    collapse:SetSize(COLLAPSE_W, COLLAPSE_W)
    collapse:SetPoint("RIGHT", header, "RIGHT", -COLLAPSE_INSET, 0)
    collapse.qcText = collapse:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    collapse.qcText:SetAllPoints(collapse)
    collapse:SetScript("OnClick", function() onCollapse() end)
    header.qcCollapse = collapse
    -- A left click anywhere on the row collapses or expands it too (the button is a child, so its own
    -- click never reaches the row twice).
    header:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then onCollapse() end
    end)
    header.qcStale = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.qcStale:SetPoint("RIGHT", collapse, "LEFT", -HEADER_GAP, 0)
    header.qcStale:SetText(L["updates after combat"])
    header.qcLockdown:Hide()
    header.qcStale:Hide()
end

--- The narrowest the header row may be (modules/Pad.lua hands it to PL.Compute as opts.minWidth):
--- the situation text at its left inset, the lockdown chip after it while shown, a gap, and the
--- collapse button at its right inset. Measured in the font, text and button the row wears now, so
--- ApplyHeaderLook and PaintHeader come first. The button counts out of combat too: a PvP match's
--- lockdown (and a battleground or arena preview) shows it while rebuilds still run.
function R.HeaderMinWidth(header)
    local w = tonumber(header.qcSituation:GetStringWidth()) or 0
    if header.qcLockdown:IsShown() then
        w = w + LOCKDOWN_GAP + (tonumber(header.qcLockdown:GetStringWidth()) or 0)
    end
    return math.ceil(PL.PAD + w + HEADER_GAP + COLLAPSE_W + COLLAPSE_INSET)
end

-- GameFontGreenSmall's green (0.1, 1, 0.1), the color the header's marker wore before it moved.
local MARK_GREEN = "|cff19ff19"

--- The drag strip's label: the pad's name, then the marker (PREVIEW or TEST MODE) in green when a
--- preview or test mode is drawn. The client measures a string without its escapes, so the strip's
--- Measure grows by the marker's own width.
--- @param name string
--- @param mark string|nil already localized
--- @return string
function R.StripLabel(name, mark)
    if not mark then return name end
    return name .. "  " .. MARK_GREEN .. mark .. "|r"
end

function R.PaintHeader(header, state)
    header.qcSituation:SetText(state.situation or "")
    header.qcLockdown:SetShown(state.lockdown == true)
    header.qcStale:SetShown(state.stale == true)
    header.qcCollapse.qcText:SetText(state.collapsed and "+" or "-")
end
