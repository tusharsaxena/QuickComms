local _, NS = ...
-- modules/Share.lua — export and import strings (design spec §15). The codec and the checks are
-- PURE: plain tables and strings in and out, no frame and no client read; the edge (Export, Check,
-- Apply and the copy window) joins below them in Task 5 of the phase 5 plan.
--
-- THE STRING. "!QC1!" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize
-- (payload))), payload = { v = 1, addon = "QuickComms", kind = "bundle", callouts, groups, pads?,
-- dials? }. Decode ignores whitespace (a pasted string may wrap or carry spaces) and refuses, with a
-- reason, a string that is not ours, is damaged or cut short, or is too large.
--
-- THE CHECKS (spec §15 steps 2 to 4). The version first: a newer one is refused, an older one is
-- lifted through MIGRATIONS (empty while v is 1). Then each member against the schema: its id's shape
-- (c<n>, g<n>, p<n>, d<n>), its channel kind, its lengths, its When, and every text field through the
-- §8.3 sanitizer (Bake.CleanText): names, callout text, icon paths, and every string in a pad's or a
-- dial's field values, nested ones too (cleanValue, which also refuses a number that is not finite and
-- a table nested past MAX_DEPTH, met twice in one value, or past MAX_NODES). Every string is refused
-- unread past TEXT_MAX bytes, and the payload past MAX_TEXT_BYTES read in all. Check fails closed: a hand-made payload that still raises inside the
-- checks reads as damaged. A member that fails is refused and listed with its reason; a reference
-- to something the string does not carry (a group's callout, a surface's group) is left out and
-- counted. A pad or a dial carries its name, Enabled, its groups and its portable fields, keyed by
-- member-row path; never its key or its position (spec §15: it arrives unbound). Nothing in a string
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

-- A string, a number or a boolean as cleanValue keeps it, or nil.
local function cleanScalar(v, t, res)
    if t == "string" then
        if not affordable(v, res) then return nil end
        local s, why = NS.Bake.CleanText(v)
        if s then return s end
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

local function cleanValue(v, depth, seen, res)
    res.nodes = res.nodes + 1
    if res.nodes > SH.MAX_NODES then return nil end
    local t = type(v)
    if t ~= "table" then return cleanScalar(v, t, res) end
    if depth > SH.MAX_DEPTH or seen[v] then return nil end
    seen[v] = true
    local out = {}
    for k, x in pairs(v) do
        local c = cleanValue(x, depth + 1, seen, res)
        if c == nil or type(k) == "table" then return nil end
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
        ignored = 0, known = {}, nodes = 0, bytes = 0 }
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

-- A name: sanitized, then 1 to 32 characters (Library.ValidName).
local function cleanName(v, res)
    if v ~= nil and type(v) ~= "string" or v and not affordable(v, res) then return nil, "badName" end
    local s = NS.Bake.CleanText(v)
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
    return { id = id, fields = { name = name, text = text, channel = c.channel, icon = icon } }
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
    return { id = id, callouts = refs, fields = { name = name, icon = icon, when = when,
        openInto = g.openInto == true, enabled = g.enabled ~= false } }
end

-- The member rows whose value travels with a pad or a dial: every one of its kind but its name and
-- Enabled (carried beside the fields), its position and its key (spec §15: it arrives unbound).
local NOT_PORTABLE = { point = true, key = true }

--- Whether the member row at `path` travels in a share string with a `kind` ("pad" | "dial").
function SH.Portable(kind, path)
    local row = NS.SchemaRuntime and type(path) == "string" and NS.SchemaRuntime.FindRow(path)
    if not (row and row.instance == kind) or NOT_PORTABLE[row.type] then return false end
    return path ~= kind .. ".name" and path ~= kind .. ".enabled"
end

local function topBuiltin(gid)
    local def = NS.BuiltIns.groups[gid]
    return def ~= nil and def.parent == nil
end

-- A surface's portable fields, every string in each value sanitized, nested ones included
-- (cleanValue); a field that does not travel, or whose value cannot be stored, is left out and
-- counted. The seam checks each value again, against its row, when Library.Import writes it.
local function surfaceFields(kind, fields, res)
    local out = {}
    for path, value in pairs(type(fields) == "table" and fields or {}) do
        local v = nil
        if SH.Portable(kind, path) then v = cleanValue(value, 1, {}, res) end
        if v ~= nil then out[path] = v else res.ignored = res.ignored + 1 end
    end
    return out
end

local function surfaceEntry(spec, id, s, res)
    if type(s) ~= "table" then return nil, "damaged" end
    local name, why = cleanName(s.name, res)
    if not name then return nil, why end
    local groups = keepRefs(s.groups, function(gid) return res.known[gid] == "group" or topBuiltin(gid) end, res)
    return { id = id, name = name, enabled = s.enabled ~= false, groups = groups,
        fields = surfaceFields(spec.kind, s.fields, res) }
end

local ENTRY = { callout = calloutEntry, group = groupEntry, pad = surfaceEntry, dial = surfaceEntry }

local function refuse(res, kind, id, entry, why)
    local raw = type(entry) == "table" and entry.name
    local name = type(raw) == "string" and affordable(raw, res) and NS.Bake.CleanText(raw) or nil
    res.refused[#res.refused + 1] = { kind = kind, id = tostring(id), name = name or tostring(id), reason = why }
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
--- `dropped` counts references to members the string does not carry, `ignored` the fields that do not
--- travel. On a refusal of the whole string `ok` is false and `reason` says why.
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
    nothing = L["Tick at least one callout, group, pad or dial to export."],
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
    local counts = SH.CountText(res)
    local out = { counts ~= "" and L["Ready to import: %s."]:format(counts) or L["Nothing in this string can be imported."] }
    for _, r in ipairs(res.refused) do
        out[#out + 1] = L["Left out the %s '%s': %s."]:format(KIND_NAME[r.kind] or r.kind, r.name,
            SH.MEMBER_REASON[r.reason] or tostring(r.reason))
    end
    if res.dropped > 0 then
        out[#out + 1] = plural(res.dropped, L["1 reference to something the string does not carry was left out."],
            L["%d references to things the string does not carry were left out."])
    end
    if res.ignored > 0 then
        out[#out + 1] = plural(res.ignored, L["1 setting this version cannot take was left out."],
            L["%d settings this version cannot take were left out."])
    end
    return out
end
