local addonName, NS = ...
-- settings/IconBrowser.lua — the icon browser (icon browser spec): a window over whatever opened it
-- (the callout popup, a user group's General tab) where an icon is picked from every source
-- settings/IconBrowser_Sources.lua offers, and a glyph's color with it.
--
--     window   settings/ModalWindow.lua's (the callout popup's chrome), title "Ka0s Quick Comms"
--     header   Choose an icon, the gold rule under it
--     tabs     [ Suggested ][ Markers ][ Game icons ][ Glyphs ]   (the library's tab strip)
--     toolbar  Game icons: Show All / Spells / Items. Suggested and Glyphs: the glyph color swatch.
--              At the right, how many icons the tab holds.
--     grid     COLS x ROWS icons and a scrollbar; the mouse wheel scrolls too
--     footer   the selected icon (a glyph in the color) and its name, then Choose and Cancel
--
-- A click on an icon selects it, a double-click chooses it, and hovering one names it (its label,
-- or a game icon's texture id). Choose hands the opener the icon and, for a glyph, the color (none
-- for white), then closes; the opener writes it (the popup's draft, or the group's icon and color as
-- one act). Cancel, the close X and Escape change nothing. The stored icon is preselected, and its
-- tab opened and scrolled to it.
--
-- THE GRID IS VIRTUALIZED: COLS x ROWS cell buttons are built once and re-dressed from the tab's
-- list at the scroll offset, so the Game icons tab's thousands of entries cost a few dozen frames.
--
-- STACKING. The catcher and the window are in the FULLSCREEN strata, above the popup and its catcher
-- (DIALOG), so the browser is modal to whatever opened it. The swatch is AceGUI's ColorPicker, which
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

local QC = NS.addon
local Settings = QC.Settings
local Src = Settings.IconBrowserSources
local L = NS.L

Settings.IconBrowser = Settings.IconBrowser or {}
local B = Settings.IconBrowser

B.COLS, B.ROWS = 12, 7
local COLS, ROWS = B.COLS, B.ROWS
local CELL, ICON = 40, 32           -- a cell's pitch, and the icon in it
local WIDTH, HEIGHT = 560, 540
local STRATA = "FULLSCREEN"
-- As settings/CalloutPopup.lua restates them: the pages' left inset and the gap under the body.
local CONTENT_X, BODY_BOTTOM = 12, 12
-- The toolbar's band over the grid. HEIGHT leaves the footer (34) its band under the grid, below
-- the header, a one-row tab strip and the gaps.
local TOOLBAR_H = 30
local GOLD = { 1, 0.82, 0, 0.7 }
local GRAY = "|cffaaaaaa"

B.TABS = {
    { key = "suggested", label = L["Suggested"], tooltip = L["The raid markers, the built-in sets' icons and the glyphs callouts use most."] },
    { key = "markers", label = L["Markers"], tooltip = L["The eight raid target markers."] },
    { key = "game", label = L["Game icons"], tooltip = L["Every icon the macro icon picker offers."] },
    { key = "glyphs", label = L["Glyphs"], tooltip = L["Every LibKa0s glyph. A glyph is drawn in the color you pick."] },
}
local FILTERS = { all = L["All"], spells = L["Spells"], items = L["Items"] }
local FILTER_ORDER = { "all", "spells", "items" }
-- The tabs that hold glyphs, where the toolbar shows the color swatch.
local SWATCH_TABS = { suggested = true, glyphs = true }

-- The open request ({ icon, color, onChoose, owner, lift, valid }), nil while closed, and what the
-- browser shows: the tab, the game filter, the tab's list, the selection, the glyph color, the
-- first visible row.
local request
local tab, filter, list, loaded, selected, color, offset = "suggested", "all", {}, true, nil, nil, 0
local ctx, area, grid, slider, status, count, filterDD, swatch, preview, nameText, chooseBtn, cancelBtn
local drawing = false
B.cells = {}

local function H() return Settings.Helpers end

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
        nameText:SetText(GRAY .. L["Click an icon to select it."] .. "|r")
    end
    chooseBtn:SetDisabled(selected == nil)
end

local function drawStatus()
    if #list > 0 then
        status:Hide()
        return
    end
    status:SetText(loaded and L["Nothing to show here."]
        or L["The game's icon list has not loaded yet. Open this tab again in a moment."])
    status:Show()
end

-- A cell's hover tooltip: its icon's name and what a click does.
local function tooltip(cell)
    if cell.qcIcon == nil or not GameTooltip then return end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:SetText(Src.Label(cell.qcIcon))
    GameTooltip:AddLine(L["Click to select it, double-click to choose it."], 1, 1, 1, true)
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
    count:SetText(L["%d icons"]:format(#list))
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

-- The toolbar's controls for the tab, and the swatch's color.
local function drawToolbar()
    filterDD.frame:SetShown(tab == "game")
    filterDD:SetValue(filter)
    swatch.frame:SetShown(SWATCH_TABS[tab] == true)
    local hex = color or "ffffff"
    swatch:SetColor(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
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

-- Show tab `key` from the top, or scrolled to `icon` when the tab holds it.
local function showTab(key, icon)
    tab = key
    list, loaded = Src.List(tab, filter)
    offset = 0
    for i, v in ipairs(list) do
        if v == icon then
            offset = math.floor((i - 1) / COLS)
            break
        end
    end
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
    sel:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
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
    grid:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -TOOLBAR_H)
    grid:SetSize(COLS * CELL, ROWS * CELL)
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta) setOffset(offset - delta) end)
    for i = 1, COLS * ROWS do B.cells[i] = makeCell(i) end
    status = grid:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(slider)
    track:SetColorTexture(0, 0, 0, 0.35)
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
    filterDD:SetWidth(180)
    filterDD:SetCallback("OnValueChanged", function(_, _, key) B.SetFilter(key) end)
    H().AttachTooltip(filterDD, L["Show"], L["All the game's icons, or only the spell or the item icons."])
    place(filterDD, "TOPLEFT", 0, 0)
    swatch = AceGUI:Create("ColorPicker")
    swatch:SetLabel(L["Icon color"])
    swatch:SetHasAlpha(false)
    swatch:SetWidth(200)
    local function pick(_, _, r, g, b) B.SetColor(NS.Library.IconColorFrom(r, g, b) or nil) end
    swatch:SetCallback("OnValueChanged", pick)
    swatch:SetCallback("OnValueConfirmed", pick)
    Settings.Editors.TrackPicker(swatch)
    H().AttachTooltip(swatch, L["Icon color"], L["The color a glyph is drawn in. White is none."])
    place(swatch, "TOPLEFT", 0, 0)
    count = area:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    count:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -6)
