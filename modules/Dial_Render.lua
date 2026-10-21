local _, NS = ...
-- modules/Dial_Render.lua — what the Comms Dial shows (spec §11.1, §11.4). INSECURE visuals only:
-- textures and font strings on the dial's frames, their text, color and visibility, which the client
-- allows in combat; it never touches an attribute or a protected frame's geometry or visibility (the
-- header's snippets show and hide the rings; modules/Dial.lua sizes and places the frames, out of
-- combat). As modules/Pad_Render.lua dresses a pad's secure buttons, this dresses the dial's secure
-- frames: the hub (a backdrop disc and a circle mark in the Hub heading's style, R.PaintHubLook) and
-- the pointer on the header; a title (the Group labels tab's font), its slices (modules/Dial_Slices.lua)
-- and, on a paged ring, two page arrows on each ring; and on each wedge an icon (a glyph in its color,
-- no backdrop of its own since the dial rework, 2026-10-21), its label, a padlock, a dim veil when it
-- sends nothing, the guard's cooling veil and a result flash. The slice the cursor points into lights
-- whole (the Slices tab's Highlight) and is hovered, anywhere on the disc outside the hub's circle
-- (R.PointerUpdate); inside it the hub is hovered (its circle brightens and its "Why is this showing?"
-- tooltip shows, R.HoverHub), from the same update: the header takes no mouse (round hub, 2026-10-21).
-- The hub carries the stale hint, the lockdown chip and the test or preview label. The pointer is a plain (unprotected) child of the header that turns toward the
-- cursor, the Slices tab's glyph, size, color and offset: its OnUpdate is set when the header shows and
-- cleared when it hides, so a closed or stood-down dial runs nothing per frame (perf bucket
-- dialRender). Every tooltip the dial shows sits outside it, on the Slice labels tab's side, at its offset
-- (R.ShowTip). The Icons tab (B9) styles each wedge's icon through modules/IconStyle.lua and
-- modules/Glow.lua (the glow, whose On hover trigger the tracker drives: R.HoverWedge). A wedge takes
-- no mouse (dial polish, 2026-10-21): the slice the cursor points into is hovered (its wedge's
-- tooltip and glow) from the per-frame update, and clicked through the ring's secure catcher.

NS.DialRender = NS.DialRender or {}
local R = NS.DialRender
local DL = NS.DialLayout
local IS = NS.IconStyle
local Glow = NS.Glow
local Slices = NS.DialSlices
local L = NS.L
local Perf = NS.Perf

-- The hollow rings (crisp dial art, 2026-10-21): media/textures/dial-ring-<k>.tga, written by
-- tools/gen-dial-textures.py, ring k's line RING_STEPS[k] of its diameter, a geometric ladder from
-- 1.25% to 50% (about 1.4x per step). Every filled circle is Slices.DISC.
local RING = Slices.MEDIA .. "dial-ring-%d"
R.RING_STEPS = {}
for k = 1, 12 do R.RING_STEPS[k] = 0.0125 * (40 ^ ((k - 1) / 11)) end
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- The page arrows' chevrons and the pointer are catalog glyphs too (Phosphor Fill, `ph:`), with these
-- Blizzard fallbacks.
local ARROW_ICONS = { prev = { "ph:caret-left", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" },
    next = { "ph:caret-right", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" } }
local POINTER_GLYPH = "ph:caret-up"
-- The padlock is the shared catalog's `lock` mark (library-stack-§8), resolved at draw time; this
-- Blizzard texture is drawn only when the catalog answers nil (the library absent). The hub's red
-- close mark is retired (dial polish, 2026-10-21): the hub draws its Hub heading's style instead.
local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local POINTER_ICON = "Interface\\Minimap\\MinimapArrow"

-- One catalog mark on `tex`, tinted (the catalog art is white), or the Blizzard fallback untinted.
local function mark(tex, name, fallback, r, g, b)
    local path = NS.Icon(name)
    tex:SetTexture(path or fallback)
    if path then tex:SetVertexColor(r, g, b, 1) end
end

--- The ring texture for a ring `diameter` across with a `width` px line: the step whose line over
--- diameter is nearest width / diameter in log space, or the solid disc when the line is half the
--- diameter or more (nothing would be left hollow). Pure.
function R.RingTexture(diameter, width)
    diameter, width = tonumber(diameter) or 0, tonumber(width) or 0
    if diameter <= 0 or width >= diameter / 2 then return Slices.DISC end
    local frac = math.log(math.max(width, 0.001) / diameter)
    local best, gap = 1, math.huge
    for k, step in ipairs(R.RING_STEPS) do
        local d = math.abs(frac - math.log(step))
        if d < gap then best, gap = k, d end
    end
    return RING:format(best)
end

-- A round texture: the disc, tinted.
local function circle(frame, layer, size, r, g, b, a)
    local t = frame:CreateTexture(nil, layer)
    t:SetTexture(Slices.DISC)
    t:SetVertexColor(r, g, b, a)
    t:SetSize(size, size)
    t:SetPoint("CENTER", frame, "CENTER", 0, 0)
    return t
end

-- The ring on screen, among the ones the last rebuild loaded (header.qcRingFrames), or nil.
local function shownRing(header)
    for _, ring in ipairs(header.qcRingFrames or {}) do
        if ring:IsShown() then return ring end
    end
    return nil
end

-- Light the slice under (angle, dist) on `ring` and, when that changed, move the hover to its wedge.
local function track(ring, angle, dist)
    local changed, was, now = Slices.Track(ring, angle, dist)
    if changed then R.HoverWedge(ring, was, now) end
end

--- While the dial is open, every frame: the pointer toward the cursor (hidden inside the dead zone,
--- or when the Slices tab turns it off); the slice the cursor points into lit and hovered (its
--- wedge's tooltip and hover glow), anywhere on the disc outside the hub's circle (Slices.Track); and
--- inside that circle the hub hovered (R.HoverHub). A hover leaves before the next one enters, so the
--- tooltip is the one just entered.
function R.PointerUpdate(pointer)
    local t0 = Perf.on and debugprofilestop()
    local header = pointer.qcHeader
    local cx, cy = header:GetCenter()
    local scale = header:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local a, ox, oy = DL.Pointer((cx or 0) * scale, (cy or 0) * scale, mx, my, header.qcReach)
    local arrow = pointer.qcArrow
    if a and header.qcPointerOn ~= false then
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", header, "CENTER", ox, oy)
        arrow:SetRotation(-a)
        arrow:Show()
    else
        arrow:Hide()
    end
    if scale and scale > 0 then
        local dx, dy = (mx or 0) / scale - (cx or 0), (my or 0) / scale - (cy or 0)
        local dist = math.sqrt(dx * dx + dy * dy)
        local onHub = DL.InHub(dist, header.qcHubSize or DL.HUB)
        if not onHub then R.HoverHub(header, false) end
        local ring = shownRing(header)
        if ring then track(ring, math.atan2(dx, dy), dist) end
        if onHub then R.HoverHub(header, true) end
    end
    if t0 then Perf.Note("dialRender", debugprofilestop() - t0) end
end

-- The hub's circle mark at rest and hovered: its color's alpha times these (the hub is clickable, so
-- the circle brightens under the cursor).
local HUB_REST, HUB_LIT = 0.8, 1.0

-- The circle mark (the filled circle and the hollow ring) in the hub's circle color, lit or at
-- rest. Insecure textures only, so combat-safe.
local function tintCircle(header, lit)
    local c = header.qcHubCircle
    if not c then return end
    local a = c.a * (lit and HUB_LIT or HUB_REST)
    header.qcHubDot:SetVertexColor(c.r, c.g, c.b, a)
    header.qcHubRing:SetVertexColor(c.r, c.g, c.b, a)
end

--- The hub hovered (`on`) or left: its circle brightens and `header.qcHubEnter(header)` (the "Why is
--- this showing?" tooltip, from R.DressHub's `onEnter`) runs, or the circle dims and the tooltip hides.
--- The header takes no mouse (round hub, 2026-10-21), so R.PointerUpdate calls this, not an OnEnter.
--- Insecure: textures and the tooltip, combat-safe.
function R.HoverHub(header, on)
    on = on and true or false
    if (header.qcHubHovered == true) == on then return end
    header.qcHubHovered = on or nil
    tintCircle(header, on)
    if on then
        if header.qcHubEnter then header.qcHubEnter(header) end
    else
        GameTooltip:Hide()
    end
end

--- Build the hub's regions and the pointer, once per header. `onEnter(header)` runs on hover
--- (R.HoverHub, from the per-frame update inside the hub's circle). The hub
--- (its backdrop disc `qcHub`, the backdrop's rim `qcHubRim` and the hollow ring `qcHubRing`, each
--- one ring texture (R.RingTexture), and the filled circle `qcHubDot`), its labels and the pointer
--- sit on a plain, mouse-off frame above the rings (`qcPointer`, raised by R.RaiseFront), so the
--- slices never draw over them. The header takes no mouse: the ring's catcher takes the hub's clicks.
function R.DressHub(header, onEnter)
    if header.qcDressed then return header end
    header.qcDressed = true
    local front = CreateFrame("Frame", nil, header)
    front:SetAllPoints(header)
    front:EnableMouse(false)
    front.qcHeader = header
    header.qcPointer = front
    header.qcHub = circle(front, "BORDER", DL.HUB, 0.12, 0.12, 0.14, 0.95)
    header.qcHubRim = circle(front, "ARTWORK", DL.HUB, 1, 1, 1, 1)
    header.qcHubRim:Hide()
    header.qcHubRing = circle(front, "ARTWORK", 22, 1, 1, 1, 1)
    header.qcHubRing:Hide()
    header.qcHubDot = circle(front, "ARTWORK", 22, 1, 0.82, 0, 1)
    header.qcStale = front:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.qcStale:SetPoint("TOP", header, "BOTTOM", 0, -2)
    header.qcStale:SetText(L["updates after combat"])
    header.qcStale:Hide()
    header.qcLockdown = front:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    header.qcLockdown:SetPoint("BOTTOM", header, "TOP", 0, 2)
    header.qcLockdown:SetText(L["LOCKDOWN"])
    header.qcLockdown:Hide()
    header.qcTest = front:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    header.qcTest:SetPoint("BOTTOM", header.qcLockdown, "TOP", 0, 2)
    header.qcTest:Hide()
    front.qcArrow = front:CreateTexture(nil, "OVERLAY")
    front.qcArrow:SetTexture(NS.Icon(POINTER_GLYPH) or POINTER_ICON)
    front.qcArrow:Hide()
    header:HookScript("OnShow", function() front:SetScript("OnUpdate", R.PointerUpdate) end)
    header:HookScript("OnHide", function()
        front:SetScript("OnUpdate", nil)
        front.qcArrow:Hide()
        R.HoverHub(header, false)
        -- the snippet hid the rings first, so clear every one the rebuild loaded
        for _, ring in ipairs(header.qcRingFrames or {}) do track(ring, 0, 0) end
    end)
    header.qcHubEnter = onEnter
    header.qcHeader = header
    return header
end

--- Raise the hub's front frame over every ring and wedge (a rebuild may have made new ones), and
--- hand it the rings the pointer tracks. Insecure: a plain frame's level.
function R.RaiseFront(header, rings)
    header.qcRingFrames = rings
    header.qcPointer:SetFrameLevel((header:GetFrameLevel() or 0) + 20)
end

-- A color swatch through its class-color companion, as { r, g, b, a }.
local function color(c, useClass, fallback)
    local r, g, b, a = NS.ResolveColor(c or fallback, useClass)
    return { r = r, g = g, b = b, a = a }
end

local HUB_STYLES = { solid = true, ring = true, target = true, rimmed = true }

-- The hub's look from its Hub heading (`dial.hub`, defaults/PadStyle.lua's DialHub): the style, the
-- backdrop's size (the hub's geometry), the circle's size and line width, the backdrop's border
-- size, and the backdrop, border and circle colors resolved through their class-color companions.
local function hubLook(hub)
    hub = type(hub) == "table" and hub or {}
    local H = NS.PadDefaults.DialHub()
    local function n(k, lo) return math.max(lo, tonumber(hub[k]) or H[k]) end
    return { style = HUB_STYLES[hub.style] and hub.style or H.style, size = n("size", 1),
        circleSize = n("circleSize", 1), lineWidth = n("lineWidth", 1), borderSize = n("borderSize", 0),
        background = color(hub.background, hub.useClassColorBackground, H.background),
        border = color(hub.borderColor, hub.useClassColorBorder, H.borderColor),
        circle = color(hub.circleColor, hub.useClassColorCircle, H.circleColor) }
end

--- A dial's look for one rebuild: its radius (clamped); its Slice labels tab (`dial.label`) as a font
--- (Pad_Render.LabelFont), whether labels show, their line height (0 when they do not) and where
--- the tooltip goes; its Slices tab (`dial.slice`: the fill, the Slice gap in pixels, the highlight, and
--- the Hub tab's pointer) and Paging tab (`dial.page`, from `dial`: the indicators' background and border
--- included) with each color resolved through its class color companion; the hub (`dial.hub`, hubLook); the Group labels tab (`dial.title`, from `dial`)
--- as `title = { show, font, line }`, its line 0 while off; and the Icon offset (`dial.iconOffset`).
function R.Look(radius, label, slice, dial)
    label = type(label) == "table" and label or {}
    slice = type(slice) == "table" and slice or {}
    dial = type(dial) == "table" and dial or {}
    local page = type(dial.page) == "table" and dial.page or {}
    local D, P = NS.PadDefaults.DialSlice(), NS.PadDefaults.DialPage()
    local function n(k) return math.max(0, tonumber(page[k]) or P[k]) end
    local font = NS.PadRender.LabelFont(label)
    local show = label.show ~= false
    local tl = type(dial.title) == "table" and dial.title or NS.PadDefaults.DialTitle()
    local tfont, tshow = NS.PadRender.LabelFont(tl, NS.PadRender.TITLE_COLOR), tl.show ~= false
    return { radius = DL.ClampRadius(radius), font = font, show = show, line = show and font.size + 2 or 0,
        tipSide = label.tooltipSide or "top", tipOffset = tonumber(label.tooltipOffset) or 8,
        labelReach = math.max(0, tonumber(label.offset) or 0),
        fill = color(slice.background, slice.useClassColorBackground, D.background),
        gap = math.max(0, tonumber(slice.gap) or D.gap),
        highlight = color(slice.highlight, slice.useClassColorHighlight, D.highlight),
        pointerShow = slice.pointerShow ~= false, pointerSize = tonumber(slice.pointerSize) or D.pointerSize,
        pointerOffset = math.max(0, tonumber(slice.pointerOffset) or 0),
        pointer = color(slice.pointerColor, slice.useClassColorPointer, D.pointerColor),
        iconReach = math.max(0, tonumber(dial.iconOffset) or 0), hub = hubLook(dial.hub),
        title = { show = tshow, font = tfont, line = tshow and tfont.size + 2 or 0 },
        paging = { offset = n("offset"), arrowSize = math.max(8, n("arrowSize")), arrowGap = n("arrowGap"),
            dotSize = math.max(2, n("dotSize")), pillWidth = math.max(2, n("pillWidth")), dotGap = n("dotGap"),
            arrow = color(page.arrowColor, page.useClassColorArrow, P.arrowColor),
            plate = color(page.plateColor, page.useClassColorPlate, P.plateColor),
            current = color(page.currentColor, page.useClassColorCurrent, P.currentColor),
            dot = color(page.dotColor, page.useClassColorDot, P.dotColor),
            dotBackShow = page.dotBackShow ~= false, dotBackPadding = n("dotBackPadding"),
            dotBack = color(page.dotBackColor, page.useClassColorDotBack, P.dotBackColor),
            dotBorder = n("dotBorder"),
            dotBorderColor = color(page.dotBorderColor, page.useClassColorDotBorder, P.dotBorderColor) } }
end

--- The pointer in the dial's look: its size, color and reach (the Pointer offset from the hub's
--- center; 0 is just outside the hub); off, it is hidden (the per-frame update still lights slices).
function R.PaintPointer(header, look)
    local arrow = header.qcPointer.qcArrow
    arrow:SetSize(look.pointerSize, look.pointerSize)
    arrow:SetVertexColor(look.pointer.r, look.pointer.g, look.pointer.b, look.pointer.a)
    header.qcReach = look.pointerOffset > 0 and look.pointerOffset
        or DL.PointerReach(look.pointerSize, look.hub.size)
    header.qcPointerOn = look.pointerShow
    if not look.pointerShow then arrow:Hide() end
end

-- A ring texture `t`, `diameter` across with a `width` px line (R.RingTexture), in `c`; `on` false
-- (or no line) hides it.
local function paintRing(t, on, diameter, width, c)
    on = on and width > 0
    if on then
        t:SetTexture(R.RingTexture(diameter, width))
        t:SetSize(diameter, diameter)
        t:SetVertexColor(c.r, c.g, c.b, c.a)
    end
    t:SetShown(on)
end

--- The hub in the dial's look (R.Look's `hub`): the backdrop disc its size across in its color,
--- with a rim of its border size (any style; Rimmed disc at least 2), and the circle mark by style:
--- `solid` a filled circle of the circle size; `ring` a hollow ring of the circle size, line width
--- thick; `target` that ring and a dot of a quarter of it (at least 4); `rimmed` the filled circle.
--- The circle rests dimmer and brightens while the hub is hovered.
function R.PaintHubLook(header, look)
    local hub = (look or R.Look()).hub
    local b = hub.background
    header.qcHub:SetSize(hub.size, hub.size)
    header.qcHub:SetVertexColor(b.r, b.g, b.b, b.a)
    local style, cs = hub.style, hub.circleSize
    local rim = style == "rimmed" and math.max(hub.borderSize, 2) or hub.borderSize
    paintRing(header.qcHubRim, rim > 0, hub.size, rim, hub.border)
    local ringed = style == "ring" or style == "target"
    paintRing(header.qcHubRing, ringed, cs, hub.lineWidth, hub.circle)
    local dot = style == "target" and math.max(4, cs / 4) or cs
    header.qcHubDot:SetSize(dot, dot)
    header.qcHubDot:SetShown(style ~= "ring")
    header.qcHubCircle = hub.circle
    header.qcHubSize = hub.size
    tintCircle(header, header.qcHubHovered == true)
end

--- Where the dial's tooltips go (the Slice labels tab's side and offset): outside the dial, clear of
--- the ring title above it (its own line height, or none while Group labels are off), the page row below it, or the widest label at either side. `labelWidth` is
--- the widest label the rebuild drew (0 with none). Kept on the header for R.ShowTip.
function R.PlaceTips(header, look, labelWidth)
    local g = DL.Geometry(look.radius, look.line, look.labelReach, look.title.line)
    local off, side = look.tipOffset, look.tipSide
    local at
    if side == "bottom" then
        at = { "TOP", 0, DL.Nav(1, 1, g, look.paging).bottom - off }
    elseif side == "left" or side == "right" then
        local x = math.max(g.disc / 2, look.show and g.reach + labelWidth or 0) + off
        at = side == "left" and { "RIGHT", -x, 0 } or { "LEFT", x, 0 }
    else
        at = { "BOTTOM", 0, g.top + off }
    end
    header.qcTipAt = at
end

--- A dial tooltip for `owner` (a wedge, an arrow or the hub), at the place R.PlaceTips keeps on its
--- header; above the owner when there is none yet.
function R.ShowTip(owner, title, lines)
    local header = owner.qcHeader
    local at = header and header.qcTipAt
    if not at then return NS.PadRender.ShowLines(owner, title, lines) end
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint(at[1], header, "CENTER", at[2], at[3])
    GameTooltip:SetText(title)
    for _, line in ipairs(lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    GameTooltip:Show()
end

--- The hub's labels: the lockdown chip, the stale hint, and TEST MODE or PREVIEW.
function R.PaintHub(header, state)
    header.qcLockdown:SetShown(state.lockdown == true)
    header.qcStale:SetShown(state.stale == true)
    header.qcTest:SetShown(state.testText ~= nil)
    header.qcTest:SetText(state.testText or "")
end

--- Build a ring container's title (drawn in the Group labels tab's font by R.PaintRing) and slices,
--- once per container.
function R.DressRing(ring)
    if ring.qcDressed then return ring end
    ring.qcDressed = true
    ring.qcTitle = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Slices.Dress(ring)
    -- A ring the snippets hide (a page turn, a group wedge, the hub going up) drops its hover: the
    -- tracker reads only the ring on screen. Insecure and attribute-free, so combat-safe.
    ring:HookScript("OnHide", function(self) track(self, 0, 0) end)
    return ring
end

--- Build a page arrow, once per button: a round plate in the slices' fill with a chevron on it, and
--- its tooltip. `side` is "prev" or "next".
function R.DressArrow(btn, side)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcSide = side
    btn.qcPlate = circle(btn, "BACKGROUND", DL.ARROW, 0.06, 0.06, 0.08, 0.80)
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetPoint("CENTER", btn, "CENTER", side == "prev" and -1 or 1, 0)
    btn.qcIcon:SetTexture(NS.Icon(ARROW_ICONS[side][1]) or ARROW_ICONS[side][2])
    btn:HookScript("OnEnter", function(self)
        if not self.qcLive then return end
        local h = self.qcLook and self.qcLook.highlight
        if h then self.qcPlate:SetVertexColor(h.r, h.g, h.b, math.max(h.a, 0.5)) end
        R.ShowTip(self, side == "prev" and L["Previous page"] or L["Next page"],
            { L["The Left and Right arrow keys and the mouse wheel turn pages too."] })
    end)
    btn:HookScript("OnLeave", function(self)
        R.PaintArrow(self, self.qcLive, self.qcLook)
        GameTooltip:Hide()
    end)
    return btn
end

--- A page arrow live (its chevron in the Paging tab's arrow color: a page lies that way) or dimmed
--- (at an end), on a plate in the tab's plate color, at the tab's arrow size.
function R.PaintArrow(btn, live, look)
    btn.qcLive = live and true or false
    btn.qcLook = look
    local pg = (look or R.Look()).paging
    btn.qcPlate:SetSize(pg.arrowSize, pg.arrowSize)
    btn.qcIcon:SetSize(math.floor(pg.arrowSize * 0.58 + 0.5), math.floor(pg.arrowSize * 0.58 + 0.5))
    local f = pg.plate
    btn.qcPlate:SetVertexColor(f.r, f.g, f.b, f.a)
    local c, dim = pg.arrow, Slices.DIM
    if live then btn.qcIcon:SetVertexColor(c.r, c.g, c.b, c.a) else btn.qcIcon:SetVertexColor(dim, dim, dim, 0.6) end
end

--- A ring's title: its name, and its page when it has several ("Arathi Basin (1 of 2)").
function R.RingTitle(spec)
    if (spec.pages or 1) > 1 then return L["%s (%d of %d)"]:format(spec.title or "", spec.page, spec.pages) end
    return spec.title or ""
end

--- Show one ring's slices (modules/Dial_Slices.lua: the fills and the page row) and its title over
--- the N wedge's label, in the dial's look (R.Look): the Group labels tab's font, or no title while
--- Show group labels is off.
function R.PaintRing(ring, spec, look)
    look = look or R.Look()
    Slices.Paint(ring, spec, look)
    local title = ring.qcTitle
    title:ClearAllPoints()
    title:SetPoint("BOTTOM", ring, "CENTER", 0,
        DL.Geometry(look.radius, look.line, look.labelReach, look.title.line).title)
    NS.PadRender.ApplyFont(title, look.title.font)
    title:SetText(R.RingTitle(spec))
    title:SetShown(look.title.show)
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
    R.ShowTip(btn, lines[1], rest)
end

--- Build a wedge's regions, once per button.
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
    return btn
end

--- A wedge hovered: its tooltip and its On hover glow. The wedges take no mouse (dial polish,
--- 2026-10-21), so the tracker calls this, not an OnEnter.
function R.EnterWedge(btn)
    R.ShowTooltip(btn)
    Glow.SetHover(btn, true)
end

--- A wedge no longer hovered: the tooltip hidden, its hover glow off.
function R.LeaveWedge(btn)
    GameTooltip:Hide()
    Glow.SetHover(btn, false)
end

--- The hover moved on `ring` from place `was` to place `now` (either nil: the hub's circle, past the rim, an
--- empty place): the wedge left first, then the one entered.
function R.HoverWedge(ring, was, now)
    local wedges = ring.qcPlaceWedge or {}
    if was and wedges[was] then R.LeaveWedge(wedges[was]) end
    if now and wedges[now] then R.EnterWedge(wedges[now]) end
end

-- The Icons tab's defaults, for a paint that names no config (IconStyle.Config of none).
local DEFAULT_LOOK

--- Show one ring item on a wedge: its icon, its label outside the disc (its `geo.anchor` point at
--- `geo.lx, geo.ly`, so it reads away from the dial) in the Slice labels tab's font, or none while labels
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
