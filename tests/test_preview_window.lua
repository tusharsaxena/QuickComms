-- tests/test_preview_window.lua — the "Preview as…" selector window (modules/PreviewWindow.lua,
-- design-qc-preview §2.2): shown while a Preview as preview or the edit preview is on (QF-02), from
-- every entry point; its dropdown, End preview, close mark and Escape; combat, test mode, the stand-down; the position
-- kept in the profile; the degraded install.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live(inputs, opts)
    local NS, m = T.enableAddon(opts)
    NS.Situation.ReadInputs = function() return inputs or { inGroup = false } end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function win(NS) return NS.PreviewWindow.__frame() end

-- What CloseSpecialWindows (Escape) does to a special frame: its own flag goes off, OnHide runs.
local function escape(f)
    f:Hide()
    f:__fire("OnHide")
end

local function armed(NS)
    local b = NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
    return b and b:GetAttribute("macrotext") == "/p Pulling next pack"
end

test("preview window: hidden until a preview starts; SetPreviewAs shows it with the dropdown on that situation", function()
    local NS = live()
    assertFalse(NS.PreviewWindow.IsShown())
    assertTrue(win(NS) == nil, "built lazily, on the first show")
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    -- red under: drop the PreviewWindow.Sync call from Preview's announce()
    assertTrue(NS.PreviewWindow.IsShown())
    assertEqual(win(NS).dropdown._value, "arena")
    assertEqual(win(NS).title.text or win(NS).title:GetText(), "Ka0s Quick Comms - Preview")
end)

test("preview window: the settings row starts it too and the dropdown follows the slash", function()
    local NS = live()
    NS.SchemaRuntime.Set("state.previewAs", "raid:2912")
    assertTrue(NS.PreviewWindow.IsShown())
    assertEqual(win(NS).dropdown._value, "raid:2912")
    NS.addon:OnSlashCommand("preview bg:ab")
    -- red under: fill the dropdown once at build instead of on every Sync
    assertEqual(win(NS).dropdown._value, "bg:ab")
end)

