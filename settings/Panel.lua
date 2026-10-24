local addonName, NS = ...
-- settings/Panel.lua — the landing page and the General page.
--
-- The landing page is the library's BuildLandingPage (logo, TOC notes, the slash command list) and
-- draws no tab strip (options-ui-§5/§13). The General page renders through the tabbed renderer, its
-- first tab `Master controls`, composed from one declaration with the canonical rows in canonical
-- order (options-ui-§15). The Comms Pad is positionable, so the block is the full framed set: General
-- visibility, Master scale and alpha, Lock frame, Test mode and Reset position (every pad and dial, design spec
-- §10.3/§10.4). The design's other pages and the
-- General page's Behavior tab (spec §13.1) are added by the settings tasks.

local QC       = NS.addon
local Settings = QC.Settings
local Helpers  = Settings.Helpers
local C        = NS.C
local L        = NS.L

-- The landing page's logo: the larger render of the launcher logo, in the same folder.
local MAIN_LOGO_TEXTURE = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga"):format(addonName, addonName:lower())

-- The landing page body, through the library's builder (options-ui-§5): logo at the library's
-- 300x300 default, the TOC notes line, then the Slash Commands heading and one row per NS.COMMANDS
-- entry. The builder keeps one texture per frame and hides it in the group's OnRelease
-- (options-ui-§19).
function Helpers.BuildMainContent(ctx)
    Helpers.BuildLandingPage(ctx, {
        logo     = MAIN_LOGO_TEXTURE,
        notes    = function() return NS.Meta("Notes") or "" end,
        sections = { {
            heading = L["Slash Commands"],
            rows    = function()
                local Sl = NS.SlashCommands
                return Sl and Sl:LandingRows() or {}
            end,
        } },
    })
end

local function showResetPopup()
    Settings.EnsureResetPopup()
    StaticPopup_Show(Settings.RESET_POPUP)
end

local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{
    prefix           = "",
    page             = "general",
    addonName        = NS.BRAND,
    debugConsolePath = "state.debugConsole",
    minimapPath      = Settings.MINIMAP_PATH,
    testModePath     = "state.testMode",
    defaults         = {
        enabled = C.PROFILE.enabled, visibility = C.PROFILE.visibility, scale = C.PROFILE.scale,
        alpha = C.PROFILE.alpha, locked = C.PROFILE.locked, debugConsole = false, testMode = false,
    },
    -- Preview as… (spec §13.3) is the block's one extra: a page-wide session row (never saved, read
    -- and written through modules/Preview.lua via settings/Schema.lua SESSION), placed after the
    -- canonical set and before the button pair. options-ui-§15 as amended in v2.84.0 sanctions host
    -- rows through the composer's `extra` slot, after the mandated rows and never interleaved with
    -- them. The Minimap button / Test mode line is full, so it opens its own line.
    extra            = {
        { path = "state.previewAs", type = "string", sessionOnly = true, default = "off",
          startsLine = true, label = L["Preview as"],
          desc = L["Draw every pad, and open dial 1, as it would look in another situation. Nothing on them sends. A small window lets you switch it or end it; combat ends it."],
          values = function() return NS.Preview.Choices() end,
          validate = function(v) return v == NS.Preview.OFF or NS.Preview.FindPreset(v) ~= nil end },
    },
    -- Reset position resets every pad and dial anchor (spec §10.4).
    onResetPosition  = function() if NS.Surfaces and NS.Surfaces.ResetPositions then NS.Surfaces.ResetPositions() end end,
    onResetAll       = showResetPopup,
}

-- Each composed row reacts the way every other surface's write to the same path does.
for _, row in ipairs(MASTER_ROWS) do
    row.onChange = Settings.REACTIONS[row.path]
end
Settings.StampClosureRows(MASTER_ROWS)
NS.SchemaRuntime.AddRows(MASTER_ROWS, 1)

local AFTER_GROUP = {}
if Helpers.MASTER_GROUP then AFTER_GROUP[Helpers.MASTER_GROUP] = MASTER_TAIL end

-- The Keybindings tab (item 015, options-ui-§20): the General page's LAST tab, drawn by the library
-- (O.KeybindingsTab, LibKa0s-Options-1.0's OptionsKeybinds.lua) with no `before`, so it lands after
-- every group tab. One row per NS.BINDINGS entry (settings/SlashVerbs.lua): Toggle Comms Pads, then
-- Open Comms Dial 1-4, two key slots and Clear each, writing WoW's own binding to the set in force, so
-- a key set here shows in Options -> Keybindings -> Ka0s Quick Comms and the other way round. The one
-- host line under the library's intro says a dial's key follows its place. This brings back an
-- in-panel key editor the dial rework removed (the Dial page's Binding tab, 2026-10-21); the owner's
-- item 015 supersedes that removal, through the library's surface rather than the retired
-- Dial.BindKey. Keys are not settings: Defaults and Reset all settings never reach them.
local function keybindingsTab()
    return Helpers.KeybindingsTab({
        bindings = NS.BINDINGS,
        intro    = L["A dial's key follows its place in the dial list: Open Comms Dial 1 opens the first dial, and a dial past the fourth has no key."],
    })
end

local function renderGeneral(c)
    Helpers.ClearScroll(c)
    Helpers.RenderTabbedSchema(c, "general", AFTER_GROUP, nil, {
        rerender = renderGeneral,
        tabs     = { keybindingsTab() },
    })
end

-- The header Defaults is the global reset (showResetPopup), so it carries the library's Reset all
-- settings tooltip, read from the same descriptor Master controls' button uses, then the key-binding
-- sentence (item 020, QUI-L-new2; options-ui-§12, §20): one act, described one way.
local function buildGeneralPage(parentCategory)
    local ctx = Helpers.CreatePanel(addonName .. "GeneralPanel", L["General"], {
        pageKey         = "general",
        defaultsButton  = true,
        defaultsTooltip = Helpers.ResetAllTooltip(Helpers.KEYBINDS_UNCHANGED),
    })
    ctx.panel.defaultsOnClick = showResetPopup
    Helpers.SetRenderer(ctx, renderGeneral)
    return _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, L["General"])
end

Helpers.RegisterOptionsPage("general", L["General"], buildGeneralPage)

--- Register the settings category. Idempotent; called from OnEnable and from `/qc config`.
function Settings.Register()
    if QC._settingsRegistered or not _G.Settings
       or not _G.Settings.RegisterCanvasLayoutCategory
       or not _G.Settings.RegisterCanvasLayoutSubcategory then
        return
    end
    Helpers.CreateOptionsPanel()
    -- "Preview as…" ends when the settings window closes (spec §13.3).
    if NS.Preview then NS.Preview.WatchPanel(_G.SettingsPanel) end
    QC._settingsRegistered = true
end
