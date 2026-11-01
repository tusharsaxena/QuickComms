-- tests/test_skin_flip.lua — the full skin on the Comms Pad and the Comms Dial (LibKa0s v1.85.0, cause D7
-- of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING): the one schema step on stored partial
-- profiles, what each surface draws under Ka0s Default and under another skin, the companions turned
-- off, the shadow, and the ghost's copy of the skinned look. A skin switch is read off the drawing
-- setters, never a getter: a look that resolves and does not draw is the failure this suite exists for.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")
local live, planOf = D.live, D.planOf

local OWNER, OTHER, GLASS = "QuickComms", "obsidian", "glass"

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

local function assertColor(got, want, what)
    for i = 1, 4 do
        assertTrue(near(got and got[i], want and want[i]),
            ("%s[%d]: got %s, want %s"):format(what, i, tostring(got and got[i]), tostring(want and want[i])))
    end
end

local function skinOf(m) return m.LibStub("LibKa0s-Skin-1.0") end
local function button(NS) return NS.Pad.Instance("p1").buttons.active[1] end
local function pad(NS)
    local snap = NS.Situation.Current()
    assertTrue(NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))))
    return NS.Pad.Instance("p1")
end
local function dial(NS)
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    return NS.Dial.Instance("d2")
end

local function color(NS, token)
    local r, g, b, a = NS.Skin.Color(token)
    return { r, g, b, a or 1 }
end

-- A deep copy, to pin a table byte for byte.
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

local function same(a, b, what)
    if type(a) ~= "table" or type(b) ~= "table" then return assertEqual(a, b, what) end
    for k, v in pairs(a) do same(v, b[k], what .. "." .. tostring(k)) end
    for k in pairs(b) do assertTrue(a[k] ~= nil, what .. " grew " .. tostring(k)) end
end

-- A stored partial profile, as an old build left it: companions false and absent, a one-key color, a
-- missing block, a class color, a picked flag and a damaged surface.
local function partial()
    return {
        skin = { ignorePanel = true, ignoreFonts = true },
        pads = {
            a = { look = { backgroundFromSkin = false, background = { r = 0.5 } },
                header = { fontColor = { r = 1, g = 0, b = 0, a = 1 }, useClassColorFont = true, fontFlags = "THICK",
                    font = "Arial", fontSize = 20, borderSize = 7 } },
            bad = 3,
        },
        dials = { c = { hub = { useClassColorCircle = true }, slice = { shineFromSkin = false, shineLook = "rim" } } },
    }
end

test("skin flip: the step puts every listed companion on, keeps every pick and color, and leaves the rest", function()
    local NS = T.enableAddon()
    local p, before = partial(), partial()
    -- red under: no step, or one that names the color and not its companion
    NS.Library.MigrateFullSkin(p)
    local h = p.pads.a.header
    assertTrue(p.pads.a.look.backgroundFromSkin, "stored false")
    assertTrue(p.pads.a.look.borderColorFromSkin, "absent")
    assertTrue(h.fontColorFromSkin)
    assertTrue(h.fontShadowFromSkin)
    assertTrue(p.dials.c.slice.shineFromSkin)
    assertTrue(p.dials.c.hub.circleColorFromSkin)
    assertEqual(h.fontFlags, "@skin", "a flags key is listed, and the ruling is that it follows")
    same(p.pads.a.look.background, before.pads.a.look.background, "a one-key color")
    same(h.fontColor, before.pads.a.header.fontColor, "a stored color")
    assertEqual(h.font, "Arial", "a stored pick")
    assertEqual(h.fontSize, 20, "a size")
    assertEqual(h.borderSize, 7, "a thickness")
    assertEqual(p.dials.c.slice.shineLook, "rim")
    assertTrue(h.useClassColorFont, "a class color's toggle")
    assertTrue(p.dials.c.hub.useClassColorCircle)
    assertEqual(p.skin.ignorePanel, true)
    assertEqual(p.skin.ignoreFonts, true)
    assertNil(p.pads.a.button, "a missing block is not made")
    assertEqual(p.pads.bad, 3, "a damaged surface is left")
    assertNil(p.pads.a.skin, "no stray skin table on an entry")
    assertNil(p.dials.c.skin)
    assertTrue(p.skin.fullSkinReset, "recorded on the profile's root")
end)

test("skin flip: no value but a flag holds the sentinel, and a second run writes nothing", function()
    local NS = T.enableAddon()
    local p = partial()
    NS.Library.MigrateFullSkin(p)
    local function walk(t, path)
        for k, v in pairs(t) do
            if type(v) == "table" then
                walk(v, path .. "." .. tostring(k))
            elseif v == "@skin" then
                assertEqual(k, "fontFlags", path)
            end
        end
    end
    walk(p, "profile")
    local once = copy(p)
    NS.Library.MigrateFullSkin(p)
    same(p, once, "the second run")
    p.pads.a.look.backgroundFromSkin = false
    NS.Library.MigrateFullSkin(p)
    assertEqual(p.pads.a.look.backgroundFromSkin, false, "turned off afterwards, it stays off")
end)

test("skin flip: the runner moves every stored profile once, and each profile event only a new one", function()
    local NS = T.enableAddon()
    local db = NS.addon.db
    local old = partial()
    db.sv.profiles.old = old
    db.global.schemaVersion = 12
    NS.db.profile.skin.fullSkinReset = false
    NS.addon:RunMigrations()
    assertEqual(db.global.schemaVersion, 14)
    assertTrue(old.pads.a.look.backgroundFromSkin)
    assertTrue(NS.db.profile.skin.fullSkinReset, "the active one too")
    old.pads.a.look.backgroundFromSkin = false
    NS.addon:RunMigrations()
    assertEqual(old.pads.a.look.backgroundFromSkin, false, "a companion turned off stays off")
    -- a profile that arrives after the stamp: an import, a copy
    local late = partial()
    db.sv.profiles.late = late
    NS.addon:RunMigrations()
    assertTrue(late.pads.a.look.backgroundFromSkin, "the stamp did not stop it")
end)

