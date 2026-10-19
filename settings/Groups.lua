local _, NS = ...
-- settings/Groups.lua — the Groups page (design spec §13.1): one group at a time. A seeded built-in
-- set is an ordinary group here (2026-10-18-builtins-as-groups-design.md, goal 1).
--
--     band      [ Group v (picker; a green dot marks a group active now; a group inside another is
--               listed indented under it) ][ New group ]
--               [x] Preview while editing (behavior.previewOnEdit: every pad and dial shows only
--               the group picked, while this page is shown; G.SyncEditPreview)
--     strip     [ General ][ Callouts ][ When ][ Preview ]
--     General   Name, Enabled, Open the dial on this group, then
--               Parent group (none, or a top-level group; idle while the group holds groups) beside
--               Inherit when conditions (grayed out with no parent), then
--               the icon under an Icon label with Choose icon…, the clear glyph and its color swatch
--               (settings/Editors.lua's chooser, no Icon text box; the icon browser writes icon and
--               color as one act), then Duplicate and Delete, then Restore built-in groups (page-wide:
--               every shipped set, node and callout the profile no longer has comes back).
--     Callouts  Add callout (the callout popup, settings/CalloutPopup.lua), Reuse callout with Add (an
--               independent copy of another group's callout, spec P2), then its callouts as a
--               drag-to-reorder list ([icon] gold name, channel in its chat color, muted text cut
--               at 40 characters) with an edit and a remove glyph each. The group owns its
--               callouts, so remove deletes the callout (asking first).
--     When      settings/Groups_When.lua
--     Preview   the active-now line, then a table (Ed.TableRows): one boxed row per callout, its name
--               beside what it sends under the current or previewed situation, or why it sends nothing;
--               a group holding groups has a titled table for its own callouts, then one per child
--
-- The band holds the picker, the create action and the page-wide Preview while editing box
-- (options-ui-§14, through O.PageHeader: a picker with another page-wide control); the acts are
-- General's, which is first. A new group goes to the top of every pad and dial (Library.OfferGroup), so it shows as
-- soon as its When matches.

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

-- What a child's picker entry starts with: it reads as inside the group listed above it.
G.CHILD_INDENT = "    "

--- Picker entries in the page's order (Library.MemberIds: the groups by name, each with its
--- children under it, indented by CHILD_INDENT); a group active under the current or previewed
--- situation carries a green dot.
function G.Entries()
    local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("group")) do
        local text = NS.db.profile.groups[id].name or id
        local indent = NS.Library.IsChild(id) and G.CHILD_INDENT or ""
        out[#out + 1] = { id = id, label = indent .. (active[id] and Ed.ACTIVE_DOT or "") .. text }
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
--- where to add it; a child's copy sits in the same parent, and the line says that instead.
function G.Duplicate(id)
    local copy = NS.Library.DuplicateGroup(id)
    if copy then
        local g = NS.db.profile.groups[copy]
        if NS.Library.IsChild(copy) then
            NS.Print(L["%s: the copy is inside %s, beside the original."]:format(g.name, NS.db.profile.groups[g.parent].name))
        else
            NS.Print(L["%s: the copy is on no pad yet. Add it under Comms Pad > Groups."]:format(g.name))
        end
        Ed.Select("group", copy)
        Ed.RequestRefresh()
    end
    return copy
end

--- Delete asks first, and says the group's callouts go with it (the group owns them), and, for a
--- parent, that the groups inside it stay, as top-level groups in its place (Library.DeleteGroup).
function G.Delete(id)
    local g = NS.db.profile.groups[id]
    if not g then return end
    local text = L["Delete '%s' and its callouts? This cannot be undone."]
    if #NS.Library.Children(id) > 0 then
        text = L["Delete '%s' and its callouts? The groups inside it become top-level groups, in its place on every pad and dial. This cannot be undone."]
    end
    Ed.ConfirmDelete(g.name, function() NS.Library.DeleteGroup(id) end, text)
end

-- Parent group's choice for no parent: a value the group.parent row reads as none (never a group id).
G.NO_PARENT = "none"

--- What Parent group offers user group `gid`: none, then every top-level user group but `gid`, in
--- the picker's order.
function G.ParentChoices(gid)
    local out = { { id = G.NO_PARENT, label = L["None"] } }
    for _, id in ipairs(NS.Library.MemberIds("group")) do
        if id ~= gid and not NS.Library.IsChild(id) then
            out[#out + 1] = { id = id, label = NS.db.profile.groups[id].name or id }
        end
    end
    return out
end

--- Parent group's tooltip: the row's own text, or, for a group that holds groups (the dropdown is
--- idle then), which groups it holds and why it cannot go inside another.
function G.ParentTooltip(gid)
    local kids = NS.Library.Children(gid)
    if #kids == 0 then return Ed.Row("group.parent").desc end
    local names = {}
    for i, kid in ipairs(kids) do names[i] = NS.db.profile.groups[kid].name or kid end
    return L["%s holds %s, so it cannot go inside another group: groups go one level deep."]
        :format(NS.db.profile.groups[gid].name, table.concat(names, ", "))
end

-- The General tab's Parent group dropdown for user group `gid` (a RenderGrid item, half the row as
-- a schema row is): a pick writes the group.parent row through the seam, whose refusal is printed.
local function parentItem(gid)
    return { make = function(_, parent, rel)
        local h = H()
        local dd = h.AceGUI:Create("Dropdown")
        local label = Ed.Row("group.parent").label
        dd:SetLabel(label)
        local list, order = Ed.PickerList(G.ParentChoices(gid))
        dd:SetList(list, order)
        local g = NS.db.profile.groups[gid]
        dd:SetValue(NS.Library.IsChild(gid) and g.parent or G.NO_PARENT)
        dd:SetDisabled(#NS.Library.Children(gid) > 0)
        dd:SetRelativeWidth(rel or 0.5)
        dd:SetCallback("OnValueChanged", function(_, _, key)
            local ok, err, why = NS.SchemaRuntime.Set("group.parent", key, gid)
            if not ok then NS.Print(tostring(why or err)) end
        end)
        h.AttachTooltip(dd, label, G.ParentTooltip(gid))
        parent:AddChild(dd)
        return dd
    end }
end

--- Inherit when conditions' state for user group `gid`: ticked unless it stores false (absent is
--- on, 2026-10-18-when-drawers-design.md §3), and live only while the group sits inside another.
--- @return boolean checked, boolean disabled
function G.InheritState(gid)
    local g = NS.db.profile.groups[gid]
    return not (g and g.inheritWhen == false), not NS.Library.IsChild(gid)
end

-- The General tab's Inherit when conditions checkbox, beside Parent group (a RenderGrid item): drawn
-- by hand as Parent group is, since the seam reads an absent field as nil and the box reads it as on.
-- A click writes the group.inheritWhen row through the seam, whose refusal is printed.
local function inheritItem(gid)
    return { make = function(_, parent, rel)
        local h = H()
        local row = Ed.Row("group.inheritWhen")
        local cb = h.AceGUI:Create("CheckBox")
        cb:SetLabel(row.label)
        local checked, disabled = G.InheritState(gid)
        cb:SetValue(checked)
        cb:SetDisabled(disabled)
        cb:SetRelativeWidth(rel or 0.5)
        cb:SetCallback("OnValueChanged", function(_, _, v)
            local ok, err, why = NS.SchemaRuntime.Set("group.inheritWhen", v and true or false, gid)
            if not ok then NS.Print(tostring(why or err)) end
        end)
        h.AttachTooltip(cb, row.label, row.desc)
        parent:AddChild(cb)
        return cb
    end }
end

--- Restore built-in groups (Library.RestoreBuiltins): every shipped set, node and callout this
--- profile no longer has comes back as a new group or callout, a set at the end of every pad and
--- dial. It changes nothing the player has, so it does not ask first. One chat line says what came
--- back, or that nothing was missing.
--- @return table what came back { groups, callouts }
function G.RestoreBuiltins()
    local n = NS.Library.RestoreBuiltins()
    if n.groups + n.callouts == 0 then
        NS.Print(L["Every built-in group and callout is here already: nothing to restore."])
    else
        NS.Print(L["Restore built-in groups: %d groups and %d callouts came back. A set that came back is at the end of every pad and dial."]
            :format(n.groups, n.callouts))
    end
    Ed.RequestRefresh()
    return n
end

-- General's last row: Restore built-in groups, alone on its row.
local function restoreRow(ctx)
    H().InlineButtonPair(ctx, { text = L["Restore built-in groups"],
        tooltip = L["Bring back every built-in group, and every built-in callout, you deleted, as new ones: a group at the end of every pad and dial. Nothing you have is changed."],
        onClick = function() G.RestoreBuiltins() end }, nil)
end

-- A callout row (B5): [icon] the name in gold, the channel's short label in its chat color, then the
-- text in muted white, cut at PREVIEW_CHARS characters. User text is drawn literal (Share.Literal),
-- so a typed "|" never opens an escape; the cut keeps every row one line (options-ui-§18's stride).
local PREVIEW_CHARS = 40
local SHORT_CHANNEL = {
    smartGroup = L["Smart group"], smartLead = L["Smart lead"], party = L["Party"], raid = L["Raid"],
    instance = L["Instance"], raidWarning = L["Raid warning"], say = L["Say"], yell = L["Yell"],
}

local function hex(r, g, b)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- A smart kind resolves against the editor's snapshot; resolving to nothing (solo) takes PARTY's.
local function channelColor(kind)
    local concrete = NS.Channels.Resolve(kind, Ed.Snapshot(), NS.Setting("behavior.soloFallback"))
    return hex(NS.PadRender.TagColor(NS.Channels.ChatType(concrete) or "PARTY"))
end

local function preview(text)
    local head = NS.Library.FirstChars(text, PREVIEW_CHARS)
    if #head < #text then head = head .. "…" end
    return NS.Share.Literal(head)
end

local function calloutLabel(c, cid)
    if not c then return cid end
    return ("|cffffd100%s|r  |cff%s%s|r  |cffb3b3b3%s|r"):format(NS.Share.Literal(c.name or cid),
        channelColor(c.channel), SHORT_CHANNEL[c.channel] or tostring(c.channel), preview(c.text or ""))
end

-- The group part of a Reuse entry ("<group>:", a set's "<set>: <child>:") is drawn in the muted
-- gold LibKa0s gives a debug line's tag (DebugLog's c9a66b), the callout's name in white.
local MUTED_GOLD = "|cffc9a66b"
G.MUTED_GOLD = MUTED_GOLD

--- What Reuse callout offers group `gid`: every callout ("<its group>: <name>", a child group as
--- "<its parent>: <it>", so two battlegrounds' same-named nodes read apart) but `gid`'s own (a
--- seeded set's among them, 2026-10-18-builtins-as-groups-design.md), as one list sorted by group,
--- then name, case-insensitively, on the plain text. Entries that would read alike are numbered
--- ("<name> (2)") so each is unambiguous. Each entry is { id, label (the group part in MUTED_GOLD),
--- plain (the label without color) }. Add copies the pick (spec P2).
function G.ReusableCallouts(gid)
    local p = NS.db.profile
    local owner, own = {}, {}
    for id, g in pairs(p.groups) do
        for _, cid in ipairs(g.callouts or {}) do
            if not owner[cid] then
                local name = g.name or id
                local parent = NS.Library.IsChild(id) and p.groups[g.parent]
                owner[cid] = parent and L["%s: %s"]:format(parent.name or g.parent, name) or name
            end
            if id == gid then own[cid] = true end
        end
    end
    local out = {}
    for id, c in pairs(p.callouts) do
        if not own[id] then out[#out + 1] = { id = id, group = owner[id], name = c.name or id } end
    end
    -- Ties by id, so the numbering below is stable.
    table.sort(out, function(x, y)
        local gx, gy = (x.group or ""):lower(), (y.group or ""):lower()
        if gx ~= gy then return gx < gy end
        local nx, ny = x.name:lower(), y.name:lower()
        if nx ~= ny then return nx < ny end
        return x.id < y.id
    end)
    local seen = {}
    for _, e in ipairs(out) do
        local plain = e.group and L["%s: %s"]:format(e.group, e.name) or e.name
        local key = plain:lower()
        seen[key] = (seen[key] or 0) + 1
        local name = seen[key] > 1 and L["%s (%d)"]:format(e.name, seen[key]) or e.name
        e.plain = e.group and L["%s: %s"]:format(e.group, name) or name
        e.label = e.group and L["%s: %s"]:format(MUTED_GOLD .. e.group .. "|r", name) or name
        e.group, e.name = nil, nil
    end
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

--- The General tab's icon chooser for user group `gid` (Ed.IconChooser): the browser's Choose writes
--- icon and color as one act (Library.SetIcon), the swatch the color row; a refusal prints its reason.
--- The browser closes as Cancel when the group is gone.
function G.IconSpec(gid)
    local function stored()
        local g = NS.db.profile.groups[gid]
        if not g then return nil, nil end
        return g.icon or nil, g.iconColor or nil
    end
    return {
        get = stored,
        choose = function(icon, color)
            local ok, why = NS.Library.SetIcon("group", gid, icon or false, color)
            if not ok then NS.Print(tostring(why)) end
        end,
        setColor = function(color)
            local ok, err, why = NS.SchemaRuntime.Set("group.iconColor", color or false, gid)
            if not ok then NS.Print(tostring(why or err)) end
        end,
        owner = "group",
        valid = function() return NS.db.profile.groups[gid] ~= nil end,
    }
end

local NONE = L["No groups yet. Click New group to make one."]
-- The General tab's rows it leaves out of its RenderRows: Parent group (its own dropdown,
-- parentItem), Inherit when conditions (its own checkbox, inheritItem) and the icon's two rows (the
-- chooser draws them).
local UNDRAWN = { ["group.parent"] = true, ["group.inheritWhen"] = true,
    ["group.icon"] = true, ["group.iconColor"] = true, ["behavior.previewOnEdit"] = true }

local function renderGeneral(ctx, rows)
    local h = H()
    local gid = Ed.Selected("group")
    if not (gid and NS.Library.Group(gid)) then
        h.TextRow(ctx, NONE)
        restoreRow(ctx)
        return
    end
    -- The icon and its color are chosen with the icon chooser (Choose icon… and the browser's
    -- swatch), never typed: neither row is drawn as a text box (/qc still reaches both).
    local mine = {}
    for _, row in ipairs(Ed.Scalar(rows)) do
        if not UNDRAWN[row.path] then mine[#mine + 1] = row end
    end
    h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })
    h.RenderGrid(ctx, { parentItem(gid), inheritItem(gid) })
    Ed.IconChooser(ctx, G.IconSpec(gid))
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = NS.Library.IsChild(gid)
            and L["Make a copy of this group, with copies of its callouts and the same When. The copy sits in the same parent group, beside this one."]
            or L["Make a copy of this group, with copies of its callouts and the same When. The copy is on no pad until you add it under Comms Pad > Groups."],
          onClick = function() G.Duplicate(gid) end },
        { text = L["Delete"], tooltip = L["Delete this group and its callouts, and take it off every pad. Asks first."],
          onClick = function() G.Delete(gid) end })
    restoreRow(ctx)
