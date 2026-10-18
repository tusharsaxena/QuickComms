-- tests/test_share.lua — modules/Share.lua's codec and checks (spec §15, §8.3): the string's shape,
-- decoding what a player actually pastes, the version gate, the schema checks, the sanitizer over every
-- text field and the import report. Pure: no frame is touched. Library.Import is tested in
-- tests/test_library.lua (here only for the one-owner rule: a callout travels inside its group), the
-- page in tests/test_page_share.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function boot()
    local NS = T.bootAddon()
    return NS, NS.Share
end

local function bundle(t)
    t.v = t.v or 1
    t.addon = t.addon or "QuickComms"
    t.kind = t.kind or "bundle"
    return t
end

-- "kind:id:reason" for each refused member, in order.
local function refusals(res)
    local out = {}
    for _, r in ipairs(res.refused) do out[#out + 1] = r.kind .. ":" .. r.id .. ":" .. r.reason end
    return table.concat(out, ",")
end

local KICK = { name = "Kick", text = "Kick on me {rt8}", channel = "party" }

test("share: a string is !QC1! then printable text, and decodes back to the same payload", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ callouts = { c1 = KICK } }))
    assertEqual(s:sub(1, 5), "!QC1!")
    assertTrue(s:find("[%s|]") == nil, "no whitespace and no escape character")
    local back = SH.Decode(s)
    assertEqual(back.callouts.c1.text, "Kick on me {rt8}")
    assertEqual(back.v, 1)
    assertEqual(back.addon, "QuickComms")
end)

