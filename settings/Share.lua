local _, NS = ...
-- settings/Share.lua — the Share page (design spec §13.1, §15, §12.2): three tabs.
--
--     strip     [ Export ][ Import ][ Built-in ]
--     Export    what travels; a checkbox per group, Comms Pad and Comms Dial, under a heading per kind
--               (a callout travels inside its group, so it has none); what the string will hold;
--               Export (the string opens, selected, in the copy window) and Clear
--     Import    a paste box (its Accept checks the string); the report (spec §15 step 5); Import and
--               Clear
--     Built-in  one line per shipped set: an Enabled checkbox named after the set, then Customize (or
--               Edit the copy) and Choose callouts
--
-- The ticks and the checked string are session state (NS.State.share), never saved; a profile switch
-- clears them (settings/Editors.lua). The codec, the checks, the export and the apply are
-- modules/Share.lua's, and Library.Import is the one writer of what arrives; both acts are refused in
-- combat. A tick and a check refresh their own lines in place; an import repaints every page.
-- Enabled is the set's `builtin.enabled` member row, written through the seam with the set's id.
-- Customize is Library's (the copy takes the set's place on every pad and dial, and the set is turned
-- off) and opens the Groups page on the copy. Choose callouts opens the set on the Groups page's
-- Callouts tab, the one hidden-callouts editor. The page edits no single instance, so its band has no
-- picker. Defaults turns every set back on and shows all of their callouts.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "share"
local BUILTIN = L["Built-in"]
local EXPORT, IMPORT = L["Export"], L["Import"]

Settings.Share = Settings.Share or {}
local SH = Settings.Share

local function H() return Settings.Helpers end

-- ── Export ──────────────────────────────────────────────────────────────────────────────────

local KINDS = {
    { kind = "group", title = L["Groups"], set = "groups" },
    { kind = "pad", title = L["Comms Pads"], set = "pads" },
    { kind = "dial", title = L["Comms Dials"], set = "dials" },
}

--- Tick or untick one member for export.
function SH.Pick(kind, id, on)
    local pick = NS.State.share.pick
    pick[kind] = pick[kind] or {}
    pick[kind][id] = on and true or nil
end

function SH.Picked(kind, id)
    local ids = NS.State.share.pick[kind]
    return ids ~= nil and ids[id] == true
end

function SH.ClearPicks()
    NS.State.share.pick = { group = {}, pad = {}, dial = {} }
    Ed.RequestRefresh()
end

--- What the export string will hold: the ticks and what they bring with them.
function SH.ExportSummary()
    local payload = NS.Share.Collect(NS.State.share.pick)
    if not payload then return L["Nothing is ticked yet."] end
    return L["The string will hold %s."]:format(NS.Share.CountText(payload))
end

--- Export the ticked members (modules/Share.lua): the string opens in the copy window. A refusal
--- prints its reason.
--- @return string|nil
function SH.Export()
    local text, why = NS.Share.Export(NS.State.share.pick)
    if not text then NS.Print(NS.Share.REASON_TEXT[why] or tostring(why)) end
    return text
end

local function pickBox(kind, id, name, summary)
    return { make = function(_, parent, rel)
        local cb = H().AceGUI:Create("CheckBox")
        cb:SetLabel(name)
        cb:SetValue(SH.Picked(kind, id))
        cb:SetRelativeWidth(rel or 0.5)
        cb:SetCallback("OnValueChanged", function(_, _, v)
            SH.Pick(kind, id, v)
            if summary.label then summary.label:SetText(SH.ExportSummary()) end
        end)
        parent:AddChild(cb)
        return cb
    end }
end

