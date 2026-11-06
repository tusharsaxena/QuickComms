# Candidates (QuickComms, LibKa0s v1.90.0 -> v1.91.0)

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the tag's `CHANGELOG.md` block v1.91.0, and
the API documents for Core 17.1, Widgets 26.1.6.13.7.8.5 and Skin 17.1.27.8.19.19.1.1.17.4.9 against
their predecessors. No blocker from `01_DELTA.md` 3g is listed here.

## A. Delivered on the re-vendor alone

- **The line chart's lines in physical pixels** (`FU-L1`; CHANGELOG v1.91.0, *The line chart's lines
  in physical pixels*; Widgets 26.1.6.13.7.8.5 doc:33, "What a host owes: nothing"). WidgetsLineChart
  minor 7. QuickComms draws no line chart, so nothing it shows changes; the code arrives on the copy.
- **The band-file peels** (`FU-L2`; CHANGELOG v1.91.0, *The band files peeled*): Core 17 + CorePixel 1,
  Widgets 26 + WidgetsDropdown 1, SkinPaintExtras 19 + SkinPaintHud 1 + SkinAceConfirm 1. Pure moves:
  no member, option or behavior changes. QuickComms' `W.Dropdown` (`modules/PreviewWindow.lua:164`),
  its skin's `S.HudFont` / `S.BarGloss` and its profile page's confirmation box are drawn by the same
  code from its new files.

## B. Host change required

None. No new public surface, descriptor field or row type in the range.

## C. Whole-module adoption

None: no major is new in this range, and every major that moved is already consumed (3e).
