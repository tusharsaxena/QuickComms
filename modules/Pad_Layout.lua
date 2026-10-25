local _, NS = ...
-- modules/Pad_Layout.lua — the Comms Pad's geometry and look decisions (spec §10.2, §10.3). PURE:
-- plain tables in, plain tables out; no frame and no client read. Coordinates are offsets from the
-- pad root's TOPLEFT with y growing down; modules/Pad.lua flips y for SetPoint. The cell placement
-- copies KickCD modules/IconGrid_Layout.lua `Layout.layoutBlock` (row-major cells, an axis mirrored
-- for leftward or upward growth). Growth is two orthogonal choices, as KickCD's IconGrid keeps
-- anchor and grow apart: left mirrors the buttons, up puts the header row at the pad's bottom and
-- stacks the sections up from it, and the pad is pinned by its growth edge (EdgePoint) so a resize
-- grows away from the drag strip. The visibility expression copies ConsumableMaster
-- core/MacroBarModel.lua `BM.ResolveVisibility` (a constant or one [combat] state-driver
-- expression, never an insecure Show/Hide in combat).

NS.PadLayout = NS.PadLayout or {}
local PL = NS.PadLayout

-- The header row (situation chip, lockdown chip, stale hint, collapse): its default height and range,
-- the Header tab's Header height (defaults/PadStyle.lua; 18 before 2026-10-20).
PL.HEADER_H  = NS.PadDefaults.HEADER_H.default
PL.HEADER_MIN, PL.HEADER_MAX = NS.PadDefaults.HEADER_H.min, NS.PadDefaults.HEADER_H.max
PL.PAD       = 4     -- inner padding
PL.SECTION_H = 14    -- a section's small-caps label row
PL.BUTTON_H    = 24    -- icon + label button height
PL.ICON      = NS.IconDefaults.SIZE.pad.default -- the icon tile inside an icon + label button (16)
PL.ICON_ONLY = PL.ICON + 8 -- an icon-only button is square: its icon and 8 pixels
PL.ICON_ROOM = 4     -- a labeled button's height past its icon's size
PL.LABEL_H   = 22    -- label-only button height
PL.MIN_PAD_W = 120   -- the narrowest pad when the caller measures no header (opts.minWidth)
PL.MIN_BUTTON_W = 1    -- the narrowest labeled button (its label hides when it has no room)
PL.DEFAULT_W = 100
PL.FONT_SIZE = 10    -- the Buttons tab's default font size, which the heights above were drawn for
PL.BUTTON_ROOM = 10    -- a labeled button's height past its font size: BUTTON_H at FONT_SIZE and up
PL.LABEL_ROOM = 8    -- a label-only button's
PL.TITLE_ROOM = 4    -- a section title row's

function PL.ClampTab(tab, n)
    n = tonumber(n) or 0
    if n < 1 then return 1 end
    tab = math.floor(tonumber(tab) or 1)
    if tab < 1 then return 1 end
    if tab > n then return n end
    return tab
end

--- The tab after a mouse-wheel step: wheel up (delta > 0) goes back one, down goes on; wraps.
function PL.NextTab(tab, n, delta)
    n = tonumber(n) or 0
    if n < 1 then return 1 end
    local step = (tonumber(delta) or 0) > 0 and -1 or 1
    return (PL.ClampTab(tab, n) - 1 + step) % n + 1
end

