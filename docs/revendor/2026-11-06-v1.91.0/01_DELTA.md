Delta: LibKa0s v1.90.0 -> v1.91.0

Item `FU-RV-QC` of the cross-repo run `Ka0sAddonsCommonTasks/docs/2026-11-06-FOLLOWUPS_V1_91/`
(branch `feat/2026-11-06-followups-v1-91`). Tag `v1.91.0` = `55bfbb4`, a **local** tag: `git -C
../LibKa0s ls-remote --tags origin v1.91.0` prints nothing, as expected. This is a new re-vendor, not a
refresh (the provenance line names v1.90.0). Extracted with `git -C ../LibKa0s archive v1.91.0 LibKa0s
testkit tools | tar -x` into a scratch directory, never the working tree.

## Step 0. Skipped

The installed skill's Step 0 roster regex (`\]\(\.\./\.\./[A-Za-z]+/\)`) matches nothing in
`ADDONS.md`, which writes `` `../../<Folder>/` ``, and its `tag_at` helper arrives with `"Ka0s"` /
`"repos:"` substituted for its positionals. Both are fixed upstream in this run (`FU-DC1`). The
collection-wide table is not produced. This addon's own row was run with a named-variable `tag_at`:
newest single-tag bundle `2026-11-06-v1.90.0`, line 1 base v1.89.0; the re-vendor commit `0b0ca05`'s
parent names v1.89.0. `ok`, no base correction owed.

## 3a. Base

- `grep -n '[Bb]undles' CLAUDE.md` -> `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).`
- `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `71321d6` (`SF2-RV-QC`, the v1.90.0 refresh),
  whose `CLAUDE.md` names v1.90.0. The two agree. No `CLAUDE.md` commit since.
- `diff -rq` of `git -C ../LibKa0s archive v1.90.0 LibKa0s testkit` (v1.90.0 = `1ba5fa2`) against
  `libs/LibKa0s` and `tests/_kit` printed nothing (`payload-matches`).

Range: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0` (9 commits: `55d3b0f` FU-L1 line-chart
pixels; `d72dc4a`, `c1ed261`, `acc9640`, `3f7be30` FU-L2 peels; `1938837`, `55bfbb4` FU-L3 release;
plus the v1.90.0 merge `f4be157` and its docs commit `06d97b0`). `git -C ../LibKa0s diff --stat
v1.90.0 v1.91.0 -- LibKa0s testkit`: 9 files, all under `LibKa0s/` (`Core.lua`, `CorePixel.lua`,
`LibKa0s.xml`, `SkinAceConfirm.lua`, `SkinPaintExtras.lua`, `SkinPaintHud.lua`, `Widgets.lua`,
`WidgetsDropdown.lua`, `WidgetsLineChart.lua`). No `testkit/` or `media/` file moved.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives the v1.90.0
tag's constants (the payload-matches check above). Line and bytes agree.

## 3c. Per-file minors (the tag's `LibKa0s/LibKa0s.xml`, 71 files)

| File | Old | New |
|---|---|---|
| `Core.lua` | 16 | 17 |
| `CorePixel.lua` (`PIXEL_MINOR`) | new | 1 |
| `SkinPaintExtras.lua` (`EXTRAS_MINOR`) | 18 | 19 |
| `SkinPaintHud.lua` (`HUD_MINOR`) | new | 1 |
| `SkinAceConfirm.lua` (`CONFIRM_MINOR`) | new | 1 |
| `Widgets.lua` | 25 | 26 |
| `WidgetsDropdown.lua` (`DROPDOWN_MINOR`) | new | 1 |
| `WidgetsLineChart.lua` (`CHART_MINOR`) | 6 | 7 |

The other 63 files are unchanged. Four files are new (the FU-L2 peels), none removed, no `NEEDS_*`
floor rises (CHANGELOG v1.91.0, *Versions in this release*). No cross-major skew. The new files'
places in the tag's XML: `CorePixel.lua` line 3 after `Core.lua`; `SkinPaintHud.lua` and
`SkinAceConfirm.lua` lines 23-24 after `SkinPaintExtras.lua`; `WidgetsDropdown.lua` line 29 after
`Widgets.lua`.

## 3d. Diffs before the copy

`diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` and the byte diff agree: the five
changed files above plus `LibKa0s.xml` differ, and `Only in <scratch>/LibKa0s` for the four new files.
No `Only in libs/LibKa0s` line. `diff -rq <scratch>/testkit tests/_kit`: empty.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Bus, Charts, Compat, Core (41 sites), DebugLog, Env, Glow, IconBrowser, Item, Launcher, Lifecycle,
Media, Options (20), Perf, Pool, Schema, Sim, Skin (29), Slash, Widgets (14). Every major that moved
(Core, Skin, Widgets) is consumed. QuickComms draws no line chart (no `LineChart` in its own code),
and its dropdown is `W.Dropdown` (`modules/PreviewWindow.lua:164`), whose code moved file, not
behavior.

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: tag `testkit/framework.lua:20` = 51, `tests/_kit/framework.lua:20` = 51. The
kit does not move; both payloads are still copied whole in one commit, so the pairing rule (v1.9.0+
takes kit 11+) holds by construction.

## 3g. Contract delta

Majors read: Core, Widgets, Skin (moved and consumed). The new documents
`docs/api/Core/version-17.1-docs.md`, `Widgets/version-26.1.6.13.7.8.5-docs.md` and
`Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md`, against their predecessors, filtered for
MUST / owe / stub:

- Core 17.1: a pure move of the pixel-edge section into `CorePixel.lua`; "What a host must change:
  nothing." The moved members are internal `__`.
- Widgets 26.1.6.13.7.8.5:33: "What a host owes: nothing" (LineChart minor 7). The dropdown peel moves
  `lib.Dropdown`, `lib.ContextMenu`, `lib.CloseMenu` to `WidgetsDropdown.lua` under the same major,
  names unchanged.
- Skin 17.1.27.8.19.19.1.1.17.4.9:21: "no member of the major or of a facade ... changes ... a host's
  Skin facade owes nothing." `S.BarGloss` and `S.HudFont` keep their names; QuickComms' degraded facade
  (`core/SkinSetup.lua:664,698`) mirrors facade names, not file locations, so it is unchanged.

`grep -rn '__Attach[A-Za-z]*'` outside `libs/` and `_kit/` finds no site.

## Blockers

None needing a fix. `tests/loader.lua:17` reads the library list from `libs/LibKa0s/LibKa0s.xml`
(`Loader.xmlFiles`), so the four new files load in the tag's XML order with no edit, and
`tests/test_harness.lua:40-41` pins only `Core.lua` first and `>= 30` files. No test pins an exact
library minor (`grep -rnE 'MINOR|minor' tests --include='*.lua' | grep -v _kit` names minors only in
comments and case titles). No stub mirrors a moved member (`grep -rnE '__Pixel|__WatchPixels|__OnPixelScale|__releaseChrome'`
outside `libs/` and `_kit/`: nothing). No README provenance line.

## 3h. Span check

Horizon `2026-10-22`. Vendored since: v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0
v1.83.0 v1.84.0 v1.85.0 v1.86.0 v1.89.0 v1.90.0. Recorded: the same fourteen. `grep -vxF -f recorded
vendored` printed nothing, so no span bundle is written. (Run with `tag_at` rewritten on a named
variable, `rev="$1"`, per the known placeholder defect.)

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `45:LibKa0s icons: all (icon browser).`, the next non-blank line
after the provenance line (44). Kept, as decided by the run (keep the icons line). No provenance split
needed. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); with `all` nothing is pruned, and the owner's in-client smoke stays the
backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: nothing.