test("share: [review 1] a pasted string may wrap and carry spaces; a cut-short one is damaged and imports nothing", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ groups = { g1 = { name = "Mine", callouts = {} } } }))
    local wrapped = "  " .. s:sub(1, 20) .. "\r\n" .. s:sub(21, 40) .. " \n\t" .. s:sub(41) .. "\n"
    assertEqual(SH.Decode(wrapped).groups.g1.name, "Mine")
    local payload, why = SH.Decode(s:sub(1, #s - 12))
    assertNil(payload)
    assertEqual(why, "damaged")
    local res = SH.Check(s:sub(1, #s - 12))
    assertFalse(res.ok)
    assertEqual(#res.callouts + #res.groups + #res.pads + #res.dials, 0)
    assertEqual(SH.ReportLines(res)[1], "That string is damaged or cut short. Copy all of it again.")
end)

test("share: a string that is not ours, is empty, is garbage after the prefix or is too large is refused", function()
    local _, SH = boot()
    assertEqual(select(2, SH.Decode("hello there")), "notOurs")
    assertEqual(select(2, SH.Decode("   \n ")), "empty")
    assertEqual(select(2, SH.Decode(nil)), "empty")
    assertEqual(select(2, SH.Decode("!QC1!@@@@")), "damaged")
    assertEqual(select(2, SH.Decode("!QC1!" .. string.rep("a", SH.MAX_STRING))), "tooLarge")
    -- another addon's payload in our wrapper
    local other = SH.Encode({ v = 1, addon = "WeakAuras", kind = "bundle" })
    assertEqual(SH.Check(other).reason, "notOurs")
end)

test("share: a newer version is refused with a line to update; a damaged version is refused", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({ v = 2, callouts = { c1 = KICK } }))
    assertFalse(res.ok)
    assertEqual(res.reason, "newer")
    assertEqual(SH.ReportLines(res)[1], "That string was made by a newer Quick Comms. Update the addon, then import it.")
    assertEqual(SH.Validate(bundle({ v = 0 })).reason, "damaged")
    assertEqual(SH.Validate(bundle({ v = 1.5 })).reason, "damaged")
    assertEqual(SH.Validate(bundle({ callouts = "nope" })).reason, "damaged")
end)

test("share: [review 2] a command or control characters never survive: / is refused, lines are flattened", function()
    local NS, SH = boot()
    local res = SH.Validate(bundle({ callouts = {
        c1 = { name = "Run", text = "  /run print(1)", channel = "party" },
        c2 = { name = "Two\nlines", text = "Kick\r\n/script x\tnow", channel = "say" },
        c3 = { name = "Pipe", text = "a|cffff0000red", channel = "party" },
        c4 = { name = "Long", text = string.rep("x", 256), channel = "party" },
    }, groups = { g1 = { name = "Holds them", callouts = { "c1", "c2", "c3", "c4" } } } }))
    assertTrue(res.ok)
    assertEqual(refusals(res), "callout:c1:startsWithSlash,callout:c4:tooLong")
    assertEqual(res.callouts[1].fields.name, "Two lines")
    assertEqual(res.callouts[1].fields.text, "Kick /script x now", "one line, the slash no longer first")
    assertEqual(res.callouts[2].fields.text, "a|cffff0000red", "stored unescaped; Bake escapes it once")
    -- red under: store B.Sanitize's escaped text instead of B.CleanText's (the bake escapes it twice)
    assertEqual(NS.Bake.Bake(res.callouts[2].fields, { group = "party", lockdown = {} }), "/p a||cffff0000red")
end)

test("share: ids, channels, names, icons and Whens are checked against the schema", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({
        callouts = {
            x9 = KICK,
            c2 = { name = "Guild", text = "hi", channel = "guild" },
            c3 = { name = string.rep("n", 33), text = "hi", channel = "party" },
            c4 = { name = "Icon", text = "hi", channel = "party", icon = -3 },
            c5 = { name = "Fine", text = "hi", channel = "smartGroup", icon = 136012 },
            c6 = { name = "Empty", channel = "party" },
        },
        groups = {
            g1 = { name = "Bad When", when = { content = { moon = true } } },
            g2 = { name = "Good", when = { content = { mythicPlus = true } }, callouts = { "c5", "c2", "bi.mplus.lust", "c5", "c6" } },
        },
    }))
    assertEqual(refusals(res), "callout:c2:badChannel,callout:c3:badName,callout:c4:badIcon,callout:x9:badId,group:g1:badWhen")
    assertEqual(#res.callouts, 2)
    assertEqual(res.callouts[1].fields.icon, 136012)
    assertEqual(res.callouts[2].fields.text, "", "a callout may have no text yet")
    assertEqual(table.concat(res.groups[1].callouts, ","), "c5,c6", "refused, shipped and repeated references are left out")
    assertEqual(res.dropped, 2)
    assertTrue(res.groups[1].fields.when.content.mythicPlus)
end)

test("share: a pad keeps the shared groups, and only the fields that travel; a shipped id is a dropped reference", function()
    local NS, SH = boot()
    local res = SH.Validate(bundle({
        groups = { g1 = { name = "Mine" } },
        pads = { p4 = { name = "Theirs", enabled = false, groups = { "g1", "bi.mplus", "bi.bg.ab.stables", "bi.gone", "g9" },
            fields = { ["pad.layout.columns"] = 6, ["pad.point"] = { "CENTER", "CENTER", 10, 10 },
                ["pad.name"] = "x", ["pad.nope"] = 1, ["dial.mode"] = "flat" } } },
        dials = { d5 = { name = "Their dial", groups = { "bi.bg.ab" },
            fields = { ["dial.key"] = "G", ["dial.mode"] = "flat", ["dial.point"] = { "CENTER", "CENTER", 0, 0 } } } },
    }))
    assertTrue(res.ok)
    local pad = res.pads[1]
    assertEqual(pad.name, "Theirs")
    assertFalse(pad.enabled)
    -- red under: keep a top-level shipped id on an imported surface, as built-in sets were
    assertEqual(table.concat(pad.groups, ","), "g1", "a shipped id (a set, a node, a stale one) is left out")
    assertEqual(pad.fields["pad.layout.columns"], 6)
    assertNil(pad.fields["pad.point"], "a position never travels")
    assertNil(pad.fields["pad.name"])
    local dial = res.dials[1]
    assertNil(dial.fields["dial.key"], "a key never travels")
    assertNil(dial.fields["dial.point"])
    assertEqual(dial.fields["dial.mode"], "flat")
    assertEqual(res.ignored, 6)
    assertEqual(res.dropped, 5)
    assertTrue(NS.Share.Portable("pad", "pad.look.visibility"))
    assertFalse(NS.Share.Portable("pad", "dial.mode"))
end)

test("share: the report counts what arrives, then names each member left out and why", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({
        callouts = { c1 = KICK, c2 = { name = "Sneaky", text = "/run print(1)", channel = "party" } },
        groups = { g1 = { name = "Smoke test", callouts = { "c1", "c2" } } },
    }))
    local lines = SH.ReportLines(res)
    assertEqual(lines[1], "Ready to import: 1 callout, 1 group.")
    assertEqual(lines[2], "Left out the callout 'Sneaky': its text starts with /.")
    assertEqual(lines[3], "1 reference to something the string does not carry was left out.")
    assertEqual(SH.CountText({ callouts = 3, groups = 0, pads = 2, dials = 1 }), "3 callouts, 2 pads, 1 dial")
    assertEqual(SH.ReportLines(SH.Validate(bundle({})))[1], "Nothing in this string can be imported.")
end)

test("share: more members than one string may carry is refused before any is checked", function()
    local _, SH = boot()
    local callouts = {}
    for i = 1, SH.MAX_MEMBERS + 1 do callouts["c" .. i] = KICK end
    assertEqual(SH.Validate(bundle({ callouts = callouts })).reason, "tooLarge")
end)

test("share: [review 1] a hand-made string with a NaN reference, a cyclic field or an infinite icon raises nothing", function()
    local _, SH = boot()
    local loop = { 1, 2 }
    loop.self = loop
    local s = SH.Encode(bundle({
        callouts = { c1 = KICK, c2 = { name = "Inf", text = "hi", channel = "party", icon = math.huge } },
        groups = { g1 = { name = "Odd refs", callouts = { 0 / 0, "c1", 7 } },
            g2 = { name = "Loop When", when = loop } },
        pads = { p1 = { name = "Loop", groups = { "g1" }, fields = { ["pad.layout.columns"] = loop,
            ["pad.layout.rows"] = 0 / 0 } } },
    }))
    -- red under: drop the type(ref) check from keepRefs in modules/Share.lua ("table index is NaN")
    local res = SH.Check(s)
    assertTrue(res.ok)
    assertEqual(refusals(res), "callout:c2:badIcon,group:g2:badWhen")
    assertEqual(table.concat(res.groups[1].callouts, ","), "c1", "the NaN and the number are dropped references")
    assertEqual(res.dropped, 2)
    assertNil(res.pads[1].fields["pad.layout.columns"], "a cyclic value is left out, never walked forever")
    assertNil(res.pads[1].fields["pad.layout.rows"], "a NaN value is left out")
    assertEqual(res.ignored, 2)
end)

test("share: [review 1] a payload that still raises inside the checks is damaged, never an error", function()
    local NS, SH = boot()
    local s = SH.Encode(bundle({ callouts = { c1 = KICK } }))
    NS.Library.ValidName = function() error("boom") end
    -- red under: call SH.Validate outside the pcall in SH.Check
    local res = SH.Check(s)
    assertFalse(res.ok)
    assertEqual(res.reason, "damaged")
end)

test("share: [review 2] a surface's string fields pass the sanitizer; an empty string is kept for the seam to judge", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({ dials = { d1 = { name = "Mine",
        fields = { ["dial.mode"] = "  flat\n", ["dial.openAt"] = "" } } } }))
    local f = res.dials[1].fields
    assertEqual(f["dial.mode"], "flat")
    assertEqual(f["dial.openAt"], "", "kept: the seam refuses it at write, as it would a player's")
    assertEqual(res.ignored, 0)
    local run = SH.Validate(bundle({ dials = { d1 = { name = "Mine", fields = { ["dial.mode"] = "/run x" } } } }))
    assertNil(run.dials[1].fields["dial.mode"])
    assertEqual(run.ignored, 1)
end)

test("share: SHARE-3's and SHARE-4's strings (docs/smoke-tests.md) read as the checks say", function()
    local _, SH = boot()
    -- the strings the owner pastes in game: a refused /run callout, then a newer version
    local share3 = "!QC1!v4CVUjmmuuaybLPIufQdD2kdOwwqHbeZgPYatnrIz8pxLef7RJSVUuuvx6JsEIS4jcZ6rF6CotojB8U4q4TIMYp)xjmgxKcRkuLfQnEafsdOpZrHfgRTUEGrqG4xAb85kHw7WXVIDQ(9oRnW77qTugrTbstxMlzlNGFOHfhZeMdzwG9RN29xAg)rKx1kqemJbRWthE8K8SBtZVT2hr2GVdP3l)intwJGO)A6LQHm86RF)09)"
    local share4 = "!QC1!JXWsk9IYV0ckMRGsmLuYpVffyPzMC2oNFU5wStzNzEPKusLMxk5KAtjNyo5KFPLumxcvgRa("
    assertEqual(table.concat(SH.ReportLines(SH.Check(share3)), " | "),
        "Ready to import: 1 callout, 1 group. | Left out the callout 'Sneaky': its text starts with /. | "
            .. "1 reference to something the string does not carry was left out.")
    assertEqual(table.concat(SH.ReportLines(SH.Check(share4)), " | "),
        "That string was made by a newer Quick Comms. Update the addon, then import it.")
end)

test("share: [review 1] a short string that inflates past MAX_RAW is damaged before it is read", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ callouts = { c1 = { name = "Big", text = string.rep("a", SH.MAX_RAW), channel = "party" } } }))
    assertTrue(#s < 5000, "a few thousand characters")
    -- red under: drop the #raw > SH.MAX_RAW check from decodeBody in modules/Share.lua
    assertEqual(select(2, SH.Decode(s)), "damaged")
end)