--- The sections a pad draws for its groups-as mode (spec §10.2).
function PL.VisibleSections(sections, groupsAs, tab)
    sections = type(sections) == "table" and sections or {}
    if groupsAs == "merged" then
        local all = {}
        for _, s in ipairs(sections) do
            for _, slot in ipairs(s.slots or {}) do all[#all + 1] = slot end
        end
        if #all == 0 then return {} end
        return { { slots = all } }
    end
    if groupsAs == "tabs" then
        local n = #sections
        if n == 0 then return {} end
        local i = PL.ClampTab(tab, n)
        return { { groupId = sections[i].groupId, title = sections[i].title, slots = sections[i].slots or {},
            tabIndex = i, tabCount = n } }
    end
    return sections
end

-- The Buttons tab's font size, or the default.
local function sizeOf(fontSize)
    return tonumber(fontSize) or PL.FONT_SIZE
end

--- One button's width and height for the pad's style. `cell` is { style, width, height }: the layout's
--- style and the Buttons tab's size. A labeled button is `width` wide; its height is `height` when that is
--- above 0 (never below the icon and its 4 pixels, beside an icon), else automatic: grown with the
--- buttons' font size and the Icons tab's icon size, never below its shipped height. An icon-only button
--- draws no text and stays square around its icon, whatever the size says.
function PL.CellSize(cell, fontSize, iconSize)
    cell = type(cell) == "table" and cell or {}
    local icon = tonumber(iconSize) or PL.ICON
    if cell.style == "icon" then
        local s = icon + (PL.ICON_ONLY - PL.ICON)
        return s, s
    end
    local w = math.max(PL.MIN_BUTTON_W, tonumber(cell.width) or PL.DEFAULT_W)
    local fixed = math.floor(tonumber(cell.height) or 0)
    if cell.style == "label" then
        if fixed > 0 then return w, fixed end
        return w, math.max(PL.LABEL_H, sizeOf(fontSize) + PL.LABEL_ROOM)
    end
    if fixed > 0 then return w, math.max(fixed, icon + PL.ICON_ROOM) end
    return w, math.max(PL.BUTTON_H, sizeOf(fontSize) + PL.BUTTON_ROOM, icon + PL.ICON_ROOM)
end

--- A section title row's height: the Section titles tab's height when it is above 0, else automatic,
--- grown with the section titles' font size (never below SECTION_H).
function PL.TitleHeight(fontSize, fixed)
    fixed = math.floor(tonumber(fixed) or 0)
    if fixed > 0 then return fixed end
    return math.max(PL.SECTION_H, sizeOf(fontSize) + PL.TITLE_ROOM)
end

--- The header row's height: the Header tab's Header height, clamped, or the default.
function PL.HeaderHeight(h)
    h = tonumber(h)
    if not h then return PL.HEADER_H end
    return math.floor(math.max(PL.HEADER_MIN, math.min(PL.HEADER_MAX, h)) + 0.5)
end

--- Columns for a section of `count` buttons: one row (horizontal), one column (vertical) or N (grid).
function PL.Columns(layout, count)
    layout = type(layout) == "table" and layout or {}
    if layout.orientation == "vertical" then return 1 end
    if layout.orientation == "grid" then return math.max(1, math.floor(tonumber(layout.columns) or 4)) end
    return math.max(1, count)
end

-- Growth values: the horizontal half mirrors, the vertical half moves the header (B2).
local UP = { rightUp = true, leftUp = true, up = true }   -- `up`: the retired value, read as rightUp
local MIRROR = { left = true, leftUp = true }

--- Whether a pad with this growth grows upward (its header row at the bottom).
function PL.GrowsUp(growth)
    return UP[growth] == true
end

local function trimLower(s)
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")):lower()
end

--- Whether a section title says what the header's situation already says (B1): the same text,
--- ignoring case and surrounding spaces.
function PL.SameText(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    return trimLower(a) == trimLower(b)
end

-- A frame point's vertical half's offset from the frame's center, and its horizontal half.
local function splitPoint(point)
    point = type(point) == "string" and point or "CENTER"
    local v = point:match("^TOP") and "TOP" or point:match("^BOTTOM") and "BOTTOM" or ""
    local hz = point:match("LEFT$") or point:match("RIGHT$") or ""
    return v, hz
end
local V_OFFSET = { TOP = 0.5, [""] = 0, BOTTOM = -0.5 }

--- The anchor a pad takes for its growth: the given frame point's horizontal half on the growth edge
--- (TOP for down, BOTTOM for up). With the frame's height `h` the y offset moves to that edge, so a
--- point read off a drawn frame names the same place (a drop); without it the stored offset is kept
--- (a stored point is read as the growth edge's).
--- @return string point, number y
function PL.EdgePoint(point, y, h, up)
    local v, hz = splitPoint(point)
    local edge = up and "BOTTOM" or "TOP"
    y = tonumber(y) or 0
    if tonumber(h) then y = y + (V_OFFSET[edge] - V_OFFSET[v]) * h end
    return (hz == "" and edge or edge .. hz), y
end

-- One section as a block: its title row and button rows, offsets from the block's top. Upward growth
-- flips the button rows inside the block (the first row sits nearest the header) but keeps the title
-- directly above its buttons. A title the header's situation already says is not drawn (B1), unless it
-- is a tab's, whose drawn title names its place.
local function sectionBlock(s, layout, cw, ch, gap, up, th, situation)
    local items, by = {}, 0
    if s.title and (s.tabCount or not PL.SameText(s.title, situation)) then
        items[#items + 1] = { kind = "title", text = s.title, groupId = s.groupId, tabIndex = s.tabIndex,
            tabCount = s.tabCount, x = PL.PAD, y = 0, w = 0, h = th }
        by = th
    end
    local list = s.slots or {}
    local n, cols, trail = #list, 0, 0
    if n > 0 then
        cols = math.min(PL.Columns(layout, n), n)
        local rows = math.ceil(n / cols)
        for i, slot in ipairs(list) do
            local r = math.floor((i - 1) / cols)
            local c = (i - 1) - r * cols
            local vr = up and (rows - 1 - r) or r
            items[#items + 1] = { kind = "button", slot = slot, row = r, col = c,
                x = PL.PAD + c * (cw + gap), y = by + vr * (ch + gap), w = cw, h = ch }
        end
        by = by + rows * ch + (rows - 1) * gap
        trail = gap
    end
    return { items = items, h = by, trail = trail, cols = cols }
end

-- The non-empty section blocks, and the widest block's content width.
local function collectBlocks(sections, layout, cw, ch, gap, up, th, situation)
    local blocks, contentW = {}, 0
    for _, s in ipairs(type(sections) == "table" and sections or {}) do
        local b = sectionBlock(s, layout, cw, ch, gap, up, th, situation)
        if #b.items > 0 then
            b.parentId = s.parentId
            blocks[#blocks + 1] = b
            if b.cols > 0 then contentW = math.max(contentW, b.cols * cw + (b.cols - 1) * gap) end
        end
    end
    return blocks, contentW
end

-- Whether block `b` joins the row `row` (bg subgroups): in a grid pad, consecutive child sections of
-- one parent sit side by side while their columns fit the grid's, so a set of many small children
-- (Alterac Valley's nineteen two-button objectives) takes half the height. Each block keeps its own
-- columns, so the buttons stay on the grid's columns. Any other section starts its own row.
local function joins(row, b, maxCols)
    return maxCols ~= nil and row ~= nil and b.parentId ~= nil and row.parentId == b.parentId
        and b.cols > 0 and row.cols + b.cols <= maxCols
end

-- Stack the blocks under the header in order, packing child rows (joins); each block's `left` is its
-- first column, below a header row `hh` tall. Answers the y below the last row and the widest row's
-- columns.
local function stackBlocks(blocks, maxCols, hh)
    local y, row, widest = hh + PL.PAD, nil, 0
    for _, b in ipairs(blocks) do
        if joins(row, b, maxCols) then
            b.top, b.left = row.top, row.cols
            row.cols = row.cols + b.cols
            row.packed = true
            local bottom = b.top + b.h + b.trail
            if bottom > y then y = bottom end
        else
            b.top, b.left = y, 0
            row = { top = y, cols = b.cols, parentId = b.parentId }
            y = y + b.h + b.trail
        end
        b.row = row
        widest = math.max(widest, row.cols)
    end
    return y, widest
end

-- Upward growth mirrors the stack across the pad's height, block by block: the header row becomes
-- the bottom row and the first section sits just above it, each block's own inside kept.
local function flipBlocks(blocks, height)
    for _, b in ipairs(blocks) do b.top = height - b.top - b.h end
end

-- Every block's items in pad coordinates; "left" mirrors each button across the pad's width. A block in
-- a packed row moves right by its first column, and its title takes the block's width (`w`), so a
-- long title stops at its neighbor; left growth mirrors such a title with its block.
local function flattenBlocks(blocks, mirror, width, step, cw, gap)
    local items = {}
    for _, b in ipairs(blocks) do
        local dx, bw = (b.left or 0) * step, b.cols * cw + (b.cols - 1) * gap
        for _, it in ipairs(b.items) do
            it.y = b.top + it.y
            it.x = it.x + dx
            if it.kind == "title" and b.row and b.row.packed then
                it.w = bw
                if mirror then it.x = width - it.x - it.w end
            end
            if mirror and it.kind == "button" then it.x = width - it.x - it.w end
            items[#items + 1] = it
        end
    end
    return items
end

-- One button's width and height: the Buttons tab's size (opts.button); a pure caller may hand a
-- layout table that carries its own.
local function cellOf(layout, opts)
    local button = type(opts.button) == "table" and opts.button or layout
    return PL.CellSize({ style = layout.style, width = button.width, height = button.height }, opts.fontSize,
        opts.iconSize)
end

-- The pad's section blocks and their content width: none while it is collapsed (the header alone).
local function blocksOf(sections, layout, opts, cw, ch, gap, up)
    if opts.collapsed then return {}, 0 end
    return collectBlocks(sections, layout, cw, ch, gap, up, PL.TitleHeight(opts.titleSize or opts.fontSize,
        opts.titleH), opts.situation)
end

-- The pad's width and height. Never narrower than the header row needs: a fixed floor would leave an
-- icon-only pad's spare width at its right edge, past the last button. With no block, the header row alone.
local function boxSize(blocks, y, contentW, minWidth, hh)
    local width = math.max(tonumber(minWidth) or PL.MIN_PAD_W, contentW + 2 * PL.PAD)
    return width, #blocks > 0 and (y + PL.PAD) or hh
end

--- Place every title row and button. Down growth keeps the header on top; up growth puts it at the
--- bottom with the first section just above it; left mirrors each button row.
--- @param sections table from VisibleSections
--- @param layout table the pad's layout table
--- @param opts table|nil { collapsed = boolean, button = table (the Buttons tab's { width, height }; default:
---   the layout table's own), fontSize = number (the buttons' label size; a button grows to hold it), titleSize = number (the section titles' size; a title row grows to hold it; default
---   fontSize), titleH = number (the Section titles tab's height: above 0 fixes the title rows'
---   height, 0 or none keeps it automatic), iconSize = number (the Icons tab's; a button grows to hold it), headerH = number (the
---   header row's height, PL.HeaderHeight),
---   situation = string (the header's text: a section title equal to it is not drawn),
---   minWidth = number (the narrowest the pad may be: what its header row needs, measured by
---   modules/Pad.lua; default PL.MIN_PAD_W) }
--- @return table { width, height, items, headerY (the header row's top), headerH (its height), up (the
---   growth is upward) }
function PL.Compute(sections, layout, opts)
    layout = type(layout) == "table" and layout or {}
    opts = type(opts) == "table" and opts or {}
    local cw, ch = cellOf(layout, opts)
    local hh = PL.HeaderHeight(opts.headerH)
    local gap = math.max(0, tonumber(layout.spacing) or 4)
    local up = PL.GrowsUp(layout.growth)
    local blocks, contentW = blocksOf(sections, layout, opts, cw, ch, gap, up)
    local maxCols = layout.orientation == "grid" and PL.Columns(layout, 1) or nil
    local y, widest = stackBlocks(blocks, maxCols, hh)
    if widest > 0 then contentW = math.max(contentW, widest * cw + (widest - 1) * gap) end
    local width, height = boxSize(blocks, y, contentW, opts.minWidth, hh)
    if up then flipBlocks(blocks, height) end
    local items = flattenBlocks(blocks, MIRROR[layout.growth] == true, width, cw + gap, cw, gap)
    return { width = width, height = height, items = items, up = up, headerY = up and (height - hh) or 0,
        headerH = hh }
end

--- The pad's visibility as one state-driver expression (spec §10.3). The master visibility applies
--- on top of the pad's own; "whenActive" is decided at the last out-of-combat rebuild; test mode
--- shows the display (options-ui-§15), even over `/qc toggle`'s session hide (`hidden`).
function PL.VisibilityDriver(master, padVis, hasActive, testMode, hidden)
    if testMode then return "show" end
    if hidden then return "hide" end
    if master == "never" or padVis == "never" then return "hide" end
    if padVis == "whenActive" then
        if not hasActive then return "hide" end
        padVis = "always"
    end
    local wantIn = master == "inCombat" or padVis == "inCombat"
    local wantOut = master == "outOfCombat" or padVis == "outOfCombat"
    if wantIn and wantOut then return "hide" end
    if wantIn then return "[combat] show; hide" end
    if wantOut then return "[combat] hide; show" end
    return "show"
end

--- The pad's alpha (SetAlpha is allowed in combat): the master alpha, faded out of combat or
--- until the mouse is over the pad, as the pad's look says.
function PL.Alpha(masterAlpha, look, inCombat, hovered)
    local a = tonumber(masterAlpha) or 1
    look = type(look) == "table" and look or {}
    local faded = (look.fade == "outOfCombat" and not inCombat and not hovered)
        or (look.fade == "mouseover" and not hovered)
    if faded then a = a * (tonumber(look.fadeAlpha) or 0.4) end
    return math.max(0, math.min(1, a))
end
