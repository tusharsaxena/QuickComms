local _, NS = ...
-- defaults/BuiltIns_MythicPlus.lua — the generic dungeon set (spec §12, brainstorm §8): any dungeon,
-- a keystone run included. Its id stays `bi.mplus`, as shipped ids do; migration step 5 renames and
-- widens the copies stored profiles hold (modules/Library_Migrate.lua MigrateBuiltins). The owner's
-- own set (2026-11-14): the pull, lust, mana and skip lines, a battle rez with an assist ping, the
-- boss mechanics and cooldown calls, a kick on the target with a warning ping and the skull, and the
-- lead's wipe. bi.mplus.chain and bi.mplus.healme are retired, never reused.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.mplus"

local dungeon = BI.Callouts(ID, "smartGroup", {
    { "pull",      L["Pulling"],     L["Pulling next pack"], "gi:stopwatch-lorc", C.yellow, { emote = "CHARGE" } },
    { "lust",      L["Lust"],        L["Lust on this pack"], "gi:enrage", C.red },
    { "mana",      L["Need mana"],   L["Wait, need mana"], "gi:water-drop", C.blue, { emote = "OOM" } },
    { "skip",      L["Skipping"],    L["Skipping with invis/shroud"], "gi:invisible", C.cyan },
    { "res",       L["Brez"],        L["Brez {target}"], "gi:hospital-cross", C.green, { ping = "assist" } },
    { "soak",      L["Soak"],        L["Soak!"], "gi:convergence-target", C.cyan },
    { "spread",    L["Spread"],      L["Spread!"], "gi:divergence", C.cyan },
    { "stack",     L["Stack"],       L["Stack!"], "gi:meeple-group", C.cyan },
    { "offensive", L["Offensive"],   L["Use offensive cooldowns!"], "gi:pointy-sword", C.amber },
    { "defensive", L["Defensive"],   L["Use personal defensives!"], "shield", C.amber },
    { "kicks",     L["Kick Target"], L["Kick {skull} {target}"], "gi:high-kick", C.purple, { ping = "warning", marker = 8 } },
})
for _, id in ipairs(BI.Callouts(ID, "smartLead", {
    { "wipe",      L["Wipe"],        L["Wipe it!"], "gi:skull-crossed-bones", C.red, { emote = "FLEE" } },
})) do dungeon[#dungeon + 1] = id end

BI.Group(ID, {
    name = L["Dungeon"], glyph = "gi:dungeon-gate", color = C.purple,
    when = { content = { dungeon = true, mythicPlus = true } }, callouts = dungeon,
})

BI.SNAPSHOTS[ID] = { content = "mythicPlus", group = "party", instanceGroup = false, difficulty = "keystone",
    keyLevel = 10, lockdown = { chat = true, challengeMode = true } }
