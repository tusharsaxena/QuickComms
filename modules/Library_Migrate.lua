local _, NS = ...
-- modules/Library_Migrate.lua — the registry writer's schemaVersion steps (savedvariables-§1), kept
-- beside modules/Library.lua (which is at its line budget). core/Database.lua's runner calls each one
-- for every stored profile, with the raw profile table; each step is idempotent against a fresh
-- default profile and leaves a damaged value as it found it.

NS.Library = NS.Library or {}
local Lib = NS.Library

-- The growth values a step rewrites: `up` (Upward) split into Right and up / Left and up (B2), and
-- the old Upward always drew rightward.
local RETIRED_GROWTH = { up = "rightUp" }

--- Step 4: every pad whose layout still carries a retired growth takes its new value.
function Lib.MigrateGrowth(profile)
    local pads = type(profile) == "table" and profile.pads
    if type(pads) ~= "table" then return end
    for _, pad in pairs(pads) do
        local layout = type(pad) == "table" and pad.layout
        if type(layout) == "table" and RETIRED_GROWTH[layout.growth] then
            layout.growth = RETIRED_GROWTH[layout.growth]
        end
    end
end

-- The generic dungeon set's name and When as builds before step 5 seeded them; a copy still holding
-- them is unedited. The literal, not a locale key: the one locale is enUS, and the key is retired.
local OLD_DUNGEON_NAME = "M+ (generic)"

-- The icons seeded callouts shipped with before step 5, by origin; a copy still holding one, or no
-- icon at all (nil: never set), takes its glyph. False is a cleared icon, and stays cleared.
local OLD_CALLOUT_ICONS = {
    ["bi.mplus.lust"] = "Interface\\Icons\\Spell_Nature_Bloodlust",
    ["bi.raid.lust"]  = "Interface\\Icons\\Spell_Nature_Bloodlust",
    ["bi.mplus.res"]  = "Interface\\Icons\\Spell_Nature_Reincarnation",
}

-- Whether a stored When sets no row but content (an empty row is unset; a malformed one is set).
local function contentAlone(when)
    for key, row in pairs(when) do
        if key ~= "content" and not (type(row) == "table" and next(row) == nil) then return false end
    end
    return true
end

-- Whether a stored content row ticks M+ and nothing else.
local function mythicPlusAlone(content)
    for key, on in pairs(content) do
        if on and key ~= "mythicPlus" then return false end
    end
    return content.mythicPlus == true
end

-- Whether a stored When is the old shipped one: content M+ alone and no other row set.
local function oldDungeonWhen(when)
    return type(when) == "table" and type(when.content) == "table" and contentAlone(when)
        and mythicPlusAlone(when.content)
end

local function migrateDungeonSet(groups)
    for _, g in pairs(groups) do
        if type(g) == "table" and g.origin == "bi.mplus" then
            if g.name == OLD_DUNGEON_NAME then g.name = NS.BuiltIns.groups["bi.mplus"].name end
            if oldDungeonWhen(g.when) then g.when.content.dungeon = true end
        end
    end
end

local function migrateCalloutIcons(callouts)
    local shipped = NS.BuiltIns.callouts
    for _, c in pairs(callouts) do
        local def = type(c) == "table" and type(c.origin) == "string" and shipped[c.origin]
        if def and def.icon and (c.icon == nil or c.icon == OLD_CALLOUT_ICONS[c.origin]) then
            c.icon, c.iconColor = def.icon, def.iconColor
        end
    end
end

--- Step 5 (B7): every copy of the generic dungeon set the player has not renamed takes its new name,
--- and one whose When is still the shipped M+ only takes Dungeon too; every seeded callout whose
--- icon is unset or the one it shipped with takes its catalog glyph and color.
function Lib.MigrateBuiltins(profile)
    if type(profile) ~= "table" then return end
    if type(profile.groups) == "table" then migrateDungeonSet(profile.groups) end
    if type(profile.callouts) == "table" then migrateCalloutIcons(profile.callouts) end
end

-- The game icons the generic sets shipped with before step 6, by origin; every other seeded group
-- shipped with none (nil). A copy still holding its one takes its glyph and color.
local OLD_GROUP_ICONS = {
    ["bi.mplus"] = "Interface\\Icons\\INV_Relics_Hourglass",
    ["bi.raid"]  = "Interface\\Icons\\Achievement_Boss_Ragnaros",
    ["bi.arena"] = "Interface\\Icons\\Achievement_Arena_2v2_7",
    ["bi.bg"]    = "Interface\\Icons\\Achievement_BG_winWSG",
}

