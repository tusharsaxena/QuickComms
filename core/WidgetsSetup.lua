local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDragHandle and NS.MakeCopyWindow from LibKa0s-Widgets-1.0: the
-- Comms Pad's drag strip and the Share page's export window.
--
-- A seam, nothing else (library-stack-§7), shaped like DropWatcher core/WidgetsSetup.lua: one file
-- leases the major, and the help mark's art arrives resolved from the addon's media seam
-- (core/MediaSetup.lua), because a vendored library cannot know its folder. The strip is born
-- hidden; modules/Pad.lua shows it while the pads are unlocked (KickCD modules/IconGrid_Handle.lua
-- `IconGrid:ApplyLock`). DEGRADED (the library absent): NS.MakeDragHandle answers nil and a pad
-- stays where its saved point puts it; NS.MakeCopyWindow answers nil too (the settings panel, and
-- with it the Share page, is unavailable then anyway).

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

-- The gap between a strip and the frame it moves.
NS.DRAG_GAP = (W and W.DRAG_HANDLE and W.DRAG_HANDLE.GAP) or 2

--- A drag strip over `parent`, or nil when the library is absent.
--- @param spec table LibKa0s DragHandle spec: label, moveFrame, canDrag, onDragStop, onRightClick, tooltip
--- @return table|nil
function NS.MakeDragHandle(parent, spec)
    if not (W and W.DragHandle) then return nil end
    spec.helpIcon = spec.helpIcon or (NS.Icon and NS.Icon("help")) or nil
    return W.DragHandle(parent, spec)
end

--- A read-only copy window (the LibKa0s CopyWindow: text in, Ctrl+C out, Escape closes), or nil when
--- the library is absent. Its frame is built on the first Show. The addon's folder name goes in so
--- the window's close control finds the collection's art.
--- @param d table CopyWindow descriptor: name, scrollName, title, width, height
--- @return table|nil the window's handle: :Show(text), :Hide(), :GetText()
function NS.MakeCopyWindow(d)
    if not (W and W.CopyWindow) then return nil end
    d.addonName = addonName
    return W.CopyWindow(d)
end
