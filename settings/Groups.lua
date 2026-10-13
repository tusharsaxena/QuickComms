local _, NS = ...
-- settings/Groups.lua — the Groups page (design spec §13.1, §12.2): one group at a time, a user group
-- or a built-in set.
--
--     band      [ Group v (picker; a green dot marks a group active now) ][ New group ]
--     strip     [ General ][ Callouts ][ When ][ Preview ]
--     General   Preview as (page-wide, first), then Name, Icon, Enabled, Open the dial on this group,
--               then Duplicate and Delete. A built-in: what it is, its Enabled row, and Customize.
--     Callouts  a user group's callouts as a drag-to-reorder list with Remove, then Add a callout (a
--               built-in callout is copied in first, spec P2). A built-in: a Show checkbox per
--               callout, the hidden-callouts editor (spec §12.2).
--     When      settings/Groups_When.lua
--     Preview   the active-now line, then every callout baked for the current or previewed situation
--
-- The band holds the picker and the create action (options-ui-§14); the acts are General's, which
-- is first. A built-in group is read-only: its group rows refuse every write (settings/SchemaMembers.lua),
-- so the page draws only what may change, its overlay. A new group goes to the top of every pad and
-- dial (Library.OfferGroup), so it shows as soon as its When matches.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "groups"
local GENERAL = L["General"]
local WHEN = L["When"]

Settings.Groups = Settings.Groups or {}
local G = Settings.Groups
G.PAGE = PAGE

local function H() return Settings.Helpers end
local function isBuiltin(id) return NS.Library.IsBuiltin(id) end

