local _, NS = ...
-- modules/Bake.lua — a callout + a snapshot -> exactly one macro line (spec §8.3). PURE.
-- Anti-pattern #20: callout text is chat text, never a command. The sanitizer flattens control
-- characters (so there is never a second macro line), refuses a leading "/", and escapes "|"
-- before tokens expand, and Tokens does the same to every baked value ({me}, {spec}, ...), so only
-- game-made spell links carry escape sequences.

NS.Bake = NS.Bake or {}
local B = NS.Bake

B.MAX_BYTES = 255

local function squeeze(s)
    s = s:gsub("%s+", " ")
    s = s:gsub("^ ", "")
    s = s:gsub(" $", "")
    return s
end

--- Clean user text: one line, no leading slash, pipes escaped.
--- @return string|nil clean, string|nil reason ("empty" | "startsWithSlash")
function B.Sanitize(text)
    if type(text) ~= "string" then return nil, "empty" end
    local s = squeeze((text:gsub("%c", " ")))
    if s == "" then return nil, "empty" end
    if s:sub(1, 1) == "/" then return nil, "startsWithSlash" end
    s = s:gsub("|", "||")
    return s
end

--- Bytes the line's text will take: its own bytes plus a nominal 12 for each live token.
function B.Length(text, live)
    return #text + (live or 0) * NS.Tokens.LIVE_NOMINAL
end

--- Bake one callout.
--- @param callout table { text, channel, ... }
--- @param s table snapshot
--- @param opts table|nil { soloFallback, ctx }
--- @return string|nil line, string|nil reason, table info
function B.Bake(callout, s, opts)
    opts = type(opts) == "table" and opts or {}
    local info = {}
    if type(callout) ~= "table" then return nil, "badCallout", info end
    local clean, why = B.Sanitize(callout.text)
    if not clean then return nil, why, info end
    local concrete, reason, selfPrint = NS.Channels.Resolve(callout.channel, s, opts.soloFallback)
    info.selfPrint = selfPrint
    if not concrete then return nil, reason, info end
    local text, unknown, missing, live = NS.Tokens.Expand(clean, opts.ctx)
    text = squeeze(text)
    info.concrete, info.unknown, info.missing, info.text = concrete, unknown, missing, text
    if text == "" then return nil, "empty", info end
    if text:sub(1, 1) == "/" then return nil, "startsWithSlash", info end
    info.length = B.Length(text, live)
    if info.length > B.MAX_BYTES then return nil, "tooLong", info end
    info.lock = NS.Channels.LockState(concrete, s)
    info.warning = NS.Channels.SoftWarning(concrete, s)
    return NS.Channels.Prefix(concrete) .. " " .. text, nil, info
end
