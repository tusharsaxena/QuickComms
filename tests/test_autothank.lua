-- tests/test_autothank.lua — modules/AutoThank.lua (#19, spec §9): which of the player's new buffs are
-- thanked (AT.Accept), the thank-you line (AT.Fill) and the Thank button's macro (AT.Macro).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertNil, T.assertTrue, T.assertFalse

local STRANGER = "Player-2-0000000B"

local function settings(over)
    local s = { enabled = true, send = "emote", text = "Thanks for the {buff}, {name}!", mute = "none",
        raidBuffsOnly = false }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

local function aura(over)
    local a = { isHelpful = true, isFromPlayerOrPlayerPet = true, duration = 3600, spellId = 1459,
        name = "Arcane Intellect", auraInstanceID = 7 }
    for k, v in pairs(over or {}) do a[k] = v end
    return a
end

local function caster(over)
    local c = { guid = STRANGER, name = "Bob", whisperName = "Bob-ArgentDawn", known = false }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

local function boot()
    local NS, m = T.newAddon()
    m.issecretvalue = T.isSecret
    m.EMOTE98_TOKEN, m.EMOTE98_CMD1 = "THANK", "/thank"   -- the client's emote globals (tests/emote_tokens.lua)
    NS.Emotes.Reset()
    return NS, m
end

-- ── AT.Accept (D3) ──────────────────────────────────────────────────────────────────────────────

test("autothank: [CA-M4-4] Accept takes a stranger's helpful buff (isFromPlayerOrPlayerPet is any player's)", function()
    local NS = boot()
    -- red under revision 1's rule (isFromPlayerOrPlayerPet must be false)
    assertTrue(NS.AutoThank.Accept(aura(), caster(), settings(), 1000))
end)

test("autothank: [CA-M4-4] Accept rejects a harmful aura, an NPC's, no caster, and anything not plainly true", function()
    local NS = boot()
    local AT = NS.AutoThank
    assertFalse(AT.Accept(aura{ isHelpful = false }, caster(), settings(), 1000), "harmful")
    assertFalse(AT.Accept(aura{ isHelpful = T.secret(true) }, caster(), settings(), 1000), "a secret isHelpful")
    assertFalse(AT.Accept(aura{ isFromPlayerOrPlayerPet = false }, caster(), settings(), 1000), "an NPC's")
    assertFalse(AT.Accept(aura{ isFromPlayerOrPlayerPet = T.secret(true) }, caster(), settings(), 1000), "secret")
    assertFalse(AT.Accept(aura(), nil, settings(), 1000), "no readable caster")
    assertFalse(AT.Accept(T.secret(aura()), caster(), settings(), 1000), "a secret aura is never indexed")
    assertFalse(AT.Accept(nil, caster(), settings(), 1000), "no aura")
end)

test("autothank: [CA-M4-4] Accept needs a duration of at least 60 s: 59 and 0 (no expiry) are refused", function()
    local NS = boot()
    local AT = NS.AutoThank
    assertTrue(AT.Accept(aura{ duration = 60 }, caster(), settings(), 1000), "60 passes")
    assertFalse(AT.Accept(aura{ duration = 59 }, caster(), settings(), 1000), "59")
    assertFalse(AT.Accept(aura{ duration = 0 }, caster(), settings(), 1000), "no expiry")
    assertFalse(AT.Accept(aura{ duration = T.secret(3600) }, caster(), settings(), 1000), "a secret duration")
end)

test("autothank: [CA-M4-4] Accept keeps a cooldown per caster and spell", function()
    local NS = boot()
    local AT = NS.AutoThank
    AT.Stamp(caster(), 1459, 1000)
    assertFalse(AT.Accept(aura(), caster(), settings(), 1000 + 599), "inside the cooldown")
    assertTrue(AT.Accept(aura(), caster(), settings(), 1000 + 600), "the cooldown has passed")
    assertTrue(AT.Accept(aura{ spellId = 21562 }, caster(), settings(), 1001), "another spell")
    assertTrue(AT.Accept(aura(), caster{ guid = "Player-2-0000000C" }, settings(), 1001), "another caster")
end)

test("autothank: [CA-M4-4] Accept with raid-buffs-only takes only THANK_RAID_BUFFS", function()
    local NS = boot()
    local AT = NS.AutoThank
    local only = settings{ raidBuffsOnly = true }
    assertTrue(AT.Accept(aura{ spellId = 1459 }, caster(), only, 1000), "Arcane Intellect")
    assertFalse(AT.Accept(aura{ spellId = 10060 }, caster(), only, 1000), "Power Infusion is no raid buff")
    assertTrue(AT.Accept(aura{ spellId = 10060 }, caster(), settings(), 1000), "the allowlist is off")
end)

test("autothank: [CA-M4-4] Accept's two mutes: strangers and known (friends and guild)", function()
    local NS = boot()
    local AT = NS.AutoThank
    local friend = caster{ known = true }
    assertFalse(AT.Accept(aura(), caster(), settings{ mute = "strangers" }, 1000), "a stranger muted")
    assertTrue(AT.Accept(aura(), friend, settings{ mute = "strangers" }, 1000), "a friend under strangers")
    assertFalse(AT.Accept(aura(), friend, settings{ mute = "known" }, 1000), "a friend muted")
    assertTrue(AT.Accept(aura(), caster(), settings{ mute = "known" }, 1000), "a stranger under known")
end)

-- ── AT.Fill ─────────────────────────────────────────────────────────────────────────────────────

test("autothank: [CA-M4-4] Fill fills {name} and {buff}, flattens control bytes and doubles pipes", function()
    local NS = boot()
    local AT = NS.AutoThank
    assertEqual(AT.Fill("Thanks for the {buff}, {name}!", "Bob", "Arcane Intellect", 200),
        "Thanks for the Arcane Intellect, Bob!")
    assertEqual(AT.Fill("ty {name}\n/script x()", "B%1b", "x", 200), "ty B%1b /script x()", "no pattern escapes")
    assertEqual(AT.Fill("a|b {name}", "Bob", "x", 200), "a||b Bob")
end)

test("autothank: [CA-M4-4] Fill cuts at the budget on a UTF-8 boundary and never inside a doubled pipe", function()
    local NS = boot()
    local AT = NS.AutoThank
    local e = "\195\169"                                     -- é, two bytes
    assertEqual(AT.Fill("ab" .. e .. "c", "", "", 3), "ab", "é would end at byte 4")
    assertEqual(AT.Fill("ab" .. e .. "c", "", "", 4), "ab" .. e)
    assertEqual(AT.Fill("ab|c", "", "", 3), "ab", "the doubled pipe needs 2 bytes")
    assertEqual(AT.Fill("ab|c", "", "", 4), "ab||")
    assertEqual(#AT.Fill(string.rep(e, 200), "", "", 255), 254)
end)

test("autothank: [CA-M4-4] Fill refuses a text that starts with / and an empty text", function()
    local NS = boot()
    local AT = NS.AutoThank
    local s, why = AT.Fill("/run x()", "Bob", "x", 200)
    assertNil(s) assertEqual(why, "startsWithSlash")
    s, why = AT.Fill("  \n ", "Bob", "x", 200)
    assertNil(s) assertEqual(why, "empty")
    s, why = AT.Fill("{name}", "", "x", 200)
    assertNil(s) assertEqual(why, "empty", "a filled text that comes out empty")
end)

-- ── AT.Macro (D4) ───────────────────────────────────────────────────────────────────────────────

test("autothank: [CA-M4-4] Macro per mode: the THANK emote on the caster, a whisper, or both on two lines", function()
    local NS, m = boot()
    local AT = NS.AutoThank
    local thank = NS.Emotes.Command("THANK")
    assertTrue(thank ~= nil, "the client has /thank")
    assertEqual(AT.Macro(caster(), "Arcane Intellect", settings{ send = "emote" }), thank .. " Bob-ArgentDawn")
    assertEqual(AT.Macro(caster(), "Arcane Intellect", settings{ send = "line" }),
        m.SLASH_WHISPER1 .. " Bob-ArgentDawn Thanks for the Arcane Intellect, Bob!")
    local both = AT.Macro(caster(), "Arcane Intellect", settings{ send = "both" })
    assertEqual(both, thank .. " Bob-ArgentDawn\n" .. m.SLASH_WHISPER1 .. " Bob-ArgentDawn Thanks for the Arcane Intellect, Bob!")
end)

test("autothank: [CA-M4-4] Macro holds the whole macro to 255 bytes, the whisper's text cut to fit", function()
    local NS = boot()
    local AT = NS.AutoThank
    local long = settings{ send = "both", text = string.rep("x", 400) }
    local macro = AT.Macro(caster(), "Arcane Intellect", long)
    assertEqual(#macro, NS.Bake.MAX_MACRO, "both, cut to the cap")
    local line = AT.Macro(caster(), "Arcane Intellect", settings{ send = "line", text = string.rep("x", 400) })
    assertEqual(#line, NS.Bake.MAX_BYTES, "a whisper alone is one line of 255")
end)

test("autothank: [CA-M4-4] Macro refuses a / text and an empty one; both keeps the emote", function()
    local NS = boot()
    local AT = NS.AutoThank
    local thank = NS.Emotes.Command("THANK")
    local macro, why = AT.Macro(caster(), "x", settings{ send = "line", text = "/run x()" })
    assertNil(macro) assertEqual(why, "startsWithSlash")
    macro, why = AT.Macro(caster(), "x", settings{ send = "line", text = "" })
    assertNil(macro) assertEqual(why, "empty")
    assertEqual(AT.REASON.empty, NS.L["Nothing to whisper: the thank-you text is empty."])
    macro, why = AT.Macro(caster(), "x", settings{ send = "both", text = "" })
    assertEqual(macro, thank .. " Bob-ArgentDawn", "both keeps the emote")
    assertEqual(why, "empty", "and says why the whisper was dropped")
    macro = AT.Macro(caster(), "x", settings{ send = "both", text = "/run x()" })
    assertEqual(macro, thank .. " Bob-ArgentDawn")
    local nameless = caster()
    nameless.whisperName = nil
    assertNil((AT.Macro(nameless, "x", settings())), "no whisper name")
end)

test("autothank: [CA-M4-4] Macro reads the client's own /w through Compat: none refuses the whisper", function()
    local NS, m = boot()
    local AT = NS.AutoThank
    m.SLASH_WHISPER1 = "/susurrar"
    assertEqual(AT.Macro(caster(), "x", settings{ send = "line", text = "ty" }), "/susurrar Bob-ArgentDawn ty")
    m.SLASH_WHISPER1 = nil
    local macro, why = AT.Macro(caster(), "x", settings{ send = "line", text = "ty" })
    assertNil(macro) assertEqual(why, "noWhisper")
    assertEqual(AT.Macro(caster(), "x", settings{ send = "both", text = "ty" }), NS.Emotes.Command("THANK") .. " Bob-ArgentDawn")
end)

-- ── the unit-filter frame (CA-M4-5, events-frames-taint-§1's carve-out) ─────────────────────────

local DUNGEON = { inInstance = true, instanceType = "party", difficultyID = 1, inGroup = true }

local function live(inputs)
    local NS, _, m = T.enableAddon()
    m.issecretvalue = T.isSecret
    NS.Situation.ReadInputs = function() return inputs or {} end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function auraUnits(NS)
    local u = NS.AutoThank.frame.__unitEvents.UNIT_AURA
    return u and table.concat(u, ",") or ""
end

test("autothank: [CA-M4-5] the frame hears UNIT_AURA for the player alone, on in the open world", function()
    local NS = live()
    assertEqual(NS.Situation.Current().content, "openWorld")
    -- red under: AT.Rewire never called on SITUATION_CHANGED
    assertEqual(auraUnits(NS), "player")
    assertNil(NS.AutoThank.frame.__frameEvents.UNIT_AURA, "a unit event, never the unfiltered one")
end)

test("autothank: [CA-M4-5] off, in a dungeon by default, or stood down, the frame hears nothing", function()
    local NS = live()
    NS.db.profile.thank.enabled = false
    NS.AutoThank.Rewire()
    assertEqual(auraUnits(NS), "", "switched off")
    NS.db.profile.thank.enabled = true
    NS.AutoThank.Rewire()
    assertEqual(auraUnits(NS), "player", "back on")
    NS.Situation.ReadInputs = function() return DUNGEON end
    NS.Situation.RefreshNow("test")
    assertEqual(NS.Situation.Current().content, "dungeon")
    assertEqual(auraUnits(NS), "", "a dungeon is off by default (R-B)")
    NS.db.profile.thank.content.dungeon = true
    NS.AutoThank.Rewire()
    assertEqual(auraUnits(NS), "player", "a content kind switched on")
end)

test("autothank: [CA-M4-5] a profile switch re-reads the thank settings", function()
    local NS = live()
    NS.db.profile.thank.enabled = false
    NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
    assertEqual(auraUnits(NS), "")
end)

test("autothank: [CA-M4-5] the stand-down unregisters the frame, and the stand-up re-uses it", function()
    local NS = live()
    local frame = NS.AutoThank.frame
    NS.addon:OnSlashCommand("disable")
    assertTrue(NS.IsStoodDown())
    -- red under: no NS.STAND_DOWN step (AceAddon's UnregisterAllEvents never reaches this frame)
    assertEqual(auraUnits(NS), "", "stood down")
    NS.AutoThank.Rewire()
    assertEqual(auraUnits(NS), "", "a rewire while stood down registers nothing")
    NS.addon:OnSlashCommand("enable")
    assertTrue(NS.AutoThank.frame == frame, "the same frame, never rebuilt")
    assertEqual(auraUnits(NS), "player", "the stand-up registers it again")
end)

test("autothank: [CA-M4-5] the frame's UNIT_AURA reaches AT.OnAura with its payload", function()
    local NS, m = live()
    local got
    NS.AutoThank.OnAura = function(unit, info) got = { unit, info } end
    local info = m.auraUpdate{ isFullUpdate = true }
    NS.AutoThank.frame:GetScript("OnEvent")(NS.AutoThank.frame, "UNIT_AURA", "player", info)
    assertEqual(got[1], "player")
    assertTrue(got[2] == info)
end)

-- ── AT.OnAura: detection and the known-aura set (CA-M4-6, spec §9 Detection) ─────────────────────

-- An enabled addon in the open world whose candidates are caught, with a stranger who can buff.
local function detecting()
    local NS, m = live()
    m.players[STRANGER] = { name = "Bob", realm = "Argent Dawn" }
    m.__now = 1000
    local got = {}
    NS.AutoThank.Offer = function(c) got[#got + 1] = c end
    return NS, m, got
end

local function buff(m, fields)
    local f = { casterGUID = STRANGER }
    for k, v in pairs(fields or {}) do f[k] = v end
    return m.addAura(f)
end

test("autothank: [CA-M4-6] an added plain aura that passes Accept becomes a candidate, and is known", function()
    local NS, m, got = detecting()
    local a = buff(m)
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { a } })
    assertEqual(#got, 1)
    assertTrue(got[1].aura == a)
    assertEqual(got[1].caster.guid, STRANGER)
    assertEqual(got[1].key, STRANGER .. ":1459")
    assertTrue(NS.State.thankKnown[a.auraInstanceID], "the new aura joins the known set")
    local short = buff(m, { duration = 30 })
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { short } })
    assertEqual(#got, 1, "a refused aura is no candidate")
    assertTrue(NS.State.thankKnown[short.auraInstanceID], "but it is known")
end)

test("autothank: [CA-M4-6] a full update re-snapshots the known set silently", function()
    local NS, m, got = detecting()
    local a, b = buff(m), buff(m, { spellId = 21562 })
    NS.State.thankKnown = { [99] = true }
    NS.AutoThank.OnAura("player", m.auraUpdate{ isFullUpdate = true, addedAuras = { a, b } })
    assertEqual(#got, 0, "a login, zoning or reload never bursts")
    assertTrue(NS.State.thankKnown[a.auraInstanceID] and NS.State.thankKnown[b.auraInstanceID])
    assertNil(NS.State.thankKnown[99], "the old set is replaced")
end)

test("autothank: [CA-M4-6] removed ids leave the known set", function()
    local NS, m = detecting()
    local a = buff(m)
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { a } })
    NS.AutoThank.OnAura("player", m.auraUpdate{ removedAuraInstanceIDs = { a.auraInstanceID } })
    assertNil(NS.State.thankKnown[a.auraInstanceID])
end)

test("autothank: [CA-M4-6] a secret or non-table payload sets dirty and indexes nothing", function()
    local NS, m, got = detecting()
    NS.State.thankDirty = false
    -- red under: indexing the payload before the secret test (the kit's secret raises on index)
    NS.AutoThank.OnAura("player", m.secretAuraUpdate{ addedAuras = { buff(m) } })
    assertTrue(NS.State.thankDirty, "secret")
    NS.State.thankDirty = false
    NS.AutoThank.OnAura("player", nil)
    assertTrue(NS.State.thankDirty, "not a table")
    NS.State.thankDirty = false
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { T.secret(buff(m)) } })
    assertTrue(NS.State.thankDirty, "a secret entry")
    assertEqual(#got, 0)
end)

test("autothank: [CA-M4-6] in combat, or on the combat edge, it only marks dirty", function()
    local NS, m, got = detecting()
    NS.State.thankDirty = false
    m.inCombat = true
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { buff(m) } })
    assertTrue(NS.State.thankDirty, "in combat")
    m.inCombat = false
    NS.State.thankDirty = false
    NS.State.combatEdge = true
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { buff(m) } })
    assertTrue(NS.State.thankDirty, "on the edge, before lockdown reads true")
    assertEqual(#got, 0)
    NS.State.combatEdge = false
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { buff(m) } })
    assertEqual(#got, 1, "after the fight's edge it detects again")
end)

test("autothank: [CA-M4-6] stood down, or the content kind off, gives nothing", function()
    local NS, m, got = detecting()
    NS.db.profile.thank.content.openWorld = false
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { buff(m) } })
    assertEqual(#got, 0, "the open world switched off")
    NS.db.profile.thank.content.openWorld = true
    NS.addon:OnSlashCommand("disable")
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { buff(m) } })
    assertEqual(#got, 0, "stood down")
end)

test("autothank: [CA-M4-6] registering the frame snapshots the player's helpful auras silently", function()
    local NS, m, got = detecting()
    NS.db.profile.thank.enabled = false
    NS.AutoThank.Rewire()
    local a = buff(m)
    NS.db.profile.thank.enabled = true
    NS.AutoThank.Rewire()
    assertTrue(NS.State.thankKnown[a.auraInstanceID], "a buff held when it switched on is known")
    assertEqual(#got, 0)
end)
