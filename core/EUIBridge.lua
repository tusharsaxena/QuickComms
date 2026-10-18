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
--   enabled the facade's S.IsEnabled() (SKINNING_API.md, "State and theme queries"): true while
--           EllesmereUI's third-party skinning AND this addon's entry in its Third-Party Addons list
--           are on. Read at paint time, so a switch turned off after the callback is honored.
-- This addon never reads EllesmereUI's SavedVariables (library-stack-§6, anti-patterns #29): the
-- facade is the only window onto its switches, and it arrives with the callback the paint waits on.

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

local function suite()
    local eui = EllesmereUI
    return type(eui) == "table" and type(eui.RegisterSkin) == "function" and eui or nil
end

--- EllesmereUI is loaded with its public RegisterSkin, and its Blizzard Skin child is loaded.
function Bridge.IsSuiteReady()
    return suite() ~= nil and loaded(SKIN_CHILD)
end

--- Why the suite is not ready, in words for the diagnostics report, or nil when it is.
--- @return string|nil
function Bridge.SuiteProblem()
    if type(EllesmereUI) ~= "table" then return "EllesmereUI is not loaded" end
    if not suite() then return "EllesmereUI has no RegisterSkin (an EllesmereUI without the skinning API)" end
    if not loaded(SKIN_CHILD) then return "EllesmereUI Blizzard Skins+ (" .. SKIN_CHILD .. ") is not loaded" end
    return nil
end

--- EllesmereUI's own answer, through the facade it handed over: are its third-party skinning and
--- this addon's entry both on? A facade without IsEnabled, or one whose IsEnabled raises, reads as
--- off.
--- @param S table|nil  the facade
--- @return boolean
function Bridge.IsEnabled(S)
    if type(S) ~= "table" or type(S.IsEnabled) ~= "function" then return false end
    local ok, on = pcall(S.IsEnabled)
    return ok and on == true
end

--- Every condition holds for facade `S`?
--- @param S table|nil  the facade
--- @return boolean open
--- @return string|nil failing  the first failing condition: "eui" or "enabled"
function Bridge.GateOpen(S)
    if not Bridge.IsSuiteReady() then return false, "eui" end
    if not Bridge.IsEnabled(S) then return false, "enabled" end
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
    Bridge.registered = ok
    return ok
end
