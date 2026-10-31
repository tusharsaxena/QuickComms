# Testing — Ka0s Quick Comms

## The green commit gate

Both MUST pass before every commit (testing-§4):

```sh
lua tests/run.lua      # the headless suite, Lua 5.1
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .   # 0 warnings / 0 errors; loads no kit, so it runs through the bounded runner (testing-§15)
```

No authored `.lua` file may pass 1500 lines (layout-§1); the kit's `test_layout_cap` reads the
census in [`ARCHITECTURE.md`](ARCHITECTURE.md). Toolchain: [`DEPENDENCIES.md`](../DEPENDENCIES.md).
The suite needs a sibling `../LibKa0s` checkout for the vendor gate's two payload cases (they SKIP
without it).

### Gate time (testing-§14)

`tests/run.lua` runs the suites sharded (`jobs = "auto"`); `lua tests/run.lua --jobs 1` runs them
serially, and `--list` is always one serial pass. Measured on 2026-10-25, 1175 cases on a WSL2 `/mnt`
checkout: serial 89.7 s wall, 32.0 s CPU (35%), and sharded across 16 workers 72.9 s wall, with the
same totals, exit code and transcript, line for line. One case is most of it: `test_vendor_sync`'s
byte check of the 5892-file vendored payload (every icon set) takes about 71 s of wall on 1.8 s of
CPU, nearly all of it one `git cat-file --batch` reading ../LibKa0s over the mount. The kit already
does the two cheaper fixes: it compiles each source file once per process (181 `loadfile` calls for
the whole run) and reads the payload's blobs in that one batched call. Without the sibling checkout
the case SKIPs and the gate is the remaining ~20 s of cases. Each automated-test run records its
suites' times as `durationMs` in its bundle's `manifest.json` (`automated-tests/<run>/`);
[`automated-tests/RESULTS.md`](automated-tests/RESULTS.md) rolls the runs up but has no duration column.

`luacheck .` lints everything authored, `tests/` included. It skips `libs/` and `tests/_kit/`
(vendored), the frozen record stores, and `docs/brainstorm/`, whose go/no-go harness is a throwaway
addon kept as history and never loaded by this one.

## The harness

`tests/run.lua` on the vendored LibKa0s kit (`tests/_kit/`, revision 42, never edited).
`tests/loader.lua` builds a fresh, isolated addon per case from the TOC's own file list and the
library files `libs/LibKa0s/LibKa0s.xml` names; `tests/wow_mock.lua` extends the kit's base mock with
what this addon reads (combat state, the client's addon list, the chat sink and the launcher's two
libraries). Phase 2 adds the secure-frame half: protected calls refused in combat are recorded in `m.blocked`, a click acts on one edge (`m.__click`), `m.sentMacros` records what a secure click sent, and `m.__setCombat` drives the visibility state drivers. A font string under a `QuickComms` root records `SetFont` and `SetShadowOffset` (`__font`, `__shadow`).

Suites reach the harness as `local T = _G.QUICKCOMMS_TEST` and build instances with the three
factories, each taking an `opts` table (`skip`, `mock`, `inCombat`) and returning `(NS, env, mock)`
(`env` and `mock` are the same table):

- `T.newAddon(opts)` — every file loaded.
- `T.bootAddon(opts)` — plus `OnInitialize` (the database, the migrations, the chat commands).
- `T.enableAddon(opts)` — plus `OnEnable` (events, settings category, launcher, the latch).

`T` also carries the kit's assertions (`test`, `assertEqual`, `assertTrue`, `assertFalse`,
`assertNil`, `assertNear`, `assertError`, …) and its secret-value simulator, `T.secret(v)` and
`T.isSecret(v)` (`tests/_kit/secrets.lua`).

`opts.skip = T.loadAddon.libFiles` loads the addon with the whole LibKa0s payload absent, which is how
every degradation stub is tested: by a real load, never by a hand-written stub (testing-§8).

