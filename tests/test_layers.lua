-- tests/test_layers.lua — frame layering (item 030, frame-layering, standard v2.88.0): the one layers
-- table (core/Constants.lua NS.Constants.LAYERS) and where each frame class sits, pinned through the
-- kit's frame-layer recorder (tests/_kit/mock_layers.lua, kit revision 42), installed before any
-- source loads so every frame the addon makes records its strata, level, toplevel and parent alpha.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local CLIENT_STRATA = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
    FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

-- A fully enabled instance whose every frame records its layers.
local function layered(inputs)
    local NS, m = T.enableAddon({ mock = function(mk) dofile("tests/_kit/mock_layers.lua")(mk) end })
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function lv(f) return f:GetFrameLevel() end

-- ── the table ───────────────────────────────────────────────────────────────────────────────

test("layers: NS.Constants.LAYERS names every strata and level once (frame-layering-§5)", function()
    local NS = T.newAddon()
    local LAYERS = NS.Constants.LAYERS
    -- red under: no layers table in core/Constants.lua
    assertTrue(type(LAYERS) == "table" and type(LAYERS.STRATA) == "table" and type(LAYERS.LEVEL) == "table")
    for k, v in pairs(LAYERS.STRATA) do assertTrue(CLIENT_STRATA[v] == true, k .. " is a client strata") end
    for k, v in pairs(LAYERS.LEVEL) do assertTrue(type(v) == "number", k .. " is a level offset") end
    local S = LAYERS.STRATA
    assertEqual(S.HUD, "MEDIUM", "the Comms Pads")
    assertEqual(S.HUD_POPUP, "DIALOG", "the Comms Dial: the secure fixed point")
    assertEqual(S.DIAL_SCREEN, "HIGH", "the dial's screen catcher, one under it")
    assertEqual(S.WINDOW, "FULLSCREEN", "the preview and Share windows, over the dial")
    assertEqual(S.MODAL, "FULLSCREEN", "the popup and the icon browser")
    assertEqual(S.POPUP, "FULLSCREEN_DIALOG", "the lifted confirms and the icon link window")
    -- the modal aliases read the table, so their two callers keep working
    local MW = NS.addon.Settings.ModalWindow
    assertEqual(MW.STRATA, S.MODAL)
    assertEqual(MW.CONFIRM_STRATA, S.POPUP)
    assertEqual(MW.LEVEL, LAYERS.LEVEL.MODAL)
    assertEqual(MW.LEVEL_OVER, LAYERS.LEVEL.MODAL_OVER)
end)

-- Every SetFrameStrata / SetFrameLevel call in the shipped code, as { file, line, text }.
local function layerCalls()
    local out = {}
    local p = io.popen("find core modules settings -name '*.lua' | sort")
    for path in p:lines() do
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            if code:find("SetFrameStrata%(") or code:find("SetFrameLevel%(") then
                out[#out + 1] = { path, n, code }
            end
        end
    end
    p:close()
    return out
end

test("layers: no strata string and no bare level at any call site (anti-pattern #99)", function()
    local calls = layerCalls()
    assertTrue(#calls > 0, "the scan found the calls")
    for _, c in ipairs(calls) do
        local where = c[1] .. ":" .. c[2]
        -- red under: SetFrameStrata("MEDIUM") in modules/Pad.lua, and the like
        assertFalse(c[3]:find('SetFrameStrata%(%s*"') ~= nil, where .. ": a strata literal")
        -- red under: SetFrameLevel(... + 20) in modules/Dial_Render.lua, MW's LEVEL + 2, and the like
        assertFalse(c[3]:find("SetFrameLevel%(%s*%d") ~= nil, where .. ": an absolute level")
        assertFalse(c[3]:find("[%+%-]%s*%d+%s*%)") ~= nil, where .. ": a bare level offset")
        -- every level is relative: a base frame's level plus an offset (frame-layering-§3)
        if c[3]:find("SetFrameLevel%(") then
            -- (ModalWindow's band: `base` is UIParent's level plus the band, `at` the base plus a part)
            assertTrue(c[3]:find("GetFrameLevel%(") ~= nil or c[3]:find("at%(LV%.") ~= nil
                or c[3]:find("SetFrameLevel%(base%)") ~= nil,
                where .. ": a level relative to a base frame")
        end
    end
end)

-- ── the Comms Pads (HUD) ───────────────────────────────────────────────────────────────────

local function pad(NS)
    local snap = NS.Situation.Current()
    assertTrue(NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))))
    return NS.Pad.Instance("p1")
end

