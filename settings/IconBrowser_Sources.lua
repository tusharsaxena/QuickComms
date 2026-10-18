local _, NS = ...
-- settings/IconBrowser_Sources.lua — what the icon browser (settings/IconBrowser.lua) offers, tab by
-- tab (icon browser spec, "Tabs"), and what each icon is called. Pure apart from the client's icon
-- lists, which it reads through core/Compat.lua.
--
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
--
-- SEARCH (Search) is a case-insensitive plain substring over what an icon is called on its tab: a
-- marker's name, a glyph's catalog key and its shown label, a game icon's texture id (its digits;
-- a texture path, should the client's list carry one, by its file name). The client has no API that
-- names a game icon from its texture id, so a game icon cannot be found by name here (the browser's
-- hint points at Wowhead for that).

local Settings = NS.addon.Settings
local L = NS.L

Settings.IconBrowserSources = Settings.IconBrowserSources or {}
local Src = Settings.IconBrowserSources

Src.MARKER_NAMES = { L["Star"], L["Circle"], L["Diamond"], L["Triangle"], L["Moon"], L["Square"], L["Cross"],
    L["Skull"] }
-- The catalog's glyphs a callout reads well with, and their player-facing labels. Every other
-- catalog glyph (most of it is window chrome: close, sort, align) is labeled from its key
-- (GlyphLabel). A name the catalog drops simply loses its label.
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

-- path -> label, and a glyph's path -> its catalog key, for every icon the named tabs carry; built
-- on the first ask (the catalog is fixed for the session).
local labels, keys
local function labelMap()
    if labels then return labels end
    labels, keys = {}, {}
    for i, path in ipairs(Src.Markers()) do labels[path] = Src.MARKER_NAMES[i] end
    for _, name in ipairs(NS.IconNames()) do
        local path = NS.Icon(name)
        if path then
            labels[path] = Src.GlyphLabel(name)
            keys[path] = name
        end
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
    local kinds = { "spells", "items" }
    if filter == "spells" or filter == "items" then kinds = { filter } else filter = "all" end
    local key = "once:" .. filter
    if cache[key] then return cache[key], true end
    -- The loose lists and the full ones overlap, and so may the two kinds: each icon once.
    local out, seen, loaded = {}, {}, true
    for _, kind in ipairs(kinds) do
        for _, v in ipairs(source(kind)) do
            if not seen[v] then
                seen[v] = true
                out[#out + 1] = v
            end
        end
        if not cache[kind] then loaded = false end
    end
    if loaded then cache[key] = out end
    return out, #out > 0
end

--- The tab an icon is found on: a marker's, a glyph's, a texture id's (game), else nil (a texture
--- path no tab lists: a built-in set's spell icon, a typed path).
--- @return string|nil
function Src.TabFor(icon)
    if type(icon) == "number" then return "game" end
    if NS.Library.IsGlyph(icon) then return "glyphs" end
    for _, path in ipairs(Src.Markers()) do
        if path == icon then return "markers" end
    end
    return nil
end

--- The list a tab shows (`filter` for the game tab), and whether it is loaded. Markers for any
--- other key.
--- @return table icons, boolean loaded
function Src.List(tab, filter)
    if tab == "glyphs" then return Src.Glyphs(), true end
    if tab == "game" then return Src.GameIcons(filter) end
    return Src.Markers(), true
end

-- What a search on `tab` reads of `icon`, lowercased.
local function searchText(tab, icon)
    if type(icon) == "number" then return tostring(icon) end
    icon = tostring(icon or "")
    if tab == "game" then return (icon:match("([^\\/]+)$") or icon):lower() end
    local label = labelMap()[icon] or icon
    return ((keys[icon] or "") .. "\n" .. label):lower()
end

--- The icons of `list` (a tab's, as List answers it) whose name on `tab` holds `query`: case-
--- insensitive, plain text, trimmed. A blank or nil query answers `list` itself.
--- @return table icons
function Src.Search(list, tab, query)
    local q = tostring(query or ""):match("^%s*(.-)%s*$"):lower()
    if q == "" then return list end
    local out = {}
    for _, v in ipairs(list) do
        if searchText(tab, v):find(q, 1, true) then out[#out + 1] = v end
    end
    return out
end
