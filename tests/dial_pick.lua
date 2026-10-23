-- tests/dial_pick.lua — a mouse pick on an open dial, for the suites that click one (QF-01, QF-02).
--
-- Not a suite (tests/run.lua does not list it), like tests/page_helpers.lua. Puts the cursor on the
-- open dial's slice that holds `wedge` and clicks its ring's catcher, as a mouse pick does: it scans
-- bearings around the hub until the catcher snippet answers that slice's name. When the wedge sits
-- on a ring that is not shown, it first picks the ring wedge on the shown ring that leads there.
local T = _G.QUICKCOMMS_TEST
local assertTrue, assertEqual = T.assertTrue, T.assertEqual

local pickOnDial
function pickOnDial(NS, m, id, wedge)
    local inst = NS.Dial.Instance(id)
    local h = inst.header
    local function placeOf(r, want)
        for j, w in pairs(inst.rings.active[r].qcPlaceWedge) do if want(w) then return j end end
    end
    local home
    for r in ipairs(inst.rings.active) do
        if placeOf(r, function(w) return w == wedge end) then home = r end
    end
    assertTrue(home ~= nil, "the wedge sits on a ring")
    local shownRing = NS.Dial.ShownRing(id)
    if shownRing ~= home then
        -- the group ring first: its ring wedge opens the callouts' ring
        local j = placeOf(shownRing, function(w) return w:GetAttribute("qc-target") == home end)
        assertTrue(j ~= nil, "the shown ring leads to the wedge's ring")
        pickOnDial(NS, m, id, inst.rings.active[shownRing].qcPlaceWedge[j])
        assertEqual(NS.Dial.ShownRing(id), home)
    end
    local ring = inst.rings.active[home]
    local place = placeOf(home, function(w) return w == wedge end)
    local cx, cy = h:GetCenter()
    local s = h:GetEffectiveScale()
    for k = 0, 71 do
        local a = math.rad(k * 5 + 1)
        m.cursor.x, m.cursor.y = (cx + 60 * math.sin(a)) * s, (cy + 60 * math.cos(a)) * s
        local got = m.__runSnippet(h, "self, button, down, owner", NS.DialSecure.SNIPPETS.catcher, ring.qcCatcher,
            "LeftButton", false, h)
        if got == "w" .. place then
            m.__click(ring.qcCatcher)
            return
        end
    end
    error("no bearing lands on the wedge's slice")
end

return pickOnDial
