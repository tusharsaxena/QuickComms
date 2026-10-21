local addonName, NS = ...
-- modules/Dial_Slices.lua — the Comms Dial's slices (the Slices tab, 2026-10-21). INSECURE visuals
-- only, as modules/Dial_Render.lua's: textures on a ring container, which the client lets an addon
-- color, turn and show in combat; the header's snippets show and hide the ring itself.
--
-- A ring is drawn as its slices: one fill per wedge place (`spec.size` of them, an empty place
-- included, so a three-item Auto ring still reads as four quarters), each a tinted pie-slice texture
-- (media/textures/dial-sector-<n>.tga, written by tools/gen-dial-textures.py; one slice is the whole
-- disc, dial-disc.tga) turned onto its place about the ring's center. No lines are drawn between
-- slices (the Slices tab's Border retired, dial polish 2026-10-21): the Slice gap parts them instead,
-- an "exploded pie": each fill moves out along its own bisector by DL.SliceShift(gap, size) and
-- shrinks to the disc's radius less that shift, so its rim stays on the disc and its straight edges
-- sit gap/2 off the spoke line (one slice has no gap). The slice the cursor points into takes the
-- highlight fill, moved and sized as its slice (Track, from the pointer's per-frame update, which
-- also hovers the wedge on it: its tooltip and hover glow, since the wedges take no mouse). A paged
-- ring's page row holds a pill for its own page and a dot (the disc) for each other one, under the disc
-- (DL.Nav); the arrows either side are secure buttons modules/Dial.lua places. Each indicator has a
-- border, a larger copy of its own texture behind it in the border color, and the row sits on a
-- rounded background (dial polish, 2026-10-21). The pill, its border and the background are each
-- three pieces (crisp dial art, 2026-10-21): the disc's left half, a flat WHITE8x8 middle stretched
-- across and the disc's right half, so the round ends stay round at any width.
--
-- THE SHINE (shine overlay, 2026-10-21; the Slices tab's Shine heading, R.Look's `shine`): each
-- place gets an overlay set, ring.qcShine[j] = { disc, mask, rim, soft, spot, glow, streak, bloom1,
-- bloom2 }, each layer made the first time a look draws it (none at None) and hidden when the look
-- or the slice count stops using it. Layers sit at BACKGROUND sublevels 3 to 6, over the fill (1) and
-- the highlight (2) and under the wedges' icons. The slice-shaped layers (the whole-disc art, the
-- per-count rim and soft edge sets of modules/Shine.lua) are placed by place(), as the fill is, so
-- they follow the gap, the W/E layouts and every count; the whole-disc art is cut to its slice by a
-- MaskTexture of the slice's sector, placed the same way (Bevel's art stays upright: one light
-- direction for the whole dial, only its mask turns). The sprites sit at local points of the slice's
-- own frame (y down, the slice pointing up), turned by its middle angle as place() turns the fill.

NS.DialSlices = NS.DialSlices or {}
local S = NS.DialSlices
local DL = NS.DialLayout

S.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\textures\\"
local SECTOR = S.MEDIA .. "dial-sector-%d"
S.DISC = S.MEDIA .. "dial-disc"   -- every filled circle the dial draws (tools/gen-dial-textures.py)
local FLAT = "Interface\\Buttons\\WHITE8x8"   -- a pill's straight middle
S.DIM = 0.4   -- a dot for a page not shown, and an arrow at an end

--- The texture for one slice of an n-slice ring: the whole disc for one.
function S.SectorTexture(n)
    n = math.floor(tonumber(n) or 1)
    if n <= 1 then return S.DISC end
    return SECTOR:format(math.min(n, DL.MAX_SLICES))
end

-- Slice j's middle, radians clockwise from N, on a ring of `size` starting at `start` degrees.
local function middle(j, size, start)
    return math.rad(tonumber(start) or 0) + (j - 1) * 2 * math.pi / size
end

local function texture(ring, layer, sub)
    local t = ring:CreateTexture(nil, layer, nil, sub)
    t:Hide()
    return t
end

-- The n-th texture of `list`, made on first use.
local function nth(ring, list, n, layer, sub)
    list[n] = list[n] or texture(ring, layer, sub)
    return list[n]
end

-- The disc's left or right half, a pill's round cap.
local function cap(ring, layer, sub, right)
    local t = texture(ring, layer, sub)
    t:SetTexture(S.DISC)
    t:SetTexCoord(right and 0.5 or 0, right and 1 or 0.5, 0, 1)
    return t
end

-- The two caps of indicator p (or of its border), in `list`, made on first use.
local function capsOf(ring, list, p, sub)
    list[p] = list[p] or { left = cap(ring, "OVERLAY", sub, false), right = cap(ring, "OVERLAY", sub, true) }
    return list[p]
