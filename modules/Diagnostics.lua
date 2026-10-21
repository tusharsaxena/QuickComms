local _, NS = ...
-- modules/Diagnostics.lua — the addon's sections of `/qc diagnostics` (debug-logging-§14).
--
-- Sections only: the markers, the identity header's library half, the per-section pcall, the cap
-- and the Add loop are LibKa0s-DebugLog-1.0's. Every section READS state and never acts: no hold,
-- no event, no timer, safe in combat and while stood down. `out:add` formats %s-only and runs every
-- argument through safeToString, so raw values are passed, never pre-built strings. The sections
-- cover design spec §16's list, the Comms Dial's and its WoW key bindings included.

NS.Diagnostics = NS.Diagnostics or {}

local TAG = "Diag"

local function stoodDown() return NS.IsStoodDown and NS.IsStoodDown() or false end

local function read(fn, ...)
    if type(fn) ~= "function" then return "unavailable" end
    local ok, v = pcall(fn, ...)
    if not ok then return "unreadable" end
    return v
end

-- The report runs after OnInitialize, so the db exists; a section that raises costs one line
-- (the library pcalls each section).
local function identity(out)
    local db = NS.addon.db
    out:add(TAG, "schema stored=%s code=%s", db.global.schemaVersion, NS.SCHEMA_VERSION)
    out:add(TAG, "profile=%s", db:GetCurrentProfile())
    out:add(TAG, "enabled=%s stoodDown=%s", db.profile.enabled, stoodDown())
    out:joined(TAG, "holds", NS.Lifecycle:Holds())
end