Named suites the standard requires: `test_surface_parity` (testing-§8), `test_vendor_sync`
(testing-§11, delegating to the kit), `test_disabled` (slash-commands-§7). The addon's own:
`test_harness` (the load and the repository's shape), `test_bus`, `test_setup` (each adopted module's wiring),
`test_database`, `test_profile`, `test_schema`, `test_slash`, `test_diagnostics`, and phase 1's `test_compat`,
`test_restrictions`, `test_situation`, `test_tokens`, `test_channels`, `test_bake`, `test_resolver`,
`test_builtins`, `test_library` and `test_check`, and phase 2's `test_mock_secure`, `test_send_guard`,
`test_sendengine`, `test_preview`, `test_master`, `test_pad_layout`, `test_surfaces`, `test_dial_yield`,
`test_pad_render` and `test_pad`, and phase 3's `test_members`, `test_editors`, `test_callout_popup` (the callout popup, which replaced `test_page_callouts`), 
`test_groups_when`, `test_page_groups`, `test_page_groups_nesting` (split off `test_page_groups` at
the layout-§1 cap: nested groups, the Preview table, Inherit when conditions and a pad title's
right-click) and `test_page_pads`, and phase 4's
`test_dial_layout`, `test_dial_secure`, `test_dial` (with `test_dial_catcher` and `test_dial_look`, split off it at the layout-§1 band) and `test_page_dials`, and phase 5's
`test_gameids`, the icon browser's `test_icon_browser`, and the Icons tab's `test_icon_style` and `test_glow`, the edit preview's `test_edit_preview`, the preview window's `test_preview_window`, the `{coordinates}` token's `test_coordinates`, and the shine overlay's `test_shine` and `test_dial_shine`, and the key bindings' `test_keybinds` (item 015: `NS.BINDINGS` and the General page's Keybindings tab, driven with the kit's `Kit.keybindThroughTab`; `tests/run.lua` hands `Kit.expose` a `mock` view that forwards to the newest instance's mock, which the driver reads for `LibStub`), and frame layering's `test_layers` (item 030: `NS.Constants.LAYERS` and every tier it names, through the kit's opt-in frame-layer recorder `tests/_kit/mock_layers.lua`, installed before any source loads through the factory's `opts.mock`; `tests/wow_mock.lua` answers UIParent's frame level, 0, for the modal bands), and the settings layout's `test_layout` (item 020: every page's headings, labels, tab order and placement; `test_schema`'s layout guard pins every row's stored path, default, range and choices against `tests/schema_pins.lua`, so a move that changed a setting fails), and the skinning rollout's `test_skinsetup` (the seam, the owner tokens, the skin.* rows, the degraded facade), `test_skin_windows` (the windows, and the color-literal gate over the window, HUD and settings files), `test_skin_hud` (the faces, border styles, chrome and schema step 10; Ignore fonts on the HUD since LibKa0s v1.81.0), `test_skin_picker` (the first-run picker; no case pins its title, which is the library's "Choose a skin" with the addon's name on `frame.ownerLabel`), LibKa0s v1.82.0's `test_skin_outline` (the Font outline, `skin.outline`), `test_skin_verb` (`/qc skin`) and `test_skin_fonts` (From skin flags, schema step 11, the HUD size scale), QC-02's `test_icons_default` (test mode's numbered group glyphs, `NS.DefaultIcon` on pads, dials and the editor previews, and the question mark only without the library), `test_glyphs` (the display-glyph guard over the addon's own string literals, the kit's `glyphs.lua`) and `test_skin_tools` (the settings pages' painting and colored lines, panel-scoped under the default Scope, the tool windows). Kit suites, declared by directory:
`test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`, `test_lizard_sighted`.
Every new `tests/test_*.lua` is added to the `suites` list in `tests/run.lua`; the kit fails the run
in both directions.

`tests/wow_mock.lua` models the client's secure handlers: a header's `_onclick` and `RunAttribute`
snippets run in the header's own environment with protected calls allowed in combat; `WrapScript`
(raising if a hook came first), `SetFrameRef`, `Execute`, override bindings, `GetBindingAction`, the
cursor, and `__pressKey(key)`, which routes a key through a snippet's binding, then an override
binding. For the icon browser it adds the macro icon lists (`GetMacroIcons`, `GetMacroItemIcons`)
and the AceGUI Icon and Label widgets' image texture with `SetVertexColor`, which records the tint it was given.

`tests/page_helpers.lua` (not a suite) drives an editor page through the kit's AceGUI recorder: show a page, redraw it, click a tab, find a widget by its label, fire its callback, accept the last popup, and spy on the reorder lists.

`tests/dial_pick.lua` (not a suite) clicks a slice on an open dial as a mouse pick does: it puts the cursor on the slice that holds a wedge and clicks its ring's catcher, first opening the ring that leads there when the wedge sits on one not shown.

`tests/prose_waivers.lua` waives, per file and per word, the British spellings in the frozen
`docs/brainstorm/` record; nothing written after the scaffold is waived.

Write tests first for pure logic. Extend `tests/wow_mock.lua` for a new client API, never
`tests/_kit/`.

`lua tests/run.lua --list` prints the case inventory; it is committed as
[`test-cases.md`](test-cases.md), and its Total is the README's `[tests]` badge. Regenerate both in
the change that moves the count (testing-§5).

## The four suites, and which checkpoint each gates

| Suite | Command | Commit / run | Release (the tag) |
|---|---|---|---|
| `lint` | `luacheck .` | **gates** | gates |
| `tests` | `lua tests/run.lua` | **gates** | gates |
| `perf` | `lua tests/perf.lua` (offline scenarios; see [`performance.md`](performance.md)) | recorded, never fails a run or blocks a commit | gates |
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (the sighted shadow) | recorded, never fails a run or blocks a commit | gates, with zero functions above CCN 15 and `blindFiles` 0; a lizard run that crashed or hit its bound is a complexity fail, never a pass (the crashed files are listed apart, `crashedFiles` 0 at release; automated-tests-§3) |

The release gate is evaluated by `/dev-copilot:bump-version` from the run's `manifest.json`
(automated-tests-§3): a bundle whose manifest shows all four suites at `pass`, no function above
CCN 15 and `blindFiles` 0 (Task 13 of the phase 5 plan records it). It never gates a commit. The record itself: [`automated-tests/README.md`](automated-tests/README.md).
For long batteries run through the bounded runner, `~/.claude/dev-copilot/bin/ka0s-bounded`.

Measure complexity through the sighted shadow (`tests/_kit/lizard_sighted.lua`), not plain
`lizard`: lizard reads Lua blind in places and can run past a function's end. Plain
`lizard -C 15 -w modules/Pad_Layout.lua` reports `PL.VisibleSections` at CCN 16 and 140 lines, while
the shadow, which the gate uses, gives 11 over its real lines (53 to 71).

## Offline renders of the shine overlay

The mock records what the shine paints but cannot show it, and a hand-drawn preview of the recipe
once hid that the game drew something else (2026-10-21). `tools/render-shine-preview.py` renders what
the code actually paints: it runs `tools/render-shine-preview.lua`, which boots the addon through this
harness (`tests/loader.lua`, `tests/wow_mock.lua`), applies each look to the stock dial (4, 8 and 12
slices) and the stock pad, and dumps every region; then it composites the dump as the client does.
The result is `docs/superpowers/specs/2026-10-21-shine-overlay/render-*.png`. It reproduced the owner's
first in-game screenshots of the old recipes look for look, so it is the check to run after any change
to `tools/gen-shine-textures.py`, `modules/Shine.lua` or the shine half of `modules/Dial_Slices.lua`,
before SHINE-1 and SHINE-2. It is not a suite and gates nothing (`DEPENDENCIES.md` has how to run it).

## In game

[`smoke-tests.md`](smoke-tests.md) — the checks the headless suite cannot make. They are the owner's
to run; an agent never marks one passed.