test("skin flip: a companion turned off stays off through every Defaults path that is not its own", function()
    local NS = live()
    local S = NS.SchemaRuntime
    NS.addon:RunMigrations()
    assertTrue(NS.db.profile.skin.fullSkinReset)
    assertTrue(S.Set("pad.button.backgroundFromSkin", false, "p1"))
    local H = NS.addon.Settings.Helpers
    if H.RestoreAllDefaults then H.RestoreAllDefaults() end
    assertTrue(NS.db.profile.skin.fullSkinReset, "no row walks the record")
    NS.addon:RunMigrations()
    assertTrue(NS.db.profile.skin.fullSkinReset)
    assertTrue(S.Set("pad.button.backgroundFromSkin", false, "p1"))
    NS.addon:RunMigrations()
    assertEqual(NS.db.profile.pads.p1.button.backgroundFromSkin, false)
    for _, row in ipairs(NS.addon.Settings.Schema) do
        assertTrue(row.path ~= "skin.fullSkinReset", "the record has no row")
    end
end)

test("skin flip: a profile reset runs the step against defaults that show nothing", function()
    local NS = live()
    local db = NS.addon.db
    db:ResetProfile()
    assertTrue(NS.db.profile.skin.fullSkinReset, "recorded again")
    assertTrue(NS.db.profile.pads.p1.button.backgroundFromSkin)
end)

test("skin flip: with the library absent the step writes by hand, the record too, and makes no table", function()
    local NS = T.newAddon{ skip = T.loadAddon.libFiles }
    local p = partial()
    p.skin = nil
    NS.Library.MigrateFullSkin(p)
    assertTrue(p.pads.a.look.backgroundFromSkin)
    assertTrue(p.pads.a.header.fontColorFromSkin)
    assertEqual(p.pads.a.header.fontFlags, "@skin")
    assertNil(p.pads.a.button)
    assertNil(p.dials.c.page)
    assertTrue(p.skin.fullSkinReset)
    p.pads.a.look.backgroundFromSkin = false
    NS.Library.MigrateFullSkin(p)
    assertEqual(p.pads.a.look.backgroundFromSkin, false, "the record gates it")
end)

test("skin flip: every listed key has a shipped default that says follow", function()
    local NS = T.enableAddon()
    local p = NS.db.profile
    for kind, keys in pairs(NS.Library.FULL_SKIN_KEYS) do
        for _, surface in pairs(p[kind]) do
            for _, key in ipairs(keys) do
                local block, leaf = key:match("^(%w+)%.(%w+)$")
                -- red under: a default and a row that disagree, so Defaults and a new profile differ
                local want = true
                if leaf == "fontFlags" then want = "@skin" end
                assertEqual(surface[block][leaf], want, key)
            end
        end
    end
end)

test("skin flip: a font row's default is the Ka0s pick, for a player who turns the companion off", function()
    local NS = T.enableAddon()
    local p = NS.db.profile.pads.p1
    assertEqual(p.header.font, "Ka0s Prototype")
    assertEqual(p.button.font, "Ka0s Prototype")
    assertEqual(NS.db.profile.dials.d2.label.font, "Ka0s Prototype")
    assertEqual(p.header.borderStyle, "None", "a border style stays None")
end)

test("skin flip: Ka0s Default draws what the stored defaults drew", function()
    local NS = live()
    local inst, di = pad(NS), dial(NS)
    local btn = button(NS)
    assertColor(btn.qcBg.__color, { 0x3F / 255, 0x3F / 255, 0x3F / 255, 0.25 }, "a button's body")
    assertEqual(btn.qcLabel.__color[1], 1, "a button's label stays white")
    local hl = inst.hlook
    assertColor({ hl.font.r, hl.font.g, hl.font.b, hl.font.a }, { 1, 0.82, 0, 1 }, "the header's gold")
    assertEqual(hl.skin.edgeSize, 0, "a header draws no edge")
    assertNil(hl.skin.edgeFile)
    assertEqual(hl.skin.bg[4], 0, "and no fill")
    local look = di.track and NS.DialRender.Look(120, NS.db.profile.dials.d2.label, NS.db.profile.dials.d2.slice,
        NS.db.profile.dials.d2)
    assertColor({ look.fill.r, look.fill.g, look.fill.b, look.fill.a }, { 0.06, 0.06, 0.08, 0.8 }, "a slice")
    assertColor({ look.highlight.r, look.highlight.g, look.highlight.b, look.highlight.a }, { 1, 0.82, 0, 0.25 }, "a hover")
    assertColor({ look.hub.background.r, look.hub.background.g, look.hub.background.b, look.hub.background.a },
        { 0.12, 0.12, 0.14, 0.95 }, "the hub")
    assertEqual(look.hub.borderSize, 1)
    assertEqual(look.shine.look, "orb")
    assertEqual(NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button).shine.look, "glossfade")
    assertNil(NS.PadRender.ButtonLook(NS.db.profile.pads.p1.button).texture, "a flat body")
end)

test("skin flip: a skin switch reaches every drawing setter on a pad", function()
    local NS, m = live()
    local inst = pad(NS)
    local Skin = skinOf(m)
    local drawn = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin)
        drawn[frame] = skin
        return apply(frame, skin)
    end
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    NS.Surfaces.ApplyAll("test")
    local btn = button(NS)
    -- red under: any look still reading its stored value
    assertColor(btn.qcBg.__color, color(NS, "btn.bg"), "a button's body")
    assertColor(btn.qcLabel.__color, color(NS, "hud.text"), "a button's label")
    assertColor(inst.header.qcSituation.__color, color(NS, "hud.label"), "the header's text")
    assertColor(drawn[inst.root].bg, color(NS, "win.bg"), "the window's fill")
    assertColor(drawn[inst.root].border, color(NS, "win.border"), "the window's edge")
    assertColor(drawn[inst.header].bg, color(NS, "title.bg"), "the header's band")
    assertColor(drawn[btn.qcEdge].border, color(NS, "btn.border"), "a button's edge")
    assertEqual(drawn[inst.header].edgeSize, Skin:ResolveSkin(OTHER)["win.borderSize"], "the band's thickness")
end)

