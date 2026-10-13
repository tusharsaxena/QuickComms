local _, NS = ...
-- modules/Library.lua — THE registry writer (architecture-§5, spec §5, §12.2): membership (create,
-- delete, duplicate, Customize), the order of every list, the references a group and a surface
-- hold, the ids and the seeding. A member's own fields (a callout's text, a pad's layout) are
-- schema rows written through the seam (settings/SchemaMembers.lua); Library resolves the member
-- for the seam (Member) and announces the write (Touch).
-- Panel pages, slash verbs and the share import (Import, spec §15) all call it. Built-ins are shipped
-- data (NS.BuiltIns); the profile holds only their overlay.
-- Prepare runs after migrations on every profile load: it seeds, appends new built-ins once per
-- surface (seenBuiltins), and drops dangling ids.

NS.Library = NS.Library or {}
local Lib = NS.Library
local L = NS.L

local TAG = "Library"

local function P() return NS.db.profile end

-- While Lib.Batch runs, the kinds announced, to send once each when it ends; nil otherwise.
local batched

local function announce(kind, id, field)
    if batched then
        batched[kind] = true
        return
    end
    NS.Debug(TAG, "%s %s%s", kind, tostring(id), field and (" " .. field) or "")
    NS.addon:SendMessage(NS.MSG.LIBRARY_CHANGED, kind, id, field)
end

local function indexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return nil
end

local function removeAll(list, value)
    local n = 0
    for i = #list, 1, -1 do if list[i] == value then table.remove(list, i) n = n + 1 end end
    return n
end

