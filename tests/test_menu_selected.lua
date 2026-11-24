-- tests/test_menu_selected.lua — the selected entry of every menu Quick Comms opens reads apart from a
-- plain one (FB2-QC-01; decision D3 of Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH/
-- R2_SMOKE_FEEDBACK.md; WowAddonStandards v2.120.0 skinning-§4, *A selected entry reads apart*;
-- LibKa0s WidgetsDropdown minor 4). The addon builds no menu of its own and paints no row color: its
-- two menus are the library's, the Preview as window's situation dropdown (W.Dropdown, through
-- NS.MakeDropdown) and the callout popup's emote menu (W.ContextMenu radio rows, through
-- NS.OpenContextMenu), so both follow the library's rule. Each is walked under Ka0s Default, Obsidian
-- and Azeroth (whose own accent stands too near its text and takes Ka0s Default's gold).
--
-- Not covered here: the settings panel's AceGUI dropdowns (the schema's `values` rows, the General
-- tab's Parent group in settings/Groups.lua) open an AceGUI pull-out, which LibKa0s's SkinAce paints
-- (its paintPullout), not WidgetsDropdown. In v1.113.0 a checked pull-out item keeps `menu.text` and is
-- told apart by its check mark alone, so D3 there is the library's to close (FB2-QC-REV).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "QuickComms"
local SKINS = { "ka0s", "obsidian", "azeroth" }
local GOLD = "1.000,0.820,0.000"

local function rgb(c) return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3]) end
local function painted(m, b) return rgb(m.__paint(b.fs).textColor) end
local function selected(W)
    local r, g, b = W.SelectedColor(OWNER)
    return rgb({ r, g, b })
end

--- Turn the kit's paint recorder on (tests/_kit/mock_paint.lua): frames made from here record their
--- paint. Called once the windows are up and before the shared menu is first built, so the menu's
--- rows record and the pads and dials (whose mask calls the recorder does not model) do not.
local function record(m) dofile("tests/_kit/mock_paint.lua")(m) end

local function live()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return { inGroup = false } end
    NS.Situation.RefreshNow("test")
    return NS, m, m.LibStub("LibKa0s-Skin-1.0"), m.LibStub("LibKa0s-Widgets-1.0")
end

--- Open `dd`'s list, answering the shared menu (the frame it builds the first time).
local function openDropdown(m, dd, state)
    local saved = m.CreateFrame
    m.CreateFrame = function(...)
        local f = saved(...)
        state.menu = state.menu or f
        return f
    end
    dd:__fire("OnClick")
    m.CreateFrame = saved
    return state.menu
end

--- What `menu`'s rows read, for a failure message.
local function labels(m, menu)
    local out = {}
    for i, b in ipairs(menu.buttons or {}) do
        out[#out + 1] = ("%d:%s:%s:%s"):format(i, tostring(b.fs and b.fs.GetText and b.fs:GetText()),
            tostring(b.fs and m.__paint(b.fs).text), tostring(b:IsShown()))
    end
    return table.concat(out, " | ")
end

--- The shown row buttons of `menu` whose label is `label`, or any other label when `other`.
local function rowWith(menu, label, other)
    for _, b in ipairs(menu.buttons or {}) do
        local text = b.fs and b.fs:GetText()
        if b:IsShown() and text and text ~= "" and ((text == label) ~= (other == true)) then return b end
    end
end

test("menu selected: the Preview as dropdown's current situation stands off the other rows", function()
    local NS, m, Skin, W = live()
    NS.Preview.SetPreviewAs("arena")
    local dd = NS.PreviewWindow.__frame().dropdown
    local label
    for _, o in ipairs(dd._options) do if o.value == "arena" then label = o.label end end
    assertTrue(label ~= nil, "Arena is one of the presets")
    local state = {}
    record(m)
    for _, key in ipairs(SKINS) do
        Skin:SetChoice(OWNER, "ka0s", key)
        local menu = openDropdown(m, dd, state)
        assertTrue(menu ~= nil, key .. ": the menu opened")
        local sel, plain = rowWith(menu, label), rowWith(menu, label, true)
        assertTrue(sel ~= nil and plain ~= nil, key .. ": a selected row and a plain row: " .. labels(m, menu))
        local t = Skin:ResolveSkin(key)
        assertEqual(painted(m, plain), rgb(t["menu.text"]), key .. ": a plain row is menu.text")
        -- red under: a selected row in a skin's own textSel where it sits near its text (Azeroth)
        assertEqual(painted(m, sel), selected(W), key .. ": the selected row is the library's selected color")
        assertTrue(painted(m, sel) ~= painted(m, plain), key .. ": and differs from a plain row")
        if key == "azeroth" then assertEqual(painted(m, sel), GOLD, "Azeroth takes Ka0s Default's gold") end
        NS.CloseMenu()
    end
end)

test("menu selected: the emote menu's ticked row paints selected, not a tick beside plain text", function()
    local NS, m, Skin, W = live()
    m.EMOTE98_TOKEN, m.EMOTE98_CMD1 = "THANK", "/thank"
    NS.Emotes.Reset()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    m.SettingsPanel:Show()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    P.during(function() Pop.Open(gid) end)   -- a new callout: no emote, so None is the ticked row
    record(m)
    local anchor = m.CreateFrame("Frame", nil, m.UIParent)
    local function check(what, wantPlain, wantSel)
        local menu = Pop.OpenEmoteMenu(anchor)
        assertTrue(menu ~= nil, what .. ": the menu opened")
        local none, plain = rowWith(menu, NS.L["None"]), rowWith(menu, NS.L["None"], true)
        assertTrue(none ~= nil and plain ~= nil, what .. ": None and a letter row: " .. labels(m, menu))
        assertEqual(painted(m, plain), wantPlain, what .. ": a plain row")
        -- red under: WidgetsDropdown minor 3, which ticked the radio and left its text plain
        assertEqual(painted(m, none), wantSel, what .. ": the ticked row is selected")
        assertTrue(painted(m, none) ~= painted(m, plain), what .. ": and differs from a plain row")
        NS.CloseMenu()
    end
    -- Out of the box the settings panel keeps the client's look (skin.ignorePanel), and so does this
    -- panel menu: the stock gray rows and the gold selection, whatever the skin.
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    check("panel ignored", "0.900,0.900,0.900", GOLD)
    -- The panel skinned: the skin's own rows and the library's selected color.
    Skin:SetIgnore(OWNER, false, nil)
    for _, key in ipairs(SKINS) do
        Skin:SetChoice(OWNER, "ka0s", key)
        check(key, rgb(Skin:ResolveSkin(key)["menu.text"]), selected(W))
        if key == "azeroth" then assertEqual(selected(W), GOLD, "Azeroth takes Ka0s Default's gold") end
    end
end)
