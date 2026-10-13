local _, NS = ...
-- settings/SchemaMembers.lua — the member rows (architecture-§5): every field a player sets on a
-- callout, a group, a Comms Pad or a built-in set's overlay is a schema row whose path starts with
-- the member's kind. settings/Schema.lua resolves the member from the instance argument, or from the
-- one its editor page has selected (NS.State.editing), so the panel, the CLI, the pad's drag and
-- Library's own built-in writers all write through NS.SchemaRuntime.Set. modules/Library.lua keeps
-- what is not a field: membership (create, delete, duplicate, Customize), the order of every list,
-- the references a group and a surface hold, the ids and the seeding. Each row's onChange hands the
-- write to Library.Touch, which sends LIBRARY_CHANGED, so the pads rebuild (in combat, at combat
-- end, with the stale hint), naming the field so the editor pages repaint only when what they draw
-- changes shape. Paths resolve against Library.TEMPLATES at the boot check; member rows are no AceDB
-- default. Three rows hold a table (a pad's point, a group's When, a set's hidden callouts): their
-- pages draw their own controls, and settings/Slash.lua's parse and format hooks type and print them
-- on the command line. Added on every load, the degraded one included: Library's writers need them
-- (tests/test_setup.lua pins that a degraded load's schema holds these rows and nothing else).

local L   = NS.L
local Lib = NS.Library
local T   = Lib.TEMPLATES

local GENERAL = L["General"]

-- A Library validator's reason code, as the line the seam hands back as its `why`.
local WHY = {
    badName   = L["A name is 1 to 32 characters."],
    badText   = L["Callout text must be text."],
    badChannel = L["That is not a channel Quick Comms sends on."],
    badIcon   = L["An icon is a texture id or a texture path."],
    badPoint  = L["A position is two anchor points and two numbers."],
    offScreen = L["That position is off the screen: an offset is at most the screen's width or height."],
    badWhen   = L["That condition is not one Quick Comms knows."],
    badRange  = L["The lowest key level is above the highest."],
    badHidden = L["Only this set's own callouts can be hidden."],
    builtin   = L["Built-in groups are read-only. Customize makes an editable copy."],
    badChoice = L["That is not one of the choices."],
}

local function check(fn)
    return function(v, id)
        local ok, code = fn(v, id)
        if ok then return true end
        return false, WHY[code] or tostring(code)
    end
end

-- Built-ins are read-only (spec §12.2): every group row refuses a built-in id, whatever the value.
local function userGroup(inner)
    return check(function(v, id)
        if Lib.IsBuiltin(id) then return false, "builtin" end
        if inner then return inner(v, id) end
        return true
    end)
end

local function oneOf(list)
    local set = {}
    for _, item in ipairs(list) do set[item.value] = true end
    return check(function(v) return set[v] == true, "badChoice" end)
end

local function isNumber(v) return type(v) == "number" and v == v end
local function clamp(lo, hi, whole)
    return function(v)
        v = math.max(lo, math.min(hi, v))
        if whole then v = math.floor(v + 0.5) end
        return v
    end
end
local NUMBER = check(function(v) return isNumber(v), "badChoice" end)

-- An icon typed into a text box: digits are a texture id, nothing is "no icon" (false, a value the
-- seam stores; nil would be a refusal), anything else a texture path.
local function iconValue(v)
    if type(v) ~= "string" then return v end
    local trimmed = v:match("^%s*(.-)%s*$")
    if trimmed == "" then return false end
    return tonumber(trimmed:match("^(%d+)$")) or trimmed
end

local function isText(v) return type(v) == "string", "badText" end

-- What a When row takes, for the refusal of a value it can never match (localization-§4).
local function whenTakes(row)
    if row == "instances" or row == "battleground" then return L["an instance id (a whole number)"] end
    if row == "spec" then return L["a specialization id (a whole number)"] end
    if row == "characters" then return L["Name-Realm"] end
    local list = row == "class" and NS.GameIds.CLASSES or NS.Resolver.TOKENS[row] or {}
    return table.concat(list, ", ")
end

-- group.when: Library.ValidWhen, with a value the row can never match named, and what it takes.
local function validWhen(v)
    local ok, code, row, value = Lib.ValidWhen(v)
    if ok then return true end
    if code == "badValue" then
        return false, L["%s does not take %s. It takes: %s."]:format(NS.Resolver.LABEL[row] or tostring(row),
            tostring(value), whenTakes(row))
    end
    return false, code
end

local CHANNEL_LABEL = {
    smartGroup = L["Smart group (instance, raid or party)"],
    smartLead = L["Smart lead (raid warning when you can)"],
    party = L["Party"], raid = L["Raid"], instance = L["Instance"], raidWarning = L["Raid warning"],
    say = L["Say"], yell = L["Yell"],
}
local CHANNELS = {}
for i, kind in ipairs(NS.Channels.KINDS) do CHANNELS[i] = { value = kind, text = CHANNEL_LABEL[kind] or kind } end

local function choices(pairsList)
    local out = {}
    for i, p in ipairs(pairsList) do out[i] = { value = p[1], text = p[2] } end
    return out
end

local GROUPS_AS = choices({ { "sections", L["Sections"] }, { "merged", L["One list"] }, { "tabs", L["Tabs (the mouse wheel switches)"] } })
local ORIENTATION = choices({ { "horizontal", L["Horizontal"] }, { "vertical", L["Vertical"] }, { "grid", L["Grid"] } })
local GROWTH = choices({ { "right", L["Right and down"] }, { "left", L["Left and down"] }, { "up", L["Upward"] } })
local STYLE = choices({ { "iconLabel", L["Icon and label"] }, { "icon", L["Icon only"] }, { "label", L["Label only"] } })
local VISIBILITY = choices({ { "always", L["Always"] }, { "inCombat", L["Only in combat"] },
    { "outOfCombat", L["Only out of combat"] }, { "whenActive", L["When a group is active"] }, { "never", L["Never"] } })
local FADE = choices({ { "none", L["Never"] }, { "outOfCombat", L["Out of combat"] }, { "mouseover", L["Until the mouse is over it"] } })

local ROWS = {
    -- Callouts page (spec §13.1). Name and text have no default: a reset never blanks them.
    { path = "callout.name", instance = "callout", type = "string", dialogControl = "EditBox",
      maxLetters = Lib.NAME_MAX, page = "callouts", group = GENERAL, label = L["Name"],
      desc = L["What the chip and the lists call this callout. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "callout.text", instance = "callout", type = "string", dialogControl = "EditBox",
      maxLetters = 255, page = "callouts", group = GENERAL, label = L["Text"],
      desc = L["What is sent. Tokens in braces are filled in: {target}, {focus}, {skull}, {me}, {spec}, {key}, {dungeon}, {spell:ID}; in a raid, {group1} to {group8}. Press Enter to apply."],
      validate = check(isText) },
    { path = "callout.channel", instance = "callout", type = "string", default = T.callout.channel,
      values = CHANNELS, page = "callouts", group = GENERAL, label = L["Channel"],
      desc = L["Where it is sent. Smart group picks instance, raid or party chat for the group you are in when the pad is built."],
      validate = check(function(v) return NS.Channels.IsKind(v), "badChannel" end) },
    -- Icon's default is false, "no icon", so `/qc reset callout.icon` clears it; the page's Defaults
    -- keeps it (settings/Schema.lua resetExempt), as its tooltip says.
    { path = "callout.icon", instance = "callout", type = "string", dialogControl = "EditBox", default = false,
      page = "callouts", group = GENERAL, label = L["Icon"],
      desc = L["A texture id (a number) or a texture path (a LibKa0s icon by its path). Leave it empty for the default icon. Press Enter to apply."],
      normalize = iconValue, validate = check(function(v) return v == false or type(v) == "string", "badIcon" end) },

    -- Groups page (spec §13.1, §13.2).
    { path = "group.name", instance = "group", type = "string", dialogControl = "EditBox",
      maxLetters = Lib.NAME_MAX, page = "groups", group = GENERAL, label = L["Name"],
      desc = L["What the pad's section and the lists call this group. Press Enter to apply."],
      validate = userGroup(Lib.ValidName) },
    { path = "group.icon", instance = "group", type = "string", dialogControl = "EditBox", default = false,
      page = "groups", group = GENERAL, label = L["Icon"],
      desc = L["A texture id (a number) or a texture path (a LibKa0s icon by its path). Leave it empty for the default icon. Press Enter to apply."],
      normalize = iconValue, validate = userGroup(function(v) return v == false or type(v) == "string", "badIcon" end) },
    { path = "group.enabled", instance = "group", type = "bool", default = T.group.enabled,
      page = "groups", group = GENERAL, label = L["Enabled"],
      desc = L["Show this group wherever its When matches. Off keeps the group and its place on every pad."],
      validate = userGroup() },
    { path = "group.openInto", instance = "group", type = "bool", default = T.group.openInto,
      page = "groups", group = GENERAL, label = L["Open the dial on this group"],
      desc = L["When this is the first active group on a Comms Dial, the dial opens on its callouts. The Comms Dial arrives in a later build."],
      validate = userGroup() },
    { path = "group.when", instance = "group", type = "when",
      page = "groups", group = L["When"], label = L["When"],
      desc = L["The conditions under which this group is active. Every condition you turn on must match; within a condition, any value may."],
      validate = userGroup(validWhen) },

    -- Comms Pad page (spec §10.2, §10.3, §13.1).
    { path = "pad.name", instance = "pad", type = "string", dialogControl = "EditBox", maxLetters = Lib.NAME_MAX,
      page = "pads", group = GENERAL, label = L["Name"],
      desc = L["What the drag strip and the lists call this pad. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "pad.enabled", instance = "pad", type = "bool", default = T.pad.enabled,
      page = "pads", group = GENERAL, label = L["Enabled"],
      desc = L["Draw this pad. A disabled pad keeps its groups and its settings."] },
    { path = "pad.groupsAs", instance = "pad", type = "string", default = T.pad.groupsAs, values = GROUPS_AS,
      page = "pads", group = L["Groups"], label = L["Show groups as"],
      desc = L["Sections under small headings, one merged list, or one group at a time (the mouse wheel over the pad switches; not in combat)."],
      validate = oneOf(GROUPS_AS) },
    { path = "pad.layout.orientation", instance = "pad", type = "string", default = T.pad.layout.orientation,
      values = ORIENTATION, page = "pads", group = L["Layout"], label = L["Orientation"],
      desc = L["One row, one column, or a grid."], validate = oneOf(ORIENTATION) },
    { path = "pad.layout.columns", instance = "pad", type = "number", default = T.pad.layout.columns,
      min = 1, max = 12, step = 1, page = "pads", group = L["Layout"], label = L["Grid columns"],
      desc = L["Chips per row when the orientation is Grid."],
      validate = NUMBER, normalize = clamp(1, 12, true) },
    { path = "pad.layout.growth", instance = "pad", type = "string", default = T.pad.layout.growth,
      values = GROWTH, page = "pads", group = L["Layout"], label = L["Growth"],
      desc = L["Which way the chips fill from the pad's anchor."], validate = oneOf(GROWTH) },
    { path = "pad.layout.style", instance = "pad", type = "string", default = T.pad.layout.style,
      values = STYLE, page = "pads", group = L["Layout"], label = L["Chip style"],
      desc = L["Icon only puts the callout's name in its tooltip."], validate = oneOf(STYLE) },
    { path = "pad.layout.scale", instance = "pad", type = "number", default = T.pad.layout.scale,
      min = 0.5, max = 2, step = 0.05, page = "pads", group = L["Layout"], label = L["Scale"],
      desc = L["This pad's size, on top of the master scale."],
      validate = NUMBER, normalize = clamp(0.5, 2) },
    { path = "pad.layout.spacing", instance = "pad", type = "number", default = T.pad.layout.spacing,
      min = 0, max = 20, step = 1, page = "pads", group = L["Layout"], label = L["Spacing"],
      desc = L["Pixels between chips."], validate = NUMBER, normalize = clamp(0, 20, true) },
    { path = "pad.layout.width", instance = "pad", type = "number", default = T.pad.layout.width,
      min = 120, max = 300, step = 10, page = "pads", group = L["Layout"], label = L["Chip width"],
      desc = L["How wide a labeled chip is."], validate = NUMBER, normalize = clamp(120, 300, true) },
    -- Position's default is false, the default place, so `/qc reset pad.point` brings a pad back; the
    -- page's Defaults keeps the position (settings/Schema.lua resetExempt), as its tooltip says.
    { path = "pad.point", instance = "pad", type = "point", default = false,
      page = "pads", group = L["Layout"], label = L["Position"],
      desc = L["Where the pad sits. Drag it while unlocked, or type an offset."],
      validate = check(Lib.ValidPoint) },
    { path = "pad.look.visibility", instance = "pad", type = "string", default = T.pad.look.visibility,
      values = VISIBILITY, page = "pads", group = L["Look"], label = L["Visibility"],
      desc = L["When this pad shows. General visibility applies on top. When a group is active is decided at the last change out of combat."],
      validate = oneOf(VISIBILITY) },
    { path = "pad.look.fade", instance = "pad", type = "string", default = T.pad.look.fade,
      values = FADE, page = "pads", group = L["Look"], label = L["Fade"],
      desc = L["Fade the pad out of combat, or until the mouse is over it."],
      validate = oneOf(FADE) },
    { path = "pad.look.fadeAlpha", instance = "pad", type = "number", default = T.pad.look.fadeAlpha,
      min = 0, max = 1, step = 0.05, page = "pads", group = L["Look"], label = L["Faded alpha"],
      desc = L["How visible a faded pad is."], validate = NUMBER, normalize = clamp(0, 1) },

    -- A built-in set's overlay (spec §12.2): the only writable part of a shipped set.
    { path = "builtin.enabled", instance = "builtin", type = "bool", default = T.builtin.enabled,
      page = "share", group = L["Built-in"], label = L["Enabled"],
      desc = L["Show this built-in set wherever it matches. Off keeps it, and its place on every pad."] },
    { path = "builtin.hidden", instance = "builtin", type = "idset",
      page = "share", group = L["Built-in"], label = L["Hidden callouts"],
      desc = L["The set's callouts that no pad shows."],
      -- With no built-in set addressed the value passes, so the seam's missing-member refusal (which
      -- says to pick a set on the Groups page) is the reason the player reads.
      validate = check(function(v, id)
          if Lib.TopOf(id) == nil then return true end
          return Lib.ValidHidden(Lib.TopOf(id), v)
      end) },
}

-- Every member row's reaction: Library.Touch announces the write (LIBRARY_CHANGED, the pads' rebuild),
-- naming the row's path as the field.
for _, row in ipairs(ROWS) do
    local kind, path = row.instance, row.path
    row.onChange = function(_, id) Lib.Touch(kind, id, path) end
end

NS.SchemaRuntime.AddRows(ROWS)
