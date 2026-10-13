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

-- ── the rebuild edge, the keys and the exit paths (Task 7) ──────────────────────────────────

local RAID = { inInstance = true, instanceType = "raid", difficultyID = 15, inGroup = true, inRaid = true }
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

local function bindG(NS) assertTrue(NS.SchemaRuntime.Set("dial.key", "G", "d2")) end

local function wedgeTitled(NS, r, title)
    for _, w in ipairs(NS.Dial.RingWedges("d2", r)) do
        if w.qcItem and w.qcItem.title == title then return w end
    end
    return nil
end

local function ringTitle(NS)
    local r = NS.Dial.ShownRing("d2")
    return r and NS.Surfaces.DialPlans().d2.rings[r].title
end

test("dial: the first situation read builds the default dial, closed; setting its key binds it", function()
    local NS, m = live()
    local inst = NS.Dial.Instance("d2")
    assertTrue(inst ~= nil)
    assertEqual(inst.header:GetName(), "QuickCommsDial1")
    assertFalse(inst.header:IsShown())
    assertNil(next(m.overrideBindings))
    bindG(NS)
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1")
    assertEqual(m.overrideBindings.G.button, "Toggle")
end)

test("dial: [exit] in Arathi Basin the dial opens on the nodes; Lumber Mill, then INC 3, sends in two clicks", function()
    local NS, m = live(AB)
    bindG(NS)
    m.__pressKey("G")
    assertEqual(ringTitle(NS), "Arathi Basin", "open-into: the node set is the first active group")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Lumber Mill"))
    assertEqual(ringTitle(NS), "Lumber Mill")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "INC 3"))
    assertEqual(m.sentMacros[#m.sentMacros].text, "/i INC 3 Lumber Mill")
    assertEqual(#m.sentMacros, 1, "two clicks, one send")
    assertFalse(NS.Dial.IsOpen("d2"))
end)

test("dial: [exit] on a raid boss the dial opens and a click on a wedge sends, with nothing blocked", function()
    local NS, m = live(RAID)
    bindG(NS)
    combat(m, true)
    m.__pressKey("G")
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
    bindG(NS)
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
    assertEqual(ringTitle(NS), "Arathi Basin")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Stables"))
    m.__click(NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1])
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.Dial.Instance("d2").header.qcTest:GetText(), "PREVIEW")
end)

test("dial: [review 3] a key or wedge change in combat waits for combat end, behind the hub's stale hint", function()
    local NS, m = live()
    bindG(NS)
    combat(m, true)
    assertTrue(NS.SchemaRuntime.Set("dial.key", "H", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 8, "d2"))
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.Instance("d2").header.qcStale:IsShown())
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1", "the old key still opens the dial")
    m.__pressKey("G")
    assertTrue(NS.Dial.IsOpen("d2"), "and it works in combat")
    combat(m, false)
    assertNil(m.overrideBindings.G)
    assertEqual(m.overrideBindings.H.name, "QuickCommsDial1")
    assertFalse(NS.Dial.Instance("d2").header.qcStale:IsShown())
    assertEqual(NS.Surfaces.DialPlans().d2.rings[2].size, 8)
    assertEqual(#m.blocked, 0)
end)

