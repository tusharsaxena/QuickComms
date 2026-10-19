local _, NS = ...
-- modules/Dial_Layout.lua — the Comms Dial's rings and geometry (spec §11.1, §11.3). PURE: plain
-- tables in, plain tables out; no frame and no client read.
--
-- THE RINGS. A dial plan's groups, in the dial's order, become a list of rings, each one page of at
-- most `size` items: a callout (kind "send", its baked slot) or a ring to open (kind "ring", the index
-- of its target). Categories (D2): the first ring holds the groups; a group's ring holds its callouts;
-- a group with children (a battleground node set, a user parent) holds its own callouts first, then
-- its nodes (a pinned node set: its own callouts as one more wedge), and each node's ring its callouts. Flat: the first ring holds every callout, highest
-- group first, a parent's own before its nodes'. A ring with more items than wedges is paged: each
-- page but the last holds size - 1 items and a More wedge to the next page, and a later page's parent
-- and previous are the page before it (the hub and the wheel go back). Open-into (D9): when the first
-- group has the flag, or is the only group (owner ruling R2), the dial opens on its ring and the hub
-- goes up to the group ring. The wedge count is the dial's slices, never grown; 12 only on a ring with
-- no children (spec §11.3), and a More wedge is a child, so such a ring gets 8. In Flat a node's
-- callout is titled with its node ("INC 3 · Lumber Mill"); the slot keeps its own name.
--
-- DEPTH (spec §11.3: depth 2; depth 3 allowed, with the editor warning). Each ring records its depth,
-- 1 for the first ring, a later page keeping its first page's. DeepGroups names the node sets whose
-- callouts sit three rings deep: a set's ring at depth 2, holding node rings, that is not the ring the
-- dial opens on (open-into skips the group ring, so a set it opens into is depth 2).
--
-- THE GEOMETRY. Wedges sit clockwise from N, on-axis first: four are N, E, S and W. Offsets are from
-- the hub's center, y up. A node set's nodes are pinned to their compass winds (spec §12.1): its ring
-- takes eight wedges, whatever the dial's slices, and is never paged; each node sits on its own wind
-- (PinNodes), a middle node on the first wind left free clockwise from N, and a wind with no node has
-- no wedge. An item carries `wedge`, its place among the ring's `size`; an unpinned item's place is
-- its index. The number keys pick the shown wedges clockwise from N.

NS.DialLayout = NS.DialLayout or {}
local DL = NS.DialLayout
local L = NS.L

DL.RADIUS  = 92                                -- a wedge's center from the hub's center
DL.WEDGE   = 44                                -- a wedge button, square
DL.HUB     = 40                                -- the hub (the header button)
DL.LABEL_GAP = 2                               -- a wedge's label starts this far past the wedge's edge
DL.LINE    = 14                                -- one line of label or title text
DL.DISC    = 2 * (DL.RADIUS + DL.WEDGE / 2 + 8)
-- The ring's title, from the ring's center: above the N wedge's label, so the two never overlap.
DL.TITLE   = DL.RADIUS + DL.WEDGE / 2 + DL.LABEL_GAP + DL.LINE + 4
DL.POINTER = DL.HUB / 2 + 8                    -- the pointer's distance from the hub's center
DL.DEAD    = 8                                 -- inside this, the pointer hides
DL.KEYS    = 8                                 -- the number keys 1-8 pick wedges

local SLICE_OK = { [4] = true, [6] = true, [8] = true, [12] = true }
local WINDS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

--- The eight winds' wedges on a pinned ring; a node in the middle of the map has DL.MIDDLE.
DL.WIND_INDEX = { N = 1, NE = 2, E = 3, SE = 4, S = 5, SW = 6, W = 7, NW = 8 }
DL.MIDDLE = "middle"

local function round(x) return math.floor(x * 100 + 0.5) / 100 end

--- A dial's slices: 4, 6, 8 or 12; anything else is the default 4.
function DL.ClampSlices(v)
    if SLICE_OK[v] then return v end
    return 4
