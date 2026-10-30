local addonName, NS = ...
-- settings/IconBrowser.lua — the icon browser (icon browser spec): a window over whatever opened it
-- (the callout popup, a user group's General tab) where an icon is picked from every source
-- settings/IconBrowser_Sources.lua offers, and a glyph's color with it.
--
--     window   settings/ModalWindow.lua's (the callout popup's chrome), title "Ka0s Quick Comms"
--     header   Choose an icon, the gold rule under it
--     tabs     [ Markers ][ Game icons ][ Glyphs ]   (the library's tab strip)
--     toolbar  Game icons: Show All / Spells / Items. Glyphs: Show All or one icon set (Open
--              Iconic / Phosphor / Game-icons, from the library), then the glyph color swatch. Then
--              the search box (a magnifier, a clear mark), and at the right how many icons the tab
--              holds, or "N of M icons" while a search narrows it.
--     grid     COLS x ROWS icons and a scrollbar, GRID_GAP under the toolbar; the mouse wheel
--              scrolls too
--     hint     Game icons only: search by texture id, Wowhead for a name, and a button that shows
--              Wowhead's icon address in a copy window (the client cannot open a web page)
--     footer   the selected icon (a glyph in the color) and its name, then Choose and Cancel
--
-- A click on an icon selects it, a double-click chooses it, and hovering one names it (its label,
-- or a game icon's texture id; a glyph's tooltip also names its set, and a Game-icons mark its
-- author, as CC BY 3.0 asks). Choose hands the opener the icon and, for a glyph, the color (none
-- for white), then closes; the opener writes it (the popup's draft, or the group's icon and color as
-- one act). Cancel, the close X and Escape change nothing. The stored icon is preselected, and its
-- tab opened and scrolled to it. An icon no tab lists (a built-in set's spell icon, a typed texture
-- path), or none, opens on Markers, the first tab, with nothing selected: the footer asks for a
-- click, and Choose waits for one.
--
-- SEARCH filters the shown tab as it is typed (IconBrowser_Sources.lua's Search: a marker by name,
-- a glyph by catalog key or label, a game icon by texture id), from the top. The text is the
-- session's: a tab switch and a later open keep it and filter again.
--
-- THE GRID IS VIRTUALIZED: COLS x ROWS cell buttons are built once and re-dressed from the tab's
-- list at the scroll offset, so the Game icons tab's thousands of entries cost a few dozen frames.
--
-- STACKING (QC-06, settings/ModalWindow.lua). The catcher and the window are in the modals'
-- FULLSCREEN strata, over the preview dial, with the popup; the browser's band of levels
-- (MW.LEVEL_OVER) is far above the popup's, so it is modal to whatever opened it. The swatch is AceGUI's ColorPicker, which
-- raises Blizzard's ColorPickerFrame to FULLSCREEN_DIALOG, above the browser; the filter's pull-out
-- is there too. The picker is not modal, so one the swatch opened is hidden when the browser closes
-- (Ed.ReleasePicker). ESCAPE hides every shown special frame, so while the browser is open the opener's
-- own special frame (the popup's, `lift`) is taken out of UISpecialFrames and put back on the next
-- frame after the browser closes (never while the client walks the list): Escape closes the browser
-- only.
--
-- WHAT CLOSES IT, as Cancel: its opener closing (the popup's close calls Cancel("popup")), the
-- settings window hiding, a profile change, the opener's member ceasing to exist (`valid`), and a
-- stand-down. In combat the library's cover lies over its page, as over every settings page, and
-- Choose is refused: nothing is written in combat. Only one browser exists, built on its first Open.
--
-- THE SKIN (QC-02). The window is settings/ModalWindow.lua's (the skin's window under every skin,
-- Ka0s Default included since LibKa0s v1.81.0, R-2); the
-- page and the parts drawn here follow the owner's skin. Every color is a token, today's pixel on
-- Ka0s Default: the selected cell this addon's qc.selStrong (gold at 0.7; it follows list.sel), the
-- empty footer line qc.note (|cffaaaaaa), the search magnifier log.tag and its clear mark
-- qc.markGray, the hint box drawer.boxBg / drawer.boxBorder (a settings drawer's box), the texts
-- their roles in the skin's body face (the count text.disabled, the icon's name text.heading, the
-- status and the hint text.highlight), the tooltip lines gtip.value and the credit gtip.subtle. The scroller is the
-- skin's ScrollBar, a corridor and a flat knob over its own track (D3: under Ka0s Default too, as
-- every scroll bar the library paints). The cell's hover highlight stays the client's art (D8).
-- Host-drawn colors repaint on every looks change.

local QC = NS.addon
local Settings = QC.Settings
local Src = Settings.IconBrowserSources
local L = NS.L

Settings.IconBrowser = Settings.IconBrowser or {}
local B = Settings.IconBrowser

B.COLS, B.ROWS = 12, 7
local COLS, ROWS = B.COLS, B.ROWS
local CELL, ICON = 40, 32           -- a cell's pitch, and the icon in it
local WIDTH, HEIGHT = 560, 594
-- As settings/CalloutPopup.lua restates them: the pages' left inset and the gap under the body.
local CONTENT_X, BODY_BOTTOM = 12, 12
-- The toolbar's band over the grid, and the gap between them (the swatch's row would touch the
-- grid's first row). HEIGHT leaves the hint (HINT_GAP + HINT_H) and the footer (34) their bands
-- under the grid, below the header, a one-row tab strip and the gaps.
local TOOLBAR_H, GRID_GAP = 30, 10
local HINT_GAP, HINT_H = 8, 36
B.GRID_TOP = TOOLBAR_H + GRID_GAP
-- The game filter is TOOL_W wide; the search box sits SEARCH_GAP after it (at the left edge on
-- Markers, which has no control), SEARCH_W wide. Glyphs carries two controls, the set filter (SET_W)
-- and the swatch (SWATCH_W), so its search box is narrower (SEARCH_W_GLYPHS) and the count keeps
-- its room at the right.
local TOOL_W, SEARCH_GAP, SEARCH_W, SEARCH_GLYPH = 180, 10, 190, 14
local SET_W, SWATCH_W, SEARCH_W_GLYPHS = 130, 110, 160
-- The selected cell's wash and the empty footer line's gray (this addon's own tokens, X1).
local SELECTED, NOTE = "qc.selStrong", "qc.note"
-- The combat refusal's chat line. Chat output, not a skinned surface (DECISIONS X7).
local CHAT_GRAY = "|cffaaaaaa"
-- The magnifier's muted gold and the clear mark's gray (the approved mockup's), and the hint's box:
-- the fill and edge of a LibKa0s drawer's box, so it reads as the settings panel does.
local MUTED_GOLD, MARK_GRAY = "log.tag", "qc.markGray"
local HINT_FILL, HINT_EDGE = "drawer.boxBg", "drawer.boxBorder"
B.WOWHEAD_ICONS = "https://www.wowhead.com/icons"

B.TABS = {
    { key = "markers", label = L["Markers"], tooltip = L["The eight raid target markers."] },
    { key = "game", label = L["Game icons"], tooltip = L["Every icon the macro icon picker offers."] },
    { key = "glyphs", label = L["Glyphs"], tooltip = L["Every LibKa0s glyph. A glyph is drawn in the color you pick."] },
}
local FILTERS = { all = L["All"], spells = L["Spells"], items = L["Items"] }
local FILTER_ORDER = { "all", "spells", "items" }
-- The tabs that hold glyphs, where the toolbar shows the color swatch.
local SWATCH_TABS = { glyphs = true }
local FIRST_TAB = B.TABS[1].key
local TAB_KEYS = {}
for _, t in ipairs(B.TABS) do TAB_KEYS[t.key] = true end

-- The open request ({ icon, color, onChoose, owner, lift, valid }), nil while closed, and what the
-- browser shows: the tab, the game filter, the glyph set, the tab's list (searched) and how many the
-- tab holds, the selection, the glyph color, the first visible row. `search` is the session's typed
-- text, kept while closed.
local request
local tab, filter, list, total, loaded, selected, color, offset = FIRST_TAB, "all", {}, 0, true, nil, nil, 0
local glyphSet = "all"
local search = ""
local ctx, area, grid, slider, status, count, filterDD, setsDD, swatch, preview, nameText, chooseBtn, cancelBtn
local searchBox, clearMark, hint, hintText, linkBtn, linkWin
-- The host-drawn parts a looks change repaints: the scroller's track, the hint box's fill and edges,
-- and each search glyph with its token.
local track, hintFill, hintEdges, magnifier, clearGlyph
local glyphs = {}
-- And each text through the skin's Text with its color token: the token's color and the skin's
-- body face, replayed by the library on a looks change. LibKa0s v1.81.0 retired the stock look under
-- Ka0s Default (R-2, Ka0sAddonsCommonTasks D-06), so these strings take Ka0s Default's face inside its
-- window, as the window's title does; Ignore fonts gives the font objects' faces back.
local drawing = false
B.cells = {}

local function H() return Settings.Helpers end

local function paintText(fs, token)
    NS.Skin.Text(fs, token)
end

-- ── Escape: the opener's special frame, out while the browser is open ───────────────────────

local lifted, pending = {}, {}

local function unlist(name)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            table.remove(UISpecialFrames, i)
            return true
        end
    end
    return false
end

local function lift(names)
    if type(UISpecialFrames) ~= "table" then return end
    for _, name in ipairs(names or {}) do
        if pending[name] or unlist(name) then
            pending[name] = nil
            lifted[name] = true
        end
    end
end

-- On the next frame: an Escape that hid the browser is still walking the list now.
local function putBack()
    for name in pairs(lifted) do
        pending[name] = true
        lifted[name] = nil
    end
    if next(pending) == nil then return end
    QC:ScheduleTimer(function()
        for name in pairs(pending) do
            pending[name] = nil
            unlist(name)
            UISpecialFrames[#UISpecialFrames + 1] = name
        end
    end, 0)
end

-- ── drawing ─────────────────────────────────────────────────────────────────────────────────

local function maxOffset()
    return math.max(0, math.ceil(#list / COLS) - ROWS)
end

local function dressCell(cell, v)
    cell.qcIcon = v
    if v == nil then
        cell:Hide()
        return
    end
    cell.icon:SetTexture(v)
    cell.icon:SetVertexColor(NS.Library.IconTint(v, color))
    cell.selected:SetShown(v == selected)
    cell:Show()
end

local function drawFooter()
    if selected ~= nil then
        preview:SetTexture(selected)
        preview:SetVertexColor(NS.Library.IconTint(selected, color))
        preview:Show()
        nameText:SetText(Src.Label(selected))
    else
        preview:Hide()
        nameText:SetText((NS.SkinEscape(NOTE) or "") .. L["Click an icon to select it."] .. "|r")
    end
    chooseBtn:SetDisabled(selected == nil)
end

-- Whether the typed text narrows the tab (Search ignores a blank one).
local function searching()
    return search:match("%S") ~= nil
end

local function drawStatus()
    if #list > 0 then
        status:Hide()
        return
    end
    local text = L["Nothing to show here."]
    if not loaded then
        text = L["The game's icon list has not loaded yet. Open this tab again in a moment."]
    elseif searching() and total > 0 then
        text = L["No icon matches your search."]
    end
    status:SetText(text)
    status:Show()
end

-- A cell's hover tooltip: its icon's name and what a click does.
local function tooltip(cell)
    if cell.qcIcon == nil or not GameTooltip then return end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:SetText(Src.Label(cell.qcIcon))
    local credit = Src.Credit(cell.qcIcon)
    if credit then
        local r, g, b = NS.SkinColor("gtip.subtle")
        GameTooltip:AddLine(credit, r, g, b, true)
    end
    local r, g, b = NS.SkinColor("gtip.value")
    GameTooltip:AddLine(L["Click to select it, double-click to choose it."], r, g, b, true)
    GameTooltip:Show()
end

-- The grid is virtualized: a scroll re-dresses the cell under the pointer without a new OnEnter,
-- so the tooltip a cell owns is re-said for its new icon, or hidden when the cell went empty.
local function refreshTooltip()
    if not GameTooltip or not GameTooltip:IsShown() then return end
    local owner = GameTooltip:GetOwner()
    for _, cell in ipairs(B.cells) do
        if cell == owner then
            if cell.qcIcon ~= nil and cell:IsShown() then tooltip(cell) else GameTooltip:Hide() end
            return
        end
    end
end

-- Re-dress every cell from the list at the offset, and the scrollbar, the count and the footer.
local function draw()
    drawing = true
    offset = math.max(0, math.min(offset, maxOffset()))
    for i, cell in ipairs(B.cells) do dressCell(cell, list[offset * COLS + i]) end
    slider:SetMinMaxValues(0, maxOffset())
    slider:SetValue(offset)
    slider:SetShown(maxOffset() > 0)
    count:SetText(searching() and L["%d of %d icons"]:format(#list, total) or L["%d icons"]:format(#list))
    drawStatus()
    drawFooter()
    refreshTooltip()
    drawing = false
end

local function setOffset(v)
    v = math.max(0, math.min(math.floor(v + 0.5), maxOffset()))
    if v == offset then return end
    offset = v
    draw()
end

-- The search box's text inset between its magnifier and its clear mark. AceGUI's EditBox resets
-- its input's insets to 0 (HideButton) on SetText, Enter and a drop, so each of those re-applies it.
local function applyInsets()
    local input = searchBox and (searchBox.editbox or searchBox.frame)
    if input and input.SetTextInsets then input:SetTextInsets(SEARCH_GLYPH + 4, SEARCH_GLYPH + 6, 3, 3) end
end

-- The search box after the tab's own controls (none on Markers), its text and its clear mark.
local function drawSearch()
    local x, w = 0, SEARCH_W
    if tab == "game" then
        x = TOOL_W + SEARCH_GAP
    elseif SWATCH_TABS[tab] then
        x, w = SET_W + SWATCH_W + 2 * SEARCH_GAP, SEARCH_W_GLYPHS
    end
    searchBox:SetWidth(w)
    searchBox.frame:ClearAllPoints()
    searchBox.frame:SetPoint("TOPLEFT", area, "TOPLEFT", x, 0)
    if searchBox:GetText() ~= search then
        searchBox:SetText(search)
        applyInsets()
    end
    clearMark:SetShown(search ~= "")
end

-- The toolbar's controls for the tab, the swatch's color, the search box and the hint row.
local function drawToolbar()
    filterDD.frame:SetShown(tab == "game")
    filterDD:SetValue(filter)
    setsDD.frame:SetShown(tab == "glyphs")
    setsDD:SetValue(glyphSet)
    swatch.frame:SetShown(SWATCH_TABS[tab] == true)
    local hex = color or "ffffff"
    swatch:SetColor(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
    drawSearch()
    hint:SetShown(tab == "game")
end

-- The area under the band the strip reserved (a strip that wraps reserves more).
local function anchorArea()
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", CONTENT_X, -((H().CHROME_GAP or 8) + (ctx.chromeHeight or 0)))
    area:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -CONTENT_X, BODY_BOTTOM)
end

-- The strip, then the area. On the first open the chrome has no width yet, so the strip wraps every
-- tab onto its own row; the library re-places it from the chrome's OnSizeChanged once the width
-- arrives (SetChromeHeight), and the area follows from a hook on the same script. Hooked, not set,
-- and only after the first strip: the library installs its handler with SetScript, which would
-- wipe a hook made before it.
local areaHooked = false
local function drawTabs()
    local h = H()
    if h.TabStrip then
        h.TabStrip(ctx, { tabs = B.TABS, value = tab, onSelect = function(key) B.SetTab(key) end })
    end
    if not areaHooked and ctx.chrome and ctx.chrome.HookScript then
        areaHooked = true
        ctx.chrome:HookScript("OnSizeChanged", anchorArea)
    end
    anchorArea()
end

-- The tab's list, searched, from the top, or scrolled to `icon` when the list holds it.
local function fill(icon)
    local all
    all, loaded = Src.List(tab, tab == "glyphs" and glyphSet or filter)
    total = #all
    list = Src.Search(all, tab, search)
    offset = 0
    if icon == nil then return end
    for i, v in ipairs(list) do
        if v == icon then
            offset = math.floor((i - 1) / COLS)
            break
        end
    end
end

-- Show tab `key`, as fill does.
local function showTab(key, icon)
    tab = key
    fill(icon)
    drawTabs()
    drawToolbar()
    draw()
end

-- ── the window's parts ──────────────────────────────────────────────────────────────────────

local function makeCell(i)
    local cell = CreateFrame("Button", nil, grid)
    cell:SetSize(CELL - 2, CELL - 2)
    cell:SetPoint("TOPLEFT", grid, "TOPLEFT", ((i - 1) % COLS) * CELL, -math.floor((i - 1) / COLS) * CELL)
    local sel = cell:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(cell)
    sel:SetColorTexture(NS.Skin.Color(SELECTED))
    sel:Hide()
    cell.selected = sel
    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("CENTER", cell, "CENTER", 0, 0)
    cell.icon = icon
    cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    cell:SetScript("OnClick", function(self) B.Select(self.qcIcon) end)
    cell:SetScript("OnDoubleClick", function(self)
        B.Select(self.qcIcon)
        B.Choose()
    end)
    cell:SetScript("OnEnter", tooltip)
    cell:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return cell
end

local function buildGrid()
    grid = CreateFrame("Frame", nil, area)
    grid:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -B.GRID_TOP)
    grid:SetSize(COLS * CELL, ROWS * CELL)
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta) setOffset(offset - delta) end)
    for i = 1, COLS * ROWS do B.cells[i] = makeCell(i) end
    status = grid:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    paintText(status, "text.highlight")
    status:SetPoint("CENTER", grid, "CENTER", 0, 0)
    status:Hide()
    slider = CreateFrame("Slider", nil, area)
    slider:SetPoint("TOPLEFT", grid, "TOPRIGHT", 6, 0)
    slider:SetPoint("BOTTOMLEFT", grid, "BOTTOMRIGHT", 6, 0)
    slider:SetWidth(16)
    slider:SetOrientation("VERTICAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(slider)
    -- The skin's corridor and flat knob (D3), the track filled scroll.track and the client's knob
    -- art faded under a knob of scroll.thumb.
    NS.Skin.ScrollBar(slider, { track = track })
    slider:SetScript("OnValueChanged", function(_, v) if not drawing then setOffset(v) end end)
    -- The scrollbar sits beside the grid, not in it: it scrolls on the wheel too.
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(_, delta) setOffset(offset - delta) end)
end

-- An AceGUI widget placed by hand in the area, kept for the browser's life (never released).
local function place(widget, point, x, y)
    widget.frame:SetParent(area)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint(point, area, point, x, y)
    widget.frame:Show()
    return widget
end

local function buildToolbar(AceGUI)
    filterDD = AceGUI:Create("Dropdown")
    filterDD:SetLabel("")
    filterDD:SetList(FILTERS, FILTER_ORDER)
    filterDD:SetWidth(TOOL_W)
    filterDD:SetCallback("OnValueChanged", function(_, _, key) B.SetFilter(key) end)
    H().AttachTooltip(filterDD, L["Show"], L["All the game's icons, or only the spell or the item icons."])
    place(filterDD, "TOPLEFT", 0, 0)
    setsDD = AceGUI:Create("Dropdown")
    setsDD:SetLabel("")
    local sets, order = { all = L["All"] }, { "all" }
    for _, set in ipairs(Src.GlyphSets()) do
        sets[set.id] = set.label
        order[#order + 1] = set.id
    end
    setsDD:SetList(sets, order)
    setsDD:SetWidth(SET_W)
    setsDD:SetCallback("OnValueChanged", function(_, _, key) B.SetGlyphSet(key) end)
    H().AttachTooltip(setsDD, L["Show"], L["Every glyph, or only one icon set's."])
    place(setsDD, "TOPLEFT", 0, 0)
    swatch = AceGUI:Create("ColorPicker")
    swatch:SetLabel(L["Icon color"])
    swatch:SetHasAlpha(false)
    swatch:SetWidth(SWATCH_W)
    local function pick(_, _, r, g, b) B.SetColor(NS.Library.IconColorFrom(r, g, b) or nil) end
    swatch:SetCallback("OnValueChanged", pick)
    swatch:SetCallback("OnValueConfirmed", pick)
    Settings.Editors.TrackPicker(swatch)
    H().AttachTooltip(swatch, L["Icon color"], L["The color a glyph is drawn in. White is none."])
    place(swatch, "TOPLEFT", SET_W + SEARCH_GAP, 0)
    count = area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    paintText(count, "text.disabled")
    count:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -6)
end

local function paintGlyph(t, token)
    local r, g, b = NS.SkinColor(token)
    t:SetVertexColor(r, g, b)
end

-- A LibKa0s glyph drawn on `parent` in color token `token`, SEARCH_GLYPH square; no texture without
-- the library.
local function glyph(parent, name, token)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(SEARCH_GLYPH, SEARCH_GLYPH)
    t:SetTexture(NS.Icon and NS.Icon(name) or nil)
    glyphs[t] = token
    paintGlyph(t, token)
    return t
end

-- The search box: an EditBox with its Okay button off (it filters as it is typed), a magnifier
-- inside its left edge and a clear mark inside its right, the text inset between them. AceGUI's
-- input frame (`editbox`) takes the art and the insets when it is there.
local function buildSearch(AceGUI)
    searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("")
    searchBox:SetWidth(SEARCH_W)
    searchBox:DisableButton(true)
    searchBox:SetCallback("OnTextChanged", function(_, _, text) B.SetSearch(text) end)
    H().AttachTooltip(searchBox, L["Search"],
        L["Markers by name, glyphs by name, game icons by texture id. Not case-sensitive."])
    place(searchBox, "TOPLEFT", TOOL_W + SEARCH_GAP, 0)
    local input = searchBox.editbox or searchBox.frame
    applyInsets()
    if input.HookScript then
        input:HookScript("OnEnterPressed", applyInsets)
        input:HookScript("OnReceiveDrag", applyInsets)
        input:HookScript("OnMouseDown", applyInsets)
    end
    magnifier = glyph(input, "search", MUTED_GOLD)
    magnifier:SetPoint("LEFT", input, "LEFT", 0, 0)
    clearMark = CreateFrame("Button", nil, input)
    clearMark:SetSize(SEARCH_GLYPH, SEARCH_GLYPH)
    clearMark:SetPoint("RIGHT", input, "RIGHT", -2, 0)
    clearGlyph = glyph(clearMark, "close", MARK_GRAY)
    clearGlyph:SetPoint("CENTER", clearMark, "CENTER", 0, 0)
    clearMark:SetScript("OnClick", function() B.SetSearch("") end)
    clearMark:Hide()
end

-- The hint box's fill and its four edges in their tokens.
local function paintHint()
    if not hintFill then return end
    hintFill:SetColorTexture(NS.Skin.Color(HINT_FILL))
    for _, t in ipairs(hintEdges) do t:SetColorTexture(NS.Skin.Color(HINT_EDGE)) end
end

-- A 1px line along `side` of `f` (painted by paintHint).
local function edge(f, side)
    local t = f:CreateTexture(nil, "BORDER")
    if side == "TOP" or side == "BOTTOM" then
        t:SetPoint(side .. "LEFT", f, side .. "LEFT", 0, 0)
        t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", 0, 0)
        t:SetHeight(1)
    else
        t:SetPoint("TOP" .. side, f, "TOP" .. side, 0, 0)
        t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, 0, 0)
        t:SetWidth(1)
    end
    return t
end

-- The copy window the hint's button shows Wowhead's address in (core/WidgetsSetup.lua's maker), above
-- the browser: the POPUP tier (FULLSCREEN_DIALOG, core/Constants.lua
-- LAYERS), over the browser's catcher. The library's CopyWindow takes no strata (a `strata` option on it
-- is an open evolution in the standard, STRATA_MODEL LK-05, not in LibKa0s v1.77.0), so the window is
-- lifted after it is built. Built on first use; nil without the library.
function B.LinkWindow()
    if linkWin then return linkWin end
    linkWin = NS.MakeCopyWindow({ name = addonName .. "IconLinkWindow", scrollName = addonName .. "IconLinkScroll",
        title = L["Quick Comms: Wowhead icons"], width = 420, height = 120,
        anchorTo = function() return B.frame end })
    if linkWin then linkWin:GetFrame():SetFrameStrata(NS.Constants.LAYERS.STRATA.POPUP) end
    return linkWin
end

-- The hint row under the grid (Game icons only): the words, then the button, in a box.
local function buildHint(AceGUI)
    hint = CreateFrame("Frame", nil, area)
    hint:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -HINT_GAP)
    hint:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -HINT_GAP)
    hint:SetHeight(HINT_H)
    hintFill = hint:CreateTexture(nil, "BACKGROUND")
    hintFill:SetAllPoints(hint)
    hintEdges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do hintEdges[#hintEdges + 1] = edge(hint, side) end
    paintHint()
    linkBtn = AceGUI:Create("Button")
    linkBtn:SetText(L["Copy wowhead.com/icons"])
    linkBtn:SetWidth(170)
    linkBtn:SetCallback("OnClick", function()
        local win = B.LinkWindow()
        if win then win:Show(B.WOWHEAD_ICONS) end
    end)
    H().AttachTooltip(linkBtn, L["Copy wowhead.com/icons"],
        L["Shows Wowhead's icon search address in a box to copy it from (Ctrl+C). The game cannot open a web page."])
    linkBtn.frame:SetParent(hint)
    linkBtn.frame:ClearAllPoints()
    linkBtn.frame:SetPoint("RIGHT", hint, "RIGHT", -6, 0)
    linkBtn.frame:Show()
    hintText = hint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    paintText(hintText, "text.highlight")
    hintText:SetPoint("LEFT", hint, "LEFT", 10, 0)
    hintText:SetPoint("RIGHT", linkBtn.frame, "LEFT", -10, 0)
    hintText:SetJustifyH("LEFT")
    hintText:SetWordWrap(true)
    hintText:SetText(L["Search by texture id. To find an icon by its name (e.g. ability_cheapshot), look it up on Wowhead and type its id here."])
    hint:Hide()
end

local function buildFooter(AceGUI)
    preview = area:CreateTexture(nil, "ARTWORK")
    preview:SetSize(ICON, ICON)
    preview:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 0, 0)
    nameText = area:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    paintText(nameText, "text.heading")
    nameText:SetPoint("LEFT", preview, "RIGHT", 8, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    chooseBtn = AceGUI:Create("Button")
    chooseBtn:SetText(L["Choose"])
    chooseBtn:SetWidth(110)
    chooseBtn:SetCallback("OnClick", function() B.Choose() end)
    H().AttachTooltip(chooseBtn, L["Choose"], L["Use the selected icon and close."])
    place(chooseBtn, "BOTTOMRIGHT", -116, 0)
    -- A long name (a typed texture path has no label) is cut short before the buttons.
    nameText:SetPoint("RIGHT", chooseBtn.frame, "LEFT", -8, 0)
    cancelBtn = AceGUI:Create("Button")
    cancelBtn:SetText(L["Cancel"])
    cancelBtn:SetWidth(110)
    cancelBtn:SetCallback("OnClick", function() B.Cancel() end)
    H().AttachTooltip(cancelBtn, L["Cancel"], L["Close without choosing. Nothing changes."])
    place(cancelBtn, "BOTTOMRIGHT", 0, 0)
end

local function build()
    local h = H()
    local w = Settings.ModalWindow.Build({ name = addonName .. "IconBrowser", pageName = addonName .. "IconBrowserPage",
        title = L["Choose an icon"], width = WIDTH, height = HEIGHT,
        strata = Settings.ModalWindow.STRATA, level = Settings.ModalWindow.LEVEL_OVER,
        onClose = function() B.Cancel() end })
    ctx = w.ctx
    B.catcher, B.frame, B.chrome, B.ctx = w.catcher, w.frame, w.chrome, ctx
    area = CreateFrame("Frame", nil, ctx.body)
    buildGrid()
    buildToolbar(h.AceGUI)
    buildSearch(h.AceGUI)
    buildHint(h.AceGUI)
    buildFooter(h.AceGUI)
    -- Hidden while open (Escape) is a Cancel.
    w.frame:HookScript("OnHide", function() if request then B.Cancel() end end)
    local settingsWindow = _G.SettingsPanel
    if settingsWindow and settingsWindow.HookScript then
        settingsWindow:HookScript("OnHide", function() if request then B.Cancel() end end)
    end
end

-- Hide the browser and drop the request. The request is cleared first, so the frame's own OnHide
-- finds nothing left to cancel.
local function close()
    request = nil
    putBack()
    if GameTooltip then GameTooltip:Hide() end
    if swatch then Settings.Editors.ReleasePicker(swatch) end   -- the picker goes with the browser
    if linkWin then linkWin:Hide() end                          -- and so does the address
    if ctx then ctx.panel:Hide() end
    if B.frame then B.frame:Hide() end
    if B.catcher then B.catcher:Hide() end
end

-- ── the surface ─────────────────────────────────────────────────────────────────────────────

--- Open the browser over its opener. `req` = { icon, color (the stored ones), onChoose(icon,
--- color|nil), owner (what Cancel(owner) closes it for), lift (the opener's special-frame names),
--- valid() (false once the opener's member is gone) }. Replaces any open browser, as Cancel.
--- @return boolean opened
function B.Open(req)
    if request then B.Cancel() end
    if not (H() and H().AceGUI) then return false end
    if not ctx then build() end
    request = req
    local home = req.icon ~= nil and Src.TabFor(req.icon) or nil
    -- An icon no tab lists is not selected: no cell could show it selected.
    selected = home and req.icon or nil
    color = nil
    if NS.Library.IsGlyph(selected) and req.color and NS.Library.ValidIconColor(req.color) then color = req.color end
    filter, glyphSet = "all", "all"
    lift(req.lift)
    B.catcher:Show()
    B.frame:Show()
    ctx.panel:Show()
    showTab(home or FIRST_TAB, selected)
    return true
end

--- Select `icon` (nil clears the selection). It is drawn highlighted and named in the footer.
function B.Select(icon)
    if not request then return end
    selected = icon
    draw()
end

--- Show tab `key` ("markers", "game", "glyphs"), scrolled to the selection when it holds it.
function B.SetTab(key)
    if not (request and TAB_KEYS[key]) then return end
    showTab(key, selected)
end

--- The Game icons tab's filter: "all", "spells" or "items".
function B.SetFilter(key)
    if not (request and FILTERS[key]) then return end
    filter = key
    if tab == "game" then showTab("game", selected) end
end

--- The Glyphs tab's set filter: "all" or a set's id (Src.GlyphSets). Kept across tab switches while
--- open; each open starts on "all", so a stored glyph of any set can be shown selected.
function B.SetGlyphSet(key)
    if not request then return end
    local known = key == "all"
    for _, set in ipairs(Src.GlyphSets()) do
        if set.id == key then known = true end
    end
    if not known then return end
    glyphSet = key
    if tab == "glyphs" then showTab("glyphs", selected) end
end

--- Search the shown tab for `text` (nil or blank shows it whole), as the search box does as it is
--- typed; from the top. The text is kept for the session, across tabs and opens.
function B.SetSearch(text)
    if not request then return end
    text = tostring(text or "")
    if text == search then return end
    search = text
    fill(nil)
    drawSearch()
    draw()
end

--- The glyph color ("rrggbb", or nil for white): every glyph in the grid and the footer is drawn in it.
function B.SetColor(hex)
    if not request then return end
    if hex ~= nil and not NS.Library.ValidIconColor(hex) then return end
    color = hex
    drawToolbar()
    draw()
end

--- Scroll the grid to row `row` (0 is the top), as the scrollbar and the mouse wheel do.
function B.ScrollTo(row)
    if request then setOffset(row) end
end

--- Choose the selection: the opener gets the icon and, for a glyph, the color (nil for any other
--- icon, or white), and the browser closes. Refused in combat and with nothing selected.
--- @return boolean ok, string|nil reason ("notOpen", "combat", "noSelection")
function B.Choose()
    if not request then return false, "notOpen" end
    if NS.Compat.InCombat() then
        NS.Print(CHAT_GRAY .. L["cannot choose an icon during combat"] .. "|r")
        return false, "combat"
    end
    if selected == nil then return false, "noSelection" end
    local req, icon = request, selected
    local c = NS.Library.IsGlyph(icon) and color or nil
    close()
    req.onChoose(icon, c)
    return true
end

--- Close without choosing. With `owner`, only a browser opened for that owner closes.
function B.Cancel(owner)
    if not request then return end
    if owner ~= nil and request.owner ~= owner then return end
    close()
end

function B.IsOpen()
    return request ~= nil
end

--- What the browser shows (for tests), or nil while closed.
function B.State()
    if not request then return nil end
    return { tab = tab, filter = filter, glyphSet = glyphSet, selected = selected, color = color, offset = offset, count = #list,
        total = total, search = search, loaded = loaded, owner = request.owner }
end

--- The toolbar's and the footer's widgets (for tests).
function B.Widgets()
    return { filter = filterDD, sets = setsDD, swatch = swatch, choose = chooseBtn, cancel = cancelBtn, slider = slider,
        grid = grid, status = status, count = count, preview = preview, name = nameText, area = area,
        search = searchBox, clear = clearMark, hint = hint, hintText = hintText, link = linkBtn,
        track = track, hintFill = hintFill, hintEdges = hintEdges, magnifier = magnifier, clearGlyph = clearGlyph }
end

-- A skin switch: every host-drawn color in the new skin (the texts, the scroller and the window are
-- the library's recorded paint), and the footer's note line redrawn in its escape.
NS.Skin.OnLooksChanged(function()
    for _, cell in ipairs(B.cells) do cell.selected:SetColorTexture(NS.Skin.Color(SELECTED)) end
    for t, token in pairs(glyphs) do paintGlyph(t, token) end
    paintHint()
    if request then drawFooter() end
end)

-- ── what closes it ──────────────────────────────────────────────────────────────────────────

local function onLibraryChanged()
    if request and request.valid and not request.valid() then B.Cancel() end
end

local HANDLERS = {
    { NS.MSG.LIBRARY_CHANGED, onLibraryChanged },
    { NS.MSG.PROFILE_CHANGED, function() B.Cancel() end },
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
    B.Cancel()
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
