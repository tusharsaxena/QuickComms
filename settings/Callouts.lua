local _, NS = ...
-- settings/Callouts.lua — the Callouts page (design spec §13.1): one callout at a time.
--
--     band     [ Callout v (picker)        ][ New callout ]
--     strip    [ General ][ Used by ]
--     General  Name, Text, Channel, Icon (the member rows, settings/SchemaMembers.lua), Insert a
--              token, Choose an icon (settings/Editors.lua's picker), then what it sends here (the
--              baked line and its bytes, or why it sends nothing, and any lock), then Duplicate and
--              Delete
--     Used by  every group that holds it, each a link to the Groups page
--
-- The band holds the picker and the create action and nothing else (options-ui-§14); the acts on
-- the selected callout are the General tab's, which is first. Every field writes through the seam to
-- the selected callout, by its id (Ed.Bound: the seam reads no callout selection, settings/Schema.lua),
-- and so does the page's Defaults. A name change repaints the page (the picker's
-- label, settings/Editors.lua); any other field refreshes in place, the baked line and the token list
-- with it (Ed.Live), so the byte count follows each committed write (Enter), not each keystroke.
-- Built-in callouts are not listed: a group copies one when it takes it (spec P2), and the copy is
-- then edited here.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "callouts"
local GENERAL = L["General"]

Settings.Callouts = Settings.Callouts or {}
local C = Settings.Callouts

-- The picker's tokens (spec §8.1). The eight raid markers are offered by name ({star} to {skull});
-- a typed {rt1} to {rt8} works the same. {spell:ID} needs an id, so it is typed, never picked.
C.TOKENS = { "{target}", "{focus}", "{skull}", "{cross}", "{square}", "{moon}", "{triangle}", "{diamond}",
    "{circle}", "{star}", "{me}", "{spec}", "{role}", "{key}", "{dungeon}" }

-- The channels that can resolve to Raid (spec §8.2), where {group1} to {group8} expand.
local RAID_CAPABLE = { raid = true, raidWarning = true, smartGroup = true, smartLead = true }

--- The tokens the picker offers for a channel: C.TOKENS, plus {group1} to {group8} only when the
--- channel can resolve to Raid (spec §8.1).
function C.TokensFor(channel)
    local out = {}
    for i, token in ipairs(C.TOKENS) do out[i] = token end
    if RAID_CAPABLE[channel] then
        for n = 1, 8 do out[#out + 1] = "{group" .. n .. "}" end
    end
    return out
end

local function H() return Settings.Helpers end

--- The user callouts as picker entries, in the page's order (Library.MemberIds: by name, then id).
function C.Entries()
    local callouts = NS.db.profile.callouts
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("callout")) do
        out[#out + 1] = { id = id, label = callouts[id].name or id }
    end
    return out
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

function C.Create()
    local id = NS.Library.CreateCallout({ name = L["New callout"], text = "", channel = "smartGroup" })
    if id then
        Ed.Select("callout", id)
        Ed.RequestRefresh()
    end
    return id
end

function C.Duplicate(id)
    local copy = NS.Library.DuplicateCallout(id)
    if copy then
        Ed.Select("callout", copy)
        Ed.RequestRefresh()
    end
    return copy
end

function C.Delete(id)
    local c = NS.db.profile.callouts[id]
    if not c then return end
    Ed.ConfirmDelete(c.name, function() NS.Library.DeleteCallout(id) end)
end

--- Add a token to the end of the callout's text, through the seam.
function C.InsertToken(id, token)
    local c = NS.db.profile.callouts[id]
    if not c then return false end
    local text = c.text or ""
    local sep = (text == "" or text:sub(-1) == " ") and "" or " "
    return (NS.SchemaRuntime.Set("callout.text", text .. sep .. token, id)) == true
end

--- What a callout sends here (spec §13.1: the live preview of the baked line, under the current or
--- previewed situation, with the padlock when locked): the line and its bytes, or why it sends
--- nothing; then any lock, the unknown tokens and the tokens empty here.
--- @return string[]
function C.PreviewLines(callout)
    local snap = Ed.Snapshot()
    local line, reason, info = NS.Bake.Bake(callout, snap,
        { soloFallback = NS.Setting("behavior.soloFallback"), ctx = NS.Surfaces.BakeContext(snap) })
    local R = NS.PadRender
    local out = {}
    if line then
        out[1] = L["Sends: %s"]:format(line)
        out[2] = L["%d of 255 bytes"]:format(info.length)
    elseif reason == "solo" and info.selfPrint then
        out[1] = L["Solo: prints to you, sends nothing."]
    else
        out[1] = L["Sends nothing here: %s"]:format(R.REASON_TEXT[reason] or tostring(reason))
        if info.length then out[2] = L["%d of 255 bytes"]:format(info.length) end
    end
    if info.lock then out[#out + 1] = R.LOCK_TEXT[info.lock] or tostring(info.lock) end
    if info.unknown and #info.unknown > 0 then
        out[#out + 1] = L["Unknown tokens, sent as typed: %s"]:format(table.concat(info.unknown, ", "))
    end
    if info.missing and #info.missing > 0 then
        out[#out + 1] = L["Empty here: %s"]:format(table.concat(info.missing, ", "))
    end
    local key = NS.Preview.PreviewAs()
    if key then out[#out + 1] = L["Previewing: %s"]:format(NS.Preview.Label(key)) end
    return out
end

--- Select a group and open the Groups page on it (a Used by link).
function C.OpenGroup(groupId)
    Ed.Select("group", groupId)
    return Ed.Open("groups")
end

local NONE = L["No callouts yet. Click New callout to make one."]

-- The token picker's entries for the callout's channel as it is now.
local function tokenEntries(id)
    return function()
        local c = NS.db.profile.callouts[id]
        local out = {}
        for i, token in ipairs(C.TokensFor(c and c.channel)) do out[i] = { id = token, label = token } end
        return out
    end
end

local function renderGeneral(ctx, rows)
    local h = H()
    local id = Ed.Selected("callout")
    local callout = id and NS.db.profile.callouts[id]
    if not callout then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Bound(Ed.Scalar(rows), id), nil, nil, { noHeadings = true })
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Insert a token"],
        L["Add a token to the end of the text. Tokens are filled in when the callout is sent."],
        tokenEntries(id), function(token) C.InsertToken(id, token) end, ctx) })
    Ed.IconPicker(ctx, "callout.icon", id)
    h.Section(ctx, L["What it sends here"])
    -- One label, refreshed in place (Ed.Live) on every write to this callout and every situation change.
    local live = h.TextRow(ctx, table.concat(C.PreviewLines(callout), "\n"))
    Ed.Live(ctx, function()
        local c = NS.db.profile.callouts[id]
        if c and live then live:SetText(table.concat(C.PreviewLines(c), "\n")) end
    end)
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this callout and edit the copy."],
          onClick = function() C.Duplicate(id) end },
        { text = L["Delete"], tooltip = L["Delete this callout and take it out of every group. Asks first."],
          onClick = function() C.Delete(id) end })
