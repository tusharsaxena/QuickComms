-- tests/test_locale.lua — the locale union gates (localization-§6). The base locale may be split into
-- topic files (locales/enUS_<Topic>.lua) at the file cap, so every gate here reads the UNION of the
-- enUS files the TOC loads, never one file: the list comes from the TOC itself, coverage reads the
-- loaded NS.L raw (its key-on-miss fallback answers for nothing), a key no addon file reads is dead,
-- and a key defined in two files fails, read from the files' text because last write wins in the
-- loaded table.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Keys an addon file reaches only through a dynamic read (`L[var]`, a reason table indexed into L):
-- the dead-key case cannot see those reads, so each such key is listed here with its reading
-- file:line and is never deleted as dead. Empty: every read today is a literal `L["..."]`.
local DYNAMIC_READS = {}

local function read(rel)
    local fh = assert(io.open(T.root .. "/" .. rel, "rb"), "cannot open " .. rel)
    local s = fh:read("*a"); fh:close()
    return s
end

-- ── a small Lua lexer: the `L["..."]` reads and definitions in a source text ────────────────────
-- Comments and strings are skipped as the client's parser skips them, so a key named in a comment
-- is neither a read nor a definition. `L` counts bare or as a field (`NS.L["..."]`); an index whose
-- key is not one string literal is a dynamic read. A literal followed by `=` (not `==`) defines.

