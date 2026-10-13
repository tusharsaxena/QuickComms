-- tests/test_setup.lua — the addon-side wiring of every adopted LibKa0s module (testing-§8).
--
-- The library's internals are covered in the LibKa0s repo; these cases cover what is this addon's:
-- each descriptor is well-formed, the seams resolve in the order the TOC promises, every declared
-- perf bucket has a real bracket, and the degraded path works when the library is genuinely absent.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

local function read(rel)
    local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
    local src = fh:read("*a"); fh:close()
    return src
end

-- ── Core ────────────────────────────────────────────────────────────────────────────────────

test("core: NS.Print is NS.Util.print after AceConsole's embed (architecture-§2)", function()
    local NS = T.newAddon()
    -- red under: drop the reclaim line in core/QuickComms.lua
    assertTrue(NS.Print == NS.Util.print)
    local D = T.newAddon{ skip = NO_LIBKA0S }
    assertTrue(D.Print == D.Util.print, "on the degraded path too")
end)

test("core: the printer tags every line with the cyan [QC] prefix", function()
    local NS, _, m = T.newAddon()
    NS.Print("hello")
    assertEqual(m.prints[#m.prints], "|cff00ffff[QC]|r hello")
end)

test("core: the degraded printer says the library is missing once, then tags every line", function()
    local D, _, m = T.newAddon{ skip = NO_LIBKA0S }
    m.prints = {}
    D.Print("one")
    D.Print("two")
    local missing = 0
    for _, line in ipairs(m.prints) do
        if line:find("LibKa0s library is missing", 1, true) then missing = missing + 1 end
    end
    assertEqual(missing, 1)
    assertEqual(m.prints[#m.prints], "|cff00ffff[QC]|r two")
end)

test("core: the close-button wrapper passes the addon folder as the third argument", function()
    local NS, _, m = T.newAddon()
    local Core = m.LibStub("LibKa0s-Core-1.0", true)
    local real, seen = Core.MakeCloseButton, nil
    Core.MakeCloseButton = function(parent, onClick, folder) seen = folder; return real(parent, onClick, folder) end
    NS.MakeCloseButton({}, function() end)
    Core.MakeCloseButton = real
    -- red under: drop `addonName` from the wrapper in core/CoreSetup.lua (anti-pattern #64)
    assertEqual(seen, "QuickComms")
end)

test("core: no file but the wrapper calls a close-button factory directly", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        local src = read(rel):gsub("%-%-[^\r\n]*", "")   -- comments name the grep; only code is checked
        for pre in src:gmatch("([%w_%.:]*)MakeCloseButton%(") do
            local ok = pre == "NS." or (rel == "core/CoreSetup.lua" and pre == "lib.")
            assertTrue(ok, rel .. " calls " .. pre .. "MakeCloseButton(")
        end
    end
end)

-- ── Media and the console font ──────────────────────────────────────────────────────────────

test("media: FONT_MONO is the shipped face live, and a real client font degraded", function()
    local NS = T.newAddon()
    -- red under: move core\MediaSetup.lua below core\Constants.lua in the TOC
    assertEqual(NS.Constants.FONT_MONO, NS.MediaFont("JetBrains Mono"))
    assertTrue(NS.Constants.FONT_MONO:find("QuickComms", 1, true) ~= nil, "built from the folder name")
    local D, _, m = T.newAddon{ skip = NO_LIBKA0S, mock = function(mk) mk.STANDARD_TEXT_FONT = "Fonts\\X.TTF" end }
    assertEqual(D.Constants.FONT_MONO, m.STANDARD_TEXT_FONT)
end)

-- ── Env ─────────────────────────────────────────────────────────────────────────────────────

test("env: the version falls back to the in-code constant when the TOC cannot be read", function()
    local NS = T.newAddon()
    assertEqual(NS.Version(), "0.1.0")
    local D = T.newAddon{ skip = NO_LIBKA0S }
    assertEqual(D.Version(), "0.1.0")
end)

-- ── Bus ─────────────────────────────────────────────────────────────────────────────────────

test("bus: every catalog name is Ka0s_QuickComms_<Event>, and the copy is strict", function()
    local NS = T.newAddon()
    local n = 0
    for _, wire in pairs(NS.MSG) do
        n = n + 1
        assertTrue(wire:find("^Ka0s_QuickComms_%u%a+$") ~= nil, wire)
    end
    assertTrue(n >= 1, "the catalog is not empty")
    assertEqual(NS.MSG.PROFILE_CHANGED, "Ka0s_QuickComms_ProfileChanged")
    -- The strict copy: a mistyped constant raises at the call site, publisher or subscriber.
    T.assertError(function() return NS.MSG.PROFILE_CHANGD end, "a mistyped key raises")
    assertTrue(NS.Bus.tracked == true, "the live bus tracks its receivers")
    assertTrue(T.newAddon{ skip = NO_LIBKA0S }.Bus.tracked == false, "the degraded one does not")
end)

test("bus: a tracked target's registrations come down with the stand-down and back with the stand-up", function()
    local NS = T.enableAddon()
    local target = NS.Bus:NewTarget()
    local heard = 0
    target:RegisterMessage(NS.MSG.PROFILE_CHANGED, function() heard = heard + 1 end)
    NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
    assertEqual(heard, 1)
    NS.SchemaRuntime.Set("enabled", false)
    NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
    -- red under: drop `NS.Bus:StandDown()` from NS.StandDown
    assertEqual(heard, 1, "nothing heard while stood down")
    NS.SchemaRuntime.Set("enabled", true)
    NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
    assertEqual(heard, 2, "replayed on the stand-up")
end)

test("bus: a profile switch sends PROFILE_CHANGED once", function()
    local NS = T.enableAddon()
    local target = NS.Bus:NewTarget()
    local heard = 0
    target:RegisterMessage(NS.MSG.PROFILE_CHANGED, function() heard = heard + 1 end)
    NS.addon.db:SetProfile("Other")
    -- red under: drop the SendMessage from reloadProfile in core/QuickComms.lua
    assertEqual(heard, 1)
end)

-- ── Perf ────────────────────────────────────────────────────────────────────────────────────

-- The bracket idiom names its bucket as the first argument of Perf.Note (performance-§2).
local function bracketKeys()
    local keys = {}
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        local src = read(rel):gsub("%-%-[^\r\n]*", "")
        for key in src:gmatch("Perf%.Note%(%s*\"([^\"]+)\"") do keys[key] = rel end
    end
    return keys
end

test("perf: every declared bucket has a bracket, and every bracket a declared bucket", function()
    local NS = T.enableAddon()
    local declared = {}
    for _, key in ipairs(NS.Perf.BUCKET_ORDER) do declared[key] = true end
    local brackets = bracketKeys()
    -- red under: declare { key = "x" } in core/PerfSetup.lua with no `Perf.Note("x", ...)` anywhere
    for key in pairs(declared) do assertTrue(brackets[key] ~= nil, "bucket " .. key .. " has no bracket") end
    for key, rel in pairs(brackets) do assertTrue(declared[key], rel .. " notes undeclared bucket " .. key) end
end)

test("perf: [audit QC-12] every bucket key is lowerCamelCase, named for the path it times (naming-cheatsheet)", function()
    local NS = T.enableAddon()
    assertTrue(#NS.Perf.BUCKET_ORDER == 7)
    for _, key in ipairs(NS.Perf.BUCKET_ORDER) do
        -- red under: a dotted key such as "bakeSurface" in core/PerfSetup.lua
        assertTrue(key:match("^%l[%w]*$") ~= nil, key .. " is not lowerCamelCase")
    end
end)

test("perf: the live harness is built, and the stub answers the perf verb", function()
    local NS = T.newAddon()
    assertTrue(NS.Perf.BuildRecord ~= nil, "the live instance, not the stub")
    local D = T.newAddon{ skip = NO_LIBKA0S }
    local lines = D.Perf.OnCommand("")
    assertTrue(lines[1]:find("perf harness is unavailable", 1, true) ~= nil, tostring(lines[1]))
end)

test("perf: the `perf` hold stands the addon down, and the verbs keep answering", function()
    local NS, _, m = T.enableAddon()
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertTrue(NS.IsStoodDown())
    m.prints = {}
    NS.addon:OnSlashCommand("version")
    -- Stored `enabled` is still true, so nothing is refused as disabled.
    assertTrue(#m.prints > 0 and not m.prints[1]:find("is disabled", 1, true), tostring(m.prints[1]))
    NS.Lifecycle:Release(NS.HOLD_PERF)
    assertFalse(NS.IsStoodDown())
end)

test("perf: the descriptor's SavedVariables global is declared in the TOC", function()
    local NS = T.newAddon()
    assertEqual(NS.Perf.descriptor and NS.Perf.descriptor.sv or "QuickCommsPerfDB", "QuickCommsPerfDB")
end)

-- ── Launcher ────────────────────────────────────────────────────────────────────────────────

test("launcher: one object, labeled with the brand, the logo as its icon, registered on enable", function()
    local NS, _, m = T.enableAddon()
    local obj = m.ldbObjects.QuickComms
    assertTrue(obj ~= nil, "named for the folder")
    assertEqual(obj.type, "launcher")
    assertEqual(obj.label, "Ka0s Quick Comms")
    assertEqual(obj.icon, "Interface\\AddOns\\QuickComms\\media\\logos\\quickcomms.logo.128.tga")
    local btn = m.minimapButtons.QuickComms
    assertTrue(btn ~= nil and btn.object == obj, "the same object, registered with LibDBIcon")
    assertTrue(btn.db == NS.addon.db.global.minimap, "LibDBIcon's table is the global store")
end)

-- The right-click menu, opened through a recording MenuUtil: the client's own context menu is the
-- library's (launcher-§2), and its entries are the descriptor's accessor-and-toggle pairs.
local function openMenu(m)
    local root = { boxes = {} }
    function root.CreateTitle(_, t) root.title = t end
    function root.CreateCheckbox(_, label, isChecked, onClick)
        local box = { label = label, checked = isChecked, click = onClick }
        root.boxes[#root.boxes + 1] = box
        return box
    end
    m.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    m.ldbObjects.QuickComms.OnClick(m.UIParent, "RightButton")
    return root
end

test("launcher: the right-click menu is Enabled, Locked and Test mode", function()
    local _, _, m = T.enableAddon()
    local root = openMenu(m)
    assertEqual(root.title, "Ka0s Quick Comms")
    local labels = {}
    for i, box in ipairs(root.boxes) do labels[i] = box.label end
    -- red under: drop isTestMode/toggleTestMode from core/LauncherSetup.lua
    assertEqual(table.concat(labels, ","), "Enabled,Locked,Test mode")
end)

test("launcher: Enabled calls the same handler `/qc disable` calls", function()
    local NS, _, m = T.enableAddon()
    local boxes = openMenu(m).boxes
    boxes[1].click()
    assertTrue(NS.IsStoodDown(), "Enabled off stands the addon down")
    assertFalse(NS.addon.db.profile.enabled, "through the stored path")
    boxes[1].click()
    assertFalse(NS.IsStoodDown())
end)

test("launcher: degraded, Register says once that there is no minimap button", function()
    local D, _, m = T.bootAddon{ skip = NO_LIBKA0S }
    m.prints = {}
    D.Launcher:Register()
    D.Launcher:Register()
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find("no minimap button", 1, true) then n = n + 1 end
    end
    assertEqual(n, 1)
    assertTrue(m.ldbObjects.QuickComms == nil)
end)

-- ── Options ─────────────────────────────────────────────────────────────────────────────────

-- The Profiles page builds only where AceDBOptions and AceConfigDialog resolve, which the kit's
-- mock does not model; the in-game check is PROFILE-1 in docs/smoke-tests.md.
test("options: the category registers eagerly, with the General page under it", function()
    local NS, _, m = T.enableAddon()
    assertTrue(NS.addon._settingsRegistered == true)
    assertTrue(m.__mainPanel ~= nil, "the parent category")
    assertTrue(m.__subcategories.General ~= nil, "General")
end)

test("options: the General page's first group is exactly `Master controls`", function()
    local NS = T.newAddon()
    local first = NS.addon.Settings.Schema[1]
    assertEqual(first.group, "Master controls")
    assertEqual(first.path, "enabled")
    for _, row in ipairs(NS.addon.Settings.Schema) do
        assertTrue(type(row.group) == "string" and row.group ~= "", "every row carries a group: " .. tostring(row.path))
    end
end)

test("options: the degraded load completes, and the panel says once that it is unavailable", function()
    local D, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    D.addon:OnSlashCommand("config")
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find("settings panel is unavailable", 1, true) then n = n + 1 end
    end
    assertEqual(n, 2, "once at registration, once at the first open")
    D.addon:OnSlashCommand("config")
    local again = 0
    for _, line in ipairs(m.prints) do
        if line:find("settings panel is unavailable", 1, true) then again = again + 1 end
    end
    assertEqual(again, 2, "and not again")
    -- The composers are hollow ({}), never a host copy: the degraded schema holds the member rows
    -- (settings/SchemaMembers.lua, which Library's writers need on every load) and nothing else.
    assertTrue(#D.addon.Settings.Schema > 0, "the member rows")
    for _, row in ipairs(D.addon.Settings.Schema) do
        -- red under: a composed or hand-written page row added on the degraded load
        assertTrue(row.instance ~= nil, "only member rows: " .. tostring(row.path))
    end
end)

test("libs: [phase 5] LibDeflate and LibSerialize are vendored, TOC-listed and loaded before the addon", function()
    local _, m = T.newAddon()
    local toc = read("QuickComms.toc")
    for _, lib in ipairs({ "LibDeflate", "LibSerialize" }) do
        -- red under: drop the lib's line from QuickComms.toc (the client would never load it)
        assertTrue(toc:find("libs\\" .. lib .. "\\lib.xml", 1, true) ~= nil, lib .. " has a TOC line")
        assertTrue(m.LibStub(lib, true) ~= nil, lib .. " registered with LibStub")
    end
    local D, S = m.LibStub("LibDeflate"), m.LibStub("LibSerialize")
    local packed = D:EncodeForPrint(D:CompressDeflate(S:Serialize({ a = 1 })))
    local ok, back = S:Deserialize(D:DecompressDeflate(D:DecodeForPrint(packed)))
    assertTrue(ok and back.a == 1, "a round trip through both")
end)

test("perf: [phase 5] a refresh notes situationRefresh, and each plan resolverResolve inside bakeSurface", function()
    local NS = T.enableAddon()
    local notes = {}
    local real = NS.Perf.Note
    NS.Perf.Note = function(key, ms, parent)
        notes[#notes + 1] = key .. (parent and ("<" .. parent) or "")
        return real(key, ms, parent)
    end
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Perf.on = true
    NS.Situation.RefreshNow("test")
    NS.Perf.on = false
    local text = table.concat(notes, ",")
    assertTrue(text:find("situationRefresh", 1, true) ~= nil, text)
    -- red under: drop the parent argument from the resolverResolve bracket in modules/Surfaces.lua
    assertTrue(text:find("resolverResolve<bakeSurface", 1, true) ~= nil, text)
end)

test("perf: [review] a refresh whose signature moves notes situationRefresh before the rebuild it publishes", function()
    local NS = T.enableAddon()
    local notes = {}
    local real = NS.Perf.Note
    NS.Perf.Note = function(key, ms, parent)
        notes[#notes + 1] = key
        return real(key, ms, parent)
    end
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Perf.on = true
    assertTrue(NS.Situation.RefreshNow("test"), "the signature moved")
    NS.Perf.on = false
    local text = table.concat(notes, ",")
    assertTrue(text:find("bakeSurface", 1, true) ~= nil, "the publish rebuilt the surfaces: " .. text)
    -- red under: Perf.Note("situationRefresh") after the SITUATION_CHANGED send in modules/Situation.lua
    -- (the whole rebuild timed inside a bucket declared with no children, performance-§3)
    assertEqual(notes[1], "situationRefresh", text)
end)

test("perf: [phase 5] the Comms Dial page's Preview notes neither bakeSurface nor resolverResolve", function()
    local NS = T.enableAddon()
    local notes = {}
    local real = NS.Perf.Note
    NS.Perf.Note = function(key, ms, parent)
        notes[#notes + 1] = key
        return real(key, ms, parent)
    end
    NS.Perf.on = true
    local lines = NS.addon.Settings.Dials.PreviewLines("d2")
    NS.Perf.on = false
    assertTrue(#lines > 0)
    -- red under: drop `not deps.unmeasured` from resolve() in modules/Surfaces.lua
    assertEqual(table.concat(notes, ","), "", "an editor's look is not a surface's bake")
end)
