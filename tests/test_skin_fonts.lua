-- tests/test_skin_fonts.lua — the HUD font settings against LibKa0s v1.82.0 (QC-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK):
--
-- - D-07: every font block is the minimum set (face with "Use the skin's font", size, color with a
--   class-color option, flags, shadow), and its Font flags lead with From skin ("@skin"), the
--   default, drawn through S.FontFlags, so it follows the Skin tab's Font outline; a picked flag wins.
-- - Addendum 01: a stored flag equal to the previous default (OUTLINE, every block's) moves to From
--   skin once, per profile: schema step 11. A flag the player changed stays.
-- - D-09: a block that uses the skin's face draws at S.HudFontSize(stored), scaled by the skin's HUD
--   size; its own face, or Ignore fonts, draws the stored size. The stored size is never written.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles
local OWNER = "QuickComms"

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

-- Every font block, by surface kind: the pad's header, section titles and buttons, the dial's slice
-- labels and ring title.
local FONT_BLOCKS = { pad = { "header", "section", "button" }, dial = { "label", "title" } }

--- An enabled instance, its default pad and dial built under an M+ read.
local function live()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m, m.LibStub("LibKa0s-Skin-1.0")
end

local function firstButton(NS) return NS.Pad.Instance("p1").buttons.active[1] end

local function set(NS, path, value, id)
    assertTrue(NS.SchemaRuntime.Set(path, value, id), path)
end

-- ── D-07: the minimum set and From skin ────────────────────────────────────────────────────────

test("skin fonts: every font block carries the minimum set, its flags led by From skin", function()
    local NS = live()
    local S = NS.SchemaRuntime
    local n = 0
    for kind, blocks in pairs(FONT_BLOCKS) do
        for _, block in ipairs(blocks) do
            local p = kind .. "." .. block .. "."
            for _, leaf in ipairs({ "font", "fontFromSkin", "fontSize", "fontColor", "useClassColorFont",
                "fontFlags", "fontShadow" }) do
                assertTrue(S.FindRow(p .. leaf) ~= nil, p .. leaf .. " is a row")
            end
            local row = S.FindRow(p .. "fontFlags")
            -- red under: FontGroup without flagsFromSkin (no From skin, OUTLINE the default)
            assertEqual(row.default, "@skin", p .. "fontFlags defaults to From skin")
            n = n + 1
        end
    end
    assertEqual(n, 5, "three pad blocks and two dial blocks")
end)

test("skin fonts: a fresh pad and dial store From skin, and /qc set takes it and every picked flag", function()
    local NS = live()
    local p = NS.db.profile
    for kind, blocks in pairs(FONT_BLOCKS) do
        local surface = kind == "pad" and p.pads.p1 or p.dials.d2
        for _, block in ipairs(blocks) do
            assertEqual(surface[block].fontFlags, "@skin", kind .. "." .. block)
        end
    end
    set(NS, "pad.button.fontFlags", "THICKOUTLINE", "p1")
    set(NS, "pad.button.fontFlags", "@skin", "p1")
    assertFalse((NS.SchemaRuntime.Set("pad.button.fontFlags", "SPARKLY", "p1")), "an unknown flag is refused")
end)

test("skin fonts: From skin follows the Font outline; a picked flag wins under every mode", function()
    local NS = live()
    -- red under: LabelFont drawing the stored "@skin" as the flags (SetFont reads it as none)
    assertEqual(firstButton(NS).qcLabel.__font[3], "OUTLINE", "All text: outlined")
    set(NS, "skin.outline", "hud")
    assertEqual(firstButton(NS).qcLabel.__font[3], "OUTLINE", "HUD text only: the pad is HUD text")
    set(NS, "skin.outline", "off")
    assertEqual(firstButton(NS).qcLabel.__font[3], "", "Off: no outline")
    assertEqual(NS.Pad.Instance("p1").header.qcSituation.__font[3], "", "the header too")
    set(NS, "pad.button.fontFlags", "THICKOUTLINE", "p1")
    assertEqual(firstButton(NS).qcLabel.__font[3], "THICKOUTLINE", "the player's pick wins")
    set(NS, "skin.outline", "all")
    assertEqual(firstButton(NS).qcLabel.__font[3], "THICKOUTLINE", "under every mode")
end)

test("skin fonts: a dial's slice labels and ring title follow the Font outline too", function()
    local NS, m = live()
    set(NS, "skin.outline", "off")
    m.__click(NS.Dial.Instance("d2").header)
    local wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2") or 1)[1]
    assertEqual(wedge.qcLabel.__font[3], "", "a slice label: Off")
    set(NS, "skin.outline", "all")
    wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2") or 1)[1]
    assertEqual(wedge.qcLabel.__font[3], "OUTLINE", "a slice label: All text")
end)

test("skin fonts: under Ignore fonts From skin is OUTLINE, the flags these blocks always had", function()
    local NS, _, Skin = live()
    set(NS, "skin.outline", "off")
    Skin:SetIgnore(OWNER, nil, true)
    assertEqual(firstButton(NS).qcLabel.__font[3], "OUTLINE")
    Skin:SetIgnore(OWNER, nil, false)
    assertEqual(firstButton(NS).qcLabel.__font[3], "", "the outline setting is read again")
end)

test("skin fonts: without the library a block's From skin draws OUTLINE", function()
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    local font = NS.PadRender.LabelFont({ fontFlags = "@skin", fontSize = 12, fontFromSkin = true })
    assertEqual(font.flags, "OUTLINE")
    assertEqual(font.size, 12, "the stored size, unscaled")
    assertEqual(NS.PadRender.LabelFont({ fontFlags = "MONOCHROME" }).flags, "MONOCHROME")
end)

-- ── Addendum 01: schema step 11 ────────────────────────────────────────────────────────────────

local function storedProfile()
    return {
        pads = { p9 = {
            header = { fontFlags = "OUTLINE" }, section = { fontFlags = "THICKOUTLINE" },
            button = { fontFlags = "" },
        } },
        dials = { d9 = { label = { fontFlags = "OUTLINE" }, title = { fontFlags = "OUTLINE" } } },
    }
end

test("skin fonts: step 11 moves a stored OUTLINE to From skin and keeps every other flag", function()
    local NS = live()
    assertEqual(NS.SCHEMA_VERSION, 11, "the move is step 11")
    local p = storedProfile()
    -- red under: no step
    NS.Library.MigrateFontFlags(p)
    assertEqual(p.pads.p9.header.fontFlags, "@skin", "the old default follows the skin now")
    assertEqual(p.pads.p9.section.fontFlags, "THICKOUTLINE", "the player's pick stays")
    assertEqual(p.pads.p9.button.fontFlags, "", "None is a pick too")
    assertEqual(p.dials.d9.label.fontFlags, "@skin")
    assertEqual(p.dials.d9.title.fontFlags, "@skin")
    NS.Library.MigrateFontFlags(p)
    assertEqual(p.pads.p9.section.fontFlags, "THICKOUTLINE", "idempotent")
    NS.Library.MigrateFontFlags({ pads = { bad = true, p = { header = "x" } }, dials = 3 })   -- damage left alone
end)

test("skin fonts: step 11 runs once per profile: OUTLINE picked afterwards stays OUTLINE", function()
    local NS = live()
    local db = NS.addon.db
    db.profile.pads.p1.header.fontFlags = "OUTLINE"
    db.global.schemaVersion = 10
    -- red under: the step missing, or not perProfile
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, 11)
    assertEqual(db.profile.pads.p1.header.fontFlags, "@skin", "the one-time move")
    set(NS, "pad.header.fontFlags", "OUTLINE", "p1")
    NS.addon:RunMigrations()
    NS.addon:OnProfileChanged(nil, nil, db:GetCurrentProfile())
    assertEqual(db.profile.pads.p1.header.fontFlags, "OUTLINE", "the player's later pick is kept")
end)

