-- tests/test_title_bars.lua — every title-bar control a Quick Comms window draws itself (SR-QC,
-- Ka0sAddonsCommonTasks docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/SR1_SMOKE_ROUND1.md, rulings 3 and 4).
--
-- Ruling 3: every title-bar control shows a one-line tooltip on hover, above it (LibKa0s-Tooltip-1.0's
-- AttachTitleTip, which places it with PlaceAttached), in the owner's gtip.title, and hides it on leave.
-- Ruling 4: at rest a control paints the skin's icon.tint, under the pointer text.link; a close X rests
-- in icon.tint (the library's close.rest follows it in every skin) and hovers in close.hot.
--
-- The windows, and their controls:
--   - the Preview window: its close X (Core.MakeCloseButton, the owner's);
--   - the modal window the callout popup is built in: its close X, the template's ClosePanelButton
--     skinned by S.CloseButton, or Core.MakeCloseButton's on a client without the template;
--   - a Comms Pad's header row: its collapse toggle ("-" / "+").
-- The library's own windows (the debug console, the copy window, the perf and sim panels, the skin
-- picker, the icon browser, a drag strip's marks) are pinned by LibKa0s itself.
--
-- Each window case reads the paint recorder (tests/_kit/mock_paint.lua), the pad's the HUD mock's own
-- recorded color (tests/wow_mock.lua, as tests/test_skin_hud.lua), under Ka0s Default and Obsidian.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D = dofile("tests/dial_helpers.lua")
local OWNER = "QuickComms"
local SKINS = { "ka0s", "obsidian" }

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

local function assertRGB(got, want, what)
    assertTrue(type(got) == "table", what .. ": nothing painted")
    assertTrue(type(want) == "table", what .. ": no token value to compare")
    for i = 1, 3 do
        assertTrue(near(got[i], want[i]),
            ("%s[%d]: got %s, want %s"):format(what, i, tostring(got[i]), tostring(want[i])))
    end
end

--- The game tooltip recorded while `fn(rec)` runs: `text` (its first line), `color`, `shown`. Put back after.
local KEYS = { "SetOwner", "GetOwner", "IsOwned", "SetText", "AddLine", "AddDoubleLine", "Show", "Hide",
               "IsShown", "ClearAllPoints", "SetPoint" }

local function record(m, fn)
    local tip, saved, rec = m.GameTooltip, {}, { shown = false }
    for _, k in ipairs(KEYS) do saved[k] = rawget(tip, k) end
    rawset(tip, "SetOwner", function(_, owner) rec.owner, rec.text, rec.color = owner, nil, nil end)
    rawset(tip, "GetOwner", function() return rec.owner end)
    rawset(tip, "IsOwned", function(_, f) return rec.owner == f end)
    rawset(tip, "SetText", function(_, text, r, g, b) rec.text, rec.color = text, { r, g, b } end)
    rawset(tip, "AddLine", function(_, text, r, g, b)
        if rec.text == nil then rec.text, rec.color = text, { r, g, b } end
    end)
    rawset(tip, "AddDoubleLine", function(_, text) if rec.text == nil then rec.text = text end end)
    rawset(tip, "Show", function() rec.shown = true end)
    rawset(tip, "Hide", function() rec.shown = false end)
    rawset(tip, "IsShown", function() return rec.shown end)
    rawset(tip, "ClearAllPoints", function() end)
    rawset(tip, "SetPoint", function() end)
    local ok, err = pcall(fn, rec)
    for _, k in ipairs(KEYS) do rawset(tip, k, saved[k]) end
    if not ok then error(err, 0) end
end

--- Every control in `controls` ({ { name, frame } }) shows a non-empty tooltip in gtip.title on enter
--- and hides it on leave. Answers what each said, by name.
local function checkTips(NS, m, controls, label)
    local said = {}
    local r, g, b = NS.Skin.Color("gtip.title")
    record(m, function(rec)
        assertTrue(#controls > 0, label .. ": the window lists its title-bar controls")
        for _, c in ipairs(controls) do
            local name, f = c[1], c[2]
            assertTrue(type(f) == "table" and type(f.__fire) == "function", label .. ": " .. name .. " is built")
            rec.text, rec.shown = nil, false
            f:__fire("OnEnter")
            -- red under: a control with no tooltip of its own
            assertTrue(type(rec.text) == "string" and rec.text ~= "",
                label .. ": " .. name .. " shows a tooltip on enter, got " .. tostring(rec.text))
            assertTrue(rec.shown, label .. ": " .. name .. "'s tooltip is shown")
            assertRGB(rec.color, { r, g, b }, label .. ": " .. name .. "'s tooltip is gtip.title")
            said[name] = rec.text
            f:__fire("OnLeave")
            assertFalse(rec.shown, label .. ": " .. name .. " hides its tooltip on leave")
        end
    end)
    return said
end

local function tokenRGB(Skin, key, token)
    local c = Skin:ResolveSkin(key)[token]
    return { c[1], c[2], c[3] }
end

--- A close control's art color now: its icon's vertex tint, else its glyph's text color.
local function closeArt(m, b)
    local art = rawget(b, "icon") or rawget(b, "glyph")
    if not art then
        for _, r in ipairs({ b:GetRegions() }) do
            if m.__paint(r).text == "x" then art = r end
        end
    end
    assertTrue(art ~= nil, "the close control has art")
    local p = m.__paint(art)
    return p.vertex or p.textColor
end

local function checkClose(m, Skin, getClose, label)
    for _, key in ipairs(SKINS) do
        Skin:SetChoice(OWNER, "ka0s", key)
        local b = getClose()
        b:__fire("OnLeave")
        -- red under: a close resting in its own close.rest, off the other header controls' icon.tint
        assertRGB(closeArt(m, b), tokenRGB(Skin, key, "icon.tint"), label .. " at rest under " .. key)
        b:__fire("OnEnter")
        assertRGB(closeArt(m, b), tokenRGB(Skin, key, "close.hot"), label .. " hovered under " .. key)
        b:__fire("OnLeave")
    end
end

-- The mask calls the dial's round art makes (modules/Dial_Slices.lua), which the paint recorder's
-- regions do not model: answered as no-ops, so the dial a preview shows builds under the recorder
-- (as tests/test_skin_windows.lua does). Nothing here asserts a mask.
local MASK_CALLS = { "AddMaskTexture", "RemoveMaskTexture", "SetMask" }

local function maskable(m)
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        local make = rawget(f, "CreateTexture")
        if make then
            rawset(f, "CreateTexture", function(self, ...)
                local t = make(self, ...)
                for _, name in ipairs(MASK_CALLS) do rawset(t, name, function() end) end
                return t
            end)
        end
        return f
    end
end

local function boot()
    local NS, m = T.enableAddon()
    dofile("tests/_kit/mock_paint.lua")(m)
    maskable(m)
    NS.Anim.Open, NS.Anim.Close = function() return false end, function() return false end
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    m.SettingsPanel:Show()
    return NS, m, m.LibStub("LibKa0s-Skin-1.0")
end

-- ── the Preview window ───────────────────────────────────────────────────────────────────────────

local function previewWindow(NS)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    return NS.PreviewWindow.__frame()
end

test("title bars: the Preview window's close shows its tooltip", function()
    local NS, m = boot()
    local f = previewWindow(NS)
    local said = checkTips(NS, m, { { "close", f.closeButton } }, "the Preview window")
    assertEqual(said.close, "Close")
end)

test("title bars: the Preview window's close rests in icon.tint and hovers in close.hot", function()
    local NS, m, Skin = boot()
    local f = previewWindow(NS)
    checkClose(m, Skin, function() return f.closeButton end, "the Preview window's close")
end)

-- ── the modal window (the callout popup's) ───────────────────────────────────────────────────────

local function openPopup(NS)
    local Pop = NS.addon.Settings.CalloutPopup
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    return Pop
end

test("title bars: the modal window's template close shows its tooltip", function()
    local NS, m = boot()
    local Pop = openPopup(NS)
    assertTrue(Pop.chrome.template, "the template's chrome")
    -- red under: the template's ClosePanelButton, skinned but given no tooltip
    local said = checkTips(NS, m, { { "close", Pop.chrome.close } }, "the modal window")
    assertEqual(said.close, "Close")
end)

-- The mock's template close carries no art of its own; the client's has its normal texture, which
-- S.CloseButton fades and draws its "x" glyph over. Given one here, so the glyph is drawn and read.
local function withStockClose(m)
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        local close = rawget(f, "ClosePanelButton")
        if close and not rawget(close, "__stockArt") then
            local art = close:CreateTexture(nil, "ARTWORK")
            rawset(close, "__stockArt", art)
            rawset(close, "GetNormalTexture", function() return art end)
        end
        return f
    end
end

test("title bars: the modal window's template close rests in icon.tint and hovers in close.hot", function()
    local NS, m, Skin = boot()
    withStockClose(m)
    local Pop = openPopup(NS)
    checkClose(m, Skin, function() return Pop.chrome.close end, "the modal window's close")
end)

test("title bars: the modal window's fallback close shows its tooltip and wears the close colors", function()
    local NS, m, Skin = boot()
    m.missingTemplates.SettingsFrameTemplate = true
    local Pop = openPopup(NS)
    assertFalse(Pop.chrome.template)
    checkTips(NS, m, { { "close", Pop.chrome.close } }, "the modal window (fallback)")
    checkClose(m, Skin, function() return Pop.chrome.close end, "the fallback's close")
end)

-- ── a Comms Pad's header row ─────────────────────────────────────────────────────────────────────

local function livePad()
    local NS, m = D.live()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    -- The pad was dressed at enable, before the recorder: a switch repaints it (test_pad_looks).
    Skin:SetChoice(OWNER, "ka0s", "glass")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    local snap = NS.Situation.Current()
    assertTrue(NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))))
    NS.Surfaces.ApplyAll("test")
    return NS, m, Skin
end

local function collapseOf(NS) return NS.Pad.Instance("p1").header.qcCollapse end

test("title bars: a pad header's collapse toggle shows its tooltip, Collapse or Expand", function()
    local NS, m = livePad()
    local said = checkTips(NS, m, { { "collapse", collapseOf(NS) } }, "the pad header")
    assertEqual(said.collapse, "Collapse")
    assertTrue(NS.Pad.ToggleCollapsed("p1"))
    said = checkTips(NS, m, { { "collapse", collapseOf(NS) } }, "the pad header (collapsed)")
    assertEqual(said.collapse, "Expand")
end)

test("title bars: a pad header's collapse toggle rests in icon.tint and hovers in text.link", function()
    local NS, _, Skin = livePad()
    for _, key in ipairs(SKINS) do
        Skin:SetChoice(OWNER, "ka0s", key)
        NS.Surfaces.ApplyAll("test")
        local b = collapseOf(NS)
        -- red under: the "-" in the header's own font color (gold under Ka0s Default)
        assertRGB(rawget(b.qcText, "__color"), tokenRGB(Skin, key, "icon.tint"), "rest under " .. key)
        b:__fire("OnEnter")
        assertRGB(rawget(b.qcText, "__color"), tokenRGB(Skin, key, "text.link"), "hovered under " .. key)
        b:__fire("OnLeave")
        assertRGB(rawget(b.qcText, "__color"), tokenRGB(Skin, key, "icon.tint"), "back at rest under " .. key)
    end
end)
