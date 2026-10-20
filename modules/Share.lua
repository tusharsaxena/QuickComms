local _, NS = ...
-- modules/Share.lua — export and import strings (design spec §15). The codec and the checks are
-- PURE: plain tables and strings in and out, no frame and no client read. The edge is at the end:
-- Collect and Export (the picked members and what they need, encoded and shown in the LibKa0s copy
-- window) and Apply (a checked string, through Library.Import), both refused in combat.
--
-- THE STRING. "!QC1!" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize
-- (payload))), payload = { v = 1, addon = "QuickComms", kind = "bundle", callouts, groups, pads?,
-- dials? }. Decode ignores whitespace (a pasted string may wrap or carry spaces) and refuses, with a
-- reason, a string that is not ours, is damaged or cut short, or is too large.
--
-- THE CHECKS (spec §15 steps 2 to 4). The version first: a newer one is refused, an older one is
-- lifted through MIGRATIONS (empty while v is 1). Then each member against the schema: its id's shape
-- (c<n>, g<n>, p<n>, d<n>), its channel kind, its lengths, its When, and every text field through the
-- §8.3 sanitizer (Bake.CleanText): callout text, icon paths, and every string in a pad's or a dial's
-- field values, nested ones and their keys too (cleanValue, which also refuses a number that is not
-- finite and a table nested past MAX_DEPTH, met twice in one value, or past MAX_NODES). Names and a
-- field's strings are drawn, never sent: each is stored with its "|" escapes literal (doubled, as a
-- typed "|" is), and a name may start with "/". A refused member is reported by its name, or by its
-- id only when that id is short plain text. Every string is refused
-- unread past TEXT_MAX bytes, and the payload past MAX_TEXT_BYTES read in all. Check fails closed: a hand-made payload that still raises inside the
-- checks reads as damaged. A member that fails is refused and listed with its reason; a reference
-- to something the string does not carry (a group's callout, a surface's group) is left out and
-- counted, and so is a callout no imported group holds (a callout travels inside its group). A
-- group's `parent` (nesting, one level) is kept only when it names another group the string carries
-- that has no parent of its own; any other is a dropped reference, and the group arrives top-level. A
-- surface's reference to a group the string nests is a dropped reference too. A pad
-- or a dial carries its name, Enabled, its groups and its portable fields, keyed by member-row path; never its key or its position (spec §15: it arrives unbound). Nothing in a string
-- is ever run (anti-pattern #20): a leading "/" is refused here, and Bake refuses one again at every
-- bake. The result is a plan that Library.Import, the registry writer, applies.

NS.Share = NS.Share or {}
local SH = NS.Share
local L = NS.L

local LD = LibStub and LibStub("LibDeflate", true)
local LS = LibStub and LibStub("LibSerialize", true)

SH.PREFIX = "!QC1!"
SH.VERSION = 1
SH.MAX_STRING = 50000    -- characters of a pasted string, before anything is decompressed
SH.MAX_RAW = 524288      -- bytes of the decompressed payload, before LibSerialize reads any of it
SH.MAX_MEMBERS = 500     -- callouts, groups, pads and dials in one string
SH.MAX_DEPTH = 8         -- nested tables in one field value (a When, a color); deeper is damaged
SH.MAX_NODES = 65536     -- values cleanValue may visit in one payload, every field and When together;
                         -- past it the string is tooLarge (a few shared tables would else copy F^depth)
SH.TEXT_MAX = 255        -- bytes of a callout's text and of an icon path: what Bake caps a whole
                         -- line at (the Text box counts characters; a text over 255 bytes never bakes);
                         -- also the most of any string in a payload, refused unread past it
SH.MAX_TEXT_BYTES = SH.MAX_RAW   -- string bytes the sanitizer may read in one payload; past it the
                                 -- string is tooLarge (one shared string would else be read per use)

-- Older payload versions, each lifted one step: MIGRATIONS[v](payload) answers the v + 1 payload.
local MIGRATIONS = {}

-- The payload's sections, in the order they are checked: a group's references need the callouts, a
-- surface's need the groups.
SH.KINDS = {
    { kind = "callout", key = "callouts", prefix = "c" },
    { kind = "group", key = "groups", prefix = "g" },
    { kind = "pad", key = "pads", prefix = "p" },
    { kind = "dial", key = "dials", prefix = "d" },
}

-- A field value as a plain copy with every string in it through the §8.3 sanitizer (an empty string
-- stays empty), or nil when it cannot be stored: a string the sanitizer refuses, a number that is not
-- finite (NaN, an infinity), a function or other non-data value, tables nested deeper than
-- MAX_DEPTH, or a table met a second time in the same value (`seen`: LibSerialize keeps shared
-- references, so a hand-made string can make a tiny DAG, or a cycle, that a walk would expand). Every
-- value visited counts against res.nodes; past SH.MAX_NODES every value is refused, and Validate
-- refuses the payload as tooLarge.
-- Whether a string may go through the sanitizer: at most SH.TEXT_MAX bytes, each one charged to
-- res.bytes, the payload's budget. LibSerialize keeps one copy of a repeated string, so a short share
-- string can name one long string thousands of times; this bounds what the sanitizer reads to
-- SH.MAX_TEXT_BYTES, and Validate refuses a payload past it as tooLarge.
local function affordable(v, res)
    if #v > SH.TEXT_MAX then return false end
    res.bytes = res.bytes + #v
    return res.bytes <= SH.MAX_TEXT_BYTES
end

-- Display text with every live "|" escape made literal: a lone "|" doubled to "||", a "||" (what the
-- game's edit box stores for a typed "|") kept, so it is never doubled again and the answer is
-- stable. For text that is only ever drawn (names, a field's strings), never sent: Bake escapes a
-- callout's text at every bake instead. Control characters are already flattened, so "\1" stands in.
local function literal(s)
    return (s:gsub("||", "\1"):gsub("|", "||"):gsub("\1", "||"))
end
SH.Literal = literal

-- A string, a number or a boolean as cleanValue keeps it, or nil. A field's strings are drawn,
-- never sent, so they are stored literal.
local function cleanScalar(v, t, res)
    if t == "string" then
        if not affordable(v, res) then return nil end
        local s, why = NS.Bake.CleanText(v)
        if s then return literal(s) end
        if why == "empty" then return "" end
        return nil
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        return v
    elseif t == "boolean" then
        return v
    end
    return nil
end

-- Whether a nested table's key may be stored as it is: a finite number, or a string within the byte
-- budget that the sanitizer leaves unchanged and that holds no "|". A key is matched, not shown, so
-- one the sanitizer would change is refused rather than rewritten.
local function cleanKey(k, res)
    if type(k) == "number" then return k == k and k ~= math.huge and k ~= -math.huge end
    if type(k) ~= "string" or not affordable(k, res) then return false end
    return NS.Bake.CleanText(k) == k and not k:find("|", 1, true)
end

local function cleanValue(v, depth, seen, res)
    res.nodes = res.nodes + 1
    if res.nodes > SH.MAX_NODES then return nil end
    local t = type(v)
    if t ~= "table" then return cleanScalar(v, t, res) end
    if depth > SH.MAX_DEPTH or seen[v] then return nil end
    seen[v] = true
    local out = {}
    for k, x in pairs(v) do
        if not cleanKey(k, res) then return nil end
        local c = cleanValue(x, depth + 1, seen, res)
        if c == nil then return nil end
        out[k] = c
    end
    return out
end

-- ── the codec ───────────────────────────────────────────────────────────────────────────────

--- A payload as a share string, or nil and "unavailable" without the two libraries.
--- @return string|nil, string|nil
function SH.Encode(payload)
    if not (LD and LS) then return nil, "unavailable" end
    return SH.PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(payload), { level = 9 }))
end

local function decodeBody(body)
    local packed = LD:DecodeForPrint(body)
    if not packed then return nil end
    local raw = LD:DecompressDeflate(packed)
    if not raw or #raw > SH.MAX_RAW then return nil end
    local ok, value = LS:Deserialize(raw)
    if ok then return value end
    return nil
end

--- A share string's payload, or nil and why ("empty" | "tooLarge" | "notOurs" | "damaged" |
--- "unavailable"). Whitespace anywhere in it is ignored.
--- @return table|nil, string|nil
function SH.Decode(text)
    if not (LD and LS) then return nil, "unavailable" end
    if type(text) ~= "string" then return nil, "empty" end
    local s = text:gsub("%s+", "")
    if s == "" then return nil, "empty" end
    if #s > SH.MAX_STRING then return nil, "tooLarge" end
    if s:sub(1, #SH.PREFIX) ~= SH.PREFIX then return nil, "notOurs" end
    local ok, payload = pcall(decodeBody, s:sub(#SH.PREFIX + 1))
    if not ok or type(payload) ~= "table" then return nil, "damaged" end
    return payload
end

-- ── the checks ──────────────────────────────────────────────────────────────────────────────

local function newResult()
    return { ok = false, callouts = {}, groups = {}, pads = {}, dials = {}, refused = {}, dropped = 0,
        loose = 0, ignored = 0, known = {}, nodes = 0, bytes = 0 }
end

-- A section's ids in a stable order: by the number they end in, then as text.
local function sortedIds(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local na = tonumber(tostring(a):match("(%d+)$")) or 0
        local nb = tonumber(tostring(b):match("(%d+)$")) or 0
        if na ~= nb then return na < nb end
        return tostring(a) < tostring(b)
    end)
    return ids
end

-- A text field through the §8.3 sanitizer. Empty is allowed (a callout may have no text yet).
local function cleanText(v, res)
    if v ~= nil and type(v) ~= "string" then return nil, "badText" end
    if v and not affordable(v, res) then return nil, "tooLong" end
    local s, why = NS.Bake.CleanText(v)
    if s then return s end
    if why == "empty" then return "" end
    return nil, why
end

-- A name as it is stored and drawn: one line (control characters flattened), whitespace squeezed
-- and trimmed, every "|" escape literal (literal). A name is never sent, so a leading "/" is a name
-- like any other (the editor takes one too); nil when nothing visible is left.
local function nameText(v)
    local s = v:gsub("%c", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if s == "" then return nil end
    return literal(s)
end

-- A name: nameText, then 1 to 32 characters (Library.ValidName).
local function cleanName(v, res)
    if v ~= nil and type(v) ~= "string" or v and not affordable(v, res) then return nil, "badName" end
    local s = v and nameText(v)
    if not (s and NS.Library.ValidName(s)) then return nil, "badName" end
    return s
end

-- An icon: none (false), a whole texture id, or a sanitized texture path with no escape character.
-- Answers the icon, and a reason only when it is refused.
local function cleanIcon(v, res)
    if v == nil or v == false then return false end
    if type(v) == "number" then
        if v > 0 and v < 2 ^ 31 and v == math.floor(v) then return v end   -- NaN and inf fail here
        return nil, "badIcon"
    end
    local s = type(v) == "string" and affordable(v, res) and NS.Bake.CleanText(v) or nil
    if not s or s:find("|", 1, true) then return nil, "badIcon" end
    return s
end

-- A glyph's color: six hex digits as Library stores them (Library.IconColorValue reads "#FF8000"), or
-- nil for none. A color that is not one is a bad field, not a bad member: it is dropped and counted
-- with the ignored fields, and the member arrives untinted. Library keeps a color only on a glyph.
local function cleanIconColor(v, res)
    if v == nil or v == false then return nil end
    if type(v) == "string" and #v <= 16 then
        local c = NS.Library.IconColorValue(v)
        if c == false then return nil end
        if NS.Library.ValidIconColor(c) then return c end
    end
    res.ignored = res.ignored + 1
    return nil
end

local function calloutEntry(_, id, c, res)
    if type(c) ~= "table" then return nil, "damaged" end
    local name, why = cleanName(c.name, res)
    if not name then return nil, why end
    local text
    text, why = cleanText(c.text, res)
    if not text then return nil, why end
    if not NS.Channels.IsKind(c.channel) then return nil, "badChannel" end
    local icon
    icon, why = cleanIcon(c.icon, res)
    if why then return nil, why end
    return { id = id, fields = { name = name, text = text, channel = c.channel, icon = icon,
        iconColor = cleanIconColor(c.iconColor, res) } }
end

-- The ids in `list` that `ok(id)` accepts, each once, in order; every other entry (one that is not a
-- string among them, a NaN included) is a dropped reference.
local function keepRefs(list, ok, res)
    local out, seen = {}, {}
    for _, ref in ipairs(type(list) == "table" and list or {}) do
        if type(ref) ~= "string" then
            res.dropped = res.dropped + 1
        elseif not seen[ref] then
            seen[ref] = true
            if ok(ref) then out[#out + 1] = ref else res.dropped = res.dropped + 1 end
        end
    end
    return out
end

local function groupEntry(_, id, g, res)
    if type(g) ~= "table" then return nil, "damaged" end
    local name, why = cleanName(g.name, res)
    if not name then return nil, why end
    local icon
    icon, why = cleanIcon(g.icon, res)
    if why then return nil, why end
    local when = cleanValue(g.when == nil and {} or g.when, 1, {}, res)
    if when == nil or not NS.Library.ValidWhen(when) then return nil, "badWhen" end
    local refs = keepRefs(g.callouts, function(cid) return res.known[cid] == "callout" end, res)
    -- `parent` as the string has it; checkParents keeps it or drops it once every group is read.
    return { id = id, callouts = refs, parent = g.parent, fields = { name = name, icon = icon,
        iconColor = cleanIconColor(g.iconColor, res), when = when, openInto = g.openInto == true,
        dialYield = g.dialYield == true, enabled = g.enabled ~= false, inheritWhen = g.inheritWhen ~= false } }
end

-- Each checked group's parent kept only when it names another checked group whose own parent, as the
-- string has it, is none (one level, so no chain and no cycle survives); any other is dropped and
-- counted with the dropped references, and the group arrives top-level.
local function checkParents(res)
    local stored = {}
    for _, e in ipairs(res.groups) do stored[e.id] = e.parent end
    for _, e in ipairs(res.groups) do
        local v = e.parent
        if v ~= nil and v ~= false then
            if not (type(v) == "string" and v ~= e.id and res.known[v] == "group" and not stored[v]) then
                res.dropped = res.dropped + 1
                v = nil
            end
        end
        e.parent = v or nil
    end
end

-- A pad's or dial's reference to a group the string nests (its checked parent is kept) is dropped and
-- counted: Library.Import puts that group inside its parent, and a surface never lists a child.
local function dropNested(res)
    local nested = {}
    for _, e in ipairs(res.groups) do
        if e.parent then nested[e.id] = true end
    end
    for _, list in ipairs({ res.pads, res.dials }) do
        for _, e in ipairs(list) do
            for i = #e.groups, 1, -1 do
                if nested[e.groups[i]] then
                    table.remove(e.groups, i)
                    res.dropped = res.dropped + 1
                end
            end
        end
    end
end

-- The member rows whose value travels with a pad or a dial: every one of its kind but its name and
-- Enabled (carried beside the fields) and its position. A dial's key is no field at all: it is WoW's
-- own binding (modules/Dial.lua BindKey), so it never travels (spec §15: it arrives unbound).
local NOT_PORTABLE = { point = true }

-- A field value an older string may carry that the row no longer offers, and what it means now:
-- the retired Upward growth (B2; core/Database.lua step 4 does the same for a stored profile).
local VALUE_ALIAS = { ["pad.layout.growth"] = { up = "rightUp" } }

--- Whether the member row at `path` travels in a share string with a `kind` ("pad" | "dial").
function SH.Portable(kind, path)
    local row = NS.SchemaRuntime and type(path) == "string" and NS.SchemaRuntime.FindRow(path)
    if not (row and row.instance == kind) or NOT_PORTABLE[row.type] then return false end
    return path ~= kind .. ".name" and path ~= kind .. ".enabled"
end

-- A surface's portable fields, every string in each value sanitized, nested ones included
-- (cleanValue); a field that does not travel, or whose value cannot be stored, is left out and
-- counted. The seam checks each value again, against its row, when Library.Import writes it.
local function surfaceFields(kind, fields, res)
    local out = {}
    for path, value in pairs(type(fields) == "table" and fields or {}) do
        local v = nil
        if SH.Portable(kind, path) then v = cleanValue(value, 1, {}, res) end
        local alias = VALUE_ALIAS[path]
        if alias and v ~= nil and alias[v] then v = alias[v] end
        if v ~= nil then out[path] = v else res.ignored = res.ignored + 1 end
    end
    return out
end

local function surfaceEntry(spec, id, s, res)
    if type(s) ~= "table" then return nil, "damaged" end
    local name, why = cleanName(s.name, res)
    if not name then return nil, why end
    local groups = keepRefs(s.groups, function(gid) return res.known[gid] == "group" end, res)
    return { id = id, name = name, enabled = s.enabled ~= false, groups = groups,
        fields = surfaceFields(spec.kind, s.fields, res) }
end

local ENTRY = { callout = calloutEntry, group = groupEntry, pad = surfaceEntry, dial = surfaceEntry }

-- A refused member's id as the report may show it: itself when it is short plain text (letters,
-- digits and dots, at most 32 bytes), else "(unnamed)". A malformed id is whatever a hand-made string
-- put there, a newline, a texture escape or 200 KB included.
local function idLabel(id)
    local s = tostring(id)
    if #s <= 32 and s:match("^[%w%.]+$") then return s end
    return L["(unnamed)"]
end

local function refuse(res, kind, id, entry, why)
    local raw = type(entry) == "table" and entry.name
    local name = type(raw) == "string" and affordable(raw, res) and nameText(raw) or nil
    local label = idLabel(id)
    res.refused[#res.refused + 1] = { kind = kind, id = label, name = name or label, reason = why }
end

local function checkSection(spec, set, res)
    for _, id in ipairs(sortedIds(set)) do
        local e, why
        if tostring(id):match("^" .. spec.prefix .. "%d+$") then
            e, why = ENTRY[spec.kind](spec, id, set[id], res)
        else
            why = "badId"
        end
        if e then
            local list = res[spec.key]
            list[#list + 1] = e
            res.known[id] = spec.kind
        else
            refuse(res, spec.kind, id, set[id], why)
        end
    end
end

-- Why a payload's header is refused, or nil: not ours, an unreadable version, or a newer one.
local function headerReason(payload)
    if type(payload) ~= "table" or payload.addon ~= "QuickComms" or payload.kind ~= "bundle" then
        return "notOurs"
    end
    local v = payload.v
    if type(v) ~= "number" or v < 1 or v ~= math.floor(v) then return "damaged" end
    if v > SH.VERSION then return "newer" end
    return nil
end

-- An older payload lifted to SH.VERSION, or nil when a step is missing or fails.
local function migrate(payload)
    local v = payload.v
    while v < SH.VERSION do
        local step = MIGRATIONS[v]
        if not step then return nil end
        payload = step(payload)
        if type(payload) ~= "table" then return nil end
        v = v + 1
    end
    return payload
end

-- Each callout no checked group holds, left out and counted: each user callout belongs to one group
-- (Library's rule), so a callout travels inside its group and a loose one has nowhere to go.
local function dropLoose(res)
    local held = {}
    for _, g in ipairs(res.groups) do
        for _, cid in ipairs(g.callouts) do held[cid] = true end
    end
    for i = #res.callouts, 1, -1 do
        if not held[res.callouts[i].id] then
            table.remove(res.callouts, i)
            res.loose = res.loose + 1
        end
    end
end

-- The members a payload holds, or nil when a section is not a table.
local function memberCount(payload)
    local n = 0
    for _, spec in ipairs(SH.KINDS) do
        local set = payload[spec.key]
        if set ~= nil and type(set) ~= "table" then return nil end
        for _ in pairs(set or {}) do n = n + 1 end
    end
    return n
end

--- Check a decoded payload (spec §15 steps 2 to 4). On success `ok` is true and the four lists hold
--- what Library.Import will make; `refused` lists { kind, id, name, reason } for each member left out,
--- `dropped` counts references to members the string does not carry, `loose` the callouts no group in
--- it holds, `ignored` the fields that do not travel. On a refusal of the whole string `ok` is false and `reason` says why.
--- @return table result
function SH.Validate(payload)
    local res = newResult()
    res.reason = headerReason(payload)
    if res.reason then return res end
    payload = migrate(payload)
    local n = payload and memberCount(payload)
    if not n then
        res.reason = "damaged"
        return res
    end
    if n > SH.MAX_MEMBERS then
        res.reason = "tooLarge"
        return res
    end
    for _, spec in ipairs(SH.KINDS) do checkSection(spec, payload[spec.key] or {}, res) end
    checkParents(res)
    dropNested(res)
    dropLoose(res)
    res.known = nil
    if res.nodes > SH.MAX_NODES or res.bytes > SH.MAX_TEXT_BYTES then
        local out = newResult()
        out.known = nil
        out.reason = "tooLarge"
        return out
    end
    res.nodes, res.bytes = nil, nil
    res.ok = true
    return res
end

--- Decode and check a pasted string: SH.Validate's result, or a refusal with Decode's reason. It
--- fails closed: a hand-made payload that still raises inside the checks is "damaged", never an error
--- in the player's Accept click.
function SH.Check(text)
    local payload, why = SH.Decode(text)
    if payload then
        local ok, res = pcall(SH.Validate, payload)
        if ok then return res end
        why = "damaged"
    end
    local res = newResult()
    res.known = nil
    res.reason = why
    return res
end

-- ── the report (spec §15 step 5) ────────────────────────────────────────────────────────────

-- Why a whole string, or an export, was refused.
SH.REASON_TEXT = {
    empty = L["Paste a Quick Comms string first."],
    notOurs = L["That is not a Quick Comms string: one starts with !QC1!."],
    damaged = L["That string is damaged or cut short. Copy all of it again."],
    newer = L["That string was made by a newer Quick Comms. Update the addon, then import it."],
    tooLarge = L["That string is too large to import."],
    unavailable = L["Sharing is unavailable: LibDeflate or LibSerialize did not load."],
    nothing = L["Tick at least one group, pad or dial to export."],
    inCombat = L["Export and import are not available in combat."],
}

-- Why one member was left out.
SH.MEMBER_REASON = {
    startsWithSlash = L["its text starts with /"],
    tooLong = L["its text is longer than 255 bytes"],
    badText = L["its text is not text"],
    badName = L["its name is not 1 to 32 characters"],
    badChannel = L["its channel is not one Quick Comms sends on"],
    badIcon = L["its icon is not a texture id or a texture path"],
    badWhen = L["its When holds a condition Quick Comms does not know"],
    badId = L["its id is malformed"],
    damaged = L["it is damaged"],
}

local KIND_NAME = { callout = L["callout"], group = L["group"], pad = L["Comms Pad"], dial = L["Comms Dial"] }

local COUNTS = {
    { key = "callouts", one = L["1 callout"], many = L["%d callouts"] },
    { key = "groups", one = L["1 group"], many = L["%d groups"] },
    { key = "pads", one = L["1 pad"], many = L["%d pads"] },
    { key = "dials", one = L["1 dial"], many = L["%d dials"] },
}

-- A count, a list (its entries) or a set (its keys).
local function countOf(v)
    if type(v) == "number" then return v end
    local n = 0
    for _ in pairs(type(v) == "table" and v or {}) do n = n + 1 end
    return n
end

--- "3 callouts, 1 group": the members in a result, a payload or Library.Import's tally; "" for none.
function SH.CountText(t)
    local parts = {}
    for _, c in ipairs(COUNTS) do
        local n = countOf(type(t) == "table" and t[c.key])
        if n == 1 then parts[#parts + 1] = c.one elseif n > 1 then parts[#parts + 1] = c.many:format(n) end
    end
    return table.concat(parts, ", ")
end

local function plural(n, one, many)
    if n == 1 then return one end
    return many:format(n)
end

--- The import report: what will arrive, each member refused with its reason, then the references and
--- the settings left out. A refused string is one line saying why.
--- @return string[]
function SH.ReportLines(res)
    if type(res) ~= "table" or not res.ok then
        return { SH.REASON_TEXT[type(res) == "table" and res.reason or "empty"] or tostring(res and res.reason) }
    end
    -- A callout two of the string's groups list arrives once per group (Library.Import), so the
    -- preview counts the groups' references to carried callouts, as the import's tally will.
    local carried, refs = {}, 0
    for _, e in ipairs(res.callouts) do carried[e.id] = true end
    for _, g in ipairs(res.groups) do
        for _, cid in ipairs(g.callouts or {}) do if carried[cid] then refs = refs + 1 end end
    end
    local counts = SH.CountText(setmetatable({ callouts = refs }, { __index = res }))
    local out = { counts ~= "" and L["Ready to import: %s."]:format(counts) or L["Nothing in this string can be imported."] }
    for _, r in ipairs(res.refused) do
        out[#out + 1] = L["Left out the %s '%s': %s."]:format(KIND_NAME[r.kind] or r.kind, literal(tostring(r.name)),
            SH.MEMBER_REASON[r.reason] or tostring(r.reason))
    end
    if res.dropped > 0 then
        out[#out + 1] = plural(res.dropped, L["1 reference to something the string does not carry was left out."],
            L["%d references to things the string does not carry were left out."])
    end
    if res.loose > 0 then
        out[#out + 1] = plural(res.loose, L["1 callout in no group was left out."],
            L["%d callouts in no group were left out."])
    end
    if res.ignored > 0 then
        out[#out + 1] = plural(res.ignored, L["1 setting this version cannot take was left out."],
            L["%d settings this version cannot take were left out."])
    end
    return out
end

-- ── the edge: export and apply ──────────────────────────────────────────────────────────────

local TAG = "Share"

-- A plain copy of a stored value for a payload. The profile's own data, so no check is needed here:
-- what comes back in a string is checked by cleanValue above.
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- The picked ids and what they need: a pad's or a dial's user groups, every picked group's children
-- (they show with it), then every picked group's callouts (spec §15: a group references its
-- callouts, a surface its groups). A child picked alone travels without its parent, and so arrives
-- top-level. A seeded group travels as any group does, without its origin. A callout is never picked on its own: it travels inside the group that owns it
-- (2026-10-17-callouts-owned-by-groups-design.md), so a `callout` pick is ignored.
local function bringGroups(want, surfaces, ids, groups)
    for sid in pairs(ids) do
        local s = surfaces[sid]
        for _, gid in ipairs(s and s.groups or {}) do
            if groups[gid] then want.group[gid] = true end
        end
    end
end

-- Every child of a wanted group is wanted too.
local function bringChildren(want, groups)
    for gid, g in pairs(groups) do
        if g.parent and want.group[g.parent] and NS.Library.IsChild(gid) then want.group[gid] = true end
    end
end

local function closure(pick, p)
    local want = { callout = {}, group = {}, pad = {}, dial = {} }
    for kind, ids in pairs(type(pick) == "table" and pick or {}) do
        if want[kind] and kind ~= "callout" then
            for id, on in pairs(ids) do want[kind][id] = on and true or nil end
        end
    end
    bringGroups(want, p.pads, want.pad, p.groups)
    bringGroups(want, p.dials, want.dial, p.groups)
    bringChildren(want, p.groups)
    for gid in pairs(want.group) do
        local g = p.groups[gid]
        for _, cid in ipairs(g and g.callouts or {}) do want.callout[cid] = true end
    end
    return want
end

--- A pad's or a dial's portable fields (SH.Portable), read through the seam: what its payload's
--- `fields` carries.
function SH.FieldsOf(kind, id)
    local out = {}
    for _, row in ipairs(NS.addon.Settings.Schema) do
        if row.instance == kind and SH.Portable(kind, row.path) then
            local v = NS.SchemaRuntime.Get(row.path, id)
            if v ~= nil then out[row.path] = copy(v) end
        end
    end
    return out
end

-- A member's payload entry. A child's `parent` travels only when the parent is picked too (`want`),
-- so a child picked alone arrives top-level with nothing dropped.
local function exportMember(kind, id, m, want)
    if kind == "callout" then
        return { name = m.name, text = m.text, channel = m.channel, icon = m.icon or nil, iconColor = m.iconColor or nil }
    end
    if kind == "group" then
        return { name = m.name, icon = m.icon or nil, iconColor = m.iconColor or nil, callouts = copy(m.callouts),
            when = copy(m.when), openInto = m.openInto == true, dialYield = m.dialYield == true,
            enabled = m.enabled ~= false,
            inheritWhen = m.inheritWhen ~= false,
            parent = NS.Library.IsChild(id) and want.group[m.parent] and m.parent or nil }
    end
    return { name = m.name, enabled = m.enabled ~= false, groups = copy(m.groups), fields = SH.FieldsOf(kind, id) }
end

--- The payload for the picked members ({ group = { [id] = true }, pad = …, dial = … }) and what they
--- need (a group's callouts), or nil when nothing is picked.
--- @return table|nil payload, number members
function SH.Collect(pick)
    local p = NS.db.profile
    local want = closure(pick, p)
    local payload, n = { v = SH.VERSION, addon = "QuickComms", kind = "bundle" }, 0
    for _, spec in ipairs(SH.KINDS) do
        local set, out = p[spec.key], {}
        for id in pairs(want[spec.kind]) do
            if set[id] then
                out[id] = exportMember(spec.kind, id, set[id], want)
                n = n + 1
            end
        end
        payload[spec.key] = out
    end
    if n == 0 then return nil, 0 end
    return payload, n
end

--- The export window: the LibKa0s copy window (core/WidgetsSetup.lua), built on first use; nil
--- without the library.
function SH.Window()
    SH.window = SH.window or NS.MakeCopyWindow({ name = "QuickCommsShareWindow", scrollName = "QuickCommsShareScroll",
        title = L["Quick Comms: share string"], width = 560, height = 300 })
    return SH.window
end

--- Make the string for the picked members and show it, selected, in the copy window (spec §15).
--- Refused in combat.
--- @return string|nil the string, string|nil why there is none
function SH.Export(pick)
    if NS.Compat.InCombat() then return nil, "inCombat" end
    local payload = SH.Collect(pick)
    if not payload then return nil, "nothing" end
    local text, why = SH.Encode(payload)
    if not text then return nil, why end
    NS.Debug(TAG, "export %s: %d characters", SH.CountText(payload), #text)
    local win = SH.Window()
    if win then win:Show(text) end
    return text
end

--- Import a checked result through Library.Import (spec §15 step 6). Refused in combat.
--- @return table|nil Library.Import's tally, string|nil why nothing was imported
function SH.Apply(res)
    if NS.Compat.InCombat() then return nil, "inCombat" end
    if type(res) ~= "table" or not res.ok then return nil, type(res) == "table" and res.reason or "empty" end
    return NS.Library.Import(res)
end