test("preview window: the dropdown lists every preset, Current first, and no Off", function()
    local NS = live()
    NS.Preview.SetPreviewAs("world")
    local options = win(NS).dropdown._options
    local presets = NS.Preview.Presets()
    -- red under: build the options from NS.Preview.Choices() (it leads with Off)
    assertEqual(#options, #presets)
    for i, e in ipairs(presets) do
        assertEqual(options[i].value, e.key)
        assertEqual(options[i].label, e.label)
    end
    assertEqual(options[1].value, "current")
    for _, o in ipairs(options) do assertTrue(o.value ~= "off", "no Off entry") end
end)

test("preview window: picking in the dropdown switches the preview", function()
    local NS, m = live()
    NS.Preview.SetPreviewAs("arena")
    m.prints = {}
    -- red under: an onSelect that only relabels the dropdown
    win(NS).dropdown.onSelect("world")
    assertEqual(NS.Preview.PreviewAs(), "world")
    assertEqual(NS.Surfaces.Plans().p1.preview, "world")
    assertTrue(NS.PreviewWindow.IsShown())
    assertEqual(#m.prints, 0, "no chat line")
end)

test("preview window: End preview, the close mark and Escape each end the preview and hide it", function()
    local NS, m = live(MPLUS)
    local function check(how)
        assertTrue(NS.Preview.PreviewAs() == nil, how)
        assertFalse(NS.PreviewWindow.IsShown(), how)
        assertTrue(armed(NS), how .. ": the live buttons are back")
    end
    NS.Preview.SetPreviewAs("arena")
    m.prints = {}
    -- red under: an End button that only hides the frame
    m.__click(win(NS).endButton)
    check("End preview")
    assertEqual(#m.prints, 0, "no chat line")
    NS.Preview.SetPreviewAs("arena")
    win(NS).closeButton:__fire("OnClick", "LeftButton")
    check("close mark")
    NS.Preview.SetPreviewAs("arena")
    -- red under: leave onHide's endPreview out (Escape would hide the window and keep the preview)
    escape(win(NS))
    check("Escape")
    assertEqual(#m.blocked, 0)
end)

test("preview window: a hidden parent does not end the preview", function()
    local NS = live()
    NS.Preview.SetPreviewAs("arena")
    -- red under: an onHide without the `not self:IsShown()` guard (Alt+Z would end the preview)
    win(NS):__fire("OnHide")
    assertEqual(NS.Preview.PreviewAs(), "arena")
    assertTrue(NS.PreviewWindow.IsShown())
end)

test("preview window: combat ends it with the one line and hides the window", function()
    local NS, m = live(MPLUS)
    NS.Preview.SetPreviewAs("arena")
    m.prints = {}
    combat(m, true)
    assertTrue(NS.Preview.PreviewAs() == nil)
    -- red under: a Sync that never hides (the window would outlive the preview)
    assertFalse(NS.PreviewWindow.IsShown())
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview ended: you entered combat.", 1, true) ~= nil, m.prints[1])
    assertEqual(#m.blocked, 0)
end)

test("preview window: test mode, the stand-down and `/qc preview off` hide it", function()
    local NS = live()
    NS.Preview.SetPreviewAs("arena")
    NS.Preview.SetTestMode(true)
    assertFalse(NS.PreviewWindow.IsShown(), "test mode has no window")
    NS.Preview.SetPreviewAs("arena")
    NS.SchemaRuntime.Set("enabled", false)
    -- red under: drop the Sync call from Preview's NS.STAND_DOWN entry (the stand-down announces nothing)
    assertFalse(NS.PreviewWindow.IsShown(), "the stand-down")
    NS.SchemaRuntime.Set("enabled", true)
    NS.Preview.SetPreviewAs("arena")
    assertTrue(NS.PreviewWindow.IsShown())
    NS.addon:OnSlashCommand("preview off")
    assertFalse(NS.PreviewWindow.IsShown(), "/qc preview off")
end)

test("preview window: bare `/qc preview` opens it on Current; again keeps the situation", function()
    local NS, m = live()
    m.prints = {}
    NS.addon:OnSlashCommand("preview")
    -- red under: a bare `/qc preview` that prints the menu and starts nothing
    assertEqual(NS.Preview.PreviewAs(), "current")
    assertTrue(NS.PreviewWindow.IsShown())
    assertEqual(win(NS).dropdown._value, "current")
    assertTrue(m.prints[#m.prints]:find("Previewing: Current", 1, true) ~= nil, m.prints[#m.prints])
    NS.addon:OnSlashCommand("preview arena")
    m.prints = {}
    NS.addon:OnSlashCommand("preview")
    -- red under: a bare `/qc preview` that always restarts Current
    assertEqual(NS.Preview.PreviewAs(), "arena")
    assertTrue(NS.PreviewWindow.IsShown())
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Previewing: Arena", 1, true) ~= nil, m.prints[1])
end)

test("preview window: bare `/qc preview` in combat refuses with one line and shows nothing", function()
    local NS, m = live(MPLUS)
    combat(m, true)
    m.prints = {}
    NS.addon:OnSlashCommand("preview")
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertFalse(NS.PreviewWindow.IsShown())
    -- red under: a "Previewing:" line printed after the refusal
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview is not available in combat.", 1, true) ~= nil, m.prints[1])
    assertEqual(#m.blocked, 0)
end)

test("preview window: `/qc preview list` changes nothing and shows no window", function()
    local NS, m = live()
    m.prints = {}
    NS.addon:OnSlashCommand("preview list")
    -- red under: `list` read as a situation name
    assertTrue(NS.Preview.PreviewAs() == nil)
    assertFalse(NS.PreviewWindow.IsShown())
    assertTrue(m.prints[1]:find("Preview as (now: Off):", 1, true) ~= nil, m.prints[1])
    assertTrue(table.concat(m.prints, "\n"):find("raid:2912", 1, true) ~= nil)
end)

test("preview window: a refused start never shows it", function()
    local NS, m = live()
    combat(m, true)
    assertFalse(NS.Preview.SetPreviewAs("arena"))
    -- red under: a Sync that shows on any announce, whatever PreviewAs() answers
    assertFalse(NS.PreviewWindow.IsShown(), "in combat")
    combat(m, false)
    NS.addon:OnSlashCommand("disable")
    assertFalse(NS.Preview.SetPreviewAs("arena"))
    assertFalse(NS.PreviewWindow.IsShown(), "disabled")
end)

test("preview window: closing the settings window keeps the preview and the window", function()
    local NS, m = live()
    NS.Preview.SetPreviewAs("arena")
    m.SettingsPanel:__fire("OnHide")
    -- red under: a WatchPanel OnHide that ends Preview as again
    assertEqual(NS.Preview.PreviewAs(), "arena")
    assertTrue(NS.PreviewWindow.IsShown())
end)

test("preview window: Escape list, strata, movable, and a position kept in the profile", function()
    local NS, m = live()
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        rawset(f, "SetFrameStrata", function(self, v) rawset(self, "__strata", v); return self end)
        -- The client's Raise: the frame to the top of its strata, over a modal's catcher and band
        -- there (QC-06 review). red under: Raise the window on every Sync
        rawset(f, "Raise", function(self) self:SetFrameLevel(10000) end)
        return f
    end
    for _ = 1, 3 do
        NS.Preview.SetPreviewAs("arena")
        NS.Preview.SetPreviewAs("off")
    end
    m.CreateFrame = create
    local n = 0
    for _, name in ipairs(m.UISpecialFrames) do
        if name == "QuickCommsPreviewWindow" then n = n + 1 end
    end
    -- red under: insert into UISpecialFrames on every Sync instead of once at build
    assertEqual(n, 1, "listed once")
    local f = win(NS)
    -- red under: leave the window in DIALOG, the preview dial's strata, where the hub draws over it
    -- (QC-06); FULLSCREEN, under the callout popup's catcher by level
    assertEqual(rawget(f, "__strata"), "FULLSCREEN")
    local order = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
        FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
    -- the dial's secure header is DIALOG (modules/SendEngine.lua); the window is over it by strata
    assertTrue(order[rawget(f, "__strata")] > order.DIALOG, "over the preview dial")
    assertTrue(f:GetFrameLevel() < NS.addon.Settings.ModalWindow.LEVEL, "under a modal's catcher")
    assertEqual(select(1, f:GetPoint(1)), "TOP", "the default place")
    assertEqual(select(5, f:GetPoint(1)), -140)
    NS.Preview.SetPreviewAs("arena")
    assertTrue(f:GetFrameLevel() < NS.addon.Settings.ModalWindow.LEVEL, "a re-show leaves the level alone")
    f:ClearAllPoints()
    f:SetPoint("CENTER", m.UIParent, "CENTER", 50, 20)
    f:__fire("OnDragStop")
    -- red under: keep the point in a file-local (session-only: a /reload forgets it)
    local saved = NS.db.profile.previewWindow
    assertEqual(saved.point, "CENTER")
    assertEqual(saved.x, 50)
    assertEqual(saved.y, 20)
    NS.Preview.SetPreviewAs("off")
    NS.Preview.SetPreviewAs("world")
    assertEqual(select(1, f:GetPoint(1)), "CENTER", "end and restart: the same place")
    assertEqual(select(4, f:GetPoint(1)), 50)
    -- A /reload: the next load reads the saved place.
    local NS2 = live(nil, { sv = _G.QuickCommsDB })
    NS2.Preview.SetPreviewAs("arena")
    assertEqual(select(1, win(NS2):GetPoint(1)), "CENTER", "restored after a /reload")
    assertEqual(select(5, win(NS2):GetPoint(1)), 20)
    -- A profile switch moves a shown window to that profile's place (the default for a new one).
    NS2.addon.db:SetProfile("Second")
    assertEqual(select(1, win(NS2):GetPoint(1)), "TOP", "the new profile's place")
end)

test("preview window: the dropdown's menu closes with the window", function()
    local NS, m = live()
    local W = m.LibStub("LibKa0s-Widgets-1.0", true)
    local real, calls = W.CloseMenu, 0
    W.CloseMenu = function() calls = calls + 1 end
    NS.Preview.SetPreviewAs("arena")
    -- red under: an onHide without the W.CloseMenu call (an open menu would float on)
    escape(win(NS))
    W.CloseMenu = real
    assertTrue(calls >= 1, "CloseMenu ran from OnHide")
    assertTrue(NS.Preview.PreviewAs() == nil)
end)

test("preview window: degraded install previews without a window", function()
    local NS, m = live(nil, { skip = T.loadAddon.libFiles })
    m.prints = {}
    -- red under: a Sync without the W.Dropdown guard (it would index a nil library)
    NS.addon:OnSlashCommand("preview arena")
    assertEqual(NS.Preview.PreviewAs(), "arena")
    assertTrue(NS.PreviewWindow.__frame() == nil, "no window")
    assertFalse(NS.PreviewWindow.IsShown())
end)

-- ── the window over the edit preview (QF-02, owner 2026-10-23) ──────────────────────────────────
--
-- "Preview while editing" on the Groups page puts the window up too: titled with the group, its
-- dropdown on the group's own situation and the window locked, since the page drives it (QF-07).
-- `/qc preview off` ends it and turns the setting off; Escape ends it for the session only, and the
-- page's own re-syncs leave it off until a new start.

local function editing()
    local NS, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Raid only", callouts = { cid }, when = { content = { raid = true } } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    NS.addon.Settings.Editors.Select("group", gid)
    P.show("Groups")
    P.flush()
    return NS, m, P, gid
end

local function titleOf(NS)
    local t = win(NS).title
    return t.text or t:GetText()
end

test("preview window: [QF-07] over the edit preview it is locked: dimmed, its controls off, a tooltip says why", function()
    local NS, m, _, gid = editing()
    assertEqual(NS.Preview.EditGroup(), gid)
    assertTrue(NS.Preview.PreviewAs() == nil, "no Preview as underneath")
    assertTrue(NS.PreviewWindow.IsShown(), "the edit preview shows the window")
    assertEqual(titleOf(NS), "Ka0s Quick Comms - Preview: Raid only")
    local f = win(NS)
    -- red under: a window that leaves its controls live over the edit preview
    assertFalse(f.dropdown:IsEnabled(), "the dropdown is off")
    assertFalse(f.endButton:IsEnabled(), "End preview is off")
    assertFalse(f.closeButton:IsEnabled(), "the close mark is off")
    assertTrue(f.dropdown:GetAlpha() < 1 and f.endButton:GetAlpha() < 1 and f.closeButton:GetAlpha() < 1, "all dimmed")
    -- A click that reaches them anyway ends nothing.
    f.endButton:__fire("OnClick", "LeftButton")
    f.closeButton:__fire("OnClick", "LeftButton")
    assertEqual(NS.Preview.EditGroup(), gid, "End preview and the close mark end nothing")
    assertEqual(NS.Setting("behavior.previewOnEdit"), true)
    -- Preview as ended underneath leaves the window up over the edit preview.
    NS.addon:OnSlashCommand("preview arena")
    NS.Preview.SetPreviewAs("off")
    assertTrue(NS.PreviewWindow.IsShown(), "Preview as off, the edit preview still on")
    -- A pick that reaches it anyway (the menu was already open) changes nothing.
    f.dropdown.onSelect("arena")
    assertTrue(NS.Preview.PreviewAs() == nil, "a pick is ignored")
    assertEqual(NS.Preview.EditGroup(), gid)
    -- red under: a disabled control the client never sends OnEnter (the owner saw no tooltip)
    for _, c in ipairs({ f.dropdown, f.endButton, f.closeButton }) do
        assertTrue(c:GetMotionScriptsWhileDisabled(), "hover reaches a disabled control")
    end
    f.dropdown:__fire("OnEnter")
    local said = table.concat((function()
        local out = {}
        for _, l in ipairs(m.GameTooltip.__lines) do out[#out + 1] = tostring(l[1]) end
        return out
    end)(), " | ")
    assertTrue(said:find("disabled while you edit a group", 1, true) ~= nil, said)
    assertTrue(said:find("Pick another group", 1, true) ~= nil, said)
    -- Out of the edit preview it is live again.
    NS.addon:OnSlashCommand("preview off")
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    f = win(NS)
    assertTrue(f.dropdown:IsEnabled() and f.endButton:IsEnabled(), "Preview as alone: live")
    assertEqual(f.dropdown:GetAlpha(), 1)
    f.dropdown.onSelect("world")
    assertEqual(NS.Preview.PreviewAs(), "world")
    assertEqual(#m.blocked, 0)
end)

test("preview window: [QF-07] the dropdown follows the edited group's situation, and the pads bake under it", function()
    local NS, _, P, gid = editing()
    -- red under: a dropdown that shows Current over the edit preview
    local firstRaid = "raid:" .. NS.Preview.Presets()[2 + #NS.GameIds.DUNGEONS].instanceID
    assertEqual(NS.Preview.EditPresetKey(gid), firstRaid)
    assertEqual(win(NS).dropdown._value, firstRaid, "a raid group: the season's first raid, A-Z")
    assertEqual(NS.Surfaces.Plans().p1.snapshot.content, "raid", "and the pads bake under it")
    local function pick(gidTo)
        P.banner(P.ctx("groups")):__fire("OnValueChanged", gidTo)
        P.flush()
        assertEqual(NS.Preview.EditGroup(), gidTo)
        return win(NS).dropdown._value
    end
    assertEqual(pick(T.seeded(NS, "bi.bg.av")), "bg:av", "Alterac Valley")
    assertEqual(pick(T.seeded(NS, "bi.bg.av.spgy")), "bg:av", "a node takes its battleground's")
    assertEqual(pick(T.seeded(NS, "bi.mplus")), NS.Preview.Presets()[2].key, "the season's first dungeon, A-Z")
    assertEqual(pick(T.seeded(NS, "bi.arena")), "arena")
    assertEqual(pick(T.seeded(NS, "bi.world")), "world")
    assertEqual(pick(T.seeded(NS, "bi.group")), "current", "a group with no content: Current")
    -- Preview as typed while editing is kept underneath; the window still follows the group.
    NS.addon:OnSlashCommand("preview arena")
    assertEqual(win(NS).dropdown._value, "current")
    assertTrue(NS.Preview.EditSnapshot() == NS.Situation.Current(), "the edit preview bakes where you are")
end)

test("preview window: [QF-07] the dropdown follows a When edited while the group is open", function()
    local NS, _, P, gid = editing()
    assertEqual(win(NS).dropdown._value:match("^raid:%d+$") ~= nil, true)
    -- red under: a dropdown filled only on announce (a When edit re-bakes the pads, no announce)
    assertTrue((NS.SchemaRuntime.Set("group.when", { content = { arena = true } }, gid)))
    P.flush()
    assertEqual(NS.Surfaces.Plans().p1.snapshot.content, "arena")
    assertEqual(win(NS).dropdown._value, "arena", "the window names what the pads show")
    assertTrue((NS.SchemaRuntime.Set("group.when", { content = { raid = true }, instances = { [2939] = true } }, gid)))
    P.flush()
    assertEqual(win(NS).dropdown._value, "raid:2939", "the raid its Instance row lists")
end)

test("preview window: [QF-07] EditPresetKey maps each kind of When", function()
    local NS = editing()
    local Lib, key = NS.Library, NS.Preview.EditPresetKey
    local function g(when, extra)
        local f = { name = "G", when = when }
        for k, v in pairs(extra or {}) do f[k] = v end
        return Lib.CreateGroup(f)
    end
    local firstRaid = "raid:" .. NS.Preview.Presets()[2 + #NS.GameIds.DUNGEONS].instanceID
    assertEqual(key(g({ content = { raid = true }, difficulty = { heroic = true } })), firstRaid,
        "no Instance row: the season's first raid")
    assertEqual(key(g({ content = { raid = true }, instances = { [2913] = true } })), "raid:2913")
    assertEqual(key(g({ content = { mythicPlus = true }, instances = { [658] = true } })), "mplus:658")
    assertEqual(key(g({ content = { dungeon = true }, instances = { [1] = true } })), NS.Preview.Presets()[2].key,
        "an Instance row of no season dungeon: the first")
    assertEqual(key(T.seeded(NS, "bi.bg")), "bg:ab", "every battleground: the first set")
    -- red under: an arena id row alone answered Current
    assertEqual(key(g({ arena = { [572] = true } })), "arena", "an arena id row alone")
    -- red under: an empty battleground row answered the first battleground
    assertEqual(key(g({ battleground = {} })), "current", "an empty battleground row is unset")
    local parent = g({ content = { mythicPlus = true } })
    assertEqual(key(g({}, { parent = parent })), NS.Preview.Presets()[2].key, "a child takes its parent's")
    assertEqual(key(g({ content = { arena = true } }, { parent = parent, inheritWhen = false })), "arena",
        "a child that does not inherit, its own")
end)

test("preview window: the edit preview bakes a raid group at Mythic, else its own first difficulty", function()
    local NS = editing()
    local Lib, P = NS.Library, NS.Preview
    local function snap(when)
        local gid = Lib.CreateGroup({ name = "R", when = when })
        P.SetEditPreview(nil)
        P.SetEditPreview(gid, true)
        return P.EditSnapshot()
    end
    assertEqual(snap({ content = { raid = true } }).difficulty, "mythic", "no Difficulty row: Mythic")
    assertEqual(snap({ content = { raid = true }, difficulty = { mythic = true, heroic = true } }).difficulty, "mythic")
    -- red under: a Heroic-only group previewed at Mythic, where it never shows
    local s = snap({ content = { raid = true }, difficulty = { heroic = true }, instances = { [2939] = true } })
    assertEqual(s.difficulty, "heroic")
    assertEqual(s.difficultyID, 15)
    assertEqual(s.instanceID, 2939)
    assertEqual(snap({ content = { raid = true }, difficulty = { story = true } }).difficulty, "normal")
    P.SetEditPreview(nil)
end)

test("preview window: [QF-02] End preview and the close mark end both and turn Preview while editing off", function()
    local NS, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    -- Outside the edit preview they are live: they end Preview as.
    NS.Preview.SetPreviewAs("arena")
    m.__click(win(NS).endButton)
    assertTrue(NS.Preview.PreviewAs() == nil, "End preview")
    assertFalse(NS.PreviewWindow.IsShown())
    NS.Preview.SetPreviewAs("arena")
    win(NS).closeButton:__fire("OnClick", "LeftButton")
    assertTrue(NS.Preview.PreviewAs() == nil, "the close mark")
    -- Called with the edit preview on (no window control reaches it now; the slash does), it turns
    -- the setting off and the page's re-syncs leave it off.
    local NS2, m2, P2, gid = editing()
    NS2.Preview.EndPreview()
    assertTrue(NS2.Preview.EditGroup() == nil and NS2.Preview.PreviewAs() == nil)
    assertEqual(NS2.db.profile.behavior.previewOnEdit, false, "the setting is off")
    P2.flush()
    P2.redraw("groups")
    assertTrue(NS2.Preview.EditGroup() == nil, "and the page's re-syncs leave it off")
    NS2.SchemaRuntime.Set("behavior.previewOnEdit", true)
    assertEqual(NS2.Preview.EditGroup(), gid)
    assertEqual(#m.blocked + #m2.blocked, 0)
    assertTrue(P ~= nil)
end)

test("preview window: [QF-02] Escape ends the edit preview for the session, the setting kept, until a new start", function()
    local NS, m, P, gid = editing()
    NS.addon:OnSlashCommand("preview arena")
    assertEqual(NS.Preview.PreviewAs(), "arena", "Preview as underneath")
    escape(win(NS))
    assertTrue(NS.Preview.EditGroup() == nil and NS.Preview.PreviewAs() == nil, "Escape ends both")
    assertFalse(NS.PreviewWindow.IsShown())
    assertEqual(NS.Setting("behavior.previewOnEdit"), true, "the saved switch is left alone")
    -- red under: Escape without the dismissal mark (the scheduled refresh's render restarts it)
    P.flush()
    assertTrue(NS.Preview.EditGroup() == nil, "the page's refresh leaves it off")
    assertFalse(NS.PreviewWindow.IsShown())
    P.redraw("groups")
    assertTrue(NS.Preview.EditGroup() == nil, "and any later render")
    combat(m, true)
    combat(m, false)
    assertTrue(NS.Preview.EditGroup() == nil, "and a combat end")
    assertFalse(NS.PreviewWindow.IsShown())
    -- A group switch is a new start.
    local mplus = T.seeded(NS, "bi.mplus")
    P.banner(P.ctx("groups")):__fire("OnValueChanged", mplus)
    P.flush()
    assertEqual(NS.Preview.EditGroup(), mplus, "a group switch starts the new group's preview")
    assertTrue(NS.PreviewWindow.IsShown())
    -- So is the page hidden and shown again.
    escape(win(NS))
    P.flush()
    assertTrue(NS.Preview.EditGroup() == nil)
    local panel = P.ctx("groups").panel
    panel:Hide()
    panel:__fire("OnHide")
    P.show("Groups")
    P.flush()
    assertEqual(NS.Preview.EditGroup(), mplus, "the page shown again starts it")
    assertTrue(gid ~= mplus)
end)

test("preview window: [QF-02] the settings window closing hides it; a hidden UIParent ends nothing", function()
    local NS, m, _, gid = editing()
    win(NS):__fire("OnHide")
    assertEqual(NS.Preview.EditGroup(), gid, "a hidden parent ends nothing")
    assertTrue(NS.PreviewWindow.IsShown())
    m.SettingsPanel:__fire("OnHide")
    assertTrue(NS.Preview.EditGroup() == nil)
    assertFalse(NS.PreviewWindow.IsShown(), "the window goes with the edit preview")
    assertEqual(NS.Setting("behavior.previewOnEdit"), true)
end)

test("preview window: [QF-02] `/qc preview off` ends the edit preview too; with nothing on it writes nothing", function()
    local NS, m = editing()
    m.prints = {}
    -- red under: PreviewLines keyed on PreviewAs() alone
    NS.addon:OnSlashCommand("preview off")
    assertTrue(NS.Preview.EditGroup() == nil)
    assertEqual(NS.db.profile.behavior.previewOnEdit, false)
    assertFalse(NS.PreviewWindow.IsShown())
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview off.", 1, true) ~= nil, m.prints[1])
    local NS2, m2 = live()
    local set, writes = NS2.SchemaRuntime.Set, 0
    NS2.SchemaRuntime.Set = function(...) writes = writes + 1; return set(...) end
    m2.prints = {}
    NS2.addon:OnSlashCommand("preview off")
    NS2.SchemaRuntime.Set = set
    assertEqual(writes, 0, "nothing on: no write")
    assertEqual(#m2.prints, 1)
    assertTrue(m2.prints[1]:find("Preview off.", 1, true) ~= nil, m2.prints[1])
end)
