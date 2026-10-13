local _, NS = ...
-- core/Constants.lua — fixed values the addon reads: the console font and the house gold.
--
-- Data only. The surface geometry, channel prefixes and limits of the design spec (§8–§11) are added
-- here by the tasks that read them.

NS.Constants = NS.Constants or {}
local C = NS.Constants

-- The debug console's monospace face, from the shared payload (core/MediaSetup.lua, which loads
-- first). A real client font when the library is absent, never nil and never a dead path.
C.FONT_MONO_NAME = "JetBrains Mono"
C.FONT_MONO = NS.MediaFont and NS.MediaFont(C.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT
    or "Fonts\\FRIZQT__.TTF"

-- The Ka0s gold (#FFD100), the logo's and the surfaces' accent.
C.GOLD = { r = 1.0, g = 0.82, b = 0.0 }
