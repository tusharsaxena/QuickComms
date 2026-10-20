local _, NS = ...
-- modules/IconStyle.lua — the Icons tab's look (B9) on a Comms Pad button's and a Comms Dial wedge's
-- icon, modeled on DropWatcher modules/IconStyle.lua: its size, crop, desaturation, alpha, tint and
-- border. INSECURE visuals only: texture calls on the icon and a plain child frame, which the client
-- allows in combat too; it never touches a secure attribute or a protected frame's geometry. A
-- button's icon size changes the button's geometry (modules/Pad_Layout.lua CellSize), so every change
-- here reaches the screen through a rebuild (LIBRARY_CHANGED -> Surfaces.Request, held behind combat
-- with the stale hint), never in combat.
--
-- CONFIG. Config reads a surface's `icon` table once per rebuild into the values the paint takes:
-- the zoom clamped, the tint and the border color resolved through their Use class color companions
-- (NS.ResolveColor: THE PLAYER'S CLASS, as every pad color is), the border's art, and the glow's
-- settings with a signature (`sig`) modules/Glow.lua compares, so a rebuild that changed nothing
-- restarts no effect.
--
-- THE TINT multiplies: a LibKa0s glyph's own color (Library.IconTint, the callout's `iconColor`)
-- times the tint, so the default white keeps every icon as it was. Its alpha joins the icon's alpha.
--
-- THE ICON FRAME is a plain BackdropTemplate child of the button laid over the icon (SetAllPoints),
-- made on first use: a button's square border is its backdrop (drawn over the icon's outer edge, as
-- DropWatcher's is), and the glow (modules/Glow.lua) is started on it, so the effect circles the
-- icon, not the whole button. A wedge is round, so its border is a ring instead: a disc of the circle
-- mask behind the icon, the icon's size plus twice the thickness, in the border's color.
--
-- SOLID, the default border style, is the client's WHITE8X8 stretched to the thickness: registered
-- with LibSharedMedia at load under AuraMaster's and DropWatcher's name (the first registration of a
-- name wins, and theirs is the same texture). Without the media library the name still draws it.
--
-- HEADLESS. Each decision is recorded on the button (`qcBorder`, the color drawn or nil;
-- `qcBorderSize`) whatever the frame answers.

NS.IconStyle = NS.IconStyle or {}
local IS = NS.IconStyle
local D = NS.IconDefaults

IS.SOLID = "Solid"
IS.SOLID_EDGE = "Interface\\Buttons\\WHITE8X8"
-- A border style no addon registers any more draws the tooltip's edge, as DropWatcher's does.
IS.BORDER_FALLBACK = "Interface\\Tooltips\\UI-Tooltip-Border"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

do
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Register then LSM:Register("border", IS.SOLID, IS.SOLID_EDGE) end
end

local function clamp(v, lo, hi, fallback)
    v = tonumber(v) or fallback
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function borderTexture(name)
    local path = NS.MediaFetch("border", name)
    if not path and name == IS.SOLID then path = IS.SOLID_EDGE end
    return path or IS.BORDER_FALLBACK
end

