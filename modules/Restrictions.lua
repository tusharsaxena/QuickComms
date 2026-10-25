local _, NS = ...
-- modules/Restrictions.lua — what Blizzard's 12.0 addon restrictions allow right now (spec §8.4,
-- the lock matrix, and §9, the send engine): whether a chat message may be sent, whether the player
-- is fighting, and the reason the surfaces' lockdown chip names.
-- Kept in-addon: LibKa0s#49 rejected under library-stack-§7; re-check trigger in docs/ARCHITECTURE.md -> Documented deviations.
--
-- THREE SOURCES, all through core/Compat.lua:
--   * ADDON_RESTRICTION_STATE_CHANGED (type, state): the type's state as the event said it, kept
--     as a HINT per type, because the event fires while the restriction is still Activating and
--     the client's own answer may not say so yet. The state arrives as a number (the
--     AddOnRestrictionState) or a boolean; a secret one reads as active.
--   * C_ChatInfo.InChatMessagingLockdown(), polled on every read (a secret answer is locked).
--   * Combat: the PLAYER_REGEN edge when one has been seen (this module's own PLAYER_REGEN rows
--     hand it over, because the flag can lag the edge), else InCombatLockdown(); the Combat type
--     counts too.
--
-- A type is active when its hint OR the client says so: a restriction is never assumed lifted
-- until both agree. The answers are read live on every call, so a caller is never behind the
-- client. RESTRICTION_CHANGED (reason, canSendChat) is sent whenever the set of blocking reasons
-- or the combat flag (InCombat: the edge, else the client's flag) moves, from the event, both
-- combat edges and the stand-up; Situation merges it into the snapshot. The flag is in the
-- signature on its own because the Combat type can put `combat` in the set before the edge does,
-- and the edge must still announce then. A lockdown that lifts with no event of its
-- own is picked up by the next read, and by RefreshAfterLift, which re-reads on ENCOUNTER_END
-- (this module's row) and CHALLENGE_MODE_COMPLETED (Situation's row, forwarded here), now and once
-- more a moment later, because the client's flag can clear after the event that ends it.
--
-- Reasons, in the chip's priority order: encounter, challengeMode, pvpMatch, chat (the Chat
-- type), chatLockdown, combat. The Map type is tracked and reported but blocks nothing: it goes
-- active on entering a dungeon and stays so (DropWatcher, docs/midnight-quirks.md, the "restriction
-- event's payload" row). A type the client adds later is reported under its own enum name and
-- blocks nothing until it is classified here.

NS.Restrictions = NS.Restrictions or {}
local R = NS.Restrictions
local State = NS.State

local TAG = "RES"

-- Enum.AddOnRestrictionType member name -> reason key.
local REASON_BY_NAME = {
    Combat = "combat", Encounter = "encounter", ChallengeMode = "challengeMode",
    PvPMatch = "pvpMatch", Map = "map", Chat = "chat",
}

-- The reasons that stop a chat message, in priority order.
local CHAT_BLOCKERS = { "encounter", "challengeMode", "pvpMatch", "chat", "chatLockdown" }

-- Every reason the snapshot may answer, in priority order.
local PRIORITY = { "encounter", "challengeMode", "pvpMatch", "chat", "chatLockdown", "combat" }

-- ── reading the client ──────────────────────────────────────────────────────────────────────

local function hints()
    State.restrictionHints = State.restrictionHints or {}
    return State.restrictionHints
end

-- True when the PLAYER_REGEN edge (or, before one, the client's flag) says the player is fighting.
local function inCombat()
    local edge = State.combatEdge
    if edge ~= nil then return edge end
    return NS.Compat.InCombat()
end

-- The reason key for an enum member name: the known ones by table, any other by its own name.
local function reasonFor(name)
    return REASON_BY_NAME[name] or name
end

-- Adds the active restriction types to `set`, keyed by reason.
local function addTypes(set)
    local Compat = NS.Compat
    local h = hints()
    for name, value in pairs(Compat.RestrictionTypes()) do
        if Compat.IsSafeKey(value) and (h[value] or Compat.IsRestrictionActive(value)) then
            set[reasonFor(name)] = true
        end
    end
end

--- Every reason in effect now, as a set { [reason] = true }. Read live.
--- @return table
function R.ActiveSet()
    local set = {}
    addTypes(set)
    if NS.Compat.InChatMessagingLockdown() then set.chatLockdown = true end
    if inCombat() then set.combat = true end
    return set
end

local function anyOf(set, list)
    for _, reason in ipairs(list) do
        if set[reason] then return reason end
    end
    return nil
end

--- True while the player is fighting: the PLAYER_REGEN edge, else (before one) the client's flag.
--- @return boolean
function R.InCombat()
    return inCombat()
end

--- The answers at once, from one read: { reason, canSendChat }. `reason` is the one that matters
--- most now, for the surfaces' lockdown chip, or nil when nothing the addon does is restricted (the
--- Map type alone is nil); `canSendChat` is true when a chat message (an ask, an offer, an announce)
--- may be sent now.
--- @return table
function R.Snapshot()
    local set = R.ActiveSet()
    return {
        reason      = anyOf(set, PRIORITY),
        canSendChat = anyOf(set, CHAT_BLOCKERS) == nil,
    }
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- The blocking reasons in effect, in priority order, then the combat flag: what RESTRICTION_CHANGED
-- announces a move of. Every reason, not just the top one, so combat under an encounter (or one
-- lockdown lifting under another) still reaches the receivers that merge the whole set; and the
-- flag, so both PLAYER_REGEN edges announce even while the Combat type already holds `combat`.
local function signature(set)
    local parts = {}
    for _, reason in ipairs(PRIORITY) do
        if set[reason] then parts[#parts + 1] = reason end
    end
    return table.concat(parts, ",") .. "|" .. tostring(inCombat() == true)
end

--- Re-read the client. Sends RESTRICTION_CHANGED (reason, canSendChat) when the set of blocking
--- reasons moved since the last send (before the first, since "nothing restricted").
--- @param cause string|nil the event (or `standUp`) that asked, for the debug line
--- @return boolean changed
function R.Refresh(cause)
    local set = R.ActiveSet()
    local sig = signature(set)
    local prev = State.restrictionSignature or "|false"
    if sig == prev then return false end
    State.restrictionSignature = sig
    NS.Debug(TAG, "restrictions [%s] -> [%s] (%s)", prev, sig, tostring(cause))
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, anyOf(set, PRIORITY), anyOf(set, CHAT_BLOCKERS) == nil)
    return true
end

-- The hint an event's state gives: true or false, or nil when it says nothing readable.
local function stateHint(state)
    local Compat = NS.Compat
    if Compat.IsSecret(state) then return true end
    if state == nil then return nil end
    return Compat.IsRestrictionStateActive(state)
end

--- ADDON_RESTRICTION_STATE_CHANGED (type, state): records the type's hint, then refreshes. A secret
--- or missing type cannot key a hint, so only the client's own answers decide then.
function R.OnRestrictionStateChanged(rtype, state)
    if NS.Compat.IsSafeKey(rtype) then
        local hint = stateHint(state)
        if hint == false then hint = nil end
        hints()[rtype] = hint
    end
    return R.Refresh("ADDON_RESTRICTION_STATE_CHANGED")
end

--- A PLAYER_REGEN edge: `fighting` is true on DISABLED and false on ENABLED. The end of combat
--- also drains SendEngine's combat-end queue (spec §9.1) directly: after a login or /reload in
--- combat no signature was seeded, so this edge may move nothing and RESTRICTION_CHANGED (which
--- drains too) may never be sent. A second drain finds the queue empty and does nothing.
function R.OnCombatEdge(fighting)
    State.combatEdge = fighting and true or false
    local changed = R.Refresh(fighting and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    if not fighting and NS.SendEngine then NS.SendEngine.Drain("PLAYER_REGEN_ENABLED") end
    return changed
end

-- How long after an encounter or a key ends to read the client once more: the chat lockdown's flag
-- can clear after the event that ends it, and nothing else would announce the lift.
local LIFT_DELAY = 1

--- An encounter or a key ended: re-read the client now, and once more LIFT_DELAY later. A second
--- end inside the window reads now and leaves the one pending re-read where it is.
--- @param cause string the event, for the debug line
--- @return boolean changed by the read now
function R.RefreshAfterLift(cause)
    local changed = R.Refresh(cause)
    if not State.restrictionLiftTimer then
        State.restrictionLiftTimer = NS.addon:ScheduleTimer(function()
            State.restrictionLiftTimer = nil
            R.Refresh(tostring(cause) .. "+late")
        end, LIFT_DELAY)
    end
    return changed
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

-- Every handler below returns at once while stood down: the stand-down unregistered its event, so
-- only a dispatch the latch did not see reaches it, and a read then would seed state the stand-down
-- dropped (hints, the edge) or arm the late re-read (slash-commands-§7, step 6).
local function standing() return not NS.IsStoodDown() end

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionEvent" }

function NS.addon.OnRestrictionEvent(_, _, rtype, state)
    if standing() then R.OnRestrictionStateChanged(rtype, state) end
end

-- The two combat edges, handed over here because the flag can lag them.
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_DISABLED", "OnRestrictionRegenDisabled" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnRestrictionRegenEnabled" }

function NS.addon.OnRestrictionRegenDisabled() if standing() then R.OnCombatEdge(true) end end
function NS.addon.OnRestrictionRegenEnabled() if standing() then R.OnCombatEdge(false) end end

-- An encounter's end (a kill or a wipe). CHALLENGE_MODE_COMPLETED is Situation's row (AceEvent keeps
-- one handler per event per object), which forwards it to RefreshAfterLift.
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "ENCOUNTER_END", "OnRestrictionLiftEvent" }

function NS.addon.OnRestrictionLiftEvent(_, event) if standing() then R.RefreshAfterLift(event) end end

-- Stood down, no event reaches the hints or the edge, so both go stale and are dropped, and the
-- late re-read is canceled; the stand-up re-reads the client after the bus has replayed its
-- receivers, so they hear it.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if State.restrictionLiftTimer then NS.addon:CancelTimer(State.restrictionLiftTimer) end
    State.restrictionLiftTimer = nil
    State.restrictionHints = nil
    State.combatEdge = nil
    State.restrictionSignature = nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function() R.Refresh("standUp") end
