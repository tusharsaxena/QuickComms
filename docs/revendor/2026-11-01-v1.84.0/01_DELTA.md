Delta: LibKa0s v1.83.0 -> v1.84.0

# 01 — Delta

Vendored from the local tag `e917ccd` (not pushed: `git -C ../LibKa0s ls-remote --tags origin v1.84.0`
prints nothing), extracted with `git -C ../LibKa0s archive v1.84.0 LibKa0s testkit tools`. Item QC-RV of
Ka0sAddonsCommonTasks `docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`, step 7.

## 3a. Base

- `grep -n '[Bb]undles' CLAUDE.md`: v1.83.0.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit`: `15dde36`, whose `CLAUDE.md` names v1.83.0. The two agree.
- Newest single-tag bundle `2026-10-24-v1.77.0`, base v1.76.0: no correction owed. The span bundle
  `2026-10-31-v1.80.0-v1.83.0` covers v1.80.0 to v1.83.0.

## 3b. Actual version

`diff -rq` of the v1.83.0 extract against `libs/LibKa0s` and `tests/_kit`: empty. Line and bytes agreed.

## 3c. Per-file minors (only those that moved; every other file is unchanged)

Command: the skill's loop over the tag's `LibKa0s/LibKa0s.xml`.

| File | Old | New |
|---|---|---|
| `Schema.lua` | 2 | 3 |
| `Charts.lua` | new | 1 |
| `ChartsRender.lua` | new | 1 |
| `Skin.lua` | 10 | 11 |
| `SkinOwnerTokens.lua` | new | 1 |
| `SkinDefs.lua` | 18 | 19 |
| `SkinDefsOthers.lua` | new | 1 |
| `WidgetsDragHandle.lua` | 8 | 10 |
| `DebugLogDiagnostics.lua` | 5 | 6 |
| `Slash.lua` | 20 | 21 |
| `Options.lua` | 34 | 35 |
| `OptionsWidgets.lua` | 38 | 40 |
| `OptionsFlow.lua` | new | 2 |
| `OptionsIds.lua` | 5 | 6 |
| `OptionsIdSuggest.lua` | new | 1 |
| `OptionsTabs.lua` | 11 | 13 |
| `OptionsTabbed.lua` | new | 2 |
| `OptionsCompose.lua` | 14 | 15 |
| `OptionsSkinPicker.lua` | 4 | 5 |
| `OptionsSkinPickerRows.lua` | new | 1 |
| `SimPanel.lua` | 8 | 9 |
| `SimPanelRender.lua` | new | 1 |

No cross-major skew: both payloads were on v1.83.0 throughout.

## 3d. Both diffs

Before the copy: clean against v1.83.0. After the copy: `diff -rq`, with and without
`--strip-trailing-cr`, empty for both payloads, so the content and the bytes both match the tag.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` over the addon outside `libs/` and `tests/`:
Bus, Compat, Core, DebugLog, Env, Glow, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Skin,
Slash and Widgets. No lookup of Charts, the new major.

## 3f. Kit

`grep -n 'Kit.VERSION'`: 46 -> 47. The two payloads move together in one commit (the pairing rule).

## 3g. Contract delta

Read: the tag's `CHANGELOG.md` `## v1.84.0` block and the Options, Widgets, Schema, Slash, Skin and
DebugLog API documents of the range. `__Attach` sites in the addon: none outside the payload.

**Blockers**

- `O.PositionBlock` is a new public member, and `tests/test_surface_parity.lua` holds every stub to the
  live surface. Fixed in the re-vendor commit: `H.PositionBlock` in `settings/OptionsSetup.lua`, in the
  same shape as the other composers on a degraded load (`docs/api/Options/` Options 35 key, the Position
  block paragraph).

Reviewed, no change owed here:

- `WidgetsDragHandle` minor 10 repeats the last `ApplyWidth` on `OnShow`, out of combat. The suite stays
  green with it.
- `O.ClearScroll` keeps the band's refresher. The addon holds no copy of that behavior.
- `note` rows arrive with no path. The addon's own row walks are unaffected until it declares one, and
  it declares none.

## 3h. Unrecorded tags

The listing printed nothing: every vendored tag has a bundle. No span bundle.

## 3i. Icons

`LibKa0s icons: all (icon browser).` kept. `prune-icons: . declares all icons (icon browser); nothing removed`.

## 3j. Tests assuming the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests`: nothing outside the kit. Nothing to fix.
