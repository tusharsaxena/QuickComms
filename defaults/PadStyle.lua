local _, NS = ...
-- defaults/PadStyle.lua — the Comms Pad's header and chip styling defaults (2026-10-20): the Window
-- tab's Header block (`pad.header.*`) and the Chip tab (`pad.chip.*`). Every field is a flat leaf of
-- the surface's top-level `header` or `chip` table, so Library's fillShape backfills a pad saved
-- before the field existed (it fills one level deep). modules/Library.lua copies these into
-- SURFACE_DEFAULTS and TEMPLATES; settings/SchemaMembers.lua makes the rows; modules/Pad_Render.lua
-- and modules/Pad.lua draw them.
--
-- Every default draws what a pad drew before the settings existed, but one: the header row is a
-- little taller (owner, 2026-10-20: "make the header slightly larger"), 22 pixels where it was 18.
-- The header's text is GameFontNormalSmall's (the face, 10 points, gold, its shadow), over no
-- background and no edge. A chip is the 0.10, 0.10, 0.12, 0.90 body with no edge, its label the
-- small white face with its shadow, its height automatic (0: grown to hold its font and icon, as
-- modules/Pad_Layout.lua CellSize always did) and no glow.

NS.PadDefaults = NS.PadDefaults or {}
local D = NS.PadDefaults

-- The header row's height range and default (modules/Pad_Layout.lua reads it through HeaderHeight).
D.HEADER_H = { min = 14, max = 40, default = 22 }
-- A chip's height range: 0 is automatic.
D.CHIP_H = { min = 0, max = 80 }

--- A pad's `header` table, fresh.
--- @return table
function D.Header()
    return {
        height = D.HEADER_H.default,
        font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = false, fontFlags = "", fontShadow = true,
        background = { r = 0, g = 0, b = 0, a = 0 }, useClassColorBackground = false,
        borderStyle = "None", borderSize = 0, borderColor = { r = 0, g = 0, b = 0, a = 1 },
        useClassColorBorder = false,
    }
end
