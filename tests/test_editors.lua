-- tests/test_editors.lua — settings/Editors.lua: what the editor pages share. The selection heals to a
-- member that exists and a profile switch clears it; a change that alters a page's shape asks for ONE
-- structural repaint on the next frame, and a scalar write or a situation change that leaves the
-- active groups alone repaints nothing (options-ui-§11); no page built, no timer; the delete
-- confirmation runs its act only when accepted; the jump opens a page.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function enabled()
    local NS, m = T.enableAddon()
    return NS, m, NS.addon.Settings.Editors
end

-- Count the structural refreshes of a probe page registered as built.
local function probe(NS, Ed)
    local H = NS.addon.Settings.Helpers
    local page, counts = { qcLive = {} }, { structural = 0 }
    Ed.built.probe = page
    local refresh = H.RefreshPanel
    H.RefreshPanel = function(ctx, structural)
        if ctx == page and structural then counts.structural = counts.structural + 1 end
    end
    return page, counts, function()
        H.RefreshPanel = refresh
        Ed.built.probe = nil
    end
end

test("editors: [review 2] Select keeps the selection, and nothing else; Heal keeps a member that exists", function()
    local NS, _, Ed = enabled()
    Ed.Select("group", "g9")
    assertEqual(NS.State.editing.group, "g9")
    assertNil(NS.State.editing.builtin, "no overlay selection")
    Ed.Select("callout", "c5")
    assertEqual(Ed.Heal("callout", { "c1", "c5" }), "c5")
    assertEqual(Ed.Heal("callout", { "c1" }), "c1")
    assertEqual(NS.State.editing.callout, "c1")
    assertNil(Ed.Heal("callout", {}))
    assertNil(NS.State.editing.callout)
end)

test("editors: every membership change asks for one structural repaint, on the next frame", function()
    local NS, m, Ed = enabled()
    local _, counts, done = probe(NS, Ed)
    NS.Library.Touch("callout", "c1")
    NS.Library.Touch("group", "g2")
    assertEqual(counts.structural, 0, "deferred: never under the widget whose callback is running")
    m.__fireTimers()
    -- red under: drop the `pending` check in Ed.RequestRefresh (two repaints)
    assertEqual(counts.structural, 1)
    done()
end)

test("editors: [phase 3] a scalar member write repaints nothing; a name does", function()
    local NS, m, Ed = enabled()
    local _, counts, done = probe(NS, Ed)
    assertTrue(NS.SchemaRuntime.Set("pad.layout.scale", 1.5, "p1"))
    m.__fireTimers()
    -- red under: drop the Ed.STRUCTURAL check from Editors' LIBRARY_CHANGED handler
    assertEqual(counts.structural, 0, "a slider write refreshes in place (options-ui-§11)")
    assertTrue(NS.SchemaRuntime.Set("pad.name", "Main", "p1"))
    m.__fireTimers()
    assertEqual(counts.structural, 1, "a name is a picker label")
    done()
end)

test("editors: [phase 3] a situation change repaints only when the set of active groups changes", function()
    local NS, m, Ed = enabled()
    local page, counts, done = probe(NS, Ed)
    local live = 0
    page.qcLive[1] = function() live = live + 1 end
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED)
    m.__fireTimers()
    assertEqual(counts.structural, 1, "the first change primes the active set")
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED)
    m.__fireTimers()
    -- red under: drop the active-set comparison from Editors' SITUATION_CHANGED handler
    assertEqual(counts.structural, 1, "the same active groups: no repaint")
    assertEqual(live, 1, "the live lines refresh in place")
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    m.__fireTimers()
    assertEqual(counts.structural, 2, "a key started: the M+ set is active now")
    done()
end)

test("editors: [phase 3] with no page body built, no change schedules a repaint", function()
    local NS, _, Ed = enabled()
    NS.Library.Touch("callout", "c1")
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED)
    -- red under: drop `next(Ed.built) == nil` from Ed.RequestRefresh (a timer for a player who never opens the settings)
    assertFalse(Ed.Pending())
end)

test("editors: a profile switch clears every selection", function()
    local NS, _, Ed = enabled()
    Ed.Select("callout", "c1")
    Ed.Select("pad", "p1")
    NS.addon.db:SetProfile("Other")
    assertNil(NS.State.editing.callout)
    assertNil(NS.State.editing.pad)
end)

test("editors: the stand-down cancels a pending repaint", function()
    local NS, m, Ed = enabled()
    local _, counts, done = probe(NS, Ed)
    NS.Library.Touch("callout", "c1")
    assertTrue(Ed.Pending())
    NS.SchemaRuntime.Set("enabled", false)
    m.__fireTimers()
    assertEqual(counts.structural, 0)
    assertFalse(Ed.Pending())
    done()
end)

