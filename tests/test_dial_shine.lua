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

local SHINE_KEYS = { "disc", "mask", "rim", "soft", "spot", "glow", "streak", "bloom1", "bloom2" }

-- Each look's layers on a slice of an n-slice ring at middle angle `a`: { texture, level, color }
-- (the plan's recipe table; color nil is the tint, white by default).
local function recipeOf(Sh, look, n, a)
    local rim, soft = Sh.Edge("rim", n), Sh.Edge("soft", n)
    local black = { 0, 0, 0 }
    if look == "gloss" then
        return { disc = { Sh.Texture("dial", "gloss"), 1 }, rim = { rim, 0.30 } }
    elseif look == "orb" then
        return { soft = { soft, 0.50, black }, glow = { Sh.Texture("sprite", "glow"), 0.45 },
            spot = { Sh.Texture("sprite", "spot"), 1 } }
    elseif look == "frost" then
        return { disc = { "Interface\\Buttons\\WHITE8x8", 0.09 }, rim = { rim, 0.55 },
            streak = { Sh.Texture("sprite", "streak"), 1 } }
    elseif look == "fluid" then
        return { bloom1 = { Sh.Texture("dial", "fluid-bloom1"), 1, { 1, 0.604, 0.835 } },
            bloom2 = { Sh.Texture("dial", "fluid-bloom2"), 1, { 0.541, 1, 0.757 } }, rim = { rim, 0.35 } }
    elseif look == "bevel" then
        local c = math.cos(a - math.rad(315))
        return { disc = { Sh.Texture("dial", "bevel"), 1 },
            rim = { rim, 0.25 + 0.45 * math.abs(c), c >= 0 and { 1, 1, 1 } or black } }
    elseif look == "rim" then
        return { soft = { soft, 0.35 }, rim = { rim, 0.60 } }
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
            local want = recipeOf(Sh, look, 4, sliceAngle(shape, j))
            for _, k in ipairs(SHINE_KEYS) do
                local t, w = set[k], want[k]
                local what = ("%s slice %d %s"):format(look, j, k)
                if k == "mask" then
                    local masked = want.disc or want.bloom1 or want.spot or want.streak
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
            for _, k in ipairs({ "disc", "bloom1", "bloom2", "spot", "glow", "streak" }) do
                if set[k] and set[k]:IsShown() then
                    local masks = set[k].__masks or {}
                    assertTrue(masks[1] == set.mask, look .. " " .. k .. ": masked by its slice")
                end
            end
        end
    end
end)

test("dial: [shine] the overlay follows the slice", function()
    local NS = live()
    local function sameAs(t, fill, what, upright)
        assertEqual(table.concat(t.__size, ","), table.concat(fill.__size, ","), what .. ": the fill's size")
        local _, rel, _, x, y = t:GetPoint(1)
        local _, frel, _, fx, fy = fill:GetPoint(1)
        assertTrue(rel == frel, what .. ": on the ring")
        near(x, fx, what .. " x")
        near(y, fy, what .. " y")
        near(t.__rotation, upright and 0 or fill.__rotation, what .. " rotation")
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
                sameAs(set.rim, fill, what .. " rim")
                sameAs(set.mask, fill, what .. " mask")
                sameAs(set.disc, fill, what .. " disc", look == "bevel")
            end
        end
        assertTrue(NS.SchemaRuntime.Set("dial.slice.gap", 0, "d2"))
    end
end)

