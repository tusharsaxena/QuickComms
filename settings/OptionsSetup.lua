local addonName, NS = ...
-- settings/OptionsSetup.lua — the panel descriptor; Settings.Helpers IS the LibKa0s-Options instance.
--
-- The canvas shell, widget makers, flow engine, tab strip, header, Defaults button and scrollbar
-- patch are the library's (options-ui-§1). This file says where values live (the schema seam) and
-- what the landing page shows. The library-absent branch is LOAD-COMPLETING: every member a
-- settings file touches at load answers, the composers are hollow ({}), and opening the panel says
-- once that it is unavailable.
local QC = NS.addon
local Settings  = QC.Settings
local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

-- The color codec, written out (options-ui-§1): every color row stores { r, g, b, a } (a pad's Look
-- colors), which is also the library's default shape. A missing component reads as 1.
Settings.ColorCodec = {
    decode = function(c)
        if type(c) ~= "table" then c = {} end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end,
    encode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
}

if not lib then
    local missing = NS.L["%s, so the settings panel is unavailable."]:format(NS.LIBKA0S_MISSING)
    local function announcer()
        local said = false
        return function()
            if said then return end
            said = true
            if NS.Print then NS.Print(missing) end
        end
    end
    local sayAtLoad, sayOnConfig = announcer(), announcer()
    local H = Settings.Helpers
    H.CreatePanel          = function() return { refreshers = {} } end
    H.EnsureDefaultsButton = function() end
    H.EnsureScroll         = function() return nil end
    H.ClearScroll          = function() end
    H.AddSpacer            = function() end
    H.Section              = function() end
    H.TextRow              = function() end
    H.AttachTooltip        = function() end
    H.InlineButtonPair     = function() end
    H.RenderField          = function() end
    H.SessionCheckbox      = function() end
    H.RenderRows           = function() end
    H.RenderSchema         = function() end
    H.RenderGrid           = function() end
    H.RenderTabbedSchema   = function() end
    H.TabStrip             = function() end
    H.PageBanner           = function() end
    H.PageHeader           = function() end
    H.SubTabStrip          = function() end
    H.SetChromeHeight      = function() end
    H.__bannerBand         = function() end
    H.__tabBand            = function() end
    H.__tabPlacement       = function() end
    H.__layoutTabs         = function() end
    H.__scrollTopInset     = function() end
    H.__releaseChrome      = function() end
    H.__releaseSubTabs     = function() end
    H.__tabArtHeight       = function() return 0 end
    H.__resetTabArtHeight  = function() end
    H.ColorPair            = function() return {} end
    H.FontGroup            = function() return {} end
    H.BorderGroup          = function() return {} end
    H.BarGroup             = function() return {} end
    H.MasterControls       = function() return {}, function() end end
    H.ChoiceGrid           = function() end
    H.IdInput              = function() end
    H.IdList               = function() end
    H.ResolveId            = function() return nil end
    H.UnnamedCandidates    = function() return nil end
    H.ID_NAME_HINT         = {}
    H.SelectTab            = function() end
    H.NavRail              = function() end
    H.Drawer               = function() end
    H.SetRenderer          = function() end
    H.RegisterOptionsPage  = function() end
    H.RefreshAllPanels     = function() end
    H.RefreshPanel         = function() end
    H.RefreshScalars       = function() end
    H.RestoreAllDefaults   = H.RestoreAllDefaults or function() end
    H.LSMValues            = function() return function() return {} end end
    H.PatchAlwaysShowScrollbar = function() end
    H.__pages              = function() return {} end
    H.__panels             = function() return {} end
    H.__panelFor           = function() return nil end
    H.CreateOptionsPanel   = function() sayAtLoad() end
    H.OpenOptionsPanel     = function() sayOnConfig() end
    return
end
local host = Settings.Helpers
local O = lib:New({
    parentTitle = NS.BRAND,
    mainPanelName = addonName .. "MainPanel",
    addonName = addonName,
    print = function(line) NS.Print(line) end,
    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    get          = NS.SchemaRuntime.Get,
    -- A refused write says why, as the CLI does (the library drops set's answer); the widget's own
    -- refresh puts it back to the stored value.
    set          = function(path, value, id)
        local ok, err, why = NS.SchemaRuntime.Set(path, value, id)
        if not ok then NS.Print(tostring(why or err)) end
        return ok, err, why
    end,
    applyDefault = NS.SchemaRuntime.ApplyDefault,
    -- A page's rows are those whose `page` is its key; `group` is the tab within it (options-ui-§13).
    rowsForPage = function(pageKey) return Settings.RowsForPage(pageKey) end,
    allRows     = function() return Settings.Schema end,
    validate = function() host.ValidateSchema() end,
    buildMain = function(ctx) Settings.Helpers.BuildMainContent(ctx) end,
    bulkBegin = NS.SchemaRuntime.BulkBegin,
    bulkEnd   = NS.SchemaRuntime.BulkEnd,
    getLSM        = function() return LibStub("LibSharedMedia-3.0", true) end,
    scheduleTimer = function(fn, delay) return QC:ScheduleTimer(fn, delay) end,
    resetProfile = function() QC.db:ResetProfile() end,
    profilesPage = true,
    colorDecode  = Settings.ColorCodec.decode,
    colorEncode  = Settings.ColorCodec.encode,
    skipRestoreAll = Settings.VetoedFromResetAll,
})
for k, v in pairs(host) do
    O[k] = v
end
Settings.Helpers = O
function O.RefreshAll() O.RefreshScalars() end
