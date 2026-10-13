local addonName, NS = ...
-- core/Bus.lua — every message name declared ONCE (architecture-§4), and the tracked bus.
--
-- Modules talk over AceEvent messages named Ka0s_QuickComms_<Event>, one sender each, and every
-- SendMessage / RegisterMessage call site uses the NS.MSG constant, never the literal. With
-- LibKa0s-Bus-1.0 present the table is the library's strict Catalog copy, so a mistyped key raises
-- at the call site for a publisher as well as a subscriber.
--
-- NS.Bus records what each receiver is registered for, so the stand-down takes every tracked
-- registration down and the stand-up replays what is wanted NOW (slash-commands-§7).
-- `NS.Bus.tracked` is this seam's one answer to "is the library present": true on the library
-- path, false on the degraded stub, where each feature module unregisters and re-registers its
-- own receivers in its stand-down and stand-up steps. No module resolves the library again. A
-- receiver takes its own target, `NS.Bus:NewTarget()`, never a shared one: CallbackHandler keys
-- callbacks by (message, target), and two receivers on one target clobber each other.

local lib = LibStub and LibStub("LibKa0s-Bus-1.0", true)

-- The catalog. Each line names its one sender; payloads and consumers are in
-- docs/ARCHITECTURE.md -> Message Bus. The rest of design spec §17's catalog lands with the
-- modules that send it.
local MSG = {
    PROFILE_CHANGED = "Ka0s_QuickComms_ProfileChanged",   -- core/QuickComms.lua (reloadProfile)
}

if not lib then
    -- Degrade, never error. The catalog is the plain table; the bus is an untracked factory whose
    -- targets are bare AceEvent embeds, and whose edges have nothing recorded to take down. The
    -- feature modules unregister their own receivers in their stand-down step on this path.
    NS.MSG = MSG
    NS.Bus = {
        name      = addonName,
        tracked   = false,
        NewTarget = function()
            local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
            return AceEvent and AceEvent:Embed({}) or nil
        end,
        StandDown = function() return 0, 0 end,
        StandUp   = function() return 0, {}, 0 end,
    }
    return
end

NS.MSG = lib.Catalog(addonName, MSG)
NS.Bus = lib:New({
    name   = addonName,
    -- Resolved when asked: the latch (core/LifecycleSetup.lua) loads after this file.
    isDown = function() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end,
})
NS.Bus.tracked = true
