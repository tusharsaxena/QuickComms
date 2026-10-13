local _, NS = ...
-- modules/Dial_Secure.lua — the Comms Dial's secure structure (spec §11.2), RELAXED MODE ONLY (the C7
-- fallback in docs/brainstorm/go-no-go/round-4-build-checks.md: the hold, flick and release dial is the
-- upgrade once C7 is verified). One header per dial, named QuickCommsDial<n> for its place in the dial
-- order, is the hub; under it one protected container per ring, holding that ring's wedges; each wedge
-- IS its slot's send button (spec §9.1), armed out of combat with the baked line.
--
-- The snippets below are restricted Lua the client runs in the header's own environment, whose globals
-- persist from one snippet to the next: `current` is the ring on screen, nil while the dial is closed,
-- and `display` is set while an insecure open (test mode, Preview as…) holds it. They show and hide the
-- rings, anchor the hub, and bind Escape, the mouse wheel and the number keys 1-8 while the dial is
-- open from its key (SetBindingClick, released by ClearBindings on close) — all allowed in combat. An
-- insecure open takes no key, because the settings window may be open behind it. They NEVER write an attribute: every attribute and frame ref is written out of combat by
-- DS.Load, through modules/SendEngine.lua, the only secure writer (tests/test_sendengine.lua greps
-- this file like every other).
--
-- The header's click (_onclick): Toggle (the dial's key, Bindings.xml) opens or closes; Close (Escape)
-- and RightButton close; Next and Prev (the wheel) turn a page; any other click is the hub: up a ring,
-- or close on the first ring. A wedge's click is wrapped: the down edge does nothing (a wedge acts on
-- the up edge), a right click closes, a ring wedge (attribute qc-target > 0) shows its ring and sends
-- nothing, and a callout wedge lets the click through, then closes the dial.

NS.DialSecure = NS.DialSecure or {}
local DS = NS.DialSecure
local SE = NS.SendEngine

DS.HEADER = "QuickCommsDial%d"   -- Bindings.xml clicks these by name
DS.TOGGLE = "Toggle"             -- the button the key and Bindings.xml click the header with

local ONCLICK = [[
if button == "Toggle" then
    if current then
        self:RunAttribute("qc-close")
    else
        display = nil
        self:RunAttribute("qc-open")
    end
elseif button == "Close" or button == "RightButton" then
    self:RunAttribute("qc-close")
elseif button == "Next" or button == "Prev" then
    if current then
        local to = self:GetAttribute((button == "Next" and "qc-next-" or "qc-prev-") .. current) or 0
        if to > 0 then self:RunAttribute("qc-show", to) end
    end
elseif current then
    local up = self:GetAttribute("qc-parent-" .. current) or 0
    if up > 0 then
        self:RunAttribute("qc-show", up)
    else
        self:RunAttribute("qc-close")
    end
end
]]

local OPEN = [[
if (self:GetAttribute("qc-rings") or 0) < 1 then return end
if self:GetAttribute("qc-openAt") == "cursor" then
    self:ClearAllPoints()
    self:SetPoint("CENTER", "$cursor")
end
self:Show()
self:RunAttribute("qc-show", self:GetAttribute("qc-openRing") or 1)
]]

-- Opened from the insecure side (test mode, Preview as…), perhaps with the settings window open: the
-- same open, but no key is taken, so Escape still closes the window and 1-8 stay the action bar's.
local DISPLAY = [[
display = true
self:RunAttribute("qc-open")
]]

