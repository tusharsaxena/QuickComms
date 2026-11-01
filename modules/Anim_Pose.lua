local _, NS = ...
-- modules/Anim_Pose.lua — the dial animations' poses and styles (#13): pure functions, no frames. The
-- motion is the approved mockup's, whose `e` runs 0 hidden to 1 at rest; a close plays it back down.
--
-- A POSE is one flat table: the whole dial's `alpha`, `scale` (uniform), `scaleX` and `scaleY` (on top of
-- `scale`, one axis apart), `rot` (radians clockwise, the places only: a hub and a title stay level, as
-- in the mockup), `dx` and `dy` (in dial radii, up is positive, and unscaled by the pose), `fan` (the
-- Fan's sweep), `hub` (the alpha of what has no place), `flash` (the additive glow's alpha), and, for a
-- style that moves slices apart, `places[1..count]`, each { alpha, radius, angle, scale, spin }: `radius`
-- 1 at rest, its slice's distance along its bisector as a share of the dial's radius; `angle` radians
-- clockwise, its orbit about the dial's center; `scale` about the dial's center, offset with it; `spin`
-- radians clockwise, turning the slice about that offset point, as `angle` does not.
--
-- A STYLE, in A.STYLES, is { g, w, knots }, every field optional. `g(e, pose, cfg)` writes the whole
-- dial's keys and `w(e, i, n, place, cfg)` one place's, `i` counted from 0 as the mockup does. Each gets
-- a pose already at rest and writes only what it moves; `cfg` is A.Config's answer (a Slide's
-- direction and phase). A `w` style fades the hub by the mockup's clamp(e * 2). `knots`, a rising list of e, breaks
-- a fresh open or close into that many more linear legs of the client's scales (modules/Anim_Ghost.lua),
-- for a curve one smoothed leg cannot follow: an overshoot, or a Squash's one axis then the other. A
-- scale that overshoots declares them, or its text, which takes one leg per stretch, will not overshoot.
--
-- NOTHING PER TICK: A.Pose and A.Lerp write into `into` and keep its place tables in `into.pool`, so a
-- track's tick makes no table. test_anim.lua pins that.

NS.Anim = NS.Anim or {}
local A = NS.Anim

local REST = { alpha = 1, scale = 1, scaleX = 1, scaleY = 1, rot = 0, dx = 0, dy = 0, fan = 1, hub = 1, flash = 0 }
local REST_PLACE = { alpha = 1, radius = 1, angle = 0, scale = 1, spin = 0 }

local PI2 = math.pi * 2
local DIAL_R = 165                  -- the mockup's dial radius in pixels, which its offsets are shares of
local SLIDE_REACH = 70 / DIAL_R
local DROP_REACH = 150 / DIAL_R
local SEED = { 0.31, 0.77, 0.12, 0.93, 0.48, 0.05, 0.66, 0.84 }   -- Shatter's scatter, wrapped past eight
local PEAK = 1 - 3.8 / 8.7          -- the `e` at which A.Back stands highest

-- Which way a Slide moves, x and y, up and right positive.
local SLIDE_WAY = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }

local function clamp01(v) return math.max(0, math.min(1, v)) end
A.Clamp = clamp01

