-- tests/test_pad_render.lua — modules/Pad_Render.lua (spec §10.1): what a chip and the pad's header
-- show, and the drag-strip seam (core/WidgetsSetup.lua). Frames come from the mock's QuickComms
-- branch, whose regions are objects of their own.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local ARMED = { calloutId = "c1", name = "Pull", line = "/p Pull", concrete = "party", chatType = "PARTY" }

local function chip(NS, m)
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    return NS.PadRender.Dress(NS.SendEngine.NewButton(root)), root
end

test("render: Dress builds a chip's regions once, each its own object", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local icon = b.qcIcon
    assertTrue(icon ~= b and b.qcLabel ~= b and b.qcLock ~= b)
    NS.PadRender.Dress(b)
    assertTrue(b.qcIcon == icon, "dressed once")
    assertFalse(b.qcDim:IsShown())
    assertFalse(b.qcFlash:IsShown())
end)

test("render: [audit QC-07] the chip's padlock is the catalog's lock mark, tinted gold; the Blizzard art is the nil fallback", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    -- red under: SetTexture(LOCK_ICON) unconditionally in PadRender.Dress
    assertTrue(NS.Icon("lock") ~= nil)
    assertEqual(b.qcLock.__texture, NS.Icon("lock"))
    assertEqual(b.qcLock.__color[1], NS.Constants.GOLD.r)
    local real = NS.Icon
    NS.Icon = function() return nil end
    local b2 = chip(NS, m)
    NS.Icon = real
    assertEqual(b2.qcLock.__texture, "Interface\\PetBattles\\PetBattle-LockIcon")
end)

test("render: an armed chip shows its name, its channel tag in the chat color, no lock, no dim", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    NS.PadRender.Paint(b, ARMED, "iconLabel")
    assertEqual(b.qcLabel:GetText(), "Pull")
    assertEqual(b.qcTag:GetText(), "P")
    assertEqual(b.qcTag.__color[1], 0.67)
    assertFalse(b.qcLock:IsShown())
    assertFalse(b.qcDim:IsShown())
    assertTrue(b.qcIcon:IsShown())
    assertTrue(b.qcSlot == ARMED)
end)

test("render: [review 5] a refused chip is dimmed and its tooltip says why", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local slot = { calloutId = "c2", name = "Bad", reason = "startsWithSlash" }
    NS.PadRender.Paint(b, slot, "iconLabel")
    assertTrue(b.qcDim:IsShown())
    local lines = NS.PadRender.TooltipLines(slot)
    assertEqual(lines[1], "Bad")
    assertEqual(lines[2], "Callout text cannot start with /.")
end)

test("render: a locked chip shows the padlock and names the lock; RefreshLock follows the slot", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local slot = { calloutId = "c3", name = "Shout", line = "/s Go", concrete = "say", chatType = "SAY", lock = "lockdown" }
    NS.PadRender.Paint(b, slot, "iconLabel")
    assertTrue(b.qcLock:IsShown())
    assertFalse(b.qcDim:IsShown(), "locked is not refused: it stays armed")
    local lines = NS.PadRender.TooltipLines(slot)
    assertEqual(lines[2], "/s Go")
    assertEqual(lines[3], "Locked: Say and Yell are blocked during this encounter.")
    slot.lock = nil
    NS.PadRender.RefreshLock(b)
    assertFalse(b.qcLock:IsShown())
end)

test("render: the style decides icon and label", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    NS.PadRender.Paint(b, ARMED, "icon")
    assertEqual(b.qcLabel:GetText(), "")
    assertTrue(b.qcIcon:IsShown())
    NS.PadRender.Paint(b, ARMED, "label")
    assertEqual(b.qcLabel:GetText(), "Pull")
    assertFalse(b.qcIcon:IsShown())
end)

