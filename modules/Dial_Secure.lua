local _, NS = ...
-- modules/Dial_Secure.lua — the Comms Dial's secure structure (spec §11.2), RELAXED MODE ONLY (the C7
-- fallback in docs/brainstorm/go-no-go/round-4-build-checks.md: the hold, flick and release dial is the
-- upgrade once C7 is verified). One header per dial, named QuickCommsDial<n> for its place in the dial
-- order, is the hub; under it one protected container per ring, holding that ring's wedges; each wedge
-- IS its slot's send button (spec §9.1), armed out of combat with the baked line.
--
-- The snippets below are restricted Lua the client runs in the header's own environment, whose globals
-- persist from one snippet to the next: `current` is the ring on screen, nil while the dial is closed,
-- `display` is set while an insecure open (test mode, Preview as…) holds it, and `lastKey` and
-- `lastPage` are the ring and page a key open was last closed on (owner, 2026-10-22): the next key open
-- shows that page of that ring (its `qc-key-<r>` and `qc-page-<r>`, DS.Load, so it outlives a
-- rebuild), else that ring's first page, else the ring it opens on. An insecure open neither reads nor
-- writes them. They show and hide the
-- rings, anchor the hub, and bind Escape, the mouse wheel, the number keys 1-8 and (on a paged ring)
-- the Left and Right arrow keys while the dial is open from its key (SetBindingClick, released by ClearBindings on close) — all allowed in combat. An
-- insecure open takes no key, because the settings window may be open behind it. They NEVER write an attribute: every attribute and frame ref is written out of combat by
-- DS.Load, through modules/SendEngine.lua, the only secure writer (tests/test_sendengine.lua greps
-- this file like every other).
--
-- The header's click (_onclick): Toggle (the dial's key, Bindings.xml) opens or closes; Next and Prev
-- (the wheel) turn a page; a left click is the hub (qc-up: up a ring, or close on the first ring);
-- anything else (Close from Escape) closes. The header takes no mouse (Dial.Apply turns it off, round
-- hub, 2026-10-21): it is a square, the hub is drawn round, so the ring's catcher takes the hub's clicks
-- inside its circle and runs qc-up; the keys still click the header by name. A wedge's click is wrapped:
-- the down edge does nothing (a wedge acts on the up edge), any button but the left closes (a dial on
-- a mouse button closes on its own key: the click lands on the wedge, not on the binding; and only a
-- left click is a press, SendEngine's click hook skips the rest), a ring wedge (attribute
-- qc-target > 0) shows its ring and sends nothing, and a callout wedge lets the click through, then
-- closes the dial, except on a preview or test dial (the header's qc-preview, written by DS.Load out
-- of combat with the same Load that disarms its wedges), which stays open for the next pick. A page arrow (under the disc of a paged ring) is wrapped the same way but never
-- sends: its left click shows the page it targets, or does nothing at an end (qc-target 0). Opening a dial closes every other open dial first (its siblings, DS.Link), so only
-- one holds Escape, the wheel and 1-8.
--
-- THE CATCHER (dial polish, 2026-10-21). The wedges and the header take no mouse; each ring has one
-- secure catcher button over its disc, centered on the hub, the only mouse target there. Its wrapped
-- click reads the cursor with the restricted GetMousePosition, finds the slice by the same math as
-- DialLayout.SliceAt from the ring's qc-size, qc-start, qc-hub and qc-disc (written by DS.Load), and
-- answers the slice's name ("w3") when a wedge sits there: the catcher's *type-w3 = "click" and
-- *clickbutton-w3 = that wedge forward the click (the any-modifier form: the client reads
-- `shift-type-w3` then `*type-w3`, never the plain key, while a modifier is held), and the wedge's own
-- wrap (which takes "w<j>" as a left click) and SendEngine's hook run as for any click. Inside the
-- hub's circle (DialLayout.InHub) a left click, with or without a modifier, runs the header's qc-up
-- (up a ring, or close on the first ring), as the hub's own click did; an empty place or past the rim
-- does nothing; any button but the left closes, but a right click on a slice (owner, 2026-10-22) runs
-- the header's qc-back: up a ring, or nothing on the first ring. Works in combat: nothing is written,
-- only read.
--
-- THE SCREEN CATCHER (dial polish, 2026-10-21). One full-screen secure button per dial, under the
-- dial (SendEngine.NewDialScreen), reached by the header's frame ref `screen` (DS.Load, opts.screen).
-- The show snippet shows it on a key open and hides it on an insecure open (`display`: the settings
-- window may be open behind the dial and must stay usable); the close snippet hides it. Its wrapped
-- click, any button on the up edge, closes the dial and does nothing else: while the dial is open from
-- its key, a click outside it closes it.

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
elseif button == "Next" or button == "Prev" then
    if current then
        local to = self:GetAttribute((button == "Next" and "qc-next-" or "qc-prev-") .. current) or 0
        if to > 0 then self:RunAttribute("qc-show", to) end
    end
