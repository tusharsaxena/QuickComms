-- tests/test_dial_shine.lua — the Comms Dial's slice shine (shine overlay, 2026-10-21; plan T4):
-- modules/Dial_Slices.lua's per-slice overlay sets, painted after the fills from R.Look's `shine`
-- (modules/Dial_Render.lua). Each look's recipe, the overlay following its slice's place (the gap,
-- the W/E layout of a fixed 4 with two items), the sprites in the slice's own frame, fewer slices
-- hiding the rest, and the dial's look leaving the pad alone. Its own suite, peeled from
-- tests/test_dial.lua, which sits at layout-§1's 1500-line cap.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

-- A plan for the default dial straight from slots, without Surfaces: the M+ set's first `n` callouts
-- (8 by default) baked under the current snapshot, as one group on a fixed 4.
local function planOf(NS, opts)
    opts = opts or {}
    local snap = NS.Situation.Current()
    local group = { id = T.seeded(NS, "bi.mplus"), title = "Dungeon (generic)", slots = {} }
    for i, cid in ipairs(NS.Library.Group(T.seeded(NS, "bi.mplus")).callouts) do
        if i > (opts.n or 8) then break end
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    local rings, open = NS.DialLayout.Rings({ group }, { slices = opts.slices or 4, title = "Comms Dial" })
    return { kind = "dial", surfaceId = "d2", snapshot = snap, order = { T.seeded(NS, "bi.mplus") }, active = {},
        rings = rings, openRing = open }
end

local function near(a, b, what)
    assertTrue(type(a) == "number" and math.abs(a - b) < 0.01, ("%s: %s vs %s"):format(what, tostring(a), tostring(b)))
end
-- ── the slices' shine overlay (shine overlay, 2026-10-21) ─────────────────────────────────────

-- The layers a set may hold, and the retired ones (the orb's spot and glow, Bevel's upright outline
-- and its rim mask), which no look may make any more.
local SHINE_KEYS = { "disc", "mask", "bevel", "rim", "streak", "bead", "bloom1", "bloom2", "spot", "glow", "edge",
    "rimMask" }

-- Each look's layers on a slice of an n-slice ring: { texture, level, color } (the mockup's SVG
-- recipe, the spec's "Dial slices"; color nil is the tint, white by default).
local function recipeOf(Sh, look, n)
    local rim = Sh.Edge("rim", n)
    local black = { 0, 0, 0 }
    if look == "gloss" then
        return { disc = { Sh.Texture("dial", "gloss"), 1 }, rim = { rim, 0.6, black } }
    elseif look == "orb" then
        -- red under: the spot and glow sprites (owner, 2026-10-21: no dots), the bead tinted black
        return { bead = { Sh.Texture("sprite", "bead"), 1 }, rim = { rim, 0.6, black } }
    elseif look == "frost" then
        -- red under: the flat WHITE8x8 wash
        return { disc = { Sh.Texture("dial", "frost"), 1 }, rim = { rim, 0.35 },
            streak = { Sh.Edge("streak", n), 1 } }
    elseif look == "fluid" then
        -- red under: the whole-disc blooms (the muddy ring)
        return { bloom1 = { Sh.Texture("sprite", "fluid-bloom1"), 1, { 1, 0.604, 0.835 } },
            bloom2 = { Sh.Texture("sprite", "fluid-bloom2"), 1, { 0.541, 1, 0.757 } }, rim = { rim, 0.3 } }
    elseif look == "bevel" then
        -- red under: one dial-wide light (the upright disc and outline)
        return { bevel = { Sh.Edge("bevel", n), 1 } }
    elseif look == "rim" then
        return { disc = { Sh.Texture("dial", "rim"), 0.3 }, rim = { rim, 0.5 } }
    end
    return {}
end

local function shineDial(NS, look, opts)
    assertTrue(NS.SchemaRuntime.Set("dial.slice.shineLook", look, "d2"))
    if opts and opts.gap then assertTrue(NS.SchemaRuntime.Set("dial.slice.gap", opts.gap, "d2")) end
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, opts)))
    local rings = NS.Dial.Instance("d2").rings.active
    if opts and opts.n then   -- the ring that holds the n callouts
        for _, ring in ipairs(rings) do
            if #(ring.qcSpec.items or {}) == opts.n then return ring end
        end
    end
    return rings[2]   -- page 1 of 2, four callouts
