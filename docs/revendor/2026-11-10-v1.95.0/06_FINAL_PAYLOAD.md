# 06 Final payload (QFE-REV)

Added after QFE-F1; 01 to 05 are left as recorded.

- After QFE-F1, LibKa0s took one more commit on the run branch before the release is cut: ad603eb, "QFE-LK2: Split lib.New and the kit scanner so no function is over CCN 15". It changes no behaviour.
- The payload was copied whole again from the library branch head, not from the local tag: `git -C ../LibKa0s archive ad603eb LibKa0s testkit`, then `libs/LibKa0s/` and `tests/_kit/` were replaced with it. `diff -r` of both payloads against that extract prints nothing.
- Three files moved: `Launcher.lua` (Launcher minor 9 -> 10, `lib.New`'s descriptor checks moved into a local helper, errors still name the host's line), `testkit/framework.lua` (kit revision 53 -> 54) and `testkit/client_globals.lua` (the scanner split into helpers, same findings).
- The final v1.95.0 payload therefore carries **Launcher minor 10** and **kit revision 54**. No signature or answer this addon reads changed. It reaches Launcher only through `core/LauncherSetup.lua`, and its descriptor passes the same checks.
- The CLAUDE.md provenance line already names v1.95.0, so it does not move. The `LibKa0s icons: all` declaration stays as it is, and nothing is pruned.
- Until the lead re-cuts the v1.95.0 tag on ad603eb or a later commit, `tests/test_vendor_sync.lua` reports two failures, one for each payload, because it diffs against the stale local tag e4493aa. Every other case is green.
