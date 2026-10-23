local _, NS = ...
-- modules/PreviewWindow.lua — the "Preview as…" selector window (design-qc-preview §2.2): a small
-- library-styled window with a situation dropdown, an End preview button and the close mark, shown
-- while a "Preview as…" preview is on, whichever way it started (the slash, the settings row, the
-- window's own dropdown), and while the Groups page's edit preview is on (QF-02, owner 2026-10-23).
-- Plain test mode (placeholders) gets no window. Over the edit preview the title names the group,
-- the dropdown shows the preset it bakes under (NS.Preview.EditPresetKey: the group's own situation,
-- following each group switch), and the window is LOCKED (owner 2026-10-23): dimmed, the dropdown,
-- End preview and the close mark off, a tooltip naming the Groups page as where it is driven from
-- (a pick there did nothing visible, and the dropdown read Current under an Alterac Valley title).
--
-- ONE function shows or hides it: PW.Sync, which modules/Preview.lua calls from announce() and from
-- its stand-down entry (late-bound: this file loads after Preview). The window's own controls go
-- through NS.Preview.SetPreviewAs, so they come back here through announce(); nothing prints.
--
-- Its close mark, Escape (UISpecialFrames) and End preview all END the preview (owner scope C). End
-- preview and the close mark go through NS.Preview.EndPreview, which also turns Preview while
-- editing off; Escape over the edit preview is NS.Preview.DismissEditPreview, for the session only
-- (modules/Preview.lua says why). A hidden UIParent (Alt+Z, a cinematic) fires OnHide with the
-- frame's own shown flag still on: that ends nothing. OnHide also closes the shared dropdown menu (W.CloseMenu, the Widgets contract for
-- every non-click close path).
--
-- The look copies LibKa0s's Perf and Sim step panels: BackdropTemplate, movable,
-- clamped, the GameFontNormal title, the close mark through the one wrapper (NS.MakeCloseButton,
-- standalone-windows), NS.ApplySkin. The position PERSISTS in the profile (standalone-windows'
-- persist MUST): `previewWindow` (defaults/Profile.lua), written on drag stop, read on every show and
-- on a profile switch. DEGRADED (LibKa0s absent): no window; the slash still previews and prints.
-- A plain insecure Frame with no secure child: it calls no protected API.
--
-- STRATA (QC-06): FULLSCREEN, not the step panels' DIALOG. The preview dial's secure header is in
-- DIALOG with its hub at the header's level + 20, which would draw over a DIALOG window; the
-- header's strata is protected in combat, so the window moves instead. It keeps the client's level
-- for a child of UIParent, far under a modal's catcher (settings/ModalWindow.lua LEVEL), so the
-- callout popup and the icon browser, also FULLSCREEN, still cover it; its menu
-- (FULLSCREEN_DIALOG) stays above it. So a show NEVER Raises it: the client's Raise lifts a frame
-- over everything in its strata, which here is the modals' catchers and bands (a `/qc preview`
-- typed while the popup is open would put the window over the popup's dim, clickable through it).

NS.PreviewWindow = NS.PreviewWindow or {}
local PW = NS.PreviewWindow
local L = NS.L

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

local NAME = "QuickCommsPreviewWindow"
local TITLE_H, PAD, ROW_H, GAP = 24, 8, 22, 6
local DROP_W, BUTTON_W = 240, 100
local WIDTH = PAD + DROP_W + GAP + BUTTON_W + PAD
local HEIGHT = TITLE_H + PAD + ROW_H + PAD
local GOLD, REST, GRAY = { 1, 0.82, 0 }, { 0.9, 0.9, 0.92 }, { 0.6, 0.6, 0.6 }

local frame

local DIM = 0.45

local function locked()
    return NS.Preview.EditGroup() ~= nil
end

local function endPreview()
    if locked() then return end
    NS.Preview.EndPreview()
end

-- The locked window's tooltip, on every control: why it is off and where it is driven from.
local function lockedTip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(L["Preview as"])
    GameTooltip:AddLine(L["This window is disabled while you edit a group with Preview while editing on: it follows that group. Pick another group on the Groups page to see a preview of it, or untick Preview while editing to end the preview."], 1, 1, 1, true)
    GameTooltip:Show()
end

-- The stored point, or the default one (`TOP, UIParent, TOP, 0, -140`) when the profile has none.
local function savedPoint()
    local p = NS.db and NS.db.profile and NS.db.profile.previewWindow
    if type(p) == "table" and type(p.point) == "string" then return p end
    return NS.C.PROFILE.previewWindow
end

local function place()
    local p = savedPoint()
    frame:ClearAllPoints()
    frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
end

local function remember(self)
    local point, _, relPoint, x, y = self:GetPoint(1)
    if type(point) ~= "string" or not (NS.db and NS.db.profile) then return end
    NS.db.profile.previewWindow = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

-- A tooltip: a title, a white body, then the typed command in gray.
local function tip(owner, title, body, typed)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(body, 1, 1, 1, true)
    GameTooltip:AddLine(typed, GRAY[1], GRAY[2], GRAY[3])
    GameTooltip:Show()
end

local function hideTip()
    GameTooltip:Hide()
end

-- The host's flat button (the library's SimPanel makeButton is private): the skin, a centered small
-- label, gold under the pointer.
local function makeButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(BUTTON_W, ROW_H)
    NS.ApplySkin(b)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(label)
    fs:SetTextColor(REST[1], REST[2], REST[3])
    b.__label = fs
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        if locked() then return lockedTip(self) end
        self.__label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        tip(self, label, L["End the preview: the pads and dials go back to live."], NS.SLASH .. " preview off")
    end)
    b:SetScript("OnLeave", function(self)
        local c = locked() and GRAY or REST
        self.__label:SetTextColor(c[1], c[2], c[3])
        hideTip()
    end)
    return b
