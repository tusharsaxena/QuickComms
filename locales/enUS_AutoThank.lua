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
