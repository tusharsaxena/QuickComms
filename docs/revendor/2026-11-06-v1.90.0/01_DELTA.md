Delta: LibKa0s v1.89.0 -> v1.90.0

Item `SF1-RV-QC` of the cross-repo run `Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`
(branch `feat/2026-11-06-revendor-libka0s-v1-89`), from the owner's first smoke feedback
(`SF1_SMOKE_FEEDBACK.md`). Tag `v1.90.0` = `4485b8f`, a **local** tag: `git -C ../LibKa0s ls-remote
--tags origin v1.90.0` shows nothing, as expected, and this is a new re-vendor, not a refresh (the
provenance line names v1.89.0). Extracted with `git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools
| tar -x` into a scratch directory, never the working tree.

## 3a. Base

- `grep -n '[Bb]undles' CLAUDE.md` -> `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).`
- `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `5b24443` (`V89-QC`), whose `CLAUDE.md`
  names v1.89.0. The two agree.
- `diff -rq` of `git -C ../LibKa0s archive v1.89.0 LibKa0s testkit` against `libs/LibKa0s` and
  `tests/_kit` printed nothing (`payload-matches`).
- Step 0 pre-flight for this addon: newest single-tag bundle `2026-11-06-v1.89.0`, line 1 base
  v1.86.0; `git show 5b24443^:CLAUDE.md` names v1.86.0. `ok`, no base correction owed.

Range: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0` (7 commits: `7d42f4e` SF1-L1 pixel edges,
`b9f7651` SF1-L2 keepScope, `4ac9f3c` and `4485b8f` SF1-L3 release, plus the harvest merge `e809ca3`
and its two docs commits). `git -C ../LibKa0s diff --stat v1.89.0 v1.90.0`: under the payload only
`LibKa0s/Core.lua`, `OptionsAppearance.lua`, `Skin.lua`, `SkinPaint.lua`, `SkinPaintExtras.lua`,
`Widgets.lua`, `WidgetsAutocomplete.lua` (7 files). No `testkit/` or `media/` file moved.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives the v1.89.0
tag's constants (the payload-matches check above). Line and bytes agree.

## 3c. Per-file minors (the tag's `LibKa0s/LibKa0s.xml`, 67 files)

| File | Old | New |
|---|---|---|
| `Core.lua` | 15 | 16 |
| `Skin.lua` | 16 | 17 |
| `SkinPaint.lua` (`PAINT_MINOR`) | 18 | 19 |
| `SkinPaintExtras.lua` (`EXTRAS_MINOR`) | 17 | 18 |
| `Widgets.lua` | 23 | 24 |
| `WidgetsAutocomplete.lua` (`AUTOCOMPLETE_MINOR`) | 7 | 8 |
| `OptionsAppearance.lua` (`APPEARANCE_MINOR`) | 6 | 7 |

The other 60 files are unchanged. No file is new, none removed, no `NEEDS_*` floor rises (CHANGELOG
v1.90.0: Widgets and Skin resolve Core's new members at call time). No cross-major skew.

## 3d. Diffs before the copy

`diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` and the byte diff: the seven files above
differ, nothing else. `diff -rq <scratch>/testkit tests/_kit`: empty. No `Only in` line on either side
(the declaration is `all`, so every icon ships).

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Bus, Charts, Compat, Core (36 sites), DebugLog, Env, Glow, IconBrowser, Item, Launcher, Lifecycle,
Media, Options (20), Perf, Pool, Schema, Sim, Skin (23), Slash, Widgets (14). Every major that moved
(Core, Skin, Widgets, Options) is consumed. Widgets controls in use that SF1-L1 reaches: `W.Dropdown`
(`modules/PreviewWindow.lua:165`); no `W.SearchBox` or autocomplete use site.

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: tag `testkit/framework.lua:20` = 51, `tests/_kit/framework.lua:20` = 51. The
kit does not move; both payloads are still copied whole in one commit, so the pairing rule (v1.9.0+
takes kit 11+) holds by construction.

## 3g. Contract delta

Majors read: Core, Widgets, Skin, Options (moved and consumed). `diff` of each predecessor document
against its successor (`docs/api/Core/version-15-docs.md` -> `version-16-docs.md`,
`Widgets/version-23.5.12.6.7.5` -> `24.5.12.6.8.5`, `Skin/version-16.1.27.8.18.17.17.4.9` ->
`17.1.27.8.19.18.17.4.9`, `Options/version-37...7.6.11.1.1.4` -> `37...7.7.11.1.1.4`), filtered for
MUST / owe / stub / contract:

- Core 16: "No public member is added, removed or renamed"; the four new members are internal `__`.
- Widgets 24: "**What a host owes**: nothing." `lib.__pixelEdged` is internal.
- Skin 17 / SkinPaint 19 / SkinPaintExtras 18: "a host's Skin facade owes nothing."
- Options 37 (OptionsAppearance 7): "a host whose Scope is a documented deviation registers with
  `keepScope = true`; every other host owes nothing." QuickComms' Scope is not a documented deviation
  (`settings/SchemaRows.lua:109,112`, ordinary user toggles), and the run names only the Skin Tester for
  it (SF1-ST), so this host owes nothing.

`grep -rn '__Attach[A-Za-z]*'` outside `libs/` and `_kit/` finds no site, so no host-supplied member can
have a moved call site.

## Blockers

None. No `__releaseChrome` mirror (`grep -rn '__releaseChrome'` outside `libs/` and `_kit/`: nothing).
No README provenance line.

## 3h. Span check

Horizon `2026-10-22`. Vendored since: v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0
v1.83.0 v1.84.0 v1.85.0 v1.86.0 v1.89.0. Recorded: the same thirteen. `grep -vxF -f recorded vendored`
printed nothing, so no span bundle is written.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `45:LibKa0s icons: all (icon browser).`, the next non-blank line
after the provenance line (44). Kept, as decided by the run (keep the icons line). No provenance split
needed. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); with `all` nothing is pruned, and the owner's in-client smoke stays the
backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: nothing.
