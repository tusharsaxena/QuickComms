local _, NS = ...
-- settings/SchemaMembers.lua — the member rows (architecture-§5): every field a player sets on a
-- callout, a group, a Comms Pad or a Comms Dial is a schema row whose path starts with the member's
-- kind. settings/Schema.lua resolves the member from the instance argument, or from the one its
-- editor page has selected (NS.State.editing), so the panel, the CLI, the pad's drag and Library's
-- own writers all write through NS.SchemaRuntime.Set.
-- modules/Library.lua keeps what is not a field: membership (create, delete, duplicate, restore),
-- the order of every list, the references a group and a surface hold, the ids and the seeding. Each
-- row's onChange hands the write to Library.Touch, which sends LIBRARY_CHANGED, so the pads rebuild
-- (in combat, at combat end, with the stale hint), naming the field so the editor pages repaint
-- only when what they draw changes shape. Paths resolve against Library.TEMPLATES at the boot
-- check; member rows are no AceDB default. Three row types are structured (a pad's or a dial's
-- point, a group's When, a dial's key): their pages draw their own
-- controls, and settings/Slash.lua's parse and format hooks type and print them on the command
-- line. Added on every load, the degraded one included: Library's writers need them
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
    badIconColor = L["An icon color is six hex digits (rrggbb), or empty for none."],
    notGlyph  = L["Only a LibKa0s glyph takes a color: choose one as the icon first."],
    badPoint  = L["A position is two anchor points and two numbers."],
    offScreen = L["That position is too far off the screen."],
    badWhen   = L["That condition is not one Quick Comms knows."],
    badRange  = L["The lowest key level is above the highest."],
    badParent = L["A parent group is one of your groups, or none."],
    selfParent = L["A group cannot be inside itself."],
    parentIsChild = L["That group is inside another group: groups go one level deep."],
    hasChildren = L["This group holds groups of its own, so it cannot go inside another: groups go one level deep."],
    badChoice = L["That is not one of the choices."],
    badKey    = L["A key is one key, with ALT-, CTRL- or SHIFT- in front if you like."],
    badColor  = L["A color is red, green and blue, and optionally alpha, each from 0 to 1."],
    reservedKey = L["Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot open a dial: the open dial uses them."],
}

local function check(fn)
    return function(v, id)
        local ok, code = fn(v, id)
        if ok then return true end
        return false, WHY[code] or tostring(code)
    end
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

-- A parent group typed on the command line: empty text and "none" (any case) are no parent (false,
-- a value the seam stores), anything else the group id as typed, for Library.ValidParent to judge.
-- The seam checks the value as given, so the check reads it through this too.
local function parentValue(v)
    if type(v) ~= "string" then return v end
    local trimmed = v:match("^%s*(.-)%s*$")
    if trimmed == "" or trimmed:lower() == "none" then return false end
    return trimmed
end

-- callout.iconColor, group.iconColor: none, or six hex digits (Library.IconColorValue reads typed
-- text) on a member whose icon is a LibKa0s glyph. With no member addressed the value passes, so the
-- seam's missing-member refusal is the reason the player reads.
local function iconColorCheck(kind)
    return function(v, id)
        local c = Lib.IconColorValue(v)
        local ok, code = Lib.ValidIconColor(c)
        if not ok then return false, code end
        local m = Lib.Member(kind, id)
        if c and m and not Lib.IsGlyph(m.icon) then return false, "notGlyph" end
        return true
    end
end

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
local MODE = choices({ { "categories", L["Categories"] }, { "flat", L["Flat"] } })
local OPEN_AT = choices({ { "center", L["At its place"] }, { "cursor", L["At the cursor"] } })
local SLICES = {}
for i, n in ipairs({ 4, 6, 8, 12 }) do SLICES[i] = { value = n, text = tostring(n) } end

-- A dial's key: none, or a key that is not reserved and that no other dial has (spec §18: the editor
-- refuses, naming the other dial). The seam then stores it as Library.KeyValue normalizes it.
local function keyCheck(v, id)
    local ok, code = Lib.ValidKey(v)
    if not ok then return false, WHY[code] end
    local other = Lib.KeyOwner(v, id)
    if other then
        local d = NS.db.profile.dials[other]
        return false, L["%s already opens %s."]:format(Lib.KeyValue(v), tostring(d and d.name or other))
    end
    return true
