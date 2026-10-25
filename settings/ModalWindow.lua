local _, NS = ...
-- settings/ModalWindow.lua — the window the callout popup (settings/CalloutPopup.lua) and the icon
-- browser (settings/IconBrowser.lua) are each built in, once, on their first Open.
--
--     catcher  a full-screen button that swallows every click and wheel, with a dim over what it
--              covers: the window is MODAL to whatever is under it
--     window   Blizzard's own SettingsFrameTemplate (its background, its border with the window
--              title, its close X), the catcher's child, so it draws above it
--     page     the library's panel factory (CreatePanel): a settings page's header (title and gold
--              rule) and its body, set inside the template's background
--
-- A client without the template, or a template that lost a part used here (NineSlice with its
-- title, Bg, ClosePanelButton), gets the older look: a plain frame, Blizzard's dialog edge over a
-- dark fill and the shared close mark. Either close calls the caller's `onClose`. The window is a
-- special frame (Escape hides it); what a hide means is the caller's (its own OnHide hook).
--
-- STACKING (QC-06). Every modal is above the Comms Dial BY STRATA: FULLSCREEN (MW.STRATA), one
-- over the dial's DIALOG. The dial's secure header (modules/SendEngine.lua) is in DIALOG and the
-- hub's dot and pointer sit at the header's level + 20 (modules/Dial_Render.lua, RaiseFront): a modal
-- in DIALOG is in a level race it loses, and the header's strata is not ours to move (a secure
-- frame's strata is protected in combat). FULLSCREEN is also over the pads (MEDIUM), the dial's
-- screen catcher (HIGH) and the settings window (HIGH).
-- The popup and the icon browser share FULLSCREEN and are told apart by a BAND of levels the caller
-- picks (`spec.level`): the popup's base is LEVEL, the browser's LEVEL_OVER, far above anything the
-- popup's nested widgets reach, so the browser and its catcher cover the popup. FULLSCREEN_DIALOG
-- stays free for what must sit over the browser: the AceGUI pull-outs, the color picker, the
-- library's menu and the browser's link window. Moving the browser up to FULLSCREEN_DIALOG would put
-- it in a level race with each of those instead.
-- Inside a band the levels are fixed: the catcher at the base, the template's Bg at base + 1 (the
-- template declares it at absolute level 0, which would put it under the catcher's dim), the window
-- with its border at base + 2, the page at base + 3 and the close X at base + 5 (it overlaps the
-- page's top edge). Every strata and level here is a name in core/Constants.lua LAYERS: a band's base
-- is UIParent's level plus MODAL or MODAL_OVER (the catcher sits at it), and each part is the base plus
-- its offset.

local Settings = NS.addon.Settings
local LAYERS = NS.Constants.LAYERS
local LV = LAYERS.LEVEL

Settings.ModalWindow = Settings.ModalWindow or {}
local MW = Settings.ModalWindow

local TEMPLATE = "SettingsFrameTemplate"
-- Where the page sits in the window: inside the template's background (its Bg is inset 7,-18 /
-- -3,3), under the title bar; the fallback window is the page alone.
MW.INSET_TEMPLATE = { left = 8, top = 24, right = 4, bottom = 5 }
MW.INSET_PLAIN = { left = 0, top = 0, right = 0, bottom = 0 }
-- Aliases of the layers table, kept for the popup's and the browser's builds.
MW.LEVEL = LV.MODAL
-- A modal over a modal (the icon browser over the popup): its band's base, in the same strata.
MW.LEVEL_OVER = LV.MODAL_OVER
-- The strata of every QuickComms modal: over the dial's DIALOG (STACKING above).
MW.STRATA = LAYERS.STRATA.MODAL
-- The strata a QuickComms confirm (a Blizzard StaticPopup: the deletes, Reset all) is shown in, one
-- over the modals' (MW.LiftConfirm).
MW.CONFIRM_STRATA = LAYERS.STRATA.POPUP
local DIM = { 0, 0, 0, 0.45 }

local function H() return Settings.Helpers end
local function isTable(v) return type(v) == "table" end

-- The window: the template when the client has it and it still has the parts used here, else a
-- plain frame. Answers the window and its chrome: what a skin paints, and whether the template drew it.
local function makeWindow(name, parent)
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

-- The fallback's chrome: Blizzard's dialog edge over a dark fill under the page, and the shared
-- close mark.
local function plainChrome(window, panel, chrome, onClose, at)
    local bg = CreateFrame("Frame", nil, window, "BackdropTemplate")
    bg:SetAllPoints(window)
    bg:SetFrameLevel(at(LV.MODAL_BG))
    if bg.SetBackdrop then
        bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 11, top = 11, bottom = 11 },
        })
        bg:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    end
    local closeButton = NS.MakeCloseButton(panel, onClose)
    if closeButton then closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -12) end
    chrome.window, chrome.bg, chrome.close = window, bg, closeButton
