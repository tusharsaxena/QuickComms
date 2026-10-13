local _, NS = ...
-- modules/Library.lua — THE registry writer (architecture-§5, spec §5, §12.2): membership (create,
-- delete, duplicate, Customize), the order of every list, the references a group and a surface
-- hold, the ids and the seeding. A member's own fields (a callout's text, a pad's layout) are
-- schema rows written through the seam (settings/SchemaMembers.lua); Library resolves the member
-- for the seam (Member) and announces the write (Touch).
-- Panel pages, slash verbs and (phase 5) import all call it. Built-ins are shipped data (NS.BuiltIns); the profile holds only their overlay.
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

--- Every member of a kind, in the order its editor page's picker lists them: user callouts and user
--- groups by name (case-insensitive, then id), the built-in sets after the user groups in shipped
--- order, the pads in the pad order. The seam's fallback when a page has selected nothing
--- (settings/Schema.lua Settings.EditingId), and the pages' picker order.
--- @param kind string "callout" | "group" | "pad"
--- @return string[]
function Lib.MemberIds(kind)
    if not (NS.db and NS.db.profile) then return {} end
    local p = P()
    local out = {}
    if kind == "pad" then
        for _, id in ipairs(p.padOrder) do
            if p.pads[id] then out[#out + 1] = id end
        end
        return out
    end
    local source = (kind == "callout" and p.callouts) or (kind == "group" and p.groups) or nil
    if not source then return out end
    local list = {}
    for id, m in pairs(source) do list[#list + 1] = { id = id, key = tostring(m.name or id):lower() } end
    table.sort(list, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.id < b.id
    end)
    for i, e in ipairs(list) do out[i] = e.id end
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

--- Whether `v` is a surface anchor: nil (the default place) or { point, relativePoint, x, y }, the
--- two points region anchor names and the offsets finite numbers.
function Lib.ValidPoint(v)
    if v == nil then return true end
    if type(v) ~= "table" or not ANCHORS[v[1]] or not ANCHORS[v[2]]
        or not finite(v[3]) or not finite(v[4]) then
        return false, "badPoint"
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

-- Any other When row: a set of ids or tokens, each mapped to true.
local function validSet(v)
    for key, on in pairs(v) do
        if on ~= true or (type(key) ~= "string" and type(key) ~= "number") then return false, "badWhen" end
    end
    return true
end

--- Whether `w` is a When (spec §5.3): rows the Resolver knows, each a set of ids or tokens mapped to
--- true, and keyLevel a { min, max } range whose lowest is not above its highest.
--- @return boolean ok, string|nil reason ("badWhen" | "badRange")
function Lib.ValidWhen(w)
    if type(w) ~= "table" then return false, "badWhen" end
    local known = {}
    for _, row in ipairs(NS.Resolver.ROWS) do known[row] = true end
    for row, v in pairs(w) do
        if not known[row] or type(v) ~= "table" then return false, "badWhen" end
        local ok, why
        if row == "keyLevel" then ok, why = validRange(v) else ok, why = validSet(v) end
        if not ok then return false, why end
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
    pad = { groupsAs = "sections", layout = { orientation = "horizontal", columns = 4, growth = "right",
        style = "iconLabel", scale = 1.0, spacing = 4, width = 140 },
        look = { visibility = "always", fade = "none", fadeAlpha = 0.4 } },
    dial = { mode = "categories", slices = 4, depth = 2, openAt = "center", delay = 0.3,
        interaction = "quick", key = nil, tapAction = "first" },
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
}

--- Create a pad or dial holding every built-in group (in BuiltIns.order).
function Lib.CreateSurface(kind, name)
    local p = P()
    local set = kind == "pad" and p.pads or kind == "dial" and p.dials
    if not set then return nil, "badKind" end
    local id = Lib.NewId(kind == "pad" and "p" or "d")
    local s = copyTable(SURFACE_DEFAULTS[kind])
    s.name, s.enabled, s.groups, s.seenBuiltins = name, true, {}, {}
    for _, gid in ipairs(NS.BuiltIns.order) do
        s.groups[#s.groups + 1] = gid
        s.seenBuiltins[gid] = true
    end
    set[id] = s
    local order = kind == "pad" and p.padOrder or p.dialOrder
    order[#order + 1] = id
    announce(kind, id)
    return id
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

--- Set, or with nil clear, a surface's saved anchor (spec §5.1). A pad's is the `pad.point` member
--- row, through the seam: the drag, the X/Y boxes and Reset position all write it there. A dial's has
--- no row until the dial's page (phase 4) and stays Library's write. A plain copy is stored, so the
--- caller's table never aliases the profile.
--- @param point table|nil { point, relativePoint, x, y }: two strings, then two numbers
--- @return boolean
function Lib.SetSurfacePoint(kind, sid, point)
    if kind == "pad" then return (NS.SchemaRuntime.Set("pad.point", point, sid)) == true end
    local s = kind == "dial" and surface(kind, sid)
    if not s or not Lib.ValidPoint(point) then return false end
    s.point = point and { point[1], point[2], point[3], point[4] } or nil
    announce(kind, sid)
    return true
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

--- Seed, append newly shipped built-ins once per surface, and drop dangling ids. Idempotent.
--- @return table { seeded, appended, repaired }
function Lib.Prepare()
    local p = P()
    local result = { seeded = false, appended = 0, repaired = 0 }
    normalize(p, result)
    liftNextId(p)
    if not p.seeded then
        if #p.padOrder == 0 then Lib.CreateSurface("pad", L["Comms Pad"]) end
        if #p.dialOrder == 0 then Lib.CreateSurface("dial", L["Comms Dial"]) end
        p.seeded = true
        result.seeded = true
    end
    for _, g in pairs(p.groups) do
        g.callouts = type(g.callouts) == "table" and g.callouts or {}
        for i = #g.callouts, 1, -1 do
            if not p.callouts[g.callouts[i]] then table.remove(g.callouts, i) result.repaired = result.repaired + 1 end
        end
    end
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do
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
    end
    for kind, set in pairs(surfaces()) do
        local order = kind == "pad" and p.padOrder or p.dialOrder
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
    if result.seeded or result.appended > 0 or result.repaired > 0 then
        NS.Debug(TAG, "prepare seeded=%s appended=%s repaired=%s", result.seeded, result.appended, result.repaired)
    end
    return result
end
