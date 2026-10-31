# 05 — Summary (LibKa0s v1.83.0 -> v1.84.0)

- Base v1.83.0 from the provenance line, new v1.84.0 (local tag `e917ccd`), kit 46 -> 47. Minors: `01_DELTA.md` 3c.
- No span bundle and no base correction.
- For free: the pad strip's fit on show and at its own scale, the library peels and the Charts line in
  the diagnostics header.
- Blocker: the `H.PositionBlock` stub, fixed in the re-vendor commit.
- Icons: `all (icon browser).` kept, nothing pruned. No provenance split, no README credit change and no
  dead stub mirror.
- Adopted: `O.PositionBlock` with `opts.afterSubgroup` (`QC-ADOPT`), `shownWhen` (`QC-67`).
- Declined, no issue filed, per the item spec: the `note` row, `PageBanner{ acts }`, `opts.beforeGroup` and
  the Charts major.
- Gate at the re-vendor: `lua tests/run.lua` 1298 passed, 0 failed, 1 skipped; `luacheck` 0/0 in 151 files.
