# Summary (QuickComms)

Local tag v1.85.0 re-cut, `9776130` -> `2ad1a50`, kit 49 -> 50, by hand in `FS-QC-GATE`. Minors are in `01_DELTA.md`. `libs/LibKa0s/` and `tests/_kit/` are exact copies, and the icon declaration is `all`, so nothing is pruned.

- **Adopted:** the kit's typed-value check and probe-skin switch test (`tests/skin_surfaces.lua`), `S.BarBorder`, `S.HoverArt`, `shadowToken`, `opts.widget` on `S.Mark`, the degraded follow rule, and the rule stamp that keeps a row's own `validate`. `NS.SkinUntrack` is gone.
- **Three things that moved with no call changed:** a pad block's border under a skin's None now draws the stored style and thickness; a real style wins under High Contrast, Azeroth, WoW Default and WoW Midnight; the veils take each skin's `cover.dim` color.
- **No step owed:** ids are `p3` and `d2`, so `Lib.FullSkinPaths` has no numeric segment, and no profile has its record set with its entries unmoved. No shipped bar-family default names a real style; the one `Solid`, `defaults/Icons.lua`, is the icon family behind `borderShow = false`.
- No issue was filed, by the run's brief.
