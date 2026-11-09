local _, NS = ...
-- core/Compat.lua — the only caller of version-variant or optional client APIs, and the secret
-- guards (events-frames-taint-§8). Every reader returns plain values or nil, never a secret.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

-- Library-absent guard arm: LibKa0s docs/api/Compat/version-1-docs.md, "Degradation" (options-ui-§1).
--- True when `v` is a secret value. Exactly one boolean.
Compat.IsSecret = CompatLib and CompatLib.IsSecret or function(v)
    return issecretvalue ~= nil and issecretvalue(v) and true or false
end

--- True when `v` may be used as a table key: not secret, not nil.
Compat.IsSafeKey = CompatLib and CompatLib.IsSafeKey or function(v)
    if Compat.IsSecret(v) then return false end
    return v ~= nil
end

local function hasMethods(object, names)
    if type(object) ~= "table" then return false end
    for _, name in ipairs(names) do
        if type(object[name]) ~= "function" then return false end
    end
    return true
end

local SCALE_GROUP = { "CreateAnimation", "Play", "Stop" }
local SCALE_ANIM = { "SetScaleFrom", "SetScaleTo", "SetOrigin", "SetDuration", "SetSmoothing" }

-- A group holding one Scale animation about `object`'s center, or nil if any part is missing.
local function scaleOn(object)
    local group = object:CreateAnimationGroup()
    if not hasMethods(group, SCALE_GROUP) then return nil end
    local anim = group:CreateAnimation("Scale")
    if not hasMethods(anim, SCALE_ANIM) then return nil end
    anim:SetOrigin("CENTER", 0, 0)
    return group, anim
end

--- A Scale animation for font string `fs`, set to run in `Enum.FontStringScaleAnimationMode.Vertex`
--- (12.0) about the string's center: the group and the animation, or nil when the client lacks any
--- part of that. FontSize mode, the default, is the shimmer, so there is no fallback to it.
function Compat.VertexScaleAnimation(fs)
    local modes = type(Enum) == "table" and Enum.FontStringScaleAnimationMode
    local vertex = type(modes) == "table" and modes.Vertex or nil
    if vertex == nil or not hasMethods(fs, { "SetScaleAnimationMode", "CreateAnimationGroup" }) then return nil end
    local group, anim = scaleOn(fs)
    if not group then return nil end
    fs:SetScaleAnimationMode(vertex)
    return group, anim
end

--- A Scale animation for frame `frame` about its center: the group and the animation, or nil when the
--- client lacks any part of it. The only way to scale one axis alone (the ghost's art, #13).
function Compat.StretchAnimation(frame)
    if not hasMethods(frame, { "CreateAnimationGroup" }) then return nil end
    return scaleOn(frame)
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

local RoleLib = LibStub and LibStub("LibKa0s-Role-1.0", true)

local function specIndex()
    local si = C_SpecializationInfo
    if si and si.GetSpecialization then return PlainNumber(si.GetSpecialization()) end
    if GetSpecialization then return PlainNumber(GetSpecialization()) end
    return nil
end

local function specInfo(index)
    if not index then return nil, nil, nil end
    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not get then return nil, nil, nil end
    local id, name, _, _, role = get(index)
    return PlainNumber(id), PlainString(name), PlainString(role)
end

-- The active spec: specID, name. LibKa0s Role's Spec (Compat's spec ladder, both clients) where the
-- library is loaded, else the same ladder read here.
local function activeSpec()
    if RoleLib and RoleLib.Spec then
        local id, name = RoleLib.Spec()
        return PlainNumber(id), PlainString(name)
    end
    local id, name = specInfo(specIndex())
    return id, name
end

--- Whether character names are unique per region (LibKa0s Compat.RegionalNames: true on WoW
--- Forever). A character is then "First Surname", with no realm, in chat and in a When. False
--- without the library, so a degraded install keeps the Name-Realm forms. Feature detection, never
--- a client check (clients-§3).
function Compat.RegionalNames()
    return CompatLib ~= nil and CompatLib.RegionalNames ~= nil and CompatLib.RegionalNames() == true
end

