local _, NS = ...
-- settings/Share.lua — the Share page (design spec §13.1, §12.2). Phase 3 ships its Built-in tab;
-- Export and Import join it, ahead of it, in phase 5.
--
--     strip     [ Built-in ]
--     Built-in  one line per shipped set: an Enabled checkbox named after the set, then Customize (or
--               Edit the copy) and Choose callouts
--
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

Settings.Share = Settings.Share or {}
local SH = Settings.Share

local function H() return Settings.Helpers end

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
    Ed.Tabs(ctx, PAGE, { { key = BUILTIN, render = renderBuiltIn } })
end

Ed.RegisterPage(PAGE, L["Share"], "SharePanel", render, {
    tooltip = L["Turn every built-in set back on and show all of their callouts. Your customized copies are kept."],
    onClick = function() SH.RestoreAll() end,
})
