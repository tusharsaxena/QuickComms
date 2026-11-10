local _, NS = ...
-- modules/Situation.lua — the situation snapshot (spec §6). The classifier, Classify(inputs) ->
-- snapshot, is PURE: a plain table in, a plain table out, never throws. ReadInputs is the edge:
-- the only place this module reads the client, all through NS.Compat. Refresh coalesces event
-- bursts into one read 0.1 s later and sends SITUATION_CHANGED (snapshot, previous) only when the
-- signature moves. inCombat and lockdown ride along for display and never move the signature: they
-- come from Restrictions (spec §17), stamped on every refresh and refreshed in place, without a
-- SITUATION_CHANGED, whenever RESTRICTION_CHANGED says the restriction or combat state moved.

NS.Situation = NS.Situation or {}
local Sit = NS.Situation
local State = NS.State
local Perf = NS.Perf
local L = NS.L

local TAG = "Situation"
local COALESCE = 0.1

-- difficultyID -> the When editor's difficulty value (spec §5.3). Unknown ids read as nil.
local DIFFICULTY = {
    [1] = "normal", [2] = "heroic", [23] = "mythic", [8] = "keystone", [205] = "follower",
    [14] = "normal", [15] = "heroic", [16] = "mythic", [17] = "lfr", [7] = "lfr", [220] = "story",
}
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
        -- Where the role came from (LibKa0s Role.Resolve's source and detail): shown by /qc why and
        -- the diagnostics, never part of the signature.
        roleSource     = i.roleSource,
        roleDetail     = i.roleDetail,
        character      = i.character,
        general        = i.general == true,
        inCombat       = i.inCombat == true,
        lockdown       = {},
    }
end

local SIGNATURE_FIELDS = { "content", "instanceID", "difficulty", "keyLevel", "challengeMapID", "group",
    "instanceGroup", "leader", "assist", "classFile", "specID", "role", "character", "general" }

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
    local classFile, specID, role, character, roleSource, roleDetail = C.PlayerIdentity()
    return {
        inInstance = inInstance, instanceType = instanceType, difficultyID = difficultyID,
        instanceID = instanceID, keystoneActive = keystoneActive, keyLevel = keyLevel,
        challengeMapID = challengeMapID, inGroup = inGroup, inRaid = inRaid,
        inInstanceGroup = inInstanceGroup, isLeader = isLeader, isAssist = isAssist,
        classFile = classFile, specID = specID, role = role, character = character,
        roleSource = roleSource, roleDetail = roleDetail,
        inHousing = C.InHousing(), inCombat = C.InCombat(), general = C.GeneralJoined(),
    }
end

-- Stamps Restrictions' view on a snapshot, in place: the lockdown reasons and the combat flag
-- (the PLAYER_REGEN edge when one has been seen, which can lead InCombatLockdown()).
local function withRestrictions(s)
    local R = NS.Restrictions
    if R and R.ActiveSet then
        local set = R.ActiveSet()
        s.lockdown = {
            chat = set.chat == true or set.chatLockdown == true, encounter = set.encounter == true,
            challengeMode = set.challengeMode == true, pvpMatch = set.pvpMatch == true,
        }
        s.inCombat = R.InCombat() == true
    end
    return s
end

-- Read, classify and sign; answers whether the signature moved, with the new and the previous
-- snapshot. Publishes nothing: RefreshNow sends SITUATION_CHANGED after its bracket closes.
local function refresh(reason)
    State.situationPending = nil
    local snap = withRestrictions(Sit.Classify(Sit.ReadInputs()))
    local sig = Sit.Signature(snap)
    local prev = State.situation
    State.situation = snap
    if sig == State.situationSignature then return false end
    State.situationSignature = sig
    NS.Debug(TAG, "%s -> %s/%s (%s)", prev and prev.content or "none", snap.content, snap.group, tostring(reason))
    return true, snap, prev
end

--- Read, classify, and publish when the signature moved. The read, classify and signature are
--- bracketed as situationRefresh (spec §16); the publish is outside the bracket, because out of
--- combat it rebuilds every surface at once, and that rebuild is measured by its own buckets
--- (bakeSurface, resolverResolve, padLayout), which also run outside a refresh (performance-§3).
--- @param reason string|nil for the debug line
--- @return boolean changed
function Sit.RefreshNow(reason)
    local t0 = Perf.on and debugprofilestop()
    local changed, snap, prev = refresh(reason)
    if t0 then Perf.Note("situationRefresh", debugprofilestop() - t0) end
    if changed then NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED, snap, prev) end
    return changed
