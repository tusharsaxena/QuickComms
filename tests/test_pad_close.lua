-- tests/test_pad_close.lua — a Comms Pad's close and settings marks, and the ways back (AF-STRIP-QC,
-- AF-HDR-QC; Ka0sAddonsCommonTasks docs/2026-11-19-ADOPTION_FEEDBACK, the owner's rulings; standalone-windows
-- *Which marks a window owes* and *The drag strip's marks*, standard v2.115.0).
--
-- The rulings: every drag strip carries [?][settings][close], and a pad's header row carries settings,
-- lock and close. The close hides THAT pad and keeps its settings (`db.char.padsClosed[id]`,
-- settings/SlashVerbs.lua V.ClosePad); three ways bring it back, which the X's tooltip names: the pad's
-- page (General, Show this pad), the launcher's Show window and `/qc show`. The settings mark opens the
-- pad's own page with the pad picked.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function live()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    NS.SchemaRuntime.Set("locked", false)
    return NS, m
end

local function inst(NS) return NS.Pad.Instance("p1") end
local function driver(NS, m) return m.stateDrivers[inst(NS).root].visibility end

--- A deep copy of a table, for comparing a pad's stored settings before and after.
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

local function same(a, b, path)
    if type(a) ~= "table" or type(b) ~= "table" then
        assertEqual(a, b, path)
        return
    end
    for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
    for k in pairs(b) do assertTrue(a[k] ~= nil, path .. "." .. tostring(k) .. " was added") end
end