test("skin flip: a skin switch reaches the dial's slices, hub, pointer, page row and shine", function()
    local NS, m = live()
    local di = dial(NS)
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    NS.Surfaces.ApplyAll("test")
    di = NS.Dial.Instance("d2") or di
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    assertColor(di.header.qcHub.__color, color(NS, "btn.bg"), "the hub's disc")
    assertColor(di.header.qcPointer.qcArrow.__color, color(NS, "icon.arrow"), "the pointer")
    local ring = di.rings.active[1]
    assertColor(ring.qcFills[1].__color, color(NS, "win.bg"), "a slice")
    local dial0 = NS.db.profile.dials.d2
    local look = NS.DialRender.Look(120, dial0.label, dial0.slice, dial0)
    assertColor({ look.paging.current.r, look.paging.current.g, look.paging.current.b, look.paging.current.a },
        color(NS, "text.accent"), "the page pill")
    assertEqual(look.paging.dot.r, select(1, NS.Skin.Color("text.disabled")), "a page dot")
    assertColor({ look.title.font.r, look.title.font.g, look.title.font.b, look.title.font.a },
        color(NS, "hud.label"), "a group label")
    assertColor({ look.font.r, look.font.g, look.font.b, look.font.a }, color(NS, "hud.text"), "a slice label")
    local tr, tg, tb = NS.Skin.Color("text.muted")
    assertEqual(look.shine.tint[1], tr)
    assertEqual(look.shine.tint[2], tg)
    assertEqual(look.shine.tint[3], tb)
end)

test("skin flip: a companion off draws the stored value under every skin", function()
    local NS, m = live()
    local S = NS.SchemaRuntime
    pad(NS)
    assertTrue(S.Set("pad.button.backgroundFromSkin", false, "p1"))
    assertTrue(S.Set("pad.button.background", { r = 0.3, g = 0, b = 0, a = 0.5 }, "p1"))
    assertTrue(S.Set("pad.button.fontColorFromSkin", false, "p1"))
    assertTrue(S.Set("pad.button.fontColor", { r = 0, g = 0.4, b = 0, a = 1 }, "p1"))
    NS.Surfaces.ApplyAll("test")
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    NS.Surfaces.ApplyAll("test")
    assertColor(button(NS).qcBg.__color, { 0.3, 0, 0, 0.5 }, "the body")
    assertEqual(button(NS).qcLabel.__color[2], 0.4, "the label")
end)

test("skin flip: a class color comes before the companion, whatever it says", function()
    local NS, m = live()
    m.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.75, b = 0.5 } }
    local class = { NS.ResolveColor({ r = 1, g = 1, b = 1, a = 1 }, true) }
    assertEqual(class[1], 0.25, "a class color the stored white cannot answer")
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    local font = NS.PadRender.LabelFont({ useClassColorFont = true, fontColorFromSkin = true,
        fontColor = { r = 1, g = 1, b = 1, a = 1 } })
    assertEqual(font.r, class[1])
    local r = NS.SkinFollow({ useClassColorBackground = true, backgroundFromSkin = true,
        background = { r = 1, g = 1, b = 1, a = 1 } }, "background", "win.bg", true)
    assertEqual(r, class[1])
end)

test("skin flip: a glyph's own color and a game icon keep theirs; the skin's tint reaches a plain glyph", function()
    local NS, m = live()
    local IS = NS.IconStyle
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    local cfg = IS.Config(NS.db.profile.pads.p1.icon, "pad")
    local tr = select(1, NS.Skin.Color("icon.tint"))
    local glyph, tex = NS.Icon("lock"), { SetTexCoord = function() end, SetDesaturated = function() end,
        SetAlpha = function() end, SetVertexColor = function(self, r, g, b) self.c = { r, g, b } end }
    IS.PaintIcon(tex, cfg, glyph, false)
    assertEqual(tex.c[1], tr, "a plain glyph")
    IS.PaintIcon(tex, cfg, glyph, "ff4040")
    assertEqual(tex.c[1], 1, "a meaning color is never tinted")
    assertTrue(near(tex.c[2], 0x40 / 255))
    IS.PaintIcon(tex, cfg, "Interface\\Icons\\INV_Misc_QuestionMark", false)
    assertEqual(tex.c[1], 1, "a game icon is art")
end)

test("skin flip: the icon's border and glow take the skin's colors, off the stored ones", function()
    local NS, m = live()
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    local base = skinOf(m):ResolveSkin(OTHER)
    local icon = NS.PadDefaults and NS.IconDefaults.For("pad")
    icon.borderShow, icon.glowEnabled = true, true
    local cfg = NS.IconStyle.Config(icon, "pad")
    assertColor(cfg.border.color, base["icon.border"], "the border")
    assertColor(cfg.glow.color, base["glow.color"], "the glow")
    icon.borderColorFromSkin, icon.glowColorFromSkin = false, false
    cfg = NS.IconStyle.Config(icon, "pad")
    assertColor(cfg.glow.color, { 1, 0.82, 0, 1 }, "the stored glow")
end)

test("skin flip: the shine is the skin's look, and its texture a skinned body; off keeps the player's", function()
    local NS, m = live()
    local Skin = skinOf(m)
    local b = NS.PadDefaults.Button()
    Skin:SetChoice(OWNER, "ka0s", GLASS)
    assertEqual(NS.Shine.Resolve(b, "qc.btnShine", "qc.btnShineTint").look, "gloss", "Glass's gloss")
    assertEqual(NS.Shine.Resolve(NS.PadDefaults.DialSlice(), "qc.sliceShine", "qc.sliceShineTint").look, "frost")
    b.shineFromSkin = false
    assertEqual(NS.Shine.Resolve(b, "qc.btnShine", "qc.btnShineTint").look, "glossfade", "the stored look")
    Skin:SetChoice(OWNER, "ka0s", "contrast")
    b.shineFromSkin = true
    assertEqual(NS.Shine.Resolve(b, "qc.btnShine", "qc.btnShineTint").look, "none", "High Contrast draws none")
end)

