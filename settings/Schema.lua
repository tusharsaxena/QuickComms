local _, NS = ...
-- settings/Schema.lua — the schema rows and the one write seam every settings path goes through.
--
-- One row per setting drives the panel widget, `/qc list|get|set|reset` and the defaults reset
-- (architecture-§5). The rows are declared by the page files (settings/Panel.lua) and spliced in at
-- load; this file owns the array, the seam, the reactions every surface shares, the defaults tree
-- and the global reset.

local QC = NS.addon
local L  = NS.L
local C  = NS.C

QC.Settings = QC.Settings or {}
local Settings   = QC.Settings
Settings.Schema  = {}
Settings.Helpers = Settings.Helpers or {}
local Schema  = Settings.Schema
local Helpers = Settings.Helpers

local function pout(...) return NS.Print(...) end

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do c[k] = deepcopy(val) end
    return c
end

-- ── storage that is not a profile path ──────────────────────────────────────────────────────

-- Session-only rows: never SavedVariables. The console's own flag. And the test mode (design spec
-- §10.4).
local SESSION = {
    ["state.debugConsole"] = {
        get = function()
            local DL = NS.DebugLog
            local spec = DL and DL.ConsoleCheckbox and DL:ConsoleCheckbox()
            return spec and spec.get() or false
        end,
        set = function(v)
            v = v and true or false
            local DL = NS.DebugLog
            local spec = DL and DL.ConsoleCheckbox and DL:ConsoleCheckbox()
            if spec then spec.set(v) end
        end,
    },
    -- Test mode (spec §10.4): the one switch is modules/Preview.lua's; the row reads and writes it.
    ["state.testMode"] = {
        get = function() return NS.Preview ~= nil and NS.Preview.IsTestMode() end,
        set = function(v) if NS.Preview then NS.Preview.SetTestMode(v and true or false) end end,
    },
    -- Preview as… (spec §13.3): modules/Preview.lua owns the switch; "current" is off.
    ["state.previewAs"] = {
        get = function() return NS.Preview ~= nil and NS.Preview.PreviewAs() or "current" end,
        set = function(v) if NS.Preview then NS.Preview.SetPreviewAs(v) end end,
    },
}

-- The Minimap button row reads and writes LibDBIcon's own `hide` in the GLOBAL store, inverted
-- (launcher-§3). There is no `shown` key anywhere.
local MINIMAP_PATH = "global.minimap.shown"
Settings.MINIMAP_PATH = MINIMAP_PATH
local function minimapStore()
    local db = QC.db
    return db and db.global and db.global.minimap
end
local GLOBAL = {
    [MINIMAP_PATH] = {
        get = function()
            local t = minimapStore()
            return not (t and t.hide)
        end,
        set = function(v)
            v = v and true or false
            local t = minimapStore()
            if t then t.hide = not v end
            if NS.Launcher then NS.Launcher:SetShown(v) end
        end,
    },
}

--- Bind get/set closures onto the rows whose storage is not a profile path.
--- @param rows table
function Settings.StampClosureRows(rows)
    for _, row in ipairs(rows or {}) do
        local path = type(row) == "table" and row.path or nil
        local spec = SESSION[path] or GLOBAL[path]
        if spec then
            row.get = spec.get
            row.set = spec.set
        end
    end
end

-- ── the reactions every surface shares ──────────────────────────────────────────────────────

-- What a write to each Master controls path does, whichever surface made it: the panel checkbox,
-- the CLI, the launcher or a host verb. settings/Panel.lua binds these as the composed rows'
-- onChange; on a load where the composers are hollow the same paths are written through
-- (`writeThrough` below) and `announce` runs the same reaction.
-- A write that changes what a pad draws asks the surfaces for one rebuild, which waits for the end
-- of combat on its own (spec §13.1: setters that rebuild secure frames queue through SendEngine).
local function rebuildSurfaces()
    if NS.Surfaces and NS.Surfaces.Request then NS.Surfaces.Request("settings") end
end
Settings.RebuildSurfaces = rebuildSurfaces

Settings.REACTIONS = {
    enabled = function(v)
        if NS.Lifecycle then NS.Lifecycle:Set(NS.HOLD_DISABLED, v == false) end
    end,
    visibility = rebuildSurfaces,
    scale      = rebuildSurfaces,
    alpha      = rebuildSurfaces,
    -- The drag strip is not protected: it shows and hides at once, in combat too.
    locked     = function() if NS.Pad and NS.Pad.ApplyLock then NS.Pad.ApplyLock() end end,
}

local function announce(row, path, value)
    if row.writeThrough then
        local react = Settings.REACTIONS[path]
        if react then react(value) end
    end
    if Helpers.RefreshAll then Helpers.RefreshAll() end
end

-- ── members (architecture-§5) ───────────────────────────────────────────────────────────────

