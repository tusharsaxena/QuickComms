Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

# 01 — Delta (consolidated span)

Two LibKa0s tags this addon vendored after its v1.75.0 bundle without a bundle of their own. Both
arrived on 2026-10-23 as post-run fixes of the LibKa0s #45-#58 run, each in one plain re-vendor
commit:

| Tag | Commit here | What moved (library) |
|---|---|---|
| v1.75.1 (`39dfb98`) | `eb18b0e` Re-vendor LibKa0s v1.75.1 (SimPanel minor 3) | `SimPanel.lua` 2 -> 3: a disabled row or control still shows its tip |
| v1.75.2 (`154599c`) | `4116872` Re-vendor LibKa0s v1.75.2 (SimPanel minor 4) | `SimPanel.lua` 3 -> 4: the picker's scenario dropdown fits its label |

QuickComms does not look up `LibKa0s-Sim-1.0` (01_DELTA 3e of `2026-10-23-v1.76.0/`), so neither
tag changed anything this addon draws. Kit revision 41 throughout.

Found by the re-vendor skill's step 3h listing, run on 2026-10-23 before the v1.76.0 copy (item
QC-RV of Ka0sAddonsCommonTasks `docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`):

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)   # 2026-10-22
tag_at() { git show "$1:CLAUDE.md" 2>/dev/null |
  grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
  grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
{ git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit
  git log --since="$horizon 00:00" --format=%H -- CLAUDE.md | while read -r c; do
    [ "$(tag_at "$c")" != "$(tag_at "$c^")" ] && echo "$c"; done
} | while read -r c; do tag_at "$c"; done | sed '/^$/d' | sort -uV
# v1.75.0
# v1.75.1
# v1.75.2
for b in docs/revendor/*/; do basename "$b" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; done | sort -uV
# v1.75.0
```

Vendored and unrecorded: v1.75.1, v1.75.2.