test("skin flip: a textured body draws the file in the look's color, and flat again clears the tint", function()
    local NS = live()
    pad(NS)
    local R = NS.PadRender
    local btn = button(NS)
    local bg = btn.qcBg
    local cl = { sig = "t", bg = { 0.1, 0.2, 0.3, 0.4 }, texture = "art", edge = {}, font = R.LabelFont({}), glow = false }
    R.ApplyButtonLook(btn, cl, 100, 24)
    assertEqual(bg.__texture, "art")
    assertColor(bg.__color, cl.bg, "the color on the file")
    R.ApplyButtonLook(btn, { sig = "f", bg = { 0.5, 0.6, 0.7, 0.8 }, edge = {}, font = R.LabelFont({}), glow = false }, 100, 24)
    assertColor(bg.__color, { 0.5, 0.6, 0.7, 0.8 }, "the flat body")
end)

test("skin flip: Ka0s Default keeps the shadow the blocks ship with, every other skin draws its own", function()
    local NS, m = live()
    local R, Skin = NS.PadRender, skinOf(m)
    local look = { fontShadow = true, fontShadowFromSkin = true }
    local shadow, follows = R.ShadowOf(look)
    assertEqual(shadow[1], 1, "offset 1, -1")
    assertEqual(shadow[6], 1, "opaque black, through qc.shadow")
    assertFalse(follows)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertTrue(select(2, R.ShadowOf(look)), "S.HudFont reads the skin's")
    look.fontShadowFromSkin = false
    shadow, follows = R.ShadowOf(look)
    assertTrue(shadow == true and follows == false, "off: the stored one")
    look.fontShadow = false
    shadow = R.ShadowOf(look)
    assertEqual(shadow, false)
end)

test("skin flip: a skin switch redraws the shadow on a string that had already drawn", function()
    local NS, m = live()
    pad(NS)
    local Skin = skinOf(m)
    local label = button(NS).qcLabel
    local object = label.__fontObject
    assertTrue(object ~= nil, "S.HudFont gave it a font object")
    assertEqual(object.__shadow[1], 1)
    local choices = Skin:ResolveSkin("contrast")
    Skin:SetChoice(OWNER, "ka0s", "contrast")
    NS.Surfaces.ApplyAll("test")
    assertEqual(button(NS).qcLabel.__fontObject.__shadow[1], choices["hud.shadowX"], "High Contrast's own offset")
    assertEqual(button(NS).qcLabel.__fontObject.__shadow[1], 2)
end)

test("skin flip: Ignore fonts leaves the stored shadow standing", function()
    local NS, m = live()
    local Skin = skinOf(m)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    Skin:SetIgnore(OWNER, nil, true)
    local shadow, follows = NS.PadRender.ShadowOf({ fontShadow = true, fontShadowFromSkin = true })
    assertTrue(shadow == true and follows == true)
    Skin:SetIgnore(OWNER, nil, false)
end)

test("skin flip: the ghost wears a skinned string's font object, so its shadow comes along", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", D.planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    m.__click(inst.header, "Toggle")
    local wedge = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    local src, fs = wedge.qcLabel.__fontObject, nil
    assertTrue(src ~= nil)
    local ghost = inst.track.ghost
    for i = 1, ghost.used do
        for _, f in ipairs(ghost.subs[i].qcFont) do
            if f.__fontObject == src then fs = f end
        end
    end
    assertTrue(fs ~= nil, "the copy wears the same object")
    assertColor(fs.__font and { 1, 1, 1, 1 } or nil, { 1, 1, 1, 1 }, "and draws its face")
end)

-- ── the host parts of the L causes (FS-QC-FIX) ───────────────────────────────────────────────────

test("skin fix: a tooltip's title takes gtip.title, on a button, a wedge and a titled tip", function()
    local NS, m = live()
    local R = NS.PadRender
    local seen
    local tip = m.GameTooltip
    local text = tip.SetText
    tip.SetText = function(self, line, r, g, b)
        seen = { line, r, g, b }
        return text(self, line, r, g, b)
    end
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    local want = color(NS, "gtip.title")
    -- red under: SetText with no color, which the client draws in its own
    R.ShowLines(button(NS), "Title", {})
    assertEqual(seen[2], want[1])
    seen = nil
    R.ShowTooltip(button(NS))
    assertEqual(seen[3], want[2])
    seen = nil
    NS.DialRender.ShowTip(NS.Dial.Instance("d2").header, "Title", {})
    assertEqual(seen[4], want[3])
end)

test("skin fix: the hub's small labels wear the skin's HUD face and their tokens", function()
    local NS, m = live()
    local di = dial(NS)
    local Skin = skinOf(m)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    NS.Surfaces.ApplyAll("test")
    local h = (NS.Dial.Instance("d2") or di).header
    local base = NS.DialRender.Look(120, NS.db.profile.dials.d2.label, NS.db.profile.dials.d2.slice, NS.db.profile.dials.d2).font
    for _, fs in ipairs({ h.qcStale, h.qcLockdown, h.qcTest }) do
        assertEqual(fs.__font[1], base.path, "not the client's font object")
        assertEqual(fs.__font[2], Skin:For(OWNER).HudFontSize(10, true))
    end
    assertColor(h.qcLockdown.__color, color(NS, "qc.lockdown"), "the lockdown tag")
    assertColor(h.qcTest.__color, color(NS, "qc.preview"), "the preview mark")
end)

