-- tests/test_master.lua — the Master controls the Comms Pad brings back (options-ui-§15): the lock
-- and test mode, each driven from the panel row, the verb and the launcher entry through ONE
-- handler (slash-commands-§8, launcher-§2, preview-mode).

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

test("master: the frame defaults are spec §5.1's: always shown, scale and alpha 1, locked", function()
    local NS = T.bootAddon()
    local p = NS.db.profile
    assertEqual(p.visibility, "always")
    assertEqual(p.scale, 1.0)
    assertEqual(p.alpha, 1.0)
    assertEqual(p.locked, true)
end)

test("master: /qc unlock and /qc lock write the Lock frame row's path and confirm on one line", function()
    local NS, m = T.enableAddon()
    m.prints = {}
    NS.addon:OnSlashCommand("unlock")
    assertFalse(NS.Setting("locked"))
    assertEqual(#m.prints, 1)
    NS.addon:OnSlashCommand("lock")
    assertTrue(NS.Setting("locked"))
end)

test("master: the launcher's Locked and Test mode entries call the same handlers", function()
    local NS, m = T.enableAddon()
    local boxes = openMenu(m).boxes
    assertEqual(boxes[2].label, "Locked")
    assertEqual(boxes[3].label, "Test mode")
    boxes[2].click()
    assertFalse(NS.Setting("locked"))
    boxes[3].click()
    assertTrue(NS.Preview.IsTestMode())
end)

test("master: /qc test toggles test mode, and in combat says why it will not", function()
    local NS, m = T.enableAddon()
    NS.addon:OnSlashCommand("test")
    assertTrue(NS.Preview.IsTestMode())
    NS.addon:OnSlashCommand("test")
    assertFalse(NS.Preview.IsTestMode())
    combat(m, true)
    m.prints = {}
    NS.addon:OnSlashCommand("test")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.prints, 1)
end)

test("master: the Test mode row reads and writes the one switch, and Reset all ends it", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    S.Set("state.testMode", true)
    assertTrue(NS.Preview.IsTestMode())
    assertTrue(S.Get("state.testMode"))
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    -- red under: drop the state.testMode entry from SESSION in settings/Schema.lua
    assertFalse(NS.Preview.IsTestMode())
end)
