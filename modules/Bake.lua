local _, NS = ...
-- modules/Bake.lua — a callout + a snapshot -> its macro: one line of at most 255 bytes per set
-- action (spec §8.3; combined actions §3). PURE. B.Bake bakes the Line action (prefix included), a
-- game emote (QFE-E2) is the client's own command (BakeEmote), and a ping or a marker is the
-- client's own command on the target. B.BakeActions bakes every set action and joins the lines.
-- Anti-pattern #20: callout text is chat text, never a command. The sanitizer flattens control
-- characters (so data never makes a second macro line; only code joins lines), refuses a leading "/", and escapes "|"
-- before tokens expand, and Tokens does the same to every baked value ({me}, {spec}, ...), so only
-- game-made spell links carry escape sequences.

NS.Bake = NS.Bake or {}
local B = NS.Bake

B.MAX_BYTES = 255
-- The whole macro's cap, measured as BakeActions' info.total (D13, conservative: the wiki's
-- SecureActionButtonTemplate page says 255 in total; ACTION-4 re-checks it in game).
B.MAX_MACRO = 255

local function squeeze(s)
    s = s:gsub("%s+", " ")
    s = s:gsub("^ ", "")
    s = s:gsub(" $", "")
    return s
end

--- The §8.3 sanitizer short of the escape: one line (every control character flattened to a
--- space), runs of whitespace collapsed, trimmed, and a leading "/" refused. The "|" escape is
--- left to the bake, so a stored "|" is never escaped twice.
--- @return string|nil clean, string|nil reason ("empty" | "startsWithSlash")
function B.CleanText(text)
    if type(text) ~= "string" then return nil, "empty" end
    local s = squeeze((text:gsub("%c", " ")))
    if s == "" then return nil, "empty" end
    if s:sub(1, 1) == "/" then return nil, "startsWithSlash" end
    return s
end

--- Clean user text: one line, no leading slash, pipes escaped.
--- @return string|nil clean, string|nil reason ("empty" | "startsWithSlash")
function B.Sanitize(text)
    local s, why = B.CleanText(text)
    if not s then return nil, why end
    return (s:gsub("|", "||"))
end

