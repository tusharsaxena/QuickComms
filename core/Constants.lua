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

-- A chat type's color (a button's tooltip channel, a callout row's channel): WoW's chat colors, used
-- when ChatTypeInfo cannot be read (spec §10.1).
C.CHAT_COLORS = {
    PARTY = { 0.67, 0.67, 1.0 }, RAID = { 1.0, 0.5, 0.0 }, INSTANCE_CHAT = { 1.0, 0.5, 0.0 },
    RAID_WARNING = { 1.0, 0.28, 0.0 }, SAY = { 1.0, 1.0, 1.0 }, YELL = { 1.0, 0.25, 0.25 },
    CHANNEL1 = { 1.0, 0.75, 0.75 },
}

-- A button's flash for each send result is the skin's (modules/Pad_Render.lua R.Chrome, QC-03): gold
-- sent (text.accent), red dropped (qc.dropped), amber guarded (sem.warn), as spec §10.1 drew them.

-- ── LAYERS (frame-layering, standard v2.88.0) ───────────────────────────────────────────────────
-- Every strata and frame level the addon sets, named once. Every SetFrameStrata and SetFrameLevel in
-- core/, modules/ and settings/ reads this table (tests/test_layers.lua greps for a literal), and every
-- level is `base:GetFrameLevel() + LEVEL.<NAME>`, never absolute.
--
-- THE STACK, bottom to top (strata separates roles, level orders within one). Issue #14 lifted the pads
-- and the dial over other addons' windows, which mostly sit in MEDIUM, HIGH and DIALOG; every band named
-- here is a level over UIParent, so the tier stays clear of a low-level neighbor in the same strata:
--   DIALOG             HUD: the Comms Pads (modules/Pad.lua), a deviation (docs/ARCHITECTURE.md, register:
--                      frame-layering-§1 T1). Root L = UIParent + HUD, set before any child; header, title
--                      bands, title hit frames, buttons and the drag strip at L+1 (the strip lies outside
--                      the root's rect, 2 px past its edge, and ignores the pad's alpha; the hit frame
--                      draws nothing and its band takes no mouse, so neither needs a band of its own); the
--                      header's collapse button L+2. The Toggle Comms Pads click target is non-visual
--                      (exempt). A pad covers the settings window (HIGH), and a Blizzard StaticPopup, the
--                      debug console, the perf panel and the sim panel (DIALOG) where it overlaps them,
--                      until a click raises one of the toplevel ones. QuickComms' own confirms are lifted,
--                      and its skin picker (the library's, DIALOG) is raised over a pad when it shows
--                      (core/SkinSetup.lua), except a picker queued behind another Ka0s addon's.
--   FULLSCREEN         One strata, four bands, all over the pads and the settings window, in this order:
--                      DIAL  HUD_POPUP: the Comms Dial, THE SECURE FIXED POINT (frame-layering-§1). Its
--                            secure header's strata cannot move in combat, so it is chosen first, one over
--                            the pads (§4). Header H = UIParent + DIAL; the screen catcher
--                            (SendEngine.NewDialScreen, a key open only) at H + DIAL_SCREEN (-2), under the
--                            ring catchers it would tie with; the ring catchers at H + DIAL_CATCHER (-1),
--                            deliberately under their own ring, which draws no region; ring containers
--                            H+1; wedges and page arrows H+2; the hub front at H + DIAL_FRONT (+20). NOT
--                            FULLSCREEN_DIALOG, as the issue proposed: the modals and the preview window
--                            must cover a preview dial, and the only tier over that one is TOOLTIP, where
--                            their menus and pull-outs could not open over them.
--                      WINDOW: the preview window (modules/PreviewWindow.lua), UIParent + WINDOW, over the
--                            hub front, NOT toplevel and never Raise()d (a raise would lift it over a
--                            modal's catcher, frame-layering-§1's exception).
--                      MODAL: the callout popup and the icon browser (settings/ModalWindow.lua), each a
--                            band over UIParent: catcher at the base, Bg +1, window +2, page +3, close X
--                            +5; the popup's base MODAL, the browser's MODAL_OVER, far over anything the
--                            popup's widgets and its combat cover (page + 100) reach.
--                      The library's CopyWindow is here too, at its inherited level, under all four.
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
        HUD = "DIALOG",
        HUD_POPUP = "FULLSCREEN",
        WINDOW = "FULLSCREEN",
        MODAL = "FULLSCREEN",
        POPUP = "FULLSCREEN_DIALOG",
        -- Blizzard's own strata for a StaticPopup: the fallback LiftConfirm hands one back in when it
        -- could not read the strata the dialog came in.
        STATIC_POPUP = "DIALOG",
    },
    LEVEL = {
        -- a pad's root (base: UIParent), high in DIALOG (#14)
        HUD = 1000,
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
        -- the dial (base: UIParent for the header, the header for its parts)
        DIAL = 1000,
        DIAL_FRONT = 20,
        DIAL_CATCHER = -1,
        DIAL_SCREEN = -2,
        -- the preview window (base: UIParent): over the hub front, under a modal's catcher
        WINDOW = 1100,
        -- the modal bands (base: UIParent for the band, the band's catcher for its parts)
        MODAL = 1200,
        MODAL_OVER = 1400,
        MODAL_BG = 1,
        MODAL_WINDOW = 2,
        MODAL_PAGE = 3,
        MODAL_CLOSE = 5,
    },
}
