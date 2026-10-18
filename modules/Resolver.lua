local _, NS = ...
-- modules/Resolver.lua — When rules -> the active group set, each surface's order, and the "why"
-- lines (spec §5.3, §7). PURE. Rows AND; values inside a row OR; an empty or absent row is ignored,
-- so an empty When is "always on" (D6: every matching group is active, a union). A group inside
-- another that inherits its When conditions is judged by its parent's When (R.WhenOf).

NS.Resolver = NS.Resolver or {}
local R = NS.Resolver
local L = NS.L

R.ROWS = { "content", "instances", "battleground", "difficulty", "keyLevel", "group", "leadership",
    "class", "spec", "role", "characters" }

local LABEL = {
    content = L["Content"], instances = L["Instance"], battleground = L["Battleground"],
    difficulty = L["Difficulty"], keyLevel = L["Key level"], group = L["Group"],
    leadership = L["Leader or assist"], class = L["Class"], spec = L["Specialization"], role = L["Role"],
    characters = L["Character"],
}
R.LABEL = LABEL   -- the When editor's row labels (settings/Groups_When.lua)

--- The tokens each token row takes, in the When editor's order: the values modules/Situation.lua
--- puts in a snapshot. Library.ValidWhen refuses any other; the When editor and the CLI offer these.
--- The class row takes NS.GameIds.CLASSES; the id rows take ids (spec §5.3).
R.TOKENS = {
    content = { "openWorld", "dungeon", "mythicPlus", "raid", "delve", "scenario", "battleground", "arena", "housing" },
    difficulty = { "normal", "heroic", "mythic", "keystone", "lfr", "story", "follower" },
    group = { "solo", "party", "raid", "instance" },
    leadership = { "leader", "assist" },
    role = { "TANK", "HEALER", "DAMAGER" },
}

-- A character matches its Name-Realm without regard to case: a name typed in lower case still
-- names the character UnitFullName reports.
local function characterMatches(v, character)
    if type(character) ~= "string" then return false end
    if v[character] == true then return true end
    local want = character:lower()
    for name, on in pairs(v) do
        if on == true and type(name) == "string" and name:lower() == want then return true end
    end
    return false
end

local function isSet(row, v)
    if type(v) ~= "table" then return false end
    if row == "keyLevel" then return type(v.min) == "number" or type(v.max) == "number" end
    return next(v) ~= nil
end

local CHECK = {
    content      = function(v, s) return v[s.content] == true end,
    instances    = function(v, s) return s.instanceID ~= nil and v[s.instanceID] == true end,
    battleground = function(v, s) return s.content == "battleground" and s.instanceID ~= nil and v[s.instanceID] == true end,
    difficulty   = function(v, s) return s.difficulty ~= nil and v[s.difficulty] == true end,
    keyLevel     = function(v, s)
        if s.content ~= "mythicPlus" or type(s.keyLevel) ~= "number" then return false end
        return (type(v.min) ~= "number" or s.keyLevel >= v.min) and (type(v.max) ~= "number" or s.keyLevel <= v.max)
    end,
    group        = function(v, s) return (v.instance == true and s.instanceGroup == true) or v[s.group] == true end,
    leadership   = function(v, s) return (v.leader == true and s.leader == true) or (v.assist == true and s.assist == true) end,
    class        = function(v, s) return s.classFile ~= nil and v[s.classFile] == true end,
    spec         = function(v, s) return s.specID ~= nil and v[s.specID] == true end,
    role         = function(v, s) return s.role ~= nil and v[s.role] == true end,
    characters   = function(v, s) return characterMatches(v, s.character) end,
}

--- Whether a When matches a snapshot.
--- @return boolean ok, table|nil matched rows, string|nil the first failing row
function R.Matches(when, s)
    local matched = {}
    if type(when) ~= "table" then return true, matched end
    s = type(s) == "table" and s or {}
    for _, row in ipairs(R.ROWS) do
        local v = when[row]
        if isSet(row, v) then
            if not CHECK[row](v, s) then return false, nil, row end
            matched[#matched + 1] = row
        end
    end
    return true, matched
end

--- The When that judges group `id` (2026-10-18-when-drawers-design.md §3, Inherit when
--- conditions): its parent's while it sits inside one of `groups` and inheritWhen is not false (an
--- absent field is on), else its own. Its own stored When is kept, only not read.
--- @param groups table { [id] = { parent, inheritWhen, when } }
--- @return table|nil when, string|nil the id whose When it is
function R.WhenOf(groups, id)
    local g = type(groups) == "table" and groups[id] or nil
    if type(g) ~= "table" then return nil, nil end
    local top = type(g.parent) == "string" and groups[g.parent] or nil
    if g.inheritWhen ~= false and type(top) == "table" and g.parent ~= id then return top.when, g.parent end
    return g.when, id
end

--- Every enabled group whose When (R.WhenOf: a child that inherits, its parent's) matches (D6 union).
--- @param groups table { [id] = { enabled, when, parent, inheritWhen } }
--- @return table { [id] = { matched = rows } }
function R.ActiveGroups(groups, s)
    local active = {}
    for id, g in pairs(type(groups) == "table" and groups or {}) do
        if type(g) == "table" and g.enabled ~= false then
            local ok, matched = R.Matches((R.WhenOf(groups, id)), s)
            if ok then active[id] = { matched = matched } end
        end
    end
    return active
end

--- How narrow a When is: the number of set rows, plus 100 for a specific instance or battleground.
function R.Narrowness(when)
    if type(when) ~= "table" then return 0 end
    local n = 0
    for _, row in ipairs(R.ROWS) do
        if isSet(row, when[row]) then
            n = n + ((row == "instances" or row == "battleground") and 101 or 1)
        end
    end
    return n
end

--- A surface's active groups, in its own order; with autoPromote, narrower groups first (stable).
--- @param list table ordered group ids from the surface
--- @return table ordered active ids
function R.SurfaceOrder(list, active, groups, autoPromote)
    local out = {}
    for i, id in ipairs(type(list) == "table" and list or {}) do
        if active[id] then out[#out + 1] = { id = id, i = i } end
    end
    if autoPromote then
        local narrow = {}
        for _, e in ipairs(out) do narrow[e.id] = R.Narrowness((R.WhenOf(groups, e.id))) end
        table.sort(out, function(a, b)
            if narrow[a.id] ~= narrow[b.id] then return narrow[a.id] > narrow[b.id] end
            return a.i < b.i
        end)
    end
    for n, e in ipairs(out) do out[n] = e.id end
    return out
end

--- One "why" line for a group.
function R.Explain(name, info)
    local rows = info and info.matched or {}
    if #rows == 0 then return ("%s: %s"):format(tostring(name), L["always on"]) end
    local labels = {}
    for n, row in ipairs(rows) do labels[n] = LABEL[row] or row end
    return ("%s: %s"):format(tostring(name), table.concat(labels, ", "))
end
