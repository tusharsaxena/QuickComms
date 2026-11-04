Delta: LibKa0s v1.85.0 -> v1.86.0

Base: `grep -n '[Bb]undles' CLAUDE.md` gave v1.85.0 before the copy (`2026-11-01-v1.85.0-recut/`). The
copy is `git -C ../LibKa0s archive v1.86.0 LibKa0s testkit` (tag `v1.86.0` = `cad1609`), never a working
tree. Both payloads were replaced whole, then both `diff -r` pairs ran before the prune: content and
bytes empty for `libs/LibKa0s/` and for `tests/_kit/`. `lua tools/prune-icons.lua` from a worktree at
the tag answered "declares all icons (icon browser); nothing removed".

## Per-file minors

| File | Old | New |
|---|---|---|
| `IconBrowserSources.lua` | absent | 1 (the new major's shell, `LibKa0s-IconBrowser-1.0`) |
| `IconBrowserWindow.lua` | absent | 1 (paired on the shell's minor) |
| `IconBrowser.lua` | absent | 1 (paired on the shell's minor) |
| `DebugLogDiagnostics.lua` | 6 | 7 (names IconBrowser on the report's `LibKa0s running:` line) |
| `LibKa0s.xml` | | loads the three new files after the Options group |

Kit revision 50 -> 50: `testkit/` did not move at this tag, and `tests/_kit/` is byte-identical.

## Majors this addon consumes

Sixteen, one more than at v1.85.0: `LibKa0s-IconBrowser-1.0`, promoted out of this addon (OutfitterReborn
`docs/superpowers/plans/2026-11-04-sheet-window-feedback.md`, M1 and Task 2.1). No other major moved a
minor, so no other call site changed, and no contract moved under an unchanged signature.

## Blockers

- None for the copy: v1.86.0 adds no Skin facade member (the browser lays its four `ib.*` owner
  tokens onto the owner itself, LibKa0s `docs/releasing.md` step 8), and the parity case stayed green.
- Adopting the major retired this addon's own copy in the same branch (`05_SUMMARY.md`).

## Icons

`LibKa0s icons: all (icon browser).` stays: the browser's Glyphs tab offers the whole catalog, and its
library-drawn marks (`search`, `close`) are inside `all`. Nothing pruned, no credit moves.
