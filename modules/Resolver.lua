local _, NS = ...
-- modules/Resolver.lua — When rules -> the active group set, each surface's order, and the "why"
-- lines (spec §5.3, §7). PURE. Rows AND; values inside a row OR; an empty or absent row is ignored,
-- so an empty When is "always on" (D6: every matching group is active, a union).

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

local function isSet(row, v)
    if type(v) ~= "table" then return false end
    if row == "keyLevel" then return v.min ~= nil or v.max ~= nil end
    return next(v) ~= nil
end

local CHECK = {
    content      = function(v, s) return v[s.content] == true end,
    instances    = function(v, s) return s.instanceID ~= nil and v[s.instanceID] == true end,
    battleground = function(v, s) return s.content == "battleground" and s.instanceID ~= nil and v[s.instanceID] == true end,
    difficulty   = function(v, s) return s.difficulty ~= nil and v[s.difficulty] == true end,
    keyLevel     = function(v, s)
        if s.content ~= "mythicPlus" or type(s.keyLevel) ~= "number" then return false end
        return (v.min == nil or s.keyLevel >= v.min) and (v.max == nil or s.keyLevel <= v.max)
    end,
    group        = function(v, s) return (v.instance == true and s.instanceGroup == true) or v[s.group] == true end,
    leadership   = function(v, s) return (v.leader == true and s.leader == true) or (v.assist == true and s.assist == true) end,
    class        = function(v, s) return s.classFile ~= nil and v[s.classFile] == true end,
    spec         = function(v, s) return s.specID ~= nil and v[s.specID] == true end,
    role         = function(v, s) return s.role ~= nil and v[s.role] == true end,
    characters   = function(v, s) return s.character ~= nil and v[s.character] == true end,
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

--- Every enabled group whose When matches (D6 union).
--- @param groups table { [id] = { enabled, when } }
--- @return table { [id] = { matched = rows } }
function R.ActiveGroups(groups, s)
    local active = {}
    for id, g in pairs(type(groups) == "table" and groups or {}) do
        if type(g) == "table" and g.enabled ~= false then
            local ok, matched = R.Matches(g.when, s)
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
        for _, e in ipairs(out) do narrow[e.id] = R.Narrowness(groups[e.id] and groups[e.id].when) end
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
