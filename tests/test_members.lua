-- tests/test_members.lua — the member rows (architecture-§5, settings/SchemaMembers.lua). Every field a
-- player sets on a callout, a group, a Comms Pad or a built-in set goes through the one seam, addressed
-- by an instance argument, by the member its editor page has selected (NS.State.editing), or by the
-- first member that page lists. Library keeps membership and announces every field write; the pads
-- pick a write up through Surfaces.Request, queued in combat.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function heard(NS)
    local out = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function(_, kind, id) out[#out + 1] = tostring(kind) .. ":" .. tostring(id) end)
    return out
end

local function boot()
    local NS = T.bootAddon()
    return NS, NS.SchemaRuntime, NS.Library
end

test("members: a callout field is written through the seam by instance id, and announced once", function()
    local NS, S, Lib = boot()
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    local out = heard(NS)
    assertTrue(S.Set("callout.text", "Lust now {rt8}", cid))
    assertEqual(NS.db.profile.callouts[cid].text, "Lust now {rt8}")
    assertEqual(S.Get("callout.text", cid), "Lust now {rt8}")
    -- red under: drop the onChange loop at the end of settings/SchemaMembers.lua
    assertEqual(table.concat(out, ","), "callout:" .. cid)
end)

test("members: with no id the seam writes the selected member, else the first the page lists, else refuses", function()
    local NS, S, Lib = boot()
    local ok, err = S.Set("callout.name", "Other")
    assertFalse(ok)
    assertTrue(tostring(err):find("No callout to edit", 1, true) ~= nil, tostring(err))
    local b = Lib.CreateCallout({ name = "Beta", text = "b", channel = "party" })
    local a = Lib.CreateCallout({ name = "Alpha", text = "a", channel = "party" })
    -- red under: drop the Library.MemberIds fallback from Settings.EditingId (nothing selected is a refusal)
    assertTrue(S.Set("callout.text", "first"))
    assertEqual(NS.db.profile.callouts[a].text, "first", "the first callout the page lists, by name")
    NS.State.editing.callout = b
    assertTrue(S.Set("callout.name", "Hero"))
    assertEqual(NS.db.profile.callouts[b].name, "Hero")
    assertEqual(S.Get("callout.name"), "Hero")
    NS.State.editing.callout = "c999"   -- a stale selection falls back too; nothing lands on it
    assertTrue(S.Set("callout.text", "again"))
    assertEqual(NS.db.profile.callouts[a].text, "again")
    assertNil(NS.db.profile.callouts.c999)
    assertNil(NS.addon.Settings.EditingId("builtin"), "a built-in overlay is never a fallback")
end)

test("members: [review 5] a bad name or channel is refused with its reason and stores nothing", function()
    local NS, S, Lib = boot()
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    local ok, _, why = S.Set("callout.name", "", cid)
    assertFalse(ok)
    assertEqual(why, "A name is 1 to 32 characters.")
    assertFalse((S.Set("callout.name", string.rep("x", 33), cid)))
    ok, _, why = S.Set("callout.channel", "guild", cid)
    assertFalse(ok)
    assertEqual(why, "That is not a channel Quick Comms sends on.")
    local c = NS.db.profile.callouts[cid]
    assertEqual(c.name, "Lust")
    assertEqual(c.channel, "party")
end)

test("members: an icon typed as digits is stored as a texture id; empty text clears it", function()
    local NS, S, Lib = boot()
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    assertTrue(S.Set("callout.icon", "136012", cid))
    assertEqual(NS.db.profile.callouts[cid].icon, 136012)
    assertTrue(S.Set("callout.icon", "Interface\\Icons\\Spell_Nature_Bloodlust", cid))
    assertEqual(NS.db.profile.callouts[cid].icon, "Interface\\Icons\\Spell_Nature_Bloodlust")
    assertTrue(S.Set("callout.icon", "", cid))
    assertTrue(NS.db.profile.callouts[cid].icon == false)
end)

test("members: [review 4] a built-in group's fields read, and every write to them is refused", function()
    local NS, S = boot()
    NS.State.editing.group = "bi.mplus"
    assertEqual(S.Get("group.name"), NS.BuiltIns.groups["bi.mplus"].name)
    local ok, _, why = S.Set("group.name", "Mine")
    assertFalse(ok)
    -- red under: drop the built-in refusal from the group rows' validate
    assertEqual(why, "Built-in groups are read-only. Customize makes an editable copy.")
    assertFalse((S.Set("group.enabled", false, "bi.mplus")))
    assertFalse((S.Set("group.when", { content = { raid = true } }, "bi.mplus")))
    assertEqual(NS.BuiltIns.groups["bi.mplus"].name, "M+ (generic)")
    assertTrue(NS.BuiltIns.groups["bi.mplus"].when.content.mythicPlus)
    local o = NS.db.profile.builtins["bi.mplus"]
    assertTrue(o == nil or o.enabled ~= false, "the overlay is untouched")
end)

test("members: a group's When is one structured row: a valid When stores, a bad one is refused", function()
    local NS, S, Lib = boot()
    local gid = Lib.CreateGroup({ name = "Mine" })
    assertTrue(S.Set("group.when", { content = { mythicPlus = true }, keyLevel = { min = 10 } }, gid))
    assertTrue(NS.db.profile.groups[gid].when.content.mythicPlus)
    local ok, _, why = S.Set("group.when", { keyLevel = { min = 12, max = 10 } }, gid)
    assertFalse(ok)
    assertEqual(why, "The lowest key level is above the highest.")
    assertFalse((S.Set("group.when", { combat = { yes = true } }, gid)))
    assertEqual(NS.db.profile.groups[gid].when.keyLevel.min, 10)
end)

test("members: member rows are not AceDB defaults, and each resolves against its template", function()
    local NS = T.bootAddon()
    local d = NS.addon.Settings.BuildDefaults()
    -- red under: drop `not def.instance` from Settings.BuildDefaults
    assertNil(d.profile.callout)
    assertNil(d.profile.pad)
    assertNil(d.profile.group)
    assertNil(d.profile.builtin)
    -- red under: drop the instance branch from the validation's defaultsRoot
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0)
end)

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

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

