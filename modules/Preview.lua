local _, NS = ...
-- modules/Preview.lua — test mode (spec §10.4, preview-mode, options-ui-§15) and the one sender of
-- TEST_MODE_CHANGED (spec §17). It holds both flavors of test mode: placeholders, and "Preview as…"
-- (spec §13.3), which builds the pads from a synthetic snapshot. They are one switch at a time.
-- Session-only (NS.State.testMode, never saved): refused while stood down or in combat
-- with one line, ended when combat starts (while secure writes are still allowed, so the pads swap
-- back to live chips at once), and ended by the stand-down. The checkbox, the `test` verb and the
-- launcher entry all call SetTestMode. Copied from DropWatcher core/DropWatcher.lua `NS.SetTestMode`,
-- `testModeRefusal` and `DW.OnCombatStart`; the combat edge arrives as RESTRICTION_CHANGED here,
-- because modules/Restrictions.lua owns PLAYER_REGEN_DISABLED.

NS.Preview = NS.Preview or {}
local P = NS.Preview
local State = NS.State
local L = NS.L

local function fighting()
    return NS.Restrictions.InCombat() or NS.Compat.InCombat()
end

-- The Test mode checkbox follows every start and stop (options-ui-§15).
local function refreshPanel()
    local S = NS.addon.Settings
    local H = S and S.Helpers
    if H and H.RefreshAll then H.RefreshAll() end
end

-- Both flavors announce through TEST_MODE_CHANGED: `on` is true while either is on.
local function announce()
    NS.addon:SendMessage(NS.MSG.TEST_MODE_CHANGED, State.testMode == true or State.previewAs ~= nil)
    refreshPanel()
end

function P.IsTestMode()
    return State.testMode == true
end

--- Turn test mode on or off. A start is refused, with one line, while stood down or in combat.
--- @return boolean changed
function P.SetTestMode(on)
    on = on and true or false
    if on == P.IsTestMode() then return false end
    if on then
        if NS.IsStoodDown() then
            NS.Print(NS.SlashCommands:DisabledLine())
            return false
        end
        if fighting() then
            NS.Print(L["Test mode is not available in combat."])
            return false
        end
    end
    State.testMode = on
    if on then State.previewAs = nil end
    NS.Debug("Pad", "test mode %s", on and "on" or "off")
    announce()
    return true
end

function P.ToggleTestMode()
    return P.SetTestMode(not P.IsTestMode())
end

-- ── Preview as… (spec §13.3) ────────────────────────────────────────────────────────────────
--
-- Test mode's second flavor: the pads are built from a synthetic snapshot instead of placeholders,
-- so they show the groups that situation resolves to (modules/Surfaces.lua marks the plan, and every
-- previewed chip is disarmed). Only where you are changes: the class, specialization, role and
-- character are the live ones. Session-only (NS.State.previewAs).

P.CURRENT = "current"
local DOT = " \194\183 "

local RAID = { { "lfr", 17, L["LFR"] }, { "normal", 14, L["Normal"] }, { "heroic", 15, L["Heroic"] },
    { "mythic", 16, L["Mythic"] } }

local function base(fields)
    local live = NS.Situation.Current()
    local s = { classFile = live.classFile, specID = live.specID, role = live.role, character = live.character,
        leader = true, assist = false, inCombat = false, lockdown = {} }
    for k, v in pairs(fields) do s[k] = v end
    return s
end

-- A dungeon entry carries its display name (`previewDungeon`): a preview has no challengeMapID, so
-- {dungeon} bakes from it (Surfaces.BakeContext). Shown, never matched.
local function mplus(instanceID, name)
    return base({ content = "mythicPlus", instanceID = instanceID, difficultyID = 8, difficulty = "keystone",
        keyLevel = 10, group = "party", instanceGroup = false, lockdown = { challengeMode = true },
        previewDungeon = name })
end

