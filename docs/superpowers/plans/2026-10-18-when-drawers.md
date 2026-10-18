# When drawers, Inherit when conditions, icon search: implementation plan

**Goal:** the When tab as condition drawers (a new LibKa0s Drawer widget), an "Inherit when
conditions" group setting, and search in the icon browser.

**Spec:** `docs/superpowers/specs/2026-10-18-when-drawers-design.md` (read it first; record every
builder call there, tagged with the task id).

**Worktrees and branches** (never touch the main checkouts; never push, merge, tag or release):

- LibKa0s: `/mnt/d/Profile/Users/Tushar/Documents/GIT/#Worktrees/LibKa0s`, branch `feat/drawer-widget`.
- Quick Comms: `/mnt/d/Profile/Users/Tushar/Documents/GIT/#Worktrees/QuickComms-when`, branch
  `feat/when-drawers`. Its vendor gate (`tests/test_vendor_sync.lua`) compares `libs/LibKa0s/` with
  the sibling `../LibKa0s`, which from this worktree is the LibKa0s worktree above.

**Gate** (each repo, before every commit), heavy runs prefixed with
`/home/tushar/.claude/dev-copilot/bin/ka0s-bounded`: `lua tests/run.lua` and `luacheck .` (0/0);
regenerate `docs/test-cases.md` from `lua tests/run.lua --list` (CRLF) and, in Quick Comms, the
README badge `Tests-N%2FN` = its Total. Every authored file stays CRLF. Write a failing test
before each change (mutation-check: the test fails without the fix).

## Ledger

| Task | What | Status | Commit |
|---|---|---|---|
| L1 | LibKa0s: Drawer widget (AceGUI container + Options helper), tests, minor bumps, majors.lua if needed, CHANGELOG block (next version after v1.72.0), docs/api document, the library-stack-§7 deviation row in CLAUDE.md | todo | |
| Q1 | Quick Comms: re-vendor LibKa0s from the LibKa0s worktree (libs/LibKa0s, tests/_kit if the kit moved), version mentions (CLAUDE.md, README, DEPENDENCIES.md, docs/module-map.md, docs/revendor record as the repo's convention does), gate green | todo | |
| Q2 | When tab as drawers (settings/Groups_When.lua): header + summary + drawer per condition, Select all / Clear (Any), no enable checkbox, open state per group per session, the explanatory line; tests in tests/test_groups_when.lua / test_page_groups.lua | todo | |
| Q3 | Inherit when conditions: `group.inheritWhen` member row (default on when absent), General tab checkbox beside Parent group (greyed with no parent), Resolver uses the parent's When, read-only When tab for an inheriting group, Share carries the field; tests | todo | |
| Q4 | Icon browser search (settings/IconBrowser*.lua): search box + count, per-tab matching, Game icons hint row + copy-box button; tests | todo | |
| Q5 | Docs: settings-panel.md, schema.md, ARCHITECTURE.md (LibKa0s version, any deviation), smoke-tests.md (rewrite the When steps; new steps for inherit and search), test-cases.md, README | todo | |

Order: L1, Q1, Q2, Q3, Q4, Q5. Mark each row done with its commit in a separate ledger commit.
