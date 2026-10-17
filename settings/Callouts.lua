local _, NS = ...
-- settings/Callouts.lua — the callout helpers the editors share (callouts-owned-by-groups spec): the
-- token picker's list for a channel, and what a callout sends here. settings/CalloutPopup.lua draws
-- both against its draft, and settings/Groups.lua's Preview tab names each callout's line. There is
-- no Callouts page: a callout is made, edited and removed on its group's Callouts tab.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

Settings.Callouts = Settings.Callouts or {}
local C = Settings.Callouts

-- The picker's tokens (spec §8.1). The eight raid markers are offered by name ({star} to {skull});
-- a typed {rt1} to {rt8} works the same. {spell:ID} needs an id, so it is typed, never picked.
C.TOKENS = { "{target}", "{focus}", "{skull}", "{cross}", "{square}", "{moon}", "{triangle}", "{diamond}",
    "{circle}", "{star}", "{me}", "{spec}", "{role}", "{key}", "{dungeon}" }

-- The channels that can resolve to Raid (spec §8.2), where {group1} to {group8} expand.
local RAID_CAPABLE = { raid = true, raidWarning = true, smartGroup = true, smartLead = true }

--- The tokens the picker offers for a channel: C.TOKENS, plus {group1} to {group8} only when the
--- channel can resolve to Raid (spec §8.1).
function C.TokensFor(channel)
    local out = {}
    for i, token in ipairs(C.TOKENS) do out[i] = token end
    if RAID_CAPABLE[channel] then
        for n = 1, 8 do out[#out + 1] = "{group" .. n .. "}" end
    end
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
