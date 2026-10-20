local _, NS = ...
-- defaults/BuiltIns_Group.lua — the In Group set (bg buttons, 2026-10-20): the short lines a player
-- types in any party, raid or instance group, greetings and thanks, asks and good games, in the short
-- forms a group reads at a glance. Smart group sends each to the group it is in. Declared after the
-- battleground sets (the TOC loads this file last of the data), so in a battleground the map's own set
-- is still the first active group and the dial opens on its nodes (D9). A shipped id is stable once
-- shipped.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.group"

BI.Group(ID, {
    name = L["In Group"], glyph = "ph:users-three", color = C.cyan,
    when = { group = { party = true, raid = true, instance = true } },
    -- Skip on the dial in content: in a dungeon, raid, arena or battleground the dial opens on that
    -- content's set, not on a ring of groups; In Group still shows on the pad (modules/Surfaces.lua).
    dialYield = true,
    callouts = BI.Callouts(ID, "smartGroup", {
        { "hello",  L["Hello"],        L["Hello"],               "ph:hand-waving",   C.gold },
        { "tyff",   L["tyff"],         L["tyff"],                "gi:hot-meal",      C.green },
        { "buffs",  L["Buffs please"], L["Buffs please!"],       "gi:muscle-up",     C.purple },
        { "hs",     L["Healthstone"],  L["Healthstone please!"], "gi:health-potion", C.green },
        { "glhf",   L["GLHF"],         L["GLHF"],                "ph:clover",        C.green },
        { "ggty",   L["ggty"],         L["ggty"],                "gi:shaking-hands", C.gold },
        { "ggnt",   L["ggnt"],         L["ggnt"],                "gi:thumb-up",      C.cyan },
        { "ty",     L["ty"],           L["ty"],                  "ph:handshake",     C.green },
        { "brb",    L["brb"],          L["brb"],                 "gi:coffee-cup",    C.white },
        { "ready",  L["Ready"],        L["Ready"],               "gi:check-mark",    C.green },
        { "drink",  L["Drink"],        L["Drinking"],            "gi:water-flask",   C.blue },
        { "summon", L["Summon"],       L["Summon please!"],      "gi:magic-portal",  C.purple },
    }),
})

BI.SNAPSHOTS[ID] = { content = "openWorld", group = "party", instanceGroup = false, lockdown = {} }