end

--- A ring's wedge count: the dial's slices, but 8 on a 12-slice dial for a ring that holds a ring.
function DL.RingSize(slices, hasChildren)
    slices = DL.ClampSlices(slices)
    if slices == 12 and hasChildren then return 8 end
    return slices
end

--- Split `items` into pages of `size`: every page but the last keeps size - 1 items, leaving the last
--- wedge for More.
--- @return table[] pages
function DL.Paginate(items, size)
    items = type(items) == "table" and items or {}
    if #items <= size then return { items } end
    local pages, i, per = {}, 1, size - 1
    while #items - i + 1 > size do
        local page = {}
        for k = i, i + per - 1 do page[#page + 1] = items[k] end
        pages[#pages + 1] = page
        i = i + per
    end
    local last = {}
    for k = i, #items do last[#last + 1] = items[k] end
    pages[#pages + 1] = last
    return pages
end

-- A label reads outward from its wedge: a wedge toward the east has its label's LEFT edge just past the
-- wedge's right edge, toward the west its RIGHT edge past the left one; at N and S (within about 17
-- degrees of the vertical) its BOTTOM or TOP edge, past the top or bottom. A long name then runs away
-- from the wedge, never back over its icon.
local SIDEWAYS = 0.3

local function labelAnchor(sx, sy)
    local edge = DL.WEDGE / 2 + DL.LABEL_GAP
    if sx > SIDEWAYS then return "LEFT", edge, 0 end
    if sx < -SIDEWAYS then return "RIGHT", -edge, 0 end
    if sy >= 0 then return "BOTTOM", 0, edge end
    return "TOP", 0, -edge
end

--- Wedge i of n: its angle (radians clockwise from N), its center, and its label's anchor point
--- (`anchor`, the label's own point) and offset from the wedge's center (`lx`, `ly`).
function DL.Wedge(i, n, radius)
    n = math.max(1, tonumber(n) or 4)
    radius = radius or DL.RADIUS
    local a = (i - 1) * 2 * math.pi / n
    local sx, sy = math.sin(a), math.cos(a)
    local anchor, lx, ly = labelAnchor(sx, sy)
    return { angle = a, x = round(radius * sx), y = round(radius * sy), anchor = anchor, lx = lx, ly = ly }
end

--- The spoke between wedge j and wedge j + 1 of n: its center, rotation and length.
function DL.Spoke(j, n)
    n = math.max(1, tonumber(n) or 4)
    local a = (j - 0.5) * 2 * math.pi / n
    local inner, outer = DL.HUB / 2 + 4, DL.DISC / 2 - 4
    local mid = (inner + outer) / 2
    return { x = round(mid * math.sin(a)), y = round(mid * math.cos(a)), rotation = -a, length = outer - inner }
end

--- Wedge i of n as the nearest of the eight compass winds, or past eight wedges (12) as its clock
--- position ("12", "1", ... "11"), since the winds would give two wedges one word.
function DL.Direction(i, n)
    n = math.max(1, tonumber(n) or 4)
    local deg = (i - 1) * 360 / n
    if n > #WINDS then
        local hour = math.floor(deg / 30 + 0.5) % 12
        return tostring(hour == 0 and 12 or hour)
    end
    return WINDS[math.floor(deg / 45 + 0.5) % 8 + 1]
end

--- The pointer from the hub's center (cx, cy) toward the cursor (mx, my), both in screen units: its
--- angle (clockwise from N) and its offset from the hub's center. Nil inside the dead zone.
function DL.Pointer(cx, cy, mx, my)
    local dx, dy = (mx or 0) - (cx or 0), (my or 0) - (cy or 0)
    local d = math.sqrt(dx * dx + dy * dy)
    if d < DL.DEAD then return nil end
    return math.atan2(dx, dy), round(DL.POINTER * dx / d), round(DL.POINTER * dy / d)
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
--- DL.MIDDLE) names its wedge on an eight-wedge ring, and a middle node takes the first wind left free,
--- clockwise from N. Answers the entries, each given its `wedge`, in wedge order; nil when they cannot
--- all be pinned (a node with no wind or an unknown one, two on one wind, none, or more than eight).
--- @return table[]|nil
function DL.PinNodes(entries)
    if type(entries) ~= "table" or #entries == 0 or #entries > 8 then return nil end
    local taken, middle = {}, {}
    for _, e in ipairs(entries) do
        local w = DL.WIND_INDEX[e.wind]
        if w and taken[w] then return nil end
        if w then
            taken[w] = e
        elseif e.wind == DL.MIDDLE then
            middle[#middle + 1] = e
        else
            return nil
        end
    end
    local free = 1
    for _, e in ipairs(middle) do
        while taken[free] do free = free + 1 end
        taken[free] = e
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
--- @param opts table { mode = "categories"|"flat", slices, title }
--- @return table rings, number openRing
function DL.Rings(groups, opts)
    groups = type(groups) == "table" and groups or {}
    opts = type(opts) == "table" and opts or {}
    local slices = DL.ClampSlices(opts.slices)
    local rings = {}

    -- A ring's wedge count and pages: a pinned ring (a node set's, PinNodes) has eight wedges and one
    -- page; any other has the dial's slices (RingSize), its items paged behind More.
    local function shape(entries, pinned)
        if pinned then return 8, { entries } end
        local hasChildren = #entries > slices
        for _, e in ipairs(entries) do
            if e.kind == "ring" then hasChildren = true end
        end
        local size = DL.RingSize(slices, hasChildren)
        return size, DL.Paginate(entries, size)
    end

    -- Add `entries` as one ring (and its pages) under `parent`, at `depth`; then each ring entry's
    -- own ring, one deeper. Returns the index of the first page.
    local function addRing(title, entries, parent, depth, pinned)
        local size, pages = shape(entries, pinned)
        local first = #rings + 1
        for p, items in ipairs(pages) do
            local idx = #rings + 1
            rings[idx] = { title = title, page = p, pages = #pages, size = size, items = items, depth = depth,
                parent = p == 1 and parent or idx - 1, prev = p > 1 and idx - 1 or 0, next = 0 }
            if p > 1 then
                local before = rings[idx - 1]
                before.next = idx
                before.items[#before.items + 1] = { kind = "ring", target = idx, title = L["More"], more = true }
            end
        end
        for r = first, first + #pages - 1 do
            for _, item in ipairs(rings[r].items) do
                if item.sub then
                    item.target = addRing(item.sub.title, item.sub.entries, r, depth + 1, item.sub.pinned)
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
        addRing(title, entries, 0, 1)
        return rings, 1
    end
    local entries, first = {}, nil
    for _, g in ipairs(groups) do
        local e = groupEntry(g)
        if e then
            entries[#entries + 1] = e
            first = first or { entry = e, openInto = g.openInto == true }
        end
    end
    if #entries == 0 then return rings, 0 end
    addRing(title, entries, 0, 1)
    -- Owner ruling R2: a single group opens straight on its ring, as open-into does.
    if first.openInto or #entries == 1 then return rings, first.entry.target end
    return rings, 1
end

--- The node sets whose callouts sit three rings deep (spec §11.3: allowed, with the editor
--- warning): each ring at depth 2, first page only, that holds a ring other than More and is not the
--- ring the dial opens on. Their titles, in ring order.
--- @return string[]
function DL.DeepGroups(rings, openRing)
    local out = {}
    for r, ring in ipairs(type(rings) == "table" and rings or {}) do
        if ring.depth == 2 and ring.page == 1 and r ~= openRing then
            for _, item in ipairs(ring.items) do
                if item.kind == "ring" and not item.more then
                    out[#out + 1] = ring.title
                    break
                end
            end
        end
    end
    return out
end
