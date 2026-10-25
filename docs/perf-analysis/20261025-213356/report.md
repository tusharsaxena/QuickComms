# Report — 20261025-213356

The client's output, copied from the debug-log window, as printed. The player's note with the paste:
"New run after pressing a bunch of buttons on pad and dial in Arm A".

## The report

```
21:33:56 | [Perf] capture: 2026-10-25 21:30  (QuickComms, schema 2, v0.1.0)
21:33:56 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
21:33:56 | [Perf] where:     Murder Row
21:33:56 | [Perf] group:     party (5) / party
21:33:56 | [Perf] active:       56.3s    3456 frames    61.4 fps   16.29 ms/frame
21:33:56 | [Perf] suspended:    59.9s    3819 frames    63.8 fps   15.68 ms/frame
21:33:56 | [Perf] delta:                                                   +0.61 ms/frame
21:33:56 | [Perf] 
21:33:56 | [Perf] bucket            calls   total ms       ms/s    max ms
21:33:56 | [Perf] sendClick             6       0.63      0.011     0.130
21:33:56 | [Perf] echoMatch             6       0.34      0.006     0.067
21:33:56 | [Perf] dialRender          223       5.96      0.106     0.227
```

No `(buckets nest: … — do not sum)` footer follows the table. The library prints one only when a
recorded bucket nests, and none of the three that fired declares a parent.

## The run log

```
21:30:20 | [Perf] run started — 2026-10-25 21:30
21:30:20 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
21:30:20 | [Perf] where:     Murder Row
21:30:20 | [Perf] group:     party (5) / party
21:30:20 | [Perf] perf run STARTED — 2026-10-25 21:30
21:30:21 | [Perf] experiment A armed (addon active) — waiting for combat
21:30:34 | [Perf] Experiment A RECORDING — combat started
21:31:31 | [Perf] Experiment A ENDED — 56.3s, 3456 frames, 61.4 fps
21:32:46 | [Perf] addon SUSPENDED — inert
21:32:46 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
21:32:53 | [Perf] Experiment B RECORDING — combat started
21:33:53 | [Perf] Experiment B ENDED — 59.9s, 3819 frames, 63.8 fps
21:33:55 | [Perf] run finished — A 56.3s / 3456 frames, B 59.9s / 3819 frames
21:33:55 | [Perf] addon RESUMED — events and frames restored
21:33:55 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```

## The dump

The one JSON line is [`dump.json`](dump.json), byte for byte.
