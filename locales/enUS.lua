local _, NS = ...
-- locales/enUS.lua — NS.L and its metatable fallback; the key IS the English source string.
--
-- Canonical locale (localization-§1). An unknown key answers itself, so a string added to the code
-- before it is added here still renders in English rather than as nil. Input side (localization-§4):
-- game data is matched on stable ids and tokens (instanceID, difficultyID, classFile, specID), never
-- on a localized display string.

local L = setmetatable({}, {
    __index = function(_, k) return k end,
})
NS.L = L

-- Chat lines and seams that degrade without the library (core/, settings/)
L["%s is unavailable: the LibKa0s library did not load."] =
    "%s is unavailable: the LibKa0s library did not load."
L["%s, so the debug console window is unavailable."] =
    "%s, so the debug console window is unavailable."
L["%s, so the perf harness is unavailable."] = "%s, so the perf harness is unavailable."
L["%s, so the settings CLI is unavailable."] = "%s, so the settings CLI is unavailable."
L["%s, so the settings panel is unavailable."] = "%s, so the settings panel is unavailable."
L["%s, so there is no minimap button and no broker plugin."] =
    "%s, so there is no minimap button and no broker plugin."
L["%s; running on reduced built-in fallbacks."] = "%s; running on reduced built-in fallbacks."
L["The LibKa0s library is missing from this installation of %s (expected in libs/LibKa0s)"] =
    "The LibKa0s library is missing from this installation of %s (expected in libs/LibKa0s)"

-- Slash command descriptions (settings/Slash.lua NS.COMMANDS)
L["Disable the addon"] = "Disable the addon"
L["Enable the addon"] = "Enable the addon"
L["List available commands"] = "List available commands"
L["List every setting and its current value"] = "List every setting and its current value"
L["List profiles, or switch to one: profile <name>"] =
    "List profiles, or switch to one: profile <name>"
L["Measure performance — `/qc perf` opens the step panel"] =
    "Measure performance — `/qc perf` opens the step panel"
L["Open the Ka0s Quick Comms settings panel"] = "Open the Ka0s Quick Comms settings panel"
L["Open/close the debug window — `/qc debug on|off` toggles logging"] =
    "Open/close the debug window — `/qc debug on|off` toggles logging"
L["Print a setting's current value — `/qc get <path>`"] =
    "Print a setting's current value — `/qc get <path>`"
L["Print the addon version"] = "Print the addon version"
L["Reset every setting to defaults"] = "Reset every setting to defaults"
L["Reset one setting to its default — `/qc reset <path>`"] =
    "Reset one setting to its default — `/qc reset <path>`"
L["Set a setting — `/qc set <path> <value>` (try /qc list)"] =
    "Set a setting — `/qc set <path> <value>` (try /qc list)"
L["Write the diagnostics report to the debug console"] =
    "Write the diagnostics report to the debug console"

-- Settings panel and chat acknowledgments
L["Debug console"] = "Debug console"
L["Diagnostic report written to the debug console: %d lines. Use Copy to share it."] =
    "Diagnostic report written to the debug console: %d lines. Use Copy to share it."
L["General"] = "General"
L["Profiles"] = "Profiles"
L["Reset every %s setting to its default. Asks for confirmation."] =
    "Reset every %s setting to its default. Asks for confirmation."
L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."] =
    "Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."
L["Settings panel is not available."] = "Settings panel is not available."
L["Slash Commands"] = "Slash Commands"
L["all settings reset to defaults"] = "all settings reset to defaults"
L["debug logging |cff40ff40ON|r"] = "debug logging |cff40ff40ON|r"
L["debug logging |cffff4040OFF|r"] = "debug logging |cffff4040OFF|r"
L["unknown command '%s'"] = "unknown command '%s'"
L["v%s slash commands"] = "v%s slash commands"
L["|cffFFFF00%s|r takes a setting path: |cffFFFF00%s|r (try |cffFFFF00%s|r). To reset everything: |cffFFFF00%s|r."] =
    "|cffFFFF00%s|r takes a setting path: |cffFFFF00%s|r (try |cffFFFF00%s|r). To reset everything: |cffFFFF00%s|r."
L["Behavior"] = "Behavior"
L["When you are solo"] = "When you are solo"
L["What a Smart group or Smart lead callout does when you are not in a group."] = "What a Smart group or Smart lead callout does when you are not in a group."
L["Do nothing"] = "Do nothing"
L["Print to me"] = "Print to me"
L["Send to Say"] = "Send to Say"
L["Spam guard (seconds)"] = "Spam guard (seconds)"
L["Shortest time between any two callouts. Bosses silently drop messages sent faster than about a second apart."] = "Shortest time between any two callouts. Bosses silently drop messages sent faster than about a second apart."
L["Note dropped callouts in chat"] = "Note dropped callouts in chat"
L["Print a one-line note when a callout seems to have been dropped by the game."] = "Print a one-line note when a callout seems to have been dropped by the game."
L["Explain why groups show"] = "Explain why groups show"
L["Show which conditions matched in the pad and dial tooltips."] = "Show which conditions matched in the pad and dial tooltips."
L["Show the lockdown chip"] = "Show the lockdown chip"
L["Show LOCKDOWN on a pad or dial when lockdown is blocking one of its callouts."] = "Show LOCKDOWN on a pad or dial when lockdown is blocking one of its callouts."
L["Play a sound on send"] = "Play a sound on send"
L["A short sound when a callout is sent."] = "A short sound when a callout is sent."
L["Promote specific groups"] = "Promote specific groups"
L["Groups for a specific dungeon or battleground move above general ones on each pad and dial."] = "Groups for a specific dungeon or battleground move above general ones on each pad and dial."
L["Content"] = "Content"
L["Instance"] = "Instance"
L["Battleground"] = "Battleground"
L["Difficulty"] = "Difficulty"
L["Key level"] = "Key level"
L["Group"] = "Group"
L["Leader or assist"] = "Leader or assist"
L["Class"] = "Class"
L["Specialization"] = "Specialization"
L["Role"] = "Role"
L["Character"] = "Character"
L["always on"] = "always on"