test("layers: a pad's root is the HUD tier; its header and buttons sit one over it", function()
    local NS, m = layered()
    local inst = pad(NS)
    local L = m.__layers(inst.root)
    assertEqual(L.strata, NS.Constants.LAYERS.STRATA.HUD)
    assertTrue(L.clamped, "clamped")
    assertFalse(L.toplevel, "a HUD is not toplevel")
    local btn = NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
    assertEqual(lv(btn), lv(inst.root) + 1)
    assertEqual(lv(inst.header), lv(inst.root) + 1)
    assertEqual(m.__layers(btn).strata, "MEDIUM", "inherited")
end)

test("layers: [QUI-Z11] the pad's drag strip ignores the pad's alpha", function()
    local NS, m = layered()
    local inst = pad(NS)
    assertTrue(inst.handle ~= nil, "a strip")
    -- red under: no ignoreParentAlpha in the strip's spec (the strip fades with the pad's alpha)
    assertTrue(m.__layers(inst.handle).ignoreParentAlpha, "drawn at full alpha over a faded pad")
end)

test("layers: [QUI-Z02/Z03] a pad button's ladder: edge, its glow, icon border, its glow, overlay", function()
    local NS = layered()
    pad(NS)
    local LV = NS.Constants.LAYERS.LEVEL
    local btn = NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
    local B = lv(btn)
    -- red under: qcEdge and qcIconFrame left at the default B+1, tied
    assertEqual(lv(btn.qcEdge), B + LV.BTN_EDGE, "the button border")
    assertTrue(btn.qcIconFrame ~= nil, "the icon frame is made at paint")
    assertEqual(lv(btn.qcIconFrame), B + LV.BTN_ICON, "the icon border, over the button's")
    -- the glows start over their own hosts (LibCustomGlow: host level + frameLevel)
    local edgeGlow, iconGlow = lv(btn.qcEdge) + LV.BTN_GLOW, lv(btn.qcIconFrame) + LV.ICON_GLOW
    assertTrue(lv(btn.qcEdge) < edgeGlow and edgeGlow < lv(btn.qcIconFrame), "button glow between the borders")
    assertTrue(lv(btn.qcIconFrame) < iconGlow, "icon glow over the icon border")
    -- red under: the label, padlock and veils as regions of the button, under every child frame
    local over = btn.qcOver
    assertTrue(over ~= nil, "an overlay frame")
    assertEqual(lv(over), B + LV.BTN_OVER)
    assertTrue(lv(over) > iconGlow, "over every border and glow")
    assertFalse(over:IsMouseEnabled(), "mouse off, so the secure button under it takes the click")
    for _, k in ipairs({ "qcLabel", "qcLock", "qcDim", "qcCool", "qcFlash" }) do
        assertTrue(btn[k]:GetParent() == over, k .. " on the overlay frame")
    end
    assertTrue(btn.qcIcon:GetParent() == btn and btn.qcBg:GetParent() == btn, "the fill stays on the button")
    -- the veils over the label and padlock, so a dim veil dims them too
    assertTrue(btn.qcDim.__sublevel > 0 and btn.qcCool.__sublevel > 0 and btn.qcFlash.__sublevel > 0)
end)

-- ── the Comms Dial (secure fixed point) ────────────────────────────────────────────────────

local function dialPlan(NS)
    local snap = NS.Situation.Current()
    local group = { id = T.seeded(NS, "bi.mplus"), title = "Dungeon", slots = {} }
    for i, cid in ipairs(NS.Library.Group(T.seeded(NS, "bi.mplus")).callouts) do
        if i > 4 then break end
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    local rings, open = NS.DialLayout.Rings({ group }, { slices = 4, title = "Comms Dial" })
    return { kind = "dial", surfaceId = "d2", snapshot = snap, order = { group.id }, active = {}, rings = rings,
        openRing = open }
end

test("layers: the dial's header, front, catchers and screen catcher keep their tiers", function()
    local NS, m = layered()
    assertTrue(NS.Dial.Apply(1, "d2", dialPlan(NS)))
    local LAYERS = NS.Constants.LAYERS
    local inst = NS.Dial.Instance("d2")
    local H = lv(inst.header)
    assertEqual(m.__layers(inst.header).strata, LAYERS.STRATA.HUD_POPUP)
    assertEqual(lv(inst.header.qcPointer), H + LAYERS.LEVEL.DIAL_FRONT, "the hub front")
    local screen = NS.SendEngine.NewDialScreen(inst.header, "")
    assertEqual(m.__layers(screen).strata, LAYERS.STRATA.DIAL_SCREEN, "one strata under the dial")
    local ring = inst.rings.active[1]
    local catcher = NS.SendEngine.NewDialCatcher(inst.header, ring, "")
    assertEqual(lv(catcher), math.max(0, H + LAYERS.LEVEL.DIAL_CATCHER), "under its ring, by design")
end)