end

local function sliceAngle(shape, j)
    return math.rad(shape.start) + (j - 1) * 2 * math.pi / shape.size
end

test("dial: [shine] each look builds its recipe on every slice", function()
    local NS = live()
    local Sh = NS.Shine
    for _, look in ipairs({ "gloss", "orb", "frost", "fluid", "bevel", "rim" }) do
        local ring = shineDial(NS, look)
        local shape = ring.qcShape
        assertEqual(shape.size, 4, look .. ": a 4-slice ring")
        -- red under: no paintShine in modules/Dial_Slices.lua S.Paint
        assertTrue(type(ring.qcShine) == "table", look .. ": the overlay sets")
        for j = 1, 4 do
            local set = ring.qcShine[j]
            assertTrue(set ~= nil, look .. ": slice " .. j .. " has its set")
            local want = recipeOf(Sh, look, 4)
            for _, k in ipairs(SHINE_KEYS) do
                local t, w = set[k], want[k]
                local what = ("%s slice %d %s"):format(look, j, k)
                if k == "mask" then
                    local masked = want.disc or want.bloom1 or want.bead
                    assertEqual(t ~= nil and t:IsShown() or false, masked and true or false, what)
                    if masked then assertEqual(t.__texture, NS.DialSlices.SectorTexture(4), what .. ": the slice's sector") end
                elseif w then
                    assertTrue(t ~= nil and t:IsShown(), what .. " shown")
                    assertEqual(t.__texture, w[1], what .. " texture")
                    assertEqual(t.__layer, "BACKGROUND", what .. " layer")
                    assertTrue(t.__sublevel >= 3 and t.__sublevel <= 6, what .. " above the fill and the highlight")
                    local c = w[3] or { 1, 1, 1 }
                    for i = 1, 3 do near(t.__color[i], c[i], what .. " color " .. i) end
                    near(t.__color[4], w[2] * 0.85, what .. " alpha: level x Strength")
                else
                    assertTrue(t == nil or not t:IsShown(), what .. " hidden")
                end
            end
            for _, k in ipairs({ "disc", "bloom1", "bloom2", "bead" }) do
                if set[k] and set[k]:IsShown() then
                    local masks = set[k].__masks or {}
                    assertTrue(masks[1] == set.mask and #masks == 1, look .. " " .. k .. ": masked by its slice")
                end
            end
            if set.bevel and set.bevel:IsShown() then
                assertEqual(#(set.bevel.__masks or {}), 0, look .. " bevel: slice-shaped art, no mask")
            end
        end
    end
end)

test("dial: [shine] the overlay follows the slice", function()
    local NS = live()
    local function sameAs(t, fill, what)
        assertEqual(table.concat(t.__size, ","), table.concat(fill.__size, ","), what .. ": the fill's size")
        local _, rel, _, x, y = t:GetPoint(1)
        local _, frel, _, fx, fy = fill:GetPoint(1)
        assertTrue(rel == frel, what .. ": on the ring")
        near(x, fx, what .. " x")
        near(y, fy, what .. " y")
        near(t.__rotation, fill.__rotation, what .. " rotation")
    end
    for _, case in ipairs({ { gap = 8 }, { n = 2 } }) do
        for _, look in ipairs({ "gloss", "bevel" }) do
            local ring = shineDial(NS, look, case)
            local spec = ring.qcSpec
            if case.n then
                assertEqual(spec.size, 4, "a fixed 4 with two items")
                assertEqual(#spec.items, 2)
            end
            for j = 1, spec.size do
                local set, fill = ring.qcShine[j], ring.qcFills[j]
                local what = ("%s gap=%s n=%s slice %d"):format(look, tostring(case.gap), tostring(case.n), j)
                -- red under: the overlay anchored at the ring's center, not placed by place()
                if look == "bevel" then
                    -- every slice the same bevel (owner, 2026-10-21): turned with its slice, not upright
                    sameAs(set.bevel, fill, what .. " bevel")
                else
                    sameAs(set.mask, fill, what .. " mask")
                    sameAs(set.disc, fill, what .. " disc")
                    sameAs(set.rim, fill, what .. " rim")
                end
            end
        end
        assertTrue(NS.SchemaRuntime.Set("dial.slice.gap", 0, "d2"))
    end
end)

test("dial: [shine] the orb's bead sits on the slice's inscribed circle, with no dots", function()
    local NS = live()
    local S = NS.DialSlices
    for _, n in ipairs({ 2, 4, 8, 12 }) do
        local sp = S.OrbSprites(n)
        local s = math.sin(math.pi / n)
        local c, p = 1 / (1 + s), s / (1 + s)
        near(sp.bead.out, c, n .. ": the bead on the circle's center")
        near(sp.bead.w, 7 * p, n .. ": the bead's vignette covers the slice")
        -- red under: the spot and glow sprites (owner, 2026-10-21: they read as a dot on every slice)
        assertTrue(sp.spot == nil and sp.glow == nil, n .. ": no specular dots")
    end
    local four = S.OrbSprites(4)
    near(four.bead.out, 0.586, "a quarter: the mockup's bead at 0.6")
    local one = S.OrbSprites(1)
    near(one.bead.out, 0, "one slice: the bead is the disc")
    near(one.bead.w, 7, "one slice: the whole disc's bead")
end)

test("dial: [shine] fluid's blooms span the slice's outer part", function()
    local NS = live()
    local S = NS.DialSlices
    -- red under: no S.FluidSprites (the blooms whole-disc art)
    for _, n in ipairs({ 3, 4, 8, 12 }) do
        local sp = S.FluidSprites(n)
        local w = 2 * math.sin(math.pi / n)
        for _, k in ipairs({ "bloom1", "bloom2" }) do
            near(sp[k].w, w, n .. " " .. k .. ": as wide as the slice's chord at the rim")
            near(sp[k].out + sp[k].w / 2, 1, n .. " " .. k .. ": its top on the rim")
            near(sp[k].x, 0, n .. " " .. k .. ": centered across the slice")
            near(sp[k].turn, 0, n .. " " .. k .. ": square to the slice")
        end
    end
    for _, n in ipairs({ 1, 2 }) do
        near(S.FluidSprites(n).bloom1.w, 2, n .. ": the whole disc")
        near(S.FluidSprites(n).bloom1.out, 0, n .. ": centered on it")
    end
end)

test("dial: [shine] sprites sit in the slice's frame", function()
    local NS = live()
    for _, case in ipairs({ { gap = 0, look = "orb" }, { gap = 8, look = "orb" }, { gap = 0, n = 8, slices = 8, look = "orb" },
        { gap = 8, look = "fluid" }, { gap = 0, n = 8, slices = 8, look = "fluid" } }) do
        local ring = shineDial(NS, case.look, case)
        local shape = ring.qcShape
        local R, d = (shape.disc - 2 * shape.shift) / 2, shape.shift
        local sprites = case.look == "orb" and NS.DialSlices.OrbSprites(shape.size)
            or NS.DialSlices.FluidSprites(shape.size)
        local function at(t, sp, a, what)
            local px = (d + sp.out * R) * math.sin(a) + sp.x * R * math.cos(a)
            local py = (d + sp.out * R) * math.cos(a) - sp.x * R * math.sin(a)
            local _, _, _, x, y = t:GetPoint(1)
            near(x, px, what .. " x")
            near(y, py, what .. " y")
            near(t.__size[1], sp.w * R, what .. " width")
            near(t.__size[2], sp.w * R, what .. " height: the art is square, so a turn keeps its shape")
            near(t.__rotation, sp.turn - a, what .. " rotation")
            local masks = t.__masks or {}
            assertTrue(masks[1] ~= nil, what .. ": cut by the slice's mask")
        end
        local sawE = false
        for j = 1, shape.size do
            local a = sliceAngle(shape, j)
            local set = ring.qcShine[j]
            local what = ("%s gap %d n %d slice %d"):format(case.look, case.gap, shape.size, j)
            for k, sp in pairs(sprites) do at(set[k], sp, a, what .. " " .. k) end
            if shape.size == 4 and math.abs(a % (2 * math.pi) - math.pi / 2) < 1e-6 then
                sawE = true
                -- the E slice: local (x, out) turned by 90 degrees is (out, -x)
                local k = case.look == "orb" and "bead" or "bloom1"
                local _, _, _, px, py = set[k]:GetPoint(1)
                near(px, d + sprites[k].out * R, "E " .. k .. " x")
                near(py, -sprites[k].x * R, "E " .. k .. " y")
            end
        end
        if shape.size == 4 then assertTrue(sawE, "the ring has an E slice") end
    end
end)

test("dial: [shine] frost's streak and Bevel are each slice's own edge set", function()
    local NS = live()
    for _, case in ipairs({ { "frost", "streak" }, { "bevel", "bevel" } }) do
        for _, n in ipairs({ 4, 8 }) do
            local ring = shineDial(NS, case[1], n == 8 and { n = 8, slices = 8 } or nil)
            assertEqual(ring.qcShape.size, n)
            for j = 1, n do
                local t = ring.qcShine[j][case[2]]
                local what = ("%s %d slice %d"):format(case[1], n, j)
                -- red under: the straight streak sprite; Bevel's one upright light for the whole dial
                assertEqual(t.__texture, NS.Shine.Edge(case[2], n), what)
                assertEqual(table.concat(t.__size, ","), table.concat(ring.qcFills[j].__size, ","),
                    what .. ": placed as the fill")
                near(t.__rotation, ring.qcFills[j].__rotation, what .. ": turned as the fill")
            end
        end
    end
end)

test("dial: [shine] fewer slices hide the rest", function()
    local NS = live()
    local S = NS.DialSlices
    local ring = shineDial(NS, "fluid")
    local function look(name)
        return NS.DialRender.Look(100, {}, { shineLook = name }, {})
    end
    local function hidden(set, what)
        for _, k in ipairs(SHINE_KEYS) do
            assertTrue(set[k] == nil or not set[k]:IsShown(), what .. " " .. k .. " hidden")
        end
    end
    for _, name in ipairs({ "fluid", "orb", "frost" }) do
        S.Paint(ring, { size = 8, start = 0, items = {} }, look(name))
        S.Paint(ring, { size = 4, start = 0, items = {} }, look(name))
        -- red under: paintShine looping only to spec.size
        for j = 5, 8 do hidden(ring.qcShine[j], name .. " place " .. j) end
        for j = 1, 4 do assertTrue(ring.qcShine[j].rim:IsShown(), name .. " " .. j) end
    end
    S.Paint(ring, { size = 4, start = 0, items = {} }, look("fluid"))
    S.Paint(ring, { size = 4, start = 0, items = {} }, look("gloss"))
    for j = 1, 4 do
        assertFalse(ring.qcShine[j].bloom1:IsShown() or ring.qcShine[j].bloom2:IsShown(), "gloss leaves no bloom")
        assertFalse(ring.qcShine[j].bead:IsShown(), "nor orb's bead")
        assertEqual(ring.qcShine[j].rim.__texture, NS.Shine.Edge("rim", 4), "the rim follows the count")
    end
    S.Paint(ring, { size = 4, start = 0, items = {} }, look("none"))
    for j = 1, 8 do hidden(ring.qcShine[j], "none place " .. j) end
    -- nothing is created at None
    local fresh = live()
    assertTrue(fresh.Dial.Apply(1, "d2", planOf(fresh)))
    for _, r in ipairs(fresh.Dial.Instance("d2").rings.active) do
        assertEqual(#r.qcShine, 0, "a dial at None makes no overlay sets")
    end
end)

test("dial: [shine] the dial's look leaves the pad alone", function()
    local NS = live()
    local ring = shineDial(NS, "orb")
    assertTrue(ring.qcShine[1].bead:IsShown(), "the dial wears its orb")
    local shown = 0
    for _, btn in ipairs(NS.Pad.Instance("p1").buttons.active) do
        if btn:IsShown() then
            shown = shown + 1
            assertTrue(btn.qcShine == nil or not btn.qcShine.left:IsShown(), "the pad at None carries no shine")
        end
    end
    assertTrue(shown > 0, "the pad has buttons")
    local look = NS.DialRender.Look(100, {}, NS.db.profile.dials.d2.slice, {})
    assertEqual(look.shine.look, "orb", "the look carries its shine")
    assertEqual(NS.db.profile.pads.p1.button.shineLook, "none")
end)
