-- tests/test_skin_tools.lua — the AceGUI rows this addon acquires itself, and the tool surfaces, on
-- the skin (QC-04; core/SkinSetup.lua's owner, skinning-§3).
--
-- What this pins:
--
--   * every AceGUI widget the settings pages make comes from the Options instance's owner proxy,
--     so it is painted for this owner, and the Scope's Ignore settings panel (on by default) leaves
--     it stock, so Ka0s Default's settings pages look as they did;
--   * the host's own release work (the popup's moved parts, the icon chooser's swatch, a reorder
--     row's image tint, a table row's layout) is chained through NS.SkinOnRelease, so it AND the
--     skin's restore both run, and no settings file sets an OnRelease callback of its own;
--   * the Profiles page's AceConfigDialog tree is painted through NS.SkinPaintAceTree after each
--     Open (AceDBOptions is not mocked, so the call is read off the source and the helper is driven
--     on a hand-built tree);
--   * the debug console, its copy window and the perf panel, all the library's, are drawn for this
--     owner: their descriptors name the folder and pass no host skin hook.
--
-- No custom AceGUI widget type (nothing to AliasAceType), no sim, no test strip, no chart. The
-- launcher tooltip's lines are the library's. Modeled on LootHistory's and AbsorbTracker's
-- tests/test_skin_tools.lua. Every case builds its own instance.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "QuickComms"

local function readFile(path)
    local fh = assert(io.open(path, "rb"))
    local body = fh:read("*a")
    fh:close()
    return body
end

--- An enabled instance with its settings panel skinned (Ignore settings panel off); answers NS,
--- the mock, the Skin major and the raw AceGUI.
local function skinned()
    local NS, _, m = T.enableAddon()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    Skin:SetIgnore(OWNER, false, false)
    return NS, m, Skin, m.LibStub("AceGUI-3.0")
end

local function ownerOf(Skin, w)
    local st = Skin.__ace and Skin.__ace[w]
    return st and st.owner
end

-- ── the AceGUI rows ──────────────────────────────────────────────────────────────────────────────

test("skin tools: the pages' AceGUI handle is the owner proxy, which paints for this owner", function()
    -- red under: a page acquiring from the raw library (its rows would never take the skin).
    local NS, _, Skin, Raw = skinned()
    local H = NS.addon.Settings.Helpers
    assertTrue(H.AceGUI ~= nil and not rawequal(H.AceGUI, Raw), "the Options instance's handle is a proxy")
    local w = H.AceGUI:Create("CheckBox")
    assertEqual(ownerOf(Skin, w), OWNER, "a widget made through the proxy is painted for " .. OWNER)
    Raw:Release(w)
    assertEqual(ownerOf(Skin, w), nil, "the release puts it back stock")
end)

test("skin tools: under the default Scope (Ignore settings panel) a page widget stays stock", function()
    -- Ka0s Default must look as it did: skin.ignorePanel defaults on, so nothing is painted.
    local NS, _, m = T.enableAddon()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    assertEqual(NS.SchemaRuntime.Get("skin.ignorePanel"), true)
    local w = NS.addon.Settings.Helpers.AceGUI:Create("Dropdown")
    assertEqual(ownerOf(Skin, w), nil, "a widget was painted under Ignore settings panel")
end)

test("skin tools: NS.SkinPaintAceTree paints every widget under a container", function()
    local NS, _, Skin, Raw = skinned()
    local group = Raw:Create("SimpleGroup")
    local box = Raw:Create("CheckBox")
    group:AddChild(box)
    assertEqual(ownerOf(Skin, box), nil, "the raw library paints nothing itself")
    local n = NS.SkinPaintAceTree(group)
    assertTrue(n >= 1, "the tree paint reached the check box under the group (got " .. tostring(n) .. ")")
    assertEqual(ownerOf(Skin, box), OWNER)
    Raw:Release(box)
    assertEqual(ownerOf(Skin, box), nil, "the release puts the widget back stock")
    Raw:Release(group)
end)

