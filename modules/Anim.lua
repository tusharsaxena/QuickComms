local _, NS = ...
-- modules/Anim.lua — the open and close animations' state machine (#13,
-- docs/superpowers/specs/2026-11-01-open-close-animations-design.md). One track per surface. A track
-- tweens a pose ({ alpha, scale, x, y, fan }) from wherever it stands to where its phase ends, and
-- modules/Anim_Ghost.lua draws that pose on the surface's insecure copy. The real frames are never
-- moved or scaled: a dial and a pad are shown and hidden by secure code, which nothing here can
-- delay, and only their alpha may change in combat (A.Open holds it at 0 under the ghost).
--
-- ONE WAY OFF A TRACK: A.Snap, which every landing, interrupt to None and stand-down passes through,
-- so a track cannot end with its surface still held invisible. One OnUpdate, on a frame with no parent
-- (a hidden UIParent must not stall a track), runs only while a track is live, so a surface at rest
-- costs nothing per frame. Every interrupt starts from the current pose, so a reversal never jumps.

NS.Anim = NS.Anim or {}
local A = NS.Anim
local Ghost = NS.AnimGhost

A.NONE = "none"
A.SLIDE = 24            -- pixels a Slide travels
A.REVERSE_FLOOR = 0.25  -- the shortest reversal, as a share of the setting's duration
A.EMPHASIS_HOLD = 0.7   -- the share of a close the sent slice stays at full alpha
A.EMPHASIS_PULSE = 0.08 -- how far it swells at the height of the pulse

local BACK = 1.70158    -- the classic back ease: about 10% of overshoot, which Pop wants

local HIDDEN = {
    fade = { alpha = 0, scale = 1 },
    fadeScale = { alpha = 0, scale = 0.9 },
    scaleFade = { alpha = 0, scale = 0.8 },
    pop = { alpha = 0, scale = 0.8 },
    slide = { alpha = 0, scale = 1 },
    fan = { alpha = 0, scale = 1, fan = 0 },
}
local DIRECTIONS = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
local KEYS = { "alpha", "scale", "x", "y", "fan" }

local function clamp01(v) return math.max(0, math.min(1, v)) end

--- The pose a surface rests in.
function A.Rest()
    return { alpha = 1, scale = 1, x = 0, y = 0, fan = 1 }
end

--- The pose `style` starts an open from or ends a close on, or nil for None and unknown styles. A
--- Slide's direction is the way it moves: Up on open starts below and rises, Up on close leaves upward.
--- Pure.
function A.Hidden(style, phase, direction)
    local h = HIDDEN[style]
    if not h then return nil end
    local x, y = 0, 0
    if style == "slide" then
        local d = DIRECTIONS[direction] or DIRECTIONS.up
        local sign = phase == "open" and -1 or 1
        x, y = d[1] * sign * A.SLIDE, d[2] * sign * A.SLIDE
    end
    return { alpha = h.alpha, scale = h.scale, x = x, y = y, fan = h.fan or 1 }
end

--- Eased progress for `f` (0 to 1): decelerating into an open, accelerating out of a close; Pop
--- overshoots its open and winds up before its close, so its answer leaves 0 to 1 on the way. Pure.
function A.Ease(style, phase, f)
    if style == "pop" then
        if phase == "open" then
            local g = f - 1
            return g * g * ((BACK + 1) * g + BACK) + 1
        end
        return f * f * ((BACK + 1) * f - BACK)
    end
    if phase == "open" then return 1 - (1 - f) * (1 - f) end
    return f * f
end

--- A slice's alpha at sweep `fan` (0 hidden, 1 rest), `at` (0 to 1) its share of the way around the
--- ring. Every slice is whole at rest. Pure.
function A.FanAlpha(fan, at)
    return clamp01(fan * 2 - at)
end

--- `from` to `to` at eased progress `e`, alpha held to 0 to 1 (Pop's overshoot is scale's). Pure.
function A.Lerp(from, to, e)
    local out = {}
    for _, k in ipairs(KEYS) do out[k] = from[k] + (to[k] - from[k]) * e end
    out.alpha = clamp01(out.alpha)
    return out
end

--- One phase's settings from a surface's `anim` table, filled from `defaults` where a key is missing.
--- @return table { style, duration, direction }
function A.Config(anim, defaults, phase)
    anim = type(anim) == "table" and anim or {}
    local function read(key)
        local v = anim[phase .. key]
        if v == nil then return defaults[phase .. key] end
        return v
    end
    return { style = read("Style"), duration = tonumber(read("Duration")) or 0, direction = read("Direction") }