-- The node sets that shipped with no callouts of their own before step 6.
local NEW_OWN_CALLOUTS = { "bi.bg.ab", "bi.bg.eots", "bi.bg.bfg", "bi.bg.dwg", "bi.bg.ioc" }

-- A fresh callout id on a raw profile: above nextId and every numeric suffix already taken, as
-- Library's liftNextId keeps it, so a stale counter never reuses an id.
local function takeCalloutId(profile)
    local high = type(profile.nextId) == "number" and profile.nextId - 1 or 0
    for _, key in ipairs({ "callouts", "groups", "pads", "dials" }) do
        for id in pairs(type(profile[key]) == "table" and profile[key] or {}) do
            local n = type(id) == "string" and tonumber(id:match("^[cgpd](%d+)$"))
            if n and n > high then high = n end
        end
    end
    profile.nextId = high + 2
    return "c" .. (high + 1)
end

local function colorGroups(groups)
    local shipped = NS.BuiltIns.groups
    for _, g in pairs(groups) do
        local def = type(g) == "table" and type(g.origin) == "string" and shipped[g.origin]
        if def and def.icon and g.iconColor == nil and (g.icon == nil or g.icon == OLD_GROUP_ICONS[g.origin]) then
            g.icon, g.iconColor = def.icon, def.iconColor
        end
    end
end

-- A seeded callout still showing its shipped glyph with no color (as every uncolored one shipped)
-- takes the glyph's color. A picked color, a picked or cleared icon, is the player's.
local function colorCallouts(callouts)
    local shipped = NS.BuiltIns.callouts
    for _, c in pairs(callouts) do
        local def = type(c) == "table" and type(c.origin) == "string" and shipped[c.origin]
        if def and def.icon and c.iconColor == nil and c.icon == def.icon then c.iconColor = def.iconColor end
    end
end

