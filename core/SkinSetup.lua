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
--                           writes the two overrides ("" for false, the skin's own).
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
--   NS.SkinDescribe()       one line for the diagnostics report: the applied choice and the
--                           EllesmereUI gate as the library reads it (`Skin:GetEUIStatus`).
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/SchemaRows.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default tokens the degraded facade answers.
--   NS.SKIN_TOKENS          this addon's own tokens (below), as RegisterOwner is handed them.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque).
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cffa0a0a0).
--   NS.SkinMarkup(name, s)  `s` wrapped in that escape and "|r" (`s` alone for a token the skin
--                           leaves alone): a settings page's colored line, read at call time.
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
-- other skin, and EllesmereUI, draws it in its own palette. The two state veils follow nothing:
-- the one black wash in the schema, `cover.dim`, is the same in every skin, so following it would
-- draw the refused veil and the cooling veil alike everywhere but Ka0s Default; a black wash over
-- an icon reads on every skin as it is.
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
local DEFAULT = "ka0s"

local function byte(n) return n / 255 end

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
    ["hud.font"]       = "Ka0s Oxanium SemiBold",
    ["bar.borderStyle"] = "None",
    ["icon.borderStyle"] = "Solid",
    ["icon.borderSize"] = 2,
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (.5 is 80), so
--- markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token the skin
--- leaves alone.
function NS.SkinEscape(name)
    local r, g, b = NS.Skin.Color(name)
    if r == nil then return nil end
    local function toByte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(toByte(r), toByte(g), toByte(b))
end

--- `text` in a color token, as markup: NS.SkinEscape(name) .. text .. "|r", or `text` alone for a
--- token the skin leaves alone. The settings pages' hint, state and inherit lines, whose escape
--- once sat inside the locale key.
function NS.SkinMarkup(name, text)
    local esc = NS.SkinEscape(name)
    if not esc then return text end
    return esc .. text .. "|r"
end

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
--- onChange). `media` is `{ font = key|false, texture = key|false }`: the Skin tab's Font and
--- texture pick and another addon's copy both hand it here, after Skin:SetOverride moved the
--- applied pair, so each row's onChange re-applies its own half as a no-op.
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
    end
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
    return O.SkinPicker(NS.SkinPickerSpec())
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
        "BarTexture",
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

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
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

--- No argument applies the stored pair AND the stored exceptions and overrides (OnInitialize, the
--- profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
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
