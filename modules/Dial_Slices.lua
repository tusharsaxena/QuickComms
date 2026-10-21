local addonName, NS = ...
-- modules/Dial_Slices.lua — the Comms Dial's slices (the Slices tab, 2026-10-21). INSECURE visuals
-- only, as modules/Dial_Render.lua's: textures on a ring container, which the client lets an addon
-- color, turn and show in combat; the header's snippets show and hide the ring itself.
--
-- A ring is drawn as its slices: one fill per wedge place (`spec.size` of them, an empty place
-- included, so a three-item Auto ring still reads as four quarters), each a tinted pie-slice texture
-- (media/textures/dial-sector-<n>.tga, written by tools/gen-dial-textures.py; one slice is the whole
-- disc, the round mask) turned onto its place about the ring's center. No lines are drawn between
-- slices (the Slices tab's Border retired, dial polish 2026-10-21): the Slice gap parts them instead,
-- an "exploded pie": each fill moves out along its own bisector by DL.SliceShift(gap, size) and
-- shrinks to the disc's radius less that shift, so its rim stays on the disc and its straight edges
-- sit gap/2 off the spoke line (one slice has no gap). The slice the cursor points into takes the
-- highlight fill, moved and sized as its slice (Track, from the pointer's per-frame update, which
-- also hovers the wedge on it: its tooltip and hover glow, since the wedges take no mouse). A paged
-- ring's page row holds a pill for its own page and a dot for each other one, under the disc
-- (DL.Nav); the arrows either side are secure buttons modules/Dial.lua places.

NS.DialSlices = NS.DialSlices or {}
local S = NS.DialSlices
local DL = NS.DialLayout

local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\textures\\"
local SECTOR = MEDIA .. "dial-sector-%d"
S.PILL = MEDIA .. "dial-pill"
S.DIM = 0.4   -- a dot for a page not shown, and an arrow at an end

--- The texture for one slice of an n-slice ring: the whole disc for one.
function S.SectorTexture(n)
    n = math.floor(tonumber(n) or 1)
    if n <= 1 then return CIRCLE end
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

--- Build a ring container's slice textures, once per container: the fills, the highlight and the
--- page indicators, each list grown on first use.
function S.Dress(ring)
    if ring.qcSlicesDressed then return ring end
    ring.qcSlicesDressed = true
    ring.qcFills, ring.qcDots = {}, {}
    ring.qcHighlight = texture(ring, "BACKGROUND", 2)
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

-- A paged ring's indicators (DL.Nav, the Paging tab): its own page a pill in the current color, the
-- others dots in the other color.
local function paintDots(ring, spec, look)
    local pages = (spec.pages or 1) > 1 and spec.pages or 0
    local pg = look.paging
    local nav = DL.Nav(math.max(pages, 1), spec.page, DL.Geometry(look.radius, look.line, look.labelReach), pg)
    for p = 1, math.max(pages, #ring.qcDots) do
        local d = nth(ring, ring.qcDots, p, "OVERLAY")
        if p <= pages then
            local current = p == spec.page
            d:SetTexture(current and S.PILL or CIRCLE)
            d:SetSize(nav.widths[p], pg.dotSize)
            d:ClearAllPoints()
            d:SetPoint("CENTER", ring, "CENTER", nav.dots[p], nav.y)
            tint(d, current and pg.current or pg.dot)
            d:Show()
        else
            d:Hide()
        end
    end
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
    paintDots(ring, spec, look)
end

--- Light the slice the cursor points into: `angle` (radians clockwise from N) and `dist` (pixels)
--- from the hub's center. Outside the hub and inside the disc, the slice holding that bearing
--- (DL.SliceAt: angle only, so a point in a gap belongs to the slice whose angle it is in) lights
--- when a wedge sits on it; anywhere else (the hub, past the rim, an empty place) none does. Answers
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