-- One table referenced `fanout` times per level, `depth` levels deep: a few bytes in a share string
-- (LibSerialize keeps shared references), fanout^depth nodes to a walk that follows every reference.
local function dag(fanout, depth)
    local node = { 1 }
    for _ = 1, depth do
        local parent = {}
        for j = 1, fanout do parent[j] = node end
        node = parent
    end
    return node
end

test("share: [fix 1] a shared-reference When or field is refused at once, never expanded", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ groups = { g1 = { name = "Fan", when = { zone = dag(30, 7) } } },
        pads = { p1 = { name = "Fan", fields = { ["pad.layout.columns"] = dag(30, 7) } } } }))
    assertTrue(#s < 1000, "a short string")
    local t0 = os.clock()
    -- red under: drop the seen set from cleanValue in modules/Share.lua (30^7 nodes; it never returns)
    local res = SH.Check(s)
    assertTrue(os.clock() - t0 < 1, "promptly")
    assertTrue(res.ok)
    assertEqual(refusals(res), "group:g1:badWhen")
    assertNil(res.pads[1].fields["pad.layout.columns"])
    assertEqual(res.ignored, 1)
end)

test("share: [fix 1] one table shared across many fields is bounded by MAX_NODES: the string is too large", function()
    local _, SH = boot()
    local big = {}
    for i = 1, 4000 do big[i] = i end
    local pads = {}
    for n = 1, 20 do
        pads["p" .. n] = { name = "Pad " .. n, fields = { ["pad.layout.columns"] = big, ["pad.layout.rows"] = big,
            ["pad.look.visibility"] = big } }
    end
    local s = SH.Encode(bundle({ pads = pads }))
    -- red under: drop the res.nodes budget from cleanValue in modules/Share.lua (240,000 values walked)
    local res = SH.Check(s)
    assertFalse(res.ok)
    assertEqual(res.reason, "tooLarge")
    assertEqual(SH.ReportLines(res)[1], "That string is too large to import.")
end)