test("dial: [shine] sprites sit in the slice's frame", function()
    local NS = live()
    for _, gap in ipairs({ 0, 8 }) do
        local ring = shineDial(NS, "orb", { gap = gap })
        local shape = ring.qcShape
        local R, d = (shape.disc - 2 * shape.shift) / 2, shape.shift
        local function at(t, lx, ly, w, h, turn, a, what)
            local x = lx * R * math.cos(a) - ly * R * math.sin(a)
            local y = -lx * R * math.sin(a) - ly * R * math.cos(a)
            local _, _, _, px, py = t:GetPoint(1)
            near(px, d * math.sin(a) + x, what .. " x")
            near(py, d * math.cos(a) + y, what .. " y")
            near(t.__size[1], w * R, what .. " width")
            near(t.__size[2], h * R, what .. " height")
            near(t.__rotation, turn - a, what .. " rotation")
        end
        local sawE = false
        for j = 1, shape.size do
            local a = sliceAngle(shape, j)
            local set = ring.qcShine[j]
            at(set.spot, -0.24, -0.80, 0.34, 0.12, math.rad(22), a, "gap " .. gap .. " slice " .. j .. " spot")
            at(set.glow, 0, -0.38, 0.5, 0.2, 0, a, "gap " .. gap .. " slice " .. j .. " glow")
            if math.abs(a % (2 * math.pi) - math.pi / 2) < 1e-6 then
                sawE = true
                -- the E slice: local (-0.24, -0.80) turned by 90 degrees is (0.80, 0.24)
                local _, _, _, px, py = set.spot:GetPoint(1)
                near(px, d + 0.80 * R, "E spot x")
                near(py, 0.24 * R, "E spot y")
            end
        end
        assertTrue(sawE, "the ring has an E slice")
    end
    local ring = shineDial(NS, "frost", { gap = 0 })
    local R, a1 = ring.qcShape.disc / 2, sliceAngle(ring.qcShape, 1)
    local _, _, _, sx, sy = ring.qcShine[1].streak:GetPoint(1)
    near(sx, 0.95 * R * math.sin(a1), "slice 1's streak on its outer arc, along its bisector (x)")
    near(sy, 0.95 * R * math.cos(a1), "(y)")
end)

test("dial: [shine] a narrower slice narrows its sprites and its mask cuts them", function()
    local NS = live()
    for _, look in ipairs({ "orb", "frost" }) do
        local ring = shineDial(NS, look, { n = 8, slices = 8 })
        local shape = ring.qcShape
        assertEqual(shape.size, 8, look .. ": an 8-slice ring")
        local R, k = shape.disc / 2, math.tan(math.pi / 8)
        for j = 1, 8 do
            local set = ring.qcShine[j]
            for _, key in ipairs(look == "orb" and { "spot", "glow" } or { "streak" }) do
                local masks = set[key].__masks or {}
                assertTrue(masks[1] == set.mask, look .. " slice " .. j .. ": the slice's mask cuts its " .. key)
            end
            if look == "orb" then
                near(set.spot.__size[1], 0.34 * k * R, "slice " .. j .. " spot width")
                near(set.glow.__size[1], 0.5 * k * R, "slice " .. j .. " glow width")
                near(set.glow.__size[2], 0.2 * R, "slice " .. j .. " glow height stays")
            else
                near(set.streak.__size[1], 0.68 * k * R, "slice " .. j .. " streak width")
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
        for j = 1, 4 do assertTrue(ring.qcShine[j].rim:IsShown() or ring.qcShine[j].soft:IsShown(), name .. " " .. j) end
    end
    S.Paint(ring, { size = 4, start = 0, items = {} }, look("fluid"))
    S.Paint(ring, { size = 4, start = 0, items = {} }, look("gloss"))
    for j = 1, 4 do
        assertFalse(ring.qcShine[j].bloom1:IsShown() or ring.qcShine[j].bloom2:IsShown(), "gloss leaves no bloom")
        assertFalse(ring.qcShine[j].spot:IsShown(), "nor orb's spot")
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
    assertTrue(ring.qcShine[1].spot:IsShown(), "the dial wears its orb")
    local shown = 0
    for _, btn in ipairs(NS.Pad.Instance("p1").buttons.active) do
        if btn:IsShown() then
            shown = shown + 1
            assertTrue(btn.qcShine == nil or not btn.qcShine:IsShown(), "the pad at None carries no shine")
        end
    end
    assertTrue(shown > 0, "the pad has buttons")
    local look = NS.DialRender.Look(100, {}, NS.db.profile.dials.d2.slice, {})
    assertEqual(look.shine.look, "orb", "the look carries its shine")
    assertEqual(NS.db.profile.pads.p1.button.shineLook, "none")
end)