test("members: [review 4] the CLI prints the built-in refusal", function()
    local NS, m = T.enableAddon()
    NS.State.editing.group = "bi.mplus"
    m.prints = {}
    NS.addon:OnSlashCommand("set group.name Mine")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Built-in groups are read-only", 1, true) ~= nil, text)
end)

test("members: Library's built-in writers and the pad point go through the seam, one announce each", function()
    local NS, S, Lib = boot()
    local out = heard(NS)
    assertTrue(Lib.SetBuiltinEnabled("bi.raid", false))
    assertFalse(NS.db.profile.builtins["bi.raid"].enabled)
    assertTrue(Lib.SetBuiltinCalloutHidden("bi.bg.ab.stables", "bi.bg.ab.stables.inc1", true))
    assertTrue(NS.db.profile.builtins["bi.bg.ab"].hidden["bi.bg.ab.stables.inc1"])
    assertTrue(Lib.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 4, -4 }))
    assertEqual(table.concat(out, ","), "builtin:bi.raid,builtin:bi.bg.ab,pad:p1")
    -- a set's hidden list holds only its own callouts
    assertFalse((S.Set("builtin.hidden", { ["bi.mplus.lust"] = true }, "bi.raid")))
    -- Each writer reaches the seam, by path and instance argument.
    local paths = {}
    local set = S.Set
    S.Set = function(path, value, id)
        paths[#paths + 1] = path .. "@" .. tostring(id)
        return set(path, value, id)
    end
    Lib.SetBuiltinEnabled("bi.raid", true)
    Lib.SetBuiltinCalloutHidden("bi.bg.ab", "bi.bg.ab.stables.inc1", false)
    Lib.SetSurfacePoint("pad", "p1", nil)
    Lib.Customize("bi.arena")
    S.Set = set
    -- red under: assign the field directly in any of the four writers in modules/Library.lua
    assertEqual(table.concat(paths, ","),
        "builtin.enabled@bi.raid,builtin.hidden@bi.bg.ab,pad.point@p1,builtin.enabled@bi.arena")
end)

