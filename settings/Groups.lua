local _, NS = ...
-- settings/Groups.lua — the Groups page (design spec §13.1, §12.2): one group at a time, a user group
-- or a built-in set.
--
--     band      [ Group v (picker; a green dot marks a group active now) ][ New group ]
--     strip     [ General ][ Callouts ][ When ][ Preview ]
--     General   Preview as (page-wide, first), then Name, Icon, Enabled, Open the dial on this group,
--               Choose an icon (settings/Editors.lua's picker), then Duplicate and Delete. A built-in:
--               what it is, its Enabled row, and Customize.
--     Callouts  a user group's: Add callout (the callout popup, settings/CalloutPopup.lua), Reuse
--               existing callout with Add (an independent copy, of a user or a built-in callout, spec
--               P2), then its callouts as a drag-to-reorder list with an edit and a remove glyph each.
--               The group owns its callouts, so remove deletes the callout (asking first). A
--               built-in: a Show checkbox per callout, the hidden-callouts editor (spec §12.2).
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

--- New group: create it and put it at the top of every pad and dial, as one act (Library.Batch), so
--- the pads rebuild once.
function G.Create()
    local gid = NS.Library.Batch(function()
        local id = NS.Library.CreateGroup({ name = L["New group"] })
        if id then NS.Library.OfferGroup(id) end
        return id
    end)
    if not gid then return nil end
    Ed.Select("group", gid)
    Ed.RequestRefresh()
    return gid
end

--- Duplicate: the copy is on no pad or dial (Library.DuplicateGroup), and the chat line says so and
--- where to add it.
function G.Duplicate(id)
    local copy = NS.Library.DuplicateGroup(id)
    if copy then
        NS.Print(L["%s: the copy is on no pad yet. Add it under Comms Pad > Groups."]:format(NS.db.profile.groups[copy].name))
        Ed.Select("group", copy)
        Ed.RequestRefresh()
    end
    return copy
end

--- Delete asks first, and says the group's callouts go with it (the group owns them).
function G.Delete(id)
    local g = NS.db.profile.groups[id]
    if not g then return end
    Ed.ConfirmDelete(g.name, function() NS.Library.DeleteGroup(id) end,
        L["Delete '%s' and its callouts? This cannot be undone."])
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
    local copy, _, _, placed = NS.Library.Customize(builtinId)
    if not copy then return nil end
    Ed.Select("group", copy)
    local name = NS.BuiltIns.groups[builtinId].name
    if (placed or 0) > 0 then
        NS.Print(L["%s customized: the copy took its place on every pad."]:format(name))
    else
        NS.Print(L["%s customized. The set was on no pad, so the copy is on none: add it under Comms Pad > Groups."]:format(name))
    end
    Ed.RequestRefresh()
    return copy
end

local function calloutLabel(cid)
    local c = NS.Library.Callout(cid)
    if not c then return cid end
    return ("%s  |cff808080%s|r"):format(c.name or cid, c.channel or "")
end

--- What Reuse existing callout offers: every user callout as "<its group>: <name>", sorted by that
--- label (the selected group's own included: copying within a group is fine), then every built-in
--- callout as "<set>: <name>" (a node's "<set>: <node>: <name>"). Add copies the pick (spec P2).
function G.ReusableCallouts()
    local p = NS.db.profile
    local owner = {}
    for gid, g in pairs(p.groups) do
        for _, cid in ipairs(g.callouts or {}) do owner[cid] = owner[cid] or g.name or gid end
    end
    local out = {}
    for id, c in pairs(p.callouts) do
        local name = c.name or id
        out[#out + 1] = { id = id, label = owner[id] and L["%s: %s"]:format(owner[id], name) or name }
    end
    table.sort(out, function(a, b)
        local la, lb = a.label:lower(), b.label:lower()
        if la ~= lb then return la < lb end
        return a.id < b.id
    end)
    -- A same-named copy (Reuse keeps the name) would list twice alike: number the repeats.
    local seen = {}
    for _, e in ipairs(out) do
        local key = e.label:lower()
        seen[key] = (seen[key] or 0) + 1
        if seen[key] > 1 then e.label = L["%s (%d)"]:format(e.label, seen[key]) end
    end
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

--- Reuse's Add: an independent copy of `cid` at the end of the group (Library.AddToGroup copies).
function G.ReuseCallout(gid, cid) return NS.Library.AddToGroup(gid, cid) end
function G.MoveCallout(gid, from, to) return NS.Library.MoveInGroup(gid, from, to) end

--- The remove glyph: asks first, then takes `cid` out of the group, which deletes it (the group
--- owns it). Found by id when the player answers, so a list that moved meanwhile loses the right one.
function G.RemoveCallout(gid, cid)
    local c = NS.Library.Callout(cid)
    if not c then return end
    Ed.ConfirmDelete(c.name or cid, function()
        local g = NS.db.profile.groups[gid]
        for i, id in ipairs(g and g.callouts or {}) do
            if id == cid then return NS.Library.RemoveFromGroup(gid, i) end
        end
    end)
end

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
    Ed.IconPicker(ctx, "group.icon", gid)
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this group, with copies of its callouts and the same When. The copy is on no pad until you add it under Comms Pad > Groups."],
          onClick = function() G.Duplicate(gid) end },
        { text = L["Delete"], tooltip = L["Delete this group and its callouts, and take it off every pad. Asks first."],
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

-- Reuse existing callout and its Add, on one row: the dropdown only picks (its prompt stands in for
-- a label, so the button lines up with it), and Add, idle until a pick, copies the pick in.
local function reuseRow(gid)
    return { wide = true, make = function(_, parent)
        local AceGUI = H().AceGUI
        local prompt, picked = L["Reuse existing callout"], nil
        local dd = AceGUI:Create("Dropdown")
        local list, order = Ed.PickerList(G.ReusableCallouts())
        dd:SetList(list, order)
        dd:SetText(prompt)
        dd:SetRelativeWidth(0.62)
        local add = AceGUI:Create("Button")
        add:SetText(L["Add"])
        add:SetRelativeWidth(0.3)
        add:SetDisabled(true)
        dd:SetCallback("OnValueChanged", function(_, _, key)
            picked = key
            add:SetDisabled(key == nil)
        end)
        add:SetCallback("OnClick", function()
            if picked == nil then return end
            local cid = picked
            picked = nil
            dd:SetValue(nil)
            dd:SetText(prompt)
            add:SetDisabled(true)
            G.ReuseCallout(gid, cid)
        end)
        H().AttachTooltip(dd, prompt, L["Pick a callout to copy into this group: one of your groups' or a built-in set's. Add puts the copy at the end."])
        H().AttachTooltip(add, L["Add"], L["Add a copy of the picked callout to the end of this group. Editing the copy leaves the original as it is."])
        parent:AddChild(dd)
        parent:AddChild(add)
        return true
    end }
end

local function renderCallouts(ctx)
    local h = H()
    local gid = Ed.Selected("group")
    if not (gid and NS.Library.Group(gid)) then
        h.TextRow(ctx, NONE)
        return
    end
    if isBuiltin(gid) then return renderBuiltinCallouts(ctx, gid) end
    h.InlineButtonPair(ctx, { text = L["Add callout"],
        tooltip = L["Make a new callout at the end of this group: its name, text, channel and icon, saved when you click Save."],
        onClick = function() Settings.CalloutPopup.Open(gid) end }, nil)
    h.RenderGrid(ctx, { reuseRow(gid) })
    local list = NS.db.profile.groups[gid].callouts
    if #list == 0 then
        h.TextRow(ctx, L["No callouts in this group yet. Add one above."])
        return
    end
    local entries = {}
    for i, cid in ipairs(list) do
        local c = NS.Library.Callout(cid)
        entries[i] = { id = cid, label = calloutLabel(cid), icon = c and c.icon or nil,
            edit = function() Settings.CalloutPopup.Open(gid, cid) end,
            editTooltip = L["Edit this callout: its name, text, channel and icon."],
            remove = function() G.RemoveCallout(gid, cid) end,
            removeTooltip = L["Delete this callout. Asks first."] }
    end
    Ed.ReorderRows(ctx, PAGE, entries, function(from, to) G.MoveCallout(gid, from, to) end)
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
    -- One act (Library.Batch): the pads rebuild once, not once per row.
    if not isBuiltin(Ed.Selected("group")) then
        return NS.Library.Batch(function() h.RestoreDefaults(PAGE, ctx) end)
    end
    local S = NS.SchemaRuntime
    NS.Library.Batch(function()
        S.BulkRun("reset", PAGE, function()
            S.ApplyDefault(Ed.Row("state.previewAs"))
            S.ApplyDefault(Ed.Row("builtin.enabled"))
        end)
    end)
    if h.RefreshPanel then h.RefreshPanel(ctx, false) end
end

Ed.RegisterPage(PAGE, L["Groups"], "GroupsPanel", render, {
    tooltip = L["Turn the selected group or built-in set back on, stop it opening the dial, and turn Preview as off. Its name, callouts and When are kept."],
    onClick = function(ctx) G.RestoreDefaults(ctx) end,
})