test("share: [fix 2] one long string referenced 2000 times in a field is refused unread, promptly", function()
    local _, SH = boot()
    local long = string.rep("a", 200000)
    local refs = {}
    for i = 1, 2000 do refs[i] = long end
    local s = SH.Encode(bundle({ pads = { p1 = { name = "Long", fields = { ["pad.layout.columns"] = refs } } } }))
    assertTrue(#s < 2000, "a short string")
    local t0 = os.clock()
    -- red under: drop the #v > SH.TEXT_MAX check from affordable in modules/Share.lua (400 MB through gsub)
    local res = SH.Check(s)
    assertTrue(os.clock() - t0 < 1, "promptly")
    assertTrue(res.ok)
    assertNil(res.pads[1].fields["pad.layout.columns"])
    assertEqual(res.ignored, 1)
end)

test("share: [fix 2] a long name, text or icon is refused unread, promptly", function()
    local _, SH = boot()
    local long = string.rep("b", 200000)
    local callouts, groups = {}, {}
    for n = 1, 150 do
        callouts["c" .. n] = { name = long, text = "Hi", channel = "say" }
        callouts["c" .. (n + 150)] = { name = "Ok", text = long, channel = "say" }
        groups["g" .. n] = { name = "Ok", icon = long }
    end
    local s = SH.Encode(bundle({ callouts = callouts, groups = groups }))
    local t0 = os.clock()
    -- red under: drop the affordable pre-checks from cleanName, cleanText, cleanIcon and refuse in
    -- modules/Share.lua (each one sanitizes 200 KB per member)
    local res = SH.Check(s)
    assertTrue(os.clock() - t0 < 1, "promptly")
    assertTrue(res.ok)
    assertEqual(#res.refused, 450)
    local why = {}
    for _, r in ipairs(res.refused) do
        why[r.reason] = (why[r.reason] or 0) + 1
        assertTrue(#r.name < 10, "a refused member is named by its id, not its long name")
    end
    assertEqual(why.badName, 150)
    assertEqual(why.tooLong, 150)
    assertEqual(why.badIcon, 150)
end)

test("share: [fix 2] shared short strings past the payload's text budget make the string too large", function()
    local _, SH = boot()
    local line = string.rep("c", 250)
    local refs = {}
    for i = 1, 1000 do refs[i] = line end
    local pads = {}
    for n = 1, 20 do
        pads["p" .. n] = { name = "Pad " .. n, fields = { ["pad.layout.columns"] = refs, ["pad.layout.rows"] = refs,
            ["pad.look.visibility"] = refs } }
    end
    local s = SH.Encode(bundle({ pads = pads }))
    -- red under: drop the res.bytes budget from affordable in modules/Share.lua (15 MB sanitized)
    local res = SH.Check(s)
    assertFalse(res.ok)
    assertEqual(res.reason, "tooLarge")
end)

test("share: [review] a refused member's malformed id never reaches the report raw: no newline, no live escape", function()
    local _, SH = boot()
    local evil = "|TInterface\\Buttons\\WHITE8X8:4000:4000|t\nReady to import: 1 callout."
    local res = SH.Check(SH.Encode(bundle({ callouts = { c1 = KICK, [evil] = {} }, groups = { g1 = { name = "Mine", callouts = { "c1" } } } })))
    assertTrue(res.ok)
    local lines = SH.ReportLines(res)
    assertEqual(#lines, 2)
    -- red under: refuse() in modules/Share.lua labeling the member tostring(id)
    assertEqual(lines[2], "Left out the callout '(unnamed)': its id is malformed.")
    for _, line in ipairs(lines) do assertTrue(line:find("\n", 1, true) == nil, "one line each") end
    -- a plain short id is still named by itself
    local plain = SH.Validate(bundle({ callouts = { x9 = {} } }))
    assertEqual(SH.ReportLines(plain)[2], "Left out the callout 'x9': its id is malformed.")
end)

test("share: [review] a 200 KB malformed id gives a short report line", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ callouts = { [string.rep("k", 200000)] = {} } }))
    assertTrue(#s < SH.MAX_STRING, "it compresses into a pasteable string")
    local res = SH.Check(s)
    assertTrue(res.ok)
    local line = SH.ReportLines(res)[2]
    -- red under: refuse() in modules/Share.lua labeling the member tostring(id)
    assertTrue(#line < 100, "a short line, not " .. #line .. " bytes")
    assertTrue(#res.refused[1].id < 100, "the refusal's id is bounded too")
end)

test("share: [review] a name's live | escape is stored and reported as text (||), as a typed | is", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({
        callouts = { c1 = { name = "|T136243:999:999|t", text = "a|cffff0000red", channel = "party" },
            c2 = { name = "|cffff0000Bad|r", text = "/run x", channel = "party" },
            c3 = { name = "Typed||pipe", text = "hi", channel = "party" } },
        groups = { g1 = { name = "|cffff0000Kick|r", callouts = { "c1", "c3" } } },
        pads = { p1 = { name = "|Hitem:1|h[x]|h", fields = { ["pad.look.font"] = "|TFont:99|t" } } },
    }))
    assertTrue(res.ok)
    -- red under: cleanName in modules/Share.lua storing Bake.CleanText's answer as it is
    assertEqual(res.callouts[1].fields.name, "||T136243:999:999||t")
    assertEqual(res.callouts[1].fields.text, "a|cffff0000red", "text is still left to the bake's one escape")
    assertEqual(res.callouts[2].fields.name, "Typed||pipe", "an escaped pipe is kept as it is, never doubled again")
    assertEqual(res.groups[1].fields.name, "||cffff0000Kick||r")
    assertEqual(res.pads[1].name, "||Hitem:1||h[x]||h")
    assertEqual(res.pads[1].fields["pad.look.font"], "||TFont:99||t", "a field's string is display text too")
    -- the refused callout's name in the report
    assertEqual(SH.ReportLines(res)[2], "Left out the callout '||cffff0000Bad||r': its text starts with /.")
end)

test("share: [review] a name that starts with / is a name, never sent: it travels and round-trips", function()
    local NS, SH = boot()
    local res = SH.Check(SH.Encode(bundle({
        callouts = { c3 = { name = "/w healer", text = "hi", channel = "party" } },
        groups = { g4 = { name = "  /raid\tstuff ", callouts = { "c3" } } },
        pads = { p1 = { name = "/pad", groups = { "g4" } } },
    })))
    -- red under: cleanName in modules/Share.lua refusing CleanText's startsWithSlash
    assertEqual(refusals(res), "")
    assertEqual(res.callouts[1].fields.name, "/w healer")
    assertEqual(res.groups[1].fields.name, "/raid stuff", "flattened and trimmed like any name")
    assertEqual(res.pads[1].name, "/pad")
    assertEqual(table.concat(res.groups[1].callouts, ","), "c3")
    assertTrue(NS.Library.ValidName("/w healer"))
end)

test("share: [review] a nested key in a When or a field passes the sanitizer and the byte budget", function()
    local _, SH = boot()
    local res = SH.Check(SH.Encode(bundle({
        groups = { g1 = { name = "Evil key", when = { characters = { ["Ev\1il|T1:4000:4000|t-Realm"] = true } } },
            g2 = { name = "Long key", when = { characters = { [string.rep("a", 50) .. "-" .. string.rep("b", 50)] = true } } },
            g3 = { name = "Fine", when = { characters = { ["Kaos-Silvermoon"] = true } } } },
        pads = { p1 = { name = "Keys", fields = {
            ["pad.look.fontColor"] = { r = 1, g = 1, b = 1, ["x\1y"] = 1 },
            ["pad.look.borderColor"] = { r = 1, g = 1, b = 1, [string.rep("z", 300)] = 1 },
            ["pad.look.background"] = { r = 1, g = 1, b = 1, [math.huge] = 1 } } } },
    })))
    assertTrue(res.ok)
    -- red under: cleanValue in modules/Share.lua copying keys unchecked, or ValidWhenValue's old pattern
    assertEqual(refusals(res), "group:g1:badWhen,group:g2:badWhen")
    assertTrue(res.groups[1].fields.when.characters["Kaos-Silvermoon"])
    local f = res.pads[1].fields
    assertNil(f["pad.look.fontColor"], "a control character in a key")
    assertNil(f["pad.look.borderColor"], "a key past TEXT_MAX")
    assertNil(f["pad.look.background"], "a key that is not finite")
    assertEqual(res.ignored, 3)
end)

-- ── one owner per callout (2026-10-17-callouts-owned-by-groups-design.md) ──────────────────

test("share import: groups sharing a callout each get their own copy", function()
    local NS, SH = boot()
    local res = SH.Validate(bundle({ callouts = { c1 = KICK },
        groups = { g1 = { name = "One", callouts = { "c1" } }, g2 = { name = "Two", callouts = { "c1" } } } }))
    local tally, map = NS.Library.Import(res)
    local p = NS.db.profile
    local a, b = p.groups[map.g1].callouts[1], p.groups[map.g2].callouts[1]
    -- red under: importMembers pointing every group at the one imported callout
    assertTrue(a ~= nil and b ~= nil and a ~= b, "one copy per group")
    assertEqual(p.callouts[a].text, KICK.text)
    assertEqual(p.callouts[b].text, KICK.text)
    assertEqual(p.callouts[b].name, KICK.name, "the name kept")
    assertEqual(tally.callouts, 2)
end)

test("share import: the report counts a shared callout once per group, as the import makes it", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({ callouts = { c1 = KICK },
        groups = { g1 = { name = "One", callouts = { "c1" } }, g2 = { name = "Two", callouts = { "c1" } } } }))
    -- red under: ReportLines counting res.callouts (one per id) instead of the groups' references
    assertEqual(SH.ReportLines(res)[1], "Ready to import: 2 callouts, 2 groups.")
end)

test("share import: a callout in no imported group is not imported", function()
    local NS, SH = boot()
    local res = SH.Validate(bundle({ callouts = { c1 = KICK, c2 = { name = "Loose", text = "x", channel = "party" } },
        groups = { g1 = { name = "One", callouts = { "c1" } } } }))
    -- red under: drop the loose-callout pass from SH.Validate
    assertEqual(#res.callouts, 1)
    assertEqual(res.callouts[1].id, "c1")
    assertEqual(res.loose, 1)
    local lines = SH.ReportLines(res)
    assertEqual(lines[1], "Ready to import: 1 callout, 1 group.")
    assertEqual(lines[2], "1 callout in no group was left out.")
    assertEqual(SH.ReportLines(SH.Validate(bundle({ callouts = { c1 = KICK, c2 = KICK } })))[2],
        "2 callouts in no group were left out.")
    -- a hand-made result that slipped a loose callout past the checks still imports only the held one
    res.callouts[#res.callouts + 1] = { id = "c7", fields = { name = "Slipped", text = "x", channel = "party" } }
    local tally = NS.Library.Import(res)
    assertEqual(tally.callouts, 1)
    for _, c in pairs(NS.db.profile.callouts) do assertTrue(c.name ~= "Slipped" and c.name ~= "Loose") end
end)

test("share: Collect takes a callout only inside its group; a picked callout alone is nothing", function()
    local NS, SH = boot()
    local Lib = NS.Library
    local gid = Lib.CreateGroup({ name = "My keys" })
    local cid = Lib.CreateCalloutIn(gid, KICK)
    -- red under: closure in modules/Share.lua honoring pick.callout
    assertNil(SH.Collect({ callout = { [cid] = true } }), "a callout travels inside its group")
    local payload = SH.Collect({ callout = { [cid] = true }, group = { [gid] = true } })
    assertEqual(payload.groups[gid].callouts[1], cid)
    assertEqual(payload.callouts[cid].text, KICK.text)
    assertEqual(SH.REASON_TEXT.nothing, "Tick at least one group, pad or dial to export.")
end)

-- ── a glyph's color (icon browser spec, "Data model") ───────────────────────────────────────

test("share: [icons] a glyph's color travels; an old string arrives untinted; a bad color is dropped and counted", function()
    local NS, SH = boot()
    local star = NS.Icon("star")
    local res = SH.Validate(bundle({
        callouts = {
            c1 = { name = "Red", text = "a", channel = "say", icon = star, iconColor = "#FF0000" },
            c2 = { name = "Old", text = "b", channel = "say", icon = star },
            c3 = { name = "Bad", text = "c", channel = "say", icon = star, iconColor = "crimson" },
            c4 = { name = "Huge", text = "d", channel = "say", icon = star, iconColor = string.rep("f", 300) },
        },
        groups = { g1 = { name = "G", icon = star, iconColor = { 1, 0, 0 }, callouts = { "c1", "c2", "c3", "c4" } } },
    }))
    assertEqual(refusals(res), "", "a bad color is a bad field, not a bad member")
    local by = {}
    for _, e in ipairs(res.callouts) do by[e.id] = e.fields end
    -- red under: calloutEntry without iconColor
    assertEqual(by.c1.iconColor, "ff0000")
    assertNil(by.c2.iconColor)
    assertNil(by.c3.iconColor)
    assertNil(by.c4.iconColor)
    assertNil(res.groups[1].fields.iconColor)
    -- red under: cleanIconColor dropping a bad color without counting it
    assertEqual(res.ignored, 3)
end)

test("share: [icons] an export carries each member's color, and the string round-trips it", function()
    local NS, SH = boot()
    local Lib, star = NS.Library, NS.Icon("star")
    local gid = Lib.CreateGroup({ name = "G", icon = star, iconColor = "00ff00" })
    local cid = Lib.CreateCalloutIn(gid, { name = "A", text = "a", channel = "say", icon = star, iconColor = "ff0000" })
    local plain = Lib.CreateCalloutIn(gid, KICK)
    local payload = SH.Collect({ group = { [gid] = true } })
    -- red under: exportMember without iconColor
    assertEqual(payload.groups[gid].iconColor, "00ff00")
    assertEqual(payload.callouts[cid].iconColor, "ff0000")
    assertNil(payload.callouts[plain].iconColor)
    local back = SH.Validate(SH.Decode(SH.Encode(payload)))
    assertEqual(back.groups[1].fields.iconColor, "00ff00")
end)

-- ── nested groups (2026-10-18-builtins-as-groups-design.md, goal 2) ──────────────────────────

test("share: [nesting] a picked parent brings its children, and the import nests them under the new copy", function()
    local NS, SH = boot()
    local Lib = NS.Library
    local parent = Lib.CreateGroup({ name = "Raid night" })
    local child = Lib.CreateGroup({ name = "Boss 1" })
    Lib.CreateCalloutIn(child, KICK)
    NS.SchemaRuntime.Set("group.parent", parent, child)
    -- red under: closure in modules/Share.lua not bringing a picked group's children
    local payload = SH.Collect({ group = { [parent] = true } })
    assertTrue(payload.groups[child] ~= nil, "the child travels with its parent")
    assertEqual(payload.groups[child].parent, parent)
    assertNil(payload.groups[parent].parent)
    local res = SH.Validate(payload)
    local tally, map = Lib.Import(res)
    assertEqual(tally.groups, 2)
    local p = NS.db.profile
    -- red under: Library.Import not setting the parent on the fresh copies
    assertEqual(p.groups[map[child]].parent, map[parent], "remapped to the new parent")
    assertTrue(map[parent] ~= parent)
end)

test("share: [nesting] a parent the string does not carry, itself, or one inside another is dropped and counted", function()
    local NS, SH = boot()
    local res = SH.Validate(bundle({ groups = {
        g1 = { name = "Deep", parent = "g2" }, g2 = { name = "Mid", parent = "g3" }, g3 = { name = "Top" },
        g4 = { name = "Self", parent = "g4" }, g5 = { name = "Lost", parent = "g99" }, g6 = { name = "Odd", parent = 7 },
    } }))
    assertTrue(res.ok)
    local parents = {}
    for _, e in ipairs(res.groups) do parents[e.id] = e.parent or "-" end
    -- red under: groupEntry passing `parent` through unchecked
    assertEqual(parents.g2, "g3", "a top-level parent the string carries is kept")
    assertEqual(parents.g1, "-", "g2 is inside g3: one level only")
    assertEqual(parents.g4, "-")
    assertEqual(parents.g5, "-")
    assertEqual(parents.g6, "-")
    assertEqual(res.dropped, 4)
    local _, map = NS.Library.Import(res)
    local p = NS.db.profile
    assertEqual(p.groups[map.g2].parent, map.g3)
    assertNil(p.groups[map.g1].parent)
end)
