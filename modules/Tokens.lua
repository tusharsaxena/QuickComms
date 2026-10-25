local _, NS = ...
-- modules/Tokens.lua — the editor's token chips -> engine tokens and baked values (spec §8.1).
-- PURE: no client call. Live tokens (%t, %f, {rtN}, {gN}) are expanded by the game at send time;
-- baked ones ({me}, {spec}, {role}, {key}, {dungeon}, {coordinates}, {spell:ID}) come from `ctx`,
-- which the caller fills out of combat. A preview (QC-07) may pass a `mock`, which fills a baked value
-- that has none here instead of dropping it. {coords} is typed shorthand for {coordinates}, as {x} is
-- for {cross}; a live button whose text uses it is re-baked at the press (QF-03, UsesCoordinates).

NS.Tokens = NS.Tokens or {}
local Tok = NS.Tokens

Tok.LIVE_NOMINAL = 12   -- bytes each live token is assumed to add when sent (spec §8.3)

local ENGINE = { target = "%t", focus = "%f" }
local RT_BY_NAME = { star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6, cross = 7, x = 7, skull = 8 }
local BAKED = { me = true, spec = true, role = true, key = true, dungeon = true, coordinates = true }
local ALIAS = { coords = "coordinates" }

local function expandOne(raw, ctx, acc)
    local name = raw:lower()
    name = ALIAS[name] or name
    if ENGINE[name] then return ENGINE[name] end   -- counted from the output in Expand
    local rt = name:match("^rt([1-8])$") or RT_BY_NAME[name]
    if rt then acc.live = acc.live + 1 return "{rt" .. rt .. "}" end
    local g = name:match("^group([1-8])$") or name:match("^g([1-8])$")
    if g then acc.live = acc.live + 1 return "{g" .. g .. "}" end
    local id = name:match("^spell:(%d+)$")
    if id then
        local link = type(ctx.spellLink) == "function" and ctx.spellLink(tonumber(id)) or nil
        if type(link) == "string" and link ~= "" then return link end
        acc.missing[#acc.missing + 1] = raw
        return acc.mock and acc.mock(name) or ""
    end
    if BAKED[name] then
        local v = ctx[name]
        if v == nil or v == "" then
            acc.missing[#acc.missing + 1] = raw
            return acc.mock and acc.mock(name) or ""
        end
        -- a baked value is chat text too: flatten control characters, escape stray pipes (spec §8.3)
        return (tostring(v):gsub("%c", " "):gsub("|", "||"))
    end
    acc.unknown[#acc.unknown + 1] = raw
    return "{" .. raw .. "}"
end

--- Expand every {chip} in `text`.
--- @param text string|any
--- @param ctx table|nil baked values (see header)
--- @param mock function|nil mock(name): the stand-in for a baked value missing here ("key",
--- "spell:123"), or nil to drop it as a send does (a preview's echo, QC-07)
--- @return string out, table unknown, table missing, number live
function Tok.Expand(text, ctx, mock)
    ctx = type(ctx) == "table" and ctx or {}
    local acc = { unknown = {}, missing = {}, live = 0, mock = type(mock) == "function" and mock or nil }
    if type(text) ~= "string" then return "", acc.unknown, acc.missing, 0 end
    local out = text:gsub("{([%w:]+)}", function(raw) return expandOne(raw, ctx, acc) end)
    -- the game also expands a typed %t / %f, so count every one in the output (chips included, once)
    local _, engine = out:gsub("%%[tf]", "")
    return out, acc.unknown, acc.missing, acc.live + engine
end

--- True when `text` uses {coordinates} (or {coords}), the one baked value that moves while a plan
--- does not: its live button is re-baked at the press (QF-03).
function Tok.UsesCoordinates(text)
    if type(text) ~= "string" then return false end
    local lower = text:lower()
    return lower:find("{coordinates}", 1, true) ~= nil or lower:find("{coords}", 1, true) ~= nil
end
