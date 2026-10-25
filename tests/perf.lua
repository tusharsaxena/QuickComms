#!/usr/bin/env lua
-- tests/perf.lua — the offline performance scenarios (performance-§9).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- OUTSIDE THE GREEN GATE: `lua tests/run.lua` never runs it, and no commit depends on it. It asserts
-- only deterministic quantities, bytes allocated per iteration and bracket notes, each measured loop
-- isolated by a full collect on either side with the collector stopped inside it. Timings are
-- printed for orientation only: compare scenarios within a run, never across runs or machines.
--
-- THE SCENARIOS (spec §16, performance-§9):
--   bracketCaptureOff     the bracket shape itself, around no work, capture off: notes and allocates
--                         nothing.
--   dialPointerCaptureOff the hottest bracketed path, the open dial's pointer OnUpdate (dialRender,
--   dialPointerNoHarness  every frame while a dial is open), with capture off, and again on an
--                         instance loaded WITHOUT the LibKa0s-Perf files (core/PerfSetup.lua's
--                         stub): the zero-overhead pin is that capture off allocates no more than no
--                         instrumentation at all.
--   padRebuild12          one 12-button pad rebuilt from its plan, capture on: bakeSurface,
--                         resolverResolve and padLayout, three notes.
--   dialOpenClose         the default dial opened, one pointer frame drawn, closed: one note.
--   situationRefresh      one situation read whose signature did not move: one note.
--
-- CEILINGS (measured 2026-10-13, Lua 5.1.5, against the headless mock, whose catch-all methods
-- allocate a closure per call, so the figures are the mock's as much as the addon's; compare them
-- run to run, never with the client). The two captureOff scenarios and bracketCaptureOff are pinned
-- by rule, not by figure; the rest sit at the measured figure rounded up to the next KiB. Raise a
-- ceiling only by re-measuring and saying why; a rise is the finding.
--
-- Raised 2026-10-14: padRebuild12 68960.4 -> 69960.4 bytes/iter (69632 -> 70656) at e0bb552, where the
-- button and title rows started growing with the Look's font size (the final review's fix): the
-- geometry now reads the size per rebuild. Re-measured; the cost is that fix's, by design.
--
-- Re-measured 2026-10-25 (review F-001, run item RA-01), no ceiling moved: padRebuild12 had risen to
-- 87026.8 (the shipped Gloss fade shine repainted on every button at every rebuild) and dialOpenClose
-- to 2317.1 (the dial polish's per-frame tracking re-placing the slice highlight on every light, plus
-- the wedge tooltip it now shows). Both repaints are guarded now: 66290.8 and 1997.1.

local BYTE_CEILING = {
    bracketCaptureOff = 0,
    dialPointerCaptureOff = 1024, dialPointerNoHarness = 1024,
    padRebuild12 = 70656, dialOpenClose = 2048, situationRefresh = 2048,
}
local NOTES_PER_ITER = {
    bracketCaptureOff = 0, dialPointerCaptureOff = 0, dialPointerNoHarness = 0,
    padRebuild12 = 3, dialOpenClose = 1, situationRefresh = 1,
}

local N = 1000
local USAGE = "usage: lua tests/perf.lua [--out <path>] [--label <text>]\n"

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        local a = arg[i]
        if a == "--out" and arg[i + 1] then opts.out = arg[i + 1]; i = i + 2
        elseif a == "--label" and arg[i + 1] then opts.label = arg[i + 1]; i = i + 2
        else
            io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
            io.stderr:write(USAGE)
            os.exit(2)
        end
    end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────

local mockf = dofile("tests/wow_mock.lua")
local loadAddon = dofile("tests/loader.lua")(".", mockf)
local NS, mock = loadAddon()
NS.addon:OnInitialize()
NS.addon:OnEnable()

