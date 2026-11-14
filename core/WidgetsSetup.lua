local addonName, NS = ...
-- core/WidgetsSetup.lua — every LibKa0s-Widgets-1.0 widget the addon draws: NS.MakeDragHandle (the
-- Comms Pad's drag strip), NS.MakeCopyWindow (the icon browser's Wowhead link window),
-- NS.MakeDropdown (the Preview as window's situation list), NS.OpenContextMenu and NS.CloseMenu (the
-- callout popup's emote menu, the library's one shared menu) and NS.MakeReorderList (an editor page's
-- drag-to-reorder rows). NS.HasWidget says whether the library offers one.
--
-- A seam, nothing else (library-stack-§7), shaped like DropWatcher core/WidgetsSetup.lua: one file
-- leases the major, and the help mark's art arrives resolved from the addon's media seam
-- (core/MediaSetup.lua), because a vendored library cannot know its folder. The strip is born
-- hidden; modules/Pad.lua shows it while the pads are unlocked (KickCD modules/IconGrid_Handle.lua
-- `IconGrid:ApplyLock`). DEGRADED (the library absent): NS.MakeDragHandle answers nil and a pad
-- stays where its saved point puts it; NS.MakeCopyWindow, NS.MakeDropdown, NS.OpenContextMenu and
-- NS.MakeReorderList answer nil too and NS.CloseMenu does nothing (the settings panel, and with it the
-- icon browser and the callout popup, is unavailable then anyway; the Preview as window stays unbuilt).
-- Each widget is looked up on the major at call time, never cached, so a test's wrapper is the one met.

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

-- The gap between a strip and the frame it moves.
NS.DRAG_GAP = (W and W.DRAG_HANDLE and W.DRAG_HANDLE.GAP) or 2

--- A drag strip over `parent`, or nil when the library is absent.
--- @param spec table LibKa0s DragHandle spec: label, moveFrame, canDrag, onDragStop, onRightClick, tooltip
--- @return table|nil
function NS.MakeDragHandle(parent, spec)
    if not (W and W.DragHandle) then return nil end
    spec.helpIcon = spec.helpIcon or (NS.Icon and NS.Icon("help")) or nil
    -- The owner (skinning-§1): the strip wears this addon's skin and follows a switch.
    spec.owner = addonName
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

--- Whether the library is loaded and offers the widget `name` ("Dropdown", "ContextMenu", ...).
--- @return boolean
function NS.HasWidget(name)
    return (W and W[name]) ~= nil
end

--- The library's Dropdown, `width` wide on `parent`, wearing this addon's skin, or nil when absent.
--- @param opts table|nil Dropdown opts: chevron, check, ...
--- @return table|nil
function NS.MakeDropdown(parent, width, opts)
    if not (W and W.Dropdown) then return nil end
    opts = opts or {}
    opts.owner = addonName
    return W.Dropdown(parent, width, opts)
end

--- Open the library's cascading menu of `rows` under `anchor` (a second call closes it), or nil.
--- @param opts table|nil ContextMenu opts: panel, ...
--- @return table|nil
function NS.OpenContextMenu(anchor, rows, opts)
    if not (W and W.ContextMenu) then return nil end
    opts = opts or {}
    opts.owner = addonName
    return W.ContextMenu(anchor, rows, opts)
end

--- Close the library's one shared menu (a Dropdown's list or a ContextMenu), if it is open.
function NS.CloseMenu()
    if W and W.CloseMenu then W.CloseMenu() end
end

--- The library's ReorderList (drag-to-reorder rows), wearing this addon's skin, or nil when absent.
--- @param spec table ReorderList spec: stride, handleIcon, handleTooltip, onMove
--- @return table|nil
function NS.MakeReorderList(spec)
    if not (W and W.ReorderList) then return nil end
    spec.owner = addonName
    return W.ReorderList(spec)
end
