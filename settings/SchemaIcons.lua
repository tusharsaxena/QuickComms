local _, NS = ...
-- settings/SchemaIcons.lua — the Icons tab's member rows (B9): how a Comms Pad's buttons and a Comms
-- Dial's wedges draw their icons, one set of rows per kind under `pad.icon.*` and `dial.icon.*`
-- (flat leaves, so Library's fillShape backfills them; defaults/Icons.lua holds the values). Drawn
-- by the Icons tab of each editor (settings/Pads.lua, settings/Dials.lua), each block under its own
-- heading, which the options library draws from the rows' subgroup:
--
--     Size and crop   Icon size, Zoom
--     Color           Desaturate, Icon opacity, then Tint and its Use class color companion
--     Border          the composed block (O.BorderGroup with its Show border toggle, options-ui-§16)
--     Glow            Glow, Glow when, Glow style, then Glow color and its Use class color companion
--     Offset          Glow X offset, Glow Y offset (always drawn, right after Glow; owner request
--                     2026-10-20, it closed the tab until then)
--     the selected style's knobs, under that style's heading (DropWatcher's knob table): Pixel border,
--                     Auto cast sparkles, Button (rotating rays) or Proc (flipbook)
--
-- Every color pair is O.ColorPair (options-ui-§17; THE PLAYER'S CLASS: a button is about no unit) and
-- is never dimmed (anti-pattern #74: the swatch's alpha is read under either mode). Border style and
-- thickness are dimmed while Show border is off; Glow when, Glow style and the offsets while the glow
-- is off, and an offset also while the glow is in a style it does not apply to (Button).
--
-- A style's knobs show only while the glow is on and in that style (owner request, 2026-10-20): the
-- rows stay in the schema (Defaults, a share import, /qc set and list still reach every knob), and
-- the tab's render filters them through Settings.ShownIconRows. Glow and Glow style are structural
-- (settings/Editors.lua Ed.STRUCTURAL), so a write to either repaints the tab, its scroll kept, and
-- the right heading appears. The options library has no hidden-row field to say this in the row.
--
-- settings/SchemaMembers.lua calls Settings.IconRows with its checks and splices the rows into its
-- own list (a pad's after its Look rows; a dial's after its Group labels rows and its Icon offset
-- row, so the Icons tab follows Group labels and opens with Icon offset under Size and crop, dial
-- polish 2026-10-21), where its loop gives each row the member rows' reaction, Library.Touch: the surfaces
-- rebuild through LIBRARY_CHANGED, at combat end when they must. On a degraded load the composers are
-- hollow and the composed rows are absent; modules/IconStyle.lua then reads the stored values or the
-- defaults.

local L = NS.L
local D = NS.IconDefaults

local ICONS = L["Icons"]
local SIZE_CROP = L["Size and crop"]
local COLOR = L["Color"]
local BORDER = L["Border"]
local GLOW = L["Glow"]

local WHEN = { { "always", L["Always"] }, { "hover", L["On hover"] }, { "send", L["After sending"] } }
local STYLES = { { "pixel", L["Pixel border"] }, { "autocast", L["Auto cast sparkles"] },
    { "button", L["Button (rotating rays)"] }, { "proc", L["Proc (flipbook)"] } }
-- The Buttons tab's Glow style takes the same four (settings/SchemaMembers.lua).
NS.addon.Settings.GLOW_STYLES = STYLES

-- Each knob's heading, label and tooltip, keyed by its defaults/Icons.lua entry.
local KNOB_TEXT = {
    pixelLines = { L["Pixel border"], L["Lines"], L["How many lines run around the icon. Pixel border only."] },
    pixelFrequency = { L["Pixel border"], L["Line speed"],
        L["How fast the lines run around the icon. Higher is faster. Pixel border only."] },
    pixelLength = { L["Pixel border"], L["Line length (0 = automatic)"],
        L["How long each line is, in pixels. 0 sizes the lines from the icon. Pixel border only."] },
    pixelThickness = { L["Pixel border"], L["Line thickness"], L["How thick each line is, in pixels. Pixel border only."] },
    pixelBorder = { L["Pixel border"], L["Dark border"], L["Draw a dark border inside the lines. Pixel border only."] },
    autocastParticles = { L["Auto cast sparkles"], L["Sparkles"],
        L["How many sparkles circle the icon in each ring. Auto cast sparkles only."] },
    autocastFrequency = { L["Auto cast sparkles"], L["Sparkle speed"],
        L["How fast the sparkles circle the icon. Higher is faster. Auto cast sparkles only."] },
    autocastScale = { L["Auto cast sparkles"], L["Sparkle size"], L["How big the sparkles are. Auto cast sparkles only."] },
    buttonFrequency = { L["Button (rotating rays)"], L["Ray speed"],
        L["How fast the rays turn. Higher is faster. Button (rotating rays) only."] },
    procDuration = { L["Proc (flipbook)"], L["Loop duration (seconds)"],
        L["How many seconds one loop of the flipbook takes. Proc (flipbook) only."] },
    procStartAnim = { L["Proc (flipbook)"], L["Start animation"],
        L["Play the burst that opens the proc glow when it starts. Proc (flipbook) only."] },
    xOffset = { L["Offset"], L["Glow X offset"],
        L["How far the glow reaches past the icon's sides, in pixels. Pixel border, Proc and Auto cast styles."] },
    yOffset = { L["Offset"], L["Glow Y offset"],
        L["How far the glow reaches past the icon's top and bottom, in pixels. Pixel border, Proc and Auto cast styles."] },
}

-- What each kind's rows say about where the icon is.
local WHERE = {
    pad = { page = "pads", size = L["How big each button's icon is, in pixels. A bigger icon makes the buttons taller."],
        when = L["Always, while the mouse is over the icon, or for a moment after its callout is sent."] },
    dial = { page = "dials", size = L["How big each wedge's icon is, in pixels. The wedges keep their size."],
        when = L["Always, while the mouse is over the icon, or for a moment after its callout is sent. The dial closes on a send, so that moment runs from the next time you open it, within a few seconds."] },
}

local function get(path) return NS.SchemaRuntime.Get(path) end

-- A style's knob row's path -> the styles it applies to (the offsets are no style's: always drawn).
local KNOB_STYLES = {}
local OFFSETS = { xOffset = true, yOffset = true }

--- One kind's Icons rows, in tab order.
--- @param kind string "pad" | "dial"
--- @param C table settings/SchemaMembers.lua's checks
--- @return table rows
function NS.addon.Settings.IconRows(kind, C)
    local O = NS.addon.Settings.Helpers
    local P = kind .. ".icon."
    local T = D.For(kind)
    local where = WHERE[kind]
    local rows = {}
    local function at(subgroup, row)
        row.instance, row.page, row.group, row.subgroup = kind, where.page, ICONS, subgroup
        rows[#rows + 1] = row
        return row
    end
    local function glowOff() return get(P .. "glowEnabled") ~= true end
    local function borderOff() return get(P .. "borderShow") ~= true end
    local range = D.SIZE[kind]
    local WHEN_VALUES, STYLE_VALUES = C.choices(WHEN), C.choices(STYLES)

    at(SIZE_CROP, { path = P .. "size", type = "number", default = T.size, min = range.min, max = range.max, step = 1,
        label = L["Icon size"], desc = where.size, validate = C.NUMBER, normalize = C.clamp(range.min, range.max, true) })
    at(SIZE_CROP, { path = P .. "zoom", type = "number", default = T.zoom, min = 0, max = D.ZOOM_MAX, step = 0.01,
        label = L["Zoom"], validate = C.NUMBER, normalize = C.clamp(0, D.ZOOM_MAX),
        desc = L["Crop the icon's edges: 0 shows the whole icon, 0.25 crops a quarter off each side. A little zoom trims the dark edge baked into most game icons."] })
    at(COLOR, { path = P .. "desaturate", type = "bool", default = T.desaturate, label = L["Desaturate"],
        desc = L["Draw the icons in gray."], validate = C.BOOL })
    at(COLOR, { path = P .. "alpha", type = "number", default = T.alpha, min = 0.1, max = 1, step = 0.05,
        label = L["Icon opacity"], desc = L["How opaque the icons are."], validate = C.NUMBER, normalize = C.clamp(0.1, 1) })

    local spec = function(subgroup, extra)
        local s = { prefix = P, page = where.page, group = ICONS, subgroup = subgroup, defaults = T }
        for k, v in pairs(extra or {}) do s[k] = v end
        return s
    end
    local composed = {
        { COLOR, O.ColorPair(spec(COLOR, { key = "tint", label = L["Tint"] })) },
        { BORDER, O.BorderGroup(spec(BORDER, { show = true })) },
    }
    local checks = {
        tint = { validate = C.color, normalize = C.fourChannels },
        useClassColorTint = { validate = C.BOOL },
        borderShow = { validate = C.BOOL, tooltip = L["Draw a border around each icon."] },
        borderStyle = { validate = C.name, disabledIf = borderOff },
        borderSize = { validate = C.NUMBER, normalize = C.clamp(1, 16, true), min = 1, disabledIf = borderOff },
        borderColor = { validate = C.color, normalize = C.fourChannels },
        useClassColorBorder = { validate = C.BOOL },
        glowColor = { validate = C.color, normalize = C.fourChannels },
        useClassColorGlow = { validate = C.BOOL },
    }
    local function stamp(list, subgroup)
        for _, row in ipairs(list) do
            local c = checks[row.path:sub(#P + 1)] or {}
            for k, v in pairs(c) do row[k] = v end
            at(subgroup, row)
        end
    end
    for _, pair in ipairs(composed) do stamp(pair[2], pair[1]) end

    at(GLOW, { path = P .. "glowEnabled", type = "bool", default = T.glowEnabled, label = L["Glow"],
        desc = L["Draw a glow around each icon."], validate = C.BOOL, startsLine = true })
    at(GLOW, { path = P .. "glowWhen", type = "string", default = T.glowWhen, values = WHEN_VALUES, label = L["Glow when"],
        desc = where.when, validate = C.oneOf(WHEN_VALUES), disabledIf = glowOff })
    at(GLOW, { path = P .. "glowType", type = "string", default = T.glowType, values = STYLE_VALUES, label = L["Glow style"],
        desc = L["How the glow looks."], validate = C.oneOf(STYLE_VALUES), disabledIf = glowOff })
    stamp(O.ColorPair(spec(GLOW, { key = "glowColor", companionKey = "useClassColorGlow", label = L["Glow color"] })), GLOW)

    local function knobRow(knob)
        local text = KNOB_TEXT[knob.key]
        local styles = knob.styles
        local row = { path = P .. knob.key, default = knob.default, label = text[2], desc = text[3],
            disabledIf = function() return glowOff() or not styles[get(P .. "glowType")] end }
        if knob.kind == "bool" then
            row.type, row.validate = "bool", C.BOOL
        else
            row.type, row.min, row.max, row.step = "number", knob.min, knob.max, knob.step
            row.validate, row.normalize = C.NUMBER, C.clamp(knob.min, knob.max, knob.step >= 1)
            if knob.key == "pixelLength" then row.zeroText = L["Automatic"] end
        end
        if not OFFSETS[knob.key] then KNOB_STYLES[row.path] = styles end
        at(text[1], row)
    end
    -- The offsets first, right after Glow; then each style's knobs in the knob table's order.
    for _, knob in ipairs(D.GLOW_KNOBS) do
        if OFFSETS[knob.key] then knobRow(knob) end
    end
    for _, knob in ipairs(D.GLOW_KNOBS) do
        if not OFFSETS[knob.key] then knobRow(knob) end
    end
    return rows
end

--- The Icons tab's rows to draw: every row but a style's knobs while the glow is off or in another
--- style. Its kind's Glow and Glow style are read for the member the page has selected.
--- @param rows table the tab's rows
--- @return table rows
function NS.addon.Settings.ShownIconRows(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
        local styles = KNOB_STYLES[row.path]
        local show = styles == nil
        if not show then
            local P = row.instance .. ".icon."
            show = get(P .. "glowEnabled") == true and styles[get(P .. "glowType")] == true
        end
        if show then out[#out + 1] = row end
    end
    return out
end
