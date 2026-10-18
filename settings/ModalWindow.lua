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
-- STACKING. Everything is set in the caller's strata: the popup's is DIALOG (above the settings
-- window), the browser's FULLSCREEN (above the popup and its catcher). Inside a strata, the levels
-- are fixed: the catcher at LEVEL, the template's Bg at LEVEL + 1 (the template declares it at
-- absolute level 0, which would put it under the catcher's dim), the window with its border at
-- LEVEL + 2, the page at LEVEL + 3 and the close X at LEVEL + 5 (it overlaps the page's top edge).

local Settings = NS.addon.Settings

Settings.ModalWindow = Settings.ModalWindow or {}
local MW = Settings.ModalWindow

local TEMPLATE = "SettingsFrameTemplate"
-- Where the page sits in the window: inside the template's background (its Bg is inset 7,-18 /
-- -3,3), under the title bar; the fallback window is the page alone.
MW.INSET_TEMPLATE = { left = 8, top = 24, right = 4, bottom = 5 }
MW.INSET_PLAIN = { left = 0, top = 0, right = 0, bottom = 0 }
MW.LEVEL = 10
local LEVEL = MW.LEVEL
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
local function plainChrome(window, panel, chrome, onClose)
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
    local closeButton = NS.MakeCloseButton(panel, onClose)
    if closeButton then closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -12) end
    chrome.window, chrome.bg, chrome.close = window, bg, closeButton
end

local function makeCatcher(strata)
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata(strata)
    catcher:SetFrameLevel(LEVEL)
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
--- entry), pageName (the page panel's), title (the page header's), width, height, strata, onClose
--- (the close X's or the close mark's click) }.
--- @return table { catcher, frame, chrome, ctx (the page's panel context), inset }
function MW.Build(spec)
    local catcher = makeCatcher(spec.strata)
    local window, chrome = makeWindow(spec.name, catcher)
    local inset = chrome.template and MW.INSET_TEMPLATE or MW.INSET_PLAIN
    -- The strata again: a template may name its own, and the window must stay above the catcher.
    window:SetFrameStrata(spec.strata)
    window:SetFrameLevel(LEVEL + 2)
    window:SetSize(spec.width, spec.height)
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:EnableMouse(true)

    local ctx = H().CreatePanel(spec.pageName, spec.title, { isMain = true })
    local panel = ctx.panel
    panel:SetParent(window)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", inset.left, -inset.top)
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -inset.right, inset.bottom)
    panel:SetFrameLevel(LEVEL + 3)
    if chrome.template then
        -- The template's Bg, over the catcher's dim and under the border: at its declared level 0
        -- the dim would draw over it, and the window would be darker than the settings window.
        if chrome.bg then chrome.bg:SetFrameLevel(LEVEL + 1) end
        -- The template's close X (an accepted deviation, docs/ARCHITECTURE.md): a click is the
        -- caller's close, and it sits above the page, whose top edge it overlaps.
        chrome.close:SetScript("OnClick", function() spec.onClose() end)
        chrome.close:SetFrameLevel(LEVEL + 5)
    else
        plainChrome(window, panel, chrome, function() spec.onClose() end)
    end
    -- Escape hides a special frame.
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = spec.name end
    return { catcher = catcher, frame = window, chrome = chrome, ctx = ctx, inset = inset }
end
