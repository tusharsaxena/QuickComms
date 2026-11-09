# 02 Candidates, LibKa0s v1.93.0 -> v1.95.0

Sources: `git -C ../LibKa0s log --oneline v1.93.0..v1.95.0`; LibKa0s CHANGELOG.md, the v1.94.0 and v1.95.0 blocks; docs/api/Skin, docs/api/Compat and docs/api/Role.

**Class A, delivered on the copy alone**
- DebugLogDiagnostics minor 8: the census names Role.
- Skin minor 18's changed answer for a choice with no skin (see 01_DELTA.md 3g).

**Class B, host change required (candidates)**
- Skin `DefaultSkin()`: the profile's default skin per client (skinning-§2). **Adopted in QFE-F1.**
- Compat `CharacterKey`, `UnitCharacterName`, `RealmKey`, `RegionalNames`: the character identity on a regional-names client. Planned by the run's design §4.4, item QFE-F4.

**Class C, whole-module**
- `LibKa0s-Role-1.0`: spec and role on Retail and WoW Forever. Planned by the run's design §4.4 and §4.5, items QFE-F4 and QFE-F5.
- Majors still not looked up: LibKa0s-Charts-1.0 LibKa0s-Item-1.0 LibKa0s-Sim-1.0 LibKa0s-Toast-1.0.

**Blockers (3g)**: none.
