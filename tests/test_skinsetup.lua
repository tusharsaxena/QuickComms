-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§1..§3; QC-01).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name with this addon's read and write seams and its own tokens; the
-- seven skin.* keys default to Ka0s Default and are skip-render schema rows on the Skin tab; the
-- tab is the library's, after Behavior and before Keybindings; the profile's skin is applied right
-- after AceDB exists and on every profile event; one pick from the tab, or from another addon's
-- copy, is ONE effective SetChoice (one OnLooksChanged, no reload request); every library factory
-- that takes an owner is handed it; the retired EllesmereUI bridge registers nothing of its own; and
-- without the library the degraded facade answers every name the live one carries, from a host copy
-- of Ka0s Default that must equal the library's.
--
-- Every case builds its own instance, so nothing leaks between cases.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "QuickComms"
local BRAND = "Ka0s Quick Comms"
local NO_LIBKA0S = T.loadAddon.libFiles

local KEYS = {
    { "source", "ka0s" }, { "skin", "ka0s" }, { "ignorePanel", true }, { "ignoreFonts", false },
    { "font", "" }, { "texture", "" }, { "outline", "hud" }, { "pickerSeen", false },
}

--- An enabled instance, its Skin major and a counter of this owner's looks changes and reload
--- requests.
local function setup(opts)
    local NS, _, m = T.enableAddon(opts)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local counts = { looks = 0, reloads = 0 }
    NS.Skin.OnLooksChanged(function() counts.looks = counts.looks + 1 end)
    Skin:OnReloadRequest(OWNER, function() counts.reloads = counts.reloads + 1 end)
    return NS, m, Skin, counts
end

local function slash(NS, line) NS.addon:OnSlashCommand(line) end

--- The General page drawn on `tab`; answers the ctx and the strip's tab keys (the render's).
local function openTab(NS, m, tab)
    local H = NS.addon.Settings.Helpers
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local keys
    local render = H.RenderTabbedSchema
    H.RenderTabbedSchema = function(...)
        local groups, tabKeys = render(...)
        keys = keys or tabKeys
        return groups, tabKeys
    end
    local ok, err = pcall(function()
        P.show("General")
        local ctx = P.ctx("general")
        ctx.activeTab = tab
        ctx._renderFn(ctx)
    end)
    H.RenderTabbedSchema = render
    if not ok then error(err, 0) end
    return P.ctx("general"), keys
end