-- A unit's character name, without a realm: "First Surname" with regional names, UnitName's name
-- otherwise (LibKa0s Compat.UnitCharacterName; UnitName where the library is absent). Plain or nil.
local function characterName(unit)
    if not UnitName then return nil end
    local name
    if CompatLib and CompatLib.UnitCharacterName then
        name = CompatLib.UnitCharacterName(unit)
    else
        name = UnitName(unit)
    end
    name = PlainString(name)
    if name == "" then return nil end
    return name
end

-- The player's name and normalized realm (the realm as chat senders carry it), each plain or nil.
-- Retail's form only: with regional names UnitFullName's second value is a surname, never a realm.
local function playerFullName()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name, realm = PlainString(name), PlainString(realm)
    if not name and UnitName then name = PlainString((UnitName("player"))) end
    if (not realm or realm == "") and GetNormalizedRealmName then realm = PlainString(GetNormalizedRealmName()) end
    if realm == "" then realm = nil end
    return name, realm
end

--- The player's character as a When's character row stores it, or nil until the client can say:
--- with regional names LibKa0s Compat.CharacterKey(), "First Surname" (the first name alone for a
--- character with no surname); otherwise "Name-Realm", the realm normalized as chat senders carry it
--- (the form every saved When already holds, so Retail's are untouched).
function Compat.CharacterKey()
    if Compat.RegionalNames() and CompatLib.CharacterKey then
        local key = PlainString(CompatLib.CharacterKey())
        if key == "" then return nil end
        return key
    end
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name, realm = PlainString(name), PlainString(realm)
    if (not realm or realm == "") and GetNormalizedRealmName then realm = PlainString(GetNormalizedRealmName()) end
    return name and realm and (name .. "-" .. realm) or nil
end

-- ── The role (QFE-F4, design §4.4): LibKa0s Role, its store this character's db.char.role ──────

local VALID_ROLE = { TANK = true, HEALER = true, DAMAGER = true }

--- This character's role store (`db.char.role`: the player's override and the last answer), made on
--- first use; nil before the database exists.
function Compat.RoleStore()
    local char = NS.db and NS.db.char
    if type(char) ~= "table" then return nil end
    if type(char.role) ~= "table" then char.role = {} end
    return char.role
end

-- The library-absent ladder: the override, the group's assignment, the spec API's role.
local function fallbackRole(store)
    local override = store and store.override
    if VALID_ROLE[override] then return override, "override", nil end
    local assigned = UnitGroupRolesAssigned and PlainString(UnitGroupRolesAssigned("player")) or nil
    if VALID_ROLE[assigned] then return assigned, "assigned", nil end
    local _, name, role = specInfo(specIndex())
    if VALID_ROLE[role] then return role, "spec", name end
    return nil, nil, nil
end

local function resolveRole(store)
    if RoleLib and RoleLib.Resolve then return RoleLib.Resolve(store) end
    return fallbackRole(store)
end

--- The role the player plays: role (TANK/HEALER/DAMAGER or nil), source ("override", "assigned",
--- "talents", "spec", "saved" or nil) and detail (the talent group's or the spec's name, or nil):
--- LibKa0s Role.Resolve over this character's store (Role's order, owner-rulings C1).
function Compat.PlayerRole()
    return resolveRole(Compat.RoleStore())
end

--- What Automatic answers, with the player's own pick set aside: role, source, detail. The store is
--- copied, so the override stays and the saved answer is not moved.
function Compat.AutomaticRole()
    local store = Compat.RoleStore()
    local copy
    if store then
        copy = {}
        if type(store.last) == "table" then copy.last = { role = store.last.role, specID = store.last.specID } end
    end
    return resolveRole(copy)
end

--- The player's own pick, or nil for Automatic.
function Compat.RoleOverride()
    local store = Compat.RoleStore()
    local v = store and store.override
    if VALID_ROLE[v] then return v end
    return nil
end

--- Set the player's pick (TANK/HEALER/DAMAGER), or nil for Automatic: LibKa0s Role.SetOverride on
--- this character's store. False when there is no store yet or the role is not one of the three.
--- @return boolean
function Compat.SetRoleOverride(role)
    local store = Compat.RoleStore()
    if not store or (role ~= nil and not VALID_ROLE[role]) then return false end
    if RoleLib and RoleLib.SetOverride then
        RoleLib.SetOverride(store, role)
    else
        store.override = role
    end
    return true
end