end

local function renderUsedBy(ctx)
    local h = H()
    local id = Ed.Selected("callout")
    if not (id and NS.db.profile.callouts[id]) then
        h.TextRow(ctx, NONE)
        return
    end
    local used = NS.Library.UsedBy(id)
    if #used == 0 then
        h.TextRow(ctx, L["No group holds this callout yet. Add it on a group's Callouts tab."])
        return
    end
    h.TextRow(ctx, L["The groups that hold this callout. Click one to open it on the Groups page."])
    local items = {}
    for _, gid in ipairs(used) do
        items[#items + 1] = { wide = true, make = function(_, parent)
            local link = h.AceGUI:Create("InteractiveLabel")
            link:SetText(NS.db.profile.groups[gid].name)
            link:SetFullWidth(true)
            link:SetCallback("OnClick", function() C.OpenGroup(gid) end)
            parent:AddChild(link)
            return link
        end }
    end
    h.RenderGrid(ctx, items)
end

local function render(ctx)
    local h = H()
    local entries = C.Entries()
    local selected = Ed.Heal("callout", ids(entries))
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Callout"], list = list, order = order, value = selected,
        tooltip = L["Which callout this page edits."],
        onSelect = function(v)
            Ed.Select("callout", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New callout"], tooltip = L["Make a new callout and edit it here."], onClick = C.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = "usedBy", label = L["Used by"], tooltip = L["The groups that hold this callout."], render = renderUsedBy },
    })
end

-- The page's Defaults, on the callout it shows. The library's page walk names no member, and the seam
-- addresses a callout by id alone, so the rows are reset by id inside the seam's bulk bracket, which
-- keeps the icon (resetExempt holds while a bracket is open). The button is refused in combat before
-- this runs (LibKa0s Options).
local function restoreDefaults(ctx)
    local id = Ed.Selected("callout")
    if not (id and NS.db.profile.callouts[id]) then return end
    local S = NS.SchemaRuntime
    S.BulkBegin("reset", PAGE)
    local ok, err = pcall(function()
        for _, row in ipairs(Settings.RowsForPage(PAGE)) do S.ApplyDefault(row, id) end
    end)
    S.BulkEnd("reset", PAGE, 0, not ok and err or nil, { profileReset = false })
    if not ok then error(err, 0) end
    for _, fn in ipairs(ctx and ctx.refreshers or {}) do pcall(fn) end
end

Ed.RegisterPage(PAGE, L["Callouts"], "CalloutsPanel", render, {
    tooltip = L["Put the selected callout's channel back to Smart group. Its name, text and icon are kept."],
    -- One act (Library.Batch): the pads rebuild once, not once per row.
    onClick = function(ctx) NS.Library.Batch(function() restoreDefaults(ctx) end) end,
})
