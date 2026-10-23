local _, NS = ...
-- settings/Callouts.lua — the callout helpers the editors share (callouts-owned-by-groups spec): the
-- tokens a channel offers and one line of help for each, and what a callout sends here.
-- settings/CalloutPopup.lua draws both against its draft (the help is the tooltip on the Text
-- label's info glyph), and settings/Groups.lua's Preview tab names each callout's line. There is
-- no Callouts page: a callout is made, edited and removed on its group's Callouts tab.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

Settings.Callouts = Settings.Callouts or {}
local C = Settings.Callouts

-- The tokens a callout's text offers (spec §8.1). The eight raid markers are named ({star} to
-- {skull}); a typed {rt1} to {rt8} works the same. {spell:ID} needs an id, so it is not in the
-- list: the help names it after the list.
C.TOKENS = { "{target}", "{focus}", "{skull}", "{cross}", "{square}", "{moon}", "{triangle}", "{diamond}",
    "{circle}", "{star}", "{me}", "{spec}", "{role}", "{key}", "{dungeon}",
    "{coordinates}" }

-- The channels that can resolve to Raid (spec §8.2), where {group1} to {group8} expand.
local RAID_CAPABLE = { raid = true, raidWarning = true, smartGroup = true, smartLead = true }

--- The tokens offered for a channel: C.TOKENS, plus {group1} to {group8} only when the channel can
--- resolve to Raid (spec §8.1).
function C.TokensFor(channel)
    local out = {}
    for i, token in ipairs(C.TOKENS) do out[i] = token end
    if RAID_CAPABLE[channel] then
        for n = 1, 8 do out[#out + 1] = "{group" .. n .. "}" end
    end
    return out
end

-- What each token is filled in with (spec §8.1; modules/Tokens.lua expands them). The markers are
-- worded from their names, so they have no entry here.
local MARKER_NAMES = { skull = L["Skull"], cross = L["Cross"], square = L["Square"], moon = L["Moon"],
    triangle = L["Triangle"], diamond = L["Diamond"], circle = L["Circle"], star = L["Star"] }
local TOKEN_HELP = {
    ["{target}"]  = L["Your target's name, filled in by the game as it sends."],
    ["{focus}"]   = L["Your focus's name, filled in by the game as it sends."],
    ["{me}"]      = L["Your character's name."],
    ["{spec}"]    = L["Your specialization."],
    ["{role}"]    = L["Your role: tank, healer or damage."],
    ["{key}"]     = L["The keystone level. Empty outside Mythic+."],
    ["{dungeon}"] = L["The keystone dungeon's name. Empty outside Mythic+."],
    ["{coordinates}"] = L["Your map position, as 45.2, 61.8. Empty where the map does not show you (dungeons, raids)."],
}
local GROUP_TOKENS = "{group1} … {group8}"
local SPELL_TOKEN = "{spell:ID}"

--- One line of help per token offered for `channel`, as { token, text } in C.TokensFor's order:
--- {group1} to {group8} folded into one line (only where the channel can resolve to Raid), then
--- {spell:ID}, which is typed with its id.
--- @return table[]
function C.TokenHelp(channel)
    local out, grouped = {}, false
    for _, token in ipairs(C.TokensFor(channel)) do
        local marker = MARKER_NAMES[token:match("^{(%a+)}$") or ""]
        if token:find("^{group%d}$") then
            if not grouped then
                grouped = true
                out[#out + 1] = { GROUP_TOKENS, L["That raid group, filled in by the game. Raid only."] }
            end
        elseif marker then
            out[#out + 1] = { token, L["The %s raid marker."]:format(marker) }
        else
            out[#out + 1] = { token, TOKEN_HELP[token] or "" }
        end
    end
    out[#out + 1] = { SPELL_TOKEN, L["A link to the spell with that id."] }
    return out
end

--- What a callout sends here (spec §13.1: the live preview of the baked line, under the current or
--- previewed situation, with the padlock when locked): the line and its bytes, or why it sends
--- nothing; then any lock, the unknown tokens and the tokens empty here.
--- @return string[]
function C.PreviewLines(callout)
    local snap = Ed.Snapshot()
    local line, reason, info = NS.Bake.Bake(callout, snap,
        { soloFallback = NS.Setting("behavior.soloFallback"), ctx = NS.Surfaces.BakeContext(snap) })
    local R = NS.PadRender
    local out = {}
    if line then
        out[1] = L["Sends: %s"]:format(line)
        out[2] = L["%d of 255 bytes"]:format(info.length)
    elseif reason == "solo" and info.selfPrint then
        out[1] = L["Solo: prints to you, sends nothing."]
    else
        out[1] = L["Sends nothing here: %s"]:format(R.REASON_TEXT[reason] or tostring(reason))
        if info.length then out[2] = L["%d of 255 bytes"]:format(info.length) end
    end
    if info.lock then out[#out + 1] = R.LOCK_TEXT[info.lock] or tostring(info.lock) end
    if info.unknown and #info.unknown > 0 then
        out[#out + 1] = L["Unknown tokens, sent as typed: %s"]:format(table.concat(info.unknown, ", "))
    end
    if info.missing and #info.missing > 0 then
        out[#out + 1] = L["Empty here: %s"]:format(table.concat(info.missing, ", "))
    end
    local key = NS.Preview.PreviewAs()
    if key then out[#out + 1] = L["Previewing: %s"]:format(NS.Preview.Label(key)) end
    return out
end