test("members: the structured rows are typed and printed on the CLI through the descriptor's parse and format", function()
    local NS, m = T.enableAddon()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    NS.addon:OnSlashCommand("set group.when content mythicPlus,raid")
    -- red under: drop `parse` from the descriptor in settings/Slash.lua (the library refuses the type)
    assertTrue(NS.db.profile.groups[gid].when.content.mythicPlus)
    assertTrue(NS.db.profile.groups[gid].when.content.raid)
    NS.addon:OnSlashCommand("set group.when keyLevel 10-")
    assertEqual(NS.db.profile.groups[gid].when.keyLevel.min, 10)
    assertNil(NS.db.profile.groups[gid].when.keyLevel.max)
    m.prints = {}
    NS.addon:OnSlashCommand("get group.when")
    local text = table.concat(m.prints, "\n")
    -- red under: drop `format` from the descriptor (a table address prints)
    assertTrue(text:find("content mythicPlus,raid; keyLevel 10-", 1, true) ~= nil, text)
    NS.addon:OnSlashCommand("set group.when content")
    assertNil(NS.db.profile.groups[gid].when.content, "the condition alone clears it")
    m.prints = {}
    NS.addon:OnSlashCommand("set group.when keyLevel 12-10")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("The lowest key level is above the highest.", 1, true) ~= nil, text)
    NS.State.editing.pad = "p1"
    NS.addon:OnSlashCommand("set pad.point 40 -60")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "CENTER,CENTER,40,-60")
    NS.addon:OnSlashCommand("set pad.point topleft topleft 5 -5")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5")
    NS.addon:OnSlashCommand("set pad.point left")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5", "refused: nothing stored")
    NS.State.editing.builtin = "bi.mplus"
    NS.addon:OnSlashCommand("set builtin.hidden bi.mplus.lust")
    assertTrue(NS.db.profile.builtins["bi.mplus"].hidden["bi.mplus.lust"])
    NS.addon:OnSlashCommand("set builtin.hidden none")
    assertTrue(next(NS.db.profile.builtins["bi.mplus"].hidden) == nil)
    NS.State.editing.builtin = nil
    m.prints = {}
    NS.addon:OnSlashCommand("list")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("table: ", 1, true) == nil, "no table address printed")
    assertTrue(text:find("pad.point", 1, true) ~= nil, "every member row is listed")
    -- red under: drop the "(nothing to edit)" branch from the descriptor's format (builtin.* print nil)
    assertTrue(text:find("(nothing to edit)", 1, true) ~= nil, text)
end)

test("members: [review 1] a callout edited from the CLI in combat waits for combat end, with the stale hint", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Mine" })
    Lib.AddToGroup(gid, cid)
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming")
    NS.State.editing.callout = cid
    combat(m, true)
    NS.addon:OnSlashCommand("set callout.text Incoming {rt8}")
    assertEqual(NS.db.profile.callouts[cid].text, "Incoming {rt8}", "the write lands in combat")
    assertEqual(#m.blocked, 0, "no protected call")
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming", "the chip keeps its line")
    assertTrue(NS.Pad.Instance("p1").header.qcStale:IsShown(), "the stale hint")
    combat(m, false)
    assertEqual(NS.Pad.ChipsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming {rt8}")
    assertFalse(NS.Pad.Instance("p1").header.qcStale:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("members: [fix 1] pad.point refuses an unknown anchor name or a non-finite offset; nothing is stored", function()
    local NS = T.enableAddon()
    NS.State.editing.pad = "p1"
    NS.addon:OnSlashCommand("set pad.point topleft topleft 5 -5")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5")
    -- red under: Lib.ValidPoint checks only that the two anchors are strings
    NS.addon:OnSlashCommand("set pad.point foo bar 1 2")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5", "refused: unknown anchors")
    -- red under: Lib.ValidPoint checks only that the offsets are numbers
    NS.addon:OnSlashCommand("set pad.point nan 0")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5", "refused: a NaN offset")
    NS.addon:OnSlashCommand("set pad.point 0 inf")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,5,-5", "refused: an infinite offset")
end)

test("members: [final 2, 11] the CLI maps When values onto their tokens, and refuses one a row never matches", function()
    local NS, m = T.enableAddon()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    -- red under: parseWhen stores each word as typed (role=tank never matches TANK)
    NS.addon:OnSlashCommand("set group.when role tank")
    assertTrue(NS.db.profile.groups[gid].when.role.TANK)
    NS.addon:OnSlashCommand("set group.when class warrior, mage")
    assertTrue(NS.db.profile.groups[gid].when.class.WARRIOR and NS.db.profile.groups[gid].when.class.MAGE)
    NS.addon:OnSlashCommand("set group.when instances 2526")
    assertTrue(NS.db.profile.groups[gid].when.instances[2526])
    for _, typed in ipairs({ "instances Ara-Kara", "difficulty 16", "spec abc", "content mplus", "role tonk" }) do
        m.prints = {}
        NS.addon:OnSlashCommand("set group.when " .. typed)
        local text = table.concat(m.prints, "\n")
        assertTrue(text:find("does not take", 1, true) ~= nil, typed .. ": " .. text)
    end
    local when = NS.db.profile.groups[gid].when
    assertNil(when.difficulty, "refused: nothing stored")
    assertNil(when.spec)
    assertNil(when.content)
    assertTrue(when.instances[2526] and when.role.TANK, "the rest is kept")
    -- the seam refuses one from any writer, with the reason
    local ok, _, why = NS.SchemaRuntime.Set("group.when", { role = { tank = true } }, gid)
    assertFalse(ok)
    assertTrue(tostring(why):find("Role does not take tank", 1, true) ~= nil, tostring(why))
end)

test("members: [final 7] what `get group.when` prints types back in", function()
    local NS, m = T.enableAddon()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    NS.addon:OnSlashCommand("set group.when content mythicPlus,raid; role TANK; keyLevel 10-")
    local stored = NS.db.profile.groups[gid].when
    assertTrue(stored.content.raid and stored.role.TANK and stored.keyLevel.min == 10)
    m.prints = {}
    NS.addon:OnSlashCommand("get group.when")
    local printed = table.concat(m.prints, "\n"):match("group%.when|r = |cFFFFFFFF(.-)|r") or ""
    assertEqual(printed, "content mythicPlus,raid; keyLevel 10-; role TANK")
    NS.addon:OnSlashCommand("set group.when always")
    assertTrue(next(NS.db.profile.groups[gid].when) == nil, "always: no condition")
    -- red under: formatWhen prints `row=values; keyLevel=10..any`, which parseWhen refuses
    NS.addon:OnSlashCommand("set group.when " .. printed)
    local again = NS.db.profile.groups[gid].when
    assertTrue(again.content.mythicPlus and again.content.raid and again.role.TANK)
    assertEqual(again.keyLevel.min, 10)
    assertNil(again.keyLevel.max)
    NS.addon:OnSlashCommand("set group.when keyLevel=12..any")
    assertEqual(NS.db.profile.groups[gid].when.keyLevel.min, 12, "the older printed form reads too")
end)

test("members: [final 4] an off-screen pad.point is refused; `/qc reset` brings back a pad's place and clears an icon", function()
    local NS, m = T.enableAddon()
    NS.State.editing.pad = "p1"
    NS.addon:OnSlashCommand("set pad.point 40 -60")
    m.prints = {}
    -- red under: Lib.ValidPoint takes any finite offset
    NS.addon:OnSlashCommand("set pad.point 90000 -90000")
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "CENTER,CENTER,40,-60", "refused: nothing stored")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, table.concat(m.prints, "\n"))
    m.prints = {}
    -- red under: pad.point has no default ("has no default to restore")
    NS.addon:OnSlashCommand("reset pad.point")
    assertTrue(NS.db.profile.pads.p1.point == false, "the default place")
    assertEqual(table.concat(NS.addon.Settings.Pads.Point("p1"), ","), "CENTER,CENTER,0,-150")
    local cid = NS.Library.CreateCallout({ name = "Lust", text = "Lust", channel = "party", icon = 136012 })
    NS.State.editing.callout = cid
    -- red under: callout.icon has no default
    NS.addon:OnSlashCommand("reset callout.icon")
    assertTrue(NS.db.profile.callouts[cid].icon == false, "no icon")
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = 136012 })
    NS.State.editing.group = gid
    NS.addon:OnSlashCommand("reset group.icon")
    assertTrue(NS.db.profile.groups[gid].icon == false)
end)