-- A member's own fields are rows whose path starts with the member's kind (settings/SchemaMembers.lua).
-- The seam addresses the member by the instance argument or, without one, by Settings.EditingId: the
-- member that kind's editor page has selected, else the first member that page lists, so the panel's
-- widgets and the CLI write the member the page shows (or would show when opened); the drag and
-- Library's built-in writers name theirs. Library resolves the id. A callout is addressed by its id
-- alone (BY_ID): no page selects one, since a callout is edited in its group's popup, so a write that
-- names none would land on an arbitrary callout. With no member to address (none of that kind
-- exists, a callout write names no id, or a named id is gone) there is no root, and the write is
-- refused with a line saying where to make one, or how to name it.
local INSTANCE = { callout = true, group = true, pad = true, dial = true, builtin = true }
Settings.INSTANCE_KINDS = INSTANCE

-- The kinds whose rows are addressed by id alone; the CLI reads the id after the path (settings/Slash.lua).
local BY_ID = { callout = true }
Settings.BY_ID_KINDS = BY_ID

local NO_MEMBER = {
    callout = L["Name the callout id: /qc set callout.<field> <id> <value>."],
    group   = L["No group to edit: make one on the Groups page."],
    pad     = L["No pad to edit: make one on the Comms Pad page."],
    dial    = L["No dial to edit: make one on the Comms Dial page."],
    builtin = L["No built-in set is selected: pick one on the Groups page."],
}

--- The member a kind's rows address when a write names none: the page's selection while it exists,
--- else the first member the page lists (Library.MemberIds). A built-in set's overlay has no
--- fallback: it is only ever the set the Groups page shows. A callout has neither: it is only ever
--- the one a write names.
--- @return string|nil
function Settings.EditingId(kind)
    if BY_ID[kind] then return nil end
    local id = NS.State.editing[kind]
    if id ~= nil and NS.Library.Member(kind, id) then return id end
    if kind == "builtin" then return nil end
    return NS.Library.MemberIds(kind)[1]
end

local function resolveRoot(parts, id)
    local kind = parts and parts[1]
    if INSTANCE[kind] then
        if not QC.db then return nil, NO_MEMBER[kind] end
        if id == nil then id = Settings.EditingId(kind) end
        local member = id ~= nil and NS.Library.Member(kind, id) or nil
        if member then return member, 2, id end
        if BY_ID[kind] and id ~= nil then return nil, L["No callout with id %s."]:format(tostring(id)) end
        return nil, NO_MEMBER[kind]
    end
    return QC.db and QC.db.profile, 1
end

-- ── the write seam ──────────────────────────────────────────────────────────────────────────

-- The panel checkbox, the CLI, the launcher and the resets all land in S.Set.
local S = Settings.SchemaLib:New{
    rows         = Schema,
    resolveRoot  = resolveRoot,
    announce     = announce,
    debug        = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    debugEnabled = function() return NS.State.debug == true end,
    print        = pout,
    -- options-ui-§1 route (a): the host verbs that write a composed row still land on a load where
    -- the composer is hollow.
    writeThrough = { "enabled" },
    -- The minimap button is a per-installation display preference: neither reset may touch it. A
    -- member's icon, a pad's or dial's position and a dial's key have a default only so a named
    -- `/qc reset` restores them; a page's Defaults (a bracketed sweep) keeps them.
    resetExempt  = { [MINIMAP_PATH] = true, ["callout.icon"] = true, ["group.icon"] = true, ["pad.point"] = true,
        ["dial.point"] = true, ["dial.key"] = true },
}
NS.SchemaRuntime = S

Helpers.Get, Helpers.Set, Helpers.FindSchema, Helpers.ApplyDefault =
    S.Get, S.Set, S.FindRow, S.ApplyDefault
Settings.ConsumeResetCount = S.ConsumeResetCount

--- A setting's value through the seam: the stored one, or the row's default while there is no
--- database yet. The one read every module's settings go through.
--- @param path string
--- @return any
function NS.Setting(path)
    local v = S.Get(path)
    if v == nil then v = S.Default(path) end
    return v
end

