local _, NS = ...
-- locales/enUS_AutoThank.lua — the strings only modules/AutoThank*.lua reads (localization-§6).
--
-- A topic file of the canonical locale: locales/enUS.lua creates NS.L and its key-on-miss fallback;
-- this file only assigns into it, and loads directly after locales/enUS_Settings.lua (the TOC's
-- LOAD-BEARING line). A key any other file reads lives in enUS.lua or enUS_Settings.lua instead;
-- tests/test_locale.lua enforces the placement.

local L = NS.L

-- Why the Thank button's whisper was not built (modules/AutoThank.lua AT.REASON)
L["Nothing to whisper: the thank-you text is empty."] = "Nothing to whisper: the thank-you text is empty."
L["The thank-you text cannot start with /."] = "The thank-you text cannot start with /."

-- The thank toast's line: the caster's name, then the buff (modules/AutoThank_Toast.lua TH.Build)
L["%s buffed you with %s"] = "%s buffed you with %s"

-- The toast's Thank button, its press's name in a lock or drop note, and why its whisper is locked
-- (modules/AutoThank_Toast.lua)
L["Thank"] = "Thank"
L["Locked: whispers are blocked right now."] = "Locked: whispers are blocked right now."

-- The test-mode sample toast's buff, and its caster where LibKa0s-Sim-1.0 is absent (modules/AutoThank_Toast.lua,
-- /qc test; with the library the caster is its sample crowd's first person)
L["A stranger"] = "A stranger"
L["a sample buff"] = "a sample buff"
L["Test mode: sends nothing."] = "Test mode: sends nothing."