end

local function buildFooter(AceGUI)
    preview = area:CreateTexture(nil, "ARTWORK")
    preview:SetSize(ICON, ICON)
    preview:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 0, 0)
    nameText = area:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
        title = L["Choose an icon"], width = WIDTH, height = HEIGHT, strata = STRATA,
        onClose = function() B.Cancel() end })
    ctx = w.ctx
    B.catcher, B.frame, B.chrome, B.ctx = w.catcher, w.frame, w.chrome, ctx
    area = CreateFrame("Frame", nil, ctx.body)
    buildGrid()
    buildToolbar(h.AceGUI)
    buildFooter(h.AceGUI)
    -- Hidden while open (Escape) is a Cancel.
    w.frame:HookScript("OnHide", function() if request then B.Cancel() end end)
    local settingsWindow = _G.SettingsPanel
    if settingsWindow and settingsWindow.HookScript then
        settingsWindow:HookScript("OnHide", function() if request then B.Cancel() end end)
    end
    local skin = Settings.CalloutPopupSkin
    if skin then skin.TryApply() end
end

-- Hide the browser and drop the request. The request is cleared first, so the frame's own OnHide
-- finds nothing left to cancel.
local function close()
    request = nil
    putBack()
    if GameTooltip then GameTooltip:Hide() end
    if swatch then Settings.Editors.ReleasePicker(swatch) end   -- the picker goes with the browser
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
    selected = req.icon or nil
    color = nil
    if NS.Library.IsGlyph(selected) and req.color and NS.Library.ValidIconColor(req.color) then color = req.color end
    filter = "all"
    lift(req.lift)
    B.catcher:Show()
    B.frame:Show()
    ctx.panel:Show()
    showTab(selected ~= nil and Src.TabFor(selected) or "suggested", selected)
    return true
end

--- Select `icon` (nil clears the selection). It is drawn highlighted and named in the footer.
function B.Select(icon)
    if not request then return end
    selected = icon
    draw()
end

--- Show tab `key` ("suggested", "markers", "game", "glyphs"), scrolled to the selection when it holds it.
function B.SetTab(key)
    if not request then return end
    showTab(key, selected)
end

--- The Game icons tab's filter: "all", "spells" or "items".
function B.SetFilter(key)
    if not (request and FILTERS[key]) then return end
    filter = key
    if tab == "game" then showTab("game", selected) end
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
        NS.Print(GRAY .. L["cannot choose an icon during combat"] .. "|r")
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
    return { tab = tab, filter = filter, selected = selected, color = color, offset = offset, count = #list,
        loaded = loaded, owner = request.owner }
end

--- The toolbar's and the footer's widgets (for tests).
function B.Widgets()
    return { filter = filterDD, swatch = swatch, choose = chooseBtn, cancel = cancelBtn, slider = slider,
        grid = grid, status = status, count = count, preview = preview, name = nameText, area = area }
end

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
