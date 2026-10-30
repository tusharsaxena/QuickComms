#!/usr/bin/env lua
-- tests/run.lua
--
-- Headless test runner for Ka0s Quick Comms, on the shared LibKa0s test kit (testing-§1). The
-- registry, assertions, runner, `--list` renderer, sandboxed loader and TOC reader come from
-- tests/_kit/ and are never edited here. What stays is this addon's: the instance factory
-- (tests/loader.lua), the mock extender (tests/wow_mock.lua), the three lifecycle factories below,
-- the surface-parity source map, the kit suites' consumer facts and the ordered suite list.
--
-- Run from the repo root:
--   lua tests/run.lua          -- run all suites (non-zero exit on failure)
--   lua tests/run.lua --list   -- print docs/test-cases.md's body; run nothing

local Kit  = dofile("tests/_kit/framework.lua")
local mock = dofile("tests/wow_mock.lua")

local root      = "."
local loadAddon = dofile("tests/loader.lua")(root, mock)

-- THE THREE FACTORIES. Each returns (NS, env, mock) -- env and mock are the same table -- and each
-- takes the same `opts` table (tests/loader.lua: skip, mock, and the mock fields). Fresh per call.

-- The mock of the newest instance, behind one table handed to Kit.expose as `mock`: the kit's
-- Kit.keybindThroughTab reads the harness's mock for LibStub (kit revision 42), and every case here
-- builds a fresh one, so the view forwards to whichever instance the case made last.
local currentMock
local mockView = setmetatable({}, { __index = function(_, k) return currentMock and currentMock[k] end })

-- Every file loaded; nothing run.
local function newAddon(opts)
    local NS, env, m = loadAddon(opts)
    currentMock = m
    return NS, env, m
end

-- The kit's AceDB fake (tests/_kit/mock_record.lua, vendored) models `profile` and `global` but not
-- AceDB's `char` section, which this addon uses for the Comms Pads' hidden state (defaults/Profile.lua
-- CHAR_DEFAULTS). Until the kit models it, this wraps the fake's New once per load: `db.char` is
-- the SavedVariables root's `char["<name> - <realm>"]`, filled from the `char` defaults as AceDB-3.0
-- does, so a test can keep the root and boot again, as a /reload would.
local CHAR_KEY = "Tester - Realm"
local function withCharSection(m)
    local AceDB = m.LibStub("AceDB-3.0", true)
    if not AceDB or AceDB.qcCharShim then return end
    local new = AceDB.New
    AceDB.New = function(self, tbl, defaults, ...)
        local db = new(self, tbl, defaults, ...)
        db.sv.char = db.sv.char or {}
        local char = db.sv.char[CHAR_KEY] or {}
        db.sv.char[CHAR_KEY] = char
        for k, v in pairs(defaults and defaults.char or {}) do
            if char[k] == nil then char[k] = v end
        end
        db.char = char
        return db
    end
    AceDB.qcCharShim = true
end

-- ... plus OnInitialize (ADDON_LOADED): the db exists, migrations have run. `opts.sv`, when given, is
-- the SavedVariables root the client hands back (a /reload or the next login of a saved one).
local function bootAddon(opts)
    local NS, env, m = newAddon(opts)
    if opts and opts.sv then _G.QuickCommsDB = opts.sv end
    withCharSection(m)
    NS.addon:OnInitialize()
    return NS, env, m
end

