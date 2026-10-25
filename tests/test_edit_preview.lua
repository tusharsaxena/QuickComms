-- tests/test_edit_preview.lua — preview while editing a group (2026-10-19 groups polish, C4): while
-- the Groups page edits a group and Preview while editing is on, every pad and dial shows only that
-- group (and the groups inside it), whatever its When says, and sends nothing. It ends when the page
-- hides, the settings close, combat starts or the addon stands down; Preview as and test mode come
-- back after it.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function combat(m, on)
    m.__setCombat(false)
    if on then
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local function live()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return { inGroup = false } end
    NS.Situation.RefreshNow("test")
    return NS, m
end

-- A user group on pad p1 that the open world never shows: its When asks for a raid.
local function raidGroup(NS)
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Raid only", callouts = { cid }, when = { content = { raid = true } } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    Lib.AddGroupToSurface("dial", "d2", gid, 1)
    return gid, cid
end

local function sectionIds(plan)
    local out = {}
    for i, sec in ipairs(plan.sections) do out[i] = sec.groupId end
    return out
end

local function dialSlots(plan)
    local out = {}
    for _, ring in ipairs(plan.rings or {}) do
        for _, item in ipairs(ring.items) do
            if item.slot then out[#out + 1] = item.slot.calloutId end
        end
    end
    return out
end

test("edit preview: every pad shows only the edited group, whatever its When says, and sends nothing", function()
    local NS, m = live()
    local gid, cid = raidGroup(NS)
    assertTrue(NS.Pad.ButtonsFor("p1", cid)[1] == nil, "the raid group is not active in the open world")
    -- red under: drop the edit branch from Surfaces.ApplyAll
    assertTrue(NS.Preview.SetEditPreview(gid))
    assertEqual(NS.Preview.EditGroup(), gid)
    local plan = NS.Surfaces.Plans().p1
    assertEqual(table.concat(sectionIds(plan), ","), gid, "that group and nothing else")
    assertEqual(plan.editGroup, gid)
    assertTrue(plan.test and plan.preview ~= nil, "drawn as a preview")
    local button = NS.Pad.ButtonsFor("p1", cid)[1]
    assertTrue(button ~= nil)
    assertTrue(button:GetAttribute("macrotext") == nil, "disarmed")
    local before = #m.sentMacros
    m.__click(button)
    assertEqual(#m.sentMacros, before)
    assertEqual(NS.Pad.Instance("p1").header.qcSituation:GetText(), "Preview: Raid only")
    assertFalse(NS.Preview.SetEditPreview(gid), "already on: no edge")
end)

test("edit preview: a battleground set shows its own callouts and every node, outside the battleground", function()
    local NS = live()
    local ab = T.seeded(NS, "bi.bg.ab")
    NS.Preview.SetEditPreview(ab)
    local ids = sectionIds(NS.Surfaces.Plans().p1)
    assertEqual(ids[1], ab, "the set's own map-wide callouts first")
    -- red under: keep the Resolver's active set gating the children of an edited group
    assertEqual(#ids, 1 + #NS.Library.Children(ab), "then every node, whatever its When")
end)

test("edit preview: every dial shows only the edited group", function()
    local NS = live()
    local gid, cid = raidGroup(NS)
    NS.Preview.SetEditPreview(gid)
    local plan = NS.Surfaces.DialPlans().d2
    assertEqual(table.concat(plan.order, ","), gid)
    assertEqual(table.concat(dialSlots(plan), ","), cid)
    assertEqual(plan.editGroup, gid)
end)

test("edit preview: it ends back to the live pads, and Preview as and test mode come back after it", function()
    local NS = live()
    local gid, cid = raidGroup(NS)
    local P = NS.Preview
    assertTrue(P.SetPreviewAs("raid:2912"))
    P.SetEditPreview(gid)
    assertEqual(NS.Surfaces.Plans().p1.editGroup, gid, "edit preview wins while it is on")
    assertTrue(P.SetEditPreview(nil))
    local plan = NS.Surfaces.Plans().p1
    assertTrue(plan.editGroup == nil)
    assertEqual(plan.preview, "raid:2912", "Preview as resumes")
    P.SetPreviewAs(nil)
    P.SetEditPreview(gid)
    assertTrue(P.SetTestMode(true))
    assertEqual(NS.Surfaces.Plans().p1.editGroup, gid, "test mode waits behind it")
    P.SetEditPreview(nil)
    assertTrue(NS.Surfaces.Plans().p1.sections[1].groupId:match("^test%.") ~= nil, "test mode resumes")
    P.SetTestMode(false)
    assertTrue(NS.Pad.ButtonsFor("p1", cid)[1] == nil, "live again: the raid group is not active here")
end)

test("edit preview: combat ends it with one line and the live buttons come back armed; a start in combat is refused", function()
    local NS, m = live()
    local gid = raidGroup(NS)
    NS.Preview.SetEditPreview(gid)
    m.prints = {}
    combat(m, true)
    -- red under: drop the edit branch from Preview's onRestrictionChanged
    assertTrue(NS.Preview.EditGroup() == nil)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview ended: you entered combat.", 1, true) ~= nil, m.prints[1])
    assertTrue(NS.Surfaces.Plans().p1.editGroup == nil)
    assertEqual(#m.blocked, 0)
    m.prints = {}
    assertFalse(NS.Preview.SetEditPreview(gid))
    assertEqual(#m.prints, 0, "silent: the page asks again on every draw")
    combat(m, false)
end)

test("edit preview: with Preview as on too, combat says so once", function()
    local NS, m = live()
    local gid = raidGroup(NS)
    NS.Preview.SetPreviewAs("arena")
    NS.Preview.SetEditPreview(gid)
    m.prints = {}
    combat(m, true)
    assertTrue(NS.Preview.EditGroup() == nil and NS.Preview.PreviewAs() == nil)
    assertEqual(#m.prints, 1)
end)

test("edit preview: closing the settings window and the stand-down end it", function()
    local NS, m = live()
    local gid, cid = raidGroup(NS)
    NS.addon.Settings.Register()
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    NS.Preview.SetEditPreview(gid)
    -- red under: leave the edit preview out of Preview.WatchPanel's OnHide
    m.SettingsPanel:__fire("OnHide")
    assertTrue(NS.Preview.EditGroup() == nil)
    -- red under: the OnHide also ending Preview as (it outlives the settings window)
    assertEqual(NS.Preview.PreviewAs(), "arena", "a Preview as underneath survives the close")
    NS.Preview.SetPreviewAs("off")
    assertTrue(NS.Pad.ButtonsFor("p1", cid)[1] == nil)
    NS.Preview.SetEditPreview(gid)
    NS.SchemaRuntime.Set("enabled", false)
    assertTrue(NS.Preview.EditGroup() == nil)
    NS.SchemaRuntime.Set("enabled", true)
    assertFalse(NS.Preview.IsTestMode())
end)

test("edit preview: a group deleted while previewed leaves the live pads", function()
    local NS = live()
    local gid = raidGroup(NS)
    NS.Preview.SetEditPreview(gid)
    NS.Library.DeleteGroup(gid)
    assertTrue(NS.Surfaces.Plans().p1.editGroup == nil)
end)

test("edit preview: the why lines say the group is being edited", function()
    local NS = live()
    local gid = raidGroup(NS)
    NS.Preview.SetEditPreview(gid)
    local lines = NS.Surfaces.WhyLines("p1")
    assertEqual(lines[1], "Editing: Raid only")
end)

-- ── the Groups page ─────────────────────────────────────────────────────────────────────────

local function m_panel(P) return P.ctx("groups").panel end

local function page()
    local NS, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local gid, cid = raidGroup(NS)
    NS.addon.Settings.Editors.Select("group", gid)
    P.show("Groups")
    return NS, m, P, gid, cid
end

test("edit preview: Preview while editing is a saved Behavior setting, on by default, drawn only in the Groups band", function()
    local NS = T.enableAddon()
    local row = NS.SchemaRuntime.FindRow("behavior.previewOnEdit")
    assertTrue(row ~= nil)
    assertEqual(row.type, "bool")
    assertEqual(row.default, true)
    assertEqual(row.page, "groups")
    assertTrue(row.skipRender == true, "the band draws it, not a tab")
    assertEqual(NS.Setting("behavior.previewOnEdit"), true)
    assertTrue(row.sessionOnly ~= true, "saved")
end)

test("edit preview: showing the Groups page previews the selected group; a pick follows; hiding the page ends it", function()
    local NS, _, P, gid = page()
    -- red under: drop G.SyncEditPreview from the Groups page's render
    assertEqual(NS.Preview.EditGroup(), gid)
    local mplus = T.seeded(NS, "bi.mplus")
    P.banner(P.ctx("groups")):__fire("OnValueChanged", mplus)
    P.flush()
    assertEqual(NS.Preview.EditGroup(), mplus)
    assertEqual(NS.Surfaces.Plans().p1.editGroup, mplus)
    local panel = m_panel(P)
    panel:Hide()
    -- red under: drop the page's OnHide hook (Ed.RegisterPage's onHide)
    panel:__fire("OnHide")
    assertTrue(NS.Preview.EditGroup() == nil)
    assertTrue(NS.Surfaces.Plans().p1.editGroup == nil)
end)

test("edit preview: the band's Preview while editing box sits under the picker and turns it off and on", function()
    local NS, _, P, gid = page()
    local band = P.ctx("groups").qcBand
    assertTrue(band ~= nil and band.toggle ~= nil, "a checkbox in the band")
    assertEqual(band.toggle.labelText, "Preview while editing")
    assertEqual(band.toggle.value, true)
    assertTrue(P.banner(P.ctx("groups")) == band.picker, "the picker is still the band's Dropdown")
    assertEqual(P.bannerAction(P.ctx("groups")).text, "New group")
    band.toggle:__fire("OnValueChanged", false)
    assertEqual(NS.db.profile.behavior.previewOnEdit, false)
    assertTrue(NS.Preview.EditGroup() == nil, "off: the live pads come back")
    P.redraw("groups")
    assertTrue(NS.Preview.EditGroup() == nil, "and a redraw does not start it")
    P.ctx("groups").qcBand.toggle:__fire("OnValueChanged", true)
    assertEqual(NS.Preview.EditGroup(), gid)
end)

test("edit preview: the Groups page drawn in combat does not start it", function()
    local NS, m, P = page()
    NS.Preview.SetEditPreview(nil)
    NS.SchemaRuntime.Set("behavior.previewOnEdit", false)
    NS.SchemaRuntime.Set("behavior.previewOnEdit", true)
    combat(m, true)
    NS.Preview.SetEditPreview(nil)
    P.redraw("groups")
    assertTrue(NS.Preview.EditGroup() == nil)
    combat(m, false)
end)

test("edit preview: it comes back when combat ends with the Groups page still on screen", function()
    local NS, m, _, gid = page()
    assertEqual(NS.Preview.EditGroup(), gid)
    combat(m, true)
    assertTrue(NS.Preview.EditGroup() == nil, "combat ends it")
    -- No page redraw here: only the end of combat itself (RESTRICTION_CHANGED, sent once
    -- Restrictions has cleared its edge) may bring it back.
    NS.addon.Settings.Editors.RequestRefresh = function() end
    combat(m, false)
    -- red under: drop the Groups page's RESTRICTION_CHANGED listener
    assertEqual(NS.Preview.EditGroup(), gid)
    assertEqual(NS.Surfaces.Plans().p1.editGroup, gid)
end)

-- ── every preview looks like live (QC-05, owner report 2026-10-23) ──────────────────────────
--
-- Opening the Groups page faded every icon and laid a dark circle over the dial's wedges: a preview
-- bakes against where you are, so solo every party line was refused and the refused-bake veil
-- (qcDim) covered each disarmed button. A preview stays disarmed, but disarming must not change the
-- look: only the PREVIEW labels are added.

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function texLook(t)
    if not t then return "-" end
    return table.concat({ tostring(t:IsShown()), tostring(t.__texture), table.concat(t.__color or {}, ","),
        tostring(t.__alpha or 1), tostring(t.__desaturated or false), table.concat(t.__size or {}, ",") }, "|")
end

-- Every visual property the render path sets on a pad button or a dial wedge.
local function look(btn)
    local out = {}
    for _, k in ipairs({ "qcIcon", "qcDim", "qcCool", "qcFlash", "qcLock" }) do
        out[#out + 1] = k .. "=" .. texLook(btn[k])
    end
    out[#out + 1] = "label=" .. tostring(btn.qcLabel:IsShown()) .. "|" .. tostring(btn.qcLabel:GetText())
    out[#out + 1] = "alpha=" .. tostring(btn:GetAlpha())
    return table.concat(out, "\n")
end

local function looks(NS, cid)
    local b = NS.Pad.ButtonsFor("p1", cid)[1]
    local w = NS.Dial.WedgesFor("d2", cid)[1]
    assertTrue(b ~= nil, "a pad button")
    assertTrue(w ~= nil, "a dial wedge")
    return look(b), look(w), b, w
end

test("preview: [QC-05] the edit preview and Preview as draw every button and wedge exactly as live", function()
    local NS, m = T.enableAddon()
    local inputs = MPLUS
    NS.Situation.ReadInputs = function() return inputs end
    NS.Situation.RefreshNow("test")
    -- A group with no When, so live, the edit preview and Preview as Current all show it.
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "smartGroup", icon = "ph:sword" })
    local gid = Lib.CreateGroup({ name = "Always", callouts = { cid } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    Lib.AddGroupToSurface("dial", "d2", gid, 1)
    NS.Surfaces.ApplyAll("test")
    local livePad, liveDial = looks(NS, cid)
    assertTrue(NS.Pad.ButtonsFor("p1", cid)[1]:GetAttribute("macrotext") ~= nil, "live is armed")
    -- Solo in the open world, where a party line is refused (no solo fallback).
    inputs = { inGroup = false }
    NS.Situation.RefreshNow("test")
    NS.Surfaces.ApplyAll("test")
    assertTrue(NS.Pad.ButtonsFor("p1", cid)[1].qcDim:IsShown(), "live, a refused button keeps its veil")
    assertTrue(NS.Dial.WedgesFor("d2", cid)[1].qcDim:IsShown(), "and a refused wedge too")
    for _, flavor in ipairs({ "edit", "current" }) do
        if flavor == "edit" then NS.Preview.SetEditPreview(gid) else NS.Preview.SetPreviewAs("current") end
        NS.Surfaces.ApplyAll("test")
        local pad, dial, b, w = looks(NS, cid)
        -- red under: Pad_Render.Paint and Dial_Render.PaintWedge showing qcDim for a refused preview slot
        assertEqual(pad, livePad, flavor .. ": the pad button looks as live")
        assertEqual(dial, liveDial, flavor .. ": the dial wedge looks as live")
        assertTrue(b:GetAttribute("macrotext") == nil and w:GetAttribute("macrotext") == nil, flavor .. ": disarmed")
        local before = #m.sentMacros
        m.__click(b)
        assertEqual(#m.sentMacros, before, flavor .. ": a click sends nothing")
        NS.Preview.SetEditPreview(nil)
        NS.Preview.SetPreviewAs(nil)
    end
end)

-- ── the start line and the dial echo (QF-02, owner 2026-10-23) ───────────────────────────────────

local function startLines(m)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find("Previewing:", 1, true) then n = n + 1 end
    end
    return n
end

test("edit preview: [QF-02] 'Previewing: <group> (editing)' prints on a user start only", function()
    local NS, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local gid = raidGroup(NS)
    NS.addon.Settings.Editors.Select("group", gid)
    m.prints = {}
    P.show("Groups")
    P.flush()
    assertEqual(NS.Preview.EditGroup(), gid)
    -- red under: a SetEditPreview that prints nothing on its start edge
    assertEqual(startLines(m), 1, "the page shown")
    assertTrue(m.prints[#m.prints]:find("Previewing: Raid only (editing)", 1, true) ~= nil, m.prints[#m.prints])
    m.prints = {}
    local mplus = T.seeded(NS, "bi.mplus")
    P.banner(P.ctx("groups")):__fire("OnValueChanged", mplus)
    P.flush()
    P.redraw("groups")
    assertEqual(NS.Preview.EditGroup(), mplus)
    assertEqual(startLines(m), 0, "a group switch and a re-render: no edge")
    NS.SchemaRuntime.Set("behavior.previewOnEdit", false)
    m.prints = {}
    NS.SchemaRuntime.Set("behavior.previewOnEdit", true)
    assertEqual(startLines(m), 1, "the setting ticked on")
    -- Combat: Preview's one line, then the restart after it is quiet.
    m.prints = {}
    combat(m, true)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Preview ended: you entered combat.", 1, true) ~= nil, m.prints[1])
    P.redraw("groups")
    assertEqual(#m.prints, 1, "a refused start in combat is silent")
    combat(m, false)
    assertEqual(NS.Preview.EditGroup(), mplus, "the combat end restarts it")
    assertTrue(NS.PreviewWindow.IsShown(), "with the window")
    -- red under: onRestrictionChanged not passing `quiet`
    assertEqual(startLines(m), 0, "no Previewing: line after combat")
    NS.SchemaRuntime.Set("enabled", false)
    m.prints = {}
    P.redraw("groups")
    assertTrue(NS.Preview.EditGroup() == nil)
    assertEqual(startLines(m), 0, "stood down: refused, silent")
    NS.SchemaRuntime.Set("enabled", true)
end)

-- A mouse pick on an open dial (tests/dial_pick.lua).
local pickOnDial = dofile("tests/dial_pick.lua")

test("edit preview: [QF-02] a dial wedge clicked through its ring's catcher with the Groups page shown echoes", function()
    local NS, m, _, gid, cid = page()
    assertEqual(NS.Preview.EditGroup(), gid)
    assertTrue(NS.Dial.IsOpen("d2"), "the edit preview opens the dial")
    local wedge = NS.Dial.WedgesFor("d2", cid)[1]
    assertTrue(wedge ~= nil and wedge.qcMeta and wedge.qcMeta.echo ~= nil, "the wedge carries its echo")
    m.prints = {}
    local before = #m.sentMacros
    -- red under: drop `echo = preview and slot.line` from Pad's arm (the wedges share it)
    pickOnDial(NS, m, "d2", wedge)
    assertEqual(#m.prints, 1, "one echo")
    assertTrue(m.prints[1]:find(NS.PREFIX, 1, true) == 1, m.prints[1])
    assertTrue(m.prints[1]:find("Incoming", 1, true) ~= nil or m.prints[1]:find("nothing sent", 1, true) ~= nil,
        m.prints[1])
    assertEqual(#m.sentMacros, before, "nothing sent")
    assertTrue(NS.Dial.IsOpen("d2"), "and the dial stays open")
    assertEqual(#m.blocked, 0)
end)
