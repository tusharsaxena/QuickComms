local _, NS = ...
-- modules/Glow.lua — the Icons tab's glow (B9) on a Comms Pad chip's and a Comms Dial wedge's icon:
-- LibCustomGlow-1.0's effect, modeled on DropWatcher modules/Glow.lua (its START/STOP tables, its
-- knob table, the unchanged-repaint no-op and the proc burst spent once).
--
-- THE TRIGGER (owner decision 2026-10-19), per pad and per dial, off by default: Always (while the
-- icon is drawn), On hover (OnEnter to OnLeave, hooked insecurely beside the tooltip) or After
-- sending (SEND_SECONDS from the callout's send result, the same SEND_RESULT edge that flashes the
-- chip; a second result restarts the window). Bind hands a button its surface's glow settings at
-- every paint; Update decides from them and the button's hover and send state.
--
-- ON THE ICON. The effect is started on the icon's plain child frame (modules/IconStyle.lua
-- IconFrame), FRAME_LEVEL over it, so it circles the icon and sits over the icon's border. The
-- effect's frames are plain children too: the client lets them be made, shown, anchored and animated
-- in combat, and nothing here makes a protected call (Review Focus 3), so a hover or a send glow
-- starts and stops in combat as well. Settings changes reach the screen through the rebuild, which
-- waits for combat end.
--
-- FREE WHEN NOTHING CHANGED. A rebuild paints every chip again; Apply keeps the running effect when
-- the settings' signature (IconStyle.Config's `sig`) is the same, and stops and restarts it
-- otherwise. A chip the rebuild leaves in its pool's free list, and every chip of a released pad or
-- dial, is released here (Release): effect stopped, its send timer canceled, its state cleared.
--
-- HEADLESS. Without the library (the suites load no libs/ beyond LibKa0s, or a LibStub miss) the
-- decision is still recorded on the button (`qcGlowStyle`) and nothing is drawn.

NS.Glow = NS.Glow or {}
local Glow = NS.Glow
local State = NS.State
local Perf = NS.Perf

-- The key every effect is started and stopped under, so another addon's glow on the same frame is
-- never touched (the button style has no key: one per frame).
Glow.KEY = "QuickCommsIcon"
Glow.FRAME_LEVEL = 2
Glow.SEND_SECONDS = 1.5

local function lib() return LibStub and LibStub("LibCustomGlow-1.0", true) or nil end

local function num(v, fallback) return type(v) == "number" and v or fallback end

local START = {
    button = function(L, f, c)
        L.ButtonGlow_Start(f, c.color, num(c.buttonFrequency), Glow.FRAME_LEVEL)
    end,
    proc = function(L, f, c)
        L.ProcGlow_Start(f, { color = c.color, startAnim = c.procStartAnim ~= false,
            duration = num(c.procDuration, 1), xOffset = num(c.xOffset, 0), yOffset = num(c.yOffset, 0),
            key = Glow.KEY, frameLevel = Glow.FRAME_LEVEL })
    end,
    pixel = function(L, f, c)
        -- A length of 0 is automatic (the library sizes the lines from the icon); `border` must be a
        -- boolean, since the library draws its dark border for nil.
        local length = num(c.pixelLength, 0)
        L.PixelGlow_Start(f, c.color, num(c.pixelLines), num(c.pixelFrequency), length > 0 and length or nil,
            num(c.pixelThickness), num(c.xOffset, 0), num(c.yOffset, 0), c.pixelBorder == true, Glow.KEY,
            Glow.FRAME_LEVEL)
    end,
    autocast = function(L, f, c)
        L.AutoCastGlow_Start(f, c.color, num(c.autocastParticles), num(c.autocastFrequency),
            num(c.autocastScale), num(c.xOffset, 0), num(c.yOffset, 0), Glow.KEY, Glow.FRAME_LEVEL)
    end,
}

local STOP = {
    button   = function(L, f) L.ButtonGlow_Stop(f) end,
    proc     = function(L, f) L.ProcGlow_Stop(f, Glow.KEY) end,
    pixel    = function(L, f) L.PixelGlow_Stop(f, Glow.KEY) end,
    autocast = function(L, f) L.AutoCastGlow_Stop(f, Glow.KEY) end,
}

