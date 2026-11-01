local _, NS = ...
-- defaults/PadStyle.lua — the Comms Pad's header, section header and button styling defaults
-- (2026-10-20): the Header tab (`pad.header.*`), the Section titles tab (`pad.section.*`) and the
-- Buttons tab (`pad.button.*`). Every field is a flat leaf of the surface's top-level `header`, `section`
-- or `button` table, so Library's fillShape backfills a pad saved before the field existed (it fills
-- one level deep). modules/Library.lua copies these into SURFACE_DEFAULTS and TEMPLATES;
-- settings/SchemaMembers.lua makes the rows; modules/Pad_Render.lua and modules/Pad.lua draw them.
--
-- The owner's defaults (2026-10-20): the header row 24 pixels (it was 18), its text 16 points, gold,
-- outlined, with its shadow, over no background and no edge (its edge color white for when a style is
-- picked). A section header is the section titles' 12-point gold outlined text with its shadow (moved
-- from the Main window's `pad.look.font*`), its height automatic (0: grown with its font, as
-- modules/Pad_Layout.lua TitleHeight always did), over no band. A button is a #3F3F3F body at 25%
-- alpha, a flat 1 px edge #3F3F3F at 10% ("None" is no border art, not no edge), its label the small
-- white face with its shadow, its height automatic (0: grown to hold its font and icon, as
-- modules/Pad_Layout.lua CellSize always did) and no glow.
--
-- Every font block's `fontFromSkin` and every border block's `borderStyleFromSkin` (the composers'
-- "Use the skin's font / border" companions, QC-03) default true (DECISIONS X3): the face is the
-- skin's hud.font and the style its bar.borderStyle while on (modules/Pad_Render.lua FontKey,
-- BorderKey); the stored `font` and `borderStyle` are the player's picks, read while off.
--
-- Every font block's `fontFlags` is "@skin", the Font flags row's From skin (LibKa0s v1.82.0,
-- Ka0sAddonsCommonTasks D-07): the Skin tab's Font outline decides, through NS.Skin.FontFlags;
-- OUTLINE before, which schema step 11 moves to From skin once (modules/Library_Migrate.lua).
--
-- THE FULL SKIN (LibKa0s v1.85.0, Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING cause D7). Every
-- color, the shadow and the shine has a "Use the skin's ..." companion, `<key>FromSkin`, default true:
-- the value beside it is kept, unread while it is on, for a player who turns it off. Where this
-- addon's default differs from the skin's token, an owner token (core/SkinSetup.lua) holds today's
-- pixels under Ka0s Default and follows the library's token everywhere else. A pick's default is the
-- Ka0s pick, so a companion turned off lands on it and not on a client face. Sizes stay stored.

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
        font = "Ka0s Prototype", fontSize = 16, fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = false, fontColorFromSkin = true, fontFlags = "@skin", fontShadow = true,
        fontShadowFromSkin = true, fontFromSkin = true,
        background = { r = 0, g = 0, b = 0, a = 0 }, useClassColorBackground = false, backgroundFromSkin = true,
        borderStyle = "None", borderSize = 0, borderColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorBorder = false, borderColorFromSkin = true, borderStyleFromSkin = true,
    }
end

--- A pad's `section` table, fresh: each section title's row, its font, and the band drawn behind it.
--- @return table
function D.Section()
    return {
        height = 0,
        font = "Ka0s Prototype", fontSize = 12, fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = false, fontColorFromSkin = true, fontFlags = "@skin", fontShadow = true,
        fontShadowFromSkin = true, fontFromSkin = true,
        background = { r = 0, g = 0, b = 0, a = 0 }, useClassColorBackground = false, backgroundFromSkin = true,
        borderStyle = "None", borderSize = 0, borderColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorBorder = false, borderColorFromSkin = true, borderStyleFromSkin = true,
    }
end

