local _, NS = ...
-- core/Constants.lua — fixed values the addon reads: the console font, the house gold and the one
-- layers table (frame-layering-§5).
--
-- Data only. The surface geometry, channel prefixes and limits of the design spec (§8–§11) are added
-- here by the tasks that read them.

NS.Constants = NS.Constants or {}
local C = NS.Constants

-- The debug console's monospace face, from the shared payload (core/MediaSetup.lua, which loads
-- first). A real client font when the library is absent, never nil and never a dead path.
C.FONT_MONO_NAME = "JetBrains Mono"
C.FONT_MONO = NS.MediaFont and NS.MediaFont(C.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT
    or "Fonts\\FRIZQT__.TTF"

-- The Ka0s gold (#FFD100), the logo's and the surfaces' accent.
C.GOLD = { r = 1.0, g = 0.82, b = 0.0 }

-- A chat type's color (a button's tooltip channel, a callout row's channel): WoW's chat colors, used
-- when ChatTypeInfo cannot be read (spec §10.1).
C.CHAT_COLORS = {
    PARTY = { 0.67, 0.67, 1.0 }, RAID = { 1.0, 0.5, 0.0 }, INSTANCE_CHAT = { 1.0, 0.5, 0.0 },
    RAID_WARNING = { 1.0, 0.28, 0.0 }, SAY = { 1.0, 1.0, 1.0 }, YELL = { 1.0, 0.25, 0.25 },
    CHANNEL1 = { 1.0, 0.75, 0.75 },
}

-- A button's flash for each send result: gold sent, red dropped, amber guarded (spec §10.1).
C.FLASH = {
    sent = { 1.0, 0.82, 0.0 }, dropped = { 0.9, 0.15, 0.15 }, guarded = { 1.0, 0.5, 0.0 },
}

-- ── LAYERS (frame-layering, standard v2.88.0) ───────────────────────────────────────────────────
-- Every strata and frame level the addon sets, named once. Every SetFrameStrata and SetFrameLevel in
-- core/, modules/ and settings/ reads this table (tests/test_layers.lua greps for a literal), and every
-- level is `base:GetFrameLevel() + LEVEL.<NAME>`, never absolute.
--
-- THE STACK, bottom to top (strata separates roles, level orders within one):
--   MEDIUM             HUD: the Comms Pads (modules/Pad.lua). Root L; header, title bands, title hit
--                      frames, buttons and the drag strip at L+1 (the strip lies outside the root's
--                      rect, 2 px past its edge, and ignores the pad's alpha; the hit frame draws nothing
--                      and its band takes no mouse, so neither needs a band of its own); the header's
--                      collapse button L+2. The Toggle Comms Pads click target is non-visual (exempt).
--   HIGH               DIAL_SCREEN: the dial's full-screen catcher (SendEngine.NewDialScreen), one strata
--                      under the dial. It ties with Blizzard's Settings panel (HIGH, toplevel): a click on
--                      an open Settings window while a key-opened dial is up reaches the settings, not the
--                      catcher. Known and rare; DIALOG would tie with the ring catchers, FULLSCREEN would
--                      cover the dial and take every slice click (QUI-Z09, kept as is).
--   DIALOG             HUD_POPUP: the Comms Dial, THE SECURE FIXED POINT (frame-layering-§1). Its secure
--                      header's strata cannot move in combat, so it is chosen first and every insecure
--                      frame that must sit over it moves up a tier (QC-06). Header H; ring containers
--                      H+1; wedges and page arrows H+2; the ring catchers at H + DIAL_CATCHER (-1),
--                      deliberately under their own ring, which draws no region; the hub front at
--                      H + DIAL_FRONT (+20). The library's debug console, perf panel and sim panel are
--                      DIALOG and toplevel too (LibKa0s v1.77.0): the dial's hub and wedges can draw over
--                      them where they overlap (developer-facing; a `strata` option on the library's
--                      tool windows is an open evolution, STRATA_MODEL LK-05, not taken).
--   FULLSCREEN         WINDOW: the preview window (modules/PreviewWindow.lua), at the client's level,
--                      NOT toplevel and never Raise()d (a raise would lift it over a modal's catcher in
--                      the same strata, frame-layering-§1's exception). MODAL: the callout popup and the icon
--                      browser (settings/ModalWindow.lua), each a band over UIParent: catcher at the base,
--                      Bg +1, window +2, page +3, close X +5; the popup's base MODAL (10), the browser's
--                      MODAL_OVER (200), far over anything the popup's widgets reach.
--   FULLSCREEN_DIALOG  POPUP: QuickComms' confirms (Blizzard StaticPopups lifted while shown and handed
--                      back on hide, ModalWindow.LiftConfirm) and the icon browser's Wowhead link window
--                      (a CopyWindow lifted after the library builds it). Also the library's menus, the
--                      AceGUI pull-outs and Blizzard's ColorPickerFrame, which the addon does not pick.
--   TOOLTIP            GameTooltip and the library's reorder ghost (Blizzard's and the library's).
-- Library bands the addon's frames meet: the drag strip and its marks (parent + 1 / handle + 1), the
-- resize grip (+10), the reorder drop line (+20) and row box (-1), the combat cover over a settings
-- page (computed), the debug console's Diagnostics link (+1).
--
-- INSIDE ONE ELEMENT (frame-layering-§3), a pad button at level B, a dial wedge at W:
--   button: regions (bg BACKGROUND, icon ARTWORK, shine ARTWORK 5-7) < edge frame B+1 (the button's
--           border) < its glow (edge + 1) < icon frame B+3 (the icon's border) < its glow (icon + 1) <
--           the overlay frame B+6 (label and padlock OVERLAY 0, dim / cool / flash veils OVERLAY 1-3);
--           the hover stays HIGHLIGHT on the button. The overlay takes no mouse: the secure button
--           under it takes the click.
--   wedge:  regions < icon frame W+1 < its glow (icon + 1) < the overlay frame W+4 (label, padlock,
--           veils).
-- Glow levels are LibCustomGlow's `frameLevel`: the effect sits at its host's level plus it.
C.LAYERS = {
    STRATA = {
        HUD = "MEDIUM",
        DIAL_SCREEN = "HIGH",
        HUD_POPUP = "DIALOG",
        WINDOW = "FULLSCREEN",
        MODAL = "FULLSCREEN",
        POPUP = "FULLSCREEN_DIALOG",
        -- Blizzard's own strata for a StaticPopup: the fallback LiftConfirm hands one back in when it
        -- could not read the strata the dialog came in.
        STATIC_POPUP = "DIALOG",
    },
    LEVEL = {
        -- a pad button (base: the button)
        BTN_EDGE = 1,
        BTN_ICON = 3,
        BTN_OVER = 6,
        -- a dial wedge (base: the wedge)
        WEDGE_ICON = 1,
        WEDGE_OVER = 4,
        -- glow effects (base: their host frame)
        BTN_GLOW = 1,
        ICON_GLOW = 1,
        -- the dial (base: its header)
        DIAL_FRONT = 20,
        DIAL_CATCHER = -1,
        -- the modal bands (base: UIParent for the band, the band's catcher for its parts)
        MODAL = 10,
        MODAL_OVER = 200,
        MODAL_BG = 1,
        MODAL_WINDOW = 2,
        MODAL_PAGE = 3,
        MODAL_CLOSE = 5,
    },
}
