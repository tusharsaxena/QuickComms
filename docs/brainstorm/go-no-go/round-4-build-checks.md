# Round 4: build-time checks C1–C9 (2026-10-13)

The owner skipped the in-game build-time checks on 2026-10-13 and will test with real messages later. The spike harness was deleted. The owner ran one check anyway, in the open world: the whisper part of C2. The checks are defined in [`../04-brainstorm.md`](../04-brainstorm.md) §11, plus C8 and C9 from the spec's §19.

| Check | Context | Result | Raw output |
|---|---|---|---|
| C1 /raid + /rw | | Skipped by the owner | |
| C2 say/yell/whisper | Open world, `W%t` button (`/w %t QC spike whisper to target`) | Whisper part: FAIL (owner, open world): `No player named '%t' is currently playing.` — `/s %t` works. Say and yell lockdown part: skipped by the owner | `No player named '%t' is currently playing.` |
| C3 battleground + arena | | Skipped by the owner | |
| C4 rebake between pulls | | Skipped by the owner | |
| C5 guard snippet | | Skipped by the owner | |
| C6 echo sender readable | | Skipped by the owner | |
| C7 secure dial | | Skipped by the owner | |
| C8 pad tabs in combat | | Skipped by the owner | |
| C9 %f | | Skipped by the owner | |

## Battleground instance IDs seen

None were captured. The IDs in `defaults/BuiltIns_Battlegrounds.lua` remain unconfirmed (phase 5 still confirms them).

| Battleground | instanceID |
|---|---|

## Consequences for the spec

Each fallback below is now the plan of record in `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`. The primary design stays where noted, and the owner tests it with real messages later.

- **Whispers dropped (C2, whisper part).** `%t` expands only in message text, never in the `/w` recipient slot. `whisperTarget` and `whisperFocus` leave v0.1.0 (code and spec §8.2, §8.4), reversing P5. Re-evaluation: [issue #7](https://github.com/tusharsaxena/QuickComms/issues/7). `%t` and `%f` in message text still work on every channel.
- **C1 and C3 (`/raid`, `/rw`, battleground `/i`, arena `/p` on a boss).** Primary design kept, unverified. If a real message fails, lock that channel during encounters (§8.4).
- **C4 (rebake between pulls).** Primary design kept, unverified. If it fails, bake once at key start (§8.2).
- **C5 (guard snippet).** Fallback adopted: no hard guard in combat; dimming plus drop notes (§9.2). The restricted-snippet guard is an upgrade to try once verified.
- **C6 (echo sender).** The echo tracker tolerates an unreadable sender, treating it as unknown and never as dropped (§9.3).
- **C7 (secure dial).** Fallback adopted: Relaxed mode only in v0.1.0 (§11.2). The hold-flick-release dial is an upgrade once verified.
- **C8 (pad tabs in combat).** Fallback adopted: tab switching is refused in combat with a one-line tooltip, and sections are the default (§10.2).
- **C9 (`%f`).** Primary design kept, unverified. If it fails, remove the `{focus}` chip (§8.1).