test("skin fix: End preview's label takes the skin's body face", function()
    local NS = live()
    local fonts = {}
    local font = NS.Skin.Font
    NS.Skin.Font = function(fs, ...)
        fonts[#fonts + 1] = fs
        return font(fs, ...)
    end
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    assertTrue(#fonts >= 1, "red under: the string left on GameFontNormalSmall")
end)

test("skin fix: the active dot is the client's while the panel is stock, the Ka0s mark with the Scope cleared", function()
    local NS, m = live()
    local Ed = NS.addon.Settings.Editors
    assertTrue(Ed.ActiveDot():find("Indicator-Green", 1, true) ~= nil, "the Scope's default")
    skinOf(m):SetIgnore(OWNER, false, nil)
    assertTrue(Ed.ActiveDot():find("confirm", 1, true) ~= nil, "cleared")
    assertTrue(Ed.ActiveDot():find("Indicator-Green", 1, true) == nil)
end)

test("skin fix: the remove mark is marked for the panel, its stock art kept as the way back", function()
    local NS = live()
    local Ed = NS.addon.Settings.Editors
    local got
    NS.Skin.Mark = function(tex, opts) got = { tex, opts } end
    local image = { SetAtlas = function(self, a) self.atlas = a end }
    Ed.RemoveMark({ image = image })
    assertEqual(image.atlas, "transmog-icon-remove", "drawn stock first: the facade may be a no-op")
    assertTrue(got[2].panel)
    assertEqual(got[2].art, NS.Icon("close"))
    image.atlas = nil
    got[2].stock(image)
    assertEqual(image.atlas, "transmog-icon-remove")
end)

test("skin fix: the panel's tooltip lines take gtip.line, its stock gold under Ignore settings panel", function()
    local NS = live()
    local r, g = NS.SkinColor("gtip.line", true)
    assertEqual(r, 1)
    assertEqual(g, 0.82)
end)

-- ── the pins the review's mutation sweep asked for (FS-QC-FIX) ───────────────────────────────────

-- A skin's token, read off the skin's own table: what a surface must draw once it moves.
local function skinToken(Skin, name, token)
    return Skin:ResolveSkin(name)[token]
end

-- The first shipped skin where `token` differs from Ka0s Default and, by `others`, from each of them.
local function skinWhere(Skin, token, others)
    local base = Skin:ResolveSkin(Skin.DEFAULT)
    for _, name in ipairs({ OTHER, "azeroth", GLASS, "contrast", "ember", "wow", "midnight", "forever" }) do
        local c, ok = Skin:ResolveSkin(name)[token], true
        for _, other in ipairs(others or {}) do
            local o = Skin:ResolveSkin(name)[other]
            if not o or (o[1] == c[1] and o[2] == c[2] and o[3] == c[3]) then ok = false end
        end
        if ok and (c[1] ~= base[token][1] or c[2] ~= base[token][2] or c[3] ~= base[token][3]) then return name end
    end
    error("no shipped skin moves " .. token)
end

-- Every line a tooltip took, with the color it was told.
local function tipColors(m)
    local tip, lines = m.GameTooltip, {}
    local setText, addLine = tip.SetText, tip.AddLine
    tip.SetText = function(t, text, r, g, b, ...)
        lines = { { text, r, g, b } }
        return setText(t, text, r, g, b, ...)
    end
    tip.AddLine = function(t, text, r, g, b, ...)
        lines[#lines + 1] = { text, r, g, b }
        return addLine(t, text, r, g, b, ...)
    end
    return function() return lines end
end

local function rgbOf(line) return { line[2], line[3], line[4], 1 } end

-- A live addon whose new frames record their paint, with its settings window up.
local function painted()
    local NS, m = live()
    dofile("tests/_kit/mock_paint.lua")(m)
    m.SettingsPanel:Show()
    return NS, m, skinOf(m)
end

-- A real Texture, as the client's Icon wears, that counts every write reaching it.
local function spiedTexture(m)
    local tex = m.CreateFrame("Frame"):CreateTexture()
    tex.__writes = 0
    for _, name in ipairs({ "SetAtlas", "SetTexture", "SetVertexColor" }) do
        local fn = tex[name]
        rawset(tex, name, function(self, ...)
            self.__writes = self.__writes + 1
            return fn(self, ...)
        end)
    end
    return tex
end

-- ── a pooled Icon's mark ──

local function releasedMark(mark)
    local NS, m, Skin = painted()
    local ace = m.LibStub("AceGUI-3.0")
    local w = ace:Create("Icon")
    local tex = spiedTexture(m)
    w.image = tex
    mark(NS, w)
    assertTrue(Skin.painted[tex] ~= nil, "the mark is on the skin's record")
    Skin:SetIgnore(OWNER, false, nil)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertColor(m.__paint(tex).vertex, color(NS, "icon.tint"), "live while the widget is ours")
    ace:Release(w)
    -- red under: no Untrack on release (the widget goes back to a pool every addon draws from)
    assertNil(Skin.painted[tex], "the record is gone")
    assertColor(m.__paint(tex).vertex, { 1, 1, 1, 1 }, "and so is the tint")
    tex.__writes = 0
    Skin:SetChoice(OWNER, "ka0s", GLASS)
    Skin:SetIgnore(OWNER, true, nil)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertEqual(tex.__writes, 0, "no skin change reaches the next user's texture")
end

test("skin fix: a released remove mark is forgotten, so a skin change never reaches the widget's next user", function()
    releasedMark(function(NS, w) NS.addon.Settings.Editors.RemoveMark(w) end)
end)

test("skin fix: a remove mark redrawn under a stock panel keeps its art until it is released", function()
    local NS, m, Skin = painted()
    local ace = m.LibStub("AceGUI-3.0")
    local w = ace:Create("Icon")
    local tex = spiedTexture(m)
    w.image = tex
    NS.addon.Settings.Editors.RemoveMark(w)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertEqual(m.__paint(tex).atlas, "transmog-icon-remove", "live before the release")
    ace:Release(w)
    tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    Skin:SetChoice(OWNER, "ka0s", GLASS)
    assertEqual(m.__paint(tex).texture, "Interface\\Icons\\INV_Misc_QuestionMark", "another widget's art stands")
end)

test("skin fix: a row's Edit glyph takes the tint with the Scope cleared, and gives it back on release", function()
    local NS, m, Skin = painted()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    assertTrue(NS.Library.CreateCalloutIn(gid, { name = "Kick", text = "Kick", channel = "party" }) ~= nil)
    local ace = m.LibStub("AceGUI-3.0")
    local create = ace.Create
    ace.Create = function(self, wtype, ...)
        local w = create(self, wtype, ...)
        if wtype == "Icon" then
            local tex = spiedTexture(m)
            w.image = tex
            w.SetImage = function(widget, path) tex:SetTexture(path) return widget end
        end
        return w
    end
    P.show("Groups")
    NS.addon.Settings.Editors.Select("group", gid)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    local stock = P.glyph(P.tab("groups", "callouts"), "edit")
    assertColor(m.__paint(stock.image).vertex, { 1, 1, 1, 1 }, "white while the panel is stock")
    Skin:SetIgnore(OWNER, false, nil)
    local g = P.glyph(P.tab("groups", "callouts"), "edit")
    local image = g.image
    -- red under: no Mark on the Edit glyph
    assertColor(m.__paint(image).vertex, color(NS, "icon.tint"), "the skin's tint")
    assertEqual(m.__paint(image).texture, NS.Icon("edit"), "on the catalog's art")
    ace:Release(g)
    assertNil(Skin.painted[image])
    assertColor(m.__paint(image).vertex, { 1, 1, 1, 1 }, "a recycled glyph keeps no tint")
end)

test("skin fix: with the library absent the marks release by callback and forget nothing", function()
    local NS = T.newAddon{ skip = T.loadAddon.libFiles }
    local tinted
    local image = { SetAtlas = function() end, SetVertexColor = function(_, r) tinted = r end }
    local w = { image = image, SetCallback = function(self, name, fn) self[name] = fn end }
    NS.addon.Settings.Editors.RemoveMark(w)
    assertTrue(w.OnRelease ~= nil, "the callback is the chain here")
    w.OnRelease(w)
    assertEqual(tinted, 1)
end)

-- ── a row grayed while its value is drawn ──

local function shineGates(kind, id, prefix, stored)
    local NS, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local Ed, S = NS.addon.Settings.Editors, NS.SchemaRuntime
    P.show(kind == "pad" and "Pad" or "Dial")
    Ed.Select(kind, id)
    local strength, tint = Ed.Row(prefix .. "shineStrength"), Ed.Row(prefix .. "shineTint")
    assertTrue(S.Set(prefix .. "shineLook", "none", id))
    assertTrue(S.Get(prefix .. "shineFromSkin"), "the step's value")
    -- red under: off() reading only the stored look
    assertEqual(strength.disabledIf(), false, "the skin's look draws, so its Strength is live")
    assertEqual(tint.disabledIf(), false, "and its tint")
    assertTrue(S.Set(prefix .. "shineFromSkin", false, id))
    assertTrue(strength.disabledIf(), "the stored None governs again")
    assertTrue(tint.disabledIf())
    assertTrue(S.Set(prefix .. "shineLook", stored, id))
    assertEqual(strength.disabledIf(), false, "a stored look draws")
    assertTrue(S.Set(prefix .. "shineLook", "none", id))
    assertTrue(S.Set(prefix .. "shineFromSkin", true, id))
    skinOf(m):SetChoice(OWNER, "ka0s", "contrast")
    assertTrue(strength.disabledIf(), "High Contrast answers None, whatever is stored")
    assertTrue(S.Set(prefix .. "shineLook", stored, id))
    assertTrue(tint.disabledIf(), "a stored look is not read while it follows")
    assertNil(Ed.Row(prefix .. "shineFromSkin").disabledIf, "the way out is never grayed")
end

test("skin fix: a pad's Shine rows gray by the look that draws, not the stored one", function()
    shineGates("pad", "p1", "pad.button.", "rim")
end)

test("skin fix: a dial's Shine rows gray by the look that draws, not the stored one", function()
    shineGates("dial", "d2", "dial.slice.", "rim")
end)

test("skin fix: the hub's border size grays while its color follows, the two sharing the companion", function()
    local NS, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local Ed, S = NS.addon.Settings.Editors, NS.SchemaRuntime
    P.show("Dial")
    Ed.Select("dial", "d2")
    local row = Ed.Row("dial.hub.borderSize")
    assertTrue(row.disabledIf(), "bar.borderSize draws while it follows")
    assertTrue(S.Set("dial.hub.borderColorFromSkin", false, "d2"))
    assertEqual(row.disabledIf(), false)
end)

-- ── class color and the list ──

test("skin fix: a class-colored shine tint stays the class's under another skin", function()
    local NS, m = live()
    m.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.75, b = 0.5 } }
    local class = { 0.25, 0.75, 0.5 }
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    local cfg = NS.PadDefaults.Button()
    cfg.useClassColorShineTint = true
    local tr = select(1, NS.Skin.Color("qc.btnShineTint"))
    assertTrue(tr ~= class[1], "the token would show it")
    local tint = NS.Shine.Resolve(cfg, "qc.btnShine", "qc.btnShineTint").tint
    -- red under: the tint's follow not asking after the class color first
    assertEqual(tint[1], class[1])
    assertEqual(tint[2], class[2])
    assertEqual(tint[3], class[3])
    cfg.useClassColorShineTint = false
    assertEqual(NS.Shine.Resolve(cfg, "qc.btnShine", "qc.btnShineTint").tint[1], tr, "off, the skin's")
end)

test("skin flip: every *FromSkin key a template ships is on the step's list", function()
    local NS = T.enableAddon()
    local Lib = NS.Library
    local function walk(kind, surface)
        local listed = {}
        for _, key in ipairs(Lib.FULL_SKIN_KEYS[kind]) do listed[key] = true end
        local seen = 0
        for block, t in pairs(surface) do
            if type(t) == "table" then
                for key in pairs(t) do
                    if type(key) == "string" and key:find("FromSkin$") then
                        seen = seen + 1
                        -- red under: an entry dropped from surfaceKeys, which the forward walk never sees
                        assertTrue(listed[block .. "." .. key], kind .. ": " .. block .. "." .. key .. " is not listed")
                    end
                end
            end
        end
        return seen
    end
    assertTrue(walk("pads", Lib.TEMPLATES.pad) > 0)
    assertTrue(walk("dials", Lib.TEMPLATES.dial) > 0)
end)

-- ── the dial and the pad off their drawing setters ──

-- NS.Skin.Resolve answering `size` for bar.borderSize: every shipped skin's thickness is 1, the
-- stored default too, so only a token no skin ships tells the rows apart.
local function barThickness(NS, size)
    local resolve = NS.Skin.Resolve
    NS.Skin.Resolve = function(token, value, follows)
        if follows and token == "bar.borderSize" then return size end
        return resolve(token, value, follows)
    end
end

test("skin flip: the hub's rim draws the skin's color and thickness", function()
    local NS, m = live()
    local di = dial(NS)
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    local size = 3
    barThickness(NS, size)
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local rim = (NS.Dial.Instance("d2") or di).header.qcHubRim
    assertTrue(rim:IsShown())
    assertColor(rim.__color, color(NS, "text.accent"), "the rim's color")
    assertEqual(rim.__texture, NS.DialRender.RingTexture(NS.db.profile.dials.d2.hub.size, size), "the rim's ring")
end)

test("skin flip: a paged ring draws the skin's arrow, plate, dots and their back and border", function()
    local NS, m = live()
    local S = NS.SchemaRuntime
    assertTrue(S.Set("dial.page.dotBorder", 2, "d2"))
    skinOf(m):SetChoice(OWNER, "ka0s", OTHER)
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS, { n = 8, slices = 4 })))
    local ring = NS.Dial.Instance("d2").rings.active[2]
    assertTrue(ring.qcNext:IsShown(), "a paged ring")
    assertColor(ring.qcNext.qcIcon.__color, color(NS, "icon.arrow"), "the arrow")
    assertColor(ring.qcNext.qcPlate.__color, color(NS, "qc.sliceBg"), "the plate")
    assertColor(ring.qcDots[2].__color, color(NS, "qc.pageDot"), "a dot")
    assertColor(ring.qcDots[1].__color, color(NS, "text.accent"), "the current page")
    assertColor(ring.qcDotEdges[2].__color, color(NS, "qc.pageDotEdge"), "a dot's border")
    assertColor(ring.qcDotBack.mid.__color, color(NS, "qc.sliceBg"), "the row's back")
