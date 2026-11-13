local _, NS = ...
-- settings/Callouts.lua — the callout helpers the editors share (callouts-owned-by-groups spec): the
-- tokens a channel offers and one line of help for each, and what a callout sends here.
-- settings/CalloutPopup.lua draws both against its draft (the help is the tooltip on the Text
-- label's info glyph), and settings/Groups.lua's What it sends tab names each callout's line. There is
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
--- resolve to Raid (spec §8.1). A token this client does not offer (NS.GameIds.HIDDEN_TOKENS: {dungeon}
--- and {key} on WoW Forever, which has no Mythic+, QFE-F3 and QFE-C7) is left out; typed, it still
--- bakes as anywhere.
function C.TokensFor(channel)
    local out, hiddenTokens = {}, NS.GameIds.HIDDEN_TOKENS or {}
    for _, token in ipairs(C.TOKENS) do
        if not hiddenTokens[token] then out[#out + 1] = token end
    end
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

-- A channel kind's short name (the Groups rows' and the preview summary's), the no-Line kind as the
-- Channel list calls it (D10).
C.SHORT_CHANNEL = {
    smartGroup = L["Smart group"], smartLead = L["Smart lead"], party = L["Party"], raid = L["Raid"],
    instance = L["Instance"], raidWarning = L["Raid warning"], say = L["Say"], yell = L["Yell"],
    general = L["General"], emote = L["Emote"], gameEmote = L["None (no chat line)"],
}

-- The marker names by number (1 star to 8 skull), as the token help words them.
local MARKER_BY_N = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
local function markerName(n) return MARKER_NAMES[MARKER_BY_N[n] or ""] or tostring(n) end
local function pingName(v) return NS.Preview.PING_NAME[v] or tostring(v) end

-- One baked action, as the summary line says it: the Line quoted with its channel, an emote its
-- command, a ping and a marker by name.
local function short(a, callout)
    if a.kind == "line" then
        -- pipes doubled (Bake.Sanitize), so a stored "|" is drawn literal, never as a UI escape
        return L['"%s" in %s']:format(NS.Bake.Sanitize(callout.text) or "", C.SHORT_CHANNEL[a.concrete] or tostring(a.concrete))
    end
    if a.kind == "emote" then return a.line end
    if a.kind == "ping" then return L["ping %s"]:format(pingName(a.value)) end
    return L["mark %s"]:format(markerName(a.value))
end

-- A baked action's own row, as "Sends: /p Kick", "Emotes: /point", "Pings: Attack", "Marks: Skull".
local function head(a)
    if a.kind == "line" then return L["Sends: %s"]:format(a.line) end
    if a.kind == "emote" then return L["Emotes: %s"]:format(a.line) end
    if a.kind == "ping" then return L["Pings: %s"]:format(pingName(a.value)) end
    return L["Marks: %s"]:format(markerName(a.value))
end

local function why(reason)
    return NS.PadRender.REASON_TEXT[reason] or tostring(reason)
end

-- A Line that fit the line cap but not what the macro left it (D13): it carries that share, `budget`.
local function heldByMacro(a)
    return a.kind == "line" and a.reason == "tooLong" and a.budget ~= nil
end

-- The rows of one action: baked, its row, a voice emote's note and its bytes (an emote alone, none); solo with "self", that
-- it prints to you; skipped, why (alone, a callout's one action, in today's words) and an unknown
-- emote's token. Then its lock.
local function bakedRows(out, a, alone)
    out[#out + 1] = head(a)
    if a.kind == "emote" and NS.Emotes.IsVoice(a.value) then out[#out + 1] = L["A voice emote: it also plays its sound."] end
    -- an emote alone keeps today's rows: its command is its whole macro
    if a.kind ~= "emote" or not alone then out[#out + 1] = L["%d of 255 bytes"]:format(a.length) end
end

local function skippedRows(out, a, alone)
    -- a Line held by the macro's budget says so, and is measured against its share (CA-M2-R2)
    local held = heldByMacro(a)
    out[#out + 1] = (alone and L["Sends nothing here: %s"] or NS.PadRender.SKIPPED_TEXT[a.kind])
        :format(held and L["Too long to send with its other actions."] or why(a.reason))
    if a.reason == "unknownEmote" then out[#out + 1] = L["Emote token: %s"]:format(tostring(a.value)) end
    if held then
        out[#out + 1] = L["%d of %d bytes"]:format(a.length, a.budget)
    elseif a.length then
        out[#out + 1] = L["%d of 255 bytes"]:format(a.length)
    end
end

local function actionRows(out, a, alone)
    if a.line then
        bakedRows(out, a, alone)
    elseif a.reason == "solo" and a.selfPrint then
        out[#out + 1] = L["Solo: prints to you, sends nothing."]
    else
        skippedRows(out, a, alone)
    end
    if a.lock then out[#out + 1] = NS.PadRender.LOCK_TEXT[a.lock] or tostring(a.lock) end
end

-- The summary line of a callout with several actions: what bakes, joined; or why nothing does.
local function summary(info, reason, callout)
    local parts = {}
    for _, a in ipairs(info.baked) do parts[#parts + 1] = short(a, callout) end
    if #parts == 0 then return L["Sends nothing here: %s"]:format(why(reason)) end
    return table.concat(parts, ", ")
end

-- The Line's token notes, the target note for a ping or a marker, and the preview's situation.
local function notes(out, info)
    local target = false
    for _, a in ipairs(info.actions) do
        if a.unknown and #a.unknown > 0 then
            out[#out + 1] = L["Unknown tokens, sent as typed: %s"]:format(table.concat(a.unknown, ", "))
        end
        if a.missing and #a.missing > 0 then out[#out + 1] = L["Empty here: %s"]:format(table.concat(a.missing, ", ")) end
        target = target or ((a.kind == "ping" or a.kind == "marker") and a.line ~= nil)
    end
    if target then out[#out + 1] = L["Needs a target when pressed."] end
    local key = NS.Preview.PreviewAs()
    if key then out[#out + 1] = L["Previewing: %s"]:format(NS.Preview.Label(key)) end
end

--- What a callout sends here (spec §13.1, combined actions §7: the live preview of the baked macro,
--- under the current or previewed situation, with the padlock when locked). With several actions,
--- [1] sums them up on one line ('"Kick on me" in Party, /point, ping Attack, mark Skull'; the Groups
--- page's What it sends reads only [1]), then each action's rows, baked or skipped, and the macro's
--- bytes; with one, [1] is that action's own row. Then the token notes and the target note.
--- @return string[]
function C.PreviewLines(callout)
    local snap = Ed.Snapshot()
    local _, reason, info = NS.Bake.BakeActions(callout, snap,
        { soloFallback = NS.Setting("behavior.soloFallback"), ctx = NS.Surfaces.BakeContext(snap) })
    local out = {}
    local several = #info.actions > 1
    if several then out[1] = summary(info, reason, callout) end
    if #info.actions == 0 then out[1] = L["Sends nothing here: %s"]:format(why(reason)) end
    for _, a in ipairs(info.actions) do actionRows(out, a, not several) end
    if #info.baked > 1 then out[#out + 1] = L["Macro: %d of 255 bytes"]:format(info.total) end
    notes(out, info)
    return out
end
