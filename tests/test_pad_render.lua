-- tests/test_pad_render.lua — modules/Pad_Render.lua (spec §10.1): what a button and the pad's header
-- show, and the drag-strip seam (core/WidgetsSetup.lua). Frames come from the mock's QuickComms
-- branch, whose regions are objects of their own.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local ARMED = { calloutId = "c1", name = "Pull", line = "/p Pull", concrete = "party", chatType = "PARTY" }

local function button(NS, m)
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    return NS.PadRender.Dress(NS.SendEngine.NewButton(root)), root
end

test("render: Dress builds a button's regions once, each its own object", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    local icon = b.qcIcon
    assertTrue(icon ~= b and b.qcLabel ~= b and b.qcLock ~= b)
    NS.PadRender.Dress(b)
    assertTrue(b.qcIcon == icon, "dressed once")
    assertFalse(b.qcDim:IsShown())
    assertFalse(b.qcFlash:IsShown())
end)

test("render: [audit QC-07] the button's padlock is the catalog's lock mark, tinted gold; the Blizzard art is the nil fallback", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    -- red under: SetTexture(LOCK_ICON) unconditionally in PadRender.Dress
    assertTrue(NS.Icon("lock") ~= nil)
    assertEqual(b.qcLock.__texture, NS.Icon("lock"))
    assertEqual(b.qcLock.__color[1], NS.Constants.GOLD.r)
    local real = NS.Icon
    NS.Icon = function() return nil end
    local b2 = button(NS, m)
    NS.Icon = real
    assertEqual(b2.qcLock.__texture, "Interface\\PetBattles\\PetBattle-LockIcon")
end)

test("render: an armed button shows its name, no channel letter, no lock, no dim; its tooltip names the channel", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    NS.PadRender.Paint(b, ARMED, "iconLabel")
    assertEqual(b.qcLabel:GetText(), "Pull")
    -- red under: Dress making the qcTag font string again
    assertTrue(b.qcTag == nil, "no channel letter at the button's right edge")
    local lines = NS.PadRender.TooltipLines(ARMED)
    assertEqual(lines[2], "/p Pull")
    -- the channel by name, in its chat color (PARTY's 0.67, 0.67, 1)
    assertEqual(lines[3], "Channel: |cffababffParty|r")
    assertFalse(b.qcLock:IsShown())
    assertFalse(b.qcDim:IsShown())
    assertTrue(b.qcIcon:IsShown())
    assertTrue(b.qcSlot == ARMED)
end)

test("render: [review 5] a refused button is dimmed and its tooltip says why", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    local slot = { calloutId = "c2", name = "Bad", reason = "startsWithSlash" }
    NS.PadRender.Paint(b, slot, "iconLabel")
    assertTrue(b.qcDim:IsShown())
    local lines = NS.PadRender.TooltipLines(slot)
    assertEqual(lines[1], "Bad")
    assertEqual(lines[2], "Callout text cannot start with /.")
end)

-- The x offset of the label's RIGHT anchor on the button (the label anchored as the client keeps a
-- region's anchors: wow_mock's regions record none).
local function labelEnd(b)
    for i = 1, b.qcLabel:GetNumPoints() do
        local p, rel, relPoint, x = b.qcLabel:GetPoint(i)
        if p == "RIGHT" and rel == b and relPoint == "RIGHT" then return x end
    end
end

test("render: a locked button shows the padlock and names the lock; RefreshLock follows the slot", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    local slot = { calloutId = "c3", name = "Shout", line = "/s Go", concrete = "say", chatType = "SAY", lock = "lockdown" }
    m.__anchored(b.qcLabel, {})
    function b.qcLabel.ClearAllPoints(self) self.__anchors = {}; return self end
    NS.PadRender.Paint(b, slot, "iconLabel")
    assertTrue(b.qcLock:IsShown())
    assertFalse(b.qcDim:IsShown(), "locked is not refused: it stays armed")
    -- red under: end a locked button's label at the button's edge, under the padlock
    assertEqual(labelEnd(b), -14, "the label ends at the padlock")
    local lines = NS.PadRender.TooltipLines(slot)
    assertEqual(lines[2], "/s Go")
    assertTrue(lines[3]:find("Say", 1, true) ~= nil, "the channel")
    assertEqual(lines[4], "Locked: Say and Yell are blocked during this encounter.")
    slot.lock = nil
    NS.PadRender.RefreshLock(b)
    assertFalse(b.qcLock:IsShown())
    assertEqual(labelEnd(b), -4, "unlocked, the label runs to the button's edge again")
    local p1, rel = b.qcLabel:GetPoint(1)
    assertTrue(p1 == "LEFT" and rel == b.qcIcon, "and still starts at the icon")
    slot.lock = "lockdown"
    NS.PadRender.RefreshLock(b)
    assertEqual(labelEnd(b), -14, "a lock that comes in combat moves the end too")
end)