end)

test("skin flip: the hub's small labels take the slice label's face, not another block's", function()
    local NS, m = live()
    local S = NS.SchemaRuntime
    dial(NS)
    assertTrue(S.Set("dial.label.fontFromSkin", false, "d2"))
    assertTrue(S.Set("dial.label.font", "Arial Narrow", "d2"))
    local fetch = NS.MediaFetch
    NS.MediaFetch = function(kind, name)
        if kind == "font" and name == "Arial Narrow" then return "Fonts\\ARIALN.TTF" end
        return fetch(kind, name)
    end
    skinOf(m):SetChoice(OWNER, "ka0s", GLASS)
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local h = NS.Dial.Instance("d2").header
    local want = NS.MediaFetch("font", "Arial Narrow")
    assertTrue(want ~= nil, "a face this machine has")
    local d = NS.db.profile.dials.d2
    assertTrue(want ~= NS.DialRender.Look(120, d.label, d.slice, d).title.font.path, "the title's face would show it")
    assertEqual(h.qcStale.__font[1], want)
    assertEqual(h.qcLockdown.__font[1], want)
    assertEqual(h.qcTest.__font[1], want)
end)

test("skin flip: a button's edge takes the bar's thickness, not the window's", function()
    local NS, m = live()
    local inst = pad(NS)
    local Skin = skinOf(m)
    local drawn = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin)
        drawn[frame] = skin
        return apply(frame, skin)
    end
    barThickness(NS, 3)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    NS.Surfaces.ApplyAll("test")
    local btn = button(NS)
    assertEqual(drawn[btn.qcEdge].edgeSize, 3, "the edge's thickness")
    assertTrue(inst ~= nil)
