local _, NS = ...
-- core/Compat.lua — the only caller of version-variant or optional client APIs, and the secret
-- guards (events-frames-taint-§8). Every reader returns plain values or nil, never a secret.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

--- True when `v` is a secret value. Exactly one boolean.
Compat.IsSecret = CompatLib and CompatLib.IsSecret or function(v)
    return issecretvalue ~= nil and issecretvalue(v) and true or false
end

--- True when `v` may be used as a table key: not secret, not nil.
Compat.IsSafeKey = CompatLib and CompatLib.IsSafeKey or function(v)
    if Compat.IsSecret(v) then return false end
    return v ~= nil
end

--- A plain number, or nil.
function Compat.PlainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

--- A plain string, or nil.
function Compat.PlainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local PlainNumber, PlainString = Compat.PlainNumber, Compat.PlainString

local function plainTrue(v)
    if Compat.IsSecret(v) then return false end
    return v == true
end

--- inInstance, instanceType, difficultyID, instanceID. Safe during loading screens.
function Compat.InstanceInfo()
    local inInstance = IsInInstance and IsInInstance()
    if not GetInstanceInfo then return plainTrue(inInstance), nil, nil, nil end
    local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    return plainTrue(inInstance), PlainString(instanceType), PlainNumber(difficultyID), PlainNumber(instanceID)
end

--- active, keystone level, challenge map id.
function Compat.ActiveKeystone()
    local cm = C_ChallengeMode
    if not cm then return false, nil, nil end
    local active = cm.IsChallengeModeActive and plainTrue(cm.IsChallengeModeActive()) or false
    local level = cm.GetActiveKeystoneInfo and PlainNumber((cm.GetActiveKeystoneInfo())) or nil
    local map = cm.GetActiveChallengeMapID and PlainNumber(cm.GetActiveChallengeMapID()) or nil
    return active, level, map
end

--- inGroup, inRaid, inInstanceGroup.
function Compat.GroupShape()
    local inGroup = IsInGroup and plainTrue(IsInGroup()) or false
    local inRaid = IsInRaid and plainTrue(IsInRaid()) or false
    local instanceCategory = LE_PARTY_CATEGORY_INSTANCE
    local inInstanceGroup = instanceCategory ~= nil and IsInGroup and plainTrue(IsInGroup(instanceCategory)) or false
    return inGroup, inRaid, inInstanceGroup
end

--- isLeader, isAssist.
function Compat.Leadership()
    local leader = UnitIsGroupLeader and plainTrue(UnitIsGroupLeader("player")) or false
    local assist = UnitIsGroupAssistant and plainTrue(UnitIsGroupAssistant("player")) or false
    return leader, assist
end

local function specIndex()
    local si = C_SpecializationInfo
    if si and si.GetSpecialization then return PlainNumber(si.GetSpecialization()) end
    if GetSpecialization then return PlainNumber(GetSpecialization()) end
    return nil
end

local function specInfo(index)
    if not index then return nil, nil end
    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not get then return nil, nil end
    local id, _, _, _, role = get(index)
    return PlainNumber(id), PlainString(role)
end

--- classFile, specID, role (TANK/HEALER/DAMAGER or nil), character ("Name-Realm" or nil).
function Compat.PlayerIdentity()
    local classFile = UnitClass and PlainString(select(2, UnitClass("player"))) or nil
    local specID, specRole = specInfo(specIndex())
    local role = UnitGroupRolesAssigned and PlainString(UnitGroupRolesAssigned("player")) or nil
    if role == nil or role == "NONE" then role = specRole end
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name, realm = PlainString(name), PlainString(realm)
    if (not realm or realm == "") and GetNormalizedRealmName then realm = PlainString(GetNormalizedRealmName()) end
    local character = name and realm and (name .. "-" .. realm) or nil
    return classFile, specID, role, character
end

--- True inside a house or plot (housing).
function Compat.InHousing()
    local h = C_Housing
    if not (h and h.IsInsideHouseOrPlot) then return false end
    return plainTrue(h.IsInsideHouseOrPlot())
end

--- True in combat lockdown.
function Compat.InCombat()
    return InCombatLockdown ~= nil and InCombatLockdown() == true
end

-- ── Restrictions (12.0), copied from DropWatcher core/Compat.lua:215-266 ───────────────────

--- True while the chat-messaging lockdown is in effect. A secret answer reads as locked.
function Compat.InChatMessagingLockdown()
    local chat = C_ChatInfo
    if not (chat and chat.InChatMessagingLockdown) then return false end
    local locked = chat.InChatMessagingLockdown()
    if Compat.IsSecret(locked) then return true end
    return locked == true
end

--- Enum.AddOnRestrictionType (name -> value), or an empty table.
function Compat.RestrictionTypes()
    local enum = Enum and Enum.AddOnRestrictionType
    return type(enum) == "table" and enum or {}
end

--- True when a restriction STATE is not Inactive. Boolean payloads answer themselves; secret is active.
function Compat.IsRestrictionStateActive(state)
    if Compat.IsSecret(state) then return true end
    if type(state) == "boolean" then return state end
    local n = PlainNumber(state)
    if n == nil then return false end
    local enum = Enum and Enum.AddOnRestrictionState
    local inactive = enum and PlainNumber(enum.Inactive) or 0
    return n ~= inactive
end

--- True while restriction `rtype` is in effect.
function Compat.IsRestrictionActive(rtype)
    local ra = C_RestrictedActions
    if not ra or rtype == nil then return false end
    if ra.IsAddOnRestrictionActive then
        local active = ra.IsAddOnRestrictionActive(rtype)
        if Compat.IsSecret(active) then return true end
        return active == true
    end
    if ra.GetAddOnRestrictionState then
        return Compat.IsRestrictionStateActive(ra.GetAddOnRestrictionState(rtype))
    end
    return false
end

-- ── The send engine (spec §9.2, §9.3) ────────────────────────────────────────────────────────

--- True when secure action buttons act on key DOWN: the ActionButtonUseKeyDown cvar, on by
--- default in the client, and assumed on when it cannot be read.
function Compat.UseKeyDown()
    local cv = C_CVar
    local get = (cv and cv.GetCVarBool) or GetCVarBool
    if not get then return true end
    local v = get("ActionButtonUseKeyDown")
    if Compat.IsSecret(v) then return true end
    return v == true
end

--- Whether a chat line came from the player: true, false, or nil when neither the GUID nor the
--- name can be read (secret or absent). Never compares a secret.
function Compat.SenderIsPlayer(sender, guid)
    local g = PlainString(guid)
    local me = UnitGUID and PlainString(UnitGUID("player")) or nil
    if g and me then return g == me end
    local name = PlainString(sender)
    if not name then return nil end
    local mine = UnitName and PlainString((UnitName("player"))) or nil
    if not mine then return nil end
    return (name:match("^([^%-]+)") or name) == mine
end
