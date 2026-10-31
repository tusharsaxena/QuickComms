-- tests/dial_helpers.lua — what the dial suites share: the situations, a live instance, a plan built
-- from slots, the combat edge and two small reads.
--
-- Not a suite (tests/run.lua does not list it), like tests/page_helpers.lua. Split out with
-- tests/test_dial_catcher.lua and tests/test_dial_look.lua when tests/test_dial.lua neared the
-- layout-§1 cap.

local T = _G.QUICKCOMMS_TEST
local assertTrue = T.assertTrue

local D = {}

D.MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
D.AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

function D.live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or D.MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

-- A plan for the default dial straight from slots, without Surfaces: the M+ set's first `n` callouts
-- baked under the current snapshot, as one group (or two, with `second`).
function D.planOf(NS, opts)
    opts = opts or {}
    local snap = NS.Situation.Current()
    local group = { id = T.seeded(NS, "bi.mplus"), title = "Dungeon", slots = {} }
    for i, cid in ipairs(NS.Library.Group(T.seeded(NS, "bi.mplus")).callouts) do
        if i > (opts.n or 8) then break end
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    local rings, open = NS.DialLayout.Rings({ group }, { slices = opts.slices or 4, title = "Comms Dial" })
    return { kind = "dial", surfaceId = "d2", snapshot = snap, order = { T.seeded(NS, "bi.mplus") }, active = {}, rings = rings,
        openRing = open, lockdownChip = opts.lockdown == true, test = opts.test }
end

function D.combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

function D.wedgeTitled(NS, r, title)
    for _, w in ipairs(NS.Dial.RingWedges("d2", r)) do
        if w.qcItem and w.qcItem.title == title then return w end
    end
    return nil
end

function D.near(a, b, what)
    assertTrue(math.abs(a - b) < 0.01, ("%s: %s vs %s"):format(what, tostring(a), tostring(b)))
end

return D
