local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table and the LibKa0s-Slash-1.0 descriptor.
--
-- The dispatcher, help renderer, formatters and value parser are the library's (slash-commands-§1);
-- the structured member rows' text forms are this file's, through the descriptor's `parse` and
-- `format` hooks (slash-commands-§6). What stays here is the ordered verb table (positional triples {name, desc, fn}) and the host verbs
-- that reach into this addon's own state. Every verb that toggles something calls the same handler
-- its Master controls row and its launcher entry call. The design spec's other verbs (§14: preview and
-- why arrive with the features they report on; check, lock, unlock and test are here)
-- follow the reserved set in the table below.

local QC = NS.addon
local L  = NS.L

local SLASH = NS.SLASH

local function helpers() return QC.Settings and QC.Settings.Helpers end
local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local ENABLED_PATH = "enabled"

local Sl   -- forward-declared: the handlers below reach it at call time
local runConfig, runDebug, runReset, runResetAll, runEnabled, runPerf

local COMMANDS = {
    {"help",     L["List available commands"],
        function() Sl:PrintHelp() end},
    {"config",   L["Open the Ka0s Quick Comms settings panel"],
        function() runConfig() end},
    {"enable",   L["Enable the addon"],
        function() runEnabled(true) end},
    {"disable",  L["Disable the addon"],
        function() runEnabled(false) end},
    {"lock",     L["Lock the Comms Pads in place"],
        function() NS.SlashVerbs.SetLocked(true) end},
    {"unlock",   L["Unlock the Comms Pads so they can be dragged"],
        function() NS.SlashVerbs.SetLocked(false) end},
    {"version",  L["Print the addon version"],
        function() Sl:CliVersion() end},
    {"list",     L["List every setting and its current value"],
        function() Sl:CliList() end},
    {"get",      L["Print a setting's current value — `/qc get <path>`"],
        function(rest) Sl:CliGet(rest) end},
    {"set",      L["Set a setting — `/qc set <path> <value>` (try /qc list)"],
        function(rest) Sl:CliSet(rest) end},
    {"reset",    L["Reset one setting to its default — `/qc reset <path>`"],
        function(rest) runReset(rest) end},
    {"resetall", L["Reset every setting to defaults"],
        function() runResetAll() end},
    {"profile",  L["List profiles, or switch to one: profile <name>"],
        function(rest) Sl:CliProfile(rest) end},
    {"debug",    L["Open/close the debug window — `/qc debug on|off` toggles logging"],
        function(rest) runDebug(rest) end},
    {"diagnostics", L["Write the diagnostics report to the debug console"],
        function() NS.DebugLog:RunDiagnostics() end},
    {"perf",     L["Measure performance — `/qc perf` opens the step panel"],
        function(rest) runPerf(rest) end},
    {"check",    L["Show the line a callout would send here (never sends)"],
        function(rest) NS.SlashVerbs.Check(rest) end},
    {"test",     L["Turn test mode on or off (placeholder chips; combat ends it)"],
        function() NS.Preview.ToggleTestMode() end},
    {"preview",  L["Preview the pads as another situation — `/qc preview <name>` or `off`; `/qc preview` lists them"],
        function(rest) NS.SlashVerbs.Preview(rest) end},
}
NS.COMMANDS = COMMANDS

local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local CLI_MISSING = L["%s, so the settings CLI is unavailable."]:format(NS.LIBKA0S_MISSING)

local function libraryAbsent(verb)
    NS.Print(L["%s is unavailable: the LibKa0s library did not load."]:format(verb))
end

-- The gate the dispatcher asks: the STORED switch, not the latch. A perf capture holds the latch
-- too, and is a reason to be inert, never a reason to refuse the player's verbs.
local function storedEnabled()
    local S = NS.SchemaRuntime
    return not (S and S.Get(ENABLED_PATH) == false)
end