-- Each copy of a node set (by origin) gets, at the end of its list, every shipped callout of its own
-- that none of its callouts keeps the origin of. A set the player deleted has no copy, so it stays
-- deleted; one held already is never added twice.
local function addOwnCallouts(profile)
    local wanted = {}
    for _, origin in ipairs(NEW_OWN_CALLOUTS) do wanted[origin] = NS.BuiltIns.groups[origin] end
    for _, g in pairs(profile.groups) do
        local def = type(g) == "table" and type(g.callouts) == "table" and wanted[g.origin]
        if def then
            local have = {}
            for _, cid in ipairs(g.callouts) do
                local c = profile.callouts[cid]
                if type(c) == "table" and c.origin then have[c.origin] = true end
            end
            for _, origin in ipairs(def.callouts) do
                if not have[origin] then
                    local c, id = NS.BuiltIns.callouts[origin], takeCalloutId(profile)
                    profile.callouts[id] = { name = c.name, text = c.text, channel = c.channel, icon = c.icon,
                        iconColor = c.iconColor, origin = origin }
                    g.callouts[#g.callouts + 1] = id
                end
            end
        end
    end
end

--- Step 6 (groups polish): every seeded group whose icon is unset or the game icon it shipped with
--- takes its catalog glyph and color; every seeded callout still on its shipped glyph with no color
--- takes the glyph's color; and each node set's copy gains the map-wide callouts it lacks. The World
--- (solo) set is new, so Prepare seeds it (seededSets) like any newly shipped set.
function Lib.MigrateBuiltinsPolish(profile)
    if type(profile) ~= "table" then return end
    if type(profile.groups) == "table" then colorGroups(profile.groups) end
    if type(profile.callouts) == "table" then
        colorCallouts(profile.callouts)
        if type(profile.groups) == "table" then addOwnCallouts(profile) end
    end
end

--- Step 7 (bg subgroups): every newly shipped node goes inside its set's copy while that is a
--- top-level group (Library.SeedNewNodes, by origin through seededSets: a node or set the player
--- deleted stays deleted, and nothing already held is touched). A copy nested in another group takes
--- no nodes. Prepare seeds the same nodes into a profile never prepared.
function Lib.MigrateBattlegroundNodes(profile)
    if type(profile) ~= "table" or type(profile.groups) ~= "table" then return end
    Lib.SeedNewNodes(profile)
end

-- The group fields the dial rework (2026-10-21) retired: Open the dial on this group and Skip on the
-- dial in content. A dial now opens straight on its one active group, or on a ring of them.
local RETIRED_GROUP_FIELDS = { "openInto", "dialYield" }

--- Step 8 (dial rework): every stored group drops the retired dial fields.
function Lib.MigrateDialFields(profile)
    if type(profile) ~= "table" or type(profile.groups) ~= "table" then return end
    for _, g in pairs(profile.groups) do
        if type(g) == "table" then
            for _, k in ipairs(RETIRED_GROUP_FIELDS) do g[k] = nil end
        end
    end
end

-- The slice leaves the dial polish (2026-10-21) retired: the Slices tab's Border heading. A Slice gap
-- parts the slices now, and no lines are drawn between them.
local RETIRED_SLICE_FIELDS = { "borderSize", "borderColor", "useClassColorBorder" }

--- Step 9 (dial polish): every stored dial's slice table drops the retired border leaves.
function Lib.MigrateSliceBorder(profile)
    if type(profile) ~= "table" or type(profile.dials) ~= "table" then return end
    for _, d in pairs(profile.dials) do
        if type(d) == "table" and type(d.slice) == "table" then
            for _, k in ipairs(RETIRED_SLICE_FIELDS) do d.slice[k] = nil end
        end
    end
end

-- The HUD style pickers that follow the skin through their "Use the skin's ..." companion (QC-03,
-- DECISIONS X4: only the faces and the border styles; colors, sizes and flags stay the player's), by
-- surface kind, as `<block>.<picker>`: each one's companion is `<block>.<picker>FromSkin`.
Lib.FROM_SKIN_KEYS = {
    pad = { "look.borderStyle", "header.font", "header.borderStyle", "section.font", "section.borderStyle",
        "button.font", "button.borderStyle", "icon.borderStyle" },
    dial = { "icon.borderStyle", "label.font", "title.font" },
}

-- One stored surface's companions turned on. A companion the surface stores goes through
-- LibKa0s-Skin-1.0's ResetToSkin, named by its picker, which sets the companion beside a picker that
-- has one. One it does not store yet (a surface saved before QC-03) is written true here: handed an
-- absent companion, a ResetToSkin before LibKa0s v1.81.0 (Skin minor 8) could not tell it is a bool
-- and wrote its "@skin" sentinel into the picker. Minor 8 fixes that only for a caller that names
-- the companion or passes `{ companions = true }`; this step shipped before it and is kept as it is
-- (Ka0sAddonsCommonTasks D-19: a profile that migrates late must get the same result, and a newer
-- library's fix is harmless beside it). Without the library every companion is written here; it
-- means nothing until the library loads, and then it must already say "follow". A block the surface
-- lacks is fillShape's (Prepare fills it from the template, whose companions are true).
local function followSkin(surface, keys, resetToSkin)
    local named = {}
    for _, key in ipairs(keys) do
        local block, picker = key:match("^(%w+)%.(%w+)$")
        local t = surface[block]
        if type(t) == "table" then
            local companion = picker .. "FromSkin"
            if resetToSkin and t[companion] ~= nil then
                named[#named + 1] = key
            else
                t[companion] = true
            end
        end
    end
    if #named > 0 then resetToSkin(surface, named) end
end

--- Step 10 (QC-03, the owner's ruling O2): the one-time reset onto the skin. Every stored pad's and
--- dial's font and border pickers follow the skin again, once, for every player: each block's
--- companion is turned on. The stored picks are kept (a companion turned off brings them back), and
--- no color, size or flag is touched. The runner's stamp is what makes it once: a player who turns a
--- companion off afterwards keeps that pick, because this step never runs again.
function Lib.MigrateFollowSkin(profile)
    if type(profile) ~= "table" then return end
    local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
    local resetToSkin = Skin and type(Skin.ResetToSkin) == "function" and Skin.ResetToSkin or nil
    for kind, list in pairs({ pad = profile.pads, dial = profile.dials }) do
        for _, surface in pairs(type(list) == "table" and list or {}) do
            if type(surface) == "table" then followSkin(surface, Lib.FROM_SKIN_KEYS[kind], resetToSkin) end
        end
    end
end