end

local ROWS = {
    -- A callout's rows (spec §13.1, as amended 2026-10-17): addressed by id alone, drawn by the callout
    -- popup against its draft; `page` is only their /qc list heading. Name and text have no default: a
    -- reset never blanks them.
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
    -- A glyph's color. Its default is false, none (white), so `/qc reset callout.iconColor <id>` clears
    -- it; the page's Defaults keeps it with the icon (settings/Schema.lua resetExempt). Only a glyph
    -- takes one, and an icon write that is no glyph clears it (the onChange loop below). The icon
    -- browser's swatch draws it, never a text box.
    { path = "callout.iconColor", instance = "callout", type = "string", default = false,
      page = "callouts", group = GENERAL, label = L["Icon color"],
      desc = L["The color a LibKa0s glyph icon is drawn in: six hex digits (rrggbb). Leave it empty for white."],
      normalize = Lib.IconColorValue, validate = check(iconColorCheck("callout")) },

    -- Groups page (spec §13.1, §13.2).
    { path = "group.name", instance = "group", type = "string", dialogControl = "EditBox",
      maxLetters = Lib.NAME_MAX, page = "groups", group = GENERAL, label = L["Name"],
      desc = L["What the pad's section and the lists call this group. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "group.icon", instance = "group", type = "string", dialogControl = "EditBox", default = false,
      page = "groups", group = GENERAL, label = L["Icon"],
      desc = L["A texture id (a number) or a texture path (a LibKa0s icon by its path). Leave it empty for the default icon. Press Enter to apply."],
      normalize = iconValue, validate = check(function(v) return v == false or type(v) == "string", "badIcon" end) },
    -- As callout.iconColor. The General tab leaves it out of its rows (settings/Groups.lua).
    { path = "group.iconColor", instance = "group", type = "string", default = false,
      page = "groups", group = GENERAL, label = L["Icon color"],
      desc = L["The color a LibKa0s glyph icon is drawn in: six hex digits (rrggbb). Leave it empty for white."],
      normalize = Lib.IconColorValue, validate = check(iconColorCheck("group")) },
    { path = "group.enabled", instance = "group", type = "bool", default = T.group.enabled,
      page = "groups", group = GENERAL, label = L["Enabled"],
      desc = L["Show this group wherever its When matches (its parent's, while Inherit when conditions is ticked). Off keeps the group and its place on every pad."] },
    { path = "group.openInto", instance = "group", type = "bool", default = T.group.openInto,
      page = "groups", group = GENERAL, label = L["Open the dial on this group"],
      desc = L["When this is the first active group on a Comms Dial, the dial opens straight on its ring, and the middle of the dial goes back to the groups."] },
    -- Nesting (2026-10-18-builtins-as-groups-design.md, goal 2): the top-level group this one sits
    -- inside, or none (false). The General tab draws it as its own dropdown of the groups it may take
    -- (settings/Groups.lua); /qc takes a group id or none. Taking a parent takes the group off every
    -- surface (Library.SettleParent, below). A page's Defaults keeps it (settings/Schema.lua resetExempt).
    { path = "group.parent", instance = "group", type = "string", dialogControl = "EditBox", default = false,
      page = "groups", group = GENERAL, label = L["Parent group"],
      desc = L["The group this one sits inside. It shows wherever that group does, in a section (or a ring) of its own, while its conditions match (its parent's, while Inherit when conditions is ticked). None makes it a group of its own."],
      normalize = parentValue, validate = check(function(v, id) return Lib.ValidParent(parentValue(v), id) end) },
    -- Inherit when conditions (2026-10-18-when-drawers-design.md §3): a child judged by its parent's
    -- When instead of its own (Resolver.WhenOf), which is kept. On by default; an absent field reads as
    -- on. The General tab draws it as its own checkbox beside Parent group (settings/Groups.lua).
    { path = "group.inheritWhen", instance = "group", type = "bool", default = T.group.inheritWhen,
      page = "groups", group = GENERAL, label = L["Inherit when conditions"],
      validate = check(function(v) return type(v) == "boolean", "badChoice" end),
      desc = L["Use the parent group's When instead of this group's own. This group's own conditions are kept for when you untick it. Only a group inside another group inherits."] },
    { path = "group.when", instance = "group", type = "when",
      page = "groups", group = L["When"], label = L["When"],
      desc = L["The conditions under which this group is active. Every condition you set must match; a condition left as Any does not limit the group; within a condition, any value may."],
      validate = check(validWhen) },

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
      disabledIf = function() return NS.SchemaRuntime.Get("pad.layout.orientation") ~= "grid" end,
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

    -- Comms Dial page (spec §11, §13.1). Relaxed is the only interaction in v0.1.0, so there is no
    -- interaction, delay or tap-action row (Quick mode brings them with the C7 upgrade), and no depth
    -- row (owner ruling R5: depth is §11.3's limit, warned about on the Groups tab).
    { path = "dial.name", instance = "dial", type = "string", dialogControl = "EditBox", maxLetters = Lib.NAME_MAX,
      page = "dials", group = GENERAL, label = L["Name"],
      desc = L["What the lists and the dial's first ring call this dial. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "dial.enabled", instance = "dial", type = "bool", default = T.dial.enabled,
      page = "dials", group = GENERAL, label = L["Enabled"],
      desc = L["Build this dial and bind its key. A disabled dial keeps its groups, key and settings."] },
    { path = "dial.mode", instance = "dial", type = "string", default = T.dial.mode, values = MODE,
      page = "dials", group = L["Groups"], label = L["Show groups as"],
      desc = L["Categories: the first ring holds your groups and a click opens one. Flat: the first ring holds callouts, highest group first, with More for the rest."],
      validate = oneOf(MODE) },
    { path = "dial.slices", instance = "dial", type = "number", default = T.dial.slices, values = SLICES,
      page = "dials", group = L["Wheel"], label = L["Wedges per ring"],
      desc = L["How many wedges a ring has. A ring with more puts the rest behind More. 12 applies only to a ring of callouts."],
      validate = oneOf(SLICES) },
    { path = "dial.openAt", instance = "dial", type = "string", default = T.dial.openAt, values = OPEN_AT,
      page = "dials", group = L["Wheel"], label = L["Open at"],
      desc = L["Where the dial opens: at its place (set below), or wherever the cursor is."],
      validate = oneOf(OPEN_AT) },
    -- Position's and Key's default is false (the default place, no key), so `/qc reset dial.point` and
    -- `/qc reset dial.key` reach them; the page's Defaults keeps both (settings/Schema.lua
    -- resetExempt), as its tooltip says. As the pad.point row.
    { path = "dial.point", instance = "dial", type = "point", default = false,
      page = "dials", group = L["Wheel"], label = L["Position"],
      desc = L["Where the dial opens at its place. Type an offset from the middle of the screen."],
      validate = check(Lib.ValidPoint) },
    { path = "dial.key", instance = "dial", type = "key", default = false,
      page = "dials", group = L["Binding"], label = L["Key"],
      desc = L["The key that opens and closes this dial. One key opens one dial. Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot be used: the open dial uses them."],
      validate = keyCheck, normalize = Lib.KeyValue },
}

-- ── a pad's Look groups (spec §10.3, §19 row 5; options-ui-§16, §17) ───────────────────────────

-- The font block, the border block and the background swatch with its class-color companion, each
-- COMPOSED by the options library (a hand-written copy is anti-pattern #73) and then stamped as pad
-- member rows: the instance, a check per leaf, and the defaults Library ships (Library.TEMPLATES).
-- The class color is the player's (`classColorSource = "player"`, the composer's default): a pad's
-- text is about no unit. A background is not a bar, so it takes a swatch and its companion only. On
-- a degraded load the composers are hollow and these rows are absent.

local function unit01(c) return type(c) == "number" and c >= 0 and c <= 1 end

-- A color as the color picker stores it, keyed ({ r, g, b, a }) or positional, alpha optional.
local function isColor(v)
    if type(v) ~= "table" then return false, "badColor" end
    local a = v.a or v[4] or 1
    return unit01(v.r or v[1]) and unit01(v.g or v[2]) and unit01(v.b or v[3]) and unit01(a), "badColor"
end

local function isName(v) return type(v) == "string" and v ~= "", "badChoice" end

local BOOL = check(function(v) return type(v) == "boolean", "badChoice" end)

-- A checked color rebuilt as { r, g, b, a } (LibKa0s Core's RGBA reads both shapes, alpha 1 when it
-- is absent), so a stored color holds its four channels and nothing else: an import's extra keys
-- never reach SavedVariables.
local Core = LibStub and LibStub("LibKa0s-Core-1.0", true)
local function fourChannels(v)
    local r, g, b, a
    if Core and Core.RGBA then
        r, g, b, a = Core.RGBA(v, 1, 1, 1, 1)
    else
        r, g, b, a = v.r or v[1], v.g or v[2], v.b or v[3], v.a or v[4] or 1
    end
    return { r = r, g = g, b = b, a = a }
end

local LOOK = "pad.look."
local LOOK_DEFAULTS = T.pad.look

local function lookChecks(O)
    local flags = O.FONT_FLAGS or {}
    return {
        font = { validate = check(isName) },
        fontSize = { validate = NUMBER, normalize = clamp(6, 32, true) },
        fontColor = { validate = check(isColor), normalize = fourChannels },
        useClassColorFont = { validate = BOOL },
        fontFlags = { validate = check(function(v) return type(v) == "string" and flags[v] ~= nil, "badChoice" end) },
        fontShadow = { validate = BOOL },
        borderStyle = { validate = check(isName) },
        borderSize = { validate = NUMBER, normalize = clamp(0, 16, true) },
        borderColor = { validate = check(isColor), normalize = fourChannels },
        useClassColorBorder = { validate = BOOL },
        background = { validate = check(isColor), normalize = fourChannels },
        useClassColorBackground = { validate = BOOL },
    }
end

local function lookSpec(subgroup, extra)
    local spec = { prefix = LOOK, page = "pads", group = L["Look"], subgroup = subgroup, defaults = LOOK_DEFAULTS }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return spec
end

local function lookRows()
    local O = NS.addon.Settings.Helpers
    local checks = lookChecks(O)
    local out = {}
    for _, list in ipairs({
        O.FontGroup(lookSpec(L["Font"])),
        O.BorderGroup(lookSpec(L["Border"])),
        O.ColorPair(lookSpec(L["Background"], { key = "background", label = L["Background"] })),
    }) do
        for _, row in ipairs(list) do
            local c = checks[row.path:sub(#LOOK + 1)] or {}
            row.instance, row.validate, row.normalize = "pad", c.validate, c.normalize
            out[#out + 1] = row
        end
    end
    return out
end

for _, row in ipairs(lookRows()) do ROWS[#ROWS + 1] = row end

-- Every member row's reaction: Library.Touch announces the write (LIBRARY_CHANGED, the pads' rebuild),
-- naming the row's path as the field. A color stays only on a glyph: an icon write that leaves a
-- colored member without one clears its color through the seam in the same act (Library.Batch, one
-- LIBRARY_CHANGED).
-- A group that takes a parent leaves every surface in the same act (Library.SettleParent).
local ICON_ROWS = { ["callout.icon"] = true, ["group.icon"] = true }
for _, row in ipairs(ROWS) do
    local kind, path = row.instance, row.path
    row.onChange = function(_, id) Lib.Touch(kind, id, path) end
    if path == "group.parent" then
        row.onChange = function(_, id)
            Lib.Batch(function()
                Lib.SettleParent(id)
                Lib.Touch(kind, id, path)
            end)
        end
    end
    if ICON_ROWS[path] then
        row.onChange = function(value, id)
            local m = Lib.Member(kind, id)
            if not (m and m.iconColor and not Lib.IsGlyph(value)) then return Lib.Touch(kind, id, path) end
            Lib.Batch(function()
                NS.SchemaRuntime.Set(kind .. ".iconColor", false, id)
                Lib.Touch(kind, id, path)
            end)
        end
    end
end

NS.SchemaRuntime.AddRows(ROWS)
