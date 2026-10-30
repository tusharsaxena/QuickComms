-- tests/test_skin_hud.lua — the HUD painted through the skin (QC-03; skinning-§6, anti-pattern #107):
-- the Comms Pads and the Comms Dials.
--
-- What this addon owes and nothing the library pins itself: every font block's face and every border
-- block's style follow the skin while its composer companion ("Use the skin's font / border") is on,
-- and the companions default on (DECISIONS X3); only faces and border styles follow, never a color the
-- player set (X4); the chrome no setting names (the padlock, the veils, the hover wash, the send
-- flashes, the lockdown and stale tags, the PREVIEW / TEST MODE marks, an arrow at an end, the tooltip
-- lines) reads a token whose Ka0s Default value is today's pixel, and moves with a skin switch; and the
-- one-time reset onto the skin (the owner's ruling O2) is schema step 10, which turns every stored
-- companion on once and keeps a pick the player makes afterwards. Ignore fonts reaches the HUD
-- through the library (LibKa0s v1.81.0, R-1): a following face draws its stored pick while it is on.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER, OTHER = "QuickComms", "obsidian"
local NO_LIBKA0S = T.loadAddon.libFiles

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local OXANIUM = "Interface\\AddOns\\QuickComms\\libs\\LibKa0s\\fonts\\Oxanium-SemiBold.ttf"
local ARIAL = "Fonts\\ARIALN.TTF"
local TOOLTIP = "Interface\\Tooltips\\UI-Tooltip-Border"
local FLAT = "Interface\\Buttons\\WHITE8x8"
local SOLID = "Interface\\Buttons\\WHITE8X8"

-- A LibSharedMedia that knows Ka0s Default's HUD face, one other face and one border art.
local function withMedia(mm)
    local lsm = mm.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    local media = { font = { Arial = ARIAL, ["Ka0s Oxanium SemiBold"] = OXANIUM }, border = { Tooltip = TOOLTIP } }
    function lsm.Register() end
    function lsm.IsValid() return true end
    function lsm.HashTable(_, kind) return media[kind] or {} end
    function lsm.Fetch(_, kind, name) return media[kind] and media[kind][name] end
    lsm.MediaType = {}
end

--- An enabled instance, its default pad and dial built under an M+ read, with the media above.
local function live()
    local NS, m = T.enableAddon{ mock = withMedia }
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m, m.LibStub("LibKa0s-Skin-1.0")
end

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

local function assertColor(got, want, what)
    assertTrue(type(got) == "table", what .. ": nothing painted")
    for i = 1, 4 do
        assertTrue(near(got[i], want[i]),
            ("%s[%d]: got %s, want %s"):format(what, i, tostring(got[i]), tostring(want[i])))
    end
end

--- The value `name` answers for this owner now: a library token or one of its own.
local function now(NS, name)
    local r, g, b, a = NS.Skin.Color(name)
    return { r, g, b, a or 1 }
end

local function firstButton(NS) return NS.Pad.Instance("p1").buttons.active[1] end

local function set(NS, path, value, id)
    assertTrue(NS.SchemaRuntime.Set(path, value, id), path)
end

-- ── the companions (X3) ─────────────────────────────────────────────────────────────────────────

test("skin hud: every HUD font and border block follows the skin by default, through a schema row", function()
    local NS = live()
    local Lib, S = NS.Library, NS.SchemaRuntime
    local ids = { pad = "p1", dial = "d2" }
    local n = 0
    for kind, keys in pairs(Lib.FROM_SKIN_KEYS) do
        for _, key in ipairs(keys) do
            local block, picker = key:match("^(%w+)%.(%w+)$")
            local companion = picker .. "FromSkin"
            -- red under: no `fromSkin` on the composer (no row) or false in defaults/ (X3)
            assertEqual(Lib.TEMPLATES[kind][block][companion], true, kind .. "." .. key .. ": the template")
            local path = kind .. "." .. block .. "." .. companion
            local row = S.FindRow(path)
            assertTrue(row ~= nil and row.type == "bool", path .. " is a schema row")
            assertEqual(row.default, true, path .. " defaults on")
            assertEqual(S.Get(path, ids[kind]), true, path .. " on the seeded " .. kind)
            assertFalse(S.Set(path, "yes", ids[kind]), path .. " takes a bool only")
            n = n + 1
        end
    end
    assertEqual(n, 11, "the pad's eight blocks and the dial's three")
end)

test("skin hud: a following picker is grayed out and shows the skin's value; off, it is the player's", function()
    local NS = live()
    local S = NS.SchemaRuntime
    NS.State.editing = NS.State.editing or {}
    local font = S.FindRow("pad.header.font")
    -- red under: no governed picker (the player edits a face nothing reads)
    assertEqual(font.disabledIf, "pad.header.fontFromSkin")
    assertTrue(type(font.skinValue) == "function")
    local icon = S.FindRow("pad.icon.borderStyle")
    assertTrue(type(icon.disabledIf) == "function", "the icon border's own rule joins the companion")
    assertTrue(type(icon.skinValue) == "function", "and it shows the skin's icon border")
end)

-- ── faces and border styles (X4) ────────────────────────────────────────────────────────────────

test("skin hud: a pad's labels, titles and header take hud.font while they follow, the pick when not", function()
    local NS = live()
    local inst = NS.Pad.Instance("p1")
    -- red under: LabelFont reads look.font (Friz Quadrata, the stored pick) whatever the companion
    assertEqual(firstButton(NS).qcLabel.__font[1], OXANIUM, "a button's label")
    assertEqual(inst.titles.active[1].__font[1], OXANIUM, "a section title")
    assertEqual(inst.header.qcSituation.__font[1], OXANIUM, "the header")
    set(NS, "pad.button.font", "Arial", "p1")
    assertEqual(firstButton(NS).qcLabel.__font[1], OXANIUM, "a pick is not read while it follows")
    set(NS, "pad.button.fontFromSkin", false, "p1")
    assertEqual(firstButton(NS).qcLabel.__font[1], ARIAL, "off: the player's face")
    assertEqual(NS.db.profile.pads.p1.button.font, "Arial", "the pick is stored either way")
end)

-- Ignore fonts reaches the HUD (LibKa0s v1.81.0, R-1; DECISIONS D-09): while the owner ignores fonts,
-- Resolve answers the block's stored pick whatever its companion says, so a following block draws the
-- player's face; a stored pick LibSharedMedia lacks (Friz Quadrata, the default) is the standard face.
test("skin hud: with Ignore fonts on, a following pad face draws its stored pick, live both ways", function()
    local NS, _, Skin = live()
    local inst = NS.Pad.Instance("p1")
    set(NS, "pad.button.font", "Arial", "p1")
    assertEqual(NS.db.profile.pads.p1.button.fontFromSkin, true, "the block still follows")
    assertEqual(firstButton(NS).qcLabel.__font[1], OXANIUM, "following: the skin's face")
    Skin:SetIgnore(OWNER, nil, true)
    -- red under: R.FontKey answers hud.font while the companion is on, whatever Ignore fonts says
    assertEqual(firstButton(NS).qcLabel.__font[1], ARIAL, "Ignore fonts: the stored pick")
    assertEqual(inst.header.qcSituation.__font[1], STANDARD_TEXT_FONT,
        "a stored Friz Quadrata LibSharedMedia lacks is the standard face, never the skin's")
    assertEqual(NS.db.profile.pads.p1.button.fontFromSkin, true, "the companion is left on")
    Skin:SetIgnore(OWNER, nil, false)
    assertEqual(firstButton(NS).qcLabel.__font[1], OXANIUM, "untick: the skin's face is back")
end)

test("skin hud: with Ignore fonts on, the font override does not reach a following HUD face", function()
    local NS, _, Skin = live()
    set(NS, "pad.button.font", "Arial", "p1")
    Skin:SetOverride(OWNER, "Ka0s Oxanium SemiBold", nil)
    Skin:SetIgnore(OWNER, nil, true)
    assertEqual(firstButton(NS).qcLabel.__font[1], ARIAL, "the stored pick beats the override")
    Skin:SetOverride(OWNER, false, nil)
    Skin:SetIgnore(OWNER, nil, false)
end)

test("skin hud: with Ignore fonts on, a following dial label draws its stored pick", function()
    local NS, m, Skin = live()
    set(NS, "dial.label.font", "Arial", "d2")
    Skin:SetIgnore(OWNER, nil, true)
    m.__click(NS.Dial.Instance("d2").header)
    local wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2") or 1)[1]
    assertEqual(wedge.qcLabel.__font[1], ARIAL, "a slice label: the stored pick")
    Skin:SetIgnore(OWNER, nil, false)
    wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2") or 1)[1]
    assertEqual(wedge.qcLabel.__font[1], OXANIUM, "untick: the skin's face")
end)

test("skin hud: a following face takes the Skin tab's font override, as every face of the owner does", function()
    local NS, _, Skin = live()
    Skin:SetOverride(OWNER, "Arial", nil)
    assertEqual(firstButton(NS).qcLabel.__font[1], ARIAL, "hud.font is the override's")
    Skin:SetOverride(OWNER, false, nil)
    assertEqual(firstButton(NS).qcLabel.__font[1], OXANIUM)
end)

test("skin hud: a pad's border blocks take bar.borderStyle while they follow, the pick when not", function()
    local NS = live()
    local skins = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin) skins[frame] = skin return apply(frame, skin) end
    local root = NS.Pad.Instance("p1").root
    set(NS, "pad.look.borderStyle", "Tooltip", "p1")
    -- red under: edgeOf reads look.borderStyle whatever the companion
    assertEqual(skins[root].edgeFile, FLAT, "bar.borderStyle is None: the flat edge")
    set(NS, "pad.look.borderStyleFromSkin", false, "p1")
    assertEqual(skins[root].edgeFile, TOOLTIP, "off: the player's art")
    set(NS, "pad.button.borderStyle", "Tooltip", "p1")
    set(NS, "pad.button.borderStyleFromSkin", false, "p1")
    assertEqual(skins[firstButton(NS).qcEdge].edgeFile, TOOLTIP, "a button's edge, off")
    -- X4: the player's colors are never the skin's
    local bg = firstButton(NS).qcBg.__color
    assertColor(bg, { 0x3F / 255, 0x3F / 255, 0x3F / 255, 0.25 }, "the owner's button body")
end)

test("skin hud: an icon's border takes the skin's icon border while it follows, the pick when not", function()
    local NS = live()
    local IS = NS.IconStyle
    local icon = NS.IconDefaults.For("pad")
    icon.borderShow, icon.borderStyle, icon.borderSize = true, "Tooltip", 5
    -- red under: Config reads borderStyle and borderSize whatever the companion
    local on = IS.Config(icon, "pad").border
    assertEqual(on.backdrop.edgeFile, SOLID, "icon.borderStyle: Solid under Ka0s Default")
    assertEqual(on.size, NS.Skin.Token("icon.borderSize"), "and its thickness")
    icon.borderStyleFromSkin = false
    local off = IS.Config(icon, "pad").border
    assertEqual(off.backdrop.edgeFile, TOOLTIP)
    assertEqual(off.size, 5)
    assertColor(off.color, { 0, 0, 0, 1 }, "the color is the player's either way")
end)

test("skin hud: a dial's slice labels and ring title take hud.font while they follow", function()
    local NS, m = live()
    m.__click(NS.Dial.Instance("d2").header)
    local ring = NS.Dial.ShownRing("d2") or 1
    local wedge = NS.Dial.RingWedges("d2", ring)[1]
    -- red under: the dial's labels read their stored Friz Quadrata
    assertEqual(wedge.qcLabel.__font[1], OXANIUM, "a slice label")
    set(NS, "dial.label.font", "Arial", "d2")
    set(NS, "dial.label.fontFromSkin", false, "d2")
    wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2") or 1)[1]
    assertEqual(wedge.qcLabel.__font[1], ARIAL, "off: the player's face")
end)

-- ── the chrome: today's pixels under Ka0s Default, the skin's under any other ──────────────────────

test("skin hud: a pad's chrome is today's pixels under Ka0s Default, each from a token", function()
    local NS, m = live()
    local R = NS.PadRender
    local btn = firstButton(NS)
    -- red under: any of these typed (they would draw Ka0s Default's pixel under every skin)
    assertColor(btn.qcDim.__color, { 0, 0, 0, 0.55 }, "the refused veil")
    assertColor(btn.qcCool.__color, { 0, 0, 0, 0.35 }, "the cooling veil")
    assertColor(btn.qcHover.__color, { 1, 0.82, 0, 0.25 }, "the hover wash")
    assertColor(btn.qcLock.__color, { 1, 0.82, 0, 1 }, "the padlock")
    R.Flash(btn, "sent")
    assertColor(btn.qcFlash.__color, { 1, 0.82, 0, 0.45 }, "sent")
    R.Flash(btn, "dropped")
    assertColor(btn.qcFlash.__color, { 0.9, 0.15, 0.15, 0.45 }, "dropped")
    R.Flash(btn, "guarded")
    assertColor(btn.qcFlash.__color, { 1, 0.5, 0, 0.45 }, "guarded")
    local header = NS.Pad.Instance("p1").header
    assertColor(header.qcLockdown.__color, { 1, 0.1, 0.1, 1 }, "the lockdown tag")
    assertColor(header.qcStale.__color, { 0.5, 0.5, 0.5, 1 }, "the stale hint")
    assertEqual(R.StripLabel("Pad", "PREVIEW"), "Pad  |cff19ff19PREVIEW|r", "the strip's marker")
    local lines = {}
    local addLine = m.GameTooltip.AddLine
    m.GameTooltip.AddLine = function(t, text, r, g, b, ...)
        lines[#lines + 1] = { r, g, b, 1 }
        return addLine(t, text, r, g, b, ...)
    end
    R.ShowTooltip(btn)
    m.GameTooltip.AddLine = addLine
    assertTrue(#lines > 0, "the tooltip wrote lines")
    assertColor(lines[1], now(NS, "gtip.value"), "a tooltip line")
    assertColor(lines[1], { 1, 1, 1, 1 }, "white, as it was")
end)

test("skin hud: a dial's chrome is today's pixels under Ka0s Default, each from a token", function()
    local NS = live()
    local inst = NS.Dial.Instance("d2")
    local wedge = NS.Dial.RingWedges("d2", 1)[1]
    assertColor(wedge.qcDim.__color, { 0, 0, 0, 0.55 }, "the refused veil")
    assertColor(wedge.qcCool.__color, { 0, 0, 0, 0.35 }, "the cooling veil")
    assertColor(wedge.qcLock.__color, { 1, 0.82, 0, 1 }, "the padlock")
    NS.DialRender.Flash(wedge, "dropped")
    assertColor(wedge.qcFlash.__color, { 0.9, 0.15, 0.15, 0.45 }, "dropped")
    local h = inst.header
    assertColor(h.qcStale.__color, { 0.5, 0.5, 0.5, 1 }, "the stale hint")
    assertColor(h.qcLockdown.__color, { 1, 0.1, 0.1, 1 }, "the lockdown tag")
    assertColor(h.qcTest.__color, { 25 / 255, 1, 25 / 255, 1 }, "the TEST MODE / PREVIEW mark")
    local look = NS.DialRender.Look()
    local arrow = { qcPlate = h:CreateTexture(), qcIcon = h:CreateTexture() }
    NS.DialRender.PaintArrow(arrow, false, look)
    assertColor(arrow.qcIcon.__color, { 0.4, 0.4, 0.4, 0.6 }, "an arrow at an end")
end)

test("skin hud: a skin switch repaints the chrome and the faces, and leaves the player's colors", function()
    local NS, _, Skin = live()
    local btn = firstButton(NS)
    local body = { unpack(btn.qcBg.__color) }
    local gen = NS.PadRender.LooksGen()
    -- red under: no OnLooksChanged listener (the HUD keeps Ka0s Default's chrome until a setting moves)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertTrue(NS.PadRender.LooksGen() > gen, "the look generation moved")
    btn = firstButton(NS)
    assertColor(btn.qcHover.__color, now(NS, "qc.hover"), "the hover wash, " .. OTHER)
    assertColor(btn.qcLock.__color, now(NS, "text.accent"), "the padlock, " .. OTHER)
    assertColor(NS.Pad.Instance("p1").header.qcLockdown.__color, now(NS, "qc.lockdown"), "the lockdown tag")
    assertColor(NS.Dial.RingWedges("d2", 1)[1].qcLock.__color, now(NS, "text.accent"), "a wedge's padlock")
    assertColor(btn.qcBg.__color, body, "the player's button body is untouched (X4)")
    assertEqual(NS.PadRender.FontKey(NS.db.profile.pads.p1.button), Skin:ResolveSkin(OTHER)["hud.font"],
        "the face is the new skin's")
end)

test("skin hud: a pad window's 1px inner rule is win.inner, none where the skin has none", function()
    local NS, _, Skin = live()
    local R = NS.PadRender
    local flat = { borderStyle = "None", borderSize = 1, borderStyleFromSkin = false }
    -- red under: R.SkinFor copying NS.SKIN's innerBorder (Ka0s Default's gray under every skin)
    assertColor(R.SkinFor(flat).innerBorder, { 0.24, 0.24, 0.27, 0.85 }, "today's line under Ka0s Default")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertTrue(type(Skin:ResolveSkin(OTHER)["win.inner"]) ~= "table", OTHER .. " has no inner line")
    assertColor(R.SkinFor(flat).innerBorder, { 0, 0, 0, 0 }, "no line under " .. OTHER)
    local colored
    for _, def in ipairs(Skin:Skins()) do
        if type(Skin:ResolveSkin(def.key)["win.inner"]) == "table" and def.key ~= "ka0s" then colored = def.key; break end
    end
    assertTrue(colored ~= nil, "a skin with an inner line of its own")
    Skin:SetChoice(OWNER, "ka0s", colored)
    assertColor(R.SkinFor(flat).innerBorder, now(NS, "win.inner"), "the line under " .. colored)
    assertColor(R.SkinFor(flat, true).innerBorder, { 0, 0, 0, 0 }, "a plain block never takes it")
end)

test("skin hud: the dial's per-frame update reads no token", function()
    local NS, m = live()
    m.__click(NS.Dial.Instance("d2").header)
    local reads = 0
    for _, name in ipairs({ "Token", "Color", "Resolve" }) do
        local real = NS.Skin[name]
        NS.Skin[name] = function(...) reads = reads + 1 return real(...) end
    end
    NS.DialRender.PointerUpdate(NS.Dial.Instance("d2").header.qcPointer)
    assertEqual(reads, 0, "R.PointerUpdate resolves nothing (the look carries the chrome)")
end)

-- ── the one-time reset (O2): schema step 10 ─────────────────────────────────────────────────────

-- A raw profile as SavedVariables holds one saved before QC-03: no companion stored, and one block
-- whose companion a player had turned off.
local function oldProfile()
    return {
        pads = { p9 = {
            look = { borderStyle = "Tooltip", borderColor = { r = 1, g = 0, b = 0, a = 1 } },
            header = { font = "Arial", fontColor = { r = 0, g = 1, b = 0, a = 1 } },
            section = { font = "Arial", fontFromSkin = false },
            button = { font = "Arial", borderStyle = "Tooltip" },
            icon = { borderStyle = "Tooltip", borderStyleFromSkin = false },
        } },
        dials = { d9 = { label = { font = "Arial" }, title = { font = "Arial", fontFromSkin = false } } },
    }
end

local function assertFollows(p)
    local pad, dial = p.pads.p9, p.dials.d9
    for _, key in ipairs({ "look.borderStyle", "header.font", "section.font", "button.font",
        "button.borderStyle", "icon.borderStyle" }) do
        local block, picker = key:match("^(%w+)%.(%w+)$")
        assertEqual(pad[block][picker .. "FromSkin"], true, "pad " .. key)
    end
    assertEqual(dial.label.fontFromSkin, true, "dial label.font")
    assertEqual(dial.title.fontFromSkin, true, "dial title.font")
    -- the picks are kept, and no sentinel lands in a picker
    assertEqual(pad.header.font, "Arial")
    assertEqual(pad.look.borderStyle, "Tooltip")
    assertEqual(pad.icon.borderStyle, "Tooltip")
    assertEqual(dial.label.font, "Arial")
    -- X4: no color moves
    assertEqual(pad.look.borderColor.r, 1)
    assertEqual(pad.header.fontColor.g, 1)
end

test("skin hud: step 10 turns every stored pad's and dial's companions on, keeping every pick", function()
    local NS = live()
    assertEqual(NS.SCHEMA_VERSION, 10, "the reset is step 10")
    local p = oldProfile()
    -- red under: no step, or ResetToSkin handed an absent companion ("@skin" lands in the picker)
    NS.Library.MigrateFollowSkin(p)
    assertFollows(p)
    NS.Library.MigrateFollowSkin(p)
    assertFollows(p)   -- idempotent
end)

test("skin hud: without the library step 10 writes the companions itself", function()
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    local p = oldProfile()
    NS.Library.MigrateFollowSkin(p)
    assertFollows(p)
end)

test("skin hud: the reset runs once: a companion the player turns off afterwards stays off", function()
    local NS = live()
    local db = NS.addon.db
    local pad = db.profile.pads.p1
    pad.header.fontFromSkin, pad.button.borderStyleFromSkin = false, false
    db.global.schemaVersion = 9
    -- red under: the step missing, or not perProfile (every stored profile is reset)
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, 10)
    assertEqual(pad.header.fontFromSkin, true, "the one-time reset")
    assertEqual(pad.button.borderStyleFromSkin, true)
    set(NS, "pad.header.fontFromSkin", false, "p1")
    NS.addon:RunMigrations()
    NS.addon:OnProfileChanged(nil, nil, db:GetCurrentProfile())
    assertEqual(db.profile.pads.p1.header.fontFromSkin, false, "the player's later pick is kept")
end)
