-- tests/test_dial.lua — modules/Dial.lua and modules/Dial_Render.lua (spec §11): the dial's frames built
-- from a plan, armed wedges, the hub and the pointer. From Task 7: the rebuild edge, the keys and the
-- exit paths; from Task 8: Bindings.xml.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

-- A plan for the default dial straight from slots, without Surfaces: the M+ set's first `n` callouts
-- baked under the current snapshot, as one group (or two, with `second`).
local function planOf(NS, opts)
    opts = opts or {}
    local snap = NS.Situation.Current()
    local group = { id = "bi.mplus", title = "M+ (generic)", slots = {} }
    for i, cid in ipairs(NS.BuiltIns.groups["bi.mplus"].callouts) do
        if i > (opts.n or 8) then break end
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    local rings, open = NS.DialLayout.Rings({ group }, { slices = opts.slices or 4, title = "Comms Dial" })
    return { kind = "dial", surfaceId = "d2", snapshot = snap, order = { "bi.mplus" }, active = {}, rings = rings,
        openRing = open, lockdownChip = opts.lockdown == true, test = opts.test }
end

test("dial: Apply builds QuickCommsDial<n> with a ring per page, each callout wedge armed with its baked line", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    assertEqual(inst.header:GetName(), "QuickCommsDial1")
    assertFalse(inst.header:IsShown(), "closed until its key opens it")
    local _, rings = NS.Pool.Counts(inst.rings)
    assertEqual(rings, 4, "the group ring, then three pages of eight callouts on four wedges")
    local w = NS.Dial.WedgesFor("d2", "bi.mplus.pull")[1]
    assertEqual(w:GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(w.qcLabel:GetText(), "Pulling")
    assertEqual(NS.DialRender.WedgeLines(w.qcItem)[2], "/p Pulling next pack")
    m.__click(inst.header, "Toggle")
    assertTrue(NS.Dial.IsOpen("d2"))
    assertEqual(NS.Dial.ShownRing("d2"), 2, "one group: open straight on its ring")
    m.__click(w)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p Pulling next pack")
    assertFalse(NS.Dial.IsOpen("d2"))
end)

test("dial: a refused callout is a dimmed, disarmed wedge; a ring wedge is disarmed", function()
    local NS = live()
    local cid = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    local plan = planOf(NS)
    local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), NS.Situation.Current(), {})
    slot.surfaceId = "d2"
    plan.rings[2].items[1] = { kind = "send", slot = slot, title = "Bad" }
    NS.Dial.Apply(1, "d2", plan)
    local w = NS.Dial.WedgesFor("d2", cid)[1]
    assertNil(w:GetAttribute("type"))
    assertTrue(w.qcDim:IsShown())
    local ringWedge = NS.Dial.RingWedges("d2", 1)[1]
    assertEqual(ringWedge.qcItem.kind, "ring")
    assertNil(ringWedge:GetAttribute("type"))
end)

test("dial: the hub shows the lockdown chip, the stale hint and TEST MODE; the pointer runs only while open", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS, { lockdown = true, test = true }))
    local h = NS.Dial.Instance("d2").header
    assertTrue(h.qcLockdown:IsShown())
    assertTrue(h.qcTest:IsShown())
    NS.Dial.SetStale("d2", true)
    assertTrue(h.qcStale:IsShown())
    local pointer = h.qcPointer
    assertNil(pointer:GetScript("OnUpdate"), "closed: no OnUpdate")
    m.__click(h, "Toggle")
    -- red under: set the pointer's OnUpdate at build instead of on the hub's OnShow
    assertTrue(pointer:GetScript("OnUpdate") ~= nil)
    m.cursor.x, m.cursor.y = 300, 0
    pointer:__fire("OnUpdate", 0.01)
    assertTrue(pointer.qcArrow:IsShown())
    m.cursor.x = 2
    pointer:__fire("OnUpdate", 0.01)
    assertFalse(pointer.qcArrow:IsShown(), "inside the dead zone")
    m.__click(h, "Toggle")
    assertNil(pointer:GetScript("OnUpdate"))
end)

test("dial: a press dims every wedge and chip for the guard window; a drop stays red long enough to reopen and see", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS))
    local h = NS.Dial.Instance("d2").header
    local w = NS.Dial.WedgesFor("d2", "bi.mplus.pull")[1]
    local other = NS.Dial.WedgesFor("d2", "bi.mplus.lust")[1]
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, "bi.mplus.pull", "d2", "dropped")
    assertTrue(w.qcFlash:IsShown())
    -- red under: flash a drop for the pad's 0.4 s (gone before the closed dial can be reopened)
    assertEqual(m.__timers[#m.__timers].delay, NS.Dial.DROP_SECONDS)
    m.__fireTimers()
    assertFalse(w.qcFlash:IsShown())
    m.__click(h, "Toggle")
    m.__click(w)
    -- red under: drop the NS.Dial.Cooldown call from Pad.Cooldown
    assertTrue(other.qcCool:IsShown(), "the guard is global: every wedge dims")
    assertTrue(NS.Pad.ChipsFor("p1", "bi.mplus.lust")[1].qcCool:IsShown(), "and every chip")
    m.__fireTimers()
    assertFalse(other.qcCool:IsShown())
end)

test("dial: Release closes, disarms and forgets a dial; HideAll also releases the keys", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS))
    local h = NS.Dial.Instance("d2").header
    m.__click(h, "Toggle")
    assertTrue(NS.Dial.Release(1))
    assertFalse(h:IsShown())
    assertNil(NS.Dial.Instance("d2"))
    for _, b in ipairs(NS.SendEngine.ArmedButtons()) do assertTrue(b.qcMeta.surfaceId ~= "d2") end
    m.__click(h, "Toggle")
    assertFalse(h:IsShown(), "nothing left to open")
    NS.SendEngine.BindKeys({ { key = "G", name = "QuickCommsDial1", button = "Toggle" } })
    NS.Dial.HideAll()
    assertNil(m.overrideBindings.G)
end)

test("dial: Sync applies each planned dial at its place in the order, binds its key, and opens dial 1 in test mode", function()
    local NS, m = live()
    NS.db.profile.dials.d2.key = "G"
    NS.Dial.Sync({ d2 = planOf(NS) }, { "d2" })
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1")
    assertEqual(m.overrideBindings.G.button, "Toggle")
    assertFalse(NS.Dial.IsOpen("d2"))
    NS.Dial.Sync({ d2 = planOf(NS, { test = true }) }, { "d2" })
    assertTrue(NS.Dial.IsOpen("d2"), "test mode shows dial 1 open")
    NS.Dial.Sync({}, { "d2" })
    assertNil(NS.Dial.Instance("d2"))
    assertNil(m.overrideBindings.G)
end)
