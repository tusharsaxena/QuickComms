local _, NS = ...
-- settings/Dials.lua — the Comms Dial page (design spec §11, §13.1): one dial at a time.
--
--     band     [ Dial v (picker) ][ New dial ]
--     strip    [ General ][ Groups ][ Wheel ][ Icons ][ Binding ][ Preview ]
--     General  Name, Enabled, then Delete dial
--     Groups   Show groups as (Categories or Flat), the depth-3 warning (spec §11.3), then the dial's
--              groups as a drag-to-reorder list with Remove (its priority order, spec §7), then Add a
--              group
--     Wheel    wedges per ring, open at, then Position: X and Y and Reset this dial's position
--     Icons    the wedges' icons (B9, settings/SchemaIcons.lua), as the Comms Pad page's Icons tab;
--              a wedge's border is a round ring and its icon size keeps the wedge's own size
--     Binding  how Relaxed mode works, the key capture (WoW's own binding of the dial's Open Comms
--              Dial entry), the key's line and the dial's place in WoW's key bindings (spec §9.4)
--     Preview  each ring as the current or previewed situation builds it, wedge by wedge
--
-- The band holds the picker and the create action (options-ui-§14). Every field is a member row
-- (settings/SchemaMembers.lua) written to the selected dial; the dial rebuilds through LIBRARY_CHANGED
-- -> Surfaces.Request, which waits for combat end when it must. The key is no row (2026-10-20): it is
-- WoW's own binding of the dial's Open Comms Dial entry (modules/Dial.lua BindKey), captured by
-- AceGUI's Keybinding widget (Escape in it answers "", no key) and shown as GetBindingKey reads it, so
-- the box and Options -> Keybindings always agree; it is account-wide unless the player ticks
-- Character Specific Keybindings there. The page re-reads it each time it is shown (its OnShow hook),
-- so a key set in Options -> Keybindings shows on the way back. A dial past the menu's four entries
-- has no key, and its box is disabled. Relaxed is the only interaction in v0.1.0 (the
-- C7 fallback), so there is no delay or tap-action control, and depth is spec §11.3's limit, not a
-- control (owner ruling R5): the Groups tab warns when a battleground node set would open three rings
-- deep (DD.DepthWarning). The Preview tab is a listing, not a drawn wheel (owner ruling R3): the wheel
-- itself shows in game (test mode and Preview as… open dial 1). As settings/Pads.lua: New dial takes
-- the lowest free number, a refused X or Y says why and puts the box back, and Defaults is one act
-- (Library.Batch) that keeps the dial's position (and never touches its key, which is WoW's).

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "dials"
local GENERAL = L["General"]
local GROUPS = L["Groups"]
local WHEEL = L["Wheel"]
local BINDING = L["Binding"]
local ICONS = L["Icons"]

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

--- Set the dial's key: WoW's own binding of its Open Comms Dial entry ("" is no key), through
--- Dial.BindKey; a refusal prints its reason. The page's lines follow.
--- @return boolean
function DD.SetKey(id, key)
    local ok = NS.Dial.BindKey(id, key or "")
    if ok then Ed.RefreshLive() end
    return ok
end

-- Plans the page builds to look at (the depth warning, the Preview listing) are not a surface's bake:
-- they stay out of the bakeSurface perf bucket.
local function lookDeps(snap)
    local deps = NS.Surfaces.Deps(snap)
    deps.unmeasured = true
    return deps
end

