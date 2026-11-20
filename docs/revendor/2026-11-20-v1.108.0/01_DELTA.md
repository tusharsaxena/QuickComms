Delta: LibKa0s v1.107.0 -> v1.108.0

Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag object fc7714fd, commit 56c20b76). The tag is local only (`git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing), which is expected: the lead pushes it at finalize. Run as item SD-RV-QC of the cross-repo run `feat/2026-11-20-libka0s-94-97-99-100` (Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/`, plan M2). That run takes the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s` only: its adoption interview is skipped and no GitHub issue is filed here.

## Step 0 pre-flight
The newest single-tag bundle `2026-11-19-v1.107.0` states base v1.106.0; the provenance line before the commit that vendored v1.107.0 (d94c172) named v1.106.0. `ok`. No correction is owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` -> `45:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.107.0 (MIT).`
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 95cdebe (AF-RV-QC, the re-copy of the re-cut local v1.107.0); its CLAUDE.md names v1.107.0. They agree.
- `diff -rq --strip-trailing-cr <v1.107.0 extract>/LibKa0s libs/LibKa0s` lists only the pruned sounds (`media/sounds/callout`); `diff -rq <v1.107.0 extract>/testkit tests/_kit` is empty. The payload was v1.107.0's.
- Range: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` lists 15 commits.

## 3b/3c Per-file minors that moved
```
Callout.lua               MINOR 4 -> 5
CalloutSettings.lua       SETTINGS_MINOR 5 -> 6
Charts.lua                MINOR 2 -> 3
ChartsRender.lua          RENDER_MINOR 1 -> 2
Core.lua                  MINOR 18 -> 19
OptionsCompose.lua        COMPOSE_MINOR 19 -> 20
SkinPaint.lua             PAINT_MINOR 19 -> 20
SkinPaintControls.lua     CONTROLS_MINOR 18 -> 19
SkinPaintHud.lua          HUD_MINOR 1 -> 2
WaypointArrow.lua         MINOR 2 -> 3
WaypointArrowSettings.lua SETTINGS_MINOR 2 -> 3
Widgets.lua               MINOR 29 -> 30
WidgetsBar.lua            BAR_MINOR 1 -> 2
WidgetsDragHandle.lua     DRAG_MINOR 15 -> 16
WidgetsDragHandleTip.lua  DRAGTIP_MINOR 2 -> 3
WidgetsDropdown.lua       DROPDOWN_MINOR 2 -> 3
WidgetsLineChart.lua      CHART_MINOR 7 -> 8
```
`diff -rq` of the two extracts' `LibKa0s/` names only these files; no file is added or removed. No cross-major skew.

## 3d Diffs
After the copy, before the prune: `diff -rq --strip-trailing-cr <extract>/LibKa0s libs/LibKa0s` and `diff -rq --strip-trailing-cr <extract>/testkit tests/_kit` are both empty. After the prune, the only difference is `Only in <extract>/LibKa0s/media/sounds…` (no `LibKa0s sounds:` line, so none ship). The icon folder ships whole (`all`).

## 3e Consumption
Unchanged: Core, Widgets, Skin, Options (through `NS.addon.Settings.Helpers`: `O.FontGroup`, `O.ColorPair`, `O.BorderGroup` in `settings/SchemaMembers.lua`), Schema, Slash, Toast, Tooltip, Pool, Glow, IconBrowser, Media, Launcher, Lifecycle, Bus, Compat, Role, DebugLog, Env, Perf. Callout, Charts and WaypointArrow have no lookup here.

## 3f Kit
`Kit.VERSION` 57 -> 58 (`SD-LK-GUARD`): the skin-switch test checks each setter family on its own and takes `expect`, `hold` and `clear`; the skin-values scanner reads keyed, multi-assigned and returned triples and `RGBA` fallbacks, and takes a row `category`. The two payloads move together in this commit.

## 3g Blockers
- **OptionsCompose minor 20: every composed swatch emits `<key>FromSkin` unless the host opts out.** This addon's six Shine swatches (`pad.button.` and `dial.slice.` `shineTint`, `shineBloomA`, `shineBloomB`, `settings/SchemaMembers.lua` `shineRows`) gained a companion with no AceDB default, and `tests/test_schema.lua` and `tests/test_members.lua` went red (6 rows with no default; the item-020 layout guard). Every other composed block already declares its companions in `extra` (`fontSpec`, `borderSpec`, `follow = true`, the button background), which the composer honours. Fixed in this commit by passing `colorFromSkin = false` on the Shine pairs: *Use the skin's shine* already draws the skin's tint (`modules/Shine.lua` `Sh.Resolve`), and these swatches are read only while it is off (the skin-defaults audit's OK row "Shine Fluid-glass bloom colors", LibKa0s#97).
- **Kit revision 58's skin-values scanner** found 22 new hits on 16 lines. Each gets a `Kit.skinValues` row in `tests/run.lua` (the chat-color fallbacks `MC`, the gloss and orb shines' black rim `L10` under owner U-26, a new pad's stored Window swatches `D7`, the rest kit categories: `unreachable default`, `white base for tinting`, `not a color`).
- Kit revision 58's skin-switch family checks pass on every declared surface with the copy alone. The new declarations (`expect`, `hold`) are SD-SK-QC's.

## 3h Span
Nothing unrecorded: v1.107.0 has its bundle `../2026-11-19-v1.107.0/`.

## 3i Icon declaration
`LibKa0s icons: all (icon browser).` kept unchanged, the next non-blank line under the provenance line. The prune refused nothing: it kept every icon and removed 362 voice-pack sound files (`sounds none`).

## 3j Tests assuming the whole icon folder
None new.
