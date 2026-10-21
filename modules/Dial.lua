local _, NS = ...
-- modules/Dial.lua — the Comms Dial's frames (spec §11). One instance per place in the dial order: the
-- header (modules/Dial_Secure.lua) named QuickCommsDial<place>, which Bindings.xml and the dial's key
-- click; a pool of ring containers under it; in each container a pool of wedges, each the slot's send
-- button (spec §9.1). Frames are never destroyed: a released place keeps its header, closed and
-- emptied, for the next dial that takes it. Bindings.xml's menu labels are set below; the file sits at
-- the addon root and is not a TOC line, as the standard allows (layout-§1, toc-file-§4 (standard v2.80.0)).
--
-- PROTECTED WORK IS OUT OF COMBAT ONLY. Apply, Release, Sync and HideAll run through Surfaces and
-- SendEngine.RunOrQueue (and the stand-down's held Teardown), and Apply also declines on its own in
-- combat. In combat only the header's snippets act (open, switch rings, send, close) and only insecure
-- paint changes here: the stale hint, the padlocks, the lockdown chip, the hub's tooltip. A callout
-- wedge is armed exactly as a pad button is (Pad.ArmSlot): a refused, placeholder or previewed slot is
-- disarmed. The dial's place is `dials[id].point` (the `dial.point` member row; Reset position writes
-- it through Library.SetSurfacePoint); "Open at the cursor" re-anchors in the snippet instead. In test
-- mode or a preview Sync opens dial 1 (spec §11.4), taking no key.
--
-- THE KEY (2026-10-20) is WoW's own binding of the place's Bindings.xml entry ("CLICK
-- QuickCommsDial<place>:Toggle", Open Comms Dial <place> under Ka0s Quick Comms in Options ->
-- Keybindings), never a profile field: account-wide unless the player ticks Character Specific
-- Keybindings. Only that menu sets it (the Comms Dial page's Binding tab retired in the dial rework,
-- 2026-10-21). It follows the place, so a dial that moves up the list takes the key of its new place, and
-- a place with no dial, a disabled dial or a stood-down addon leaves the key bound and opening
-- nothing. Only the first BINDINGS places have an entry, so a dial past them has no key. The guard's dim and the result flash (spec §9.2, §9.3) are insecure and
-- reach every wedge as they reach every button: Pad.Cooldown calls Dial.Cooldown, and SEND_RESULT
-- flashes a callout's wedges. The dial closes on a send, so both show on the next open; a drop stays
-- red for DROP_SECONDS so the player can reopen it and see which line was lost. The Icons tab (B9)
-- is read once per rebuild (IconStyle.Config) and painted on every wedge; a wedge the rebuild leaves
-- unused, and every wedge of a released dial, loses its glow (Glow.ReleaseFree), and a send result
-- starts an After sending glow (Glow.Sent) held for DROP_SECONDS: the send closed the dial, so the
-- next open within that time runs the glow again (Glow.Shown, from the header's OnShow).

NS.Dial = NS.Dial or {}
local Dial = NS.Dial
local DL = NS.DialLayout
local DS = NS.DialSecure
local R = NS.DialRender
local State = NS.State
local L = NS.L

local TAG = "Dial"
local FLASH_SECONDS = 0.4
Dial.DROP_SECONDS = 5          -- a drop stays red long enough to reopen the dial and see it

-- Bindings.xml's "Open Comms Dial 1-4" (spec §9.4). The key bindings menu reads its header and its
-- entries' labels from these globals by name; the client requires them, so they are the one place
-- this addon writes a global that is not a frame. The header is an identifier, declared in
-- .luacheckrc `globals` with its reason. An entry's label is named after its binding, which holds a
-- space and a colon ("BINDING_NAME_CLICK QuickCommsDial1:Toggle"): no identifier can spell it, so it
-- cannot be declared there, and rawset writes it.
Dial.BINDINGS = 4
BINDING_HEADER_QUICKCOMMS = NS.BRAND
for i = 1, Dial.BINDINGS do
    rawset(_G, ("BINDING_NAME_CLICK %s:%s"):format(DS.HEADER:format(i), DS.TOGGLE), L["Open Comms Dial %d"]:format(i))
end

--- The key bindings menu's command for the dial at `place` in the dial order (Bindings.xml), or nil
--- past the BINDINGS entries the menu lists.
function Dial.Command(place)
    place = tonumber(place)
    if not place or place < 1 or place > Dial.BINDINGS then return nil end
    return ("CLICK %s:%s"):format(DS.HEADER:format(place), DS.TOGGLE)
end

--- A dial's place in the dial order, or nil.
function Dial.PlaceOf(id)
    local p = NS.db and NS.db.profile
    for i, did in ipairs(p and p.dialOrder or {}) do
        if did == id then return i end
    end
    return nil
end

--- The key WoW binds to the dial `id`'s entry (its first), or nil: none, no entry past the
--- BINDINGS places, or no such dial.
function Dial.KeyOf(id)
    local command = Dial.Command(Dial.PlaceOf(id))
    return command and NS.Compat.BindingKey(command) or nil
end

local byIndex, byId = {}, {}   -- [place] = instance; [dialId] = instance
local linked = 0               -- how many headers DS.Link last joined
local displayMode = nil        -- the test or preview mode the last Sync drew dial 1 in ("test", a preview key)

local function profileDial(id)
    local db = NS.db
    return db and db.profile.dials[id]
end

local function inCombat() return NS.Compat.InCombat() end

local function applyPoint(inst)
    local dial = profileDial(inst.id)
    -- Read here, not at load: Library is not a load-time upvalue of this file.
    local pt = (dial and type(dial.point) == "table") and dial.point or NS.Library.DIAL_DEFAULT_POINT
    inst.header:ClearAllPoints()
    inst.header:SetPoint(pt[1] or "CENTER", UIParent, pt[2] or "CENTER", tonumber(pt[3]) or 0, tonumber(pt[4]) or 0)
end

-- A callout wedge is armed as a button is; a ring wedge sends nothing (its click switches the ring).
local function arm(btn, item)
    if item.slot then return NS.Pad.ArmSlot(btn, item.slot) end
    NS.SendEngine.Disarm(btn)
end

-- A ring's container, its two page arrows (secure: their click turns the page in combat, through the
-- header's arrow snippet), its catcher (secure: every mouse click on the disc, forwarded to the wedge
-- under the cursor by the header's catcher snippet, in combat too) and its dressing. Sized per plan in
-- Apply.
local function newRing(inst)
    local ring = DS.NewRing(inst.header)
    ring.qcCatcher = DS.NewCatcher(inst.header, ring)
    ring.qcCatcher:SetPoint("CENTER", ring, "CENTER", 0, 0)
    ring.qcPlaceWedge = {}
    ring.qcPrev = R.DressArrow(DS.NewArrow(inst.header, ring), "prev")
    ring.qcNext = R.DressArrow(DS.NewArrow(inst.header, ring), "next")
    ring.qcPrev.qcHeader, ring.qcNext.qcHeader = inst.header, inst.header
    R.DressRing(ring)
    ring:SetPoint("CENTER", inst.header, "CENTER", 0, 0)
    ring.qcWedges = NS.Pool.New()
    -- The debug log: the ring the snippets just showed (an open, a group wedge, a page turn).
    ring:HookScript("OnShow", function(self)
        local spec = self.qcSpec
        if spec then NS.Debug(TAG, "%s shows %s", tostring(inst.id), R.RingTitle(spec)) end
    end)
    return ring
end

-- A ring's arrows: shown on a paged ring, in its row under the disc and the labels (DL.Nav); each
-- targets the page before or after (0 at an end, where it is dimmed and does nothing). Protected
-- geometry and visibility: here, under Apply, out of combat.
local function placeArrows(ring, spec, look)
    local nav = DL.Nav(spec.pages, spec.page, DL.Geometry(look.radius, look.line, look.labelReach), look.paging)
    local paged = (spec.pages or 1) > 1
    for _, a in ipairs({ { ring.qcPrev, -1, spec.prev }, { ring.qcNext, 1, spec.next } }) do
        local btn, side, target = a[1], a[2], a[3]
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", ring, "CENTER", side * nav.arrow, nav.y)
        btn:SetSize(look.paging.arrowSize, look.paging.arrowSize)
        btn:SetShown(paged)
        R.PaintArrow(btn, paged and (target or 0) > 0, look)
    end
end

-- A wedge's press dims every button and wedge for the guard window (Pad.Cooldown calls Dial.Cooldown).
local function newWedge(inst, ring)
    local w = R.DressWedge(DS.NewWedge(inst.header, ring, function(_, _, window) NS.Pad.Cooldown(window) end))
    w.qcHeader = inst.header
    return w
end

local function releaseWedge(w)
    NS.SendEngine.Disarm(w)
    R.Unflash(w)
    R.SetCooling(w, false)
    w.qcItem = nil
end

local function releaseRings(inst)
    for _, ring in ipairs(inst.rings.active) do NS.Pool.ReleaseAll(ring.qcWedges, releaseWedge) end
    NS.Pool.ReleaseAll(inst.rings)
    inst.byCallout = {}
end

-- Every wedge no ring drew this time loses its glow: the free wedges of the rings in use and of the
-- rings left in the pool.
local function releaseFreeGlows(inst)
    for _, list in ipairs({ inst.rings.active, inst.rings.free }) do
        for _, ring in ipairs(list) do NS.Glow.ReleaseFree(ring.qcWedges) end
    end
end

local function build(index)
    local header = DS.NewHeader(index)
    -- The screen catcher (dial polish): a click outside the dial, open from its key, closes it.
    local inst = { index = index, header = header, screen = DS.NewScreen(header), rings = NS.Pool.New(),
        byCallout = {}, live = false }
    R.DressHub(header, function(self)
        if inst.id then Dial.ShowWhy(inst.id, self) end
    end)
    -- The debug log: one line per open and close (insecure hooks; the snippets do the work).
    header:HookScript("OnShow", function() NS.Debug(TAG, "%s opened", tostring(inst.id)) end)
    header:HookScript("OnHide", function() NS.Debug(TAG, "%s closed", tostring(inst.id)) end)
    -- Insecure, beside the hub's own OnShow hook: a send glow held for a wedge runs on the next open.
    header:HookScript("OnShow", function()
        for _, list in pairs(inst.byCallout) do
            for _, w in ipairs(list) do NS.Glow.Shown(w) end
        end
    end)
    byIndex[index] = inst
    NS.Debug(TAG, "built %s", header:GetName())
    return inst
end

local function hubState(inst, plan)
    return {
        lockdown = plan.lockdownChip == true and NS.Setting("behavior.lockdownChip") ~= false,
        stale = State.surfaceStale ~= nil and State.surfaceStale[inst.id] == true,
        testText = (plan.preview and L["PREVIEW"]) or (plan.test and L["TEST MODE"]) or nil,
    }
end

-- One ring's wedges: placed on their places at the dial's radius (a pinned node on its own wind,
-- Dial_Layout's `wedge`), painted, armed, indexed by callout and by place (`ring.qcPlaceWedge`, for the
-- tracker's hover). A wedge takes no mouse (dial polish, 2026-10-21): the ring's catcher clicks it and
-- the tracker hovers it, so one function (DL.SliceAt) decides the slice; the number keys still click
-- it by name.
local function placeWedges(inst, ring, spec, icfg, look)
    local wedges = {}
    ring.qcPlaceWedge = {}
    for i, item in ipairs(spec.items) do
        local w = NS.Pool.Acquire(ring.qcWedges, function() return newWedge(inst, ring) end)
        local place = item.wedge or i
        local geo = DL.Wedge(place, spec.size, look.radius, spec.start, look.labelReach, look.iconReach)
        w:ClearAllPoints()
        w:SetPoint("CENTER", ring, "CENTER", geo.x, geo.y)
        w:SetSize(DL.WEDGE, DL.WEDGE)
        w:EnableMouse(false)   -- protected: here, under Apply, out of combat
        ring.qcPlaceWedge[place] = w
        R.PaintWedge(w, item, geo, icfg, look)
        arm(w, item)
        if item.slot then
            local list = inst.byCallout[item.slot.calloutId] or {}
            list[#list + 1] = w
            inst.byCallout[item.slot.calloutId] = list
        end
        wedges[i] = { button = w, target = item.kind == "ring" and item.target or 0, place = place }
    end
    return wedges
end

-- The widest label the rebuild drew on a wedge that reads sideways (the tooltip clears it at either
-- side, R.PlaceTips).
local function widestLabel(inst)
    local w = 0
    for _, ring in ipairs(inst.rings.active) do
        for _, wedge in ipairs(ring.qcWedges.active) do
            w = math.max(w, tonumber(wedge.qcLabel:GetStringWidth()) or 0)
        end
    end
    return w
end

--- Rebuild the dial at `index` (its place in the dial order, which names its header) from a plan.
--- Out of combat only: Surfaces runs it through RunOrQueue.
--- @return boolean applied
function Dial.Apply(index, id, plan)
    if inCombat() then return false end
    local dial = profileDial(id)
    if not (dial and plan) then return false end
    local inst = byIndex[index] or build(index)
    if inst.id and inst.id ~= id and byId[inst.id] == inst then byId[inst.id] = nil end
    inst.id, inst.plan, inst.live = id, plan, true
    byId[id] = inst
    DS.Close(inst.header)
    releaseRings(inst)
    local icfg = NS.IconStyle.Config(dial.icon, "dial")
    local look = R.Look(plan.radius, dial.label, dial.slice, dial)
    local disc = DL.Geometry(look.radius, look.line, look.labelReach).disc
    -- the header is the hub, its Hub size across (protected geometry: here, out of combat). It takes
    -- no mouse (round hub, 2026-10-21): a square button would take the corners outside the drawn
    -- circle, so the ring's catcher takes the hub's clicks inside its circle (DialLayout.InHub) and the
    -- tracker hovers it; its keys still click it by name.
    inst.header:SetSize(look.hub.size, look.hub.size)
    inst.header:EnableMouse(false)   -- protected: here, under Apply, out of combat
    R.PaintHubLook(inst.header, look)
    R.PaintPointer(inst.header, look)
    local loaded = {}
    for r, spec in ipairs(plan.rings) do
        local ring = NS.Pool.Acquire(inst.rings, function() return newRing(inst) end)
        ring:Hide()
        ring.qcSpec = spec
        ring:SetSize(disc, disc)   -- protected geometry: here, under Apply, out of combat
        ring.qcCatcher:SetSize(disc, disc)
        R.PaintRing(ring, spec, look)
        placeArrows(ring, spec, look)
        loaded[r] = { frame = ring, parent = spec.parent, prev = spec.prev, next = spec.next,
            arrows = { prev = ring.qcPrev, next = ring.qcNext },
            wedges = placeWedges(inst, ring, spec, icfg, look), catcher = ring.qcCatcher,
            shape = { size = spec.size, start = tonumber(spec.start) or 0, hub = look.hub.size, disc = disc } }
    end
    releaseFreeGlows(inst)
    local frames = {}
    for r, l in ipairs(loaded) do frames[r] = l.frame end
    R.RaiseFront(inst.header, frames)
    R.PlaceTips(inst.header, look, widestLabel(inst))
    DS.Load(inst.header, loaded, { openRing = plan.openRing, openAt = plan.test and "center" or dial.openAt,
        screen = inst.screen })
    applyPoint(inst)
    inst.header:SetScale(math.max(NS.Library.MIN_SURFACE_SCALE, tonumber(NS.Setting("scale")) or 1))
    inst.header:SetAlpha(math.max(0, math.min(1, tonumber(NS.Setting("alpha")) or 1)))
    R.PaintHub(inst.header, hubState(inst, plan))
    local opens = plan.rings[plan.openRing]
    NS.Debug(TAG, "%s at place %s: %s ring(s), opens on %s (%s); slices=%s radius=%s", id, index, #plan.rings,
        plan.openRing, opens and opens.title or "none", DL.ClampSlices(dial.slices), look.radius)
    return true
end

--- Take the dial at `index` away: closed, its wedges disarmed and parked, nothing left to open. Out of
--- combat only.
--- @return boolean released
function Dial.Release(index)
    local inst = byIndex[index]
    if not inst or inCombat() then return false end
    DS.Close(inst.header)
    releaseRings(inst)
    releaseFreeGlows(inst)
    DS.Load(inst.header, {}, {})
    if inst.id and byId[inst.id] == inst then byId[inst.id] = nil end
    NS.Debug(TAG, "released place %s (%s)", index, tostring(inst.id))
    inst.id, inst.plan, inst.live = nil, nil, false
    return true
end

-- Every built header knows the others, so opening one closes any other that is open (DS.Link).
local function link()
    local headers = {}
    for _, inst in pairs(byIndex) do headers[#headers + 1] = inst.header end   -- places may have gaps
    if #headers ~= linked and DS.Link(headers) then linked = #headers end
end

-- Apply each planned dial at its place in `order` (the dial order). Answers the places built and the
-- first place built.
local function applyAll(plans, order)
    local used, first = {}, nil
    for index, id in ipairs(order or {}) do
        local plan = plans[id]
        if plan and Dial.Apply(index, id, plan) then
            used[index] = true
            first = first or index
        end
    end
    return used, first
end

-- In test mode or a preview, open the first dial built (spec §11.4) when the mode turns on or
-- changes, or when that dial was open before this rebuild closed it; then remember the mode.
local function openDisplay(plans, order, first, wasOpen)
    local plan = first and plans[order[first]]
    local mode = plan and plan.test and (plan.preview or "test") or nil
    if mode and (mode ~= displayMode or wasOpen[first]) then DS.Open(byIndex[first].header) end
    displayMode = mode
end

--- Make the dials match a set of plans: apply each planned dial at its place in `order` (the dial
--- order), release every other place, and in test mode or a preview open the first one (spec §11.4): when the mode turns on or changes, or when the dial was open
--- before this rebuild closed it. A dial the player closed stays closed through later rebuilds, so it
--- does not come back over the settings window after every edit. Out of combat only.
function Dial.Sync(plans, order)
    local wasOpen = {}
    for index, inst in pairs(byIndex) do wasOpen[index] = inst.header:IsShown() end
    local used, first = applyAll(plans, order)
    for index in pairs(byIndex) do
        if not used[index] then Dial.Release(index) end
    end
    link()
    openDisplay(plans, order, first, wasOpen)
end

--- The secure half of the stand-down: every dial released, so its key (WoW's binding, kept) opens
--- nothing. Out of combat (the stand-down holds it to combat end).
function Dial.HideAll()
    for index in pairs(byIndex) do Dial.Release(index) end
    displayMode = nil
end

-- ── insecure updates, allowed in combat ─────────────────────────────────────────────────────

local function forEachWedge(fn)
    for _, inst in pairs(byIndex) do
        for _, ring in ipairs(inst.rings.active) do
            for _, w in ipairs(ring.qcWedges.active) do fn(w) end
        end
    end
end

--- The guard's dim on every wedge of every dial, for the window (spec §9.2, D12: the guard is
--- global). Pad.Cooldown calls it, so a button's press and a wedge's dim the same set.
function Dial.Cooldown(window)
    forEachWedge(function(w) R.SetCooling(w, true) end)
    if State.dialCoolTimer then NS.addon:CancelTimer(State.dialCoolTimer) end
    State.dialCoolTimer = NS.addon:ScheduleTimer(function()
        State.dialCoolTimer = nil
        forEachWedge(function(w) R.SetCooling(w, false) end)
    end, tonumber(window) or 1)
end

function Dial.SetStale(id, on)
    local inst = byId[id]
    if inst then inst.header.qcStale:SetShown(on and true or false) end
end

function Dial.RefreshLocks(id, showLockdownChip)
    local inst = byId[id]
    if not inst then return end
    for _, ring in ipairs(inst.rings.active) do
        for _, w in ipairs(ring.qcWedges.active) do R.RefreshLock(w) end
    end
    inst.header.qcLockdown:SetShown(showLockdownChip and true or false)
end

--- "Why is this showing?" (spec §13.3) over the hub, unless behavior.whyTooltips is off.
function Dial.ShowWhy(id, owner)
    if NS.Setting("behavior.whyTooltips") == false then return false end
    R.ShowTip(owner, L["Why is this showing?"], NS.Surfaces.WhyLines(id))
    return true
end

--- Master controls' Reset position (spec §10.4), the dials' half: every dial back to the middle.
function Dial.ResetPositions()
    local p = NS.db and NS.db.profile
    if not p then return end
    for id in pairs(p.dials) do NS.Library.SetSurfacePoint("dial", id, nil) end
    NS.SendEngine.RunOrQueue("dialPositions", function()
        for _, inst in pairs(byIndex) do
            if inst.id then applyPoint(inst) end
        end
    end)
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

function Dial.Instance(id)
    return byId[id]
end

function Dial.Ids()
    local out = {}
    for id in pairs(byId) do out[#out + 1] = id end
    table.sort(out)
    return out
end

function Dial.WedgesFor(id, calloutId)
    local inst = byId[id]
    return inst and inst.byCallout[calloutId] or {}
end

--- Ring r's wedges, in wedge order (clockwise from N).
function Dial.RingWedges(id, r)
    local inst = byId[id]
    local ring = inst and inst.rings.active[r]
    return ring and ring.qcWedges.active or {}
end

function Dial.IsOpen(id)
    local inst = byId[id]
    return inst ~= nil and inst.header:IsShown()
end

--- The ring on screen, or nil while closed.
function Dial.ShownRing(id)
    local inst = byId[id]
    if not (inst and inst.header:IsShown()) then return nil end
    for r, ring in ipairs(inst.rings.active) do
        if ring:IsShown() then return r end
    end
    return nil
end

-- ── the edge: send results (as modules/Pad.lua's) ───────────────────────────────────────────

local function onSendResult(_, calloutId, surfaceId, what)
    local inst = byId[surfaceId]
    local list = inst and inst.byCallout[calloutId]
    if not list then return end
    for _, w in ipairs(list) do
        R.Flash(w, what)
        NS.Glow.Sent(w, Dial.DROP_SECONDS)
    end
    local timers = State.dialFlashTimers or {}
    State.dialFlashTimers = timers
    local handle
    handle = NS.addon:ScheduleTimer(function()
        timers[handle] = nil
        for _, w in ipairs(list) do R.Unflash(w) end
    end, what == "dropped" and Dial.DROP_SECONDS or FLASH_SECONDS)
    timers[handle] = true
    if what == "sent" and NS.Setting("behavior.sounds") then
        PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master")
    end
end

local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.SEND_RESULT, onSendResult) end
end
listen()

-- The insecure half of the stand-down; the secure half (release, unbind) is Surfaces' Teardown.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.dialFlashTimers or {}) do NS.addon:CancelTimer(handle) end
    if State.dialCoolTimer then NS.addon:CancelTimer(State.dialCoolTimer) end
    State.dialFlashTimers, State.dialCoolTimer = nil, nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.SEND_RESULT) end
end

NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
