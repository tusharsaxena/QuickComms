local _, NS = ...
-- modules/Preview.lua — test mode (spec §10.4, preview-mode, options-ui-§15) and the one sender of
-- TEST_MODE_CHANGED (spec §17). It holds both flavors of test mode: placeholders, and "Preview as…"
-- (spec §13.3), which builds the pads from a synthetic snapshot, or from the live one for Current (a
-- live preview of where you are). They are one switch at a time. A third, the edit preview (one
-- group, while the Groups page edits it), sits over either. Preview as ends on "off", a switch to
-- test mode, combat or the stand-down; closing the settings window ends only the edit preview.
-- Session-only (NS.State.testMode, never saved): refused while stood down or in combat
-- with one line, ended when combat starts (while secure writes are still allowed, so the pads swap
-- back to live buttons at once), and ended by the stand-down. The checkbox, the `test` verb and the
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

-- Every flavor announces through TEST_MODE_CHANGED: `on` is true while any is on.
local function announce()
    NS.addon:SendMessage(NS.MSG.TEST_MODE_CHANGED,
        State.testMode == true or State.previewAs ~= nil or State.editPreview ~= nil)
    -- The selector window shows exactly while Preview as is on (late-bound: it loads after this file).
    if NS.PreviewWindow then NS.PreviewWindow.Sync() end
    refreshPanel()
end

function P.IsTestMode()
    return State.testMode == true
end

--- Turn test mode on or off. A start is refused, with one line, while stood down (by hold:
--- NS.StoodDownRefusal) or in combat.
--- @return boolean changed
function P.SetTestMode(on)
    on = on and true or false
    if on == P.IsTestMode() then return false end
    if on then
        local refusal = NS.StoodDownRefusal()
        if refusal then
            NS.Print(refusal)
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
-- previewed button is disarmed). Only where you are changes: the class, specialization, role and
-- character are the live ones. Current is a preset too: a live preview of where you are, whose
-- snapshot is the live one, so it follows a zone change (SITUATION_CHANGED -> Surfaces.Request). It
-- ends on P.OFF ("off"), test mode, combat or the stand-down, never when the settings window closes.
-- Session-only (NS.State.previewAs).

P.CURRENT = "current"
P.OFF = "off"
local DOT = " \194\183 "

local RAID = { { "lfr", 17, L["LFR"] }, { "normal", 14, L["Normal"] }, { "heroic", 15, L["Heroic"] },
    { "mythic", 16, L["Mythic"] } }