end

local function makeDropdown(parent)
    local dd = W.Dropdown(parent, DROP_W, { chevron = NS.Icon("chevron-down"), check = NS.Icon("confirm") })
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -(TITLE_H + PAD))
    -- One line: a long situation label truncates rather than wrapping out of the box.
    if dd.text and dd.text.SetWordWrap then dd.text:SetWordWrap(false) end
    dd.onSelect = function(v)
        if not locked() then NS.Preview.SetPreviewAs(v) end
    end
    dd:HookScript("OnEnter", function(self)
        if locked() then return lockedTip(self) end
        tip(self, L["Preview as"], L["Switch the situation the pads and dials preview."],
            NS.SLASH .. " preview <name>")
    end)
    dd:HookScript("OnLeave", hideTip)
    return dd
end

-- Escape and a Hide call clear the frame's own flag; a hidden parent leaves it on. A Sync-driven hide
-- finds every preview already off, so this never recurses.
local function onHide(self)
    if W.CloseMenu then W.CloseMenu() end
    if self:IsShown() then return end
    local P = NS.Preview
    if P.EditGroup() ~= nil then
        P.DismissEditPreview()
    elseif P.PreviewAs() ~= nil then
        P.SetPreviewAs(P.OFF)
    end
end

local function chrome(f)
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("FULLSCREEN")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        remember(self)
    end)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -6)
    -- One line: a long group name truncates (the width is the window's, inside the close mark).
    title:SetWidth(WIDTH - 2 * (PAD + 20))
    if title.SetWordWrap then title:SetWordWrap(false) end
    f.title = title
end

local function ensure()
    if frame then return frame end
    local f = CreateFrame("Frame", NAME, UIParent, "BackdropTemplate")
    chrome(f)
    f.closeButton = NS.MakeCloseButton(f, endPreview)
    if f.closeButton then f.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -(TITLE_H - 18) / 2) end
    if f.closeButton then
        -- Locked, its own hover paint is undone (its OnLeave repaints it at rest) before the tooltip.
        f.closeButton:HookScript("OnEnter", function(self)
            if not locked() then return end
            local rest = self:GetScript("OnLeave")
            if rest then rest(self) end
            lockedTip(self)
        end)
        f.closeButton:HookScript("OnLeave", hideTip)
    end
    f.dropdown = makeDropdown(f)
    f.endButton = makeButton(f, L["End preview"], endPreview)
    f.endButton:SetPoint("LEFT", f.dropdown, "RIGHT", GAP, 0)
    NS.ApplySkin(f)
    f:Hide()
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, NAME) end
    f:HookScript("OnHide", onHide)
    frame = f
    return f
end

-- Locked over the edit preview, live otherwise: each control on or off, dimmed, its label grayed. A
-- disabled Button runs no OnEnter in the client unless told to (SetMotionScriptsWhileDisabled, as
-- LibKa0s's SimPanel does), so it is: the tooltip says why it is off.
local function setLocked(f, on)
    for _, c in ipairs({ f.dropdown, f.endButton, f.closeButton }) do
        if c.SetMotionScriptsWhileDisabled then c:SetMotionScriptsWhileDisabled(true) end
        if c.SetEnabled then c:SetEnabled(not on) end
        c:SetAlpha(on and DIM or 1)
    end
    local c = on and GRAY or REST
    f.endButton.__label:SetTextColor(c[1], c[2], c[3])
    if on and W.CloseMenu then W.CloseMenu() end
end

local function fill(f)
    local P = NS.Preview
    local options = {}
    for _, e in ipairs(P.Presets()) do options[#options + 1] = { value = e.key, label = e.label } end
    f.dropdown:SetOptions(options)
    local editing = P.EditGroup() ~= nil
    f.dropdown:SelectValue(editing and P.EditPresetKey() or P.PreviewAs() or P.CURRENT)
    setLocked(f, editing)
    if editing then
        f.title:SetText(L["%s - Preview: %s"]:format(NS.BRAND, P.Label(P.EDIT)))
    else
        f.title:SetText(L["%s - Preview"]:format(NS.BRAND))
    end
end

--- Show the window while a "Preview as…" preview or the edit preview is on (and the addon stands),
--- hide it otherwise. Re-reads the menu, the selection and the title on every show, so the slash,
--- the settings row and a group switch move it.
function PW.Sync()
    local P = NS.Preview
    local want = (P.PreviewAs() ~= nil or P.EditGroup() ~= nil) and not NS.IsStoodDown()
    if not want then
        if frame then frame:Hide() end
        return
    end
    if not (W and W.Dropdown and type(CreateFrame) == "function") then return end
    local f = ensure()
    fill(f)
    place()
    f:Show()
end

function PW.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end

--- Test seam (the PerfPanel `__panel` idiom): the frame, or nil before the first show.
function PW.__frame()
    return frame
end

-- A profile switch moves a shown window to that profile's place. A library write re-fills it over the
-- edit preview: a When edited on the Groups page re-bakes the pads under a new preset with no
-- announce, and the dropdown names what they show (QF-07). With the library absent there is no
-- window, so no receiver; the library's tracked bus takes it down and up with the addon.
if W and NS.Bus.tracked then
    local receiver = NS.Bus:NewTarget()
    if receiver then
        receiver:RegisterMessage(NS.MSG.PROFILE_CHANGED, function()
            if frame and frame:IsShown() then place() end
        end)
        receiver:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function()
            if frame and frame:IsShown() and NS.Preview.EditGroup() ~= nil then fill(frame) end
        end)
    end
end
