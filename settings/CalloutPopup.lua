local addonName, NS = ...
-- settings/CalloutPopup.lua — the callout popup (callouts-owned-by-groups spec, "The callout popup"):
-- one user group's callout, new or listed, edited as a draft and saved as one act.
--
--     window   Blizzard's settings window (title "Ka0s Quick Comms")             (its close X)
--     header   New callout / Edit callout, the gold rule under it
--     body     Name, Text, Channel, Icon (the member rows' labels, read and written on the draft),
--              with an info glyph beside the Text label whose tooltip lists the tokens; Choose an
--              icon, Preview, then Cancel and Save, and under them the line that names a field
--              Save refused
--
-- THE DRAFT is a plain copy of the callout's four fields (blank for Add: an empty name and text,
-- Smart group, no icon), and every control writes it, never the profile. The preview bakes the
-- draft, and the token tooltip reads its channel when it shows, so both follow each edit before
-- anything is saved. A text box commits to the
-- draft on Enter, and what a box shows that Enter did not commit is taken into the draft before any
-- other write and by Save, so a typed name is never lost to a pick or to a click on Save. Save checks
-- the draft with the member rows' own validators, then writes it as ONE act (Library.Batch): an edit writes each
-- field that differs from the copy taken when the popup opened, through the seam, by id; Add is
-- Library.CreateCalloutIn at the end of the group. A slash write to the same callout meanwhile is not
-- merged: Save writes only what the draft changed. Cancel, the close mark and Escape drop the draft,
-- and so do the settings window hiding, a profile change and the callout ceasing to exist, so a
-- Cancel never leaves a half-saved or empty callout behind.
--
-- THE LOOK is the settings window's. The window is Blizzard's own SettingsFrameTemplate (its
-- background, its border with the window title, its close X), and inside it the library's panel
-- factory draws a page's header (title and gold rule); the body is drawn with the same Helpers,
-- picker and button pair as a page, into a plain AceGUI container rather than a scroll frame: the
-- popup has no scrollbar, and the window's height follows the laid-out body (fit, after every
-- refresh and every error line). It is not a page (no sidebar entry, no banner, no Defaults). A
-- client without the template gets the old look: a plain frame, Blizzard's dialog edge and the
-- shared close mark. With EllesmereUI's skin on, settings/CalloutPopup_Skin.lua paints the window's
-- chrome (Pop.chrome) as EllesmereUI paints the settings window. FULLY MODAL: a full-screen
-- click-catcher under it covers the settings window, so the page underneath cannot change while a
-- draft is open. Only one popup exists, built on its first Open.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local C = Settings.Callouts
local L = NS.L

Settings.CalloutPopup = Settings.CalloutPopup or {}
local Pop = Settings.CalloutPopup

