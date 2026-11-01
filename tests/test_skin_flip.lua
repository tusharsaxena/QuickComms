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
    assertEqual(db.global.schemaVersion, 13)
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
    local class = { NS.ResolveColor({ r = 1, g = 1, b = 1, a = 1 }, true) }
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
    assertNil(bg.qcGhostColor, "the ghost reads the file")
    R.ApplyButtonLook(btn, { sig = "f", bg = { 0.5, 0.6, 0.7, 0.8 }, edge = {}, font = R.LabelFont({}), glow = false }, 100, 24)
    assertColor(bg.qcGhostColor, { 0.5, 0.6, 0.7, 0.8 }, "the flat body is recorded")
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
    local NS = live()
    local inst = pad(NS)
    local label = button(NS).qcLabel
    local src, fs = label.__fontObject, nil
    assertTrue(src ~= nil)
    local track = inst.track
    track.ghost = track.ghost or NS.AnimGhost.New()
    assertTrue(NS.AnimGhost.Capture(track.ghost, inst.root, { inst.root }))
    for i = 1, track.ghost.used do
        for _, f in ipairs(track.ghost.subs[i].qcFont) do
            if f.__fontObject == src then fs = f end
        end
    end
    assertTrue(fs ~= nil, "the copy wears the same object")
    assertColor(fs.__font and { 1, 1, 1, 1 } or nil, { 1, 1, 1, 1 }, "and draws its face")
end)

test("skin flip: a color texture a library paints on a watched frame reaches the ghost", function()
    local NS = live()
    local inst = pad(NS)
    local t = inst.root:CreateTexture(nil, "BORDER")
    -- red under: no G.Watch around NS.ApplySkin (the gap docs/known-limitations.md named)
    t:SetColorTexture(0.2, 0.3, 0.4, 0.5)
    assertColor(t.__color, { 0.2, 0.3, 0.4, 0.5 }, "it still paints")
    assertColor(t.qcGhostColor, { 0.2, 0.3, 0.4, 0.5 }, "and the record lets the ghost copy it")
    t:SetColorTexture(0.1, 0.1, 0.1, 1)
    assertEqual(t.qcGhostColor[1], 0.1, "a repaint moves the record")
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
    Ed.RemoveMark(image)
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
