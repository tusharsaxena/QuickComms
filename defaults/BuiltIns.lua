local _, NS = ...
-- defaults/BuiltIns.lua — the shipped, read-only callout sets (spec §12): the registry table and
-- the helpers the four data files use. Shipped data, not registry members (architecture-§5): the
-- profile stores only the overlay (profile.builtins). Built-in ids are stable once shipped.

NS.BuiltIns = NS.BuiltIns or { groups = {}, callouts = {}, order = {}, SNAPSHOTS = {} }
local BI = NS.BuiltIns

--- Declare a callout. `short` is appended to the group id: "bi.mplus" + "lust" -> "bi.mplus.lust".
--- @return string id
function BI.Callout(groupId, short, name, text, channel, icon)
    local id = groupId .. "." .. short
    BI.callouts[id] = { name = name, text = text, channel = channel, icon = icon }
    return id
end

--- Declare a group. Top-level groups (no parent) join BI.order in declaration order.
function BI.Group(id, def)
    def.callouts = def.callouts or {}
    BI.groups[id] = def
    if def.parent == nil then BI.order[#BI.order + 1] = id end
    return def
end

--- Callouts from a list of { short, name, text[, icon] } rows, all on `channel`.
function BI.Callouts(groupId, channel, rows)
    local ids = {}
    for n, r in ipairs(rows) do ids[n] = BI.Callout(groupId, r[1], r[2], r[3], channel, r[4]) end
    return ids
end