elseif button == "LeftButton" and current then
    self:RunAttribute("qc-up")
else
    self:RunAttribute("qc-close")
end
]]

-- The hub's action: up a ring, or close on the first ring. The header's left click and the catcher's
-- click inside the hub's circle run it.
local UP = [[
if not current then return end
local up = self:GetAttribute("qc-parent-" .. current) or 0
if up > 0 then
    self:RunAttribute("qc-show", up)
else
    self:RunAttribute("qc-close")
end
]]

-- A right click on a slice: up a ring, or nothing on the first ring.
local BACK = [[
if not current then return end
local up = self:GetAttribute("qc-parent-" .. current) or 0
if up > 0 then self:RunAttribute("qc-show", up) end
]]

local OPEN = [[
if (self:GetAttribute("qc-rings") or 0) < 1 then return end
for i = 1, self:GetAttribute("qc-siblings") or 0 do
    local other = self:GetFrameRef("sibling" .. i)
    if other then other:RunAttribute("qc-close") end
end
if self:GetAttribute("qc-openAt") == "cursor" then
    self:ClearAllPoints()
    self:SetPoint("CENTER", "$cursor")
end
self:Show()
local count, at, first = self:GetAttribute("qc-rings") or 0, nil, nil
if not display and lastKey then
    for r = 1, count do
        if self:GetAttribute("qc-key-" .. r) == lastKey then
            first = first or r
            if self:GetAttribute("qc-page-" .. r) == lastPage then at = r end
        end
    end
end
self:RunAttribute("qc-show", at or first or self:GetAttribute("qc-openRing") or 1)
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
local screen = self:GetFrameRef("screen")
if screen then
    if display then screen:Hide() else screen:Show() end
end
self:ClearBindings()
if not display then
    self:SetBindingClick(true, "ESCAPE", self, "Close")
    self:SetBindingClick(true, "MOUSEWHEELUP", self, "Prev")
    self:SetBindingClick(true, "MOUSEWHEELDOWN", self, "Next")
    if (self:GetAttribute("qc-prev-" .. r) or 0) > 0 or (self:GetAttribute("qc-next-" .. r) or 0) > 0 then
        self:SetBindingClick(true, "LEFT", self, "Prev")
        self:SetBindingClick(true, "RIGHT", self, "Next")
    end
    local n = self:GetAttribute("qc-n-" .. r) or 0
    for i = 1, n do
        local name = self:GetAttribute("qc-name-" .. r .. "-" .. i)
        if name and i <= 8 then self:SetBindingClick(true, tostring(i), name, "LeftButton") end
    end
end
]]

local CLOSE = [[
if current and not display then
    lastKey, lastPage = self:GetAttribute("qc-key-" .. current), self:GetAttribute("qc-page-" .. current)
end
local count = self:GetAttribute("qc-rings") or 0
for i = 1, count do
    local ring = self:GetFrameRef("ring" .. i)
    if ring then ring:Hide() end
end
local screen = self:GetFrameRef("screen")
if screen then screen:Hide() end
current = nil
display = nil
self:ClearBindings()
self:Hide()
]]