-- ── the structured member rows on the command line (slash-commands-§6) ──────────────────────
--
-- Three member rows hold a table (settings/SchemaMembers.lua). The library parses and prints bool,
-- number, string and color; the descriptor's `parse` and `format` hooks teach it these three and
-- hand every other row back to it:
--   pad.point       `x y` (keeps the pad's anchor points) or `POINT RELATIVEPOINT x y`
--   group.when      `<condition> <value>[,<value>...]` replaces that one condition; the condition
--                   alone clears it; keyLevel takes `min-max`, either end empty, or one level
--   builtin.hidden  callout ids, or `none`
-- A row is written to the member Settings.EditingId addresses, as every member row is. A member row
-- with no member to address prints "(nothing to edit)" instead of nil.

local function wordsOf(text)
    local out = {}
    for w in (text or ""):gmatch("[^%s,]+") do out[#out + 1] = w end
    return out
end

local function parsePoint(text)
    local w = wordsOf(text)
    local x, y = tonumber(w[#w - 1] or ""), tonumber(w[#w] or "")
    if not (x and y) or (#w ~= 2 and #w ~= 4) then
        return nil, L["A position is `x y` or `POINT RELATIVEPOINT x y`."]
    end
    if #w == 4 then return { w[1]:upper(), w[2]:upper(), x, y } end
    local current = NS.SchemaRuntime.Get("pad.point")
    local base = type(current) == "table" and current or NS.Pad.DEFAULT_POINT
    return { base[1], base[2], x, y }
end

local function knownCondition(name)
    for _, row in ipairs(NS.Resolver.ROWS) do
        if row == name then return true end
    end
    return false
end

-- `min-max`, `min-`, `-max` or one level.
local function parseKeyLevel(text)
    local lo, dash, hi = text:match("^(%d*)%s*(%-?)%s*(%d*)$")
    if not lo or (lo == "" and hi == "") or (dash == "" and hi ~= "") then return nil end
    if dash == "" then hi = lo end
    return { min = tonumber(lo), max = tonumber(hi) }
end

local function parseWhen(text)
    local name, rest = (text or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if not (name and knownCondition(name)) then
        return nil, L["Name a condition: %s."]:format(table.concat(NS.Resolver.ROWS, ", "))
    end
    local current = NS.SchemaRuntime.Get("group.when")
    local when = {}
    for k, v in pairs(type(current) == "table" and current or {}) do when[k] = v end
    if rest == "" then
        when[name] = nil
    elseif name == "keyLevel" then
        when.keyLevel = parseKeyLevel(rest)
        if not when.keyLevel then return nil, L["A key level is `min-max`; either end may be empty."] end
    else
        local set = {}
        for _, v in ipairs(wordsOf(rest)) do set[tonumber(v) or v] = true end
        when[name] = set
    end
    return when
end

local function parseIdSet(text)
    local w = wordsOf(text)
    if #w == 0 then return nil, L["Name the callout ids to hide, or none."] end
    local set = {}
    if not (#w == 1 and w[1]:lower() == "none") then
        for _, id in ipairs(w) do set[id] = true end
    end
    return set
end

local PARSE = { point = parsePoint, when = parseWhen, idset = parseIdSet }

local function sortedKeys(set)
    local keys = {}
    for k in pairs(set) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return keys
end

local function formatWhen(when)
    local parts = {}
    for _, row in ipairs(NS.Resolver.ROWS) do
        local v = type(when) == "table" and when[row] or nil
        if row == "keyLevel" and type(v) == "table" and (v.min or v.max) then
            parts[#parts + 1] = ("keyLevel=%s..%s"):format(v.min and tostring(v.min) or L["any"],
                v.max and tostring(v.max) or L["any"])
        elseif row ~= "keyLevel" and type(v) == "table" and next(v) then
            parts[#parts + 1] = row .. "=" .. table.concat(sortedKeys(v), ",")
        end
    end
    if #parts == 0 then return L["always"] end
    return table.concat(parts, "; ")
end

local FORMAT = {
    point = function(v)
        if type(v) ~= "table" then return L["the default place"] end
        return ("%s %s %s %s"):format(tostring(v[1]), tostring(v[2]), tostring(v[3]), tostring(v[4]))
    end,
    when = formatWhen,
    idset = function(v)
        if type(v) ~= "table" or next(v) == nil then return L["none"] end
        return table.concat(sortedKeys(v), ", ")
    end,
}

local function memberExists(kind)
    local id = QC.Settings.EditingId(kind)
    return id ~= nil and NS.Library.Member(kind, id) ~= nil
end

if not lib then
    -- Degrade, never error: `/qc` is registered unconditionally, so something must answer. The
    -- host verbs keep working; the schema CLI names the missing library. The ONE library string the
    -- stub carries verbatim is DISABLED_LINE_FORMAT, pinned by Kit.assertLibraryConstant.
    local function unavailable() NS.Print(CLI_MISSING) end
    local function profileAbsent() libraryAbsent(SLASH .. " profile") end
    local DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"

    local function helpRow(entry) return SLASH .. " " .. entry[1] .. " — " .. entry[2] end

    -- The verbs that answer while disabled: the standard's reserved set, plus `profile`. Any other
    -- verb the addon ships prints the one refusal line instead (slash-commands-§2).
    local LIVE = { help = true, config = true, version = true, enable = true, disable = true,
        debug = true, perf = true, diagnostics = true, get = true, set = true, list = true,
        reset = true, resetall = true, profile = true }

    Sl = {
        OnSlash = function(_, msg)
            local raw = trim(msg)
            if raw == "" then return runConfig() end
            local name, rest = raw:match("^(%S+)%s*(.*)$")
            name = (name or ""):lower()
            for _, entry in ipairs(COMMANDS) do
                if entry[1] == name then
                    if not (LIVE[name] or storedEnabled()) then return NS.Print(Sl:DisabledLine()) end
                    return entry[3](rest or "")
                end
            end
            NS.Print(L["unknown command '%s'"]:format(name))
            Sl:PrintHelp()
        end,
        PrintHelp = function()
            NS.Print(L["v%s slash commands"]:format(NS.Version()))
            for _, entry in ipairs(COMMANDS) do NS.Print("  " .. helpRow(entry)) end
        end,
        HelpRows = function()
            local out = {}
            for i, entry in ipairs(COMMANDS) do out[i] = "  " .. helpRow(entry) end
            return out
        end,
        LandingRows = function()
            local out = {}
            for i, entry in ipairs(COMMANDS) do out[i] = helpRow(entry) end
            return out
        end,
        HelpHeader   = function() return L["v%s slash commands"]:format(NS.Version()) end,
        DisabledLine = function() return DISABLED_LINE_FORMAT:format(NS.BRAND, SLASH .. " enable") end,
        __disabledLineFormat = DISABLED_LINE_FORMAT,
        CliList         = unavailable,
        CliGet          = unavailable,
        CliSet          = unavailable,
        CliReset        = unavailable,
        CliResetAll     = unavailable,
        CliVersion      = function() NS.Print("v" .. NS.Version()) end,
        BuildListLines  = function() return { CLI_MISSING } end,
        SetRowAnnotator = function() end,
        Text            = function(_, key) return key end,
        CliProfile      = function() profileAbsent() end,
        ProfileSwitch   = function() profileAbsent(); return false end,
    }
    NS.SlashCommands = Sl
else
    -- `profile` answers while disabled too: it is how a player reaches an enabled profile.
    local liveVerbs = {}
    for i, verb in ipairs(lib.LIVE_VERBS) do liveVerbs[i] = verb end
    liveVerbs[#liveVerbs + 1] = "profile"

    Sl = lib:New({
        slash        = SLASH,
        slashAliases = { NS.SLASH_ALIAS },
        commands     = COMMANDS,                       -- passed IN, never owned by the library
        isEnabled    = storedEnabled,
        brandName    = NS.BRAND,
        liveVerbs    = liveVerbs,
        profiles     = function() return QC.db end,
        print        = function(line) NS.Print(line) end,
        debug        = function(tag, message) NS.Debug(tag, message) end,
        version      = NS.Version,
        get          = NS.SchemaRuntime.Get,
        set          = NS.SchemaRuntime.Set,           -- the single write seam
        findRow      = NS.SchemaRuntime.FindRow,
        allRows      = function() return QC.Settings.Schema end,
        applyDefault = NS.SchemaRuntime.ApplyDefault,
        bulkBegin    = NS.SchemaRuntime.BulkBegin,
        bulkEnd      = NS.SchemaRuntime.BulkEnd,
        groupKey     = function(row) return row.page or "general" end,
        -- The structured member rows' text forms; every other row is the library's (see above).
        parse        = function(row, text, textOf)
            local fn = row and PARSE[row.type]
            if fn then return fn(text) end
            return lib.ParseValue(row, text, textOf)
        end,
        format       = function(row, value)
            if row and row.instance and value == nil and not memberExists(row.instance) then
                return L["(nothing to edit)"]
            end
            local fn = row and FORMAT[row.type]
            if fn then return fn(value) end
            return lib.FormatValue(row, value)
        end,
    })
    NS.SlashCommands = Sl
end

--- Open the settings panel (registering the category first if OnEnable has not run yet).
function QC:OpenSettings()
    if self.Settings and self.Settings.Register then self.Settings.Register() end
    local H = helpers()
    if not (H and H.OpenOptionsPanel) then return NS.Print(L["Settings panel is not available."]) end
    H.OpenOptionsPanel()
end

function runConfig() QC:OpenSettings() end

-- `/qc enable|disable`: aliases writing the Enable row's stored path through the write seam. On a
-- library-absent load the path is written through (settings/Schema.lua `writeThrough`).
function runEnabled(on)
    local S = NS.SchemaRuntime
    local ok, err = S.Set(ENABLED_PATH, on)
    if ok == false then return NS.Print(tostring(err)) end
    local value = S.Get(ENABLED_PATH)
    local row = S.FindRow(ENABLED_PATH)
    if lib and row then return NS.Print(lib.FormatKV(row.path, lib.FormatValue(row, value))) end
    NS.Print(ENABLED_PATH .. " = " .. tostring(value))
end

function runReset(rest)
    if trim(rest) == "" then
        NS.Print(L["|cffFFFF00%s|r takes a setting path: |cffFFFF00%s|r (try |cffFFFF00%s|r). To reset everything: |cffFFFF00%s|r."]
            :format(SLASH .. " reset", SLASH .. " reset <path>", SLASH .. " list", SLASH .. " resetall"))
        return
    end
    Sl:CliReset(rest)
end

function runResetAll()
    local H = helpers()
    if not (H and H.RestoreAllDefaults) then return NS.Print(CLI_MISSING) end
    QC.Settings.EnsureResetPopup()
    StaticPopup_Show(QC.Settings.RESET_POPUP)
end

-- `diagnostics` is tested FIRST (inside DebugVerb), then on/off; anything else toggles the console.
function runDebug(rest)
    local DL = NS.DebugLog
    if not DL:DebugVerb(rest) then DL:Toggle() end
end

-- The library returns the lines; the addon prints them (performance-§4).
function runPerf(rest)
    for _, line in ipairs(NS.Perf.OnCommand(rest) or {}) do NS.Print(line) end
end

function QC:SlashEnabled(on) runEnabled(on and true or false) end

function QC:OnSlashCommand(input)
    Sl:OnSlash(input)
end
