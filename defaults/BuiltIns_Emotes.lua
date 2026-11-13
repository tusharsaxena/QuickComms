local _, NS = ...
-- defaults/BuiltIns_Emotes.lua — the Emotes set (QFE-E3, QuickComms#15, design 5.3): the game's own
-- emotes, out in the open world in any group size. Each callout is a game emote (`emote`, channel
-- gameEmote): its line is the client's own command for the token, so it plays the voice line or the
-- animation as typing it would, and acts on your target. One list for both clients (C5): every token is
-- in Blizzard's ChatEmoteConstants.lua on Retail and on WoW Forever alike, and tests/test_builtins.lua
-- pins that against tests/emote_tokens.lua. The voice emotes come first (TextEmoteSpeechList), then the
-- social ones. Placed after the World (Solo) set (the TOC loads this file after it). A shipped id is
-- stable once shipped.

local BI, L = NS.BuiltIns, NS.L
local C = BI.COLOR
local ID = "bi.emotes"

-- Rows of { short, name, token, glyph, color }: each a game emote callout with no text, its token
-- as BI.Callout's `extra`.
local function emoteCallouts(rows)
    local ids = {}
    for n, r in ipairs(rows) do
        ids[n] = BI.Callout(ID, r[1], r[2], "", "gameEmote", r[4], r[5], { emote = r[3] })
    end
    return ids
end

BI.Group(ID, {
    name = L["Emotes"], glyph = "ph:smiley", color = C.yellow,
    when = { content = { openWorld = true } },
    callouts = emoteCallouts({
        -- voice
        { "incoming",  L["Incoming"],      "INCOMING",       "gi:siren",               C.orange },
        { "charge",    L["Charge"],        "CHARGE",         "gi:charging-bull",       C.red },
        { "attack",    L["Attack target"], "ATTACKMYTARGET", "gi:on-target",           C.red },
        { "openfire",  L["Open fire"],     "OPENFIRE",       "gi:flame",               C.orange },
        { "oom",       L["Out of mana"],   "OOM",            "gi:water-drop",          C.blue },
        { "healme",    L["Heal me"],       "HEALME",         "gi:heart-plus",          C.green },
        { "helpme",    L["Help me"],       "HELPME",         "ph:lifebuoy",            C.orange },
        { "flee",      L["Flee"],          "FLEE",           "ph:person-simple-run",   C.cyan },
        { "wait",      L["Wait"],          "WAIT",           "ph:hourglass",           C.cyan },
        { "follow",    L["Follow me"],     "FOLLOW",         "ph:footprints",          C.cyan },
        -- social
        { "wave",      L["Wave"],          "WAVE",           "ph:hand-waving",         C.sky },
        { "hello",     L["Hello"],         "HELLO",          "ph:hand-palm",           C.sky },
        { "thank",     L["Thank you"],     "THANK",          "ph:hand-heart",          C.green },
        { "cheer",     L["Cheer"],         "CHEER",          "ph:confetti",            C.gold },
        { "bow",       L["Bow"],           "BOW",            "gi:kneeling",            C.purple },
        { "point",     L["Point"],         "POINT",          "ph:hand-pointing",       C.white },
        { "dance",     L["Dance"],         "DANCE",          "ph:music-notes",         C.purple },
        { "ready",     L["Ready"],         "READY",          "gi:check-mark",          C.green },
        { "laugh",     L["Laugh"],         "LAUGH",          "ph:smiley-wink",         C.yellow },
        { "bye",       L["Bye"],           "BYE",            "ph:sign-out",            C.sky },
    }),
})

-- The bake audit's snapshot: solo in the open world, the least a game emote needs.
BI.SNAPSHOTS[ID] = { content = "openWorld", group = "solo", instanceGroup = false, lockdown = {} }
