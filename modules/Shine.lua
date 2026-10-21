local addonName, NS = ...
-- modules/Shine.lua — the shine overlay's seam (NS.Shine, spec 2026-10-21-shine-overlay-design.md): an
-- optional glossy look over a whole Comms Pad button or a Comms Dial slice. INSECURE visuals only:
-- textures on a button, which the client lets an addon make, color and show in combat too; it never
-- touches a secure attribute or a protected frame's geometry. Painted on Apply (out of combat), as
-- every other look is.
--
-- THE CATALOG. Six looks and None (LOOKS): Gloss cap, Glass orb, Frosted glass, Fluid glass, Bevel,
-- Rim light. Every texture is ours, written by tools/gen-shine-textures.py under media/textures/:
-- white pixels add light, black pixels add shade, alpha is how much. The client draws them in BLEND
-- mode, SetVertexColor's color tints the light (shade stays black) and its alpha is Strength.
-- Texture(kind, name) names a file: "pad" (a look, or a Fluid glass bloom), "dial" (the whole-disc
-- art a slice draws masked), "sprite" (the orb's bead, spot and glow); Edge(kind, n) names the
-- per-count edge sets ("rim", each slice's outline, or "streak", Frosted glass's light along its arc;
-- shaped like dial-sector-<n>.tga).
--
-- RESOLVE reads a look table's flat leaves (shineLook, shineStrength, shineTint and its Use class
-- color companion, the two bloom colors and theirs; like dial.page.dotBack*) into the paint's values:
-- the look (an unknown one is None), the alpha (Strength / 100, clamped) and the colors through
-- NS.ResolveColor (THE PLAYER'S CLASS, as every pad color is).
--
-- APPLY paints a pad button's shine over the WHOLE button (owner, 2026-10-21: the plate, the icon and
-- the label's chip, not the icon alone), at ARTWORK sublevel 5: above the icon, below the OVERLAY
-- label, marks and veils and the HIGHLIGHT hover. A button is a wide chip (120 x 24) and the art is
-- square, so each layer is three pieces, as the dial's pills are: the art's left half as a cap half
-- the button's height wide, its middle column stretched across, and its right half; the caps keep
-- the art's edges (a rim, a bevel, the orb's spot) as thin as on a square, and a square button
-- (icon only) is the art whole, no middle. Fluid glass adds its two tinted blooms (sublevels 6 and
-- 7), made only when that look is chosen. A look change hides whatever the new look does not draw.
-- Nothing here is pad-specific, so a later lift into LibKa0s is a move (the spec's re-check
-- trigger: a second Ka0s addon wants a button shine). The dial's slice shine lives in
-- modules/Dial_Slices.lua, beside the fills it follows.

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
    dial = { gloss = true, bevel = true, ["bevel-edge"] = true, rim = true, ["fluid-bloom1"] = true,
        ["fluid-bloom2"] = true },
    sprite = { spot = true, glow = true, bead = true },
}
local EDGE = { rim = "rim", streak = "streak", ["edge-rim"] = "rim", ["edge-streak"] = "streak" }

Sh.STRENGTH = 85
Sh.TINT = { r = 1, g = 1, b = 1, a = 1 }
Sh.BLOOM_A = { r = 1, g = 0.604, b = 0.835, a = 1 }     -- #ff9ad5
Sh.BLOOM_B = { r = 0.541, g = 1, b = 0.757, a = 1 }     -- #8affc1

local SUB_SHINE, SUB_BLOOM1, SUB_BLOOM2 = 5, 6, 7

--- The edge texture of kind "rim" or "streak" for one slice of an n-slice dial (n clamped to 1..12).
function Sh.Edge(kind, n)
    local set = EDGE[kind]
    if not set then return nil end
    n = math.max(1, math.min(MAX_SLICES, math.floor(tonumber(n) or 1)))
    return MEDIA .. "shine-edge-" .. set .. "-" .. n
end

--- The media path of one shine texture, or nil (None, an unknown look, a name the kind has no file
--- for). "edge-rim" and "edge-streak" take the slice count as `name` (Edge).
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

-- The art's three columns (texcoords): its left half, its middle, its right half.
local PIECES = { left = { 0, 0.5 }, mid = { 0.49, 0.51 }, right = { 0.5, 1 } }

-- The button's layer `key`, three pieces made on first use.
local function layer(btn, key, sub)
    local set = btn[key]
    if not set then
        set = {}
        for name, tc in pairs(PIECES) do
            local t = btn:CreateTexture(nil, "ARTWORK", nil, sub)
            t:SetBlendMode("BLEND")
            t:SetTexCoord(tc[1], tc[2], 0, 1)
            set[name] = t
        end
        btn[key] = set
    end
    return set
end

-- One layer over the whole `w` x `h` button: the caps on its corners, each half the shorter side
-- wide, and the middle between them while the button is wider than it is tall.
local function paint(set, btn, path, color, alpha, w, h)
    local cap = math.min(w, h) / 2
    local left, mid, right = set.left, set.mid, set.right
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    left:SetSize(cap, h)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    right:SetSize(cap, h)
    mid:ClearAllPoints()
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    for _, t in pairs(set) do
        t:SetTexture(path)
        t:SetVertexColor(color[1], color[2], color[3], alpha)
    end
    left:Show()
    right:Show()
    mid:SetShown(w > h)
end

local function hide(btn, key)
    local set = btn[key]
    if set then
        for _, t in pairs(set) do t:Hide() end
    end
end

--- Paints `shine` (a Resolve result; nil or None draws nothing) over the whole of `btn`, drawn `w` x
--- `h` (its own size when not given).
function Sh.Apply(btn, shine, w, h)
    local path = shine and Sh.Texture("pad", shine.look)
    w = tonumber(w) or btn:GetWidth() or 0
    h = tonumber(h) or btn:GetHeight() or 0
    if not path or w <= 0 or h <= 0 then
        hide(btn, "qcShine")
        hide(btn, "qcShineBloom1")
        hide(btn, "qcShineBloom2")
        return
    end
    paint(layer(btn, "qcShine", SUB_SHINE), btn, path, shine.tint, shine.alpha, w, h)
    if shine.look == "fluid" then
        paint(layer(btn, "qcShineBloom1", SUB_BLOOM1), btn, Sh.Texture("pad", "fluid-bloom1"), shine.bloomA,
            shine.alpha, w, h)
        paint(layer(btn, "qcShineBloom2", SUB_BLOOM2), btn, Sh.Texture("pad", "fluid-bloom2"), shine.bloomB,
            shine.alpha, w, h)
    else
        hide(btn, "qcShineBloom1")
        hide(btn, "qcShineBloom2")
    end
end