test("skin tools: NS.SkinOnRelease runs the host's release work AND the skin's restore", function()
    -- red under: a host release set as an AceGUI callback that the chain does not reach, or a chain
    -- that takes the skin's restore off the widget.
    local NS, _, Skin, Raw = skinned()
    local w = NS.addon.Settings.Helpers.AceGUI:Create("Label")
    assertEqual(ownerOf(Skin, w), OWNER, "painted on Create")
    local ran = 0
    NS.SkinOnRelease(w, function(self)
        assertTrue(rawequal(self, w), "the host step is handed the widget")
        ran = ran + 1
    end)
    Raw:Release(w)
    assertEqual(ran, 1, "the host step ran once")
    assertEqual(ownerOf(Skin, w), nil, "and the skin restored the widget")
end)

test("skin tools: the host's release work goes through NS.SkinOnRelease, never a callback", function()
    -- red under: any settings or module file setting `SetCallback("OnRelease", ...)` itself (it
    -- would sit beside the skin's chain, and AceGUI keeps one callback per name).
    local files = {
        "settings/CalloutPopup.lua", "settings/Editors.lua", "settings/Groups.lua",
        "settings/Groups_When.lua", "settings/Dials.lua", "settings/Pads.lua", "settings/Callouts.lua",
        "settings/IconBrowser.lua", "settings/Panel.lua", "settings/Profiles.lua",
    }
    local hits, chained = {}, 0
    for _, path in ipairs(files) do
        local src = readFile(path)
        for ln in src:gmatch("[^\n]+") do
            local code = ln:gsub("%-%-.*$", "")
            if code:find('SetCallback%(%s*"OnRelease"') then hits[#hits + 1] = path .. ": " .. code end
            if code:find("NS%.SkinOnRelease%(") then chained = chained + 1 end
        end
    end
    assertEqual(#hits, 0, "a host OnRelease callback:\n  " .. table.concat(hits, "\n  "))
    assertEqual(chained, 5, "the popup's release list, the swatch, the reorder label, the table row, the table name")
end)

test("skin tools: the icon chooser's swatch release still drops a tracked color picker", function()
    -- The swatch's host step (Ed.ReleasePicker) moved onto the chain: a release must still reach it.
    local NS, _, _, Raw = skinned()
    local Ed = NS.Editors or NS.addon.Settings.Editors
    assertTrue(Ed ~= nil and Ed.ReleasePicker ~= nil, "the editors module")
    local real, got = Ed.ReleasePicker, nil
    Ed.ReleasePicker = function(w, hide) got = { w, hide } end
    local ok, err = pcall(function()
        local swatch = NS.addon.Settings.Helpers.AceGUI:Create("ColorPicker")
        NS.SkinOnRelease(swatch, function() Ed.ReleasePicker(swatch, true) end)
        Raw:Release(swatch)
        assertTrue(got ~= nil and rawequal(got[1], swatch) and got[2] == true, "the swatch's release reached Ed.ReleasePicker")
    end)
    Ed.ReleasePicker = real
    if not ok then error(err, 0) end
end)

test("skin tools: the Profiles page paints AceConfigDialog's tree after each Open", function()
    -- red under: the Open with no tree paint after it (the profile manager's rows stay stock).
    local src = readFile("settings/Profiles.lua")
    local open = src:find("AceConfigDialog:Open%(APPNAME, container%)")
    local paint = src:find("NS%.SkinPaintAceTree%(container%)")
    assertTrue(open ~= nil and paint ~= nil and paint > open, "SkinPaintAceTree(container) follows the Open")
    assertTrue(src:find("Settings%.Helpers%.AceGUI or LibStub%(\"AceGUI%-3%.0\"") ~= nil,
        "the container comes from the Options instance's handle when there is one")
end)

test("skin tools: without LibKa0s the release work takes the AceGUI callback, and nothing paints", function()
    local NS = T.enableAddon({ skip = T.loadAddon.libFiles })
    assertEqual(NS.SkinPaintAce({}), false)
    assertEqual(NS.SkinPaintAceTree({}), 0)
    local set = {}
    local w = { SetCallback = function(_, name, fn) set[name] = fn end }
    local ran = false
    NS.SkinOnRelease(w, function() ran = true end)
    assertTrue(type(set.OnRelease) == "function", "the degraded chain is the widget's OnRelease callback")
    set.OnRelease(w)
    assertTrue(ran, "and it runs the host's step")
end)

-- ── the settings pages' colored lines ──────────────────────────────────────────────────────────

test("skin tools: the pages' colored lines keep today's bytes under Ka0s Default", function()
    -- red under: an escape left in a locale key, or a token whose Ka0s Default value is not the
    -- byte the line drew before (a0a0a0 hints, 40ff40 active, ff6060 inactive, c9a66b inherit).
    local NS = T.enableAddon()
    local W = NS.addon.Settings.GroupsWhen
    local snap = NS.Situation.Classify({ inInstance = true, instanceType = "raid", difficultyID = 15 })
    assertEqual(W.ActiveLine({ when = { content = { raid = true } } }, snap), "|cff40ff40Active now.|r")
    assertEqual(W.ActiveLine({ enabled = false, when = {} }, snap), "|cffa0a0a0Off: this group is turned off.|r")
    local line = W.ActiveLine({ when = { content = { mythicPlus = true } } }, snap)
    assertEqual(line, "|cffff6060Not active now:|r Content does not match.")
    assertEqual(NS.SkinMarkup("qc.hint", "x"), "|cffa0a0a0x|r")
    assertEqual(NS.SkinMarkup("log.tag", "x"), "|cffc9a66bx|r")
    assertEqual(NS.SkinMarkup("text.heading", "x"), "|cffffd100x|r")
    assertEqual(NS.SkinMarkup("gtip.subtle", "x"), "|cffb3b3b3x|r")
    assertEqual(NS.addon.Settings.Groups.MutedGold(), "|cffc9a66b")
end)

test("skin tools: the pages' colored lines move with a skin switch", function()
    -- red under: an escape built once at file load (a skin switch would never reach the line).
    local NS, _, m = T.enableAddon()
    local W = NS.addon.Settings.GroupsWhen
    local snap = NS.Situation.Classify({ inInstance = true, instanceType = "raid", difficultyID = 15 })
    local before = W.ActiveLine({ enabled = false, when = {} }, snap)
    local gold = NS.addon.Settings.Groups.MutedGold()
    m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "obsidian")
    assertTrue(W.ActiveLine({ enabled = false, when = {} }, snap) ~= before, "the hint gray followed the skin")
    assertTrue(NS.addon.Settings.Groups.MutedGold() ~= gold, "the Reuse group gold followed the skin")
    assertTrue(NS.SkinMarkup("no.such.token", "x") == "x", "a token the skin leaves alone draws the text bare")
end)

-- ── the tool surfaces ────────────────────────────────────────────────────────────────────────────

test("skin tools: the debug console and its copy window are painted for this owner", function()
    -- red under: a console descriptor without addonName, or one with a host skin hook of its own.
    local src = readFile("core/DebugLogSetup.lua")
    assertTrue(src:find("addonName%s*=%s*addonName") ~= nil, "the console descriptor names the folder")
    assertTrue(src:find("applySkin%s*=") == nil and src:find("%f[%w]skin%s*=%s*{") == nil,
        "a host skin hook opts the console out of its owner")
    local NS, _, m = T.enableAddon()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    NS.DebugLog:Show()
    local f = NS.DebugLog._frameForTest
    assertTrue(f ~= nil, "the console frame")
    local rec = Skin.painted and Skin.painted[f]
    assertTrue(rec ~= nil and rec.owner == OWNER, "the console window is recorded for " .. OWNER)
    NS.DebugLog:ShowCopy()
    local cf = NS.DebugLog._copyFrameForTest
    assertTrue(cf ~= nil, "the console's copy window")
    assertTrue(rawget(cf, "__copyDesc") ~= nil, "the copy window was not painted for an owner")
end)

test("skin tools: the perf panel is painted for this owner", function()
    local src = readFile("core/PerfSetup.lua")
    assertTrue(src:find("addonName%s*=%s*addonName") ~= nil, "the Perf descriptor's addonName")
    local NS, _, m = T.enableAddon()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    NS.Perf.ShowPanel()
    local f = NS.Perf.__panel and NS.Perf.__panel()
    assertTrue(f ~= nil, "the perf panel frame")
    local rec = Skin.painted and Skin.painted[f]
    assertTrue(rec ~= nil and rec.owner == OWNER, "the perf panel is recorded for " .. OWNER)
    NS.Perf.HidePanel()
end)
