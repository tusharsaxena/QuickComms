# Testing — Ka0s Quick Comms

## The green commit gate

Both MUST pass before every commit (testing-§4):

```sh
lua tests/run.lua      # the headless suite, Lua 5.1
luacheck .             # 0 warnings / 0 errors
```

No authored `.lua` file may pass 1500 lines (layout-§1); the kit's `test_layout_cap` reads the
census in [`ARCHITECTURE.md`](ARCHITECTURE.md). Toolchain: [`DEPENDENCIES.md`](../DEPENDENCIES.md).
The suite needs a sibling `../LibKa0s` checkout for the vendor gate's two payload cases (they SKIP
without it).

`luacheck .` lints everything authored, `tests/` included. It skips `libs/` and `tests/_kit/`
(vendored), the frozen record stores, and `docs/brainstorm/`, whose go/no-go harness is a throwaway
addon kept as history and never loaded by this one.

## The harness

`tests/run.lua` on the vendored LibKa0s kit (`tests/_kit/`, revision 39, never edited).
`tests/loader.lua` builds a fresh, isolated addon per case from the TOC's own file list and the
library files `libs/LibKa0s/LibKa0s.xml` names; `tests/wow_mock.lua` extends the kit's base mock with
what this addon reads (combat state, the client's addon list, the chat sink and the launcher's two
libraries). Phase 2 adds the secure-frame half: protected calls refused in combat are recorded in `m.blocked`, a click acts on one edge (`m.__click`), `m.sentMacros` records what a secure click sent, and `m.__setCombat` drives the visibility state drivers. `tests/loader.lua` also loads `libs/LibDeflate` and `libs/LibSerialize` through their `lib.xml`, as the TOC does. A font string under a `QuickComms` root records `SetFont` and `SetShadowOffset` (`__font`, `__shadow`).

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
`test_pad_render` and `test_pad`, and phase 3's `test_members`, `test_editors`, `test_callout_popup` (the callout popup, which replaced `test_page_callouts`), `test_eui_skin` (its optional EllesmereUI skin, on a mocked EllesmereUI),
`test_groups_when`, `test_page_groups`, `test_page_pads` and `test_page_share`, and phase 4's
`test_dial_layout`, `test_dial_secure`, `test_dial` and `test_page_dials`, and phase 5's `test_share`
and `test_gameids`, the icon browser's `test_icon_browser`, and the Icons tab's `test_icon_style` and `test_glow`. Kit suites, declared by directory:
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
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (the sighted shadow) | recorded, never fails a run or blocks a commit | gates, with zero functions above CCN 15 and `blindFiles` 0 |

The release gate is evaluated by `/dev-copilot:bump-version` from the run's `manifest.json`
(automated-tests-§3): a bundle whose manifest shows all four suites at `pass`, no function above
CCN 15 and `blindFiles` 0 (Task 13 of the phase 5 plan records it). It never gates a commit. The record itself: [`automated-tests/README.md`](automated-tests/README.md).
For long batteries run through the bounded runner, `~/.claude/dev-copilot/bin/ka0s-bounded`.

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