--- A pad's `button` table, fresh. The glow's knobs are not here: a button's glow takes the Icons tab's
--- knob defaults (defaults/Icons.lua GLOW_KNOBS), its style and color its own. The Shine heading's
--- leaves (shine overlay, 2026-10-21; modules/Shine.lua) are flat, like `dial.page.dotBack*`: the look,
--- its Strength (0 to 100 percent), its tint and Fluid glass's two bloom colors, each with its
--- class-color companion. `shineFromSkin` puts the look and the tint on the skin; Strength stays stored.
--- @return table
function D.Button()
    return {
        width = 100, height = 0,
        background = { r = 0x3F / 255, g = 0x3F / 255, b = 0x3F / 255, a = 0.25 },
        useClassColorBackground = false, backgroundFromSkin = true, textureFromSkin = true,
        borderStyle = "None", borderSize = 1, borderColor = { r = 0x3F / 255, g = 0x3F / 255, b = 0x3F / 255, a = 0.10 },
        useClassColorBorder = false, borderColorFromSkin = true, borderStyleFromSkin = true,
        font = "Ka0s Prototype", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorFont = false, fontColorFromSkin = true, fontFlags = "@skin", fontShadow = true,
        fontShadowFromSkin = true, fontFromSkin = true,
        glowEnabled = false, glowType = "pixel", glowColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorGlow = false, glowColorFromSkin = true,
        shineLook = "glossfade", shineStrength = 80, shineFromSkin = true,
        shineTint = { r = 0x1B / 255, g = 0x1B / 255, b = 0x1B / 255, a = 1 }, useClassColorShineTint = false,
        shineBloomA = { r = 1, g = 0.604, b = 0.835, a = 1 }, useClassColorShineBloomA = false,   -- #ff9ad5
        shineBloomB = { r = 0.541, g = 1, b = 0.757, a = 1 }, useClassColorShineBloomB = false,   -- #8affc1
    }
end

--- The Dial page's Labels tab (`dial.label.*`, dial rework 2026-10-21): each wedge's name outside
--- the disc, white 12 points with its shadow, as the dial always drew it; `show` off
--- draws none. The tooltip shows outside the dial too: above it by default, `tooltipOffset` pixels
--- clear of the title (or the labels, the page row on the other sides).
function D.DialLabel()
    return {
        show = true,
        font = "Ka0s Prototype", fontSize = 12, fontColor = { r = 1, g = 1, b = 1, a = 1 },
        useClassColorFont = false, fontColorFromSkin = true, fontFlags = "@skin", fontShadow = true,
        fontShadowFromSkin = true, fontFromSkin = true,
        tooltipSide = "top", tooltipOffset = 8,
        offset = 0,   -- the labels' distance from the dial's center; 0 is just past the disc
    }
end

--- The Dial page's Labels tab's Group labels heading (`dial.title.*`, dial polish 2026-10-21): the ring's title above
--- the dial ("Solo", "Comms Dial"), gold 16 points with its shadow, as the
--- GameFontNormal title it was drawn in; `show` off draws none.
function D.DialTitle()
    return {
        show = true,
        font = "Ka0s Prototype", fontSize = 16, fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        useClassColorFont = false, fontColorFromSkin = true, fontFlags = "@skin", fontShadow = true,
        fontShadowFromSkin = true, fontFromSkin = true,
    }
end