end

local function makeCatcher(strata, base)
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata(strata)
    catcher:SetFrameLevel(base)
    catcher:EnableMouse(true)
    catcher:EnableMouseWheel(true)
    catcher:SetScript("OnMouseWheel", function() end)
    local dim = catcher:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(catcher)
    dim:SetColorTexture(DIM[1], DIM[2], DIM[3], DIM[4])
    catcher:Hide()
    return catcher
end

--- Build a modal window, hidden. `spec` = { name (the window's global name, also its special-frame
--- entry), pageName (the page panel's), title (the page header's), width, height, strata, level
--- (the band's base: MW.LEVEL when nil, MW.LEVEL_OVER for a modal over a modal), onClose (the close
--- X's or the close mark's click) }.
--- @return table { catcher, frame, chrome, ctx (the page's panel context), inset }
function MW.Build(spec)
    -- The band's base: UIParent's level plus the band's offset; every part sits at base + its offset.
    local base = UIParent:GetFrameLevel() + (spec.level or MW.LEVEL)
    local function at(offset) return base + offset end
    local catcher = makeCatcher(spec.strata, base)
    local window, chrome = makeWindow(spec.name, catcher)
    local inset = chrome.template and MW.INSET_TEMPLATE or MW.INSET_PLAIN
    -- The strata again: a template may name its own, and the window must stay above the catcher.
    window:SetFrameStrata(spec.strata)
    window:SetFrameLevel(at(LV.MODAL_WINDOW))
    window:SetSize(spec.width, spec.height)
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:EnableMouse(true)
    -- Clamped (frame-layering-§4), but NOT toplevel: a toplevel window is raised to the top of its
    -- strata on every mouse-down, so the click on the popup's Choose icon… would lift the popup's
    -- window over the browser's band (MODAL_OVER) just as the browser opens, and the browser and its
    -- catcher would no longer cover it. The catcher already makes each window the only thing in its
    -- strata a click reaches, so a raise has nothing to win (docs/ARCHITECTURE.md, register row QC-R6).
    window:SetClampedToScreen(true)

    local ctx = H().CreatePanel(spec.pageName, spec.title, { isMain = true })
    local panel = ctx.panel
    panel:SetParent(window)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", inset.left, -inset.top)
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -inset.right, inset.bottom)
    panel:SetFrameLevel(at(LV.MODAL_PAGE))
    if chrome.template then
        -- The template's Bg, over the catcher's dim and under the border: at its declared level 0
        -- the dim would draw over it, and the window would be darker than the settings window.
        if chrome.bg then chrome.bg:SetFrameLevel(at(LV.MODAL_BG)) end
        -- The template's close X (an accepted deviation, docs/ARCHITECTURE.md): a click is the
        -- caller's close, and it sits above the page, whose top edge it overlaps.
        chrome.close:SetScript("OnClick", function() spec.onClose() end)
        chrome.close:SetFrameLevel(at(LV.MODAL_CLOSE))
    else
        plainChrome(window, panel, chrome, function() spec.onClose() end, at)
    end
    -- Escape hides a special frame.
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = spec.name end
    return { catcher = catcher, frame = window, chrome = chrome, ctx = ctx, inset = inset }
end

-- CONFIRMS (QC-06 review). QuickComms' confirms are Blizzard StaticPopups, whose dialog frames are
-- DIALOG: the preview dial's strata, where the hub (header level + 20) races them for the top, and
-- under the modals' FULLSCREEN catchers (a `/qc resetall` typed while the callout popup is open would
-- show a confirm nobody can click). A QuickComms confirm lifts its dialog to CONFIRM_STRATA while it
-- shows and hands the shared frame back in the strata it came in when it hides, so Blizzard's next
-- popup in that slot is untouched. The strata it came in is kept here, never on Blizzard's frame
-- (a field written on it would taint it).
local confirmStrata = setmetatable({}, { __mode = "k" })

--- Lift a StaticPopupDialogs definition `def` (in place) over the dial and the modals while shown.
function MW.LiftConfirm(def)
    def.OnShow = function(dialog)
        if not (dialog and dialog.SetFrameStrata) then return end
        confirmStrata[dialog] = dialog.GetFrameStrata and dialog:GetFrameStrata() or LAYERS.STRATA.STATIC_POPUP
        dialog:SetFrameStrata(MW.CONFIRM_STRATA)
    end
    def.OnHide = function(dialog)
        if not (dialog and dialog.SetFrameStrata) then return end
        dialog:SetFrameStrata(confirmStrata[dialog] or LAYERS.STRATA.STATIC_POPUP)
        confirmStrata[dialog] = nil
    end
    return def
end
