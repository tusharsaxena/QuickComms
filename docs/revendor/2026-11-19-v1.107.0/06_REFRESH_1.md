# 06 — Refresh 1: the local v1.107.0 tag moved before it was pushed

Written 2026-11-19 by AF-RV-QC. The tag is still local (`git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing), and it was re-cut on the library's run branch after this addon's first copy, so this is a refresh, not a new re-vendor. Line 1 of `01_DELTA.md` stands.

- Before: `git -C ../LibKa0s rev-parse v1.107.0^{commit}` = 5e963659 (tag object 427e108d).
- After: 87ae35f3 (tag object 00b52b13). The one commit between them: `87ae35f3 AF-LK-03 + #95: The HUD dock reads a secret edge, height or level as none (Widgets minor 29), folded into the unpushed v1.107.0`.

## Per-file minor delta between the two commits

```
Widgets.lua  MINOR 28 -> 29
```

`diff -rq` of the two extracts names `LibKa0s/Widgets.lua` alone; the testkit is identical (Kit.VERSION 57). The HUD dock is not consumed here (this addon docks no HUD display), so the change reaches it as bytes only.

## Copy and gate

Re-copied both payloads whole from the new extract, re-ran the tag's `tools/prune-icons.lua` (every icon kept under `all`, 362 sound files removed), and both content diffs are empty. The consumer's `tests/test_vendor_sync.lua` was the witness: it failed on `Widgets.lua` against the moved tag before the re-copy and passes after it.

Gate after the re-copy, on the branch head with AF-STRIP-QC committed: Retail and Forever each 2085 passed, 0 failed, 1 skipped (2086, 16 shards); `ka0s-bounded luacheck .` 0 warnings / 0 errors in 185 files.
