# Perf analysis — Ka0s Quick Comms

The store for **in-game** performance captures (performance-§8). An interpretation without its
record is an assertion, so every capture this repo cites lands here as a frozen bundle. What the
harness measures and why is on [performance.md](../performance.md).

## Bundle naming

`docs/perf-analysis/<YYYYMMDD-HHMMSS>/`, in local time, taken from the record's own timestamp
rather than from when the bundle was written.

## The three artifacts

| File | What it is |
|---|---|
| `report.md` | The text report the client printed after `/qc perf finish`, and the run's lifecycle lines |
| `dump.json` | The JSON dump, byte for byte as copied out of the client |
| `ANALYSIS.md` | The write-up, per the standards repo's `PERF_ANALYSIS.md` playbook |

Bundles are never edited and never pruned.

## Record schema

The record is LibKa0s-Perf's, not this addon's: `lib.SCHEMA` in `libs/LibKa0s/Perf.lua`, documented
field by field in the library's `docs/api/Perf/`. The buckets are declared in `core/PerfSetup.lua`.

## How to capture

1. `/qc perf` opens the step panel.
2. Run Experiment A, then Experiment B, then finish.
3. Copy the report and the dump.
4. Run `/dev-copilot:wow-perf-analysis` with both; it writes the bundle here.

Offline runs (`lua tests/perf.lua`) are not captures. They are recorded with the automated-test
battery in [`automated-tests/`](../automated-tests/RESULTS.md).

## Captures

| Stamp | Addon version | Label | What it measured | Bundle |
|---|---|---|---|---|
| `20261025-212400` | 0.1.0 | `2026-10-25 21:19` | The first capture, in Murder Row with a party of five. No bucket fired, because nothing was pressed and no dial was opened; the +1.45 ms/frame delta is between two different fights and is not attributable to the addon. | [`20261025-212400/`](20261025-212400/ANALYSIS.md) |
| `20261025-213356` | 0.1.0 | `2026-10-25 21:30` | Pad and dial presses in arm A: six sends, six echoes and 3.6 s of the open dial cost 0.123 ms per second of combat in all (dialRender 0.106 ms/s); the +0.61 ms/frame delta is barely above the floor, and the buckets are about 0.3% of it. | [`20261025-213356/`](20261025-213356/ANALYSIS.md) |
