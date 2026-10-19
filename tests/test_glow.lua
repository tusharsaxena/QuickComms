-- tests/test_glow.lua — the Icons tab's glow (B9, modules/Glow.lua): LibCustomGlow-1.0's effect on a
-- chip's or a wedge's icon. Off by default; each style starts with DropWatcher's knob table under the
-- addon's key; a repaint that changes nothing calls the library not at all; the trigger is Always,
-- On hover (OnEnter/OnLeave) or After sending (a send result, then SEND_SECONDS); a chip a rebuild
-- leaves unused, or a released pad, stops its glow; and in combat a glow starts and stops with no
-- protected call (the effect's frames are plain children), while an Icons write waits for combat end.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

-- A LibCustomGlow-1.0 stand-in on the instance's LibStub: every call recorded as { name, args... }.
local function fakeLib(m)
    local lib = m.LibStub:NewLibrary("LibCustomGlow-1.0", 24)
    lib.calls = {}
    for _, name in ipairs({ "ButtonGlow", "ProcGlow", "PixelGlow", "AutoCastGlow" }) do
        for _, edge in ipairs({ "_Start", "_Stop" }) do
            lib[name .. edge] = function(...) lib.calls[#lib.calls + 1] = { name .. edge, ... } end
        end
    end
    return lib
end

local function names(lib)
    local out = {}
    for i, c in ipairs(lib.calls) do out[i] = c[1] end
    return table.concat(out, ",")
end

local function count(lib, name)
    local n = 0
    for _, c in ipairs(lib.calls) do if c[1] == name then n = n + 1 end end
    return n
end

local function live()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m, fakeLib(m)
end

local function planFor(NS)
    local snap = NS.Situation.Current()
    return NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))
end

local function rebuild(NS)
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    return NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
end

local function set(NS, path, v, id)
    local ok, err, why = NS.SchemaRuntime.Set(path, v, id or "p1")
    assertTrue(ok, tostring(why or err))
end

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

