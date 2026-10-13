local _, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDragHandle from LibKa0s-Widgets-1.0: the Comms Pad's drag strip.
--
-- A seam, nothing else (library-stack-§7), shaped like DropWatcher core/WidgetsSetup.lua: one file
-- leases the major, and the help mark's art arrives resolved from the addon's media seam
-- (core/MediaSetup.lua), because a vendored library cannot know its folder. The strip is born
-- hidden; modules/Pad.lua shows it while the pads are unlocked (KickCD modules/IconGrid_Handle.lua
-- `IconGrid:ApplyLock`). DEGRADED (the library absent): NS.MakeDragHandle answers nil and a pad
-- stays where its saved point puts it.

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
