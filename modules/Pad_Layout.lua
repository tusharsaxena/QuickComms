local _, NS = ...
-- modules/Pad_Layout.lua — the Comms Pad's geometry and look decisions (spec §10.2, §10.3). PURE:
-- plain tables in, plain tables out; no frame and no client read. Coordinates are offsets from the
-- pad root's TOPLEFT with y growing down; modules/Pad.lua flips y for SetPoint. The cell placement
-- copies KickCD modules/IconGrid_Layout.lua `Layout.layoutBlock` (row-major cells, an axis mirrored
-- for leftward or upward growth); the visibility expression copies ConsumableMaster
-- core/MacroBarModel.lua `BM.ResolveVisibility` (a constant or one [combat] state-driver
-- expression, never an insecure Show/Hide in combat).

NS.PadLayout = NS.PadLayout or {}
local PL = NS.PadLayout

PL.HEADER_H  = 18    -- the header row: situation chip, lockdown chip, stale hint, collapse
PL.PAD       = 4     -- inner padding
PL.SECTION_H = 14    -- a section's small-caps label row
PL.CHIP_H    = 24    -- icon + label chip height
PL.ICON      = 20    -- the icon tile inside an icon + label chip
PL.ICON_ONLY = 28    -- an icon-only chip is square
PL.LABEL_H   = 22    -- label-only chip height
PL.MIN_W     = 120   -- the narrowest pad and the narrowest labeled chip
PL.DEFAULT_W = 140

local TAG = { party = "P", raid = "R", instance = "I", raidWarning = "RW", say = "S", yell = "Y" }

--- The chip's channel tag: the channel a callout resolved to (a smart kind shows its result).
function PL.Tag(concrete)
    return TAG[concrete]
end

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
        return { { title = sections[i].title, slots = sections[i].slots or {}, tabIndex = i, tabCount = n } }
    end
    return sections
end

--- One chip's width and height for the pad's style.
function PL.CellSize(layout)
    layout = type(layout) == "table" and layout or {}
    if layout.style == "icon" then return PL.ICON_ONLY, PL.ICON_ONLY end
    local w = math.max(PL.MIN_W, tonumber(layout.width) or PL.DEFAULT_W)
    if layout.style == "label" then return w, PL.LABEL_H end
    return w, PL.CHIP_H
end

--- Columns for a section of `count` chips: one row (horizontal), one column (vertical) or N (grid).
function PL.Columns(layout, count)
    layout = type(layout) == "table" and layout or {}
    if layout.orientation == "vertical" then return 1 end
    if layout.orientation == "grid" then return math.max(1, math.floor(tonumber(layout.columns) or 4)) end
    return math.max(1, count)
end

local function mirror(items, width, height, growth)
    for _, it in ipairs(items) do
        if growth == "left" and it.kind == "chip" then it.x = width - it.x - it.w end
        if growth == "up" then it.y = PL.HEADER_H + (height - it.y - it.h) end
    end
end

--- Place every title row and chip.
--- @param sections table from VisibleSections
--- @param layout table the pad's layout table
--- @param opts table|nil { collapsed = boolean }
--- @return table { width, height, items }
function PL.Compute(sections, layout, opts)
    layout = type(layout) == "table" and layout or {}
    opts = type(opts) == "table" and opts or {}
    local cw, ch = PL.CellSize(layout)
    local gap = math.max(0, tonumber(layout.spacing) or 4)
    local items, contentW, used = {}, 0, false
    local y = PL.HEADER_H + PL.PAD
    if not opts.collapsed then
        for _, s in ipairs(type(sections) == "table" and sections or {}) do
            if s.title then
                items[#items + 1] = { kind = "title", text = s.title, tabIndex = s.tabIndex, tabCount = s.tabCount,
                    x = PL.PAD, y = y, w = 0, h = PL.SECTION_H }
                y = y + PL.SECTION_H
                used = true
            end
            local list = s.slots or {}
            local n = #list
            if n > 0 then
                local cols = math.min(PL.Columns(layout, n), n)
                local rows = math.ceil(n / cols)
                for i, slot in ipairs(list) do
                    local r = math.floor((i - 1) / cols)
                    local c = (i - 1) - r * cols
                    items[#items + 1] = { kind = "chip", slot = slot, row = r, col = c,
                        x = PL.PAD + c * (cw + gap), y = y + r * (ch + gap), w = cw, h = ch }
                end
                contentW = math.max(contentW, cols * cw + (cols - 1) * gap)
                y = y + rows * ch + (rows - 1) * gap + gap
                used = true
            end
        end
    end
    local width = math.max(PL.MIN_W, contentW + 2 * PL.PAD)
    local height = used and (y + PL.PAD) or PL.HEADER_H
    mirror(items, width, height, layout.growth)
    return { width = width, height = height, items = items }
end

--- The pad's visibility as one state-driver expression (spec §10.3). The master visibility applies
--- on top of the pad's own; "whenActive" is decided at the last out-of-combat rebuild; test mode
--- shows the display (options-ui-§15).
function PL.VisibilityDriver(master, padVis, hasActive, testMode)
    if testMode then return "show" end
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
