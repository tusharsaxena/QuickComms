local _, NS = ...
-- defaults/BuiltIns.lua — the shipped callout sets (spec §12): the seed table and the helpers the
-- data files use. Seed data, not registry members (architecture-§5): Library gives each profile
-- these sets once as ordinary user groups and callouts (2026-10-18-builtins-as-groups-design.md),
-- each keeping its shipped id as its `origin`, so a shipped id is stable once shipped.

NS.BuiltIns = NS.BuiltIns or { groups = {}, callouts = {}, order = {}, SNAPSHOTS = {} }
local BI = NS.BuiltIns

-- The tints a shipped glyph takes, one per meaning (B7, groups polish): red for attack, a kill or
-- danger, green for life, all-clear and safety, blue for water, mana and defense, gold for a reward,
-- lust or a win, orange for an alarm or something incoming, purple for crowd control and magic, cyan
-- for moving and positioning, white for the neutral. Every shipped glyph takes one, and no set is
-- white only (tests/test_builtins.lua).
BI.COLOR = { red = "ff4040", green = "40d040", blue = "4da6ff", gold = "ffd100", orange = "ff9933",
    purple = "b07cff", cyan = "40d8e0", white = "ffffff" }

--- Declare a callout. `short` is appended to the group id: "bi.mplus" + "lust" -> "bi.mplus.lust".
--- `glyph` names its icon in the LibKa0s catalog (B7; library-stack-§8: a shipped mark, never one
--- drawn here) and `color` tints it ("rrggbb", where the color carries meaning). The catalog name is
--- kept as `glyph` for the integrity tests; seeding copies `icon` (its texture path) and `iconColor`.
--- Without the library the icon is nil, and so is the color, which only a glyph takes.
--- @return string id
function BI.Callout(groupId, short, name, text, channel, glyph, color)
    local id = groupId .. "." .. short
    local icon = glyph and NS.Icon(glyph) or nil
    BI.callouts[id] = { name = name, text = text, channel = channel, icon = icon, glyph = glyph,
        iconColor = icon and color or nil }
    return id
end

--- Declare a group. Top-level groups (no parent) join BI.order in declaration order. `def.glyph`
--- names its icon in the catalog and `def.color` tints it, as a callout's do (BI.Callout): seeding
--- copies `icon` and `iconColor`, and `glyph` stays for the integrity tests.
function BI.Group(id, def)
    def.callouts = def.callouts or {}
    def.icon = def.glyph and NS.Icon(def.glyph) or nil
    def.iconColor = def.icon and def.color or nil
    def.color = nil
    BI.groups[id] = def
    if def.parent == nil then BI.order[#BI.order + 1] = id end
    return def
end

--- Callouts from a list of { short, name, text, glyph[, color] } rows, all on `channel`.
function BI.Callouts(groupId, channel, rows)
    local ids = {}
    for n, r in ipairs(rows) do ids[n] = BI.Callout(groupId, r[1], r[2], r[3], channel, r[4], r[5]) end
    return ids
end