test("render: the style decides icon and label", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    NS.PadRender.Paint(b, ARMED, "icon")
    assertEqual(b.qcLabel:GetText(), "")
    assertTrue(b.qcIcon:IsShown())
    NS.PadRender.Paint(b, ARMED, "label")
    assertEqual(b.qcLabel:GetText(), "Pull")
    assertFalse(b.qcIcon:IsShown())
end)

test("render: a test-mode button and a solo self-print button are not dimmed, and say what they do", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    local test1 = { calloutId = "test.1.1", name = "Callout 1", reason = "testMode", concrete = "party" }
    NS.PadRender.Paint(b, test1, "iconLabel")
    assertFalse(b.qcDim:IsShown())
    assertEqual(NS.PadRender.TooltipLines(test1)[2], "Test mode: a placeholder that sends nothing.")
    local solo = { calloutId = "c4", name = "Hi", reason = "solo", selfText = "Hello" }
    NS.PadRender.Paint(b, solo, "iconLabel")
    assertFalse(b.qcDim:IsShown())
    assertEqual(NS.PadRender.TooltipLines(solo)[2], "Solo: prints to you, sends nothing.")
end)

test("render: flashes take the result's color; the cooldown dims and clears", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    NS.PadRender.Flash(b, "dropped")
    assertTrue(b.qcFlash:IsShown())
    assertEqual(b.qcFlash.__color[1], 0.9)
    NS.PadRender.Unflash(b)
    assertFalse(b.qcFlash:IsShown())
    NS.PadRender.SetCooling(b, true)
    assertTrue(b.qcCool:IsShown())
    NS.PadRender.SetCooling(b, false)
    assertFalse(b.qcCool:IsShown())
end)

test("render: the situation chip names the content, the dungeon and the key", function()
    local NS = T.newAddon()
    local R = NS.PadRender
    assertEqual(R.SituationText({ content = "mythicPlus", keyLevel = 14 }, "Windrunner Spire"),
        "M+ \194\183 Windrunner Spire +14")
    assertEqual(R.SituationText({ content = "raid" }), "Raid")
    assertEqual(R.SituationText(nil), "World")
    assertEqual(R.SectionTitle({ text = "Raid" }), "Raid")
    assertEqual(R.SectionTitle({ text = "Raid", tabIndex = 2, tabCount = 3 }), "Raid (2 of 3)")
end)

test("render: the header shows the lockdown chip and the stale hint on demand; no test label", function()
    local NS, m = T.enableAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    local header = m.CreateFrame("Frame", nil, root)
    local collapsed = 0
    NS.PadRender.DressHeader(header, function() collapsed = collapsed + 1 end)
    NS.PadRender.PaintHeader(header, { situation = "M+", lockdown = true, stale = false })
    assertEqual(header.qcSituation:GetText(), "M+")
    assertTrue(header.qcLockdown:IsShown())
    assertFalse(header.qcStale:IsShown())
    -- red under: the header keeping its own TEST MODE / PREVIEW label (it moved to the drag strip)
    assertNil(header.qcTest)
    NS.PadRender.PaintHeader(header, { situation = "M+", stale = true, collapsed = true })
    assertFalse(header.qcLockdown:IsShown())
    assertTrue(header.qcStale:IsShown())
    assertEqual(header.qcCollapse.qcText:GetText(), "+")
    header.qcCollapse:__fire("OnClick")
    assertEqual(collapsed, 1)
    -- a left click anywhere on the row toggles it too; another button does not
    header:__fire("OnMouseUp", "LeftButton")
    assertEqual(collapsed, 2)
    header:__fire("OnMouseUp", "RightButton")
    assertEqual(collapsed, 2)
end)

