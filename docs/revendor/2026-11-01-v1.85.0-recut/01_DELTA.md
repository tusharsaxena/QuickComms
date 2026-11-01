Delta: LibKa0s v1.84.0 -> v1.85.0

This is a re-cut, not a new release. The local tag v1.85.0 moved from `9776130` to `2ad1a50` before it was pushed (`git -C ../LibKa0s ls-remote --tags origin v1.85.0` prints nothing), for the owner's rulings of 2026-11-01 and the review's gate (`FS-FIX`, `FS-GATE`). Line 1 keeps the tag-level delta; the real delta of this folder is commit to commit, `9776130..2ad1a50`. `2026-11-01-v1.85.0/` is frozen, so this record sits in its own suffixed folder.

Base: `grep -n '[Bb]undles' CLAUDE.md` gives v1.85.0, and `723b546` (FS-QC-RV) vendored the earlier cut.

## Per-file minors

| File | Old | New |
|---|---|---|
| `Skin.lua` | 14 | 15 |
| `SkinDefs.lua` | 24 | 25 |
| `SkinDefsOthers.lua` | 6 | 7 |
| `SkinPaint.lua` | 16 | 17 |
| `SkinPaintExtras.lua` | 15 | 16 |
| `SkinPaintControls.lua` | 14 | 15 |
| `SkinEUI.lua` | 3 | 4 |
| `Widgets.lua` | 20 | 21 |
| `OptionsCompose.lua` | 17 | 18 |
| `Media.lua` | 11 | 12 |

Kit revision 49 -> 50, in the same commit as the bytes.

## Blockers

- The skin facade owed `BarBorder` and `HoverArt`; `BarBorder` answers its three. `tests/run.lua` owed `test_skin_values` and `test_skin_switch` by the pair.
- No `O.LabelFont`, `O.PositionBlock` or `ContextMenu` stub moved here: the parity case stayed green.

## Icons

`LibKa0s icons: all (icon browser).` stays. Nothing pruned, no credit moves.
