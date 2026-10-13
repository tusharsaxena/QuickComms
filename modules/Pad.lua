local _, NS = ...
-- modules/Pad.lua — the Comms Pad's frames (spec §10.1, §10.3, §10.4).
--
-- The root is a plain BackdropTemplate frame wearing the Ka0s skin (NS.ApplySkin); it becomes
-- protected in combat because its chips are secure. Every chip IS a send button (spec §9.1),
-- built by SendEngine, dressed by Pad_Render, pooled per pad with NS.Pool and never destroyed. The
-- header row (situation chip, lockdown chip, test label, stale hint, collapse) is a plain child;
-- the LibKa0s drag strip sits above the root and shows only while unlocked (KickCD
-- modules/IconGrid_Handle.lua `buildHandle` / `IconGrid:ApplyLock`), and its canDrag refuses while
-- locked or in combat. canDrag guards only the start: when combat begins mid-drag, the
-- RESTRICTION_CHANGED edge ends the drag itself (endDrags), so the strip's OnDragStop never stops
-- the protected root in combat.
--
-- PROTECTED WORK IS OUT OF COMBAT ONLY. Apply, Release and ResetPositions' anchoring run through
-- Surfaces and SendEngine.RunOrQueue; Apply also declines on its own in combat. Visibility is the
-- SendEngine state driver (spec §10.3), never an insecure Show/Hide on the root. What may change in
-- combat is insecure: alpha (the fade), the padlocks, the lockdown chip, the stale hint, the
-- cooldown veil and the flashes. Tab switching and collapse are refused in combat with one line
-- (spec §10.2, the C8 fallback); the wheel is heard over the header, the root and every chip. The
-- position is `pads[id].point = { point, relativePoint, x, y }`
-- (a member row since phase 3, spec §5.1), shaped as DropWatcher modules/Window.lua `savePoint` /
-- `applyPoint`. It is the `pad.point` member row (settings/SchemaMembers.lua): the drag and Reset
-- position write it through Library.SetSurfacePoint, which hands it to the seam (architecture-§5);
-- the active tab and the collapsed state are session
-- state in NS.State. Every rebuild re-anchors the root from the active profile (spec §10.4: the
-- point lives in the profile), so a profile switch, copy or reset moves an existing pad; a frame
-- being dragged, or whose drag stop is held for combat end, keeps the cursor's place.
-- A held stop the stand-down dropped is filed again by the stand-up, and a new drag clears it.

NS.Pad = NS.Pad or {}
local Pad = NS.Pad
local PL = NS.PadLayout
local R = NS.PadRender
local State = NS.State
local L = NS.L
local Perf = NS.Perf

local TAG = "Pad"
local FLASH_SECONDS = 0.4
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -150 }
Pad.DEFAULT_POINT = DEFAULT_POINT   -- read, never written, by settings/Slash.lua and settings/Pads.lua

local pads = {}   -- [padId] = instance; frames are reused across rebuilds and profiles

local function profilePad(id)
    local db = NS.db
    return db and db.profile.pads[id]
end

local function inCombat() return NS.Compat.InCombat() end
local function isLocked() return NS.Setting("locked") ~= false end

local function session(key)
    State[key] = State[key] or {}
    return State[key]
end

local function applyPoint(inst)
    local pad = profilePad(inst.id)
    local pt = (pad and type(pad.point) == "table") and pad.point or DEFAULT_POINT
    inst.root:ClearAllPoints()
    inst.root:SetPoint(pt[1] or "CENTER", UIParent, pt[2] or "CENTER", tonumber(pt[3]) or 0, tonumber(pt[4]) or 0)
end

-- The point is the `pad.point` member row: Library.SetSurfacePoint writes it through the seam; the pad only asks.
local function savePoint(inst)
    local point, _, relativePoint, x, y = inst.root:GetPoint(1)
    if not point then return end
    if NS.Library.SetSurfacePoint("pad", inst.id, { point, relativePoint, x, y }) then
        NS.Debug(TAG, "%s moved to %s %s,%s", inst.id, point, x, y)
    else
        -- Refused: put the pad back on its saved place now, so it never sits where nothing was saved.
        NS.Debug(TAG, "%s move to %s %s,%s refused", inst.id, point, x, y)
        applyPoint(inst)
    end
