local _, NS = ...
-- modules/Dial_Render.lua — what the Comms Dial shows (spec §11.1, §11.4). INSECURE visuals only:
-- textures and font strings on the dial's frames, their text, color and visibility, which the client
-- allows in combat; it never touches an attribute or a protected frame's geometry or visibility (the
-- header's snippets show and hide the rings; modules/Dial.lua sizes and places the frames, out of
-- combat). As modules/Pad_Render.lua dresses a pad's secure buttons, this dresses the dial's secure
-- frames: the dark disc and the hub's close mark on the header; spokes, a title and (on a paged ring)
-- its page dots and two page arrows on each ring; and on each wedge an icon (a glyph in its color, no
-- backdrop of its own since the dial rework, 2026-10-21), its label, a padlock, a dim veil when it sends nothing, the
-- guard's cooling veil, a result flash and a gold glow under the mouse (the selected wedge). The hub carries the stale hint, the lockdown chip and the test
-- or preview label. The pointer is a plain (unprotected) child of the header that turns toward the
-- cursor: its OnUpdate is set when the header shows and cleared when it hides, so a closed or
-- stood-down dial runs nothing per frame (perf bucket dialRender). The Icons tab (B9) styles each
-- wedge's icon through modules/IconStyle.lua (its size inside the fixed wedge, crop, desaturation,
-- alpha, tint, and a round ring for a border) and modules/Glow.lua (the glow, whose On hover trigger
-- the wedge's OnEnter and OnLeave hooks drive).

NS.DialRender = NS.DialRender or {}
local R = NS.DialRender
local DL = NS.DialLayout
local IS = NS.IconStyle
local Glow = NS.Glow
local L = NS.L
local Perf = NS.Perf

local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- The page arrows and dots are catalog glyphs too, with these Blizzard fallbacks.
local ARROW_ICONS = { prev = { "caret-circle-left", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" },
    next = { "caret-circle-right", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" } }
local DOT_ICON = "circle"
local DIM = 0.4   -- an arrow at an end, and a page dot not shown
-- The padlock and the hub's close are the shared catalog's `lock` and `close` marks
-- (library-stack-§8), resolved at draw time; these Blizzard textures are drawn only when the catalog
-- answers nil (the library absent).
local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local CLOSE_ICON = "Interface\\Buttons\\UI-StopButton"
local POINTER_ICON = "Interface\\Minimap\\MinimapArrow"
local SPOKES = 12

-- One catalog mark on `tex`, tinted (the catalog art is white), or the Blizzard fallback untinted.
local function mark(tex, name, fallback, r, g, b)
    local path = NS.Icon(name)
    tex:SetTexture(path or fallback)
    if path then tex:SetVertexColor(r, g, b, 1) end
end

-- A round texture: the circular alpha mask, tinted.
local function circle(frame, layer, size, r, g, b, a)
    local t = frame:CreateTexture(nil, layer)
    t:SetTexture(CIRCLE)
    t:SetVertexColor(r, g, b, a)
    t:SetSize(size, size)
    t:SetPoint("CENTER", frame, "CENTER", 0, 0)
    return t
end

--- The pointer, while the dial is open: toward the cursor, hidden inside the dead zone.
function R.PointerUpdate(pointer)
    local t0 = Perf.on and debugprofilestop()
    local header = pointer.qcHeader
    local cx, cy = header:GetCenter()
    local scale = header:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local a, ox, oy = DL.Pointer((cx or 0) * scale, (cy or 0) * scale, mx, my)
    local arrow = pointer.qcArrow
    if a then
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", header, "CENTER", ox, oy)
        arrow:SetRotation(-a)
        arrow:Show()
    else
        arrow:Hide()
    end
    if t0 then Perf.Note("dialRender", debugprofilestop() - t0) end
end

--- Build the hub's regions and the pointer, once per header. `onEnter(header)` runs on hover.
function R.DressHub(header, onEnter)
    if header.qcDressed then return header end
    header.qcDressed = true
    header.qcDisc = circle(header, "BACKGROUND", DL.Geometry().disc, 0.06, 0.06, 0.08, 0.80)
    header.qcHub = circle(header, "BORDER", DL.HUB, 0.12, 0.12, 0.14, 0.95)
    header.qcClose = header:CreateTexture(nil, "ARTWORK")
    mark(header.qcClose, "close", CLOSE_ICON, 1.0, 0.35, 0.35)   -- red, as the stop button reads
    header.qcClose:SetSize(DL.HUB - 16, DL.HUB - 16)
    header.qcClose:SetPoint("CENTER", header, "CENTER", 0, 0)
    header.qcStale = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.qcStale:SetPoint("TOP", header, "BOTTOM", 0, -2)
    header.qcStale:SetText(L["updates after combat"])
    header.qcStale:Hide()
    header.qcLockdown = header:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    header.qcLockdown:SetPoint("BOTTOM", header, "TOP", 0, 2)
    header.qcLockdown:SetText(L["LOCKDOWN"])
    header.qcLockdown:Hide()
    header.qcTest = header:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    header.qcTest:SetPoint("BOTTOM", header.qcLockdown, "TOP", 0, 2)
    header.qcTest:Hide()
    local pointer = CreateFrame("Frame", nil, header)
    pointer:SetAllPoints(header)
    pointer.qcHeader = header
    local gold = NS.Constants.GOLD
    pointer.qcArrow = pointer:CreateTexture(nil, "OVERLAY")
    pointer.qcArrow:SetTexture(POINTER_ICON)
    pointer.qcArrow:SetSize(16, 16)
    pointer.qcArrow:SetVertexColor(gold.r, gold.g, gold.b, 1)
    pointer.qcArrow:Hide()
    header.qcPointer = pointer
    header:HookScript("OnShow", function() pointer:SetScript("OnUpdate", R.PointerUpdate) end)
    header:HookScript("OnHide", function()
        pointer:SetScript("OnUpdate", nil)
        pointer.qcArrow:Hide()
    end)
    header:HookScript("OnEnter", function(self) if onEnter then onEnter(self) end end)
    header:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return header
end

--- A dial's look for one rebuild: its radius (clamped), its Labels tab (`dial.label`) as a font
--- (Pad_Render.LabelFont), whether labels show, and their line height (0 when they do not).
function R.Look(radius, label)
    label = type(label) == "table" and label or {}
    local font = NS.PadRender.LabelFont(label)
    local show = label.show ~= false
    return { radius = DL.ClampRadius(radius), font = font, show = show, line = show and font.size + 2 or 0 }
end

--- The disc's diameter, as the dial's radius sets it.
function R.SizeDisc(header, disc)
    header.qcDisc:SetSize(disc, disc)
end

--- The hub's labels: the lockdown chip, the stale hint, and TEST MODE or PREVIEW.
function R.PaintHub(header, state)
    header.qcLockdown:SetShown(state.lockdown == true)
    header.qcStale:SetShown(state.stale == true)
    header.qcTest:SetShown(state.testText ~= nil)
    header.qcTest:SetText(state.testText or "")
end

--- Build a ring container's spokes and title, once per container.
function R.DressRing(ring)
    if ring.qcDressed then return ring end
    ring.qcDressed = true
    ring.qcSpokes = {}
    for j = 1, SPOKES do
        local s = ring:CreateTexture(nil, "BORDER")
        s:SetColorTexture(1, 1, 1, 0.12)
        s:Hide()
        ring.qcSpokes[j] = s
    end
    ring.qcTitle = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ring.qcDots = {}
    return ring
end

-- One page dot, made on first use: the catalog's circle, or the round mask.
local function dot(ring, p)
    local d = ring.qcDots[p]
    if d then return d end
    d = ring:CreateTexture(nil, "OVERLAY")
    d:SetTexture(NS.Icon(DOT_ICON) or CIRCLE)
    d:SetSize(DL.DOT, DL.DOT)
    ring.qcDots[p] = d
    return d
end

-- A paged ring's dots in the row under the disc (DL.Nav): this page's gold, the others gray.
local function paintDots(ring, spec, look)
    local pages = (spec.pages or 1) > 1 and spec.pages or 0
    local nav = DL.Nav(pages, look.radius, look.line)
    local gold = NS.Constants.GOLD
    for p = 1, math.max(pages, #ring.qcDots) do
        local d = dot(ring, p)
        if p <= pages then
            d:ClearAllPoints()
            d:SetPoint("CENTER", ring, "CENTER", nav.dots[p], nav.y)
            if p == spec.page then d:SetVertexColor(gold.r, gold.g, gold.b, 1) else d:SetVertexColor(DIM, DIM, DIM, 0.9) end
            d:Show()
        else
            d:Hide()
        end
    end
end

--- Build a page arrow's glyph and hover, once per button. `side` is "prev" or "next".
function R.DressArrow(btn, side)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcSide = side
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetAllPoints(btn)
    btn.qcIcon:SetTexture(NS.Icon(ARROW_ICONS[side][1]) or ARROW_ICONS[side][2])
    btn:HookScript("OnEnter", function(self)
        if self.qcLive then
            NS.PadRender.ShowLines(self, side == "prev" and L["Previous page"] or L["Next page"],
                { L["The Left and Right arrow keys and the mouse wheel turn pages too."] })
        end
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

--- A page arrow live (gold: a page lies that way) or dimmed (at an end).
function R.PaintArrow(btn, live)
    btn.qcLive = live and true or false
    local c = NS.Constants.GOLD
    if live then btn.qcIcon:SetVertexColor(c.r, c.g, c.b, 1) else btn.qcIcon:SetVertexColor(DIM, DIM, DIM, 0.6) end
end

--- A ring's title: its name, and its page when it has several ("Arathi Basin (1 of 2)").
function R.RingTitle(spec)
    if (spec.pages or 1) > 1 then return L["%s (%d of %d)"]:format(spec.title or "", spec.page, spec.pages) end
    return spec.title or ""
end

--- Show one ring's spokes (one between each pair of its wedges; none for a lone wedge), its title over
--- the N wedge's label, and its page dots, in the dial's look (R.Look).
function R.PaintRing(ring, spec, look)
    look = look or R.Look()
    local radius = look.radius
    for j, s in ipairs(ring.qcSpokes) do
        if spec.size > 1 and j <= spec.size then
            local g = DL.Spoke(j, spec.size, radius, spec.start)
            s:ClearAllPoints()
            s:SetPoint("CENTER", ring, "CENTER", g.x, g.y)
            s:SetSize(1, g.length)
            s:SetRotation(g.rotation)
            s:Show()
        else
            s:Hide()
        end
    end
    ring.qcTitle:ClearAllPoints()
    ring.qcTitle:SetPoint("BOTTOM", ring, "CENTER", 0, DL.Geometry(radius, look.line).title)
    ring.qcTitle:SetText(R.RingTitle(spec))
    paintDots(ring, spec, look)
end

--- A wedge's tooltip lines: a callout's as its pad button's (name, its line or why it sends nothing,
--- any lock), a ring's name and what a click does.
function R.WedgeLines(item)
    if item.slot then return NS.PadRender.TooltipLines(item.slot) end
    return { item.title or "?", L["Click to open."] }
end

function R.ShowTooltip(btn)
    local item = btn.qcItem
    if not item then return end
    local lines = R.WedgeLines(item)
    local rest = {}
    for i = 2, #lines do rest[#rest + 1] = lines[i] end
    NS.PadRender.ShowLines(btn, lines[1], rest)
end

--- Build a wedge's regions and hover hooks, once per button.
function R.DressWedge(btn)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetSize(DL.WEDGE - 12, DL.WEDGE - 12)
    btn.qcIcon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.qcLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.qcLock = btn:CreateTexture(nil, "OVERLAY")
    btn.qcLock:SetSize(14, 14)
    btn.qcLock:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    local lockTint = NS.Constants.GOLD
    mark(btn.qcLock, "lock", LOCK_ICON, lockTint.r, lockTint.g, lockTint.b)
    btn.qcDim = circle(btn, "OVERLAY", DL.WEDGE, 0, 0, 0, 0.55)
    btn.qcDim:Hide()
    btn.qcCool = circle(btn, "OVERLAY", DL.WEDGE, 0, 0, 0, 0.35)
    btn.qcCool:Hide()
    btn.qcFlash = circle(btn, "OVERLAY", DL.WEDGE, 1, 1, 1, 0.45)
    btn.qcFlash:Hide()
    local gold = NS.Constants.GOLD
    btn.qcGlow = circle(btn, "HIGHLIGHT", DL.WEDGE + 8, gold.r, gold.g, gold.b, 0.45)
    btn:HookScript("OnEnter", function(self)
        R.ShowTooltip(self)
        Glow.SetHover(self, true)
    end)
    btn:HookScript("OnLeave", function(self)
        GameTooltip:Hide()
        Glow.SetHover(self, false)
    end)
    return btn
end

-- The Icons tab's defaults, for a paint that names no config (IconStyle.Config of none).
local DEFAULT_LOOK

--- Show one ring item on a wedge: its icon, its label outside the disc (its `geo.anchor` point at
--- `geo.lx, geo.ly`, so it reads away from the dial) in the Labels tab's font, or none while labels
--- are off, a padlock when its callout is locked, and the dim veil when it sends nothing here. `icfg`
--- is the dial's Icons tab (IconStyle.Config; none is the defaults), `look` its R.Look.
function R.PaintWedge(btn, item, geo, icfg, look)
    btn.qcItem = item
    local slot = item.slot
    DEFAULT_LOOK = DEFAULT_LOOK or IS.Config(nil, "dial")
    icfg = icfg or DEFAULT_LOOK
    btn.qcIcon:SetTexture(item.icon or DEFAULT_ICON)
    btn.qcIcon:SetSize(icfg.size, icfg.size)
    IS.ApplyIcon(btn.qcIcon, icfg, NS.Library.IconTint(item.icon, item.iconColor))
    IS.PaintRing(btn, icfg)
    IS.IconFrame(btn)
    Glow.Bind(btn, icfg.glow, slot and slot.calloutId or item.title)
    look = look or R.Look()
    btn.qcLabel:ClearAllPoints()
    btn.qcLabel:SetPoint(geo.anchor or "CENTER", btn, "CENTER", geo.lx, geo.ly)
    NS.PadRender.ApplyFont(btn.qcLabel, look.font)
    btn.qcLabel:SetText(item.title or "?")
    btn.qcLabel:SetShown(look.show)
    btn.qcLock:SetShown(slot ~= nil and slot.lock ~= nil)
    local live = slot == nil or slot.line ~= nil or slot.selfText ~= nil or slot.reason == "testMode"
    btn.qcDim:SetShown(not live)
end

function R.RefreshLock(btn)
    local slot = btn.qcItem and btn.qcItem.slot
    btn.qcLock:SetShown(slot ~= nil and slot.lock ~= nil)
end

--- A send result on a wedge (spec §9.3): the pad's colors (NS.Constants.FLASH), red for a drop.
function R.Flash(btn, what)
    local c = NS.Constants.FLASH[what] or NS.Constants.FLASH.sent
    btn.qcFlash:SetVertexColor(c[1], c[2], c[3], 0.45)
    btn.qcFlash:Show()
end

function R.Unflash(btn)
    btn.qcFlash:Hide()
end

--- The guard's dim (spec §9.2).
function R.SetCooling(btn, on)
    btn.qcCool:SetShown(on and true or false)
end
