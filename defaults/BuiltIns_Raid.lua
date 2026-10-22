local _, NS = ...
-- defaults/BuiltIns_Raid.lua — the generic raid set (spec §12). Lead callouts use Smart lead
-- (raid warning for the leader or an assistant, raid chat otherwise).

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.raid"

local raid = BI.Callouts(ID, "raid", {
    { "lust",    L["Bloodlust"],     L["Bloodlust now"], "gi:enrage", C.red },
    { "brez",    L["Battle rez"],    L["Battle rez used on {target}"], "gi:angel-wings", C.green },
    { "soak",    L["Soak"],          L["Soak {rt3}"], "gi:convergence-target", C.orange },
    { "spread",  L["Spread"],        L["Spread for mechanic"], "gi:divergence", C.cyan },
    { "stack",   L["Stack"],         L["Stack on {rt1}"], "gi:meeple-group", C.white },
    { "stones",  L["Healthstones"],  L["Healthstones/cauldron down"], "gi:emerald", C.green },
})
local lead = BI.Callouts(ID, "smartLead", {
    { "pull10",  L["Pull in 10"],    L["Pull in 10"], "gi:stopwatch-lorc", C.gold },
    { "wipe",    L["Wipe"],          L["Wipe it, run back"], "gi:skull-crossed-bones", C.red },
})
for _, id in ipairs(lead) do raid[#raid + 1] = id end

BI.Group(ID, {
    name = L["Raid"], glyph = "gi:dragon-head-lorc", color = C.red,
    when = { content = { raid = true } }, callouts = raid,
})

BI.SNAPSHOTS[ID] = { content = "raid", group = "raid", instanceGroup = false, leader = true, lockdown = {} }
