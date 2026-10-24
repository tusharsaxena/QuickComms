local _, NS = ...
-- modules/Glow.lua — the Icons tab's glow (B9) on a Comms Pad button's and a Comms Dial wedge's icon:
-- LibCustomGlow-1.0's effect, drawn through LibKa0s-Glow-1.0 (core/GlowSetup.lua, NS.GlowLib), which
-- owns the knob-to-argument mapping. The knob table and the trigger stay modeled on DropWatcher
-- modules/Glow.lua, as do the unchanged-repaint no-op and the proc burst spent once.
--
-- THE TRIGGER (owner decision 2026-10-19), per pad and per dial, off by default: Always (while the
-- icon is drawn), On hover (a pad button's OnEnter to OnLeave, hooked insecurely beside the tooltip;
-- a dial wedge's from the dial's tracker, Dial_Render.HoverWedge, since wedges take no mouse) or After
-- sending (SEND_SECONDS from the callout's send result, the same SEND_RESULT edge that flashes the
-- button; a second result restarts the window). Bind hands a button its surface's glow settings at
-- every paint; Update decides from them and the button's hover and send state. A dial closes on every
-- send, so its result lands while the wedges are hidden: Sent is given a hold there (Dial.DROP_SECONDS,
-- as long as a drop stays red), and the dial's next open within it runs the window again (Shown).
--
-- ON THE ICON. The effect is started on the icon's plain child frame (modules/IconStyle.lua
-- IconFrame), ICON_GLOW over it (core/Constants.lua LAYERS), so it circles the icon and sits over the
-- icon's border and under the button's overlay frame (its label, padlock and veils). The
-- effect's frames are plain children too: the client lets them be made, shown, anchored and animated
-- in combat, and nothing here makes a protected call (Review Focus 3), so a hover or a send glow
-- starts and stops in combat as well. Settings changes reach the screen through the rebuild, which
-- waits for combat end.
--
-- FREE WHEN NOTHING CHANGED. A rebuild paints every button again; Apply keeps the running effect when
-- the settings' signature (IconStyle.Config's `sig`) is the same, and stops and restarts it
-- otherwise. A button the rebuild leaves in its pool's free list, and every button of a released pad or
-- dial, is released here (Release): effect stopped, its send timer canceled, its state cleared. The
-- stand-down puts out every running send glow itself (each timer knows its button), since the frames'
-- release can be held to combat end and canceled by a stand-up in the same combat.
--
-- THE BUTTON GLOW (the Buttons tab, 2026-10-20) is a second effect on a Comms Pad button, around the whole
-- button: started on the button's edge frame (modules/Pad_Render.lua `qcEdge`, a plain child laid over
-- the button) under its own key, so it never meets the icon's; BTN_GLOW over the edge frame, so it sits
-- between the button's border and the icon frame (the LAYERS ladder). It has no trigger: on while the button is
-- drawn with it enabled (Glow.Button, at every paint), in its style and color at the Icons tab's knob
-- defaults; the same signature rule keeps it across an unchanged rebuild, and Release stops it too.
--
-- HEADLESS. The driver resolves LibCustomGlow-1.0 at call time, and the seam's stub (LibKa0s absent)
-- answers false. Either way, without the library (the suites load no libs/ beyond LibKa0s, or a
-- LibStub miss) the decision is still recorded on the button (`qcGlowStyle`, `qcButtonGlowStyle`)
-- and nothing is drawn.

NS.Glow = NS.Glow or {}
local Glow = NS.Glow
local State = NS.State
local Perf = NS.Perf

-- The key every effect is started and stopped under, so another addon's glow on the same frame is
-- never touched (the button style has no key: one per frame).
Glow.KEY = "QuickCommsIcon"
Glow.BUTTON_KEY = "QuickCommsButton"
-- LibCustomGlow's frameLevel: each effect at its host's level plus these (core/Constants.lua LAYERS).
Glow.ICON_LEVEL = NS.Constants.LAYERS.LEVEL.ICON_GLOW
Glow.BUTTON_LEVEL = NS.Constants.LAYERS.LEVEL.BTN_GLOW
Glow.SEND_SECONDS = 1.5

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
    NS.GlowLib.Stop(btn.qcIconFrame, btn.qcGlowStyle, Glow.KEY)
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
    NS.GlowLib.Start(btn.qcIconFrame, g.type, g, Glow.KEY, Glow.ICON_LEVEL)
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
    btn.qcSending, btn.qcSendHeldUntil = nil, nil
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

--- The button's callout had a send result (After sending): glow for SEND_SECONDS from now. With
--- `holdSeconds` (a dial's wedge, hidden by the send), the button's next Shown within that many
--- seconds runs the window again.
function Glow.Sent(btn, holdSeconds)
    if not (btn and btn.qcGlowCfg and btn.qcGlowCfg.when == "send") then return end
    cancelSend(btn)
    btn.qcSending = true
    if holdSeconds then btn.qcSendHeldUntil = GetTime() + holdSeconds end
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
    timers[handle] = btn
    Glow.Update(btn)
end

--- The button came on screen (a dial opening): a send held for it runs its window now, once.
function Glow.Shown(btn)
    local untilAt = btn and btn.qcSendHeldUntil
    if not untilAt then return end
    btn.qcSendHeldUntil = nil
    if GetTime() <= untilAt then Glow.Sent(btn) end
end

-- ── the button glow (the Buttons tab) ────────────────────────────────────────────────────────────

local function stopButton(btn)
    if not btn.qcButtonGlowStyle then return end
    NS.GlowLib.Stop(btn.qcEdge, btn.qcButtonGlowStyle, Glow.BUTTON_KEY)
    btn.qcButtonGlowStyle, btn.qcButtonGlowSig = nil, nil
end

--- A button's paint: its pad's button glow (IconStyle.GlowConfig of the Buttons tab, false while off), on
--- the button's edge frame. An unchanged signature keeps the running effect.
function Glow.Button(btn, g)
    if not btn then return end
    if not g then return stopButton(btn) end
    if btn.qcButtonGlowStyle and btn.qcButtonGlowSig == g.sig then return end
    stopButton(btn)
    NS.GlowLib.Start(btn.qcEdge, g.type, g, Glow.BUTTON_KEY, Glow.BUTTON_LEVEL)
    btn.qcButtonGlowStyle, btn.qcButtonGlowSig = g.type, g.sig
end

--- A button no longer drawn: its effects stopped, its send timer canceled, its state cleared.
function Glow.Release(btn)
    if not btn then return end
    cancelSend(btn)
    Glow.Stop(btn)
    stopButton(btn)
    btn.qcGlowCfg, btn.qcGlowKey, btn.qcHovered = nil, nil, nil
end

--- Release every button in a pool's free list (NS.Pool's shape): the ones a rebuild left unused.
function Glow.ReleaseFree(pool)
    for _, btn in ipairs(pool and pool.free or {}) do Glow.Release(btn) end
end

-- The stand-down: no send timer outlives it, and no send glow stays lit on a button whose release
-- is held (the frames' own release stops every other effect).
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle, btn in pairs(State.glowTimers or {}) do
        NS.addon:CancelTimer(handle)
        if type(btn) == "table" and btn.qcGlowTimer == handle then
            btn.qcGlowTimer = nil
            cancelSend(btn)
            Glow.Update(btn)
        end
    end
    State.glowTimers = nil
end
