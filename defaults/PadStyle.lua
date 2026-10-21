local _, NS = ...
-- defaults/PadStyle.lua — the Comms Pad's header, section header and button styling defaults
-- (2026-10-20): the Pad header tab (`pad.header.*`), the Section header tab (`pad.section.*`) and the
-- Buttons tab (`pad.button.*`). Every field is a flat leaf of the surface's top-level `header`, `section`
-- or `button` table, so Library's fillShape backfills a pad saved before the field existed (it fills
-- one level deep). modules/Library.lua copies these into SURFACE_DEFAULTS and TEMPLATES;
-- settings/SchemaMembers.lua makes the rows; modules/Pad_Render.lua and modules/Pad.lua draw them.
--
-- The owner's defaults (2026-10-20): the header row 24 pixels (it was 18), its text Friz Quadrata
-- 16 points, gold, outlined, with its shadow, over no background and no edge (its edge color white
-- for when a style is picked). A section header is the section titles' 12-point gold outlined Friz
-- Quadrata with its shadow (moved from the Main window's `pad.look.font*`), its height automatic (0:
-- grown with its font, as modules/Pad_Layout.lua TitleHeight always did), over no band. A button is a
-- #3F3F3F body at 25% alpha, a flat 1 px edge #EAEAEA at 10% ("None" is no border art, not no edge),
-- its label the small white face with its shadow, its height automatic (0: grown to hold its font
-- and icon, as modules/Pad_Layout.lua CellSize always did) and no glow.

NS.PadDefaults = NS.PadDefaults or {}
local D = NS.PadDefaults

-- The header row's height range and default (modules/Pad_Layout.lua reads it through HeaderHeight).
D.HEADER_H = { min = 14, max = 40, default = 24 }
-- A section header's and a button's height ranges: 0 is automatic.
D.SECTION_H = { min = 0, max = 40 }
D.BUTTON_H = { min = 0, max = 80 }

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

--- A pad's `section` table, fresh: each section title's row, its font, and the band drawn behind it.
--- @return table
function D.Section()
    return {
        height = 0,
        font = "Friz Quadrata TT", fontSize = 12, fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = false, fontFlags = "OUTLINE", fontShadow = true,
        background = { r = 0, g = 0, b = 0, a = 0 }, useClassColorBackground = false,
        borderStyle = "None", borderSize = 0, borderColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorBorder = false,
    }
end

--- A pad's `button` table, fresh. The glow's knobs are not here: a button's glow takes the Icons tab's
--- knob defaults (defaults/Icons.lua GLOW_KNOBS), its style and color its own.
--- @return table
function D.Button()
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

--- The Dial page's Labels tab (`dial.label.*`, dial rework 2026-10-21): each wedge's name outside
--- the disc, white Friz Quadrata 12 points with its shadow, as the dial always drew it; `show` off
--- draws none. The tooltip shows outside the dial too: above it by default, `tooltipOffset` pixels
--- clear of the title (or the labels, the page row on the other sides).
function D.DialLabel()
    return {
        show = true,
        font = "Friz Quadrata TT", fontSize = 12, fontColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorFont = false, fontFlags = "", fontShadow = true,
        tooltipSide = "top", tooltipOffset = 8,
        offset = 0,   -- the labels' distance from the dial's center; 0 is just past the disc
    }
end

--- The Dial page's Group labels tab (`dial.title.*`, dial polish 2026-10-21): the ring's title above
--- the dial ("World (solo)", "Comms Dial"), gold Friz Quadrata 12 points with its shadow, as the
--- GameFontNormal title it was drawn in; `show` off draws none.
function D.DialTitle()
    return {
        show = true,
        font = "Friz Quadrata TT", fontSize = 12, fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = false, fontFlags = "", fontShadow = true,
    }
end

--- The Dial page's Slices tab (`dial.slice.*`, 2026-10-21): each slice's fill (the dial's dark disc,
--- as it was), the Slice gap between neighboring slices (pixels, 0 draws them touching; dial polish
--- 2026-10-21, which retired the Border lines), the fill a hovered slice takes, and the pointer in the
--- hub that turns toward the cursor.
function D.DialSlice()
    return {
        background = { r = 0.06, g = 0.06, b = 0.08, a = 0.80 }, useClassColorBackground = false,
        gap = 0,
        highlight = { r = 1, g = 0.82, b = 0, a = 0.25 }, useClassColorHighlight = false,
        pointerShow = true, pointerSize = 20, pointerColor = { r = 1, g = 0.82, b = 0, a = 1 },
        pointerOffset = 0,   -- the pointer's distance from the dial's center; 0 is just outside the hub
        useClassColorPointer = false,
    }
end

--- The Comms Dial's hub (`dial.hub.*`, the Slices tab's Hub heading; dial polish 2026-10-21, which
--- retired the red close mark): a Backdrop disc `size` across (the hub's geometry: the pointer, the
--- tracker and the catcher start at its edge), with a rim `borderSize` thick (0 draws none; the
--- Rimmed disc style draws one of at least 2), and a Circle mark `circleSize` across in the style's
--- shape (`solid` a filled circle, `ring` a hollow ring `lineWidth` thick, `target` a ring and a
--- center dot, `rimmed` a filled circle on the rimmed backdrop). Opacity is each color's alpha.
function D.DialHub()
    return {
        style = "solid", size = 40, circleSize = 22, lineWidth = 2,
        background = { r = 0.12, g = 0.12, b = 0.14, a = 0.95 }, useClassColorBackground = false,
        borderSize = 0, borderColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorBorder = false,
        circleColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorCircle = false,
    }
end

--- The Dial page's Paging tab (`dial.page.*`, 2026-10-21): a paged ring's row under the dial. Its
--- distance under the dial's labels; the two arrows (round plates in the slices' fill, gold chevrons)
--- and how far they stand from the indicators; the indicators, a gold pill for the page shown and a
--- gray dot for each other page.
function D.DialPage()
    return {
        offset = 6,
        arrowSize = 24, arrowGap = 10, arrowColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorArrow = false,
        plateColor = { r = 0.06, g = 0.06, b = 0.08, a = 0.80 }, useClassColorPlate = false,
        dotSize = 6, pillWidth = 18, dotGap = 6,
        currentColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorCurrent = false,
        dotColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9 }, useClassColorDot = false,
    }
end
