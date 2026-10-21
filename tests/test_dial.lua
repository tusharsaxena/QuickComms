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
    local group = { id = T.seeded(NS, "bi.mplus"), title = "Dungeon (generic)", slots = {} }
    for i, cid in ipairs(NS.Library.Group(T.seeded(NS, "bi.mplus")).callouts) do
        if i > (opts.n or 8) then break end
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    local rings, open = NS.DialLayout.Rings({ group }, { slices = opts.slices or 4, title = "Comms Dial" })
    return { kind = "dial", surfaceId = "d2", snapshot = snap, order = { T.seeded(NS, "bi.mplus") }, active = {}, rings = rings,
        openRing = open, lockdownChip = opts.lockdown == true, test = opts.test }
end

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

-- The dial's key, as Options -> Keybindings sets it: WoW's own binding of Open Comms Dial 1.
local function bindG(_, m) m.SetBinding("G", "CLICK QuickCommsDial1:Toggle") end



local function wedgeTitled(NS, r, title)
    for _, w in ipairs(NS.Dial.RingWedges("d2", r)) do
        if w.qcItem and w.qcItem.title == title then return w end
    end
    return nil
end

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
    assertNil(NS.Dial.BindKey, "set only in Options -> Keybindings (dial rework)")
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
    pick(NS, m, "Raid (generic)")
    assertEqual(ringTitle(NS), "Raid (generic)")
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
    assertEqual(#names, NS.Dial.BINDINGS + 1, "the four dials and Toggle Comms Pads")
    for i = 1, NS.Dial.BINDINGS do
        local name = names[i]
        assertEqual(name, ("CLICK QuickCommsDial%d:Toggle"):format(i))
        -- red under: drop the rawset loop from modules/Dial.lua (the menu would show the raw name)
        assertEqual(m["BINDING_NAME_" .. name], ("Open Comms Dial %d"):format(i))
    end
    assertEqual(names[#names], "CLICK QuickCommsTogglePads:LeftButton")
    -- red under: drop the label's rawset from settings/SlashVerbs.lua
    assertEqual(m["BINDING_NAME_" .. names[#names]], "Toggle Comms Pads")
    assertTrue(xml:find('header="QUICKCOMMS"', 1, true) ~= nil)
    -- red under: drop the BINDING_HEADER_QUICKCOMMS line from modules/Dial.lua
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

test("dial: [phase 5] Arathi Basin's node wedges sit on their winds: Lumber Mill is SW, Blacksmith N", function()
    local NS, m = live(AB)
    bindG(NS, m)
    m.__pressKey("G")
    pick(NS, m, "Arathi Basin")
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
        bindG(NS, m)
        m.__pressKey("G")
        pick(NS, m, "Arathi Basin")
        local r = NS.Dial.ShownRing("d2")
        assertEqual(ringTitle(NS), "Arathi Basin")
        assertEqual(#NS.Dial.RingWedges("d2", r), 6, slices .. " slices: five nodes and the set's own, one page")
        -- clockwise from N: Blacksmith (N), Gold Mine (NE), Arathi Basin's own (E), Farm (SE),
        -- Lumber Mill (SW), Stables (NW)
        m.__pressKey("5")
        assertEqual(ringTitle(NS), "Lumber Mill", slices .. " slices: key 5 is the fifth wedge shown")
        m.__pressKey("3")
        assertEqual(m.sentMacros[#m.sentMacros].text, "/i INC Lumber Mill")
    end
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
    local gold = NS.Constants.GOLD
    assertEqual(one.qcDots[1].__color[2], gold.g, "page 1's dot is gold")
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
    assertEqual(math.floor(math.sqrt(x * x + y * y) + 0.5), 140, "the wedge sits on the radius")
end)

test("dial: [slices] each place is a tinted slice; the slice the cursor points into lights, anywhere but the hub", function()
    local NS, m = live()
    local did = "d2"
    assertTrue(NS.SchemaRuntime.Set("dial.slice.highlight", { r = 0, g = 1, b = 0, a = 0.5 }, did))
    assertTrue(NS.Dial.Apply(1, did, planOf(NS)))
    local inst = NS.Dial.Instance(did)
    local h = inst.header
    local ring = inst.rings.active[2]
    -- four wedges from W (planOf's fixed four): four fills, each its own quarter
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
    -- red under: start fixed counts at N in modules/Dial_Layout.lua PageShape (E is place 2)
    assertEqual(ring.qcLit, 3, "E is place 3, clockwise from W")
    assertEqual(ring.qcHighlight.__color[2], 1, "the Slices tab's highlight color")
    assertFalse(at(5, 5), "over the hub: nothing")
    assertFalse(at(400, 0), "past the rim: nothing")
    assertTrue(at(-2, -60))
    assertEqual(ring.qcLit, 4, "toward S")
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

local function near(a, b, what)
    assertTrue(math.abs(a - b) < 0.01, ("%s: %s vs %s"):format(what, tostring(a), tostring(b)))
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
    assertEqual(ring.qcLit, 3, "toward E")
    -- red under: Track leaves the highlight at the ring's center
    local hx, hy, hw = placeOf(ring.qcHighlight)
    local fx, fy, fw = placeOf(ring.qcFills[3])
    near(hx, fx, "the highlight moves with its slice (x)")
    near(hy, fy, "the highlight moves with its slice (y)")
    near(hw, fw, "and takes its size")
    m.__click(h, "Toggle")
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

-- ── the page indicators' background and border (dial polish, 2026-10-21) ─────────────────────

test("dial: [paging] the indicators sit on a rounded background sized to the row; off hides it", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[2]   -- page 1 of 2: the pill (18), a dot (6), a gap (6)
    local back = ring.qcDotBack
    -- red under: no background in modules/Dial_Slices.lua paintDots
    assertTrue(back ~= nil, "the background is drawn")
    local w, y = 0, select(5, ring.qcDots[1]:GetPoint(1))
    for _, k in ipairs({ "left", "mid", "right" }) do
        local t = back[k]
        assertTrue(t:IsShown(), k .. " shown by default")
        assertEqual(t.__texture, k == "mid" and "Interface\\Buttons\\WHITE8x8" or NS.DialSlices.DISC,
            k .. " is a pill piece")
        assertEqual(t.__size[2], 6 + 2 * 1 + 2 * 4, k .. ": the dot, its border and the padding, tall")
        assertEqual(select(5, t:GetPoint(1)), y, k .. " centered on the row")
        assertEqual(table.concat(t.__color, ","), "0.06,0.06,0.08,0.8", k .. " in the plates' color")
        assertEqual(t.__sublevel, -2, k .. " under the borders")
        w = w + t.__size[1]
    end
    assertEqual(w, 30 + 2 * 1 + 2 * 4, "the row, its border and the padding, wide")
    assertEqual(back.left.__size[1], back.left.__size[2] / 2, "a round cap: half its height wide")
    assertEqual(table.concat(back.left.__texCoord, ","), "0,0.5,0,1", "the disc's left half")
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBackPadding", 10, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBackColor", { r = 0, g = 0, b = 1, a = 0.5 }, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertEqual(back.mid.__size[2], 6 + 2 + 20, "the padding grows it")
    assertEqual(table.concat(back.mid.__color, ","), "0,0,1,0.5", "in its color")
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBackShow", false, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    for _, k in ipairs({ "left", "mid", "right" }) do assertFalse(back[k]:IsShown(), k .. " hidden while off") end
    assertFalse(NS.Dial.Instance("d2").rings.active[1].qcDotBack.mid:IsShown(), "a ring of one page has none")
end)

test("dial: [paging] every dot and the pill has a border, its size plus twice the Dot border; 0 draws none", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[2]
    -- red under: no border textures in modules/Dial_Slices.lua paintDots
    local edges = ring.qcDotEdges
    assertTrue(edges ~= nil and edges[1] ~= nil, "a border per indicator")
    assertEqual(table.concat(edges[1].__size, ","), "12,8", "the pill (18 x 6) and 1 each side: its middle")
    assertEqual(edges[1].__size[1] + 2 * ring.qcDotEdgeCaps[1].left.__size[1], 20, "and its caps")
    assertEqual(table.concat(edges[2].__size, ","), "8,8", "the dot (6) and 1 each side")
    assertEqual(ring.qcDotEdgeCaps[1].left.__texture, NS.DialSlices.DISC, "the pill's own shape")
    assertEqual(edges[2].__texture, ring.qcDots[2].__texture, "the dot's own shape")
    assertEqual(table.concat(edges[2].__color, ","), "0,0,0,0.9", "near black")
    assertEqual(edges[2].__sublevel, -1, "over the background, under the dot")
    assertEqual(select(4, edges[2]:GetPoint(1)), select(4, ring.qcDots[2]:GetPoint(1)), "behind its dot")
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBorder", 3, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBorderColor", { r = 1, g = 0, b = 0, a = 1 }, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertEqual(table.concat(edges[1].__size, ","), "12,12")
    assertEqual(edges[1].__size[1] + 2 * ring.qcDotEdgeCaps[1].left.__size[1], 24)
    assertEqual(table.concat(edges[2].__color, ","), "1,0,0,1", "in its color")
    assertTrue(edges[1]:IsShown() and edges[2]:IsShown())
    assertTrue(NS.SchemaRuntime.Set("dial.page.dotBorder", 0, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertFalse(edges[1]:IsShown() or edges[2]:IsShown(), "0 draws no border")
    assertFalse(ring.qcDotEdgeCaps[1].left:IsShown() or ring.qcDotEdgeCaps[1].right:IsShown(), "nor its caps")
    assertEqual(ring.qcDotBack.mid.__size[2], 6 + 8, "nor counts one in the background")
end)

test("dial: [front] the hub, its circle and the pointer draw over the slices", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    local front = inst.header.qcPointer
    -- red under: the hub's backdrop and circle on the header, under the rings' fills
    assertTrue(inst.header.qcHub:GetParent() == front and inst.header.qcHubDot:GetParent() == front)
    for _, ring in ipairs(inst.rings.active) do
        assertTrue(front:GetFrameLevel() > ring:GetFrameLevel(), "above every ring")
        for _, w in ipairs(ring.qcWedges.active) do assertTrue(front:GetFrameLevel() > w:GetFrameLevel()) end
    end
end)

test("dial: [tooltip] a wedge's tooltip sits outside the dial: above by default, on the Labels tab's side", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local h = NS.Dial.Instance("d2").header
    local w = NS.Dial.RingWedges("d2", 2)[1]
    NS.DialRender.EnterWedge(w)   -- the tracker's hover (wedges take no mouse since dial polish)
    local tip = m.GameTooltip
    -- red under: R.ShowTooltip through PadRender.ShowLines (ANCHOR_TOP, over the dial)
    assertEqual(tip.__anchor, "ANCHOR_NONE")
    local p, rel, _, x, y = tip:GetPoint(1)
    local g = NS.DialLayout.Geometry(100)
    assertEqual(p .. "," .. tostring(rel == h) .. "," .. x, "BOTTOM,true,0")
    assertTrue(y >= g.title + 8, "above the ring title, by the offset")
    assertTrue(NS.SchemaRuntime.Set("dial.label.tooltipSide", "left", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.label.tooltipOffset", 20, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    NS.DialRender.EnterWedge(w)
    p, _, _, x = tip:GetPoint(1)
    assertEqual(p, "RIGHT")
    assertTrue(x <= -(g.disc / 2 + 20), "left of the disc and its labels, by the offset")
end)

test("dial: [pointer] the pointer is a catalog glyph, sized, colored and placed by the Slices tab, and can be off", function()
    local NS = live()
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerSize", 30, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerColor", { r = 0, g = 0, b = 1, a = 1 }, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local h = NS.Dial.Instance("d2").header
    local arrow = h.qcPointer.qcArrow
    assertEqual(arrow.__size[1], 30)
    assertEqual(arrow.__color[3], 1)
    assertEqual(h.qcReach, NS.DialLayout.PointerReach(30), "automatic: pushed out to clear the hub")
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerOffset", 70, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    -- red under: ignore pointerOffset in R.PaintPointer
    assertEqual(h.qcReach, 70, "the Pointer offset, from the center")
    assertTrue(NS.SchemaRuntime.Set("dial.slice.pointerShow", false, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    h:Show()
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertFalse(h.qcPointer.qcArrow:IsShown(), "off: never drawn (the update still lights slices)")
end)

test("dial: [labels] the Label offset moves every label out from the center; the title and the page row follow", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local w = NS.Dial.RingWedges("d2", 2)[3]   -- E (places from W: W, N, E, S)
    local _, _, _, x0 = w.qcLabel:GetPoint(1)
    local _, _, _, wx = w:GetPoint(1)
    local g = NS.DialLayout.Geometry(100)
    assertEqual(wx + x0, g.reach, "automatic: just past the disc")
    assertTrue(NS.SchemaRuntime.Set("dial.label.offset", 220, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local _, _, _, x1 = w.qcLabel:GetPoint(1)
    -- red under: drop `reach` from DL.Wedge
    assertEqual(wx + x1, 220, "220 pixels from the center")
    local ring = NS.Dial.Instance("d2").rings.active[2]
    local _, _, _, _, ty = ring.qcTitle:GetPoint(1)
    assertTrue(ty >= 220 + 14, "the title clears the N label")
end)

-- ── select to the hub (dial polish T3): the catcher clicks, the tracker hovers ───────────────

-- The default dial on a fixed four with planOf's first `n` callouts, open from its header (as its
-- key opens it) on that callout ring; answers the ring and a function that puts the cursor (dx, dy)
-- from the hub's center.
local function openPolish(NS, m, n)
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, { n = n })))
    local inst = NS.Dial.Instance("d2")
    local h = inst.header
    m.__click(h, "Toggle")
    local ring = inst.rings.active[NS.Dial.ShownRing("d2")]
    local cx, cy = h:GetCenter()
    local function cursor(dx, dy)
        m.cursor.x, m.cursor.y = (cx + dx) * h:GetEffectiveScale(), (cy + dy) * h:GetEffectiveScale()
    end
    return ring, cursor, h
end

test("dial: [polish] a click near the hub sends the lit slice, in combat", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    local east = ring.qcPlaceWedge[3]
    assertTrue(east ~= nil and east.qcItem == ring.qcSpec.items[2], "two items on four places: the second is E")
    m.inCombat = true
    cursor(25, 0)   -- 25 px east: inside the old dead band between the hub and the wedge's square
    -- red under: no catcher (a click lands only on a wedge's own square)
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, east:GetAttribute("macrotext"))
    assertTrue(m.sentMacros[1].frame == east, "forwarded to the E wedge's own button")
    assertFalse(NS.Dial.IsOpen("d2"), "the dial closes on the send")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a click with a modifier held still sends the slice, in combat", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    local east = ring.qcPlaceWedge[3]
    m.inCombat = true
    for _, mod in ipairs({ "shift", "ctrl", "alt" }) do
        m.modifiers = { [mod] = true }
        if not NS.Dial.IsOpen("d2") then m.__click(NS.Dial.Instance("d2").header, "Toggle") end
        cursor(40, 0)
        local before = #m.sentMacros
        -- red under: the catcher's plain type-w<j> / clickbutton-w<j> (never read with a modifier held)
        m.__click(ring.qcCatcher)
        assertEqual(#m.sentMacros, before + 1, mod .. " held: the slice sends")
        assertTrue(m.sentMacros[#m.sentMacros].frame == east, mod .. ": forwarded to the E wedge")
    end
    m.modifiers = {}
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] just outside the hub's circle, on a diagonal, the slice lights and clicks, in combat", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    local east = ring.qcPlaceWedge[3]
    local dx, dy = 18, 10   -- 20.6 px out (hub 40: outside its circle), bearing ~61 degrees (E)
    local dist, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dx, dy)
    -- red under: the hub as a square in DL.SliceAt (|dx|, |dy| <= hub / 2)
    assertEqual(NS.DialLayout.SliceAt(angle, dist, 4, 270, 40, 300), 3, "the round hub ends at 20: E")
    assertFalse(NS.DialLayout.InHub(dist, 40), "off the hub")
    NS.DialSlices.Track(ring, angle, dist)
    assertEqual(ring.qcLit, 3, "the tracker lights E there")
    m.inCombat = true
    cursor(dx, dy)
    -- red under: the hub as a square in CATCHER_PRE
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 1, "the catcher forwards it")
    assertTrue(m.sentMacros[1].frame == east, "to the E wedge, the slice that lit")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a click inside the hub's circle runs the hub, any modifier held, in combat", function()
    local NS, m = live()
    local ring, cursor, h = openPolish(NS, m, 2)
    local inst = NS.Dial.Instance("d2")
    -- red under: the header taking the mouse (its square would hold the corners past the circle)
    assertFalse(h:IsMouseEnabled(), "the header takes no mouse: the catcher is the hub's mouse")
    local dx, dy = 12, 9   -- 15 px out: inside the circle
    assertNil(NS.DialLayout.SliceAt(math.atan2(dx, dy), 15, 4, 270, 40, 300), "no slice there")
    assertTrue(NS.DialLayout.InHub(15, 40))
    m.inCombat = true
    for _, mod in ipairs({ "none", "shift", "ctrl", "alt" }) do
        m.modifiers = mod == "none" and {} or { [mod] = true }
        if not NS.Dial.IsOpen("d2") then m.__click(h, "Toggle") end
        assertEqual(NS.Dial.ShownRing("d2"), 2, mod .. ": open on the callout ring, a child of the groups")
        cursor(dx, dy)
        -- red under: CATCHER_PRE answering nothing inside the hub (no qc-up)
        m.__click(ring.qcCatcher)
        assertEqual(NS.Dial.ShownRing("d2"), 1, mod .. ": the hub goes up a ring")
        local top = inst.rings.active[1]
        m.__click(top.qcCatcher)
        assertFalse(NS.Dial.IsOpen("d2"), mod .. ": on the first ring the hub closes")
    end
    m.modifiers = {}
    assertEqual(#m.sentMacros, 0, "the hub sends nothing")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] the hub's hover shows from the tracker inside its circle and clears outside", function()
    local NS, m = live(AB)
    local _, cursor, h = openPolish(NS, m, 2)
    local tip = m.GameTooltip
    local rest = h.qcHubDot.__color[4]
    cursor(12, 9)   -- 15 px out: on the hub
    NS.DialRender.PointerUpdate(h.qcPointer)
    -- red under: the hub's hover only from the header's OnEnter (it takes no mouse)
    assertTrue(h.qcHubDot.__color[4] > rest, "the circle brightens")
    assertTrue(tip.__owner == h and tip:IsShown(), "the hub owns the tooltip")
    assertEqual(tip.__lines[1][1], "Why is this showing?")
    cursor(18, 10)   -- 20.6 px out: on E
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertEqual(h.qcHubDot.__color[4], rest, "off the hub: dims back")
    assertFalse(tip.__owner == h, "the hub's tooltip gone")
    cursor(0, 0)
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertTrue(tip.__owner == h and tip:IsShown(), "back on the hub")
    m.__click(h, "Toggle")
    assertEqual(h.qcHubDot.__color[4], rest, "closing clears the hub's hover")
    assertFalse(tip:IsShown())
end)

test("dial: [polish] the dial's key still opens and closes it with the header's mouse off, in combat", function()
    local NS, m = live()
    m.SetBinding("G", "CLICK QuickCommsDial1:Toggle")
    local h = NS.Dial.Instance("d2").header
    -- red under: the header taking the mouse
    assertFalse(h:IsMouseEnabled())
    m.inCombat = true
    assertTrue(m.__pressKey("G"))
    assertTrue(NS.Dial.IsOpen("d2"), "the key opens it")
    m.__pressKey("ESCAPE")
    assertFalse(NS.Dial.IsOpen("d2"), "Escape closes it")
    m.__pressKey("G")
    m.__pressKey("G")
    assertFalse(NS.Dial.IsOpen("d2"), "the key closes it")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a click on an empty place does nothing; in the hub it sends nothing", function()
    local NS, m = live()
    local ring, cursor = openPolish(NS, m, 2)
    m.inCombat = true
    cursor(0, 40)   -- N: place 2, empty with two items (W, E)
    -- red under: write type-w<j> for every place in DS.Load, used or not
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 0)
    assertTrue(NS.Dial.IsOpen("d2"), "an empty place does nothing")
    cursor(5, 5)
    m.__click(ring.qcCatcher)
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.Dial.ShownRing("d2"), 1, "the hub goes up a ring, through the catcher")
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] hovering anywhere in a slice shows its tooltip", function()
    local NS, m = live()
    local ring, cursor, h = openPolish(NS, m, 2)
    local east = ring.qcPlaceWedge[3]
    local tip = m.GameTooltip
    cursor(25, 0)
    NS.DialRender.PointerUpdate(h.qcPointer)
    -- red under: show a wedge's tooltip only from its own OnEnter
    assertTrue(tip.__owner == east, "the lit slice's wedge owns the tooltip")
    assertTrue(tip:IsShown())
    assertEqual(tip.__lines[1][1], NS.DialRender.WedgeLines(east.qcItem)[1])
    cursor(-25, 0)
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertTrue(tip.__owner == ring.qcPlaceWedge[1], "W next")
    cursor(3, 3)
    NS.DialRender.PointerUpdate(h.qcPointer)
    assertFalse(tip.__owner == ring.qcPlaceWedge[1], "into the hub: the wedge's tooltip is gone")
    assertNil(ring.qcLit, "and no slice is lit")
end)

test("dial: [polish] wedges take no mouse; keys still click by name", function()
    local NS, m = live()
    local ring = openPolish(NS, m, 8)
    for _, r in ipairs(NS.Dial.Instance("d2").rings.active) do
        for _, w in ipairs(r.qcWedges.active) do
            -- red under: keep the wedges mouse-enabled (their grown hit squares)
            assertFalse(w:IsMouseEnabled(), "a wedge takes no mouse")
        end
    end
    local first = ring.qcWedges.active[1]
    m.__pressKey("1")
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, first:GetAttribute("macrotext"), "the number key clicks item 1 by name")
end)

test("dial: [polish] a built dial closes on a click outside it, in combat", function()
    local NS, m = live()
    openPolish(NS, m, 2)
    local screen = NS.Dial.Instance("d2").screen
    -- red under: no screen catcher made in build / no `screen` ref handed to DS.Load
    assertTrue(screen ~= nil and screen:IsShown(), "open from its key, the screen catcher is up")
    m.inCombat = true
    m.__click(screen, "RightButton")
    assertFalse(NS.Dial.IsOpen("d2"))
    assertEqual(#m.sentMacros, 0)
    assertEqual(#m.blocked, 0)
end)

test("dial: [polish] a ring hidden under the hover clears its slice, tooltip and hover glow", function()
    local NS, m = live()
    local ring, cursor, h = openPolish(NS, m, 8)
    local inst = NS.Dial.Instance("d2")
    local tip = m.GameTooltip
    cursor(25, 0)
    NS.DialRender.PointerUpdate(h.qcPointer)
    local lit = ring.qcLit
    local wedge = ring.qcPlaceWedge[lit]
    assertTrue(wedge ~= nil and tip.__owner == wedge and tip:IsShown(), "a slice of page 1 hovered")
    assertTrue(wedge.qcHovered, "its hover glow on")
    m.__click(ring.qcNext)   -- the arrow snippet hides page 1 and shows page 2
    assertEqual(NS.Dial.ShownRing("d2"), 3, "page 2 on screen")
    -- red under: no OnHide hook on a ring (only the header's OnHide clears the hover)
    assertFalse(tip:IsShown(), "page 1's tooltip hidden with its ring")
    assertNil(ring.qcLit, "page 1 has no slice lit")
    assertNil(wedge.qcHovered, "its wedge's hover glow off")
    m.__click(inst.header, "LeftButton")   -- the hub goes up a ring
    assertNil(ring.qcLit)
end)

-- ── hub styles (dial polish T5): a backdrop disc and a circle mark ─────────────────────────────

-- The default dial applied with `hub` written to its dial.hub rows; answers its header.
local function hubWith(NS, hub)
    for k, v in pairs(hub or {}) do assertTrue(NS.SchemaRuntime.Set("dial.hub." .. k, v, "d2"), k) end
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    return NS.Dial.Instance("d2").header
end

-- The distance from the header's center of a region's one anchor.
local function reachOf(t)
    local _, _, _, x, y = t:GetPoint(1)
    return math.sqrt((x or 0) ^ 2 + (y or 0) ^ 2)
end

test("dial: [polish] default hub is a solid gold circle of 22 on a 40 backdrop, no red X", function()
    local NS = live()
    local h = hubWith(NS)
    -- red under: keep R.DressHub's qcClose (the red stop mark)
    assertNil(h.qcClose, "the red X is gone")
    assertEqual(h.__w, 40, "the header is the hub's size")
    assertTrue(h.qcHub:IsShown())
    assertEqual(h.qcHub.__size[1], 40, "the backdrop, 40 across")
    assertEqual(h.qcHub.__color[1], 0.12)
    -- red under: no qcHubDot / no R.PaintHubLook in Dial.Apply
    assertTrue(h.qcHubDot:IsShown(), "solid: the circle")
    assertEqual(h.qcHubDot.__size[1], 22)
    assertEqual(h.qcHubDot.__color[1] .. "," .. h.qcHubDot.__color[2], "1,0.82", "gold")
    assertFalse(h.qcHubRing:IsShown(), "no hollow ring")
    assertFalse(h.qcHubRim:IsShown(), "no backdrop rim at border size 0")
    local rest = h.qcHubDot.__color[4]
    NS.DialRender.HoverHub(h, true)
    -- red under: no brightening in R.HoverHub
    assertTrue(h.qcHubDot.__color[4] > rest, "hovered, the circle brightens")
    NS.DialRender.HoverHub(h, false)
    assertEqual(h.qcHubDot.__color[4], rest, "and dims back")
end)

test("dial: [polish] hub style solid draws the backdrop rim when its border size is set", function()
    local NS = live()
    local h = hubWith(NS, { style = "solid", borderSize = 3, borderColor = { r = 0, g = 0, b = 1, a = 1 } })
    assertTrue(h.qcHubDot:IsShown())
    -- red under: draw the backdrop rim only for the rimmed style
    assertTrue(h.qcHubRim:IsShown(), "any style draws the backdrop's border")
    local rim = h.qcHubRim
    assertEqual(rim.__texture, NS.DialRender.RingTexture(40, 3), "border size thick")
    assertEqual(rim.__color[3], 1, "in the border color")
    assertEqual(rim.__size[1], 40, "the backdrop across")
    assertTrue(reachOf(rim) < 0.01, "centered on the hub")
end)

test("dial: [polish] hub style ring is a hollow ring of the circle size and line width", function()
    local NS = live()
    local h = hubWith(NS, { style = "ring", circleSize = 30, lineWidth = 4 })
    -- red under: PaintHubLook ignoring the style (solid always)
    assertFalse(h.qcHubDot:IsShown(), "no filled circle")
    assertTrue(h.qcHubRing:IsShown())
    assertEqual(h.qcHubRing.__texture, NS.DialRender.RingTexture(30, 4), "line width thick")
    assertEqual(h.qcHubRing.__size[1], 30, "the circle size across")
    assertEqual(h.qcHubRing.__color[2], 0.82, "in the circle color")
    assertFalse(h.qcHubRim:IsShown())
end)

test("dial: [polish] hub style target is a ring with a center dot", function()
    local NS = live()
    local h = hubWith(NS, { style = "target", circleSize = 32 })
    -- red under: target drawn as the ring alone
    assertTrue(h.qcHubRing:IsShown())
    assertTrue(h.qcHubDot:IsShown())
    assertEqual(h.qcHubDot.__size[1], 8, "a quarter of the circle size")
    h = hubWith(NS, { circleSize = 8 })
    assertEqual(h.qcHubDot.__size[1], 4, "never under 4")
end)

test("dial: [polish] hub style rimmed is a filled circle on a backdrop with its own rim", function()
    local NS = live()
    local h = hubWith(NS, { style = "rimmed" })
    assertTrue(h.qcHubDot:IsShown())
    assertEqual(h.qcHubDot.__size[1], 22)
    -- red under: the rimmed style drawn without its rim at border size 0
    assertTrue(h.qcHubRim:IsShown(), "rimmed at border size 0: a 2 px rim")
    assertEqual(h.qcHubRim.__texture, NS.DialRender.RingTexture(40, 2))
    assertFalse(h.qcHubRing:IsShown())
    h = hubWith(NS, { borderSize = 5 })
    assertEqual(h.qcHubRim.__texture, NS.DialRender.RingTexture(40, 5), "the border size when larger")
end)

test("dial: [polish] hub size moves the inner edge everywhere", function()
    local NS = live()
    local h = hubWith(NS, { size = 60 })
    -- red under: header:SetSize(DL.HUB, DL.HUB) in Dial.build
    assertEqual(h.__w .. "x" .. h.__h, "60x60", "the header is the hub")
    assertEqual(h.qcHub.__size[1], 60, "the backdrop")
    local ring = NS.Dial.Instance("d2").rings.active[2]
    -- red under: shape.hub = DL.HUB in Dial.Apply
    assertEqual(ring.qcCatcher:GetAttribute("qc-hub"), 60, "the catcher's inner edge")
    -- red under: DL.HUB in Slices.Track
    NS.DialSlices.Track(ring, -math.pi / 2, 29)
    assertNil(ring.qcLit, "inside the hub: nothing")
    NS.DialSlices.Track(ring, -math.pi / 2, 31)
    assertEqual(ring.qcLit, 1, "just past it: W")
    -- red under: DL.PointerReach reading DL.HUB
    assertTrue(h.qcReach > 30, "the pointer sits outside the hub")
end)

-- ── group labels (dial polish T6): the ring title in its own font ────────────────────────────

test("dial: [polish] group labels take their font and hide when off", function()
    local NS = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[1]
    local title = ring.qcTitle
    -- red under: R.PaintRing without the title font (the GameFontNormal template alone)
    assertEqual(title.__font and title.__font[2], 12, "today's look: 12 points")
    assertEqual(title.__color[1] .. "," .. title.__color[2] .. "," .. title.__color[3], "1,0.82,0", "gold")
    assertTrue(title:IsShown())
    local g = NS.DialLayout.Geometry(100)
    local header = NS.Dial.Instance("d2").header
    assertEqual(header.qcTipAt[3], g.title + NS.DialLayout.LINE + 8, "the tooltip clears a 14-pixel title")
    assertTrue(NS.SchemaRuntime.Set("dial.title.fontSize", 20, "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.title.fontColor", { r = 0, g = 1, b = 0, a = 1 }, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertEqual(title.__font[2], 20)
    assertEqual(title.__color[2], 1, "its own color")
    -- red under: DL.Geometry without the title's own line height (titleLine)
    assertEqual(NS.DialLayout.Geometry(100, nil, nil, 22).top, g.title + 22)
    assertEqual(header.qcTipAt[3], g.title + 22 + 8, "the tooltip clears the bigger title")
    assertEqual(NS.Dial.RingWedges("d2", 1)[1].qcLabel.__font[2], 12, "the slice labels keep theirs")
    assertTrue(NS.SchemaRuntime.Set("dial.title.show", false, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    -- red under: R.PaintRing leaving the title shown while Show group labels is off
    assertFalse(title:IsShown(), "off: no title")
    assertEqual(header.qcTipAt[3], g.title + 8, "and the tooltip takes its place")
end)

-- ── crisp dial art (shine T1, 2026-10-21): the disc, the ring ladder, the three-piece pill ──────

local PORTRAIT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- The ring step k whose line-to-diameter ratio is nearest `frac` in log space.
local function nearestStep(steps, frac)
    local best, bestD
    for k, s in ipairs(steps) do
        local d = math.abs(math.log(frac) - math.log(s))
        if not bestD or d < bestD then best, bestD = k, d end
    end
    return best
end

test("dial: [art] RingTexture picks the nearest step", function()
    local NS = live()
    local R, S = NS.DialRender, NS.DialSlices
    -- red under: no R.RING_STEPS / R.RingTexture in modules/Dial_Render.lua
    assertEqual(#R.RING_STEPS, 12, "twelve steps")
    near(R.RING_STEPS[1], 0.0125, "step 1")
    near(R.RING_STEPS[12], 0.5, "step 12")
    local k = nearestStep(R.RING_STEPS, 2 / 22)
    assertTrue(R.RingTexture(22, 2):sub(-#("dial-ring-" .. k)) == "dial-ring-" .. k, R.RingTexture(22, 2))
    assertTrue(R.RingTexture(80, 1):sub(-#"dial-ring-1") == "dial-ring-1", "a thin line on a big ring: step 1")
    assertTrue(S.DISC ~= nil and S.DISC:find("dial%-disc$") ~= nil, "the disc's path")
    assertEqual(R.RingTexture(4, 6), S.DISC, "a line half the diameter or more: the solid disc")
    assertEqual(R.RingTexture(40, 20), S.DISC, "exactly half: the disc")
end)

test("dial: [art] the hub draws textures, not segments", function()
    local NS = live()
    local R, S = NS.DialRender, NS.DialSlices
    local function isRing(t) return type(t.__texture) == "string" and t.__texture:find("dial%-ring%-%d+$") ~= nil end
    for _, style in ipairs({ "solid", "ring", "target", "rimmed" }) do
        local h = hubWith(NS, { style = style, borderSize = 0 })
        -- red under: qcHubRing / qcHubRim kept as lists of DL.ARC segments
        assertTrue(h.qcHubRing.SetTexture ~= nil and h.qcHubRim.SetTexture ~= nil, style .. ": single textures")
        local ringed = style == "ring" or style == "target"
        assertEqual(h.qcHubRing:IsShown(), ringed, style .. ": the hollow ring")
        if ringed then
            assertTrue(isRing(h.qcHubRing), style .. ": a ring texture")
            assertEqual(h.qcHubRing.__texture, R.RingTexture(22, NS.PadDefaults.DialHub().lineWidth),
                style .. ": circle size and line width")
            assertEqual(h.qcHubRing.__size[1], 22, style .. ": the circle size across")
        end
        assertEqual(h.qcHubRim:IsShown(), style == "rimmed", style .. ": the rim at border size 0")
        if style == "rimmed" then
            assertEqual(h.qcHubRim.__texture, R.RingTexture(40, 2), "a 2 px rim on the 40 backdrop")
            assertEqual(h.qcHubRim.__size[1], 40)
        end
        assertEqual(h.qcHub.__texture, S.DISC, style .. ": the backdrop is the disc")
        assertEqual(h.qcHubDot.__texture, S.DISC, style .. ": the circle is the disc")
        for _, t in ipairs({ h.qcHub, h.qcHubDot, h.qcHubRing, h.qcHubRim }) do
            assertTrue(t.__texture ~= PORTRAIT, style .. ": no portrait mask on the hub")
        end
    end
    local h = hubWith(NS, { style = "solid", borderSize = 3, borderColor = { r = 0, g = 0, b = 1, a = 1 } })
    assertTrue(h.qcHubRim:IsShown(), "any style draws the backdrop's border")
    assertEqual(h.qcHubRim.__texture, R.RingTexture(40, 3))
    assertEqual(h.qcHubRim.__color[3], 1, "in the border color")
    local ring = NS.Dial.Instance("d2").rings.active[2]
    local w = NS.Dial.RingWedges("d2", 2)[1]
    for _, t in ipairs({ w.qcDim, w.qcCool, w.qcFlash }) do
        assertEqual(t.__texture, S.DISC, "the wedge's discs")
    end
    assertTrue(ring ~= nil)
end)

test("dial: [art] the pill is three pieces with round ends", function()
    local NS = live()
    local S = NS.DialSlices
    local WHITE = "Interface\\Buttons\\WHITE8x8"
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local ring = NS.Dial.Instance("d2").rings.active[2]   -- page 1 of 2: the pill (18 x 6)
    -- red under: S.PILL, one stretched texture per indicator
    assertNil(S.PILL, "dial-pill.tga is retired")
    local function threePiece(left, mid, right, w, h, what)
        assertEqual(left.__texture, S.DISC, what .. ": the left cap is the disc")
        assertEqual(table.concat(left.__texCoord, ","), "0,0.5,0,1", what .. ": its left half")
        assertEqual(right.__texture, S.DISC, what .. ": the right cap is the disc")
        assertEqual(table.concat(right.__texCoord, ","), "0.5,1,0,1", what .. ": its right half")
        assertEqual(mid.__texture, WHITE, what .. ": a flat middle")
        assertEqual(table.concat(left.__size, ","), (h / 2) .. "," .. h, what .. ": a round cap")
        assertEqual(table.concat(right.__size, ","), (h / 2) .. "," .. h, what .. ": a round cap")
        assertEqual(table.concat(mid.__size, ","), (w - h) .. "," .. h, what .. ": the middle")
        local _, _, _, mx = mid:GetPoint(1)
        near(select(4, left:GetPoint(1)), mx - (w - h) / 2 - h / 4, what .. ": the left cap abuts the middle")
        near(select(4, right:GetPoint(1)), mx + (w - h) / 2 + h / 4, what .. ": the right cap abuts it")
    end
    local caps, ecaps = ring.qcDotCaps[1], ring.qcDotEdgeCaps[1]
    threePiece(caps.left, ring.qcDots[1], caps.right, 18, 6, "the pill")
    threePiece(ecaps.left, ring.qcDotEdges[1], ecaps.right, 20, 8, "the pill's border")
    local back = ring.qcDotBack
    threePiece(back.left, back.mid, back.right, 30 + 2 + 8, 6 + 2 + 8, "the background")
    assertEqual(ring.qcDots[2].__texture, S.DISC, "a dot is the disc")
    assertFalse(ring.qcDotCaps[2].left:IsShown() or ring.qcDotCaps[2].right:IsShown(), "a dot has no caps")
    assertTrue(caps.left:IsShown() and caps.right:IsShown(), "the pill shows its caps")
end)
