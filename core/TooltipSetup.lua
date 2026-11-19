local _, NS = ...
-- core/TooltipSetup.lua — the one lease of LibKa0s-Tooltip-1.0 (LibKa0s#92, AD-92-QC; WowAddonStandards
-- standalone-windows, *Tooltip placement*): where every tooltip this addon places itself opens. Each
-- one belongs to a BODY element or a CHROME element, and the caller says which by the placer it calls.
--
-- BODY (NS.Tip.Beside): a pad button, a pad's section title, a dial wedge, the dial's hub and page
-- arrows, the Preview as window's dropdown and End preview button, the callout popup's token glyph.
-- The library's PlaceBeside opens the tooltip beside the WINDOW GROUP (a HUD display's group is the
-- whole display), outside its outer edge: its TOPLEFT a TIP_GAP right of the group's right edge, else
-- its TOPRIGHT a TIP_GAP left of its left edge, its top level with the hovered element's top, clamped
-- on screen. With room on neither side it attaches above the element (the library's fallback).
--
-- CHROME (NS.Tip.Attached): the pad's header row (its "Why is this showing?" and the combat refusal
-- of a tab switch) and the Preview as window's title marks under the edit preview's lock. The
-- library's PlaceAttached centers the tooltip on the control, TIP_GAP above it, below only when the
-- screen has no room above.
--
-- NEVER THE CURSOR. The tooltip is owned at ANCHOR_NONE (NS.Tip.Own), filled and shown, then placed,
-- so its real size is measured. With the library absent, or a geometry read that is not a plain
-- number (an unplaced frame, a secret), the fallback attaches it centered above the element (BOTTOM
-- on its TOP, TIP_GAP up): never at the pointer, never at a corner. The major is read at call time,
-- never cached, so a suite's spy and a newer copy are the ones met.

NS.Tip = NS.Tip or {}
local Tip = NS.Tip

-- The gap the standard fixes (standalone-windows, *Terms*), when the library is absent.
local GAP = 2

local function lib()
    local T = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    if type(T) == "table" and type(T.PlaceBeside) == "function" and type(T.PlaceAttached) == "function" then
        return T
    end
    return nil
end

--- The gap between a tooltip and what it is placed against: the library's TIP_GAP, else 2.
function Tip.Gap()
    local T = lib()
    return (T and tonumber(T.TIP_GAP)) or GAP
end

--- Own `tip` for a placement: SetOwner(element, "ANCHOR_NONE"), through the library when it is there.
--- @return table tip
function Tip.Own(tip, element)
    local T = lib()
    if T and type(T.Own) == "function" then return T.Own(tip, element) end
    tip:SetOwner(element, "ANCHOR_NONE")
    return tip
end

-- The fallback: centered above the element, the gap up.
local function attach(tip, element)
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOM", element, "TOP", 0, Tip.Gap())
    return "attached"
end

--- A chrome element's tooltip, on a shown `tip`: centered above `element`, below without room above.
--- @return string side "above" | "below" (the library's), or "attached" (the fallback)
function Tip.Attached(tip, element, opts)
    local T = lib()
    local side = T and T.PlaceAttached(tip, element, opts)
    if side then return side end
    return attach(tip, element)
end

--- A body element's tooltip, on a shown `tip`: beside `group` (a frame, `{ main = frame, panels = {...} }`,
--- a frame-like span, or nil for the library's GroupOf), top level with `element`. `opts.prefer` "left" tries the
--- left first.
--- @return string side "right" | "left" | "above" | "below" (the library's), or "attached" (the fallback)
function Tip.Beside(tip, element, group, opts)
    local T = lib()
    local side = T and T.PlaceBeside(tip, element, group, opts)
    if side then return side end
    return Tip.Attached(tip, element, opts)
end