-- One entry per battleground set: its key ("bi.bg.ab" -> "bg:ab"), its name, its lowest instanceID.
local function battlegrounds()
    local out = {}
    for _, gid in ipairs(NS.BuiltIns.order) do
        local def = NS.BuiltIns.groups[gid]
        local ids = def.when and def.when.battleground
        local short = gid:match("^bi%.bg%.(.+)$")
        if short and type(ids) == "table" then
            local first
            for id in pairs(ids) do
                if not first or id < first then first = id end
            end
            out[#out + 1] = { key = "bg:" .. short, label = def.name, instanceID = first }
        end
    end
    return out
end

--- The "Preview as…" menu, in order (spec §13.3): { key, label, snapshot }; Current has none.
function P.Presets()
    local out = { { key = P.CURRENT, label = L["Current"] } }
    local spec = NS.Compat.SpecName()
    out[#out + 1] = { key = "mplus", label = spec and (L["M+"] .. DOT .. spec) or L["M+"], snapshot = mplus(nil) }
    -- One entry per shipped dungeon (defaults/GameIds.lua), labeled as spec §13.3 lists it.
    for _, id in ipairs(NS.GameIds.DUNGEONS) do
        local known = NS.Compat.InstanceName(id)
        local name = known or L["Instance %d"]:format(id)
        local label = L["M+"] .. DOT .. name
        if spec then label = label .. DOT .. spec end
        out[#out + 1] = { key = "mplus:" .. id, label = label, snapshot = mplus(id, known) }
    end
    for _, r in ipairs(RAID) do
        out[#out + 1] = { key = "raid:" .. r[1], label = L["Raid"] .. DOT .. r[3], snapshot = base({ content = "raid",
            difficultyID = r[2], difficulty = r[1], group = "raid", instanceGroup = r[1] == "lfr" }) }
    end
    out[#out + 1] = { key = "arena", label = L["Arena"], snapshot = base({ content = "arena", group = "party",
        instanceGroup = false, lockdown = { pvpMatch = true } }) }
    for _, bg in ipairs(battlegrounds()) do
        out[#out + 1] = { key = bg.key, label = bg.label, snapshot = base({ content = "battleground",
            instanceID = bg.instanceID, group = "raid", instanceGroup = true, lockdown = { pvpMatch = true } }) }
    end
    out[#out + 1] = { key = "world", label = L["World"] .. DOT .. L["Solo"], snapshot = base({ content = "openWorld",
        group = "solo", leader = false }) }
    return out
end

function P.FindPreset(key)
    for _, e in ipairs(P.Presets()) do
        if e.key == key then return e end
    end
    return nil
end

function P.Label(key)
    local e = P.FindPreset(key)
    return e and e.label or tostring(key)
end

--- The menu as a row's `values` list.
function P.Choices()
    local out = {}
    for i, e in ipairs(P.Presets()) do out[i] = { value = e.key, text = e.label } end
    return out
end

function P.PreviewAs()
    return State.previewAs
end

--- The previewed snapshot, or nil when "Preview as…" is off.
function P.PreviewSnapshot()
    local key = State.previewAs
    if not key then return nil end
    local e = P.FindPreset(key)
    return e and e.snapshot or nil
end

--- Preview the pads as `key`, or turn the preview off (nil, "", "off" or "current"). A start is
--- refused, with one line, while stood down or in combat.
--- @return boolean changed
function P.SetPreviewAs(key)
    if key == nil or key == "" or key == "off" then key = P.CURRENT end
    if not P.FindPreset(key) then return false end
    local want = key ~= P.CURRENT and key or nil
    if want == State.previewAs then return false end
    if want then
        if NS.IsStoodDown() then
            NS.Print(NS.SlashCommands:DisabledLine())
            return false
        end
        if fighting() then
            NS.Print(L["Preview is not available in combat."])
            return false
        end
        State.testMode = nil
    end
    State.previewAs = want
    NS.Debug("Pad", "preview %s", want or "off")
    announce()
    return true
end

local watched = setmetatable({}, { __mode = "k" })

--- End the preview when the settings window closes (spec §13.3). settings/Panel.lua hands it the
--- client's SettingsPanel once; the hook is insecure and runs only when that window hides.
function P.WatchPanel(frame)
    if type(frame) ~= "table" or type(frame.HookScript) ~= "function" or watched[frame] then return false end
    watched[frame] = true
    frame:HookScript("OnHide", function()
        if State.previewAs then P.SetPreviewAs(nil) end
    end)
    return true
end

local function onRestrictionChanged()
    if not NS.Restrictions.InCombat() then return end
    if P.IsTestMode() then
        P.SetTestMode(false)
        NS.Print(L["Test mode ended: you entered combat."])
    end
    if State.previewAs then
        P.SetPreviewAs(nil)
        NS.Print(L["Preview ended: you entered combat."])
    end
end

-- Its own target (core/Bus.lua); the degraded bus is handled here, as in modules/Situation.lua.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.testMode, State.previewAs = nil, nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
