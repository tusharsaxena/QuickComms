local _, NS = ...
-- core/IconBrowserSetup.lua — NS.IconBrowserLib from LibKa0s-IconBrowser-1.0 (LibKa0s v1.86.0): the
-- icon browser's seam (library-stack-§7).
--
-- The major was promoted out of this addon (its settings/IconBrowser.lua, IconBrowser_Sources.lua,
-- the glyph helpers of modules/Library.lua and Compat.MacroIcons). Two callers read it, both at call
-- time: settings/IconBrowser.lua builds the one browser with `IB:New`, and modules/Library.lua's glyph
-- helpers (IsGlyph, ValidIconColor, IconTint, IconColorFrom) are its IsGlyph, ValidColor, Tint and
-- ColorFrom under the names the rest of the addon calls.
--
-- An absent major means no browser and no glyph: the stub has no New (settings/IconBrowser.lua opens
-- nothing), IsGlyph answers nil for every icon (MediaSetup's catalog is empty without the library
-- too), and ColorFrom stores none. ValidColor keeps the real check, so a degraded install's repair
-- pass (modules/Library.lua) never drops a stored color it could not draw anyway.

local IB = LibStub and LibStub("LibKa0s-IconBrowser-1.0", true)

local function validColor(v)
    if v == nil or v == false then return true end
    if type(v) == "string" and v:match("^%x%x%x%x%x%x$") and v == v:lower() then return true end
    return false, "badColor"
end

NS.IconBrowserLib = IB or {
    IsGlyph = function() return nil end,
    ValidColor = validColor,
    ColorFrom = function() return false end,
    Tint = function() return 1, 1, 1 end,
}
