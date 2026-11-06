# Candidates (QuickComms, LibKa0s v1.89.0 -> v1.90.0)

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`, the tag's `CHANGELOG.md` block v1.90.0, and
the API documents for Core 16, Widgets 24.5.12.6.8.5, Skin 17.1.27.8.19.18.17.4.9 and Options
37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4 against their predecessors. No blocker from `01_DELTA.md`
3g is listed here.

## A. Delivered on the re-vendor alone

- **One physical pixel for every Widgets edge** (`SF1-L1`; CHANGELOG v1.90.0, *One physical pixel*;
  Widgets 24 doc, "What a host owes: nothing"). `W.Dropdown`'s box and its shared menu, as the preview
  window's chat-channel picker draws them (`modules/PreviewWindow.lua:165`), now draw a one-physical-pixel
  edge at any UI scale and sub-pixel position, with no skin and under every skin. No host change.
- **Core 16 pixel internals** (`__PixelSize`, `__WatchPixels`, `__OnPixelScale`, `__PixelBackdrop`)
  and **SkinPaint 19 / SkinPaintExtras 18** (`P.px` on Core's, `P.pxEdge`): internal, reached through
  the Widgets controls and the skin painter.

## B. Host change required

- **`RegisterOwner(owner, { keepScope = true })`** (`SF1-L2`; Skin 17 doc; Options doc, "a host whose
  Scope is a documented deviation registers with `keepScope = true`; every other host owes nothing").
  Files it would touch: `core/SkinSetup.lua:729`. QuickComms' Scope toggles are ordinary player settings
  (`settings/SchemaRows.lua:109,112`), not a documented deviation, so a copy from another addon carrying
  its Scope here is the intended behavior. Recommendation: not applicable. Blast radius: none.

## C. Whole-module adoption

None: no major is new in this range, and every major that moved is already consumed (3e).