local function copyTable(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copyTable(v) end
    return out
end

local function isBuiltin(id) return type(id) == "string" and id:sub(1, 3) == "bi." end

local function topOf(id)
    local def = NS.BuiltIns.groups[id]
    while def and def.parent do id = def.parent def = NS.BuiltIns.groups[id] end
    return def and id or nil
end

--- Whether an id names a shipped built-in (a dotted `bi.` id).
Lib.IsBuiltin = isBuiltin
--- A built-in id's top-level set (a node resolves to its battleground), or nil.
Lib.TopOf = topOf

--- A fresh user id: prefix .. n.
function Lib.NewId(prefix)
    local p = P()
    local n = p.nextId or 1
    p.nextId = n + 1
    return prefix .. n
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

local function overlay(id)
    local p = P()
    p.builtins[id] = p.builtins[id] or { enabled = true, hidden = {} }
    return p.builtins[id]
end

--- A callout by id (user or built-in); built-ins carry builtin = true. Read-only use.
function Lib.Callout(id)
    if isBuiltin(id) then
        local c = NS.BuiltIns.callouts[id]
        if not c then return nil end
        local out = copyTable(c)
        out.builtin = true
        return out
    end
    return P().callouts[id]
end

--- A group by id; built-ins are merged with their overlay (enabled, hidden callouts filtered out).
function Lib.Group(id)
    if not isBuiltin(id) then return P().groups[id] end
    local def = NS.BuiltIns.groups[id]
    if not def then return nil end
    local top = id
    while NS.BuiltIns.groups[top].parent do top = NS.BuiltIns.groups[top].parent end
    local o = P().builtins[top] or {}
    local hidden = o.hidden or {}
    local g = copyTable(def)
    g.builtin = true
    g.enabled = o.enabled ~= false
    g.callouts = {}
    for _, cid in ipairs(def.callouts or {}) do if not hidden[cid] then g.callouts[#g.callouts + 1] = cid end end
    return g
end

--- Every top-level group (user and built-in), merged, keyed by id: the Resolver's input.
function Lib.AllGroups()
    local all = {}
    for id, g in pairs(P().groups) do all[id] = g end
    for _, id in ipairs(NS.BuiltIns.order) do all[id] = Lib.Group(id) end
    return all
end

--- The user groups that reference a callout.
function Lib.UsedBy(calloutId)
    local out = {}
    for gid, g in pairs(P().groups) do
        if indexOf(g.callouts or {}, calloutId) then out[#out + 1] = gid end
    end
    table.sort(out)
    return out
end

--- The live member a member row addresses (settings/SchemaMembers.lua): a user callout, group, pad
--- or dial, or the overlay of a built-in set (a node's is its battleground's). A built-in group
--- answers its merged copy, so its fields read; the group rows refuse to write one. Nil without a
--- database, an id or such a member.
--- @param kind string "callout" | "group" | "pad" | "dial" | "builtin"
--- @return table|nil
function Lib.Member(kind, id)
    if id == nil or not (NS.db and NS.db.profile) then return nil end
    local p = P()
    if kind == "callout" then return p.callouts[id] end
    if kind == "group" then
        if isBuiltin(id) then return Lib.Group(id) end
        return p.groups[id]
    end
    if kind == "pad" then return p.pads[id] end
    if kind == "dial" then return p.dials[id] end
    if kind == "builtin" then
        local top = topOf(id)
        return top and overlay(top) or nil
    end
    return nil
end

--- A member row's reaction: the seam stored the field; Library, LIBRARY_CHANGED's one sender
--- (spec §17), announces it, naming the field (the row's path), so a listener can tell a field
--- write from a membership or order change (settings/Editors.lua repaints only for some fields).
function Lib.Touch(kind, id, field)
    announce(kind, id, field)
end

local function pack(...) return { n = select("#", ...), ... } end

--- Run `fn` with Library's announces held, then send ONE LIBRARY_CHANGED for the whole act, with no
--- id and no field (several members changed): a bulk act (Share's Defaults, Customize, New group, a
--- page's Defaults) rebuilds the pads and repaints the pages once, however many kinds it touched.
--- Its kind is the kinds touched, sorted and joined by commas ("builtin", "callout,group,pad").
--- Nothing is sent when nothing was. A nested call joins the outer batch. Answers what `fn` answers.
--- An error in `fn` is re-raised after the held announce is sent, so nothing that landed goes
--- unannounced.
function Lib.Batch(fn)
    if batched then return fn() end
    batched = {}
    local r = pack(pcall(fn))
    local kinds = {}
    for kind in pairs(batched) do kinds[#kinds + 1] = kind end
    batched = nil
    table.sort(kinds)
    if #kinds > 0 then announce(table.concat(kinds, ","), nil) end
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
end

-- A pad's or a dial's ids in the kind's display order (padOrder, dialOrder), skipping a stale entry.
local function surfaceIds(p, kind)
    local set = kind == "pad" and p.pads or p.dials
    local out = {}
    for _, id in ipairs(kind == "pad" and p.padOrder or p.dialOrder) do
        if set[id] then out[#out + 1] = id end
    end
    return out
end

-- A set's ids by name (case-insensitive), then by id.
local function idsByName(source)
    local list = {}
    for id, m in pairs(source) do list[#list + 1] = { id = id, key = tostring(m.name or id):lower() } end
    table.sort(list, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.id < b.id
    end)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.id end
    return out
end

local NAMED_SETS = { callout = "callouts", group = "groups" }

--- Every member of a kind, in the order its editor page's picker lists them: user callouts and user
--- groups by name (case-insensitive, then id), the built-in sets after the user groups in shipped
--- order, the pads in the pad order, the dials in the dial order. The seam's fallback when a page
--- has selected nothing (settings/Schema.lua Settings.EditingId), and the pages' picker order.
--- @param kind string "callout" | "group" | "pad" | "dial"
--- @return string[]
function Lib.MemberIds(kind)
    if not (NS.db and NS.db.profile) then return {} end
    local p = P()
    if kind == "pad" or kind == "dial" then return surfaceIds(p, kind) end
    local source = NAMED_SETS[kind] and p[NAMED_SETS[kind]]
    if not source then return {} end
    local out = idsByName(source)
    if kind == "group" then
        for _, id in ipairs(NS.BuiltIns.order) do out[#out + 1] = id end
    end
    return out
end

-- ── callouts ────────────────────────────────────────────────────────────────────────────────

Lib.NAME_MAX = 32   -- characters, not bytes: a translated built-in name may be multi-byte

-- UTF-8 characters in `s`: every byte that is not a continuation byte (0x80-0xBF) starts one.
local function chars(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

--- Whether `v` is a member name: a string with a visible character, at most NAME_MAX characters.
--- @return boolean ok, string|nil reason
function Lib.ValidName(v)
    if type(v) ~= "string" or not v:match("%S") or chars(v) > Lib.NAME_MAX then return false, "badName" end
    return true
end

--- Whether `v` is an icon: none (nil or false), a texture id, or a texture path.
function Lib.ValidIcon(v)
    if v == nil or v == false or type(v) == "number" then return true end
    if type(v) == "string" and v ~= "" then return true end
    return false, "badIcon"
end

-- The nine region anchor names SetPoint accepts.
local ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- A finite number: not NaN (which is not equal to itself) and not either infinity.
local function finite(x)
    return type(x) == "number" and x == x and math.abs(x) ~= math.huge
end

--- The largest offset a surface anchor takes while the screen's size is unknown (a headless load).
Lib.POINT_LIMIT = 4096

--- The smallest scale a surface is drawn at (the master scale times the surface's own, clamped).
Lib.MIN_SURFACE_SCALE = 0.3

--- Whether `v` is a surface anchor: nil or false (the default place) or { point, relativePoint, x,
--- y }, the two points region anchor names and the offsets finite numbers. The offsets are in the
--- surface's own scaled units, so the bound is the screen (UIParent's width for x, its height for
--- y) at the smallest scale a surface takes: every on-screen drag fits, and a typed offset still
--- cannot put a surface far beyond the screen.
--- @return boolean ok, string|nil reason ("badPoint" | "offScreen")
function Lib.ValidPoint(v)
    if v == nil or v == false then return true end
    if type(v) ~= "table" or not ANCHORS[v[1]] or not ANCHORS[v[2]]
        or not finite(v[3]) or not finite(v[4]) then
        return false, "badPoint"
    end
    local w, h = NS.Compat.ScreenSize()
    local k = 1 / Lib.MIN_SURFACE_SCALE
    if math.abs(v[3]) > (w or Lib.POINT_LIMIT) * k or math.abs(v[4]) > (h or Lib.POINT_LIMIT) * k then
        return false, "offScreen"
    end
    return true
end

-- A When's keyLevel: { min, max }, either end a number or absent, the lowest not above the highest.
local function validRange(v)
    local lo, hi = v.min, v.max
    if (lo ~= nil and type(lo) ~= "number") or (hi ~= nil and type(hi) ~= "number") then
        return false, "badWhen"
    end
    if lo and hi and lo > hi then return false, "badRange" end
    return true
end

local ID_ROWS = { instances = true, battleground = true, spec = true }

--- Whether `key` is a value the When row `row` can ever match (localization-§4: ids and tokens,
--- never a name): a token the row lists (NS.Resolver.TOKENS; the class row, NS.GameIds.CLASSES), a
--- positive whole id (instances, battlegrounds, specializations), or a Name-Realm (characters).
function Lib.ValidWhenValue(row, key)
    if ID_ROWS[row] then return type(key) == "number" and key > 0 and key == math.floor(key) end
    if row == "characters" then return type(key) == "string" and key:match("^[^%s%-]+%-%S+$") ~= nil end
    local list = row == "class" and NS.GameIds.CLASSES or NS.Resolver.TOKENS[row]
    for _, token in ipairs(list or {}) do
        if token == key then return true end
    end
    return false
end

-- Any other When row: a set of ids or tokens, each mapped to true, each one the row can match.
local function validSet(row, v)
    for key, on in pairs(v) do
        if on ~= true or (type(key) ~= "string" and type(key) ~= "number") then return false, "badWhen" end
        if not Lib.ValidWhenValue(row, key) then return false, "badValue", key end
    end
    return true
end

--- Whether `w` is a When (spec §5.3): rows the Resolver knows, each a set of values the row can
--- match (Lib.ValidWhenValue) mapped to true, and keyLevel a { min, max } range whose lowest is not
--- above its highest. A refused value answers its row and the value too.
--- @return boolean ok, string|nil reason ("badWhen" | "badRange" | "badValue"), string|nil row, any value
function Lib.ValidWhen(w)
    if type(w) ~= "table" then return false, "badWhen" end
    local known = {}
    for _, row in ipairs(NS.Resolver.ROWS) do known[row] = true end
    for row, v in pairs(w) do
        if not known[row] or type(v) ~= "table" then return false, "badWhen" end
        local ok, why, value
        if row == "keyLevel" then ok, why = validRange(v) else ok, why, value = validSet(row, v) end
        if not ok then return false, why, row, value end
    end
    return true
end

--- Whether `set` is a hidden-callout set for the top-level built-in `top` (spec §12.2): its own
--- callouts (a node's included) mapped to true.
function Lib.ValidHidden(top, set)
    if type(top) ~= "string" or type(set) ~= "table" then return false, "badHidden" end
    local prefix = top .. "."
    for cid, on in pairs(set) do
        if on ~= true or type(cid) ~= "string" or cid:sub(1, #prefix) ~= prefix or not NS.BuiltIns.callouts[cid] then
            return false, "badHidden"
        end
    end
    return true
end

local function validCallout(f)
    if type(f) ~= "table" then return false, "badCallout" end
    if not Lib.ValidName(f.name) then return false, "badName" end
    if type(f.text) ~= "string" then return false, "badText" end
    if not NS.Channels.IsKind(f.channel) then return false, "badChannel" end
    if not Lib.ValidIcon(f.icon) then return false, "badIcon" end
    return true
end

-- The first `n` UTF-8 characters of `s`.
local function firstChars(s, n)
    local out, count = {}, 0
    for ch in s:gmatch("[%z\1-\127\192-\253][\128-\191]*") do
        if count == n then break end
        count = count + 1
        out[count] = ch
    end
    return table.concat(out)
end

--- A copy's name: "<name> (copy)", or `<name>` plus `suffix`, the original shortened so the whole
--- stays within NAME_MAX (counted in characters).
function Lib.CopyName(name, suffix)
    suffix = suffix or L[" (copy)"]
    return firstChars(tostring(name or ""), Lib.NAME_MAX - chars(suffix)) .. suffix
end

--- Create a user callout.
--- @return string|nil id, string|nil reason
function Lib.CreateCallout(fields)
    local ok, why = validCallout(fields)
    if not ok then return nil, why end
    local id = Lib.NewId("c")
    P().callouts[id] = { name = fields.name, text = fields.text, channel = fields.channel, icon = fields.icon }
    announce("callout", id)
    return id
end

--- Delete a user callout and every reference to it.
function Lib.DeleteCallout(id)
    local p = P()
    if not p.callouts[id] then return false end
    p.callouts[id] = nil
    for _, g in pairs(p.groups) do removeAll(g.callouts, id) end
    announce("callout", id)
    return true
end

--- Copy a user callout under a "(copy)" name. The copy is in no group.
--- @return string|nil id, string|nil reason
function Lib.DuplicateCallout(id)
    local c = P().callouts[id]
    if not c then return nil, "noCallout" end
    return Lib.CreateCallout({ name = Lib.CopyName(c.name), text = c.text, channel = c.channel, icon = c.icon })
end

-- ── groups ──────────────────────────────────────────────────────────────────────────────────

--- Create a user group. `fields.callouts` (optional) are user callout ids, copied in order; an id
--- that is not a user callout is dropped.
--- @return string|nil id, string|nil reason
function Lib.CreateGroup(fields)
    if type(fields) ~= "table" or not Lib.ValidName(fields.name) then return nil, "badName" end
    if fields.when ~= nil and not Lib.ValidWhen(fields.when) then return nil, "badWhen" end
    local p = P()
    local callouts = {}
    for _, cid in ipairs(type(fields.callouts) == "table" and fields.callouts or {}) do
        if p.callouts[cid] then callouts[#callouts + 1] = cid end
    end
    local id = Lib.NewId("g")
    p.groups[id] = { name = fields.name, icon = fields.icon, callouts = callouts, when = copyTable(fields.when) or {},
        openInto = fields.openInto == true, enabled = fields.enabled ~= false }
    announce("group", id)
    return id
end

local function surfaces()
    local p = P()
    return { pad = p.pads, dial = p.dials }
end

-- The top-level built-in a user group is the customized copy of, or nil.
local function customizedFrom(gid)
    for top, o in pairs(P().builtins) do
        if type(o) == "table" and o.customizedAs == gid and NS.BuiltIns.groups[top] then return top end
    end
    return nil
end

--- Delete a user group and every surface reference to it. Deleting a built-in's customized copy
--- undoes the Customize (spec §12.2): the set goes back into the copy's place on every surface that
--- does not list it already, it is turned back on, and it forgets the copy. One act (Batch).
function Lib.DeleteGroup(id)
    local p = P()
    if not p.groups[id] then return false end
    Lib.Batch(function()
        local top = customizedFrom(id)
        p.groups[id] = nil
        for _, set in pairs(surfaces()) do
            for _, s in pairs(set) do
                local at = indexOf(s.groups, id)
                if top and at and not indexOf(s.groups, top) then
                    s.groups[at] = top
                    s.seenBuiltins[top] = true
                end
                removeAll(s.groups, id)
            end
        end
        if top then
            overlay(top).customizedAs = nil
            NS.SchemaRuntime.Set("builtin.enabled", true, top)
        end
        announce("group", id)
    end)
    return true
end

--- Copy a user group: the same callouts by reference (D8), a copy of its When. On no surface.
--- @return string|nil id, string|nil reason
function Lib.DuplicateGroup(id)
    local g = P().groups[id]
    if not g then return nil, "noGroup" end
    return Lib.CreateGroup({ name = Lib.CopyName(g.name), icon = g.icon, when = g.when, openInto = g.openInto,
        enabled = g.enabled, callouts = g.callouts })
end

local function addToGroup(g, groupId, calloutId, index)
    local id = calloutId
    if isBuiltin(calloutId) then
        local src = NS.BuiltIns.callouts[calloutId]
        if not src then return nil, "noCallout" end
        local why
        id, why = Lib.CreateCallout({ name = src.name, text = src.text, channel = src.channel, icon = src.icon })
        if not id then return nil, why end
    elseif not P().callouts[calloutId] then
        return nil, "noCallout"
    end
    index = math.max(1, math.min(index or (#g.callouts + 1), #g.callouts + 1))
    table.insert(g.callouts, index, id)
    announce("group", groupId)
    return id
end

--- Add a callout to a user group at `index` (end by default). A built-in callout is copied first (P2);
--- the copy and the insert are one act (Batch).
--- @return string|nil the callout id actually added, string|nil reason
function Lib.AddToGroup(groupId, calloutId, index)
    local g = P().groups[groupId]
    if not g then return nil, "noGroup" end
    if not isBuiltin(calloutId) then return addToGroup(g, groupId, calloutId, index) end
    return Lib.Batch(function() return addToGroup(g, groupId, calloutId, index) end)
end

function Lib.RemoveFromGroup(groupId, index)
    local g = P().groups[groupId]
    if not (g and g.callouts[index]) then return false end
    table.remove(g.callouts, index)
    announce("group", groupId)
    return true
end

function Lib.MoveInGroup(groupId, from, to)
    local g = P().groups[groupId]
    if not (g and g.callouts[from]) or type(to) ~= "number" then return false end
    to = math.max(1, math.min(to, #g.callouts))
    table.insert(g.callouts, to, table.remove(g.callouts, from))
    announce("group", groupId)
    return true
end

-- ── built-ins ───────────────────────────────────────────────────────────────────────────────

--- Turn a built-in set on or off: the `builtin.enabled` member row, through the seam.
function Lib.SetBuiltinEnabled(id, on)
    local top = topOf(id)
    if not top then return false end
    return (NS.SchemaRuntime.Set("builtin.enabled", on and true or false, top)) == true
end

--- Hide or show one of a built-in set's callouts: the whole `builtin.hidden` row, through the seam.
function Lib.SetBuiltinCalloutHidden(groupId, calloutId, hidden)
    local top = topOf(groupId)
    if not top then return false end
    local set = copyTable(overlay(top).hidden) or {}
    set[calloutId] = hidden and true or nil
    return (NS.SchemaRuntime.Set("builtin.hidden", set, top)) == true
end

--- Copy a top-level built-in into an editable user group, swap it into every surface at the same
--- place, and turn the built-in off (spec §12.2). Node children are flattened: v0.1.0 has no user
--- nesting, so a customized node battleground keeps every node's callouts in one list. A callout
--- whose copy fails validation is skipped, never inserted as a hole, and counted. One act (Batch):
--- the pads rebuild once. `placed` is the number of surfaces the copy took the set's place on (0 when
--- the set was on none).
--- @return string|nil id, string|nil reason, number skipped, number placed
function Lib.Customize(builtinId)
    local def = NS.BuiltIns.groups[builtinId]
    if not def or def.parent then return nil, "notTopLevel" end
    local prior = overlay(builtinId).customizedAs
    if prior and P().groups[prior] then return nil, "alreadyCustomized" end
    return Lib.Batch(function()
        -- The copy's name is shortened to fit, never refused (a translated set name may run long); a
        -- copy CreateGroup still refuses changes nothing: no surface loses the set, and the set stays on.
        local id, why = Lib.CreateGroup({ name = Lib.CopyName(def.name, " " .. L["(custom)"]), icon = def.icon,
            when = def.when, openInto = def.openInto == true })
        if not id then return nil, why end
        local skipped, placed = 0, 0
        local function copyFrom(gid)
            for _, cid in ipairs(Lib.Group(gid).callouts) do
                local added, reason = Lib.AddToGroup(id, cid)
                if not added then
                    skipped = skipped + 1
                    NS.Debug(TAG, "customize %s: skipped %s (%s)", builtinId, cid, tostring(reason))
                end
            end
            for _, child in ipairs(NS.BuiltIns.groups[gid].children or {}) do copyFrom(child) end
        end
        copyFrom(builtinId)
        for _, set in pairs(surfaces()) do
            for _, s in pairs(set) do
                local at = indexOf(s.groups, builtinId)
                if at then
                    s.groups[at] = id
                    placed = placed + 1
                end
            end
        end
        NS.SchemaRuntime.Set("builtin.enabled", false, builtinId)
        overlay(builtinId).customizedAs = id
        announce("builtin", builtinId)
        return id, nil, skipped, placed
    end)
end

-- ── surfaces ────────────────────────────────────────────────────────────────────────────────

local SURFACE_DEFAULTS = {
    -- look: the Look tab's rows (settings/SchemaMembers.lua). The font, border and background rows
    -- (phase 5, options-ui-§16/§17) default to the Ka0s skin a pad has always worn: the chip label's
    -- small white face with its shadow, a flat 1px black edge ("None" is no border art) and the
    -- 0.06, 0.06, 0.08, 0.92 body (spec §10.1).
    pad = { groupsAs = "sections", layout = { orientation = "horizontal", columns = 4, growth = "right",
        style = "iconLabel", scale = 1.0, spacing = 4, width = 140 },
        look = { visibility = "always", fade = "none", fadeAlpha = 0.4,
            font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
            useClassColorFont = false, fontFlags = "", fontShadow = true,
            borderStyle = "None", borderSize = 1, borderColor = { r = 0, g = 0, b = 0, a = 1 },
            useClassColorBorder = false,
            background = { r = 0.06, g = 0.06, b = 0.08, a = 0.92 }, useClassColorBackground = false } },
    -- Relaxed is the only interaction in v0.1.0 (the C7 fallback, round-4 record). `delay` and
    -- `tapAction` are kept for the hold, flick and release upgrade, and `depth` until owner ruling R5
    -- gives it a meaning; nothing reads them yet.
    dial = { mode = "categories", slices = 4, depth = 2, openAt = "center", delay = 0.3,
        interaction = "relaxed", key = nil, tapAction = "first" },
}

--- The shape of one member of each kind: what every member row's path resolves against (the
--- architecture-§5 boot check) and what a member row resets to. `icon` and `point` are false, not
--- nil, so the boot check can see the key: false is "none" and "the default place".
Lib.TEMPLATES = {
    callout = { name = "", text = "", channel = "smartGroup", icon = false },
    group = { name = "", icon = false, enabled = true, openInto = false, when = {} },
    pad = { name = "", enabled = true, groupsAs = SURFACE_DEFAULTS.pad.groupsAs, point = false,
        layout = copyTable(SURFACE_DEFAULTS.pad.layout), look = copyTable(SURFACE_DEFAULTS.pad.look) },
    builtin = { enabled = true, hidden = {} },
    -- `key` and `point` are false, not nil, for the same reason as above: false is "no key" and "the
    -- default place".
    dial = { name = "", enabled = true, mode = SURFACE_DEFAULTS.dial.mode, slices = SURFACE_DEFAULTS.dial.slices,
        openAt = SURFACE_DEFAULTS.dial.openAt, key = false, point = false },
}

--- A dial's place when its `point` is unset: the middle of the screen (read at run time by
--- modules/Dial.lua, the CLI and the Comms Dial page).
Lib.DIAL_DEFAULT_POINT = { "CENTER", "CENTER", 0, 0 }

-- A new pad or dial: its kind's defaults, `name` and a copy of `groups`, with every shipped built-in
-- marked seen (so Prepare never appends one the list leaves out), at the end of its kind's order.
local function newSurface(kind, name, groups)
    local p = P()
    local set = kind == "pad" and p.pads or p.dials
    local id = Lib.NewId(kind == "pad" and "p" or "d")
    local s = copyTable(SURFACE_DEFAULTS[kind])
    s.name, s.enabled, s.groups, s.seenBuiltins = name, true, copyTable(groups), {}
    for _, gid in ipairs(NS.BuiltIns.order) do s.seenBuiltins[gid] = true end
    set[id] = s
    local order = kind == "pad" and p.padOrder or p.dialOrder
    order[#order + 1] = id
    announce(kind, id)
    return id
end

--- Create a pad or dial holding every built-in group (in BuiltIns.order).
function Lib.CreateSurface(kind, name)
    if kind ~= "pad" and kind ~= "dial" then return nil, "badKind" end
    return newSurface(kind, name, NS.BuiltIns.order)
end

function Lib.DeleteSurface(kind, id)
    local p = P()
    local set = kind == "pad" and p.pads or kind == "dial" and p.dials
    if not (set and set[id]) then return false end
    set[id] = nil
    removeAll(kind == "pad" and p.padOrder or p.dialOrder, id)
    announce(kind, id)
    return true
end

local function surface(kind, sid)
    local s = surfaces()[kind]
    return s and s[sid]
end

function Lib.AddGroupToSurface(kind, sid, gid, index)
    local s = surface(kind, sid)
    local known = P().groups[gid] or (NS.BuiltIns.groups[gid] and not NS.BuiltIns.groups[gid].parent)
    if not s or not known or indexOf(s.groups, gid) then return false end
    index = math.max(1, math.min(index or (#s.groups + 1), #s.groups + 1))
    table.insert(s.groups, index, gid)
    if isBuiltin(gid) then s.seenBuiltins[gid] = true end
    announce(kind, sid)
    return true
end

function Lib.RemoveGroupFromSurface(kind, sid, gid)
    local s = surface(kind, sid)
    if not s or removeAll(s.groups, gid) == 0 then return false end
    announce(kind, sid)
    return true
end

--- Put a new user group at the top of every pad's and dial's list (the editors' New group): the
--- player's own groups come before the shipped sets. A surface that already lists it is skipped.
--- One act (Batch): one LIBRARY_CHANGED however many surfaces there are.
--- @return number surfaces it was added to
function Lib.OfferGroup(groupId)
    if not P().groups[groupId] then return 0 end
    return Lib.Batch(function()
        local n = 0
        for _, kind in ipairs({ "pad", "dial" }) do
            local ids = {}
            for sid in pairs(surfaces()[kind]) do ids[#ids + 1] = sid end
            table.sort(ids)
            for _, sid in ipairs(ids) do
                if Lib.AddGroupToSurface(kind, sid, groupId, 1) then n = n + 1 end
            end
        end
        return n
    end)
end

--- Move one of a surface's groups from position `from` to position `to` (clamped to the list).
function Lib.MoveGroupOnSurface(kind, sid, from, to)
    local s = surface(kind, sid)
    if not (s and s.groups[from]) or type(to) ~= "number" then return false end
    to = math.max(1, math.min(to, #s.groups))
    table.insert(s.groups, to, table.remove(s.groups, from))
    announce(kind, sid)
    return true
end

--- Set, or with nil clear, a surface's saved anchor (spec §5.1): the `pad.point` or `dial.point`
--- member row, through the seam (the seam stores a copy, so the caller's table never aliases the
--- profile). The pad's drag, the X/Y boxes and Reset position all write it here.
--- @param point table|nil { point, relativePoint, x, y }: two strings, then two numbers
--- @return boolean
function Lib.SetSurfacePoint(kind, sid, point)
    if kind ~= "pad" and kind ~= "dial" then return false end
    return (NS.SchemaRuntime.Set(kind .. ".point", point, sid)) == true
end

-- ── dial keys (spec §9.4, §18) ──────────────────────────────────────────────────────────────

-- Keys a dial may not take, because the open dial uses them. Whatever the modifiers: Escape (the game
-- menu, and the open dial's close), the left and right mouse buttons, and the mouse wheel (the open
-- dial turns its pages with it). Without a modifier: 1-8, which pick the open dial's wedges (ALT-1 is
-- another key, and free).
local RESERVED_KEYS = { ESCAPE = true, BUTTON1 = true, BUTTON2 = true, MOUSEWHEELUP = true, MOUSEWHEELDOWN = true }
local RESERVED_BARE = { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, ["6"] = true,
    ["7"] = true, ["8"] = true }

-- The modifiers a key may carry, in the order the client spells a chord (ALT-CTRL-SHIFT-META-X), and
-- the modifier keys themselves, which are no key on their own: the client never sends a bare SHIFT.
local MODIFIERS = { "ALT", "CTRL", "SHIFT", "META" }
local IS_MODIFIER = { ALT = true, CTRL = true, SHIFT = true, META = true }
local MODIFIER_KEYS = { ALT = true, CTRL = true, SHIFT = true, META = true, LALT = true, RALT = true,
    LCTRL = true, RCTRL = true, LSHIFT = true, RSHIFT = true, LMETA = true, RMETA = true }

-- An upper-cased key split into its modifiers (a set) and its base key, or nil when it is not one key:
-- an empty or dangling part ("SHIFT-", "-G"), an unknown or repeated modifier ("FOO-G",
-- "SHIFT-SHIFT-G"), or a modifier as the base ("SHIFT"). A trailing "--" is the minus key ("CTRL--").
local function splitKey(t)
    local base, rest
    if t == "-" then return {}, "-" end
    if t:sub(-2) == "--" then
        base, rest = "-", t:sub(1, -3)
    else
        base = t:match("([^%-]+)$")
        if not base or MODIFIER_KEYS[base] then return nil end
        if #base == #t then return {}, base end
        rest = t:sub(1, #t - #base - 1)
    end
    if rest == "" then return nil end
    local mods = {}
    for part in (rest .. "-"):gmatch("([^%-]*)%-") do
        if not IS_MODIFIER[part] or mods[part] then return nil end
        mods[part] = true
    end
    return mods, base
end

--- A key as stored: trimmed and upper-cased, its modifiers in the client's order (SHIFT-CTRL-G is
--- CTRL-SHIFT-G, so one chord is one stored key); nil, false, "" and "none" are no key (false). A
--- string that is not one key is kept as typed, for ValidKey to refuse.
--- @return string|false|any
function Lib.KeyValue(v)
    if v == nil or v == false then return false end
    if type(v) ~= "string" then return v end
    local t = v:match("^%s*(.-)%s*$"):upper()
    if t == "" or t == "NONE" then return false end
    local mods, base = splitKey(t)
    if not mods then return t end
    local parts = {}
    for _, m in ipairs(MODIFIERS) do
        if mods[m] then parts[#parts + 1] = m end
    end
    parts[#parts + 1] = base
    return table.concat(parts, "-")
end

--- Whether `v` is a key a dial may take: no key, or one key name with optional ALT-, CTRL-, SHIFT- or
--- META- modifiers, none twice (no space, at most 40 characters), not a modifier alone, not a reserved
--- key.
--- @return boolean ok, string|nil reason ("badKey" | "reservedKey")
function Lib.ValidKey(v)
    v = Lib.KeyValue(v)
    if v == false then return true end
    if type(v) ~= "string" or #v > 40 or v:find("%s") then return false, "badKey" end
    local mods, base = splitKey(v)
    if not mods then return false, "badKey" end
    if RESERVED_KEYS[base] or RESERVED_BARE[v] then return false, "reservedKey" end
    return true
end

--- The other dial that already has `key` (spec §18: one key opens one dial), or nil.
function Lib.KeyOwner(key, exceptId)
    key = Lib.KeyValue(key)
    if type(key) ~= "string" then return nil end
    local ids = {}
    for id, d in pairs(P().dials) do
        if id ~= exceptId and type(d) == "table" and d.key == key then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids[1]
end

-- ── migrations (core/Database.lua calls these; Library writes the lists) ────────────────────

--- Schema step 2 for one stored profile: on every pad and dial, the generic battleground set moves to
--- just below the last per-battleground set, so a node set can be the first active group and the dial
--- opens into it (D9). The shipped order changed the same way (defaults/BuiltIns_Battlegrounds.lua).
--- A raw SavedVariables profile: anything missing or malformed is skipped. Idempotent.
--- @return number the lists changed
function Lib.MoveGenericBattlegroundLast(profile)
    local n = 0
    for _, key in ipairs({ "pads", "dials" }) do
        local set = type(profile) == "table" and profile[key]
        for _, s in pairs(type(set) == "table" and set or {}) do
            local list = type(s) == "table" and s.groups
            if type(list) == "table" then
                local at, last
                for i, gid in ipairs(list) do
                    if gid == "bi.bg" then
                        at = i
                    elseif type(gid) == "string" and gid:find("^bi%.bg%.") then
                        last = i
                    end
                end
                if at and last and at < last then
                    table.remove(list, at)
                    table.insert(list, last, "bi.bg")
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- ── prepare ─────────────────────────────────────────────────────────────────────────────────

local function exists(gid) return P().groups[gid] ~= nil or (NS.BuiltIns.groups[gid] ~= nil and not NS.BuiltIns.groups[gid].parent) end

local REGISTRY = { "callouts", "groups", "builtins", "pads", "dials", "padOrder", "dialOrder" }

-- The registry's top-level keys as tables, and its entries as tables, before anything walks them.
local function normalize(p, result)
    for _, key in ipairs(REGISTRY) do
        if type(p[key]) ~= "table" then p[key] = {} result.repaired = result.repaired + 1 end
    end
    for _, key in ipairs({ "callouts", "groups", "builtins", "pads", "dials" }) do
        for id, v in pairs(p[key]) do
            if type(v) ~= "table" then p[key][id] = nil result.repaired = result.repaired + 1 end
        end
    end
end

-- nextId above the largest numeric suffix of any user id, so a stale counter never reuses one.
local function liftNextId(p)
    local high = 0
    for _, key in ipairs({ "callouts", "groups", "pads", "dials" }) do
        for id in pairs(p[key]) do
            local n = type(id) == "string" and tonumber(id:match("^[cgpd](%d+)$"))
            if n and n > high then high = n end
        end
    end
    if type(p.nextId) ~= "number" or p.nextId <= high then p.nextId = high + 1 end
end

-- A fresh profile's default pad and dial (D7), once.
local function seed(p, result)
    if p.seeded then return end
    if #p.padOrder == 0 then Lib.CreateSurface("pad", L["Comms Pad"]) end
    if #p.dialOrder == 0 then Lib.CreateSurface("dial", L["Comms Dial"]) end
    p.seeded = true
    result.seeded = true
end

-- Every user group's callout list as a table, its dangling ids dropped.
local function repairGroups(p, result)
    for _, g in pairs(p.groups) do
        g.callouts = type(g.callouts) == "table" and g.callouts or {}
        for i = #g.callouts, 1, -1 do
            if not p.callouts[g.callouts[i]] then table.remove(g.callouts, i) result.repaired = result.repaired + 1 end
        end
    end
end

-- A stored surface's settings tables (a pad's layout and look) with every field its kind's defaults
-- have that it lacks: a pad saved before a field existed (the Look tab's font, border and background,
-- phase 5) reads like a new one.
local function fillShape(s, kind)
    for key, defaults in pairs(SURFACE_DEFAULTS[kind]) do
        if type(defaults) == "table" then
            if type(s[key]) ~= "table" then s[key] = {} end
            for field, v in pairs(defaults) do
                if s[key][field] == nil then s[key][field] = copyTable(v) end
            end
        end
    end
end

-- One pad or dial: its lists as tables, its dangling groups dropped, each built-in it has not been
-- offered yet appended once (seenBuiltins), and its settings tables filled (fillShape).
local function repairSurface(s, kind, result)
    fillShape(s, kind)
    s.seenBuiltins = type(s.seenBuiltins) == "table" and s.seenBuiltins or {}
    s.groups = type(s.groups) == "table" and s.groups or {}
    for i = #s.groups, 1, -1 do
        if not exists(s.groups[i]) then table.remove(s.groups, i) result.repaired = result.repaired + 1 end
    end
    for _, gid in ipairs(NS.BuiltIns.order) do
        if not s.seenBuiltins[gid] then
            s.seenBuiltins[gid] = true
            if not indexOf(s.groups, gid) then
                s.groups[#s.groups + 1] = gid
                result.appended = result.appended + 1
            end
        end
    end
end

-- A kind's display order: entries naming no surface dropped, surfaces it misses appended by id.
local function repairOrder(order, set, result)
    for i = #order, 1, -1 do
        if not set[order[i]] then table.remove(order, i) result.repaired = result.repaired + 1 end
    end
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not indexOf(order, id) then order[#order + 1] = id result.repaired = result.repaired + 1 end
    end
end

--- Seed, append newly shipped built-ins once per surface, and drop dangling ids. Idempotent.
--- @return table { seeded, appended, repaired }
function Lib.Prepare()
    local p = P()
    local result = { seeded = false, appended = 0, repaired = 0 }
    normalize(p, result)
    liftNextId(p)
    seed(p, result)
    repairGroups(p, result)
    for kind, set in pairs(surfaces()) do
        for _, s in pairs(set) do repairSurface(s, kind, result) end
        repairOrder(kind == "pad" and p.padOrder or p.dialOrder, set, result)
    end
    if result.seeded or result.appended > 0 or result.repaired > 0 then
        NS.Debug(TAG, "prepare seeded=%s appended=%s repaired=%s", result.seeded, result.appended, result.repaired)
    end
    return result
end

-- ── import (spec §15, §18) ──────────────────────────────────────────────────────────────────

-- A surface's group list from a share result, pointing at the fresh copies: a built-in set stays
-- itself, an imported group becomes its new id, anything else (gone since the check) is left out.
local function remapGroups(list, map)
    local out = {}
    for _, gid in ipairs(list) do
        local id = isBuiltin(gid) and gid or map[gid]
        if id and exists(id) and not indexOf(out, id) then out[#out + 1] = id end
    end
    return out
end

-- One pad or dial: a new member with no key and no position, then each field that travels
-- (Share.Portable, checked again here, so no key or position is ever written) through the seam, which
-- refuses what it would refuse a player. A field left out either way is counted as ignored.
local function importSurface(kind, e, map, tally)
    local id = newSurface(kind, e.name, remapGroups(e.groups, map))
    local paths = {}
    for path in pairs(e.fields) do paths[#paths + 1] = path end
    table.sort(paths)
    for _, path in ipairs(paths) do
        local ok = NS.Share.Portable(kind, path) and NS.SchemaRuntime.Set(path, e.fields[path], id)
        if not ok then tally.ignored = tally.ignored + 1 end
    end
    if e.enabled == false then NS.SchemaRuntime.Set(kind .. ".enabled", false, id) end
    map[e.id] = id
    tally[kind .. "s"] = tally[kind .. "s"] + 1
end

local function importMembers(res, map, tally)
    for _, e in ipairs(res.callouts) do
        local id = Lib.CreateCallout(e.fields)
        if id then map[e.id], tally.callouts = id, tally.callouts + 1 end
    end
    for _, e in ipairs(res.groups) do
        local ids = {}
        for _, cid in ipairs(e.callouts) do ids[#ids + 1] = map[cid] end
        local f = e.fields
        local id = Lib.CreateGroup({ name = f.name, icon = f.icon, when = f.when, openInto = f.openInto,
            enabled = f.enabled, callouts = ids })
        if id then map[e.id], tally.groups = id, tally.groups + 1 end
    end
    for _, e in ipairs(res.pads) do importSurface("pad", e, map, tally) end
    for _, e in ipairs(res.dials) do importSurface("dial", e, map, tally) end
end

--- Apply a checked share result (modules/Share.lua Validate): every member under a fresh id (spec
--- §18: ids are always re-mapped, names may repeat), each group's callouts and each surface's groups
--- pointing at the new copies, built-in sets kept by id. A pad or a dial arrives unbound (spec §15): no
--- key, at the default place, at the end of its kind's order. One act: one LIBRARY_CHANGED, so the
--- surfaces rebuild once, and one `[Set] import share` line for every field it wrote.
--- @return table|nil tally { callouts, groups, pads, dials, ignored }, table|string map (old id ->
--- new id) or the reason nothing was imported
function Lib.Import(res)
    if type(res) ~= "table" or res.ok ~= true then return nil, "badImport" end
    local map, tally = {}, { callouts = 0, groups = 0, pads = 0, dials = 0, ignored = 0 }
    Lib.Batch(function()
        NS.SchemaRuntime.BulkRun("import", "share", function() importMembers(res, map, tally) end)
    end)
    NS.Debug(TAG, "import %s callouts, %s groups, %s pads, %s dials (%s fields ignored)", tally.callouts,
        tally.groups, tally.pads, tally.dials, tally.ignored)
    return tally, map
end
