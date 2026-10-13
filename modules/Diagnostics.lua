local _, NS = ...
-- modules/Diagnostics.lua — the addon's sections of `/qc diagnostics` (debug-logging-§14).
--
-- Sections only: the markers, the identity header's library half, the per-section pcall, the cap
-- and the Add loop are LibKa0s-DebugLog-1.0's. Every section READS state and never acts: no hold,
-- no event, no timer, safe in combat and while stood down. `out:add` formats %s-only and runs every
-- argument through safeToString, so raw values are passed, never pre-built strings. The feature
-- tasks add their own sections (design spec §16: the snapshot, restrictions, active groups, armed
-- buttons, the combat queue, bindings, the guard, the echo tracker) here.

NS.Diagnostics = NS.Diagnostics or {}

local TAG = "Diag"

local function stoodDown() return NS.IsStoodDown and NS.IsStoodDown() or false end

local function read(fn, ...)
    if type(fn) ~= "function" then return "unavailable" end
    local ok, v = pcall(fn, ...)
    if not ok then return "unreadable" end
    return v
end

-- The report runs after OnInitialize, so the db exists; a section that raises costs one line
-- (the library pcalls each section).
local function identity(out)
    local db = NS.addon.db
    out:add(TAG, "schema stored=%s code=%s", db.global.schemaVersion, NS.SCHEMA_VERSION)
    out:add(TAG, "profile=%s", db:GetCurrentProfile())
    out:add(TAG, "enabled=%s stoodDown=%s", db.profile.enabled, stoodDown())
    out:joined(TAG, "holds", NS.Lifecycle:Holds())
end

local function settings(out)
    local S = NS.SchemaRuntime
    local Settings = NS.addon and NS.addon.Settings
    out:nonDefaults(Settings and Settings.Schema, function(row) return S.Get(row.path) end, nil, nil,
        { always = { "enabled" } })
end

local function registration(out)
    local names = {}
    for i, row in ipairs(NS.FEATURE_EVENTS or {}) do names[i] = row[1] end
    out:joined(TAG, "feature events (declared)", names)
    -- Stood down, the latch has unregistered them; the declared list is printed either way.
    out:add(TAG, "feature events registered=%s", not stoodDown())
    out:list(TAG, "rejected events", NS.rejectedEvents or {})
end

local function integrations(out)
    local Lc = NS.Launcher
    out:add(TAG, "launcher: registered=%s shown=%s", Lc and read(Lc.IsRegistered, Lc),
        Lc and read(Lc.IsShown, Lc))
end

local function situation(out)
    local s = NS.Situation.Current()
    out:add("Situation", "content=%s instanceID=%s difficulty=%s key=%s group=%s instanceGroup=%s",
        s.content, s.instanceID, s.difficulty, s.keyLevel, s.group, s.instanceGroup)
    out:add("Situation", "leader=%s assist=%s class=%s spec=%s role=%s combat=%s",
        s.leader, s.assist, s.classFile, s.specID, s.role, s.inCombat)
    local lock = {}
    for k, v in pairs(s.lockdown or {}) do if v then lock[#lock + 1] = k end end
    table.sort(lock)
    out:add("Situation", "lockdown=%s", table.concat(lock, ","))
end

-- The restriction state (spec §16): every reason in effect, the one the chip names, and whether
-- a chat message may be sent. Read live, like every Restrictions answer.
local function restrictions(out)
    local R = NS.Restrictions
    local active = {}
    for reason in pairs(R.ActiveSet()) do active[#active + 1] = tostring(reason) end
    table.sort(active)
    local snap = R.Snapshot()
    out:add("RES", "active=%s reason=%s canSendChat=%s inCombat=%s",
        table.concat(active, ","), snap.reason, snap.canSendChat, R.InCombat())
end

local function count(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

local function library(out)
    local p = NS.db.profile
    out:add("Library", "callouts=%s groups=%s pads=%s dials=%s nextId=%s seeded=%s",
        count(p.callouts), count(p.groups), #p.padOrder, #p.dialOrder, p.nextId, p.seeded)
    local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), NS.Situation.Current())
    local ids = {}
    for id in pairs(active) do ids[#ids + 1] = id end
    table.sort(ids)
    out:add("Library", "active=%s", table.concat(ids, ","))
end

--- The sections, in report order. Read at RUN time by core/DebugLogSetup.lua's descriptor.
--- @return table
function NS.Diagnostics.Sections()
    return {
        { "identity",     identity },
        { "settings",     settings },
        { "registration", registration },
        { "integrations", integrations },
        { "situation",    situation },
        { "restrictions", restrictions },
        { "library",      library },
    }
end