--- Bytes the line will take: its text's own bytes plus a nominal 12 for each live token and, with
--- a prefix, the prefix and its space too. The 255-byte cap covers the WHOLE macro line, because
--- macrotext runs through the edit-box path, whose cap counts the line as typed (spec §8.3).
--- @param text string
--- @param live number|nil live tokens in the text
--- @param prefix string|nil the channel's slash prefix ("/p")
--- @return number
function B.Length(text, live, prefix)
    local head = prefix and (#prefix + 1) or 0
    return head + #text + (live or 0) * NS.Tokens.LIVE_NOMINAL
end

--- Bake a game-emote callout (QFE-E2): its line is the client's own command for its token
--- ("/point"), from Emotes' map and never from user text, so no typed "/" ever reaches the line. Its
--- text is ignored. A token this client lacks bakes nothing: "noEmote" with none set, else
--- "unknownEmote" (info.emote names it).
--- @return string|nil line, string|nil reason, table info
function B.BakeEmote(callout, s, info)
    info = info or {}
    info.unknown, info.missing, info.emote = {}, {}, callout.emote
    local token = NS.Emotes.Normalize(callout.emote)
    if not token then return nil, "noEmote", info end
    local cmd = NS.Emotes.Command(token)
    if not cmd then return nil, "unknownEmote", info end
    info.concrete, info.text, info.command = "gameEmote", cmd, cmd
    info.length = #cmd
    if info.length > B.MAX_BYTES then return nil, "tooLong", info end
    info.lock = NS.Channels.LockState("gameEmote", s)
    return cmd, nil, info
end

--- Bake one callout.
--- @param callout table { text, channel, ... }
--- @param s table snapshot
--- @param opts table|nil { soloFallback, ctx, mock } (`mock`: Tokens.Expand's, a preview's echo only)
--- @return string|nil line, string|nil reason, table info
function B.Bake(callout, s, opts)
    opts = type(opts) == "table" and opts or {}
    local info = {}
    if type(callout) ~= "table" then return nil, "badCallout", info end
    if NS.Channels.IsGameEmote(callout.channel) then return B.BakeEmote(callout, s, info) end
    local clean, why = B.Sanitize(callout.text)
    if not clean then return nil, why, info end
    local concrete, reason, selfPrint = NS.Channels.Resolve(callout.channel, s, opts.soloFallback)
    info.selfPrint = selfPrint
    if not concrete then return nil, reason, info end
    local text, unknown, missing, live = NS.Tokens.Expand(clean, opts.ctx, opts.mock)
    text = squeeze(text)
    info.concrete, info.unknown, info.missing, info.text = concrete, unknown, missing, text
    if text == "" then return nil, "empty", info end
    if text:sub(1, 1) == "/" then return nil, "startsWithSlash", info end
    local prefix = NS.Channels.Prefix(concrete)
    info.length = B.Length(text, live, prefix)
    if info.length > B.MAX_BYTES then return nil, "tooLong", info end
    info.lock = NS.Channels.LockState(concrete, s)
    return prefix .. " " .. text, nil, info
end

-- ── The four actions (combined actions §3): line, emote, ping, marker, in that fixed order (D1) ──

-- The ping's numeric keyword: the same in every locale (D12, pingNameToTypeTable).
local PING_NUM = { attack = "1", warning = "2", onmyway = "3", assist = "4" }

local function lineEntry(callout, s, opts)
    local line, reason, info = B.Bake(callout, s, opts)
    return { kind = "line", line = line, reason = reason, concrete = info.concrete,
        chatType = info.concrete and NS.Channels.ChatType(info.concrete) or nil, lock = info.lock,
        length = info.length, unknown = info.unknown, missing = info.missing, selfPrint = info.selfPrint,
        text = info.text }
end

local function emoteEntry(callout, s)
    local line, reason, info = B.BakeEmote(callout, s)
    return { kind = "emote", line = line, reason = reason, concrete = "gameEmote",
        chatType = NS.Channels.ChatType("gameEmote"), lock = info.lock, length = info.length,
        unknown = info.unknown, missing = info.missing, value = callout.emote }
end

-- A ping or a marker: the client's command, "[@target,exists]" (so no target parses to nothing),
-- then the argument. No chat type and no lock (D25). An absent command drops only this action.
local function targetEntry(kind, cmd, arg, missingReason, value)
    if not cmd then return { kind = kind, reason = missingReason, value = value } end
    if not arg then return { kind = kind, reason = kind == "ping" and "badPing" or "badMarker", value = value } end
    local line = cmd .. " [@target,exists] " .. arg
    return { kind = kind, line = line, length = #line, value = value }
end

local function markerArg(n)
    if type(n) == "number" and n >= 1 and n <= 8 and n % 1 == 0 then return "!" .. n end
    return nil
end

--- Whether callout fields `f` carry a Line (the one rule Bake and Library share): a channel other
--- than the no-line gameEmote (D10), and text that is not empty after B.CleanText (whitespace or
--- control characters alone are no Line; a leading "/" still is: its bake refuses it and says why).
function B.HasLine(f)
    if type(f) ~= "table" or NS.Channels.IsGameEmote(f.channel) or type(f.text) ~= "string" then return false end
    local clean, why = B.CleanText(f.text)
    return clean ~= nil or why == "startsWithSlash"
end

-- Hold the Line to what the macro has left (D13): the other actions bake first, and the Line gets
-- min(MAX_BYTES, MAX_MACRO - their lengths - the one newline each puts between it and them). A Line
-- over it alone fails "tooLong"; the others still bake.
local function holdLine(list)
    local line = list[1]
    if not (line and line.kind == "line" and line.line) then return end
    local others = 0
    for i = 2, #list do
        if list[i].line then others = others + list[i].length + 1 end
    end
    line.budget = math.min(B.MAX_BYTES, B.MAX_MACRO - others)
    if line.length > line.budget then line.line, line.reason = nil, "tooLong" end
end

--- Bake every set action of one callout (combined actions §3).
--- info.actions lists every set action, baked or not, as { kind, line, reason, concrete, chatType,
--- lock, length, unknown, missing, selfPrint } (the Line's also carries `budget`, its share of
--- MAX_MACRO); info.baked only those that baked (line ~= nil), in the same order; info.total the
--- macro's budgeted length (each baked length plus one per "\n", at most MAX_MACRO). `reason` is set
--- only when nothing baked (D14): the Line's if there was one, else the first action's, else
--- "noAction". Solo with the "self" fallback the Line bakes no line (its reason is "solo") and the
--- other actions still arm.
--- @param callout table
--- @param s table snapshot
--- @param opts table|nil as B.Bake's
--- @return string|nil macro, string|nil reason, table info
function B.BakeActions(callout, s, opts)
    local info = { actions = {}, baked = {}, total = 0 }
    if type(callout) ~= "table" then return nil, "badCallout", info end
    local list = info.actions
    if B.HasLine(callout) then list[#list + 1] = lineEntry(callout, s, opts) end
    if callout.emote then list[#list + 1] = emoteEntry(callout, s) end
    if callout.ping then
        list[#list + 1] = targetEntry("ping", NS.Compat.PingCommand(), PING_NUM[callout.ping], "noPing", callout.ping)
    end
    if callout.marker then
        list[#list + 1] = targetEntry("marker", NS.Compat.MarkerCommand(), markerArg(callout.marker), "noMarker",
            callout.marker)
    end
    holdLine(list)
    local lines = {}
    for _, a in ipairs(list) do
        if a.line then
            info.baked[#info.baked + 1] = a
            lines[#lines + 1] = a.line
            info.total = info.total + a.length + (#lines > 1 and 1 or 0)
        end
    end
    if #lines == 0 then return nil, list[1] and list[1].reason or "noAction", info end
    return table.concat(lines, "\n"), nil, info
end
