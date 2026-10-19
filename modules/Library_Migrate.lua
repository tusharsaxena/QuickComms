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

-- Whether a stored When is the old shipped one: content M+ alone and no other row set.
local function oldDungeonWhen(when)
    if type(when) ~= "table" or type(when.content) ~= "table" then return false end
    for key, row in pairs(when) do
        if key ~= "content" and not (type(row) == "table" and next(row) == nil) then return false end
    end
    for key, on in pairs(when.content) do
        if on and key ~= "mythicPlus" then return false end
    end
    return when.content.mythicPlus == true
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