local FIELDS = { "name", "text", "channel", "icon" }
local WIDTH, HEIGHT = 560, 640   -- HEIGHT until the first fit
local TEMPLATE = "SettingsFrameTemplate"
-- Where the page sits in the window: inside the template's background (its Bg is inset 7,-18 /
-- -3,3), under the title bar; the fallback window is the page alone.
local INSET_TEMPLATE = { left = 8, top = 24, right = 4, bottom = 5 }
local INSET_PLAIN = { left = 0, top = 0, right = 0, bottom = 0 }
-- The page's body starts this far under the panel's top: the library's header (HEADER_HEIGHT, 54)
-- plus its 8 (Options.lua, CreatePanel). The laid-out body sits CHROME_GAP under that, as a page's
-- scroll does, CONTENT_X in from both sides (the pages' left inset, CONTENT_LEFT; there is no
-- scrollbar gutter), with BODY_BOTTOM under it. HEADER_HEIGHT and CONTENT_LEFT are LibKa0s
-- INTERNAL layout keys, and the 8 is not a key at all, restated here because the library publishes
-- none of them (an upstream candidate: a published body offset, or a no-scroll body);
-- tests/test_callout_popup.lua reads BODY_TOP off the body anchor of the panel CreatePanel builds
-- and CONTENT_X from lib.LAYOUT, so a re-vendor that moves any of them turns it red.
local BODY_TOP, CONTENT_X, BODY_BOTTOM = 62, 12, 12
local DIM = { 0, 0, 0, 0.45 }
-- The catcher's frame level in its strata. Above it, in order: the template's Bg (LEVEL + 1; the
-- template declares it at absolute level 0, which would put it under the catcher's dim), the window
-- with its border (LEVEL + 2), the page (LEVEL + 3) and the close X (LEVEL + 5).
local LEVEL = 10
local ERROR_COLOR = "|cffff4040"
-- The gap between the preview and the button pair, a section's worth (two row gaps).
local BUTTONS_GAP = 16
-- The token glyph: GLYPH_GAP right of the Text label's last letter, sized to the label's font
-- (its size plus 4, kept within GLYPH_MIN to GLYPH_MAX).
local GLYPH_GAP, GLYPH_MIN, GLYPH_MAX = 4, 14, 16

-- The open popup's state: the group, the callout (nil for Add), the draft and its baseline.
local gid, cid, draft, baseline
local ctx, errorRow
-- The plain container the body is laid out in (ctx.scroll), and where the page sits in the window.
local body, inset
-- The popup's text boxes by field, and the text each last showed of the draft (see flush).
local boxes, shown = {}, {}

local function H() return Settings.Helpers end

local function copyFields(c)
    local out = {}
    for _, f in ipairs(FIELDS) do out[f] = c[f] end
    if out.icon == false then out.icon = nil end
    return out
end

-- UTF-8 characters in `s`, as the EditBox counts its letters.
local function chars(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

-- Put every control and line the popup draws back to the draft (a draft write is no seam write, so
-- nothing else refreshes them).
local function refresh()
    for _, fn in ipairs(ctx and ctx.refreshers or {}) do pcall(fn) end
end

local function put(field, value, row)
    if row and type(row.normalize) == "function" then value = row.normalize(value) end
    if field == "icon" and value == false then value = nil end
    draft[field] = value
end

-- Take into the draft what the player typed in a box and did not commit with Enter: a box whose
-- text is not what it last showed of the draft. Clicking Save is the commit gesture here, and any
-- other draft write, or a seam write (it refreshes the popup with every rendered panel), would
-- otherwise put each box back over the typed text.
local function flush()
    if not draft then return end
    for field, box in pairs(boxes) do
        local text = box:GetText() or ""
        if text ~= tostring(shown[field] or "") then
            put(field, text, Ed.Row("callout." .. field))
            shown[field] = text
        end
    end
end

local function setField(field, value, row)
    if not draft then return end
    flush()
    put(field, value, row)
    refresh()
end

--- The four member rows, bound to the draft: each a copy with no path and its own get and set
--- (LibKa0s draws a path-less row through them), so the popup shows the rows' own labels, help and
--- channel list and writes nothing until Save.
local function draftRows()
    local out = {}
    for i, field in ipairs(FIELDS) do
        local row = Ed.Row("callout." .. field)
        local copy = {}
        for k, v in pairs(row) do copy[k] = v end
        copy.path, copy.validate, copy.onChange = nil, nil, nil
        copy.get = function()
            shown[field] = draft and draft[field]
            return shown[field]
        end
        copy.set = function(value) setField(field, value, row) end
        out[i] = copy
    end
    return out
end

-- Check the draft with the member rows' validators. Answers the field that failed and why.
local function check(d)
    local name = Ed.Row("callout.name")
    local ok, why = name.validate(d.name)
    if not ok then return "name", name.label, why end
    local text = Ed.Row("callout.text")
    ok, why = text.validate(d.text)
    if ok and chars(d.text) > text.maxLetters then
        ok, why = false, L["Text is at most %d characters."]:format(text.maxLetters)
    end
    if not ok then return "text", text.label, why end
    local channel = Ed.Row("callout.channel")
    ok, why = channel.validate(d.channel)
    if not ok then return "channel", channel.label, why end
    if not NS.Library.ValidIcon(d.icon) then
        return "icon", Ed.Row("callout.icon").label, L["An icon is a texture id or a texture path."]
    end
    return nil
end

-- Size the window to the body: lay it out (AceGUI's List layout sets the container's height to its
-- children's), then measure it. Run after every refresh and every error line, so a preview that
-- gains a line or an error that appears grows the window rather than spilling out of it.
local function fit()
    if not (body and Pop.frame) then return end
    if body.DoLayout then body:DoLayout() end
    local h = body.frame:GetHeight() or 0
    local gap = H().CHROME_GAP or 8
    Pop.frame:SetHeight(inset.top + BODY_TOP + gap + h + BODY_BOTTOM + inset.bottom)
end

local function showError(text)
    if errorRow then errorRow:SetText(text and (ERROR_COLOR .. text .. "|r") or "") end
    fit()
end

-- The token tooltip: every token the draft's channel offers, one line each (C.TokenHelp), read
-- when it shows, so a channel picked since the render is the one it lists.
local function showTokenHelp(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Tokens"], 1, 1, 1)
    GameTooltip:AddLine(L["Type a token into the text. It is filled in when the callout is sent."], nil, nil, nil,
        true)
    for _, line in ipairs(C.TokenHelp(draft and draft.channel)) do
        GameTooltip:AddDoubleLine(line[1], line[2], 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

-- The info glyph beside the Text box's label (the library's catalog "info" mark). As the library
-- keeps its landing logo (OptionsWidgets.lua, landingLogo): the glyph is kept ON the box's frame
-- and reused, so a frame that comes back for the Text box again cannot gain a second one, and it
-- is hidden when the box is released, so a frame AceGUI hands to any other EditBox does not show
-- it. The release callback is set fresh on every render (AceGUI clears callbacks on release), and
-- the anchor is set again each time, on the label as it is now.
local function tokenGlyph(box)
    local frame, label = box and box.frame, box and box.label
    if not (frame and label) then return nil end
    local glyph = frame.qcTokenGlyph
    if not glyph then
        glyph = CreateFrame("Button", nil, frame)
        glyph.icon = glyph:CreateTexture(nil, "ARTWORK")
        glyph.icon:SetAllPoints(glyph)
        glyph:EnableMouse(true)
        glyph:SetScript("OnEnter", showTokenHelp)
        glyph:SetScript("OnLeave", hideTooltip)
        frame.qcTokenGlyph = glyph
    end
    glyph.icon:SetTexture(NS.Icon("info"))
    local _, fontSize = label:GetFont()
    local size = math.max(GLYPH_MIN, math.min(GLYPH_MAX, (tonumber(fontSize) or 0) + 4))
    glyph:SetSize(size, size)
    glyph:ClearAllPoints()
    glyph:SetPoint("LEFT", label, "LEFT", (tonumber(label:GetStringWidth()) or 0) + GLYPH_GAP, 0)
    glyph:Show()
    box:SetCallback("OnRelease", function()
        hideTooltip()
        glyph:Hide()
    end)
    return glyph
end

-- The AceGUI EditBoxes under widget `w`, in the order they were drawn.
local function editBoxes(w, out)
    for _, child in ipairs(w and w.children or {}) do
        if child.type == "EditBox" then out[#out + 1] = child end
        editBoxes(child, out)
    end
    return out
end

local function render()
    local h = H()
    h.ClearScroll(ctx)
    ctx.qcLive = {}
    boxes, shown = {}, {}
    -- First, so every refresh (the popup's own and a seam write's) takes the typed text in before
    -- the boxes' refreshers put the draft back into them.
    ctx.refreshers[#ctx.refreshers + 1] = flush
    local rows = draftRows()
    h.RenderRows(ctx, rows, nil, nil, { noHeadings = true })
    -- The member rows are the body's only content yet, so its boxes are theirs, in row order.
    local drawn, n = editBoxes(body, {}), 0
    for i, row in ipairs(rows) do
        if row.dialogControl == "EditBox" then
            n = n + 1
            boxes[FIELDS[i]] = drawn[n]
        end
    end
    Pop.tokenGlyph = tokenGlyph(boxes.text)
    Ed.IconPicker(ctx, function(path) setField("icon", path) end)
    h.Section(ctx, L["Preview"])
    -- One label, refreshed in place on every draft write and every situation change.
    local live = h.TextRow(ctx, table.concat(C.PreviewLines(draft), "\n"))
    Ed.Live(ctx, function()
        if draft and live then live:SetText(table.concat(C.PreviewLines(draft), "\n")) end
    end)
    h.AddSpacer(ctx.scroll, BUTTONS_GAP)
    h.InlineButtonPair(ctx,
        { text = L["Cancel"], tooltip = L["Close without saving. Nothing changes."],
          onClick = function() Pop.Cancel() end },
        { text = L["Save"], tooltip = L["Save this callout to the group and close."],
          onClick = function() Pop.Save() end })
    errorRow = h.TextRow(ctx, "")
    -- Last, so it measures what every refresher before it has just redrawn.
    ctx.refreshers[#ctx.refreshers + 1] = fit
    fit()
end

-- Hide the popup and drop the draft. The state is cleared first, so the frame's own OnHide (Escape)
-- finds nothing left to cancel.
local function close()
    gid, cid, draft, baseline = nil, nil, nil, nil
    errorRow = nil
    Pop.tokenGlyph = nil
    boxes, shown = {}, {}
    if ctx then
        H().ClearScroll(ctx)
        ctx.qcLive = {}
        ctx.panel:Hide()
    end
    if Pop.frame then Pop.frame:Hide() end
    if Pop.catcher then Pop.catcher:Hide() end
end

local function isTable(v) return type(v) == "table" end

-- The window: SettingsFrameTemplate when the client has it and it still has the parts used here
-- (NineSlice with its title, Bg, ClosePanelButton), else a plain frame. Answers the window and its
-- chrome: what the skin paints, and whether the template drew it.
local function makeWindow(parent)
    local name = addonName .. "CalloutPopup"
    local f
    -- A client that says it lacks the template is not asked; one that cannot say is, under pcall.
    if NS.Compat.HasTemplate(TEMPLATE) ~= false then
        local ok, made = pcall(CreateFrame, "Frame", name, parent, TEMPLATE)
        if ok then f = made end
    end
    if f and isTable(f.NineSlice) and isTable(f.ClosePanelButton) then
        if isTable(f.NineSlice.Text) then f.NineSlice.Text:SetText(NS.BRAND) end
        return f, { template = true, window = f, nineSlice = f.NineSlice,
            bg = isTable(f.Bg) and f.Bg or nil, close = f.ClosePanelButton }
    end
    return f or CreateFrame("Frame", name, parent), { template = false }
end

-- The fallback's chrome, as the popup looked before the template: Blizzard's dialog edge over a
-- dark fill under the page, and the shared close mark.
local function plainChrome(window, panel, chrome)
    local bg = CreateFrame("Frame", nil, window, "BackdropTemplate")
    bg:SetAllPoints(window)
    bg:SetFrameLevel(LEVEL + 1)
    if bg.SetBackdrop then
        bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 11, top = 11, bottom = 11 },
        })
        bg:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    end
    local closeButton = NS.MakeCloseButton(panel, function() Pop.Cancel() end)
    if closeButton then closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -12) end
    chrome.window, chrome.bg, chrome.close = window, bg, closeButton
end

-- The body: a plain AceGUI container in the page's body, where a page has its scroll frame. The
-- library draws a page's rows into ctx.scroll and builds a scroll frame only when there is none
-- (EnsureScroll), so this one is laid out with no scroll frame and no scrollbar.
local function makeBody(h)
    local group = h.AceGUI and h.AceGUI:Create("SimpleGroup")
    if not group then return nil end
    group:SetLayout("List")
    group.frame:SetParent(ctx.body)
    group.frame:ClearAllPoints()
    group.frame:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", CONTENT_X, -(h.CHROME_GAP or 8))
    group:SetWidth(WIDTH - inset.left - inset.right - 2 * CONTENT_X)
    group.frame:Show()
    ctx.scroll = group
    return group
end

-- The popup and its click-catcher, built once, on the first Open. The catcher is a full-screen
-- button in the DIALOG strata (above the settings window) that swallows every click and wheel; the
-- window is its child, so it draws above it and its dropdowns' pull-outs above both.
local function build()
    local h = H()
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(LEVEL)
    catcher:EnableMouse(true)
    catcher:EnableMouseWheel(true)
    catcher:SetScript("OnMouseWheel", function() end)
    local dim = catcher:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(catcher)
    dim:SetColorTexture(DIM[1], DIM[2], DIM[3], DIM[4])
    catcher:Hide()
    Pop.catcher = catcher

    local window, chrome = makeWindow(catcher)
    inset = chrome.template and INSET_TEMPLATE or INSET_PLAIN
    -- The strata again: a template may name its own, and the window must stay above the catcher.
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(LEVEL + 2)
    window:SetSize(WIDTH, HEIGHT)
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:EnableMouse(true)

    -- The library's panel factory: the settings pages' header, body and refresh registry.
    ctx = h.CreatePanel(addonName .. "CalloutPopupPage", L["Edit callout"], { isMain = true })
    local panel = ctx.panel
    panel:SetParent(window)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", inset.left, -inset.top)
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -inset.right, inset.bottom)
    panel:SetFrameLevel(LEVEL + 3)
    if chrome.template then
        -- The template's Bg, over the catcher's dim and under the border: at its declared level 0
        -- the dim would draw over it, and the popup would be darker than the settings window.
        if chrome.bg then chrome.bg:SetFrameLevel(LEVEL + 1) end
        -- The template's close X (an accepted deviation, docs/ARCHITECTURE.md): a click is a
        -- Cancel, and it sits above the page, whose top edge it overlaps.
        chrome.close:SetScript("OnClick", function() Pop.Cancel() end)
        chrome.close:SetFrameLevel(LEVEL + 5)
    else
        plainChrome(window, panel, chrome)
    end
    body = makeBody(h)
    -- Escape hides a special frame; hidden with a draft still open is a Cancel.
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = addonName .. "CalloutPopup" end
    window:HookScript("OnHide", function() if draft then Pop.Cancel() end end)
    local settingsWindow = _G.SettingsPanel
    if settingsWindow and settingsWindow.HookScript then
        settingsWindow:HookScript("OnHide", function() if draft then Pop.Cancel() end end)
    end
    Pop.frame, Pop.chrome = window, chrome
    local skin = Settings.CalloutPopupSkin
    if skin then skin.TryApply() end
end

--- Open the popup on user group `groupId`: on callout `calloutId`, filled in, or with no callout
--- for Add. Replaces any open popup.
--- @return boolean opened (false for a group or callout that is not the player's)
function Pop.Open(groupId, calloutId)
    if draft then Pop.Cancel() end
    local p = NS.db and NS.db.profile
    if not (p and p.groups[groupId]) then return false end
    if calloutId ~= nil and not p.callouts[calloutId] then return false end
    if not ctx then build() end
    gid, cid = groupId, calloutId
    if calloutId then
        baseline = copyFields(p.callouts[calloutId])
        draft = copyFields(baseline)
    else
        baseline = nil
        draft = { name = "", text = "", channel = "smartGroup", icon = nil }
    end
    local title = calloutId and L["Edit callout"] or L["New callout"]
    ctx.panel.title:SetText(title)
    ctx.panel.titleText = title
    Pop.catcher:Show()
    Pop.frame:Show()
    ctx.panel:Show()
    render()
    return true
end

-- The value the seam row takes for a draft field: an icon as text (the row's normalize turns a
-- texture id back into a number) or false for none.
local function seamValue(field, value)
    if field ~= "icon" then return value end
    if value == nil then return false end
    return tostring(value)
end

--- Save the draft. A field that fails keeps the popup open and names the field; otherwise one act
--- writes it and the popup closes. A callout gone since the popup opened writes nothing.
--- @return boolean ok, string|nil reason (the field that failed, "noCallout", "noGroup", "notOpen")
function Pop.Save()
    if not draft then return false, "notOpen" end
    local p = NS.db.profile
    if cid and not p.callouts[cid] then
        Pop.Cancel()
        return false, "noCallout"
    end
    flush()
    local field, label, why = check(draft)
    if field then
        showError(L["%s: %s"]:format(label, tostring(why)))
        return false, field
    end
    local ok, reason
    if cid then
        local S, id, d, base = NS.SchemaRuntime, cid, draft, baseline
        ok, reason = NS.Library.Batch(function()
            for _, f in ipairs(FIELDS) do
                if d[f] ~= base[f] then
                    local done, err, w = S.Set("callout." .. f, seamValue(f, d[f]), id)
                    if not done then return false, tostring(w or err) end
                end
            end
            return true
        end)
    else
        ok, reason = NS.Library.CreateCalloutIn(gid, draft)
        ok = ok ~= nil
    end
    if not ok then
        showError(tostring(reason or ""))
        return false, reason
    end
    close()
    return true
end

--- Drop the draft and close. Nothing is written.
function Pop.Cancel()
    close()
end

function Pop.IsOpen()
    return draft ~= nil
end

--- The open draft (for tests), or nil.
function Pop.Draft()
    return draft
end

-- ── what closes it ──────────────────────────────────────────────────────────────────────────

local function onLibraryChanged()
    if not draft then return end
    local p = NS.db.profile
    if not p.groups[gid] or (cid and not p.callouts[cid]) then Pop.Cancel() end
end

local function refreshLive()
    if not (draft and ctx) then return end
    for _, fn in ipairs(ctx.qcLive or {}) do pcall(fn) end
    fit()
end

local HANDLERS = {
    { NS.MSG.LIBRARY_CHANGED, onLibraryChanged },
    { NS.MSG.PROFILE_CHANGED, function() if draft then Pop.Cancel() end end },
    { NS.MSG.SITUATION_CHANGED, refreshLive },
    { NS.MSG.TEST_MODE_CHANGED, refreshLive },
}

-- Its own target (core/Bus.lua): one target holds several different messages.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if not receiver then return end
    for _, h in ipairs(HANDLERS) do receiver:RegisterMessage(h[1], h[2]) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if draft then Pop.Cancel() end
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