-- ── D-09: the HUD size scale ───────────────────────────────────────────────────────────────────

test("skin fonts: a block on the skin's face draws at the skin's HUD scale; the stored size stays", function()
    local NS = live()
    set(NS, "pad.button.fontSize", 12, "p1")
    assertEqual(firstButton(NS).qcLabel.__font[2], 12, "Ka0s Default draws 12 at 12")
    set(NS, "skin.skin", "obsidian")
    local want = NS.Skin.HudFontSize(12, true)
    assertTrue(want ~= 12, "Obsidian's HUD scale is not Ka0s Default's (the case means something)")
    -- red under: LabelFont drawing the stored size whatever the skin
    assertEqual(firstButton(NS).qcLabel.__font[2], want, "Obsidian scales it")
    assertEqual(NS.db.profile.pads.p1.button.fontSize, 12, "the stored size is never rewritten")
    set(NS, "pad.button.fontFromSkin", false, "p1")
    assertEqual(firstButton(NS).qcLabel.__font[2], 12, "its own face: unscaled")
end)

test("skin fonts: under Ignore fonts a following block draws its stored size", function()
    local NS, _, Skin = live()
    set(NS, "pad.button.fontSize", 12, "p1")
    set(NS, "skin.skin", "obsidian")
    Skin:SetIgnore(OWNER, nil, true)
    assertEqual(firstButton(NS).qcLabel.__font[2], 12)
    Skin:SetIgnore(OWNER, nil, false)
end)

test("skin fonts: a dial's slice labels scale with the skin's HUD size", function()
    local NS, m = live()
    set(NS, "dial.label.fontSize", 12, "d2")
    set(NS, "skin.skin", "obsidian")
    m.__click(NS.Dial.Instance("d2").header)
    local wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2") or 1)[1]
    assertEqual(wedge.qcLabel.__font[2], NS.Skin.HudFontSize(12, true))
end)

test("skin fonts: a pad's buttons grow with the size they draw at, not the size they store", function()
    -- red under: Pad.Apply sizing its cells from the stored button.fontSize
    local NS = live()
    set(NS, "pad.button.fontSize", 30, "p1")
    set(NS, "pad.button.height", 0, "p1")
    local h12 = firstButton(NS).__h
    set(NS, "skin.skin", "obsidian")
    local drawn = NS.Skin.HudFontSize(30, true)
    local h = firstButton(NS).__h
    assertTrue(drawn > 30, "Obsidian draws it larger")
    assertTrue(h > h12, ("the cell grows with the drawn size (%s -> %s)"):format(tostring(h12), tostring(h)))
end)
