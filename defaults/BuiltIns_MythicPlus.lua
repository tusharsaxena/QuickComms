local _, NS = ...
-- defaults/BuiltIns_MythicPlus.lua — the generic dungeon set (spec §12, brainstorm §8): any dungeon,
-- a keystone run included. Its id stays `bi.mplus`, as shipped ids do; migration step 5 renames and
-- widens the copies stored profiles hold (modules/Library_Migrate.lua MigrateBuiltins).

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.mplus"

BI.Group(ID, {
    name = L["Dungeon"], glyph = "gi:dungeon-gate", color = C.purple,
    when = { content = { dungeon = true, mythicPlus = true } },
    callouts = BI.Callouts(ID, "smartGroup", {
        { "pull",   L["Pulling"],        L["Pulling next pack"], "gi:crossed-swords", C.orange },
        { "lust",   L["Lust"],           L["Lust on this pack"], "gi:enrage", C.red },
        { "mana",   L["Need mana"],      L["Wait, need mana"], "gi:water-drop", C.blue },
        { "skip",   L["Skipping"],       L["Skipping with invis/shroud"], "gi:invisible", C.cyan },
        { "res",    L["Res me"],         L["Res me pls"], "gi:hospital-cross", C.green },
        { "chain",  L["Chain pull"],     L["Chain pulling"], "gi:crossed-chains", C.red },
        { "kicks",  L["Kick order"],     L["Kick order: {rt1} {rt2} {rt3}"], "gi:foot-plaster", C.purple },
    }),
})

BI.SNAPSHOTS[ID] = { content = "mythicPlus", group = "party", instanceGroup = false, difficulty = "keystone",
    keyLevel = 10, lockdown = { chat = true, challengeMode = true } }