test("members: [final 5] builtin.hidden with no set selected says to pick one", function()
    local NS, m = T.enableAddon()
    NS.State.editing.builtin = nil
    m.prints = {}
    NS.addon:OnSlashCommand("set builtin.hidden none")
    local text = table.concat(m.prints, "\n")
    -- red under: builtin.hidden's validate refuses every value when no set is addressed
    assertTrue(text:find("No built-in set is selected", 1, true) ~= nil, text)
    assertTrue(text:find("Only this set's own callouts", 1, true) == nil, text)
end)

-- ── the Comms Dial's member rows (phase 4) ──────────────────────────────────────────────────

test("members: [phase 4] a dial's fields are member rows, and its position goes through SetSurfacePoint", function()
    local NS, S, Lib = boot()
    assertTrue(S.Set("dial.slices", 6, "d2"))
    assertEqual(NS.db.profile.dials.d2.slices, 6)
    assertFalse((S.Set("dial.slices", 5, "d2")))
    assertTrue(S.Set("dial.mode", "flat", "d2"))
    assertEqual(NS.db.profile.dials.d2.mode, "flat")
    local fields = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.LIBRARY_CHANGED, function(_, kind, id, field)
        fields[#fields + 1] = tostring(kind) .. ":" .. tostring(id) .. ":" .. tostring(field)
    end)
    assertTrue(Lib.SetSurfacePoint("dial", "d2", { "CENTER", "CENTER", 0, 120 }))
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
    -- red under: keep Library's own dial branch in SetSurfacePoint (it announces with no field)
    assertEqual(table.concat(fields, ","), "dial:d2:dial.point", "the row's onChange, through Library.Touch")
    assertEqual(Lib.MemberIds("dial")[1], "d2")
    assertEqual(S.Get("dial.openAt"), "center", "no id: the first dial the page lists")
    local id = Lib.CreateSurface("dial", "Lead")
    assertEqual(NS.db.profile.dials[id].interaction, "relaxed", "Relaxed is the only interaction in v0.1.0")
end)