local WEDGE_PRE = [[
if down then return false end
if button:match("^w%d+$") then button = "LeftButton" end
if button ~= "LeftButton" then
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

-- A preview or test dial (the header's qc-preview, DS.Load) stays open after a pick, so the player can
-- try slice after slice (owner, 2026-10-23); a live dial closes as it always has. The snippet only
-- reads the attribute.
local WEDGE_POST = [[
if not owner:GetAttribute("qc-preview") then owner:RunAttribute("qc-close") end
]]

local ARROW_PRE = [[
if down then return false end
if button ~= "LeftButton" then
    owner:RunAttribute("qc-close")
    return false
end
local target = self:GetAttribute("qc-target") or 0
if target > 0 then owner:RunAttribute("qc-show", target) end
return false
]]

-- A ring's catcher (dial polish): inside the hub's circle (DialLayout.InHub) the hub's action, any
-- modifier held; else the slice under the cursor, by the same math as DialLayout.SliceAt (angle only,
-- on the disc), named for its place ("w3") when a wedge sits there; the catcher's *type-w<j> /
-- *clickbutton-w<j> (any modifier) then click that wedge with that name. A right click on a slice is
-- qc-back; any other button, and a right click on the hub or past the rim, closes.
local CATCHER_PRE = [[
if down then return false end
local right = button == "RightButton"
if button ~= "LeftButton" and not right then owner:RunAttribute("qc-close") return false end
local x, y = self:GetMousePosition()
if not x then return false end
local disc = self:GetAttribute("qc-disc") or 0
local dx, dy = (x - 0.5) * disc, (y - 0.5) * disc
local dist = math.sqrt(dx * dx + dy * dy)
local onHub, offDisc = dist <= (self:GetAttribute("qc-hub") or 0) / 2, dist > disc / 2
if right then
    owner:RunAttribute((onHub or offDisc) and "qc-close" or "qc-back")
    return false
end
if onHub then owner:RunAttribute("qc-up") return false end
if offDisc then return false end
local size = self:GetAttribute("qc-size") or 1
local step = 2 * math.pi / size
local from = math.rad(self:GetAttribute("qc-start") or 0) - step / 2
local j = math.floor(((math.atan2(dx, dy) - from) % (2 * math.pi)) / step) + 1
if not self:GetAttribute("*type-w" .. j) then return false end
return "w" .. j
]]

-- The screen catcher (dial polish): any click outside the open dial closes it, on the up edge, and
-- nothing goes through (the button has no type).
local SCREEN_PRE = [[
if down then return false end
owner:RunAttribute("qc-close")
return false
]]

DS.SNIPPETS = { onclick = ONCLICK, up = UP, back = BACK, open = OPEN, display = DISPLAY, show = SHOW, close = CLOSE, pre = WEDGE_PRE,
    post = WEDGE_POST, arrow = ARROW_PRE, catcher = CATCHER_PRE, screen = SCREEN_PRE }

--- A dial's header (its hub), named for its place in the dial order, carrying its snippets. Out of
--- combat only; nil in combat.
function DS.NewHeader(index)
    local header = SE.NewDialHeader(DS.HEADER:format(index))
    if not header then return nil end
    SE.SetAttributes(header, { _onclick = ONCLICK, ["qc-up"] = UP, ["qc-back"] = BACK, ["qc-open"] = OPEN, ["qc-display"] = DISPLAY, ["qc-show"] = SHOW,
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

--- One page arrow: a button in `ring` that sends nothing, its click wrapped by the arrow snippet.
--- Out of combat only.
function DS.NewArrow(header, ring)
    return SE.NewButton(ring, nil, { header = header, pre = ARROW_PRE })
end

--- One ring's catcher: a secure button over the ring's disc, its click wrapped by the catcher snippet.
--- Out of combat only.
function DS.NewCatcher(header, ring)
    return SE.NewDialCatcher(header, ring, CATCHER_PRE)
end

--- A dial's screen catcher: a full-screen secure button under the dial, its click wrapped by the
--- screen snippet (any click closes the dial). DS.Load hands it to the header. Out of combat only.
function DS.NewScreen(header)
    return SE.NewDialScreen(header, SCREEN_PRE)
end

-- A catcher's layout: the ring's shape (size, start in degrees, hub and disc across) and, for each
-- place up to the most a ring has, a forward to the wedge on it; an empty place's two keys are
-- cleared (the second list), so a place a rebuild emptied forwards nothing.
local function catcherAttrs(ring)
    local shape = ring.shape or {}
    local attrs = { ["qc-size"] = shape.size or 1, ["qc-start"] = shape.start or 0, ["qc-hub"] = shape.hub or 0,
        ["qc-disc"] = shape.disc or 0 }
    local clear, onPlace = {}, {}
    for i, w in ipairs(ring.wedges) do onPlace[w.place or i] = w.button end
    for j = 1, math.max(NS.DialLayout.MAX_SLICES, shape.size or 0) do
        if onPlace[j] then
            attrs["*type-w" .. j], attrs["*clickbutton-w" .. j] = "click", onPlace[j]
        else
            clear[#clear + 1] = "*type-w" .. j
            clear[#clear + 1] = "*clickbutton-w" .. j
        end
    end
    return attrs, clear
end

-- Ring r's header attributes, into `attrs`: its parent, key, page, previous and next page and wedge count.
local function ringAttrs(attrs, r, ring)
    attrs["qc-parent-" .. r] = ring.parent or 0
    attrs["qc-key-" .. r] = ring.key or ("ring" .. r)
    attrs["qc-page-" .. r] = ring.page or 1
    attrs["qc-prev-" .. r] = ring.prev or 0
    attrs["qc-next-" .. r] = ring.next or 0
    attrs["qc-n-" .. r] = #ring.wedges
end

-- Ring r's own buttons: each page arrow's target, each wedge's target (its name into the header's
-- `attrs`, for the number keys) and the catcher's layout; then the header's frame ref to the ring.
local function loadRing(header, attrs, r, ring)
    if ring.arrows then
        SE.SetAttributes(ring.arrows.prev, { ["qc-target"] = ring.prev or 0 })
        SE.SetAttributes(ring.arrows.next, { ["qc-target"] = ring.next or 0 })
    end
    for i, w in ipairs(ring.wedges) do
        attrs["qc-name-" .. r .. "-" .. i] = w.button:GetName()
        SE.SetAttributes(w.button, { ["qc-target"] = w.target or 0 })
    end
    if ring.catcher then SE.SetAttributes(ring.catcher, catcherAttrs(ring)) end
    SE.SetFrameRef(header, "ring" .. r, ring.frame)
end

--- Hand the header a plan's rings: per ring its container, its key and page (where a close leaves the
--- next open, OPEN), its parent, previous and next page, its
--- page arrows ({ prev, next }, each targeting that page), its wedges ({ button, target, place }:
--- target 0 for a callout, else the ring a click opens; place its slice, 1..size from `start`) and,
--- when it has one, its catcher with the ring's `shape` ({ size, start, hub, disc }); the ring it opens
--- on and where it opens; (opts.screen) the dial's screen catcher, as the header's frame ref
--- `screen`; and (opts.preview) whether this is a preview or test dial, as `qc-preview` (always
--- written, false for a live plan, so a reload from a preview to live clears it). Out of combat only.
--- @return boolean loaded
function DS.Load(header, rings, opts)
    if NS.Compat.InCombat() then return false end
    opts = opts or {}
    -- The ring it opens on has its own attribute: `qc-open` is the open snippet's.
    local attrs = { ["qc-rings"] = #rings, ["qc-openRing"] = opts.openRing or 1,
        ["qc-openAt"] = opts.openAt == "cursor" and "cursor" or "center", ["qc-preview"] = opts.preview == true }
    for r, ring in ipairs(rings) do
        ringAttrs(attrs, r, ring)
        loadRing(header, attrs, r, ring)
    end
    if opts.screen then SE.SetFrameRef(header, "screen", opts.screen) end
    return SE.SetAttributes(header, attrs)
end

--- Hand each header the others (its siblings), so opening one closes any other that is open: two
--- open dials would overlap at the same place and both hold the number keys. Out of combat only.
--- @return boolean linked
function DS.Link(headers)
    if NS.Compat.InCombat() then return false end
    for _, h in ipairs(headers) do
        local n = 0
        for _, other in ipairs(headers) do
            if other ~= h then
                n = n + 1
                SE.SetFrameRef(h, "sibling" .. n, other)
            end
        end
        SE.SetAttributes(h, { ["qc-siblings"] = n })
    end
    return true
end

--- Open the dial from the insecure side (test mode, Preview as…), taking no key. Out of combat only.
function DS.Open(header)
    return SE.RunSnippet(header, "qc-display")
end

--- Close the dial from the insecure side (a rebuild, a release). Out of combat only.
function DS.Close(header)
    return SE.RunSnippet(header, "qc-close")
end
