Delta: LibKa0s v1.75.2 -> v1.76.0

# 01 — Delta

Re-vendor of LibKa0s into QuickComms, run 2026-10-23 as item QC-RV of the cross-repo run "sim
auto-run, QC preview selector, mode strips, MM/KCD simulators" (Ka0sAddonsCommonTasks
`docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`). The procedure is the installed dev-copilot 2.4.0
`/dev-copilot:wow-revendor-libka0s`, run without its interview: the run's `inputs/OWNER_SCOPE.md`
pre-decides every adoption, and M2 files no GitHub issues.

The new tag is a LOCAL tag on the run branch (not pushed at the time of this record):

```sh
git -C ../LibKa0s rev-parse v1.76.0              # 546e284d6542689989c2d5c152f3b5ed9ef0ade2 (tag object)
git -C ../LibKa0s rev-parse 'v1.76.0^{commit}'   # 9949368df8db12e51c9c51e403738989c87709a5
git -C ../LibKa0s rev-parse 'v1.75.2^{commit}'   # 154599c15327bd2e0aa9c3e6b10fcdaa1ce29401
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools | tar -x -C <scratch>
```

## Step 0. Pre-flight

The newest single-tag bundle, `2026-10-22-v1.75.0`, states base v1.74.0; the provenance line before
its re-vendor commit `06276e7` named v1.74.0. **ok**, no correction.

## 3a. Claimed version (the base)

```sh
grep -n '[Bb]undles' CLAUDE.md
# 42:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2 (MIT).
git log -1 --format=%h -- libs/LibKa0s tests/_kit
# 4116872  "Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)", whose CLAUDE.md names v1.75.2
git -C ../LibKa0s archive v1.75.2 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s && diff -rq <scratch>/claimed/testkit tests/_kit && echo payload-matches
# payload-matches
```

The base is **v1.75.2**.

```sh
git -C ../LibKa0s log --oneline v1.75.2..v1.76.0
# 9949368 LK-90: address review — name tests/test_sim_panel.lua in the CLAUDE.md 1000-1500 band
# 82d76f6 LK-90: close v1.76.0 with its release record (20261023-150627)
# f9ce82a LK-90 (1/2): release v1.76.0: version block, pointers, consumers
# 37e6b69 LK-25: add the preview and simulation re-look to the release checklist
# d5fa6e9 LK-10: give W.TestStrip a simulation flavor (Widgets minor 14)
# d728cc4 LK-01: play a simulation on its own and drop Run all (Sim 2.3.5)
# 05cb400 LK-00: open v1.76.0 with an unreleased CHANGELOG block
```

## 3b. Actual version

The minors under `libs/LibKa0s/` before the copy were exactly v1.75.2's (the `payload-matches` above).

## 3c. Per-file minor delta

The 3c loop over the tag's `LibKa0s/LibKa0s.xml`, filtered to files whose constant moved:

| File | v1.75.2 | v1.76.0 |
|---|---|---|
| `Widgets.lua` | `MINOR = 13` | `MINOR = 14` |
| `SimTimeline.lua` | `TIMELINE_MINOR = 2` | `TIMELINE_MINOR = 3` |
| `SimPanel.lua` | `SIM_PANEL_MINOR = 4` | `SIM_PANEL_MINOR = 5` |

Every other file is at its v1.75.2 minor. No file is new, none is removed. No cross-major skew.

## 3d. Both diffs

Before the copy, `diff -rq <scratch>/LibKa0s libs/LibKa0s` named exactly `SimPanel.lua`,
`SimTimeline.lua` and `Widgets.lua`; `diff -rq <scratch>/testkit tests/_kit` was empty. After
`cp -r`, all four diffs (with and without `--strip-trailing-cr`, both payloads) were empty, before
the prune. No `Only in libs/LibKa0s` line: nothing to delete.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Glow, Env, Media, Compat, Launcher, Lifecycle, Core, Bus, DebugLog, Perf, Widgets, Pool
(`core/*Setup.lua`, `core/Bus.lua`, `core/Compat.lua`), Widgets again in `settings/Editors.lua:407`,
Options (`settings/OptionsSetup.lua`), Schema (`settings/SchemaSetup.lua`), Slash
(`settings/Slash.lua`). Of the moved majors, **Widgets** is consumed and **Sim** is not.

## 3f. Kit revision

`Kit.VERSION = 41` in both the tag's `testkit/framework.lua` and `tests/_kit/framework.lua`:
unchanged. The two payloads still move together (the pairing rule), so `tests/_kit/` was re-copied
whole; it was already byte-identical.

## 3g. Contract delta

Read for the consumed moved major only, Widgets 13 -> 14:

```sh
diff <(git -C ../LibKa0s show v1.75.2:docs/api/Widgets/version-13.1.4.3.2-docs.md) \
     <(git -C ../LibKa0s show v1.76.0:docs/api/Widgets/version-14.1.4.3.2-docs.md)
```

The only additions are `opts.kind` and `strip.kind` on `W.TestStrip` (both **Since 14**,
`docs/api/Widgets/version-14.1.4.3.2-docs.md:27` and `:33`); "every existing call draws exactly what it
drew at 13", and `members-14.1.4.3.2.json` lists the same names as 13. QuickComms never calls
`TestStrip`. No `__Attach*` member this addon supplies moved. CHANGELOG v1.76.0, *What a consumer
owes*: no code; re-true suites that drove Sim (none here); reword docs naming Run all (none here,
`grep -rn 'RUN_ALL\|Run all\|sim run'` over the authored tree is empty).

**Blockers: none.**

## 3h. Span bundle

v1.75.1 and v1.75.2 were vendored (`eb18b0e`, `4116872`) and never recorded; written as
`docs/revendor/2026-10-23-v1.75.1-v1.75.2/`.

## 3i. The icon declaration

`CLAUDE.md:43` `LibKa0s icons: all (icon browser).`, directly under the provenance line at
`CLAUDE.md:42`. Kept. The tag's prune: `prune-icons: . declares all icons (icon browser); nothing
removed`. The owner's in-client smoke stays the backstop for any icon the gate cannot see.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: no hit.

## Dead stub mirrors

`grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: no hit (removed
at v1.75.0).
