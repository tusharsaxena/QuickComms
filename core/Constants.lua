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

-- A chat type's color (a chip's tooltip channel, a callout row's channel): WoW's chat colors, used
-- when ChatTypeInfo cannot be read (spec §10.1).
C.CHAT_COLORS = {
    PARTY = { 0.67, 0.67, 1.0 }, RAID = { 1.0, 0.5, 0.0 }, INSTANCE_CHAT = { 1.0, 0.5, 0.0 },
    RAID_WARNING = { 1.0, 0.28, 0.0 }, SAY = { 1.0, 1.0, 1.0 }, YELL = { 1.0, 0.25, 0.25 },
}

-- A chip's flash for each send result: gold sent, red dropped, amber guarded (spec §10.1).
C.FLASH = {
    sent = { 1.0, 0.82, 0.0 }, dropped = { 0.9, 0.15, 0.15 }, guarded = { 1.0, 0.5, 0.0 },
}
