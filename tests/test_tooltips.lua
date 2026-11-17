-- tests/test_tooltips.lua — where every tooltip Quick Comms places itself opens (AD-92-QC, LibKa0s#92;
-- WowAddonStandards standalone-windows, *Tooltip placement*): through core/TooltipSetup.lua's seam onto
-- LibKa0s-Tooltip-1.0, a body element's beside its window group (PlaceBeside), a chrome element's
-- attached above it (PlaceAttached), never on the cursor and never at a corner of the control.
--
-- Each surface has a case: the placer is spied (the seam reads the major at call time) and the case
-- asserts the placer, the element and the group it was handed, and that the tooltip was owned at
-- ANCHOR_NONE. The dial's case also drives the kit's fake screen (tests/_kit/mock_screen.lua, kit
-- revision 57, for UIParent's geometry) through a right-fits and a right-does-not-fit layout and reads
-- the side, the top and the gap back from the GameTooltip mock's recorded point.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local D = dofile("tests/dial_helpers.lua")

local MPLUS = D.MPLUS
local AB = D.AB

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function combat(m)
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_DISABLED")
    m.__setCombat(true)
end

-- Every PlaceBeside and PlaceAttached call the addon makes, in order: { placer, tip, element,
-- group|opts, opts }. A call the library makes inside another (PlaceBeside's fallback onto
-- PlaceAttached) is not the addon's, so it is not recorded.
local function spy(m)
    local Tip = m.LibStub("LibKa0s-Tooltip-1.0")
    local calls, depth = {}, 0
    for _, k in ipairs({ "PlaceBeside", "PlaceAttached" }) do
        local real = Tip[k]
        Tip[k] = function(...)
            if depth == 0 then calls[#calls + 1] = { k, ... } end
            depth = depth + 1
            local r = real(...)
            depth = depth - 1
            return r
        end
    end
    return calls
end

-- The first recorded call on `el` (the seam's own fallback onto PlaceAttached comes after it).
local function firstOn(calls, el, from)
    for i = from or 1, #calls do
        if calls[i][3] == el then return calls[i] end
    end
    return nil
end

local function planFor(NS)
    local snap = NS.Situation.Current()
    return NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))
end

local function read(rel)
    local f = assert(io.open(rel, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

-- ── the seam ─────────────────────────────────────────────────────────────────────────────────

test("tooltips: only core/TooltipSetup.lua leases LibKa0s-Tooltip-1.0 (library-stack-§7)", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel:sub(1, 5) ~= "libs/" then
            local src = read(rel):gsub("%-%-[^\r\n]*", "")
            -- red under: a `LibStub("LibKa0s-Tooltip-1.0", true)` in modules/Pad_Render.lua beside the seam
            assertEqual(src:find("LibKa0s%-Tooltip%-1%.0") ~= nil, rel == "core/TooltipSetup.lua", rel)
        end
    end
end)

-- The tooltips the standard leaves to their own code (standalone-windows, *What it does not bind*):
-- a settings page inside Blizzard's Settings canvas. Listed in docs/ARCHITECTURE.md.
local OUT_OF_SCOPE = { ["settings/Groups_When.lua"] = true }

test("tooltips: no own tooltip is owned on the cursor or at a corner; every SetOwner is ANCHOR_NONE", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel:sub(1, 5) ~= "libs/" and rel:match("%.lua$") then
            local src = read(rel):gsub("%-%-[^\r\n]*", "")
            -- red under: GameTooltip:SetOwner(btn, "ANCHOR_TOP") back in modules/Pad_Render.lua
            assertNil(src:find("ANCHOR_CURSOR", 1, true), rel .. " anchors a tooltip on the cursor")
            if not OUT_OF_SCOPE[rel] then
                for anchor in src:gmatch(":SetOwner%([^,]+,%s*\"([%u_]+)\"") do
                    assertEqual(anchor, "ANCHOR_NONE", rel .. " owns a tooltip at " .. anchor)
                end
                assertNil(src:find("\"ANCHOR_TOP", 1, true), rel .. " names a corner anchor")
                assertNil(src:find("\"ANCHOR_RIGHT\"", 1, true), rel .. " names a corner anchor")
            end
        end
    end
end)

test("tooltips: with the geometry unreadable, the seam attaches above the element", function()
    local NS, m = live()
    local el = m.CreateFrame("Frame", nil, m.UIParent)
    local tip = m.GameTooltip
    NS.Tip.Own(tip, el)
    tip:Show()
    -- The mock's frames answer no plain-number geometry: the library places nothing (answers nil).
    -- red under: a seam that leaves the tooltip where the client's default put it (at the pointer)
    assertEqual(NS.Tip.Beside(tip, el, nil), "attached")
    assertEqual(tip.__anchor, "ANCHOR_NONE")
    local p, rel, rp, x, y = tip:GetPoint(1)
    assertEqual(p .. "," .. rp .. "," .. x .. "," .. y, "BOTTOM,TOP,0,2")
    assertTrue(rel == el, "on the element")
    assertEqual(#tip.__points, 1, "one point, set afresh")
    assertEqual(NS.Tip.Attached(tip, el), "attached")
    assertEqual(NS.Tip.Gap(), 2)
end)

test("tooltips: with LibKa0s absent the seam owns at ANCHOR_NONE and attaches above, with no error", function()
    local NS, m = T.newAddon({ skip = T.loadAddon.libFiles })
    local el = m.CreateFrame("Frame", nil, m.UIParent)
    local tip = m.GameTooltip
    -- red under: a seam that calls the major without checking it is there
    NS.Tip.Own(tip, el)
    assertEqual(tip.__anchor, "ANCHOR_NONE")
    assertEqual(NS.Tip.Beside(tip, el, nil), "attached")
    local p, rel, rp, x, y = tip:GetPoint(1)
    assertTrue(rel == el)
    assertEqual(p .. "," .. rp .. "," .. x .. "," .. y, "BOTTOM,TOP,0,2")
end)

-- ── the Comms Pad (a HUD display: its group is the whole display) ───────────────────────────

test("tooltips: [pad] a button's tooltip opens beside the whole pad (PlaceBeside, the pad's group)", function()
    local NS, m = live()
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    local calls = spy(m)
    local inst = NS.Pad.Instance("p1")
    local btn = NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
    btn:__fire("OnEnter")
    -- red under: Pad_Render.ShowTooltip's SetOwner(btn, "ANCHOR_TOP")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    assertTrue(m.GameTooltip.__owner == btn)
    local c = calls[1]
    assertTrue(c and c[1] == "PlaceBeside", "the body placer")
    assertTrue(c[3] == btn, "top level with the hovered button")
    assertTrue(c[4] == inst.tipGroup and c[4].main == inst.root, "the group is the pad, never the single button")
    assertEqual(m.GameTooltip.__lines[1][1], "Pulling", "the content is kept")
end)

test("tooltips: [pad] the drag strip is in the pad's group while it shows", function()
    local NS = live()
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    local inst = NS.Pad.Instance("p1")
    local btn = NS.Pad.ButtonsFor("p1", T.seeded(NS, "bi.mplus.pull"))[1]
    local hit = inst.titleHits.active[1]
    -- red under: a group of the root alone (the strip outside the measured group)
    assertTrue(inst.tipGroup.panels[1] == inst.handle and inst.handle ~= nil, "the strip is a companion")
    assertTrue(btn.qcTipGroup == inst.tipGroup, "a button carries the pad's group")
    assertTrue(hit == nil or hit.qcTipGroup == inst.tipGroup, "so does a section title")
end)

test("tooltips: [pad] a section title's tooltip opens beside the pad (a body element)", function()
    local NS, m = live(AB)
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    local calls = spy(m)
    local hit = NS.Pad.Instance("p1").titleHits.active[1]
    hit:__fire("OnEnter")
    -- red under: PadRender.ShowLines on ANCHOR_TOP
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    assertTrue(calls[1] and calls[1][1] == "PlaceBeside" and calls[1][3] == hit)
    assertTrue(calls[1][4] == NS.Pad.Instance("p1").tipGroup, "beside the whole pad")
    assertEqual(m.GameTooltip.__lines[2][1], "Right-click to edit this group.")
end)

test("tooltips: [pad] the header row's Why is this showing? is chrome: attached above the header", function()
    local NS, m = live()
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    local calls = spy(m)
    local header = NS.Pad.Instance("p1").header
    header:__fire("OnEnter")
    -- red under: Pad.ShowWhy through the body placer, or on ANCHOR_TOP
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    assertTrue(calls[1] and calls[1][1] == "PlaceAttached" and calls[1][3] == header, "the chrome placer")
    assertEqual(m.GameTooltip.__lines[1][1], "Why is this showing?")
end)

test("tooltips: [pad] the wheel's combat refusal is attached above the header", function()
    local NS, m = live(AB)
    NS.db.profile.pads.p1.groupsAs = "tabs"
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    local calls = spy(m)
    combat(m)
    assertFalse(NS.Pad.Wheel("p1", -1))
    local header = NS.Pad.Instance("p1").header
    -- red under: Pad.Wheel's SetOwner(inst.header, "ANCHOR_TOP")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    assertTrue(calls[1] and calls[1][1] == "PlaceAttached" and calls[1][3] == header)
    assertEqual(m.GameTooltip.__lines[1][1], "Tabs switch after combat.")
end)

-- ── the Comms Dial (a HUD display: its group is the drawn dial, labels included) ─────────────

-- The fake screen, with the dial's hub at (`cx`, 540) and `w`'s top at 600, and a 200 x 80 tooltip.
local function onScreen(m, h, w, cx)
    local scr = dofile("tests/_kit/mock_screen.lua")(m, { width = 1920, height = 1080 })
    h.__cx, h.__cy = cx, 540
    rawset(w, "GetLeft", function() return cx - 22 end)
    rawset(w, "GetRight", function() return cx + 22 end)
    rawset(w, "GetTop", function() return 600 end)
    rawset(w, "GetBottom", function() return 556 end)
    local tip = m.GameTooltip
    rawset(tip, "GetWidth", function() return 200 end)
    rawset(tip, "GetHeight", function() return 80 end)
    rawset(tip, "GetEffectiveScale", function() return 1 end)
    return scr
end

test("tooltips: [dial] a wedge's tooltip opens right of the whole dial, top level with the wedge, 2 px off", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", D.planOf(NS)))
    local h = NS.Dial.Instance("d2").header
    local w = NS.Dial.RingWedges("d2", 2)[1]
    local calls = spy(m)
    local scr = onScreen(m, h, w, 960)
    NS.DialRender.EnterWedge(w)
    local tip = m.GameTooltip
    assertEqual(tip.__anchor, "ANCHOR_NONE")
    local c = calls[1]
    -- red under: R.ShowTip's SetPoint on the header's CENTER at the Labels tab's side
    assertTrue(c and c[1] == "PlaceBeside" and c[3] == w, "the body placer, on the wedge")
    assertTrue(c[4] == h.qcTipSpan, "the group is the drawn dial")
    local span = h.qcTipSpan
    local g = NS.DialLayout.Geometry(NS.DialLayout.RADIUS)
    assertTrue(span:GetRight() - 960 >= g.disc / 2, "the span holds the disc")
    -- The client's GameTooltip mock records its points (tests/wow_mock.lua): one absolute point on
    -- UIParent's BOTTOMLEFT, in screen units at scale 1.
    local p, rel, rp, x, y = tip:GetPoint(#tip.__points)
    assertTrue(rel == m.UIParent and rp == "BOTTOMLEFT", "pinned on UIParent")
    assertEqual(p, "TOPLEFT", "on the right")
    assertEqual(x, span:GetRight() + 2, "TIP_GAP right of the dial's right edge")
    assertEqual(y, 600, "top level with the wedge")
    -- Right does not fit: the left of the dial.
    h.__cx = 1800
    NS.DialRender.LeaveWedge(w)
    NS.DialRender.EnterWedge(w)
    p, rel, rp, x, y = tip:GetPoint(#tip.__points)
    assertTrue(rel == m.UIParent and rp == "BOTTOMLEFT")
    assertEqual(p, "TOPRIGHT", "on the left")
    assertEqual(x, span:GetLeft() - 2, "TIP_GAP left of the dial's left edge")
    assertEqual(y, 600)
    scr.restore()
end)

test("tooltips: [dial] the hub's and a page arrow's tooltips open beside the dial too", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", D.planOf(NS, { n = 8, slices = 4 })))
    local h = NS.Dial.Instance("d2").header
    local calls = spy(m)
    NS.Dial.ShowWhy("d2", h)
    -- red under: Dial.ShowWhy through PadRender.ShowLines (ANCHOR_TOP)
    assertTrue(calls[1] and calls[1][1] == "PlaceBeside" and calls[1][3] == h and calls[1][4] == h.qcTipSpan)
    assertEqual(m.GameTooltip.__lines[1][1], "Why is this showing?")
    local ring = NS.Dial.Instance("d2").rings.active[2]
    local arrow = ring.qcNext
    arrow.qcLive = true
    local n = #calls
    arrow:__fire("OnEnter")
    assertTrue(calls[n + 1] and calls[n + 1][1] == "PlaceBeside" and calls[n + 1][3] == arrow)
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
end)

test("tooltips: [dial] Beside, prefer left tries the left first; Tooltip offset widens the span", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", D.planOf(NS)))
    local h = NS.Dial.Instance("d2").header
    local base = h.qcTipSpan.qcExtent.half
    assertTrue(NS.SchemaRuntime.Set("dial.label.tooltipSide", "left", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.label.tooltipOffset", 20, "d2"))
    assertTrue(NS.Dial.Apply(1, "d2", D.planOf(NS)))
    local calls = spy(m)
    NS.DialRender.EnterWedge(NS.Dial.RingWedges("d2", 2)[1])
    -- red under: a tipSide that no longer reaches the placer's prefer
    assertEqual(calls[1][5] and calls[1][5].prefer, "left")
    assertEqual(h.qcTipSpan.qcExtent.half, base + 20, "the offset is a nudge outward")
    -- red under: the retired Above / Below choices kept
    assertFalse(NS.SchemaRuntime.Set("dial.label.tooltipSide", "top", "d2"))
end)

-- ── the Preview as window ───────────────────────────────────────────────────────────────────

test("tooltips: [preview window] the dropdown's and End preview's tooltips open beside the window", function()
    local NS, m = live({ inGroup = false })
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    local f = NS.PreviewWindow.__frame()
    local calls = spy(m)
    f.dropdown:__fire("OnEnter")
    -- red under: PreviewWindow's tip() on ANCHOR_TOP
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    assertTrue(calls[1] and calls[1][1] == "PlaceBeside" and calls[1][3] == f.dropdown and calls[1][4] == f)
    assertEqual(m.GameTooltip.__lines[1][1], "Preview as")
    f.endButton:__fire("OnEnter")
    local c = firstOn(calls, f.endButton)
    assertTrue(c and c[1] == "PlaceBeside" and c[4] == f, "End preview, beside the window")
end)

test("tooltips: [preview window] locked, a title mark's tooltip is attached above it (chrome)", function()
    local NS, m = live({ inGroup = false })
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Inc", text = "Incoming", channel = "party" })
    local gid = Lib.CreateGroup({ name = "Raid only", callouts = { cid }, when = { content = { raid = true } } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    NS.addon.Settings.Editors.Select("group", gid)
    P.show("Groups")
    P.flush()
    local f = NS.PreviewWindow.__frame()
    assertTrue(f ~= nil and NS.PreviewWindow.IsShown(), "the edit preview locks the window")
    local calls = spy(m)
    f.closeButton:__fire("OnEnter")
    -- red under: lockedTip(self) on ANCHOR_TOP for a title mark
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    for _, c in ipairs(calls) do
        assertTrue(c[1] == "PlaceAttached" and c[3] == f.closeButton, "the chrome placer, on the mark")
    end
    assertTrue(#calls >= 1)
    local n = #calls
    f.dropdown:__fire("OnEnter")
    local c = firstOn(calls, f.dropdown, n + 1)
    assertTrue(c and c[1] == "PlaceBeside" and c[4] == f, "a body control's, beside the window")
end)

-- ── the callout popup ───────────────────────────────────────────────────────────────────────

test("tooltips: [callout popup] the token glyph's tooltip opens beside the popup, not beside its catcher", function()
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    m.SettingsPanel:Show()
    local Pop = NS.addon.Settings.CalloutPopup
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local cid = NS.Library.CreateCalloutIn(gid, { name = "Kick", text = "Kick", channel = "party" })
    P.during(function() Pop.Open(gid, cid) end)
    local calls = spy(m)
    Pop.tokenGlyph:__fire("OnEnter")
    -- red under: showTokenHelp's SetOwner(owner, "ANCHOR_RIGHT"), or a group left to GroupOf (the
    -- full-screen catcher is the popup's outermost ancestor)
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    local c = calls[1]
    assertTrue(c and c[1] == "PlaceBeside" and c[3] == Pop.tokenGlyph, "the body placer, on the glyph")
    assertTrue(c[4] == Pop.frame, "the popup window is the group")
    assertEqual(m.GameTooltip.__lines[1][1], "Tokens")
end)

-- ── the migration ───────────────────────────────────────────────────────────────────────────

test("tooltips: [migration 21] a dial's retired Above or Below side becomes Beside; the old default offset 0", function()
    local NS = T.newAddon()
    local profile = { dials = {
        a = { label = { tooltipSide = "top", tooltipOffset = 8 } },
        b = { label = { tooltipSide = "bottom", tooltipOffset = 30 } },
        c = { label = { tooltipSide = "left", tooltipOffset = 8 } },
        d = { label = { tooltipSide = "right" } },
        e = {},
    } }
    -- red under: no step 21 in core/Database.lua
    NS.Library.MigrateDialTipSide(profile)
    local l = profile.dials
    assertEqual(l.a.label.tooltipSide .. "," .. l.a.label.tooltipOffset, "right,0")
    assertEqual(l.b.label.tooltipSide .. "," .. l.b.label.tooltipOffset, "right,30", "a chosen offset kept")
    assertEqual(l.c.label.tooltipSide .. "," .. l.c.label.tooltipOffset, "left,0", "Left keeps its side")
    assertEqual(l.d.label.tooltipSide, "right")
    assertNil(l.e.label)
    NS.Library.MigrateDialTipSide(profile)
    assertEqual(l.b.label.tooltipOffset, 30, "idempotent")
    assertEqual(NS.MIGRATIONS[#NS.MIGRATIONS].to, 21)
end)
