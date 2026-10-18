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

test("editors: [review 2] Select mirrors a built-in group into the built-in selection; Heal keeps a member that exists", function()
    local NS, _, Ed = enabled()
    Ed.Select("group", "bi.mplus")
    assertEqual(NS.State.editing.builtin, "bi.mplus")
    Ed.Select("group", "g9")
    assertNil(NS.State.editing.builtin)
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

test("editors: Open goes to a page's category by its id", function()
    local _, m, Ed = enabled()
    local opened
    m.Settings.OpenToCategory = function(id) opened = id end
    Ed.categories.probe = { GetID = function() return 42 end }
    assertTrue(Ed.Open("probe"))
    assertEqual(opened, 42)
    assertFalse(Ed.Open("nope"))
    Ed.categories.probe = nil
end)

test("editors: [audit QC-02] Open refuses in combat with one gray line and never reaches the category switch", function()
    local _, m, Ed = enabled()
    local opened, refreshed = 0, 0
    m.Settings.OpenToCategory = function() opened = opened + 1 end
    Ed.categories.probe = { GetID = function() return 42 end }
    local realRefresh = Ed.RequestRefresh
    Ed.RequestRefresh = function() refreshed = refreshed + 1 end
    m.__setCombat(true)
    m.prints = {}
    -- red under: drop the InCombat gate from Ed.Open in settings/Editors.lua
    assertFalse(Ed.Open("probe"))
    assertEqual(opened, 0, "Settings.OpenToCategory is protected: never called in combat")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("cannot open settings during combat", 1, true) ~= nil, m.prints[1])
    assertEqual(refreshed, 0, "a refused jump queues no repaint")
    m.__setCombat(false)
    assertTrue(Ed.Open("probe"))
    assertEqual(opened, 1)
    Ed.RequestRefresh = realRefresh
    Ed.categories.probe = nil
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
    P.show("Comms Pad")
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
    assertEqual(glyph.imageSize[1], 22)
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
