local addonName, NS = ...
-- settings/CalloutPopup.lua — the callout popup (callouts-owned-by-groups spec, "The callout popup"):
-- one user group's callout, new or listed, edited as a draft and saved as one act.
--
--     header   New callout / Edit callout                                   (close mark)
--     body     Name, Text, Channel, Icon (the member rows' labels, read and written on the draft),
--              Insert a token, Choose an icon, What it sends here, then Save and Cancel, and under
--              them the line that names a field Save refused
--
-- THE DRAFT is a plain copy of the callout's four fields (blank for Add: an empty name and text,
-- Smart group, no icon), and every control writes it, never the profile. The preview and the token
-- list bake the draft, so they follow each edit before anything is saved. A text box commits to the
-- draft on Enter, and what a box shows that Enter did not commit is taken into the draft before any
-- other write and by Save, so a typed name is never lost to a pick or to a click on Save. Save checks
-- the draft with the member rows' own validators, then writes it as ONE act (Library.Batch): an edit writes each
-- field that differs from the copy taken when the popup opened, through the seam, by id; Add is
-- Library.CreateCalloutIn at the end of the group. A slash write to the same callout meanwhile is not
-- merged: Save writes only what the draft changed. Cancel, the close mark and Escape drop the draft,
-- and so do the settings window hiding, a profile change and the callout ceasing to exist, so a
-- Cancel never leaves a half-saved or empty callout behind.
--
-- THE LOOK is the settings panel's: the library's panel factory draws the header (title and gold
-- rule) and the body is drawn with the same Helpers, picker and button pair as a page. It is not a
-- page (no sidebar entry, no banner, no Defaults). FULLY MODAL: a full-screen click-catcher under it
-- covers the settings window, so the page underneath cannot change while a draft is open. Only one
-- popup exists, built on its first Open.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local C = Settings.Callouts
local L = NS.L

Settings.CalloutPopup = Settings.CalloutPopup or {}
local Pop = Settings.CalloutPopup

local FIELDS = { "name", "text", "channel", "icon" }
local WIDTH, HEIGHT = 560, 640
local DIM = { 0, 0, 0, 0.45 }
local LEVEL = 10    -- the catcher's frame level in its strata; the backdrop and the popup sit above it
local ERROR_COLOR = "|cffff4040"

-- The open popup's state: the group, the callout (nil for Add), the draft and its baseline.
local gid, cid, draft, baseline
local ctx, errorRow
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

local function showError(text)
    if errorRow then errorRow:SetText(text and (ERROR_COLOR .. text .. "|r") or "") end
end

-- The token picker's entries for the draft's channel as it is now.
local function tokenEntries()
    local out = {}
    for i, token in ipairs(C.TokensFor(draft and draft.channel)) do out[i] = { id = token, label = token } end
    return out
end

local function insertToken(token)
    if not draft then return end
    flush()
    local text = draft.text or ""
    local sep = (text == "" or text:sub(-1) == " ") and "" or " "
    setField("text", text .. sep .. token)
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
    -- The member rows are the scroll's only content yet, so its boxes are theirs, in row order.
    local drawn, n = editBoxes(ctx.scroll, {}), 0
    for i, row in ipairs(rows) do
        if row.dialogControl == "EditBox" then
            n = n + 1
            boxes[FIELDS[i]] = drawn[n]
        end
    end
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Insert a token"],
        L["Add a token to the end of the text. Tokens are filled in when the callout is sent."],
        tokenEntries, insertToken, ctx) })
    Ed.IconPicker(ctx, function(path) setField("icon", path) end)
    h.Section(ctx, L["What it sends here"])
    -- One label, refreshed in place on every draft write and every situation change.
    local live = h.TextRow(ctx, table.concat(C.PreviewLines(draft), "\n"))
    Ed.Live(ctx, function()
        if draft and live then live:SetText(table.concat(C.PreviewLines(draft), "\n")) end
    end)
    h.InlineButtonPair(ctx,
        { text = L["Save"], tooltip = L["Save this callout to the group and close."],
          onClick = function() Pop.Save() end },
        { text = L["Cancel"], tooltip = L["Close without saving. Nothing changes."],
          onClick = function() Pop.Cancel() end })
    errorRow = h.TextRow(ctx, "")
end

-- Hide the popup and drop the draft. The state is cleared first, so the frame's own OnHide (Escape)
-- finds nothing left to cancel.
local function close()
    gid, cid, draft, baseline = nil, nil, nil, nil
    errorRow = nil
    boxes, shown = {}, {}
    if ctx then
        H().ClearScroll(ctx)
        ctx.qcLive = {}
        ctx.panel:Hide()
    end
    if Pop.catcher then Pop.catcher:Hide() end
end

-- The popup and its click-catcher, built once, on the first Open. The catcher is a full-screen
-- button in the DIALOG strata (above the settings window) that swallows every click and wheel; the
-- popup is its child, so it draws above it and its dropdowns' pull-outs above both.
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

    -- The library's panel factory: the settings pages' header, body and refresh registry.
    ctx = h.CreatePanel(addonName .. "CalloutPopup", L["Edit callout"], { isMain = true })
    local panel = ctx.panel
    panel:SetParent(catcher)
    panel:SetSize(WIDTH, HEIGHT)
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameLevel(LEVEL + 2)
    panel:EnableMouse(true)
    -- Blizzard's dialog edge over a dark fill, between the catcher and the popup's own content.
    local bg = CreateFrame("Frame", nil, catcher, "BackdropTemplate")
    bg:SetAllPoints(panel)
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
    -- Escape hides a special frame; hidden with a draft still open is a Cancel.
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = addonName .. "CalloutPopup" end
    panel:HookScript("OnHide", function() if draft then Pop.Cancel() end end)
    local window = _G.SettingsPanel
    if window and window.HookScript then
        window:HookScript("OnHide", function() if draft then Pop.Cancel() end end)
    end
    Pop.frame = panel
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