--- The Dial page's Slices tab (`dial.slice.*`, 2026-10-21): each slice's fill (the dial's dark disc,
--- as it was), the Slice gap between neighboring slices (pixels, 0 draws them touching; dial polish
--- 2026-10-21, which retired the Border lines), the fill a hovered slice takes, and the pointer in the
--- hub that turns toward the cursor (the Hub tab's Pointer heading since dial polish, 2026-10-21; its
--- `dial.slice.*` paths kept). The Shine heading's leaves (shine overlay, 2026-10-21) are the pad
--- button's (D.Button), the dial's own.
function D.DialSlice()
    return {
        background = { r = 0.06, g = 0.06, b = 0.08, a = 0.80 }, useClassColorBackground = false,
        backgroundFromSkin = true,
        gap = 0,
        highlight = { r = 1, g = 0.82, b = 0, a = 0.25 }, useClassColorHighlight = false, highlightFromSkin = true,
        pointerShow = true, pointerSize = 24, pointerColor = { r = 1, g = 0.82, b = 0, a = 1 },
        pointerOffset = 24,   -- the pointer's distance from the dial's center; 0 is just outside the hub
        useClassColorPointer = false, pointerColorFromSkin = true,
        shineLook = "orb", shineStrength = 85, shineFromSkin = true,
        shineTint = { r = 0x80 / 255, g = 0x80 / 255, b = 0x80 / 255, a = 1 }, useClassColorShineTint = false,
        shineBloomA = { r = 1, g = 0.604, b = 0.835, a = 1 }, useClassColorShineBloomA = false,   -- #ff9ad5
        shineBloomB = { r = 0.541, g = 1, b = 0.757, a = 1 }, useClassColorShineBloomB = false,   -- #8affc1
    }
end

--- A dial's Animation tab (`dial.anim.*`, #13): its open and its close, each on its own. A style of
--- "none" switches that one off; a dial animates by default (the owner's ruling, 2026-11-01), by
--- Rotate and scale both ways. A direction is read only on Slide, and reads as motion: the defaults
--- rise into place and drop away, as the mockup does.
function D.DialAnim()
    return { openStyle = "rotateScale", openDuration = 0.2, openDirection = "up",
        closeStyle = "rotateScale", closeDuration = 0.2, closeDirection = "down" }
end

--- The Comms Dial's hub (`dial.hub.*`, the Hub tab's Hub heading; dial polish 2026-10-21, which
--- retired the red close mark): a Backdrop disc `size` across (the hub's geometry: the pointer, the
--- tracker and the catcher start at its edge), with a rim `borderSize` thick (0 draws none; the
--- Rimmed disc style draws one of at least 2), and a Circle mark `circleSize` across in the style's
--- shape (`solid` a filled circle, `ring` a hollow ring `lineWidth` thick, `target` a ring and a
--- center dot, `rimmed` a filled circle on the rimmed backdrop). Opacity is each color's alpha.
function D.DialHub()
    return {
        style = "solid", size = 32, circleSize = 24, lineWidth = 4,
        background = { r = 0.12, g = 0.12, b = 0.14, a = 0.95 }, useClassColorBackground = false,
        backgroundFromSkin = true,
        borderSize = 1, borderColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorBorder = false,
        borderColorFromSkin = true,   -- governs the thickness too: bar.borderSize while it is on
        circleColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorCircle = false, circleColorFromSkin = true,
    }
end

--- The Dial page's Paging tab (`dial.page.*`, 2026-10-21): a paged ring's row under the dial. Its
--- distance under the dial's labels; the two arrows (round plates in the slices' fill, gold chevrons)
--- and how far they stand from the indicators; the indicators, a gold pill for the page shown and a
--- gray dot for each other page, each with a near-black border `dotBorder` pixels wide (0 draws none),
--- on a rounded background in the plates' fill, `dotBackPadding` clear of the row (dial polish,
--- 2026-10-21: they were hard to see on a busy scene).
function D.DialPage()
    return {
        offset = 6,
        arrowSize = 24, arrowGap = 10, arrowColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorArrow = false, arrowColorFromSkin = true,
        plateColor = { r = 0.06, g = 0.06, b = 0.08, a = 0.80 }, useClassColorPlate = false, plateColorFromSkin = true,
        dotSize = 8, pillWidth = 18, dotGap = 6,
        currentColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorCurrent = false, currentColorFromSkin = true,
        dotColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9 }, useClassColorDot = false, dotColorFromSkin = true,
        dotBackShow = true, dotBackPadding = 4,
        dotBackColor = { r = 0.06, g = 0.06, b = 0.08, a = 0.80 }, useClassColorDotBack = false, dotBackColorFromSkin = true,
        dotBorder = 2, dotBorderColor = { r = 0, g = 0, b = 0, a = 0.9 }, useClassColorDotBorder = false, dotBorderColorFromSkin = true,
    }
end
