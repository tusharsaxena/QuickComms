local _, NS = ...
-- defaults/PadStyle.lua — the Comms Pad's header and chip styling defaults (2026-10-20): the Window
-- tab's Header block (`pad.header.*`) and the Chip tab (`pad.chip.*`). Every field is a flat leaf of
-- the surface's top-level `header` or `chip` table, so Library's fillShape backfills a pad saved
-- before the field existed (it fills one level deep). modules/Library.lua copies these into
-- SURFACE_DEFAULTS and TEMPLATES; settings/SchemaMembers.lua makes the rows; modules/Pad_Render.lua
-- and modules/Pad.lua draw them.
--
-- The owner's defaults (2026-10-20): the header row 24 pixels (it was 18), its text Friz Quadrata
-- 16 points, gold, outlined, with its shadow, over no background and no edge (its edge color white
-- for when a style is picked). A chip is a #3F3F3F body at 25% alpha, a flat 1 px edge #EAEAEA at 10%
-- ("None" is no border art, not no edge), its label the small white face with its shadow, its height
-- automatic (0: grown to hold its font and icon, as modules/Pad_Layout.lua CellSize always did) and
-- no glow.

NS.PadDefaults = NS.PadDefaults or {}
local D = NS.PadDefaults

-- The header row's height range and default (modules/Pad_Layout.lua reads it through HeaderHeight).
D.HEADER_H = { min = 14, max = 40, default = 24 }
-- A chip's height range: 0 is automatic.
D.CHIP_H = { min = 0, max = 80 }

--- A pad's `header` table, fresh.
--- @return table
function D.Header()
    return {
        height = D.HEADER_H.default,
        font = "Friz Quadrata TT", fontSize = 16, fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = false, fontFlags = "OUTLINE", fontShadow = true,
        background = { r = 0, g = 0, b = 0, a = 0 }, useClassColorBackground = false,
        borderStyle = "None", borderSize = 0, borderColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorBorder = false,
    }
end

--- A pad's `chip` table, fresh. The glow's knobs are not here: a chip's glow takes the Icons tab's
--- knob defaults (defaults/Icons.lua GLOW_KNOBS), its style and color its own.
--- @return table
function D.Chip()
    return {
        width = 100, height = 0,
        background = { r = 0x3F / 255, g = 0x3F / 255, b = 0x3F / 255, a = 0.25 },
        useClassColorBackground = false,
        borderStyle = "None", borderSize = 1, borderColor = { r = 0xEA / 255, g = 0xEA / 255, b = 0xEA / 255, a = 0.10 },
        useClassColorBorder = false,
        font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorFont = false, fontFlags = "", fontShadow = true,
        glowEnabled = false, glowType = "pixel", glowColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorGlow = false,
    }
end