test("glow: off by default, so a chip starts nothing", function()
    local NS, _, lib = live()
    local chip = rebuild(NS)
    assertEqual(#lib.calls, 0)
    assertNil(chip.qcGlowStyle)
end)

test("glow: each style starts with the knob table's arguments, on the icon, under the addon's key", function()
    local NS, _, lib = live()
    local G = NS.Glow
    set(NS, "pad.icon.glowEnabled", true)
    -- pixel, the default style: length 0 is automatic (nil), the border a boolean
    local chip = rebuild(NS)
    local c = lib.calls[1]
    assertEqual(c[1], "PixelGlow_Start")
    assertTrue(c[2] == chip.qcIconFrame, "the effect is on the icon, not the whole chip")
    assertEqual(c[3][1], 1); assertEqual(c[3][2], 0.82); assertEqual(c[3][4], 1)
    assertEqual(c[4], 8); assertEqual(c[5], 0.1); assertNil(c[6]); assertEqual(c[7], 1)
    assertEqual(c[10], true); assertEqual(c[11], G.KEY); assertEqual(c[12], G.FRAME_LEVEL)
    lib.calls = {}
    set(NS, "pad.icon.glowType", "proc")
    rebuild(NS)
    assertTrue(count(lib, "PixelGlow_Stop") >= 1, "the old style stops first")
    local proc
    for _, call in ipairs(lib.calls) do if call[1] == "ProcGlow_Start" then proc = call end end
    assertEqual(proc[3].duration, 1); assertEqual(proc[3].startAnim, true); assertEqual(proc[3].key, G.KEY)
    assertEqual(proc[3].frameLevel, G.FRAME_LEVEL)
    lib.calls = {}
    set(NS, "pad.icon.glowType", "button")
    set(NS, "pad.icon.buttonFrequency", 0.5)
    rebuild(NS)
    local btn
    for _, call in ipairs(lib.calls) do if call[1] == "ButtonGlow_Start" then btn = call end end
    assertEqual(btn[4], 0.5); assertEqual(btn[5], G.FRAME_LEVEL)
    lib.calls = {}
    set(NS, "pad.icon.glowType", "autocast")
    set(NS, "pad.icon.autocastParticles", 6)
    set(NS, "pad.icon.xOffset", -3)
    rebuild(NS)
    local ac
    for _, call in ipairs(lib.calls) do if call[1] == "AutoCastGlow_Start" then ac = call end end
    assertEqual(ac[4], 6); assertEqual(ac[5], 0.125); assertEqual(ac[6], 1); assertEqual(ac[7], -3)
    assertEqual(ac[9], G.KEY); assertEqual(ac[10], G.FRAME_LEVEL)
    lib.calls = {}
    set(NS, "pad.icon.glowEnabled", false)
    chip = rebuild(NS)
    assertTrue(count(lib, "AutoCastGlow_Stop") >= 1, "turned off: stopped")
    assertEqual(count(lib, "AutoCastGlow_Start"), 0)
    assertNil(chip.qcGlowStyle)
end)

test("glow: a repaint that changes nothing calls the library not at all; a setting restarts it", function()
    local NS, _, lib = live()
    set(NS, "pad.icon.glowEnabled", true)
    rebuild(NS)
    local started = count(lib, "PixelGlow_Start")
    assertTrue(started > 0)
    lib.calls = {}
    rebuild(NS)
    -- red under: Glow.Bind restarting the effect on every paint
    assertEqual(#lib.calls, 0)
    set(NS, "pad.icon.pixelLines", 4)
    rebuild(NS)
    assertEqual(count(lib, "PixelGlow_Start"), started, "every glowing chip restarts once")
end)

test("glow: On hover starts on enter and stops on leave", function()
    local NS, _, lib = live()
    set(NS, "pad.icon.glowEnabled", true)
    set(NS, "pad.icon.glowWhen", "hover")
    lib.calls = {}
    local chip = rebuild(NS)
    assertEqual(#lib.calls, 0, "nothing until the mouse is over it")
    chip:__fire("OnEnter")
    assertEqual(names(lib), "PixelGlow_Start")
    assertTrue(lib.calls[1][2] == chip.qcIconFrame)
    chip:__fire("OnLeave")
    assertEqual(names(lib), "PixelGlow_Start,PixelGlow_Stop")
end)

test("glow: After sending glows from the send result for SEND_SECONDS, then stops", function()
    local NS, m, lib = live()
    set(NS, "pad.icon.glowEnabled", true)
    set(NS, "pad.icon.glowWhen", "send")
    lib.calls = {}
    local chip = rebuild(NS)
    assertEqual(#lib.calls, 0)
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, T.seeded(NS, "bi.mplus.pull"), "p1", "sent")
    assertEqual(names(lib), "PixelGlow_Start")
    assertTrue(lib.calls[1][2] == chip.qcIconFrame)
    local found
    for _, t in ipairs(m.__timers) do if t.delay == NS.Glow.SEND_SECONDS then found = true end end
    assertTrue(found, "a timer for SEND_SECONDS")
    assertEqual(NS.Glow.SEND_SECONDS, 1.5)
    m.__fireTimers()
    assertEqual(names(lib), "PixelGlow_Start,PixelGlow_Stop")
end)

test("glow: a chip a rebuild leaves unused stops its glow, and so does every chip of a released pad", function()
    local NS, _, lib = live()
    set(NS, "pad.icon.glowEnabled", true)
    rebuild(NS)
    local inst = NS.Pad.Instance("p1")
    local n = #inst.chips.active
    assertTrue(n > 1, "chips: " .. n)
    lib.calls = {}
    assertTrue(NS.Library.RemoveGroupFromSurface("pad", "p1", T.seeded(NS, "bi.mplus")), "removed")
    rebuild(NS)
    -- red under: the rebuild leaving the pool's free chips glowing
    assertTrue(count(lib, "PixelGlow_Stop") > 0, "the chips no longer drawn stop")
    for _, b in ipairs(inst.chips.free) do assertNil(b.qcGlowStyle) end
    NS.Library.AddGroupToSurface("pad", "p1", T.seeded(NS, "bi.mplus"))
    rebuild(NS)
    lib.calls = {}
    local glowing = #inst.chips.active
    assertTrue(glowing > 0, "glowing: " .. glowing)
    NS.Pad.Release("p1")
    assertEqual(count(lib, "PixelGlow_Stop"), glowing, "every chip that glowed stops")
    for _, b in ipairs(inst.chips.free) do assertNil(b.qcGlowStyle) end
end)

test("glow: in combat a hover glow starts and stops with no protected call; an Icons write waits for combat end", function()
    local NS, m, lib = live()
    set(NS, "pad.icon.glowEnabled", true)
    set(NS, "pad.icon.glowWhen", "hover")
    local chip = rebuild(NS)
    lib.calls = {}
    combat(m, true)
    chip:__fire("OnEnter")
    chip:__fire("OnLeave")
    assertEqual(names(lib), "PixelGlow_Start,PixelGlow_Stop")
    set(NS, "pad.icon.zoom", 0.2)
    m.__fireTimers()
    assertEqual(table.concat(chip.qcIcon.__texCoord, ","), "0,1,0,1", "not repainted in combat")
    assertEqual(#m.blocked, 0, "no protected call")
    combat(m, false)
    m.__fireTimers()
    assertEqual(table.concat(chip.qcIcon.__texCoord, ","), "0.2,0.8,0.2,0.8", "repainted at combat end")
end)

test("glow: a wedge glows on its icon too, and on hover", function()
    local NS, _, lib = live()
    local did = NS.db.profile.dialOrder[1]
    set(NS, "dial.icon.glowEnabled", true, did)
    set(NS, "dial.icon.glowWhen", "hover", did)
    local snap = NS.Situation.Current()
    local plan = NS.Surfaces.BuildDialPlan(did, NS.db.profile.dials[did], snap, NS.Surfaces.Deps(snap))
    lib.calls = {}
    assertTrue(NS.Dial.Apply(1, did, plan))
    assertEqual(#lib.calls, 0)
    local w = NS.Dial.RingWedges(did, 1)[1]
    w:__fire("OnEnter")
    assertEqual(names(lib), "PixelGlow_Start")
    assertTrue(lib.calls[1][2] == w.qcIconFrame)
    w:__fire("OnLeave")
    assertEqual(names(lib), "PixelGlow_Start,PixelGlow_Stop")
end)
