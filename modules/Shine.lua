local addonName, NS = ...
-- modules/Shine.lua — the shine overlay's seam (NS.Shine, spec 2026-10-21-shine-overlay-design.md): an
-- optional glossy look over a Comms Pad button's icon or a Comms Dial slice. INSECURE visuals only:
-- textures on a button, which the client lets an addon make, color and show in combat too; it never
-- touches a secure attribute or a protected frame's geometry. Painted on Apply (out of combat), as
-- every other look is.
--
-- THE CATALOG. Six looks and None (LOOKS): Gloss cap, Glass orb, Frosted glass, Fluid glass, Bevel,
-- Rim light. Every texture is ours, written by tools/gen-shine-textures.py under media/textures/:
-- white pixels add light, black pixels add shade, alpha is how much. The client draws them in BLEND
-- mode, SetVertexColor's color tints the light (shade stays black) and its alpha is Strength.
-- Texture(kind, name) names a file: "pad" (a look, or a Fluid glass bloom), "dial" (the whole-disc
-- art a slice draws masked), "sprite" (the orb's spot and glow, the frost's streak); Edge(kind, n)
-- names the per-count edge sets ("rim" or "soft", shaped like dial-sector-<n>.tga).
--
-- RESOLVE reads a look table's flat leaves (shineLook, shineStrength, shineTint and its Use class
-- color companion, the two bloom colors and theirs; like dial.page.dotBack*) into the paint's values:
-- the look (an unknown one is None), the alpha (Strength / 100, clamped) and the colors through
-- NS.ResolveColor (THE PLAYER'S CLASS, as every pad color is).
--
-- APPLY paints a pad button's shine: `btn.qcShine`, laid over the icon (SetAllPoints) at ARTWORK
-- sublevel 5, above the icon and below the OVERLAY marks and the HIGHLIGHT hover; Fluid glass adds
-- its two tinted blooms (sublevels 6 and 7), made only when that look is chosen. A look change hides
-- whatever the new look does not draw, and an icon that is hidden or has no texture (a text-only
-- button style) draws no shine. Nothing here is pad-specific, so a later lift into LibKa0s is a move
-- (the spec's re-check trigger: a second Ka0s addon wants a button shine). The dial's slice shine
-- lives in modules/Dial_Slices.lua, beside the fills it follows.

NS.Shine = NS.Shine or {}
local Sh = NS.Shine

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\textures\\"
local MAX_SLICES = 12   -- the edge sets' counts (DL.MAX_SLICES; the generator writes 1..12)

Sh.LOOKS = { "none", "gloss", "orb", "frost", "fluid", "bevel", "rim" }
local KNOWN = {}
for _, look in ipairs(Sh.LOOKS) do KNOWN[look] = true end

-- Every file the generator writes but the edge sets, by kind and name.
local FILES = {
    pad = { gloss = true, orb = true, frost = true, fluid = true, bevel = true, rim = true,
        ["fluid-bloom1"] = true, ["fluid-bloom2"] = true },
    dial = { gloss = true, bevel = true, ["fluid-bloom1"] = true, ["fluid-bloom2"] = true },
    sprite = { spot = true, glow = true, streak = true },
}
local EDGE = { rim = "rim", soft = "soft", ["edge-rim"] = "rim", ["edge-soft"] = "soft" }

Sh.STRENGTH = 85
Sh.TINT = { r = 1, g = 1, b = 1, a = 1 }
Sh.BLOOM_A = { r = 1, g = 0.604, b = 0.835, a = 1 }     -- #ff9ad5
Sh.BLOOM_B = { r = 0.541, g = 1, b = 0.757, a = 1 }     -- #8affc1

local SUB_SHINE, SUB_BLOOM1, SUB_BLOOM2 = 5, 6, 7

--- The edge texture of kind "rim" or "soft" for one slice of an n-slice dial (n clamped to 1..12).
function Sh.Edge(kind, n)
    local set = EDGE[kind]
    if not set then return nil end
    n = math.max(1, math.min(MAX_SLICES, math.floor(tonumber(n) or 1)))
    return MEDIA .. "shine-edge-" .. set .. "-" .. n
end

--- The media path of one shine texture, or nil (None, an unknown look, a name the kind has no file
--- for). "edge-rim" and "edge-soft" take the slice count as `name` (Edge).
function Sh.Texture(kind, name)
    if EDGE[kind] then return Sh.Edge(kind, name) end
    local names = FILES[kind]
    if not names or not names[name] then return nil end
    if kind == "sprite" then return MEDIA .. "shine-" .. name end
    return MEDIA .. "shine-" .. kind .. "-" .. name
end

local function rgb(stored, useClass, fallback)
    local r, g, b = NS.ResolveColor(stored or fallback, useClass == true)
    return { r, g, b }
end

--- A look table's shine leaves as the paint takes them: { look, alpha, tint, bloomA, bloomB }, each
--- color { r, g, b }.
function Sh.Resolve(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local look = KNOWN[cfg.shineLook] and cfg.shineLook or "none"
    local strength = tonumber(cfg.shineStrength) or Sh.STRENGTH
    return {
        look = look,
        alpha = math.max(0, math.min(100, strength)) / 100,
        tint = rgb(cfg.shineTint, cfg.useClassColorShineTint, Sh.TINT),
        bloomA = rgb(cfg.shineBloomA, cfg.useClassColorShineBloomA, Sh.BLOOM_A),
        bloomB = rgb(cfg.shineBloomB, cfg.useClassColorShineBloomB, Sh.BLOOM_B),
    }
end

-- The button's layer `key`, made on first use, over the icon.
local function layer(btn, key, sub)
    local t = btn[key]
    if not t then
        t = btn:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetBlendMode("BLEND")
        btn[key] = t
    end
    return t
end

local function paint(t, icon, path, color, alpha)
    t:SetAllPoints(icon)
    t:SetTexture(path)
    t:SetVertexColor(color[1], color[2], color[3], alpha)
    t:Show()
end

local function hide(btn, key)
    if btn[key] then btn[key]:Hide() end
end

local function drawn(icon)
    return icon ~= nil and icon:IsShown() and icon:GetTexture() ~= nil
end

--- Paints `shine` (a Resolve result; nil or None draws nothing) on `btn` over `icon`.
function Sh.Apply(btn, icon, shine)
    local path = shine and Sh.Texture("pad", shine.look)
    if not path or not drawn(icon) then
        hide(btn, "qcShine")
        hide(btn, "qcShineBloom1")
        hide(btn, "qcShineBloom2")
        return
    end
    paint(layer(btn, "qcShine", SUB_SHINE), icon, path, shine.tint, shine.alpha)
    if shine.look == "fluid" then
        paint(layer(btn, "qcShineBloom1", SUB_BLOOM1), icon, Sh.Texture("pad", "fluid-bloom1"), shine.bloomA, shine.alpha)
        paint(layer(btn, "qcShineBloom2", SUB_BLOOM2), icon, Sh.Texture("pad", "fluid-bloom2"), shine.bloomB, shine.alpha)
    else
        hide(btn, "qcShineBloom1")
        hide(btn, "qcShineBloom2")
    end
end
