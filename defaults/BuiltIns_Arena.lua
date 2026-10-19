local _, NS = ...
-- defaults/BuiltIns_Arena.lua — the generic arena set (spec §12): party chat.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.arena"

BI.Group(ID, {
    name = L["Arena (generic)"], icon = "Interface\\Icons\\Achievement_Arena_2v2_7",
    when = { content = { arena = true } },
    callouts = BI.Callouts(ID, "party", {
        { "trinket", L["Trinket used"],  L["Trinket used"], "gi:medal", C.gold },
        { "cc",      L["CC"],            L["CC {rt1} now"], "gi:sheep", C.purple },
        { "swap",    L["Swap"],          L["Swap to %t"], "gi:cycle" },
        { "incc",    L["I'm in CC"],     L["I'm in CC"], "gi:manacles", C.purple },
        { "kill",    L["Kill"],          L["Going for kill on %t"], "gi:bloody-sword", C.red },
        { "drink",   L["Drink"],         L["Drink, reset"], "gi:water-flask", C.blue },
    }),
})

BI.SNAPSHOTS[ID] = { content = "arena", group = "party", instanceGroup = false, lockdown = { pvpMatch = true } }
