# Final payload: the re-cut v1.95.0 tag

Re-vendored from LibKa0s `v1.95.0`, re-cut locally at `9645d18` after the review. One shipped file moved:
`libs/LibKa0s/Role.lua` (Role minor 1, unreleased, so no bump): `Resolve` no longer writes an override to
`store.last`, so clearing an override cannot come back as the saved role (review finding 2, the lead's call).
The kit is unchanged at revision 54. Both vendor-sync cases now pass against the tag on both kit profiles
(1768 passed, 0 failed, 1 skipped).
