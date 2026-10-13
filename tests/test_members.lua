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
