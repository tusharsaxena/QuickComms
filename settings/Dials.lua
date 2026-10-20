local _, NS = ...
-- settings/Dials.lua — the Comms Dial page (design spec §11, §13.1): one dial at a time.
--
--     band     [ Dial v (picker) ][ New dial ]
--     strip    [ General ][ Groups ][ Wheel ][ Slices ][ Paging ][ Labels ][ Icons ][ Preview ]
--     General  Name, Enabled, then Delete dial
--     Groups   Show groups as (Categories or Flat), then the dial's groups as a drag-to-reorder list
--              with Remove (its priority order, spec §7), then Add a group
--     Wheel    wedges per ring (Auto by default), ring radius, icon offset, open at, then Position: X and Y and
--              Reset this dial's position
--     Slices   Background (the slices' fill), Border (size, color), Highlight (the hovered slice's
--              fill) and Pointer (show, size, color), each color with its class-color companion
--     Paging   a paged ring's row under the dial: Position (offset), Arrows (size, spacing, colors) and
--              Page indicator (dot size, current page width, spacing, colors)
--     Labels   Show labels, then the labels' Font block (font, size, outline, color, class color,
--              shadow), grayed out while labels are off, then Tooltip (side, offset)
--     Icons    the wedges' icons (B9, settings/SchemaIcons.lua), as the Comms Pad page's Icons tab;
--              a wedge's border is a round ring and its icon size keeps the wedge's own size
--     Preview  each ring as the current or previewed situation builds it, wedge by wedge
--
-- The band holds the picker and the create action (options-ui-§14). Every field is a member row
-- (settings/SchemaMembers.lua) written to the selected dial; the dial rebuilds through LIBRARY_CHANGED
-- -> Surfaces.Request, which waits for combat end when it must. The key is no row and has no tab
-- (dial rework, 2026-10-21): it is WoW's own binding of the dial's Open Comms Dial entry, set only in
-- Options -> Keybindings -> Ka0s Quick Comms. Relaxed is the only interaction in v0.1.0 (the C7
-- fallback), so there is no delay or tap-action control, and depth is no control (owner ruling R5).
-- The Preview tab is a listing, not a drawn wheel (owner ruling R3): the wheel itself shows in game
-- (test mode and Preview as… open dial 1). As settings/Pads.lua: New dial takes the lowest free
-- number, a refused X or Y says why and puts the box back, and Defaults is one act (Library.Batch)
-- that keeps the dial's position.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "dials"
local GENERAL = L["General"]
local GROUPS = L["Groups"]
local WHEEL = L["Wheel"]
local ICONS = L["Icons"]
local LABELS = L["Labels"]
local SLICES = L["Slices"]
local PAGING = L["Paging"]

local DIRECTION = { N = L["N"], NE = L["NE"], E = L["E"], SE = L["SE"], S = L["S"], SW = L["SW"], W = L["W"],
    NW = L["NW"] }

Settings.Dials = Settings.Dials or {}
local DD = Settings.Dials

local function H() return Settings.Helpers end

