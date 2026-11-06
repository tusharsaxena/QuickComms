Delta: LibKa0s v1.86.0 -> v1.89.0

Item `V89-QC` of the cross-repo run `Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`
(branch `feat/2026-11-06-revendor-libka0s-v1-89`). Tag `v1.89.0` = `df00e5f`, extracted with
`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x` into a scratch directory, never the
working tree.

## 3a. Base

- `grep -n '[Bb]undles' CLAUDE.md` -> `44:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.86.0 (MIT).`
- `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `7398649`, whose `CLAUDE.md` names v1.86.0.
  The two agree.
- `diff -rq` of `git -C ../LibKa0s archive v1.86.0 LibKa0s testkit` against `libs/LibKa0s` and
  `tests/_kit` printed nothing (`payload-matches`).
- Step 0 pre-flight (run's `inputs/step0-preflight.txt`): `QuickComms  2026-11-04-v1.86.0  base v1.85.0
  vendored-before v1.85.0@7398649  ok`. No base correction owed.

Range: `git -C ../LibKa0s log --oneline v1.86.0..v1.89.0` (15 commits: Widgets 23 cascading menus at
v1.87.0, Toast 4 stack at v1.88.0, kit revision 51 at v1.89.0). `git -C ../LibKa0s diff --stat v1.86.0
v1.89.0 -- LibKa0s testkit tools`: `LibKa0s/Toast.lua`, `LibKa0s/Widgets.lua`, `testkit/README.md`,
`testkit/framework.lua`, `testkit/mock_ace.lua` (5 files). No `media/` file moved.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives 67
constants, every one the v1.86.0 tag's (the payload-matches check above). Line and bytes agree.

## 3c. Per-file minors (the tag's `LibKa0s/LibKa0s.xml`, 67 files)

| File | Old | New |
|---|---|---|
| `Toast.lua` | 3 | 4 |
| `Widgets.lua` | 22 | 23 |

The other 65 files are unchanged. No file is new, none removed, no `NEEDS_*` floor rises. No
cross-major skew.

## 3d. Diffs before the copy

`diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s`: `Toast.lua` and `Widgets.lua` differ.
`diff -rq <scratch>/testkit tests/_kit`: `README.md`, `framework.lua`, `mock_ace.lua` differ. No
`Only in` line on either side (the declaration is `all`, so every icon ships).

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
IconBrowser, DebugLog, Bus, Media, Compat, Lifecycle, Glow, Core, Env, Launcher, Pool, Perf, Widgets,
Skin, Slash, Schema, Options (`core/*Setup.lua`, `modules/PreviewWindow.lua`,
`modules/Library_Migrate.lua`, `settings/Editors.lua`, `settings/Slash.lua`,
`settings/SchemaSetup.lua`, `settings/OptionsSetup.lua`, `settings/SchemaMembers.lua`). Of the two
majors that moved, **Widgets is consumed and Toast is not** (no lookup, no `ToastSetup.lua`).

Widgets members in use (`grep -rnoE '\bW\.[A-Za-z_]+' core modules settings`): `DragHandle`,
`CopyWindow`, `Dropdown`, `CloseMenu` (`modules/PreviewWindow.lua:165,184,257`), `ReorderList`, `Icon`
and the When-editor row helpers. **No `W.ContextMenu` use site**, and no `MenuUtil`/`EasyMenu` menu of
the addon's own outside `libs/`.

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: tag `testkit/framework.lua:20` = 51, `tests/_kit/framework.lua:20` = 50. Both
payloads are copied whole in one commit, so the pairing rule (v1.9.0+ takes kit 11+) holds by
construction.

## 3g. Contract delta

Majors read: Widgets only (moved and consumed). `diff` of
`docs/api/Widgets/version-22.5.12.6.7.5-docs.md` (v1.86.0) against
`docs/api/Widgets/version-23.5.12.6.7.5-docs.md` (v1.89.0): the new `submenu`, `radio`, `selected`
and `opts.check` are `W.ContextMenu` row options for a host's rows only, and "a dropdown ignores all
three" (v23 doc, *What changed*). `CloseMenu()` gains "every level of a cascade" (`**2** (every
cascading level **Since 23**)`), a widening, and still a no-op when nothing is open. `Dropdown`'s row
in the members table is unchanged. `grep -rn '__Attach[A-Za-z]*'` outside `libs/` and `_kit/` finds no
site, so no host-supplied member can have a moved call site.

## Blockers

None. Toast 4's stub obligation (`SetStack`, `Visible`, `FrameFor`) applies to a host with a Toast
stub; this addon has none. No `__releaseChrome` mirror (`grep -rn '__releaseChrome'` outside `libs/` and
`_kit/`: nothing). No README provenance line.

## 3h. Span check

Horizon `2026-10-22`. Vendored since: v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0
v1.83.0 v1.84.0 v1.85.0 v1.86.0. Recorded: the same twelve. `grep -vxF -f recorded vendored` printed
nothing, so no span bundle is written.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `45:LibKa0s icons: all (icon browser).`, the next non-blank line
after the provenance line (44). Kept as decided by the run plan (keep unless a fact forces a change):
the icon browser's Glyphs tab offers the whole catalog. No provenance split needed. Hand lists have
drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); with
`all` nothing is pruned, and the owner's in-client smoke stays the backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: nothing.