--- Every line the game tooltip is given while `fn` runs, joined by newlines.
local function tipText(m, fn)
    local tip, saved, lines = m.GameTooltip, {}, {}
    local keys = { "SetText", "AddLine", "Show" }
    for _, k in ipairs(keys) do saved[k] = rawget(tip, k) end
    rawset(tip, "SetText", function(_, text) lines[#lines + 1] = tostring(text) end)
    rawset(tip, "AddLine", function(_, text) lines[#lines + 1] = tostring(text) end)
    rawset(tip, "Show", function() end)
    local ok, err = pcall(fn)
    for _, k in ipairs(keys) do rawset(tip, k, saved[k]) end
    if not ok then error(err, 0) end
    return table.concat(lines, "\n")
end

-- ── the drag strip's marks (AF-STRIP-QC) ──────────────────────────────────────────────────────────

test("pad close: a pad's drag strip carries all three marks, [?][settings][close]", function()
    local NS = live()
    local h = inst(NS).handle
    assertTrue(h:IsShown(), "unlocked: the strip shows")
    -- red under: MakeDragHandle without onClose (the close appears only with it, DragHandle minor 15)
    assertTrue(h.help ~= nil, "the help mark")
    assertTrue(h.settings ~= nil, "the settings mark")
    assertTrue(h.close ~= nil, "the close mark")
end)

test("pad close: each strip mark says its own words, never the strip's description", function()
    local NS, m = live()
    local h = inst(NS).handle
    local strip = tipText(m, function() h:__fire("OnEnter") end)
    local close = tipText(m, function() h.close:__fire("OnEnter") end)
    local settings = tipText(m, function() h.settings:__fire("OnEnter") end)
    -- red under: no closeTooltip (the X falls back to the strip's "Drag to move" description)
    assertTrue(close:find("Hide this pad", 1, true) ~= nil, close)
    assertTrue(close:find("/qc show", 1, true) ~= nil, "the X says how to bring the pad back: " .. close)
    assertTrue(close:find("Show window", 1, true) ~= nil, close)
    assertTrue(close:find("Show this pad", 1, true) ~= nil, close)
    assertTrue(settings:find("Open settings", 1, true) ~= nil, settings)
    assertTrue(close ~= strip and settings ~= strip, "neither mark repeats the strip's tooltip")
end)

test("pad close: the strip's X hides that pad, keeps its settings and says how to bring it back", function()
    local NS, m = live()
    local before = copy(NS.db.profile.pads.p1)
    assertEqual(driver(NS, m), "show")
    m.prints = {}
    inst(NS).handle.close:__fire("OnClick", "LeftButton")
    -- red under: an onClose that disables the pad (pad.enabled) or does nothing
    assertTrue(NS.SlashVerbs.PadClosed("p1"), "closed on this character")
    assertEqual(driver(NS, m), "hide", "the driver hides the pad")
    same(before, NS.db.profile.pads.p1, "pads.p1")
    assertFalse(NS.db.char.padsHidden == true, "the other pads are not hidden")
    assertEqual(#m.prints, 1, "one acknowledgment line")
    assertTrue(m.prints[1]:find("/qc show", 1, true) ~= nil, m.prints[1])
end)

test("pad close: the strip's settings mark opens this pad's own page, the pad picked", function()
    local NS = live()
    local got = {}
    NS.addon.EditPad = function(_, id) got[#got + 1] = id end
    inst(NS).handle.settings:__fire("OnClick", "LeftButton")
    -- red under: settings = NS.addon:OpenSettings (the addon's main page, not the pad's)
    assertEqual(#got, 1, "the pad page opened once")
    assertEqual(got[1], "p1")
end)

test("pad close: the Pad page's Edit picks the pad and opens the page", function()
    local NS = live()
    local Ed = NS.addon.Settings.Editors
    local opened = {}
    local real = Ed.OpenPage
    Ed.OpenPage = function(key) opened[#opened + 1] = key; return true end
    local ok, err = pcall(function()
        assertTrue(NS.addon:EditPad("p1"))
        assertEqual(opened[1], "pads")
        assertEqual(Ed.Selected("pad"), "p1")
        assertFalse(NS.addon:EditPad("nope"), "an unknown pad opens nothing")
        assertEqual(#opened, 1)
    end)
    Ed.OpenPage = real
    if not ok then error(err, 0) end
end)

-- ── the ways back ─────────────────────────────────────────────────────────────────────────────────

test("pad close: /qc show brings a closed pad back as it was", function()
    local NS, m = live()
    assertTrue(NS.SlashVerbs.ClosePad("p1"))
    assertFalse(NS.SlashVerbs.ClosePad("p1"), "closing it twice does nothing")
    m.prints = {}
    -- red under: no `show` row in NS.COMMANDS
    NS.addon:OnSlashCommand("show")
    assertFalse(NS.SlashVerbs.PadClosed("p1"))
    assertTrue(NS.db.char.padsClosed == nil, "the set is dropped when empty")
    assertEqual(driver(NS, m), "show")
    assertTrue(m.prints[1]:find("Comms Pads shown.", 1, true) ~= nil, m.prints[1])
    m.prints = {}
    NS.addon:OnSlashCommand("show")
    assertTrue(m.prints[1]:find("Every Comms Pad is already shown.", 1, true) ~= nil, "nothing to show says so")
end)

test("pad close: /qc show also ends /qc toggle's hide", function()
    local NS, m = live()
    NS.addon:OnSlashCommand("toggle")
    assertEqual(driver(NS, m), "hide")
    NS.addon:OnSlashCommand("show")
    assertFalse(NS.db.char.padsHidden == true)
    assertEqual(driver(NS, m), "show")
end)

test("pad close: Show window reads off when every pad is closed, and one click brings them back", function()
    local NS, m = live()
    local L = NS.Launcher
    assertTrue(NS.SlashVerbs.WindowShown(), "shown on a fresh addon")
    NS.SlashVerbs.ClosePad("p1")
    -- red under: isWindowShown reading PadsShown alone (on, though no pad shows)
    assertFalse(NS.SlashVerbs.WindowShown(), "every enabled pad closed: Show window off")
    assertTrue(L ~= nil)
    NS.SlashVerbs.TogglePads()
    assertFalse(NS.SlashVerbs.PadClosed("p1"), "Show window brought the pad back")
    assertFalse(NS.db.char.padsHidden == true)
    assertEqual(driver(NS, m), "show")
    NS.SlashVerbs.TogglePads()
    assertTrue(NS.db.char.padsHidden == true, "and the next click hides the pads, as it always did")
end)

test("pad close: Show window hides first while one pad of two still shows, then shows both", function()
    local NS = live()
    local id = NS.Library.CreateSurface("pad", "Second")
    NS.Surfaces.ApplyAll("test")
    NS.SlashVerbs.ClosePad("p1")
    assertTrue(NS.SlashVerbs.WindowShown(), "the second pad still shows")
    NS.SlashVerbs.TogglePads()
    assertTrue(NS.db.char.padsHidden == true, "hidden")
    assertTrue(NS.SlashVerbs.PadClosed("p1"), "the closed one stays closed under the hide")
    NS.SlashVerbs.TogglePads()
    assertFalse(NS.SlashVerbs.PadClosed("p1"), "shown again: both")
    assertFalse(NS.SlashVerbs.PadClosed(id))
end)

test("pad close: the Pad page's Show this pad brings back that one pad", function()
    local NS, m = live()
    NS.SlashVerbs.ClosePad("p1")
    -- red under: no V.ShowPad (the page's button)
    assertTrue(NS.SlashVerbs.ShowPad("p1"))
    assertFalse(NS.SlashVerbs.PadClosed("p1"))
    assertEqual(driver(NS, m), "show")
    assertFalse(NS.SlashVerbs.ShowPad("p1"), "a pad not closed: nothing to show")
end)

test("pad close: test mode still shows a closed pad, and it hides again when test mode ends", function()
    local NS, m = live()
    NS.SlashVerbs.ClosePad("p1")
    NS.Preview.SetTestMode(true)
    NS.Surfaces.ApplyAll("test")
    assertEqual(driver(NS, m), "show", "test mode is an explicit preview")
    NS.Preview.SetTestMode(false)
    NS.Surfaces.ApplyAll("test")
    assertEqual(driver(NS, m), "hide")
end)

test("pad close: the diagnostics name the pads closed on this character", function()
    local NS = live()
    NS.SlashVerbs.ClosePad("p1")
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    -- red under: no closed-pads line in modules/Diagnostics.lua surfaces
    assertTrue(text:find("closed with their X (this character) p1", 1, true) ~= nil, text)
end)

-- ── the header row's marks (AF-HDR-QC) ────────────────────────────────────────────────────────────

local function marks(NS) return inst(NS).header.qcMarks end

test("pad close: the header row's X hides that pad and keeps its settings, as the strip's does", function()
    local NS, m = live()
    local before = copy(NS.db.profile.pads.p1)
    -- red under: the header row built with close = false (AD-86-QC)
    marks(NS).close:__fire("OnClick", "LeftButton")
    assertTrue(NS.SlashVerbs.PadClosed("p1"))
    assertEqual(driver(NS, m), "hide")
    same(before, NS.db.profile.pads.p1, "pads.p1")
    NS.addon:OnSlashCommand("show")
    assertEqual(driver(NS, m), "show", "and /qc show brings it back")
end)

test("pad close: the header row's settings mark opens this pad's own page", function()
    local NS = live()
    local got = {}
    NS.addon.EditPad = function(_, id) got[#got + 1] = id end
    marks(NS).settings:__fire("OnClick", "LeftButton")
    -- red under: settings = false (AD-86-QC's opt-out)
    assertEqual(table.concat(got, ","), "p1")
end)

test("pad close: the header row's lock calls the one lock seam and follows the lock's state", function()
    local NS = live()
    local lock = inst(NS).header.qcLock
    assertTrue(lock ~= nil, "a lock mark")
    assertFalse(NS.Setting("locked"), "unlocked to start (live)")
    assertFalse(lock.qcLocked, "the mark reads unlocked")
    assertEqual(lock.__tip, "Lock the pads", "its tooltip says what a click does")
    local calls, real = 0, NS.SlashVerbs.ToggleLock
    NS.SlashVerbs.ToggleLock = function() calls = calls + 1; return real() end
    lock:__fire("OnClick", "LeftButton")
    NS.SlashVerbs.ToggleLock = real
    -- red under: a lock mark that writes `locked` itself instead of calling the seam
    assertEqual(calls, 1, "the click goes through SlashVerbs.ToggleLock")
    assertTrue(NS.Setting("locked"), "locked")
    assertTrue(lock.qcLocked, "repainted for the new state")
    assertEqual(lock.__tip, "Unlock the pads")
    -- another way in (/qc unlock) repaints the mark too
    NS.addon:OnSlashCommand("unlock")
    assertFalse(lock.qcLocked, "/qc unlock repainted it")
    assertEqual(lock.__tip, "Lock the pads")
end)
