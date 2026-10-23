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
    callouts = BI.Callouts(ID, "smartGroup", {
        { "hello",  L["Hello"],        L["Hello!"],              "ph:hand-waving",   C.sky },
        { "stone",  L["At Stone"],     L["At stone, WM off."],   "gi:tombstone-sbed", C.purple },
        { "summon", L["Summon"],       L["Summon please!"],      "gi:magic-portal",  C.purple },
        { "buffs",  L["Buffs please"], L["Buffs please!"],       "gi:muscle-up",     C.purple },
        { "hs",     L["Healthstone"],  L["Healthstone please!"], "gi:health-potion", C.purple },
        { "tyff",   L["tyff"],         L["tyff"],                "gi:hot-meal",      C.purple },
        { "brb",    L["brb"],          L["brb"],                 "gi:coffee-cup",    C.crimson },
        { "ready",  L["Ready"],        L["Ready"],               "gi:check-mark",    C.green },
        { "glhf",   L["GLHF"],         L["GLHF!"],               "ph:clover",        C.green },
        { "ggty",   L["ggty"],         L["ggty"],                "gi:shaking-hands", C.gold },
        { "ggnt",   L["ggnt"],         L["ggnt"],                "gi:thumb-up",      C.gold },
    }),
})

BI.SNAPSHOTS[ID] = { content = "openWorld", group = "party", instanceGroup = false, lockdown = {} }