end

-- ── chips ───────────────────────────────────────────────────────────────────────────────────

local function forEachChip(fn)
    for _, inst in pairs(pads) do
        for _, btn in ipairs(inst.chips.active) do fn(btn) end
    end
end

--- The spam guard is global (D12): one press dims every chip on every pad, and every wedge on every
--- dial (modules/Dial.lua, which a wedge's press reaches through here too), for the window.
function Pad.Cooldown(window)
    if NS.Dial and NS.Dial.Cooldown then NS.Dial.Cooldown(window) end
    forEachChip(function(btn) R.SetCooling(btn, true) end)
    if State.padCoolTimer then NS.addon:CancelTimer(State.padCoolTimer) end
    State.padCoolTimer = NS.addon:ScheduleTimer(function()
        State.padCoolTimer = nil
        forEachChip(function(btn) R.SetCooling(btn, false) end)
    end, tonumber(window) or 1)
end

local function newChip(inst)
    local btn = NS.SendEngine.NewButton(inst.root, function(_, _, window) Pad.Cooldown(window) end)
    R.Dress(btn, function() Pad.SetHover(inst.id, true) end, function() Pad.SetHover(inst.id, false) end)
    -- An insecure hook, as Dress hooks OnEnter: it never touches the secure click path.
    btn:EnableMouseWheel(true)
    btn:HookScript("OnMouseWheel", function(_, delta) Pad.Wheel(inst.id, delta) end)
    return btn
end

local function newTitle(inst)
    return inst.root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
end

local function releaseChip(btn)
    NS.SendEngine.Disarm(btn)
    btn.qcSlot = nil
end

-- Armed when the slot baked; otherwise disarmed, keeping only what a click may still do (a solo
-- self-print). A refused or placeholder chip carries no chat type, so its click reports nothing.
-- lockText reads the slot's live lock (RefreshLocks keeps it current in combat), so a press on a
-- padlocked chip is explained by its lock, never tracked as a send.
-- A previewed chip (spec §13.3) keeps its line for the tooltip and is disarmed, and carries neither
-- the solo self-line nor the lock text: a previewed chip sends, prints and reports nothing.
local function arm(btn, slot)
    local preview = slot.preview == true
    local meta = { calloutId = slot.calloutId, surfaceId = slot.surfaceId, name = slot.name,
        chatType = slot.chatType, selfText = (not preview) and slot.selfText or nil,
        lockText = (not preview) and function() return slot.lock and (R.LOCK_TEXT[slot.lock] or tostring(slot.lock)) end or nil }
    if slot.line and slot.chatType and not preview then
        NS.SendEngine.Arm(btn, slot.line, meta)
    else
        meta.chatType = nil
        NS.SendEngine.Disarm(btn, meta)
    end
end

-- The dial's callout wedges are armed exactly as a chip is (modules/Dial.lua).
Pad.ArmSlot = arm

local function place(inst, box, style)
    for _, item in ipairs(box.items) do
        if item.kind == "chip" then
            local btn = NS.Pool.Acquire(inst.chips, function() return newChip(inst) end)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", inst.root, "TOPLEFT", item.x, -item.y)
            btn:SetSize(item.w, item.h)
            R.Paint(btn, item.slot, style)
            arm(btn, item.slot)
            local list = inst.byCallout[item.slot.calloutId] or {}
            list[#list + 1] = btn
            inst.byCallout[item.slot.calloutId] = list
        else
            local fs = NS.Pool.Acquire(inst.titles, function() return newTitle(inst) end)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", inst.root, "TOPLEFT", item.x, -item.y)
            fs:SetText(R.SectionTitle(item))
        end
    end
end

-- ── the frame ───────────────────────────────────────────────────────────────────────────────

local function build(id)
    local pad = profilePad(id) or {}
    local root = CreateFrame("Frame", "QuickCommsPad" .. id, UIParent, "BackdropTemplate")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:SetFrameStrata("MEDIUM")
    root:EnableMouseWheel(true)
    root:SetScript("OnMouseWheel", function(_, delta) Pad.Wheel(id, delta) end)
    NS.ApplySkin(root)
    local inst = { id = id, root = root, chips = NS.Pool.New(), titles = NS.Pool.New(), byCallout = {},
        hover = 0, live = false }
    local header = CreateFrame("Frame", nil, root)
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    header:SetHeight(PL.HEADER_H)
    header:EnableMouse(true)
    header:EnableMouseWheel(true)
    header:SetScript("OnMouseWheel", function(_, delta) Pad.Wheel(id, delta) end)
    header:SetScript("OnEnter", function()
        Pad.SetHover(id, true)
        Pad.ShowWhy(id, header)
    end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
        Pad.SetHover(id, false)
    end)
    R.DressHeader(header, function() Pad.ToggleCollapsed(id) end)
    inst.header = header
    local label = pad.name or L["Comms Pad"]
    inst.handle = NS.MakeDragHandle(root, {
        label = label,
        moveFrame = root,
        canDrag = function() return not isLocked() and not inCombat() end,
        -- A new drag supersedes any stop still held for an earlier one (endDrags).
        onDragStart = function()
            inst.dragHeld = nil
            inst.dragging = true
        end,
        onDragStop = function()
            inst.dragging = nil
            savePoint(inst)
        end,
        onRightClick = function() NS.addon:OpenSettings() end,
        tooltip = { title = label, body = { L["Drag to move. Right-click for settings."] } },
    })
    if inst.handle then inst.handle:SetPoint("BOTTOM", root, "TOP", 0, NS.DRAG_GAP) end
    pads[id] = inst
    applyPoint(inst)
    NS.Debug(TAG, "built %s", id)
    return inst
end

local function headerState(inst, plan)
    local snap = plan.snapshot or {}
    return {
        -- A preview names the situation as its menu does (the dungeon, the raid's difficulty, the
        -- battleground), not as a live snapshot would read.
        situation = plan.preview and L["Preview: %s"]:format(NS.Preview.Label(plan.preview))
            or plan.test and L["Test mode"] or R.SituationText(snap, NS.Compat.DungeonName(snap.challengeMapID)),
        testText = plan.preview and L["PREVIEW"] or nil,
        lockdown = plan.lockdownChip == true and NS.Setting("behavior.lockdownChip") ~= false,
        stale = State.surfaceStale ~= nil and State.surfaceStale[inst.id] == true,
        test = plan.test == true,
        collapsed = session("padCollapsed")[inst.id] == true,
    }
end

--- Rebuild one pad from its plan. Out of combat only: Surfaces runs it through RunOrQueue.
--- @return boolean applied
function Pad.Apply(id, plan)
    if inCombat() then return false end
    local pad = profilePad(id)
    if not (pad and plan) then return false end
    local t0 = Perf.on and debugprofilestop()
    local inst = pads[id] or build(id)
    if not (inst.dragging or inst.dragHeld) then applyPoint(inst) end
    inst.plan, inst.live = plan, true
    NS.Pool.ReleaseAll(inst.chips, releaseChip)
    NS.Pool.ReleaseAll(inst.titles)
    inst.byCallout = {}
    local layout = type(pad.layout) == "table" and pad.layout or {}
    local look = type(pad.look) == "table" and pad.look or {}
    local sections = PL.VisibleSections(plan.sections, pad.groupsAs, session("padTab")[id])
    local box = PL.Compute(sections, layout, { collapsed = session("padCollapsed")[id] == true })
    inst.root:SetScale(math.max(NS.Library.MIN_SURFACE_SCALE, (tonumber(NS.Setting("scale")) or 1) * (tonumber(layout.scale) or 1)))
    inst.root:SetSize(box.width, box.height)
    place(inst, box, layout.style)
    R.PaintHeader(inst.header, headerState(inst, plan))
    Pad.ApplyLock()
    NS.SendEngine.SetVisibility(inst.root,
        PL.VisibilityDriver(NS.Setting("visibility"), look.visibility, plan.hasActive, plan.test == true))
    Pad.ApplyAlpha(id)
    if t0 then Perf.Note("pad.layout", debugprofilestop() - t0) end
    return true
end

--- Take a pad off screen: its chips disarmed and parked, its driver cleared. Out of combat only.
function Pad.Release(id)
    local inst = pads[id]
    if not inst or inCombat() then return false end
    if inst.dragHeld then
        -- A drag caught after lockdown began, whose queued stop a stand-down dropped.
        inst.dragHeld = nil
        inst.root:StopMovingOrSizing()
    end
    NS.Pool.ReleaseAll(inst.chips, releaseChip)
    NS.Pool.ReleaseAll(inst.titles)
    inst.byCallout, inst.plan, inst.live = {}, nil, false
    if inst.handle then inst.handle:Hide() end
    NS.SendEngine.ClearVisibility(inst.root)
    return true
end

function Pad.HideAll()
    for id in pairs(pads) do Pad.Release(id) end
end

--- Make the pads match a set of plans: release every pad no plan names, then apply each plan.
function Pad.Sync(plans)
    for id in pairs(pads) do
        if not plans[id] then Pad.Release(id) end
    end
    for id, plan in pairs(plans) do Pad.Apply(id, plan) end
end

-- ── insecure updates, allowed in combat ─────────────────────────────────────────────────────

function Pad.SetStale(id, on)
    local inst = pads[id]
    if inst then inst.header.qcStale:SetShown(on and true or false) end
end

function Pad.RefreshLocks(id, showLockdownChip)
    local inst = pads[id]
    if not inst then return end
    for _, btn in ipairs(inst.chips.active) do R.RefreshLock(btn) end
    inst.header.qcLockdown:SetShown(showLockdownChip and true or false)
end

--- The drag strip: shown on a live pad while unlocked. The strip is not protected.
function Pad.ApplyLock()
    local locked = isLocked()
    for _, inst in pairs(pads) do
        if inst.handle then
            if locked or not inst.live then
                inst.handle:Hide()
            else
                inst.handle:ApplyWidth(0)
                inst.handle:Show()
            end
        end
    end
end

function Pad.ApplyAlpha(id)
    local inst, pad = pads[id], profilePad(id)
    if not (inst and pad) then return end
    inst.root:SetAlpha(PL.Alpha(NS.Setting("alpha"), pad.look, NS.Restrictions.InCombat(), inst.hover > 0))
end

function Pad.SetHover(id, on)
    local inst = pads[id]
    if not inst then return end
    inst.hover = math.max(0, inst.hover + (on and 1 or -1))
    Pad.ApplyAlpha(id)
end

--- "Why is this showing?" (spec §13.3) over the pad's header, unless behavior.whyTooltips is off.
--- Insecure: a tooltip, shown in combat too.
function Pad.ShowWhy(id, owner)
    if NS.Setting("behavior.whyTooltips") == false then return false end
    R.ShowLines(owner, L["Why is this showing?"], NS.Surfaces.WhyLines(id))
    return true
end

-- ── tabs, collapse, position ────────────────────────────────────────────────────────────────

--- The mouse wheel over the header switches tabs; refused in combat with a one-line tooltip.
function Pad.Wheel(id, delta)
    local inst, pad = pads[id], profilePad(id)
    if not (inst and inst.plan and pad and pad.groupsAs == "tabs") then return false end
    if inCombat() then
        GameTooltip:SetOwner(inst.header, "ANCHOR_TOP")
        GameTooltip:SetText(L["Tabs switch after combat."])
        GameTooltip:Show()
        return false
    end
    local tabs = session("padTab")
    tabs[id] = PL.NextTab(tabs[id], #inst.plan.sections, delta)
    return Pad.Apply(id, inst.plan)
end

function Pad.ToggleCollapsed(id)
    local inst = pads[id]
    if not (inst and inst.plan) then return false end
    if inCombat() then
        NS.Print(L["The pad can be collapsed or expanded after combat."])
        return false
    end
    local c = session("padCollapsed")
    c[id] = (not c[id]) or nil
    return Pad.Apply(id, inst.plan)
end

--- The pads' half of Master controls' Reset position (spec §10.4): every pad back to its default
--- anchor. `quiet`: Surfaces.ResetPositions prints one line for pads and dials together.
function Pad.ResetPositions(quiet)
    local p = NS.db and NS.db.profile
    if not p then return end
    for id in pairs(p.pads) do NS.Library.SetSurfacePoint("pad", id, nil) end
    NS.SendEngine.RunOrQueue("positions", function()
        for _, inst in pairs(pads) do applyPoint(inst) end
    end)
    if not quiet then NS.Print(L["Pad positions reset."]) end
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

function Pad.Instance(id)
    return pads[id]
end

function Pad.ChipsFor(id, calloutId)
    local inst = pads[id]
    return inst and inst.byCallout[calloutId] or {}
end

function Pad.Ids()
    local out = {}
    for id in pairs(pads) do out[#out + 1] = id end
    table.sort(out)
    return out
end

-- ── the edge: send results ──────────────────────────────────────────────────────────────────

local function onSendResult(_, calloutId, surfaceId, what)
    local inst = pads[surfaceId]
    local list = inst and inst.byCallout[calloutId]
    if not list then return end
    for _, btn in ipairs(list) do R.Flash(btn, what) end
    local timers = session("padFlashTimers")
    local handle
    handle = NS.addon:ScheduleTimer(function()
        timers[handle] = nil
        for _, btn in ipairs(list) do R.Unflash(btn) end
    end, FLASH_SECONDS)
    timers[handle] = true
    if what == "sent" and NS.Setting("behavior.sounds") then
        PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master")
    end
end

-- The combat edge while a pad is being dragged. The strip forgets the drag first, so its
-- OnDragStop does nothing; the stop and the save run now when lockdown has not begun yet (the
-- PLAYER_REGEN_DISABLED edge comes before it), else once combat ends. A profile switch meanwhile
-- keeps this entry: the root is still stopped, and the drop point is saved only into the profile
-- it was dragged in (another profile's pad goes to that profile's own point). A stand-down drops
-- the entry, and Release stops the root instead.
local function endDrags()
    local dragging = {}
    for _, inst in pairs(pads) do
        if inst.dragging then
            inst.dragging = nil
            inst.dragHeld = true
            if inst.handle then inst.handle.__dragging = nil end
            dragging[#dragging + 1] = inst
        end
    end
    if #dragging == 0 then return end
    local profile = NS.db and NS.db:GetCurrentProfile()
    NS.SendEngine.RunOrQueue("padDrag", function()
        for _, inst in ipairs(dragging) do
            if inst.dragHeld then
                inst.dragHeld = nil
                inst.root:StopMovingOrSizing()
                if NS.db and NS.db:GetCurrentProfile() == profile then savePoint(inst) else applyPoint(inst) end
            end
        end
    end)
end

local function onRestrictionChanged()
    if NS.Restrictions.InCombat() then endDrags() end
end

local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then
        receiver:RegisterMessage(NS.MSG.SEND_RESULT, onSendResult)
        receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged)
    end
end
listen()

-- The insecure half of the stand-down; the secure half (hide, disarm) is Surfaces' Teardown.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.padFlashTimers or {}) do NS.addon:CancelTimer(handle) end
    if State.padCoolTimer then NS.addon:CancelTimer(State.padCoolTimer) end
    State.padFlashTimers, State.padCoolTimer = nil, nil
    for _, inst in pairs(pads) do inst.hover = 0 end
    if receiver and not NS.Bus.tracked then
        receiver:UnregisterMessage(NS.MSG.SEND_RESULT)
        receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED)
    end
end
-- A held drag whose stop the stand-down dropped (it drops the whole combat-end queue) and whose
-- teardown the stand-up then canceled inside the same combat would keep `dragHeld` for good, and
-- Apply would never re-anchor the pad again. The stand-up files the stop again: it runs now out of
-- combat, else at combat end, and the frame goes back to its saved point, because the player
-- disabled the addon mid-drag and the drop was never saved.
local function refileHeldDrags()
    local held = {}
    for _, inst in pairs(pads) do
        if inst.dragHeld then held[#held + 1] = inst end
    end
    if #held == 0 then return end
    NS.SendEngine.RunOrQueue("padDrag", function()
        for _, inst in ipairs(held) do
            if inst.dragHeld then
                inst.dragHeld = nil
                inst.root:StopMovingOrSizing()
                applyPoint(inst)
            end
        end
    end)
end

NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    refileHeldDrags()
end