end)

for _, key in ipairs({ "fontColorFromSkin", "fontShadowFromSkin", "backgroundFromSkin", "borderColorFromSkin",
    "textureFromSkin", "glowColorFromSkin", "shineFromSkin" }) do
    test("skin flip: toggling " .. key .. " on a live pad rebuilds the button's look", function()
        local NS = live()
        local R = NS.PadRender
        pad(NS)
        local before = R.ButtonLook(NS.db.profile.pads.p1.button)
        assertTrue(R.ButtonLook(NS.db.profile.pads.p1.button, before) == before, "held while nothing moved")
        -- red under: the companion missing from SIG_KEYS, so the old look is handed back
        assertTrue(NS.SchemaRuntime.Set("pad.button." .. key, false, "p1"))
        assertTrue(R.ButtonLook(NS.db.profile.pads.p1.button, before) ~= before, "a new look")
    end)
end

-- ── the host parts of L2 and L6, driven ──

test("skin fix: the token glyph is white under a stock panel and the skin's tint with the Scope cleared", function()
    local NS, m, Skin = painted()
    local Pop = NS.addon.Settings.CalloutPopup
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    local icon = Pop.tokenGlyph.icon
    assertColor(m.__paint(icon).vertex, { 1, 1, 1, 1 }, "stock")
    Skin:SetIgnore(OWNER, false, nil)
    -- red under: no Mark on the glyph
    assertColor(m.__paint(icon).vertex, color(NS, "icon.tint"), "cleared, and live")
end)

test("skin fix: the popup's token tooltip draws its first line in gtip.line, panel-scoped", function()
    local NS, m, Skin = painted()
    local Pop = NS.addon.Settings.CalloutPopup
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    local moved = skinWhere(Skin, "gtip.line", { "gtip.value" })
    Skin:SetChoice(OWNER, "ka0s", moved)
    local lines = tipColors(m)
    Pop.tokenGlyph:__fire("OnEnter")
    assertColor(rgbOf(lines()[2]), { 1, 0.82, 0, 1 }, "stock gold under the panel's Scope")
    Skin:SetIgnore(OWNER, false, nil)
    Pop.tokenGlyph:__fire("OnEnter")
    assertColor(rgbOf(lines()[2]), skinToken(Skin, moved, "gtip.line"), "the skin's, cleared")
end)

test("skin fix: a When checkbox's tooltip draws its line in gtip.line, panel-scoped", function()
    local NS, m, Skin = painted()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    P.show("Groups")
    NS.addon.Settings.Editors.Select("group", gid)
    P.drawer(P.tab("groups", "When"), "Arena"):__fire("OnClick")
    local cb = P.find(P.tab("groups", "When"), "CheckBox", "All arenas")
    assertTrue(cb ~= nil, "the whole-kind checkbox on the open drawer")
    local moved = skinWhere(Skin, "gtip.line", { "gtip.value" })
    Skin:SetChoice(OWNER, "ka0s", moved)
    local lines = tipColors(m)
    cb:__fire("OnEnter")
    assertColor(rgbOf(lines()[2]), { 1, 0.82, 0, 1 }, "stock gold")
    Skin:SetIgnore(OWNER, false, nil)
    cb:__fire("OnEnter")
    assertColor(rgbOf(lines()[2]), skinToken(Skin, moved, "gtip.line"), "the skin's, cleared")
end)

