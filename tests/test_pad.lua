-- tests/test_pad.lua — modules/Pad.lua (spec §10): the pad's frames and chips. Each chip is a pooled
-- secure send button armed with its baked line; a refused chip is disarmed; visibility goes through
-- the state driver; the drag strip shows while unlocked, and will not drag while locked or in combat.

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

local function pull(NS) return NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1] end

test("pad: the default pad shows the M+ callouts, each chip armed with its baked line", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    assertEqual(inst.root.__name, "QuickCommsPadp1")
    assertTrue(inst.root:IsShown())
    local _, active = NS.Pool.Counts(inst.chips)
    assertEqual(active, 20, "M+'s eight and In Group's twelve")
    local chip = pull(NS)
    assertEqual(chip:GetAttribute("type"), "macro")
    assertEqual(chip:GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(chip.qcLabel:GetText(), "Pulling")
    assertTrue(chip.qcTag == nil, "no channel letter on the chip")
    assertEqual(NS.PadRender.TooltipLines(chip.qcSlot)[3], "Channel: |cffababffParty|r", "the tooltip names it")
    m.__click(chip)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p Pulling next pack")
    assertEqual(inst.header.qcSituation:GetText(), "M+ +12")
end)

test("pad: [review 5] a refused chip is dimmed and disarmed: a click sends and reports nothing", function()
    local NS, m = live()
    local cid = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    cid = NS.Library.AddToGroup(gid, cid)
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
    -- M+ alone: In Group (active in any party, bg buttons) off before the count
    NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.group"))
    NS.Pad.Apply("p1", planFor(NS))
    local before = NS.SendEngine.ButtonCount()   -- the pad's eight chips and the default dial's wedges
    NS.SchemaRuntime.Set("group.enabled", false, T.seeded(NS, "bi.mplus"))
    NS.Pad.Apply("p1", planFor(NS))
    local free, active = NS.Pool.Counts(inst.chips)
    assertEqual(active, 0)
    assertEqual(free, 20, "the twenty chips M+ and In Group drew, parked")
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    NS.SchemaRuntime.Set("group.enabled", true, T.seeded(NS, "bi.mplus"))
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(NS.SendEngine.ButtonCount(), before, "the same buttons, reused")
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
    assertEqual(p, "TOP")
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
    assertEqual(p, "TOP")
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
    -- Arathi Basin's own set comes first (phase 4), so its own map-wide callouts are the first tab
    -- (groups polish), then its first node.
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.hold")), 1)
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.stables.attack")), 0)
    assertTrue(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.stables.attack")), 1)
    assertTrue(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.lumbermill.attack")), 1)
    combat(m, true)
    assertFalse(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.lumbermill.attack")), 1, "unchanged in combat")
    assertEqual(#m.blocked, 0)
end)

test("pad: collapse hides the chips out of combat and is refused, with one line, in it", function()
    local NS, m = applied()
    assertTrue(NS.Pad.ToggleCollapsed("p1"))
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.mplus.pull")), 0)
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
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, T.seeded(NS, "bi.mplus.pull"), "p1", "dropped")
    assertTrue(chip.qcFlash:IsShown())
    m.__fireTimers()
    assertFalse(chip.qcFlash:IsShown())
    m.__click(chip)
    local other = NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.mplus.lust"))[1]
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
    for _, b in ipairs(NS.SendEngine.ArmedButtons()) do assertTrue(b.qcMeta.surfaceId ~= "p1", "only the dial's stay armed") end
    assertFalse(inst.live)
end)

-- ── the fix wave ────────────────────────────────────────────────────────────────────────────

local function pointOf(inst)
    local p, _, rel, x, y = inst.root:GetPoint(1)
    return table.concat({ tostring(p), tostring(rel), tostring(x), tostring(y) }, ",")
end

local function userGroup(NS, fields)
    local cid = assert(NS.Library.CreateCallout(fields))
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    cid = NS.Library.AddToGroup(gid, cid)
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    return cid
end

test("pad: [fix wave] a profile switch, a switch back and a profile reset each move the pad to that profile's point", function()
    local NS = live()
    local inst = NS.Pad.Instance("p1")
    NS.Library.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 40, -60 })
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(pointOf(inst), "TOPLEFT,TOPLEFT,40,-60")
    NS.addon.db:SetProfile("Other")
    -- red under: drop the applyPoint in Pad.Apply (the frame keeps Default's place)
    assertEqual(pointOf(inst), "TOP,CENTER,0,-150", "Other has no point: the default")
    NS.addon.db:SetProfile("Default")
    assertEqual(pointOf(inst), "TOPLEFT,TOPLEFT,40,-60", "back to Default's own point")
    NS.addon.db:ResetProfile()
    assertNil(NS.db.profile.pads.p1.point)
    assertEqual(pointOf(inst), "TOP,CENTER,0,-150", "reset: the default")
end)

test("pad: [fix wave] a rebuild during a drag leaves the dragged frame where the cursor has it", function()
    local NS, m = applied()
    local inst = startDrag(NS, m)
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(pointOf(inst), "TOPLEFT,TOPLEFT,25,-35")
    inst.handle:__fire("OnDragStop")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,25,-35")
end)

local function countStops(inst)
    local n = { 0 }
    local orig = inst.root.StopMovingOrSizing
    inst.root.StopMovingOrSizing = function(self, ...)
        n[1] = n[1] + 1
        return orig(self, ...)
    end
    return n
end

test("pad: [fix wave] a held drag survives a profile switch in combat: stopped at combat end, nothing blocked", function()
    local NS, m = applied()
    local inst = startDrag(NS, m)
    local stops = countStops(inst)
    m.__setCombat(true)
    m.__fire("PLAYER_REGEN_DISABLED")
    NS.addon.db:SetProfile("Other")
    -- red under: the profile switch drops the whole combat-end queue (padDrag with it)
    assertTrue(NS.SendEngine.Snapshot()[1] == "padDrag", "padDrag kept")
    combat(m, false)
    assertEqual(stops[1], 1, "the root is stopped once combat ends")
    assertEqual(#m.blocked, 0)
    assertNil(NS.db.profile.pads.p1.point, "the old profile's drag is not saved into Other")
    assertEqual(pointOf(inst), "TOP,CENTER,0,-150", "Other's place")
end)

test("pad: [fix wave] a held drag on a stand-down in combat is stopped by the held teardown", function()
    local NS, m = applied()
    local inst = startDrag(NS, m)
    local stops = countStops(inst)
    m.__setCombat(true)
    m.__fire("PLAYER_REGEN_DISABLED")
    NS.SchemaRuntime.Set("enabled", false)
    combat(m, false)
    -- red under: drop the held-drag stop in Pad.Release
    assertEqual(stops[1], 1)
    assertEqual(#m.blocked, 0)
end)

test("pad: [fix wave] a locked chip's press is not tracked: no guard, no drop, one lock note", function()
    local NS, m = live({})
    local cid = userGroup(NS, { name = "Inc", text = "Incoming", channel = "party" })
    NS.Pad.Apply("p1", planFor(NS))
    local chip = NS.Pad.ChipsFor("p1", cid)[1]
    assertEqual(chip:GetAttribute("macrotext"), "/p Incoming", "locked, still armed")
    assertTrue(chip.qcLock:IsShown())
    local heard = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function(_, _, _, what) heard[#heard + 1] = what end)
    m.prints = {}
    m.__now = 100
    m.__click(chip)
    -- red under: track a locked press like any other (a 'dropped' blaming the spam guard)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
    assertNil(NS.SendEngine.GuardState().last, "no guard stamp")
    assertFalse(chip.qcCool:IsShown(), "no dim")
    m.__now = 103
    m.__fireTimers()
    assertEqual(#heard, 0)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Locked: you are not in a group.", 1, true) ~= nil, m.prints[1])
end)

test("pad: [fix wave] tabs switch on a wheel over a chip or the pad, not only the header", function()
    local NS = live(AB)
    NS.db.profile.pads.p1.groupsAs = "tabs"
    NS.Pad.Apply("p1", planFor(NS))
    local chip = NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.hold"))[1]
    -- red under: enable the wheel on the header alone
    chip:__fire("OnMouseWheel", -1)
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.stables.attack")), 1)
    NS.Pad.Instance("p1").root:__fire("OnMouseWheel", 1)
    assertEqual(#NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.bg.ab.hold")), 1, "back to the set's own tab")
end)

test("pad: [fix wave] in combat Reset position, Apply and Release do no protected work; combat end anchors", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    NS.Library.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 40, -60 })
    NS.Pad.Apply("p1", planFor(NS))
    combat(m, true)
    NS.Pad.ResetPositions()
    -- red under: anchor directly in ResetPositions (no RunOrQueue)
    assertEqual(#m.blocked, 0)
    assertEqual(pointOf(inst), "TOPLEFT,TOPLEFT,40,-60", "unchanged in combat")
    -- red under: drop the inCombat guard in Pad.Apply / Pad.Release
    assertFalse(NS.Pad.Apply("p1", planFor(NS)))
    assertFalse(NS.Pad.Release("p1"))
    assertEqual(#m.blocked, 0)
    combat(m, false)
    assertEqual(pointOf(inst), "TOP,CENTER,0,-150")
    assertEqual(#m.blocked, 0)
end)

test("pad: [review 5] too long, and solo with no fallback: dimmed, disarmed, the reason shown, a click does nothing", function()
    local NS, m = live({})
    NS.SchemaRuntime.Set("behavior.soloFallback", "none")
    local long = userGroup(NS, { name = "Long", text = string.rep("x", 300), channel = "say" })
    local solo = userGroup(NS, { name = "Solo", text = "Hi", channel = "smartGroup" })
    NS.Pad.Apply("p1", planFor(NS))
    local heard = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() heard = heard + 1 end)
    for cid, reason in pairs({ [long] = "Too long: a chat line holds 255 bytes.", [solo] = "You are not in a group." }) do
        local chip = NS.Pad.ChipsFor("p1", cid)[1]
        assertNil(chip:GetAttribute("type"), cid)
        assertTrue(chip.qcDim:IsShown(), cid)
        assertEqual(NS.PadRender.TooltipLines(chip.qcSlot)[2], reason)
        local before = #m.sentMacros
        m.prints = {}
        m.__click(chip)
        assertEqual(#m.sentMacros, before)
        assertEqual(#m.prints, 0)
    end
    assertEqual(heard, 0)
end)

test("pad: [phase 3] a held drag whose stand-down is canceled in the same combat is stopped at combat end", function()
    local NS, m = applied()
    local inst = startDrag(NS, m)
    local stops = countStops(inst)
    m.__setCombat(true)
    m.__fire("PLAYER_REGEN_DISABLED")
    NS.SchemaRuntime.Set("enabled", false)   -- the stand-down drops `padDrag` and holds the teardown
    NS.SchemaRuntime.Set("enabled", true)    -- the stand-up cancels the held teardown
    assertTrue(inst.dragHeld == true, "still held while combat lasts")
    combat(m, false)
    -- red under: drop refileHeldDrags from Pad's NS.STAND_UP step (dragHeld sticks; the root is never stopped)
    assertEqual(stops[1], 1)
    assertNil(inst.dragHeld)
    assertEqual(#m.blocked, 0)
    assertEqual(pointOf(inst), "TOP,CENTER,0,-150", "the drop was never saved: back to the saved point")
end)

test("pad: [phase 3] a new drag clears a stale held stop, so the next rebuild re-anchors", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    inst.dragHeld = true
    startDrag(NS, m)
    -- red under: drop `inst.dragHeld = nil` from the strip's onDragStart in modules/Pad.lua
    assertNil(inst.dragHeld)
    inst.handle:__fire("OnDragStop")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,25,-35")
    NS.Library.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 40, -60 })
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(pointOf(inst), "TOPLEFT,TOPLEFT,40,-60")
end)

test("pad: [phase 3] the header's tooltip says why each group shows, unless the player turned it off", function()
    local NS = applied()
    local shown = {}
    NS.PadRender.ShowLines = function(_, title, lines) shown[#shown + 1] = { title = title, lines = lines } end
    local header = NS.Pad.Instance("p1").header
    header:__fire("OnEnter")
    -- red under: drop the Pad.ShowWhy call from the header's OnEnter
    assertEqual(#shown, 1)
    assertEqual(shown[1].title, "Why is this showing?")
    assertEqual(shown[1].lines[1], "Dungeon (generic): Content")
    header:__fire("OnLeave")
    NS.SchemaRuntime.Set("behavior.whyTooltips", false)
    header:__fire("OnEnter")
    assertEqual(#shown, 1, "behavior.whyTooltips off: no tooltip")
end)

-- A LibSharedMedia with one font and one border, loaded before the addon reads it (core/MediaSetup.lua).
local function withMedia(mm)
    local lsm = mm.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    local media = { font = { Arial = "Fonts\\ARIALN.TTF" }, border = { Tooltip = "Interface\\Tooltips\\UI-Tooltip-Border" } }
    function lsm.Register() end
    function lsm.IsValid() return true end
    function lsm.HashTable(_, kind) return media[kind] or {} end
    function lsm.Fetch(_, kind, name) return media[kind] and media[kind][name] end
    lsm.MediaType = {}
end

test("pad: [phase 5] the pad wears its Look: the chips' font and the edge and body it was given", function()
    local NS = T.enableAddon{ mock = withMedia }
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local skins = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin) skins[frame] = skin return apply(frame, skin) end
    local S = NS.SchemaRuntime
    assertTrue(S.Set("pad.look.font", "Arial", "p1"))
    assertTrue(S.Set("pad.look.fontSize", 13, "p1"))
    assertTrue(S.Set("pad.look.borderStyle", "Tooltip", "p1"))
    assertTrue(S.Set("pad.look.background", { r = 0.2, g = 0.1, b = 0, a = 1 }, "p1"))
    local label = NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1].qcLabel
    assertEqual(label.__font[1] .. "," .. label.__font[2], "Fonts\\ARIALN.TTF,13")
    local skin = skins[NS.Pad.Instance("p1").root]
    assertEqual(skin.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border")
    assertEqual(table.concat(skin.bg, ","), "0.2,0.1,0,1")
end)

test("pad: [window] the header wears its own block: gold small text over nothing by default, then what it is given", function()
    local NS = T.enableAddon{ mock = withMedia }
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local skins = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin) skins[frame] = skin return apply(frame, skin) end
    NS.Surfaces.Request("test")
    local header = NS.Pad.Instance("p1").header
    local sit = header.qcSituation
    assertEqual(table.concat(sit.__color, ","), "1,0.82,0,1", "GameFontNormalSmall's gold, as before")
    assertEqual(sit.__font[2], 10)
    assertEqual(table.concat(sit.__shadow, ","), "1,-1")
    assertEqual(header.__h, 22, "slightly larger than the 18 it was")
    -- red under: Pad.Apply skinning the header with the pad's own Look (a second edge and body)
    assertNil(skins[header].edgeFile, "no edge by default")
    assertEqual(skins[header].bg[4], 0, "no background by default")
    local S = NS.SchemaRuntime
    assertTrue(S.Set("pad.header.fontSize", 14, "p1"))
    assertTrue(S.Set("pad.header.font", "Arial", "p1"))
    assertTrue(S.Set("pad.header.background", { r = 0.1, g = 0.2, b = 0.3, a = 0.5 }, "p1"))
    assertTrue(S.Set("pad.header.borderSize", 2, "p1"))
    assertEqual(sit.__font[1] .. "," .. sit.__font[2], "Fonts\\ARIALN.TTF,14")
    assertEqual(header.qcLockdown.__font[2], 14, "the lockdown chip takes the header's size")
    assertEqual(table.concat(header.qcLockdown.__color, ","), "1,0.1,0.1,1", "and keeps its red")
    assertEqual(table.concat(skins[header].bg, ","), "0.1,0.2,0.3,0.5")
    assertEqual(skins[header].edgeFile, "Interface\\Buttons\\WHITE8x8")
    assertEqual(skins[header].edgeSize, 2)
    assertEqual(skins[header].innerBorder[4], 0, "never the Ka0s inner line")
end)

test("pad: [window] the header's text starts at the section titles' left edge, in every growth", function()
    local NS = live(AB)
    local PL = NS.PadLayout
    local inst = NS.Pad.Instance("p1")
    for _, growth in ipairs({ "right", "left", "rightUp", "leftUp" }) do
        assertTrue(NS.SchemaRuntime.Set("pad.layout.growth", growth, "p1"))
        local point, rel, relPoint, x = inst.header.qcSituation:GetPoint(1)
        -- red under: the situation anchored at LEFT 6 (a few pixels right of the titles)
        assertEqual(point .. "," .. relPoint .. "," .. x, "LEFT,LEFT," .. PL.PAD, growth)
        assertTrue(rel == inst.header, "on the header, which spans the pad")
        local titles = 0
        for _, fs in ipairs(inst.titles.active) do
            local p, r, rp, tx = fs:GetPoint(1)
            if p == "TOPLEFT" and r == inst.root and rp == "TOPLEFT" and tx == PL.PAD then titles = titles + 1 end
        end
        assertTrue(titles > 0, growth .. ": a section title on the same left edge")
    end
end)

test("pad: [review 5] a font or border this machine does not have draws the default, with no error", function()
    local NS, m = T.enableAddon{ mock = withMedia }
    m.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local skins = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin) skins[frame] = skin return apply(frame, skin) end
    -- a shared pad, or a media addon since removed: the names are stored, the media is not here
    assertTrue(NS.SchemaRuntime.Set("pad.look.font", "Gone Font", "p1"))
    assertTrue(NS.SchemaRuntime.Set("pad.look.borderStyle", "Gone Border", "p1"))
    local label = NS.Pad.ChipsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1].qcLabel
    assertEqual(label.__font[1], "Fonts\\FRIZQT__.TTF")
    assertEqual(skins[NS.Pad.Instance("p1").root].edgeFile, "Interface\\Buttons\\WHITE8x8")
end)

-- ── icons and polish (2026-10-19): the title, the growth edge ───────────────────────────────

local function pointsOf(frame)
    local out = {}
    for i = 1, #(frame.__points or {}) do
        local p, rel, relPoint, x, y = frame:GetPoint(i)
        out[#out + 1] = table.concat({ tostring(p), rel == nil and "nil" or (rel.__name or "frame"),
            tostring(relPoint), tostring(x), tostring(y) }, ",")
    end
    return table.concat(out, " | ")
end

test("pad: [B1] a group named as the header's situation draws no title row of its own", function()
    local NS = live()
    local cid = assert(NS.Library.CreateCallout({ name = "Go", text = "Go", channel = "party" }))
    local gid = NS.Library.CreateGroup({ name = "m+ +12" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    NS.Pad.Apply("p1", planFor(NS))
    local inst = NS.Pad.Instance("p1")
    assertEqual(inst.header.qcSituation:GetText(), "M+ +12")
    -- red under: Pad.Apply not passing the situation to PL.Compute
    for _, fs in ipairs(inst.titles.active) do
        assertTrue(fs:GetText() ~= "m+ +12", "the situation is not drawn twice")
    end
end)

test("pad: [B2] down growth pins the pad's top edge; the header is on top and the strip above", function()
    local NS = applied()
    local inst = NS.Pad.Instance("p1")
    -- red under: applyPoint anchoring the stored CENTER point (a resize drifts both ways)
    assertEqual(pointOf(inst), "TOP,CENTER,0,-150")
    assertEqual(pointsOf(inst.header), "TOPLEFT,QuickCommsPadp1,TOPLEFT,0,0 | TOPRIGHT,QuickCommsPadp1,TOPRIGHT,0,0")
    assertEqual(pointsOf(inst.handle), "BOTTOM,QuickCommsPadp1,TOP,0," .. NS.DRAG_GAP)
end)

test("pad: [B2] up growth pins the bottom edge, puts the header at the bottom and the strip below", function()
    local NS, m = live()
    NS.db.profile.pads.p1.layout.growth = "rightUp"
    NS.Pad.Apply("p1", planFor(NS))
    local inst = NS.Pad.Instance("p1")
    assertEqual(pointOf(inst), "BOTTOM,CENTER,0,-150")
    assertEqual(pointsOf(inst.header),
        "BOTTOMLEFT,QuickCommsPadp1,BOTTOMLEFT,0,0 | BOTTOMRIGHT,QuickCommsPadp1,BOTTOMRIGHT,0,0")
    assertEqual(pointsOf(inst.handle), "TOP,QuickCommsPadp1,BOTTOM,0," .. -NS.DRAG_GAP)
    -- A drop is saved as the bottom edge, so the reload and every resize keep the strip where it was.
    local h = inst.root.__h
    startDrag(NS, m)
    inst.handle:__fire("OnDragStop")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "BOTTOMLEFT,TOPLEFT,25," .. (-35 - h))
    NS.Pad.ToggleCollapsed("p1")
    assertEqual(pointOf(inst), "BOTTOMLEFT,TOPLEFT,25," .. (-35 - h), "a resize keeps the bottom edge")
    assertTrue(inst.root.__h < h, "collapsed is shorter")
    NS.db.profile.pads.p1.layout.growth = "right"
    NS.Pad.ToggleCollapsed("p1")
    assertEqual(pointsOf(inst.header), "TOPLEFT,QuickCommsPadp1,TOPLEFT,0,0 | TOPRIGHT,QuickCommsPadp1,TOPRIGHT,0,0",
        "a growth change re-anchors the header")
end)

-- The client measures a string without its color escapes; the stand-in does the same, 6 per letter.
local function measureLikeTheClient(m)
    local fs = { text = "" }
    function fs.SetText(self, v) self.text = v or "" end
    function fs.GetStringWidth(self)
        return 6 * #(self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    m.LibStub("LibKa0s-Widgets-1.0").__DragHandleMeasurer = function() return fs end
end

test("pad: [R3] the strip reads the pad's name and PREVIEW / TEST MODE, spans the pad, and shows while locked", function()
    local NS, m = live()
    measureLikeTheClient(m)
    NS.db.profile.pads.p1.name = "A rather long raid pad name"
    local inst = NS.Pad.Instance("p1")
    local widths = {}
    inst.handle.SetWidth = function(_, w) widths[#widths + 1] = w end
    NS.Pad.Apply("p1", planFor(NS))
    -- red under: the strip keeping the label it was built with (a rename never reached it)
    assertEqual(inst.handle.label:GetText(), "A rather long raid pad name")
    assertTrue(NS.Setting("locked"))
    assertFalse(inst.handle:IsShown(), "locked and live: no strip")
    NS.Preview.SetTestMode(true)
    assertEqual(inst.handle.label:GetText(), "A rather long raid pad name  |cff19ff19TEST MODE|r")
    -- red under: ApplyLock hiding the strip on a locked pad in test mode (the marker would vanish)
    assertTrue(inst.handle:IsShown(), "locked, test mode still shows the strip that carries the marker")
    local reserve = inst.handle:Reserve() * 2
    assertTrue(6 * #"A rather long raid pad name  TEST MODE" + reserve < inst.root.__w, "the label fits the pad")
    -- red under: ApplyWidth(0) in Pad.ApplyLock (the strip shrinks to its label, narrower than the pad)
    assertEqual(widths[#widths], inst.root.__w, "the strip spans the pad")
    -- red under: canDrag ignoring the lock now that the strip shows while locked
    inst.handle:__fire("OnDragStart")
    assertFalse(inst.dragging == true, "a locked strip does not drag")
    NS.Preview.SetTestMode(false)
    assertEqual(inst.handle.label:GetText(), "A rather long raid pad name")
    assertFalse(inst.handle:IsShown())
    NS.SchemaRuntime.Set("locked", false)
    NS.Pad.ApplyLock()
    assertTrue(inst.handle:IsShown())
    assertEqual(widths[#widths], inst.root.__w, "unlocked, it still spans the pad")
    -- A name longer than the pad widens the strip past it, as the widget's floor allows: never cut off.
    local long = string.rep("Long name ", 8)
    NS.db.profile.pads.p1.name = long
    NS.Pad.Apply("p1", planFor(NS))
    assertTrue(6 * #long + reserve > inst.root.__w, "this one is wider than the pad")
    assertEqual(widths[#widths], 6 * #long + reserve, "the strip grows to fit a label wider than the pad")
    assertNil(inst.header.qcTest, "the header carries no marker of its own")
end)

test("pad: [bg buttons] the strip matches the pad's width through a resize, and below an up-growing pad", function()
    local NS = live()
    NS.SchemaRuntime.Set("locked", false)
    local inst = NS.Pad.Instance("p1")
    local widths = {}
    inst.handle.SetWidth = function(_, w) widths[#widths + 1] = w end
    NS.Pad.Apply("p1", planFor(NS))
    assertTrue(inst.handle:IsShown())
    local wide = inst.root.__w
    -- red under: ApplyWidth(0) in Pad.ApplyLock
    assertEqual(widths[#widths], wide, "the strip spans the pad")
    -- a resize: one column narrows the pad, and the strip follows it
    NS.db.profile.pads.p1.layout.orientation = "vertical"
    NS.Pad.Apply("p1", planFor(NS))
    assertTrue(inst.root.__w < wide, "the pad is narrower")
    assertEqual(widths[#widths], inst.root.__w, "the strip follows the resize")
    -- up growth: the strip sits below the pad, the same width
    NS.db.profile.pads.p1.layout.growth = "rightUp"
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(pointsOf(inst.handle), "TOP,QuickCommsPadp1,BOTTOM,0," .. -NS.DRAG_GAP)
    assertEqual(widths[#widths], inst.root.__w, "below the pad, still its width")
end)

-- ── groups polish (2026-10-19) R4: right-click a section title to edit its group ─────────────

local function hits(NS)
    return NS.Pad.Instance("p1").titleHits.active
end

local function spyEdit(NS)
    local opened = {}
    NS.addon.EditGroup = function(_, gid) opened[#opened + 1] = gid return true end
    return opened
end

test("pad: [R4] each drawn title takes a right-click to edit its group; a left-click does nothing", function()
    local NS = live(AB)
    local opened = spyEdit(NS)
    local plan = planFor(NS)
    NS.Pad.Apply("p1", plan)
    local inst = NS.Pad.Instance("p1")
    -- red under: titles drawn as font strings alone, with nothing to click
    assertTrue(#hits(NS) > 0, "a hit frame per title")
    assertEqual(#hits(NS), #inst.titles.active, "one per drawn title")
    local ids = {}
    for _, sec in ipairs(plan.sections) do ids[sec.groupId] = true end
    for _, hit in ipairs(hits(NS)) do
        assertTrue(ids[hit.qcGroupId], "names a section's group")
        assertTrue(hit:IsShown())
    end
    local hit = hits(NS)[1]
    hit:__fire("OnClick", "LeftButton")
    assertEqual(#opened, 0, "left-click is unchanged: nothing")
    hit:__fire("OnClick", "RightButton")
    assertEqual(opened[1], hit.qcGroupId)
end)

test("pad: [R4] the title's tooltip says Right-click to edit this group", function()
    local NS = live(AB)
    NS.Pad.Apply("p1", planFor(NS))
    local shown = {}
    NS.PadRender.ShowLines = function(_, title, lines) shown[#shown + 1] = { title = title, lines = lines } end
    local hit = hits(NS)[1]
    hit:__fire("OnEnter")
    assertEqual(shown[1].title, NS.Library.Group(hit.qcGroupId).name)
    assertEqual(shown[1].lines[1], "Right-click to edit this group.")
end)

test("pad: [R4] in tabs mode the tab's title edits the group the tab shows; the wheel moves it", function()
    local NS = live(AB)
    local opened = spyEdit(NS)
    NS.db.profile.pads.p1.groupsAs = "tabs"
    local plan = planFor(NS)
    NS.Pad.Apply("p1", plan)
    assertEqual(#hits(NS), 1)
    assertEqual(hits(NS)[1].qcGroupId, plan.sections[1].groupId)
    assertTrue(NS.Pad.Wheel("p1", -1))
    assertEqual(#hits(NS), 1, "the last tab's hit frame went back to the pool")
    hits(NS)[1]:__fire("OnClick", "RightButton")
    assertEqual(opened[1], plan.sections[2].groupId, "a nested node's own group")
end)

test("pad: [R4] merged pads, collapsed pads and test mode's placeholder groups have no title to click", function()
    local NS = live(AB)
    NS.db.profile.pads.p1.groupsAs = "merged"
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(#hits(NS), 0, "merged draws no titles")
    NS.db.profile.pads.p1.groupsAs = "sections"
    NS.Pad.Apply("p1", planFor(NS))
    assertTrue(#hits(NS) > 0)
    NS.Pad.ToggleCollapsed("p1")
    assertEqual(#hits(NS), 0, "collapsed")
    NS.Pad.ToggleCollapsed("p1")
    NS.Preview.SetTestMode(true)
    -- red under: a hit frame on a "test.N" placeholder that names no group
    assertEqual(#hits(NS), 0, "test mode's groups are placeholders")
    NS.Preview.SetTestMode(false)
    NS.Pad.Release("p1")
    assertEqual(#hits(NS), 0, "a released pad keeps none")
end)

-- ── bg subgroups (2026-10-20): Alterac Valley's objectives side by side ──────────────────────

local AV = { inInstance = true, instanceType = "pvp", instanceID = 30, inGroup = true, inRaid = true,
    inInstanceGroup = true }

test("pad: [bg subgroups] Alterac Valley draws its nineteen objectives two to a row, each title its block wide", function()
    local NS = live(AV)
    local plan = planFor(NS)
    local av = T.seeded(NS, "bi.bg.av")
    local kids = 0
    for _, sec in ipairs(plan.sections) do if sec.parentId == av then kids = kids + 1 end end
    -- red under: no parentId on a child's section in modules/Surfaces.lua
    assertEqual(kids, 19, "each objective's section names its set")
    assertTrue(NS.Pad.Apply("p1", plan))
    local inst = NS.Pad.Instance("p1")
    -- record the size and width each pooled title and hit frame is given (the mock answers none),
    -- then draw the same plan again on the same pooled frames
    for _, hit in ipairs(hits(NS)) do rawset(hit, "SetSize", function(self, w, h) self.__sz = { w, h } end) end
    for _, fs in ipairs(inst.titles.active) do rawset(fs, "SetWidth", function(self, w) self.__w = w end) end
    assertTrue(NS.Pad.Apply("p1", plan))
    local byGroup = {}
    for _, hit in ipairs(hits(NS)) do byGroup[hit.qcGroupId] = hit end
    local first, second = byGroup[T.seeded(NS, "bi.bg.av.vanndar")], byGroup[T.seeded(NS, "bi.bg.av.dbnorth")]
    assertTrue(first ~= nil and second ~= nil, "each objective's title takes a right-click")
    -- the default pad: a four-column grid of 100-pixel chips, 4 apart
    assertEqual(second.__sz[1], 204, "the second's hit frame is its block wide")
    assertEqual(first.__sz[1], 204)
    assertTrue(byGroup[av].__sz[1] > 204, "the set's own title row spans the pad")
    local sized, auto = 0, 0
    for _, fs in ipairs(inst.titles.active) do
        if fs.__w == 204 then sized = sized + 1 elseif fs.__w == 0 then auto = auto + 1 end
    end
    assertEqual(sized, 18, "each paired objective's title stops at its block; the nineteenth has a row to itself")
    assertEqual(sized + auto, #inst.titles.active, "every other title sizes to its text")
end)
