Delta: LibKa0s v1.83.0 -> v1.84.0

This is a re-cut, not a new release. The local tag v1.84.0 moved from `e917ccd` to `7a8bc0f` before it
was pushed (`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing), for the owner's ruling
of 2026-11-01 that `Ka0sMedia_*` is the only media picker. Line 1 keeps the tag-level delta, so the
pre-flight base check and the audit's re-vendor check still read the v1.84.0 re-vendor correctly. The
real delta of this folder is commit to commit, `e917ccd..7a8bc0f`.

Run by item `M3-RV` of the 2026-10-31 findings remediation. `2026-11-01-v1.84.0/` is frozen, so this
record sits in its own suffixed folder.

Base: `grep -n '[Bb]undles' CLAUDE.md` gives v1.84.0, and `dd97051` vendored the tag's first cut.

## Per-file minors

Command: the skill's 3c loop over `LibKa0s/LibKa0s.xml`. Only these moved:

| File | Old | New |
|---|---|---|
| `Options.lua` | 35 | 36 |
| `OptionsWidgets.lua` | 40 | 41 |
| `OptionsCompose.lua` | 15 | 16 |
| `OptionsScroll.lua` | 9 | 10 (comments only) |
| `OptionsMedia.lua` | 1 | 2 |
| `SkinAce.lua` | 5 | 6 (comments only) |

`git -C ../LibKa0s diff --stat e917ccd v1.84.0 -- LibKa0s testkit tools`: those six files, 67 insertions
and 109 deletions. No kit file moved: `Kit.VERSION` stays 47.

## Diffs

`diff -r` and `diff -r --strip-trailing-cr` of the tag's `LibKa0s/` against `libs/LibKa0s` and of its
`testkit/` against `tests/_kit`: empty after the copy, both ways.

## Blockers

None. This addon never called `lib.__PatchLSM30Border` (`git grep PatchLSM30` outside the payloads finds
nothing), and no authored code or test names `LSM30_*`: the pad's Font and Border rows come from the
composers, which now write `Ka0sMedia_*`. `H.LSMValues` in `settings/OptionsSetup.lua` is the
library-absent stub and keeps its deferred shape.

## Icons

`LibKa0s icons: all (icon browser).` kept. `tools/prune-icons.lua` removed nothing.