local function longBracket(src, i)
    local eq = src:match("^%[(=*)%[", i)
    if not eq then return nil end
    local close = "]" .. eq .. "]"
    local _, e = src:find(close, i + #eq + 2, true)
    return (e or #src) + 1
end

local function shortString(src, i)
    local q, j = src:sub(i, i), i + 1
    while j <= #src do
        local c = src:sub(j, j)
        if c == "\\" then j = j + 2
        elseif c == q then return j + 1
        else j = j + 1 end
    end
    error("unterminated string at byte " .. i)
end

local function skipSpace(src, i)
    while true do
        local _, e = src:find("^%s+", i)
        if e then i = e + 1 end
        if src:sub(i, i + 1) == "--" then
            i = longBracket(src, i + 2) or ((src:find("\n", i, true) or #src) + 1)
        else
            return i
        end
    end
end

-- An `L[` at byte i (just past the `[`): the literal key and whether it is assigned, or nil when the
-- index is not one string literal.
local function indexAt(src, i)
    local s = skipSpace(src, i)
    local c = src:sub(s, s)
    if c ~= '"' and c ~= "'" then return nil end
    local e = shortString(src, s)
    local after = skipSpace(src, e)
    if src:sub(after, after) ~= "]" then return nil end
    local key = assert(loadstring("return " .. src:sub(s, e - 1)))()
    local nxt = skipSpace(src, after + 1)
    local assigned = src:sub(nxt, nxt) == "=" and src:sub(nxt + 1, nxt + 1) ~= "="
    return key, assigned
end

--- Every `L[...]` in `src`, in order: { key = <string|nil>, assigned = <bool>, line = <n> }.
local function scan(src)
    local out, i, n = {}, 1, #src
    while i <= n do
        local c = src:sub(i, i)
        if c == "-" and src:sub(i + 1, i + 1) == "-" then
            i = longBracket(src, i + 2) or ((src:find("\n", i, true) or n) + 1)
        elseif c == '"' or c == "'" then
            i = shortString(src, i)
        elseif c == "[" and longBracket(src, i) then
            i = longBracket(src, i)
        elseif c:match("[%a_]") then
            local _, e = src:find("^[%w_]+", i)
            local word = src:sub(i, e)
            i = e + 1
            if word == "L" then
                local b = skipSpace(src, i)
                if src:sub(b, b) == "[" and src:sub(b + 1, b + 1) ~= "[" and src:sub(b + 1, b + 1) ~= "=" then
                    local key, assigned = indexAt(src, b + 1)
                    local _, lines = src:sub(1, b):gsub("\n", "")
                    out[#out + 1] = { key = key, assigned = assigned or false, line = lines + 1 }
                end
            end
        else
            i = i + 1
        end
    end
    return out
end

-- ── the union, read from the TOC ────────────────────────────────────────────────────────────

local function isLocale(rel) return rel:match("^locales/enUS[%w_]*%.lua$") ~= nil end

local function localeFiles()
    local out = {}
    for _, rel in ipairs(T.loadAddon.tocFiles) do if isLocale(rel) then out[#out + 1] = rel end end
    return out
end

-- key -> { [file] = count } over every enUS file's definitions.
local function definitions()
    local defs = {}
    for _, rel in ipairs(localeFiles()) do
        for _, hit in ipairs(scan(read(rel))) do
            if hit.key and hit.assigned then
                defs[hit.key] = defs[hit.key] or {}
                defs[hit.key][rel] = (defs[hit.key][rel] or 0) + 1
            end
        end
    end
    return defs
end

-- key -> { [file] = line } over every literal read in every other addon file; and the dynamic reads.
local function readers()
    local reads, dynamic = {}, {}
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if not isLocale(rel) then
            for _, hit in ipairs(scan(read(rel))) do
                if hit.key then
                    reads[hit.key] = reads[hit.key] or {}
                    reads[hit.key][rel] = reads[hit.key][rel] or hit.line
                else
                    dynamic[#dynamic + 1] = rel .. ":" .. hit.line
                end
            end
        end
    end
    return reads, dynamic
end

local function sorted(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- ── the lexer itself ────────────────────────────────────────────────────────────────────────

test("locale: the scan reads literal L reads, field reads and definitions, and skips comments and strings", function()
    local hits = scan(table.concat({
        'L["a"] = "a"',
        'local x = NS.L["b"] .. L[ \'c\\"d\' ]',
        '-- L["in a comment"]',
        '--[[ L["in a block comment"] ]]',
        'local s = "L[\\"in a string\\"]"',
        'if L["e"] == x then end',
        'local y = L[var]',
        'local CL = {}; CL["f"] = 1',
    }, "\n"))
    local seen = {}
    for _, h in ipairs(hits) do seen[#seen + 1] = tostring(h.key) .. (h.assigned and "=" or "") end
    assertEqual(table.concat(seen, ","), 'a=,b,c"d,e,nil')
    assertEqual(hits[#hits].line, 7, "a dynamic read reports its line")
end)

-- ── the gates ───────────────────────────────────────────────────────────────────────────────

test("locale: the enUS files come from the TOC, enUS.lua first and the topic files contiguous after it", function()
    local toc = T.loadAddon.tocFiles
    local files = localeFiles()
    assertTrue(#files >= 1, "the TOC loads a base locale")
    assertEqual(files[1], "locales/enUS.lua", "enUS.lua loads first: it is the only file that creates NS.L")
    local first
    for i, rel in ipairs(toc) do if rel == files[1] then first = i break end end
    for k, rel in ipairs(files) do assertEqual(toc[first + k - 1], rel, "the enUS files load contiguously") end
end)

test("locale: only enUS.lua creates NS.L; each topic file opens on NS.L and only assigns", function()
    for _, rel in ipairs(localeFiles()) do
        local src = read(rel)
        if rel == "locales/enUS.lua" then
            assertTrue(src:find("NS.L = L", 1, true) ~= nil, rel .. " publishes NS.L")
        else
            assertTrue(src:find("local _, NS = ...", 1, true) ~= nil, rel .. " opens with local _, NS = ...")
            assertTrue(src:find("local L = NS.L", 1, true) ~= nil, rel .. " reads NS.L")
            assertTrue(src:find("setmetatable", 1, true) == nil, rel .. " creates no table of its own")
            for _, hit in ipairs(scan(src)) do assertTrue(hit.key and hit.assigned, rel .. ":" .. hit.line .. " only assigns") end
        end
    end
end)

test("locale: each topic file's TOC line is preceded by a LOAD-BEARING comment", function()
    local prev
    for line in read("QuickComms.toc"):gmatch("[^\r\n]+") do
        local entry = line:match("^%s*(.-)%s*$")
        local rel = entry:gsub("\\", "/")
        if isLocale(rel) and rel ~= "locales/enUS.lua" then
            assertTrue(prev and prev:match("^# LOAD%-BEARING:") ~= nil, rel .. " carries a LOAD-BEARING comment")
        end
        if entry ~= "" then prev = entry end
    end
end)

test("locale: every literal L read resolves in the loaded NS.L, raw", function()
    local NS = T.newAddon()
    local reads = readers()
    local missing = {}
    for _, key in ipairs(sorted(reads)) do
        if rawget(NS.L, key) == nil then
            local where = sorted(reads[key])[1]
            missing[#missing + 1] = ("%s:%d %q"):format(where, reads[key][where], key)
        end
    end
    assertEqual(#missing, 0, "keys read but defined in no enUS file:\n" .. table.concat(missing, "\n"))
end)

test("locale: no key is dead (defined in an enUS file and read by no addon file)", function()
    local reads = readers()
    local dead = {}
    for _, key in ipairs(sorted(definitions())) do
        if not reads[key] and not DYNAMIC_READS[key] then dead[#dead + 1] = ("%q"):format(key) end
    end
    assertEqual(#dead, 0, "dead keys:\n" .. table.concat(dead, "\n"))
end)

test("locale: every dynamic L read is accounted for in the allowlist", function()
    local _, dynamic = readers()
    local listed = {}
    for _, where in pairs(DYNAMIC_READS) do listed[where] = true end
    for _, where in ipairs(dynamic) do
        assertTrue(listed[where], where .. " reads L with a non-literal key: list its keys in DYNAMIC_READS")
    end
end)

test("locale: no key is defined twice, in one enUS file or across two", function()
    local twice, defs = {}, definitions()
    for _, key in ipairs(sorted(defs)) do
        local d, total = defs[key], 0
        for _, n in pairs(d) do total = total + n end
        if total > 1 then twice[#twice + 1] = ("%q in %s"):format(key, table.concat(sorted(d), ", ")) end
    end
    assertEqual(#twice, 0, "keys defined more than once:\n" .. table.concat(twice, "\n"))
end)

-- ── placement, both ways (localization-§6: a key sits with its first reader in TOC order) ──────
-- settings/ loads after modules/, defaults/ and core/, so a key any of those reads stays in enUS.lua
-- and a key only settings/ reads lives in enUS_Settings.lua.

local function definedIn(rel)
    local keys = {}
    for _, hit in ipairs(scan(read(rel))) do if hit.key and hit.assigned then keys[#keys + 1] = hit.key end end
    return keys
end

local function underSettings(rel) return rel:match("^settings/") ~= nil end

test("locale: the TOC loads locales/enUS_Settings.lua", function()
    local found = false
    for _, rel in ipairs(localeFiles()) do if rel == "locales/enUS_Settings.lua" then found = true end end
    assertTrue(found, "the settings-only strings have their own file")
end)

test("locale: every enUS_Settings.lua key is read only under settings/", function()
    local reads, wrong = readers(), {}
    for _, key in ipairs(definedIn("locales/enUS_Settings.lua")) do
        for _, rel in ipairs(sorted(reads[key] or {})) do
            if not underSettings(rel) then wrong[#wrong + 1] = ("%s:%d %q"):format(rel, reads[key][rel], key) end
        end
    end
    assertEqual(#wrong, 0, "read outside settings/, so they belong in enUS.lua:\n" .. table.concat(wrong, "\n"))
end)

test("locale: every enUS.lua key has a reader outside settings/", function()
    local reads, wrong = readers(), {}
    for _, key in ipairs(definedIn("locales/enUS.lua")) do
        local outside = DYNAMIC_READS[key] ~= nil
        for rel in pairs(reads[key] or {}) do if not underSettings(rel) then outside = true end end
        if not outside then wrong[#wrong + 1] = ("%q"):format(key) end
    end
    assertEqual(#wrong, 0, "read only under settings/, so they belong in enUS_Settings.lua:\n" .. table.concat(wrong, "\n"))
end)

test("locale: [CA-M4-4] every enUS_AutoThank.lua key is read only from modules/AutoThank*", function()
    local found = false
    for _, rel in ipairs(localeFiles()) do if rel == "locales/enUS_AutoThank.lua" then found = true end end
    assertTrue(found, "the TOC loads locales/enUS_AutoThank.lua")
    local reads, wrong = readers(), {}
    for _, key in ipairs(definedIn("locales/enUS_AutoThank.lua")) do
        for _, rel in ipairs(sorted(reads[key] or {})) do
            if not rel:match("^modules/AutoThank[%w_]*%.lua$") then
                wrong[#wrong + 1] = ("%s:%d %q"):format(rel, reads[key][rel], key)
            end
        end
    end
    assertEqual(#wrong, 0, "read outside modules/AutoThank*, so they belong in another enUS file:\n" .. table.concat(wrong, "\n"))
end)
