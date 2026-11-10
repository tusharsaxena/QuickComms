# 04 Execution plan

The QFE-F1 commit is the copy, the provenance roll, and the default-skin adoption:

1. `NS.DEFAULT_SKIN = Skin:DefaultSkin()` in core/SkinSetup.lua ("ka0s" without the library), named by defaults/Profile.lua's `skin.skin` (so the schema row's default follows) and by the stand-in fallback in `NS.SkinChoice`. Tests pin the default per kit profile (tests/test_skinsetup.lua, tests/schema_pins.lua). The harness boots every other case on Ka0s Default by name (tests/run.lua, `opts.clientSkin` to opt out), because most suites pin Ka0s Default's pixels.
2. The two `GetFrameStrata` reads go through the new `Compat.FrameStrata(frame, fallback)`, which answers the fallback for a secret strata: the ghost (modules/Anim_Ghost.lua, the dial's `HUD_POPUP`) and `LiftConfirm` (settings/ModalWindow.lua, Blizzard's `DIALOG`).

Identity and Role land in QFE-F4 and QFE-F5, each with its own characterization tests.
