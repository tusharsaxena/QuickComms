local _, NS = ...
-- modules/Dial_Render.lua — what the Comms Dial shows (spec §11.1, §11.4). INSECURE visuals only:
-- textures and font strings on the dial's frames, their text, color and visibility, which the client
-- allows in combat; it never touches an attribute or a protected frame's geometry or visibility (the
-- header's snippets show and hide the rings; modules/Dial.lua sizes and places the frames, out of
-- combat). As modules/Pad_Render.lua dresses a pad's secure chips, this dresses the dial's secure
-- frames: the dark disc and the hub's close mark on the header, spokes and a title on each ring, and
-- on each wedge an icon, its label outside the disc, a padlock, a dim veil when it sends nothing, the
-- guard's cooling veil, a result flash and a gold glow under the mouse (the selected wedge). The hub carries the stale hint, the lockdown chip and the test
-- or preview label. The pointer is a plain (unprotected) child of the header that turns toward the
-- cursor: its OnUpdate is set when the header shows and cleared when it hides, so a closed or
-- stood-down dial runs nothing per frame (perf bucket dial.render).

NS.DialRender = NS.DialRender or {}
local R = NS.DialRender
local DL = NS.DialLayout
local L = NS.L
local Perf = NS.Perf

local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local MORE_ICON = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local CLOSE_ICON = "Interface\\Buttons\\UI-StopButton"
local POINTER_ICON = "Interface\\Minimap\\MinimapArrow"
local SPOKES = 12

-- A round texture: the circular alpha mask, tinted.
local function circle(frame, layer, size, r, g, b, a)
    local t = frame:CreateTexture(nil, layer)
    t:SetTexture(CIRCLE)
    t:SetVertexColor(r, g, b, a)
    t:SetSize(size, size)
    t:SetPoint("CENTER", frame, "CENTER", 0, 0)
    return t
end

--- The pointer, while the dial is open: toward the cursor, hidden inside the dead zone.
function R.PointerUpdate(pointer)
    local t0 = Perf.on and debugprofilestop()
    local header = pointer.qcHeader
    local cx, cy = header:GetCenter()
    local scale = header:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local a, ox, oy = DL.Pointer((cx or 0) * scale, (cy or 0) * scale, mx, my)
    local arrow = pointer.qcArrow
    if a then
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", header, "CENTER", ox, oy)
        arrow:SetRotation(-a)
        arrow:Show()
    else
        arrow:Hide()
    end
    if t0 then Perf.Note("dial.render", debugprofilestop() - t0) end
end

--- Build the hub's regions and the pointer, once per header. `onEnter(header)` runs on hover.
function R.DressHub(header, onEnter)
    if header.qcDressed then return header end
    header.qcDressed = true
    header.qcDisc = circle(header, "BACKGROUND", DL.DISC, 0.06, 0.06, 0.08, 0.80)
    header.qcHub = circle(header, "BORDER", DL.HUB, 0.12, 0.12, 0.14, 0.95)
    header.qcClose = header:CreateTexture(nil, "ARTWORK")
    header.qcClose:SetTexture(CLOSE_ICON)
    header.qcClose:SetSize(DL.HUB - 16, DL.HUB - 16)
    header.qcClose:SetPoint("CENTER", header, "CENTER", 0, 0)
    header.qcStale = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.qcStale:SetPoint("TOP", header, "BOTTOM", 0, -2)
    header.qcStale:SetText(L["updates after combat"])
    header.qcStale:Hide()
    header.qcLockdown = header:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    header.qcLockdown:SetPoint("BOTTOM", header, "TOP", 0, 2)
    header.qcLockdown:SetText(L["LOCKDOWN"])
    header.qcLockdown:Hide()
    header.qcTest = header:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    header.qcTest:SetPoint("BOTTOM", header.qcLockdown, "TOP", 0, 2)
    header.qcTest:Hide()
    local pointer = CreateFrame("Frame", nil, header)
    pointer:SetAllPoints(header)
    pointer.qcHeader = header
    local gold = NS.Constants.GOLD
    pointer.qcArrow = pointer:CreateTexture(nil, "OVERLAY")
    pointer.qcArrow:SetTexture(POINTER_ICON)
    pointer.qcArrow:SetSize(16, 16)
    pointer.qcArrow:SetVertexColor(gold.r, gold.g, gold.b, 1)
    pointer.qcArrow:Hide()
    header.qcPointer = pointer
    header:HookScript("OnShow", function() pointer:SetScript("OnUpdate", R.PointerUpdate) end)
    header:HookScript("OnHide", function()
        pointer:SetScript("OnUpdate", nil)
        pointer.qcArrow:Hide()
    end)
    header:HookScript("OnEnter", function(self) if onEnter then onEnter(self) end end)
    header:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return header
end

--- The hub's labels: the lockdown chip, the stale hint, and TEST MODE or PREVIEW.
function R.PaintHub(header, state)
    header.qcLockdown:SetShown(state.lockdown == true)
    header.qcStale:SetShown(state.stale == true)
    header.qcTest:SetShown(state.testText ~= nil)
    header.qcTest:SetText(state.testText or "")
