# 02 — Candidates: LibKa0s v1.107.0 -> v1.108.0

Sources: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` (15 commits) and the v1.108.0 CHANGELOG block at the tag.

## Class A: reached the addon on the re-vendor alone
- A pad strip whose rect reads secret shows its tooltip above its nearest readable ancestor (WidgetsDragHandleTip 3, LibKa0s#99).
- The shared menu (the Preview-as situation list, the callout popup's context menu) tints a submenu arrow from the menu palette and opens at `opts.width` for secret labels (WidgetsDropdown 3).
- A window footer lays out only its shown marks (Widgets 30, LibKa0s#94).
- Every composed Font, Border and Color block's defaults now start on the skin; this addon already followed it through its own `extra` companions, so no profile moves.

## Class B: host change required
- `skinBands = true` on a host skin table (Core 19, SD-LK-97.16): the pad window's gradient and art. Owed by SD-SK-QC (the release's *What a consumer owes*).
- `W.OwnerWarnings(owner, sink)` (Widgets 30, SD-LK-97.1): optional, a debug-gated report of owner-less library widgets under an owned window. Not adopted in this run; noted for the lead.
- The kit's `expect`, `hold` and `clear` surface fields (revision 58). Owed by SD-SK-QC.

## Class C: whole-module adoption
- None new (Callout, Charts, WaypointArrow stay unadopted: Quick Comms draws no call-out, chart or arrow).