-- The proc style's frame replays its opening burst from its own OnShow, and a rebuild re-shows the
-- pad; once the effect has been on screen the burst has played, so from then on it shows its loop.
local function spendBurst(btn)
    local f = btn.qcIconFrame
    if btn.qcGlowStyle ~= "proc" or not (f and f:IsVisible()) then return end
    local pf = f["_ProcGlow" .. Glow.KEY]
    if type(pf) == "table" then pf.startAnim = false end
end

--- Stop the effect on a button and forget it (a no-op on a button with none).
function Glow.Stop(btn)
    if not (btn and btn.qcGlowStyle) then return end
    local L, stop = lib(), STOP[btn.qcGlowStyle]
    if L and stop and btn.qcIconFrame then stop(L, btn.qcIconFrame) end
    btn.qcGlowStyle, btn.qcGlowSig = nil, nil
end

-- Start, keep or restart the effect for glow settings `g`.
local function start(btn, g)
    if btn.qcGlowStyle and btn.qcGlowSig == g.sig then
        spendBurst(btn)
        return
    end
    Glow.Stop(btn)
    local t0 = Perf.on and debugprofilestop()
    local L, fn = lib(), START[g.type]
    if L and fn and btn.qcIconFrame then fn(L, btn.qcIconFrame, g) end
    btn.qcGlowStyle, btn.qcGlowSig = g.type, g.sig
    spendBurst(btn)
    if t0 then Perf.Note("glowStart", debugprofilestop() - t0) end
end

--- Whether glow settings `g` light the icon now, given the button's hover and send state.
--- @return boolean
function Glow.Wants(g, hovered, sending)
    if not g then return false end
    if g.when == "hover" then return hovered == true end
    if g.when == "send" then return sending == true end
    return true
end

--- Start or stop the button's effect as its settings and state say.
function Glow.Update(btn)
    if not btn then return end
    local g = btn.qcGlowCfg
    if Glow.Wants(g, btn.qcHovered, btn.qcSending) then start(btn, g) else Glow.Stop(btn) end
end

local function cancelSend(btn)
    if btn.qcGlowTimer then
        NS.addon:CancelTimer(btn.qcGlowTimer)
        if State.glowTimers then State.glowTimers[btn.qcGlowTimer] = nil end
        btn.qcGlowTimer = nil
    end
    btn.qcSending = nil
end

--- A button's paint: its surface's glow settings (IconStyle.Config's `glow`, false while off) for
--- the callout `key` it now shows. A button now showing another callout drops its send glow.
function Glow.Bind(btn, g, key)
    if not btn then return end
    if btn.qcGlowKey ~= key then cancelSend(btn) end
    btn.qcGlowCfg, btn.qcGlowKey = g or false, key
    Glow.Update(btn)
end

--- The mouse entered or left the button (On hover).
function Glow.SetHover(btn, on)
    if not btn then return end
    btn.qcHovered = on and true or nil
    if btn.qcGlowCfg then Glow.Update(btn) end
end

--- The button's callout had a send result (After sending): glow for SEND_SECONDS from now.
function Glow.Sent(btn)
    if not (btn and btn.qcGlowCfg and btn.qcGlowCfg.when == "send") then return end
    cancelSend(btn)
    btn.qcSending = true
    local timers = State.glowTimers or {}
    State.glowTimers = timers
    local handle
    handle = NS.addon:ScheduleTimer(function()
        timers[handle] = nil
        if btn.qcGlowTimer == handle then
            btn.qcGlowTimer, btn.qcSending = nil, nil
            Glow.Update(btn)
        end
    end, Glow.SEND_SECONDS)
    btn.qcGlowTimer = handle
    timers[handle] = true
    Glow.Update(btn)
end

--- A button no longer drawn: its effect stopped, its send timer canceled, its state cleared.
function Glow.Release(btn)
    if not btn then return end
    cancelSend(btn)
    Glow.Stop(btn)
    btn.qcGlowCfg, btn.qcGlowKey, btn.qcHovered = nil, nil, nil
end

--- Release every button in a pool's free list (NS.Pool's shape): the ones a rebuild left unused.
function Glow.ReleaseFree(pool)
    for _, btn in ipairs(pool and pool.free or {}) do Glow.Release(btn) end
end

-- The stand-down: no send timer outlives it (the frames' own release stops the effects).
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.glowTimers or {}) do NS.addon:CancelTimer(handle) end
    State.glowTimers = nil
end