--- The Binding tab's line: the dial's key (WoW's binding of its Open Comms Dial entry) and what it does
--- (spec §9.4). A dial that is off, or Quick Comms stood down, opens nothing, and the line says so.
function DD.KeyLine(id)
    local dial = NS.db.profile.dials[id]
    local place = NS.Dial.PlaceOf(id)
    if not NS.Dial.Command(place) then
        return L["No key: WoW's key bindings list Open Comms Dial 1 to %d only. Move this dial into the first %d to give it one."]
            :format(NS.Dial.BINDINGS, NS.Dial.BINDINGS)
    end
    local key = NS.Dial.KeyOf(id)
    if not key then
        return L["No key yet. Click the box and press one, or bind Open Comms Dial %d in WoW's key bindings: it is the same key."]:format(place)
    end
    if dial and dial.enabled == false then
        return L["%s is bound to Open Comms Dial %d in WoW's key bindings, but this dial is off: it opens nothing until the dial is enabled."]:format(key, place)
    end
    if NS.IsStoodDown() then
        return L["%s is bound to Open Comms Dial %d in WoW's key bindings, but Quick Comms is off: it opens nothing until Quick Comms is enabled."]:format(key, place)
    end
    return L["%s opens and closes this dial."]:format(key)
end

--- Which Open Comms Dial entry in WoW's key bindings this dial is: its place in the dial list, so the
--- number changes when a dial above it is deleted; and that the key is account-wide unless the player
--- ticks Character Specific Keybindings.
function DD.PlaceLine(id)
    local place = NS.Dial.PlaceOf(id)
    if not place then return "" end
    if NS.Dial.Command(place) then
        return L["In WoW's key bindings, under Ka0s Quick Comms, this dial is Open Comms Dial %d."]:format(place)
            .. " " .. L["The number is its place in the dial list: it changes when a dial above it is deleted."]
            .. " " .. L["The key is for every character, unless you tick Character Specific Keybindings there."]
    end
    return L["This dial is number %d in the dial list."]:format(place)
end

--- The Groups tab's warning (spec §11.3: depth 3 is allowed, with the editor warning): the seeded
--- battleground sets with nodes on this dial (a group seeded from a `bi.bg.` set that holds groups)
--- that would open three rings deep in their own battleground, because a group listed above is
--- active there too (built under that battleground's Preview as… snapshot). Nil when there is none,
--- or in Flat, which has no depth.
--- @return string|nil
function DD.DepthWarning(id)
    local dial = NS.db.profile.dials[id]
    if not dial or dial.mode == "flat" then return nil end
    local names = {}
    for _, gid in ipairs(dial.groups) do
        local short = NS.Library.SeededBattleground(gid)
        local preset = short and #NS.Library.Children(gid) > 0 and NS.Preview.FindPreset("bg:" .. short)
        if preset and preset.snapshot then
            local snap = preset.snapshot
            local plan = NS.Surfaces.BuildDialPlan(id, dial, snap, lookDeps(snap))
            for _, title in ipairs(NS.DialLayout.DeepGroups(plan.rings, plan.openRing)) do names[#names + 1] = title end
        end
    end
    if #names == 0 then return nil end
    return L["Three rings deep: %s. A group listed above it is active in that battleground too, so the dial opens on the groups instead of the nodes. Move the battleground to the top of the list to open straight on its nodes."]:format(table.concat(names, ", "))
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
            local dir = NS.DialLayout.Direction(item.wedge or i, ring.size)
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
    -- Spec §11.3's editor warning; a mode write refreshes in place, so the line follows it.
    local warn = h.TextRow(ctx, DD.DepthWarning(id) or "")
    Ed.Live(ctx, function() if warn then warn:SetText(DD.DepthWarning(id) or "") end end)
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

-- The key capture: AceGUI's Keybinding widget, showing WoW's own binding of the dial's entry
-- (Dial.KeyOf). The widget shows a pressed key before it fires OnKeyChanged, and a refused bind
-- changes nothing, so the callback itself puts the box back to the bound key; the live line follows
-- binds made elsewhere (Options -> Keybindings, read again when the page is shown). A dial past the
-- menu's entries has no key: the box is disabled. (The kit's AceGUI fake has no SetKey; the guard
-- keeps the page drawable there.)
local function keyBox(ctx, id)
    local function show(kb)
        if kb.SetKey then kb:SetKey(NS.Dial.KeyOf(id) or "") end
    end
    return { make = function(_, parent, rel)
        local kb = H().AceGUI:Create("Keybinding")
        kb:SetLabel(L["Key"])
        show(kb)
        Ed.Live(ctx, function() show(kb) end)
        kb:SetDisabled(NS.Dial.Command(NS.Dial.PlaceOf(id)) == nil)
        kb:SetRelativeWidth(rel or 0.5)
        kb:SetCallback("OnKeyChanged", function(_, _, value)
            -- A refusal (its line already printed) puts the box back to the stored key.
            if not DD.SetKey(id, value) then show(kb) end
        end)
        H().AttachTooltip(kb, L["Key"], L["Click, then press the key you want, with Alt, Ctrl or Shift if you like. Escape clears it. This is WoW's own key binding (Options, Keybindings, Ka0s Quick Comms): changing it in either place changes both."])
        parent:AddChild(kb)
        return kb
    end }
end

local function renderBinding(ctx)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.TextRow(ctx, L["Relaxed: press the key to open the dial and click a wedge to send. The key again, Escape or a right click closes it; a click in the middle goes back a ring. The number keys 1 to 8 pick a wedge, and the mouse wheel turns pages."])
    h.RenderGrid(ctx, { keyBox(ctx, id) })
    local line = h.TextRow(ctx, DD.KeyLine(id))
    Ed.Live(ctx, function() if line then line:SetText(DD.KeyLine(id)) end end)
    local placeRow = h.TextRow(ctx, DD.PlaceLine(id))
    Ed.Live(ctx, function() if placeRow then placeRow:SetText(DD.PlaceLine(id)) end end)
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
        { key = ICONS, render = renderIcons },
        { key = BINDING, render = renderBinding },
        { key = "preview", label = L["Preview"], tooltip = L["What each ring holds here, or in the preview."],
          render = renderPreview },
    })
end

Ed.RegisterPage(PAGE, L["Comms Dial"], "DialsPanel", render, {
    tooltip = L["Put the selected dial's groups-as, wedges per ring, where it opens and its icons back to their defaults, and turn it on. Its name, groups, key and position are kept."],
    -- One act (Library.Batch): the dials rebuild once, not once per row.
    onClick = function(ctx) NS.Library.Batch(function() H().RestoreDefaults(PAGE, ctx) end) end,
}, {
    -- WoW's key bindings may have changed while another page was shown (Options -> Keybindings).
    onShow = function() Ed.RefreshLive() end,
})