test("render: the drag-strip seam builds a hidden strip, and answers nil without the library", function()
    local NS, m = T.enableAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    local handle = NS.MakeDragHandle(root, { label = "Comms Pad", moveFrame = root })
    assertTrue(handle ~= nil)
    assertFalse(handle:IsShown(), "born hidden; the pad shows it when unlocked")
    local D = T.newAddon{ skip = T.loadAddon.libFiles }
    assertNil(D.MakeDragHandle(root, { label = "x", moveFrame = root }))
end)

test("render: [R3] the strip label is the pad's name, then PREVIEW or TEST MODE in green", function()
    local NS = T.newAddon()
    local R = NS.PadRender
    assertEqual(R.StripLabel("Comms Pad"), "Comms Pad")
    assertEqual(R.StripLabel("Raid pad", "PREVIEW"), "Raid pad  |cff19ff19PREVIEW|r")
    assertEqual(R.StripLabel("Raid pad", "TEST MODE"), "Raid pad  |cff19ff19TEST MODE|r")
end)

test("pad render: [phase 3] a previewed slot's tooltip shows its line and says it sends nothing", function()
    local NS = T.newAddon()
    local lines = NS.PadRender.TooltipLines({ name = "Lust", line = "/p Lust", preview = true })
    assertEqual(lines[2], "/p Lust")
    -- [final 9] a previewed wedge shares these lines, so the line names no surface
    assertEqual(lines[#lines - 1], "Preview: this sends nothing.")
    -- [echo review 2] a click prints the line, and the tooltip says so
    assertEqual(lines[#lines], "Click to print its line.")
    local solo = NS.PadRender.TooltipLines({ name = "Me", selfText = "x", preview = true })
    assertEqual(solo[#solo], "Preview: this sends nothing.", "no line, nothing to print")
end)

test("render: [phase 5] a pad's Look is a font and a skin; the defaults are the skin a pad always wore", function()
    local NS, m = T.enableAddon()
    m.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    local R, look = NS.PadRender, NS.Library.TEMPLATES.pad.look
    local font = R.LabelFont(NS.Library.TEMPLATES.pad.button)
    assertEqual(font.path, "Fonts\\FRIZQT__.TTF", "no LibSharedMedia here: the standard face")
    -- red under: no outline (owner, 2026-10-22: OUTLINE)
    assertEqual(font.size .. "|" .. font.flags .. "|" .. tostring(font.shadow), "10|OUTLINE|true")
    assertEqual(font.r + font.g + font.b + font.a, 4, "a button's label: white")
    local skin = R.SkinFor(look)
    assertEqual(skin.edgeFile, "Interface\\Buttons\\WHITE8x8", "None is the flat Ka0s edge")
    assertEqual(skin.edgeSize, 1)
    assertEqual(table.concat(skin.bg, ","), "0.06,0.06,0.08,0.92")
    assertEqual(table.concat(skin.border, ","), "0,0,0,1")
    assertNil(R.SkinFor({ borderSize = 0 }).edgeFile, "thickness 0 is no edge")
    local fs = button(NS, m).qcLabel
    R.ApplyFont(fs, R.LabelFont({ fontSize = 14, fontFlags = "OUTLINE", fontShadow = false,
        fontColor = { r = 1, g = 0, b = 0, a = 1 } }))
    assertEqual(table.concat(fs.__font, ","), "Fonts\\FRIZQT__.TTF,14,OUTLINE")
    assertEqual(table.concat(fs.__color, ","), "1,0,0,1")
    assertEqual(table.concat(fs.__shadow, ","), "0,0")
end)

test("render: [review] the skin's 1px inner line is kept only on the default flat 1px edge", function()
    local NS = T.enableAddon()
    local R = NS.PadRender
    local function alpha(skin) return skin.innerBorder and skin.innerBorder[4] end
    assertEqual(table.concat(R.SkinFor(NS.Library.TEMPLATES.pad.look).innerBorder, ","),
        table.concat(NS.SKIN.innerBorder, ","), "the default Look wears the Ka0s inner line")
    -- red under: SkinFor copying NS.SKIN's innerBorder whatever the border (a gray line at thickness 0)
    assertEqual(alpha(R.SkinFor({ borderSize = 0 })), 0, "thickness 0 is no edge at all")
    assertEqual(alpha(R.SkinFor({ borderSize = 4 })), 0, "no gray line over a thick edge")
    local fetch = NS.MediaFetch
    NS.MediaFetch = function(kind, name)
        if kind == "border" and name == "Tooltip" then return "Interface\\Tooltips\\UI-Tooltip-Border" end
        return fetch(kind, name)
    end
    local art = R.SkinFor({ borderStyle = "Tooltip", borderSize = 16 })
    assertEqual(art.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border")
    assertEqual(alpha(art), 0, "no gray line over border art")
    assertEqual(art.insets.left, 4, "the background reaches under the art's soft inner edge")
    assertEqual(R.SkinFor({ borderSize = 3 }).insets.left, 3, "a flat edge insets by its thickness")
end)

test("render: [review] a button's label runs to the button's right edge, on one line", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    local points, wrap = {}, nil
    b.qcLabel.ClearAllPoints = function(self) points = {} return self end
    b.qcLabel.SetPoint = function(self, ...) points[#points + 1] = { ... } return self end
    b.qcLabel.SetWordWrap = function(self, v) wrap = v return self end
    NS.PadRender.Paint(b, { name = "A very long callout name indeed", calloutId = "c1" }, "iconLabel")
    assertEqual(wrap, false, "one line")
    local right
    for _, pt in ipairs(points) do if pt[1] == "RIGHT" then right = pt end end
    -- red under: R.Paint anchoring the label LEFT only (a large font runs off the button)
    assertTrue(right ~= nil, "a right edge")
    -- red under: the label still bounded by a channel letter (the tag took the width it now uses)
    assertTrue(right[2] == b and right[3] == "RIGHT" and right[4] == -4, "the button's right edge, less its padding")
end)

test("render: [phase 5] Use class color takes the player's class color and keeps the swatch's alpha", function()
    local NS, m = T.enableAddon()
    m.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.75, b = 0.5 } }
    local font = NS.PadRender.LabelFont({ fontColor = { r = 1, g = 1, b = 1, a = 0.5 }, useClassColorFont = true })
    assertEqual(font.r .. "," .. font.g .. "," .. font.b .. "," .. font.a, "0.25,0.75,0.5,0.5")
    local skin = NS.PadRender.SkinFor({ background = { r = 0, g = 0, b = 0, a = 0.8 }, useClassColorBackground = true })
    assertEqual(table.concat(skin.bg, ","), "0.25,0.75,0.5,0.8")
    assertEqual(table.concat(NS.PadRender.SkinFor({ borderColor = { 0.1, 0.2, 0.3 } }).border, ","), "0.1,0.2,0.3,1",
        "a positional swatch, alpha 1 by default")
end)

test("render: [window] the section titles wear the Section header tab's font, gold by default", function()
    local NS, m = T.enableAddon()
    m.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.75, b = 0.5 } }
    local R = NS.PadRender
    -- red under: a white default in defaults/PadStyle.lua D.Section's fontColor (the titles were always gold)
    local t = R.TitleFont(NS.Library.TEMPLATES.pad.section)
    assertEqual(t.r .. "," .. t.g .. "," .. t.b .. "|" .. t.size, "1,0.82,0|12", "the owner's default: gold, 12 points")
    t = R.TitleFont({ fontSize = 12, fontColor = { r = 1, g = 0, b = 0, a = 1 } })
    assertEqual(t.r .. "," .. t.g .. "," .. t.b .. "|" .. t.size, "1,0,0|12", "a chosen color reaches the titles")
    t = R.TitleFont({ fontColor = { r = 1, g = 1, b = 1, a = 1 }, useClassColorFont = true })
    assertEqual(t.r .. "," .. t.g .. "," .. t.b, "0.25,0.75,0.5", "and so does the class color")
    t = R.TitleFont({ fontColor = { r = 1, g = 1, b = 1, a = 1 } })
    assertEqual(t.r .. "," .. t.g .. "," .. t.b, "1,1,1", "white is a color like any other now")
end)

test("render: [section header] SectionLook: no band by default, then the band's skin and the text's inset", function()
    local NS = T.enableAddon()
    local R = NS.PadRender
    local sl = R.SectionLook(NS.Library.TEMPLATES.pad.section)
    -- red under: a section look that draws an edge or a body by default (the titles never had one)
    assertNil(sl.skin.edgeFile, "no edge")
    assertEqual(sl.skin.bg[4], 0, "a clear body")
    assertEqual(sl.inset .. "|" .. sl.height .. "|" .. sl.font.size, "0|0|12", "the text on the band's edge, automatic height")
    local framed = R.SectionLook({ borderSize = 2, borderColor = { r = 1, g = 0, b = 0, a = 1 }, height = 22,
        background = { r = 0, g = 0, b = 1, a = 0.5 } })
    assertTrue(framed.skin.edgeFile ~= nil, "a flat edge")
    assertEqual(framed.inset, 2, "the text keeps clear of the edge")
    assertEqual(framed.height, 22)
    assertEqual(table.concat(framed.skin.bg, ","), "0,0,1,0.5")
    assertTrue(R.SectionLook({ borderSize = 2, borderColor = { r = 1, g = 0, b = 0, a = 1 }, height = 22,
        background = { r = 0, g = 0, b = 1, a = 0.5 } }, framed) == framed, "an unchanged look is reused")
end)

test("render: [icons] a glyph button is drawn in its color; the button repainted with another icon is white again", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    local star = NS.Icon("star")
    NS.PadRender.Paint(b, { calloutId = "c1", name = "Star", line = "/p Go", concrete = "party", chatType = "PARTY",
        icon = star, iconColor = "ff0000" }, "iconLabel")
    assertEqual(b.qcIcon.__texture, star)
    -- red under: Paint setting the texture only
    assertEqual(table.concat(b.qcIcon.__color, ","), "1,0,0")
    NS.PadRender.Paint(b, ARMED, "iconLabel")
    -- red under: tint only when the slot carries a color (a reused button keeps the old one)
    assertEqual(table.concat(b.qcIcon.__color, ","), "1,1,1")
end)

test("render: [B3] a button's label is one line, and hidden when the button leaves it no room", function()
    local NS, m = T.enableAddon()
    local b = button(NS, m)
    local lines
    b.qcLabel.SetMaxLines = function(self, n) lines = n return self end
    NS.PadRender.Paint(b, ARMED, "iconLabel", 140)
    -- red under: R.Paint without SetMaxLines(1) (a narrow button wraps its label)
    assertEqual(lines, 1, "one line, truncated")
    assertTrue(b.qcLabel:IsShown(), "room for it at 140")
    NS.PadRender.Paint(b, ARMED, "iconLabel", 20)
    assertFalse(b.qcLabel:IsShown(), "no room beside the icon: hidden")
    NS.PadRender.Paint(b, ARMED, "label", 20)
    assertTrue(b.qcLabel:IsShown(), "a label-only button has room at 20")
    NS.PadRender.Paint(b, ARMED, "label", 8)
    assertFalse(b.qcLabel:IsShown())
    NS.PadRender.Paint(b, ARMED, "iconLabel")
    assertTrue(b.qcLabel:IsShown(), "no width given: shown")
    assertTrue(NS.PadRender.LabelRoom(140, "iconLabel") > 0)
    assertEqual(NS.PadRender.LabelRoom(34, "iconLabel"), 8,
        "22 for the default 16-pixel icon and its gaps, 4 for the right padding, no channel letter")
    assertTrue(NS.PadRender.LabelRoom(26, "iconLabel") <= 0)
end)

-- ── the shine overlay (Shine T3) ────────────────────────────────────────────────────────────

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function livePad()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function padButtons(NS)
    local out = {}
    for _, btn in ipairs(NS.Pad.Instance("p1").buttons.active) do
        if btn:IsShown() then out[#out + 1] = btn end
    end
    return out
end

-- Every texture a dial ring holds under its qc* fields (and the lists of them), two levels deep.
local function shineTextures(ring)
    local found = {}
    local function visit(v, depth)
        if type(v) ~= "table" or depth > 2 then return end
        if type(v.__texture) == "string" and v.__texture:find("shine-", 1, true) then found[#found + 1] = v end
        if v.qcShine and v.qcShine.IsShown and v.qcShine:IsShown() then found[#found + 1] = v.qcShine end
        for k, child in pairs(v) do
            if (type(k) == "number" or (type(k) == "string" and k:find("^qc"))) and child ~= ring then
                visit(child, depth + 1)
            end
        end
    end
    visit(ring, 0)
    return found
end

-- A button's shine shown: any of its three pieces (modules/Shine.lua).
local function shineShown(btn)
    local set = btn.qcShine
    return set ~= nil and (set.left:IsShown() or set.mid:IsShown() or set.right:IsShown())
end

test("pad render: [shine] a look on the Buttons tab paints every button", function()
    local NS = livePad()
    local S = NS.SchemaRuntime
    for _, btn in ipairs(padButtons(NS)) do
        -- red under: shineLook "none" in defaults/PadStyle.lua Button (owner, 2026-10-22: Gloss fade)
        assertTrue(shineShown(btn), "Gloss fade by default")
    end
    assertTrue(S.Set("pad.button.shineLook", "none", "p1"))
    for _, btn in ipairs(padButtons(NS)) do
        assertFalse(shineShown(btn), "None: no shine")
    end
    assertTrue(S.Set("pad.button.shineLook", "gloss", "p1"))
    local buttons = padButtons(NS)
    assertTrue(#buttons > 0)
    for _, btn in ipairs(buttons) do
        -- red under: R.ApplyButtonLook never calling NS.Shine.Apply
        assertTrue(shineShown(btn), "every visible button takes the shine")
        local set = btn.qcShine
        assertEqual(set.left.__texture, NS.Shine.Texture("pad", "gloss"))
        -- red under: the shine laid over the icon only (owner, 2026-10-21: the whole button)
        local _, rel = set.left:GetPoint(1)
        assertTrue(rel == btn, "the left cap on the button's own corner, not the icon")
        local _, rrel = set.right:GetPoint(1)
        assertTrue(rrel == btn, "the right cap on the button's other corner")
        assertEqual(set.left.__size[1], btn.__h / 2, "a cap half the button's height wide")
        assertEqual(set.mid:IsShown(), btn.__w > btn.__h, "the middle spans a wide button")
        assertEqual(set.left.__color[4], 0.8, "the default Strength (80)")
    end
    assertTrue(S.Set("pad.button.shineStrength", 40, "p1"))
    -- red under: the button look's signature leaving out the shine leaves (the old look reused)
    assertEqual(padButtons(NS)[1].qcShine.left.__color[4], 0.4)
    assertTrue(S.Set("pad.layout.style", "label", "p1"))
    for _, btn in ipairs(padButtons(NS)) do
        assertTrue(shineShown(btn), "a label-only button keeps its shine: it covers the plate, not the icon")
    end
    assertTrue(S.Set("pad.layout.style", "icon", "p1"))
    for _, btn in ipairs(padButtons(NS)) do
        assertTrue(shineShown(btn), "an icon-only button")
        assertFalse(btn.qcShine.mid:IsShown(), "is square: no middle")
    end
    assertTrue(S.Set("pad.layout.style", "iconLabel", "p1"))
    assertTrue(S.Set("pad.button.shineLook", "none", "p1"))
    for _, btn in ipairs(padButtons(NS)) do
        assertFalse(shineShown(btn), "None hides it")
    end
    local look = NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button)
    assertEqual(look.shine.look, "none", "the look carries its shine")
end)

test("pad render: [shine] the pad's look leaves the dial alone", function()
    local NS = livePad()
    assertTrue(NS.SchemaRuntime.Set("pad.button.shineLook", "orb", "p1"))
    assertTrue(shineShown(padButtons(NS)[1]), "the pad wears its orb")
    local snap = NS.Situation.Current()
    local group = { id = T.seeded(NS, "bi.mplus"), title = "Dungeon", slots = {} }
    for i, cid in ipairs(NS.Library.Group(T.seeded(NS, "bi.mplus")).callouts) do
        if i > 4 then break end
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    local rings, open = NS.DialLayout.Rings({ group }, { slices = 4, title = "Comms Dial" })
    assertTrue(NS.Dial.Apply(1, "d2", { kind = "dial", surfaceId = "d2", snapshot = snap,
        order = { T.seeded(NS, "bi.mplus") }, active = {}, rings = rings, openRing = open }))
    for i, ring in ipairs(NS.Dial.Instance("d2").rings.active) do
        assertEqual(#shineTextures(ring), 0, "ring " .. i .. ": the dial at None carries no shine")
    end
end)
