local _, NS = ...
-- modules/PreviewWindow.lua — the "Preview as…" selector window (design-qc-preview §2.2): a small
-- library-styled window with a situation dropdown, an End preview button and the close mark, shown
-- exactly while a "Preview as…" preview is on, whichever way it started (the slash, the settings
-- row, the window's own dropdown). Plain test mode (placeholders) and the edit preview get no window.
--
-- ONE function shows or hides it: PW.Sync, which modules/Preview.lua calls from announce() and from
-- its stand-down entry (late-bound: this file loads after Preview). The window's own controls go
-- through NS.Preview.SetPreviewAs, so they come back here through announce(); nothing prints.
--
-- Its close mark, Escape (UISpecialFrames) and End preview all END the preview (owner scope C). A
-- hidden UIParent (Alt+Z, a cinematic) fires OnHide with the frame's own shown flag still on: that
-- ends nothing. OnHide also closes the shared dropdown menu (W.CloseMenu, the Widgets contract for
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
-- (FULLSCREEN_DIALOG) stays above it.

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

local function endPreview()
    NS.Preview.SetPreviewAs(NS.Preview.OFF)
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
        self.__label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        tip(self, label, L["End the preview: the pads and dials go back to live."], NS.SLASH .. " preview off")
    end)
    b:SetScript("OnLeave", function(self)
        self.__label:SetTextColor(REST[1], REST[2], REST[3])
        hideTip()
    end)
    return b
end

local function makeDropdown(parent)
    local dd = W.Dropdown(parent, DROP_W, { chevron = NS.Icon("chevron-down"), check = NS.Icon("confirm") })
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -(TITLE_H + PAD))
    -- One line: a long situation label truncates rather than wrapping out of the box.
    if dd.text and dd.text.SetWordWrap then dd.text:SetWordWrap(false) end
    dd.onSelect = function(v) NS.Preview.SetPreviewAs(v) end
    dd:HookScript("OnEnter", function(self)
        tip(self, L["Preview as"], L["Switch the situation the pads and dials preview."],
            NS.SLASH .. " preview <name>")
    end)
    dd:HookScript("OnLeave", hideTip)
    return dd
end

-- Escape and a Hide call clear the frame's own flag; a hidden parent leaves it on. A Sync-driven hide
-- finds the preview already off, so this never recurses.
local function onHide(self)
    if W.CloseMenu then W.CloseMenu() end
    if not self:IsShown() and NS.Preview.PreviewAs() ~= nil then endPreview() end
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
    title:SetText(L["%s - Preview"]:format(NS.BRAND))
    f.title = title
end

local function ensure()
    if frame then return frame end
    local f = CreateFrame("Frame", NAME, UIParent, "BackdropTemplate")
    chrome(f)
    f.closeButton = NS.MakeCloseButton(f, endPreview)
    if f.closeButton then f.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -(TITLE_H - 18) / 2) end
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

local function fill(f)
    local options = {}
    for _, e in ipairs(NS.Preview.Presets()) do options[#options + 1] = { value = e.key, label = e.label } end
    f.dropdown:SetOptions(options)
    f.dropdown:SelectValue(NS.Preview.PreviewAs())
end

--- Show the window while a "Preview as…" preview is on (and the addon stands), hide it otherwise.
--- Re-reads the menu and the selection on every show, so the slash and the settings row move it.
function PW.Sync()
    local want = NS.Preview.PreviewAs() ~= nil and not NS.IsStoodDown()
    if not want then
        if frame then frame:Hide() end
        return
    end
    if not (W and W.Dropdown and type(CreateFrame) == "function") then return end
    local f = ensure()
    fill(f)
    place()
    f:Show()
    if f.Raise then f:Raise() end
end

function PW.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end

--- Test seam (the PerfPanel `__panel` idiom): the frame, or nil before the first show.
function PW.__frame()
    return frame
end

-- A profile switch moves a shown window to that profile's place. With the library absent there is no
-- window, so no receiver; the library's tracked bus takes it down and up with the addon.
if W and NS.Bus.tracked then
    local receiver = NS.Bus:NewTarget()
    if receiver then
        receiver:RegisterMessage(NS.MSG.PROFILE_CHANGED, function()
            if frame and frame:IsShown() then place() end
        end)
    end
end
