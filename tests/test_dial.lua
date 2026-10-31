-- tests/test_dial.lua — modules/Dial.lua and modules/Dial_Render.lua (spec §11): the dial's frames built
-- from a plan, armed wedges, the hub and the pointer. From Task 7: the rebuild edge, the keys and the
-- exit paths; from Task 8: Bindings.xml. Select to the hub is tests/test_dial_catcher.lua's and how a
-- dial is drawn tests/test_dial_look.lua's; their shared helpers are tests/dial_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local AB, live, planOf, combat, wedgeTitled, near =
    D.AB, D.live, D.planOf, D.combat, D.wedgeTitled, D.near

test("dial: Apply builds QuickCommsDial<n> with a ring per page, each callout wedge armed with its baked line", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    assertEqual(inst.header:GetName(), "QuickCommsDial1")
    assertFalse(inst.header:IsShown(), "closed until its key opens it")
    local _, rings = NS.Pool.Counts(inst.rings)
    assertEqual(rings, 3, "the group ring, then two pages of eight callouts on four wedges")
    local w = NS.Dial.WedgesFor("d2", T.seeded(NS, "bi.mplus.pull"))[1]
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

test("dial: [audit QC-07] a wedge's padlock is a catalog mark, with the Blizzard art as the nil fallback (the hub's close retired)", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS))
    local h = NS.Dial.Instance("d2").header
    -- red under: SetTexture(LOCK_ICON) unconditionally in modules/Dial_Render.lua
    -- red under: keep the hub's close mark (dial polish retired it for the hub styles)
    assertNil(h.qcClose)
    local w = NS.Dial.RingWedges("d2", 1)[1]
    assertEqual(w.qcLock.__texture, NS.Icon("lock"))
    local real = NS.Icon
    NS.Icon = function() return nil end
    local bare = NS.DialRender.DressHub(m.CreateFrame("Frame", "QuickCommsDialProbe", m.UIParent))
    local wedge = NS.DialRender.DressWedge(m.CreateFrame("Button", "QuickCommsDialProbeWedge", m.UIParent))
    NS.Icon = real
    assertNil(bare.qcClose)
    assertEqual(wedge.qcLock.__texture, "Interface\\PetBattles\\PetBattle-LockIcon")
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

