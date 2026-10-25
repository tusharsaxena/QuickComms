# Report — 20261025-212400

The client's output, copied from the debug-log window, as printed.

## The report

```
21:24:00 | [Perf] capture: 2026-10-25 21:19  (QuickComms, schema 2, v0.1.0)
21:24:00 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
21:24:00 | [Perf] where:     Murder Row
21:24:00 | [Perf] group:     party (5) / party
21:24:00 | [Perf] active:       57.7s    3364 frames    58.3 fps   17.16 ms/frame
21:24:00 | [Perf] suspended:    66.1s    4206 frames    63.7 fps   15.71 ms/frame
21:24:00 | [Perf] delta:                                                   +1.45 ms/frame
21:24:00 | [Perf] 
21:24:00 | [Perf] bucket            calls   total ms       ms/s    max ms
```

The bucket table has a header and no rows: no bucket recorded a call. The `(buckets nest: … — do not
sum)` footer is printed only when a nested bucket recorded something, so its absence here goes with
the empty table rather than a cut paste.

## The run log

```
21:19:26 | [Perf] run started — 2026-10-25 21:19
21:19:26 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
21:19:26 | [Perf] where:     Murder Row
21:19:26 | [Perf] group:     party (5) / party
21:19:26 | [Perf] perf run STARTED — 2026-10-25 21:19
21:19:26 | [Perf] experiment A armed (addon active) — waiting for combat
21:19:36 | [Perf] Experiment A RECORDING — combat started
21:20:34 | [Perf] Experiment A ENDED — 57.7s, 3364 frames, 58.3 fps
21:22:36 | [Perf] addon SUSPENDED — inert
21:22:36 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
21:22:48 | [Perf] Experiment B RECORDING — combat started
21:23:54 | [Perf] Experiment B ENDED — 66.1s, 4206 frames, 63.7 fps
21:23:59 | [Perf] run finished — A 57.7s / 3364 frames, B 66.1s / 4206 frames
21:23:59 | [Perf] addon RESUMED — events and frames restored
21:23:59 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```

## The dump

The one JSON line is [`dump.json`](dump.json), byte for byte.
