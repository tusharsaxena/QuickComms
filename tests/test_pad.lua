-- tests/test_pad.lua — modules/Pad.lua (spec §10): the pad's frames and chips. Each chip is a pooled
-- secure send button armed with its baked line; a refused chip is disarmed; visibility goes through
-- the state driver; the drag strip shows only while unlocked and out of combat.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

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

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function planFor(NS)
    local snap = NS.Situation.Current()
    return NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))
end

local function applied(inputs)
    local NS, m = live(inputs)
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    return NS, m
end

local function pull(NS) return NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1] end

test("pad: the default pad shows the M+ callouts, each chip armed with its baked line", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    assertEqual(inst.root.__name, "QuickCommsPadp1")
    assertTrue(inst.root:IsShown())
    local _, active = NS.Pool.Counts(inst.chips)
    assertEqual(active, 8)
    local chip = pull(NS)
    assertEqual(chip:GetAttribute("type"), "macro")
    assertEqual(chip:GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(chip.qcLabel:GetText(), "Pulling")
    assertEqual(chip.qcTag:GetText(), "P")
    m.__click(chip)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p Pulling next pack")
    assertEqual(inst.header.qcSituation:GetText(), "M+ +12")
end)

test("pad: [review 5] a refused chip is dimmed and disarmed: a click sends and reports nothing", function()
    local NS, m = live()
    local cid = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    NS.Pad.Apply("p1", planFor(NS))
    local chip = NS.Pad.ChipsFor("p1", cid)[1]
    assertNil(chip:GetAttribute("type"))
    assertNil(chip:GetAttribute("macrotext"))
    assertTrue(chip.qcDim:IsShown())
    assertEqual(NS.PadRender.TooltipLines(chip.qcSlot)[2], "Callout text cannot start with /.")
    local heard = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() heard = heard + 1 end)
    local before = #m.sentMacros
    m.__click(chip)
    assertEqual(#m.sentMacros, before)
    assertEqual(heard, 0)
    assertEqual(pull(NS):GetAttribute("type"), "macro", "the other chips still send")
end)

test("pad: [review 4] a hidden or locked pad still rebuilds; the driver hides; the strip stays hidden", function()
    local NS, m = live()
    NS.SchemaRuntime.Set("visibility", "never")
    NS.Pad.Apply("p1", planFor(NS))
    local inst = NS.Pad.Instance("p1")
    assertFalse(inst.root:IsShown())
    assertEqual(m.stateDrivers[inst.root].visibility, "hide")
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack", "re-armed while hidden")
    assertTrue(NS.Setting("locked"))
    assertFalse(inst.handle:IsShown(), "locked: no drag strip")
    NS.SchemaRuntime.Set("visibility", "always")
    NS.Pad.Apply("p1", planFor(NS))
    assertTrue(inst.root:IsShown())
    NS.SchemaRuntime.Set("locked", false)
    NS.Pad.ApplyLock()
    assertTrue(inst.handle:IsShown())
    NS.db.profile.pads.p1.look.visibility = "outOfCombat"
    NS.Pad.Apply("p1", planFor(NS))
    combat(m, true)
    assertFalse(inst.root:IsShown(), "the driver hides it in combat")
    assertEqual(#m.blocked, 0)
end)

test("pad: a rebuild with fewer chips parks the rest, disarmed, for the next", function()
    local NS = applied()
    local inst = NS.Pad.Instance("p1")
    NS.Library.SetBuiltinEnabled("bi.mplus", false)
    NS.Pad.Apply("p1", planFor(NS))
    local free, active = NS.Pool.Counts(inst.chips)
    assertEqual(active, 0)
    assertEqual(free, 8)
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    NS.Library.SetBuiltinEnabled("bi.mplus", true)
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(NS.SendEngine.ButtonCount(), 8, "the same eight buttons, reused")
end)

test("pad: [registry] no file but Library writes a surface's point", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "modules/Library.lua" then
            local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
            local src = fh:read("*a"):gsub("%-%-[^\r\n]*", "")
            fh:close()
            -- red under: write `pad.point = …` in modules/Pad.lua instead of calling SetSurfacePoint
            assertTrue(not src:find("%.point%s*=[^=]"), rel .. " writes a surface's point")
        end
    end
end)

test("pad: the drag saves the point; locked or in combat it does not move; Reset position clears it", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    local p, _, _, _, y = inst.root:GetPoint(1)
    assertEqual(p, "CENTER")
    assertEqual(y, -150)
    local function drag(x, yy)
        inst.handle:__fire("OnDragStart")
        inst.root:ClearAllPoints()
        inst.root:SetPoint("TOPLEFT", m.UIParent, "TOPLEFT", x, yy)
        inst.handle:__fire("OnDragStop")
    end
    drag(10, -10)
    assertNil(NS.db.profile.pads.p1.point, "locked: canDrag refuses")
    NS.SchemaRuntime.Set("locked", false)
    drag(40, -60)
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,40,-60")
    NS.Pad.ResetPositions()
    assertNil(NS.db.profile.pads.p1.point)
    p = inst.root:GetPoint(1)
    assertEqual(p, "CENTER")
end)

-- Combat can begin while the player is already dragging: canDrag only guards the start. The pad
-- ends the drag itself on the combat edge, so the strip's OnDragStop never calls the protected
-- root's StopMovingOrSizing in combat.
local function startDrag(NS, m)
    NS.SchemaRuntime.Set("locked", false)
    local inst = NS.Pad.Instance("p1")
    inst.handle:__fire("OnDragStart")
    inst.root:ClearAllPoints()
    inst.root:SetPoint("TOPLEFT", m.UIParent, "TOPLEFT", 25, -35)
    return inst
end

test("pad: [fix 1] combat starting mid-drag ends the drag on the edge; the stop is never blocked", function()
    local NS, m = applied()
    local inst = startDrag(NS, m)
    combat(m, true)
    -- red under: drop the pad's RESTRICTION_CHANGED receiver (the strip then stops the root in combat)
    inst.handle:__fire("OnDragStop")
    assertEqual(#m.blocked, 0)
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,25,-35")
    assertNil(inst.dragging)
end)

test("pad: [fix 1] a drag caught after lockdown began is stopped and saved when combat ends", function()
    local NS, m = applied()
    local inst = startDrag(NS, m)
    m.__setCombat(true)
    m.__fire("PLAYER_REGEN_DISABLED")
    inst.handle:__fire("OnDragStop")
    assertEqual(#m.blocked, 0)
    assertNil(NS.db.profile.pads.p1.point, "deferred until combat ends")
    combat(m, false)
    assertEqual(#m.blocked, 0)
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,25,-35")
end)

test("pad: tabs show one section; the wheel steps them out of combat and is refused in it", function()
    local NS, m = live(AB)
    NS.db.profile.pads.p1.groupsAs = "tabs"
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.help"), 1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 0)
    assertTrue(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1)
    combat(m, true)
    assertFalse(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1, "unchanged in combat")
    assertEqual(#m.blocked, 0)
end)

test("pad: collapse hides the chips out of combat and is refused, with one line, in it", function()
    local NS, m = applied()
    assertTrue(NS.Pad.ToggleCollapsed("p1"))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.mplus.pull"), 0)
    assertEqual(NS.Pad.Instance("p1").header.qcCollapse.qcText:GetText(), "+")
    assertTrue(NS.Pad.ToggleCollapsed("p1"))
    combat(m, true)
    m.prints = {}
    assertFalse(NS.Pad.ToggleCollapsed("p1"))
    assertEqual(#m.prints, 1)
    assertEqual(#m.blocked, 0)
end)

test("pad: a send result flashes its chips; a press dims every chip for the guard window", function()
    local NS, m = applied()
    local chip = pull(NS)
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, "bi.mplus.pull", "p1", "dropped")
    assertTrue(chip.qcFlash:IsShown())
    m.__fireTimers()
    assertFalse(chip.qcFlash:IsShown())
    m.__click(chip)
    local other = NS.Pad.ChipsFor("p1", "bi.mplus.lust")[1]
    assertTrue(other.qcCool:IsShown(), "the guard is global: every chip dims")
    m.__fireTimers()
    assertFalse(other.qcCool:IsShown())
end)

test("pad: the fade follows the mouse and combat through SetAlpha alone", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    NS.db.profile.pads.p1.look.fade = "mouseover"
    NS.Pad.ApplyAlpha("p1")
    assertEqual(inst.root:GetAlpha(), 0.4)
    NS.Pad.SetHover("p1", true)
    assertEqual(inst.root:GetAlpha(), 1)
    NS.Pad.SetHover("p1", false)
    assertEqual(inst.root:GetAlpha(), 0.4)
    combat(m, true)
    NS.Pad.SetHover("p1", true)
    assertEqual(inst.root:GetAlpha(), 1, "SetAlpha is allowed in combat")
    assertEqual(#m.blocked, 0)
end)

test("pad: Sync releases a pad no plan names: hidden, its chips disarmed", function()
    local NS = applied()
    NS.Pad.Sync({})
    local inst = NS.Pad.Instance("p1")
    assertFalse(inst.root:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    assertFalse(inst.live)
end)