end

-- ── the tracks ──────────────────────────────────────────────────────────────────────────────

local live = {}     -- the tracks running, as a set
local driver        -- the frame whose OnUpdate steps them

local function anyLive()
    return next(live) ~= nil
end

local function step(_, elapsed)
    for track in pairs(live) do A.Step(track, elapsed) end
end

local function wake()
    driver = driver or CreateFrame("Frame")
    driver:SetScript("OnUpdate", step)
end

local function sleepIfIdle()
    if driver and not anyLive() then driver:SetScript("OnUpdate", nil) end
end

--- A surface's track. `spec`: `src` (the real frame), `roots()` (the frames to mirror, then the ring's
--- size for a Fan), `config(phase)` (A.Config's answer), `restAlpha()` (the real frame's alpha at rest),
--- `hold()` (the real frame goes invisible under the ghost) and `release()` (it comes back).
function A.NewTrack(spec)
    return { spec = spec }
end

local function capture(track)
    track.ghost = track.ghost or Ghost.New()
    local roots, size = track.spec.roots()
    return Ghost.Capture(track.ghost, track.spec.src, roots, size)
end

local function draw(track, f)
    Ghost.Pose(track.ghost, track.pose, track.spec.restAlpha(), track.emphasis, f)
end

-- Into `phase` from wherever the track stands: a fresh open from the style's hidden pose, a fresh
-- close from rest, an interrupted one from the current pose over the time its alpha has left.
local function begin(track, phase, cfg)
    local hidden = A.Hidden(cfg.style, phase, cfg.direction)
    local interrupted = track.phase ~= nil
    local from = interrupted and track.pose or (phase == "open" and hidden or A.Rest())
    local to = phase == "open" and A.Rest() or hidden
    local duration = cfg.duration
    if interrupted then duration = duration * math.max(A.REVERSE_FLOOR, math.abs(to.alpha - from.alpha)) end
    track.phase, track.style, track.from, track.to = phase, cfg.style, from, to
    track.pose, track.t, track.duration = from, 0, math.max(duration, 0.001)
    if phase == "open" then track.emphasis = nil end
    live[track] = true
    draw(track, 0)
    Ghost.Show(track.ghost)
    wake()
end

--- The surface opened: the ghost plays and the real frame waits invisible, already taking clicks and
--- keys. None, or nothing to draw, is a snap.
--- @return boolean animating
function A.Open(track)
    local cfg = track.spec.config("open")
    if not A.Hidden(cfg.style, "open", cfg.direction) or not capture(track) then
        A.Snap(track)
        return false
    end
    begin(track, "open", cfg)
    track.spec.hold()
    return true
end

--- The surface closed: the real frame is already hidden and the ghost plays out in its place.
--- @return boolean animating
function A.Close(track)
    local cfg = track.spec.config("close")
    if not A.Hidden(cfg.style, "close", cfg.direction) or not capture(track) then
        A.Snap(track)
        return false
    end
    begin(track, "close", cfg)
    return true
end

--- Name the slice a send went out on: it stays bright and pulses through this close. No effect on a
--- track that is not closing.
function A.Emphasize(track, place)
    if track.phase == "close" then track.emphasis = place end
end

--- One tick of a live track (the driver's, a test's).
function A.Step(track, elapsed)
    if not track.phase then return end
    track.t = track.t + (tonumber(elapsed) or 0)
    local f = math.min(1, track.t / track.duration)
    track.pose = A.Lerp(track.from, track.to, A.Ease(track.style, track.phase, f))
    if f >= 1 then return A.Snap(track) end
    draw(track, f)
end

--- Off the track, whatever it was doing: nothing running, the ghost hidden, the real frame back.
function A.Snap(track)
    local was = track.phase
    track.phase, track.emphasis, track.pose = nil, nil, nil
    live[track] = nil
    if track.ghost then Ghost.Hide(track.ghost) end
    sleepIfIdle()
    if was == "open" or was == "close" then track.spec.release() end
end

--- Whether the real frame is being held invisible under the ghost (Pad.ApplyAlpha asks).
function A.Holding(track)
    return track ~= nil and track.phase == "open"
end

--- Whether any track runs.
function A.Running()
    return anyLive()
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for track in pairs(live) do A.Snap(track) end
end