test("members: [review 4] a dial's key is stored upper-case; none clears it; a reserved key or another dial's is refused", function()
    local NS, S, Lib = boot()
    assertTrue(S.Set("dial.key", "shift-g", "d2"))
    assertEqual(NS.db.profile.dials.d2.key, "SHIFT-G")
    local other = Lib.CreateSurface("dial", "Lead")
    local ok, _, why = S.Set("dial.key", "SHIFT-G", other)
    assertFalse(ok)
    -- red under: drop the KeyOwner check from keyCheck in settings/SchemaMembers.lua
    assertEqual(why, "SHIFT-G already opens Comms Dial.")
    assertNil(NS.db.profile.dials[other].key)
    ok, _, why = S.Set("dial.key", "Escape", other)
    assertFalse(ok)
    assertEqual(why, "Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot open a dial: the open dial uses them.")
    assertFalse((S.Set("dial.key", "CTRL-BUTTON1", other)))
    assertFalse((S.Set("dial.key", "SHIFT-MOUSEWHEELDOWN", other)), "the open dial turns pages with the wheel")
    assertFalse((S.Set("dial.key", "1", other)), "and picks wedges with 1-8")
    assertTrue(S.Set("dial.key", "ALT-1", other), "a modified number is another key")
    assertTrue(S.Set("dial.key", "none", "d2"))
    assertEqual(NS.db.profile.dials.d2.key, false)
    assertTrue(S.Set("dial.key", "SHIFT-G", other), "free again")
end)

test("members: [final 3] a bare, dangling, unknown or repeated modifier is refused; [final 4] modifier order is one key", function()
    local NS, S, Lib = boot()
    for _, bad in ipairs({ "SHIFT", "SHIFT-", "FOO-G", "SHIFT-SHIFT-G" }) do
        local ok, _, why = S.Set("dial.key", bad, "d2")
        assertFalse(ok, bad)
        assertEqual(why, "A key is one key, with ALT-, CTRL- or SHIFT- in front if you like.", bad)
    end
    assertNil(NS.db.profile.dials.d2.key)
    assertTrue(S.Set("dial.key", "CTRL-SHIFT-G", "d2"))
    local other = Lib.CreateSurface("dial", "Lead")
    local ok, _, why = S.Set("dial.key", "shift-ctrl-g", other)
    assertFalse(ok)
    -- red under: only trim and upper-case in Lib.KeyValue (KeyOwner compares the strings)
    assertEqual(why, "CTRL-SHIFT-G already opens Comms Dial.")
    assertTrue(S.Set("dial.key", "none", "d2"))
    assertTrue(S.Set("dial.key", "shift-ctrl-g", other))
    assertEqual(NS.db.profile.dials[other].key, "CTRL-SHIFT-G")
end)

test("members: [phase 4] the CLI types and prints a dial's key and position", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("set dial.key ctrl-f")
    assertEqual(NS.db.profile.dials.d2.key, "CTRL-F")
    NS.addon:OnSlashCommand("set dial.point 10 -20")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,10,-20")
    m.prints = {}
    NS.addon:OnSlashCommand("get dial.key")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("CTRL-F", 1, true) ~= nil, text)
    NS.addon:OnSlashCommand("set dial.key none")
    m.prints = {}
    NS.addon:OnSlashCommand("get dial.key")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("none", 1, true) ~= nil, text)
end)

test("members: [phase 4] an off-screen dial.point is refused; `/qc reset` brings the dial back and frees its key", function()
    local NS, m = T.enableAddon()
    NS.State.editing.dial = "d2"
    NS.addon:OnSlashCommand("set dial.point 10 -20")
    NS.addon:OnSlashCommand("set dial.key g")
    m.prints = {}
    NS.addon:OnSlashCommand("set dial.point 90000 0")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,10,-20", "refused: nothing stored")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, table.concat(m.prints, "\n"))
    -- red under: dial.point has no default ("has no default to restore")
    NS.addon:OnSlashCommand("reset dial.point")
    assertTrue(NS.db.profile.dials.d2.point == false, "the default place")
    -- red under: dial.key has no default
    NS.addon:OnSlashCommand("reset dial.key")
    assertTrue(NS.db.profile.dials.d2.key == false, "no key")
end)
