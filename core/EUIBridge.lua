local addonName, NS = ...
-- core/EUIBridge.lua — the only file that reads EllesmereUI's state (the optional skin's gate).
--
-- EllesmereUI is an optional suite (library-stack-§6: presence-guarded, in ## OptionalDeps, and the
-- addon falls back to the stock look without it). Every seam below was read against EllesmereUI's
-- public skinning API (EllesmereUI/SKINNING_API.md: EllesmereUI.RegisterSkin, facade S, apiVersion
-- 3) and its window-skin child's dispatcher (EllesmereUIBlizzardSkin_SkinAPI.lua). Each read
-- happens at CALL time, nil-guarded, so an absent or renamed seam reads as "off" instead of raising.
-- NOTHING here writes EllesmereUI's state. There is no switch of this addon's own: EllesmereUI's
-- per-addon toggle in its Third-Party Addons list is the switch.
--
-- The conditions the skin is gated on, in order:
--   eui     the EllesmereUI global with RegisterSkin, and its Blizzard Skin child
--           (EllesmereUIBlizzardSkin) loaded: the child holds the dispatcher, and without it
--           RegisterSkin only queues;
--   master  EllesmereUI's third-party skinning on (EllesmereUIDB.thirdPartySkinsOff not truthy);
--   own     this addon's entry in its Third-Party Addons list on
--           (EllesmereUIDB.thirdPartySkinAddons.QuickComms not false).
-- The two switch reads mirror the dispatcher's own MasterOn / AddonOn: nil is on.

local Bridge = NS.EUIBridge or {}
NS.EUIBridge = Bridge

--- The name the skin registers under: the folder name (SKINNING_API.md, FAQ). It is also the key of
--- this addon's entry in EllesmereUI's Third-Party Addons list.
Bridge.SKIN_NAME = addonName

local SKIN_CHILD = "EllesmereUIBlizzardSkin"

-- C_AddOns.IsAddOnLoaded answers (loadedOrLoading, loaded). No reader, or one that raises, reads as
-- not loaded.
local function loaded(name)
    local api = C_AddOns and C_AddOns.IsAddOnLoaded
    if type(api) ~= "function" then return false end
    local ok, _, isLoaded = pcall(api, name)
    return ok and isLoaded == true
end

local function db()
    local d = EllesmereUIDB
    return type(d) == "table" and d or nil
end

local function suite()
    local eui = EllesmereUI
    return type(eui) == "table" and type(eui.RegisterSkin) == "function" and eui or nil
end

--- EllesmereUI is loaded with its public RegisterSkin, and its Blizzard Skin child is loaded.
function Bridge.IsSuiteReady()
    return suite() ~= nil and loaded(SKIN_CHILD)
end

--- EllesmereUI's third-party skinning switch (nil is on; any truthy value is off, as the
--- dispatcher reads it).
function Bridge.IsMasterOn()
    local d = db()
    return not (d and d.thirdPartySkinsOff)
end

--- This addon's entry in EllesmereUI's Third-Party Addons list (nil is on; only false is off).
function Bridge.IsEntryOn()
    local d = db()
    local t = d and d.thirdPartySkinAddons
    return not (type(t) == "table" and t[Bridge.SKIN_NAME] == false)
end

--- Every condition holds?
--- @return boolean open
--- @return string|nil failing  the first failing condition: "eui", "master" or "own"
function Bridge.GateOpen()
    if not Bridge.IsSuiteReady() then return false, "eui" end
    if not Bridge.IsMasterOn() then return false, "master" end
    if not Bridge.IsEntryOn() then return false, "own" end
    return true
end

--- Register `onFacade` with EllesmereUI under SKIN_NAME, when EllesmereUI is there to take it. Not
--- gated on the switches (SKINNING_API.md: registering is free, and EllesmereUI calls back only
--- while they are on); registering is what lists this addon in its Third-Party Addons list.
--- @return boolean registered
function Bridge.Register(onFacade)
    local eui = suite()
    if not eui then return false end
    local ok = pcall(eui.RegisterSkin, Bridge.SKIN_NAME, onFacade)
    return ok
end
