local _, NS = ...
-- modules/Library.lua — THE registry writer (architecture-§5, spec §5, §12.2). The only module
-- that creates, deletes, orders or re-references profile.callouts / groups / pads / dials /
-- builtins / padOrder / dialOrder / nextId / seeded, and the surfaces' saved anchors (point).
-- Panel pages, slash verbs and (phase 5) import all call it. Built-ins are shipped data (NS.BuiltIns); the profile holds only their overlay.
-- Prepare runs after migrations on every profile load: it seeds, appends new built-ins once per
-- surface (seenBuiltins), and drops dangling ids.

NS.Library = NS.Library or {}
local Lib = NS.Library
local L = NS.L

local TAG = "Library"

local function P() return NS.db.profile end

local function announce(kind, id)
    NS.Debug(TAG, "%s %s", kind, tostring(id))
    NS.addon:SendMessage(NS.MSG.LIBRARY_CHANGED, kind, id)
end

local function indexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return nil
end

local function removeAll(list, value)
    local n = 0
    for i = #list, 1, -1 do if list[i] == value then table.remove(list, i) n = n + 1 end end
    return n
end

local function copyTable(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copyTable(v) end
    return out
end

local function isBuiltin(id) return type(id) == "string" and id:sub(1, 3) == "bi." end

local function topOf(id)
    local def = NS.BuiltIns.groups[id]
    while def and def.parent do id = def.parent def = NS.BuiltIns.groups[id] end
    return def and id or nil
end

--- A fresh user id: prefix .. n.
function Lib.NewId(prefix)
    local p = P()
    local n = p.nextId or 1
    p.nextId = n + 1
    return prefix .. n
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

local function overlay(id)
    local p = P()
    p.builtins[id] = p.builtins[id] or { enabled = true, hidden = {} }
    return p.builtins[id]
end

--- A callout by id (user or built-in); built-ins carry builtin = true. Read-only use.
function Lib.Callout(id)
    if isBuiltin(id) then
        local c = NS.BuiltIns.callouts[id]
        if not c then return nil end
        local out = copyTable(c)
        out.builtin = true
        return out
    end
    return P().callouts[id]
end

--- A group by id; built-ins are merged with their overlay (enabled, hidden callouts filtered out).
function Lib.Group(id)
    if not isBuiltin(id) then return P().groups[id] end
    local def = NS.BuiltIns.groups[id]
    if not def then return nil end
    local top = id
    while NS.BuiltIns.groups[top].parent do top = NS.BuiltIns.groups[top].parent end
    local o = P().builtins[top] or {}
    local hidden = o.hidden or {}
    local g = copyTable(def)
    g.builtin = true
    g.enabled = o.enabled ~= false
    g.callouts = {}
    for _, cid in ipairs(def.callouts or {}) do if not hidden[cid] then g.callouts[#g.callouts + 1] = cid end end
    return g
end

--- Every top-level group (user and built-in), merged, keyed by id: the Resolver's input.
function Lib.AllGroups()
    local all = {}
    for id, g in pairs(P().groups) do all[id] = g end
    for _, id in ipairs(NS.BuiltIns.order) do all[id] = Lib.Group(id) end
    return all
end

--- The user groups that reference a callout.
function Lib.UsedBy(calloutId)
    local out = {}
    for gid, g in pairs(P().groups) do
        if indexOf(g.callouts or {}, calloutId) then out[#out + 1] = gid end
    end
    table.sort(out)
    return out
end

-- ── callouts ────────────────────────────────────────────────────────────────────────────────

Lib.NAME_MAX = 32   -- characters, not bytes: a translated built-in name may be multi-byte

-- UTF-8 characters in `s`: every byte that is not a continuation byte (0x80-0xBF) starts one.
local function chars(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

local function validCallout(f)
    if type(f) ~= "table" then return false, "badCallout" end
    if type(f.name) ~= "string" or f.name == "" or chars(f.name) > Lib.NAME_MAX then return false, "badName" end
    if type(f.text) ~= "string" then return false, "badText" end
    if not NS.Channels.IsKind(f.channel) then return false, "badChannel" end
    if f.icon ~= nil and type(f.icon) ~= "number" and type(f.icon) ~= "string" then return false, "badIcon" end
    return true
end

--- Create a user callout.
--- @return string|nil id, string|nil reason
function Lib.CreateCallout(fields)
    local ok, why = validCallout(fields)
    if not ok then return nil, why end
    local id = Lib.NewId("c")
    P().callouts[id] = { name = fields.name, text = fields.text, channel = fields.channel, icon = fields.icon }
    announce("callout", id)
    return id
end

--- Delete a user callout and every reference to it.
function Lib.DeleteCallout(id)
    local p = P()
    if not p.callouts[id] then return false end
    p.callouts[id] = nil
    for _, g in pairs(p.groups) do removeAll(g.callouts, id) end
    announce("callout", id)
    return true
end

-- ── groups ──────────────────────────────────────────────────────────────────────────────────

--- Create a user group.
function Lib.CreateGroup(fields)
    if type(fields) ~= "table" or type(fields.name) ~= "string" or fields.name == "" then return nil, "badName" end
    local id = Lib.NewId("g")
    P().groups[id] = { name = fields.name, icon = fields.icon, callouts = {}, when = copyTable(fields.when) or {},
        openInto = fields.openInto == true, enabled = fields.enabled ~= false }
    announce("group", id)
    return id
end

local function surfaces()
    local p = P()
    return { pad = p.pads, dial = p.dials }
end

--- Delete a user group and every surface reference to it.
function Lib.DeleteGroup(id)
    local p = P()
    if not p.groups[id] then return false end
    p.groups[id] = nil
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do removeAll(s.groups, id) end
    end
    announce("group", id)
    return true
end

--- Add a callout to a user group at `index` (end by default). A built-in callout is copied first (P2).
--- @return string|nil the callout id actually added, string|nil reason
function Lib.AddToGroup(groupId, calloutId, index)
    local g = P().groups[groupId]
    if not g then return nil, "noGroup" end
    local id = calloutId
    if isBuiltin(calloutId) then
        local src = NS.BuiltIns.callouts[calloutId]
        if not src then return nil, "noCallout" end
        local why
        id, why = Lib.CreateCallout({ name = src.name, text = src.text, channel = src.channel, icon = src.icon })
        if not id then return nil, why end
    elseif not P().callouts[calloutId] then
        return nil, "noCallout"
    end
    index = math.max(1, math.min(index or (#g.callouts + 1), #g.callouts + 1))
    table.insert(g.callouts, index, id)
    announce("group", groupId)
    return id
end

function Lib.RemoveFromGroup(groupId, index)
    local g = P().groups[groupId]
    if not (g and g.callouts[index]) then return false end
    table.remove(g.callouts, index)
    announce("group", groupId)
    return true
end

function Lib.MoveInGroup(groupId, from, to)
    local g = P().groups[groupId]
    if not (g and g.callouts[from]) or type(to) ~= "number" then return false end
    to = math.max(1, math.min(to, #g.callouts))
    table.insert(g.callouts, to, table.remove(g.callouts, from))
    announce("group", groupId)
    return true
end

-- ── built-ins ───────────────────────────────────────────────────────────────────────────────

function Lib.SetBuiltinEnabled(id, on)
    local top = topOf(id)
    if not top then return false end
    overlay(top).enabled = on and true or false
    announce("builtin", top)
    return true
end

function Lib.SetBuiltinCalloutHidden(groupId, calloutId, hidden)
    local top = topOf(groupId)
    if not top then return false end
    overlay(top).hidden[calloutId] = hidden and true or nil
    announce("builtin", top)
    return true
end

--- Copy a top-level built-in into an editable user group, swap it into every surface at the same
--- place, and turn the built-in off (spec §12.2). Node children are flattened: v0.1.0 has no user
--- nesting, so a customized node battleground keeps every node's callouts in one list. A callout
--- whose copy fails validation is skipped, never inserted as a hole, and counted.
--- @return string|nil id, string|nil reason, number skipped
function Lib.Customize(builtinId)
    local def = NS.BuiltIns.groups[builtinId]
    if not def or def.parent then return nil, "notTopLevel" end
    local prior = overlay(builtinId).customizedAs
    if prior and P().groups[prior] then return nil, "alreadyCustomized" end
    local id = Lib.CreateGroup({ name = def.name .. " " .. L["(custom)"], icon = def.icon, when = def.when,
        openInto = def.openInto == true })
    local skipped = 0
    local function copyFrom(gid)
        for _, cid in ipairs(Lib.Group(gid).callouts) do
            local added, why = Lib.AddToGroup(id, cid)
            if not added then
                skipped = skipped + 1
                NS.Debug(TAG, "customize %s: skipped %s (%s)", builtinId, cid, tostring(why))
            end
        end
        for _, child in ipairs(NS.BuiltIns.groups[gid].children or {}) do copyFrom(child) end
    end
    copyFrom(builtinId)
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do
            local at = indexOf(s.groups, builtinId)
            if at then s.groups[at] = id end
        end
    end
    overlay(builtinId).enabled = false
    overlay(builtinId).customizedAs = id
    announce("builtin", builtinId)
    return id, nil, skipped
end

-- ── surfaces ────────────────────────────────────────────────────────────────────────────────

local SURFACE_DEFAULTS = {
    pad = { groupsAs = "sections", layout = { orientation = "horizontal", columns = 4, growth = "right",
        style = "iconLabel", scale = 1.0, spacing = 4, width = 140 },
        look = { visibility = "always", fade = "none", fadeAlpha = 0.4 } },
    dial = { mode = "categories", slices = 4, depth = 2, openAt = "center", delay = 0.3,
        interaction = "quick", key = nil, tapAction = "first" },
}

--- Create a pad or dial holding every built-in group (in BuiltIns.order).
function Lib.CreateSurface(kind, name)
    local p = P()
    local set = kind == "pad" and p.pads or kind == "dial" and p.dials
    if not set then return nil, "badKind" end
    local id = Lib.NewId(kind == "pad" and "p" or "d")
    local s = copyTable(SURFACE_DEFAULTS[kind])
    s.name, s.enabled, s.groups, s.seenBuiltins = name, true, {}, {}
    for _, gid in ipairs(NS.BuiltIns.order) do
        s.groups[#s.groups + 1] = gid
        s.seenBuiltins[gid] = true
    end
    set[id] = s
    local order = kind == "pad" and p.padOrder or p.dialOrder
    order[#order + 1] = id
    announce(kind, id)
    return id
end

function Lib.DeleteSurface(kind, id)
    local p = P()
    local set = kind == "pad" and p.pads or kind == "dial" and p.dials
    if not (set and set[id]) then return false end
    set[id] = nil
    removeAll(kind == "pad" and p.padOrder or p.dialOrder, id)
    announce(kind, id)
    return true
end

local function surface(kind, sid)
    local s = surfaces()[kind]
    return s and s[sid]
end

function Lib.AddGroupToSurface(kind, sid, gid, index)
    local s = surface(kind, sid)
    local known = P().groups[gid] or (NS.BuiltIns.groups[gid] and not NS.BuiltIns.groups[gid].parent)
    if not s or not known or indexOf(s.groups, gid) then return false end
    index = math.max(1, math.min(index or (#s.groups + 1), #s.groups + 1))
    table.insert(s.groups, index, gid)
    if isBuiltin(gid) then s.seenBuiltins[gid] = true end
    announce(kind, sid)
    return true
end

function Lib.RemoveGroupFromSurface(kind, sid, gid)
    local s = surface(kind, sid)
    if not s or removeAll(s.groups, gid) == 0 then return false end
    announce(kind, sid)
    return true
end

--- Set, or with nil clear, a pad's or dial's saved anchor (spec §5.1, the named non-setting state).
--- The drag strip and Reset position call it; nothing else writes `point`. A plain copy is stored,
--- so the caller's table never aliases the profile.
--- @param point table|nil { point, relativePoint, x, y }: two strings, then two numbers
--- @return boolean
function Lib.SetSurfacePoint(kind, sid, point)
    local s = surface(kind, sid)
    if not s then return false end
    if point ~= nil then
        if type(point) ~= "table" or type(point[1]) ~= "string" or type(point[2]) ~= "string"
            or type(point[3]) ~= "number" or type(point[4]) ~= "number" then
            return false
        end
        s.point = { point[1], point[2], point[3], point[4] }
    else
        s.point = nil
    end
    announce(kind, sid)
    return true
end

-- ── prepare ─────────────────────────────────────────────────────────────────────────────────

local function exists(gid) return P().groups[gid] ~= nil or (NS.BuiltIns.groups[gid] ~= nil and not NS.BuiltIns.groups[gid].parent) end

local REGISTRY = { "callouts", "groups", "builtins", "pads", "dials", "padOrder", "dialOrder" }

-- The registry's top-level keys as tables, and its entries as tables, before anything walks them.
local function normalize(p, result)
    for _, key in ipairs(REGISTRY) do
        if type(p[key]) ~= "table" then p[key] = {} result.repaired = result.repaired + 1 end
    end
    for _, key in ipairs({ "callouts", "groups", "builtins", "pads", "dials" }) do
        for id, v in pairs(p[key]) do
            if type(v) ~= "table" then p[key][id] = nil result.repaired = result.repaired + 1 end
        end
    end
end

-- nextId above the largest numeric suffix of any user id, so a stale counter never reuses one.
local function liftNextId(p)
    local high = 0
    for _, key in ipairs({ "callouts", "groups", "pads", "dials" }) do
        for id in pairs(p[key]) do
            local n = type(id) == "string" and tonumber(id:match("^[cgpd](%d+)$"))
            if n and n > high then high = n end
        end
    end
    if type(p.nextId) ~= "number" or p.nextId <= high then p.nextId = high + 1 end
end

--- Seed, append newly shipped built-ins once per surface, and drop dangling ids. Idempotent.
--- @return table { seeded, appended, repaired }
function Lib.Prepare()
    local p = P()
    local result = { seeded = false, appended = 0, repaired = 0 }
    normalize(p, result)
    liftNextId(p)
    if not p.seeded then
        if #p.padOrder == 0 then Lib.CreateSurface("pad", L["Comms Pad"]) end
        if #p.dialOrder == 0 then Lib.CreateSurface("dial", L["Comms Dial"]) end
        p.seeded = true
        result.seeded = true
    end
    for _, g in pairs(p.groups) do
        g.callouts = type(g.callouts) == "table" and g.callouts or {}
        for i = #g.callouts, 1, -1 do
            if not p.callouts[g.callouts[i]] then table.remove(g.callouts, i) result.repaired = result.repaired + 1 end
        end
    end
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do
            s.seenBuiltins = type(s.seenBuiltins) == "table" and s.seenBuiltins or {}
            s.groups = type(s.groups) == "table" and s.groups or {}
            for i = #s.groups, 1, -1 do
                if not exists(s.groups[i]) then table.remove(s.groups, i) result.repaired = result.repaired + 1 end
            end
            for _, gid in ipairs(NS.BuiltIns.order) do
                if not s.seenBuiltins[gid] then
                    s.seenBuiltins[gid] = true
                    if not indexOf(s.groups, gid) then
                        s.groups[#s.groups + 1] = gid
                        result.appended = result.appended + 1
                    end
                end
            end
        end
    end
    for kind, set in pairs(surfaces()) do
        local order = kind == "pad" and p.padOrder or p.dialOrder
        for i = #order, 1, -1 do
            if not set[order[i]] then table.remove(order, i) result.repaired = result.repaired + 1 end
        end
        local ids = {}
        for id in pairs(set) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            if not indexOf(order, id) then order[#order + 1] = id result.repaired = result.repaired + 1 end
        end
    end
    if result.seeded or result.appended > 0 or result.repaired > 0 then
        NS.Debug(TAG, "prepare seeded=%s appended=%s repaired=%s", result.seeded, result.appended, result.repaired)
    end
    return result
end