local function renderExport(ctx)
    local h = H()
    h.TextRow(ctx, L["Tick what to share. A group brings its callouts with it, and a pad or a dial brings its groups. A pad or a dial travels without its key and its position."])
    local p, summary = NS.db.profile, {}
    for _, k in ipairs(KINDS) do
        local items = {}
        for _, id in ipairs(NS.Library.MemberIds(k.kind)) do
            local m = p[k.set][id]
            if m then items[#items + 1] = pickBox(k.kind, id, m.name or id, summary) end
        end
        if #items > 0 then
            h.Section(ctx, k.title)
            h.RenderGrid(ctx, items)
        end
    end
    summary.label = h.TextRow(ctx, SH.ExportSummary())
    h.InlineButtonPair(ctx,
        { text = L["Export"], tooltip = L["Make the string and open it, selected, in a window: press Ctrl+C to copy it."],
          onClick = function() SH.Export() end },
        { text = L["Clear"], tooltip = L["Untick everything."], onClick = SH.ClearPicks })
end

-- ── Import ──────────────────────────────────────────────────────────────────────────────────

--- Check a pasted string (modules/Share.lua Check) and keep the result for the report and Import.
--- @return table the result
function SH.Check(text)
    NS.State.share.import = NS.Share.Check(text)
    return NS.State.share.import
end

--- The report's text: the checked string's ReportLines, or how to start.
function SH.ReportText()
    local res = NS.State.share.import
    if not res then return L["Paste a string in the box, then click Accept to check it. Nothing changes until you click Import."] end
    return table.concat(NS.Share.ReportLines(res), "\n")
end

-- How many of a checked string's groups no shared pad or dial lists: they arrive on no surface
-- (Library.Import adds a group to no pad, unlike the Groups page's New group).
local function looseGroups(res)
    local listed = {}
    for _, key in ipairs({ "pads", "dials" }) do
        for _, s in ipairs(res[key]) do
            for _, gid in ipairs(s.groups) do listed[gid] = true end
        end
    end
    local n = 0
    for _, g in ipairs(res.groups) do
        if not listed[g.id] then n = n + 1 end
    end
    return n
end

--- Import the checked string and say what arrived (one chat line; one more when a dial did, since it
--- has no key yet; and one more when a group arrived that no shared pad or dial lists, since it shows
--- nowhere until it is added). A refusal prints its reason and keeps the string.
--- @return table|nil Library.Import's tally
function SH.Import()
    local res = NS.State.share.import
    local tally, why = NS.Share.Apply(res)
    if not tally then
        NS.Print(NS.Share.REASON_TEXT[why] or tostring(why))
        return nil
    end
    NS.State.share.import = nil
    local counts = NS.Share.CountText(tally)
    NS.Print(counts ~= "" and L["Imported %s."]:format(counts) or L["Nothing was imported."])
    if tally.dials > 0 then NS.Print(L["An imported dial has no key yet: give it one on the Comms Dial page."]) end
    if looseGroups(res) > 0 then
        NS.Print(L["An imported group is on no pad or dial yet: add it on the Groups tab of the Comms Pad or Comms Dial page."])
    end
    Ed.RequestRefresh()
    return tally
end

function SH.ClearImport()
    NS.State.share.import = nil
end

local function renderImport(ctx)
    local h = H()
    local report
    local function refresh()
        if report then report:SetText(SH.ReportText()) end
    end
    h.RenderGrid(ctx, { { wide = true, make = function(_, parent)
        local box = h.AceGUI:Create("MultiLineEditBox")
        box:SetLabel(L["Share string"])
        box:SetNumLines(8)
        box:SetFullWidth(true)
        box:SetCallback("OnEnterPressed", function(_, _, text)
            SH.Check(text)
            refresh()
        end)
        -- An edit forgets the last check, so Import never adds a string the box no longer holds
        -- (and the report never describes one); Accept checks the new text.
        box:SetCallback("OnTextChanged", function()
            if NS.State.share.import then
                SH.ClearImport()
                refresh()
            end
        end)
        parent:AddChild(box)
        return box
    end } })
    report = h.TextRow(ctx, SH.ReportText())
    h.InlineButtonPair(ctx,
        { text = L["Import"], tooltip = L["Add what the checked string holds to this profile. Everything arrives as new: nothing you have is changed."],
          onClick = function()
              SH.Import()
              refresh()
          end },
        { text = L["Clear"], tooltip = L["Forget the checked string."], onClick = function()
              SH.ClearImport()
              refresh()
          end })
end

-- ── Built-in ────────────────────────────────────────────────────────────────────────────────

function SH.Customize(id)
    local copy = Settings.Groups.Customize(id)
    if copy then Ed.Open(Settings.Groups.PAGE) end
    return copy
end

function SH.ChooseCallouts(id)
    Ed.Select("group", id)
    local groups = Ed.pages[Settings.Groups.PAGE]
    if groups then groups.activeTab = "callouts" end
    return Ed.Open(Settings.Groups.PAGE)
end

--- Every set back on, every callout shown (the page's Defaults; its blast radius is the whole list).
--- One act: one bulk bracket (debug-logging-§10: one `[Set] reset share: N rows` line) and one
--- coalesced LIBRARY_CHANGED (Lib.Batch), so the pads rebuild once and the pages repaint once. The
--- Defaults button is refused in combat by the options library, at the control.
function SH.RestoreAll()
    local S = NS.SchemaRuntime
    S.BulkRun("reset", PAGE, function()
        NS.Library.Batch(function()
            for _, id in ipairs(NS.BuiltIns.order) do
                S.Set("builtin.enabled", true, id)
                S.Set("builtin.hidden", {}, id)
            end
        end)
    end)
end

local function renderBuiltIn(ctx)
    local h = H()
    h.TextRow(ctx, L["The callout sets that ship with Quick Comms. Turn a set off, Customize it into a group you can edit, or choose which of its callouts show."])
    local items = {}
    for _, id in ipairs(NS.BuiltIns.order) do
        local def = NS.BuiltIns.groups[id]
        local group = NS.Library.Group(id)
        items[#items + 1] = { make = function(_, parent, rel)
            local cb = h.AceGUI:Create("CheckBox")
            cb:SetLabel(def.name)
            cb:SetValue(group and group.enabled ~= false)
            cb:SetRelativeWidth(rel or 0.5)
            cb:SetCallback("OnValueChanged", function(_, _, v) NS.Library.SetBuiltinEnabled(id, v and true or false) end)
            h.AttachTooltip(cb, def.name, L["Show this set wherever it matches. Off keeps it, and its place on every pad."])
            parent:AddChild(cb)
            return cb
        end }
        items[#items + 1] = { make = function(_, parent, rel)
            local AceGUI = h.AceGUI
            local row = AceGUI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetRelativeWidth(rel or 0.5)
            local copy = Settings.Groups.CustomizedAs(id)
            local customize = AceGUI:Create("Button")
            customize:SetText(copy and L["Edit the copy"] or L["Customize"])
            customize:SetRelativeWidth(0.48)
            customize:SetCallback("OnClick", function() SH.Customize(id) end)
            row:AddChild(customize)
            local choose = AceGUI:Create("Button")
            choose:SetText(L["Choose callouts"])
            choose:SetRelativeWidth(0.48)
            choose:SetCallback("OnClick", function() SH.ChooseCallouts(id) end)
            row:AddChild(choose)
            parent:AddChild(row)
            return row
        end }
    end
    h.RenderGrid(ctx, items)
end

local function render(ctx)
    Ed.Tabs(ctx, PAGE, {
        { key = EXPORT, label = EXPORT, tooltip = L["Make a string of your callouts, groups, pads or dials to share."],
          render = renderExport },
        { key = IMPORT, label = IMPORT, tooltip = L["Add what someone shared with you, from their string."],
          render = renderImport },
        { key = BUILTIN, render = renderBuiltIn },
    })
end

Ed.RegisterPage(PAGE, L["Share"], "SharePanel", render, {
    tooltip = L["Turn every built-in set back on and show all of their callouts. Your customized copies are kept."],
    onClick = function() SH.RestoreAll() end,
})
