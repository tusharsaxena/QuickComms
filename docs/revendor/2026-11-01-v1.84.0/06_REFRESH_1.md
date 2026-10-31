# Refresh 1: local tag v1.84.0 moved again (QuickComms)

The tag moved before it was pushed (`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing),
for the owner's ruling of 2026-11-01 that `lib.__PatchLSM30Border` is deleted with no stub. Item `M4-RV`
of the 2026-10-31 findings remediation.

- Old: `7a8bc0f`, vendored by `190fa85` and recorded in `2026-11-01-v1.84.0-recut/`.
- New: `git -C ../LibKa0s rev-parse 'v1.84.0^{commit}'` gives `b5229b876e803768322fb4d8c66be69f01c8e4a1`.

## Per-file minors

The skill's 3c loop, run against each commit. Only these moved:

| File | Old | New |
|---|---|---|
| `Options.lua` | 36 | 37 (`lib.__PatchLSM30Border` deleted) |
| `OptionsDrawer.lua` | 3 | 4 (comment only) |
| `OptionsMedia.lua` | 2 | 3 (comment only) |

`git -C ../LibKa0s diff --stat 7a8bc0f v1.84.0 -- LibKa0s testkit tools`: those three files, 11 insertions
and 17 deletions. No kit file moved: `Kit.VERSION` stays 47.

## Host calls

`git grep -n '__Patch\|PatchLSM' -- '*.lua' ':!libs' ':!tests/_kit'` finds nothing. This addon never
called the member, so no call, test, stub or pinned minor moved here.

## Diffs and icons

`diff -r` and `diff -r --strip-trailing-cr` of the tag's `LibKa0s/` against `libs/LibKa0s` and of its
`testkit/` against `tests/_kit`: empty after the copy. `LibKa0s icons: all (icon browser).` kept; the
prune removed nothing.

## Gate

`lua tests/run.lua`: 1303 passed, 0 failed, 1 skipped. `luacheck .`: 0 warnings, 0 errors in 151 files.
