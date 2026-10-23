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

-- The player's name and normalized realm (the realm as chat senders carry it), each plain or nil.
local function playerFullName()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name, realm = PlainString(name), PlainString(realm)
    if not name and UnitName then name = PlainString((UnitName("player"))) end
    if (not realm or realm == "") and GetNormalizedRealmName then realm = PlainString(GetNormalizedRealmName()) end
    if realm == "" then realm = nil end
    return name, realm
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
    local mine, myRealm = playerFullName()
    if not mine then return nil end
    local bare, realm = name:match("^([^%-]+)%-(.+)$")
    if not bare then return name == mine end
    if bare ~= mine then return false end
    if not myRealm then return nil end
    return realm == myRealm
end

-- ── The bake context (spec §8.1): the values {me}, {spec}, {dungeon}, {coordinates} and {spell:ID} bake from ──

--- The player's name, without the realm.
function Compat.PlayerName()
    if not UnitName then return nil end
    return PlainString((UnitName("player")))
end

--- A unit's name, without the realm, or nil when there is no such unit (no target) or its name is
--- unreadable. Reads only, so a click in combat may call it (the preview echo's %t and %f, QC-07).
function Compat.UnitDisplayName(unit)
    if not (UnitExists and UnitName) or not UnitExists(unit) then return nil end
    local name = PlainString((UnitName(unit)))
    if name == "" then return nil end
    return name
end

--- The current specialization's display name.
function Compat.SpecName()
    local index = specIndex()
    if not index then return nil end
    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not get then return nil end
    local _, name = get(index)
    return PlainString(name)
end

--- A Mythic+ dungeon's display name from its challenge map id.
function Compat.DungeonName(mapID)
    local cm = C_ChallengeMode
    if not (PlainNumber(mapID) and cm and cm.GetMapUIInfo) then return nil end
    return PlainString((cm.GetMapUIInfo(mapID)))
end

--- True when the player is in chat channel 1 (General, by the client's default order):
--- GetChannelName(1) answers a plain non-zero id. False when not joined, unreadable or absent (QF-04).
function Compat.GeneralJoined()
    if not GetChannelName then return false end
    local id = PlainNumber((GetChannelName(1)))
    return id ~= nil and id ~= 0
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

-- ── The icon browser (settings/IconBrowser_Sources.lua) ─────────────────────────────────────

-- The macro icon selector's readers for `kind`, in the order Blizzard's IconDataProvider calls
-- them (the loose icons first), read at call time: each fills the table it is handed (and may
-- return it).
local function macroReaders(kind)
    if kind == "spells" then return { GetLooseMacroIcons, GetMacroIcons } end
    if kind == "items" then return { GetLooseMacroItemIcons, GetMacroItemIcons } end
    return {}
end

-- One reader's list, appended to `out` as plain texture ids. Nothing when the reader is absent,
-- raises, or its list has not loaded yet.
local function readInto(reader, out)
    if type(reader) ~= "function" then return end
    local filled = {}
    local ok, returned = pcall(reader, filled)
    if not ok then return end
    if #filled == 0 and type(returned) == "table" then filled = returned end
    for _, v in ipairs(filled) do
        v = PlainNumber(v)
        if v then out[#out + 1] = v end
    end
end

--- The icons the macro icon selector offers, `kind` "spells" (GetLooseMacroIcons, then
--- GetMacroIcons) or "items" (GetLooseMacroItemIcons, then GetMacroItemIcons): a list of texture
--- ids (plain numbers only), repeats kept (the browser dedups). A reader that is absent, raises, or
--- has not loaded yet adds nothing.
--- @return number[]
function Compat.MacroIcons(kind)
    local out = {}
    -- A list with holes (an absent reader) is walked by index, not ipairs.
    local readers = macroReaders(kind)
    for i = 1, 2 do readInto(readers[i], out) end
    return out
end
