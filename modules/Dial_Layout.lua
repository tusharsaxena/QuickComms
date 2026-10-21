local _, NS = ...
-- modules/Dial_Layout.lua — the Comms Dial's rings and geometry (spec §11.1, §11.3). PURE: plain
-- tables in, plain tables out; no frame and no client read.
--
-- THE RINGS. A dial plan's groups, in the dial's order, become a list of rings, each one page of at
-- most `size` items: a callout (kind "send", its baked slot) or a ring to open (kind "ring", the index
-- of its target). Categories (D2): the first ring holds the groups; a group's ring holds its callouts;
-- a group with children (a battleground node set, a user parent) holds its own callouts first, then
-- its nodes (a pinned node set: its own callouts as one more wedge), and each node's ring its
-- callouts. Flat: the first ring holds every callout, highest group first, a parent's own before its
-- nodes'. A ring with more items than wedges is paged (dial rework, 2026-10-21): plain pages of
-- `size`, turned by the arrows under the dial (and the wheel and the arrow keys), never a wedge of
-- their own; every page has the first page's parent, so the hub goes up a ring from any page. A dial
-- with one group to show opens straight on its ring (owner ruling R2, the only open-into since the
-- Open the dial on this group flag retired); with several it opens on the ring of groups.
--
-- THE WEDGE COUNT is the dial's slices: Auto (0, the default) gives each page one wedge per item, at
-- most 12; or a fixed 4, 6, 8 or 12, never grown and never changed by the gap. A ring that holds
-- rings takes at most 8 either way (spec §11.3: the number keys 1-8 reach every ring wedge). Auto
-- also fits its icons (dial polish, owner 2026-10-21): a page holds no more wedges than leave each
-- icon its size plus FIT_MARGIN of arc at the icon reach, less the Slice gap (AutoCap); past that the
-- ring pages. In Flat a node's callout is titled with its node ("INC · Lumber Mill"); the slot keeps
-- its own name.
--
-- THE PLACEMENT (dial polish, one rule for Auto and fixed counts): places are numbered clockwise from
-- W (START). On four places (Auto's three and four items, a fixed 4 with any count) the items take,
-- by count: one W; two W and E; three W, N and E; four W, N, E and S; an unused place is an empty
-- slice. Auto's one item is the whole disc and two are halves (W, E). Five places or more are evenly
-- spaced, the items filling places 1..k clockwise from W, the rest empty. The number keys 1-8 follow
-- item order whatever the places.
--
-- THE GEOMETRY. Wedges sit clockwise from the ring's `start` (W), on-axis first. Offsets are from
-- the hub's center, y up; the radius is the dial's (`dial.radius`, Geometry), and the disc leaves RIM
-- between a wedge's edge and its own. A node set's nodes are pinned to their compass winds (spec
-- §12.1): its ring takes eight wedges, whatever the dial's slices, and is never paged; each node sits
-- on its own wind (PinNodes), a middle node on the first wind left free clockwise from N, a free node
-- (one with no fixed place on the map: Our base, a flag map's carrier) on the first wind left after
-- those, and a wind with no node has no wedge. An item carries `wedge`, its place among the ring's
-- `size` (an unpinned one's from PageShape). The number keys pick the shown wedges in that order. A paged ring's arrows and page dots sit in one row under the disc (Nav).

NS.DialLayout = NS.DialLayout or {}
local DL = NS.DialLayout
local L = NS.L

DL.RADIUS  = 100                               -- a wedge's center from the hub's center, by default
DL.RADIUS_MIN, DL.RADIUS_MAX = 70, 180         -- the Ring radius row's range
DL.WEDGE   = 44                                -- a wedge button, square
DL.HUB     = 40                                -- the hub (the header button), by default (dial.hub.size)
DL.RIM     = 20                                -- from a wedge's outer edge to the disc's edge
DL.LABEL_GAP = 2                               -- a wedge's label starts this far past the wedge's edge
DL.LINE    = 14                                -- one line of label or title text
DL.POINTER = DL.HUB / 2 + 8                    -- the pointer's distance from the hub's center, by default
DL.DEAD    = 8                                 -- inside this, the pointer hides
DL.KEYS    = 8                                 -- the number keys 1-8 pick wedges
DL.AUTO    = 0                                 -- slices: one wedge per item, spread evenly
DL.MAX_SLICES = 12
DL.ARROW   = 24                                -- a page arrow, square, by default (the Paging tab)
DL.START   = 270                               -- an unpinned page's place 1: W
DL.FIT_MARGIN = 4                              -- Auto leaves each icon this much more arc (AutoCap)

local SLICE_OK = { [DL.AUTO] = true, [4] = true, [6] = true, [8] = true, [12] = true }
local WINDS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

--- The eight winds' wedges on a pinned ring; a node in the middle of the map has DL.MIDDLE.
DL.WIND_INDEX = { N = 1, NE = 2, E = 3, SE = 4, S = 5, SW = 6, W = 7, NW = 8 }
DL.MIDDLE = "middle"
--- A node with no fixed place on the map (bg subgroups): it takes a wind left over by every node with a
--- wind and every middle one, so a set's own wedge keeps its place when such nodes are added.
DL.FREE = "free"

local function round(x) return math.floor(x * 100 + 0.5) / 100 end

--- A dial's slices: Auto (0), 4, 6, 8 or 12; anything else is Auto.
function DL.ClampSlices(v)
    if SLICE_OK[v] then return v end
    return DL.AUTO
end

--- A dial's ring radius: a number in the row's range, else the default.
function DL.ClampRadius(v)
    v = tonumber(v)
    if not v then return DL.RADIUS end
    return math.max(DL.RADIUS_MIN, math.min(DL.RADIUS_MAX, v))
end

--- The dial's measures at `radius`, with labels `line` pixels tall (0: no labels; nil: DL.LINE)
--- anchored `reach` pixels from the center (the Label offset; nil or 0: just past the disc's edge)
--- and the ring title `titleLine` pixels tall (the Group labels tab's line; 0: no title; nil:
--- DL.LINE): the disc's diameter, the labels' reach, the ring title's height above the center (its
--- bottom, over the N wedge's label and the disc, so none overlap), the title's top (`top`: a tooltip
--- above the dial starts over it) and how far below the center the S wedge's label and the disc end
--- (`below`: the page row starts under it, Nav).
function DL.Geometry(radius, line, reach, titleLine)
    radius = DL.ClampRadius(radius)
    line = tonumber(line) or DL.LINE
    local edge = radius + DL.WEDGE / 2 + DL.RIM
    reach = tonumber(reach)
    if not reach or reach <= 0 then reach = edge + DL.LABEL_GAP end
    local label = line > 0 and math.max(edge, reach + line) or edge
    titleLine = math.max(0, tonumber(titleLine) or DL.LINE)
    return { radius = radius, disc = 2 * edge, reach = reach, title = label + 4, top = label + 4 + titleLine,
        below = label }
end

--- A ring's page length: the dial's fixed slices, or under Auto 12 (at most `cap`, AutoCap's icon
--- fit, when given); at most 8 on a ring that holds a ring.
function DL.PageSize(slices, hasChildren, cap)
    slices = DL.ClampSlices(slices)
    local most = hasChildren and DL.KEYS or DL.MAX_SLICES
    if slices == DL.AUTO then return math.min(most, tonumber(cap) or DL.MAX_SLICES) end
    return math.min(slices, most)
end

-- Four places' items by count (the owner's sheet): W; W, E; W, N, E; W, N, E, S.
local FOUR = { { 1 }, { 1, 3 }, { 1, 2, 3 }, { 1, 2, 3, 4 } }

--- One page's wedges: its wedge count, where place 1 sits (degrees clockwise from N: always START,
--- W) and each item's place (`places[i]`, 1-based, clockwise from `start`). A fixed count keeps its
--- page size; Auto has one wedge per item, but three items take a four-wedge ring (S empty). Four
--- places take their items by count (FOUR); more are filled in order from W.
--- @return number size, number start, number[] places
function DL.PageShape(slices, pageSize, count)
    count = math.max(1, tonumber(count) or 1)
    local size = pageSize
    if DL.ClampSlices(slices) == DL.AUTO then size = count == 3 and 4 or count end
    local places = {}
    if size == 4 and FOUR[count] then
        for i, place in ipairs(FOUR[count]) do places[i] = place end
    else
        for i = 1, count do places[i] = i end
    end
    return size, DL.START, places
end

--- How far a slice moves out along its bisector so neighbors on a ring of n stand `gap` pixels
--- apart (the exploded pie, dial polish): (gap / 2) / sin(pi / n); none for one slice or no gap.
function DL.SliceShift(gap, n)
    gap, n = tonumber(gap) or 0, tonumber(n) or 1
    if n <= 1 or gap <= 0 then return 0 end
    return (gap / 2) / math.sin(math.pi / n)
end

--- Auto's icon fit: the most wedges (1..MAX_SLICES) whose arc at the icon reach (IconReach of
--- `radius` and the Icon offset `at`), less the Slice `gap`, still holds an icon of `iconSize` plus
--- FIT_MARGIN; one when none do.
function DL.AutoCap(radius, at, iconSize, gap)
    local around = 2 * math.pi * DL.IconReach(radius, at)
    local need = (tonumber(iconSize) or 0) + DL.FIT_MARGIN
    gap = tonumber(gap) or 0
    for n = DL.MAX_SLICES, 1, -1 do
        if around / n - gap >= need then return n end
    end
    return 1
end

--- Whether a point `dist` from the center is on the hub (`hub` across): inside its circle, the round
--- shape it is drawn. The ring's catcher takes the hub's clicks there and the tracker hovers it.
function DL.InHub(dist, hub)
    return (tonumber(dist) or 0) <= (tonumber(hub) or 0) / 2
end

--- The slice of a ring of `size` (place 1 at `start` degrees) under a point at bearing `angle`
--- (radians clockwise from N), `dist` from the center: its index when the point is past the hub's
--- circle (`hub` across, DL.InHub) and on the disc (`disc` across), else nil. Angle only: a point in a
--- slice gap belongs to the slice whose angle it is in. The one function the tracker and the catcher
--- agree on; whether the place holds an item is the caller's check.
function DL.SliceAt(angle, dist, size, start, hub, disc)
    dist = tonumber(dist) or 0
    angle = tonumber(angle) or 0
    if DL.InHub(dist, hub) or dist > (tonumber(disc) or 0) / 2 then return nil end
    size = math.max(1, tonumber(size) or 1)
    local step = 2 * math.pi / size
    local from = math.rad(tonumber(start) or 0) - step / 2
    return math.floor(((angle - from) % (2 * math.pi)) / step) + 1
end

--- Split `items` into pages of `size`, the last holding the rest.
--- @return table[] pages
function DL.Paginate(items, size)
    items = type(items) == "table" and items or {}
    size = math.max(1, tonumber(size) or 1)
    local pages = {}
    for i = 1, math.max(#items, 1), size do
        local page = {}
        for k = i, math.min(i + size - 1, #items) do page[#page + 1] = items[k] end
        pages[#pages + 1] = page
    end
    return pages
end

--- The Paging tab's measures when a dial names none (defaults/PadStyle.lua DialPage's).
DL.PAGING = { arrowSize = DL.ARROW, arrowGap = 10, dotSize = 6, pillWidth = 18, dotGap = 6, offset = 6 }

--- A paged ring's row under the dial (`g`, a Geometry), showing page `current` of `pages`, measured
--- by the Paging tab (`pg`, DL.PAGING's fields): the row's height (`y`, from the hub's center, `offset`
--- under the S label and the disc), each indicator's x and width (the current page a pill,
--- `pillWidth` wide; the others dots), the indicators' width end to end (`total`), and the arrows'
--- x (right; left is its negative), `arrowGap` clear of the indicators.
function DL.Nav(pages, current, g, pg)
    pages = math.max(1, tonumber(pages) or 1)
    current = tonumber(current) or 1
    g = g or DL.Geometry()
    pg = pg or DL.PAGING
    local widths, total = {}, 0
    for p = 1, pages do
        widths[p] = p == current and pg.pillWidth or pg.dotSize
        total = total + widths[p] + (p > 1 and pg.dotGap or 0)
    end
    local dots, x = {}, -total / 2
    for p = 1, pages do
        dots[p] = round(x + widths[p] / 2)
        x = x + widths[p] + pg.dotGap
    end
    local tall = math.max(pg.arrowSize, pg.dotSize)
    return { y = round(-(g.below + pg.offset + tall / 2)), bottom = round(-(g.below + pg.offset + tall)),
        dots = dots, widths = widths, total = total, arrow = round(total / 2 + pg.arrowGap + pg.arrowSize / 2) }
end

--- The icons' distance from the center: the Icon offset `at` when it is set (above 0), else the ring
--- radius.
function DL.IconReach(radius, at)
    at = tonumber(at)
    if at and at > 0 then return at end
    return DL.ClampRadius(radius)
end

--- The pointer's distance from the hub's center for a pointer `size` pixels across: just outside
--- the hub, `hub` pixels across (DL.HUB when none: the Hub size row, dial polish).
function DL.PointerReach(size, hub)
    return (tonumber(hub) or DL.HUB) / 2 + (tonumber(size) or 16) / 2 + 2
end

-- A label reads outward from the disc (owner, 2026-10-21: wholly outside it): its anchor sits on the
-- circle just past the disc's edge (or at the Label offset), on the wedge's own bearing. A wedge toward the east has its
-- label's LEFT edge there, toward the west its RIGHT edge; at N and S (within about 17 degrees of the
-- vertical) its BOTTOM or TOP edge. A long name then runs away from the dial, never over it.
local SIDEWAYS = 0.3

local function labelAnchor(sx, sy)
    if sx > SIDEWAYS then return "LEFT" end
    if sx < -SIDEWAYS then return "RIGHT" end
    if sy >= 0 then return "BOTTOM" end
    return "TOP"
end

--- Wedge i of n on a ring whose wedge 1 sits `start` degrees clockwise from N: its angle (radians
--- clockwise from N), its center, and its label's anchor point (`anchor`, the label's own point) and
--- offset from the wedge's center (`lx`, `ly`), `reach` pixels from the dial's center (as Geometry:
--- nil or 0 is just past the disc's edge); the wedge itself sits `at` from the center (IconReach:
--- nil or 0 is the radius).
function DL.Wedge(i, n, radius, start, reach, at)
    n = math.max(1, tonumber(n) or 4)
    radius = DL.ClampRadius(radius)
    local a = math.rad(tonumber(start) or 0) + (i - 1) * 2 * math.pi / n
    local sx, sy = math.sin(a), math.cos(a)
    local out = DL.Geometry(radius, nil, reach).reach
    at = DL.IconReach(radius, at)
    local x, y = round(at * sx), round(at * sy)
    return { angle = a, x = x, y = y, anchor = labelAnchor(sx, sy), lx = round(out * sx) - x, ly = round(out * sy) - y }
end

--- Wedge i of n (wedge 1 at `start` degrees) as the nearest of the eight compass winds, or past eight
--- wedges as its clock position ("12", "1", ... "11"), since the winds would give two wedges one word.
function DL.Direction(i, n, start)
    n = math.max(1, tonumber(n) or 4)
    local deg = ((tonumber(start) or 0) + (i - 1) * 360 / n) % 360
    if n > #WINDS then
        local hour = math.floor(deg / 30 + 0.5) % 12
        return tostring(hour == 0 and 12 or hour)
    end
    return WINDS[math.floor(deg / 45 + 0.5) % 8 + 1]
end

--- The pointer from the hub's center (cx, cy) toward the cursor (mx, my), both in screen units: its
--- angle (clockwise from N) and its offset from the hub's center, `reach` out (DL.POINTER when none).
--- Nil inside the dead zone.
function DL.Pointer(cx, cy, mx, my, reach)
    local dx, dy = (mx or 0) - (cx or 0), (my or 0) - (cy or 0)
    local d = math.sqrt(dx * dx + dy * dy)
    if d < DL.DEAD then return nil end
    reach = tonumber(reach) or DL.POINTER
    return math.atan2(dx, dy), round(reach * dx / d), round(reach * dy / d)
end

-- ── the rings ───────────────────────────────────────────────────────────────────────────────

-- `node`: the node's title, for a Flat ring, where the node's own ring is gone.
local function sendEntries(slots, node)
    local out = {}
    for i, slot in ipairs(slots or {}) do
        local title = slot.name
        if node then title = L["%s · %s"]:format(tostring(slot.name), node) end
        out[i] = { kind = "send", slot = slot, title = title, icon = slot.icon, iconColor = slot.iconColor }
    end
    return out
end

-- `src`: the group (or node) the ring is, for its title, icon and icon color.
local function ringEntry(src, entries, pinned)
    return { kind = "ring", title = src.title, icon = src.icon, iconColor = src.iconColor,
        sub = { title = src.title, entries = entries, pinned = pinned } }
end

--- A node set's nodes on their compass winds (spec §12.1): each entry's `wind` (N, NE … NW, or
--- DL.MIDDLE or DL.FREE) names its wedge on an eight-wedge ring; a middle node takes the first wind
--- left free, clockwise from N, and a free node the first left after every middle one. Answers the entries, each given its `wedge`, in wedge order; nil when they cannot
--- all be pinned (a node with no wind or an unknown one, two on one wind, none, or more than eight).
--- @return table[]|nil
function DL.PinNodes(entries)
    if type(entries) ~= "table" or #entries == 0 or #entries > 8 then return nil end
    local taken, middle, loose = {}, {}, {}
    for _, e in ipairs(entries) do
        local w = DL.WIND_INDEX[e.wind]
        if w and taken[w] then return nil end
        if w then
            taken[w] = e
        elseif e.wind == DL.MIDDLE then
            middle[#middle + 1] = e
        elseif e.wind == DL.FREE then
            loose[#loose + 1] = e
        else
            return nil
        end
    end
    local free = 1
    for _, list in ipairs({ middle, loose }) do
        for _, e in ipairs(list) do
            while taken[free] do free = free + 1 end
            taken[free] = e
        end
    end
    local out = {}
    for w = 1, 8 do
        if taken[w] then
            taken[w].wedge = w
            out[#out + 1] = taken[w]
        end
    end
    return out
end

-- A group's entry on the first ring (Categories), or nil when nothing under it can be shown. A node
-- set's nodes are pinned to their winds when every one of them has one; its own callouts (a
-- battleground's map-wide ones, groups polish) then take one wedge of their own, titled and drawn as
-- the set, on the first wind left free (as a middle node does). Otherwise a parent's own callouts come
-- first, then its nodes, on a ring of the dial's slices.
local function groupEntry(g)
    if type(g.children) == "table" then
        local nodes = {}
        for _, c in ipairs(g.children) do
            if #(c.slots or {}) > 0 then
                local node = ringEntry(c, sendEntries(c.slots))
                node.wind = c.compass
                nodes[#nodes + 1] = node
            end
        end
        local own = sendEntries(g.slots)
        local wedges = { unpack(nodes) }
        if #own > 0 then
            local general = ringEntry(g, own)
            general.wind = DL.MIDDLE
            wedges[#wedges + 1] = general
        end
        local pinned = #nodes > 0 and DL.PinNodes(wedges)
        if pinned then return ringEntry(g, pinned, true) end
        if #own > 0 then
            for _, node in ipairs(nodes) do own[#own + 1] = node end
            return ringEntry(g, own)
        end
        if #nodes == 0 then return nil end
        return ringEntry(g, nodes)
    end
    if #(g.slots or {}) == 0 then return nil end
    return ringEntry(g, sendEntries(g.slots))
end

-- Every callout, highest group first, a node set's nodes in order (Flat).
local function flatEntries(groups)
    local out = {}
    for _, g in ipairs(groups) do
        local lists = { { slots = g.slots } }
        if type(g.children) == "table" then
            for _, c in ipairs(g.children) do lists[#lists + 1] = { slots = c.slots, node = c.title } end
        end
        for _, list in ipairs(lists) do
            for _, e in ipairs(sendEntries(list.slots, list.node)) do out[#out + 1] = e end
        end
    end
    return out
end

--- A dial's rings, and the ring it opens on (0: nothing to show).
--- @param groups table the dial's active groups in its order (see the Interfaces block of Task 3)
--- @param opts table { mode = "categories"|"flat", slices, title, fit = { radius, iconOffset, iconSize,
---   gap } } (fit: Auto's icon-fit cap, AutoCap; nil: no cap)
--- @return table rings, number openRing
function DL.Rings(groups, opts)
    groups = type(groups) == "table" and groups or {}
    opts = type(opts) == "table" and opts or {}
    local slices = DL.ClampSlices(opts.slices)
    local fit = type(opts.fit) == "table" and opts.fit
    local cap = fit and DL.AutoCap(fit.radius, fit.iconOffset, fit.iconSize, fit.gap)
    local rings = {}

    -- A ring's pages: a pinned ring (a node set's, PinNodes) is one page of eight wedges from N; any
    -- other is paged at the dial's page size (PageSize), each page shaped by PageShape, its items
    -- given their places.
    local function pagesOf(entries, pinned)
        if pinned then return { { items = entries, size = 8, start = 0 } } end
        local hasChildren = false
        for _, e in ipairs(entries) do
            if e.kind == "ring" then hasChildren = true end
        end
        local out = {}
        local pageSize = DL.PageSize(slices, hasChildren, cap)
        for p, items in ipairs(DL.Paginate(entries, pageSize)) do
            local size, start, places = DL.PageShape(slices, pageSize, #items)
            for i, item in ipairs(items) do item.wedge = places[i] end
            out[p] = { items = items, size = size, start = start }
        end
        return out
    end

    -- Add `entries` as one ring (and its pages) under `parent`; then each ring entry's own ring.
    -- Returns the index of the first page.
    local function addRing(title, entries, parent, pinned)
        local pages = pagesOf(entries, pinned)
        local first = #rings + 1
        for p, page in ipairs(pages) do
            local idx = #rings + 1
            rings[idx] = { title = title, page = p, pages = #pages, size = page.size, start = page.start,
                items = page.items, parent = parent, prev = p > 1 and idx - 1 or 0, next = 0 }
            if p > 1 then rings[idx - 1].next = idx end
        end
        for r = first, first + #pages - 1 do
            for _, item in ipairs(rings[r].items) do
                if item.sub then
                    item.target = addRing(item.sub.title, item.sub.entries, r, item.sub.pinned)
                    item.sub = nil
                end
            end
        end
        return first
    end

    local title = opts.title or L["Comms Dial"]
    if opts.mode == "flat" then
        local entries = flatEntries(groups)
        if #entries == 0 then return rings, 0 end
        addRing(title, entries, 0)
        return rings, 1
    end
    local entries = {}
    for _, g in ipairs(groups) do
        entries[#entries + 1] = groupEntry(g)
    end
    if #entries == 0 then return rings, 0 end
    addRing(title, entries, 0)
    -- Owner ruling R2: a single group opens straight on its ring; several open on the ring of groups.
    if #entries == 1 then return rings, entries[1].target end
    return rings, 1
end
