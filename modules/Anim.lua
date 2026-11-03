local _, NS = ...
-- modules/Anim.lua — the open and close animations' state machine (#13,
-- docs/superpowers/specs/2026-11-01-open-close-animations-design.md). One track per dial. A fresh leg
-- plays its style's curve (modules/Anim_Pose.lua) along `e`, 0 hidden to 1 at rest; an interrupted one
-- tweens from the pose it stands in, every place of it, to the new style's end, so two different styles
-- meet with no jump. modules/Anim_Ghost.lua draws the pose on the surface's insecure copy; each leg also
-- hands the copy's text and one-axis art their client-run scale (G.ScaleText), which never goes through
-- a frame's SetScale. Each track owns its pose buffers, so a tick makes no table. The real frames are never
-- moved or scaled: a dial is shown and hidden by secure code, which nothing here can delay, and only
-- its alpha may change in combat (A.Open holds it at 0 under the ghost). Animations are the dial's
-- alone (the owner's ruling, 2026-11-01): a pad has no track.
--
-- ONE WAY OFF A TRACK: A.Snap, which every landing, interrupt to None and stand-down passes through,
-- so a track cannot end with its surface still held invisible. One OnUpdate, on a frame with no parent
-- (a hidden UIParent must not stall a track), runs only while a track is live, so a surface at rest
-- costs nothing per frame. Every interrupt starts from the current pose, so a reversal never jumps.

NS.Anim = NS.Anim or {}
local A = NS.Anim
local Ghost = NS.AnimGhost

A.NONE = "none"
A.REVERSE_FLOOR = 0.25  -- the shortest reversal, as a share of the setting's duration
A.EMPHASIS_HOLD = 0.7   -- the share of a close the sent slice stays at full alpha
A.EMPHASIS_PULSE = 0.08 -- how far it swells at the height of the pulse

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
--- size and its shape, { start, disc }), `config(phase)` (A.Config's answer), `restAlpha()` (the real frame's alpha at rest),
--- `hold()` (the real frame goes invisible under the ghost) and `release()` (it comes back).
function A.NewTrack(spec)
    return { spec = spec, nowBuf = A.Rest(), fromBuf = A.Rest(), toBuf = A.Rest(),
        legFrom = A.Rest(), legTo = A.Rest() }
end

local function capture(track)
    track.ghost = track.ghost or Ghost.New()
    local roots, size, shape = track.spec.roots()
    return Ghost.Capture(track.ghost, track.spec.src, roots, size, shape)
end

local function draw(track, f)
    Ghost.Pose(track.ghost, track.pose, track.spec.restAlpha(), track.emphasis, f)
end

local function styleOf(track)
    return track.curve and A.STYLES[track.curve]
end

-- The leg from `e`: the whole way, or, on a fresh curve with knots, a linear one to the next knot.
local function runLeg(track, e)
    local style = styleOf(track)
    local knots, phase = style and style.knots, track.phase
    if not knots then
        track.legEnd = nil
        return Ghost.ScaleText(track.ghost, track.from, track.to, track.duration, phase)
    end
    local stop, n = A.NextKnot(knots, e, phase), track.size
    A.Pose(track.curve, e, n, track.legFrom, track.cfg)
    A.Pose(track.curve, stop, n, track.legTo, track.cfg)
    local share = math.abs(A.Unease(phase, stop) - A.Unease(phase, e))
    track.legEnd = stop ~= track.target and stop or nil
    Ghost.ScaleText(track.ghost, track.legFrom, track.legTo, share * track.duration, "linear")
end

-- Into `phase` from wherever the track stands: a fresh open from the style's hidden pose, a fresh
-- close from rest, an interrupted one from the current pose over the share of `e` it has left.
local function begin(track, phase, cfg)
    local target = phase == "open" and 1 or 0
    local size = track.ghost.size or 1
    local interrupted = track.phase ~= nil
    local from, duration = track.fromBuf, cfg.duration
    local e = 1 - target
    if interrupted then
        e = track.e
        A.Lerp(track.pose, track.pose, 0, from)
        -- The sent place drew at rest through the close, and the pose never recorded that.
        if phase == "open" and track.emphasis then A.SettlePlace(from, track.emphasis) end
        duration = duration * math.max(A.REVERSE_FLOOR, math.abs(target - e))
    else
        A.Pose(cfg.style, e, size, from, cfg)
    end
    track.phase, track.from, track.to = phase, from, A.Pose(cfg.style, target, size, track.toBuf, cfg)
    track.curve, track.cfg, track.size, track.target = not interrupted and cfg.style or nil, cfg, size, target
    track.e, track.start = e, e
    track.pose, track.t, track.duration = A.Lerp(from, from, 0, track.nowBuf), 0, math.max(duration, 0.001)
    if phase == "open" then track.emphasis = nil end
    live[track] = true
    draw(track, 0)
    Ghost.Show(track.ghost)
    runLeg(track, e)
    wake()
end

--- The surface opened: the ghost plays and the real frame waits invisible, already taking clicks and
--- keys. None, or nothing to draw, is a snap.
--- @return boolean animating
function A.Open(track)
    local cfg = track.spec.config("open")
    if not A.STYLES[cfg.style] or not capture(track) then
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
    if not A.STYLES[cfg.style] or not capture(track) then
        A.Snap(track)
        return false
    end
    begin(track, "close", cfg)
    return true
end

--- Name the slice a send went out on: it stays bright and pulses through this close. No effect on a
--- track that is not closing.
function A.Emphasize(track, place)
    if track.phase ~= "close" or track.emphasis == place then return end
    track.emphasis = place
    Ghost.EmphasizeText(track.ghost, place, track.duration - track.t)
end

--- One tick of a live track (the driver's, a test's).
function A.Step(track, elapsed)
    if not track.phase then return end
    track.t = track.t + (tonumber(elapsed) or 0)
    local f = math.min(1, track.t / track.duration)
    local eased = A.Ease(track.phase, f)
    track.e = track.start + (track.target - track.start) * eased
    if track.curve then
        A.Pose(track.curve, track.e, track.size, track.pose, track.cfg)
    else
        A.Lerp(track.from, track.to, eased, track.pose)
    end
    if f >= 1 then return A.Snap(track) end
    if track.legEnd and (track.e - track.legEnd) * (track.target - 0.5) >= 0 then runLeg(track, track.legEnd) end
    draw(track, f)
end

--- Off the track, whatever it was doing: nothing running, the ghost hidden, the real frame back.
function A.Snap(track)
    local was = track.phase
    track.phase, track.emphasis, track.pose, track.curve, track.legEnd = nil, nil, nil, nil, nil
    live[track] = nil
    if track.ghost then Ghost.Hide(track.ghost) end
    sleepIfIdle()
    if was == "open" or was == "close" then track.spec.release() end
end

--- Whether any track runs.
function A.Running()
    return anyLive()
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for track in pairs(live) do A.Snap(track) end
end
