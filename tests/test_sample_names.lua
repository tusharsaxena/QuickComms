-- tests/test_sample_names.lua — every named sample person this addon draws comes from the library
-- (FB2-QC-01; LibKa0s#104, decision D1 of Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH/
-- R2_SMOKE_FEEDBACK.md; WowAddonStandards v2.120.0, one source of sample names). The one sample person
-- Quick Comms shows is the caster on test mode's sample auto-thank toast (FB-QC-02): a stranger, so
-- it is the first of LibKa0s-Sim-1.0's seeded crowd (Sim.SampleCrowd), beyond the five protagonists
-- that stand for the player's own party. Test mode's pad and dial placeholders wear the shipped
-- callouts' names, not people. No `Sample*`/`Mock*` name is typed in the shipped code.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function live()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    return NS, m, NS.AutoThankToast
end

--- The name the toast should show for the crowd's first person on this client: the bare name on
--- Retail (Compat.AuraCaster's `name`, no realm), "First Surname" where names are regional.
local function crowdName(m, client, seed)
    local row = m.LibStub("LibKa0s-Sim-1.0").SampleCrowd(client, 1, seed)[1]
    return client == "forever" and row.fullName or row.name
end

test("sample names: the test-mode toast's caster is the library crowd's first person, seeded", function()
    local NS, m, TH = live()
    local client = NS.Compat.ClientKey()
    assertEqual(type(TH.SAMPLE_SEED), "number", "the crowd is seeded, so the sample replays")
    local want = crowdName(m, client, TH.SAMPLE_SEED)
    local p = TH.SamplePayload()
    -- red under: the hand-kept L["A stranger"] (FB-QC-02), a name no other Ka0s addon shows
    assertEqual(p.name, want, client .. ": the crowd's name")
    assertEqual(p.caster.name, want, "the caster the Thank button would name")
    assertTrue(p.name:find("^Sample") ~= nil or p.name:find("^Mock") ~= nil, "a convention name: " .. p.name)
    assertFalse(p.name:find("-", 1, true) ~= nil, "no realm, as a real caster's name reads")
    assertEqual(TH.SamplePayload().name, want, "the same person every time")
end)

test("sample names: the sample toast's line names the crowd person", function()
    local NS, m, TH = live()
    m.issecretvalue = T.isSecret
    NS.addon:OnSlashCommand("test")
    local f = TH.toast:FrameFor(m.LibStub("LibKa0s-Toast-1.0").PREVIEW)
    assertTrue(f ~= nil, "the sample toast is up")
    local want = crowdName(m, NS.Compat.ClientKey(), TH.SAMPLE_SEED)
    assertEqual(f.qcText:GetText(), NS.L["%s buffed you with %s"]:format(want, NS.L["a sample buff"]))
end)

test("sample names: with no LibKa0s-Sim-1.0 the toast falls back to the plain label", function()
    local NS, m, TH = live()
    local real = m.LibStub
    m.LibStub = setmetatable({}, { __index = real, __call = function(_, name, silent)
        if name == "LibKa0s-Sim-1.0" then return nil end
        return real(name, silent)
    end })
    local p = TH.SamplePayload()
    m.LibStub = real
    -- a degraded install still shows a sample, named by a label rather than a made-up person
    assertEqual(p.name, NS.L["A stranger"])
end)

-- ── the guard: no sample name typed in the shipped code ─────────────────────────────────────

--- Every `Sample*`/`Mock*` name word (a capitalized word of 2+ lower-case letters after the prefix:
--- the convention's shape, so `SamplePayload` or `MockSecure` identifiers do not match) in `text`.
local function sampleWords(text)
    local out = {}
    for _, prefix in ipairs({ "Sample", "Mock" }) do
        for w in text:gmatch("%f[%w_]" .. prefix .. "%l%l+%f[^%w_]") do out[#out + 1] = w end
    end
    return out
end

--- The shipped files: every .lua, .toc and .xml outside libs/ (vendored) and tests/.
local function shippedFiles()
    local files = {}
    local p = io.popen("find . -type f \\( -name '*.lua' -o -name '*.toc' -o -name '*.xml' \\)"
        .. " -not -path './libs/*' -not -path './tests/*' -not -path './.git/*' | sort")
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    return files
end

test("sample names: no Sample*/Mock* name literal lives in the shipped code", function()
    local files = shippedFiles()
    assertTrue(#files > 50, "the walk found the addon's files, got " .. #files)
    local hits = {}
    for _, path in ipairs(files) do
        local fh = assert(io.open(path, "rb"))
        local text = fh:read("*a")
        fh:close()
        for _, w in ipairs(sampleWords(text)) do hits[#hits + 1] = path .. ": " .. w end
    end
    -- red under: a hand-copied library name (or a hand-kept pool) in core/, modules/, settings/, ...
    assertEqual(table.concat(hits, "; "), "", "sample names come from LibKa0s-Sim-1.0 at run time")
end)

test("sample names: the guard is falsifiable, a planted name is flagged and an identifier is not", function()
    local got = sampleWords('local who = "Mockgrove" -- and Samplehunter-Samplerealm\nTH.SamplePayload() Mock.x')
    assertEqual(table.concat(got, ","), "Samplehunter,Samplerealm,Mockgrove")
end)
