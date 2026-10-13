-- tests/test_share.lua — modules/Share.lua's codec and checks (spec §15, §8.3): the string's shape,
-- decoding what a player actually pastes, the version gate, the schema checks, the sanitizer over every
-- text field and the import report. Pure: no frame is touched. Library.Import is tested in
-- tests/test_library.lua, the page in tests/test_page_share.lua.

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
    } }))
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
            g2 = { name = "Good", when = { content = { mythicPlus = true } }, callouts = { "c5", "c2", "bi.mplus.lust", "c5" } },
        },
    }))
    assertEqual(refusals(res), "callout:c2:badChannel,callout:c3:badName,callout:c4:badIcon,callout:x9:badId,group:g1:badWhen")
    assertEqual(#res.callouts, 2)
    assertEqual(res.callouts[1].fields.icon, 136012)
    assertEqual(res.callouts[2].fields.text, "", "a callout may have no text yet")
    assertEqual(table.concat(res.groups[1].callouts, ","), "c5", "refused, built-in and repeated references are left out")
    assertEqual(res.dropped, 2)
    assertTrue(res.groups[1].fields.when.content.mythicPlus)
end)

test("share: a pad keeps the shared groups and the built-in sets, and only the fields that travel", function()
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
    assertEqual(table.concat(pad.groups, ","), "g1,bi.mplus", "a node is not a top-level set; an unknown set is left out")
    assertEqual(pad.fields["pad.layout.columns"], 6)
    assertNil(pad.fields["pad.point"], "a position never travels")
    assertNil(pad.fields["pad.name"])
    local dial = res.dials[1]
    assertNil(dial.fields["dial.key"], "a key never travels")
    assertNil(dial.fields["dial.point"])
    assertEqual(dial.fields["dial.mode"], "flat")
    assertEqual(res.ignored, 6)
    assertEqual(res.dropped, 3)
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