--- Picker entries in the page's order (Library.MemberIds: the user groups by name, then the built-in
--- sets in shipped order); a group active under the current or previewed situation carries a green dot.
function G.Entries()
    local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("group")) do
        local text
        if isBuiltin(id) then
            text = L["%s (built-in)"]:format(NS.BuiltIns.groups[id].name)
        else
            text = NS.db.profile.groups[id].name or id
        end
        out[#out + 1] = { id = id, label = (active[id] and Ed.ACTIVE_DOT or "") .. text }
    end
    return out
end

function G.Create()
    local gid = NS.Library.CreateGroup({ name = L["New group"] })
    if not gid then return nil end
    NS.Library.OfferGroup(gid)
    Ed.Select("group", gid)
    Ed.RequestRefresh()
    return gid
end

function G.Duplicate(id)
    local copy = NS.Library.DuplicateGroup(id)
    if copy then
        Ed.Select("group", copy)
        Ed.RequestRefresh()
    end
    return copy
end

function G.Delete(id)
    local g = NS.db.profile.groups[id]
    if not g then return end
    Ed.ConfirmDelete(g.name, function() NS.Library.DeleteGroup(id) end)
end

--- The user group a built-in was customized into, while it still exists.
function G.CustomizedAs(builtinId)
    local o = NS.db.profile.builtins[builtinId]
    local copy = o and o.customizedAs
    return (copy and NS.db.profile.groups[copy]) and copy or nil
end

--- Customize a built-in (spec §12.2): the copy takes its place on every pad and dial, the built-in
--- is turned off, and the page selects the copy. A set already customized selects its copy.
function G.Customize(builtinId)
    local existing = G.CustomizedAs(builtinId)
    if existing then
        Ed.Select("group", existing)
        Ed.RequestRefresh()
        return existing
    end
    local copy = NS.Library.Customize(builtinId)
    if not copy then return nil end
    Ed.Select("group", copy)
    NS.Print(L["%s customized: the copy took its place on every pad."]:format(NS.BuiltIns.groups[builtinId].name))
    Ed.RequestRefresh()
    return copy
end

local function calloutLabel(cid)
    local c = NS.Library.Callout(cid)
    if not c then return cid end
    return ("%s  |cff808080%s|r"):format(c.name or cid, c.channel or "")
end

--- What "Add a callout" offers: the user callouts not in the group, by name, then every built-in
--- callout as "<set>: <name>" (adding one copies it, spec P2).
function G.AddableCallouts(gid)
    local have = {}
    for _, cid in ipairs((NS.db.profile.groups[gid] or {}).callouts or {}) do have[cid] = true end
    local user = {}
    for id, c in pairs(NS.db.profile.callouts) do
        if not have[id] then user[#user + 1] = { id = id, label = c.name or id } end
    end
    table.sort(user, function(a, b) return a.label:lower() < b.label:lower() end)
    local out = user
    local function addSet(gidB, prefix)
        local def = NS.BuiltIns.groups[gidB]
        for _, cid in ipairs(def.callouts or {}) do
            out[#out + 1] = { id = cid, label = L["%s: %s"]:format(prefix, NS.BuiltIns.callouts[cid].name) }
        end
        for _, child in ipairs(def.children or {}) do
            addSet(child, L["%s: %s"]:format(prefix, NS.BuiltIns.groups[child].name))
        end
    end
    for _, top in ipairs(NS.BuiltIns.order) do addSet(top, NS.BuiltIns.groups[top].name) end
    return out
end

function G.AddCallout(gid, cid) return NS.Library.AddToGroup(gid, cid) end
function G.MoveCallout(gid, from, to) return NS.Library.MoveInGroup(gid, from, to) end

local NONE = L["No groups yet. Click New group to make one."]

local function renderGeneral(ctx, rows)
    local h = H()
    local gid = Ed.Selected("group")
    h.RenderRows(ctx, { Ed.Row("state.previewAs") }, nil, nil, { noHeadings = true })
    if not (gid and NS.Library.Group(gid)) then
        h.TextRow(ctx, NONE)
        return
    end
    if isBuiltin(gid) then
        h.TextRow(ctx, L["%s is a built-in set: read-only, and updated with the addon. Customize makes an editable copy in its place on every pad."]
            :format(NS.BuiltIns.groups[gid].name))
        h.RenderRows(ctx, { Ed.Row("builtin.enabled") }, nil, nil, { noHeadings = true })
        local copy = G.CustomizedAs(gid)
        h.InlineButtonPair(ctx, {
            text = copy and L["Edit the copy"] or L["Customize"],
            tooltip = copy and L["This set is already customized: open its copy."]
                or L["Copy this set into a group you can edit, in its place on every pad, and turn the set off."],
            onClick = function() G.Customize(gid) end,
        }, nil)
        return
    end
    local mine = {}
    for _, row in ipairs(Ed.Scalar(rows)) do
        if row.path ~= "state.previewAs" then mine[#mine + 1] = row end
    end
    h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this group, with the same callouts and When."],
          onClick = function() G.Duplicate(gid) end },
        { text = L["Delete"], tooltip = L["Delete this group and take it off every pad. Its callouts are kept. Asks first."],
          onClick = function() G.Delete(gid) end })
end

local function renderBuiltinCallouts(ctx, gid)
    local h = H()
    h.TextRow(ctx, L["Untick a callout to hide it from every pad. A hidden callout stays in the set."])
    local hidden = (NS.db.profile.builtins[gid] or {}).hidden or {}
    local items = {}
    local function add(cid, prefix)
        local c = NS.BuiltIns.callouts[cid]
        local label = prefix and L["%s: %s"]:format(prefix, c.name) or c.name
        items[#items + 1] = { make = function(_, parent, rel)
            local cb = h.AceGUI:Create("CheckBox")
            cb:SetLabel(label)
            cb:SetValue(not hidden[cid])
            cb:SetRelativeWidth(rel or 0.5)
            cb:SetCallback("OnValueChanged", function(_, _, v)
                NS.Library.SetBuiltinCalloutHidden(gid, cid, not v)
            end)
            h.AttachTooltip(cb, c.name, c.text)
            parent:AddChild(cb)
            return cb
        end }
    end
    local def = NS.BuiltIns.groups[gid]
    for _, cid in ipairs(def.callouts or {}) do add(cid) end
    for _, child in ipairs(def.children or {}) do
        local node = NS.BuiltIns.groups[child]
        for _, cid in ipairs(node.callouts or {}) do add(cid, node.name) end
    end
    h.RenderGrid(ctx, items)
end

local function renderCallouts(ctx)
    local h = H()
    local gid = Ed.Selected("group")
    if not (gid and NS.Library.Group(gid)) then
        h.TextRow(ctx, NONE)
        return
    end
    if isBuiltin(gid) then return renderBuiltinCallouts(ctx, gid) end
    local list = NS.db.profile.groups[gid].callouts
    if #list == 0 then
        h.TextRow(ctx, L["No callouts in this group yet. Add one below."])
    else
        local entries = {}
        for i, cid in ipairs(list) do
            entries[i] = { id = cid, label = calloutLabel(cid),
                remove = function() NS.Library.RemoveFromGroup(gid, i) end }
        end
        Ed.ReorderRows(ctx, PAGE, entries, function(from, to) G.MoveCallout(gid, from, to) end)
    end
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Add a callout"],
        L["Add a callout to the end of this group. A built-in callout is copied into your callouts first."],
        G.AddableCallouts(gid), function(cid) G.AddCallout(gid, cid) end) })
