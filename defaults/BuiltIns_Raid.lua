local _, NS = ...
-- defaults/BuiltIns_Raid.lua — the generic raid set (spec §12). The owner's own set (2026-11-14): every
-- call on Smart lead (raid warning for the leader or an assistant, raid chat otherwise) but Heal me,
-- which asks the raid. bi.raid.stones is retired, never reused.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.raid"

local function lead(rows) return BI.Callouts(ID, "smartLead", rows) end

local raid = lead({
    { "pull10",    L["Pull in 10"],  L["Pull in 10"], "gi:stopwatch-lorc", C.gold },
    { "lust",      L["Lust"],        L["Lust now!"], "gi:enrage", C.red },
    { "brez",      L["Battle rez"],  L["Battle rez used on {target}"], "gi:angel-wings", C.green },
})
local rest = {}
rest[#rest + 1] = BI.Callouts(ID, "raid", {
    { "healme",    L["Heal me"],     L["Need heals on me!"], "gi:heart-plus", C.green, { emote = "HEALME" } },
})
rest[#rest + 1] = lead({
    { "soak",      L["Soak"],        L["Soak!"], "gi:convergence-target", C.cyan },
    { "spread",    L["Spread"],      L["Spread!"], "gi:divergence", C.cyan },
    { "stack",     L["Stack"],       L["Stack!"], "gi:meeple-group", C.cyan },
    { "offensive", L["Offensive"],   L["Use offensive cooldowns!"], "gi:pointy-sword", C.amber },
    { "defensive", L["Defensive"],   L["Use personal defensives!"], "shield", C.amber },
    { "kick",      L["Kick Target"], L["Kick {skull} {target}"], "gi:high-kick", C.purple, { ping = "warning", marker = 8 } },
    { "wipe",      L["Wipe"],        L["Wipe it!"], "gi:skull-crossed-bones", C.red, { emote = "FLEE" } },
})
for _, ids in ipairs(rest) do
    for _, id in ipairs(ids) do raid[#raid + 1] = id end
end

BI.Group(ID, {
    name = L["Raid"], glyph = "gi:dragon-head-lorc", color = C.red,
    when = { content = { raid = true } }, callouts = raid,
})

BI.SNAPSHOTS[ID] = { content = "raid", group = "raid", instanceGroup = false, leader = true, lockdown = {} }