test("render: a test-mode chip and a solo self-print chip are not dimmed, and say what they do", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
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
    local b = chip(NS, m)
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

test("render: the header shows the lockdown chip, the stale hint and the test label on demand", function()
    local NS, m = T.enableAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    local header = m.CreateFrame("Frame", nil, root)
    local collapsed = 0
    NS.PadRender.DressHeader(header, function() collapsed = collapsed + 1 end)
    NS.PadRender.PaintHeader(header, { situation = "M+", lockdown = true, stale = false, test = false })
    assertEqual(header.qcSituation:GetText(), "M+")
    assertTrue(header.qcLockdown:IsShown())
    assertFalse(header.qcStale:IsShown())
    assertFalse(header.qcTest:IsShown())
    NS.PadRender.PaintHeader(header, { situation = "M+", stale = true, test = true, collapsed = true })
    assertFalse(header.qcLockdown:IsShown())
    assertTrue(header.qcStale:IsShown())
    assertTrue(header.qcTest:IsShown())
    assertEqual(header.qcCollapse.qcText:GetText(), "+")
    header.qcCollapse:__fire("OnClick")
    assertEqual(collapsed, 1)
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

test("pad render: [phase 3] a previewed slot's tooltip shows its line and says it sends nothing", function()
    local NS = T.newAddon()
    local lines = NS.PadRender.TooltipLines({ name = "Lust", line = "/p Lust", preview = true })
    assertEqual(lines[2], "/p Lust")
    -- [final 9] a previewed wedge shares these lines, so the line names no surface
    assertEqual(lines[#lines], "Preview: this sends nothing.")
end)

test("render: [phase 5] a pad's Look is a font and a skin; the defaults are the skin a pad always wore", function()
    local NS, m = T.enableAddon()
    m.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    local R, look = NS.PadRender, NS.Library.TEMPLATES.pad.look
    local font = R.LabelFont(look)
    assertEqual(font.path, "Fonts\\FRIZQT__.TTF", "no LibSharedMedia here: the standard face")
    assertEqual(font.size .. "|" .. font.flags .. "|" .. tostring(font.shadow), "10||true")
    assertEqual(font.r + font.g + font.b + font.a, 4, "white")
    local skin = R.SkinFor(look)
    assertEqual(skin.edgeFile, "Interface\\Buttons\\WHITE8x8", "None is the flat Ka0s edge")
    assertEqual(skin.edgeSize, 1)
    assertEqual(table.concat(skin.bg, ","), "0.06,0.06,0.08,0.92")
    assertEqual(table.concat(skin.border, ","), "0,0,0,1")
    assertNil(R.SkinFor({ borderSize = 0 }).edgeFile, "thickness 0 is no edge")
    local fs = chip(NS, m).qcLabel
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

test("render: [review] a chip's label stops short of the channel tag, on one line", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local points, wrap = {}, nil
    b.qcLabel.ClearAllPoints = function(self) points = {} return self end
    b.qcLabel.SetPoint = function(self, ...) points[#points + 1] = { ... } return self end
    b.qcLabel.SetWordWrap = function(self, v) wrap = v return self end
    NS.PadRender.Paint(b, { name = "A very long callout name indeed", calloutId = "c1" }, "iconLabel")
    assertEqual(wrap, false, "one line")
    local right
    for _, pt in ipairs(points) do if pt[1] == "RIGHT" then right = pt end end
    -- red under: R.Paint anchoring the label LEFT only (a large font runs under the tag and off the chip)
    assertTrue(right ~= nil, "a right edge")
    assertTrue(right[2] == b.qcTag, "bounded by the tag")
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

test("render: [phase 5] a section title keeps its gold until the player colors the font", function()
    local NS, m = T.enableAddon()
    m.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.75, b = 0.5 } }
    local R = NS.PadRender
    -- red under: apply the label font to the titles in modules/Pad.lua's place() (they turn white)
    local t = R.TitleFont(R.LabelFont(NS.Library.TEMPLATES.pad.look))
    assertEqual(t.r .. "," .. t.g .. "," .. t.b .. "|" .. t.size, "1,0.82,0|10", "the default Look: gold, as before")
    t = R.TitleFont(R.LabelFont({ fontSize = 12, fontColor = { r = 1, g = 0, b = 0, a = 1 } }))
    assertEqual(t.r .. "," .. t.g .. "," .. t.b .. "|" .. t.size, "1,0,0|12", "a chosen color reaches the titles")
    t = R.TitleFont(R.LabelFont({ fontColor = { r = 1, g = 1, b = 1, a = 1 }, useClassColorFont = true }))
    assertEqual(t.r .. "," .. t.g .. "," .. t.b, "0.25,0.75,0.5", "and so does the class color")
end)

test("render: [icons] a glyph chip is drawn in its color; the chip repainted with another icon is white again", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local star = NS.Icon("star")
    NS.PadRender.Paint(b, { calloutId = "c1", name = "Star", line = "/p Go", concrete = "party", chatType = "PARTY",
        icon = star, iconColor = "ff0000" }, "iconLabel")
    assertEqual(b.qcIcon.__texture, star)
    -- red under: Paint setting the texture only
    assertEqual(table.concat(b.qcIcon.__color, ","), "1,0,0")
    NS.PadRender.Paint(b, ARMED, "iconLabel")
    -- red under: tint only when the slot carries a color (a reused chip keeps the old one)
    assertEqual(table.concat(b.qcIcon.__color, ","), "1,1,1")
end)

test("render: [B3] a chip's label is one line, and hidden when the chip leaves it no room", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local lines
    b.qcLabel.SetMaxLines = function(self, n) lines = n return self end
    NS.PadRender.Paint(b, ARMED, "iconLabel", 140)
    -- red under: R.Paint without SetMaxLines(1) (a narrow chip wraps its label)
    assertEqual(lines, 1, "one line, truncated")
    assertTrue(b.qcLabel:IsShown(), "room for it at 140")
    NS.PadRender.Paint(b, ARMED, "iconLabel", 20)
    assertFalse(b.qcLabel:IsShown(), "no room beside the icon: hidden")
    NS.PadRender.Paint(b, ARMED, "label", 20)
    assertTrue(b.qcLabel:IsShown(), "a label-only chip has room at 20")
    NS.PadRender.Paint(b, ARMED, "label", 8)
    assertFalse(b.qcLabel:IsShown())
    NS.PadRender.Paint(b, ARMED, "iconLabel")
    assertTrue(b.qcLabel:IsShown(), "no width given: shown")
    assertTrue(NS.PadRender.LabelRoom(140, "iconLabel", 0) > 0)
    assertTrue(NS.PadRender.LabelRoom(30, "iconLabel", 10) <= 0, "the tag takes its room too")
end)
