local addonName, NS = ...
-- core/QuickComms.lua — AceAddon registration and lifecycle; the one place NS is promoted to an addon.
--
-- Every game event the addon reacts to is declared in NS.FEATURE_EVENTS, so OnEnable and the
-- stand-up register exactly the same list and the stand-down unregisters exactly that list
-- (slash-commands-§7). Feature modules append their rows, and their teardown and rebuild steps
-- (NS.STAND_DOWN / NS.STAND_UP), at file load. The host handlers the launcher, the Master controls
-- rows and the slash verbs share live here or in settings/Slash.lua, so each surface calls the same
-- function.

local QC = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
NS.addon = QC

-- Reclaim NS.Print from AceConsole's embed: core/CoreSetup.lua published the library printer on
-- NS.Util.print, and the two names must be the same function object (architecture-§2).
NS.Print = NS.Util.print

-- Every game event this addon owns, as { event, handlerMethodName } pairs. Feature modules append
-- theirs at load (Restrictions, Situation, SendEngine's echo tracker); the latch registers and
-- unregisters the whole list.
NS.FEATURE_EVENTS = NS.FEATURE_EVENTS or {}

-- Teardown and rebuild steps feature modules contribute, run by the latch's two callbacks.
NS.STAND_DOWN = NS.STAND_DOWN or {}
NS.STAND_UP   = NS.STAND_UP or {}

local function registerFeatureEvents(self)
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        NS.SafeRegisterEvent(self, row[1], row[2], NS.rejectedEvents)
    end
end

local function runAll(list)
    for _, fn in ipairs(list) do fn() end
end

local function storedEnabled(self)
    local p = self.db and self.db.profile
    return not (p and p.enabled == false)
end

-- ── stand-down and stand-up (slash-commands-§7) ─────────────────────────────────────────────

--- The latch's standDown: every feature event and every tracked bus registration actually
--- unregistered, and every module's teardown run. The chat command, the dispatcher, the settings
--- category, the launcher and AceDB's callbacks are setup and stay up.
function NS.StandDown()
    for _, row in ipairs(NS.FEATURE_EVENTS) do QC:UnregisterEvent(row[1]) end
    NS.Bus:StandDown()
    runAll(NS.STAND_DOWN)
end

--- The latch's standUp: rebuilt from CURRENT state, because settings may change while off.
function NS.StandUp()
    registerFeatureEvents(QC)
    NS.Bus:StandUp()
    runAll(NS.STAND_UP)
end

-- ── profiles ────────────────────────────────────────────────────────────────────────────────

-- The three profile events share one reaction: migrations, panel refresh, the latch re-read (an
-- incoming profile carries its own answer to `enabled`), then PROFILE_CHANGED for every module that
-- caches a profile value.
local function reloadProfile(self)
    self:RunMigrations()
    NS.Library.Prepare()
    local S = self.Settings
    local H = S and S.Helpers
    if H and H.RefreshAll then H.RefreshAll() end
    if S and S.RefreshProfilesPage then S.RefreshProfilesPage() end
    if NS.Lifecycle then
        NS.Lifecycle:Set(NS.HOLD_DISABLED, not storedEnabled(self))
        NS.Lifecycle:Reevaluate()
    end
    self:SendMessage(NS.MSG.PROFILE_CHANGED)
end

-- Logged here, once (debug-logging-§10): a profile switch rewrites no row through the write seam.
function QC:OnProfileChanged(_, _, key)
    NS.Debug("Profile", "switched to '%s'", tostring(key or self.db:GetCurrentProfile()))
    reloadProfile(self)
end

function QC:OnProfileCopied(_, _, source)
    NS.Debug("Set", "copied profile '%s' \226\134\146 '%s'", source, self.db:GetCurrentProfile())
    reloadProfile(self)
end

function QC:OnProfileReset()
    local S = self.Settings
    local n = S and S.ConsumeResetCount and S.ConsumeResetCount()
    if n then
        NS.Debug("Set", "reset profile '%s' to defaults (%d rows)", self.db:GetCurrentProfile(), n)
    else
        NS.Debug("Set", "reset profile '%s' to defaults", self.db:GetCurrentProfile())
    end
    reloadProfile(self)
end

-- ── AceAddon lifecycle ──────────────────────────────────────────────────────────────────────

function QC:OnInitialize()
    -- settings/Schema.lua has loaded by ADDON_LOADED, so BuildDefaults exists.
    local S = self.Settings
    local defaults = S and S.BuildDefaults and S.BuildDefaults() or { profile = {} }
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
    NS.db = self.db

    -- Before anything reads the profile (savedvariables-§1).
    self:RunMigrations()
    NS.Library.Prepare()

    if self.db.RegisterCallback then
        self.db.RegisterCallback(self, "OnProfileChanged", function(...) self:OnProfileChanged(...) end)
        self.db.RegisterCallback(self, "OnProfileCopied",  function(...) self:OnProfileCopied(...) end)
        self.db.RegisterCallback(self, "OnProfileReset",   function(...) self:OnProfileReset(...) end)
    end

    self:RegisterChatCommand(NS.SLASH:sub(2), "OnSlashCommand")
    self:RegisterChatCommand(NS.SLASH_ALIAS:sub(2), "OnSlashCommand")
end

function QC:OnEnable()
    registerFeatureEvents(self)

    -- Eager category registration (options-ui-§1); bodies stay lazy.
    if self.Settings and self.Settings.Register then self.Settings.Register() end

    -- The launcher needs db.global.minimap, which exists from OnInitialize.
    if NS.Launcher then NS.Launcher:Register() end

    -- THE LATCH, taken from the stored path. Last, so everything above is up before it can be
    -- taken back down.
    if NS.Lifecycle then NS.Lifecycle:Set(NS.HOLD_DISABLED, not storedEnabled(self)) end
end

--- The [Init] session summary (debug-logging-§5): name, version, schema, profile, then state.
--- @return string
function QC:InitSummary()
    local db = self.db
    local schema  = db and db.global and db.global.schemaVersion
    local profile = (db and db.GetCurrentProfile and db:GetCurrentProfile()) or "?"
    local line = ("%s v%s, schema v%s, profile '%s' (enabled=%s)"):format(
        addonName, tostring(NS.Version()), tostring(schema), tostring(profile),
        tostring(storedEnabled(self)))
    if #NS.rejectedEvents > 0 then
        line = line .. ", rejected events: " .. table.concat(NS.rejectedEvents, ", ")
    end
    return line
end
