# Icon browser, game icons and tinted glyphs: design

Date: 2026-10-18. Status: approved by the owner 2026-10-18 (questions answered; builder calls marked).

## Why

The inline "Choose an icon" grid offers 8 raid markers, the built-in sets' icons and ~20 curated
LibKa0s glyphs. The owner wants far more choice: every icon the macro icon selector offers, every
LibKa0s glyph (tintable, since they are white on transparent), and the 8 markers, in an interface
that stays intuitive although the callout editor is already a popup.

## Goals

- **Icon browser window** (owner ruling): the inline grid goes. Where the picker sat (the callout
  popup and a user group's General tab), the editor shows the current icon (tinted), a
  **Choose icon…** button and, for a glyph, its color swatch. The button opens the browser, a
  window stacked **above** the callout popup (higher level than the popup and its modal cover), built
  from the same chrome as the popup (`SettingsFrameTemplate`, same title, same EllesmereUI paint path
  through `core/EUIBridge.lua`). Only one browser exists; it is modal to whatever opened it.
- **Tabs**, in this order:
  1. **Suggested**: the 8 markers, the built-in sets' icons and the previously curated glyphs (today's palette).
  2. **Markers**: the 8 raid target markers (owner: 8 is the whole set).
  3. **Game icons**: every icon `GetMacroIcons` and `GetMacroItemIcons` return (fileIDs; built
     lazily on first open, after the client's own icon list loads), with an All / Spells / Items
     filter. Thousands of entries: the grid must be virtualized (only visible rows have frames).
  4. **Glyphs**: every icon in the LibKa0s catalog (`NS.IconNames()`, never a hard-coded list,
     library-stack-§8), labeled from the catalog key ("arrow-circle-down" → "Arrow circle down",
     the curated labels where they exist). Builder call: derived labels are not localized.
- **Glyph color** (owner ruling): a color swatch in the Glyphs tab and next to the editor's icon opens
  Blizzard's `ColorPickerFrame` (it must show above the browser and the popup). Default white. The
  tint is stored with the member and drawn **everywhere** the icon is drawn: pads, dials, the
  settings lists, the popup's icon preview, the browser's selection.
- The browser has **Choose** and **Cancel**; Escape and the close X cancel. Hovering an icon shows a
  tooltip (label, or the fileID for a game icon); a click selects it (highlighted), a double-click
  chooses it. The currently stored icon is preselected and its tab opened.
- Combat: the browser follows the popup and panel combat rules (no writes in combat; it closes as
  Cancel when its opener closes).

## Data model

- New optional member field **`iconColor`** on user callouts and user groups: a 6-digit hex string
  `"rrggbb"` (lowercase), `nil` = untinted. Validated by a new `Library.ValidIconColor`; written only
  through the seam (`callout.iconColor`, `group.iconColor` member rows). It only applies to a glyph;
  choosing a non-glyph icon clears it (one act with the icon write). Built-ins carry none.
- `icon` keeps its shape (path string or fileID number); game icons are numbers.
- Share: `iconColor` travels with callouts and groups; old strings import unchanged; validation drops
  a bad color like any bad field. Prepare drops a malformed stored color. No payload version bump.
- The callout popup's draft gains `iconColor`; Save writes it with the other fields in one act.

## Non-goals

- No search by icon name (the client gives fileIDs only). No custom texture typing beyond the
  existing Icon box. No tint on non-glyph icons.

## Standard check

Any rule this breaks must be raised before committing (CLAUDE.md). Expected: none new; the browser
reuses the popup's chrome and its accepted deviations (close X, window edge). If the reviewer finds
that the deviation rows need to name the browser too, extend the existing rows' text (owner already
accepted the chrome for "the popup"), and say so in the report.

## Left to the builder

Browser geometry and grid icon size, swatch widget, the virtualization approach (Blizzard
`ScrollBox` + grid view or a hand-rolled pool), how the game-icon list is cached, label wording.
