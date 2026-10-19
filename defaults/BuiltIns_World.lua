local _, NS = ...
-- defaults/BuiltIns_World.lua — the solo open-world set (groups polish, 2026-10-19): out in the world
-- and in no group, where only the open channels reach anyone, so every callout says it out loud. A
-- shipped id is stable once shipped.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.world"

BI.Group(ID, {
    name = L["World (solo)"], glyph = "gi:world", color = C.green,
    when = { content = { openWorld = true }, group = { solo = true } },
    callouts = BI.Callouts(ID, "say", {
        { "rare",   L["Rare spotted"],  L["Rare spotted here: %t"], "gi:spyglass", C.gold },
        { "elite",  L["Elite help"],    L["Can anyone help with this elite? %t"], "gi:ogre", C.red },
        { "quest",  L["Group quest"],   L["Anyone want to group up for this quest?"], "gi:scroll-unfurled", C.gold },
        { "boss",   L["World boss"],    L["World boss up here: %t"], "gi:crowned-skull", C.red },
        { "event",  L["Event here"],    L["World event starting here, come join"], "gi:ringing-bell", C.orange },
        { "invite", L["Invite me"],     L["Invite please"], "gi:envelope", C.blue },
        { "thanks", L["Thanks"],        L["Thanks for the help!"], "gi:shaking-hands", C.green },
        { "afk",    L["AFK"],           L["AFK a moment"], "gi:coffee-cup", C.white },
        { "back",   L["Back"],          L["Back"], "gi:return-arrow", C.cyan },
    }),
})

BI.SNAPSHOTS[ID] = { content = "openWorld", group = "solo", instanceGroup = false, lockdown = {} }
