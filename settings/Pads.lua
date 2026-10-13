local _, NS = ...
-- settings/Pads.lua — the Comms Pad page (design spec §10.2-§10.4, §13.1): one pad at a time.
--
--     band     [ Pad v (picker) ][ New pad ]
--     strip    [ General ][ Groups ][ Layout ][ Look ]
--     General  Preview as (page-wide, first), Name, Enabled, then Unlock (or Lock) pads and Delete pad
--     Groups   Show groups as, then the pad's groups as a drag-to-reorder list with Remove (its
--              priority order, spec §7), then Add a group
--     Layout   orientation, grid columns, growth, chip style, scale, spacing, chip width, then
--              Position: X and Y and Reset this pad's position
--     Look     visibility, fade and faded alpha; then Font (face, size, color with Use class color,
--              flags, shadow), Border (style, thickness, color with Use class color) and Background
--              (its color with Use class color), each composed by the options library (options-ui-§16,
--              §17) under its own heading
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
local LOOK = L["Look"]

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
    local name = g and g.name or gid
    if NS.Library.IsBuiltin(gid) then name = L["%s (built-in)"]:format(name) end
    return ((active and active[gid]) and Ed.ACTIVE_DOT or "") .. name
end

--- The groups the pad does not list: user groups by name, then the top-level built-ins in order.
function PD.AddableGroups(id)
    local on = {}
    for _, gid in ipairs(NS.db.profile.pads[id].groups) do on[gid] = true end
    local user = {}
    for gid, g in pairs(NS.db.profile.groups) do
        if not on[gid] then user[#user + 1] = { id = gid, label = g.name or gid } end
    end
    table.sort(user, function(a, b) return a.label:lower() < b.label:lower() end)
    for _, gid in ipairs(NS.BuiltIns.order) do
        if not on[gid] then user[#user + 1] = { id = gid, label = groupLabel(gid) } end
    end
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
    h.RenderRows(ctx, { Ed.Row("state.previewAs") }, nil, nil, { noHeadings = true })
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    local locked = NS.Setting("locked") ~= false
    h.InlineButtonPair(ctx,
        { text = locked and L["Unlock pads"] or L["Lock pads"],
          tooltip = L["Unlocked, every pad shows a strip to drag it by. The same switch as /qc lock and /qc unlock."],
          onClick = function()
              NS.SlashVerbs.ToggleLock()
              Ed.RequestRefresh()
          end },
        { text = L["Delete pad"], tooltip = L["Delete this pad. Its groups and callouts are kept. Asks first."],
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
    local list = NS.db.profile.pads[id].groups
    if #list == 0 then
        h.TextRow(ctx, L["This pad lists no group. Add one below."])
    else
        h.TextRow(ctx, L["Higher groups come first on the pad. Drag to reorder."])
        local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
        local entries = {}
        for i, gid in ipairs(list) do
            entries[i] = { id = gid, label = groupLabel(gid, active),
                remove = function() NS.Library.RemoveGroupFromSurface("pad", id, gid) end }
        end
        Ed.ReorderRows(ctx, PAGE, entries, function(from, to) PD.MoveGroup(id, from, to) end)
    end
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Add a group"], L["Add a group to the end of this pad's list."],
        PD.AddableGroups(id), function(gid) NS.Library.AddGroupToSurface("pad", id, gid) end) })
end

-- One offset box. Its refresher (a scalar refresh, never a situation change) puts it back to the
-- stored point after any write, the drag's included.
local function offsetBox(ctx, id, label, axis)
    local index = axis == "x" and 3 or 4
    return { make = function(_, parent, rel)
        local eb = H().AceGUI:Create("EditBox")
        eb:SetLabel(label)
        eb:SetText(tostring(PD.Point(id)[index]))
        if ctx.refreshers then
            ctx.refreshers[#ctx.refreshers + 1] = function() eb:SetText(tostring(PD.Point(id)[index])) end
        end
        eb:SetRelativeWidth(rel or 0.5)
        eb:SetCallback("OnEnterPressed", function(_, _, text)
            -- A refusal (its line already printed) puts the box back to the stored offset.
            if not PD.SetOffset(id, axis, text) then eb:SetText(tostring(PD.Point(id)[index])) end
        end)
        H().AttachTooltip(eb, label, L["Pixels from the pad's anchor. Press Enter to apply."])
        parent:AddChild(eb)
        return eb
    end }
end

local function renderLayout(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    h.Section(ctx, L["Position"])
    h.RenderGrid(ctx, { offsetBox(ctx, id, L["X offset"], "x"), offsetBox(ctx, id, L["Y offset"], "y") })
    h.InlineButtonPair(ctx, { text = L["Reset this pad's position"],
        tooltip = L["Put this pad back in its default place."], onClick = function() PD.ResetPoint(id) end }, nil)
end

-- The Look tab's groups after its own rows, each under its heading (options-ui-§16: a tab with more
-- than one group says where one stops and the next starts). The subgroup is the composed rows' own.
PD.LOOK_GROUPS = { L["Font"], L["Border"], L["Background"] }

--- The rows of `rows` whose subgroup is `subgroup` (nil: the rows in no group), in order.
function PD.LookRows(rows, subgroup)
    local out = {}
    for _, row in ipairs(rows) do
        if row.subgroup == subgroup then out[#out + 1] = row end
    end
    return out
end

local function renderLook(ctx, rows)
    local h = H()
    if not selected() then
        h.TextRow(ctx, NONE)
        return
    end
    local scalar = Ed.Scalar(rows)
    h.RenderRows(ctx, PD.LookRows(scalar, nil), nil, nil, { noHeadings = true })
    for _, subgroup in ipairs(PD.LOOK_GROUPS) do
        local mine = PD.LookRows(scalar, subgroup)
        if #mine > 0 then
            h.Section(ctx, subgroup)
            h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })
        end
    end
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
        action = { text = L["New pad"], tooltip = L["Make a new Comms Pad showing every built-in set, and edit it here."],
            onClick = PD.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = GROUPS, render = renderGroups },
        { key = LAYOUT, render = renderLayout },
        { key = LOOK, render = renderLook },
    })
end

Ed.RegisterPage(PAGE, L["Comms Pad"], "PadsPanel", render, {
    tooltip = L["Put the selected pad's groups-as, layout and look back to their defaults, and turn it on. Its name, groups and position are kept."],
    -- One act (Library.Batch): the pads rebuild once, not once per row.
    onClick = function(ctx) NS.Library.Batch(function() H().RestoreDefaults(PAGE, ctx) end) end,
})
