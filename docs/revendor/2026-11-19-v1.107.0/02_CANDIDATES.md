# 02 — Candidates: LibKa0s v1.106.0 -> v1.107.0

Sources: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` (7 commits) and the v1.107.0 CHANGELOG block at the tag.

## Class A: reached the addon on the re-vendor alone
- Each pad's drag strip reads its marks `?` then settings left to right (was settings then `?`), at the tighter pitch, tinted like the window header's marks (`icon.tint` at rest, `text.link` under the pointer) (WidgetsDragHandle 15).
- The strip's own tooltip opens above the strip, below only without room (WidgetsDragHandleTip 2). This addon passed no `tooltipPlace`, so nothing is removed.

## Class B: host change required
- The strip's close mark, which needs the host's `onClose`. Decided by the run, not here: AF-STRIP-QC (see 03_DECISIONS.md).

## Class C: whole-module adoption
- None new.
