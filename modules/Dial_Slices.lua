local addonName, NS = ...
-- modules/Dial_Slices.lua — the Comms Dial's slices (the Slices tab, 2026-10-21). INSECURE visuals
-- only, as modules/Dial_Render.lua's: textures on a ring container, which the client lets an addon
-- color, turn and show in combat; the header's snippets show and hide the ring itself.
--
-- A ring is drawn as its slices: one fill per wedge place (`spec.size` of them, an empty place
-- included, so a three-item Auto ring still reads as four quarters), each a tinted pie-slice texture
-- (media/textures/dial-sector-<n>.tga, written by tools/gen-dial-textures.py; one slice is the whole
-- disc, the round mask) turned onto its place about the ring's center. The border is lines: a spoke
-- between each pair of slices and the rim as DL.ARC straight segments, each `borderSize` thick (0
-- draws none). The hovered wedge's slice takes the highlight fill (Highlight, from the wedge's hover
-- hooks). A paged ring's page row holds a pill for its own page and a dot for each other one, under
-- the disc (DL.Nav); the arrows either side are secure buttons modules/Dial.lua places.

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

--- Build a ring container's slice textures, once per container: the fills, the highlight, the
--- spokes, the rim and the page indicators, each list grown on first use.
function S.Dress(ring)
    if ring.qcSlicesDressed then return ring end
    ring.qcSlicesDressed = true
    ring.qcFills, ring.qcSpokes, ring.qcRim, ring.qcDots = {}, {}, {}, {}
    ring.qcHighlight = texture(ring, "BACKGROUND", 2)
    return ring
end

local function tint(t, c)
    t:SetVertexColor(c.r, c.g, c.b, c.a)
end

-- Every fill: the slice's texture, the dial's disc across, turned onto its place.
local function paintFills(ring, spec, look)
    local disc = DL.Geometry(look.radius, look.line, look.labelReach).disc
    for j = 1, math.max(spec.size, #ring.qcFills) do
        local t = nth(ring, ring.qcFills, j, "BACKGROUND", 1)
        if j <= spec.size then
            t:SetTexture(S.SectorTexture(spec.size))
            t:SetSize(disc, disc)
            t:ClearAllPoints()
            t:SetPoint("CENTER", ring, "CENTER", 0, 0)
            t:SetRotation(-middle(j, spec.size, spec.start))
            tint(t, look.fill)
            t:Show()
        else
            t:Hide()
        end
    end
    ring.qcHighlight:SetTexture(S.SectorTexture(spec.size))
    ring.qcHighlight:SetSize(disc, disc)
    ring.qcHighlight:ClearAllPoints()
    ring.qcHighlight:SetPoint("CENTER", ring, "CENTER", 0, 0)
    tint(ring.qcHighlight, look.highlight)
    ring.qcHighlight:Hide()
end

-- One straight line of the border, centered at (x, y), turned by `rotation` from the vertical.
local function line(t, ring, x, y, rotation, length, thick, c)
    t:SetColorTexture(c.r, c.g, c.b, c.a)
    t:ClearAllPoints()
    t:SetPoint("CENTER", ring, "CENTER", x, y)
    t:SetSize(thick, length)
    t:SetRotation(rotation)
    t:Show()
end

-- The spokes (from the hub's edge to the rim, between slices) and the rim's segments.
local function paintBorder(ring, spec, look)
    local thick = look.borderSize
    local outer = DL.Geometry(look.radius, look.line, look.labelReach).disc / 2
    local spokes = (thick > 0 and spec.size > 1) and spec.size or 0
    for j = 1, math.max(spokes, #ring.qcSpokes) do
        local t = nth(ring, ring.qcSpokes, j, "BORDER")
        if j <= spokes then
            local a = middle(j, spec.size, spec.start) + math.pi / spec.size
            local inner = DL.HUB / 2
            local mid = (inner + outer) / 2
            line(t, ring, mid * math.sin(a), mid * math.cos(a), -a, outer - inner, thick, look.border)
        else
            t:Hide()
        end
    end
    local arcs = thick > 0 and DL.ARC or 0
    local r = outer - thick / 2
    local chord = 2 * r * math.sin(math.pi / DL.ARC) + 1   -- one pixel over, so no seam shows
    for k = 1, math.max(arcs, #ring.qcRim) do
        local t = nth(ring, ring.qcRim, k, "BORDER")
        if k <= arcs then
            local a = (k - 0.5) * 2 * math.pi / DL.ARC
            -- a rim segment runs along the circle: across its radius, so a quarter turn more
            line(t, ring, r * math.sin(a), r * math.cos(a), -a + math.pi / 2, chord, thick, look.border)
        else
            t:Hide()
        end
    end
end

-- A paged ring's indicators: its own page a gold pill, the others gray dots (DL.Nav).
local function paintDots(ring, spec, look)
    local pages = (spec.pages or 1) > 1 and spec.pages or 0
    local nav = DL.Nav(math.max(pages, 1), look.radius, look.line, spec.page, look.labelReach)
    local gold = NS.Constants.GOLD
    for p = 1, math.max(pages, #ring.qcDots) do
        local d = nth(ring, ring.qcDots, p, "OVERLAY")
        if p <= pages then
            local current = p == spec.page
            d:SetTexture(current and S.PILL or CIRCLE)
            d:SetSize(nav.widths[p], DL.DOT)
            d:ClearAllPoints()
            d:SetPoint("CENTER", ring, "CENTER", nav.dots[p], nav.y)
            if current then d:SetVertexColor(gold.r, gold.g, gold.b, 1) else d:SetVertexColor(S.DIM, S.DIM, S.DIM, 0.9) end
            d:Show()
        else
            d:Hide()
        end
    end
end

--- Draw one ring's slices, border and page row in the dial's look (Dial_Render.Look), and keep its
--- shape for Track: the slice count, where wedge 1 sits, the disc and which places hold a wedge.
function S.Paint(ring, spec, look)
    S.Dress(ring)
    local used = {}
    for i, item in ipairs(spec.items or {}) do used[item.wedge or i] = true end
    ring.qcShape = { size = spec.size, start = tonumber(spec.start) or 0, used = used,
        disc = DL.Geometry(look.radius, look.line, look.labelReach).disc }
    ring.qcLit = nil
    paintFills(ring, spec, look)
    paintBorder(ring, spec, look)
    paintDots(ring, spec, look)
end

--- Light the slice the cursor points into: `angle` (radians clockwise from N) and `dist` (pixels)
--- from the hub's center. Outside the hub and inside the disc, the slice holding that bearing lights
--- when a wedge sits on it; anywhere else (the hub, past the rim, an empty place) none does.
function S.Track(ring, angle, dist)
    local shape, hl = ring.qcShape, ring.qcHighlight
    if not (shape and hl) then return end
    local j
    if dist > DL.HUB / 2 and dist <= shape.disc / 2 then
        local step = 2 * math.pi / shape.size
        local from = math.rad(shape.start) - step / 2
        j = math.floor(((angle - from) % (2 * math.pi)) / step) + 1
        if not shape.used[j] then j = nil end
    end
    if j == ring.qcLit then return end
    ring.qcLit = j
    if j then
        hl:SetRotation(-middle(j, shape.size, shape.start))
        hl:Show()
    else
        hl:Hide()
    end
end
