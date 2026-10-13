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

`tests/run.lua` on the vendored LibKa0s kit (`tests/_kit/`, revision 38, never edited).
`tests/loader.lua` builds a fresh, isolated addon per case from the TOC's own file list and the
library files `libs/LibKa0s/LibKa0s.xml` names; `tests/wow_mock.lua` extends the kit's base mock with
what this addon reads (combat state, the client's addon list, the chat sink and the launcher's two
libraries).

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
`test_harness` (the load and the repository's shape), `test_setup` (each adopted module's wiring),
`test_database`, `test_schema`, `test_slash`, `test_diagnostics`. Kit suites, declared by directory:
`test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`, `test_lizard_sighted`.
Every new `tests/test_*.lua` is added to the `suites` list in `tests/run.lua`; the kit fails the run
in both directions.

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
(automated-tests-§3). The record itself: [`automated-tests/README.md`](automated-tests/README.md).
For long batteries run through the bounded runner, `~/.claude/dev-copilot/bin/ka0s-bounded`.

## In game

[`smoke-tests.md`](smoke-tests.md) — the checks the headless suite cannot make. They are the owner's
to run; an agent never marks one passed.