function DD.Entries()
    local dials = NS.db.profile.dials
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("dial")) do out[#out + 1] = { id = id, label = dials[id].name or id } end
    return out
end

--- A new dial's name: "Comms Dial <n>", the lowest n from 2 that no dial is named, so a delete never
--- leads to two dials with one name (as settings/Pads.lua PD.NewName).
function DD.NewName()
    local taken = {}
    for _, dial in pairs(NS.db.profile.dials) do
        if dial.name then taken[dial.name] = true end
    end
    local n = 2
    while taken[L["Comms Dial %d"]:format(n)] do n = n + 1 end
    return L["Comms Dial %d"]:format(n)
end

function DD.Create()
    local id = NS.Library.CreateSurface("dial", DD.NewName())
    if id then
        Ed.Select("dial", id)
        Ed.RequestRefresh()
    end
    return id
end

function DD.Delete(id)
    local dial = NS.db.profile.dials[id]
    if not dial then return end
    Ed.ConfirmDelete(dial.name or id, function() NS.Library.DeleteSurface("dial", id) end)
end

--- The dial's place, or the default one; a copy.
function DD.Point(id)
    local dial = NS.db.profile.dials[id]
    local pt = (dial and type(dial.point) == "table") and dial.point or NS.Library.DIAL_DEFAULT_POINT
    return { pt[1], pt[2], pt[3], pt[4] }
end

--- Move the dial by a typed X or Y offset: the whole `dial.point` row, through the seam. A refusal
--- prints its reason.
function DD.SetOffset(id, axis, text)
    local n = tonumber((text or ""):match("^%s*(-?%d+%.?%d*)%s*$"))
    if not n then
        NS.Print(L["A position is a number of pixels."])
        return false
    end
    local pt = DD.Point(id)
    if axis == "x" then pt[3] = n else pt[4] = n end
    local ok, err, why = NS.SchemaRuntime.Set("dial.point", pt, id)
    if not ok then NS.Print(tostring(why or err)) end
    return ok == true
end

function DD.ResetPoint(id)
    return (NS.SchemaRuntime.Set("dial.point", nil, id)) == true
end

-- Plans the page builds to look at (the Preview listing) are not a surface's bake: they stay out of
-- the bakeSurface perf bucket.
local function lookDeps(snap)
    local deps = NS.Surfaces.Deps(snap)
    deps.unmeasured = true
    return deps
end

--- The Preview tab's lines: each ring as the current or previewed situation builds it.
--- @return string[]
function DD.PreviewLines(id)
    local snap = Ed.Snapshot()
    local plan = NS.Surfaces.BuildDialPlan(id, NS.db.profile.dials[id], snap, lookDeps(snap))
    if #plan.rings == 0 then return { L["Nothing to show: no group on this dial is active here."] } end
    local out = {}
    for r, ring in ipairs(plan.rings) do
        local title = NS.DialRender.RingTitle(ring)
        out[#out + 1] = r == plan.openRing and L["%s (opens here)"]:format(title) or title
        for i, item in ipairs(ring.items) do
            local what = item.title or "?"
            if item.kind == "ring" then what = L["%s, opens a ring"]:format(what) end
            local dir = NS.DialLayout.Direction(item.wedge or i, ring.size, ring.start)
            out[#out + 1] = L["  %d %s: %s"]:format(i, DIRECTION[dir] or L["%s o'clock"]:format(dir), what)
        end
    end
    return out
end

local function groupLabel(gid, active)
    local g = NS.Library.Group(gid)
    return (g and g.name or gid) .. ((active and active[gid]) and Ed.ACTIVE_DOT or "")
end

--- The groups the dial does not list: top-level user groups by name (a group inside another shows
--- with it, never by itself).
function DD.AddableGroups(id)
    local on = {}
    for _, gid in ipairs(NS.db.profile.dials[id].groups) do on[gid] = true end
    local out = {}
    for gid, g in pairs(NS.db.profile.groups) do
        if not on[gid] and not NS.Library.IsChild(gid) then out[#out + 1] = { id = gid, label = g.name or gid } end
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end

local NONE = L["No dials yet. Click New dial to make one."]

local function selected()
    local id = Ed.Selected("dial")
    return (id and NS.db.profile.dials[id]) and id or nil
end

local function renderGeneral(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    h.InlineButtonPair(ctx, { text = L["Delete dial"],
        tooltip = L["Delete this dial. Its groups and callouts are kept. Asks first."],
        onClick = function() DD.Delete(id) end }, nil)
end

local function renderGroups(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    local list = NS.db.profile.dials[id].groups
    if #list == 0 then
        h.TextRow(ctx, L["This dial lists no group. Add one below."])
    else
        h.TextRow(ctx, L["Higher groups come first on the dial. Drag to reorder."])
        local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
        local entries = {}
        for i, gid in ipairs(list) do
            entries[i] = { id = gid, label = groupLabel(gid, active),
                removeTooltip = L["Take this group off the dial. The group itself is kept."],
                remove = function() NS.Library.RemoveGroupFromSurface("dial", id, gid) end }
        end
        Ed.ReorderRows(ctx, PAGE, entries, function(from, to) NS.Library.MoveGroupOnSurface("dial", id, from, to) end)
    end
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Add a group"], L["Add a group to the end of this dial's list."],
        DD.AddableGroups(id), function(gid) NS.Library.AddGroupToSurface("dial", id, gid) end) })
end

-- One offset box. Its refresher (a scalar refresh) puts it back to the stored point after any write.
local function offsetBox(ctx, id, label, axis)
    local index = axis == "x" and 3 or 4
    return { make = function(_, parent, rel)
        local eb = H().AceGUI:Create("EditBox")
        eb:SetLabel(label)
        eb:SetText(tostring(DD.Point(id)[index]))
        if ctx.refreshers then
            ctx.refreshers[#ctx.refreshers + 1] = function() eb:SetText(tostring(DD.Point(id)[index])) end
        end
        eb:SetRelativeWidth(rel or 0.5)
        eb:SetCallback("OnEnterPressed", function(_, _, text)
            -- A refusal (its line already printed) puts the box back to the stored offset.
            if not DD.SetOffset(id, axis, text) then eb:SetText(tostring(DD.Point(id)[index])) end
        end)
        H().AttachTooltip(eb, label, L["Pixels from the middle of the screen. Press Enter to apply."])
        parent:AddChild(eb)
        return eb
    end }
end

-- The Icons tab: its rows in schema order, the headings the library's (as the Comms Pad page's), and
-- only the selected glow style's knobs (Settings.ShownIconRows).
local function renderIcons(ctx, rows)
    local h = H()
    if not selected() then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(Settings.ShownIconRows(rows)), nil, nil, { noHeadings = true })
end

-- The Slices, Paging and Labels tabs: their rows, under their own headings.
local function renderStyled(ctx, rows)
    local h = H()
    if not selected() then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
end

local function renderWheel(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    h.Section(ctx, L["Position"])
    h.RenderGrid(ctx, { offsetBox(ctx, id, L["X offset"], "x"), offsetBox(ctx, id, L["Y offset"], "y") })
    h.InlineButtonPair(ctx, { text = L["Reset this dial's position"],
        tooltip = L["Put this dial back in the middle of the screen."], onClick = function() DD.ResetPoint(id) end }, nil)
end

local function renderPreview(ctx)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    local label = h.TextRow(ctx, table.concat(DD.PreviewLines(id), "\n"))
    Ed.Live(ctx, function() if label then label:SetText(table.concat(DD.PreviewLines(id), "\n")) end end)
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

local function render(ctx)
    local h = H()
    local entries = DD.Entries()
    local sel = Ed.Heal("dial", ids(entries))
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Dial"], list = list, order = order, value = sel,
        tooltip = L["Which Comms Dial this page edits."],
        onSelect = function(v)
            Ed.Select("dial", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New dial"], tooltip = L["Make a new Comms Dial holding the built-in groups, and edit it here."],
            onClick = DD.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = GROUPS, render = renderGroups },
        { key = WHEEL, render = renderWheel },
        { key = SLICES, render = renderStyled },
        { key = PAGING, render = renderStyled },
        { key = LABELS, render = renderStyled },
        { key = ICONS, render = renderIcons },
        { key = "preview", label = L["Preview"], tooltip = L["What each ring holds here, or in the preview."],
          render = renderPreview },
    })
end

Ed.RegisterPage(PAGE, L["Comms Dial"], "DialsPanel", render, {
    tooltip = L["Put the selected dial's groups-as, wedges per ring, ring radius, icon offset, where it opens, its slices, paging, labels and icons back to their defaults, and turn it on. Its name, groups and position are kept."],
    -- One act (Library.Batch): the dials rebuild once, not once per row.
    onClick = function(ctx) NS.Library.Batch(function() H().RestoreDefaults(PAGE, ctx) end) end,
})
