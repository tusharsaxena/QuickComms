local _, NS = ...
-- settings/AutoThank.lua — auto-thank's settings (#19, spec §9 Settings page, §10): the thank.* rows.
--
-- One row per setting under the profile's `thank` block, each default read from NS.C.PROFILE.thank
-- (savedvariables-§2), never a literal here. The rows draw on the Auto-thank page (pageKey
-- "autothank"): General (on or off, what the Thank button sends, the text, who is muted), Where (one
-- check box per content kind) and Filter (raid buffs only). The toast's dragged
-- spot is a row so a named `/qc reset thank.position` reaches it; it is drawn by nothing and a
-- page's Defaults keeps it (settings/Schema.lua resetExempt).
--
-- Every row's onChange re-runs NS.AutoThank.Rewire: there is no setting-change message on the bus,
-- so this is the one wire from a write to the unit-filter frame (modules/AutoThank.lua). It is
-- resolved when a write runs, never captured at load.

local L = NS.L
local D = NS.C.PROFILE.thank

local PAGE    = "autothank"
local GENERAL = L["General"]
local WHERE   = L["Where"]
local FILTER  = L["Filter"]

local function rewire()
    if NS.AutoThank and NS.AutoThank.Rewire then NS.AutoThank.Rewire() end
end

local function oneOf(list)
    local set = {}
    for _, e in ipairs(list) do set[e.value] = true end
    return function(v) return set[v] == true end
end

local SEND = { { value = "emote", text = L["Emote"] }, { value = "line", text = L["Whisper"] },
    { value = "both", text = L["Both"] } }
local MUTE = { { value = "none", text = L["No one"] }, { value = "strangers", text = L["Strangers"] },
    { value = "known", text = L["Friends and guild"] } }

local function isString(v) return type(v) == "string" end
local function isPoint(v) return NS.Library.ValidPoint(v) end

local ROWS = {
    { path = "thank.enabled", type = "bool", default = D.enabled, label = L["Enable auto-thank"],
      desc = L["When another player buffs you, show a toast with a Thank button."] },
    { path = "thank.send", type = "string", default = D.send, values = SEND, validate = oneOf(SEND),
      label = L["Thank button sends"],
      desc = L["What the Thank button does: the game's /thank emote at the caster, a whisper of your text, or both."] },
    { path = "thank.text", type = "string", default = D.text, dialogControl = "EditBox",
      maxLetters = NS.Bake.MAX_BYTES, validate = isString, label = L["Whisper text"],
      desc = L["The whisper the Thank button sends. {name} is the caster, {buff} the buff."] },
    { path = "thank.mute", type = "string", default = D.mute, values = MUTE, validate = oneOf(MUTE),
      label = L["Mute"],
      desc = L["Whose buffs show no toast: no one's, strangers', or your friends' and guildmates'."] },
    { path = "thank.position", type = "point", default = D.position, skipRender = true, validate = isPoint,
      label = L["Toast position"],
      desc = L["Where the thank toast sits. Drag the toast to move it."] },
}

-- Where: one check box per content kind, in NS.Resolver.TOKENS.content's order, labeled as the pad's
-- situation chip. Every kind has a row on every client, so the stored set and `/qc set` are one shape;
-- the page draws only the kinds Settings.GroupsWhen.ContentValues offers on this client (the When
-- editor's own list), read when the page draws (`skipRender` below), never at load.
for _, kind in ipairs(NS.Resolver.TOKENS.content) do
    ROWS[#ROWS + 1] = { path = "thank.content." .. kind, type = "bool", default = D.content[kind],
        group = WHERE, label = NS.PadRender.CONTENT[kind] or kind,
        desc = L["Show thank toasts here."], qcKind = kind }
end

ROWS[#ROWS + 1] = { path = "thank.raidBuffsOnly", type = "bool", default = D.raidBuffsOnly, group = FILTER,
    label = L["Raid buffs only"],
    desc = L["Auto-thank guesses at a buff: one of a minute or more that another player cast on you. With this on, only the raid buffs a stranger can give you show a toast."] }

-- What a row's `skipRender` answers when the page draws: a content kind this client does not offer, and
-- the raid-buffs-only toggle on a client whose NS.GameIds.THANK_RAID_BUFFS is empty (FRB: it would
-- toast nothing there; WoW Forever's ids are derived, so today both clients draw it).
local function offered(kind)
    for _, v in ipairs(NS.addon.Settings.GroupsWhen.ContentValues()) do
        if v.value == kind then return true end
    end
    return false
end
local function hiddenNow(row)
    if row.qcKind then return not offered(row.qcKind) end
    if row.path == "thank.raidBuffsOnly" then return next(NS.GameIds.THANK_RAID_BUFFS or {}) == nil end
    return nil
end

-- On a load where the Options composers are hollow (LibKa0s absent) no page draws these rows, so,
-- as settings/SchemaRows.lua, none is added; modules/AutoThank.lua reads the profile's `thank` itself.
if not NS.addon.Settings.Helpers.MASTER_GROUP then return end

for _, row in ipairs(ROWS) do
    row.page = PAGE
    row.group = row.group or GENERAL
    row.onChange = rewire
    if row.qcKind or row.path == "thank.raidBuffsOnly" then
        setmetatable(row, { __index = function(r, key)
            if key == "skipRender" then return hiddenNow(r) end
            return nil
        end })
    end
end
NS.SchemaRuntime.AddRows(ROWS)

-- ── the page (D21: its own sidebar page, after Comms Dial and before Profiles) ──────────────────
-- Through the editor pages' registration (settings/Editors.lua Ed.RegisterPage, the canvas and the
-- Defaults button of Panel.lua's buildGeneralPage), whose RegisterOptionsPage the degraded load
-- stubs (settings/OptionsSetup.lua). The tabs are the rows' groups; a tab whose every row is hidden
-- draws no tab (untabbedSkipRender). Defaults resets every row the page draws but the toast's
-- position (settings/Schema.lua resetExempt).
local Ed = NS.addon.Settings.Editors
local function H() return NS.addon.Settings.Helpers end

local function render(ctx)
    H().RenderTabbedSchema(ctx, PAGE, nil, nil, { rerender = Ed.redraw[PAGE], untabbedSkipRender = true })
end

Ed.RegisterPage(PAGE, L["Auto-thank"], "AutoThankPanel", render, {
    tooltip = L["Put auto-thank's settings back to their defaults. The toast's position is kept."],
    onClick = function(ctx) H().RestoreDefaults(PAGE, ctx) end,
})
