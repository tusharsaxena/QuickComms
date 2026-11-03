local addonName, NS = ...
-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§1, §3).
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("QuickComms")`: the painting vocabulary
--                           (Shell, Button, Text, ...) and Token / Color / Resolve / OnLooksChanged.
--                           Every surface that draws reads its colors here.
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.SchemaRuntime.Get;
--                           "ka0s", "ka0s" before OnInitialize has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.SchemaRuntime.Set, the one
--                           seam `/qc set` and the settings panel already write through
--                           (architecture-§5); `i`, the Scope's `{ panel, fonts }`, writes the two
--                           exceptions, and `m`, the Font and texture section's `{ font, texture }`,
--                           writes the two overrides ("" for false, the skin's own); its `outline`,
--                           when not nil, writes skin.outline (LibKa0s v1.82.0, D-06).
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before the store exists.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints every
--                           frame recorded for this owner and THEN fires OnLooksChanged. No argument
--                           applies the stored pair (OnInitialize, the profile events) and with it
--                           the stored exceptions and overrides; a nil half keeps that half (each
--                           Skin tab row's onChange).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions (`Skin:SetIgnore`); no argument applies the
--                           stored pair, a nil half keeps that half.
--   NS.ApplySkinOverride(f,t) moves the applied overrides (`Skin:SetOverride`); no argument applies
--                           the stored pair, a nil half keeps that half, false or "" clears it.
--   NS.ApplySkinOutline(m)  moves the applied Font outline (`Skin:SetOutline`, Skin minor 9, D-06):
--                           "all" text, "hud" text only or "off"; no argument applies the stored
--                           skin.outline. NS.SkinOutline() reads it ("hud" before the store exists).
--   NS.SKIN_OUTLINE_OPTIONS the outline row's values, the library's three modes in its order.
--   NS.RunSkinVerb()        the reserved `/qc skin` verb's act: O.SkinVerb(NS.SkinPickerSpec()), the
--                           picker a new profile shows, whatever skin.pickerSeen says (D-16).
--   NS.SkinDescribe()       one line for the diagnostics report: the applied choice and the
--                           EllesmereUI gate as the library reads it (`Skin:GetEUIStatus`).
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/SchemaRows.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default tokens the degraded facade answers.
--   NS.SKIN_TOKENS          this addon's own tokens (below), as RegisterOwner is handed them.
--   NS.SkinColor(name, p)   a color token as a call site writes it (three components when opaque).
--                           `p` true marks a settings page's read: Ka0s Default's value while the
--                           owner ignores its settings panel (D-03), NS.SkinPanelColor's rule.
--   NS.SkinEscape(name, p)  a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cffa0a0a0).
--   NS.SkinMarkup(name, s)  `s` wrapped in that escape and "|r" (`s` alone for a token the skin
--                           leaves alone): a settings page's colored line, read at call time,
--                           always panel-scoped.
--   NS.SkinPanelIgnored()   whether the owner ignores its settings panel (Skin:GetIgnore's panel half).
--   NS.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this owner:
--   NS.SkinPaintAceTree(c)  `Skin:PaintAce` / `Skin:PaintAceTree` with the owner bound (the facade
--                           carries neither). Nothing while the owner ignores its settings panel
--                           (the Scope's Ignore settings panel, on by default); release restores stock.
--   NS.SkinOnRelease(w, fn) host release work chained onto the widget's own OnRelease
--                           (`Skin:OnRelease`), so it and the skin's restore both run, once.
--   NS.MaybeShowSkinPicker() the first-run skin picker (LibKa0s OptionsSkinPicker 1, owner ruling
--                           O3): the Options instance's SkinPicker while the profile's
--                           `skin.pickerSeen` is false and the addon stands up; held to
--                           PLAYER_REGEN_ENABLED in combat. Answers the frame, or nil, "queued"
--                           behind another Ka0s addon's picker.
--   NS.ScheduleSkinPicker() the login start: MaybeShowSkinPicker two seconds in, on the AceTimer
--                           NS.HideSkinPicker cancels (core/QuickComms.lua OnEnable).
--   NS.HideSkinPicker()     takes a shown picker down (its pending preview put back) or out of the
--                           queue WITHOUT marking it seen: the stand-down, and first on every
--                           profile event; drops a held combat start and the login timer.
--   NS.SkinPickerSpec()     the spec MaybeShowSkinPicker hands the library.
--
-- ── THE OWNER TOKENS (skinning-§1) ───────────────────────────────────────────────────────────
--
-- The colors Quick Comms draws under Ka0s Default that no library token holds exactly: the M0
-- inventory's QC-G1..G3 and its near shades (D7, D8), kept at today's pixels (DECISIONS X1) rather
-- than snapped to the nearest library token. Each is named in this addon's namespace (`qc.`, X2,
-- X12), carries today's value as `default` and follows the nearest library ROLE token, so every
-- other skin, and EllesmereUI, draws it in its own palette. The two state veils hold only their
-- alphas: each skin's `cover.dim` is its own (LibKa0s v1.85.0, the owner's ruling of 2026-11-01), so
-- R.Chrome draws both in that wash's color, and following it whole would draw the refused veil and
-- the cooling veil alike.
--
-- WoW Default's `win.border` is white and its `win.borderSize` 32: they are what its dialog ART is
-- multiplied by and drawn at, not a color or a thickness for a flat edge, and Glass's 8 is the same
-- kind of number. So an edge this addon draws flat never reads either as it stands: the window's and a
-- band's color answer the skin's gray under WoW Default (`skins`), and a band's thickness follows the
-- bar edge, the hairline a button already wears. That skin's `bar.texture` is the client's dim status
-- bar art, which multiplies its red buttons down to maroon, so a button there has none.
--
-- Three looks are not today's pixels, by the owner's ruling of 2026-11-01: Ka0s Default's button body,
-- edge, texture and shine tint are the fuller look every other skin's buttons have, and the Strength
-- of the shine, in every skin, is qc.btnShineStrength and qc.sliceShineStrength, a third under the 80
-- and 85 it was and one value, so a pad and a dial sharing a look read alike.
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- Below core/CoreSetup.lua, whose NS.ApplySkin the degraded facade's Shell routes to, and above
-- core/WidgetsSetup.lua and every module that builds a frame, so NS.Skin exists for all of them;
-- settings/SchemaRows.lua reads NS.SKIN_OPTIONS at file load and is far below. AT FILE LOAD, never
-- PLAYER_LOGIN (skinning-§1): the EllesmereUI provider has to offer the owner to EllesmereUI before
-- EllesmereUI dispatches its skins, which `## OptionalDeps: EllesmereUI` makes it do after this
-- file. Nothing here reads the profile at load: RegisterOwner calls `get` once, before AceDB
-- exists, and it answers Ka0s Default; the profile's pair is applied by NS.ApplySkinChoice right
-- after the store and its migrations exist (core/QuickComms.lua OnInitialize).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never picked.
-- Applying only the row's own half against the applied choice makes each write a no-op (SetChoice
-- is idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/qc set skin.skin obsidian` still repaints. Nothing skin-related keys off SETTINGS_CHANGED: a
-- surface that has to rebuild on a skin change subscribes to NS.Skin.OnLooksChanged.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local OUTLINE_PATH, OUTLINE_DEFAULT = "skin.outline", "hud"
local DEFAULT = "ka0s"

local function byte(n) return n / 255 end
-- WoW Default's own grays (its tooltip edge, its divider), for an edge drawn flat.
local WOW_EDGE, WOW_RULE = { byte(0x9A), byte(0x9A), byte(0x9A), 1 }, { byte(0x6E), byte(0x6E), byte(0x6E), 1 }

NS.SKIN_TOKENS = {
    -- QC-G1: the pad button's and the dial wedge's state veils, a refused bake and the spam guard.
    ["qc.veil"]      = { default = { 0, 0, 0, 0.55 } },
    ["qc.veilCool"]  = { default = { 0, 0, 0, 0.35 } },
    -- QC-G2: the pad button's hover wash, gold at a quarter.
    ["qc.hover"]     = { default = { 1, 0.82, 0, 0.25 }, follow = "list.hover" },
    -- QC-G3: the icon browser's selected cell, gold at 0.7 behind the icon.
    ["qc.selStrong"] = { default = { 1, 0.82, 0, 0.7 }, follow = "list.sel" },
    -- D7's near shades. The settings pages' gray hint lines (|cffa0a0a0).
    ["qc.hint"]      = { default = { byte(160), byte(160), byte(160), 1 }, follow = "text.muted" },
    -- The When drawer's "Not active now" (|cffff6060).
    ["qc.inactive"]  = { default = { 1, byte(96), byte(96), 1 }, follow = "sem.bad" },
    -- The PREVIEW and TEST MODE marks on a pad's strip and a dial's hub (|cff19ff19).
    ["qc.preview"]   = { default = { byte(25), 1, byte(25), 1 }, follow = "sem.goodAlt" },
    -- The LOCKDOWN tag on a pad's header and a dial's hub.
    ["qc.lockdown"]  = { default = { 1, 0.1, 0.1, 1 }, follow = "sem.statusBad" },
    -- The send flash of a callout the game seems to have dropped.
    ["qc.dropped"]   = { default = { 0.9, 0.15, 0.15, 1 }, follow = "sem.bad" },
    -- The callout popup's and the icon browser's catcher dim over the settings window.
    ["qc.modalDim"]  = { default = { 0, 0, 0, 0.45 }, follow = "cover.dim" },
    -- A dial's page arrow at an end of its pages.
    ["qc.arrowDim"]  = { default = { 0.4, 0.4, 0.4, 0.6 }, follow = "text.disabled" },
    -- D8: the icon browser's search clear mark and its gray "Click an icon..." line (|cffaaaaaa).
    ["qc.markGray"]  = { default = { 0.54, 0.54, 0.54, 1 }, follow = "icon.dim" },
    ["qc.note"]      = { default = { byte(170), byte(170), byte(170), 1 }, follow = "text.muted" },
    -- The full skin (LibKa0s v1.85.0, cause D7): where a pad's or a dial's default is not the library
    -- token's value, today's pixels under Ka0s Default and the token in every other skin. A section
    -- title's band draws no band in any skin (R5-QC1, Ka0sAddonsCommonTasks
    -- docs/2026-11-03-SMOKE_ROUND5, the lead's call 5): no fill, and no edge while it follows the skin
    -- (R.BAND_TOKENS' `bare`), so the pad's header is its only band. The edge color is for a border
    -- the player stores. The header's own band is the library's title band (S.TitleBar); qc.headEdge is
    -- the edge of a border the player stores on the header.
    ["qc.bandBg"]    = { default = { 0, 0, 0, 0 } },
    ["qc.bandEdge"]  = { default = { 1, 1, 1, 1 }, follow = "win.border", skins = { wow = WOW_RULE } },
    ["qc.headEdge"]  = { default = { 1, 1, 1, 1 }, follow = "win.border", skins = { wow = WOW_RULE } },
    -- A pad window's border art, where the skin's own is a thicker frame than bar.borderStyle's (SF-QC-3):
    -- WoW Default's dialog frame, as the Skin Tester's window wears. "None" in every other skin leaves
    -- the window on bar.borderStyle and bar.borderSize.
    ["qc.winBorderStyle"] = { default = "None", skins = { wow = "Blizzard Dialog" } },
    ["qc.winBorderSize"]  = { default = 0, skins = { wow = 16 } },
    -- A pad window's edge: win.border, but for the white WoW Default's art is multiplied by.
    ["qc.winEdge"]   = { default = { 0, 0, 0, 1 }, follow = "win.border", skins = { wow = WOW_EDGE } },
    -- A pad button's body, edge and texture ("" naming none: WoW Default's red, flat).
    ["qc.btnBg"]     = { default = { 0.10, 0.10, 0.12, 0.90 }, follow = "btn.bg" },
    ["qc.btnEdge"]   = { default = { 0.24, 0.24, 0.27, 0.90 }, follow = "btn.border" },
    ["qc.btnTexture"] = { default = "Ka0s Default", follow = "bar.texture", skins = { wow = "" } },
    -- The shine: a look per skin (modules/Shine.lua's names, "none" for none), a tint and a Strength
    -- in percent, one in every skin. No library token names a look or a Strength, so these say it
    -- themselves.
    ["qc.btnShine"]  = { default = "glossfade", skins = { glass = "gloss", contrast = "none" } },
    ["qc.btnShineTint"] = { default = { 0x80 / 255, 0x80 / 255, 0x80 / 255, 1 }, follow = "text.muted" },
    ["qc.btnShineStrength"] = { default = 55 },
    ["qc.sliceShine"] = { default = "orb", skins = { glass = "frost", contrast = "none" } },
    ["qc.sliceShineTint"] = { default = { 0x80 / 255, 0x80 / 255, 0x80 / 255, 1 }, follow = "text.muted" },
    ["qc.sliceShineStrength"] = { default = 55 },
    -- A dial's fills: its slices and plates (alpha 0.80), its hub, its page dots and their edge.
    ["qc.sliceBg"]   = { default = { 0.06, 0.06, 0.08, 0.80 }, follow = "win.bg" },
    ["qc.hubBg"]     = { default = { 0.12, 0.12, 0.14, 0.95 }, follow = "btn.bg" },
    ["qc.pageDot"]   = { default = { 0.4, 0.4, 0.4, 0.9 }, follow = "text.disabled" },
    ["qc.pageDotEdge"] = { default = { 0, 0, 0, 0.9 }, follow = "win.border", skins = { wow = { 0, 0, 0, 0.9 } } },
    -- An icon's tint: white, every icon as it was, where icon.tint is a gray under Ka0s Default.
    ["qc.iconTint"]  = { default = { 1, 1, 1, 1 }, follow = "icon.tint" },
    -- HUD text's shadow color under a skin that states none: Ka0s Default's hud.shadow is false, and
    -- every font block here ships with a black shadow (R.ShadowOf, modules/Pad_Render.lua).
    ["qc.shadow"]    = { default = { 0, 0, 0, 1 }, follow = "hud.shadow" },
}

-- The Ka0s Default tokens the DEGRADED facade answers, copied from the library and limited to the
-- ones this addon reads. Both arms publish the table, so tests/test_skinsetup.lua can hold each
-- entry to the live library's Ka0s Default value: a copy that drifts goes red there. A surface
-- converted to a token adds the token here in the same change.
NS.SKIN_FALLBACK = {
    ["win.bg"]         = { 0.06, 0.06, 0.08, 0.92 },
    ["win.border"]     = { 0, 0, 0, 1 },
    ["win.inner"]      = { 0.24, 0.24, 0.27, 0.85 },
    ["title.text"]     = { 1, 0.82, 0, 1 },
    ["text.body"]      = { 0.9, 0.9, 0.9, 1 },
    ["text.accent"]    = { 1, 0.82, 0, 1 },
    ["text.heading"]   = { 1, 0.82, 0, 1 },
    ["text.highlight"] = { 1, 1, 1, 1 },
    ["text.disabled"]  = { 0.5, 0.5, 0.5, 1 },
    ["gtip.title"]     = { 1, 0.82, 0, 1 },
    ["gtip.value"]     = { 1, 1, 1, 1 },
    ["gtip.line"]      = { 1, 0.82, 0, 1 },
    ["gtip.subtle"]    = { 0.7, 0.7, 0.7, 1 },
    -- QC-02's windows: the Preview window's button (the step panels' tokens, D8), the popup's
    -- refused-field line, the icon browser's hint box and magnifier.
    ["btn.hover"]      = { 1, 0.82, 0, 1 },
    ["sem.stepReady"]  = { 0.9, 0.9, 0.92, 1 },
    ["sem.unknown"]    = { 0.6, 0.6, 0.6, 1 },
    ["sem.badAlt"]     = { 1, 0.25, 0.25, 1 },
    ["drawer.boxBg"]   = { 0.08, 0.07, 0.05, 0.9 },
    ["drawer.boxBorder"] = { 0.24, 0.2, 0.13, 1 },
    ["log.tag"]        = { byte(0xc9), byte(0xa6), byte(0x6b), 1 },
    -- QC-04's settings pages: the When drawer's "Active now." (|cff40ff40).
    ["sem.goodAlt"]    = { 0.25, 1, 0.25, 1 },
    -- QC-03's HUD: a button's fallback fill, the guarded flash, and what a font or border block
    -- follows while its "Use the skin's ..." companion is on (the face, the border styles and size).
    ["btn.bg"]         = { 0.1, 0.1, 0.12, 0.9 },
    ["sem.warn"]       = { 1, 0.5, 0, 1 },
    ["hud.font"]       = "Ka0s Prototype",
    ["bar.borderStyle"] = "None",
    ["icon.borderStyle"] = "Solid",
    ["icon.borderSize"] = 1,   -- 1 px in every skin since LibKa0s v1.85.0 R3-FIX
    -- The full skin's HUD (cause D7): the tokens a color or a size follows that are not above.
    ["bar.borderSize"] = 1,
    ["cover.dim"]      = { 0, 0, 0, 0.6 },
    ["icon.arrow"]     = { 1, 0.82, 0, 1 },
    ["icon.border"]    = { 0, 0, 0, 1 },
}

--- A stored color, or the skin's while its "Use the skin's ..." companion `<key>FromSkin` is on: r, g,
--- b, a. A class color comes first and is left alone, and a token that answers nothing (a skin that
--- leaves it alone) falls back to the stored color. So does the library's absence: the degraded
--- facade's S.Color answers a token's default for the panels it paints, and a companion defaults true,
--- so a read past S.IsEnabled would draw that over the player's color. `look` is the block, `fallback`
--- its missing swatch.
function NS.SkinFollow(look, key, token, useClass, fallback)
    if look[key .. "FromSkin"] == true and not useClass and NS.Skin.IsEnabled() then
        local r, g, b, a = NS.Skin.Color(token)
        if r then return r, g, b, a or 1 end
    end
    return NS.ResolveColor(look[key] or fallback, useClass)
end

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
--- With `panel`, the read is a settings page's (Ka0sAddonsCommonTasks D-03): while this owner ignores
--- its settings panel (the Scope's Ignore settings panel, on by default) the page is stock AceGUI, so
--- the answer is Ka0s Default's value (the host copy, NS.SKIN_FALLBACK, or an owner token's
--- default), the pixel the page drew before it had a skin, and one page never mixes stock and
--- skinned. Without it the read is a window's or the HUD's, which wear the skin whatever that switch
--- says (D-01).
function NS.SkinColor(name, panel)
    local r, g, b, a = NS.SkinPanelColor(name, panel)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- True while this owner ignores its settings panel: the public Skin:GetIgnore panel half, never the
--- library's internals. Always false without the library (nothing is skinned then).
function NS.SkinPanelIgnored()
    if not (Skin and type(Skin.GetIgnore) == "function") then return false end
    return (Skin:GetIgnore(addonName)) == true
end

--- A color token's r, g, b, a for a settings page (`panel` true) or anything else (NS.SkinColor).
function NS.SkinPanelColor(name, panel)
    if panel and NS.SkinPanelIgnored() then
        local own = NS.SKIN_TOKENS[name]
        local c = NS.SKIN_FALLBACK[name] or (own and own.default)
        if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
    end
    return NS.Skin.Color(name)
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (.5 is 80), so
--- markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token the skin
--- leaves alone. `panel` as NS.SkinColor's.
function NS.SkinEscape(name, panel)
    local r, g, b = NS.SkinPanelColor(name, panel)
    if r == nil then return nil end
    local function toByte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(toByte(r), toByte(g), toByte(b))
end

--- How far down from `frame`'s top its title band ends, in px: the band S.Shell lays (S.Band, LibKa0s
--- SkinPaintExtras minor 17: in from a flat edge by `win.borderSize`, else 1, `title.height` high;
--- flush and 25 px under EllesmereUI), read off the band itself so a window's content starts under it
--- in every skin (R5-WIN, Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5, item 2). A band that
--- answers no height yet (before layout, or headless) is `title.height` high; with no band (the
--- library absent) the answer is a 1 px edge plus `title.height`.
function NS.SkinBandBottom(frame)
    local tall = tonumber(NS.Skin.Token("title.height")) or 30
    local band = NS.Skin.Band and NS.Skin.Band(frame)
    if type(band) ~= "table" then return 1 + tall end
    local _, _, _, _, y = band:GetPoint(1)
    local h = band:GetHeight()
    return -(tonumber(y) or -1) + ((type(h) == "number" and h > 0) and h or tall)
end

--- `text` in a color token, as markup: NS.SkinEscape(name, true) .. text .. "|r", or `text` alone
--- for a token the skin leaves alone. The settings pages' hint, state and inherit lines, whose escape
--- once sat inside the locale key; always a settings page's read (panel-scoped).
function NS.SkinMarkup(name, text)
    local esc = NS.SkinEscape(name, true)
    if not esc then return text end
    return esc .. text .. "|r"
end

-- The Font outline's modes (LibKa0s-Skin-1.0 minor 9's OUTLINE_MODES), with the Skin tab's words;
-- settings/SchemaRows.lua's skin.outline row validates `/qc set` against them.
NS.SKIN_OUTLINE_OPTIONS = {
    { value = "all", text = NS.L["All text"] },
    { value = "hud", text = NS.L["HUD text only"] },
    { value = "off", text = NS.L["Off"] },
}

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = NS.L["Ka0s skins"] },
    { value = "eui",  text = NS.L["EllesmereUI"] },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

-- The schema instance, nil-safely: settings/Schema.lua publishes it far below this file, and the
-- profile store exists from OnInitialize.
local function schema()
    local S = NS.SchemaRuntime
    if not (NS.db and S and S.Get and S.Set) then return nil end
    return S
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    local S = schema()
    if not S then return DEFAULT, DEFAULT end
    return S.Get(SOURCE_PATH) or DEFAULT, S.Get(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through NS.SchemaRuntime.Set (validate, store, the [Set] line,
--- onChange). `media` is `{ font = key|false, texture = key|false, outline = mode|nil }`: the Skin
--- tab's Font and texture pick, its Font outline and another addon's copy all hand it here, after
--- Skin:SetOverride or Skin:SetOutline moved the applied look, so each row's onChange re-applies its
--- own half as a no-op. A nil `outline` leaves skin.outline as it is.
function NS.WriteSkinChoice(source, skin, ignore, media)
    local S = schema()
    if not S then return end
    if source ~= nil then S.Set(SOURCE_PATH, source) end
    if skin ~= nil then S.Set(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        S.Set(PANEL_PATH, ignore.panel == true)
        S.Set(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        S.Set(FONT_PATH, storedKey(media.font))
        S.Set(TEXTURE_PATH, storedKey(media.texture))
        if media.outline ~= nil then S.Set(OUTLINE_PATH, media.outline) end
    end
end

--- The stored Font outline, nil-safely: "hud" (the library's default) until the store exists.
function NS.SkinOutline()
    local S = schema()
    local v = S and S.Get(OUTLINE_PATH)
    return type(v) == "string" and v or OUTLINE_DEFAULT
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
    local S = schema()
    if not S then return false, false end
    local font, texture = storedKey(S.Get(FONT_PATH)), storedKey(S.Get(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: false, false until the profile store exists.
local function storedIgnore()
    local S = schema()
    if not S then return false, false end
    return S.Get(PANEL_PATH) == true, S.Get(FONTS_PATH) == true
end

-- ── the first-run skin picker (LibKa0s OptionsSkinPicker 1, owner ruling O3) ─────────────────
--
-- WHEN. Once per UI session, two seconds after OnEnable (a login or a reload, off the login spike,
-- on an AceTimer this file cancels), and again after every profile event (core/QuickComms.lua
-- reloadProfile), because a new, copied or reset profile carries its own `pickerSeen`. Never while
-- the addon stands down, and never in combat: a start in combat is held for the
-- PLAYER_REGEN_ENABLED edge, one private target at most (modules/SendEngine.lua's held stand-down
-- idiom). The library's queue waits out combat only for the NEXT owner's picker; a first call with
-- nothing up shows at once, whatever the lockdown.
--
-- SEEN. The library calls `onClose` once per showing, by any route the player takes (Apply, its
-- close control, the gear, Escape), and once for a picker still queued behind another Ka0s addon's
-- when that addon's "Apply to all Ka0s addons" dismisses it unshown; that is the one write of
-- `skin.pickerSeen`, through NS.SchemaRuntime.Set. A close this addon makes itself
-- (NS.HideSkinPicker: the stand-down, a profile event) is not the player's and writes nothing.
--
-- THE EYE (the rollout's X6). Test mode (modules/Preview.lua), session state that writes nothing:
-- every pad shows its placeholders and dial 1 opens, so the player sees the skin on this addon's
-- HUD; the library raises its window over them once onPreview returns. A start test mode refuses
-- (stood down, in combat) prints its own line.
--
-- PREVIEW. A pick only previews: the Skin major moves and every recorded frame repaints, but `set`
-- (NS.WriteSkinChoice) runs only on Apply, the gear or Apply to all. The close control and Escape
-- put back the stored choice as it reads at the close (the library's revert reads `get`). A
-- profile event takes the picker down FIRST, before the new profile's skin is applied, so the new
-- profile's whole pair is what NS.ApplySkinChoice leaves worn.

local PICKER_PATH = "skin.pickerSeen"
local PICKER_DELAY = 2       -- seconds after OnEnable
local pickerTarget           -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held
local pickerTimer            -- the login start's AceTimer handle, until it fires
local quietClose = false     -- true while NS.HideSkinPicker takes the picker down

--- The Options instance (settings/OptionsSetup.lua's Settings.Helpers), read at call time: it
--- loads after this file.
local function options()
    local S = NS.addon and NS.addon.Settings
    return S and S.Helpers
end

--- The eye: test mode on, unless it already is (the header above).
local function previewSkin()
    local P = NS.Preview
    if not (P and P.SetTestMode and P.IsTestMode) then return end
    if not P.IsTestMode() then P.SetTestMode(true) end
end

--- The player's close: the picker seen, and nothing else. The library's put-back already wears the
--- stored choice, so the skin is not this callback's to move.
local function pickerClosed()
    if quietClose then return end
    local S = schema()
    if S then S.Set(PICKER_PATH, true) end
end

function NS.SkinPickerSpec()
    return {
        owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice,
        -- The gear: O.OpenOptionsPanel("general"), the key settings/Panel.lua gave
        -- RegisterOptionsPage, then O.SelectTab("general", "Appearance"), the Skin tab's key.
        page = "general", tab = "Appearance",
        onPreview = previewSkin, onClose = pickerClosed,
    }
end

local function dropPickerDeferral()
    if pickerTarget then pickerTarget:UnregisterEvent("PLAYER_REGEN_ENABLED") end
    pickerTarget = nil
end

local function dropPickerTimer()
    if pickerTimer and NS.addon and NS.addon.CancelTimer then NS.addon:CancelTimer(pickerTimer) end
    pickerTimer = nil
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

--- True while this profile has not closed the picker and the addon stands up.
local function pickerDue()
    local S = schema()
    if not S then return false end
    if NS.IsStoodDown and NS.IsStoodDown() then return false end
    return S.Get(PICKER_PATH) == false
end

function NS.HideSkinPicker()
    dropPickerDeferral()
    dropPickerTimer()
    local O = options()
    if not (O and type(O.HideSkinPicker) == "function") then return end
    quietClose = true
    local ok, err = pcall(O.HideSkinPicker)
    quietClose = false
    if not ok then error(err, 0) end
end

--- The library's window sits at its inherited DIALOG level and never raises itself on a show, so a pad
--- at UIParent + LAYERS.LEVEL.HUD would cover it and take its clicks (#14). A queued picker is not
--- reached: the library shows it later, with no host hook. Passes the library's answer through.
local function raisedPicker(win, why)
    if win and type(win.Raise) == "function" then win:Raise() end
    return win, why
end

--- Show the picker when this profile has not seen it: answers the library's frame, or nil,
--- "queued" while another Ka0s addon's picker is up (it shows when that one closes), or nil.
function NS.MaybeShowSkinPicker()
    local O = options()
    if not (O and type(O.SkinPicker) == "function") then return nil end
    if not pickerDue() then
        NS.HideSkinPicker()
        return nil
    end
    if inCombat() then
        if pickerTarget then return nil end
        local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
        if not (AceEvent and NS.SafeRegisterEvent) then return nil end
        local target = AceEvent:Embed({})
        -- Through the SafeRegister family (events-frames-taint-§1); a refusal lists the event in
        -- NS.rejectedEvents and the start is simply not held.
        if NS.SafeRegisterEvent(target, "PLAYER_REGEN_ENABLED", function()
            dropPickerDeferral()
            NS.MaybeShowSkinPicker()
        end, NS.rejectedEvents) then
            pickerTarget = target
        end
        return nil
    end
    return raisedPicker(O.SkinPicker(NS.SkinPickerSpec()))
end

-- ── the one-time skin notice (LibKa0s OptionsSkinPicker minor 9, SG-L3) ────────────────────────
-- A release that wants every account to learn skins exist raises lib.SKIN_NOTICE_VERSION. The first
-- addon to ask in a session claims the notice and shows the picker; every other addon records the
-- version and stays quiet. The record is `db.global.skinNotice`, a number: account-wide, so a profile
-- switch never shows it twice. In combat nothing is claimed; it asks again every NOTICE_RETRY seconds until combat ends.
local NOTICE_RETRY = 5   -- seconds between asks while the player is in combat
local noticeWaiting = false

local function noticeGlobal()
    local d = NS.db or (NS.addon and NS.addon.db)
    return d and d.global or nil
end

local noticeStore = {
    get = function() local g = noticeGlobal(); return g and g.skinNotice or nil end,
    set = function(v) local g = noticeGlobal(); if g then g.skinNotice = v end end,
}

function NS.MaybeShowSkinNotice()
    local O = options()
    if not (O and type(O.SkinNotice) == "function" and noticeGlobal()) then return nil, "unavailable" end
    if NS.IsStoodDown and NS.IsStoodDown() then
        -- A stood-down addon shows nothing, but a seen record still silences the rest (SG-L3).
        O.SkinNotice(nil, noticeStore, true)
        return nil, "standdown"
    end
    local spec = NS.SkinPickerSpec()
    local frame, why = raisedPicker(O.SkinNotice(spec, noticeStore))
    if why == "combat" and not noticeWaiting and type(_G.C_Timer) == "table" and _G.C_Timer.After then
        noticeWaiting = true
        _G.C_Timer.After(NOTICE_RETRY, function()
            noticeWaiting = false
            NS.MaybeShowSkinNotice()
        end)
    end
    return frame, why
end

local pickerFirstRun = NS.MaybeShowSkinPicker
function NS.MaybeShowSkinPicker()
    local frame, why = NS.MaybeShowSkinNotice()
    if frame or why == "queued" then return frame, why end
    return pickerFirstRun()
end

--- The reserved `/qc skin` verb's act (LibKa0s v1.82.0, OptionsSkinPicker minor 3, ruling D-16):
--- O.SkinVerb with the spec the first-run start builds, so it shows the picker a new profile shows
--- whatever skin.pickerSeen says. The library prints its own lines (combat on every call, queued,
--- unavailable); without LibKa0s the stub answers nil, "absent" and this prints the library-absent
--- line. The dispatcher refuses the verb while the addon is disabled (settings/Slash.lua). Answers
--- the picker's frame, or nil and the reason.
function NS.RunSkinVerb()
    local O = options()
    local win, why
    if O and type(O.SkinVerb) == "function" then win, why = O.SkinVerb(NS.SkinPickerSpec()) else why = "absent" end
    if win == nil and why == "absent" and NS.Print then
        NS.Print(NS.L["%s is unavailable: the LibKa0s library did not load."]:format(NS.SLASH .. " skin"))
    end
    return raisedPicker(win, why)
end

--- The login start, PICKER_DELAY seconds in; a second call while one waits is a no-op.
function NS.ScheduleSkinPicker()
    if pickerTimer or not (NS.addon and NS.addon.ScheduleTimer) then return end
    pickerTimer = NS.addon:ScheduleTimer(function()
        pickerTimer = nil
        NS.MaybeShowSkinPicker()
    end, PICKER_DELAY)
end

-- AceGUI keeps ONE callback per event name (options-ui-§19). Without the library's chain there is
-- no skin restore to share the release with, so the host's work takes the callback, as it did
-- before the skin engine.
local function releaseByCallback(widget, fn)
    if type(widget) ~= "table" or type(fn) ~= "function" or type(widget.SetCallback) ~= "function" then
        return nil
    end
    widget:SetCallback("OnRelease", function(w) fn(w) end)
    return fn
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function token(name)
        local own = NS.SKIN_TOKENS[name]
        return NS.SKIN_FALLBACK[name] or (own and own.default)
    end
    local function color(name)
        local c = token(name)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises. The list is LibKa0s-Skin-1.0's VOCAB; tests/test_skinsetup.lua holds this table to
    -- the live facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture", "FontFlags", "HudFontSize", "Mark", "MarkText", "HudTextColor", "HudLabelColor",
        "BarFillColor", "HudShadow", "BarGloss", "HudFont", "BarBorder", "HoverArt",
        "Band", "Header",
    }) do S[name] = noop end

    S.Token = token
    S.Color = color
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end
    -- The window edge is CoreSetup's: without the library that is nothing (core/CoreSetup.lua).
    S.Shell = function(frame) if NS.ApplySkin then NS.ApplySkin(frame) end end
    S.Text = function(fs, role)
        local r, g, b, a = color(role == "title" and "title.text" or ("text." .. tostring(role)))
        if r == nil then r, g, b, a = color(role) end
        if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
    end
    S.GetFont = function() return _G.STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end
    -- LibKa0s v1.82.0 (SkinPaintExtras minor 7): never nil, which SetFont would read as no flags or
    -- refuse. A picked flag as stored; From skin ("@skin") or nothing stored is OUTLINE, Ka0s
    -- Default's HUD outline. A size as stored when it is a number above 0, else 12, unscaled.
    S.FontFlags = function(v) if type(v) == "string" and v ~= S.FROM_SKIN then return v end return "OUTLINE" end
    S.HudFontSize = function(size) local n = tonumber(size) return (n and n > 0) and n or 12 end
    -- LibKa0s v1.85.0 (SkinPaintExtras minors 9 to 16): HudFont must draw, a no-op would leave a pad
    -- with no face, and BarBorder must answer the three it is handed, or a pad loses its stored border.
    -- No font object, so a stored shadow does not draw on a 12.0.7 client with the library absent,
    -- which the library's Options document accepts. MarkText still answers its markup, untinted: a
    -- line is built around it.
    S.BarBorder = function(style, show, size) return style, show, size end
    S.HudFont = function(fs, opts)
        opts = type(opts) == "table" and opts or {}
        local face = opts.face
        if type(face) ~= "string" or face == "" then face = _G.STANDARD_TEXT_FONT end
        if type(face) ~= "string" then return nil end
        fs:SetFont(face, S.HudFontSize(opts.size), S.FontFlags(opts.flags))
        local on = opts.shadow and true or false
        fs:SetShadowColor(0, 0, 0, on and 1 or 0)
        fs:SetShadowOffset(on and 1 or 0, on and -1 or 0)
    end
    S.MarkText = function(path, size)
        size = size or 14
        return ("|T%s:%d:%d|t"):format(path, size, size)
    end

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    function NS.ApplySkinOutline() return false end
    function NS.SkinDescribe() return "skin: Ka0s Default (the LibKa0s skin library is not loaded)" end
    -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
    function NS.SkinPaintAce() return false end
    function NS.SkinPaintAceTree() return 0 end
    NS.SkinOnRelease = releaseByCallback
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = NS.BRAND,
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup for
-- its own picks.
local RELOAD_LINE = NS.L["Reload your interface (/reload) to finish changing the skin."]

-- The AceGUI rows (SkinAce.lua). Every widget the settings pages make comes from the Options
-- instance's `AceGUI`, the owner proxy, which paints on Create already; PaintAce for the same owner
-- repaints in place, so a host call after it is harmless, and it is what paints a widget acquired
-- any other way (AceConfigDialog's, on the Profiles page). Each guards on the member, so a copy
-- whose SkinAce secondary did not attach paints nothing.
function NS.SkinPaintAce(widget)
    if type(Skin.PaintAce) ~= "function" then return false end
    return Skin:PaintAce(addonName, widget)
end

function NS.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

function NS.SkinOnRelease(widget, fn)
    if type(Skin.OnRelease) ~= "function" then return releaseByCallback(widget, fn) end
    return Skin:OnRelease(widget, fn)
end

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride (a Skin major before minor 6) moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored Font outline; a mode moves it (the skin.outline row's onChange, a
--- no-op after the Skin tab already did). A copy without SetOutline (a Skin major before minor 9)
--- moves nothing; the library reads an unknown mode as "hud".
function NS.ApplySkinOutline(mode)
    if type(Skin.SetOutline) ~= "function" then return false end
    if mode == nil then mode = NS.SkinOutline() end
    return Skin:SetOutline(addonName, mode)
end

--- No argument applies the stored pair AND the stored exceptions, overrides and Font outline
--- (OnInitialize, the profile events); a nil half keeps that half and leaves the rest alone (each
--- Skin tab row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
        NS.ApplySkinOutline()
    end
    return changed, reload
end

--- The applied choice and the EllesmereUI gate, as the library reads them: `ok` is whether the
--- EllesmereUI source may be chosen, `painted` whether EllesmereUI paints this addon, `refused` the
--- latched reason it does not, and `failing` the first of the four conditions that does not hold
--- (eui, master, own, facade), or none. This addon never reads EllesmereUI's state itself
--- (skinning-§5): the library's GetEUIStatus is the one window onto it.
function NS.SkinDescribe()
    local source, skin = Skin:GetChoice(addonName)
    local line = ("skin: source=%s skin=%s"):format(tostring(source), tostring(skin))
    if type(Skin.GetEUIStatus) ~= "function" then return line .. " ellesmereui: n/a" end
    local st = Skin:GetEUIStatus(addonName) or {}
    local failing = "none"
    for _, c in ipairs(st.conditions or {}) do
        if not c.ok then failing = tostring(c.key); break end
    end
    return line .. (" ellesmereui: ok=%s painted=%s refused=%s failing=%s"):format(
        tostring(st.ok == true), tostring(st.painted == true), tostring(st.refused), failing)
end