--- The specializations a class has, as the When editor's spec row lists them: an array of
--- `{ id, name }`, from LibKa0s Role.SpecsForClass (read from the client on both clients, so WoW
--- Forever needs no seed); empty when the library or the client cannot say (the caller then falls
--- back to NS.GameIds.SPECS).
function Compat.SpecsForClass(classFile)
    local out = {}
    if not (RoleLib and RoleLib.SpecsForClass and Compat.IsSafeKey(classFile)) then return out end
    for _, spec in ipairs(RoleLib.SpecsForClass(classFile)) do
        local id = PlainNumber(spec.id)
        if id and id > 0 then out[#out + 1] = { id = id, name = PlainString(spec.name) } end
    end
    return out
end

--- classFile, specID, role (TANK/HEALER/DAMAGER or nil), character (Compat.CharacterKey or nil),
--- then the role's source and detail (Compat.PlayerRole). The first four are the situation's
--- signature fields; the last two ride along for /qc why and the diagnostics.
function Compat.PlayerIdentity()
    local classFile = UnitClass and PlainString(select(2, UnitClass("player"))) or nil
    local specID = activeSpec()
    local role, source, detail = Compat.PlayerRole()
    return classFile, specID, role, Compat.CharacterKey(), source, detail
end

-- ── The probe's readers (QFE-F5, design §4.5): what /qc probe records, each value plain or nil ───

-- A plain boolean, or nil for a secret or no answer.
local function plainBool(v)
    if v == nil or Compat.IsSecret(v) then return nil end
    return v and true or false
end

--- Every value IsInInstance() and GetInstanceInfo() return, by name, each plain or nil (the
--- probe's record of the place, so Forever's ids and kinds can be read off a saved file).
--- @return table
function Compat.ProbeInstance()
    local out = {}
    if IsInInstance then
        local inInstance, kind = IsInInstance()
        out.inInstance, out.inInstanceType = plainBool(inInstance), PlainString(kind)
    end
    if not GetInstanceInfo then return out end
    local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic,
        instanceID, instanceGroupSize, lfgDungeonID = GetInstanceInfo()
    out.name, out.instanceType = PlainString(name), PlainString(instanceType)
    out.difficultyID, out.difficultyName = PlainNumber(difficultyID), PlainString(difficultyName)
    out.maxPlayers, out.dynamicDifficulty = PlainNumber(maxPlayers), PlainNumber(dynamicDifficulty)
    out.isDynamic, out.instanceID = plainBool(isDynamic), PlainNumber(instanceID)
    out.instanceGroupSize, out.lfgDungeonID = PlainNumber(instanceGroupSize), PlainNumber(lfgDungeonID)
    return out
end

--- The active spec's id and name, each plain or nil (the situation's spec ladder).
function Compat.ActiveSpec()
    return activeSpec()
end

--- The talent groups LibKa0s Role reads the role from (Role.Groups: `{ index, id, name, spent }`
--- rows, plain copies), empty where the library or the trees are absent (Retail answers none).
--- @return table[]
function Compat.TalentGroups()
    local out = {}
    if not (RoleLib and RoleLib.Groups) then return out end
    for _, g in ipairs(RoleLib.Groups()) do
        out[#out + 1] = { index = PlainNumber(g.index), id = PlainNumber(g.id), name = PlainString(g.name),
            spent = PlainNumber(g.spent) }
    end
    return out
end

-- How far the emote scan reads when the client names no MAXEMOTEINDEX (628 on both clients today).
local EMOTE_SCAN_MAX = 1000

