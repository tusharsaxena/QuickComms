-- tests/test_layout.lua — item 020, the settings layout (QC-LY, 2026-10-24): every page's rows moved,
-- regrouped and relabeled, never a setting changed (tests/test_schema.lua's layout guard pins that).
-- One case per page or tab group: the General page's Behavior and Defaults, the Groups page's band,
-- General, When and What it sends, the Pad page's strip and tabs, and the Dial page's strip and tabs.
-- Driven headlessly through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open(title, select)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show(title)
    if select then NS.addon.Settings.Editors.Select(select[1], select[2]) end
    return NS, m, P
end

-- The page's tabs in strip order: each group's first row (the options library's rule).
local function strip(NS, page)
    local order, seen = {}, {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage(page)) do
        if row.group and not seen[row.group] then
            seen[row.group] = true
            order[#order + 1] = row.group
        end
    end
    return table.concat(order, ",")
end

-- A tab's rows as "label [subgroup]", in schema order.
local function rowsOf(NS, page, group)
    local out = {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage(page)) do
        if row.group == group then out[#out + 1] = row end
    end
    return out
end

local function paths(rows)
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.path end
    return table.concat(out, ",")
end

-- The draw index of the first widget of `wtype` labeled `label` (nil type: any).
local function at(P, w, wtype, label)
    local target = P.find(w, wtype, label)
    for i, x in ipairs(w) do
        if x == target then return i end
    end
    return nil
end

local function textAt(w, needle)
    for i, x in ipairs(w) do
        if (x.type == "Label" or x.type == "InteractiveLabel") and x.text and x.text:find(needle, 1, true) then
            return i
        end
    end
    return nil
end

local function row(NS, path) return NS.addon.Settings.Editors.Row(path) end

-- The host tabs a page hands the tabbed renderer (Ed.Tabs' opts.tabs), by key.
local function hostTabs(NS, P, page)
    local H = NS.addon.Settings.Helpers
    local render, seen = H.RenderTabbedSchema, {}
    H.RenderTabbedSchema = function(ctx, key, a, b, opts)
        for _, t in ipairs(opts and opts.tabs or {}) do seen[t.key] = t end
        return render(ctx, key, a, b, opts)
    end
    local ok, err = pcall(P.redraw, page)
    H.RenderTabbedSchema = render
    assert(ok, err)
    return seen
end

-- ── General page ────────────────────────────────────────────────────────────────────────────

test("layout: [general] Behavior reads Sending, then Pads and dials, with the new labels (QUI-L01, L02)", function()
    local NS = open("General")
    local rows = rowsOf(NS, "general", "Behavior")
    -- red under: the old order (soloFallback, spamGuard, dropNotes, whyTooltips, lockdownChip, ...)
    assertEqual(paths(rows), "behavior.soloFallback,behavior.spamGuard,behavior.sounds,behavior.dropNotes,"
        .. "behavior.autoPromote,behavior.lockdownChip,behavior.whyTooltips")
    for i = 1, 4 do assertEqual(rows[i].subgroup, "Sending", rows[i].path) end
    for i = 5, 7 do assertEqual(rows[i].subgroup, "Pads and dials", rows[i].path) end
    assertEqual(row(NS, "behavior.autoPromote").label, "Put instance-specific groups first")
    assertEqual(row(NS, "behavior.whyTooltips").label, "Explain why groups show (tooltips)")
    assertEqual(row(NS, "behavior.lockdownChip").label, "Show the LOCKDOWN tag")
end)

test("layout: [general] the header Defaults carries the library's Reset all settings tooltip (QUI-L-new2)", function()
    local NS, _, P = open("General")
    local H = NS.addon.Settings.Helpers
    -- red under: the host's own "Reset every %s setting to its default." lead
    assertEqual(P.ctx("general").panel.defaultsTooltip, H.ResetAllTooltip(H.KEYBINDS_UNCHANGED))
end)

-- ── Groups page ─────────────────────────────────────────────────────────────────────────────

local function groupsPage()
    local NS, m, P = open("Groups")
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.addon.Settings.Editors.Select("group", gid)
    return NS, m, P, gid
end

test("layout: [groups] the band is one row: picker, New group and Preview while editing (QUI-L34)", function()
    local NS, _, P = groupsPage()
    P.redraw("groups")
    local band = P.ctx("groups").qcBand
    local H = NS.addon.Settings.Helpers
    -- red under: G.BAND_H = 72 (two rows)
    assertEqual(NS.addon.Settings.Groups.BAND_H, H.BANNER_H, "the one-row height Pad and Dial use")
    local sum = (band.picker.relativeWidth or 0) + (band.action.relativeWidth or 0) + (band.toggle.relativeWidth or 0)
    assertTrue(sum <= 1.0001, "the three fit one Flow row: " .. sum)
    assertEqual(band.toggle.labelText, "Preview while editing")
end)

test("layout: [groups] General: Name | Enable this group, the icon, Parent group, Duplicate | Delete group, then Restore (QUI-L04, L05, L-new3)", function()
    local _, _, P = groupsPage()
    local w = P.redraw("groups")
    local name, enable = at(P, w, "EditBox", "Name"), at(P, w, "CheckBox", "Enable this group")
    local icon, parent = at(P, w, "Button", "Choose icon…"), at(P, w, "Dropdown", "Parent group")
    local dup, del = at(P, w, "Button", "Duplicate"), at(P, w, "Button", "Delete group")
    local hint = textAt(w, "Adds back the built-in groups and callouts you deleted. Changes nothing you have.")
    local restore = at(P, w, "Button", "Restore built-in groups")
    assertTrue(name and enable and icon and parent and dup and del and hint and restore, "every control drawn")
    assertTrue(name < enable and enable < icon and icon < parent and parent < dup and dup < del, "identity, then placement, then acts")
    assertTrue(del < hint and hint < restore, "the hint above the button it describes")
    -- red under: Inherit when conditions left beside Parent group (QUI-L03)
    assertNil(P.find(w, "CheckBox", "Inherit when conditions"), "Inherit is on When now")
    assertNil(P.find(w, "Button", "Delete"), "the delete names its object")
end)

test("layout: [groups] When opens with Inherit when conditions, above the hint, grayed with no parent (QUI-L03)", function()
    local NS, _, P = groupsPage()
    local w = P.tab("groups", "When")
    local cb = at(P, w, "CheckBox", "Inherit when conditions")
    local hint = textAt(w, "Every condition you set must match.")
    assertTrue(cb ~= nil and hint ~= nil and cb < hint, "Inherit sits above the gray hint")
    assertTrue(w[cb].disabled, "no parent: nothing to inherit")
    assertEqual(row(NS, "group.inheritWhen").group, "When")
    assertTrue(row(NS, "group.inheritWhen").desc:find("Set the parent on the General tab.", 1, true) ~= nil)
    assertEqual(strip(NS, "groups"), "General,When", "the schema strip (Callouts and the listing are host tabs)")
end)

test("layout: [groups] an inheriting group's When says untick Inherit above (QUI-L03)", function()
    local NS, _, P, gid = groupsPage()
    local top = NS.Library.CreateGroup({ name = "Raid night" })
    NS.SchemaRuntime.Set("group.parent", top, gid)
    local w = P.tab("groups", "When")
    assertTrue(P.hasText(w, "Uses Raid night's conditions. Untick Inherit when conditions above to set this group's own."))
    assertFalse(w[at(P, w, "CheckBox", "Inherit when conditions")].disabled)
end)

test("layout: [groups] the listing tab is What it sends, and Defaults names what it keeps (QUI-L06, L08)", function()
    local NS, _, P = groupsPage()
    local tip = P.ctx("groups").panel.defaultsTooltip
    -- red under: the stale "stop it opening the dial"
    assertEqual(tip, "Turn the selected group back on, turn Inherit when conditions back on, and turn Preview while editing back on. Its name, icon, parent, callouts and own When are kept.")
    -- red under: the tab labeled Preview
    assertEqual(hostTabs(NS, P, "groups").preview.label, "What it sends")
end)

-- ── Pad page ────────────────────────────────────────────────────────────────────────────────

test("layout: [pads] the strip runs outside in: Window, Header, Section titles, Buttons, Icons (QUI-L09, L10)", function()
    local NS = open("Pad", { "pad", "p1" })
    -- red under: the header rows left ahead of the window rows in windowRows()
    assertEqual(strip(NS, "pads"), "General,Groups,Layout,Window,Header,Section titles,Buttons,Icons")
    assertEqual(row(NS, "pad.section.height").label, "Section title height (0 = automatic)")
end)

test("layout: [pads] General: Enable this pad, Faded opacity, Unlock all pads (QUI-L-new1, L-new3, L15)", function()
    local NS, _, P = open("Pad", { "pad", "p1" })
    local w = P.tab("pads", "General")
    assertTrue(P.find(w, "CheckBox", "Enable this pad") ~= nil)
    assertTrue(P.find(w, "Slider", "Faded opacity") ~= nil)
    assertNil(row(NS, "pad.look.fadeAlpha").disabledIf, "no gate added (XC-34)")
    local lock = P.find(w, "Button", "Unlock all pads") or P.find(w, "Button", "Lock all pads")
    assertTrue(lock ~= nil, "the master lock says it moves every pad")
end)

test("layout: [pads] Groups draws Add group above the hint and the list (QUI-L07)", function()
    local NS, _, P = open("Pad", { "pad", "p1" })
    local w = P.tab("pads", "Groups")
    local add, hint = at(P, w, "Dropdown", "Add group"), textAt(w, "Higher groups come first on the pad.")
    assertTrue(add ~= nil and hint ~= nil and add < hint, "the add control above the list")
    assertTrue(add > at(P, w, "Dropdown", "Show groups as"))
    NS.db.profile.pads.p1.groups = {}
    w = P.tab("pads", "Groups")
    assertTrue(P.hasText(w, "This pad lists no group. Add one above."))
end)

test("layout: [pads] Layout names Pad scale and Button spacing (QUI-L36)", function()
    local NS, _, P = open("Pad", { "pad", "p1" })
    local w = P.tab("pads", "Layout")
    assertTrue(P.find(w, "Slider", "Pad scale") ~= nil and P.find(w, "Slider", "Button spacing") ~= nil)
    assertEqual(row(NS, "pad.layout.scale").desc, "This pad's size. Multiplied by Master scale on the General page > Master controls.")
end)

test("layout: [pads] Buttons runs Size, Font, Background, Border, Button glow, Shine (QUI-L12, L13)", function()
    local NS, _, P = open("Pad", { "pad", "p1" })
    local order, seen = {}, {}
    for _, r in ipairs(rowsOf(NS, "pads", "Buttons")) do
        if not seen[r.subgroup] then seen[r.subgroup] = true order[#order + 1] = r.subgroup end
    end
    assertEqual(table.concat(order, ","), "Size,Font,Background,Border,Button glow,Shine")
    assertEqual(row(NS, "pad.button.glowType").desc, "How the glow looks. Drawn at the Icons tab's default knobs.")
    for _, tab in ipairs({ "Window", "Header", "Section titles", "Buttons" }) do
        local w = P.tab("pads", tab)
        assertTrue(P.find(w, "ColorPicker", "Background color") ~= nil, tab .. " labels its swatch Background color")
    end
end)

test("layout: [pads] Icons folds the glow offsets under Icon glow (QUI-L13, L14)", function()
    local _, _, P = open("Pad", { "pad", "p1" })
    local w = P.tab("pads", "Icons")
    assertEqual(#P.all(w, "Heading", "Icon glow"), 1)
    assertEqual(#P.all(w, "Heading", "Offset"), 0, "no separate Offset heading")
    assertEqual(#P.all(w, "Heading", "Size and crop"), 1, "the pad keeps Size and crop")
    assertTrue(at(P, w, "Slider", "Glow X offset") > at(P, w, "Heading", "Icon glow"))
end)

test("layout: [pads] the Defaults tooltip names every tab it resets (QUI-L18)", function()
    local _, _, P = open("Pad", { "pad", "p1" })
    assertEqual(P.ctx("pads").panel.defaultsTooltip, "Put the selected pad's visibility, groups-as, layout, header, section titles, window, buttons and icons back to their defaults, and turn it on. Its name, groups and position are kept.")
end)

-- ── Dial page ───────────────────────────────────────────────────────────────────────────────

test("layout: [dials] the strip: Layout for Wheel, one Labels tab, and Ring map (QUI-L08, L19, L22)", function()
    local NS, _, P = open("Dial", { "dial", "d2" })
    -- red under: the Slice labels and Group labels tabs, or the Wheel tab name
    assertEqual(strip(NS, "dials"), "General,Groups,Layout,Slices,Hub,Paging,Labels,Icons")
    assertEqual(hostTabs(NS, P, "dials").preview.label, "Ring map")
    local keys = {}
    for k in pairs(hostTabs(NS, P, "dials")) do keys[#keys + 1] = k end
    table.sort(keys)
    assertEqual(table.concat(keys, ","), "General,Groups,Hub,Icons,Labels,Layout,Paging,Slices,preview")
    assertEqual(P.ctx("dials").panel.defaultsTooltip, "Put the selected dial's groups-as, layout, slices, hub, paging, labels, tooltip placement and icons back to their defaults, and turn it on. Its name, groups, position and key are kept.")
end)

test("layout: [dials] General: Enable this dial, then the key line (QUI-L29, L-new3)", function()
    local _, _, P = open("Dial", { "dial", "d2" })
    local w = P.tab("dials", "General")
    local enable = at(P, w, "CheckBox", "Enable this dial")
    local line = textAt(w, "Set this dial's key on the General page > Keybindings. A dial's key follows its place in the dial order.")
    assertTrue(enable ~= nil and line ~= nil and enable < line and line < at(P, w, "Button", "Delete dial"))
    assertEqual(#P.all(w, "Keybinding"), 0, "no key box here")
end)

test("layout: [dials] Groups draws Add group above the hint (QUI-L07)", function()
    local NS, _, P = open("Dial", { "dial", "d2" })
    local w = P.tab("dials", "Groups")
    local add, hint = at(P, w, "Dropdown", "Add group"), textAt(w, "Higher groups come first on the dial.")
    assertTrue(add ~= nil and hint ~= nil and add < hint)
    NS.db.profile.dials.d2.groups = {}
    assertTrue(P.hasText(P.tab("dials", "Groups"), "This dial lists no group. Add one above."))
end)

test("layout: [dials] Layout: Slices per ring | Ring radius, Slice gap, then Position with Open at (QUI-L21, L35)", function()
    local NS, _, P = open("Dial", { "dial", "d2" })
    assertEqual(paths(rowsOf(NS, "dials", "Layout")), "dial.slices,dial.radius,dial.slice.gap,dial.openAt,dial.point")
    assertNil(row(NS, "dial.slice.gap").subgroup, "the Gap heading goes")
    local w = P.tab("dials", "Layout")
    local slices, gap = at(P, w, "Dropdown", "Slices per ring"), at(P, w, "Slider", "Slice gap")
    local pos, openAt = at(P, w, "Heading", "Position"), at(P, w, "Dropdown", "Open at")
    assertTrue(slices and gap and pos and openAt, "every control drawn")
    assertTrue(slices < gap and gap < pos and pos < openAt and openAt < at(P, w, "EditBox", "X offset"))
    assertTrue(row(NS, "dial.slices").desc:find("wedge", 1, true) == nil, "one word: slice")
end)

test("layout: [dials] Slices: one Colors heading, then Shine (QUI-L23)", function()
    local NS, _, P = open("Dial", { "dial", "d2" })
    local w = P.tab("dials", "Slices")
    assertEqual(#P.all(w, "Heading", "Colors"), 1)
    for _, gone in ipairs({ "Background", "Highlight", "Gap" }) do assertEqual(#P.all(w, "Heading", gone), 0, gone) end
    assertTrue(at(P, w, "ColorPicker", "Slice color") < at(P, w, "ColorPicker", "Highlight color"))
    assertTrue(at(P, w, "ColorPicker", "Highlight color") < at(P, w, "Heading", "Shine"))
    assertTrue(#rowsOf(NS, "dials", "Slices") > 0)
end)

test("layout: [dials] Hub: Hub, Hub border, Hub circle, Pointer, each size beside its color (QUI-L24)", function()
    local NS = open("Dial", { "dial", "d2" })
    local got = {}
    for _, r in ipairs(rowsOf(NS, "dials", "Hub")) do got[#got + 1] = r.path:match("[^.]+$") .. "@" .. r.subgroup end
    assertEqual(table.concat(got, ","), "style@Hub,size@Hub,background@Hub,useClassColorBackground@Hub,"
        .. "borderSize@Hub border,borderColor@Hub border,useClassColorBorder@Hub border,"
        .. "circleSize@Hub circle,lineWidth@Hub circle,circleColor@Hub circle,useClassColorCircle@Hub circle,"
        .. "pointerShow@Pointer,pointerSize@Pointer,pointerOffset@Pointer,pointerColor@Pointer,useClassColorPointer@Pointer")
end)

test("layout: [dials] Paging: Page row, Arrows, Page indicator, Indicator border, Indicator background (QUI-L25, L26)", function()
    local NS = open("Dial", { "dial", "d2" })
    local got = {}
    for _, r in ipairs(rowsOf(NS, "dials", "Paging")) do got[#got + 1] = r.path:match("[^.]+$") .. "@" .. r.subgroup end
    assertEqual(table.concat(got, ","), "offset@Page row,arrowSize@Arrows,arrowGap@Arrows,arrowColor@Arrows,"
        .. "useClassColorArrow@Arrows,plateColor@Arrows,useClassColorPlate@Arrows,"
        .. "dotSize@Page indicator,pillWidth@Page indicator,dotGap@Page indicator,currentColor@Page indicator,"
        .. "useClassColorCurrent@Page indicator,dotColor@Page indicator,useClassColorDot@Page indicator,"
        .. "dotBorder@Indicator border,dotBorderColor@Indicator border,useClassColorDotBorder@Indicator border,"
        .. "dotBackShow@Indicator background,dotBackPadding@Indicator background,dotBackColor@Indicator background,"
        .. "useClassColorDotBack@Indicator background")
    assertEqual(row(NS, "dial.page.offset").label, "Distance below labels")
    assertFalse(row(NS, "dial.page.dotBackPadding").startsLine == true, "padding pairs with its toggle")
end)

test("layout: [dials] Labels: Slice labels, Group labels, then Tooltip (QUI-L19)", function()
    local NS, _, P = open("Dial", { "dial", "d2" })
    local got, seen = {}, {}
    for _, r in ipairs(rowsOf(NS, "dials", "Labels")) do
        if not seen[r.subgroup] then seen[r.subgroup] = true got[#got + 1] = r.subgroup end
    end
    assertEqual(table.concat(got, ","), "Slice labels,Group labels,Tooltip")
    local w = P.tab("dials", "Labels")
    assertTrue(at(P, w, "CheckBox", "Show slice labels") < at(P, w, "CheckBox", "Show group labels"))
    assertTrue(at(P, w, "CheckBox", "Show group labels") < at(P, w, "Dropdown", "Tooltip side"))
    assertEqual(#P.all(w, "Heading", "Font"), 0, "each font block sits under its labels' heading")
end)

test("layout: [dials] Icons: Size, offset and crop holds Icon size | Icon offset, then Zoom (QUI-L27)", function()
    local NS, _, P = open("Dial", { "dial", "d2" })
    local rows = rowsOf(NS, "dials", "Icons")
    assertEqual(rows[1].path .. "," .. rows[2].path .. "," .. rows[3].path, "dial.icon.size,dial.iconOffset,dial.icon.zoom")
    for i = 1, 3 do assertEqual(rows[i].subgroup, "Size, offset and crop", rows[i].path) end
    local w = P.tab("dials", "Icons")
    assertEqual(#P.all(w, "Heading", "Icon glow"), 1)
    assertTrue(row(NS, "dial.icon.size").desc:find("wedge", 1, true) == nil, "one word: slice")
end)
