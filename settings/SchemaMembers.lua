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
-- check; member rows are no AceDB default. Two row types are structured (a pad's or a dial's
-- point, a group's When): their pages draw their own
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
    badColor  = L["A color is red, green and blue, and optionally alpha, each from 0 to 1."],
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
    if NS.Resolver.ID_ROWS[row] then return L["an instance id (a whole number)"] end
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
-- `up` (Upward) is retired: migration step 4 and Share's import alias read it as rightUp (B2).
local GROWTH = choices({ { "right", L["Right and down"] }, { "left", L["Left and down"] },
    { "rightUp", L["Right and up"] }, { "leftUp", L["Left and up"] } })
local STYLE = choices({ { "iconLabel", L["Icon and label"] }, { "icon", L["Icon only"] }, { "label", L["Label only"] } })
local VISIBILITY = choices({ { "always", L["Always"] }, { "inCombat", L["Only in combat"] },
    { "outOfCombat", L["Only out of combat"] }, { "whenActive", L["When a group is active"] }, { "never", L["Never"] } })
local FADE = choices({ { "none", L["Never"] }, { "outOfCombat", L["Out of combat"] }, { "mouseover", L["Until the mouse is over it"] } })
local MODE = choices({ { "categories", L["Categories"] }, { "flat", L["Flat"] } })
local OPEN_AT = choices({ { "center", L["At its place"] }, { "cursor", L["At the cursor"] } })
local SLICES = { { value = NS.DialLayout.AUTO, text = L["Auto"] } }
for _, n in ipairs({ 4, 6, 8, 12 }) do SLICES[#SLICES + 1] = { value = n, text = tostring(n) } end

local ROWS = {
    -- A callout's rows (spec §13.1, as amended 2026-10-17): addressed by id alone, drawn by the callout
    -- popup against its draft; `page` is only their /qc list heading. Name and text have no default: a
    -- reset never blanks them.
    { path = "callout.name", instance = "callout", type = "string", dialogControl = "EditBox",
      maxLetters = Lib.NAME_MAX, page = "callouts", group = GENERAL, label = L["Name"],
      desc = L["What the button and the lists call this callout. Press Enter to apply."],
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

    -- Pad page (spec §10.2, §10.3, §13.1).
    { path = "pad.name", instance = "pad", type = "string", dialogControl = "EditBox", maxLetters = Lib.NAME_MAX,
      page = "pads", group = GENERAL, label = L["Name"],
      desc = L["What the drag strip and the lists call this pad. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "pad.enabled", instance = "pad", type = "bool", default = T.pad.enabled,
      page = "pads", group = GENERAL, label = L["Enabled"],
      desc = L["Draw this pad. A disabled pad keeps its groups and its settings."] },
    -- Visibility, Fade and Faded alpha (`pad.look.*`, the paths kept) under General's Visibility heading
    -- (owner request, 2026-10-20; on the Window tab before): General's first row stays Name, so the
    -- options library still draws General first.
    { path = "pad.look.visibility", instance = "pad", type = "string", default = T.pad.look.visibility,
      values = VISIBILITY, page = "pads", group = GENERAL, subgroup = L["Visibility"], label = L["Visibility"],
      desc = L["When this pad shows. General visibility applies on top. When a group is active is decided at the last change out of combat."],
      validate = oneOf(VISIBILITY) },
    { path = "pad.look.fade", instance = "pad", type = "string", default = T.pad.look.fade,
      values = FADE, page = "pads", group = GENERAL, subgroup = L["Visibility"], label = L["Fade"],
      desc = L["Fade the pad out of combat, or until the mouse is over it."],
      validate = oneOf(FADE) },
    { path = "pad.look.fadeAlpha", instance = "pad", type = "number", default = T.pad.look.fadeAlpha,
      min = 0, max = 1, step = 0.05, page = "pads", group = GENERAL, subgroup = L["Visibility"], label = L["Faded alpha"],
      desc = L["How visible a faded pad is."], validate = NUMBER, normalize = clamp(0, 1) },
    { path = "pad.groupsAs", instance = "pad", type = "string", default = T.pad.groupsAs, values = GROUPS_AS,
      page = "pads", group = L["Groups"], label = L["Show groups as"],
      desc = L["Sections under small headings, one merged list, or one group at a time (the mouse wheel over the pad switches; not in combat)."],
      validate = oneOf(GROUPS_AS) },
    { path = "pad.layout.orientation", instance = "pad", type = "string", default = T.pad.layout.orientation,
      values = ORIENTATION, page = "pads", group = L["Layout"], label = L["Orientation"],
      desc = L["One row, one column, or a grid."], validate = oneOf(ORIENTATION) },
    { path = "pad.layout.columns", instance = "pad", type = "number", default = T.pad.layout.columns,
      min = 1, max = 12, step = 1, page = "pads", group = L["Layout"], label = L["Grid columns"],
      desc = L["Buttons per row when the orientation is Grid."],
      disabledIf = function() return NS.SchemaRuntime.Get("pad.layout.orientation") ~= "grid" end,
      validate = NUMBER, normalize = clamp(1, 12, true) },
    { path = "pad.layout.growth", instance = "pad", type = "string", default = T.pad.layout.growth,
      values = GROWTH, page = "pads", group = L["Layout"], label = L["Growth"],
      desc = L["Which way the buttons fill from the pad's anchor."], validate = oneOf(GROWTH) },
    { path = "pad.layout.style", instance = "pad", type = "string", default = T.pad.layout.style,
      values = STYLE, page = "pads", group = L["Layout"], label = L["Button style"],
      desc = L["Icon only puts the callout's name in its tooltip."], validate = oneOf(STYLE) },
    { path = "pad.layout.scale", instance = "pad", type = "number", default = T.pad.layout.scale,
      min = 0.5, max = 2, step = 0.05, page = "pads", group = L["Layout"], label = L["Scale"],
      desc = L["This pad's size, on top of the master scale."],
      validate = NUMBER, normalize = clamp(0.5, 2) },
    { path = "pad.layout.spacing", instance = "pad", type = "number", default = T.pad.layout.spacing,
      min = 0, max = 20, step = 1, page = "pads", group = L["Layout"], label = L["Spacing"],
      desc = L["Pixels between buttons."], validate = NUMBER, normalize = clamp(0, 20, true) },
    -- Position's default is false, the default place, so `/qc reset pad.point` brings a pad back; the
    -- page's Defaults keeps the position (settings/Schema.lua resetExempt), as its tooltip says.
    { path = "pad.point", instance = "pad", type = "point", default = false,
      page = "pads", group = L["Layout"], label = L["Position"],
      desc = L["Where the pad sits. Drag it while unlocked, or type an offset."],
      validate = check(Lib.ValidPoint) },

    -- Dial page (spec §11, §13.1). Relaxed is the only interaction in v0.1.0, so there is no
    -- interaction, delay or tap-action row (Quick mode brings them with the C7 upgrade), and no depth
    -- row (owner ruling R5: depth is §11.3's limit, warned about on the Groups tab).
    { path = "dial.name", instance = "dial", type = "string", dialogControl = "EditBox", maxLetters = Lib.NAME_MAX,
      page = "dials", group = GENERAL, label = L["Name"],
      desc = L["What the lists and the dial's first ring call this dial. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "dial.enabled", instance = "dial", type = "bool", default = T.dial.enabled,
      page = "dials", group = GENERAL, label = L["Enabled"],
      desc = L["Build this dial. A disabled dial keeps its groups and settings, and its key opens nothing."] },
    { path = "dial.mode", instance = "dial", type = "string", default = T.dial.mode, values = MODE,
      page = "dials", group = L["Groups"], label = L["Show groups as"],
      desc = L["Categories: the first ring holds your groups and a click opens one. Flat: the first ring holds callouts, highest group first, with More for the rest."],
      validate = oneOf(MODE) },
    { path = "dial.slices", instance = "dial", type = "number", default = T.dial.slices, values = SLICES,
      page = "dials", group = L["Wheel"], label = L["Wedges per ring"],
      desc = L["How many wedges a ring has. Auto spreads a ring's wedges evenly around it, up to 12. A ring with more turns pages with the arrows under the dial. A ring that opens other rings has at most 8."],
      validate = oneOf(SLICES) },
    { path = "dial.radius", instance = "dial", type = "number", default = T.dial.radius,
      min = NS.DialLayout.RADIUS_MIN, max = NS.DialLayout.RADIUS_MAX, step = 2,
      page = "dials", group = L["Wheel"], label = L["Ring radius"],
      desc = L["How big the dial is, in pixels: at the default 100, the icons' distance from its middle. The disc grows with it, and automatic icon offset and size follow it."],
      validate = NUMBER, normalize = clamp(NS.DialLayout.RADIUS_MIN, NS.DialLayout.RADIUS_MAX, true) },
    { path = "dial.openAt", instance = "dial", type = "string", default = T.dial.openAt, values = OPEN_AT,
      page = "dials", group = L["Wheel"], label = L["Open at"],
      desc = L["Where the dial opens: at its place (set below), or wherever the cursor is."],
      validate = oneOf(OPEN_AT) },
    -- Position's default is false (the default place), so `/qc reset dial.point` reaches it; the page's
    -- Defaults keeps it (settings/Schema.lua resetExempt), as its tooltip says. As the pad.point row.
    -- A dial has no key row: its key is WoW's own binding (Options -> Keybindings, modules/Dial.lua).
    { path = "dial.point", instance = "dial", type = "point", default = false,
      page = "dials", group = L["Wheel"], label = L["Position"],
      desc = L["Where the dial opens at its place. Type an offset from the middle of the screen."],
      validate = check(Lib.ValidPoint) },
}

-- ── a pad's window tabs (spec §10.3, §19 row 5; options-ui-§16, §17) ───────────────────────────

-- The font blocks, the border blocks and the background swatches with their class-color companions,
-- each COMPOSED by the options library (a hand-written copy is anti-pattern #73) and then stamped as
-- pad member rows: the instance, a check per leaf, and the defaults Library ships (Library.TEMPLATES).
-- The class color is the player's (`classColorSource = "player"`, the composer's default): a pad's
-- text is about no unit. A background is not a bar, so it takes a swatch and its companion only. On
-- a degraded load the composers are hollow and these rows are absent.
--
-- The Window tab (the Look tab before) became three tabs on 2026-10-20 (owner request), each under
-- its own headings: Pad header (`pad.header.*`: Size, its Header height; Font; Background; Border),
-- Section header (`pad.section.*`: Size, its height, 0 automatic; Font, the section titles'; and the
-- Background and Border of the band behind each title) and Window (`pad.look.*`, the stored key kept:
-- Background; Border; no font, the owner's call). It was Main window, with Visibility, Fade and Faded
-- alpha, until those moved to General (owner request, 2026-10-20).
--
-- The Buttons tab (`pad.button.*`, 2026-10-20; `pad.chip.*` until the rename) styles the buttons themselves: Size (Button width, moved from
-- Layout, and Button height, 0 automatic), Color (the button's background), Border, Font (the buttons'
-- labels only) and Glow (off by default: a LibCustomGlow effect around the whole button, in one of the
-- Icons tab's four styles, at that tab's knob defaults).

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

-- The checks every composed leaf takes, by its leaf name, whichever block it is in.
local function composedChecks(O)
    local flags = O.FONT_FLAGS or {}
    local color = { validate = check(isColor), normalize = fourChannels }
    return {
        font = { validate = check(isName) },
        fontSize = { validate = NUMBER, normalize = clamp(6, 32, true) },
        fontColor = color,
        useClassColorFont = { validate = BOOL },
        fontFlags = { validate = check(function(v) return type(v) == "string" and flags[v] ~= nil, "badChoice" end) },
        fontShadow = { validate = BOOL },
        borderStyle = { validate = check(isName) },
        borderSize = { validate = NUMBER, normalize = clamp(0, 16, true) },
        borderColor = color,
        useClassColorBorder = { validate = BOOL },
        background = color,
        useClassColorBackground = { validate = BOOL },
    }
end

-- One composed block's rows stamped as pad member rows: `prefix` names the pad's table
-- ("pad.look.", "pad.header.", "pad.section.", "pad.button."), `defaults` that table's shipped values.
local function stampBlock(out, list, prefix, checks, instance)
    for _, row in ipairs(list) do
        local c = checks[row.path:sub(#prefix + 1)] or {}
        row.instance, row.validate, row.normalize = instance or "pad", c.validate, c.normalize
        out[#out + 1] = row
    end
end

local function blockSpec(prefix, group, subgroup, defaults, extra)
    local spec = { prefix = prefix, page = prefix:match("^dial") and "dials" or "pads", group = group,
        subgroup = subgroup, defaults = defaults }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return spec
end

-- The three tabs, in strip order: the options library orders a page's tabs by each group's first
-- row, so these rows come after Layout's and before the Buttons tab's.
local PAD_HEADER, SECTION_HEADER, WINDOW = L["Pad header"], L["Section header"], L["Window"]
local LOOK, HEAD, SECT = "pad.look.", "pad.header.", "pad.section."
local HEADER_H, SECTION_H = NS.PadDefaults.HEADER_H, NS.PadDefaults.SECTION_H

-- One styled tab's Font (when `font`), Background and Border blocks, each under its own heading.
local function styleBlocks(out, O, checks, prefix, group, defaults, font)
    if font then stampBlock(out, O.FontGroup(blockSpec(prefix, group, L["Font"], defaults)), prefix, checks) end
    stampBlock(out, O.ColorPair(blockSpec(prefix, group, L["Background"], defaults,
        { key = "background", label = L["Background"] })), prefix, checks)
    stampBlock(out, O.BorderGroup(blockSpec(prefix, group, L["Border"], defaults)), prefix, checks)
end

local function windowRows()
    local O = NS.addon.Settings.Helpers
    local checks = composedChecks(O)
    local SIZE = L["Size"]
    local out = {}
    out[1] = { path = HEAD .. "height", instance = "pad", type = "number", default = T.pad.header.height,
        min = HEADER_H.min, max = HEADER_H.max, step = 1, page = "pads", group = PAD_HEADER, subgroup = SIZE,
        label = L["Header height"], startsLine = true,
        desc = L["How tall the pad's header row is, in pixels: the row with the situation (World, M+, Raid) and the collapse button."],
        validate = NUMBER, normalize = clamp(HEADER_H.min, HEADER_H.max, true) }
    styleBlocks(out, O, checks, HEAD, PAD_HEADER, T.pad.header, true)
    out[#out + 1] = { path = SECT .. "height", instance = "pad", type = "number", default = T.pad.section.height,
        min = SECTION_H.min, max = SECTION_H.max, step = 1, page = "pads", group = SECTION_HEADER, subgroup = SIZE,
        label = L["Section header height (0 = automatic)"], zeroText = L["Automatic"], startsLine = true,
        desc = L["How tall each section title's row is, in pixels. 0 grows it to hold its font."],
        validate = NUMBER, normalize = clamp(SECTION_H.min, SECTION_H.max, true) }
    styleBlocks(out, O, checks, SECT, SECTION_HEADER, T.pad.section, true)
    -- Window: its Background and Border; no font (Visibility, Fade and Faded alpha are on General).
    styleBlocks(out, O, checks, LOOK, WINDOW, T.pad.look, false)
    return out
end

for _, row in ipairs(windowRows()) do ROWS[#ROWS + 1] = row end

local BUTTON, BUTTONP = L["Buttons"], "pad.button."
local BUTTON_H = NS.PadDefaults.BUTTON_H

-- The shine overlay's looks (modules/Shine.lua NS.Shine.LOOKS, in its order) by name.
local SHINE_LABEL = { none = L["None"], gloss = L["Gloss cap"], glossfade = L["Gloss fade"], orb = L["Glass orb"],
    frost = L["Frosted glass"], fluid = L["Fluid glass"], bevel = L["Bevel"], rim = L["Rim light"] }
local SHINE_LOOK = {}
for i, look in ipairs(NS.Shine.LOOKS) do SHINE_LOOK[i] = { value = look, text = SHINE_LABEL[look] or look } end

--- A Shine heading's rows (shine overlay, 2026-10-21): the look, its Strength (0 to 100 percent, step
--- 5), the tint and Fluid glass's two bloom colors, each a composed swatch with its class-color
--- companion. `spec` names the block: `prefix` ("pad.button."), `instance`, `page`, `tab` and the
--- shipped `defaults` table. Strength, the tint and the blooms gray out while the look is None, and the
--- blooms unless it is Fluid glass (as the pointer rows do while Show pointer is off).
local function shineRows(O, checks, spec)
    local prefix, def, SHINE = spec.prefix, spec.defaults, L["Shine"]
    for _, k in ipairs({ "shineTint", "shineBloomA", "shineBloomB" }) do checks[k] = checks.background end
    for _, k in ipairs({ "useClassColorShineTint", "useClassColorShineBloomA", "useClassColorShineBloomB" }) do
        checks[k] = { validate = BOOL }
    end
    local function lookNow() return NS.SchemaRuntime.Get(prefix .. "shineLook") or def.shineLook end
    local function off() return lookNow() == "none" end
    local function notFluid() return lookNow() ~= "fluid" end
    local function base(r)
        r.instance, r.page, r.group, r.subgroup = spec.instance, spec.page, spec.tab, SHINE
        return r
    end
    local out = {
        base({ path = prefix .. "shineLook", type = "string", default = def.shineLook, values = SHINE_LOOK,
            label = L["Shine look"], startsLine = true,
            desc = L["A glossy overlay: Gloss cap, Gloss fade, Glass orb, Frosted glass, Fluid glass, Bevel or Rim light. None draws none."],
            validate = oneOf(SHINE_LOOK) }),
        base({ path = prefix .. "shineStrength", type = "number", default = def.shineStrength, min = 0, max = 100,
            step = 5, label = L["Shine strength"], disabledIf = off,
            desc = L["How strong the shine is, from 0 to 100 percent."], validate = NUMBER,
            normalize = clamp(0, 100, true) }),
    }
    local pairs3 = { { "shineTint", L["Shine tint"], "useClassColorShineTint", off },
        { "shineBloomA", L["Bloom color A"], "useClassColorShineBloomA", notFluid },
        { "shineBloomB", L["Bloom color B"], "useClassColorShineBloomB", notFluid } }
    for _, p in ipairs(pairs3) do
        local rows = {}
        stampBlock(rows, O.ColorPair(blockSpec(prefix, spec.tab, SHINE, def,
            { key = p[1], label = p[2], companionKey = p[3] })), prefix, checks, spec.instance)
        for _, r in ipairs(rows) do
            r.disabledIf = p[4]
            out[#out + 1] = r
        end
    end
    return out
end

local function buttonRows()
    local O = NS.addon.Settings.Helpers
    local checks = composedChecks(O)
    checks.glowColor = checks.background
    checks.useClassColorGlow = { validate = BOOL }
    local cdef = T.pad.button
    local SIZE, COLOR, GLOW = L["Size"], L["Color"], L["Glow"]
    local function glowOff() return NS.SchemaRuntime.Get(BUTTONP .. "glowEnabled") ~= true end
    local styles = choices(NS.addon.Settings.GLOW_STYLES)
    local function row(subgroup, r)
        r.instance, r.page, r.group, r.subgroup = "pad", "pads", BUTTON, subgroup
        return r
    end
    local out = {
        row(SIZE, { path = BUTTONP .. "width", type = "number", default = cdef.width, min = 1, max = 300, step = 1,
            label = L["Button width"], startsLine = true, desc = L["How wide a labeled button is. An icon-only button stays square around its icon."],
            validate = NUMBER, normalize = clamp(1, 300, true) }),
        row(SIZE, { path = BUTTONP .. "height", type = "number", default = cdef.height, min = BUTTON_H.min,
            max = BUTTON_H.max, step = 1, label = L["Button height (0 = automatic)"], zeroText = L["Automatic"],
            desc = L["How tall a labeled button is, in pixels. 0 grows it to hold its font and its icon. An icon-only button stays square around its icon."],
            validate = NUMBER, normalize = clamp(BUTTON_H.min, BUTTON_H.max, true) }),
    }
    stampBlock(out, O.ColorPair(blockSpec(BUTTONP, BUTTON, COLOR, cdef, { key = "background", label = L["Background"] })),
        BUTTONP, checks)
    stampBlock(out, O.BorderGroup(blockSpec(BUTTONP, BUTTON, L["Border"], cdef)), BUTTONP, checks)
    stampBlock(out, O.FontGroup(blockSpec(BUTTONP, BUTTON, L["Font"], cdef)), BUTTONP, checks)
    out[#out + 1] = row(GLOW, { path = BUTTONP .. "glowEnabled", type = "bool", default = cdef.glowEnabled,
        label = L["Glow"], desc = L["Draw a glow around each button."], validate = BOOL, startsLine = true })
    out[#out + 1] = row(GLOW, { path = BUTTONP .. "glowType", type = "string", default = cdef.glowType, values = styles,
        label = L["Glow style"], desc = L["How the glow looks."], validate = oneOf(styles), disabledIf = glowOff })
    stampBlock(out, O.ColorPair(blockSpec(BUTTONP, BUTTON, GLOW, cdef, { key = "glowColor",
        companionKey = "useClassColorGlow", label = L["Glow color"] })), BUTTONP, checks)
    for _, r in ipairs(shineRows(O, checks, { prefix = BUTTONP, instance = "pad", page = "pads", tab = BUTTON,
        defaults = cdef })) do
        out[#out + 1] = r
    end
    return out
end

for _, row in ipairs(buttonRows()) do ROWS[#ROWS + 1] = row end

-- The Dial page's Slices tab (2026-10-21): each slice's fill, the Slice gap between them (dial polish,
-- which retired the Border heading), the hovered slice's fill and the Shine heading (shineRows, shine
-- overlay 2026-10-21); then the Hub tab (dial polish,
-- 2026-10-21: the Hub and Pointer headings, which sat on Slices until then, their paths kept): the
-- Hub (hubRows) and the pointer (`dial.slice.pointer*`). Each color a composed swatch with its
-- class-color companion, stamped as dial member rows. The options library orders a page's tabs by
-- each group's first row, so these rows come after Wheel's and before Paging's, Slices' first, and
-- the Hub tab follows Slices.
local SLICES_TAB, HUB_TAB, SLICEP = L["Slices"], L["Hub"], "dial.slice."

-- The Hub tab's Hub heading (dial polish, 2026-10-21; `dial.hub.*`, defaults/PadStyle.lua's
-- DialHub): the style, the backdrop's size (the hub's geometry) and the circle's, the ring styles'
-- line width, then the backdrop's color, its border and the circle's color, each a composed swatch
-- with its class-color companion (opacity is the swatch's alpha, as every color row's).
local HUBP = "dial.hub."
local HUB_STYLE = choices({ { "solid", L["Solid circle"] }, { "ring", L["Hollow ring"] }, { "target", L["Target"] },
    { "rimmed", L["Rimmed disc"] } })
local function hubRows(O, checks)
    local hdef, HUB = T.dial.hub, L["Hub"]
    local function solid() return (NS.SchemaRuntime.Get(HUBP .. "style") or hdef.style) == "solid" end
    local function size(key, label, lo, hi, desc, extra)
        local r = { path = HUBP .. key, instance = "dial", type = "number", default = hdef[key], min = lo, max = hi,
            step = 1, page = "dials", group = HUB_TAB, subgroup = HUB, label = label, desc = desc,
            validate = NUMBER, normalize = clamp(lo, hi, true) }
        for k, v in pairs(extra or {}) do r[k] = v end
        return r
    end
    local out = { { path = HUBP .. "style", instance = "dial", type = "string", default = hdef.style, values = HUB_STYLE,
        page = "dials", group = HUB_TAB, subgroup = HUB, label = L["Hub style"], startsLine = true,
        desc = L["What the middle of the dial draws: a filled circle, a hollow ring, a ring with a dot, or a filled circle on a rimmed disc."],
        validate = oneOf(HUB_STYLE) },
      size("size", L["Hub size"], 24, 80,
        L["How wide the middle of the dial is, in pixels. The slices and the pointer start at its edge."]),
      size("circleSize", L["Circle size"], 4, 60, L["How wide the circle on the hub is, in pixels."], { startsLine = true }),
      size("lineWidth", L["Line width"], 1, 6, L["How thick the hollow ring is, in pixels."], { disabledIf = solid }) }
    local function pair(key, label, companion)
        stampBlock(out, O.ColorPair(blockSpec(HUBP, HUB_TAB, HUB, hdef,
            { key = key, label = label, companionKey = companion })), HUBP, checks, "dial")
    end
    pair("background", L["Backdrop color"], "useClassColorBackground")
    out[#out + 1] = size("borderSize", L["Hub border size"], 0, 6,
        L["How thick the rim around the hub is, in pixels. 0 draws none; Rimmed disc always draws one."],
        { startsLine = true })
    pair("borderColor", L["Hub border color"], "useClassColorBorder")
    pair("circleColor", L["Circle color"], "useClassColorCircle")
    return out
end

local function sliceRows()
    local O = NS.addon.Settings.Helpers
    local checks = composedChecks(O)
    checks.highlight, checks.pointerColor = checks.background, checks.background
    checks.useClassColorHighlight, checks.useClassColorPointer = { validate = BOOL }, { validate = BOOL }
    local sdef = T.dial.slice
    local POINTER = L["Pointer"]
    local function pointerOff() return NS.SchemaRuntime.Get(SLICEP .. "pointerShow") == false end
    local function row(subgroup, r, tab)
        r.instance, r.page, r.group, r.subgroup = "dial", "dials", tab or SLICES_TAB, subgroup
        return r
    end
    local function pair(subgroup, key, label, companion, tab)
        local out = {}
        stampBlock(out, O.ColorPair(blockSpec(SLICEP, tab or SLICES_TAB, subgroup, sdef,
            { key = key, label = label, companionKey = companion })), SLICEP, checks, "dial")
        return out
    end
    local out = pair(L["Background"], "background", L["Slice color"])
    out[#out + 1] = row(L["Gap"], { path = SLICEP .. "gap", type = "number", default = sdef.gap,
        min = 0, max = 20, step = 1, label = L["Slice gap"], startsLine = true,
        desc = L["The space between slices, in pixels. 0 draws them touching."],
        validate = NUMBER, normalize = clamp(0, 20, true) })
    for _, r in ipairs(pair(L["Highlight"], "highlight", L["Highlight color"])) do out[#out + 1] = r end
    for _, r in ipairs(shineRows(O, checks, { prefix = SLICEP, instance = "dial", page = "dials", tab = SLICES_TAB,
        defaults = sdef })) do
        out[#out + 1] = r
    end
    checks.circleColor, checks.useClassColorCircle = checks.background, { validate = BOOL }
    for _, r in ipairs(hubRows(O, checks)) do out[#out + 1] = r end
    out[#out + 1] = row(POINTER, { path = SLICEP .. "pointerShow", type = "bool", default = sdef.pointerShow,
        label = L["Show pointer"], startsLine = true,
        desc = L["Draw the pointer in the middle of the dial that turns toward the cursor."], validate = BOOL }, HUB_TAB)
    out[#out + 1] = row(POINTER, { path = SLICEP .. "pointerSize", type = "number", default = sdef.pointerSize,
        min = 10, max = 48, step = 1, label = L["Pointer size"], disabledIf = pointerOff,
        desc = L["How big the pointer is, in pixels."], validate = NUMBER, normalize = clamp(10, 48, true) }, HUB_TAB)
    out[#out + 1] = row(POINTER, { path = SLICEP .. "pointerOffset", type = "number", default = sdef.pointerOffset,
        min = 0, max = 150, step = 1, label = L["Pointer offset (0 = automatic)"], zeroText = L["Automatic"],
        disabledIf = pointerOff, startsLine = true,
        desc = L["How far the pointer sits from the middle of the dial, in pixels. 0 puts it just outside the middle button."],
        validate = NUMBER, normalize = clamp(0, 150, true) }, HUB_TAB)
    for _, r in ipairs(pair(POINTER, "pointerColor", L["Pointer color"], "useClassColorPointer", HUB_TAB)) do
        r.disabledIf = pointerOff
        out[#out + 1] = r
    end
    return out
end

for _, row in ipairs(sliceRows()) do ROWS[#ROWS + 1] = row end

-- The Dial page's Paging tab (2026-10-21): a paged ring's row under the dial. Where it sits, the
-- arrows (size, spacing, chevron and plate colors) and the page indicators (sizes, spacing, the
-- current and other pages' colors, then their background and border: dial polish, 2026-10-21), each
-- color a composed swatch with its class-color companion; after the Slices rows, so the tab follows
-- Slices.
local PAGING, PAGEP = L["Paging"], "dial.page."
local function pagingRows()
    local O = NS.addon.Settings.Helpers
    local checks = composedChecks(O)
    for _, k in ipairs({ "arrowColor", "plateColor", "currentColor", "dotColor", "dotBackColor", "dotBorderColor" }) do
        checks[k] = checks.background
    end
    for _, k in ipairs({ "useClassColorArrow", "useClassColorPlate", "useClassColorCurrent", "useClassColorDot",
        "useClassColorDotBack", "useClassColorDotBorder" }) do
        checks[k] = { validate = BOOL }
    end
    local pdef = T.dial.page
    local ARROWS, INDICATOR = L["Arrows"], L["Page indicator"]
    local function size(subgroup, key, label, lo, hi, desc, first)
        return { path = PAGEP .. key, instance = "dial", type = "number", default = pdef[key], min = lo, max = hi,
            step = 1, page = "dials", group = PAGING, subgroup = subgroup, label = label, startsLine = first,
            desc = desc, validate = NUMBER, normalize = clamp(lo, hi, true) }
    end
    local function pair(subgroup, key, label, companion)
        local out = {}
        stampBlock(out, O.ColorPair(blockSpec(PAGEP, PAGING, subgroup, pdef,
            { key = key, label = label, companionKey = companion })), PAGEP, checks, "dial")
        return out
    end
    local out = {
        size(L["Position"], "offset", L["Offset"], 0, 80,
            L["How far under the dial's labels the arrows and page indicators sit, in pixels."], true),
        size(ARROWS, "arrowSize", L["Arrow size"], 12, 48, L["How big each page arrow is, in pixels."], true),
        size(ARROWS, "arrowGap", L["Arrow spacing"], 0, 60,
            L["How far the arrows stand from the page indicators, in pixels."]),
    }
    for _, r in ipairs(pair(ARROWS, "arrowColor", L["Arrow color"], "useClassColorArrow")) do out[#out + 1] = r end
    for _, r in ipairs(pair(ARROWS, "plateColor", L["Arrow background"], "useClassColorPlate")) do out[#out + 1] = r end
    out[#out + 1] = size(INDICATOR, "dotSize", L["Dot size"], 2, 20,
        L["How big each other page's dot is, and how tall the current page's pill, in pixels."], true)
    out[#out + 1] = size(INDICATOR, "pillWidth", L["Current page width"], 2, 60,
        L["How wide the current page's pill is, in pixels. Set it to the dot size for a plain dot."])
    out[#out + 1] = size(INDICATOR, "dotGap", L["Dot spacing"], 0, 30, L["The gap between page indicators, in pixels."], true)
    for _, r in ipairs(pair(INDICATOR, "currentColor", L["Current page color"], "useClassColorCurrent")) do out[#out + 1] = r end
    for _, r in ipairs(pair(INDICATOR, "dotColor", L["Other pages color"], "useClassColorDot")) do out[#out + 1] = r end
    local function backOff() return NS.SchemaRuntime.Get(PAGEP .. "dotBackShow") == false end
    local function borderOff() return NS.SchemaRuntime.Get(PAGEP .. "dotBorder") == 0 end
    out[#out + 1] = { path = PAGEP .. "dotBackShow", instance = "dial", type = "bool", default = pdef.dotBackShow,
        page = "dials", group = PAGING, subgroup = INDICATOR, label = L["Show indicator background"], startsLine = true,
        desc = L["Draw a rounded background behind the page indicators, so they read on a busy scene."],
        validate = BOOL }
    for _, r in ipairs(pair(INDICATOR, "dotBackColor", L["Indicator background"], "useClassColorDotBack")) do
        r.disabledIf = backOff
        out[#out + 1] = r
    end
    local padding = size(INDICATOR, "dotBackPadding", L["Background padding"], 0, 20,
        L["How far the background reaches past the page indicators, in pixels."], true)
    padding.disabledIf = backOff
    out[#out + 1] = padding
    local border = size(INDICATOR, "dotBorder", L["Dot border (0 = none)"], 0, 4,
        L["How wide the outline around each page indicator is, in pixels. 0 draws none."], true)
    border.zeroText = L["None"]
    out[#out + 1] = border
    for _, r in ipairs(pair(INDICATOR, "dotBorderColor", L["Dot border color"], "useClassColorDotBorder")) do
        r.disabledIf = borderOff
        out[#out + 1] = r
    end
    return out
end

for _, row in ipairs(pagingRows()) do ROWS[#ROWS + 1] = row end

-- The Dial page's Slice labels tab (dial rework, 2026-10-21; the Labels tab until dial polish
-- renamed it, its `dial.label.*` paths kept): Show labels, then the composed Font block (as the
-- Buttons tab's), stamped as dial member rows, then where the dial's tooltip goes; before the Group
-- labels rows and the dial's Icons rows, so the tabs sit between Paging and Icons.
local LABELS, LABELP = L["Slice labels"], "dial.label."
local TIP_SIDE = choices({ { "top", L["Above"] }, { "bottom", L["Below"] }, { "left", L["Left"] }, { "right", L["Right"] } })
local function labelRows()
    local O = NS.addon.Settings.Helpers
    local ldef = T.dial.label
    local function hidden() return NS.SchemaRuntime.Get(LABELP .. "show") == false end
    local out = { { path = LABELP .. "show", instance = "dial", type = "bool", default = ldef.show,
        page = "dials", group = LABELS, label = L["Show labels"], startsLine = true,
        desc = L["Write each wedge's name outside the dial. Off shows the icons alone; the tooltip still names them."],
        validate = BOOL },
      { path = LABELP .. "offset", instance = "dial", type = "number", default = ldef.offset,
        min = 0, max = 300, step = 1, page = "dials", group = LABELS, label = L["Label offset (0 = automatic)"],
        zeroText = L["Automatic"], disabledIf = hidden,
        desc = L["How far each label sits from the middle of the dial, in pixels. 0 puts it just outside the dial."],
        validate = NUMBER, normalize = clamp(0, 300, true) } }
    local font = {}
    stampBlock(font, O.FontGroup(blockSpec(LABELP, LABELS, L["Font"], ldef)), LABELP, composedChecks(O), "dial")
    for _, row in ipairs(font) do
        row.disabledIf = hidden
        out[#out + 1] = row
    end
    local TIP = L["Tooltip"]
    out[#out + 1] = { path = LABELP .. "tooltipSide", instance = "dial", type = "string", default = ldef.tooltipSide,
        values = TIP_SIDE, page = "dials", group = LABELS, subgroup = TIP, label = L["Tooltip side"], startsLine = true,
        desc = L["Which side of the dial a wedge's tooltip shows on. It always sits outside the dial."],
        validate = oneOf(TIP_SIDE) }
    out[#out + 1] = { path = LABELP .. "tooltipOffset", instance = "dial", type = "number", default = ldef.tooltipOffset,
        min = 0, max = 80, step = 1, page = "dials", group = LABELS, subgroup = TIP, label = L["Tooltip offset"],
        desc = L["How far the tooltip sits from the dial's title, labels or page arrows, in pixels."],
        validate = NUMBER, normalize = clamp(0, 80, true) }
    return out
end

for _, row in ipairs(labelRows()) do ROWS[#ROWS + 1] = row end

-- The Dial page's Group labels tab (dial polish, 2026-10-21): the ring's title above the dial. Show
-- group labels, then the composed Font block under `dial.title.*`, grayed out while off, as the slice
-- labels' block; after the Slice labels rows, so its tab follows that one.
local TITLES, TITLEP = L["Group labels"], "dial.title."
local function titleRows()
    local O = NS.addon.Settings.Helpers
    local tdef = T.dial.title
    local function hidden() return NS.SchemaRuntime.Get(TITLEP .. "show") == false end
    local out = { { path = TITLEP .. "show", instance = "dial", type = "bool", default = tdef.show,
        page = "dials", group = TITLES, label = L["Show group labels"], startsLine = true,
        desc = L["Write the ring's name above the dial."], validate = BOOL } }
    local font = {}
    stampBlock(font, O.FontGroup(blockSpec(TITLEP, TITLES, L["Font"], tdef)), TITLEP, composedChecks(O), "dial")
    for _, row in ipairs(font) do
        row.disabledIf = hidden
        out[#out + 1] = row
    end
    return out
end

for _, row in ipairs(titleRows()) do ROWS[#ROWS + 1] = row end

-- The Icons tab's rows (B9, settings/SchemaIcons.lua), with these checks: a pad's after its window and
-- Button rows, a dial's after its Group labels rows, so each editor's Icons tab sits there. A dial's
-- Icons tab opens with Icon offset (dial polish, 2026-10-21: it was a Wheel row; its path is kept),
-- the first row under Size and crop. It is spliced here, not listed with the Wheel rows, because the
-- options library orders a page's tabs by each group's first row.
local ICON_OFFSET = { path = "dial.iconOffset", instance = "dial", type = "number", default = T.dial.iconOffset,
    min = 0, max = 250, step = 1, zeroText = L["Automatic"],
    page = "dials", group = L["Icons"], subgroup = L["Size and crop"], label = L["Icon offset (0 = automatic)"],
    desc = L["How far each icon sits from the middle of the dial, in pixels. 0 keeps each icon in the same place in its slice at any ring radius: on the ring radius at the default 100, a little inside it on a bigger wheel. The disc keeps its size."],
    validate = NUMBER, normalize = clamp(0, 250, true) }
do
    local C = { check = check, choices = choices, oneOf = oneOf, clamp = clamp, NUMBER = NUMBER, BOOL = BOOL,
        color = check(isColor), name = check(isName), fourChannels = fourChannels }
    local IconRows = NS.addon.Settings.IconRows
    for _, row in ipairs(IconRows("pad", C)) do ROWS[#ROWS + 1] = row end
    ROWS[#ROWS + 1] = ICON_OFFSET
    for _, row in ipairs(IconRows("dial", C)) do ROWS[#ROWS + 1] = row end
end

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