end

--- Build a ring container's slice textures, once per container: the fills, the highlight, the shine's
--- per-place overlay sets (qcShine, each layer made on first use), the page
--- indicators and their borders (each list grown on first use; an indicator's body in qcDots or
--- qcDotEdges, a pill's round caps in qcDotCaps or qcDotEdgeCaps), and the indicators' background
--- (its left cap, middle and right cap, under the borders, which sit under the indicators).
function S.Dress(ring)
    if ring.qcSlicesDressed then return ring end
    ring.qcSlicesDressed = true
    ring.qcFills, ring.qcDots, ring.qcDotEdges = {}, {}, {}
    ring.qcDotCaps, ring.qcDotEdgeCaps = {}, {}
    ring.qcDotBack = { left = cap(ring, "OVERLAY", -2, false), mid = texture(ring, "OVERLAY", -2),
        right = cap(ring, "OVERLAY", -2, true) }
    ring.qcDotBack.mid:SetTexture(FLAT)
    ring.qcHighlight = texture(ring, "BACKGROUND", 2)
    ring.qcShine = {}
    return ring
end

local function tint(t, c)
    t:SetVertexColor(c.r, c.g, c.b, c.a)
end

-- Slice j's texture placed on its ring of `shape` (size, start, disc, shift): moved out along its
-- bisector by the shift, shrunk so its rim stays on the disc, and turned onto its place.
local function place(t, ring, j, shape)
    local a, d = middle(j, shape.size, shape.start), shape.shift
    local across = shape.disc - 2 * d
    t:SetSize(across, across)
    t:ClearAllPoints()
    t:SetPoint("CENTER", ring, "CENTER", d * math.sin(a), d * math.cos(a))
    t:SetRotation(-a)
end

-- Every fill: the slice's texture, the dial's disc across less the gap's shift, on its place.
local function paintFills(ring, spec, look)
    local shape = ring.qcShape
    for j = 1, math.max(spec.size, #ring.qcFills) do
        local t = nth(ring, ring.qcFills, j, "BACKGROUND", 1)
        if j <= spec.size then
            t:SetTexture(S.SectorTexture(spec.size))
            place(t, ring, j, shape)
            tint(t, look.fill)
            t:Show()
        else
            t:Hide()
        end
    end
    ring.qcHighlight:SetTexture(S.SectorTexture(spec.size))
    tint(ring.qcHighlight, look.highlight)
    ring.qcHighlight:Hide()
end

-- ── the shine overlay ──────────────────────────────────────────────────────────────────────────

local SHINE_KEYS = { "disc", "rim", "soft", "spot", "glow", "streak", "bloom1", "bloom2" }
local SHINE_SUB = { disc = 3, soft = 3, bloom1 = 3, bloom2 = 4, glow = 4, rim = 5, streak = 6, spot = 6 }
local MASKED = { disc = true, bloom1 = true, bloom2 = true }
local BLACK, WHITE = { 0, 0, 0 }, { 1, 1, 1 }
local BEVEL_LIGHT = math.rad(315)   -- Bevel's light comes from the top left

-- A sprite at local (x, y) of the slice's frame, w by h, each a fraction of its placed radius, turned
-- `turn` radians counterclockwise in that frame.
local function sprite(x, y, w, h, turn)
    return { x = x, y = y, w = w, h = h, turn = turn or 0 }
end

-- One look's layers on a slice of an n-slice ring at middle angle `a` (the spec's "Dial slices"):
-- { key, texture, color, level[, sprite][, upright] }, each level times the Strength alpha.
local function recipe(shine, n, a)
    local Sh, light, look = NS.Shine, shine.tint, shine.look
    local rim, soft = Sh.Edge("rim", n), Sh.Edge("soft", n)
    if look == "gloss" then
        return { { "disc", Sh.Texture("dial", "gloss"), light, 1 }, { "rim", rim, light, 0.30 } }
    elseif look == "orb" then
        return { { "soft", soft, BLACK, 0.50 },
            { "glow", Sh.Texture("sprite", "glow"), light, 0.45, sprite(0, -0.38, 0.5, 0.2) },
            { "spot", Sh.Texture("sprite", "spot"), light, 1, sprite(-0.24, -0.80, 0.34, 0.12, math.rad(22)) } }
    elseif look == "frost" then
        return { { "disc", FLAT, light, 0.09 }, { "rim", rim, light, 0.55 },
            { "streak", Sh.Texture("sprite", "streak"), light, 1, sprite(0, -0.95, 0.68, 0.05) } }
    elseif look == "fluid" then
        return { { "bloom1", Sh.Texture("dial", "fluid-bloom1"), shine.bloomA, 1 },
            { "bloom2", Sh.Texture("dial", "fluid-bloom2"), shine.bloomB, 1 }, { "rim", rim, light, 0.35 } }
    elseif look == "bevel" then
        local facing = math.cos(a - BEVEL_LIGHT)
        return { { "disc", Sh.Texture("dial", "bevel"), light, 1, nil, true },
            { "rim", rim, facing >= 0 and WHITE or BLACK, 0.25 + 0.45 * math.abs(facing) } }
    elseif look == "rim" then
        return { { "soft", soft, light, 0.35 }, { "rim", rim, light, 0.60 } }
    end
    return {}
end

-- Place j's mask: its slice's sector, placed and turned as the fill; made on first use.
local function maskOf(ring, set, j, n)
    if not set.mask then
        set.mask = ring:CreateMaskTexture(nil, "BACKGROUND")
        set.mask:Hide()
    end
    set.mask:SetTexture(S.SectorTexture(n), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    place(set.mask, ring, j, ring.qcShape)
    set.mask:Show()
    return set.mask
end

-- Layer `key` of a set, made on first use (a masked one cut by the set's mask).
local function shineLayer(ring, set, key)
    local t = set[key]
    if not t then
        t = texture(ring, "BACKGROUND", SHINE_SUB[key])
        t:SetBlendMode("BLEND")
        if MASKED[key] then t:AddMaskTexture(set.mask) end
        set[key] = t
    end
    return t
end

-- A sprite on slice j at middle angle `a`: its local point turned by `a` (as place() turns the fill)
-- from the slice's placed center, sized by the placed radius.
local function placeSprite(t, ring, a, sp)
    local d = ring.qcShape.shift
    local r = (ring.qcShape.disc - 2 * d) / 2
    local x, y = sp.x * r, -sp.y * r   -- the slice's frame is y down; the ring's is y up
    t:SetSize(sp.w * r, sp.h * r)
    t:ClearAllPoints()
    t:SetPoint("CENTER", ring, "CENTER", d * math.sin(a) + x * math.cos(a) + y * math.sin(a),
        d * math.cos(a) - x * math.sin(a) + y * math.cos(a))
    t:SetRotation(sp.turn - a)
end

-- Every place's overlay set in the dial's shine (R.Look's `shine`, NS.Shine.Resolve): the look's
-- layers on each of `spec.size` places; whatever the look, the count or None leaves unused is hidden.
local function paintShine(ring, spec, look)
    local shine = look.shine
    local on = type(shine) == "table" and shine.look ~= "none"
    local n = spec.size
    for j = 1, math.max(on and n or 0, #ring.qcShine) do
        local drawn = {}
        if on and j <= n then
            local set = ring.qcShine[j] or {}
            ring.qcShine[j] = set
            local a = middle(j, ring.qcShape.size, ring.qcShape.start)
            for _, l in ipairs(recipe(shine, n, a)) do
                local key = l[1]
                if MASKED[key] then
                    maskOf(ring, set, j, n)
                    drawn.mask = true
                end
                local t = shineLayer(ring, set, key)
                t:SetTexture(l[2])
                if l[5] then placeSprite(t, ring, a, l[5]) else place(t, ring, j, ring.qcShape) end
                if l[6] then t:SetRotation(0) end
                t:SetVertexColor(l[3][1], l[3][2], l[3][3], l[4] * shine.alpha)
                t:Show()
                drawn[key] = true
            end
        end
        local set = ring.qcShine[j]
        if set then
            for _, key in ipairs(SHINE_KEYS) do
                if set[key] and not drawn[key] then set[key]:Hide() end
            end
            if set.mask and not drawn.mask then set.mask:Hide() end
        end
    end
end

-- A pill `w` by `h` centered at `x`, `y` in three pieces: `left` and `right` the disc's halves, each
-- half its height wide (so its ends are round), and `mid` the straight middle between them, `w - h`
-- wide (none when the pill is no wider than it is tall); `on` false hides them all.
local function paintPill(ring, left, mid, right, w, h, x, y, c, on)
    local inner = math.max(0, w - h)
    local function piece(t, px, width, shown)
        t:SetSize(width, h)
        t:ClearAllPoints()
        t:SetPoint("CENTER", ring, "CENTER", px, y)
        tint(t, c)
        t:SetShown(shown)
    end
    piece(left, x - inner / 2 - h / 4, h / 2, on)
    piece(mid, x, inner, on and inner > 0)
    piece(right, x + inner / 2 + h / 4, h / 2, on)
end

-- The indicators' background, `w` by `h` centered on the row at `y`, a pill; `on` false hides it.
local function paintBack(ring, on, w, h, y, c)
    local back = ring.qcDotBack
    paintPill(ring, back.left, back.mid, back.right, w, h, 0, y, c, on)
end

-- One indicator `d` with its caps (and its border `e` with its caps, `edge` pixels wider each side;
-- 0 hides it) at `x`, `y`: a pill (three pieces) when `pill`, else the disc (its caps hidden).
local function paintDot(ring, p, pill, w, h, x, y, c, edge, ec)
    local sets = { { ring.qcDots[p], capsOf(ring, ring.qcDotCaps, p, 0), 0, c, true },
        { ring.qcDotEdges[p], capsOf(ring, ring.qcDotEdgeCaps, p, -1), 2 * edge, ec, edge > 0 } }
    for _, set in ipairs(sets) do
        local t, caps, grow, color, on = set[1], set[2], set[3], set[4], set[5]
        if pill then
            t:SetTexture(FLAT)
            paintPill(ring, caps.left, t, caps.right, w + grow, h + grow, x, y, color, on)
        else
            t:SetTexture(S.DISC)
            t:SetSize(w + grow, h + grow)
            t:ClearAllPoints()
            t:SetPoint("CENTER", ring, "CENTER", x, y)
            tint(t, color)
            t:SetShown(on)
            caps.left:Hide()
            caps.right:Hide()
        end
    end
end

-- A paged ring's indicators (DL.Nav, the Paging tab): its own page a pill in the current color, the
-- others dots in the other color, each with its border, on the background (as wide and tall as the
-- row and its borders, plus the padding each side).
local function paintDots(ring, spec, look)
    local pages = (spec.pages or 1) > 1 and spec.pages or 0
    local pg = look.paging
    local nav = DL.Nav(math.max(pages, 1), spec.page, DL.Geometry(look.radius, look.line, look.labelReach), pg)
    local edge = pg.dotBorder or 0
    for p = 1, math.max(pages, #ring.qcDots) do
        local d = nth(ring, ring.qcDots, p, "OVERLAY")
        local e = nth(ring, ring.qcDotEdges, p, "OVERLAY", -1)
        if p <= pages then
            local current = p == spec.page
            paintDot(ring, p, current, nav.widths[p], pg.dotSize, nav.dots[p], nav.y,
                current and pg.current or pg.dot, edge, pg.dotBorderColor)
        else
            d:Hide()
            e:Hide()
            for _, caps in ipairs({ capsOf(ring, ring.qcDotCaps, p, 0), capsOf(ring, ring.qcDotEdgeCaps, p, -1) }) do
                caps.left:Hide()
                caps.right:Hide()
            end
        end
    end
    local pad = 2 * (edge + (pg.dotBackPadding or 0))
    paintBack(ring, pages > 0 and pg.dotBackShow == true, nav.total + pad, pg.dotSize + pad, nav.y,
        pg.dotBack or pg.plate)
end

--- Draw one ring's slices and page row in the dial's look (Dial_Render.Look), and keep its shape
--- for Track: the slice count, where wedge 1 sits, the disc, the gap's shift (DL.SliceShift), the
--- hub across (its Hub size: the tracker's inner edge) and which places hold a wedge.
function S.Paint(ring, spec, look)
    S.Dress(ring)
    local used = {}
    for i, item in ipairs(spec.items or {}) do used[item.wedge or i] = true end
    ring.qcShape = { size = spec.size, start = tonumber(spec.start) or 0, used = used,
        disc = DL.Geometry(look.radius, look.line, look.labelReach).disc,
        shift = DL.SliceShift(look.gap, spec.size), hub = look.hub and look.hub.size or DL.HUB }
    ring.qcLit = nil
    paintFills(ring, spec, look)
    paintShine(ring, spec, look)
    paintDots(ring, spec, look)
end

--- Light the slice the cursor points into: `angle` (radians clockwise from N) and `dist` (pixels)
--- from the hub's center. Past the hub's circle and inside the disc, the slice holding that bearing
--- (DL.SliceAt: angle only, so a point in a gap belongs to the slice whose angle it is in) lights
--- when a wedge sits on it; anywhere else (the hub's circle, past the rim, an empty place) none does. Answers
--- true, the slice lit before and the slice lit now when that changed (Dial_Render hovers the wedges
--- on them), else nothing.
function S.Track(ring, angle, dist)
    local shape, hl = ring.qcShape, ring.qcHighlight
    if not (shape and hl) then return end
    local j = DL.SliceAt(angle, dist, shape.size, shape.start, shape.hub, shape.disc)
    if j and not shape.used[j] then j = nil end
    local was = ring.qcLit
    if j == was then return end
    ring.qcLit = j
    if j then
        place(hl, ring, j, shape)
        hl:Show()
    else
        hl:Hide()
    end
    return true, was, j
end
