local addonName, NS = ...
-- settings/CalloutPopup.lua — the callout popup (callouts-owned-by-groups spec, "The callout popup"):
-- one user group's callout, new or listed, edited as a draft and saved as one act.
--
--     window   Blizzard's settings window (title "Ka0s Quick Comms")             (its close X)
--     header   New callout / Edit callout, the gold rule under it
--     body     Name, Text, Channel, Icon (the member rows' labels, read and written on the draft),
--              with an info glyph beside the Text label whose tooltip lists the tokens; the icon
--              (Choose icon… opens the icon browser over the popup, and a glyph's color swatch),
--              Preview, then Cancel and Save, and under them the line that names a field Save
--              refused
--
-- THE DRAFT is a plain copy of the callout's four fields and its icon's glyph color (blank for Add:
-- an empty name and text, Smart group, no icon, no color), and every control writes it, never the
-- profile. An icon that is no glyph drops the draft's color, as the stored callout would. The
-- preview bakes the draft, and the token tooltip reads its channel when it shows, so both follow
-- each edit before anything is saved. A text box commits to the
-- draft on Enter, and what a box shows that Enter did not commit is taken into the draft before any
-- other write and by Save, so a typed name is never lost to a pick or to a click on Save. Save checks
-- the draft with the member rows' own validators, then writes it as ONE act (Library.Batch): an edit writes each
-- field that differs from the copy taken when the popup opened, through the seam, by id; Add is
-- Library.CreateCalloutIn at the end of the group. A slash write to the same callout meanwhile is not
-- merged: Save writes only what the draft changed. Cancel, the close mark and Escape drop the draft,
-- and so do the settings window hiding, a profile change and the callout ceasing to exist, so a
-- Cancel never leaves a half-saved or empty callout behind.
--
-- THE LOOK is the settings window's. The window is settings/ModalWindow.lua's: Blizzard's own
-- SettingsFrameTemplate (its background, its border with the window title, its close X), and inside
-- it the library's panel factory draws a page's header (title and gold rule); the body is drawn with the same Helpers,
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

-- The member rows the popup draws, in order, and every field the draft carries (the icon's color
-- is drawn with the icon, not as a row of its own).
local FIELDS = { "name", "text", "channel", "icon" }
local DRAFT = { "name", "text", "channel", "icon", "iconColor" }
local WIDTH, HEIGHT = 560, 640   -- HEIGHT until the first fit
-- The page's body starts this far under the panel's top: the library's header (HEADER_HEIGHT, 54)
-- plus its 8 (Options.lua, CreatePanel). The laid-out body sits CHROME_GAP under that, as a page's
-- scroll does, CONTENT_X in from both sides (the pages' left inset, CONTENT_LEFT; there is no
-- scrollbar gutter), with BODY_BOTTOM under it. HEADER_HEIGHT and CONTENT_LEFT are LibKa0s
-- INTERNAL layout keys, and the 8 is not a key at all, restated here because the library publishes
-- none of them (an upstream candidate: a published body offset, or a no-scroll body);
-- tests/test_callout_popup.lua reads BODY_TOP off the body anchor of the panel CreatePanel builds
-- and CONTENT_X from lib.LAYOUT, so a re-vendor that moves any of them turns it red.
local BODY_TOP, CONTENT_X, BODY_BOTTOM = 62, 12, 12
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
    for _, f in ipairs(DRAFT) do out[f] = c[f] end
    if out.icon == false then out.icon = nil end
    if out.iconColor == false then out.iconColor = nil end
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
    if (field == "icon" or field == "iconColor") and value == false then value = nil end
    draft[field] = value
    if field == "icon" and not NS.Library.IsGlyph(value) then draft.iconColor = nil end
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
    if not NS.Library.ValidIconColor(d.iconColor) then
        return "iconColor", Ed.Row("callout.iconColor").label, L["An icon color is six hex digits (rrggbb), or empty for none."]
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
    Ed.IconChooser(ctx, {
        get = function() return draft and draft.icon, draft and draft.iconColor end,
        choose = function(icon, color) Pop.SetIcon(icon, color) end,
        setColor = function(color) setField("iconColor", color) end,
        owner = "popup", lift = { addonName .. "CalloutPopup" },
    })
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

--- The icon browser's Choose: the draft's icon and its glyph color, as one draft write (a color
--- stays only on a glyph).
function Pop.SetIcon(icon, color)
    if not draft then return end
    flush()
    put("icon", icon)
    if NS.Library.IsGlyph(draft.icon) then draft.iconColor = color or nil end
    refresh()
end

-- Hide the popup and drop the draft. The state is cleared first, so the frame's own OnHide (Escape)
-- finds nothing left to cancel. An icon browser opened from the popup closes with it, as Cancel.
local function close()
    gid, cid, draft, baseline = nil, nil, nil, nil
    if Settings.IconBrowser then Settings.IconBrowser.Cancel("popup") end
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

-- The popup and its click-catcher (settings/ModalWindow.lua), built once, on the first Open, in
-- the DIALOG strata (above the settings window); the window is the catcher's child, so it draws
-- above it and its dropdowns' pull-outs above both.
local function build()
    local h = H()
    local w = Settings.ModalWindow.Build({ name = addonName .. "CalloutPopup", pageName = addonName .. "CalloutPopupPage",
        title = L["Edit callout"], width = WIDTH, height = HEIGHT, strata = "DIALOG",
        onClose = function() Pop.Cancel() end })
    ctx, inset = w.ctx, w.inset
    Pop.catcher = w.catcher
    body = makeBody(h)
    -- Hidden with a draft still open (Escape) is a Cancel.
    w.frame:HookScript("OnHide", function() if draft then Pop.Cancel() end end)
    local settingsWindow = _G.SettingsPanel
    if settingsWindow and settingsWindow.HookScript then
        settingsWindow:HookScript("OnHide", function() if draft then Pop.Cancel() end end)
    end
    Pop.frame, Pop.chrome = w.frame, w.chrome
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
        draft = { name = "", text = "", channel = "smartGroup", icon = nil, iconColor = nil }
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
-- texture id back into a number), and an icon or its color false for none.
local function seamValue(field, value)
    if field ~= "icon" and field ~= "iconColor" then return value end
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
            -- DRAFT's order: the icon lands before its color, which the color row checks against.
            for _, f in ipairs(DRAFT) do
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