--- The emote tokens this client has, in index order: every EMOTEn_TOKEN global from 1 to
--- MAXEMOTEINDEX, as Blizzard's own chat code walks them (the indices are not contiguous).
--- @return string[]
function Compat.EmoteTokens()
    local max = PlainNumber(_G.MAXEMOTEINDEX) or EMOTE_SCAN_MAX
    local out = {}
    for i = 1, max do
        local token = PlainString(_G["EMOTE" .. i .. "_TOKEN"])
        if token and token ~= "" then out[#out + 1] = token end
    end
    return out
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
--- name can be read (secret or absent). Never compares a secret. Without the GUID the full name
--- decides: a sender with a realm is the player only on the player's own realm (a cross-realm
--- namesake is not), so when that realm cannot be read the answer is unknown; a sender with no
--- realm is on the player's realm and the bare name decides.
function Compat.SenderIsPlayer(sender, guid)
    local g = PlainString(guid)
    local me = UnitGUID and PlainString(UnitGUID("player")) or nil
    if g and me then return g == me end
    local name = PlainString(sender)
    if not name then return nil end
    -- Regional names (WoW Forever): the sender is "First Surname" with no realm, as is the player.
    if Compat.RegionalNames() then
        local mine = characterName("player")
        if not mine then return nil end
        return name == mine
    end
    local mine, myRealm = playerFullName()
    if not mine then return nil end
    local bare, realm = name:match("^([^%-]+)%-(.+)$")
    if not bare then return name == mine end
    if bare ~= mine then return false end
    if not myRealm then return nil end
    return realm == myRealm
end

-- ── The bake context (spec §8.1): the values {me}, {spec}, {dungeon}, {coordinates} and {spell:ID} bake from ──

--- The player's name, without the realm: "First Surname" with regional names (WoW Forever), the
--- name alone otherwise (LibKa0s Compat.UnitCharacterName).
function Compat.PlayerName()
    return characterName("player")
end

--- A unit's name, without the realm ("First Surname" with regional names), or nil when there is no
--- such unit (no target) or its name is unreadable. Reads only, so a click in combat may call it (the
--- preview echo's %t and %f, QC-07).
function Compat.UnitDisplayName(unit)
    if not (UnitExists and UnitName) or not UnitExists(unit) then return nil end
    return characterName(unit)
end

--- The current specialization's display name.
function Compat.SpecName()
    local _, name = activeSpec()
    return name
end

--- A Mythic+ dungeon's display name from its challenge map id.
function Compat.DungeonName(mapID)
    local cm = C_ChallengeMode
    if not (PlainNumber(mapID) and cm and cm.GetMapUIInfo) then return nil end
    return PlainString((cm.GetMapUIInfo(mapID)))
end

--- True when chat channel 1 is the zone's General channel, as the client identifies it:
--- C_ChatInfo.GetGeneralChannelLocalID() answers a plain 1 (the number General holds, nil when it is
--- not joined). Never the channel's name, which is localized (localization-§4): a channel 1 the
--- player made or reordered there is not General. False when General is elsewhere, not joined,
--- unreadable or the API is absent, so the `general` kind falls back to Say (QF-04, F-007).
function Compat.GeneralJoined()
    local chat = C_ChatInfo
    if not (chat and chat.GetGeneralChannelLocalID) then return false end
    return PlainNumber((chat.GetGeneralChannelLocalID())) == 1
end

--- The client's key, "retail" or "forever" (clients-§3): LibKa0s Compat's ClientKey, the one place the
--- question is answered (from WOW_PROJECT_ID, never an interface number). Retail when the library is
--- absent or the project constants say neither, so a degraded install keeps the Retail lists.
--- Asked once at load by defaults/GameIds_Clients.lua (QFE-F3).
function Compat.ClientKey()
    local key = CompatLib and CompatLib.ClientKey and CompatLib.ClientKey() or nil
    return key == "forever" and "forever" or "retail"
end

--- Whether this is a WoW Forever client (Compat.ClientKey).
function Compat.IsForever()
    return Compat.ClientKey() == "forever"
end

--- A frame's strata as a plain string, or `fallback` when the read is secret (WoW Forever can hand a
--- strata back secret, Enum.SecretAspect.FrameStrata), not a string, or the frame has no reader.
--- Asked before a strata read is stored or handed back to SetFrameStrata (QFE-F1).
function Compat.FrameStrata(frame, fallback)
    if not (frame and frame.GetFrameStrata) then return fallback end
    local strata = frame:GetFrameStrata()
    if Compat.IsSecret(strata) or type(strata) ~= "string" then return fallback end
    return strata
end

