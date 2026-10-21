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
-- place gets an overlay set, ring.qcShine[j] = { mask, disc, bevel, rim, streak, bead, bloom1, bloom2 },
-- each layer made the first time a look draws it (none at None) and hidden when the look or the
-- slice count stops using it. Layers sit at BACKGROUND sublevels 3 to 6, over the fill (1) and the
-- highlight (2) and under the wedges' icons. Each look's recipe is the spec's "Dial slices". The
-- slice-shaped layers (the whole-disc art, the per-count rim, streak and bevel edge sets of
-- modules/Shine.lua) are placed by place(), as the fill is, so they follow the gap, the W/E layouts
-- and every count; the whole-disc art is cut to its slice by a MaskTexture of the slice's sector
-- (`mask`), placed the same way. Bevel is its own per-count edge set, turned with its slice, so every
-- slice wears the same bevel (owner, 2026-10-21). The sprites (Glass orb's bead on the slice's
-- inscribed circle, Fluid glass's two blooms across its outer part) sit at local points of the
-- slice's own frame, turned by its middle angle as place() turns the fill, and cut by its mask.

NS.DialSlices = NS.DialSlices or {}
local S = NS.DialSlices
local DL = NS.DialLayout

S.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\textures\\"
local SECTOR = S.MEDIA .. "dial-sector-%d"
S.DISC = S.MEDIA .. "dial-disc"   -- every filled circle the dial draws (tools/gen-dial-textures.py)
local FLAT = "Interface\\Buttons\\WHITE8x8"   -- a pill's straight middle
S.DIM = 0.4   -- an arrow at an end (the dots take the Paging tab's dot color)

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

local SHINE_KEYS = { "disc", "bevel", "rim", "streak", "bead", "bloom1", "bloom2" }
local SHINE_SUB = { disc = 3, bead = 3, bevel = 3, bloom1 = 3, bloom2 = 4, rim = 5, streak = 6 }
local MASKED = { disc = true, bloom1 = true, bloom2 = true, bead = true }
local BLACK = { 0, 0, 0 }

-- A sprite at local (x, out) of the slice's frame (x across, out along its outward axis), side `w`
-- (the art is square), each a fraction of the placed radius, turned `turn` radians counterclockwise.
local function sprite(x, out, w, turn)
    return { x = x, out = out, w = w, turn = turn or 0 }
end

-- The inscribed circle of one slice of n (center's distance from the apex, radius), in placed radii:
-- the whole disc for one slice.
local function inscribed(n)
    if n <= 1 then return 0, 1 end
    local s = math.sin(math.pi / n)
    return 1 / (1 + s), s / (1 + s)
end

--- Glass orb's sprite on a slice of n: the bead (its vignette, 3.5 p across its half), on the slice's
--- inscribed circle of center c and radius p, so the bulge keeps its shape at every count. The
--- mockup's specular spot and glow are gone (owner, 2026-10-21: they read as a dot on every slice).
function S.OrbSprites(n)
    local c, p = inscribed(n)
    return { bead = sprite(0, c, 7 * p) }
end

--- Fluid glass's two blooms on a slice of n (owner, 2026-10-21: the redesign): one square as wide as
--- the slice's chord at the rim (the whole disc for one or two slices), its top on the rim, so the
--- blooms' pink to mint gradient runs across the slice's outer part at every count.
function S.FluidSprites(n)
    local w = n <= 2 and 2 or 2 * math.sin(math.pi / n)
    local b = sprite(0, 1 - w / 2, w)
    return { bloom1 = b, bloom2 = b }
end

local FROST_RIM, FLUID_RIM = 0.35, 0.3

-- One look's layers on a slice of an n-slice ring (the spec's "Dial slices"): { key, texture, color,
-- level[, sprite] }, each level times the Strength alpha.
local function recipe(shine, n)
    local Sh, light, look = NS.Shine, shine.tint, shine.look
    local rim = Sh.Edge("rim", n)
    if look == "gloss" or look == "glossfade" then
        return { { "disc", Sh.Texture("dial", look), light, 1 }, { "rim", rim, BLACK, 0.6 } }
    elseif look == "orb" then
        return { { "bead", Sh.Texture("sprite", "bead"), light, 1, S.OrbSprites(n).bead },
            { "rim", rim, BLACK, 0.6 } }
    elseif look == "frost" then
        return { { "disc", Sh.Texture("dial", "frost"), light, 1 }, { "rim", rim, light, FROST_RIM },
            { "streak", Sh.Edge("streak", n), light, 1 } }
    elseif look == "fluid" then
        local sp = S.FluidSprites(n)
        return { { "bloom1", Sh.Texture("sprite", "fluid-bloom1"), shine.bloomA, 1, sp.bloom1 },
            { "bloom2", Sh.Texture("sprite", "fluid-bloom2"), shine.bloomB, 1, sp.bloom2 },
            { "rim", rim, light, FLUID_RIM } }
    elseif look == "bevel" then
        return { { "bevel", Sh.Edge("bevel", n), light, 1 } }
    elseif look == "rim" then
        return { { "disc", Sh.Texture("dial", "rim"), light, 0.3 }, { "rim", rim, light, 0.5 } }
    end
    return {}
end

-- Place j's mask `key` ("mask", its slice's sector): placed and turned as the fill; made on first use.
local function maskOf(ring, set, key, j, path)
    if not set[key] then
        set[key] = ring:CreateMaskTexture(nil, "BACKGROUND")
        set[key]:Hide()
    end
    set[key]:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    place(set[key], ring, j, ring.qcShape)
    set[key]:Show()
    return set[key]
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

-- A sprite on a slice at middle angle `a`: its local point turned by `a` (as place() turns the fill)
-- from the slice's placed apex, sized by the placed radius; the slice's mask cuts whatever reaches
-- past its edges.
local function placeSprite(t, ring, a, sp)
    local d = ring.qcShape.shift
    local r = (ring.qcShape.disc - 2 * d) / 2
    local x, y = sp.x * r, sp.out * r
    t:SetSize(sp.w * r, sp.w * r)
    t:ClearAllPoints()
    t:SetPoint("CENTER", ring, "CENTER", (d + y) * math.sin(a) + x * math.cos(a),
        (d + y) * math.cos(a) - x * math.sin(a))
    t:SetRotation(sp.turn - a)
end

-- One recipe layer `l` on place j (middle angle `a`) of an n-slice ring: its masks placed first, then
-- the layer, its texture placed (a sprite at its local point, else as the fill), tinted and faded by
-- Strength. Marks in `drawn` what it showed.
local function paintLayer(ring, set, j, a, n, l, alpha, drawn)
    local key = l[1]
    if MASKED[key] then
        maskOf(ring, set, "mask", j, S.SectorTexture(n))
        drawn.mask = true
    end
    local t = shineLayer(ring, set, key)
    t:SetTexture(l[2])
    if l[5] then placeSprite(t, ring, a, l[5]) else place(t, ring, j, ring.qcShape) end
    t:SetVertexColor(l[3][1], l[3][2], l[3][3], l[4] * alpha)
    t:Show()
    drawn[key] = true
end

-- Hide whatever of a set `drawn` does not name (its layers and its masks).
local function hideUnused(set, drawn)
    for _, key in ipairs(SHINE_KEYS) do
        if set[key] and not drawn[key] then set[key]:Hide() end
    end
    if set.mask and not drawn.mask then set.mask:Hide() end
end

-- Every place's overlay set in the dial's shine (R.Look's `shine`, NS.Shine.Resolve): the look's
-- layers on each of `spec.size` places; whatever the look, the count or None leaves unused is hidden.
local function paintShine(ring, spec, look)
    local shine = look.shine
    local on = type(shine) == "table" and shine.look ~= "none"
    local n = spec.size
    local layers = on and recipe(shine, n) or {}
    for j = 1, math.max(on and n or 0, #ring.qcShine) do
        local drawn = {}
        if on and j <= n then
            local set = ring.qcShine[j] or {}
            ring.qcShine[j] = set
            local a = middle(j, ring.qcShape.size, ring.qcShape.start)
            for _, l in ipairs(layers) do paintLayer(ring, set, j, a, n, l, shine.alpha, drawn) end
        end
        if ring.qcShine[j] then hideUnused(ring.qcShine[j], drawn) end
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
