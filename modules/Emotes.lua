local _, NS = ...
-- modules/Emotes.lua — the game emotes a callout can perform (QFE-E2, QuickComms#15, design §5.1, §5.2).
-- A game-emote callout stores a token (`emote = "POINT"`) and no text; its line is the client's own
-- localized command for that token ("/point"), from the EMOTEn_TOKEN to EMOTEn_CMDj map
-- (Compat.EmoteCommands: the first command the chat parser does not run as something else first,
-- so never /shout, which is Yell), never from user text, so the bake's "text may not start with /" rule stays
-- whole. The map is built once, on the first read, and kept: the client defines the globals before
-- any addon loads. A token the client lacks has no command: the callout bakes nothing and says why.
--
-- THE PICKER ORDER: the speech emotes first (TextEmoteSpeechList, marked as voice: they play a
-- line), then the animated ones (EmoteList), then every other token in the client's index order.
-- Only tokens with a command are listed. PURE apart from that one read.

NS.Emotes = NS.Emotes or {}
local E = NS.Emotes

local commands, order, voice

local function build()
    if commands then return end
    commands, order = NS.Compat.EmoteCommands()
    voice = {}
    local speech, animated = NS.Compat.EmoteLists()
    local listed, ordered = {}, {}
    local function add(token, isVoice)
        if listed[token] or not commands[token] then return end
        listed[token] = true
        ordered[#ordered + 1] = token
        if isVoice then voice[token] = true end
    end
    for _, t in ipairs(speech) do add(t, true) end
    for _, t in ipairs(animated) do add(t, false) end
    for _, t in ipairs(order) do add(t, false) end
    order = ordered
end

--- Forget the map, so the next read builds it again (tests, which plant the client's globals).
function E.Reset()
    commands, order, voice = nil, nil, nil
end

--- A token as stored: trimmed and upper case, or nil for anything that is not one word of letters,
--- digits and underscores (what EMOTEn_TOKEN holds).
function E.Normalize(token)
    if type(token) ~= "string" then return nil end
    local t = token:match("^%s*(.-)%s*$"):upper()
    if not t:find("^[%u%d_]+$") then return nil end
    return t
end

--- The client's command for `token` ("/point"), or nil when this client has no such emote.
function E.Command(token)
    build()
    return commands[E.Normalize(token) or ""]
end

--- True for a speech emote (it plays a voice line).
function E.IsVoice(token)
    build()
    return voice[E.Normalize(token) or ""] == true
end

--- Every emote this client has, in the picker's order: { token, command, voice }.
--- @return table[]
function E.List()
    build()
    local out = {}
    for i, t in ipairs(order) do out[i] = { token = t, command = commands[t], voice = voice[t] == true } end
    return out
end

--- The token `text` names exactly: a command ("/point", "point") or a token ("POINT"), any case.
--- @return string|nil token
function E.Find(text)
    if type(text) ~= "string" then return nil end
    build()
    local typed = text:match("^%s*(.-)%s*$"):lower():gsub("^/", "")
    if typed == "" then return nil end
    for _, t in ipairs(order) do
        if commands[t]:lower() == "/" .. typed or t:lower() == typed then return t end
    end
    return nil
end

--- The emotes whose command or token holds `text` (any case, a leading "/" ignored), in the picker's
--- order, at most `limit` (all when nil). An empty search lists everything.
--- @return table[] { token, command, voice }
function E.Search(text, limit)
    build()
    local needle = type(text) == "string" and text:match("^%s*(.-)%s*$"):lower():gsub("^/", "") or ""
    local out = {}
    for _, t in ipairs(order) do
        local cmd = commands[t]
        if needle == "" or cmd:lower():find(needle, 1, true) or t:lower():find(needle, 1, true) then
            out[#out + 1] = { token = t, command = cmd, voice = voice[t] == true }
            if limit and #out >= limit then break end
        end
    end
    return out
end
