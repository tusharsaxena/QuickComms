local addonName, NS = ...
-- settings/Editors.lua — what the editor pages share (design spec §13.1): Groups, Comms Pad, Comms
-- Dial and Share each register here, keep their selection here and repaint through here.
--
-- THE SELECTION is session state (NS.State.editing[kind], never saved): the member each page edits.
-- The band's picker sets it (options-ui-§14: the banner is the ONLY picker), and the member rows
-- resolve against it when the panel or the CLI writes with no instance argument (settings/Schema.lua).
-- Heal keeps it on a member that exists; a profile switch clears it (the ids were the old profile's).
--
-- THE REPAINT (options-ui-§11: re-render only when what invalidates the layout changed, never on every
-- write). A member changes from a widget's own callback, a popup, a slash verb, the pad's drag or a
-- profile switch. A structural refresh of every built page, ONE, on the next frame and coalesced (so
-- no page is torn down under the widget whose callback is running; a hidden page is only marked
-- owed), follows: a LIBRARY_CHANGED with no field (membership, order, Customize) or naming a field in
-- STRUCTURAL (a name is a picker label; a group's Enabled and When, and a set's Enabled, move the
-- active-now dot and the When tab's rows); a SITUATION_CHANGED that changes the set of active
-- groups; TEST_MODE_CHANGED (Preview as…); PROFILE_CHANGED. Any other member-row write is a scalar:
-- the seam's announce refreshes the widgets in place (Helpers.RefreshAll), and the lines a page draws
-- itself (Ed.Live) with them. A SITUATION_CHANGED that leaves the active groups alone re-runs only
-- those lines, never the library's own refreshers, so a box the player is typing in keeps its text.
-- Until a page body has been built nothing is scheduled at all.
--
-- THE REORDER LISTS are LibKa0s-Widgets' ReorderList (options-ui-§18): one controller per page,
-- canceled at the top of every render (RegisterPage's redraw, which a tab click also runs through
-- `rerender`) before ClearScroll gives the row frames back to AceGUI. Without the library there is
-- no handle and the list does not drag: the accepted degradation, with no host-drawn arrows.

local QC = NS.addon
local Settings = QC.Settings
local L = NS.L
local State = NS.State

Settings.Editors = Settings.Editors or {}
local Ed = Settings.Editors

Ed.ROW_H = 30       -- one reorderable row; the drop arithmetic's stride
Ed.HANDLE_W = 30    -- the library's handle gutter (LibKa0s-Widgets ROW_BOX.HANDLE_W)
Ed.ACTIVE_DOT = "|TInterface\\COMMON\\Indicator-Green:12|t "
Ed.pages, Ed.built, Ed.categories, Ed.reorders, Ed.redraw = {}, {}, {}, {}, {}

local function H() return Settings.Helpers end

-- ── the selection ───────────────────────────────────────────────────────────────────────────

function Ed.Selected(kind)
    return State.editing[kind]
end

--- Select the member a page edits. A built-in group is also the built-in overlay's selection, so the
--- `builtin.*` rows address the set the Groups page shows.
function Ed.Select(kind, id)
    State.editing[kind] = id
    if kind == "group" then
        State.editing.builtin = (id ~= nil and NS.Library.IsBuiltin(id)) and id or nil
    end
end

--- Keep a page's selection on a member that exists: the current one, else the first of `ids`.
--- @return string|nil the selection
function Ed.Heal(kind, ids)
    local current = State.editing[kind]
    for _, id in ipairs(ids) do
        if id == current then return current end
    end
    Ed.Select(kind, ids[1])
    return ids[1]
end

--- The snapshot an editor shows its lines against: the previewed one while "Preview as…" is on.
function Ed.Snapshot()
    return NS.Preview.PreviewSnapshot() or NS.Situation.Current()
end

--- O.PageBanner's list and order, from ordered { id, label } entries.
function Ed.PickerList(entries)
    local list, order = {}, {}
    for i, e in ipairs(entries) do
        list[e.id] = e.label
        order[i] = e.id
    end
    return list, order
end

-- ── the repaint ─────────────────────────────────────────────────────────────────────────────

local pending, lastActive

--- The member-row paths whose write changes what a page draws, not only a value in place.
Ed.STRUCTURAL = { ["callout.name"] = true, ["group.name"] = true, ["group.enabled"] = true,
    ["group.when"] = true, ["pad.name"] = true, ["dial.name"] = true, ["builtin.enabled"] = true }

-- The ids of the groups active under the editors' snapshot, as one comparable string.
local function activeKey()
    if not (NS.db and NS.db.profile) then return "" end
    local ids = {}
    for id in pairs(NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end

--- One structural refresh of every built editor page, on the next frame, however many changes ask.
--- Nothing is scheduled while no page body has been built (a player who never opens the settings).
function Ed.RequestRefresh()
    if pending or next(Ed.built) == nil then return end
    pending = QC:ScheduleTimer(function()
        pending = nil
        lastActive = activeKey()
        local h = H()
        if not (h and h.RefreshPanel) then return end
        for _, ctx in pairs(Ed.built) do h.RefreshPanel(ctx, true) end
    end, 0)
end

function Ed.Pending()
    return pending ~= nil
end

--- A line the page draws itself (the baked line, the active-now line, the token list): `fn` puts it
--- back to current state in place. It runs with the library's refreshers on every scalar write, and
--- on its own on a situation change that leaves the active groups alone (Ed.RefreshLive).
function Ed.Live(ctx, fn)
    ctx.qcLive = ctx.qcLive or {}
    ctx.qcLive[#ctx.qcLive + 1] = fn
    if ctx.refreshers then ctx.refreshers[#ctx.refreshers + 1] = fn end
end

function Ed.RefreshLive()
    for _, ctx in pairs(Ed.built) do
        for _, fn in ipairs(ctx.qcLive or {}) do pcall(fn) end
    end
end

local function onLibraryChanged(_, _, _, field)
    if field ~= nil and not Ed.STRUCTURAL[field] then return end
    Ed.RequestRefresh()
end

local function onSituationChanged()
    if next(Ed.built) == nil then return end
    local key = activeKey()
    if key ~= lastActive then
        lastActive = key
        return Ed.RequestRefresh()
    end
    Ed.RefreshLive()
end

local function onProfileChanged()
    for kind in pairs(State.editing) do State.editing[kind] = nil end
    for gid in pairs(State.whenOpen or {}) do State.whenOpen[gid] = nil end
    -- The Share page's ticks and checked string name the old profile's ids.
    State.share.pick = { group = {}, pad = {}, dial = {} }
    State.share.import = nil
    Ed.RequestRefresh()
end

local HANDLERS = {
    { NS.MSG.LIBRARY_CHANGED, onLibraryChanged },
    { NS.MSG.SITUATION_CHANGED, onSituationChanged },
    { NS.MSG.TEST_MODE_CHANGED, function() Ed.RequestRefresh() end },
    { NS.MSG.PROFILE_CHANGED, onProfileChanged },
}

-- Its own target (core/Bus.lua): one target holds several different messages.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if not receiver then return end
    for _, h in ipairs(HANDLERS) do receiver:RegisterMessage(h[1], h[2]) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if pending then QC:CancelTimer(pending) end
    pending, lastActive = nil, nil
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end

-- ── rows ────────────────────────────────────────────────────────────────────────────────────

function Ed.Row(path)
    return NS.SchemaRuntime.FindRow(path)
end

-- The structured member rows (settings/SchemaMembers.lua): a table each, drawn by the page's own controls.
local STRUCTURED = { point = true, when = true, idset = true, key = true }

--- The rows the flow engine draws: a structured row has its own control on its page.
function Ed.Scalar(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
        if not STRUCTURED[row.type] then out[#out + 1] = row end
    end
    return out
end

--- A dropdown that acts on the choice at once ("Add a group", "Insert a token"), as a RenderGrid item.
--- `entries` is a list, or a function; with `ctx`, a function is re-read in place (Ed.Live), so a
--- list that depends on a field (the token list on the callout's channel) follows it without a repaint.
function Ed.ActionDropdown(label, tooltip, entries, onPick, ctx)
    local function current()
        if type(entries) == "function" then return entries() end
        return entries
    end
    return { make = function(_, parent, rel)
        local h = H()
        local dd = h.AceGUI:Create("Dropdown")
        dd:SetLabel(label)
        local list, order = Ed.PickerList(current())
        dd:SetList(list, order)
        if ctx and type(entries) == "function" then
            Ed.Live(ctx, function() dd:SetList(Ed.PickerList(current())) end)
        end
        dd:SetRelativeWidth(rel or 0.5)
        dd:SetCallback("OnValueChanged", function(_, _, key) onPick(key) end)
        h.AttachTooltip(dd, label, tooltip)
        parent:AddChild(dd)
        return dd
    end }
end

-- ── the icon (icon browser spec, "Goals") ───────────────────────────────────────────────────

-- Where an editor's icon is chosen (the callout popup, a user group's General tab), under its Icon
-- box: the icon as it is drawn (a glyph in its color; a question mark for none), Choose icon…, which
-- opens the icon browser (settings/IconBrowser.lua) over whatever opened it, and the glyph's color
-- swatch, live only while the icon is a glyph (no other icon takes a color). Every control writes
-- through `spec`, never the profile itself, and the row is put back in place (Ed.Live) after any write.
Ed.NO_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local CHOOSER_ICON = 32

--- Open the icon browser on what `spec.get()` answers (see Ed.IconChooser).
--- @return boolean opened
function Ed.OpenIconBrowser(spec)
    local icon, color = spec.get()
    return Settings.IconBrowser.Open({ icon = icon, color = color, onChoose = spec.choose,
        owner = spec.owner, lift = spec.lift, valid = spec.valid })
end

-- The swatch's write: the picked color as stored (white is none), only when it changed. AceGUI's
-- ColorPicker sends OnValueChanged on every drag tick while the picker is open, and OK confirms
-- nothing new (its color is the last tick's), so the swatch writes on both callbacks, as
-- AceConfigDialog does; Cancel confirms the old color, which puts it back.
local function swatchWrite(spec, r, g, b)
    local _, current = spec.get()
    local picked = NS.Library.IconColorFrom(r, g, b) or nil
    if picked ~= (current or nil) then spec.setColor(picked) end
end

--- The chooser, as one row. `spec` = { get() -> icon, color; choose(icon, color) (the browser's
--- Choose); setColor(color|nil) (the swatch); owner, lift, valid (handed to the browser) }.
function Ed.IconChooser(ctx, spec)
    local h = H()
    h.RenderGrid(ctx, { { wide = true, make = function(_, parent)
        local AceGUI = h.AceGUI
        local preview = AceGUI:Create("Icon")
        preview:SetImageSize(CHOOSER_ICON, CHOOSER_ICON)
        preview:SetWidth(48)
        preview:SetHeight(44)
        preview:SetCallback("OnClick", function() Ed.OpenIconBrowser(spec) end)
        h.AttachTooltip(preview, L["Icon"], L["Click to choose another icon."])
        local choose = AceGUI:Create("Button")
        choose:SetText(L["Choose icon…"])
        choose:SetRelativeWidth(0.4)
        choose:SetCallback("OnClick", function() Ed.OpenIconBrowser(spec) end)
        h.AttachTooltip(choose, L["Choose icon…"], L["Pick from the raid markers, the game's icons and the LibKa0s glyphs."])
        local swatch = AceGUI:Create("ColorPicker")
        swatch:SetLabel(L["Icon color"])
        swatch:SetHasAlpha(false)
        swatch:SetRelativeWidth(0.4)
        local function pick(_, _, r, g, b) swatchWrite(spec, r, g, b) end
        swatch:SetCallback("OnValueChanged", pick)
        swatch:SetCallback("OnValueConfirmed", pick)
        h.AttachTooltip(swatch, L["Icon color"], L["The color a LibKa0s glyph is drawn in. Only a glyph takes a color; white is none."])
        local function paint()
            local icon, color = spec.get()
            preview:SetImage(icon or Ed.NO_ICON)
            Ed.Tint(preview.image, icon, color)
            swatch:SetColor(NS.Library.IconTint(icon, color))
            swatch:SetDisabled(not NS.Library.IsGlyph(icon))
        end
        paint()
        Ed.Live(ctx, paint)
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        row:AddChild(preview)
        row:AddChild(choose)
        row:AddChild(swatch)
        parent:AddChild(row)
        return row
    end } })
end

-- ── the reorder lists (options-ui-§18) ──────────────────────────────────────────────────────

function Ed.CancelReorder(pageKey)
    local r = Ed.reorders[pageKey]
    Ed.reorders[pageKey] = nil
    if r then r:Cancel() end
end

local function newReorder(pageKey, onMove)
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    if not (W and W.ReorderList) then return nil end
    local r = W.ReorderList{
        stride        = Ed.ROW_H,
        handleIcon    = NS.Icon("segment"),
        handleTooltip = L["Drag to reorder"],
        onMove        = onMove,
    }
    Ed.reorders[pageKey] = r
    return r
end

-- The row's glyph buttons (Consumable Master's precedent: the catalog's mark first, Blizzard's where
-- the catalog has none): a 22px clickable icon with a tooltip, tagged in `userdata.qcGlyph` so a test
-- finds it. `atlas` dresses the Icon's own texture after it is made; `texture` is a plain path.
local GLYPH, GLYPH_W, ROW_ICON = 22, 32, 18
local GLYPHS = {
    edit   = { texture = function() return NS.Icon("edit") end, title = function() return L["Edit"] end },
    remove = { atlas = "transmog-icon-remove", title = function() return L["Remove"] end },
}

local function addGlyph(h, into, kind, onClick, tooltip)
    local spec = GLYPHS[kind]
    local g = h.AceGUI:Create("Icon")
    g:SetImageSize(GLYPH, GLYPH)
    if spec.atlas then
        g.image:SetAtlas(spec.atlas)
    else
        g:SetImage(spec.texture())
    end
    g:SetWidth(GLYPH_W)
    g:SetHeight(Ed.ROW_H)
    g.userdata.qcGlyph = kind
    g:SetCallback("OnClick", function() onClick() end)
    h.AttachTooltip(g, spec.title(), tooltip)
    into:AddChild(g)
    return g
end

--- Draw `texture` (an AceGUI widget's image) in icon `icon`'s glyph color, or white: AceGUI pools its
--- widgets and a pooled texture keeps the last tint it was given, so an untinted icon is set white.
function Ed.Tint(texture, icon, color)
    if texture then texture:SetVertexColor(NS.Library.IconTint(icon, color)) end
end

--- One uniform row per entry ({ id, label, icon = texture|nil, iconColor = "rrggbb"|nil, edit = fn|nil, editTooltip = string|nil,
--- remove = fn|nil, removeTooltip = string|nil }): the library's handle in the gutter at the left, the
--- entry's icon (when set, a glyph in its color) and its label, then the edit and remove glyphs at the right. With
--- `onMove(from, to)` the rows drag; the list's one write and one repaint are the host's (Library,
--- then LIBRARY_CHANGED).
function Ed.ReorderRows(ctx, pageKey, entries, onMove)
    local h = H()
    local scroll = h.EnsureScroll(ctx)
    if not (h.AceGUI and scroll) then return end
    local built, items = {}, {}
    for i, e in ipairs(entries) do
        items[i] = { wide = true, make = function(_, into)
            local AceGUI = h.AceGUI
            into:SetLayout("Flow")
            into:SetAutoAdjustHeight(false)
            into:SetHeight(Ed.ROW_H)
            local gutter = AceGUI:Create("Label")
            gutter:SetText("")
            gutter:SetWidth(Ed.HANDLE_W)
            into:AddChild(gutter)
            -- The label takes what the glyphs leave; AceGUI's Label draws its image left of its text.
            local glyphs = (e.edit and 1 or 0) + (e.remove and 1 or 0)
            local label = AceGUI:Create("Label")
            label:SetText(e.label)
            if e.icon then
                label:SetImage(e.icon)
                label:SetImageSize(ROW_ICON, ROW_ICON)
            end
            Ed.Tint(label.image, e.icon, e.iconColor)
            -- AceGUI's Label never resets its image's color on acquire, and its pool is shared with
            -- every addon: put the tint back to white when the row is released (options-ui-§19).
            label:SetCallback("OnRelease", function(w)
                if w.image then w.image:SetVertexColor(1, 1, 1, 1) end
            end)
            label:SetRelativeWidth(0.85 - 0.06 * glyphs)
            into:AddChild(label)
            if e.edit then addGlyph(h, into, "edit", e.edit, e.editTooltip) end
            if e.remove then addGlyph(h, into, "remove", e.remove, e.removeTooltip) end
            built[#built + 1] = { group = into, entry = e }
            return true
        end }
    end
    h.RenderGrid(ctx, items, scroll, { gap = false })
    if not onMove then return end
    local r = newReorder(pageKey, onMove)
    if not r then return end
    for _, b in ipairs(built) do r:AddRow(b.group.frame, { ghostText = b.entry.label }) end
    r:Finish(scroll.content or scroll.frame)
end

-- ── pages ───────────────────────────────────────────────────────────────────────────────────

--- The strip and the active tab, through the library's tabbed renderer with the page's host tabs. A
--- tab click runs the page's whole redraw (`rerender`), so the reorder cancel and the band come first.
function Ed.Tabs(ctx, pageKey, tabs)
    return H().RenderTabbedSchema(ctx, pageKey, nil, nil, { tabs = tabs, rerender = Ed.redraw[pageKey] })
end

--- Register one editor page (options-ui-§3, §5): its canvas, a body built on first show, its place in
--- the sidebar and its Defaults button (`defaults = { tooltip, onClick(ctx) }`; options-ui-§13: its
--- blast radius is the selected member). `render(ctx)` draws the band, the strip and the active tab.
function Ed.RegisterPage(pageKey, title, frameSuffix, render, defaults)
    local function redraw(ctx)
        Ed.CancelReorder(pageKey)
        H().ClearScroll(ctx)
        ctx.qcLive = {}
        Ed.built[pageKey] = ctx
        render(ctx)
    end
    Ed.redraw[pageKey] = redraw
    H().RegisterOptionsPage(pageKey, title, function(parentCategory)
        local h = H()
        local ctx = h.CreatePanel(addonName .. frameSuffix, title, {
            pageKey = pageKey, defaultsButton = true, defaultsTooltip = defaults.tooltip })
        ctx.panel.defaultsOnClick = function() defaults.onClick(ctx) end
        h.SetRenderer(ctx, redraw)
        Ed.pages[pageKey] = ctx
        local category = _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, title)
        Ed.categories[pageKey] = category
        return category
    end)
end

-- ── acts ────────────────────────────────────────────────────────────────────────────────────

local DELETE_POPUP = "QUICKCOMMS_DELETE_MEMBER"

--- Ask before deleting `name`; `onAccept` runs only when the player accepts. It is the popup's data,
--- so a popup accepted after combat started still runs it: a delete is a data write, and the pads
--- pick it up at combat end. `text` (optional, with one %s for the name) says more than the plain
--- question, as a group's delete does about its callouts; each ask sets the text afresh.
function Ed.ConfirmDelete(name, onAccept, text)
    StaticPopupDialogs[DELETE_POPUP] = StaticPopupDialogs[DELETE_POPUP] or {
        button1      = YES or "Yes",
        button2      = NO or "No",
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept     = function(_, data) if type(data) == "function" then data() end end,
    }
    StaticPopupDialogs[DELETE_POPUP].text = text or L["Delete '%s'? This cannot be undone."]
    StaticPopup_Show(DELETE_POPUP, name, nil, onAccept)
end

--- Open the settings at another editor page (Customize, Choose callouts). The page repaints from
--- the selection the caller set. Refused in combat, here rather than at each caller: Blizzard's
--- category switch is protected (options-ui-§2's page-jump carve-out is combat-gated).
--- @return boolean opened
function Ed.Open(pageKey)
    if NS.Compat.InCombat() then
        NS.Print("|cffaaaaaa" .. L["cannot open settings during combat \226\128\148 Blizzard's category-switch is protected"] .. "|r")
        return false
    end
    Ed.RequestRefresh()
    local category = Ed.categories[pageKey]
    local S = _G.Settings
    if not (category and type(category.GetID) == "function" and S and S.OpenToCategory) then return false end
    S.OpenToCategory(category:GetID())
    return true
end
