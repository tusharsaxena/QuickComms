-- tests/test_eui_skin.lua — settings/CalloutPopup_Skin.lua and core/EUIBridge.lua: the callout
-- popup painted the way EllesmereUI paints Blizzard's settings window, when EllesmereUI, its Blizzard
-- Skin module, its third-party skinning and this addon's entry are all on. EllesmereUI is mocked:
-- RegisterSkin keeps the callback, and the facade records every primitive it is handed.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- A mocked EllesmereUI on mock `mk`, before any source loads. `opts.db` is EllesmereUIDB,
-- `opts.noChild` leaves the Blizzard Skin module unloaded, `opts.noRegister` drops RegisterSkin.
local function withEUI(opts)
    opts = opts or {}
    local eui = { registered = {} }
    return eui, function(mk)
        mk.EllesmereUI = {}
        if not opts.noRegister then
            mk.EllesmereUI.RegisterSkin = function(name, fn) eui.registered[name] = fn end
        end
        mk.EllesmereUIDB = opts.db or {}
        if not opts.noChild then mk.loadedAddons.EllesmereUIBlizzardSkin = true end
    end
end

-- A facade that records each call as { primitive, frame }.
local function facade()
    local S, calls = { apiVersion = 3 }, {}
    for _, name in ipairs({ "Shell", "FadeNineSlice", "CloseButton", "Button", "EditBox" }) do
        S[name] = function(frame) calls[#calls + 1] = { name, frame } end
    end
    return S, calls
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
    local Skin = NS.addon.Settings.CalloutPopupSkin
    local register = eui.registered.QuickComms
    -- red under: drop the RegisterSkin call (or register under another name than the folder's)
    assertTrue(register ~= nil, "registered at file load under the folder name")
    local S, calls = facade()
    register(S)                    -- PLAYER_LOGIN: the popup is not built yet, so S is kept
    assertFalse(Skin.IsApplied())
    assertTrue(Skin.HasFacade())
    Pop.Open(gid)                  -- the build paints
    local f = Pop.frame
    assertTrue(Skin.IsApplied())
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

test("eui skin: a callback that comes after the popup was built paints it at once", function()
    local NS, _, Pop, gid, eui = openWith()
    Pop.Open(gid)
    local S, calls = facade()
    eui.registered.QuickComms(S)
    assertTrue(NS.addon.Settings.CalloutPopupSkin.IsApplied())
    assertTrue(called(calls, "Shell", Pop.frame))
end)

test("eui skin: not painted when any condition fails", function()
    local cases = {
        { "the Blizzard Skin module is not loaded", { noChild = true } },
        { "third-party skinning is off", { db = { thirdPartySkinsOff = true } } },
        { "this addon's entry is off", { db = { thirdPartySkinAddons = { QuickComms = false } } } },
    }
    for _, case in ipairs(cases) do
        local NS, _, Pop, gid, eui = openWith(case[2])
        local S, calls = facade()
        eui.registered.QuickComms(S)   -- as if EllesmereUI called back anyway
        Pop.Open(gid)
        -- red under: drop that condition from NS.EUIBridge.GateOpen
        assertFalse(NS.addon.Settings.CalloutPopupSkin.IsApplied(), case[1])
        assertEqual(#calls, 0, case[1])
        assertEqual(Pop.frame.Bg:GetAlpha(), 1, case[1])
    end
    -- another addon's entry being off is not this one's
    local NS, _, Pop, gid, eui = openWith({ db = { thirdPartySkinAddons = { Other = false } } })
    eui.registered.QuickComms((facade()))
    Pop.Open(gid)
    assertTrue(NS.addon.Settings.CalloutPopupSkin.IsApplied())
end)

test("eui skin: never raises without EllesmereUI, or with one that has no RegisterSkin", function()
    local NS, m = T.enableAddon()
    m.SettingsPanel:Show()
    local Skin = NS.addon.Settings.CalloutPopupSkin
    -- red under: call EllesmereUI.RegisterSkin unguarded at file load (the load raises)
    assertFalse(Skin.registered)
    local Pop = NS.addon.Settings.CalloutPopup
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    assertFalse(Skin.IsApplied())
    assertFalse((NS.EUIBridge.GateOpen()))
    local _, failing = NS.EUIBridge.GateOpen()
    assertEqual(failing, "eui")
    local NS2, _, Pop2, gid2 = openWith({ noRegister = true })
    assertFalse(NS2.addon.Settings.CalloutPopupSkin.registered)
    assertTrue(Pop2.Open(gid2))
    assertFalse(NS2.addon.Settings.CalloutPopupSkin.IsApplied())
end)

test("eui skin: a facade missing a primitive, or one that raises, leaves the popup stock", function()
    local NS, _, Pop, gid, eui = openWith()
    local S, calls = facade()
    S.CloseButton = nil
    eui.registered.QuickComms(S)
    Pop.Open(gid)
    local Skin = NS.addon.Settings.CalloutPopupSkin
    assertFalse(Skin.IsApplied())
    assertEqual(#calls, 0, "refused before anything is painted")
    local NS2, _, Pop2, gid2, eui2 = openWith()
    local S2 = facade()
    S2.FadeNineSlice = function() error("changed API") end
    eui2.registered.QuickComms(S2)
    Pop2.Open(gid2)                 -- the build's try raises inside its pcall: no error escapes
    assertFalse(NS2.addon.Settings.CalloutPopupSkin.IsApplied())
end)

test("eui skin: waits out a stand-down and paints on the way back up", function()
    local NS, _, Pop, gid, eui = openWith()
    Pop.Open(gid)
    Pop.Cancel()
    NS.SchemaRuntime.Set("enabled", false)
    local S, calls = facade()
    eui.registered.QuickComms(S)
    local Skin = NS.addon.Settings.CalloutPopupSkin
    assertFalse(Skin.IsApplied(), "nothing is painted while stood down")
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(Skin.IsApplied())
    assertTrue(called(calls, "Shell", Pop.frame))
end)

test("eui skin: the diagnostics report names its state", function()
    local NS = openWith()
    local line = NS.addon.Settings.CalloutPopupSkin.Describe()
    assertTrue(line:find("ellesmereui: suite=true master=true entry=true facade=false applied=false", 1, true) ~= nil, line)
end)