test("dial: [review 1] the key opens nothing where no group is active, and is the game's again while disabled", function()
    local NS, m = live({})
    bindG(NS)
    m.__pressKey("G")
    assertFalse(NS.Dial.IsOpen("d2"), "solo in the open world: no ring to show")
    NS.SchemaRuntime.Set("enabled", false)
    -- red under: drop NS.Dial.HideAll() from the stand-down's Teardown in modules/Surfaces.lua
    assertFalse(m.__pressKey("G"))
    assertEqual(#m.blocked, 0)
    NS.SchemaRuntime.Set("enabled", true)
    -- red under: bind the keys only on a key edit (spec §9.4: re-applied on stand-up)
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1", "re-applied on stand-up")
end)

test("dial: [review 3] disabled in combat with the dial open: nothing blocked; combat end hides it and frees the key", function()
    local NS, m = live()
    bindG(NS)
    combat(m, true)
    m.__pressKey("G")
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.IsOpen("d2"), "held: no protected call in combat")
    combat(m, false)
    assertNil(NS.Dial.Instance("d2"))
    assertNil(m.overrideBindings.G)
    assertEqual(#m.blocked, 0)
end)

test("dial: [review 3] a profile switch in combat waits: the old key still opens the dial, then combat end binds the new", function()
    local NS, m = live()
    bindG(NS)
    combat(m, true)
    NS.addon.db:SetProfile("Other")
    assertTrue(NS.SchemaRuntime.Set("dial.key", "H", NS.db.profile.dialOrder[1]))
    assertEqual(#m.blocked, 0)
    local h = m.__named.QuickCommsDial1
    assertTrue(h.qcStale:IsShown(), "updates after combat")
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1", "the old profile's key until combat ends")
    combat(m, false)
    assertNil(m.overrideBindings.G)
    assertEqual(m.overrideBindings.H.name, "QuickCommsDial1")
    assertFalse(h.qcStale:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("dial: a profile switch binds the new profile's key and releases the old one", function()
    local NS, m = live()
    bindG(NS)
    NS.addon.db:SetProfile("Other")
    assertNil(m.overrideBindings.G, "Other's dial has no key")
    assertTrue(NS.SchemaRuntime.Set("dial.key", "H", NS.db.profile.dialOrder[1]))
    assertEqual(m.overrideBindings.H.name, "QuickCommsDial1")
    NS.addon.db:SetProfile("Default")
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1")
    assertNil(m.overrideBindings.H)
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
    local NS = live(AB)
    local shown = {}
    NS.PadRender.ShowLines = function(_, title, lines) shown[#shown + 1] = { title = title, lines = lines } end
    local h = NS.Dial.Instance("d2").header
    h:__fire("OnEnter")
    assertEqual(#shown, 1)
    assertEqual(shown[1].title, "Why is this showing?")
    assertEqual(shown[1].lines[1], "Arathi Basin (built-in): Content, Battleground")
    NS.SchemaRuntime.Set("behavior.whyTooltips", false)
    h:__fire("OnEnter")
    assertEqual(#shown, 1)
    assertEqual(NS.Surfaces.WhyLines("d9")[1], "This pad has not been built yet.")
    NS.Preview.SetTestMode(true)
    assertEqual(NS.Surfaces.WhyLines("d2")[1], "Test mode: placeholder wedges that send nothing.")
end)

-- ── Bindings.xml (Task 8) ───────────────────────────────────────────────────────────────────

local function readFile(rel)
    local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
    local s = fh:read("*a")
    fh:close()
    return s
end

test("dial: Bindings.xml offers Open Comms Dial 1 to 4, each clicking that dial's header with Toggle", function()
    -- A plain global write leaves the chunk's environment for the process's _G (tests/_kit/loader.lua
    -- makeEnv's __newindex), so the header is read there; cleared first so this load is the writer.
    rawset(_G, "BINDING_HEADER_QUICKCOMMS", nil)
    local NS, m = T.newAddon()
    local xml = readFile("Bindings.xml")
    local names = {}
    for name in xml:gmatch('<Binding name="([^"]+)"') do names[#names + 1] = name end
    assertEqual(#names, NS.Dial.BINDINGS)
    for i, name in ipairs(names) do
        assertEqual(name, ("CLICK QuickCommsDial%d:Toggle"):format(i))
        -- red under: drop the rawset loop from modules/Dial.lua (the menu would show the raw name)
        assertEqual(m["BINDING_NAME_" .. name], ("Open Comms Dial %d"):format(i))
    end
    assertTrue(xml:find('header="QUICKCOMMS"', 1, true) ~= nil)
    -- red under: drop the BINDING_HEADER_QUICKCOMMS line from modules/Dial.lua
    assertEqual(rawget(_G, "BINDING_HEADER_QUICKCOMMS"), "Ka0s Quick Comms")
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        -- a root file, not a TOC line, as the standard allows (layout-§1, toc-file-§4 (standard v2.80.0))
        assertTrue(rel ~= "Bindings.xml", "the client loads it by name, never through the TOC")
    end
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
    bindG(NS)
    local other = NS.Library.CreateSurface("dial", "Lead")
    assertTrue(NS.SchemaRuntime.Set("dial.key", "H", other))
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

test("dial: [phase 5] Arathi Basin's node wedges sit on their winds: Lumber Mill is SW, Blacksmith N", function()
    local NS, m = live(AB)
    bindG(NS)
    m.__pressKey("G")
    local ring = NS.Dial.ShownRing("d2")
    local function at(title)
        local _, _, _, x, y = wedgeTitled(NS, ring, title):GetPoint(1)
        return x .. "," .. y
    end
    local sw, n = NS.DialLayout.Wedge(6, 8), NS.DialLayout.Wedge(1, 8)
    assertEqual(at("Lumber Mill"), sw.x .. "," .. sw.y)
    assertEqual(at("Blacksmith"), n.x .. "," .. n.y)
end)

test("dial: [review 6] on a four- or six-slice dial every node shows, and the number keys pick the shown wedges from N", function()
    for _, slices in ipairs({ 4, 6 }) do
        local NS, m = live(AB)
        assertTrue(NS.SchemaRuntime.Set("dial.slices", slices, "d2"))
        bindG(NS)
        m.__pressKey("G")
        local r = NS.Dial.ShownRing("d2")
        assertEqual(ringTitle(NS), "Arathi Basin")
        assertEqual(#NS.Dial.RingWedges("d2", r), 5, slices .. " slices: five nodes, no More")
        -- clockwise from N: Blacksmith (N), Gold Mine (NE), Farm (SE), Lumber Mill (SW), Stables (NW)
        m.__pressKey("4")
        assertEqual(ringTitle(NS), "Lumber Mill", slices .. " slices: key 4 is the fourth wedge shown")
        m.__pressKey("3")
        assertEqual(m.sentMacros[#m.sentMacros].text, "/i INC 3 Lumber Mill")
    end
end)
