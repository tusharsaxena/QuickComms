-- tests/test_members.lua — the member rows (architecture-§5, settings/SchemaMembers.lua). Every field a
-- player sets on a callout, a group, a Comms Pad or a built-in set goes through the one seam, addressed
-- by an instance argument, by the member its editor page has selected (NS.State.editing), or by the
-- first member that page lists. A callout is addressed by its id alone. Library keeps membership and
-- announces every field write; the pads pick a write up through Surfaces.Request, queued in combat.

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
    for id in pairs(NS.db.profile.pads) do Lib.DeleteSurface("pad", id) end
    for id in pairs(NS.db.profile.groups) do NS.db.profile.groups[id] = nil end   -- the seeded groups
    local ok, err = S.Set("pad.name", "Other")
    assertFalse(ok)
    assertTrue(tostring(err):find("No pad to edit", 1, true) ~= nil, tostring(err))
    local b = Lib.CreateGroup({ name = "Beta" })
    local a = Lib.CreateGroup({ name = "Alpha" })
    -- red under: drop the Library.MemberIds fallback from Settings.EditingId (nothing selected is a refusal)
    assertTrue(S.Set("group.name", "First"))
    assertEqual(NS.db.profile.groups[a].name, "First", "the first group the page lists, by name")
    NS.State.editing.group = b
    assertTrue(S.Set("group.name", "Hero"))
    assertEqual(NS.db.profile.groups[b].name, "Hero")
    assertEqual(S.Get("group.name"), "Hero")
    NS.State.editing.group = "g999"   -- a stale selection falls back too; nothing lands on it
    assertTrue(S.Set("group.name", "Again"))
    assertEqual(NS.db.profile.groups[a].name, "Again")
    assertNil(NS.db.profile.groups.g999)
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

