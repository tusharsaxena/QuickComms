-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; QC-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row after `config` runs NS.RunSkinVerb, which hands O.SkinVerb the first-run spec, so
-- `/qc skin` shows the picker a new profile shows whatever skin.pickerSeen says. Refused while the
-- addon is disabled (the dispatcher's gate), a gray line on every call in combat (the library's),
-- and the library-absent line without LibKa0s. Modeled on LibKa0sSkinTester's tests/test_skin_verb.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

local function run(NS, m, input)
    local mark = #m.prints
    NS.addon:OnSlashCommand(input)
    local out = {}
    for i = mark + 1, #m.prints do out[#out + 1] = m.prints[i] end
    return out
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do if tostring(l):find(fragment, 1, true) then return true end end
    return false
end

local function strings(m) return m.LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

--- Logged in, the first-run picker closed, so only the verb can bring it back. The Options
--- instance's SkinVerb is wrapped so a case can read the frame it answered.
local function seenProfile()
    local NS, _, m = T.enableAddon()
    m.prints = m.prints or {}
    NS.HideSkinPicker()
    NS.SchemaRuntime.Set("skin.pickerSeen", true)
    local H = NS.addon.Settings.Helpers
    local live, last = H.SkinVerb, {}
    H.SkinVerb = function(spec)
        local win, why = live(spec)
        last.win, last.why, last.spec = win, why, spec
        return win, why
    end
    return NS, m, last
end

test("skin verb: the row sits right after config, with the library's help words", function()
    local NS, _, m = T.newAddon()
    local at
    for i, c in ipairs(NS.COMMANDS) do
        if c[1] == "skin" then at = i end
    end
    assertTrue(at ~= nil, "a skin row")
    assertEqual(NS.COMMANDS[at - 1][1], "config", "after config")
    assertEqual(NS.COMMANDS[at][2], strings(m).VERB_HELP, "one wording for every host")
end)

test("skin verb: /qc skin shows the picker on a profile that has closed it", function()
    -- red under: no skin row (the dispatcher answers "unknown command").
    local NS, m, last = seenProfile()
    local out = run(NS, m, "skin")
    assertFalse(anyLine(out, "unknown command"), "a known verb")
    assertTrue(last.win ~= nil and last.win:IsShown(), "the picker is up")
    assertEqual(NS.SchemaRuntime.Get("skin.pickerSeen"), true, "the seen flag is not what decides")
end)

test("skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec", function()
    local NS = seenProfile()
    local H = NS.addon.Settings.Helpers
    local live, seen = H.SkinVerb, nil
    H.SkinVerb = function(spec) seen = spec; return nil, "queued" end
    local win, why = NS.RunSkinVerb()
    H.SkinVerb = live
    local want = NS.SkinPickerSpec()
    assertTrue(type(seen) == "table", "a spec")
    assertEqual(seen.owner, want.owner)
    assertTrue(rawequal(seen.get, want.get) and rawequal(seen.set, want.set), "the two seams")
    assertEqual(seen.page, want.page)
    assertEqual(seen.tab, want.tab)
    assertTrue(win == nil, "nothing shown")
    assertEqual(why, "queued", "the library's reason, passed on")
end)

test("skin verb: in combat every call prints the library's gray line and shows nothing", function()
    local NS, m, last = seenProfile()
    m.inCombat = true
    local first = run(NS, m, "skin")
    local second = run(NS, m, "skin")
    m.inCombat = false
    assertTrue(last.win == nil, "no picker mid-combat")
    assertEqual(last.why, "combat")
    assertTrue(anyLine(first, strings(m).VERB_COMBAT), "the first call says why")
    assertTrue(anyLine(second, strings(m).VERB_COMBAT), "and so does every later one")
end)

test("skin verb: refused while the addon is disabled, and no picker shows", function()
    local NS, m, last = seenProfile()
    NS.addon:OnSlashCommand("disable")
    local out = run(NS, m, "skin")
    assertEqual(#out, 1, "one refusal line")
    assertTrue(out[1]:find("is disabled", 1, true) ~= nil, "the disabled line")
    assertTrue(last.spec == nil, "O.SkinVerb was never called")
end)

test("skin verb: without LibKa0s the verb prints the library-absent line", function()
    local NS, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    m.prints = m.prints or {}
    local out = run(NS, m, "skin")
    assertTrue(anyLine(out, "/qc skin is unavailable: the LibKa0s library did not load."), "names the verb")
end)
