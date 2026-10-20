local _, NS = ...
-- defaults/Icons.lua — the Icons tab's defaults (B9): how a Comms Pad button's and a Comms Dial
-- wedge's icon is drawn. Every field is a flat leaf of the surface's top-level `icon` table
-- (`pad.icon.*`, `dial.icon.*`), so Library's fillShape backfills a surface saved before the field
-- existed (it fills one level deep). modules/Library.lua copies these into SURFACE_DEFAULTS and
-- TEMPLATES; settings/SchemaIcons.lua makes the rows; modules/IconStyle.lua and modules/Glow.lua draw
-- them. Every default draws an icon exactly as it was drawn before the tab existed: no crop, no
-- desaturation, opaque, a white tint (a glyph keeps its own color), no border and no glow.
--
-- The glow knobs, their ranges and defaults are DropWatcher's (settings/SchemaRows.lua GLOW_KNOBS,
-- shared with KickCD's glow slots); `pixelLength` 0 is automatic (the library sizes the lines from
-- the icon). The styles are LibCustomGlow-1.0's four.

NS.IconDefaults = NS.IconDefaults or {}
local D = NS.IconDefaults

-- The size ranges: a button's icon feeds the button's geometry; a wedge's is drawn inside the fixed
-- 44-pixel wedge (modules/Dial_Layout.lua DL.WEDGE), so its geometry never changes.
D.SIZE = { pad = { min = 12, max = 40, default = 16 }, dial = { min = 16, max = 40, default = 32 } }

D.ZOOM_MAX = 0.25
D.GLOW_STYLES = { "button", "proc", "pixel", "autocast" }
-- always: while the icon is drawn; hover: while the mouse is over it; send: for SEND_SECONDS after
-- its callout's send result (modules/Glow.lua).
D.GLOW_WHEN = { "always", "hover", "send" }

-- { key, kind, min, max, step, default, styles } in DropWatcher's knob table order.
D.GLOW_KNOBS = {
    { key = "pixelLines", kind = "slider", min = 1, max = 20, step = 1, default = 8, styles = { pixel = true } },
    { key = "pixelFrequency", kind = "slider", min = 0.05, max = 2, step = 0.05, default = 0.1, styles = { pixel = true } },
    { key = "pixelLength", kind = "slider", min = 0, max = 20, step = 1, default = 0, styles = { pixel = true } },
    { key = "pixelThickness", kind = "slider", min = 1, max = 6, step = 1, default = 1, styles = { pixel = true } },
    { key = "pixelBorder", kind = "bool", default = true, styles = { pixel = true } },
    { key = "autocastParticles", kind = "slider", min = 1, max = 12, step = 1, default = 4, styles = { autocast = true } },
    { key = "autocastFrequency", kind = "slider", min = 0.05, max = 2, step = 0.05, default = 0.125, styles = { autocast = true } },
    { key = "autocastScale", kind = "slider", min = 0.5, max = 3, step = 0.1, default = 1, styles = { autocast = true } },
    { key = "buttonFrequency", kind = "slider", min = 0.05, max = 2, step = 0.05, default = 0.25, styles = { button = true } },
    { key = "procDuration", kind = "slider", min = 0.25, max = 3, step = 0.25, default = 1, styles = { proc = true } },
    { key = "procStartAnim", kind = "bool", default = true, styles = { proc = true } },
    { key = "xOffset", kind = "slider", min = -10, max = 10, step = 1, default = 0,
      styles = { pixel = true, autocast = true, proc = true } },
    { key = "yOffset", kind = "slider", min = -10, max = 10, step = 1, default = 0,
      styles = { pixel = true, autocast = true, proc = true } },
}

--- One surface kind's `icon` table, fresh.
--- @param kind string "pad" | "dial"
--- @return table
function D.For(kind)
    local t = {
        size = D.SIZE[kind].default, zoom = 0, desaturate = false, alpha = 1,
        tint = { r = 1, g = 1, b = 1, a = 1 }, useClassColorTint = false,
        borderShow = false, borderStyle = "Solid", borderSize = 1, borderColor = { r = 0, g = 0, b = 0, a = 1 },
        useClassColorBorder = false,
        glowEnabled = false, glowWhen = "always", glowType = "pixel",
        glowColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorGlow = false,
    }
    for _, knob in ipairs(D.GLOW_KNOBS) do t[knob.key] = knob.default end
    return t
end