--- One settings page's rows, in schema order: those whose `page` is `pageKey`. A page's `group`s
--- are its tabs (options-ui-§13); handing every page the whole schema would give each one every tab.
--- @param pageKey string
--- @return table
function Settings.RowsForPage(pageKey)
    local out = {}
    for _, row in ipairs(Schema) do
        if row.page == pageKey then out[#out + 1] = row end
    end
    return out
end

-- `point`, `when`, `idset` and `key` are the structured member rows (settings/SchemaMembers.lua): each
-- drawn by its own control on its editor page (a dial's key by a capture box) and typed and printed on
-- the CLI by settings/Slash.lua's parse and format hooks. `color` is a pad's Look swatches (phase 5),
-- which the options library draws and its CLI parses and prints itself.
local VALID_TYPES = { bool = true, number = true, string = true, point = true, when = true, idset = true,
    key = true, color = true }

-- A row carrying BOTH its own get and set owns its storage, so there is no defaults entry at its
-- path: answering nil makes the library skip the resolution check for it (the session rows, and
-- the Minimap button row, whose backing key is resolved explicitly below). Every other row's path
-- must resolve against the profile defaults tree (architecture-§5).
local function defaultsRootFor(profileDefaults)
    return function(_, row)
        if row and type(row.get) == "function" and type(row.set) == "function" then return nil end
        -- A member row resolves against its kind's template, from the segment after the kind.
        if row and row.instance then return NS.Library.TEMPLATES[row.instance], 2 end
        return profileDefaults, 1
    end
end

-- The Minimap button row's backing key is LibDBIcon's `hide` in the GLOBAL defaults (launcher-§3).
local function minimapBackingMissing(defaults)
    local mm = defaults.global and defaults.global.minimap
    if type(mm) == "table" and mm.hide ~= nil then return 0 end
    pout("|cffff0000schema error|r: " .. MINIMAP_PATH .. ": backing key `global.minimap.hide` "
        .. "does not resolve against the defaults")
    return 1
end

--- Validate every row; returns the error count plus the paths that do not resolve against the
--- defaults. The `schema error` lines are developer diagnostics for a malformed row, not
--- player-facing text, so they stay literal (not through NS.L).
--- @return number
function Helpers.ValidateSchema()
    local defaults = Settings.BuildDefaults()
    local errors, _, missing = S.Validate{
        types        = VALID_TYPES,
        defaultsRoot = defaultsRootFor(defaults.profile),
    }
    errors = errors + (missing or 0) + minimapBackingMissing(defaults)
    for i, def in ipairs(Schema) do
        if type(def) == "table" and type(def.label) ~= "string" then
            pout("|cffff0000schema error|r: row #" .. i .. " (" .. tostring(def.path or "<no path>")
                .. "): missing or non-string `label`")
            errors = errors + 1
        end
    end
    return errors
end

-- ── defaults and the global reset ───────────────────────────────────────────────────────────

--- The AceDB defaults tree: defaults/Profile.lua's two scopes, then every stored schema row.
--- A member row (`instance`) is no default: its member's fields are written whole when Library
--- creates it.
--- @return table
function Settings.BuildDefaults()
    local out = {
        profile = deepcopy(C.PROFILE),
        global  = deepcopy(C.GLOBAL_DEFAULTS),
    }
    for _, def in ipairs(Schema) do
        if def.path and not def.sessionOnly and not GLOBAL[def.path] and not def.instance then
            local segs = {}
            for part in string.gmatch(def.path, "[^.]+") do segs[#segs + 1] = part end
            local parent = out.profile
            for i = 1, #segs - 1 do
                parent[segs[i]] = parent[segs[i]] or {}
                parent = parent[segs[i]]
            end
            parent[segs[#segs]] = deepcopy(def.default)
        end
    end
    return out
end

-- The rows a profile reset counts (debug-logging-§10's N): not a global row, and not a member row,
-- which addresses whichever member is selected and has no profile default of its own.
local function notGlobal(row) return not GLOBAL[row.path] and not row.instance end
Settings.CountedByProfileReset = notGlobal

--- The global reset IS a profile reset (options-ui-§12); the walk keeps only session rows.
--- @param row table
--- @return boolean
function Settings.VetoedFromResetAll(row)
    return row.page == "profiles" or not row.sessionOnly
end

function Helpers.RestoreAllDefaults()
    local db = QC.db
    if db and db.ResetProfile then
        local ok, err = pcall(S.ResetCounted, function() db:ResetProfile() end, notGlobal)
        if not ok then
            NS.Debug("Set", "reset profile '%s' to defaults (stopped by an error)", db:GetCurrentProfile())
            error(err, 0)
        end
    end
    S.BulkRun("reset", "profile", function(info)
        info.profileReset = true
        for _, def in ipairs(Schema) do
            if not Settings.VetoedFromResetAll(def) then S.ApplyDefault(def) end
        end
    end)
end

function Helpers.RefreshAll()
    local H = Settings.Helpers
    if H and H.RefreshScalars then H.RefreshScalars() end
end

Settings.RESET_POPUP = "QUICKCOMMS_RESET_ALL"

function Settings.EnsureResetPopup()
    if Settings._resetPopupRegistered then return end
    Settings._resetPopupRegistered = true
    StaticPopupDialogs[Settings.RESET_POPUP] = {
        text         = L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected."],
        button1      = YES or "Yes",
        button2      = NO  or "No",
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
        preferredIndex = 3,   -- clear of the slots Blizzard's own popups take first
        OnAccept     = function()
            Helpers.RestoreAllDefaults()
            pout(L["all settings reset to defaults"])
        end,
    }
end
