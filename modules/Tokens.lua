local _, NS = ...
-- modules/Tokens.lua — the editor's token chips -> engine tokens and baked values (spec §8.1).
-- PURE: no client call. Live tokens (%t, %f, {rtN}, {gN}) are expanded by the game at send time;
-- baked ones ({me}, {spec}, {role}, {key}, {dungeon}, {spell:ID}) come from `ctx`, which the
-- caller fills out of combat.

NS.Tokens = NS.Tokens or {}
local Tok = NS.Tokens

Tok.LIVE_NOMINAL = 12   -- bytes each live token is assumed to add when sent (spec §8.3)

local ENGINE = { target = "%t", focus = "%f" }
local RT_BY_NAME = { star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6, cross = 7, x = 7, skull = 8 }
local BAKED = { me = true, spec = true, role = true, key = true, dungeon = true }

local function expandOne(raw, ctx, acc)
    local name = raw:lower()
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
        return ""
    end
    if BAKED[name] then
        local v = ctx[name]
        if v == nil or v == "" then acc.missing[#acc.missing + 1] = raw return "" end
        -- a baked value is chat text too: flatten control characters, escape stray pipes (spec §8.3)
        return (tostring(v):gsub("%c", " "):gsub("|", "||"))
    end
    acc.unknown[#acc.unknown + 1] = raw
    return "{" .. raw .. "}"
end

--- Expand every {chip} in `text`.
--- @param text string|any
--- @param ctx table|nil baked values (see header)
--- @return string out, table unknown, table missing, number live
function Tok.Expand(text, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local acc = { unknown = {}, missing = {}, live = 0 }
    if type(text) ~= "string" then return "", acc.unknown, acc.missing, 0 end
    local out = text:gsub("{([%w:]+)}", function(raw) return expandOne(raw, ctx, acc) end)
    -- the game also expands a typed %t / %f, so count every one in the output (chips included, once)
    local _, engine = out:gsub("%%[tf]", "")
    return out, acc.unknown, acc.missing, acc.live + engine
end

--- True when `text` uses a raid-group token, which expands only in a raid (spec §8.1).
function Tok.UsesGroupToken(text)
    if type(text) ~= "string" then return false end
    local lower = text:lower()
    return lower:find("{g[1-8]}") ~= nil or lower:find("{group[1-8]}") ~= nil
end