test("layers: [QUI-Z04] a wedge's ladder: icon border, its glow, then the overlay over both", function()
    local NS = layered()
    assertTrue(NS.Dial.Apply(1, "d2", dialPlan(NS)))
    local LV = NS.Constants.LAYERS.LEVEL
    local w = NS.Dial.WedgesFor("d2", T.seeded(NS, "bi.mplus.pull"))[1]
    local W = lv(w)
    assertEqual(W, lv(NS.Dial.Instance("d2").header) + 2, "a wedge sits at H+2")
    assertEqual(lv(w.qcIconFrame), W + LV.WEDGE_ICON, "the icon border at H+3")
    local glow = lv(w.qcIconFrame) + LV.ICON_GLOW
    -- red under: the label, padlock and veils as regions of the wedge, under its icon frame and glow
    local over = w.qcOver
    assertTrue(over ~= nil, "an overlay frame")
    assertEqual(lv(over), W + LV.WEDGE_OVER, "at H+6")
    assertTrue(lv(over) > glow, "over the icon's glow")
    assertFalse(over:IsMouseEnabled(), "mouse off")
    for _, k in ipairs({ "qcLabel", "qcLock", "qcDim", "qcCool", "qcFlash" }) do
        assertTrue(w[k]:GetParent() == over, k .. " on the overlay frame")
    end
    assertTrue(lv(over) < lv(NS.Dial.Instance("d2").header.qcPointer), "under the hub front")
end)

-- ── windows, modals and popups ─────────────────────────────────────────────────────────────

test("layers: [QUI-Z10] the preview window is the window tier, never toplevel, never raised", function()
    local NS, m = layered()
    NS.Preview.SetPreviewAs("arena")
    local f = NS.PreviewWindow.__frame()
    local L = m.__layers(f)
    assertEqual(L.strata, NS.Constants.LAYERS.STRATA.WINDOW)
    assertTrue(L.clamped)
    assertFalse(L.toplevel, "the secure fixed point's exception: a raise would lift it over a modal")
    assertEqual(L.raised, 0)
    assertTrue(lv(f) < m.UIParent:GetFrameLevel() + NS.Constants.LAYERS.LEVEL.MODAL, "under a modal's catcher")
end)

test("layers: the modal bands sit over UIParent, each part at its named offset", function()
    local NS, m = layered()
    local LAYERS = NS.Constants.LAYERS
    local MW = NS.addon.Settings.ModalWindow
    local w = MW.Build({ name = "QuickCommsLayersModal", pageName = "QuickCommsLayersModalPage", title = "x",
        width = 100, height = 100, strata = MW.STRATA, onClose = function() end })
    local base = m.UIParent:GetFrameLevel() + LAYERS.LEVEL.MODAL
    assertEqual(m.__layers(w.catcher).strata, LAYERS.STRATA.MODAL)
    assertEqual(lv(w.catcher), base)
    assertEqual(m.__layers(w.frame).strata, LAYERS.STRATA.MODAL)
    assertEqual(lv(w.frame), base + LAYERS.LEVEL.MODAL_WINDOW)
    assertEqual(lv(w.ctx.panel), base + LAYERS.LEVEL.MODAL_PAGE)
    assertEqual(lv(w.chrome.close), base + LAYERS.LEVEL.MODAL_CLOSE)
    local over = MW.Build({ name = "QuickCommsLayersOver", pageName = "QuickCommsLayersOverPage", title = "y",
        width = 100, height = 100, strata = MW.STRATA, level = MW.LEVEL_OVER, onClose = function() end })
    assertEqual(lv(over.catcher), m.UIParent:GetFrameLevel() + LAYERS.LEVEL.MODAL_OVER)
    assertTrue(lv(over.catcher) > lv(w.chrome.close), "a modal over a modal clears the first's band")
end)

test("layers: [QUI-Z06] the Share window keeps the window tier; the icon link window is lifted to POPUP", function()
    local NS, m = layered()
    local LAYERS = NS.Constants.LAYERS
    local share = NS.Share.Window()
    assertTrue(share ~= nil)
    share:Show("x")
    assertEqual(m.__layers(m.__named.QuickCommsShareWindow).strata, LAYERS.STRATA.WINDOW, "the library's FULLSCREEN")
    local link = NS.addon.Settings.IconBrowser.LinkWindow()
    assertTrue(link ~= nil)
    assertEqual(m.__layers(link:GetFrame()).strata, LAYERS.STRATA.POPUP, "over the browser's band")
end)
