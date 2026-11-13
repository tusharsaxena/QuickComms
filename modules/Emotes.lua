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

-- ── THE BROWSE TREE (the popup's emote dropdown) ─────────────────────────────────────────────
--
-- Every emote, A to Z by command, cut into a cascade the popup's menu opens level by level: at most
-- TREE_BRANCH rows on a level that holds levels, at most TREE_LEAF emotes on a level that holds emotes
-- (owner, 2026-11-13). The top level is letters, a letter never split across two rows: adjacent
-- letters are packed into at most TREE_BRANCH runs ("A", "B–C") as evenly as the letters allow (the
-- smallest cap that packs them). A run with more than TREE_LEAF emotes is cut into ranges named by
-- the prefixes that tell their ends apart ("Ba–Bl"), each range cut again while it is over, so a level
-- is added only where one is needed. A command that does not start with a letter A to Z files under
-- "#". PURE apart from E.List.

E.TREE_BRANCH, E.TREE_LEAF = 10, 15

local function bare(cmd) return (cmd:gsub("^/", "")) end

local function initial(cmd)
    local c = bare(cmd):sub(1, 1):upper()
    return c:find("^%u$") and c or "#"
end

-- Group sizes `counts` (in order) into consecutive runs of total at most `cap` (a group over it alone):
-- how many runs that takes.
local function runsUnder(counts, cap)
    local runs, total = 0, cap + 1
    for _, n in ipairs(counts) do
        if total + n > cap then runs, total = runs + 1, n else total = total + n end
    end
    return runs
end

-- The shortest prefixes of commands `a` and `b` that differ, 2 to 4 letters, capitalized as a
-- label reads ("Ba", "Bl"); equal commands answer their whole selves.
local function rangeEnds(a, b)
    a, b = bare(a), bare(b)
    local n = 1
    while n <= #a and n <= #b and a:sub(n, n):lower() == b:sub(n, n):lower() do n = n + 1 end
    n = math.min(math.max(n, 2), 4)
    local function cap(s) return s:sub(1, 1):upper() .. s:sub(2):lower() end
    return cap(a:sub(1, n)), cap(b:sub(1, n))
end

local cut

-- One node for `items` (sorted emotes) under `label`: its emotes when they fit a leaf, else `cut`.
local function node(label, items)
    if #items <= E.TREE_LEAF then return { label = label, emotes = items } end
    return { label = label, children = cut(items) }
end

-- `items` cut into at most TREE_BRANCH even ranges, each a node named by its ends.
function cut(items)
    local k = math.min(E.TREE_BRANCH, math.ceil(#items / E.TREE_LEAF))
    local size = math.ceil(#items / k)
    local out = {}
    for i = 1, #items, size do
        local slice = {}
        for j = i, math.min(i + size - 1, #items) do slice[#slice + 1] = items[j] end
        local lo, hi = rangeEnds(slice[1].command, slice[#slice].command)
        out[#out + 1] = node(lo == hi and lo or (lo .. "–" .. hi), slice)
    end
    return out
end

--- The browse tree of `list` (E.List's shape; E.List when nil): a list of nodes, each { label, and
--- either `emotes` (the emotes, A to Z) or `children` (nodes) }. Empty for no emotes.
--- @return table[]
function E.Tree(list)
    local items = {}
    for i, e in ipairs(list or E.List()) do items[i] = e end
    table.sort(items, function(x, y)
        local a, b = bare(x.command):lower(), bare(y.command):lower()
        if a ~= b then return a < b end
        return x.token < y.token
    end)
    -- The letters in order, with their emotes.
    local letters, byLetter = {}, {}
    for _, e in ipairs(items) do
        local c = initial(e.command)
        if not byLetter[c] then byLetter[c] = {}; letters[#letters + 1] = c end
        table.insert(byLetter[c], e)
    end
    table.sort(letters, function(a, b)
        if (a == "#") ~= (b == "#") then return a == "#" end
        return a < b
    end)
    local counts = {}
    for i, c in ipairs(letters) do counts[i] = #byLetter[c] end
    -- The smallest cap that packs the letters into at most TREE_BRANCH runs.
    local capN = 0
    for _, n in ipairs(counts) do capN = math.max(capN, n) end
    while runsUnder(counts, capN) > E.TREE_BRANCH do capN = capN + 1 end
    local tree, run, total = {}, {}, 0
    local function flush()
        if #run == 0 then return end
        local emotes = {}
        for _, c in ipairs(run) do
            for _, e in ipairs(byLetter[c]) do emotes[#emotes + 1] = e end
        end
        local label = #run == 1 and run[1] or (run[1] .. "–" .. run[#run])
        tree[#tree + 1] = node(label, emotes)
        run, total = {}, 0
    end
    for i, c in ipairs(letters) do
        if total + counts[i] > capN then flush() end
        run[#run + 1] = c
        total = total + counts[i]
    end
    flush()
    return tree
end