test("skin fix: the Preview window's tooltip titles take gtip.title, locked and at rest", function()
    local NS, m, Skin = painted()
    local moved = skinWhere(Skin, "gtip.title")
    Skin:SetChoice(OWNER, "ka0s", moved)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    local f = NS.PreviewWindow.__frame()
    local lines = tipColors(m)
    local want = color(NS, "gtip.title")
    f.endButton:__fire("OnEnter")
    assertColor(rgbOf(lines()[1]), want, "at rest")
    local editGroup = NS.Preview.EditGroup
    NS.Preview.EditGroup = function() return "g1" end
    f.endButton:__fire("OnEnter")
    NS.Preview.EditGroup = editGroup
    assertColor(rgbOf(lines()[1]), want, "locked")
end)

test("skin fix: the browser's cell tooltip title takes gtip.title under the HUD's rule", function()
    local NS, m, Skin = painted()
    local B = NS.addon.Settings.IconBrowser
    assertTrue(B.Open({ owner = "test", onChoose = function() end }))
    local moved = skinWhere(Skin, "gtip.title")
    Skin:SetChoice(OWNER, "ka0s", moved)
    local cell
    for _, c in ipairs(B.cells) do if c:IsShown() then cell = c; break end end
    local lines = tipColors(m)
    cell:__fire("OnEnter")
    assertColor(rgbOf(lines()[1]), color(NS, "gtip.title"), "a window of ours: the skin's title")
end)

test("skin fix: a cell's hover art is the client's while the panel is stock, tinted with the Scope cleared", function()
    local NS, m, Skin = painted()
    local B = NS.addon.Settings.IconBrowser
    assertTrue(B.Open({ owner = "test", onChoose = function() end }))
    -- The recorder's Button has no highlight region of its own: the client's, as a Texture.
    local cell, art = B.cells[1], m.CreateFrame("Frame"):CreateTexture()
    rawset(cell, "GetHighlightTexture", function() return art end)
    Skin:SetChoice(OWNER, "ka0s", GLASS)
    assertFalse(m.__paint(art).desaturated, "stock")
    Skin:SetIgnore(OWNER, false, nil)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    Skin:SetChoice(OWNER, "ka0s", GLASS)
    local c = Skin:ResolveSkin(GLASS)["list.hoverArt"]
    assertTrue(type(c) == "table", "a skin that has one")
    -- red under: paintHover gone, the art left as the client draws it
    assertTrue(m.__paint(art).desaturated, "desaturated")
    assertColor(m.__paint(art).vertex, c, "in the skin's hover art color")
end)

test("skin fix: the pad's combat refusal tooltip takes gtip.title", function()
    local NS, m = live()
    local inst = pad(NS)
    assertTrue(inst ~= nil)
    NS.db.profile.pads.p1.groupsAs = "tabs"
    pad(NS)
    skinOf(m):SetChoice(OWNER, "ka0s", skinWhere(skinOf(m), "gtip.title"))
    NS.Compat.InCombat = function() return true end
    local lines = tipColors(m)
    assertFalse(NS.Pad.Wheel("p1", 1))
    assertColor(rgbOf(lines()[1]), color(NS, "gtip.title"), "the refusal")
end)

local function activeLabel(widgets, needle)
    for _, x in ipairs(widgets) do
        if type(x.text) == "string" and x.text:find(needle, 1, true) then return x.text end
    end
    return nil
end

for _, page in ipairs({ { "pad", "p1", "Pad", "pads" }, { "dial", "d2", "Dial", "dials" } }) do
    test("skin fix: the " .. page[4] .. " page's active dot is the Ka0s mark with the Scope cleared", function()
        local NS, m, Skin = painted()
        local P = dofile("tests/page_helpers.lua")(NS, m)
        P.show(page[3])
        NS.addon.Settings.Editors.Select(page[1], page[2])
        local w = P.tab(page[4], "Groups")
        assertTrue(activeLabel(w, "Indicator-Green") ~= nil, "the client's dot while stock")
        Skin:SetIgnore(OWNER, false, nil)
        w = P.tab(page[4], "Groups")
        -- red under: the client's dot typed where the row writes its label
        assertTrue(activeLabel(w, "Indicator-Green") == nil, "no stock dot left")
        assertTrue(activeLabel(w, NS.Icon("confirm")) ~= nil, "the mark")
    end)
end

test("skin fix: the active dot's mark is drawn in sem.good", function()
    local NS, _, Skin = painted()
    Skin:SetIgnore(OWNER, false, nil)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    local c = Skin:ResolveSkin(OTHER)["sem.good"]
    local tint = Skin:ResolveSkin(OTHER)["icon.tint"]
    assertTrue(c[1] ~= tint[1] or c[2] ~= tint[2], "a mark that means something")
    local function byte(x) return math.floor(x * 255 + 0.5) end
    local want = (":%d:%d:%d|t"):format(byte(c[1]), byte(c[2]), byte(c[3]))
    assertTrue(NS.addon.Settings.Editors.ActiveDot():find(want, 1, true) ~= nil, "the good color, not the tint")
end)

test("skin fix: the degraded facade answers Ka0s Default for gtip.line and icon.arrow", function()
    local live0, lm = T.enableAddon()
    assertTrue(live0 ~= nil)
    local base = skinOf(lm):ResolveSkin(skinOf(lm).DEFAULT)
    local NS = T.newAddon{ skip = T.loadAddon.libFiles }
    -- red under: a token missing from NS.SKIN_FALLBACK (the arrow and the line would be nil)
    assertColor(color(NS, "gtip.line"), base["gtip.line"], "gtip.line")
    assertColor(color(NS, "icon.arrow"), base["icon.arrow"], "icon.arrow")
end)
