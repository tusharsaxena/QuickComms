local _, NS = ...
-- defaults/BuiltIns_MythicPlus.lua — the generic M+ set (spec §12, brainstorm §8).

local BI, L = NS.BuiltIns, NS.L
local ID = "bi.mplus"

BI.Group(ID, {
    name = L["M+ (generic)"], icon = "Interface\\Icons\\INV_Relics_Hourglass",
    when = { content = { mythicPlus = true } },
    callouts = BI.Callouts(ID, "smartGroup", {
        { "pull",   L["Pulling"],        L["Pulling next pack"] },
        { "lust",   L["Lust"],           L["Lust on this pack {rt8}"], "Interface\\Icons\\Spell_Nature_Bloodlust" },
        { "mana",   L["Need mana"],      L["Wait, need mana"] },
        { "kicks",  L["Kick order"],     L["Kick order: {rt1} {rt2} {rt3}"] },
        { "skip",   L["Skipping"],       L["Skipping with invis/shroud"] },
        { "res",    L["Res me"],         L["Res me pls"], "Interface\\Icons\\Spell_Nature_Reincarnation" },
        { "chain",  L["Chain pull"],     L["Key time is tight, chain pull"] },
        { "gg",     L["GG"],             L["gg, thanks all"] },
    }),
})

BI.SNAPSHOTS[ID] = { content = "mythicPlus", group = "party", instanceGroup = false, difficulty = "keystone",
    keyLevel = 10, lockdown = { chat = true, challengeMode = true } }