local failures = {}
local function check(ok, msg) if not ok then failures[#failures + 1] = msg end end

check(NS.Perf.BuildRecord ~= nil, "NS.Perf is the degradation stub: every scenario would measure a stub")

-- Count the bracket's notes without allocating: a counter, not a list.
local notes = 0
local realNote = NS.Perf.Note
NS.Perf.Note = function(key, ms, parent)
    notes = notes + 1
    return realNote(key, ms, parent)
end

local results = {}

--- Run `fn` n times after a warm-up, the collector stopped inside the loop.
local function measure(name, n, fn)
    for _ = 1, 50 do fn() end
    notes = 0
    collectgarbage("collect"); collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    local t0 = os.clock()
    for _ = 1, n do fn() end
    local t1 = os.clock()
    local after = collectgarbage("count")
    collectgarbage("restart")
    local r = {
        name = name, iterations = n, totalMs = (t1 - t0) * 1000, msPerIter = (t1 - t0) * 1000 / n,
        notesPerIter = notes / n, bytesPerIter = math.max(0, (after - before) * 1024 / n),
    }
    results[#results + 1] = r
    return r
end

-- ── scenarios ───────────────────────────────────────────────────────────────────────────────

-- Zero overhead (performance-§2/§9): the bracket in exactly the shape every hot path will use, a
-- load-time upvalue, one field read and one boolean test, around no work at all.
local Perf = NS.Perf
local clock = mock.debugprofilestop
local function bracketed()
    local t0 = Perf.on and clock()
    if t0 then Perf.Note("scaffold.probe", clock() - t0) end
end

Perf.on = false
measure("bracketCaptureOff", N, bracketed)

-- In a Mythic+ key, so the default pad and dial have something to show.
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local function live(instance)
    instance.Situation.ReadInputs = function() return MPLUS end
    instance.Situation.RefreshNow("perf")
end

-- The zero-overhead pair (performance-§9): the dial's pointer OnUpdate, the hottest bracketed path,
-- with capture off, and on an instance with no Perf library at all.
local function pointerFrame(instance, m)
    local header = instance.Dial.Instance("d2").header
    instance.DialSecure.Open(header)
    m.cursor.x, m.cursor.y = 50, 60
    local pointer = header.qcPointer
    return function() instance.DialRender.PointerUpdate(pointer) end
end

live(NS)
local pointer = pointerFrame(NS, mock)
measure("dialPointerCaptureOff", N, pointer)

local NO_PERF = {}
for _, rel in ipairs(loadAddon.libFiles) do
    if rel:find("/Perf", 1, true) then NO_PERF[#NO_PERF + 1] = rel end
end
local bare, bareMock = loadAddon({ skip = NO_PERF })
bare.addon:OnInitialize()
bare.addon:OnEnable()
check(bare.Perf.BuildRecord == nil, "the bare instance still has the Perf library: the pair compares nothing")
live(bare)
measure("dialPointerNoHarness", N, pointerFrame(bare, bareMock))
NS.DialSecure.Close(NS.Dial.Instance("d2").header)

-- A 12-button pad: twelve callouts in one group of the player's own, the pad's only group.
local Lib = NS.Library
local twelve = {}
for i = 1, 12 do
    twelve[i] = Lib.CreateCallout({ name = "Callout " .. i, text = "Callout " .. i .. " {rt8}", channel = "party" })
end
local group = Lib.CreateGroup({ name = "Twelve", callouts = twelve })
local p1 = NS.db.profile.pads.p1
while #p1.groups > 0 do Lib.RemoveGroupFromSurface("pad", "p1", p1.groups[1]) end
Lib.AddGroupToSurface("pad", "p1", group)

Perf.on = true
measure("padRebuild12", 200, function()
    local snap = NS.Situation.Current()
    NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", p1, snap, NS.Surfaces.Deps(snap)))
end)
local header = NS.Dial.Instance("d2").header
measure("dialOpenClose", 200, function()
    NS.DialSecure.Open(header)
    NS.DialRender.PointerUpdate(header.qcPointer)
    NS.DialSecure.Close(header)
end)
measure("situationRefresh", 500, function() NS.Situation.RefreshNow("perf") end)
Perf.on = false
NS.Perf.Note = realNote

-- The zero-overhead claim itself: capture off costs no more than no instrumentation.
local function bytesOf(name)
    for _, r in ipairs(results) do if r.name == name then return r.bytesPerIter end end
    return math.huge
end
check(bytesOf("dialPointerCaptureOff") <= bytesOf("dialPointerNoHarness"),
    ("the pointer allocated %.1f bytes/iter with capture off and %.1f with no harness"):format(
        bytesOf("dialPointerCaptureOff"), bytesOf("dialPointerNoHarness")))

for _, r in ipairs(results) do
    local ceiling = BYTE_CEILING[r.name]
    check(ceiling ~= nil and r.bytesPerIter <= ceiling,
        ("%s allocated %.1f bytes/iter, over its %s-byte ceiling"):format(r.name, r.bytesPerIter, tostring(ceiling)))
    local want = NOTES_PER_ITER[r.name]
    check(want ~= nil and math.abs(r.notesPerIter - want) < 1e-9,
        ("%s noted %.2f times/iter, pinned at %s"):format(r.name, r.notesPerIter, tostring(want)))
end

-- ── report ──────────────────────────────────────────────────────────────────────────────────

print(("Ka0s Quick Comms \226\128\148 offline perf  (v%s, label '%s')"):format(tostring(NS.version), opts.label))
print()
-- Five columns, exactly: tests/_kit/run-automated-tests.sh counts scenarios structurally as the
-- five-field rows under this header.
print(("%-24s %8s %11s %10s %11s"):format("scenario", "iters", "ms/iter", "notes/iter", "bytes/iter"))
for _, r in ipairs(results) do
    print(("%-24s %8d %11.5f %10.2f %11.1f"):format(
        r.name, r.iterations, r.msPerIter, r.notesPerIter, r.bytesPerIter))
end
print()
print("timings are for orientation only \226\128\148 compare scenarios within a run, never across machines")
if #failures > 0 then
    print()
    print(("%d assertion%s FAILED:"):format(#failures, #failures == 1 and "" or "s"))
    for _, f in ipairs(failures) do print("  - " .. f) end
end

-- ── the record ──────────────────────────────────────────────────────────────────────────────

local function writeRecord(path)
    local buckets = {}
    for _, r in ipairs(results) do
        buckets[r.name] = { calls = r.iterations, totalMs = r.totalMs, maxMs = r.msPerIter,
                            notesPerIter = r.notesPerIter, bytesPerIter = r.bytesPerIter }
    end
    local fh, err = io.open(path, "w")
    if not fh then
        io.stderr:write("cannot write " .. path .. ": " .. tostring(err) .. "\n")
        os.exit(2)
    end
    fh:write(NS.Perf.EncodeJSON({
        schema = 1, addon = "QuickComms", source = "offline",
        version = tostring(NS.version), interface = 0, timestamp = os.time(),
        label = opts.label, buckets = buckets, failures = failures,
    }), "\n")
    fh:close()
    print("wrote " .. path)
end

if opts.out then writeRecord(opts.out) end

os.exit(#failures == 0 and 0 or 1)