end

-- THE RIGHT EDGE. Add callout and Reuse's Add end G.EDGE_INSET short of the content's right edge (a
-- trailing cell that wide, AceGUI's Table layout), not on it: the scroll content fills the
-- ScrollFrame's clip rect exactly, and a cell-filling button's right border on that edge is the one
-- options-ui-§8 insets so it is not shaved.
G.EDGE_INSET = 2

-- A Table row's trailing inset cell: an explicit { width = n } (a bare number under 10 is a weight).
local function insetCell(parent)
    parent:AddChild(Ed.Gap(G.EDGE_INSET))
end

-- Add callout across the row, to G.EDGE_INSET short of the right edge.
local function addCalloutRow(gid)
    return { wide = true, make = function(_, parent)
        parent:SetLayout("Table")
        parent.userdata.table = { columns = { { weight = 1, alignH = "fill" }, { width = G.EDGE_INSET } } }
        local btn = H().AceGUI:Create("Button")
        btn:SetText(L["Add callout"])
        btn:SetCallback("OnClick", function() Settings.CalloutPopup.Open(gid) end)
        H().AttachTooltip(btn, L["Add callout"], L["Make a new callout at the end of this group: its name, text, channel and icon, saved when you click Save."])
        parent:AddChild(btn)
        insetCell(parent)
        return true
    end }
end

-- Reuse callout and its Add, on one row (AceGUI's Table layout): the dropdown takes the width Add
-- leaves, Add sits at the right edge (G.EDGE_INSET short of it), the two the same height (the
-- dropdown with no label is 26px tall, AceGUI's Button 24). The dropdown only picks (its prompt
-- stands in for a label), and Add, idle until a pick, copies the pick in.
G.REUSE_ADD_W, G.REUSE_H, G.REUSE_GAP = 120, 26, 6
local function reuseRow(gid)
    return { wide = true, make = function(_, parent)
        local AceGUI = H().AceGUI
        local prompt, picked = L["Reuse callout"], nil
        parent:SetLayout("Table")
        -- The gap is a cell of its own, not the layout's spaceH, which would also come between Add
        -- and the inset cell and leave Add short of Add callout's right edge.
        parent.userdata.table = { columns = { { weight = 1, alignH = "fill" }, { width = G.REUSE_GAP },
            G.REUSE_ADD_W, { width = G.EDGE_INSET } } }
        local dd = AceGUI:Create("Dropdown")
        local list, order = Ed.PickerList(G.ReusableCallouts(gid))
        dd:SetList(list, order)
        dd:SetText(prompt)
        local add = AceGUI:Create("Button")
        add:SetText(L["Add"])
        add:SetWidth(G.REUSE_ADD_W)
        add:SetHeight(G.REUSE_H)
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
        H().AttachTooltip(dd, prompt, L["Pick a callout to copy into this group, from any of your other groups. Add puts the copy at the end."])
        H().AttachTooltip(add, L["Add"], L["Add a copy of the picked callout to the end of this group. Editing the copy leaves the original as it is."])
        parent:AddChild(dd)
        parent:AddChild(Ed.Gap(G.REUSE_GAP))
        parent:AddChild(add)
        insetCell(parent)
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
    h.RenderGrid(ctx, { addCalloutRow(gid) })
    h.RenderGrid(ctx, { reuseRow(gid) })
    local list = NS.db.profile.groups[gid].callouts
    if #list == 0 then
        h.TextRow(ctx, L["No callouts in this group yet. Add one above."])
        return
    end
    local entries = {}
    for i, cid in ipairs(list) do
        local c = NS.Library.Callout(cid)
        entries[i] = { id = cid, label = calloutLabel(c, cid), ghost = c and c.name or cid,
            icon = c and c.icon or Ed.NO_ICON, iconColor = c and c.iconColor or nil,
            edit = function() Settings.CalloutPopup.Open(gid, cid) end,
            editTooltip = L["Edit this callout: its name, text, channel and icon."],
            remove = function() G.RemoveCallout(gid, cid) end,
            removeTooltip = L["Delete this callout. Asks first."] }
    end
    Ed.ReorderRows(ctx, PAGE, entries, function(from, to) G.MoveCallout(gid, from, to) end)
end

-- The Preview table's column headings.
local PREVIEW_HEADER = { name = L["Callout"], text = L["What it sends here"] }

--- What the Preview tab tabulates for group `gid` (Surfaces.Sections: the group; or, for a group
--- holding groups, its own callouts when it has any, then each child): one block per section,
--- titled when there are several or the one is a child's, each row a callout's name and icon and its first preview line
--- (Callouts.PreviewLines), read when drawn and again on each live refresh.
function G.PreviewBlocks(gid)
    local sections = NS.Surfaces.Sections(gid, NS.Library.Group, { children = NS.Library.Children })
    local blocks = {}
    for _, sec in ipairs(sections) do
        local rows = {}
        for _, cid in ipairs(sec.callouts) do
            local c = NS.Library.Callout(cid)
            if c then
                rows[#rows + 1] = { label = c.name or cid, icon = c.icon, iconColor = c.iconColor,
                    text = function()
                        local now = NS.Library.Callout(cid)
                        return now and Settings.Callouts.PreviewLines(now)[1] or ""
                    end }
            end
        end
        -- Titled when there are several, or when the one section is a child's (a parent with no
        -- callouts of its own and one child), so the table never reads as the parent's own.
        local titled = #sections > 1 or sec.groupId ~= gid
        blocks[#blocks + 1] = { title = titled and sec.title or nil, rows = rows }
    end
    return blocks
end

-- The Preview tab: the active-now line, then the table (Ed.TableRows), or a line saying the group
-- has no callouts.
local function renderPreview(ctx)
    local h = H()
    local gid = Ed.Selected("group")
    local g = gid and NS.Library.Group(gid)
    if not g then
        h.TextRow(ctx, NONE)
        return
    end
    -- The active-now line and the table's texts are refreshed in place (Ed.Live) on a write or a
    -- situation change.
    local W = Settings.GroupsWhen
    local active = h.TextRow(ctx, W.ActiveText(gid))
    Ed.Live(ctx, function() if active then active:SetText(W.ActiveText(gid)) end end)
    local blocks, any = G.PreviewBlocks(gid), false
    for _, b in ipairs(blocks) do any = any or #b.rows > 0 end
    if not any then
        h.TextRow(ctx, L["This group has no callouts yet."])
        return
    end
    Ed.TableRows(ctx, PAGE, blocks, PREVIEW_HEADER)
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

-- Whether the page is on screen (the settings window open on it).
local function onScreen()
    local ctx = Ed.pages[PAGE]
    local panel = ctx and ctx.panel
    if not (panel and panel.IsVisible) then return false end
    return panel:IsVisible() == true
end

--- Preview while editing (2026-10-19 groups polish, C4): while the page is on screen and the
--- setting is on, every pad and dial shows only the selected group (Preview.SetEditPreview); else
--- that ends. Run on every draw, on the page's show and hide, and on the setting's write; the
--- preview refuses a start in combat on its own.
function G.SyncEditPreview()
    local gid = Ed.Selected("group")
    local want = onScreen() and NS.Setting("behavior.previewOnEdit") ~= false and gid ~= nil
        and NS.Library.Group(gid) ~= nil and gid or nil
    return NS.Preview.SetEditPreview(want)
end

-- THE BAND (options-ui-§14) through O.PageHeader, which a page with a picker and another page-wide
-- control draws instead of O.PageBanner: the picker in the left half with New group level with its
-- control in the right half, as PageBanner places them, and Preview while editing under the
-- picker. The widgets are the page's to release: the last render's go back to AceGUI once this
-- render's are drawn, so none is released under the callback that asked for the redraw.
G.BAND_H, G.BAND_GAP, G.BAND_ACTION_Y, G.BAND_ACTION_H = 72, 4, 14, 24
G.BAND_TOGGLE_Y, G.BAND_TOGGLE_H = 46, 24

local function place(widget, frame, left, leftRel, leftX, right, rightRel, rightX, y, height)
    local f = widget.frame
    if not f then return end
    f:SetParent(frame)
    f:ClearAllPoints()
    f:SetPoint(left, frame, leftRel, leftX, -y)
    f:SetPoint(right, frame, rightRel, rightX, -y)
    if height then f:SetHeight(height) end
    f:Show()
end

local function refused(kind, subject)
    local check = H().__combatRefused
    return check ~= nil and check(kind, subject) == true
end

local function bandPicker(AceGUI, frame, list, order, selected)
    local dd = AceGUI:Create("Dropdown")
    local label = L["Group"]
    dd:SetLabel(label)
    dd:SetList(list, order)
    dd:SetValue(selected)
    dd:SetCallback("OnValueChanged", function(_, _, v)
        -- A change of subject is a structural redraw: refused in combat, as PageBanner's is.
        if refused("banner select", v) then
            dd:SetValue(selected)
            return
        end
        Ed.Select("group", v)
        Ed.RequestRefresh()
    end)
    place(dd, frame, "TOPLEFT", "TOPLEFT", 0, "TOPRIGHT", "TOP", -G.BAND_GAP, 0)
    H().AttachTooltip(dd, label, L["Which group this page edits. A green dot marks a group active now (or in the preview)."])
    return dd
end

local function bandAction(AceGUI, frame)
    local btn = AceGUI:Create("Button")
    local text = L["New group"]
    btn:SetText(text)
    btn:SetCallback("OnClick", function()
        if refused("banner action", text) then return end
        G.Create()
    end)
    place(btn, frame, "TOPLEFT", "TOP", G.BAND_GAP, "TOPRIGHT", "TOPRIGHT", 0, G.BAND_ACTION_Y, G.BAND_ACTION_H)
    H().AttachTooltip(btn, text, L["Make a new group, put it at the top of every pad, and edit it here."])
    return btn
end

local function bandToggle(AceGUI, frame)
    local row = Ed.Row("behavior.previewOnEdit")
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(row.label)
    cb:SetValue(NS.Setting("behavior.previewOnEdit") ~= false)
    cb:SetCallback("OnValueChanged", function(_, _, v)
        local ok, err, why = NS.SchemaRuntime.Set("behavior.previewOnEdit", v and true or false)
        if not ok then NS.Print(tostring(why or err)) end
    end)
    place(cb, frame, "TOPLEFT", "TOPLEFT", 0, "TOPRIGHT", "TOP", -G.BAND_GAP, G.BAND_TOGGLE_Y, G.BAND_TOGGLE_H)
    H().AttachTooltip(cb, row.label, row.desc)
    return cb
end

local function drawBand(ctx, list, order, selected)
    local old = ctx.qcBand
    ctx.qcBand = nil
    H().PageHeader(ctx, { height = G.BAND_H, build = function(_, frame)
        local AceGUI = H().AceGUI
        ctx.qcBand = { picker = bandPicker(AceGUI, frame, list, order, selected), action = bandAction(AceGUI, frame),
            toggle = Ed.Row("behavior.previewOnEdit") and bandToggle(AceGUI, frame) or nil }
    end })
    local AceGUI = H().AceGUI
    if not AceGUI then return end
    for _, w in pairs(old or {}) do AceGUI:Release(w) end
end

local function render(ctx)
    local entries = G.Entries()
    local selected = Ed.Heal("group", ids(entries))
    Ed.Select("group", selected)   -- keeps the selection in step after a heal
    local list, order = Ed.PickerList(entries)
    drawBand(ctx, list, order, selected)
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = "callouts", label = L["Callouts"], tooltip = L["The callouts this group shows, in order."],
          before = WHEN, render = renderCallouts },
        { key = WHEN, render = function(c) Settings.GroupsWhen.Render(c, Ed.Selected("group")) end },
        { key = "preview", label = L["Preview"], tooltip = L["What each callout sends here, or in the preview."],
          render = renderPreview },
    })
    G.SyncEditPreview()
end

--- The page's Defaults (options-ui-§13: page-wide, what the page draws): every row of the page, for
--- the selected group.
function G.RestoreDefaults(ctx)
    -- One act (Library.Batch): the pads rebuild once, not once per row.
    return NS.Library.Batch(function() H().RestoreDefaults(PAGE, ctx) end)
end

Ed.RegisterPage(PAGE, L["Groups"], "GroupsPanel", render, {
    tooltip = L["Turn the selected group back on, stop it opening the dial, turn Inherit when conditions back on, and turn Preview while editing back on. Its name, callouts and own When are kept."],
    onClick = function(ctx) G.RestoreDefaults(ctx) end,
}, {
    onShow = function() G.SyncEditPreview() end,
    onHide = function() NS.Preview.SetEditPreview(nil) end,
})
