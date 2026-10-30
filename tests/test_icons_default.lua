-- tests/test_icons_default.lua — the glyphs a member with no icon of its own draws (QC-02 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-21; the owner's item 15,
-- image-52 and image-53):
--
-- - test mode's four groups wear numbered glyphs, ph:number-circle-one to -four, each tinted, so the
--   dial's first ring reads 1 to 4 where it drew four red question marks;
-- - a real group (a dial ring) or callout saved with no icon draws ph:folder-simple /
--   ph:chat-circle-dots, on a pad, on a dial and in the settings editors' previews;
-- - the Blizzard question mark is drawn only without the library (no catalog to draw from).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local NO_LIBKA0S = T.loadAddon.libFiles
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local NUMBERS = { "ph:number-circle-one", "ph:number-circle-two", "ph:number-circle-three", "ph:number-circle-four" }

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

-- ── test mode's groups ─────────────────────────────────────────────────────────────────────────

test("default icons: test mode's dial rings 1 to 4 wear the numbered glyphs, each tinted", function()
    local NS = live()
    local plan = NS.Surfaces.TestDialPlan("d2", NS.db.profile.dials.d2)
    local first = plan.rings[plan.openRing or 1] or plan.rings[1]
    local seen, n = {}, 0
    for _, item in ipairs(first.items) do
        if item.kind == "ring" then
            n = n + 1
            -- red under: test groups built with no icon (the dial drew the question mark, image-52)
            assertTrue(item.icon ~= nil, "ring " .. n .. " has an icon")
            assertEqual(item.icon, NS.Icon(NUMBERS[n]), "ring " .. n .. " is its number")
            assertTrue(NS.Library.IsGlyph(item.icon) ~= nil, "a LibKa0s glyph")
            assertTrue(NS.Library.ValidIconColor(item.iconColor), "tinted")
            assertTrue(not seen[item.icon], "four distinct glyphs")
            seen[item.icon] = true
        end
    end
    assertEqual(n, 4, "the four test groups on the first ring")
end)

test("default icons: test mode's pad sections carry the same glyphs", function()
    local NS = live()
    local plan = NS.Surfaces.TestPlan("p1")
    for s, section in ipairs(plan.sections) do
        assertEqual(section.icon, NS.Icon(NUMBERS[s]), "section " .. s)
        assertTrue(NS.Library.ValidIconColor(section.iconColor), "section " .. s .. " tinted")
    end
end)

test("default icons: the four glyphs ship in the vendored payload", function()
    -- The prune keeps what CLAUDE.md's `LibKa0s icons:` line declares (all, for the icon browser); a
    -- texture path the catalog answers for a missing file would draw nothing in the client.
    local NS = live()
    for _, name in ipairs({ NUMBERS[1], NUMBERS[2], NUMBERS[3], NUMBERS[4], "ph:folder-simple", "ph:chat-circle-dots" }) do
        local path = NS.Icon(name)
        assertTrue(path ~= nil, name .. " is in the catalog")
        local rel = path:gsub("^Interface\\AddOns\\QuickComms\\", ""):gsub("\\", "/")
        local f = io.open(T.root .. "/" .. rel .. ".tga", "rb") or io.open(T.root .. "/" .. rel, "rb")
        assertTrue(f ~= nil, name .. " ships at " .. rel)
        if f then f:close() end
    end
end)

-- ── the defaults ───────────────────────────────────────────────────────────────────────────────

test("default icons: a group's default is the folder, a callout's the speech bubble", function()
    local NS = live()
    assertEqual(NS.DefaultIcon("group"), NS.Icon("ph:folder-simple"))
    assertEqual(NS.DefaultIcon("ring"), NS.Icon("ph:folder-simple"), "a dial ring is a group")
    assertEqual(NS.DefaultIcon("callout"), NS.Icon("ph:chat-circle-dots"))
    assertEqual(NS.DefaultIcon(), NS.Icon("ph:chat-circle-dots"), "anything else is a callout")
end)

test("default icons: without the library the question mark is the one default", function()
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    assertEqual(NS.DefaultIcon("group"), QUESTION)
    assertEqual(NS.DefaultIcon("callout"), QUESTION)
end)

test("default icons: a pad button for a callout with no icon draws the speech bubble", function()
    local NS = live()
    local btn = NS.Pad.Instance("p1").buttons.active[1]
    -- red under: Pad_Render.Paint's `slot.icon or DEFAULT_ICON` (the question mark)
    NS.PadRender.Paint(btn, { calloutId = "c1", name = "Mine", icon = false }, "both", 100)
    assertEqual(btn.qcIcon.__texture, NS.Icon("ph:chat-circle-dots"))
end)

test("default icons: a dial's group wedge with no icon draws the folder, a callout's the bubble", function()
    local NS, m = live()
    m.__click(NS.Dial.Instance("d2").header)
    local wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2") or 1)[1]
    local geo = { lx = 0, ly = 0 }
    -- red under: Dial_Render.PaintWedge's `item.icon or DEFAULT_ICON`
    NS.DialRender.PaintWedge(wedge, { kind = "ring", title = "Mine", icon = false }, geo)
    assertEqual(wedge.qcIcon.__texture, NS.Icon("ph:folder-simple"), "a ring")
    NS.DialRender.PaintWedge(wedge, { kind = "send", title = "Pull", slot = { calloutId = "c1" } }, geo)
    assertEqual(wedge.qcIcon.__texture, NS.Icon("ph:chat-circle-dots"), "a callout")
end)

test("default icons: the editors' preview shows what the member draws", function()
    local NS = live()
    local Ed = NS.addon.Settings.Editors
    -- red under: Ed.NO_ICON, the question mark the member never draws
    assertEqual(Ed.NoIcon("group"), NS.DefaultIcon("group"))
    assertEqual(Ed.NoIcon("callout"), NS.DefaultIcon("callout"))
end)