--- The player's map position in percent (0-100), `x, y`, or nil: C_Map.GetBestMapForUnit("player"),
--- then C_Map.GetPlayerMapPosition on that map and its GetXY, every value plain (secret-safe). Nil
--- when any step is missing, the map is restricted (an instance answers no position) or the position
--- is 0, 0. Reads only, so a click in combat may call it (QF-03).
function Compat.PlayerMapPosition()
    local map = C_Map
    if not (map and map.GetBestMapForUnit and map.GetPlayerMapPosition) then return nil end
    local mapID = PlainNumber(map.GetBestMapForUnit("player"))
    if not mapID then return nil end
    local pos = map.GetPlayerMapPosition(mapID, "player")
    if Compat.IsSecret(pos) or type(pos) ~= "table" or type(pos.GetXY) ~= "function" then return nil end
    local x, y = pos:GetXY()
    x, y = PlainNumber(x), PlainNumber(y)
    if not (x and y) or (x == 0 and y == 0) then return nil end
    return x * 100, y * 100
end

--- The player's map position as chat text, "45.2, 61.8" (x, y in percent, one decimal), for
--- {coordinates}; nil where PlayerMapPosition has none.
function Compat.Coordinates()
    local x, y = Compat.PlayerMapPosition()
    if not x then return nil end
    return ("%.1f, %.1f"):format(x, y)
end

--- A spell's chat link, for {spell:ID}.
function Compat.SpellLink(id)
    local sp = C_Spell
    if not (PlainNumber(id) and sp and sp.GetSpellLink) then return nil end
    return PlainString(sp.GetSpellLink(id))
end

-- ── Display names for the editors (spec §13.2, §13.3): shown, never matched ─────────────────

--- An instance's display name from its instanceID (GetRealZoneText takes a map id), or nil.
function Compat.InstanceName(id)
    if not (PlainNumber(id) and GetRealZoneText) then return nil end
    local name = PlainString(GetRealZoneText(id))
    if name == "" then return nil end
    return name
end

--- A specialization's display name and icon from its specID, or nil.
function Compat.SpecInfoByID(id)
    if not (PlainNumber(id) and GetSpecializationInfoByID) then return nil end
    local _, name, _, icon = GetSpecializationInfoByID(id)
    name = PlainString(name)
    if not name or name == "" then return nil end
    return name, PlainNumber(icon)
end

--- A class's display name from its classFile token, or nil.
function Compat.ClassName(classFile)
    local names = LOCALIZED_CLASS_NAMES_MALE
    if type(names) ~= "table" or not Compat.IsSafeKey(classFile) then return nil end
    return PlainString(names[classFile])
end

-- ── The dial's key (spec §9.4): WoW's own binding, set in Options -> Keybindings ───────────────

--- The first key the player bound to `command` in WoW's key bindings menu (GetBindingKey), or nil
--- when there is none, it is secret, or the API is absent.
function Compat.BindingKey(command)
    if not (GetBindingKey and Compat.IsSafeKey(command)) then return nil end
    local key = PlainString((GetBindingKey(command)))
    if key == nil or key == "" then return nil end
    return key
end

-- ── The pad (spec §10.1) ─────────────────────────────────────────────────────────────────────

--- UIParent's width and height, or nil while either is unknown or not a positive plain number.
function Compat.ScreenSize()
    local ui = UIParent
    if not (ui and ui.GetWidth and ui.GetHeight) then return nil end
    local w, h = PlainNumber(ui:GetWidth()), PlainNumber(ui:GetHeight())
    if not (w and h and w > 0 and h > 0) then return nil end
    return w, h
end

--- The client's color for a chat type, or nil when it cannot be read.
function Compat.ChatColor(chatType)
    local info = ChatTypeInfo
    if type(info) ~= "table" or not Compat.IsSafeKey(chatType) then return nil end
    local c = info[chatType]
    if type(c) ~= "table" then return nil end
    local r, g, b = PlainNumber(c.r), PlainNumber(c.g), PlainNumber(c.b)
    if r and g and b then return r, g, b end
    return nil
end

-- ── The callout popup's window (settings/CalloutPopup.lua) ───────────────────────────────────

--- Whether the client knows XML template `name`: true or false where C_XMLUtil.GetTemplateInfo
--- answers, nil (unknown) where the API is absent, so the caller tries CreateFrame under pcall.
function Compat.HasTemplate(name)
    local x = C_XMLUtil
    if type(name) ~= "string" or type(x) ~= "table" or type(x.GetTemplateInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(x.GetTemplateInfo, name)
    return ok and type(info) == "table"
end