test("members: a seeded group's fields read and write as any group's; the shipped set never changes", function()
    local NS, S = boot()
    local gid = T.seeded(NS, "bi.mplus")
    NS.State.editing.group = gid
    assertEqual(S.Get("group.name"), NS.BuiltIns.groups["bi.mplus"].name)
    -- red under: a group row refusing a group that carries an origin
    assertTrue((S.Set("group.name", "Mine")))
    assertTrue((S.Set("group.enabled", false, gid)))
    assertTrue((S.Set("group.when", { content = { raid = true } }, gid)))
    assertEqual(NS.db.profile.groups[gid].name, "Mine")
    assertEqual(NS.BuiltIns.groups["bi.mplus"].name, "Dungeon", "the seed data is untouched")
    assertTrue(NS.BuiltIns.groups["bi.mplus"].when.content.mythicPlus)
    assertFalse((S.Set("group.name", "Mine", "bi.mplus")), "a shipped id is no group")
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

test("members: Library's own writers (the pad point, an icon) go through the seam, one announce each", function()
    local NS, S, Lib = boot()
    local gid = Lib.CreateGroup({ name = "Mine" })
    local out = heard(NS)
    assertTrue(Lib.SetSurfacePoint("pad", "p1", { "TOPLEFT", "TOPLEFT", 4, -4 }))
    assertTrue(Lib.SetIcon("group", gid, NS.Icon("star"), "ff0000"))
    assertEqual(table.concat(out, ","), "pad:p1,group:nil", "the icon and its color are one act")
    -- Each writer reaches the seam, by path and instance argument.
    local paths = {}
    local set = S.Set
    S.Set = function(path, value, id)
        paths[#paths + 1] = path .. "@" .. tostring(id)
        return set(path, value, id)
    end
    Lib.SetSurfacePoint("pad", "p1", nil)
    Lib.SetIcon("group", gid, NS.Icon("heart"), false)
    S.Set = set
    -- red under: assign the field directly in either writer in modules/Library.lua
    assertEqual(table.concat(paths, ","), "pad.point@p1,group.icon@" .. gid .. ",group.iconColor@" .. gid)
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
    m.prints = {}
    NS.addon:OnSlashCommand("list")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("table: ", 1, true) == nil, "no table address printed")
    assertTrue(text:find("pad.point", 1, true) ~= nil, "every member row is listed")
    -- red under: drop the "(nothing to edit)" branch from the descriptor's format (callout.* print nil)
    assertTrue(text:find("(nothing to edit)", 1, true) ~= nil, text)
end)

test("members: [review 1] a callout edited from the CLI in combat waits for combat end, with the stale hint", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Mine" })
    cid = Lib.AddToGroup(gid, cid)
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    assertEqual(NS.Pad.ButtonsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming")
    combat(m, true)
    NS.addon:OnSlashCommand("set callout.text " .. cid .. " Incoming {rt8}")
    assertEqual(NS.db.profile.callouts[cid].text, "Incoming {rt8}", "the write lands in combat")
    assertEqual(#m.blocked, 0, "no protected call")
    assertEqual(NS.Pad.ButtonsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming", "the button keeps its line")
    assertTrue(NS.Pad.Instance("p1").header.qcStale:IsShown(), "the stale hint")
    combat(m, false)
    assertEqual(NS.Pad.ButtonsFor("p1", cid)[1]:GetAttribute("macrotext"), "/p Incoming {rt8}")
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
    -- red under: callout.icon has no default
    NS.addon:OnSlashCommand("reset callout.icon " .. cid)
    assertTrue(NS.db.profile.callouts[cid].icon == false, "no icon")
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = 136012 })
    NS.State.editing.group = gid
    NS.addon:OnSlashCommand("reset group.icon")
    assertTrue(NS.db.profile.groups[gid].icon == false)
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

test("members: [keys] a dial has no key row: its key is WoW's binding, set in Options -> Keybindings, never on the CLI", function()
    local NS, S = boot()
    -- red under: a dial.key member row (a profile field, account-wide WoW bindings out of step)
    assertNil(S.FindRow("dial.key"))
    assertNil(NS.Library.TEMPLATES.dial.key)
end)

test("members: [phase 4] the CLI types and prints a dial's position", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("set dial.point 10 -20")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,10,-20")
    m.prints = {}
    NS.addon:OnSlashCommand("get dial.point")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("CENTER CENTER 10 -20", 1, true) ~= nil, text)
end)

test("members: [phase 4] an off-screen dial.point is refused; `/qc reset` brings the dial back", function()
    local NS, m = T.enableAddon()
    NS.State.editing.dial = "d2"
    NS.addon:OnSlashCommand("set dial.point 10 -20")
    m.prints = {}
    NS.addon:OnSlashCommand("set dial.point 90000 0")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,10,-20", "refused: nothing stored")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, table.concat(m.prints, "\n"))
    -- red under: dial.point has no default ("has no default to restore")
    NS.addon:OnSlashCommand("reset dial.point")
    assertTrue(NS.db.profile.dials.d2.point == false, "the default place")
end)

test("members: [phase 5] a When's key level prints as it types back in: one level, open below, open above", function()
    local NS, m = T.enableAddon()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    for _, typed in ipairs({ "12", "-15", "10-", "10-15" }) do
        NS.addon:OnSlashCommand("set group.when keyLevel " .. typed)
        m.prints = {}
        NS.addon:OnSlashCommand("get group.when")
        local text = table.concat(m.prints, "\n")
        assertTrue(text:find("keyLevel " .. typed, 1, true) ~= nil, typed .. ": " .. text)
    end
end)

test("members: [phase 5] a pad's Look rows are composed member rows: checked, clamped, announced", function()
    local NS, S, Lib = boot()
    local pid = Lib.CreateSurface("pad", "Mine")
    local out = heard(NS)
    assertTrue(S.Set("pad.section.fontSize", 99, pid))
    assertEqual(NS.db.profile.pads[pid].section.fontSize, 32, "clamped to the row's range")
    local ok, _, why = S.Set("pad.look.borderColor", { r = 2, g = 0, b = 0 }, pid)
    assertFalse(ok)
    assertEqual(why, "A color is red, green and blue, and optionally alpha, each from 0 to 1.")
    assertFalse((S.Set("pad.section.fontFlags", "SPARKLY", pid)))
    assertTrue(S.Set("pad.section.fontFlags", "OUTLINE", pid))
    assertTrue(S.Set("pad.look.useClassColorBorder", true, pid))
    assertEqual(table.concat(out, ","), "pad:" .. pid .. ",pad:" .. pid .. ",pad:" .. pid)
    local row = S.FindRow("pad.look.background")
    assertEqual(row.classColorSource, "player", "a pad's text and chrome describe no unit")
end)

-- ── a glyph's color (icon browser spec, "Data model") ───────────────────────────────────────

local BLOODLUST = "Interface\\Icons\\Spell_Nature_Bloodlust"

test("members: [icons] a glyph's color is written through the seam by id, typed text read as rrggbb", function()
    local NS, S, Lib = boot()
    local star = NS.Icon("star")
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party", icon = star })
    local out = heard(NS)
    -- red under: drop the callout.iconColor row (an unknown path is refused)
    assertTrue(S.Set("callout.iconColor", " #FF8000 ", cid))
    assertEqual(NS.db.profile.callouts[cid].iconColor, "ff8000", "trimmed, no #, lower case")
    assertEqual(table.concat(out, ","), "callout:" .. cid)
    assertTrue(S.Set("callout.iconColor", "", cid))
    assertTrue(NS.db.profile.callouts[cid].iconColor == false, "empty text is no color")
    local gid = Lib.CreateGroup({ name = "Mine", icon = star })
    assertTrue(S.Set("group.iconColor", "00ff00", gid))
    assertEqual(NS.db.profile.groups[gid].iconColor, "00ff00")
end)

test("members: [icons] a malformed color, a color on no glyph and a shipped id's color are refused", function()
    local NS, S, Lib = boot()
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party", icon = NS.Icon("star") })
    for _, bad in ipairs({ "ff80", "gg8000", "ff80001", 16744448, { 1, 0, 0 } }) do
        local ok, _, why = S.Set("callout.iconColor", bad, cid)
        assertFalse(ok, tostring(bad))
        assertEqual(why, "An icon color is six hex digits (rrggbb), or empty for none.")
    end
    assertNil(NS.db.profile.callouts[cid].iconColor)
    local plain = Lib.CreateCallout({ name = "Kick", text = "Kick", channel = "party", icon = BLOODLUST })
    -- red under: drop the glyph check from iconColorCheck
    local ok, _, why = S.Set("callout.iconColor", "ff0000", plain)
    assertFalse(ok)
    assertEqual(why, "Only a LibKa0s glyph takes a color: choose one as the icon first.")
    assertTrue(S.Set("callout.iconColor", false, plain), "clearing is always allowed")
    assertFalse((S.Set("group.iconColor", "ff0000", "bi.mplus")), "a shipped id is no group")
end)

test("members: [icons] an icon that is no glyph clears the color in the same act; a glyph keeps it", function()
    local NS, S, Lib = boot()
    local star, heart = NS.Icon("star"), NS.Icon("heart")
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party", icon = star, iconColor = "ff0000" })
    assertTrue(S.Set("callout.icon", heart, cid))
    assertEqual(NS.db.profile.callouts[cid].iconColor, "ff0000", "another glyph keeps the color")
    local out = heard(NS)
    -- red under: drop the ICON_ROWS onChange in settings/SchemaMembers.lua
    assertTrue(S.Set("callout.icon", "136012", cid))
    assertTrue(not NS.db.profile.callouts[cid].iconColor, "a game icon drops the color")
    assertEqual(#out, 1, "one LIBRARY_CHANGED for the icon and its color")
    local gid = Lib.CreateGroup({ name = "Mine", icon = star, iconColor = "00ff00" })
    assertTrue(S.Set("group.icon", "", gid))
    assertTrue(not NS.db.profile.groups[gid].iconColor, "no icon drops the color too")
end)

test("members: [icons] Library.SetIcon writes the icon and its color as one act", function()
    local NS, _, Lib = boot()
    local star = NS.Icon("star")
    local cid = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    local out = heard(NS)
    -- red under: SetIcon writing the two rows outside Library.Batch (two LIBRARY_CHANGED)
    assertTrue(Lib.SetIcon("callout", cid, star, "#00FF00"))
    local c = NS.db.profile.callouts[cid]
    assertEqual(c.icon, star)
    assertEqual(c.iconColor, "00ff00")
    assertEqual(#out, 1)
    assertTrue(Lib.SetIcon("callout", cid, 136012, "00ff00"), "a texture id as a number")
    assertEqual(c.icon, 136012)
    assertTrue(not c.iconColor, "a game icon takes no color: cleared, not refused")
    local ok, why = Lib.SetIcon("callout", cid, star, "nope")
    assertFalse(ok)
    assertEqual(why, "badIconColor")
    assertEqual(c.icon, 136012, "a malformed color writes nothing")
    assertFalse((Lib.SetIcon("group", "bi.mplus", star, false)), "a shipped id is no group")
    assertFalse((Lib.SetIcon("pad", "p1", star, false)))
end)

test("members: [icons] `/qc reset` clears a color; a group page's Defaults keeps it with the icon", function()
    local NS = T.enableAddon()
    local star = NS.Icon("star")
    local cid = NS.Library.CreateCallout({ name = "Lust", text = "Lust", channel = "party", icon = star, iconColor = "ff0000" })
    NS.addon:OnSlashCommand("reset callout.iconColor " .. cid)
    assertTrue(NS.db.profile.callouts[cid].iconColor == false)
    local gid = NS.Library.CreateGroup({ name = "Mine", icon = star, iconColor = "ff0000" })
    NS.State.editing.group = gid
    -- red under: drop group.iconColor from settings/Schema.lua resetExempt
    NS.addon.Settings.Helpers.RestoreDefaults("groups")
    assertEqual(NS.db.profile.groups[gid].iconColor, "ff0000")
end)

test("members: [inherit] group.inheritWhen is a member row: a bool stores and announces, anything else is refused", function()
    local NS, S, Lib = boot()
    local parent = Lib.CreateGroup({ name = "Raid night" })
    local child = Lib.CreateGroup({ name = "Boss 1" })
    assertTrue(S.Set("group.parent", parent, child))
    local out = heard(NS)
    -- red under: no group.inheritWhen row in settings/SchemaMembers.lua
    assertTrue(S.Set("group.inheritWhen", false, child))
    assertEqual(NS.db.profile.groups[child].inheritWhen, false)
    assertEqual(table.concat(out, ","), "group:" .. child)
    assertFalse((S.Set("group.inheritWhen", "maybe", child)), "not a bool")
    assertEqual(NS.db.profile.groups[child].inheritWhen, false)
    NS.State.editing.group = child
    NS.addon:OnSlashCommand("set group.inheritWhen true")
    assertTrue(NS.db.profile.groups[child].inheritWhen, "the CLI reaches it")
end)

test("members: [inherit] the Enabled tooltip names whose When a sub-group is shown by", function()
    -- red under: "Show this group wherever its When matches", which reads wrong for a group that
    -- inherits: it is shown wherever its parent's When matches, whatever its own says.
    local NS = T.enableAddon()
    local row = NS.SchemaRuntime.FindRow("group.enabled")
    assertEqual(row.desc, "Show this group wherever its When matches (its parent's, while Inherit when conditions is ticked). Off keeps the group and its place on every pad.")
end)

test("members: [arena] the CLI sets the arena row by id, name or all, and prints it back", function()
    local NS, m = T.enableAddon()
    m.GetRealZoneText = function(id) return ({ [1505] = "Nagrand Arena", [572] = "Ruins of Lordaeron" })[id] or "" end
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    -- red under: an arena condition the CLI does not know ("Name a condition")
    NS.addon:OnSlashCommand("set group.when arena Nagrand Arena, 572")
    local when = NS.db.profile.groups[gid].when
    assertTrue(when.arena and when.arena[1505] and when.arena[572], "a name with a space, split on commas")
    m.prints = {}
    NS.addon:OnSlashCommand("get group.when")
    assertTrue(table.concat(m.prints, "\n"):find("arena 1505,572", 1, true) ~= nil, table.concat(m.prints, "\n"))
    NS.addon:OnSlashCommand("set group.when arena all")
    assertTrue(NS.db.profile.groups[gid].when.arena.all)
end)
