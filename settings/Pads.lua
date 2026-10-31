local _, NS = ...
-- settings/Pads.lua — the Pad page (design spec §10.2-§10.4, §13.1): one pad at a time.
--
--     band     [ Pad v (picker) ][ New pad ]
--     strip    [ General ][ Groups ][ Layout ][ Window ][ Header ][ Section titles ][ Buttons ]
--              [ Icons ]   (outside in since item 020, QUI-L09; Header and Section titles were Pad
--              header and Section header until then, QUI-L10)
--     General  Name, Enable this pad, Visibility (with Fade and Faded opacity, `pad.look.*`, under its
--              own heading; on the Window tab until 2026-10-20), then Unlock (or Lock) all pads and
--              Delete pad…
--     Groups   Show groups as, then Add group, then the pad's groups as a drag-to-reorder list with
--              Remove (its priority order, spec §7); the add control above the list since item 020
--              (QUI-L07), as the Callouts tab's
--     Layout   orientation, grid columns, growth, button style, pad scale, button spacing, then
--              Position: X and Y and Reset this pad's position
--     Window          the pad itself (`pad.look.*`, the Look tab's stored key): Background and Border.
--                     Header, Section titles and this were one Window tab until 2026-10-20, then
--                     this was Main window, with Visibility, until that moved to General (owner
--                     requests)
--     Header          the top row that names the situation (`pad.header.*`): Size (Header height),
--                     Font (face, size, color with Use class color, flags, shadow), Background (its
--                     color with Use class color) and Border (style, thickness, color with Use class
--                     color), the blocks composed by the options library (options-ui-§16, §17), each
--                     under its own heading, which the library draws from the rows' subgroup (once)
--     Section titles  each section title's row (`pad.section.*`): Size (its height, 0 automatic), Font
--                     (the titles'), and the Background and Border of the band behind each title
--     Buttons  the buttons themselves (`pad.button.*`; the Chip tab, `pad.chip.*`, until 2026-10-20): Size (Button width,
--              from Layout until 2026-10-20, and Button height, 0 automatic), Font (the buttons'
--              labels), Background, Border, Button glow (off by default: its style and color) and
--              Shine, each under its own heading, in the styled tabs' order (item 020, QUI-L12)
--     Icons    the buttons' icons (B9, settings/SchemaIcons.lua): Size and crop, Color (with Tint), the
--              composed Border block, Icon glow (its trigger, style, color and offsets), then only the
--              selected style's knobs (none while the glow is off), each under its own heading drawn
--              by the library
--
-- The band holds the picker and the create action (options-ui-§14). Every field is a member row
-- (settings/SchemaMembers.lua) written to the selected pad; the pad redraws through LIBRARY_CHANGED
-- -> Surfaces.Request, which waits for combat end when it must. X and Y write the whole `pad.point`
-- row, the same one the drag strip writes (spec §5.1). The pad's list order and membership are
-- Library's (MoveGroupOnSurface, Add/RemoveGroupFromSurface). Lock is the one master lock. A write to
-- a pad's fields refreshes the tab in place (only its name repaints, settings/Editors.lua); the X/Y
-- boxes have their own refreshers, so a drag on screen updates them.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "pads"
local GENERAL = L["General"]
local GROUPS = L["Groups"]
local LAYOUT = L["Layout"]
local WINDOW = L["Window"]
local PAD_HEADER = L["Header"]
local SECTION_HEADER = L["Section titles"]
local BUTTON = L["Buttons"]
local ICONS = L["Icons"]

Settings.Pads = Settings.Pads or {}
local PD = Settings.Pads

local function H() return Settings.Helpers end

function PD.Entries()
    local pads = NS.db.profile.pads
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("pad")) do out[#out + 1] = { id = id, label = pads[id].name or id } end
    return out
end

--- A new pad's name: "Comms Pad <n>", the lowest n from 2 that no pad is named, so a delete never
--- leads to two pads with one name.
function PD.NewName()
    local taken = {}
    for _, pad in pairs(NS.db.profile.pads) do
        if pad.name then taken[pad.name] = true end
    end
    local n = 2
    while taken[L["Comms Pad %d"]:format(n)] do n = n + 1 end
    return L["Comms Pad %d"]:format(n)
end

function PD.Create()
    local id = NS.Library.CreateSurface("pad", PD.NewName())
    if id then
        Ed.Select("pad", id)
        Ed.RequestRefresh()
    end
    return id
end

function PD.Delete(id)
    local pad = NS.db.profile.pads[id]
    if not pad then return end
    Ed.ConfirmDelete(pad.name or id, function() NS.Library.DeleteSurface("pad", id) end)
end

--- The pad's anchor, or the default one; a copy.
function PD.Point(id)
    local pad = NS.db.profile.pads[id]
    local pt = (pad and type(pad.point) == "table") and pad.point or NS.Pad.DEFAULT_POINT
    return { pt[1], pt[2], pt[3], pt[4] }
end

--- Move the pad by a typed X or Y offset: the whole `pad.point` row, through the seam. A refusal
--- prints its reason.
function PD.SetOffset(id, axis, text)
    local n = tonumber((text or ""):match("^%s*(-?%d+%.?%d*)%s*$"))
    if not n then
        NS.Print(L["A position is a number of pixels."])
        return false
    end
    local pt = PD.Point(id)
    if axis == "x" then pt[3] = n else pt[4] = n end
    local ok, err, why = NS.SchemaRuntime.Set("pad.point", pt, id)
    if not ok then NS.Print(tostring(why or err)) end
    return ok == true
end

function PD.ResetPoint(id)
    return (NS.SchemaRuntime.Set("pad.point", nil, id)) == true
end

local function groupLabel(gid, active)
    local g = NS.Library.Group(gid)
    return (g and g.name or gid) .. ((active and active[gid]) and Ed.ACTIVE_DOT or "")
end

--- The groups the pad does not list: top-level user groups by name (a group inside another shows
--- with it, never by itself).
function PD.AddableGroups(id)
    local on = {}
    for _, gid in ipairs(NS.db.profile.pads[id].groups) do on[gid] = true end
    local user = {}
    for gid, g in pairs(NS.db.profile.groups) do
        if not on[gid] and not NS.Library.IsChild(gid) then user[#user + 1] = { id = gid, label = g.name or gid } end
    end
    table.sort(user, function(a, b) return a.label:lower() < b.label:lower() end)
    return user
end

function PD.MoveGroup(id, from, to)
    return NS.Library.MoveGroupOnSurface("pad", id, from, to)
end

local NONE = L["No pads yet. Click New pad to make one."]

local function selected()
    local id = Ed.Selected("pad")
    return (id and NS.db.profile.pads[id]) and id or nil
end

local function renderGeneral(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    -- The master lock (item 020, QUI-L15: "all", since it moves every pad).
    local locked = NS.Setting("locked") ~= false
    h.InlineButtonPair(ctx,
        { text = locked and L["Unlock all pads"] or L["Lock all pads"],
          tooltip = L["Unlocked, every pad shows a strip to drag it by. The same switch as Lock frame on the General page > Master controls, and as /qc lock and /qc unlock."],
          onClick = function()
              NS.SlashVerbs.ToggleLock()
              Ed.RequestRefresh()
          end },
        { text = L["Delete pad…"], tooltip = L["Delete this pad. Its groups and callouts are kept. Asks first."],
          onClick = function() PD.Delete(id) end })
end

local function renderGroups(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    -- Above the list, as the Callouts tab's Add callout (item 020, QUI-L07): a long list never pushes
    -- it out of view.
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Add group"], L["Add a group to the end of this pad's list."],
        PD.AddableGroups(id), function(gid) NS.Library.AddGroupToSurface("pad", id, gid) end) })
    local list = NS.db.profile.pads[id].groups
    if #list == 0 then
        h.TextRow(ctx, L["This pad lists no group. Add one above."])
    else
        h.TextRow(ctx, L["Higher groups come first on the pad. Drag to reorder."])
        local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
        local entries = {}
        for i, gid in ipairs(list) do
            entries[i] = { id = gid, label = groupLabel(gid, active),
                removeTooltip = L["Take this group off the pad. The group itself is kept."],
                remove = function() NS.Library.RemoveGroupFromSurface("pad", id, gid) end }
        end
        Ed.ReorderRows(ctx, PAGE, entries, function(from, to) PD.MoveGroup(id, from, to) end)
    end
end

local function renderLayout(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    local list = Ed.Scalar(rows)
    local place, reset = Ed.PositionRows({
        page = "pads", tooltip = L["Pixels from the pad's anchor. Press Enter to apply."],
        point = function() return PD.Point(id) end,
        setOffset = function(axis, text) return PD.SetOffset(id, axis, text) end,
        resetText = L["Reset this pad's position"], resetTooltip = L["Put this pad back in its default place."],
        onReset = function() PD.ResetPoint(id) end,
    })
    for _, row in ipairs(place) do list[#list + 1] = row end
    h.RenderRows(ctx, list, nil, nil, { noHeadings = true, afterSubgroup = { [L["Position"]] = reset } })
end

-- A styled tab (Window, Header, Section titles, Buttons) in one call: its rows in schema
-- order, whose headings the library draws from each row's subgroup (options-ui-§7, §16: a subsection
-- is never drawn by the host, so each heading shows once).
local function renderStyled(ctx, rows)
    local h = H()
    if not selected() then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

local function render(ctx)
    local h = H()
    local entries = PD.Entries()
    local sel = Ed.Heal("pad", ids(entries))
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Pad"], list = list, order = order, value = sel,
        tooltip = L["Which Comms Pad this page edits."],
        onSelect = function(v)
            Ed.Select("pad", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New pad"], tooltip = L["Make a new Comms Pad holding the built-in groups, and edit it here."],
            onClick = PD.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = GROUPS, render = renderGroups },
        { key = LAYOUT, render = renderLayout },
        { key = WINDOW, render = renderStyled },
        { key = PAD_HEADER, render = renderStyled },
        { key = SECTION_HEADER, render = renderStyled },
        { key = BUTTON, render = renderStyled },
        { key = ICONS, render = renderStyled },
    })
end

Ed.RegisterPage(PAGE, L["Pad"], "PadsPanel", render, {
    tooltip = L["Put the selected pad's visibility, groups-as, layout, header, section titles, window, buttons and icons back to their defaults, and turn it on. Its name, groups and position are kept."],
    -- One act (Library.Batch): the pads rebuild once, not once per row.
    onClick = function(ctx) NS.Library.Batch(function() H().RestoreDefaults(PAGE, ctx) end) end,
})