-- The glow's settings as modules/Glow.lua takes them, or false while it is off; `sig` names every
-- value it draws with, so an unchanged rebuild keeps the effect. A table without the knobs (the Button
-- tab's) takes their defaults; one without `glowWhen` glows always.
local function glowConfig(icon, size)
    if icon.glowEnabled ~= true then return false end
    local g = { type = icon.glowType, when = icon.glowWhen, size = size }
    g.color = { NS.ResolveColor(icon.glowColor, icon.useClassColorGlow == true) }
    local parts = { tostring(g.type), tostring(size), table.concat(g.color, ":") }
    for _, knob in ipairs(D.GLOW_KNOBS) do
        local v = icon[knob.key]
        if v == nil then v = knob.default end
        g[knob.key] = v
        parts[#parts + 1] = tostring(v)
    end
    g.sig = table.concat(parts, "|")
    return g
end

--- A glow-bearing table (a surface's `icon`, a pad's `button`) read into modules/Glow.lua's settings, or
--- false while its glow is off. `size` joins the signature.
IS.GlowConfig = glowConfig

--- A surface's `icon` table read into what a paint takes. A nil table is the kind's defaults.
--- @param icon table|nil the surface's `icon` (pad.icon / dial.icon)
--- @param kind string "pad" | "dial"
--- @return table { size, zoom, desaturate, alpha, tint = {r,g,b,a}, border = false|{...}, glow = false|{...} }
function IS.Config(icon, kind)
    local range = D.SIZE[kind] or D.SIZE.pad
    icon = type(icon) == "table" and icon or D.For(kind)
    local c = {
        kind = kind,
        size = math.floor(clamp(icon.size, range.min, range.max, range.default) + 0.5),
        zoom = clamp(icon.zoom, 0, D.ZOOM_MAX, 0),
        desaturate = icon.desaturate == true,
        alpha = clamp(icon.alpha, 0.1, 1, 1),
        tint = { NS.ResolveColor(icon.tint, icon.useClassColorTint == true) },
        border = false,
    }
    if icon.borderShow == true then
        local size = math.floor(clamp(icon.borderSize, 1, 16, 1) + 0.5)
        local r, g, b, a = NS.ResolveColor(icon.borderColor, icon.useClassColorBorder == true)
        c.border = { size = size, color = { r, g, b, a },
            backdrop = { edgeFile = borderTexture(icon.borderStyle), edgeSize = size } }
    end
    c.glow = glowConfig(icon, c.size)
    return c
end

--- Draw an icon texture with a config: crop, desaturation, the tint times the glyph color `r, g, b`
--- (white for any icon that is no glyph), and the alpha times the tint's.
function IS.ApplyIcon(tex, cfg, r, g, b)
    local z, t = cfg.zoom, cfg.tint
    tex:SetTexCoord(z, 1 - z, z, 1 - z)
    tex:SetDesaturated(cfg.desaturate)
    tex:SetVertexColor((r or 1) * t[1], (g or 1) * t[2], (b or 1) * t[3])
    tex:SetAlpha(cfg.alpha * (t[4] or 1))
end

--- The plain child frame over a button's icon (`btn.qcIcon`): the border's backdrop and the glow's
--- host. Made on first use.
function IS.IconFrame(btn)
    local f = btn.qcIconFrame
    if not f then
        f = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        f:SetAllPoints(btn.qcIcon)
        btn.qcIconFrame = f
    end
    return f
end

--- A button's square border: the icon frame's backdrop, or none. `shown` false (a label-only button)
--- draws none.
function IS.PaintBorder(btn, cfg, shown)
    local f = IS.IconFrame(btn)
    local border = shown ~= false and cfg.border or nil
    if not border then
        if f.SetBackdrop then f:SetBackdrop(nil) end
        f.__backdrop = nil
        btn.qcBorder, btn.qcBorderSize = nil, nil
        return
    end
    local c = border.color
    if f.SetBackdrop then
        f:SetBackdrop(border.backdrop)
        f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
    end
    f.__backdrop = border.backdrop
    btn.qcBorder, btn.qcBorderSize = { c[1], c[2], c[3], c[4] }, border.size
end

--- A wedge's round border: a disc of the circle mask behind the icon, the icon's size plus twice the
--- thickness but never wider than the wedge (DialLayout.WEDGE), so a thick ring on a big icon cannot
--- reach the next wedge or its label; in the border's color; hidden when the border is off.
function IS.PaintRing(btn, cfg)
    local border = cfg.border
    if not border then
        if btn.qcRing then btn.qcRing:Hide() end
        btn.qcBorder, btn.qcBorderSize = nil, nil
        return
    end
    local ring = btn.qcRing
    if not ring then
        ring = btn:CreateTexture(nil, "BORDER")
        ring:SetTexture(CIRCLE)
        ring:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.qcRing = ring
    end
    local c, d = border.color, math.min(cfg.size + 2 * border.size, NS.DialLayout.WEDGE)
    ring:SetSize(d, d)
    ring:SetVertexColor(c[1], c[2], c[3], c[4])
    ring:Show()
    btn.qcBorder, btn.qcBorderSize = { c[1], c[2], c[3], c[4] }, border.size
end