local function seed(i) return SEED[i % #SEED + 1] end

--- The mockup's overshoot: 0 to 1, past it on the way. Pure.
function A.Back(e)
    local c, g = 1.9, e - 1
    return 1 + g * g * ((c + 1) * g + c)
end

--- The mockup's bounce: 0 to 1, rebounding off it. Pure.
function A.Bounce(e)
    local n, d = 7.5625, 2.75
    if e < 1 / d then return n * e * e end
    if e < 2 / d then
        e = e - 1.5 / d
        return n * e * e + 0.75
    end
    if e < 2.5 / d then
        e = e - 2.25 / d
        return n * e * e + 0.9375
    end
    e = e - 2.625 / d
    return n * e * e + 0.984375
end

-- The direction reads as motion (the design's Slide): Up on an open rises into place, and Up on a close
-- leaves upward, so the hidden end is on the far side for a close. Whichever way, as the mockup's reach.
local function slide(e, p, cfg)
    local way = SLIDE_WAY[cfg and cfg.direction] or SLIDE_WAY.up
    local off = (1 - e) * SLIDE_REACH * ((cfg and cfg.phase == "close") and 1 or -1)
    p.dx, p.dy, p.alpha = way[1] * off, way[2] * off, e
end

-- The approved mockup's S, key for key but for its pixels, and the owner's two fading scales.
A.STYLES = {
    fade = { g = function(e, p) p.alpha = e end },
    scaleFade = { g = function(e, p) p.alpha, p.scale = e, 0.8 + 0.2 * e end },
    fan = { g = function(e, p) p.alpha, p.fan = e, e end },
    scaleIn = { g = function(e, p) p.scale, p.alpha = 0.25 + 0.75 * e, clamp01(e * 4) end },
    scaleInFade = { g = function(e, p) p.scale, p.alpha = 0.25 + 0.75 * e, e end },
    scaleOut = { g = function(e, p) p.scale, p.alpha = 1.7 - 0.7 * e, clamp01(e * 2) end },
    scaleOutFade = { g = function(e, p) p.scale, p.alpha = 1.7 - 0.7 * e, e end },
    rotateScale = { g = function(e, p)
        p.scale, p.rot, p.alpha = 0.45 + 0.55 * e, (1 - e) * -2.1, clamp01(e * 2.5)
    end },
    spiralOut = { w = function(e, _, _, p)
        p.radius, p.angle, p.alpha = 1 + (1 - e) * 1.1, (1 - e) * 1.8, clamp01(e * 1.6)
    end },
    spiralIn = { w = function(e, _, _, p)
        p.radius, p.angle, p.alpha = e, (1 - e) * -2.4, clamp01(e * 2.5)
    end },
    orbit = { w = function(e, i, n, p)
        p.angle, p.alpha = (1 - e) * -(i / n) * PI2, clamp01(e * 3)
    end },
    burst = { w = function(e, _, _, p) p.radius, p.alpha = A.Back(e), clamp01(e * 3) end },
    stagger = { knots = { 0.2, 0.4, 0.6, 0.8 }, w = function(e, i, n, p)
        local k = clamp01(e * 1.7 - (i / n) * 0.7)
        p.scale, p.alpha = A.Back(k), clamp01(k * 3)
    end },
    pop = { knots = { 0.3, PEAK }, g = function(e, p)
        p.scale, p.alpha = 0.7 + 0.3 * A.Back(e), clamp01(e * 3)
    end },
    slide = { g = slide },
    drop = { g = function(e, p) p.dy, p.alpha = (1 - A.Bounce(e)) * DROP_REACH, clamp01(e * 4) end },
    squash = { knots = { 1 / 2.2, 1.2 / 2.2 }, g = function(e, p)
        p.scaleX = math.max(0.03, clamp01(e * 2.2))
        p.scaleY = math.max(0.015, clamp01(e * 2.2 - 1.2))
        p.alpha = clamp01(e * 8)
    end },
    flip = { knots = { 0.25, 0.5, 0.75 }, g = function(e, p)
        p.scaleX, p.alpha = math.max(0.02, math.sin(e * math.pi / 2)), clamp01(e * 5)
    end },
    shatter = { w = function(e, i, _, p)
        local left, s = 1 - e, seed(i)
        p.radius, p.angle = 1 + left * (0.5 + s), left * (seed(i + 3) - 0.5) * 2
        p.spin, p.alpha = left * (s - 0.5) * 4, clamp01(e * 1.4)
    end },
    flash = { g = function(e, p)
        p.scale, p.alpha, p.flash = 0.92 + 0.08 * e, clamp01(e * 2), math.sin(math.pi * clamp01(e)) * 0.8
    end },
}

local function atRest(t, rest)
    for k, v in pairs(rest) do t[k] = v end
    return t
end

--- The pose a surface rests in.
function A.Rest()
    return atRest({}, REST)
end

--- A place at rest.
function A.RestPlace()
    return atRest({}, REST_PLACE)
end

-- `into`'s first `n` place tables, made once and kept, on as its places.
local function placesOf(into, n)
    local pool = into.pool or {}
    into.pool = pool
    for i = #pool + 1, n do pool[i] = A.RestPlace() end
    into.places, into.count = pool, n
    return pool
end

--- Put place `i` of `pose` at rest, if the pose has that place.
function A.SettlePlace(pose, i)
    local p = pose.places and pose.places[i]
    if p then atRest(p, REST_PLACE) end
end

--- `style` at `e` (0 hidden, 1 rest) on a ring of `n` places, into the buffer `into` when given. Pure but
--- for `into`. nil for None and an unknown style.
--- @return table|nil pose
function A.Pose(style, e, n, into, cfg)
    local def = A.STYLES[style]
    if not def then return nil end
    into = atRest(into or {}, REST)
    into.places, into.count = nil, nil
    if def.g then def.g(e, into, cfg) end
    if def.w then
        into.hub = clamp01(e * 2)
        n = math.max(1, tonumber(n) or 1)
        local places = placesOf(into, n)
        for i = 1, n do def.w(e, i - 1, n, atRest(places[i], REST_PLACE), cfg) end
    end
    return into
end

--- The pose `style` starts an open from or ends a close on, or nil for None and unknown styles. Pure.
function A.Hidden(style, n, cfg)
    return A.Pose(style, 0, n, nil, cfg)
end

--- Eased progress for `f` (0 to 1): decelerating into an open, accelerating out of a close. Pure.
function A.Ease(phase, f)
    if phase == "open" then return 1 - (1 - f) * (1 - f) end
    return f * f
end

--- The `f` at which a fresh `phase` stands at `e`: A.Ease undone, an open's e rising and a close's
--- falling. Pure.
function A.Unease(phase, e)
    local left = math.sqrt(1 - clamp01(e))
    if phase == "open" then return 1 - left end
    return left
end

--- The next stop after `e` on `knots`, going `phase`'s way: a knot, or the end. Pure.
function A.NextKnot(knots, e, phase)
    if phase == "open" then
        for _, k in ipairs(knots) do
            if k > e then return k end
        end
        return 1
    end
    for i = #knots, 1, -1 do
        if knots[i] < e then return knots[i] end
    end
    return 0
end

--- A slice's alpha at sweep `fan` (0 hidden, 1 rest), `at` (0 to 1) its share of the way around the
--- ring. Every slice is whole at rest. Pure.
function A.FanAlpha(fan, at)
    return clamp01(fan * 2 - at)
end

local function lerpKeys(a, b, e, out, rest)
    for k in pairs(rest) do out[k] = a[k] + (b[k] - a[k]) * e end
end

--- `from` to `to` at progress `e`, into the buffer `into` when given (never `from` or `to` with places
--- on the other), alpha held to 0 to 1, and a place missing from one side at rest there. Pure but for
--- `into`. At 0 it is a copy.
function A.Lerp(from, to, e, into)
    into = into or {}
    local a, b = from.places, to.places
    local n = math.max(a and from.count or 0, b and to.count or 0)
    lerpKeys(from, to, e, into, REST)
    into.alpha = clamp01(into.alpha)
    if n == 0 then
        into.places, into.count = nil, nil
        return into
    end
    local places = placesOf(into, n)
    for i = 1, n do
        lerpKeys(a and a[i] or REST_PLACE, b and b[i] or REST_PLACE, e, places[i], REST_PLACE)
    end
    return into
end

--- One phase's settings from a surface's `anim` table, filled from `defaults` where a key is missing.
--- @return table { style, duration, direction, phase }
function A.Config(anim, defaults, phase)
    anim = type(anim) == "table" and anim or {}
    local function read(key)
        local v = anim[phase .. key]
        if v == nil then return defaults[phase .. key] end
        return v
    end
    return { style = read("Style"), duration = tonumber(read("Duration")) or 0, direction = read("Direction"),
        phase = phase }
end
