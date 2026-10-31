-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; QC-03 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, Addendum 07, ruling D-19).
--
-- Nine skins draw this addon's text in a dozen faces, and a character one of them lacks is a box in
-- that skin only. So every string literal in a tracked .lua file outside libs/, tests/ and tools/
-- carries only characters every shipped face draws (the kit's safe set, read from their cmaps).
-- A string drawn in the mono role carries a `glyph: mono` marker on its line; a string that is
-- never drawn (a lookup key, a pattern) carries `glyph: data` with its reason.
--
-- When it landed the guard found nothing to fix: the addon's display strings use only ASCII, the
-- em dash, the ellipsis and the middle dot (all in the safe set). The one arrow in a literal
-- (core/QuickComms.lua's profile-copy line) is the argument of an NS.Debug call, which the kit
-- reads as the debug console's (mono) text and skips.

local T = _G.QUICKCOMMS_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
  -- red under: a ≈, →, ▸ (or any other character outside the kit's safe set) in a string the
  -- addon paints in a skin face.
  T.assertDisplayGlyphs{ label = "QuickComms" }
end)
