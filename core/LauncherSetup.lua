local addonName, NS = ...
-- core/LauncherSetup.lua — the launcher: one LibDataBroker object, registered twice (launcher).
--
-- LibKa0s-Launcher-1.0 builds the `launcher` object, registers the same object with LibDBIcon, owns
-- its single OnClick (left-click opens settings, right-click the options menu) and draws the status
-- tooltip. This file supplies the seams: the logo, the brand label, where LibDBIcon's `hide` lives
-- (db.global.minimap, shared with the Minimap button row), and one accessor-and-toggle pair per
-- menu entry. Enabled calls the handler `/qc enable|disable` calls (settings/Slash.lua); Locked
-- calls `/qc lock|unlock`'s, Test mode `/qc test`'s, and Show window `/qc toggle`'s (design spec §16).

local lib = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

-- The 128x128 uncompressed 32-bit logo; the same path as the TOC's ## IconTexture.
local ICON = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga"):format(addonName, addonName:lower())

local function minimapStore()
    local db = NS.addon and NS.addon.db
    return db and db.global and db.global.minimap
end

if not lib then
    local missing = NS.L["%s, so there is no minimap button and no broker plugin."]:format(NS.LIBKA0S_MISSING)
    local said = false
    NS.Launcher = {
        Register = function()
            if not said then
                said = true
                if NS.Print then NS.Print(missing) end
            end
            return false
        end,
        IsRegistered = function() return false end,
        Object       = function() return nil end,
        IsShown      = function()
            local t = minimapStore()
            return not (t and t.hide)
        end,
        SetShown     = function(_, shown)
            local t = minimapStore()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = lib:New({
    name  = addonName,
    icon  = ICON,
    label = NS.BRAND,

    minimap = minimapStore,

    openSettings = function() NS.addon:OpenSettings() end,

    -- The stored `enabled` setting, the same accessor the Master controls row reads (launcher-§1),
    -- written through the same handler `/qc enable|disable` calls.
    isEnabled  = function() return NS.SchemaRuntime ~= nil and NS.SchemaRuntime.Get("enabled") ~= false end,
    setEnabled = function(on) NS.addon:SlashEnabled(on) end,

    -- The Lock frame row's path and the test-mode switch, each through the handler its verb and its
    -- Master controls row call (launcher-§2, slash-commands-§8, preview-mode).
    isLocked       = function() return NS.SchemaRuntime ~= nil and NS.SchemaRuntime.Get("locked") ~= false end,
    toggleLock     = function() NS.SlashVerbs.ToggleLock() end,
    isTestMode     = function() return NS.Preview ~= nil and NS.Preview.IsTestMode() end,
    toggleTestMode = function() NS.Preview.ToggleTestMode() end,
    -- The pads are the primary display: Show window is `/qc toggle`'s session hide (plan B4).
    isWindowShown  = function() return NS.SlashVerbs ~= nil and NS.SlashVerbs.PadsShown() end,
    toggleWindow   = function() NS.SlashVerbs.TogglePads() end,

    print         = function(line) NS.Print(line) end,
    debug         = function(tag, message) NS.Debug(tag, message) end,
    debugAtEnable = function(tag, message) NS.DebugAtEnable(tag, "%s", message) end,

    version = function()
        local v = NS.Version()
        return v ~= "?" and v or nil
    end,
})
