local _, NS = ...
-- modules/Situation.lua — the situation snapshot (spec §6). The classifier, Classify(inputs) ->
-- snapshot, is PURE: a plain table in, a plain table out, never throws. ReadInputs is the edge:
-- the only place this module reads the client, all through NS.Compat. Refresh coalesces event
-- bursts into one read 0.1 s later and sends SITUATION_CHANGED (snapshot, previous) only when the
-- signature moves. inCombat and lockdown ride along for display and never move the signature.

NS.Situation = NS.Situation or {}
local Sit = NS.Situation
local State = NS.State

local TAG = "Situation"
local COALESCE = 0.1

-- difficultyID -> the When editor's difficulty value (spec §5.3). Unknown ids read as nil.
local DIFFICULTY = {
    [1] = "normal", [2] = "heroic", [23] = "mythic", [8] = "keystone", [205] = "follower",
    [14] = "normal", [15] = "heroic", [16] = "mythic", [17] = "lfr", [7] = "lfr", [220] = "story",
}
Sit.DIFFICULTY = DIFFICULTY
local KEYSTONE, DELVE = 8, 208

local function content(i)
    local t = i.instanceType
    if t == "arena" then return "arena" end
    if t == "pvp" then return "battleground" end
    if i.keystoneActive or i.difficultyID == KEYSTONE then return "mythicPlus" end
    if i.inHousing then return "housing" end
    if not i.inInstance then return "openWorld" end
    if i.difficultyID == DELVE then return "delve" end
    if t == "party" then return "dungeon" end
    if t == "raid" then return "raid" end
    if t == "scenario" then return "scenario" end
    return "openWorld"
end

local function group(i)
    if i.inRaid then return "raid" end
    if i.inGroup then return "party" end
    return "solo"
end

--- The snapshot for a set of inputs (spec §6). Pure.
--- @param i table|any inputs from ReadInputs (or a test)
--- @return table snapshot
function Sit.Classify(i)
    if type(i) ~= "table" then i = {} end
    local c = content(i)
    local mplus = c == "mythicPlus"
    return {
        content        = c,
        instanceID     = i.instanceID,
        difficultyID   = i.difficultyID,
        difficulty     = DIFFICULTY[i.difficultyID],
        keyLevel       = mplus and i.keyLevel or nil,
        challengeMapID = mplus and i.challengeMapID or nil,
        group          = group(i),
        instanceGroup  = i.inInstanceGroup == true,
        leader         = i.isLeader == true,
        assist         = i.isAssist == true,
        classFile      = i.classFile,
        specID         = i.specID,
        role           = i.role,
        character      = i.character,
        inCombat       = i.inCombat == true,
        lockdown       = {},
    }
end

local SIGNATURE_FIELDS = { "content", "instanceID", "difficulty", "keyLevel", "challengeMapID", "group",
    "instanceGroup", "leader", "assist", "classFile", "specID", "role", "character" }

--- The fields that decide which groups are active, joined. Combat and lockdown are left out.
--- @param s table snapshot
--- @return string
function Sit.Signature(s)
    local parts = {}
    for n, field in ipairs(SIGNATURE_FIELDS) do parts[n] = tostring(s[field]) end
    return table.concat(parts, "|")
end

--- The classifier inputs, read now. Read-only; safe in combat and stood down.
--- @return table inputs
function Sit.ReadInputs()
    local C = NS.Compat
    local inInstance, instanceType, difficultyID, instanceID = C.InstanceInfo()
    local keystoneActive, keyLevel, challengeMapID = C.ActiveKeystone()
    local inGroup, inRaid, inInstanceGroup = C.GroupShape()
    local isLeader, isAssist = C.Leadership()
    local classFile, specID, role, character = C.PlayerIdentity()
    return {
        inInstance = inInstance, instanceType = instanceType, difficultyID = difficultyID,
        instanceID = instanceID, keystoneActive = keystoneActive, keyLevel = keyLevel,
        challengeMapID = challengeMapID, inGroup = inGroup, inRaid = inRaid,
        inInstanceGroup = inInstanceGroup, isLeader = isLeader, isAssist = isAssist,
        classFile = classFile, specID = specID, role = role, character = character,
        inHousing = C.InHousing(), inCombat = C.InCombat(),
    }
end

local function withLockdown(s)
    local R = NS.Restrictions
    if R and R.ActiveSet then
        local set = R.ActiveSet()
        s.lockdown = {
            chat = set.chat == true or set.chatLockdown == true, encounter = set.encounter == true,
            challengeMode = set.challengeMode == true, pvpMatch = set.pvpMatch == true,
        }
    end
    return s
end

--- Read, classify, and publish when the signature moved.
--- @param reason string|nil for the debug line
--- @return boolean changed
function Sit.RefreshNow(reason)
    State.situationPending = nil
    local snap = withLockdown(Sit.Classify(Sit.ReadInputs()))
    local sig = Sit.Signature(snap)
    local prev = State.situation
    State.situation = snap
    if sig == State.situationSignature then return false end
    State.situationSignature = sig
    NS.Debug(TAG, "%s -> %s/%s (%s)", prev and prev.content or "none", snap.content, snap.group, tostring(reason))
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED, snap, prev)
    return true
end

--- Coalesced refresh: a burst of events within 0.1 s gives one read.
function Sit.Refresh(reason)
    if State.situationPending then return end
    State.situationPending = true
    NS.addon:ScheduleTimer(function() Sit.RefreshNow(reason) end, COALESCE)
end

--- The current snapshot, classified live (without a message) before the first refresh.
function Sit.Current()
    return State.situation or withLockdown(Sit.Classify(Sit.ReadInputs()))
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_DIFFICULTY_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ROLES_ASSIGNED",
}
for _, event in ipairs(EVENTS) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSituationEvent" }
end

function NS.addon.OnSituationEvent(_, event)
    Sit.Refresh(event)
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.situation, State.situationSignature, State.situationPending = nil, nil, nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function() Sit.RefreshNow("standUp") end
