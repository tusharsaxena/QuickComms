local _, NS = ...
-- modules/Channels.lua — channel kinds -> a concrete channel, its slash prefix, and the lock
-- matrix (spec §8.2, §8.4). PURE. Smart kinds resolve at bake time from the snapshot, because chat
-- slash commands take no macro conditionals (spec P3).

NS.Channels = NS.Channels or {}
local Ch = NS.Channels

Ch.KINDS = { "smartGroup", "smartLead", "party", "raid", "instance", "raidWarning", "say", "yell" }

local PREFIX = {
    say = "/s", yell = "/y", party = "/p", raid = "/raid", instance = "/i", raidWarning = "/rw",
}
local CHAT_TYPE = {
    say = "SAY", yell = "YELL", party = "PARTY", raid = "RAID", instance = "INSTANCE_CHAT",
    raidWarning = "RAID_WARNING",
}
local IS_KIND = {}
for _, k in ipairs(Ch.KINDS) do IS_KIND[k] = true end

function Ch.IsKind(kind) return IS_KIND[kind] == true end
function Ch.Prefix(concrete) return PREFIX[concrete] end
function Ch.ChatType(concrete) return CHAT_TYPE[concrete] end

local function smartGroup(s)
    if s.instanceGroup then return "instance" end
    if s.group == "raid" then return "raid" end
    if s.group == "party" then return "party" end
    return nil
end

local function smartLead(s)
    if s.group == "raid" and not s.instanceGroup and (s.leader or s.assist) then return "raidWarning" end
    if s.group == "party" and not s.instanceGroup then return "raidWarning" end
    return smartGroup(s)
end

--- Resolve a kind against a snapshot.
--- @param kind string one of Ch.KINDS
--- @param s table snapshot
--- @param soloFallback string|nil "none" | "self" | "say"
--- @return string|nil concrete, string|nil reason, boolean selfPrint
function Ch.Resolve(kind, s, soloFallback)
    s = type(s) == "table" and s or {}
    if PREFIX[kind] then return kind, nil, false end
    local concrete
    if kind == "smartGroup" then concrete = smartGroup(s)
    elseif kind == "smartLead" then concrete = smartLead(s)
    else return nil, "badChannel", false end
    if concrete then return concrete, nil, false end
    if soloFallback == "say" then return "say", nil, false end
    return nil, "solo", soloFallback == "self"
end

--- Why a concrete channel can't send right now, or nil (spec §8.4). The slot stays visible.
function Ch.LockState(concrete, s)
    s = type(s) == "table" and s or {}
    local lockdown = s.lockdown or {}
    if concrete == "raid" then
        if s.group ~= "raid" then return "notInRaid" end
    elseif concrete == "raidWarning" then
        if s.group == "raid" then
            if not (s.leader or s.assist) then return "notLeader" end
        elseif s.group ~= "party" then
            return "notInGroup"
        end
    elseif concrete == "party" then
        if s.group ~= "party" and s.group ~= "raid" then return "notInGroup" end
    elseif concrete == "instance" then
        if not s.instanceGroup then return "notInInstanceGroup" end
    elseif concrete == "say" or concrete == "yell" then
        if lockdown.encounter or lockdown.pvpMatch then return "lockdown" end
    end
    return nil
end