end

--- Build a ring container's spokes and title, once per container.
function R.DressRing(ring)
    if ring.qcDressed then return ring end
    ring.qcDressed = true
    ring.qcSpokes = {}
    for j = 1, SPOKES do
        local s = ring:CreateTexture(nil, "BORDER")
        s:SetColorTexture(1, 1, 1, 0.12)
        s:Hide()
        ring.qcSpokes[j] = s
    end
    ring.qcTitle = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ring.qcTitle:SetPoint("BOTTOM", ring, "TOP", 0, 4)
    return ring
end

--- A ring's title: its name, and its page when it has several ("Arathi Basin (1 of 2)").
function R.RingTitle(spec)
    if (spec.pages or 1) > 1 then return L["%s (%d of %d)"]:format(spec.title or "", spec.page, spec.pages) end
    return spec.title or ""
end

--- Show one ring's spokes (one between each pair of its wedges) and its title.
function R.PaintRing(ring, spec)
    for j, s in ipairs(ring.qcSpokes) do
        if j <= spec.size then
            local g = DL.Spoke(j, spec.size)
            s:ClearAllPoints()
            s:SetPoint("CENTER", ring, "CENTER", g.x, g.y)
            s:SetSize(1, g.length)
            s:SetRotation(g.rotation)
            s:Show()
        else
            s:Hide()
        end
    end
    ring.qcTitle:SetText(R.RingTitle(spec))
end

--- A wedge's tooltip lines: a callout's as its pad chip's (name, its line or why it sends nothing,
--- any lock), a ring's name and what a click does.
function R.WedgeLines(item)
    if item.slot then return NS.PadRender.TooltipLines(item.slot) end
    if item.more then return { L["More"], L["Click for the next page. The mouse wheel turns pages too."] } end
    return { item.title or "?", L["Click to open."] }
end

function R.ShowTooltip(btn)
    local item = btn.qcItem
    if not item then return end
    local lines = R.WedgeLines(item)
    local rest = {}
    for i = 2, #lines do rest[#rest + 1] = lines[i] end
    NS.PadRender.ShowLines(btn, lines[1], rest)
end

--- Build a wedge's regions and hover hooks, once per button.
function R.DressWedge(btn)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcBg = circle(btn, "BACKGROUND", DL.WEDGE, 0.10, 0.10, 0.12, 0.95)
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetSize(DL.WEDGE - 12, DL.WEDGE - 12)
    btn.qcIcon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.qcLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.qcLock = btn:CreateTexture(nil, "OVERLAY")
    btn.qcLock:SetSize(14, 14)
    btn.qcLock:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    btn.qcLock:SetTexture(LOCK_ICON)
    btn.qcDim = circle(btn, "OVERLAY", DL.WEDGE, 0, 0, 0, 0.55)
    btn.qcDim:Hide()
    btn.qcCool = circle(btn, "OVERLAY", DL.WEDGE, 0, 0, 0, 0.35)
    btn.qcCool:Hide()
    btn.qcFlash = circle(btn, "OVERLAY", DL.WEDGE, 1, 1, 1, 0.45)
    btn.qcFlash:Hide()
    local gold = NS.Constants.GOLD
    btn.qcGlow = circle(btn, "HIGHLIGHT", DL.WEDGE + 8, gold.r, gold.g, gold.b, 0.45)
    btn:HookScript("OnEnter", R.ShowTooltip)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

--- Show one ring item on a wedge: its icon, its label outward at `geo.lx, geo.ly`, a padlock when its
--- callout is locked, and the dim veil when it sends nothing here.
function R.PaintWedge(btn, item, geo)
    btn.qcItem = item
    local slot = item.slot
    btn.qcIcon:SetTexture(item.icon or (item.more and MORE_ICON) or DEFAULT_ICON)
    btn.qcLabel:ClearAllPoints()
    btn.qcLabel:SetPoint("CENTER", btn, "CENTER", geo.lx, geo.ly)
    btn.qcLabel:SetText(item.title or "?")
    btn.qcLock:SetShown(slot ~= nil and slot.lock ~= nil)
    local live = slot == nil or slot.line ~= nil or slot.selfText ~= nil or slot.reason == "testMode"
    btn.qcDim:SetShown(not live)
end

function R.RefreshLock(btn)
    local slot = btn.qcItem and btn.qcItem.slot
    btn.qcLock:SetShown(slot ~= nil and slot.lock ~= nil)
end

--- A send result on a wedge (spec §9.3): the pad's colors (NS.Constants.FLASH), red for a drop.
function R.Flash(btn, what)
    local c = NS.Constants.FLASH[what] or NS.Constants.FLASH.sent
    btn.qcFlash:SetVertexColor(c[1], c[2], c[3], 0.45)
    btn.qcFlash:Show()
end

function R.Unflash(btn)
    btn.qcFlash:Hide()
end

--- The guard's dim (spec §9.2).
function R.SetCooling(btn, on)
    btn.qcCool:SetShown(on and true or false)
end
