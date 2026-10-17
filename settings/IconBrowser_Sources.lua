local _, NS = ...
-- settings/IconBrowser_Sources.lua — what the icon browser (settings/IconBrowser.lua) offers, tab by
-- tab (icon browser spec, "Tabs"), and what each icon is called. Pure apart from the client's icon
-- lists, which it reads through core/Compat.lua.
--
--     suggested  the eight raid markers; the game icons the built-in sets wear, read from
--                NS.BuiltIns (so a set that gains an icon offers it); then the LibKa0s glyphs a
--                callout reads well with (GLYPH_LABELS)
--     markers    the eight raid target markers (the whole set)
--     game       every icon the macro icon selector offers (Compat.MacroIcons: spells, then items),
--                as texture ids, filtered All / Spells / Items
--     glyphs     every icon of the LibKa0s catalog (NS.IconNames; library-stack-§8: enumerated,
--                never a hard-coded path list), white on transparent, so each takes a color
--
-- Each tab is a list of icon VALUES as the Icon row stores them (a texture path, or a texture id
-- for a game icon), never a table per icon: the game list holds thousands. Label(icon) names one.
--
-- THE GAME LIST is read on first use and kept only once the client answers with icons: until its
-- own icon list has loaded the client answers with none, so an empty answer is asked again next
-- time (GameIcons' second value says whether it is loaded).

local Settings = NS.addon.Settings
local L = NS.L

Settings.IconBrowserSources = Settings.IconBrowserSources or {}
local Src = Settings.IconBrowserSources

Src.MARKER_NAMES = { L["Star"], L["Circle"], L["Diamond"], L["Triangle"], L["Moon"], L["Square"], L["Cross"],
    L["Skull"] }
-- The catalog's glyphs a callout reads well with, and their player-facing labels. Most of the
-- catalog is window chrome (close, sort, align) that the Glyphs tab still offers; these are the
-- ones Suggested offers. A name the catalog drops simply stops being offered.
Src.GLYPH_LABELS = { chat = L["Chat"], ["speech-bubble"] = L["Speech bubble"], warning = L["Warning"],
    info = L["Information"], help = L["Help"], target = L["Target"], shield = L["Shield"],
    heart = L["Heart"], star = L["Star"], ["map-marker"] = L["Map marker"], location = L["Location"],
    people = L["People"], person = L["Person"], timer = L["Timer"], ban = L["Ban"],
    ["thumb-up"] = L["Thumbs up"] }

function Src.MarkerPath(i)
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i
end

--- A catalog name's label: the curated one, else the name itself, its dashes as spaces and its
--- first letter capitalized ("arrow-circle-down" -> "Arrow circle down"; not localized).
function Src.GlyphLabel(name)
    if Src.GLYPH_LABELS[name] then return Src.GLYPH_LABELS[name] end
    local words = name:gsub("-", " ")
    return (words:gsub("^%l", string.upper))
end

function Src.Markers()
    local out = {}
    for i = 1, #Src.MARKER_NAMES do out[i] = Src.MarkerPath(i) end
    return out
end

--- Every catalog glyph's path, in the catalog's order; empty without the library.
function Src.Glyphs()
    local out = {}
    for _, name in ipairs(NS.IconNames()) do
        local path = NS.Icon(name)
        if path then out[#out + 1] = path end
    end
    return out
end

-- The built-in sets' icons, each once, in the sets' order: a set's own, then its callouts'. Calls
-- `add(path, label)` for each.
local function eachBuiltinIcon(add)
    local BI = NS.BuiltIns
    for _, gid in ipairs(BI.order) do
        local def = BI.groups[gid]
        add(def.icon, def.name)
        for _, cid in ipairs(def.callouts or {}) do
            local c = BI.callouts[cid]
            if c then add(c.icon, c.name) end
        end
    end
end

function Src.Suggested()
    local out, seen = {}, {}
    local function add(path)
        if type(path) == "string" and not seen[path] then
            seen[path] = true
            out[#out + 1] = path
        end
    end
    for _, path in ipairs(Src.Markers()) do add(path) end
    eachBuiltinIcon(add)
    for _, name in ipairs(NS.IconNames()) do
        if Src.GLYPH_LABELS[name] then add(NS.Icon(name)) end
    end
    return out
end

-- path -> label, for every icon the named tabs carry; built on the first ask (the catalog and the
-- built-ins are fixed for the session).
local labels
local function labelMap()
    if labels then return labels end
    labels = {}
    for i, path in ipairs(Src.Markers()) do labels[path] = Src.MARKER_NAMES[i] end
    eachBuiltinIcon(function(path, label)
        if type(path) == "string" and labels[path] == nil then labels[path] = label end
    end)
    for _, name in ipairs(NS.IconNames()) do
        local path = NS.Icon(name)
        if path then labels[path] = Src.GlyphLabel(name) end
    end
    return labels
end

--- What `icon` is called: its label, "Texture id N" for a game icon, or the path itself.
function Src.Label(icon)
    if type(icon) == "number" then return L["Texture id %d"]:format(icon) end
    return labelMap()[icon] or tostring(icon or "")
end

-- The client's icon lists, kept once they answered with icons.
local cache = {}

local function source(kind)
    if cache[kind] then return cache[kind] end
    local list = NS.Compat.MacroIcons(kind)
    if #list > 0 then cache[kind] = list end
    return list
end

--- The game icons for `filter` ("all", "spells", "items"; default all), spells before items, each
--- once. Second value: false while the client's list has not loaded (it answered with none).
--- @return table icons, boolean loaded
function Src.GameIcons(filter)
    if filter == "spells" or filter == "items" then
        local list = source(filter)
        return list, #list > 0
    end
    if cache.all then return cache.all, true end
    local out, seen = {}, {}
    for _, kind in ipairs({ "spells", "items" }) do
        for _, v in ipairs(source(kind)) do
            if not seen[v] then
                seen[v] = true
                out[#out + 1] = v
            end
        end
    end
    if cache.spells and cache.items then cache.all = out end
    return out, #out > 0
end

--- The tab an icon is found on: a marker's, a glyph's, a texture id's (game), else Suggested.
function Src.TabFor(icon)
    if type(icon) == "number" then return "game" end
    if NS.Library.IsGlyph(icon) then return "glyphs" end
    for _, path in ipairs(Src.Markers()) do
        if path == icon then return "markers" end
    end
    return "suggested"
end

--- The list a tab shows (`filter` for the game tab), and whether it is loaded.
--- @return table icons, boolean loaded
function Src.List(tab, filter)
    if tab == "markers" then return Src.Markers(), true end
    if tab == "glyphs" then return Src.Glyphs(), true end
    if tab == "game" then return Src.GameIcons(filter) end
    return Src.Suggested(), true
end
