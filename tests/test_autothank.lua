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

-- ── the after-combat diff (CA-M4-7, spec §9 Combat, F4c) ────────────────────────────────────────

-- The two combat edges as the client delivers them (tests/test_sendengine.lua): PLAYER_REGEN_DISABLED
-- fires while lockdown still reads false, and lockdown ends before PLAYER_REGEN_ENABLED fires.
local function edgeOn(m)
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_DISABLED")
end
local function fightOver(m)
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_ENABLED")
end

test("autothank: [CA-M4-7] a buff in the edge window is not diffed at the edge, and is thanked after the fight", function()
    local NS, m, got = detecting()
    edgeOn(m)
    assertFalse(m.InCombatLockdown(), "lockdown still reads false at the edge")
    local a = buff(m)
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { a } })
    assertEqual(#got, 0, "nothing toasted at the edge")
    assertTrue(NS.State.thankDirty)
    -- the edge's own drain (RESTRICTION_CHANGED while lockdown is false) runs nothing for it
    NS.SendEngine.Drain("test")
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, nil, true)
    assertEqual(#got, 0, "red under SE.RunOrQueue or a diff that ignores the edge")
    assertTrue(NS.State.thankDirty, "still dirty")
    m.__setCombat(true)
    fightOver(m)
    assertEqual(#got, 1, "thanked once the fight is over")
    assertTrue(got[1].aura == a)
    assertFalse(NS.State.thankDirty)
end)

test("autothank: [CA-M4-7] a secret payload in combat gives the new aura once at the end of combat", function()
    local NS, m, got = detecting()
    edgeOn(m)
    m.__setCombat(true)
    local a = buff(m)
    NS.AutoThank.OnAura("player", m.secretAuraUpdate{ addedAuras = { a } })
    assertEqual(#got, 0)
    fightOver(m)
    assertEqual(#got, 1)
    NS.AutoThank.Diff()
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, nil, true)
    assertEqual(#got, 1, "once")
end)

test("autothank: [CA-M4-7] a /reload in combat with no RESTRICTION_CHANGED still diffs at PLAYER_REGEN_ENABLED", function()
    local NS, m, got = detecting()
    NS.State.combatEdge = nil              -- a login or /reload in combat: no edge seen
    m.__setCombat(true)
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { buff(m) } })
    NS.Restrictions.Refresh = function() return false end   -- the edge moves nothing
    NS.SendEngine.Drain = function() return 0 end            -- and nothing drains
    fightOver(m)
    -- red under: no R.OnCombatEdge(false) hook
    assertEqual(#got, 1)
end)

test("autothank: [CA-M4-7] a still restricted read stays dirty and toasts nothing", function()
    local NS, m, got = detecting()
    local a = buff(m)
    NS.State.thankDirty = true
    m.auraInstanceIDs = { T.secret(a.auraInstanceID) }
    NS.AutoThank.Diff()
    assertEqual(#got, 0)
    assertTrue(NS.State.thankDirty)
    m.auraInstanceIDs = nil
    NS.AutoThank.Diff()
    assertEqual(#got, 1, "the lifted read catches it up")
    assertFalse(NS.State.thankDirty)
end)

test("autothank: [CA-M4-7] the diff takes at most COMBAT_QUEUE candidates, newest first", function()
    local NS, m, got = detecting()
    local ids = {}
    for i = 1, 12 do ids[i] = buff(m, { spellId = 5000 + i }).auraInstanceID end
    NS.State.thankDirty = true
    NS.AutoThank.Diff()
    assertEqual(#got, NS.Constants.THANK.COMBAT_QUEUE)
    assertEqual(got[1].aura.auraInstanceID, ids[12], "newest first")
    assertEqual(got[10].aura.auraInstanceID, ids[3])
    assertTrue(NS.State.thankKnown[ids[1]], "the rest are known, never thanked later")
end)

test("autothank: [CA-M4-7] expired or unreadable auras drop quietly", function()
    local NS, m, got = detecting()
    local gone = buff(m)
    local nameless = m.addAura{ spellId = 21562 }          -- no caster GUID and no sourceUnit
    local good = buff(m, { spellId = 1126 })
    m.auraInstanceIDs = { gone.auraInstanceID, nameless.auraInstanceID, good.auraInstanceID }
    m.auras[gone.auraInstanceID] = nil                    -- expired between the list and the read
    NS.State.thankDirty = true
    NS.AutoThank.Diff()
    assertEqual(#got, 1)
    assertTrue(got[1].aura == good)
    assertFalse(NS.State.thankDirty)
end)

test("autothank: [CA-M4-7] the diff waits while in combat or on the edge, and does nothing when clean", function()
    local NS, m, got = detecting()
    buff(m)
    NS.State.thankDirty = true
    NS.State.combatEdge = true
    NS.AutoThank.Diff()
    assertEqual(#got, 0, "on the edge")
    NS.State.combatEdge = false
    m.inCombat = true
    NS.AutoThank.Diff()
    assertEqual(#got, 0, "in combat")
    m.inCombat = false
    NS.State.thankDirty = false
    NS.AutoThank.Diff()
    assertEqual(#got, 0, "a clean set is not diffed")
end)

test("autothank: [CA-M4-R2] buffs held before a /reload in combat are not thanked after the fight", function()
    local NS, m, got = detecting()
    local held = {}
    for i = 1, 3 do held[i] = buff(m, { spellId = 6000 + i }) end
    -- the /reload in combat: the known set starts empty and the first snapshot reads restricted
    NS.State.thankKnown, NS.State.thankDirty, NS.State.combatEdge = {}, false, nil
    m.__setCombat(true)
    local secret = {}
    for i, a in ipairs(held) do secret[i] = T.secret(a.auraInstanceID) end
    m.auraInstanceIDs = secret
    assertFalse(NS.AutoThank.Snapshot())
    NS.AutoThank.OnAura("player", m.secretAuraUpdate{ isFullUpdate = true })
    m.auraInstanceIDs = nil
    fightOver(m)
    -- red under: a diff that takes every held buff as fresh against the empty set
    assertEqual(#got, 0, "no burst for the buffs held before the reload")
    assertTrue(NS.State.thankKnown[held[1].auraInstanceID], "they are the baseline now")
    assertFalse(NS.State.thankDirty)
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { buff(m, { spellId = 1126 }) } })
    assertEqual(#got, 1, "a buff gained after the baseline is still thanked")
end)

test("autothank: [CA-M4-R2] a known set kept across the fight still thanks the buff gained in it", function()
    local NS, m, got = detecting()
    buff(m, { spellId = 6001 })
    assertTrue(NS.AutoThank.Snapshot())
    edgeOn(m)
    m.__setCombat(true)
    NS.AutoThank.OnAura("player", m.secretAuraUpdate{ addedAuras = { buff(m, { spellId = 1126 }) } })
    fightOver(m)
    assertEqual(#got, 1, "only the new one")
end)

-- ── the toast host and its throttle (CA-M4-9, spec §9 The toast) ────────────────────────────────

-- An enabled addon whose toast's Show calls are recorded with the time each was made.
local function hosting()
    local NS, m = live()
    m.__now = 1000
    local TH = NS.AutoThankToast
    local shows = {}
    local show = TH.toast.Show
    TH.toast.Show = function(self, payload, opts)
        shows[#shows + 1] = { at = m.GetTime(), key = opts and opts.key, payload = payload }
        return show(self, payload, opts)
    end
    return NS, m, TH, shows
end

local function stranger(m, n)
    local guid = ("Player-2-%08X"):format(0x100 + n)
    m.players[guid] = { name = "Caster" .. n, realm = "Argent Dawn" }
    return guid
end

-- One candidate from caster `n`, as AT.OnAura hands it on.
local function offer(NS, m, n, spellId)
    local guid = stranger(m, n)
    local a = m.addAura{ casterGUID = guid, spellId = spellId or 1459 }
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { a } })
    return guid .. ":" .. (spellId or 1459)
end

-- Fire the host's GAP pump alone (the toasts' own countdowns sit in the same queue), `dt` later.
local function pumpAfter(m, TH, dt)
    m.__now = m.__now + dt
    local h = TH.pumpTimer
    if not h then return false end
    for i, t in ipairs(m.__timers) do
        if t == h or t.timer == h then
            table.remove(m.__timers, i)
            t.fn()
            return true
        end
    end
    return false
end

test("autothank: [CA-M4-9] five strangers give 3 toasts on screen and 2 queued, shown GAP apart", function()
    local NS, m, TH, shows = hosting()
    local GAP = NS.Constants.THANK.GAP
    local keys = {}
    for n = 1, 5 do keys[n] = offer(NS, m, n) end
    assertEqual(#shows, 1, "the first shows at once")
    assertEqual(shows[1].key, keys[1])
    pumpAfter(m, TH, GAP / 2)
    assertEqual(#shows, 1, "never two inside one GAP")
    for _ = 2, 5 do assertTrue(pumpAfter(m, TH, GAP), "the pump is armed") end
    assertEqual(#shows, 5)
    for i = 2, 5 do assertTrue(shows[i].at - shows[i - 1].at >= GAP, "Show " .. i .. " is GAP after the last") end
    local st = TH.toast:Stats()
    assertEqual(st.visible, NS.Constants.THANK.STACK, "3 on screen")
    assertEqual(st.waiting, 2, "2 queued behind them")
    assertNil(TH.pumpTimer, "nothing left to pump")
end)

test("autothank: [CA-M4-9] a toast names the caster and the buff, and starts the caster's cooldown", function()
    local NS, m, TH = hosting()
    local key = offer(NS, m, 1)
    local f = TH.toast:FrameFor(key)
    assertTrue(f ~= nil, "on screen under its key")
    assertEqual(f.qcText:GetText(), NS.L["%s buffed you with %s"]:format("Caster1", "Arcane Intellect"))
    offer(NS, m, 1)                                       -- the same caster recasts it
    assertEqual(TH.toast:Stats().visible, 1, "inside the cooldown, no second toast")
end)

test("autothank: [CA-M4-9] maxQueue drops the oldest waiting toast", function()
    local NS, m, TH, shows = hosting()
    local keys = {}
    for n = 1, 9 do keys[n] = offer(NS, m, n) end
    while pumpAfter(m, TH, NS.Constants.THANK.GAP) do end
    assertEqual(#shows, 9, "every one reached the toast")
    local st = TH.toast:Stats()
    assertEqual(st.visible, 3)
    assertEqual(st.waiting, NS.Constants.THANK.MAX_QUEUE)
    assertEqual(st.keys[1], keys[5], "the oldest waiting (the 4th) was dropped")
end)

test("autothank: [CA-M4-9] no Show in lockdown: the host holds the payload and the pump waits", function()
    local _, m, TH, shows = hosting()
    m.inCombat = true
    TH.Offer({ key = "k1", caster = { guid = "Player-2-1", name = "A" }, aura = { spellId = 1, name = "x" } })
    assertEqual(#shows, 0, "red under: a host Show not gated on lockdown")
    assertEqual(#TH.pending, 1, "held in the host's own list")
    TH.Pump()
    assertEqual(#shows, 0, "the pump is gated too")
    m.inCombat = false
    TH.Pump()
    assertEqual(#shows, 1, "out of combat it shows")
end)

test("autothank: [CA-M4-9] the stand-down clears the toast, the host's list and its pump", function()
    local NS, m, TH, shows = hosting()
    for n = 1, 4 do offer(NS, m, n) end
    assertTrue(TH.pumpTimer ~= nil)
    NS.addon:OnSlashCommand("disable")
    assertEqual(TH.toast:Stats().visible, 0, "nothing on screen")
    assertEqual(#TH.pending, 0, "nothing held")
    assertNil(TH.pumpTimer, "no pump armed")
    TH.Offer({ key = "k", caster = { guid = "Player-2-1", name = "A" }, aura = { spellId = 1, name = "x" } })
    assertEqual(#shows, 1, "stood down, nothing more is shown")
end)

-- ── the toast's combat Hold and Release (CA-M4-10, spec §9 The toast, F4c) ──────────────────────

-- hosting(), with every Hold, Release, Pause and Show the toast is asked for logged in order.
local function holding()
    local NS, m, TH, shows = hosting()
    local log = {}
    for _, name in ipairs({ "Hold", "Release", "Pause", "Show" }) do
        local real = TH.toast[name]
        TH.toast[name] = function(self, a, ...)
            log[#log + 1] = { name, a }
            return real(self, a, ...)
        end
    end
    local function calls(name)
        local n = {}
        for _, e in ipairs(log) do if e[1] == name then n[#n + 1] = e end end
        return n
    end
    return NS, m, TH, shows, log, calls
end

local function firstOf(log, name)
    for i, e in ipairs(log) do if e[1] == name then return i end end
    return nil
end

test("autothank: [CA-M4-10] the combat edge holds the toast with no keepShown, while lockdown still reads false", function()
    local NS, m, TH, _, _, calls = holding()
    offer(NS, m, 1)
    assertEqual(TH.toast:Stats().visible, 1, "one up before the fight")
    edgeOn(m)
    assertFalse(m.InCombatLockdown(), "the edge is still writable")
    -- red under: no RESTRICTION_CHANGED receiver in the host
    assertEqual(#calls("Hold"), 1)
    assertNil(calls("Hold")[1][2], "no keepShown: every toast on screen goes back to the queue")
    local st = TH.toast:Stats()
    assertEqual(st.visible, 0, "nothing on screen in combat")
    assertTrue(st.held)
    assertEqual(st.waiting, 1, "it waits with its full time")
end)

test("autothank: [CA-M4-10] nothing releases the toast at the start of combat", function()
    local NS, m, TH, _, _, calls = holding()
    edgeOn(m)
    NS.SendEngine.Drain("test")                         -- the edge's own drain
    m.__setCombat(true)
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "combat", true)
    assertEqual(#calls("Release"), 0)
    assertTrue(TH.toast:Stats().held)
end)

test("autothank: [CA-M4-10] the end of combat releases the toast before the diff's own shows", function()
    local NS, m, TH, _, log, calls = holding()
    edgeOn(m)
    m.__setCombat(true)
    local guid = stranger(m, 1)
    NS.AutoThank.OnAura("player", m.secretAuraUpdate{ addedAuras = { m.addAura{ casterGUID = guid, spellId = 1459 } } })
    assertEqual(#calls("Show"), 0, "nothing shows in combat")
    fightOver(m)
    local released, shown = firstOf(log, "Release"), firstOf(log, "Show")
    assertTrue(released ~= nil, "released at the end of combat")
    assertTrue(shown ~= nil, "the diff's toast shows")
    assertTrue(released < shown, "Release before the diff's Show")
    assertFalse(TH.toast:Stats().held)
    assertEqual(TH.toast:Stats().visible, 1, "on screen after the fight")
end)

test("autothank: [CA-M4-10] a /reload in combat with no RESTRICTION_CHANGED is released by the combat-end hook", function()
    local NS, m, TH, _, log = holding()
    TH.toast:Hold()                                     -- held, as the edge before the reload left it
    NS.State.combatEdge = nil
    m.__setCombat(true)
    local guid = stranger(m, 1)
    NS.AutoThank.OnAura("player", m.auraUpdate{ addedAuras = { m.addAura{ casterGUID = guid, spellId = 1459 } } })
    NS.Restrictions.Refresh = function() return false end   -- the edge announces nothing
    fightOver(m)
    local released, shown
    for i, e in ipairs(log) do
        if e[1] == "Release" and not released then released = i end
        if e[1] == "Show" and not shown then shown = i end
    end
    -- red under: AT.OnCombatEnd that diffs without releasing
    assertTrue(released ~= nil and shown ~= nil and released < shown, "Release, then the diff's Show")
    assertEqual(TH.toast:Stats().visible, 1)
end)

test("autothank: [CA-M4-10] what the host held through combat is pumped after the release", function()
    local _, m, TH, shows = holding()
    m.inCombat = true
    TH.Offer({ key = "k1", caster = { guid = "Player-2-1", name = "A" }, aura = { spellId = 1, name = "x" } })
    assertEqual(#shows, 0)
    fightOver(m)
    assertEqual(#shows, 1, "the held payload shows once the fight is over")
end)

test("autothank: [CA-M4-10] Hold(true) and Pause() are never called through a fight", function()
    local NS, m, _, _, _, calls = holding()
    offer(NS, m, 1)
    edgeOn(m)
    m.__setCombat(true)
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "combat", true)
    fightOver(m)
    for _, h in ipairs(calls("Hold")) do assertTrue(h[2] ~= true, "never Hold(true)") end
    assertEqual(#calls("Pause"), 0, "never Pause()")
end)

-- ── the fade (CA-M4-11, D26) ────────────────────────────────────────────────────────────────────

-- One toast up at m.__now = 1000, its frame, and a way to run its OnUpdate at `at`, `elapsed` after
-- the last run.
local function fading()
    local NS, m, TH = hosting()
    local key = offer(NS, m, 1)
    local f = TH.toast:FrameFor(key)
    local function tick(at, elapsed)
        m.__now = at
        f:__fire("OnUpdate", elapsed or 0)
    end
    return NS, m, TH, f, tick, key
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

test("autothank: [CA-M4-11] alpha is 1 until the last FADE seconds, then falls to 0", function()
    local NS, _, _, f, tick = fading()
    local due = 1000 + NS.Constants.THANK.DURATION
    local FADE = NS.Constants.THANK.FADE
    -- red under: no OnUpdate hooked on the frame
    assertTrue(f:GetScript("OnUpdate") ~= nil, "the fade is hooked")
    assertEqual(f:GetAlpha(), 1, "drawn at full alpha")
    tick(1003, 3)
    assertEqual(f:GetAlpha(), 1)
    tick(due - FADE, 1)
    assertEqual(f:GetAlpha(), 1, "the fade starts FADE seconds before the end")
    tick(due - FADE / 2, FADE / 2)
    assertTrue(near(f:GetAlpha(), 0.5), "half way through the fade")
    tick(due, FADE / 2)
    assertEqual(f:GetAlpha(), 0)
    tick(due + 1, 1)
    assertEqual(f:GetAlpha(), 0, "never below 0")
end)

test("autothank: [CA-M4-11] hover holds alpha at 1 and pushes the due time by what it held", function()
    local NS, _, _, f, tick = fading()
    local due = 1000 + NS.Constants.THANK.DURATION
    tick(due - 1.5, due - 1.5 - 1000)
    assertTrue(f:GetAlpha() < 1, "fading")
    f.__mouseOver = true
    tick(due - 1.5, 0)
    assertEqual(f:GetAlpha(), 1, "the pointer holds it")
    tick(due + 2.5, 4)                                  -- 4 s under the pointer
    assertEqual(f:GetAlpha(), 1)
    f.__mouseOver = false
    tick(due + 2.5, 0)
    assertTrue(near(f:GetAlpha(), 0.75), "1.5 s left of the pushed due time")
end)

test("autothank: [CA-M4-11] leaving with under a second left gives one second", function()
    local NS, _, _, f, tick = fading()
    local due = 1000 + NS.Constants.THANK.DURATION
    f.__mouseOver = true
    tick(due - 0.2, 0)
    f.__mouseOver = false
    tick(due - 0.2, 0)
    -- red under: a resume that keeps the 0.2 s left (alpha 0.1)
    assertTrue(near(f:GetAlpha(), 0.5), "one second of FADE's two")
    tick(due + 0.8, 1)
    assertEqual(f:GetAlpha(), 0)
end)

test("autothank: [CA-M4-11] OnUpdate is hooked once per frame, and a new draw starts at full alpha", function()
    local NS, m, TH, f, tick = fading()
    local hook = f:GetScript("OnUpdate")
    tick(1000 + NS.Constants.THANK.DURATION, 10)
    assertEqual(f:GetAlpha(), 0)
    TH.toast:Dismiss()
    m.__now = 2000
    local key = offer(NS, m, 2)
    local g = TH.toast:FrameFor(key)
    assertTrue(g == f, "the pool frame is re-used")
    assertTrue(g:GetScript("OnUpdate") == hook, "red under: a hook added on every draw")
    assertEqual(g:GetAlpha(), 1, "the new draw is at full alpha")
    tick(2005, 5)
    assertEqual(g:GetAlpha(), 1, "and its due time is its own")
end)

test("autothank: [CA-M4-11] the fade does nothing in combat", function()
    local NS, m, _, f, tick = fading()
    m.inCombat = true
    tick(1000 + NS.Constants.THANK.DURATION, 10)
    assertEqual(f:GetAlpha(), 1, "untouched in lockdown")
end)

test("autothank: [CA-M4-11] the library hides the toast at DURATION", function()
    local NS, m, TH, f = fading()
    local fired = false
    for i, t in ipairs(m.__timers) do
        if t.delay == NS.Constants.THANK.DURATION then
            table.remove(m.__timers, i)
            m.__now = 1000 + NS.Constants.THANK.DURATION
            t.fn()
            fired = true
            break
        end
    end
    assertTrue(fired, "the library's own countdown")
    assertFalse(f:IsShown(), "hidden at DURATION")
    assertEqual(TH.toast:Stats().visible, 0)
end)

test("autothank: [CA-M4-R1] a drag holds every toast's fade as the library holds its countdown", function()
    local NS, m, TH = hosting()
    local C = NS.Constants.THANK
    local k1 = offer(NS, m, 1)
    local k2 = offer(NS, m, 2)
    pumpAfter(m, TH, C.GAP)
    local head, follower = TH.toast:FrameFor(k1), TH.toast:FrameFor(k2)
    assertTrue(head ~= nil and follower ~= nil and head ~= follower, "two toasts up")
    local t0 = m.__now
    head:__fire("OnDragStart")
    m.__now = t0 + C.DURATION + 5
    follower:__fire("OnUpdate", C.DURATION + 5)
    head:__fire("OnUpdate", C.DURATION + 5)
    -- red under: a fade that holds only the frame under the pointer
    assertEqual(follower:GetAlpha(), 1, "the follower is held through the drag")
    assertEqual(head:GetAlpha(), 1, "and the head")
    head:__fire("OnDragStop")
    follower:__fire("OnUpdate", 0)
    assertTrue(follower:GetAlpha() > 0, "it fades from where the drag held it")
    m.__now = m.__now + C.DURATION
    follower:__fire("OnUpdate", C.DURATION)
    assertEqual(follower:GetAlpha(), 0, "and runs out after the drag")
end)

test("autothank: [CA-M4-R1] the stand-down forgets a drag in progress", function()
    local NS, m, TH = hosting()
    local f = TH.toast:FrameFor(offer(NS, m, 1))
    f:__fire("OnDragStart")
    NS.addon:OnSlashCommand("disable")
    assertNil(TH.dragging)
end)

-- ── the Thank button and its press (CA-M4-12, D4, spec §9 The Thank button) ─────────────────────

-- hosting(), with the client's THANK emote known, `send` set, and one stranger's toast up: its key,
-- its frame and the frame's Thank button.
local function thanking(send, over)
    local NS, m, TH, shows = hosting()
    m.EMOTE98_TOKEN, m.EMOTE98_CMD1 = "THANK", "/thank"
    NS.Emotes.Reset()
    NS.db.profile.thank.send = send or "emote"
    for k, v in pairs(over or {}) do NS.db.profile.thank[k] = v end
    local key = offer(NS, m, 1)
    local f = TH.toast:FrameFor(key)
    return NS, m, TH, key, f, f and f.qcThank, shows
end

local function results(NS)
    local got = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.SEND_RESULT, function(_, id, surface, what)
        got[#got + 1] = { id = id, surface = surface, what = what }
    end)
    return got
end

-- A CHAT_MSG_* as the client sends it: text, sender, then nine fields, then the sender's GUID.
local function echo(m, event, sender, guid)
    m.__fire(event, "never read", sender or "Testchar-Testrealm", "", "", "", "", 0, 0, "", 0, 1, guid or m.playerGUID)
end

local function whisperName(NS) return NS.Compat.WhisperName("Caster1", "Argent Dawn") end

test("autothank: [CA-M4-12] the Thank click runs the macro of each mode", function()
    for _, send in ipairs({ "emote", "line", "both" }) do
        local NS, m, _, _, _, b = thanking(send)
        assertTrue(b ~= nil, send .. ": the toast carries a Thank button")
        m.__click(b)
        assertEqual(#m.sentMacros, 1, send)
        local lines = m.sentLines()
        local emote = "/thank " .. whisperName(NS)
        local whisper = "/w " .. whisperName(NS) .. " Thanks for the Arcane Intellect, Caster1!"
        if send == "emote" then assertEqual(table.concat(lines, "|"), emote) end
        if send == "line" then assertEqual(table.concat(lines, "|"), whisper) end
        if send == "both" then assertEqual(table.concat(lines, "|"), emote .. "|" .. whisper) end
    end
end)

test("autothank: [CA-M4-12] a right-click never runs the macro", function()
    local _, m, _, _, _, b = thanking("emote")
    assertTrue(b.qcLeftOnly)
    m.__click(b, "RightButton")
    assertEqual(#m.sentMacros, 0)
end)

test("autothank: [CA-M4-12] a Thank click stamps no guard, so the next pad press is not guarded", function()
    local NS, m, _, _, _, b = thanking("emote")
    local got = results(NS)
    m.__click(b)
    assertNil(NS.State.lastSendAt, "red under: a Thank press through G.Decide")
    for _, r in ipairs(got) do assertTrue(r.what ~= "guarded") end
end)

test("autothank: [CA-M4-12] its result carries the toast key on the thank surface and touches no pad or dial", function()
    local NS, m, _, key, _, b = thanking("emote")
    local got = results(NS)
    m.__click(b)
    echo(m, "CHAT_MSG_TEXT_EMOTE")
    assertEqual(#got, 1)
    assertEqual(got[1].id, key)
    assertEqual(got[1].surface, "thank")
    assertEqual(got[1].what, "sent")
    assertNil(next(NS.State.padFlashTimers or {}), "no pad button flashed")
    assertNil(next(NS.State.dialFlashTimers or {}), "no dial wedge flashed")
end)

test("autothank: [CA-M4-12] the whisper under chat lockdown prints its note and awaits no echo", function()
    local NS, m, _, _, _, b = thanking("line")
    m.chatLockdown = true
    local lines = {}
    local print0 = NS.Print
    NS.Print = function(s) lines[#lines + 1] = s end
    m.__click(b)
    NS.Print = print0
    assertEqual(#m.sentMacros, 1, "the click is never canceled")
    assertEqual(NS.SendEngine.EchoState().pending, 0, "no echo awaited")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find(NS.L["Thank"], 1, true) == 1, "named the Thank press")
end)

test("autothank: [CA-M4-12] both records two pending entries and gives one result", function()
    local NS, m, _, _, _, b = thanking("both")
    local got = results(NS)
    m.__click(b)
    assertEqual(NS.SendEngine.EchoState().pending, 2)
    echo(m, "CHAT_MSG_TEXT_EMOTE")
    assertEqual(#got, 0, "one of two")
    -- the whisper's echo names the recipient as its sender: it is ours all the same
    echo(m, "CHAT_MSG_WHISPER_INFORM", "Caster1-ArgentDawn", "Player-2-00000101")
    assertEqual(#got, 1, "red under: no CHAT_MSG_WHISPER_INFORM echo, or one read as someone else's")
    assertEqual(got[1].what, "sent")
end)

test("autothank: [CA-M4-12] an empty thank-you text leaves the whisper unarmed, and the toast says why", function()
    local NS, m, _, _, f, b = thanking("line", { text = "   " })
    assertFalse(b.qcArmed, "nothing to send")
    assertEqual(f.qcNote:GetText(), NS.L["Nothing to whisper: the thank-you text is empty."])
    m.__click(b)
    assertEqual(#m.sentMacros, 0)
    local NS2, m2, _, _, f2, b2 = thanking("both", { text = "" })
    assertTrue(b2.qcArmed, "both keeps the emote")
    m2.__click(b2)
    assertEqual(table.concat(m2.sentLines(), "|"), "/thank " .. whisperName(NS2))
    assertEqual(f2.qcNote:GetText() or "", "")
end)

test("autothank: [CA-M4-12] Attach is called once per pool frame across reuses", function()
    local NS, m, TH = hosting()
    local attached = {}
    local attach = TH.toast.Attach
    TH.toast.Attach = function(self, w) attached[#attached + 1] = w; return attach(self, w) end
    local key = offer(NS, m, 1)
    local f = TH.toast:FrameFor(key)
    local b = f.qcThank
    TH.toast:Dismiss()
    m.__now = m.__now + 10
    local key2 = offer(NS, m, 2)
    assertTrue(TH.toast:FrameFor(key2) == f, "the pool frame is re-used")
    assertTrue(f.qcThank == b, "its button is made once")
    assertEqual(#attached, 1, "red under: Attach on every draw")
end)

test("autothank: [CA-M4-12] a click removes its toast through SE.RunOrQueue", function()
    local NS, m, TH, key, _, b = thanking("emote")
    local queued = {}
    local roq = NS.SendEngine.RunOrQueue
    NS.SendEngine.RunOrQueue = function(k, fn) queued[#queued + 1] = k; return roq(k, fn) end
    m.__click(b)
    assertEqual(#queued, 1, "through SE.RunOrQueue")
    assertNil(TH.toast:FrameFor(key), "the toast is gone")
end)

test("autothank: [CA-M4-12] #19: a stranger's UNIT_AURA gives exactly one toast, naming the caster and the buff", function()
    local NS, m, TH, shows = hosting()
    local guid = stranger(m, 1)
    local a = m.addAura{ casterGUID = guid, spellId = 1459 }
    TH.toast:Clear()
    NS.AutoThank.frame:GetScript("OnEvent")(NS.AutoThank.frame, "UNIT_AURA", "player",
        m.auraUpdate{ addedAuras = { a } })
    assertEqual(#shows, 1)
    local f = TH.toast:FrameFor(guid .. ":1459")
    assertEqual(f.qcText:GetText(), NS.L["%s buffed you with %s"]:format("Caster1", "Arcane Intellect"))
end)
