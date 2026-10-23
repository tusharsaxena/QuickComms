# 02 — Candidates (LibKa0s v1.75.2 -> v1.76.0)

Sources: `git -C ../LibKa0s log --oneline v1.75.2..v1.76.0`, the tag's `CHANGELOG.md` `## v1.76.0`
block (line 13 on), and `docs/api/Widgets/version-14.1.4.3.2-docs.md` and
`docs/api/Sim/version-2.3.5-docs.md`. The run's `inputs/OWNER_SCOPE.md` pre-decides each one; nothing
here was put to an interview.

## Class A — delivered on the copy, no host change

- **Widgets 14** re-pairs the four attach files on the shell's new minor; every Widgets surface this
  addon calls draws what it drew at 13.
- **`docs/releasing.md`'s preview and simulation re-look** is the library's own release step; it
  asks nothing of a consumer's code.

## Class B / C — candidates

| Candidate | Class | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| `W.TestStrip(parent, { kind = "sim" })`, `strip.kind` (Widgets 14) | B | CHANGELOG v1.76.0, *Widgets minor 14*; `docs/api/Widgets/version-14.1.4.3.2-docs.md:27`, `:33` | none | Not adopted: OWNER_SCOPE A and C name the strip's adopters (BankLedger, DropWatcher, LootHistory, MultiMeters, KickCD) and say QuickComms has no test-mode strip and keeps its header word | n/a |
| `LibKa0s-Sim-1.0` auto-run (SimTimeline 3, SimPanel 5) | C (unconsumed major) | CHANGELOG v1.76.0, *SimTimeline minor 3 and SimPanel minor 5*; `docs/api/Sim/version-2.3.5-docs.md` | none | Not adopted: settled at v1.75.0 (`2026-10-22-v1.75.0/03_DECISIONS.md`), QuickComms has no simulator; v1.76.0 changes no premise of that | n/a |