local SHOW = [[
local r = tonumber((...)) or 0
local count = self:GetAttribute("qc-rings") or 0
if r < 1 or r > count then return end
for i = 1, count do
    local ring = self:GetFrameRef("ring" .. i)
    if ring then
        if i == r then ring:Show() else ring:Hide() end
    end
end
current = r
self:ClearBindings()
if not display then
    self:SetBindingClick(true, "ESCAPE", self, "Close")
    self:SetBindingClick(true, "MOUSEWHEELUP", self, "Prev")
    self:SetBindingClick(true, "MOUSEWHEELDOWN", self, "Next")
    local n = self:GetAttribute("qc-n-" .. r) or 0
    for i = 1, n do
        local name = self:GetAttribute("qc-name-" .. r .. "-" .. i)
        if name and i <= 8 then self:SetBindingClick(true, tostring(i), name, "LeftButton") end
    end
end
]]

local CLOSE = [[
local count = self:GetAttribute("qc-rings") or 0
for i = 1, count do
    local ring = self:GetFrameRef("ring" .. i)
    if ring then ring:Hide() end
end
current = nil
display = nil
self:ClearBindings()
self:Hide()
]]

local WEDGE_PRE = [[
if down then return false end
if button == "RightButton" then
    owner:RunAttribute("qc-close")
    return false
end
local target = self:GetAttribute("qc-target") or 0
if target > 0 then
    owner:RunAttribute("qc-show", target)
    return false
end
return button, "sent"
]]

local WEDGE_POST = [[
owner:RunAttribute("qc-close")
]]

DS.SNIPPETS = { onclick = ONCLICK, open = OPEN, display = DISPLAY, show = SHOW, close = CLOSE, pre = WEDGE_PRE,
    post = WEDGE_POST }

--- A dial's header (its hub), named for its place in the dial order, carrying its snippets. Out of
--- combat only; nil in combat.
function DS.NewHeader(index)
    local header = SE.NewDialHeader(DS.HEADER:format(index))
    if not header then return nil end
    SE.SetAttributes(header, { _onclick = ONCLICK, ["qc-open"] = OPEN, ["qc-display"] = DISPLAY, ["qc-show"] = SHOW,
        ["qc-close"] = CLOSE })
    return header
end

--- One ring's container under the header. Out of combat only.
function DS.NewRing(header)
    return SE.NewDialRing(header)
end

--- One wedge: a send button in `ring`, its click wrapped by the header's wedge snippets. Out of combat.
function DS.NewWedge(header, ring, onPress)
    return SE.NewButton(ring, onPress, { header = header, pre = WEDGE_PRE, post = WEDGE_POST })
end

--- Hand the header a plan's rings: per ring its container, its parent, previous and next page, and its
--- wedges ({ button, target }: 0 for a callout, else the ring a click opens); the ring it opens on and
--- where it opens. Out of combat only.
--- @return boolean loaded
function DS.Load(header, rings, opts)
    if NS.Compat.InCombat() then return false end
    opts = opts or {}
    -- The ring it opens on has its own attribute: `qc-open` is the open snippet's.
    local attrs = { ["qc-rings"] = #rings, ["qc-openRing"] = opts.openRing or 1,
        ["qc-openAt"] = opts.openAt == "cursor" and "cursor" or "center" }
    for r, ring in ipairs(rings) do
        attrs["qc-parent-" .. r] = ring.parent or 0
        attrs["qc-prev-" .. r] = ring.prev or 0
        attrs["qc-next-" .. r] = ring.next or 0
        attrs["qc-n-" .. r] = #ring.wedges
        for i, w in ipairs(ring.wedges) do
            attrs["qc-name-" .. r .. "-" .. i] = w.button:GetName()
            SE.SetAttributes(w.button, { ["qc-target"] = w.target or 0 })
        end
        SE.SetFrameRef(header, "ring" .. r, ring.frame)
    end
    return SE.SetAttributes(header, attrs)
end

--- Open the dial from the insecure side (test mode, Preview as…), taking no key. Out of combat only.
function DS.Open(header)
    return SE.RunSnippet(header, "qc-display")
end

--- Close the dial from the insecure side (a rebuild, a release). Out of combat only.
function DS.Close(header)
    return SE.RunSnippet(header, "qc-close")
end