-- The settings rows, member rows left out: a member row read with no instance is whichever member
-- is selected or listed first, not a setting (the library section counts the members).
local function settings(out)
    local S = NS.SchemaRuntime
    local Settings = NS.addon and NS.addon.Settings
    local rows = {}
    for _, row in ipairs(Settings and Settings.Schema or {}) do
        if not row.instance then rows[#rows + 1] = row end
    end
    out:nonDefaults(rows, function(row) return S.Get(row.path) end, nil, nil, { always = { "enabled" } })
end

local function registration(out)
    local names = {}
    for i, row in ipairs(NS.FEATURE_EVENTS or {}) do names[i] = row[1] end
    out:joined(TAG, "feature events (declared)", names)
    -- Stood down, the latch has unregistered them; the declared list is printed either way.
    out:add(TAG, "feature events registered=%s", not stoodDown())
    out:list(TAG, "rejected events", NS.rejectedEvents or {})
end

local function integrations(out)
    local Lc = NS.Launcher
    out:add(TAG, "launcher: registered=%s shown=%s", Lc and read(Lc.IsRegistered, Lc),
        Lc and read(Lc.IsShown, Lc))
    -- The callout popup's optional EllesmereUI skin: its gate, the facade and the paint.
    local skin = NS.addon.Settings and NS.addon.Settings.CalloutPopupSkin
    if skin and skin.Describe then out:add(TAG, "%s", skin.Describe()) end
end

local function situation(out)
    local s = NS.Situation.Current()
    out:add("Situation", "content=%s instanceID=%s difficulty=%s key=%s group=%s instanceGroup=%s",
        s.content, s.instanceID, s.difficulty, s.keyLevel, s.group, s.instanceGroup)
    out:add("Situation", "leader=%s assist=%s class=%s spec=%s role=%s combat=%s",
        s.leader, s.assist, s.classFile, s.specID, s.role, s.inCombat)
    local lock = {}
    for k, v in pairs(s.lockdown or {}) do if v then lock[#lock + 1] = k end end
    table.sort(lock)
    out:add("Situation", "lockdown=%s", table.concat(lock, ","))
end

-- The restriction state (spec §16): every reason in effect, the one the button names, and whether
-- a chat message may be sent. Read live, like every Restrictions answer.
local function restrictions(out)
    local R = NS.Restrictions
    local active = {}
    for reason in pairs(R.ActiveSet()) do active[#active + 1] = tostring(reason) end
    table.sort(active)
    local snap = R.Snapshot()
    out:add("RES", "active=%s reason=%s canSendChat=%s inCombat=%s",
        table.concat(active, ","), snap.reason, snap.canSendChat, R.InCombat())
end

local function count(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

local function library(out)
    local p = NS.db.profile
    out:add("Library", "callouts=%s groups=%s pads=%s dials=%s nextId=%s seeded=%s",
        count(p.callouts), count(p.groups), #p.padOrder, #p.dialOrder, p.nextId, p.seeded)
    local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), NS.Situation.Current())
    local ids = {}
    for id in pairs(active) do ids[#ids + 1] = id end
    table.sort(ids)
    out:add("Library", "active=%s", table.concat(ids, ","))
end

-- The surfaces (spec §16): each pad's active groups, its stale hint, its lockdown chip.
local function surfaces(out)
    local plans = NS.Surfaces.Plans()
    local stale = NS.State.surfaceStale or {}
    out:joined("Pad", "pads built", NS.Pad.Ids())
    out:add("Pad", "testMode=%s", NS.Preview.IsTestMode())
    out:add("Pad", "previewAs=%s", NS.Preview.PreviewAs() or "off")
    out:add("Pad", "editPreview=%s", NS.Preview.EditGroup() or "off")
    out:add("Pad", "padsHidden=%s (this character)", not NS.SlashVerbs.PadsShown())
    local ids = {}
    for id in pairs(plans) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local plan = plans[id]
        out:add("Pad", "%s active=%s stale=%s lockdownChip=%s", id, table.concat(plan.order, ","),
            stale[id] == true, plan.lockdownChip)
    end
end

-- One dial's look: the Wheel, Slices (Hub included), Paging, Slice labels and Group labels tabs' values that
-- shape what it draws.
local function dialLook(out, id, d)
    local s, l, pg = d.slice or {}, d.label or {}, d.page or {}
    out:add("Dial", "%s look mode=%s slices=%s radius=%s iconOffset=%s openAt=%s", id, d.mode, d.slices, d.radius,
        d.iconOffset, d.openAt)
    out:add("Dial", "%s slices gap=%s pointer=%s size=%s offset=%s labels=%s size=%s offset=%s tooltip=%s/%s", id,
        s.gap, s.pointerShow, s.pointerSize, s.pointerOffset, l.show, l.fontSize, l.offset, l.tooltipSide,
        l.tooltipOffset)
    out:add("Dial", "%s paging offset=%s arrow=%s gap=%s dot=%s pill=%s dotGap=%s", id, pg.offset, pg.arrowSize,
        pg.arrowGap, pg.dotSize, pg.pillWidth, pg.dotGap)
    local h, t = d.hub or {}, d.title or {}
    out:add("Dial", "%s hub style=%s size=%s circle=%s line=%s border=%s groupLabels=%s", id, h.style, h.size,
        h.circleSize, h.lineWidth, h.borderSize, t.show)
end

-- One line per ring of a dial's plan: its title, page, wedge count and where wedge 1 sits, the items
-- it holds, and the rings its hub, previous and next lead to.
local function dialRings(out, id, plan)
    for r, ring in ipairs(plan.rings or {}) do
        out:add("Dial", "%s ring %s %s page=%s/%s size=%s start=%s items=%s parent=%s prev=%s next=%s", id, r,
            ring.title, ring.page, ring.pages, ring.size, ring.start, #ring.items, ring.parent, ring.prev, ring.next)
    end
end

-- The dials (spec §16): each built dial's header, key, rings, the ring it opens on, whether it is open
-- now and the ring on screen, its active groups, its stale hint and its lockdown chip; then its look
-- and its rings.
local function dials(out)
    local plans = NS.Surfaces.DialPlans()
    local stale = NS.State.surfaceStale or {}
    local p = NS.db.profile
    out:joined("Dial", "dials built", NS.Dial.Ids())
    for _, id in ipairs(NS.Dial.Ids()) do
        local inst, plan, d = NS.Dial.Instance(id), plans[id], p.dials[id]
        out:add("Dial", "%s %s key=%s rings=%s openRing=%s open=%s active=%s stale=%s lockdownChip=%s", id,
            inst.header:GetName(), d and NS.Dial.KeyOf(id), plan and #plan.rings, plan and plan.openRing, NS.Dial.IsOpen(id),
            plan and table.concat(plan.order, ","), stale[id] == true, plan and plan.lockdownChip)
        out:add("Dial", "%s shown=%s", id, NS.Dial.ShownRing(id) or "closed")
        if d then dialLook(out, id, d) end
        if plan then dialRings(out, id, plan) end
    end
end

-- The key bindings (spec §9.4, §16): each Open Comms Dial entry's key in WoW's own bindings, the
-- command it runs, and the Toggle Comms Pads entry's.
local function bindings(out)
    local commands = {}
    for place = 1, NS.Dial.BINDINGS do commands[place] = NS.Dial.Command(place) end
    commands[#commands + 1] = NS.SlashVerbs.TOGGLE_COMMAND
    for _, command in ipairs(commands) do
        out:add("Bind", "%s -> %s", tostring(NS.Compat.BindingKey(command) or "none"), command)
    end
end

-- The send engine (spec §16): the armed buttons, each with its pad, callout and escaped line; the
-- combat-end queue's keys; the guard; the echo tracker's counts.
local function send(out)
    local SE = NS.SendEngine
    local armed = SE.ArmedButtons()
    out:add("Send", "buttons=%s armed=%s", SE.ButtonCount(), #armed)
    for _, b in ipairs(armed) do
        local meta = b.qcMeta or {}
        out:add("Send", "%s %s:%s %s", b:GetName(), meta.surfaceId, meta.calloutId, SE.Escaped(b))
    end
    out:joined("Queue", "pending", SE.Snapshot())
    local g = SE.GuardState()
    out:add("Guard", "window=%s last=%s remaining=%s", g.window, g.last, g.remaining)
    local e = SE.EchoState()
    out:add("Echo", "pending=%s sent=%s dropped=%s unknownSender=%s ignored=%s", e.pending, e.sent, e.dropped,
        e.unknown, e.ignored)
end

--- The sections, in report order. Read at RUN time by core/DebugLogSetup.lua's descriptor.
--- @return table
function NS.Diagnostics.Sections()
    return {
        { "identity",     identity },
        { "settings",     settings },
        { "registration", registration },
        { "integrations", integrations },
        { "situation",    situation },
        { "restrictions", restrictions },
        { "library",      library },
        { "surfaces",     surfaces },
        { "dials",        dials },
        { "bindings",     bindings },
        { "send",         send },
    }
end
