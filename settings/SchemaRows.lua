local _, NS = ...
-- settings/SchemaRows.lua — the hand-written schema rows (design spec §13.1).
--
-- One row per setting: stored path, type, label, tooltip, the page and the tab it draws on (`group`
-- is the tab, options-ui-§13), widget hints and the check the write seam runs before storing. Every
-- `default` references defaults/Profile.lua (savedvariables-§2), never a literal here. The composed
-- Master controls rows are settings/Panel.lua's and are spliced in at index 1, so the General
-- page's `Master controls` tab stays first and Behavior follows it.

local L = NS.L
local B = NS.C.PROFILE.behavior

local BEHAVIOR  = L["Behavior"]
local FALLBACKS = { "none", "self", "say" }

local function oneOf(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return function(v) return set[v] == true end
end

-- The write seam does not read `min`/`max`; they are widget hints. The spam guard's range is held by
-- `validate` (a number) and `normalize` (clamps into 0.6-2.0), so an out-of-range write stores the
-- nearest bound.
local function isNumber(v) return type(v) == "number" and v == v end
local function clampGuard(v) return math.max(0.6, math.min(2.0, v)) end

-- On a load where the Options composers are hollow (LibKa0s absent) the schema stays empty
-- (settings/Panel.lua adds no rows either); the Behavior rows are drawn by that library.
if not NS.addon.Settings.Helpers.MASTER_GROUP then return end

NS.SchemaRuntime.AddRows({
    { path = "behavior.soloFallback", type = "string", default = B.soloFallback, page = "general",
      group = BEHAVIOR, label = L["When you are solo"],
      desc = L["What a Smart group or Smart lead callout does when you are not in a group."],
      values = { { value = "none", text = L["Do nothing"] }, { value = "self", text = L["Print to me"] },
                 { value = "say", text = L["Send to Say"] } },
      validate = oneOf(FALLBACKS) },
    { path = "behavior.spamGuard", type = "number", default = B.spamGuard, page = "general",
      group = BEHAVIOR, label = L["Spam guard (seconds)"],
      desc = L["Shortest time between any two callouts. Bosses silently drop messages sent faster than about a second apart."],
      min = 0.6, max = 2.0, step = 0.1,
      validate = isNumber, normalize = clampGuard },
    { path = "behavior.dropNotes", type = "bool", default = B.dropNotes, page = "general",
      group = BEHAVIOR, label = L["Note dropped callouts in chat"],
      desc = L["Print a one-line note when a callout seems to have been dropped by the game."] },
    { path = "behavior.whyTooltips", type = "bool", default = B.whyTooltips, page = "general",
      group = BEHAVIOR, label = L["Explain why groups show"],
      desc = L["Show which conditions matched in the pad and dial tooltips."] },
    { path = "behavior.lockdownChip", type = "bool", default = B.lockdownChip, page = "general",
      group = BEHAVIOR, label = L["Show the lockdown chip"],
      desc = L["Show LOCKDOWN on a pad or dial when lockdown is blocking one of its callouts."] },
    { path = "behavior.sounds", type = "bool", default = B.sounds, page = "general",
      group = BEHAVIOR, label = L["Play a sound on send"], desc = L["A short sound when a callout is sent."] },
    { path = "behavior.autoPromote", type = "bool", default = B.autoPromote, page = "general",
      group = BEHAVIOR, label = L["Promote specific groups"],
      desc = L["Groups for a specific dungeon or battleground move above general ones on each pad and dial."] },
})