end

local function renderPreview(ctx)
    local h = H()
    local gid = Ed.Selected("group")
    local g = gid and NS.Library.Group(gid)
    if not g then
        h.TextRow(ctx, NONE)
        return
    end
    -- Every line here is refreshed in place (Ed.Live) on a write or a situation change.
    local W = Settings.GroupsWhen
    local active = h.TextRow(ctx, W.ActiveText(gid))
    Ed.Live(ctx, function() if active then active:SetText(W.ActiveText(gid)) end end)
    local sections = NS.Surfaces.Sections(gid, NS.Library.Group)
    local any = false
    for _, sec in ipairs(sections) do
        if #sections > 1 then h.Section(ctx, sec.title) end
        local ids = sec.callouts
        local function lines()
            local out = {}
            for _, cid in ipairs(ids) do
                local c = NS.Library.Callout(cid)
                if c then out[#out + 1] = L["%s: %s"]:format(c.name, Settings.Callouts.PreviewLines(c)[1]) end
            end
            return out
        end
        local now = lines()
        if #now > 0 then
            any = true
            local label = h.TextRow(ctx, table.concat(now, "\n"))
            Ed.Live(ctx, function() if label then label:SetText(table.concat(lines(), "\n")) end end)
        end
    end
    if not any then h.TextRow(ctx, L["This group has no callouts yet."]) end
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

local function render(ctx)
    local h = H()
    local entries = G.Entries()
    local selected = Ed.Heal("group", ids(entries))
    Ed.Select("group", selected)   -- keeps the built-in selection in step after a heal
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Group"], list = list, order = order, value = selected,
        tooltip = L["Which group this page edits. A green dot marks a group active now (or in the preview)."],
        onSelect = function(v)
            Ed.Select("group", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New group"], tooltip = L["Make a new group, put it at the top of every pad, and edit it here."],
            onClick = G.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = "callouts", label = L["Callouts"], tooltip = L["The callouts this group shows, in order."],
          before = WHEN, render = renderCallouts },
        { key = WHEN, render = function(c) Settings.GroupsWhen.Render(c, Ed.Selected("group")) end },
        { key = "preview", label = L["Preview"], tooltip = L["What each callout sends here, or in the preview."],
          render = renderPreview },
    })
end

--- The page's Defaults (options-ui-§13: page-wide, what the page draws). A user group: every row of
--- the page. A built-in set: its group rows refuse every write, and its General draws Preview as and
--- the overlay's Enabled row (whose page is share), so those two are what it resets, as one act.
function G.RestoreDefaults(ctx)
    local h = H()
    if not isBuiltin(Ed.Selected("group")) then return h.RestoreDefaults(PAGE, ctx) end
    local S = NS.SchemaRuntime
    S.BulkRun("reset", PAGE, function()
        S.ApplyDefault(Ed.Row("state.previewAs"))
        S.ApplyDefault(Ed.Row("builtin.enabled"))
    end)
    if h.RefreshPanel then h.RefreshPanel(ctx, false) end
end

Ed.RegisterPage(PAGE, L["Groups"], "GroupsPanel", render, {
    tooltip = L["Turn the selected group or built-in set back on, stop it opening the dial, and turn Preview as off. Its name, callouts and When are kept."],
    onClick = function(ctx) G.RestoreDefaults(ctx) end,
})
