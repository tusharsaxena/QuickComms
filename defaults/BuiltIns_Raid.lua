local _, NS = ...
-- defaults/BuiltIns_Raid.lua — the generic raid set (spec §12). Lead callouts use Smart lead
-- (raid warning for the leader or an assistant, raid chat otherwise).

local BI, L = NS.BuiltIns, NS.L
local ID = "bi.raid"

local raid = BI.Callouts(ID, "raid", {
    { "lust",    L["Bloodlust"],     L["Bloodlust now"], "Interface\\Icons\\Spell_Nature_Bloodlust" },
    { "brez",    L["Battle rez"],    L["Battle rez used on %t"] },
    { "soak",    L["Soak"],          L["Soak {rt3}"] },
    { "spread",  L["Spread"],        L["Spread for mechanic"] },
    { "stack",   L["Stack"],         L["Stack on {rt1}"] },
    { "stones",  L["Healthstones"],  L["Healthstones/cauldron down"] },
})
local lead = BI.Callouts(ID, "smartLead", {
    { "pull10",  L["Pull in 10"],    L["Pull in 10"] },
    { "wipe",    L["Wipe"],          L["Wipe it, run back"] },
})
for _, id in ipairs(lead) do raid[#raid + 1] = id end

BI.Group(ID, {
    name = L["Raid (generic)"], icon = "Interface\\Icons\\Achievement_Boss_Ragnaros",
    when = { content = { raid = true } }, callouts = raid,
})

BI.SNAPSHOTS[ID] = { content = "raid", group = "raid", instanceGroup = false, leader = true, lockdown = {} }
