-- tests/test_preview_window.lua — the "Preview as…" selector window (modules/PreviewWindow.lua,
-- design-qc-preview §2.2): shown exactly while a Preview as preview is on, from every entry point;
-- its dropdown, End preview, close mark and Escape; combat, test mode, the stand-down; the position
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
    NS.SchemaRuntime.Set("state.previewAs", "raid:heroic")
    assertTrue(NS.PreviewWindow.IsShown())
    assertEqual(win(NS).dropdown._value, "raid:heroic")
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
    assertEqual(rawget(f, "__strata"), "DIALOG")
    assertEqual(select(1, f:GetPoint(1)), "TOP", "the default place")
    assertEqual(select(5, f:GetPoint(1)), -140)
    NS.Preview.SetPreviewAs("arena")
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