--- Every widget the page drew, depth first.
local function flatten(ctx)
    local out = {}
    local function walk(w)
        out[#out + 1] = w
        for _, c in ipairs(w.children or {}) do walk(c) end
    end
    for _, w in ipairs(ctx.scroll.children) do walk(w) end
    return out
end

--- The Skin tab's check box (a radio choice or a Scope box) whose label ends with `name`.
local function choiceNamed(NS, m, name)
    local ctx = openTab(NS, m, "Appearance")
    for _, w in ipairs(flatten(ctx)) do
        local label = tostring(w.labelText or "")
        if w.type == "CheckBox" and label:sub(-#name) == name then return w, ctx end
    end
    return nil, ctx
end

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

local function assertColor(got, want, what)
    for i = 1, 4 do
        assertTrue(near(got and got[i], want[i]),
            ("%s[%d]: got %s, want %s"):format(what, i, tostring(got and got[i]), tostring(want[i])))
    end
end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────────

test("skin seam: the owner is the folder name, and NS.Skin is its facade", function()
    -- red under: registering under the brand or a typo (the library keys every frame and every
    -- listener by owner), or publishing a facade of some other owner.
    local NS, _, Skin = setup()
    assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
    assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"" .. OWNER .. "\")")
    assertEqual(NS.Skin.owner, OWNER)
    assertEqual(Skin:OwnerLabel(OWNER), BRAND, "the copy confirmation names the addon by its brand")
end)

test("skin seam: the owner is registered at file load, before the profile store exists", function()
    -- skinning-§1: at FILE LOAD, so the EllesmereUI provider offers it before EllesmereUI dispatches.
    -- red under: RegisterOwner moved into OnInitialize or OnEnable.
    local NS, _, m = T.newAddon()
    assertTrue(NS.addon.db == nil, "nothing has run OnInitialize")
    assertTrue(m.LibStub("LibKa0s-Skin-1.0"):IsOwner(OWNER), "not registered at file load")
end)

test("skin seam: the read answers Ka0s Default before the profile store exists", function()
    -- RegisterOwner calls `get` at FILE LOAD; a getter that raised there would be a Lua error on
    -- every login.
    local NS = T.newAddon()
    local ok, source, skin = pcall(NS.SkinChoice)
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
    local font, texture = NS.SkinOverride()
    assertEqual(font, false); assertEqual(texture, false)
end)

test("skin seam: EllesmereUI hears of this addon once, from the library alone", function()
    -- D1: Quick Comms's own bridge (core/EUIBridge.lua, settings/CalloutPopup_Skin.lua) registered
    -- the same name the library's EllesmereUI provider registers for the owner, and EllesmereUI keeps
    -- one callback per name. red under: a host RegisterSkin call left in.
    local names = {}
    local NS = T.newAddon{ mock = function(mk)
        mk.EllesmereUI = { RegisterSkin = function(name) names[#names + 1] = name end }
        mk.loadedAddons.EllesmereUIBlizzardSkin = true
    end }
    assertTrue(NS.Skin ~= nil, "the seam loaded")
    local n = 0
    for _, name in ipairs(names) do if name == OWNER then n = n + 1 end end
    assertEqual(n, 1, ("EllesmereUI.RegisterSkin(%q) calls"):format(OWNER))
    assertTrue(NS.EUIBridge == nil, "the retired bridge is gone")
    assertTrue(NS.addon.Settings.CalloutPopupSkin == nil, "the retired popup skin is gone")
end)

-- ── the owner tokens (skinning-§1; DECISIONS X1, X2, X12) ────────────────────────────────────────

test("skin seam: every owner token is in the qc namespace and answers today's pixels on Ka0s Default", function()
    -- red under: a token snapped to a library value (Ka0s Default would move), a name outside `qc.`
    -- (the library refuses it, and the color would read nil), or a follow the library rejects.
    local NS = setup()
    local n = 0
    for name, def in pairs(NS.SKIN_TOKENS) do
        n = n + 1
        assertTrue(name:sub(1, 3) == "qc.", name .. " is outside this addon's namespace")
        local r, g, b, a = NS.Skin.Color(name)
        assertTrue(r ~= nil, name .. " does not resolve: the library refused it")
        assertColor({ r, g, b, a }, def.default, name)
    end
    assertTrue(n >= 3, "QC-G1..G3 are owner tokens")
end)

test("skin seam: under another skin an owner token takes its follow token's value", function()
    -- X2: each follows the nearest library role token, so every skin draws it in its own palette;
    -- the two veils follow nothing and keep their black washes everywhere.
    local NS, _, Skin = setup()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local base = Skin:ResolveSkin("obsidian")
    for name, def in pairs(NS.SKIN_TOKENS) do
        local r, g, b, a = NS.Skin.Color(name)
        if def.follow then
            assertColor({ r, g, b, a }, base[def.follow], name .. " under Obsidian")
        else
            assertColor({ r, g, b, a }, def.default, name .. " under Obsidian")
        end
    end
end)

test("skin seam: an owner token reaches a markup escape byte for byte", function()
    -- The hint lines are written as |cffa0a0a0 today; the escape built from the token must match.
    local NS = setup()
    assertEqual(NS.SkinEscape("qc.hint"), "|cffa0a0a0")
    assertEqual(NS.SkinEscape("qc.inactive"), "|cffff6060")
    assertEqual(NS.SkinEscape("qc.preview"), "|cff19ff19")
    assertEqual(NS.SkinEscape("qc.note"), "|cffaaaaaa")
end)

-- ── the owner handed to every factory (skinning-§1) ──────────────────────────────────────────────

test("skin seam: Core's window edge is handed the owner", function()
    -- red under: NS.ApplySkin = lib.ApplySkin (an owner-less call draws Ka0s Default whatever the skin).
    local NS, m = setup()
    local core = m.LibStub("LibKa0s-Core-1.0")
    local real, seen = core.ApplySkin, nil
    core.ApplySkin = function(_, _, owner) seen = owner end
    local ok, err = pcall(NS.ApplySkin, m.CreateFrame("Frame"))
    core.ApplySkin = real
    if not ok then error(err, 0) end
    assertEqual(seen, OWNER)
end)

test("skin seam: the drag strip, the Preview dropdown and the reorder list are handed the owner", function()
    -- red under: drop `spec.owner` from core/WidgetsSetup.lua, `owner` from modules/PreviewWindow.lua's
    -- W.Dropdown opts, or `owner` from settings/Editors.lua's W.ReorderList spec.
    local NS, m = setup()
    local W = m.LibStub("LibKa0s-Widgets-1.0")
    local seen = {}
    local real = { DragHandle = W.DragHandle, Dropdown = W.Dropdown, ReorderList = W.ReorderList }
    W.DragHandle = function(parent, spec) seen.DragHandle = spec.owner; return real.DragHandle(parent, spec) end
    W.Dropdown = function(parent, w, opts) seen.Dropdown = opts and opts.owner; return real.Dropdown(parent, w, opts) end
    W.ReorderList = function(spec) seen.ReorderList = spec.owner; return real.ReorderList(spec) end
    local ok, err = pcall(function()
        NS.MakeDragHandle(m.CreateFrame("Frame"), { label = "x" })
        NS.Preview.SetPreviewAs("arena")
        NS.Preview.SetPreviewAs("off")
        -- A group's Callouts tab draws its rows through Ed.ReorderRows.
        local P = dofile("tests/page_helpers.lua")(NS, m)
        P.show("Groups")
        local gid = NS.Library.CreateGroup({ name = "Mine" })
        NS.Library.CreateCalloutIn(gid, { name = "A", text = "a", channel = "party" })
        NS.Library.CreateCalloutIn(gid, { name = "B", text = "b", channel = "party" })
        NS.addon.Settings.Editors.Select("group", gid)
        P.tab("groups", "callouts")
    end)
    W.DragHandle, W.Dropdown, W.ReorderList = real.DragHandle, real.Dropdown, real.ReorderList
    if not ok then error(err, 0) end
    assertEqual(seen.DragHandle, OWNER, "the drag strip")
    assertEqual(seen.Dropdown, OWNER, "the Preview as dropdown")
    assertEqual(seen.ReorderList, OWNER, "an editor page's reorder list")
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────────

test("skin seam: the eight skin keys default to Ka0s Default, the picker unseen", function()
    -- red under: a default other than today's look, or pickerSeen true (owner ruling O3: every
    -- profile, old and new, gets the first-run picker).
    local NS = T.bootAddon()
    local p = NS.addon.db.profile.skin
    for _, kv in ipairs(KEYS) do assertEqual(p[kv[1]], kv[2], "skin." .. kv[1]) end
end)

test("skin seam: every skin key is a skip-render schema row on the Skin tab", function()
    -- red under: a row that renders itself on top of the library's controls, or one outside the
    -- tab's group (the host tab keyed "Appearance" takes that group's place in the strip).
    local NS = T.newAddon()
    local H = NS.addon.Settings.Helpers
    for _, kv in ipairs(KEYS) do
        local path = "skin." .. kv[1]
        local row = H.FindSchema(path)
        assertTrue(row ~= nil, path .. " is not a schema row")
        assertEqual(row.page, "general", path .. ": page")
        assertEqual(row.group, "Appearance", path .. ": group")
        assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
        assertEqual(row.default, kv[2], path .. ": default")
    end
end)

test("skin seam: the skin row's values are every registered skin, in the library's order", function()
    local NS, _, m = T.newAddon()
    local values = NS.addon.Settings.Helpers.FindSchema("skin.skin").values
    local skins = m.LibStub("LibKa0s-Skin-1.0"):Skins()
    assertEqual(#values, #skins, "one value per registered skin")
    for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
    assertEqual(values[1].value, "ka0s", "Ka0s Default first")
end)

test("skin seam: /qc set refuses a skin that is not registered and applies one that is", function()
    local NS, _, Skin, counts = setup()
    slash(NS, "set skin.skin no-such-skin")
    assertEqual(NS.addon.db.profile.skin.skin, "ka0s", "an unknown skin was stored")
    assertEqual(counts.looks, 0, "a refused set repainted")
    slash(NS, "set skin.skin obsidian")
    assertEqual(NS.addon.db.profile.skin.skin, "obsidian", "a registered skin was refused")
    local _, applied = Skin:GetChoice(OWNER)
    assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
    assertEqual(counts.looks, 1, "one set, one repaint")
end)

test("skin seam: /qc set reaches an exception, and only its own half", function()
    local NS, _, Skin = setup()
    slash(NS, "set skin.ignoreFonts true")
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the set applied")
    assertEqual(panel, true, "the other half untouched (the default ignores the settings panel)")
end)

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────────

test("skin seam: the Skin tab is the library's, after Behavior and before Keybindings", function()
    -- skinning-§3: immediately before Keybindings, Master controls first. red under: no
    -- AppearanceTab entry, or the skin rows declared ahead of Behavior.
    local NS, m = setup()
    local ctx, keys = openTab(NS, m, "Appearance")
    assertTrue(type(keys) == "table", "the strip was drawn")
    assertEqual(table.concat(keys, ","), "Master controls,Behavior,Appearance,Keybindings")
    assertEqual(ctx.activeTab, "Appearance")
    assertTrue(choiceNamed(NS, m, "Obsidian") ~= nil, "the tab drew no Obsidian choice")
end)

test("skin seam: one tab pick is one effective SetChoice, one repaint and no reload", function()
    -- The tab calls SetChoice first, then the write seam, which writes both rows through
    -- NS.SchemaRuntime.Set; each row's onChange applies only its own half and finds it applied.
    -- red under: an onChange that re-applies the whole stored pair, or a seam around the schema.
    local NS, m, Skin, counts = setup()
    local cb = choiceNamed(NS, m, "Obsidian")
    assertTrue(cb ~= nil, "the Skin tab drew no Obsidian choice")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    assertEqual(counts.looks, 1, "one pick must repaint exactly once")
    assertEqual(counts.reloads, 0, "a Ka0s-to-Ka0s pick asks for no reload")
    local source, skin = Skin:GetChoice(OWNER)
    assertEqual(source, "ka0s")
    assertEqual(skin, "obsidian", "the pick did not move the applied skin")
    assertEqual(NS.addon.db.profile.skin.skin, "obsidian", "the pick did not reach the profile")
end)

test("skin seam: the tab's Ignore fonts reaches the library and the profile, one repaint", function()
    local NS, m, Skin, counts = setup()
    local cb = choiceNamed(NS, m, "Ignore fonts")
    assertTrue(cb ~= nil, "the Skin tab drew no Ignore fonts box")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the library's exception moved")
    assertEqual(panel, true, "and the other kept")
    assertEqual(NS.addon.db.profile.skin.ignoreFonts, true, "the profile holds it")
    assertEqual(counts.looks, 1, "one toggle repaints once")
end)

test("skin seam: another addon's copy to every Ka0s addon repaints this one once", function()
    -- The library's copy calls SetChoice for this owner, then WriteChoice, which reaches this addon's
    -- registered setter. Driven through a fake second owner.
    local NS, _, Skin, counts = setup()
    Skin:RegisterOwner("SkinProbeAddon", { label = "Skin Probe",
        get = function() return "ka0s", "ember" end, set = function() end })
    Skin:SetChoice(OWNER, "ka0s", "ember")
    assertTrue(Skin:WriteChoice(OWNER, "ka0s", "ember"), "the copy's write did not reach this addon's setter")
    assertEqual(counts.looks, 1, "a copy must repaint this addon exactly once")
    assertEqual(NS.addon.db.profile.skin.skin, "ember", "the copy did not land in the profile")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ember")
end)

-- ── the profile: login and the profile events ────────────────────────────────────────────────────

test("skin seam: login applies the stored skin, exceptions and overrides", function()
    -- red under: no NS.ApplySkinChoice() in OnInitialize, or one that applies only the pair.
    local first = T.bootAddon()
    local p = first.addon.db.profile.skin
    p.skin, p.ignorePanel, p.ignoreFonts, p.texture = "glass", false, true, "Blizzard"
    local saved = _G.QuickCommsDB
    local _, _, m = T.bootAddon{ sv = saved }
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the stored skin")
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(panel, false, "the stored panel exception")
    assertEqual(fonts, true, "the stored fonts exception")
    assertEqual(select(2, Skin:GetOverride(OWNER)), "Blizzard", "the stored texture override")
end)

test("skin seam: a profile switch applies the new profile's skin, pages built or not", function()
    -- red under: applying the skin inside a page refresh (a page may never have been built), or not
    -- at all on a switch.
    local NS, _, Skin, counts = setup()
    local db = NS.addon.db
    db:SetProfile("SkinProbe")
    db.profile.skin.skin = "glass"
    db:SetProfile("Default")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "back on Default, Default's skin")
    counts.looks = 0
    db:SetProfile("SkinProbe")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the switch did not move the applied skin")
    assertEqual(counts.looks, 1, "one switch, one repaint")
end)

test("skin seam: Reset all settings puts the skin back on Ka0s Default and applies it", function()
    -- skinning-§3: a reset reaches the choice as a profile value, and re-applies it.
    local NS, _, Skin = setup()
    slash(NS, "set skin.skin ember")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ember")
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(NS.addon.db.profile.skin.skin, "ka0s", "the stored skin reset")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the applied skin followed")
end)

-- ── the diagnostics line ─────────────────────────────────────────────────────────────────────────

test("skin seam: the diagnostics report names the skin and the EllesmereUI gate", function()
    -- D1: the retired bridge's `ellesmereui: suite= ...` line becomes the library's GetEUIStatus,
    -- read through core/SkinSetup.lua. red under: the integrations section without the line.
    local NS = setup()
    NS.DebugLog:Clear()
    slash(NS, "diagnostics")
    local report = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(report:find("skin: source=ka0s skin=ka0s ellesmereui: ok=false painted=false", 1, true) ~= nil,
        "no skin line in the report")
    assertTrue(report:find("failing=eui", 1, true) ~= nil, "without EllesmereUI the first condition fails")
end)

-- ── without the library ──────────────────────────────────────────────────────────────────────────

test("skin seam: the degraded facade answers every name the live facade carries", function()
    -- skinning-§1, testing-§8: without LibKa0s NS.Skin is a host table whose primitives are no-ops
    -- and whose Token / Color / Text answer the host copy NS.SKIN_FALLBACK and the owner tokens.
    local live = T.newAddon()
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(live.Skin, degraded.Skin, "Skin facade vs host stub", {})
    assertEqual(degraded.Skin.owner, OWNER)
    local r, g, b = degraded.SkinColor("text.disabled")
    assertEqual(r, 0.5); assertEqual(g, 0.5); assertEqual(b, 0.5)
    assertEqual(degraded.SkinEscape("text.accent"), "|cffffd100")
    assertEqual(degraded.SkinEscape("qc.hint"), "|cffa0a0a0", "an owner token's default degraded")
    assertEqual(degraded.ApplySkinChoice(), false, "nothing to apply without the library")
    assertTrue(type(degraded.SkinDescribe()) == "string")
end)

test("skin seam: each host-copy skin token is the live library's Ka0s Default value", function()
    -- A copy that drifts from the library goes red here, so a degraded install draws Ka0s Default.
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    local _, _, m = T.newAddon()
    local live = m.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("ka0s")
    local n = 0
    for name, c in pairs(degraded.SKIN_FALLBACK) do
        n = n + 1
        local want = live[name]
        assertTrue(want ~= nil, name .. " is not a library token")
        -- QC-03's HUD reads four scalar tokens too (the face and the border styles and size)
        if type(want) == "table" then assertColor(c, want, name) else assertEqual(c, want, name) end
    end
    assertTrue(n > 0, "the host copy is empty")
end)