end

--- Coalesced refresh: a burst of events within 0.1 s gives one read.
function Sit.Refresh(reason)
    if State.situationPending then return end
    State.situationPending = true
    State.situationTimer = NS.addon:ScheduleTimer(function()
        State.situationTimer = nil
        Sit.RefreshNow(reason)
    end, COALESCE)
end

local ROLE_NAME = { TANK = L["Tank"], HEALER = L["Healer"], DAMAGER = L["Damage"] }
local ROLE_FROM = {
    override = L["%s, your choice on the General page"],
    assigned = L["%s, the role your group gave you"],
    talents  = L["%s, from your talents"],
    spec     = L["%s, from your specialization"],
    saved    = L["%s, the last role read on this character"],
}
local ROLE_FROM_DETAIL = {
    talents = L["%s, from your talents: %s"],
    spec    = L["%s, from your specialization: %s"],
}

--- A role and where it came from, as one phrase ("Tank, from your talents: Protection"); "not known
--- yet" for no role. The source and detail are Compat.PlayerRole's.
--- @return string
function Sit.DescribeRole(role, source, detail)
    local name = ROLE_NAME[role]
    if not name then return L["not known yet"] end
    if detail and ROLE_FROM_DETAIL[source] then return ROLE_FROM_DETAIL[source]:format(name, detail) end
    if ROLE_FROM[source] then return ROLE_FROM[source]:format(name) end
    return name
end

--- The current snapshot, classified live (without a message) before the first refresh.
function Sit.Current()
    return State.situation or withRestrictions(Sit.Classify(Sit.ReadInputs()))
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_DIFFICULTY_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ROLES_ASSIGNED",
    -- Talents committed (QFE-F4): on WoW Forever the role Automatic reads is the talent tree with the
    -- most points (LibKa0s Role), and a respec there changes no specialization. Both clients have it.
    "TRAIT_CONFIG_UPDATED",
    -- A talent-group swap (QFE-REV): Forever's dual spec keeps the one spec, so the swap moves no
    -- specialization and commits no config; Blizzard's own talent frame listens for these. Both clients.
    "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_TALENT_UPDATE",
    -- General joined, left or moved off channel 1 (QF-04): the notice also covers the automatic joins after login and
    -- the zone's channel swap, should CHANNEL_UI_UPDATE not fire for them. A notice for any other
    -- channel leaves the signature, so it rebuilds nothing.
    "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE",
}
for _, event in ipairs(EVENTS) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSituationEvent" }
end

-- Stood down it returns at once: its events are unregistered, so only a dispatch the latch did not
-- see reaches it, and it must not arm the coalesce timer then (slash-commands-§7, step 6).
function NS.addon.OnSituationEvent(_, event)
    if NS.IsStoodDown() then return end
    Sit.Refresh(event)
    -- A key's end can lift a chat lockdown with no event of its own; the event is this row's (one
    -- handler per event per object), so it hands the lift to Restrictions rather than registering twice.
    if event == "CHALLENGE_MODE_COMPLETED" then NS.Restrictions.RefreshAfterLift(event) end
end

-- RESTRICTION_CHANGED: refresh the current snapshot's lockdown and combat in place. Never moves
-- the signature and never sends SITUATION_CHANGED. Before the first refresh there is nothing to
-- update: Current() classifies live then.
--- Refresh the current snapshot's lockdown and combat in place; never moves the signature. A
--- module that reads the lockdown on RESTRICTION_CHANGED calls this first, so the order in which
--- receivers hear the message never matters.
function Sit.Restamp()
    local s = State.situation
    if s then withRestrictions(s) end
end

local function onRestrictionChanged()
    Sit.Restamp()
end

-- Its own target (core/Bus.lua). On the tracked bus the stand-down and stand-up take it down and
-- replay it; on the degraded bus this module does both itself.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if State.situationTimer then NS.addon:CancelTimer(State.situationTimer) end
    State.situationTimer = nil
    State.situation, State.situationSignature, State.situationPending = nil, nil, nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    Sit.RefreshNow("standUp")
end