test("dial: a press dims every wedge and button for the guard window; a drop stays red long enough to reopen and see", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS))
    local h = NS.Dial.Instance("d2").header
    local w = NS.Dial.WedgesFor("d2", T.seeded(NS, "bi.mplus.pull"))[1]
    local other = NS.Dial.WedgesFor("d2", T.seeded(NS, "bi.mplus.lust"))[1]
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, T.seeded(NS, "bi.mplus.pull"), "d2", "dropped")
    assertTrue(w.qcFlash:IsShown())
    -- red under: flash a drop for the pad's 0.4 s (gone before the closed dial can be reopened)
    assertEqual(m.__timers[#m.__timers].delay, NS.Dial.DROP_SECONDS)
    m.__fireTimers()
    assertFalse(w.qcFlash:IsShown())
    m.__click(h, "Toggle")
    m.__click(w)
    -- red under: drop the NS.Dial.Cooldown call from Pad.Cooldown
    assertTrue(other.qcCool:IsShown(), "the guard is global: every wedge dims")
    assertTrue(NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.lust"))[1].qcCool:IsShown(), "and every button")
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
end)

test("dial: Sync applies each planned dial at its place in the order, and opens dial 1 in test mode", function()
    local NS = live()
    NS.Dial.Sync({ d2 = planOf(NS) }, { "d2" })
    assertEqual(NS.Dial.Instance("d2").header:GetName(), "QuickCommsDial1")
    assertFalse(NS.Dial.IsOpen("d2"))
    NS.Dial.Sync({ d2 = planOf(NS, { test = true }) }, { "d2" })
    assertTrue(NS.Dial.IsOpen("d2"), "test mode shows dial 1 open")
    NS.Dial.Sync({}, { "d2" })
    assertNil(NS.Dial.Instance("d2"))
end)

-- ── the rebuild edge, the keys and the exit paths (Task 7) ──────────────────────────────────

local RAID = { inInstance = true, instanceType = "raid", difficultyID = 15, inGroup = true, inRaid = true }

-- The dial's key, as Options -> Keybindings sets it: WoW's own binding of Open Comms Dial 1.
local function bindG(_, m) m.SetBinding("G", "CLICK QuickCommsDial1:Toggle") end

-- From the ring of groups (the dial opens there when several are active), open the one titled.
local function pick(NS, m, title)
    assertEqual(NS.Dial.ShownRing("d2"), 1, "several active groups: the dial opens on the groups")
    m.__click(wedgeTitled(NS, 1, title))
end

local function ringTitle(NS)
    local r = NS.Dial.ShownRing("d2")
    return r and NS.Surfaces.DialPlans().d2.rings[r].title
end

test("dial: the first situation read builds the default dial, closed; its key is WoW's own binding", function()
    local NS, m = live()
    local inst = NS.Dial.Instance("d2")
    assertTrue(inst ~= nil)
    assertEqual(inst.header:GetName(), "QuickCommsDial1")
    assertFalse(inst.header:IsShown())
    bindG(NS, m)
    -- red under: an override binding (SetOverrideBindingClick), which Options -> Keybindings never shows
    assertNil(next(m.overrideBindings), "no override binding")
    assertNil(NS.db.profile.dials.d2.key, "never a profile field")
    assertEqual(NS.Dial.KeyOf("d2"), "G")
    assertNil(NS.Dial.BindKey, "retired in the dial rework; the library's Keybindings tab writes the key (item 015)")
    m.__pressKey("G")
    assertTrue(NS.Dial.IsOpen("d2"))
end)

test("dial: [keys] a key set in Options -> Keybindings is the dial's key; a dial past the fourth has none", function()
    local NS, m = live()
    m.SetBinding("J", "CLICK QuickCommsDial1:Toggle")   -- what the game's own menu does
    assertEqual(NS.Dial.KeyOf("d2"), "J")
    m.__pressKey("J")
    assertTrue(NS.Dial.IsOpen("d2"))
    local ids = {}
    for i = 1, 4 do ids[i] = NS.Library.CreateSurface("dial", "Dial " .. i) end
    assertEqual(NS.Dial.PlaceOf(ids[4]), 5)
    assertNil(NS.Dial.Command(5))
    assertNil(NS.Dial.KeyOf(ids[4]), "no Open Comms Dial entry past the fourth")
end)

test("dial: [exit] in Arathi Basin the dial opens on the groups; the set, Lumber Mill, then INC sends", function()
    local NS, m = live(AB)
    bindG(NS, m)
    m.__pressKey("G")
    -- red under: open on the first group's ring in modules/Dial_Layout.lua Rings (In Group is active too)
    pick(NS, m, "Arathi Basin")
    assertEqual(ringTitle(NS), "Arathi Basin")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Lumber Mill"))
    assertEqual(ringTitle(NS), "Lumber Mill")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "INC"))
    assertEqual(m.sentMacros[#m.sentMacros].text, "/i INC Lumber Mill")
    assertEqual(#m.sentMacros, 1, "three clicks, one send")
    assertFalse(NS.Dial.IsOpen("d2"))
end)

test("dial: [exit] on a raid boss the dial opens and a click on a wedge sends, with nothing blocked", function()
    local NS, m = live(RAID)
    bindG(NS, m)
    combat(m, true)
    m.__pressKey("G")
    -- In Group is active in a raid too: the dial opens on the groups (dial rework)
    pick(NS, m, "Raid")
    assertEqual(ringTitle(NS), "Raid")
    local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    m.__click(w)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/raid Bloodlust now")
    assertFalse(NS.Dial.IsOpen("d2"))
    assertEqual(#m.blocked, 0)
end)

test("dial: [exit] the Categories two-stroke: a group wedge opens its ring, a callout wedge sends", function()
    local NS, m = live()
    local cid = NS.Library.CreateCallout({ name = "Inc", text = "INC {skull}", channel = "smartGroup" })
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.OfferGroup(gid)
    bindG(NS, m)
    m.__pressKey("G")
    assertEqual(NS.Dial.ShownRing("d2"), 1, "two active groups: the group ring")
    m.__click(wedgeTitled(NS, 1, "Mine"))
    assertEqual(ringTitle(NS), "Mine")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Inc"))
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p INC {rt8}")
    m.__pressKey("G")
    m.__click(wedgeTitled(NS, 1, "Mine"))
    m.__click(NS.Dial.Instance("d2").header, "LeftButton")
    assertEqual(NS.Dial.ShownRing("d2"), 1, "the hub goes back to the groups")
end)

test("dial: test mode opens dial 1 with placeholder wedges that send nothing, and takes no key", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    assertTrue(NS.Dial.IsOpen("d2"))
    assertTrue(NS.Dial.Instance("d2").header.qcTest:IsShown())
    -- red under: open test mode's dial with DS's key-taking open (qc-open) instead of qc-display
    assertNil(next(m.restrictedBindings), "Escape stays the settings window's, 1-8 the action bar's")
    m.__click(NS.Dial.RingWedges("d2", 1)[1])
    m.__click(NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1])
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("dial: combat start ends test mode and the live dial comes back closed", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    combat(m, true)
    assertFalse(NS.Preview.IsTestMode())
    assertFalse(NS.Dial.IsOpen("d2"))
    assertFalse(NS.Dial.Instance("d2").header.qcTest:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("dial: [review 6] test mode ended by a combat whose lockdown began first: no key held, closed at combat end", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    m.__setCombat(true)                   -- lockdown first, then the edge (the other order)
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.IsOpen("d2"), "the rebuild that closes it waits for combat end")
    assertNil(next(m.restrictedBindings), "and the placeholder dial holds no key meanwhile")
    combat(m, false)
    assertFalse(NS.Dial.IsOpen("d2"))
    assertFalse(NS.Dial.Instance("d2").header.qcTest:IsShown())
    assertNil(next(m.restrictedBindings))
    assertEqual(#m.blocked, 0)
end)

test("dial: Preview as opens dial 1 on the previewed situation, and its wedges send nothing", function()
    local NS, m = live({})
    NS.Preview.SetPreviewAs("bg:ab")
    assertTrue(NS.Dial.IsOpen("d2"))
    assertNil(next(m.restrictedBindings), "opened from the settings window: no key taken")
    pick(NS, m, "Arathi Basin")
    assertEqual(ringTitle(NS), "Arathi Basin")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Stables"))
    m.__click(NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1])
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.Dial.Instance("d2").header.qcTest:GetText(), "PREVIEW")
end)

test("dial: [review 3] a wedge change in combat waits for combat end, behind the hub's stale hint; the key works", function()
    local NS, m = live()
    bindG(NS, m)
    combat(m, true)
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 8, "d2"))
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.Instance("d2").header.qcStale:IsShown())
    m.__pressKey("G")
    assertTrue(NS.Dial.IsOpen("d2"), "the key opens the dial in combat")
    combat(m, false)
    assertEqual(m.bindingActions.G, "CLICK QuickCommsDial1:Toggle", "WoW's binding, untouched by the rebuild")
    assertFalse(NS.Dial.Instance("d2").header.qcStale:IsShown())
    assertEqual(NS.Surfaces.DialPlans().d2.rings[2].size, 8)
    assertEqual(#m.blocked, 0)
end)

test("dial: [review 1] the key opens nothing where no group is active, and is the game's again while disabled", function()
    local NS, m = live({})
    -- the World (solo) set is the one active solo in the open world (groups polish): without it, none is
    assertTrue(NS.Library.DeleteGroup(T.seeded(NS, "bi.world")))
    NS.Situation.RefreshNow("test")
    bindG(NS, m)
    m.__pressKey("G")
    assertFalse(NS.Dial.IsOpen("d2"), "solo in the open world with no World set: no ring to show")
    NS.SchemaRuntime.Set("enabled", false)
    -- red under: drop NS.Dial.HideAll() from the stand-down's Teardown in modules/Surfaces.lua
    m.__pressKey("G")
    assertFalse(NS.Dial.IsOpen("d2"), "the key is still WoW's binding, and opens nothing while disabled")
    assertEqual(#m.blocked, 0)
    NS.SchemaRuntime.Set("enabled", true)
    assertEqual(m.bindingActions.G, "CLICK QuickCommsDial1:Toggle", "kept through the stand-down")
end)

test("dial: [review 3] disabled in combat with the dial open: nothing blocked; combat end hides it and frees the key", function()
    local NS, m = live()
    bindG(NS, m)
    combat(m, true)
    m.__pressKey("G")
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.IsOpen("d2"), "held: no protected call in combat")
    combat(m, false)
    assertNil(NS.Dial.Instance("d2"))
    m.__pressKey("G")
    assertEqual(#m.blocked, 0, "the key now clicks an emptied header: nothing opens, nothing is blocked")
end)

test("dial: [keys] a profile switch keeps the key: it is WoW's binding, never the profile's", function()
    local NS, m = live()
    bindG(NS, m)
    NS.addon.db:SetProfile("Other")
    -- red under: a key stored in the profile (the Other profile's dial would have none)
    assertEqual(NS.Dial.KeyOf(NS.db.profile.dialOrder[1]), "G", "the first dial in any profile takes place 1's key")
    m.__pressKey("G")
    assertTrue(NS.Dial.IsOpen(NS.db.profile.dialOrder[1]))
    assertEqual(#m.blocked, 0)
end)

test("dial: Reset position puts every pad and dial back, through their point rows, on one line", function()
    local NS, m = live()
    assertTrue(NS.Library.SetSurfacePoint("dial", "d2", { "CENTER", "CENTER", 0, 200 }))
    local h = NS.Dial.Instance("d2").header
    assertEqual(select(5, h:GetPoint(1)), 200)
    m.prints = {}
    NS.Surfaces.ResetPositions()
    assertNil(NS.db.profile.dials.d2.point)
    assertEqual(select(5, h:GetPoint(1)), 0)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Pad and dial positions reset.", 1, true) ~= nil, m.prints[1])
end)

test("dial: the hub's tooltip says why each group shows, unless the player turned it off", function()
    local NS, m = live(AB)
    local shown = {}
    NS.DialRender.ShowTip = function(_, title, lines) shown[#shown + 1] = { title = title, lines = lines } end
    local h = NS.Dial.Instance("d2").header
    local cx, cy = h:GetCenter()
    local function at(dx)   -- the per-frame update with the cursor dx east of the hub's center
        m.cursor.x, m.cursor.y = cx + dx, cy
        NS.DialRender.PointerUpdate(h.qcPointer)
    end
    at(0)
    assertEqual(#shown, 1)
    assertEqual(shown[1].title, "Why is this showing?")
    assertEqual(shown[1].lines[1], "Arathi Basin: Content, Battleground")
    NS.SchemaRuntime.Set("behavior.whyTooltips", false)
    at(400)
    at(0)
    assertEqual(#shown, 1)
    assertEqual(NS.Surfaces.WhyLines("d9")[1], "This pad has not been built yet.")
    NS.Preview.SetTestMode(true)
    assertEqual(NS.Surfaces.WhyLines("d2")[1], "Test mode: placeholder wedges that send nothing.")
end)

-- ── Bindings.xml (Task 8; launcher-§6 since item 015) ───────────────────────────────────────────────────────────────────

test("dial: Bindings.xml is Toggle Comms Pads, then Open Comms Dial 1 to 4, all in the Ka0s Quick Comms category", function()
    -- A plain global write leaves the chunk's environment for the process's _G (tests/_kit/loader.lua
    -- makeEnv's __newindex), so the category global is read there; cleared first so this load is the
    -- writer. The labels are rawset into the environment, so the check reads the two together.
    rawset(_G, "BINDING_HEADER_QUICKCOMMS", nil)
    local NS, m = T.newAddon()
    local globals = setmetatable({}, { __index = function(_, k)
        local v = m[k]
        if v == nil then v = rawget(_G, k) end
        return v
    end })
    local labels = { ["CLICK QuickCommsTogglePads:LeftButton"] = "Toggle Comms Pads" }
    for i = 1, NS.Dial.BINDINGS do labels[("CLICK QuickCommsDial%d:Toggle"):format(i)] = ("Open Comms Dial %d"):format(i) end
    -- red under: header="QUICKCOMMS" or category="ADDONS" on any line, the toggle last, or a label's
    -- rawset dropped (launcher-§6, Kit.assertBindingsXml)
    local found = T.assertBindingsXml("Bindings.xml", {
        category = "BINDING_HEADER_QUICKCOMMS", commands = NS.BINDINGS, brand = NS.BRAND,
        globals = globals, labels = labels,
    })
    assertEqual(#found, NS.Dial.BINDINGS + 1, "Toggle Comms Pads and the four dials")
    assertEqual(found[1].name, "CLICK QuickCommsTogglePads:LeftButton", "the Show window binding first")
    -- red under: drop the BINDING_HEADER_QUICKCOMMS line from settings/SlashVerbs.lua
    assertEqual(rawget(_G, "BINDING_HEADER_QUICKCOMMS"), "Ka0s Quick Comms")
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        -- a root file, not a TOC line, as the standard allows (layout-§1, toc-file-§4 (standard v2.80.0))
        assertTrue(rel ~= "Bindings.xml", "the client loads it by name, never through the TOC")
    end
end)

test("dial: [keys] Toggle Comms Pads runs exactly /qc toggle's handler, from a key bound in WoW's menu", function()
    local NS, m = live()
    local calls = 0
    local toggle = NS.SlashVerbs.TogglePads
    NS.SlashVerbs.TogglePads = function(...)
        calls = calls + 1
        return toggle(...)
    end
    m.SetBinding("P", "CLICK QuickCommsTogglePads:LeftButton")   -- bound in Options -> Keybindings
    m.prints = {}
    assertTrue(m.__pressKey("P"))
    -- red under: the button's OnClick doing its own toggle (two handlers for one verb)
    assertEqual(calls, 1, "one press, one toggle")
    assertTrue(NS.db.char.padsHidden, "the pads are hidden on this character")
    assertEqual(#m.prints, 0, "the toggle says nothing in chat")
    m.__pressKey("P")
    assertFalse(NS.db.char.padsHidden == true, "and shown again")
    assertEqual(calls, 2)
    assertFalse(m.__named.QuickCommsTogglePads:IsShown(), "the button itself is never seen")
end)

test("dial: the key bindings menu's click opens the dial, even while it is hidden", function()
    local NS, m = live()
    local h = NS.Dial.Instance("d2").header
    assertFalse(h:IsShown())
    m.__click(h, "Toggle")   -- what "CLICK QuickCommsDial1:Toggle" does
    assertTrue(NS.Dial.IsOpen("d2"))
end)

-- ── final review fixes ──────────────────────────────────────────────────────────────────────

test("dial: [final 2] two dials: opening the second closes the first, and the number keys go with it", function()
    local NS, m = live()
    bindG(NS, m)
    local other = NS.Library.CreateSurface("dial", "Lead")
    m.SetBinding("H", "CLICK QuickCommsDial2:Toggle")
    assertTrue(NS.Dial.Instance(other) ~= nil, "the second dial is built")
    m.__pressKey("G")
    assertTrue(NS.Dial.IsOpen("d2"))
    m.__pressKey("H")
    -- red under: drop DS.Link from Dial.Sync
    assertFalse(NS.Dial.IsOpen("d2"), "one dial open at a time")
    assertTrue(NS.Dial.IsOpen(other))
    m.__pressKey("H")
    assertNil(next(m.restrictedBindings))
    assertEqual(#m.blocked, 0)
end)

test("dial: [final 5] test mode opens dial 1 once: a rebuild keeps it open, and after the player closes it, closed", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    assertTrue(NS.Dial.IsOpen("d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 8, "d2"))
    assertTrue(NS.Dial.IsOpen("d2"), "open before the rebuild: open after it")
    m.__click(NS.Dial.Instance("d2").header, "RightButton")
    assertFalse(NS.Dial.IsOpen("d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 6, "d2"))
    -- red under: open the display dial on every Dial.Sync
    assertFalse(NS.Dial.IsOpen("d2"), "closed by the player: a rebuild leaves it closed")
    NS.Preview.SetPreviewAs("bg:ab")
    assertTrue(NS.Dial.IsOpen("d2"), "a new display mode opens it again")
    assertEqual(#m.blocked, 0)
end)

test("dial: Arathi Basin's ring has six slices: its own wedge at N, then the nodes A-Z", function()
    local NS, m = live(AB)
    bindG(NS, m)
    m.__pressKey("G")
    pick(NS, m, "Arathi Basin")
    local ring = NS.Dial.ShownRing("d2")
    local function at(title)
        local _, _, _, x, y = wedgeTitled(NS, ring, title):GetPoint(1)
        return x .. "," .. y
    end
    -- red under: the nodes pinned on eight winds (Lumber Mill at Wedge(6, 8))
    local fifth, second = NS.DialLayout.Wedge(5, 6), NS.DialLayout.Wedge(2, 6)
    assertEqual(at("Lumber Mill"), fifth.x .. "," .. fifth.y)
    assertEqual(at("Blacksmith"), second.x .. "," .. second.y)
    assertEqual(#NS.Dial.RingWedges("d2", ring), 6, "no empty slice")
end)

test("dial: a four-slice dial pages Arathi Basin's ring; on six every node shows, and the number keys pick from N", function()
    local NS, m = live(AB)
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 4, "d2"))
    bindG(NS, m)
    m.__pressKey("G")
    pick(NS, m, "Arathi Basin")
    assertEqual(#NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2")), 4, "4 slices: the first page of two")
    NS, m = live(AB)
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 6, "d2"))
    bindG(NS, m)
    m.__pressKey("G")
    pick(NS, m, "Arathi Basin")
    local r = NS.Dial.ShownRing("d2")
    assertEqual(ringTitle(NS), "Arathi Basin")
    assertEqual(#NS.Dial.RingWedges("d2", r), 6, "6 slices: five nodes and the set's own, one page")
    -- clockwise from N: Arathi Basin's own, Blacksmith, Farm, Gold Mine, Lumber Mill, Stables
    m.__pressKey("5")
    assertEqual(ringTitle(NS), "Lumber Mill", "key 5 is the fifth wedge shown")
    m.__pressKey("3")
    assertEqual(m.sentMacros[#m.sentMacros].text, "/i INC Lumber Mill")
end)

test("dial: [icons] a wedge draws its glyph in its color; repainted untinted, it is white again", function()
    local NS, m = live()
    local R = NS.DialRender
    local w = R.DressWedge(m.CreateFrame("Button", "QuickCommsDialTintProbe", m.UIParent))
    local star = NS.Icon("star")
    local geo = { anchor = "CENTER", lx = 0, ly = 0 }
    R.PaintWedge(w, { kind = "ring", title = "Mine", icon = star, iconColor = "00ff00" }, geo)
    assertEqual(w.qcIcon.__texture, star)
    -- red under: PaintWedge setting the texture only
    assertEqual(table.concat(w.qcIcon.__color, ","), "0,1,0")
    R.PaintWedge(w, { kind = "ring", title = "Other", icon = star }, geo)
    -- red under: tint only when the item carries a color (a reused wedge keeps the old one)
    assertEqual(table.concat(w.qcIcon.__color, ","), "1,1,1")
end)

-- ── the dial rework (2026-10-21): page arrows and dots, no icon backdrop, the radius ─────────────

test("dial: [rework] a paged ring turns with its arrows and the Left and Right keys; its dots mark the page", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    m.__click(inst.header, "Toggle")
    assertEqual(NS.Dial.ShownRing("d2"), 2, "page 1 of the group's two")
    local one, two = inst.rings.active[2], inst.rings.active[3]
    assertTrue(one.qcPrev:IsShown() and one.qcNext:IsShown(), "a paged ring shows both arrows")
    assertFalse(one.qcPrev.qcLive, "the left arrow is dimmed on the first page")
    assertTrue(one.qcNext.qcLive)
    assertFalse(inst.rings.active[1].qcPrev:IsShown(), "a ring of one page has no arrows")
    assertEqual(one.qcDots[1].__color[2], 0.82, "page 1's dot is gold")
    assertEqual(one.qcDots[2].__color[2], 0.4, "page 2's is gray")
    assertTrue(one.qcDots[2]:IsShown())
    -- red under: drop DS.NewArrow's wrap (the arrow would be a plain button that turns nothing)
    m.__click(one.qcNext)
    assertEqual(NS.Dial.ShownRing("d2"), 3, "the right arrow shows page 2")
    assertTrue(NS.Dial.IsOpen("d2"), "and sends nothing, so the dial stays open")
    m.__click(two.qcNext)
    assertEqual(NS.Dial.ShownRing("d2"), 3, "at the last page the right arrow does nothing")
    m.__pressKey("LEFT")
    assertEqual(NS.Dial.ShownRing("d2"), 2, "Left turns back")
    -- red under: no LEFT/RIGHT SetBindingClick in the show snippet
    m.__pressKey("RIGHT")
    assertEqual(NS.Dial.ShownRing("d2"), 3, "Right turns on")
    m.__click(inst.header, "LeftButton")
    assertEqual(NS.Dial.ShownRing("d2"), 1, "the hub goes up a ring from any page")
    assertNil(m.restrictedBindings.LEFT, "a ring of one page leaves the arrow keys to the game")
    assertEqual(#m.sentMacros, 0)
    assertEqual(#m.blocked, 0)
end)

test("dial: [rework] wedges have no backdrop; the slices, the wedges and their hit squares follow the ring radius", function()
    local NS = live()
    local plan = planOf(NS)
    plan.radius = 140
    assertTrue(NS.Dial.Apply(1, "d2", plan))
    local w = NS.Dial.WedgesFor("d2", T.seeded(NS, "bi.mplus.pull"))[1]
    -- red under: keep R.DressWedge's qcBg circle
    assertNil(w.qcBg, "no round backdrop behind the icon")
    local g = NS.DialLayout.Geometry(140)
    local ring = NS.Dial.Instance("d2").rings.active[2]
    assertEqual(ring.qcFills[1].__size[1], g.disc, "each slice's fill is the disc across")
    local _, _, _, x, y = w:GetPoint(1)
    assertEqual(math.floor(math.sqrt(x * x + y * y) + 0.5), math.floor(NS.DialLayout.IconReach(140, 0) + 0.5),
        "the wedge sits on the automatic reach for the radius")
end)

test("dial: [slices] each place is a tinted slice; the slice the cursor points into lights, anywhere but the hub", function()
    local NS, m = live()
    local did = "d2"
    assertTrue(NS.SchemaRuntime.Set("dial.slice.highlight", { r = 0, g = 1, b = 0, a = 0.5 }, did))
    assertTrue(NS.Dial.Apply(1, did, planOf(NS)))
    local inst = NS.Dial.Instance(did)
    local h = inst.header
    local ring = inst.rings.active[2]
    -- four wedges from N (planOf's fixed four): four fills, each its own quarter
    assertEqual(ring.qcFills[1].__texture, NS.DialSlices.SectorTexture(4))
    assertTrue(ring.qcFills[4]:IsShown())
    m.__click(h, "Toggle")
    assertEqual(NS.Dial.ShownRing(did), 2)
    local cx, cy = h:GetCenter()
    local function at(dx, dy)
        m.cursor.x, m.cursor.y = (cx + dx) * h:GetEffectiveScale(), (cy + dy) * h:GetEffectiveScale()
        NS.DialRender.PointerUpdate(h.qcPointer)
        return ring.qcHighlight:IsShown()
    end
    -- red under: light a slice only from a wedge's own OnEnter (its square)
    assertTrue(at(30, 2), "just outside the hub, toward E: the E slice lights, though the cursor is not on its wedge")
    -- red under: START at W (270) in modules/Dial_Layout.lua (E is place 3)
    assertEqual(ring.qcLit, 2, "E is place 2, clockwise from N")
    assertEqual(ring.qcHighlight.__color[2], 1, "the Slices tab's highlight color")
    assertFalse(at(5, 5), "over the hub: nothing")
    assertFalse(at(400, 0), "past the rim: nothing")
    assertTrue(at(-2, -60))
    assertEqual(ring.qcLit, 3, "toward S")
    m.__click(h, "Toggle")
    assertFalse(ring.qcHighlight:IsShown(), "closing clears it")
    assertEqual(NS.DialSlices.SectorTexture(1), NS.DialSlices.DISC, "one slice is the disc")
end)

-- How many of a ring's textures in `list` are shown (none when the list was never made).
local function shownOf(list)
    local n = 0
    for _, t in ipairs(list or {}) do
        if t:IsShown() then n = n + 1 end
    end
    return n
end

test("dial slices: [polish] no border lines are drawn", function()
    local NS = live()
    local did = "d2"
    -- a profile saved before the border retired still holds its leaves: it rebuilds clean
    local slice = NS.db.profile.dials[did].slice
    slice.borderSize, slice.borderColor, slice.useClassColorBorder = 3, { r = 1, g = 0, b = 0, a = 1 }, true
    assertTrue(NS.Dial.Apply(1, did, planOf(NS)))
    local ring = NS.Dial.Instance(did).rings.active[2]
    -- red under: keep paintBorder's spokes and rim in modules/Dial_Slices.lua
    assertEqual(shownOf(ring.qcSpokes), 0, "no spokes")
    assertEqual(shownOf(ring.qcRim), 0, "no rim")
    assertNil(NS.DialRender.Look(100, {}, slice, {}).borderSize, "the look carries no border")
    assertEqual(shownOf(ring.qcFills), 4, "the four fills still draw")
end)

-- Fill (or highlight) t's offset from the ring's center and its width.
local function placeOf(t)
    local _, _, _, x, y = t:GetPoint(1)
    return x, y, t.__size[1]
end

test("dial slices: [polish] a gap shifts each fill outward along its bisector", function()
    local NS, m = live()
    local did = "d2"
    assertTrue(NS.SchemaRuntime.Set("dial.slice.gap", 10, did))
    assertTrue(NS.Dial.Apply(1, did, planOf(NS)))
    local inst = NS.Dial.Instance(did)
    local ring = inst.rings.active[2]
    local shape = ring.qcShape
    local R, d = shape.disc / 2, NS.DialLayout.SliceShift(10, 4)
    -- red under: paintFills anchors every fill at the ring's center (no SliceShift)
    for j = 1, 4 do
        local a = math.rad(shape.start) + (j - 1) * math.pi / 2
        local x, y, w = placeOf(ring.qcFills[j])
        near(x, d * math.sin(a), "fill " .. j .. " x")
        near(y, d * math.cos(a), "fill " .. j .. " y")
        near(w, 2 * (R - d), "fill " .. j .. " shrunk so its rim stays on the disc")
    end
    local h = inst.header
    m.__click(h, "Toggle")
    local cx, cy = h:GetCenter()
    m.cursor.x, m.cursor.y = (cx + 60) * h:GetEffectiveScale(), (cy + 2) * h:GetEffectiveScale()
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertEqual(ring.qcLit, 2, "toward E")
    -- red under: Track leaves the highlight at the ring's center
    local hx, hy, hw = placeOf(ring.qcHighlight)
    local fx, fy, fw = placeOf(ring.qcFills[2])
    near(hx, fx, "the highlight moves with its slice (x)")
    near(hy, fy, "the highlight moves with its slice (y)")
    near(hw, fw, "and takes its size")
    m.__click(h, "Toggle")
end)

test("dial slices: [perf] a reopen on the slice last lit leaves the highlight where it is; a rebuild moves it", function()
    local NS, m = live()
    local did = "d2"
    assertTrue(NS.Dial.Apply(1, did, planOf(NS)))
    local inst = NS.Dial.Instance(did)
    local h, ring = inst.header, inst.rings.active[2]
    local cx, cy = h:GetCenter()
    m.cursor.x, m.cursor.y = (cx + 60) * h:GetEffectiveScale(), (cy + 2) * h:GetEffectiveScale()
    m.__click(h, "Toggle")
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertEqual(ring.qcLit, 2, "toward E")
    m.__click(h, "Toggle")
    local moved, hl = 0, ring.qcHighlight
    local realSetPoint = hl.SetPoint
    hl.SetPoint = function(...) moved = moved + 1; return realSetPoint(...) end
    m.__click(h, "Toggle")
    NS.DialRender.PointerUpdate(h.qcPointer)
    -- red under: S.Track placing the highlight on every light (F-001: a fifth of dialOpenClose's bytes)
    assertEqual(moved, 0, "relit on the slice it already sits on")
    assertTrue(hl:IsShown())
    m.__click(h, "Toggle")
    hl.SetPoint = realSetPoint
    assertTrue(NS.SchemaRuntime.Set("dial.slice.gap", 10, did))
    assertTrue(NS.Dial.Apply(1, did, planOf(NS)))
    ring = inst.rings.active[2]
    m.__click(h, "Toggle")
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertEqual(ring.qcLit, 2)
    -- red under: the guard keyed on the slice alone (the highlight left at the old gap's place)
    local hx, hy = placeOf(ring.qcHighlight)
    local fx, fy = placeOf(ring.qcFills[2])
    near(hx, fx, "the new shape's place (x)")
    near(hy, fy, "the new shape's place (y)")
    m.__click(h, "Toggle")
end)

-- Every wedge the dial's pools hold but no ring drew: the free wedges of its rings, in use or parked.
local function parkedWedges(inst)
    local out = {}
    for _, list in ipairs({ inst.rings.active, inst.rings.free }) do
        for _, ring in ipairs(list) do
            for _, w in ipairs(ring.qcWedges.free) do out[#out + 1] = w end
        end
    end
    return out
end

test("dial: [F-006] an unchanged rebuild rewrites no wedge's line; a wedge left out carries no type", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    local writes, wrapped = 0, {}
    for _, w in ipairs(NS.SendEngine.ArmedButtons()) do
        local real = w.SetAttribute
        wrapped[w] = real
        w.SetAttribute = function(self, k, v)
            if k == "type" or k == "macrotext" then writes = writes + 1 end
            return real(self, k, v)
        end
    end
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    for w, real in pairs(wrapped) do w.SetAttribute = real end
    -- red under: releaseWedge disarming every wedge before the rebuild arms it again
    assertEqual(writes, 0, "the same plan again writes no line")
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, { n = 2 })))
    local parked = parkedWedges(inst)
    assertTrue(#parked > 0, "two callouts park the wedges eight used")
    for _, w in ipairs(parked) do
        -- red under: the rebuild parking wedges armed and never disarming the ones it did not take back
        assertNil(w:GetAttribute("type"), "a parked wedge sends nothing")
        assertFalse(w.qcArmed)
    end
    assertEqual(#m.blocked, 0, "every write out of combat")
    assertTrue(NS.Dial.Release(1))
    for _, w in ipairs(parkedWedges(inst)) do
        -- red under: Dial.Release parking its wedges without the disarm
        assertNil(w:GetAttribute("type"), "a released dial's wedges send nothing")
    end
end)

test("dial slices: [polish] gap 0 draws as before", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[2]
    -- red under: SliceShift without its gap <= 0 guard, or a default gap other than 0
    assertEqual(NS.db.profile.dials.d2.slice.gap, 0, "the default")
    for j = 1, 4 do
        local x, y, w = placeOf(ring.qcFills[j])
        near(x, 0, "fill " .. j .. " x")
        near(y, 0, "fill " .. j .. " y")
        assertEqual(w, ring.qcShape.disc, "the disc across")
    end
end)