-- The one dungeon and the one raid the menu previews (owner, 2026-10-22): a current-season dungeon,
-- Windrunner Spire (one of Midnight's own), and the tier's first raid; each falls back to the
-- season's first when a new season's lists no longer hold it (defaults/GameIds.lua).
local PREVIEW_DUNGEON = 2805

local function seasonPick(list, want)
    for _, id in ipairs(list) do
        if id == want then return id end
    end
    return list[1]
end

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

--- The "Preview as…" menu, in order (spec §13.3): { key, label, snapshot }; Current has none (it
--- previews the live snapshot, P.PreviewSnapshot).
function P.Presets()
    local out = { { key = P.CURRENT, label = L["Current"] } }
    local spec = NS.Compat.SpecName()
    -- One M+ entry: one current-season dungeon, labeled as spec §13.3 lists it.
    local id = seasonPick(NS.GameIds.DUNGEONS, PREVIEW_DUNGEON)
    local known = id and NS.Compat.InstanceName(id)
    local label = L["M+"]
    if id then label = label .. DOT .. (known or L["Instance %d"]:format(id)) end
    if spec then label = label .. DOT .. spec end
    out[#out + 1] = { key = "mplus", label = label, snapshot = mplus(id, known) }
    -- Each difficulty in the tier's first raid.
    local raid = seasonPick(NS.GameIds.RAIDS, nil)
    local raidName = raid and (NS.Compat.InstanceName(raid) or L["Instance %d"]:format(raid))
    for _, r in ipairs(RAID) do
        out[#out + 1] = { key = "raid:" .. r[1], label = L["Raid"] .. DOT .. r[3] .. (raidName and DOT .. raidName or ""),
            snapshot = base({ content = "raid", instanceID = raid, difficultyID = r[2], difficulty = r[1],
                group = "raid", instanceGroup = r[1] == "lfr" }) }
    end
    out[#out + 1] = { key = "arena", label = L["Arena"], snapshot = base({ content = "arena", group = "party",
        instanceGroup = false, lockdown = { pvpMatch = true } }) }
    for _, bg in ipairs(battlegrounds()) do
        out[#out + 1] = { key = bg.key, label = L["BG - %s"]:format(bg.label), snapshot = base({ content = "battleground",
            instanceID = bg.instanceID, group = "raid", instanceGroup = true, lockdown = { pvpMatch = true } }) }
    end
    out[#out + 1] = { key = "world", label = L["Solo"], snapshot = base({ content = "openWorld",
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
    if key == nil or key == P.OFF then return L["Off"] end
    if key == P.EDIT then
        local g = State.editPreview and NS.Library.Group(State.editPreview)
        return g and g.name or tostring(State.editPreview)
    end
    local e = P.FindPreset(key)
    return e and e.label or tostring(key)
end

--- The settings row's `values` list: Off, then every preset (Current included).
function P.Choices()
    local out = { { value = P.OFF, text = L["Off"] } }
    for _, e in ipairs(P.Presets()) do out[#out + 1] = { value = e.key, text = e.label } end
    return out
end

function P.PreviewAs()
    return State.previewAs
end

--- The previewed snapshot, or nil when "Preview as…" is off. Current answers the live snapshot.
function P.PreviewSnapshot()
    local key = State.previewAs
    if not key then return nil end
    if key == P.CURRENT then return NS.Situation.Current() end
    local e = P.FindPreset(key)
    return e and e.snapshot or nil
end

--- Preview the pads as `key`, or turn the preview off (nil, "" or "off"). A start is refused, with
--- one line, while stood down (by hold: NS.StoodDownRefusal) or in combat; an unknown key, silently.
--- @return boolean changed
function P.SetPreviewAs(key)
    local want
    if key ~= nil and key ~= "" and key ~= P.OFF then
        if not P.FindPreset(key) then return false end
        want = key
    end
    if want == State.previewAs then return false end
    if want then
        local refusal = NS.StoodDownRefusal()
        if refusal then
            NS.Print(refusal)
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

-- ── Editing a group (2026-10-19 groups polish, C4) ──────────────────────────────────────────
--
-- While the Groups page edits a group with Preview while editing on (settings/Groups.lua
-- SyncEditPreview), every pad and dial shows only that group and the groups inside it, whatever its
-- When says, drawn and disarmed as a Preview as plan is (modules/Surfaces.lua, plan.editGroup).
-- It wins over Preview as and test mode while it is on, and leaves both as they were: they come
-- back when it ends. Session-only (NS.State.editPreview). A start in combat or stood down is
-- refused without a line, because the page asks again on every draw; combat, the stand-down,
-- the page hiding and the settings window closing end it.

P.EDIT = "edit"

function P.EditGroup()
    return State.editPreview
end

--- Preview only group `gid` on every pad and dial, or end that (nil).
--- @return boolean changed
function P.SetEditPreview(gid)
    if gid == State.editPreview then return false end
    if gid ~= nil and (NS.IsStoodDown() or fighting()) then return false end
    State.editPreview = gid
    NS.Debug("Pad", "edit preview %s", tostring(gid or "off"))
    announce()
    return true
end

local watched = setmetatable({}, { __mode = "k" })

--- End the edit preview when the settings window closes. settings/Panel.lua hands it the client's
--- SettingsPanel once; the hook is insecure and runs only when that window hides. Preview as outlives
--- the settings window: the preview window carries its end control.
function P.WatchPanel(frame)
    if type(frame) ~= "table" or type(frame.HookScript) ~= "function" or watched[frame] then return false end
    watched[frame] = true
    frame:HookScript("OnHide", function()
        if State.editPreview then P.SetEditPreview(nil) end
    end)
    return true
end

local function onRestrictionChanged()
    if not NS.Restrictions.InCombat() then return end
    if P.IsTestMode() then
        P.SetTestMode(false)
        NS.Print(L["Test mode ended: you entered combat."])
    end
    -- One line for both previews: the edit preview and Preview as end together.
    local previewing = State.previewAs ~= nil or State.editPreview ~= nil
    if State.editPreview then P.SetEditPreview(nil) end
    if State.previewAs then P.SetPreviewAs(nil) end
    if previewing then NS.Print(L["Preview ended: you entered combat."]) end
end

-- Its own target (core/Bus.lua); the degraded bus is handled here, as in modules/Situation.lua.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.testMode, State.previewAs, State.editPreview = nil, nil, nil
    -- The stand-down announces nothing, so the selector window is told here.
    if NS.PreviewWindow then NS.PreviewWindow.Sync() end
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
