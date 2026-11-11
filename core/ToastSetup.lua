local addonName, NS = ...
-- core/ToastSetup.lua — NS.NewToast from LibKa0s-Toast-1.0: the alert-toast shell auto-thank's
-- toast host (modules/AutoThank_Toast.lua) draws its "buffed you" toast in (spec §9 The toast).
--
-- A seam, nothing else (library-stack-§7), shaped like DropWatcher's Toast seam: one file leases the
-- major and names this addon as the toast's skin owner (skinning-§1), so it wears this addon's skin
-- and follows a switch. The strata is the library's (lib.STRATA, HIGH, the T5 alert tier); the
-- addon never sets one on it (core/Constants.lua C.LAYERS). DEGRADED (the library absent):
-- NS.NewToast answers NS.ToastStub, every member of a live toast as a no-op that shows nothing, so
-- auto-thank never toasts and nothing it calls raises. tests/test_surface_parity.lua pins the stub
-- against a live instance.

local Toast = LibStub and LibStub("LibKa0s-Toast-1.0", true)

local function none() end

--- The library-absent toast: a live toast's members, doing nothing.
NS.ToastStub = {
    Show = function() return false end,
    Dismiss = none,
    Remove = function() return 0 end,
    Clear = none,
    Hold = none,
    Release = none,
    Pause = none,
    Resume = none,
    Attach = none,
    Refresh = none,
    SetStack = function() return 1, "DOWN" end,
    ResetPosition = none,
    Preview = none,
    Current = none,
    Visible = function() return {} end,
    FrameFor = none,
    Stats = function()
        return { built = false, shown = false, waiting = 0, held = false, paused = false, sticky = false,
            keys = {}, visible = 0, visibleKeys = {}, stack = 1, grow = "DOWN" }
    end,
    Frame = none,
}

--- A toast for descriptor `d` (LibKa0s-Toast-1.0's New: d.build is required), owned by this addon,
--- or NS.ToastStub when the library is absent.
--- @param d table the toast descriptor
--- @return table the toast instance
function NS.NewToast(d)
    if not Toast then return NS.ToastStub end
    d.owner = addonName
    return Toast:New(d)
end
