-- tests/test_eui_skin.lua — settings/CalloutPopup_Skin.lua and core/EUIBridge.lua: the callout
-- popup painted the way EllesmereUI paints Blizzard's settings window, when EllesmereUI, its Blizzard
-- Skin module are loaded and the facade's S.IsEnabled() says its third-party skinning and this addon's
-- entry are on. EllesmereUI is mocked: RegisterSkin keeps the callback, and the facade records every
-- primitive it is handed. No EllesmereUIDB is mocked: the addon never reads it.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- A mocked EllesmereUI on mock `mk`, before any source loads. `opts.noChild` leaves the Blizzard Skin module unloaded, `opts.noRegister` drops RegisterSkin.
local function withEUI(opts)
    opts = opts or {}
    local eui = { registered = {} }
    return eui, function(mk)
        mk.EllesmereUI = {}
        if not opts.noRegister then
            mk.EllesmereUI.RegisterSkin = function(name, fn) eui.registered[name] = fn end
        end
        if not opts.noChild then mk.loadedAddons.EllesmereUIBlizzardSkin = true end
    end
end

-- A facade that records each paint call as { primitive, frame }. `enabled` is what S.IsEnabled()
-- answers (true unless given), or a function that stands in for it.
local function facade(enabled)
    local S, calls = { apiVersion = 3 }, {}
    for _, name in ipairs({ "Shell", "FadeNineSlice", "CloseButton", "Button", "EditBox" }) do
        S[name] = function(frame) calls[#calls + 1] = { name, frame } end
    end
    if type(enabled) == "function" then
        S.IsEnabled = enabled
    else
        S.IsEnabled = function() return enabled ~= false end
    end
    return S, calls
end

-- The skin's state as the diagnostics report reads it: applied, and whether EllesmereUI called back.
local function applied(NS)
    return NS.addon.Settings.CalloutPopupSkin.Describe():find("applied=true", 1, true) ~= nil
end

local function hasFacade(NS)
    return NS.addon.Settings.CalloutPopupSkin.Describe():find("facade=true", 1, true) ~= nil
end

local function report(NS)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    return table.concat(NS.DebugLog.buffer, "\n")
end

local function called(calls, name, frame)
    for _, c in ipairs(calls) do
        if c[1] == name and c[2] == frame then return true end
    end
    return false
end

-- Enable the addon, EllesmereUI mocked as `opts` says, and open the popup on a user group.
local function openWith(opts)
    local eui, mock = withEUI(opts)
    local NS, m = T.enableAddon({ mock = mock })
    m.SettingsPanel:Show()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    return NS, m, Pop, gid, eui
end

test("eui skin: the popup is painted as EllesmereUI paints the settings window when every condition holds", function()
    local NS, _, Pop, gid, eui = openWith()
    local register = eui.registered.QuickComms
    -- red under: drop the RegisterSkin call (or register under another name than the folder's)
    assertTrue(register ~= nil, "registered at file load under the folder name")
    local S, calls = facade()
    register(S)                    -- PLAYER_LOGIN: the popup is not built yet, so S is kept
    assertFalse(applied(NS))
    assertTrue(hasFacade(NS))
    Pop.Open(gid)                  -- the build paints
    local f = Pop.frame
    assertTrue(applied(NS))
    assertTrue(called(calls, "Shell", f), "the shell")
    assertTrue(called(calls, "FadeNineSlice", f.NineSlice), "the border faded")
    assertEqual(f.Bg:GetAlpha(), 0, "the background at alpha 0")
    assertTrue(called(calls, "CloseButton", f.ClosePanelButton), "the house close X")
    assertEqual(#calls, 3, "chrome only: the page's controls stay stock")
    -- one paint per session: a second Open and a late callback paint nothing again
    local n = #calls
    Pop.Cancel()
    Pop.Open(gid)
    register(S)
    assertEqual(#calls, n)
    -- the close X still cancels
    f.ClosePanelButton:__fire("OnClick")
    assertFalse(Pop.IsOpen())
end)

test("eui skin: the icon browser's window is painted the same way, once, when it is built", function()
    local NS, _, Pop, gid, eui = openWith()
    local S, calls = facade()
    eui.registered.QuickComms(S)
    Pop.Open(gid)
    local n = #calls
    local B = NS.addon.Settings.IconBrowser
    assertTrue(B.Open({ owner = "test", onChoose = function() end }))
    local f = B.frame
    -- red under: paint only Pop.chrome in settings/CalloutPopup_Skin.lua
    assertTrue(called(calls, "Shell", f), "the browser's shell")
    assertTrue(called(calls, "FadeNineSlice", f.NineSlice))
    assertTrue(called(calls, "CloseButton", f.ClosePanelButton))
    assertEqual(f.Bg:GetAlpha(), 0)
    assertEqual(#calls - n, 3, "chrome only")
    assertTrue(NS.addon.Settings.CalloutPopupSkin.Describe():find("applied=true failed=false browser=true", 1, true) ~= nil)
    B.Cancel()
    B.Open({ owner = "test", onChoose = function() end })
    eui.registered.QuickComms(S)
    assertEqual(#calls - n, 3, "one paint per window")
    -- the close X still cancels
    f.ClosePanelButton:__fire("OnClick")
    assertFalse(B.IsOpen())
end)

test("eui skin: a callback that comes after the popup was built paints it at once", function()
    local NS, _, Pop, gid, eui = openWith()
    Pop.Open(gid)
    local S, calls = facade()
    eui.registered.QuickComms(S)
    assertTrue(applied(NS))
    assertTrue(called(calls, "Shell", Pop.frame))
end)

test("eui skin: not painted when any condition fails", function()
    local cases = {
        { "the Blizzard Skin module is not loaded", { noChild = true }, true },
        -- a switch turned off after the callback: S.IsEnabled() is read at paint time
        { "S.IsEnabled() says skinning or this addon's entry is off", {}, false },
        { "S.IsEnabled() raises", {}, function() error("changed API") end },
        { "S.IsEnabled() answers something other than true", {}, function() return 1 end },
    }
    for _, case in ipairs(cases) do
        local NS, _, Pop, gid, eui = openWith(case[2])
        local S, calls = facade(case[3])
        eui.registered.QuickComms(S)   -- as if EllesmereUI called back anyway
        Pop.Open(gid)
        -- red under: drop that condition from NS.EUIBridge.GateOpen (or the pcall in IsEnabled)
        assertFalse(applied(NS), case[1])
        assertEqual(#calls, 0, case[1])
        assertEqual(Pop.frame.Bg:GetAlpha(), 1, case[1])
    end
end)

test("eui skin: never raises without EllesmereUI, or with one that has no RegisterSkin", function()
    -- red under: call EllesmereUI.RegisterSkin unguarded at file load (the load raises)
    local NS, m = T.enableAddon()
    m.SettingsPanel:Show()
    local Pop = NS.addon.Settings.CalloutPopup
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    assertFalse(applied(NS))
    assertFalse((NS.EUIBridge.GateOpen()))
    local _, failing = NS.EUIBridge.GateOpen()
    assertEqual(failing, "eui")
    -- red under: call a RegisterSkin that is not there (the load raises)
    local NS2, _, Pop2, gid2 = openWith({ noRegister = true })
    assertTrue(Pop2.Open(gid2))
    assertFalse(applied(NS2))
    assertFalse(hasFacade(NS2))
end)

test("eui skin: a facade missing a primitive, or one that raises, leaves the popup stock", function()
    local NS, _, Pop, gid, eui = openWith()
    local S, calls = facade()
    S.CloseButton = nil
    eui.registered.QuickComms(S)
    Pop.Open(gid)
    -- red under: drop the REQUIRED facade check in blocked() (Shell and FadeNineSlice would paint)
    assertFalse(applied(NS))
    assertEqual(#calls, 0, "refused before anything is painted")
    local NS2, _, Pop2, gid2, eui2 = openWith()
    local S2 = facade()
    S2.FadeNineSlice = function() error("changed API") end
    eui2.registered.QuickComms(S2)
    -- red under: drop the pcall around paint() in TryApply (the raise escapes Open)
    Pop2.Open(gid2)                 -- the build's try raises inside its pcall: no error escapes
    assertFalse(applied(NS2))
    assertTrue(NS2.addon.Settings.CalloutPopupSkin.Describe():find("failed=true", 1, true) ~= nil)
end)

test("eui skin: waits out a stand-down and paints on the way back up", function()
    local NS, _, Pop, gid, eui = openWith()
    Pop.Open(gid)
    Pop.Cancel()
    NS.SchemaRuntime.Set("enabled", false)
    local S, calls = facade()
    eui.registered.QuickComms(S)
    -- red under: drop the NS.IsStoodDown() check in blocked()
    assertFalse(applied(NS), "nothing is painted while stood down")
    assertEqual(#calls, 0)
    -- red under: drop the NS.STAND_UP entry
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(applied(NS))
    assertTrue(called(calls, "Shell", Pop.frame))
end)

test("eui skin: the fallback window (no settings-window template) keeps its older look", function()
    local eui, mock = withEUI()
    local NS, m = T.enableAddon({ mock = mock })
    m.missingTemplates.SettingsFrameTemplate = true
    m.SettingsPanel:Show()
    local Pop = NS.addon.Settings.CalloutPopup
    local S, calls = facade()
    eui.registered.QuickComms(S)
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    -- red under: drop the chrome.template check in blocked() (the dialog edge goes to alpha 0)
    assertFalse(applied(NS))
    assertEqual(#calls, 0, "nothing painted on the fallback")
    assertEqual(Pop.chrome.bg:GetAlpha(), 1, "the dialog edge and its fill stay")
end)

test("eui skin: the diagnostics report names its state", function()
    local NS, _, _, _, eui = openWith()
    -- red under: drop the skin line from modules/Diagnostics.lua's integrations section
    local text = report(NS)
    assertTrue(text:find("ellesmereui: suite=true facade=false enabled=n/a applied=false failed=false", 1, true) ~= nil, text)
    -- red under: read the switches anywhere but the facade's S.IsEnabled()
    eui.registered.QuickComms((facade(false)))
    text = report(NS)
    assertTrue(text:find("ellesmereui: suite=true facade=true enabled=false applied=false", 1, true) ~= nil, text)
end)
