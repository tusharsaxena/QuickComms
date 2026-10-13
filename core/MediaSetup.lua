local addonName, NS = ...
-- core/MediaSetup.lua — NS.Icon / NS.MediaFont from LibKa0s-Media-1.0, the one RegisterLSM call, and
-- NS.MediaFetch, a LibSharedMedia entry by its name.
--
-- The icon catalog, the monospace face and the bar textures ship inside the vendored payload
-- (library-stack-§8). Every call passes the addon's own FOLDER name: the library is vendored and
-- cannot know which folder it was copied into, and a wrong texture path draws nothing and raises
-- nothing. Loads before core/Constants.lua, which resolves FONT_MONO from NS.MediaFont at load.

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon, or nil (library absent, or no such name). Nil is a real
--- answer: the caller draws something else.
--- @param name string  an entry of the library's icon catalog, e.g. "close"
--- @return string|nil
function NS.Icon(name)
    if not Media then return nil end
    return Media.Icon(addonName, name)
end

--- The path of one shipped face, or nil when the library is absent.
--- @param name string  a key of the library's font list, e.g. "JetBrains Mono"
--- @return string|nil
function NS.MediaFont(name)
    if not Media then return nil end
    return Media.Font(addonName, name)
end

-- At FILE LOAD, not PLAYER_LOGIN: LibSharedMedia is vendored under libs/ and has already run.
if Media then Media.RegisterLSM(addonName) end

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

--- The path of a LibSharedMedia entry by its name (a pad's Look font or border style), or nil: no
--- LibSharedMedia, no such name on this machine (a media addon removed, a shared pad naming one this
--- player lacks). Nil is a real answer: the caller draws its default.
--- @param kind string "font" | "border" | "statusbar" | "background"
--- @param name string|nil
--- @return string|nil
function NS.MediaFetch(kind, name)
    if not (LSM and type(name) == "string" and name ~= "") then return nil end
    local ok, path = pcall(LSM.Fetch, LSM, kind, name, true)
    if ok and type(path) == "string" and path ~= "" then return path end
    return nil
end

--- The icon catalog's names, in its order (library-stack-§8: a catalog is enumerated, never
--- hard-coded), or an empty list when the library is absent. The icon picker reads it
--- (settings/Editors.lua).
--- @return string[]
function NS.IconNames()
    return Media and Media.ICONS or {}
end