-- ... plus OnEnable (PLAYER_LOGIN): events registered, settings category and launcher registered,
-- and the latch taken from the stored `enabled` path.
--
-- AND THE SKIN LIBRARY'S LOGIN RETRY SETTLED. Since LibKa0s v1.78.0 the first RegisterOwner
-- (core/SkinSetup.lua) makes LibKa0s-Skin-1.0's EllesmereUI retry frame, registered for ADDON_LOADED
-- and PLAYER_LOGIN; the client fires PLAYER_LOGIN once, at this point, and the frame unregisters
-- both. Delivering it here puts the frame where every real session has it, so the stand-down
-- suites do not count the library's two events as this addon's (LootHistory's tests do the same).
local function settleSkinLogin(m)
    local skinLib = m.LibStub("LibKa0s-Skin-1.0", true)
    local retry = skinLib and skinLib.__euiEventFrame
    if retry and retry.__fire then retry:__fire("OnEvent", "PLAYER_LOGIN") end
end

local function enableAddon(opts)
    local NS, env, m = bootAddon(opts)
    settleSkinLogin(m)
    NS.addon:OnEnable()
    return NS, env, m
end

-- Where Kit.assertSurfaceParity's by-name form finds the LIVE half. Instances, not library tables,
-- because each stub mirrors what `lib:New(descriptor)` returned. One extra load, used for nothing
-- else and handed to no case.
local surfaceNS, surfaceMock = loadAddon()
Kit.setSurfaceSource{
    ["LibKa0s-DebugLog-1.0"]  = surfaceNS.DebugLog,
    ["LibKa0s-Slash-1.0"]     = surfaceNS.SlashCommands,
    ["LibKa0s-Options-1.0"]   = surfaceNS.addon.Settings.Helpers,
    ["LibKa0s-Launcher-1.0"]  = surfaceNS.Launcher,
    ["LibKa0s-Lifecycle-1.0"] = surfaceNS.Lifecycle,
    ["LibKa0s-Schema-1.0"]    = surfaceMock.LibStub("LibKa0s-Schema-1.0", true),
    ["LibKa0s-Pool-1.0"]      = surfaceMock.LibStub("LibKa0s-Pool-1.0", true),
    ["LibKa0s-Glow-1.0"]      = surfaceMock.LibStub("LibKa0s-Glow-1.0", true),
}

-- The table every suite reaches as `local T = _G.QUICKCOMMS_TEST`. Kit.expose merges `test` and the
-- kit assertions in beside these keys.
_G.QUICKCOMMS_TEST = Kit.expose{
    newAddon    = newAddon,
    bootAddon   = bootAddon,
    enableAddon = enableAddon,
    settleSkinLogin = settleSkinLogin,   -- the client's one PLAYER_LOGIN, to the skin's retry frame
    loadAddon   = loadAddon,
    root        = root,
    LibStub     = surfaceMock.LibStub,
    mock        = mockView,
    KIT_VERSION = Kit.VERSION,
    -- The kit's secret-value simulator (tests/_kit/secrets.lua), which Kit.expose leaves out.
    secret      = Kit.secret,
    isSecret    = Kit.isSecret,
    -- The id a profile's seeded group, else callout, has (the lowest when several do), by the shipped
    -- id it came from: `T.seeded(NS, "bi.mplus.pull")`. Seeded ids are fresh per profile, so a case
    -- names them so. Read from the profile: only Library reads `origin` in shipped code.
    seeded      = function(NS, origin)
        local p = NS.db.profile
        for _, set in ipairs({ p.groups, p.callouts }) do
            local found
            for id, m in pairs(set) do
                if type(m) == "table" and m.origin == origin and (not found or tostring(id) < tostring(found)) then found = id end
            end
            if found then return found end
        end
        return nil
    end,
}

-- The diagnostics-dump contract's consumer facts (debug-logging-§14): the kit's cases run through
-- THIS addon's dispatcher, on a fresh, fully enabled instance per case, and "disabled" goes through
-- the same write seam the Master controls checkbox and `/qc disable` use.
local diagNS
Kit.diagnostics = {
    brand       = "Ka0s Quick Comms",
    dispatch    = function(line) diagNS.addon:OnSlashCommand(line) end,
    console     = function() return diagNS.DebugLog end,
    setDebug    = function(on) diagNS.State.debug = on and true or false end,
    setDisabled = function(off) diagNS.SchemaRuntime.Set("enabled", not off) end,
    reset       = function() diagNS = enableAddon() end,
}

-- The layout-§1 census lives in the hub; the repository has no generated data to carve out.
Kit.layoutCap = { hub = "docs/ARCHITECTURE.md" }

-- Order is stable. Kit.assertSuiteInventory (called by Kit.run) fails the run in both directions:
-- a name here with no file, and a test_*.lua on disk (tests/ or tests/_kit/) with no name here.
-- `jobs = "auto"` fans the suites out across worker processes (testing-§14). Measured 2026-10-25 on
-- 1175 cases: serial 89.7 s wall, 32.0 s CPU (35%); 71 s of it is one case, test_vendor_sync's byte
-- check of the 5892-file payload, a single `git cat-file --batch` waiting on ../LibKa0s over the
-- WSL2 /mnt mount. Sharded: 72.9 s, the same totals, exit code and transcript. `--jobs 1` runs serial.
Kit.run{
    jobs   = "auto",
    dir    = "tests/",
    suites = {
        "test_harness",
        "test_mock_secure",
        "test_bus",
        "test_surface_parity",
        "test_setup",
        "test_database",
        "test_profile",
        "test_schema",
        "test_slash",
        "test_disabled",
        "test_diagnostics",
        "test_compat",
        "test_restrictions", "test_situation",
        "test_tokens",
        "test_channels",
        "test_bake",
        "test_resolver",
        "test_builtins",
        "test_gameids",
        "test_library",
        "test_members",
        "test_editors",
        "test_callout_popup",
        "test_icon_browser",
        "test_groups_when",
        "test_page_groups",
        "test_page_groups_nesting",
        "test_page_pads",
        "test_page_dials",
        "test_check",
        "test_send_guard",
        "test_sendengine",
        "test_dial_secure",
        "test_preview",
        "test_edit_preview",
        "test_preview_window",
        "test_coordinates",
        "test_master",
        "test_pad_layout",
        "test_dial_layout",
        "test_surfaces",
        "test_pad_render",
        "test_pad",
        "test_dial",
        "test_keybinds",
        "test_dial_shine",
        "test_icon_style",
        "test_glow",
        "test_shine",
        "test_layers",
        "test_layout",
        "test_skinsetup",
        "test_skin_windows",
        "test_skin_hud",
        "test_skin_picker",
        "test_skin_outline",
        "test_skin_verb",
        "test_skin_tools",
        "test_vendor_sync",
        { name = "test_eol",                  dir = "tests/_kit/" },   -- line-endings-§7
        { name = "test_prose",                dir = "tests/_kit/" },   -- localization-§5
        { name = "test_layout_cap",           dir = "tests/_kit/" },   -- layout-§1
        { name = "test_diagnostics_contract", dir = "tests/_kit/" },   -- debug-logging-§14
        { name = "test_lizard_sighted",       dir = "tests/_kit/" },   -- automated-tests-§3
    },
}