test("editors: ConfirmDelete asks first, and only the accepted popup runs the act, once", function()
    local _, m, Ed = enabled()
    local ran = 0
    Ed.ConfirmDelete("Lust", function() ran = ran + 1 end)
    local shown = m.popupsShown[#m.popupsShown]
    assertEqual(shown[1], "QUICKCOMMS_DELETE_MEMBER")
    assertEqual(shown[2], "Lust")
    assertEqual(ran, 0)
    m.StaticPopupDialogs[shown[1]].OnAccept(nil, shown[4])
    assertEqual(ran, 1)
    assertTrue(m.StaticPopupDialogs[shown[1]].text:find("%s", 1, true) ~= nil, "names what is deleted")
end)

-- A dialog frame as the client hands it to the definition's OnShow / OnHide: DIALOG, Blizzard's.
local function dialogFrame()
    return { strata = "DIALOG",
        SetFrameStrata = function(self, v) self.strata = v end,
        GetFrameStrata = function(self) return self.strata end }
end

test("editors: [QC-06] the delete confirm lifts its dialog over the dial and the modals, then hands it back", function()
    local NS, m, Ed = enabled()
    Ed.ConfirmDelete("Lust", function() end)
    local def = m.StaticPopupDialogs[m.popupsShown[#m.popupsShown][1]]
    local d = dialogFrame()
    -- red under: leave the confirm in Blizzard's DIALOG, the dial's strata (the hub draws over it),
    -- and under the popup's and the browser's FULLSCREEN catchers
    assertTrue(type(def.OnShow) == "function", "an OnShow")
    def.OnShow(d)
    assertEqual(d.strata, NS.addon.Settings.ModalWindow.CONFIRM_STRATA)
    assertEqual(d.strata, "FULLSCREEN_DIALOG")
    -- red under: no OnHide (the shared dialog frame would keep the strata for Blizzard's next popup)
    def.OnHide(d)
    assertEqual(d.strata, "DIALOG", "the shared frame is handed back as it came")
    -- A second ask reuses the definition: still lifted, once.
    Ed.ConfirmDelete("Lust", function() end)
    def.OnShow(d)
    assertEqual(d.strata, "FULLSCREEN_DIALOG")
    def.OnHide(d)
    assertEqual(d.strata, "DIALOG")
end)

test("editors: Scalar keeps the rows the flow engine draws, and CancelReorder cancels once", function()
    local _, _, Ed = enabled()
    local rows = Ed.Scalar({ { path = "a", type = "string" }, { path = "b", type = "when" }, { path = "c", type = "number" } })
    assertEqual(#rows, 2)
    assertEqual(rows[2].path, "c")
    local n = 0
    Ed.reorders.probe = { Cancel = function() n = n + 1 end }
    Ed.CancelReorder("probe")
    Ed.CancelReorder("probe")
    assertEqual(n, 1)
end)

-- One probe list drawn on the pads page's scroll: answers the widgets it drew.
-- `entries` may be a function of NS, for entries that name a catalog path.
local function probeRows(entries)
    local NS, m, Ed = enabled()
    if type(entries) == "function" then entries = entries(NS, m) end
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Pad")
    local w = P.during(function() Ed.ReorderRows(P.ctx("pads"), "probe", entries) end)
    return NS, P, w
end

test("editors: a row's remove is a glyph, not a button", function()
    local removed = 0
    local _, P, w = probeRows({ { id = "a", label = "A", removeTooltip = "Take A off.",
        remove = function() removed = removed + 1 end } })
    -- red under: draw the remove as the red L["Remove"] Button in Ed.ReorderRows
    assertNil(P.find(w, "Button", "Remove"), "no red button remains")
    local glyph = P.glyph(w, "remove")
    assertTrue(glyph ~= nil, "the remove glyph")
    assertEqual(glyph.image.atlas, "transmog-icon-remove")
    -- red under: keep the 22px glyphs
    assertEqual(glyph.imageSize[1], 16)
    assertTrue(glyph.callbacks.OnEnter ~= nil, "it carries a tooltip")
    assertNil(P.glyph(w, "edit"), "no edit glyph without edit")
    glyph:__fire("OnClick")
    assertEqual(removed, 1)
end)

test("editors: a row with edit shows the edit glyph and fires it", function()
    local edited = 0
    local NS, P, w = probeRows({ { id = "a", label = "A", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear",
        edit = function() edited = edited + 1 end, editTooltip = "Edit A.", remove = function() end } })
    local glyph = P.glyph(w, "edit")
    -- red under: drop the edit glyph from Ed.ReorderRows
    assertTrue(glyph ~= nil, "the edit glyph")
    assertEqual(glyph.image[1], NS.Icon("edit"))
    assertTrue(glyph.callbacks.OnEnter ~= nil, "it carries a tooltip")
    assertTrue(P.glyph(w, "remove") ~= nil, "remove sits beside it")
    glyph:__fire("OnClick")
    assertEqual(edited, 1)
    local label = P.find(w, "Label", "A")
    -- red under: ignore the entry's icon
    assertEqual(label.image and label.image[1], "Interface\\Icons\\Ability_Hunter_Pet_Bear")
end)

test("editors: a row centers its widgets and puts the glyphs at its right edge", function()
    local NS, P, w = probeRows({ { id = "a", label = "A", edit = function() end, remove = function() end },
        { id = "b", label = "B", remove = function() end } })
    local Ed = NS.addon.Settings.Editors
    local label = P.find(w, "Label", "A")
    local row
    for _, x in ipairs(w) do
        for _, c in ipairs(x.children or {}) do if c == label then row = x end end
    end
    assertTrue(row ~= nil, "the label's row")
    -- red under: lay the row out in Flow (its 3px row offset sets everything low)
    assertEqual(row.layout, "Table")
    local t = row.userdata.table
    assertEqual(t.alignV, Ed.RowAlignV)
    assertEqual(Ed.RowAlignV(26), (Ed.ROW_H - 26) / 2, "a glyph is centered in the row")
    assertEqual(Ed.RowAlignV(18), (Ed.ROW_H - 18) / 2, "an icon label is centered in the row")
    -- the handle's gutter, the label filling what is left, a cell per glyph, then a small pad
    local cols = t.columns
    assertEqual(#cols, 5)
    assertEqual(cols[1].width, Ed.HANDLE_W)
    assertEqual(cols[2].weight, 1)
    assertEqual(cols[2].alignH, "fill")
    assertEqual(cols[3].width, 24)
    assertEqual(cols[4].width, 24)
    -- red under a bare 3: AceGUI's Table layout reads 1 <= n < 10 as a weight, not a width
    assertEqual(cols[5].width, 3, "the glyphs sit close to the right edge")
    assertNil(cols[5].weight)
    assertEqual(#Ed.RowColumns(1), 4, "one glyph, one cell")
    -- red under: force the glyph to the row's height (its art then sits at the top of a taller frame)
    assertNil(P.glyph(w, "edit").height, "the glyph keeps its own height, its art centered in it")
end)

test("editors: [layout] under AceGUI's column rule only the label's column is weighted", function()
    local _, _, Ed = enabled()
    -- AceGUI-3.0's Table layout: a bare number n is a weight when 1 <= n < 10, a width otherwise
    local function resolve(c)
        if type(c) == "number" then return { [(c >= 1 and c < 10) and "weight" or "width"] = c } end
        return c
    end
    for glyphs = 1, 2 do
        local weighted, fixed = {}, 0
        for i, c in ipairs(Ed.RowColumns(glyphs)) do
            local r = resolve(c)
            if r.weight then weighted[#weighted + 1] = i else fixed = fixed + r.width end
        end
        assertEqual(#weighted, 1, "one weighted column")
        assertEqual(weighted[1], 2, "the label's")
        -- the glyphs end GLYPH_PAD from the right edge: all fixed widths sum to handle + cells + pad
        assertEqual(fixed, Ed.HANDLE_W + 24 * glyphs + 3)
    end
end)

test("editors: Snapshot is the preview's while Preview as is on", function()
    local NS, _, Ed = enabled()
    NS.Situation.RefreshNow("test")
    assertEqual(Ed.Snapshot().content, NS.Situation.Current().content)
    NS.Preview.SetPreviewAs("arena")
    assertEqual(Ed.Snapshot().content, "arena")
end)

test("editors: [icons] a row's glyph is drawn in its color; a row with none is white", function()
    local _, P, w = probeRows(function(NS, m)
        -- AceGUI's pool hands a Label back with the tint it last had: model that by giving every
        -- new Label a red image, so the white row passes only if the row sets it white itself.
        local AceGUI = m.LibStub("AceGUI-3.0")
        local create = AceGUI.Create
        AceGUI.Create = function(self, wtype)
            local w = create(self, wtype)
            if wtype == "Label" and w.image then w.image:SetVertexColor(1, 0, 0) end
            return w
        end
        local star = NS.Icon("star")
        return { { id = "a", label = "A", icon = star, iconColor = "ff0000" }, { id = "b", label = "B", icon = star } }
    end)
    local a, b = P.find(w, "Label", "A"), P.find(w, "Label", "B")
    -- red under: Ed.ReorderRows setting the image only
    assertEqual(table.concat(a.image.vertexColor, ","), "1,0,0")
    -- red under: tint only a row with a color (AceGUI pools the Label, so a white row must be set white)
    assertEqual(table.concat(b.image.vertexColor, ","), "1,1,1")
end)

-- ── the table (2026-10-18-builtins-as-groups-design.md, goal 3: the Groups page's Preview) ──────

local function probeTable(blocks, header)
    local NS, m, Ed = enabled()
    if type(blocks) == "function" then blocks = blocks(NS) end
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Pad")
    local lists = P.reorderSpy()
    local w = P.during(function() Ed.TableRows(P.ctx("pads"), "probe", blocks, header) end)
    return NS, P, w, lists, Ed
end

-- The widget among `widgets` whose children hold `child`.
local function rowOf(widgets, child)
    for _, x in ipairs(widgets) do
        for _, c in ipairs(x.children or {}) do if c == child then return x end end
    end
    return nil
end

test("editors: [preview table] TableRows draws a header, then a boxed row per entry: its name in one cell, its text in the other", function()
    local star
    local _, P, w, lists, Ed = probeTable(function(NS)
        star = NS.Icon("star")
        return { { rows = {
            { label = "Pull", icon = star, iconColor = "00ff00", text = function() return "Sends: /p Pulling" end },
            { label = "Lust", text = function() return "Solo" end } } } }
    end, { name = "Callout", text = "What it sends here" })
    local name, sends = P.find(w, "Label", "Pull"), P.find(w, "Label", "Sends: /p Pulling")
    assertTrue(name ~= nil and sends ~= nil, "the name and the text are separate labels")
    local row = rowOf(w, name)
    -- red under: one "<name>: <text>" label per row
    assertEqual(row.children[1], name)
    assertEqual(row.children[2], sends, "the text is the same row's second cell")
    assertEqual(row.layout, Ed.TABLE_LAYOUT)
    assertEqual(name.image and name.image[1], star, "the name keeps the entry's icon")
    assertEqual(table.concat(name.image.vertexColor, ","), "0,1,0", "in its color")
    local head = P.find(w, "Label", "Callout")
    assertTrue(head ~= nil and P.find(w, "Label", "What it sends here") ~= nil, "the header's two cells")
    assertEqual(rowOf(w, head).layout, Ed.TABLE_LAYOUT, "the header lines up with the rows")
    assertEqual(head.color.r, 1)
    assertEqual(head.color.g, 0.82, "the header in gold")
    -- the box under each row is the Callouts table's (the library's ROW_BOX), with nothing to drag
    assertEqual(#lists, 1)
    assertEqual(lists[1].rows, 2, "a box per entry, none for the header")
    assertEqual(lists[1].specs[1].draggable, false)
    assertNil(lists[1].opts.onMove)
    -- red under: leave the list off Ed.reorders (the page's redraw would not reclaim its boxes)
    assertTrue(Ed.reorders.probe ~= nil)
end)

test("editors: [preview table] a table row gives its text the width the name leaves, and grows with the text", function()
    local _, _, Ed = enabled()
    -- A cell as AceGUI's Label behaves: SetWidth sets its frame's height from the wrapped text.
    local function cell(heightAt)
        local c = { frame = { points = {} } }
        function c:SetWidth(width) self.width = width; self.frame.height = heightAt(width) end
        function c.frame:ClearAllPoints() self.points = {} end
        function c.frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
        c.frame.Show = function() end
        return c
    end
    local finished
    local content = { width = 700, obj = { LayoutFinished = function(_, _, height) finished = height end } }
    local name = cell(function() return 14 end)
    local text = cell(function(width) return width < 300 and 42 or 14 end)
    Ed.LayoutTableRow(content, { name, text })
    assertEqual(name.width, Ed.TABLE_NAME_W)
    -- red under: leave the text the width it was made with (it would wrap at the wrong edge)
    assertEqual(text.width, 700 - 2 * Ed.TABLE_PAD - Ed.TABLE_NAME_W - Ed.TABLE_GAP)
    assertEqual(finished, Ed.ROW_H, "one line: the Callouts table's row height")
    local p = name.frame.points[1]
    assertEqual(p[1], "TOPLEFT")
    assertEqual(p[2], content)
    assertEqual(p[4], Ed.TABLE_PAD)
    assertEqual(p[5], -(Ed.ROW_H - 14) / 2, "centered in the row")
    assertEqual(text.frame.points[1][4], Ed.TABLE_PAD + Ed.TABLE_NAME_W + Ed.TABLE_GAP)
    content.width = 500
    Ed.LayoutTableRow(content, { name, text })
    -- red under: a fixed ROW_H (wrapped text would spill out of its box)
    assertEqual(finished, 42 + 2 * Ed.TABLE_VPAD, "three lines: the row grows to hold them")
    assertEqual(name.frame.points[1][5], -(42 + 2 * Ed.TABLE_VPAD - 14) / 2)
    assertEqual(text.frame.points[1][5], -Ed.TABLE_VPAD)
end)
