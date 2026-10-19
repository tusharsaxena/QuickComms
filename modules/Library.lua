local _, NS = ...
-- modules/Library.lua — THE registry writer (architecture-§5, spec §5): membership (create, delete,
-- duplicate, restore), the order of every list, the references a group and a surface hold, the ids
-- and the seeding. A member's own fields (a callout's text, a pad's layout) are schema rows written
-- through the seam (settings/SchemaMembers.lua); Library resolves the member for the seam (Member)
-- and announces the write (Touch).
-- Panel pages, slash verbs and the share import (Import, spec §15) all call it.
-- SEEDING (2026-10-18-builtins-as-groups-design.md, goal 1): the shipped sets (NS.BuiltIns) are
-- seed data. Each profile is given them once as ordinary user groups and callouts under fresh ids,
-- a battleground's nodes as groups inside its set; each seeded member keeps the shipped id it came
-- from (`origin`), and a node its compass wind (`compass`). Neither is a tag or a lock: only Library
-- reads `origin` (what Restore puts back, and SeededBattleground for the dial's depth warning).
-- ONE OWNER (2026-10-17-callouts-owned-by-groups-design.md): each user callout id sits in exactly
-- one user group's list. Adding a callout to a group adds a copy, removing one deletes it, and a
-- deleted group takes its callouts with it.
-- NESTING (2026-10-18-builtins-as-groups-design.md, goal 2): a user group may sit inside one
-- top-level user group (its `parent`, the group.parent member row). One level only: a parent is
-- top-level, and a group holding groups takes no parent (ValidParent). A child is never placed on a
-- surface itself: it shows wherever its parent is (modules/Surfaces.lua), so taking a parent takes
-- it off every surface (SettleParent), and deleting a parent puts its children in its place.
-- A child takes its parent's When unless its inheritWhen is false (2026-10-18-when-drawers-design.md
-- §3; absent is on): modules/Resolver.lua's WhenOf.
-- Prepare runs after migrations on every profile load: it seeds (a shipped set the profile was never
-- given, once, at the end of every pad and dial), splits a callout two groups hold into copies,
-- drops dangling ids, drops callouts no group holds, and drops a parent that breaks the one-level
-- rule.

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

-- The number a user id ends in ("g12" -> 12), for the order the ids were made in.
local function idNumber(id) return tonumber(tostring(id):match("(%d+)$")) or 0 end

--- Whether `id` is a user group inside another (its parent is a user group).
function Lib.IsChild(id)
    local groups = NS.db and NS.db.profile and NS.db.profile.groups
    local g = groups and groups[id]
    return g ~= nil and type(g.parent) == "string" and groups[g.parent] ~= nil
end
local isChild = Lib.IsChild

--- The groups inside group `id`, in the order they show on a pad and a dial: the order they were
--- made in (their ids), so a seeded set keeps its shipped node order.
--- @return string[]
function Lib.Children(id)
    local out = {}
    for gid, g in pairs(P().groups) do
        if g.parent == id and gid ~= id then out[#out + 1] = gid end
    end
    table.sort(out, function(a, b)
        if idNumber(a) ~= idNumber(b) then return idNumber(a) < idNumber(b) end
        return a < b
    end)
    return out
end

-- A fresh user id in profile `p` (the live one, or a stored one a migration step converts).
local function takeId(p, prefix)
    local n = type(p.nextId) == "number" and p.nextId or 1
    p.nextId = n + 1
    return prefix .. n
end

--- A fresh user id: prefix .. n.
function Lib.NewId(prefix)
    return takeId(P(), prefix)
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

--- A user callout by id. Read-only use.
function Lib.Callout(id)
    return P().callouts[id]
end

--- A user group by id.
function Lib.Group(id)
    return P().groups[id]
end

--- Every user group, keyed by id: the Resolver's input.
function Lib.AllGroups()
    local all = {}
    for id, g in pairs(P().groups) do all[id] = g end
    return all
end

-- The id of the member of `set` (a profile's callouts or groups) seeded from shipped id `origin`,
-- the lowest when several are; nil when none is.
local function byOrigin(set, origin)
    local found
    for id, m in pairs(set) do
        if type(m) == "table" and m.origin == origin and (not found or tostring(id) < tostring(found)) then found = id end
    end
    return found
end

--- The battleground key ("ab") of user group `id` when it was seeded from a shipped battleground
--- set ("bi.bg.ab"), a node not included; nil for any other group (the dial's depth warning).
--- @return string|nil
function Lib.SeededBattleground(id)
    local g = P().groups[id]
    return g and type(g.origin) == "string" and g.origin:match("^bi%.bg%.([^.]+)$") or nil
end

-- Whether any user group's list holds `calloutId`.
local function held(calloutId)
    for _, g in pairs(P().groups) do
        if indexOf(g.callouts or {}, calloutId) then return true end
    end
    return false
end

--- The live member a member row addresses (settings/SchemaMembers.lua): a user callout, group, pad
--- or dial. Nil without a database, an id or such a member.
--- @param kind string "callout" | "group" | "pad" | "dial"
--- @return table|nil
function Lib.Member(kind, id)
    if id == nil or not (NS.db and NS.db.profile) then return nil end
    local p = P()
    if kind == "callout" then return p.callouts[id] end
    if kind == "group" then return p.groups[id] end
    if kind == "pad" then return p.pads[id] end
    if kind == "dial" then return p.dials[id] end
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
--- id and no field (several members changed): a bulk act (Restore, New group, an import, a page's
--- Defaults) rebuilds the pads and repaints the pages once, however many kinds it touched.
--- Its kind is the kinds touched, sorted and joined by commas ("group", "callout,group,pad").
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
--- groups by name (case-insensitive, then id), each group's children right after it (Children's
--- order), the pads in the pad order, the dials in the dial order. The seam's fallback when a page
--- has selected nothing (settings/Schema.lua Settings.EditingId; never for a callout, which a write
--- names by id), and the pages' picker order.
--- @param kind string "callout" | "group" | "pad" | "dial"
--- @return string[]
function Lib.MemberIds(kind)
    if not (NS.db and NS.db.profile) then return {} end
    local p = P()
    if kind == "pad" or kind == "dial" then return surfaceIds(p, kind) end
    local source = NAMED_SETS[kind] and p[NAMED_SETS[kind]]
    if not source then return {} end
    if kind ~= "group" then return idsByName(source) end
    local out = {}
    for _, id in ipairs(idsByName(source)) do
        if not isChild(id) then
            out[#out + 1] = id
            for _, child in ipairs(Lib.Children(id)) do out[#out + 1] = child end
        end
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

-- Each LibKa0s catalog icon's texture path mapped to its catalog name, built on the first ask (the
-- catalog is fixed for the session; NS.IconNames, library-stack-§8). Empty without the library.
local glyphNames

--- The LibKa0s catalog name of icon `v` when it is one of the catalog's glyphs (white on transparent,
--- so it takes a tint), else nil: a game icon, a raid marker or any other texture.
--- @return string|nil
function Lib.IsGlyph(v)
    if type(v) ~= "string" then return nil end
    if not glyphNames then
        glyphNames = {}
        for _, name in ipairs(NS.IconNames()) do
            local path = NS.Icon(name)
            if path then glyphNames[path] = name end
        end
    end
    return glyphNames[v]
end

--- A glyph's color as stored: six lowercase hex digits ("rrggbb"), from text that may carry spaces,
--- a leading "#" or capitals. Nil, false and empty text are no color (false). Anything else is kept
--- as given, for ValidIconColor to refuse.
function Lib.IconColorValue(v)
    if v == nil or v == false then return false end
    if type(v) ~= "string" then return v end
    local t = v:match("^%s*#?(.-)%s*$"):lower()
    if t == "" then return false end
    return t
end

--- Whether `v` is a stored glyph color: none (nil or false) or six lowercase hex digits.
--- @return boolean ok, string|nil reason
function Lib.ValidIconColor(v)
    if v == nil or v == false then return true end
    if type(v) == "string" and v:match("^%x%x%x%x%x%x$") and v == v:lower() then return true end
    return false, "badIconColor"
end

--- The tint icon `icon` is drawn with, as r, g, b (0..1): its glyph color, or white (1, 1, 1) for
--- none, a malformed color or an icon that is no glyph. Every place a member's icon is drawn sets
--- this, white included, since a pooled texture keeps the last tint it was given.
--- @return number r, number g, number b
function Lib.IconTint(icon, color)
    if type(color) ~= "string" or not Lib.ValidIconColor(color) or not Lib.IsGlyph(icon) then return 1, 1, 1 end
    return tonumber(color:sub(1, 2), 16) / 255, tonumber(color:sub(3, 4), 16) / 255, tonumber(color:sub(5, 6), 16) / 255
end

--- The stored glyph color for a picked r, g, b (0..1, as the color picker answers): six lowercase
--- hex digits, or false (none) for white, which is how an untinted glyph is drawn. A channel out of
--- range is clamped.
--- @return string|false
function Lib.IconColorFrom(r, g, b)
    local function byte(v)
        v = tonumber(v) or 1
        return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5)
    end
    local hex = ("%02x%02x%02x"):format(byte(r), byte(g), byte(b))
    if hex == "ffffff" then return false end
    return hex
end

-- The color a member made with `icon` and `color` keeps: the color only when the icon is a glyph,
-- else none (a malformed color is refused before this).
local function glyphColor(icon, color)
    if color and Lib.IsGlyph(icon) then return color end
    return nil
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

Lib.CHARACTER_MAX = 96   -- bytes of a Name-Realm: a 12-character name and a long realm, both multi-byte

--- Whether `key` is a value the When row `row` can ever match (localization-§4: ids and tokens,
--- never a name): a token the row lists (NS.Resolver.TOKENS; the class row, NS.GameIds.CLASSES), a
--- positive whole id (instances, battlegrounds, arenas, specializations), the whole kind on a place
--- row (NS.Resolver.ID_ROWS, NS.Resolver.ALL), or a Name-Realm (characters: no control or "|"
--- character, at most CHARACTER_MAX bytes).
function Lib.ValidWhenValue(row, key)
    local place = NS.Resolver.ID_ROWS[row]
    if key == NS.Resolver.ALL and place then return true end
    if place or row == "spec" then return type(key) == "number" and key > 0 and key == math.floor(key) end
    if row == "characters" then
        return type(key) == "string" and #key <= Lib.CHARACTER_MAX and not key:find("[%c|]")
            and key:match("^[^%s%-]+%-%S+$") ~= nil
    end
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

--- Whether user group `id` may sit inside `parent` (nesting, one level): none (nil or false), or
--- another top-level user group, while `id` holds no groups of its own. `id` may be nil (a group not
--- made yet holds none).
--- @return boolean ok, string|nil reason ("badParent" | "selfParent" | "parentIsChild" | "hasChildren")
function Lib.ValidParent(parent, id)
    if parent == nil or parent == false then return true end
    local groups = P().groups
    if type(parent) ~= "string" or not groups[parent] then return false, "badParent" end
    if parent == id then return false, "selfParent" end
    if isChild(parent) then return false, "parentIsChild" end
    if id ~= nil and #Lib.Children(id) > 0 then return false, "hasChildren" end
    return true
end

local function validCallout(f)
    if type(f) ~= "table" then return false, "badCallout" end
    if not Lib.ValidName(f.name) then return false, "badName" end
    if type(f.text) ~= "string" then return false, "badText" end
    if not NS.Channels.IsKind(f.channel) then return false, "badChannel" end
    if not Lib.ValidIcon(f.icon) then return false, "badIcon" end
    if not Lib.ValidIconColor(f.iconColor) then return false, "badIconColor" end
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
Lib.FirstChars = firstChars

--- A copy's name: "<name> (copy)", or `<name>` plus `suffix`, the original shortened so the whole
--- stays within NAME_MAX (counted in characters).
function Lib.CopyName(name, suffix)
    suffix = suffix or L[" (copy)"]
    return firstChars(tostring(name or ""), Lib.NAME_MAX - chars(suffix)) .. suffix
end

--- Create a user callout. Its `iconColor` is kept only when its icon is a glyph.
--- @return string|nil id, string|nil reason
function Lib.CreateCallout(fields)
    local ok, why = validCallout(fields)
    if not ok then return nil, why end
    local id = Lib.NewId("c")
    P().callouts[id] = { name = fields.name, text = fields.text, channel = fields.channel, icon = fields.icon,
        iconColor = glyphColor(fields.icon, fields.iconColor) }
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

-- ── groups ──────────────────────────────────────────────────────────────────────────────────

-- A new user callout with `src`'s fields (its icon's color too) and its name unchanged (the copy
-- lives in another group, or the player renames it), checked as any new callout is.
local function copyCallout(src)
    return Lib.CreateCallout({ name = src.name, text = src.text, channel = src.channel, icon = src.icon,
        iconColor = src.iconColor })
end

-- Whether a new group's fields pass: its name, When, glyph color and parent.
local function validGroup(fields)
    if type(fields) ~= "table" or not Lib.ValidName(fields.name) then return false, "badName" end
    if fields.when ~= nil and not Lib.ValidWhen(fields.when) then return false, "badWhen" end
    if not Lib.ValidIconColor(fields.iconColor) then return false, "badIconColor" end
    return Lib.ValidParent(fields.parent)
end

--- Create a user group, its `iconColor` kept only when its icon is a glyph. `fields.callouts`
--- (optional) are user callout ids, in order; an id that is not a user callout is dropped. One owner:
--- a callout no group holds is taken as it is, and one a group holds (or that the list repeats) is
--- copied, the copies and the group made as one act (Batch). `fields.parent` (optional) puts it
--- inside a top-level group (ValidParent); a new group is on no surface either way. It inherits its
--- parent's When (inheritWhen, Resolver.WhenOf) unless `fields.inheritWhen` is false.
--- @return string|nil id, string|nil reason
function Lib.CreateGroup(fields)
    local ok, why = validGroup(fields)
    if not ok then return nil, why end
    local p = P()
    local wanted, take, copies = {}, {}, false
    for _, cid in ipairs(type(fields.callouts) == "table" and fields.callouts or {}) do
        if p.callouts[cid] then
            local n = #wanted + 1
            wanted[n] = cid
            take[n] = not (held(cid) or indexOf(wanted, cid) < n)
            copies = copies or not take[n]
        end
    end
    local function make()
        local callouts = {}
        for n, cid in ipairs(wanted) do
            local id = take[n] and cid or copyCallout(p.callouts[cid])
            if id then callouts[#callouts + 1] = id end
        end
        local id = Lib.NewId("g")
        p.groups[id] = { name = fields.name, icon = fields.icon, iconColor = glyphColor(fields.icon, fields.iconColor),
            callouts = callouts, when = copyTable(fields.when) or {}, openInto = fields.openInto == true,
            enabled = fields.enabled ~= false, parent = fields.parent or nil, inheritWhen = fields.inheritWhen ~= false }
        announce("group", id)
        return id
    end
    if copies then return Lib.Batch(make) end
    return make()
end

local function surfaces()
    local p = P()
    return { pad = p.pads, dial = p.dials }
end

-- One surface's list as group `id` leaves it: its children (`kids`) in its place, each the list does
-- not hold already; then `id` taken out.
local function vacate(s, id, kids)
    local at = indexOf(s.groups, id)
    if at then
        for i = #kids, 1, -1 do
            if not indexOf(s.groups, kids[i]) then table.insert(s.groups, at + 1, kids[i]) end
        end
    end
    removeAll(s.groups, id)
end

--- Delete a user group, its callouts (nothing else holds them) and every surface reference to it.
--- A seeded group is deleted as any other is (Restore puts it back). Deleting a parent keeps its
--- children: each becomes a top-level group (its group.parent row cleared through the seam) in the
--- parent's place on every surface the parent was on, in Children's order. One act (Batch).
function Lib.DeleteGroup(id)
    local p = P()
    if not p.groups[id] then return false end
    Lib.Batch(function()
        local kids = Lib.Children(id)
        for _, kid in ipairs(kids) do NS.SchemaRuntime.Set("group.parent", false, kid) end
        local callouts = p.groups[id].callouts or {}
        p.groups[id] = nil
        for _, cid in ipairs(callouts) do
            if p.callouts[cid] and not held(cid) then
                p.callouts[cid] = nil
                announce("callout", cid)
            end
        end
        for _, set in pairs(surfaces()) do
            for _, s in pairs(set) do vacate(s, id, kids) end
        end
        announce("group", id)
    end)
    return true
end

--- Copy a user group: fresh copies of its callouts (one owner; CreateGroup copies a held callout),
--- a copy of its When, and its parent: a child's copy sits beside it in the same parent. A parent's
--- copy holds no groups (its children are not copied). On no surface.
--- @return string|nil id, string|nil reason
function Lib.DuplicateGroup(id)
    local g = P().groups[id]
    if not g then return nil, "noGroup" end
    return Lib.CreateGroup({ name = Lib.CopyName(g.name), icon = g.icon, iconColor = g.iconColor, when = g.when,
        openInto = g.openInto, enabled = g.enabled, callouts = g.callouts, parent = isChild(id) and g.parent or nil,
        inheritWhen = g.inheritWhen })
end

--- The group.parent row's reaction (settings/SchemaMembers.lua): a group that now sits inside another
--- leaves every surface, as one act with the announce (Batch). A top-level group stays where it is.
--- @return number the surfaces it left
function Lib.SettleParent(id)
    if not isChild(id) then return 0 end
    local n = 0
    for kind, set in pairs(surfaces()) do
        for sid, s in pairs(set) do
            if removeAll(s.groups, id) > 0 then
                n = n + 1
                announce(kind, sid)
            end
        end
    end
    return n
end

-- Put callout `id` into group `g` at `index`, clamped (end by default).
local function insertAt(g, groupId, id, index)
    index = math.max(1, math.min(index or (#g.callouts + 1), #g.callouts + 1))
    table.insert(g.callouts, index, id)
    announce("group", groupId)
    return id
end

local function addToGroup(g, groupId, calloutId, index)
    local src = P().callouts[calloutId]
    if not src then return nil, "noCallout" end
    local id, why = copyCallout(src)
    if not id then return nil, why end
    return insertAt(g, groupId, id, index)
end

--- Add a callout to a user group at `index` (end by default). It is always a copy (P2; one owner:
--- the source stays in its own group), under the same name; a seeded callout's copy keeps no
--- origin. The copy and the insert are one act (Batch).
--- @return string|nil the callout id actually added, string|nil reason
function Lib.AddToGroup(groupId, calloutId, index)
    local g = P().groups[groupId]
    if not g then return nil, "noGroup" end
    return Lib.Batch(function() return addToGroup(g, groupId, calloutId, index) end)
end

--- Create a user callout straight into a user group at `index` (end by default): the create and the
--- insert are one act (Batch). A refusal (no such user group, a field that fails) makes nothing and
--- consumes no id.
--- @return string|nil id, string|nil reason
function Lib.CreateCalloutIn(groupId, fields, index)
    local g = P().groups[groupId]
    if not g then return nil, "noGroup" end
    local ok, why = validCallout(fields)
    if not ok then return nil, why end
    return Lib.Batch(function() return insertAt(g, groupId, Lib.CreateCallout(fields), index) end)
end

--- Take the callout at `index` out of a user group and delete it: nothing else holds it (one owner).
--- One act (Batch).
function Lib.RemoveFromGroup(groupId, index)
    local p = P()
    local g = p.groups[groupId]
    if not (g and g.callouts[index]) then return false end
    Lib.Batch(function()
        local cid = table.remove(g.callouts, index)
        announce("group", groupId)
        if p.callouts[cid] and not held(cid) then
            p.callouts[cid] = nil
            announce("callout", cid)
        end
    end)
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

-- ── icons ───────────────────────────────────────────────────────────────────────────────────

--- Set a user callout's or a user group's icon and its glyph color as ONE act (Batch): the
--- `<kind>.icon` member row, then `<kind>.iconColor`, both through the seam. A color stays only on a
--- glyph: with any other icon the color is cleared. A malformed color is refused before anything is
--- written. A texture id may be given as a number (the Icon row takes text).
--- @param kind string "callout" | "group"
--- @param icon string|number|false
--- @param color string|false|nil "rrggbb", or none
--- @return boolean ok, string|nil why (the seam's line, or a reason code)
function Lib.SetIcon(kind, id, icon, color)
    if kind ~= "callout" and kind ~= "group" then return false, "badKind" end
    if id == nil then return false, "noMember" end
    color = Lib.IconColorValue(color)
    if not Lib.ValidIconColor(color) then return false, "badIconColor" end
    if type(icon) == "number" then icon = tostring(icon) end
    local S = NS.SchemaRuntime
    return Lib.Batch(function()
        local ok, err, why = S.Set(kind .. ".icon", icon, id)
        if not ok then return false, why or err end
        ok, err, why = S.Set(kind .. ".iconColor", glyphColor(Lib.Member(kind, id).icon, color) or false, id)
        if not ok then return false, why or err end
        return true
    end)
end

-- ── seeding (2026-10-18-builtins-as-groups-design.md, goal 1) ──────────────────────────────
--
-- Raw writes to a profile `p`: the live one (Prepare, Restore) or a stored one migration step 3
-- converts (SeedFromOverlay). Shipped data is trusted, so nothing here is checked, and nothing here
-- announces: its callers do.

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

-- A user callout copied from shipped callout `cid`, which it keeps as its origin.
local function seedCallout(p, cid)
    local c = NS.BuiltIns.callouts[cid]
    local id = takeId(p, "c")
    p.callouts[id] = { name = c.name, text = c.text, channel = c.channel, icon = c.icon, iconColor = c.iconColor,
        origin = cid }
    return id
end

-- A user group copied from shipped group `gid` (a set, or a node inside `parent`, its set's group),
-- with copies of its callouts but the ones `hidden` names; `gid` is marked seeded (seededSets). Its
-- callouts take their ids before it, and a set's nodes after it, so Children keeps the shipped order.
local function seedGroup(p, gid, parent, hidden)
    local def = NS.BuiltIns.groups[gid]
    local callouts = {}
    for _, cid in ipairs(def.callouts or {}) do
        if not (hidden and hidden[cid]) then callouts[#callouts + 1] = seedCallout(p, cid) end
    end
    local id = takeId(p, "g")
    p.groups[id] = { name = def.name, icon = def.icon, callouts = callouts, when = copyTable(def.when) or {},
        openInto = def.openInto == true, enabled = true, parent = parent, inheritWhen = true, compass = def.compass,
        origin = gid }
    p.seededSets[gid] = true
    return id
end

-- A shipped set and each of its nodes, as a top-level group with its nodes inside it.
local function seedSet(p, top, hidden)
    local id = seedGroup(p, top, nil, hidden)
    for _, child in ipairs(NS.BuiltIns.groups[top].children or {}) do seedGroup(p, child, id, hidden) end
    return id
end

-- `ids`, in order, at the end of every pad's and dial's list that does not hold them; `notify`
-- announces each surface that changed. Answers the lists changed.
local function placeEverywhere(p, ids, notify)
    local n = 0
    for _, kind in ipairs({ "pad", "dial" }) do
        for sid, s in pairs(kind == "pad" and p.pads or p.dials) do
            local changed = false
            for _, gid in ipairs(type(s.groups) == "table" and ids or {}) do
                if not indexOf(s.groups, gid) then
                    s.groups[#s.groups + 1] = gid
                    changed = true
                end
            end
            if changed then
                n = n + 1
                if notify then announce(kind, sid) end
            end
        end
    end
    return n
end

-- The seeded sets a new pad or dial holds: each shipped set's group while it is a top-level group,
-- in shipped order.
local function seededTops(p)
    local out = {}
    for _, top in ipairs(NS.BuiltIns.order) do
        local id = byOrigin(p.groups, top)
        if id and not isChild(id) then out[#out + 1] = id end
    end
    return out
end

-- Prepare's seeding: each shipped set the profile was never given (seededSets) is seeded and put at
-- the end of every pad and dial; a node shipped after its set was given goes inside the set's group
-- while that is a top-level group. A seeded member the player deleted is not seeded again: that is
-- Restore's. `appended` counts the surfaces a set was put on.
local function seedNew(p, result)
    local placed = {}
    for _, top in ipairs(NS.BuiltIns.order) do
        if not p.seededSets[top] then
            placed[#placed + 1] = seedSet(p, top)
        else
            local set = byOrigin(p.groups, top)
            for _, child in ipairs(NS.BuiltIns.groups[top].children or {}) do
                if not p.seededSets[child] then
                    if set and not isChild(set) then seedGroup(p, child, set) else p.seededSets[child] = true end
                end
            end
        end
    end
    result.appended = result.appended + placeEverywhere(p, placed, false)
end

-- The stock callouts of shipped group `origin` that seeded group `gid` lacks (none of its callouts
-- keeps their origin), each put back at its end. Answers how many.
local function restoreCallouts(p, gid, origin)
    local g = p.groups[gid]
    local have, n = {}, 0
    for _, cid in ipairs(g.callouts) do
        local c = p.callouts[cid]
        if c and c.origin then have[c.origin] = true end
    end
    for _, cid in ipairs(NS.BuiltIns.groups[origin].callouts or {}) do
        if not have[cid] then
            g.callouts[#g.callouts + 1] = seedCallout(p, cid)
            n = n + 1
        end
    end
    if n > 0 then announce("group", gid) end
    return n
end

--- Restore built-in groups (the Groups page): every shipped set, node and callout the profile no
--- longer has (no member keeps its origin) comes back as a fresh ordinary member: a set as a
--- top-level group at the end of every pad and dial, a node inside its set's group while that is a
--- top-level group, a callout at the end of its seeded group. What the player still has is never
--- changed, moved or overwritten, so a second run adds nothing. One act (Batch).
--- @return table { groups = n, callouts = n }: what came back
function Lib.RestoreBuiltins()
    local p = P()
    return Lib.Batch(function()
        local n, placed = { groups = 0, callouts = 0 }, {}
        local function seed(gid, parent)
            local id = seedGroup(p, gid, parent)
            n.groups, n.callouts = n.groups + 1, n.callouts + #p.groups[id].callouts
            announce("group", id)
            return id
        end
        for _, top in ipairs(NS.BuiltIns.order) do
            local set = byOrigin(p.groups, top)
            if set then
                n.callouts = n.callouts + restoreCallouts(p, set, top)
            else
                set = seed(top)
                placed[#placed + 1] = set
            end
            for _, child in ipairs(NS.BuiltIns.groups[top].children or {}) do
                local node = byOrigin(p.groups, child)
                if node then
                    n.callouts = n.callouts + restoreCallouts(p, node, child)
                elseif Lib.ValidParent(set) then
                    seed(child, set)
                end
            end
        end
        placeEverywhere(p, placed, true)
        if n.callouts > 0 then announce("callout", nil) end
        NS.Debug(TAG, "restore built-ins: %s groups, %s callouts", n.groups, n.callouts)
        return n
    end)
end

-- ── surfaces ────────────────────────────────────────────────────────────────────────────────

local SURFACE_DEFAULTS = {
    -- look: the Look tab's rows (settings/SchemaMembers.lua). The font, border and background rows
    -- (phase 5, options-ui-§16/§17) default to the Ka0s skin a pad has always worn: the chip label's
    -- small white face with its shadow, a flat 1px black edge ("None" is no border art) and the
    -- 0.06, 0.06, 0.08, 0.92 body (spec §10.1).
    pad = { groupsAs = "sections", layout = { orientation = "grid", columns = 4, growth = "right",
        style = "iconLabel", scale = 1.0, spacing = 4, width = 100 },
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
--- architecture-§5 boot check) and what a member row resets to. `icon`, `iconColor` and `point` are
--- false, not nil, so the boot check can see the key: false is "none" and "the default place".
Lib.TEMPLATES = {
    callout = { name = "", text = "", channel = "smartGroup", icon = false, iconColor = false },
    group = { name = "", icon = false, iconColor = false, enabled = true, openInto = false, when = {}, parent = false,
        inheritWhen = true },
    pad = { name = "", enabled = true, groupsAs = SURFACE_DEFAULTS.pad.groupsAs, point = false,
        layout = copyTable(SURFACE_DEFAULTS.pad.layout), look = copyTable(SURFACE_DEFAULTS.pad.look) },
    -- `key` and `point` are false, not nil, for the same reason as above: false is "no key" and "the
    -- default place".
    dial = { name = "", enabled = true, mode = SURFACE_DEFAULTS.dial.mode, slices = SURFACE_DEFAULTS.dial.slices,
        openAt = SURFACE_DEFAULTS.dial.openAt, key = false, point = false },
}

--- A dial's place when its `point` is unset: the middle of the screen (read at run time by
--- modules/Dial.lua, the CLI and the Comms Dial page).
Lib.DIAL_DEFAULT_POINT = { "CENTER", "CENTER", 0, 0 }

-- A new pad or dial: its kind's defaults, `name` and a copy of `groups`, at the end of its kind's
-- order.
local function newSurface(kind, name, groups)
    local p = P()
    local set = kind == "pad" and p.pads or p.dials
    local id = Lib.NewId(kind == "pad" and "p" or "d")
    local s = copyTable(SURFACE_DEFAULTS[kind])
    s.name, s.enabled, s.groups = name, true, copyTable(groups)
    set[id] = s
    local order = kind == "pad" and p.padOrder or p.dialOrder
    order[#order + 1] = id
    announce(kind, id)
    return id
end

--- Create a pad or dial holding the seeded sets the profile still has as top-level groups, in
--- shipped order (where the built-in sets went on a new surface; seededTops).
function Lib.CreateSurface(kind, name)
    if kind ~= "pad" and kind ~= "dial" then return nil, "badKind" end
    return newSurface(kind, name, seededTops(P()))
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

--- Put a top-level user group on a pad or a dial at `index` (end by default). A group inside another
--- is refused: it shows wherever its parent does.
function Lib.AddGroupToSurface(kind, sid, gid, index)
    local s = surface(kind, sid)
    local known = P().groups[gid] and not isChild(gid)
    if not s or not known or indexOf(s.groups, gid) then return false end
    index = math.max(1, math.min(index or (#s.groups + 1), #s.groups + 1))
    table.insert(s.groups, index, gid)
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
--- new group comes before the seeded sets. A surface that already lists it is skipped.
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

-- A converted surface list: each `bi.` set reference as the group `map` seeded for it, any other
-- `bi.` id (a node, a set seeded for no one, a stale id) left out, no id twice.
local function convertRefs(list, map)
    local out = {}
    for _, gid in ipairs(list) do
        local id = gid
        if type(gid) == "string" and gid:sub(1, 3) == "bi." then id = map[gid] end
        if id ~= nil and not indexOf(out, id) then out[#out + 1] = id end
    end
    return out
end

--- Schema step 3 for one stored profile (2026-10-18-builtins-as-groups-design.md, goal 1): the
--- built-in overlay becomes seeded groups. A profile that has its surfaces (`seeded`) is given every
--- shipped set as seeded groups (seedSet), each in the set's place on every pad and dial that listed
--- it: a set that was off is a group that is off, and its hidden callouts are left out. A customized
--- set is not seeded: its copy, a user group already, keeps its place, and Restore brings the set
--- back. A set a surface's seenBuiltins lacks (shipped after it last loaded) goes at that surface's
--- end. Any other `bi.` reference is dropped (convertRefs), and the overlay (`builtins`) and every
--- surface's seenBuiltins go. A profile never prepared is left to Prepare, which seeds it, and one
--- already given its sets (seededSets) is left as it is. A raw SavedVariables profile: a missing or
--- malformed registry key is made empty. Idempotent.
--- @return number the sets seeded
function Lib.SeedFromOverlay(profile)
    if type(profile) ~= "table" then return 0 end
    local overlays = type(profile.builtins) == "table" and profile.builtins or {}
    profile.builtins = nil
    if profile.seeded ~= true or (type(profile.seededSets) == "table" and next(profile.seededSets) ~= nil) then
        return 0
    end
    for _, key in ipairs({ "callouts", "groups", "pads", "dials" }) do
        if type(profile[key]) ~= "table" then profile[key] = {} end
    end
    profile.seededSets = {}
    liftNextId(profile)
    local map, n = {}, 0
    for _, top in ipairs(NS.BuiltIns.order) do
        local o = type(overlays[top]) == "table" and overlays[top] or {}
        if type(o.customizedAs) == "string" and type(profile.groups[o.customizedAs]) == "table" then
            profile.seededSets[top] = true
            for _, child in ipairs(NS.BuiltIns.groups[top].children or {}) do profile.seededSets[child] = true end
        else
            map[top] = seedSet(profile, top, type(o.hidden) == "table" and o.hidden or nil)
            if o.enabled == false then profile.groups[map[top]].enabled = false end
            n = n + 1
        end
    end
    for _, key in ipairs({ "pads", "dials" }) do
        for _, s in pairs(profile[key]) do
            if type(s) == "table" then
                local seen = type(s.seenBuiltins) == "table" and s.seenBuiltins or nil
                if type(s.groups) == "table" then
                    s.groups = convertRefs(s.groups, map)
                    -- A set shipped after the surface last loaded (not in its seenBuiltins) goes at
                    -- its end, as Prepare would have put it there before the overlay went.
                    for _, top in ipairs(NS.BuiltIns.order) do
                        if seen and not seen[top] and map[top] and not indexOf(s.groups, map[top]) then
                            s.groups[#s.groups + 1] = map[top]
                        end
                    end
                end
                s.seenBuiltins = nil
            end
        end
    end
    return n
end

-- ── prepare ─────────────────────────────────────────────────────────────────────────────────

-- Whether a surface may list `gid`: a top-level user group.
local function exists(gid)
    return P().groups[gid] ~= nil and not isChild(gid)
end

local REGISTRY = { "callouts", "groups", "pads", "dials", "padOrder", "dialOrder", "seededSets" }

-- The registry's top-level keys as tables, and its entries as tables, before anything walks them.
local function normalize(p, result)
    for _, key in ipairs(REGISTRY) do
        if type(p[key]) ~= "table" then p[key] = {} result.repaired = result.repaired + 1 end
    end
    for _, key in ipairs({ "callouts", "groups", "pads", "dials" }) do
        for id, v in pairs(p[key]) do
            if type(v) ~= "table" then p[key][id] = nil result.repaired = result.repaired + 1 end
        end
    end
end

-- A fresh profile's default pad and dial (D7), once. Made before the sets are seeded (seedNew puts
-- them on every surface), so the two keep the first ids, p1 and d2.
local function seedSurfaces(p, result)
    if p.seeded then return end
    if #p.padOrder == 0 then Lib.CreateSurface("pad", L["Comms Pad"]) end
    if #p.dialOrder == 0 then Lib.CreateSurface("dial", L["Comms Dial"]) end
    p.seeded = true
    result.seeded = true
end

-- A stored glyph color that is not one (Library.ValidIconColor) is dropped from every user callout
-- and group: a hand-edited or damaged SavedVariables never reaches a renderer.
local function dropBadColors(p, result)
    for _, key in ipairs({ "callouts", "groups" }) do
        for _, m in pairs(p[key]) do
            if not Lib.ValidIconColor(m.iconColor) then m.iconColor = nil result.repaired = result.repaired + 1 end
        end
    end
end

-- One owner: a callout held a second time (by another group, or again in the same list) is replaced
-- there by a fresh copy, the groups walked by id so the first keeps the original. A plain copy of the
-- stored fields, checked by nothing: a repair, never a refusal. Before the dangling-id repair.
local function splitShared(p, result)
    local gids = {}
    for gid in pairs(p.groups) do gids[#gids + 1] = gid end
    table.sort(gids, function(a, b) return tostring(a) < tostring(b) end)
    local seen = {}
    for _, gid in ipairs(gids) do
        local list = p.groups[gid].callouts
        for i, cid in ipairs(type(list) == "table" and list or {}) do
            local c = p.callouts[cid]
            if c and seen[cid] then
                local copy = Lib.NewId("c")
                -- A copy keeps no provenance (docs/schema.md): only the original claims its origin.
                local fresh = copyTable(c)
                fresh.origin = nil
                p.callouts[copy] = fresh
                list[i] = copy
                result.repaired = result.repaired + 1
            elseif c then
                seen[cid] = true
            end
        end
    end
end

-- One owner: a callout no group holds is deleted (owner ruling, 2026-10-17). After the dangling-id
-- repair, so every list is a table.
local function dropLoose(p, result)
    local kept = {}
    for _, g in pairs(p.groups) do
        for _, cid in ipairs(g.callouts) do kept[cid] = true end
    end
    for cid in pairs(p.callouts) do
        if not kept[cid] then p.callouts[cid] = nil result.repaired = result.repaired + 1 end
    end
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

-- Nesting, one level: a stored parent that is no user group, is the group itself, or itself has a
-- parent (a chain, or a cycle) is dropped, so the group is top-level again. Judged on the parents as
-- stored, so the answer does not hang on the order the groups are walked in. Before seedNew, which
-- judges whether a set's group is top-level, and before the surfaces' repair, which then takes every
-- child off every surface.
local function repairParents(p, result)
    local stored = {}
    for gid, g in pairs(p.groups) do stored[gid] = g.parent end
    for gid, g in pairs(p.groups) do
        local v = stored[gid]
        if v ~= nil and v ~= false and not (type(v) == "string" and v ~= gid and p.groups[v] and not stored[v]) then
            g.parent = nil
            result.repaired = result.repaired + 1
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

-- One pad or dial: its list as a table, its dangling groups dropped (a child among them), and its
-- settings tables filled (fillShape).
local function repairSurface(s, kind, result)
    fillShape(s, kind)
    s.groups = type(s.groups) == "table" and s.groups or {}
    for i = #s.groups, 1, -1 do
        if not exists(s.groups[i]) then table.remove(s.groups, i) result.repaired = result.repaired + 1 end
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

--- Seed (a fresh profile's pad and dial, then the shipped sets the profile was never given), split
--- shared callouts, drop dangling ids, loose callouts, malformed glyph colors and bad parents, and
--- take a child off every surface. Idempotent. `appended` counts the surfaces a newly seeded set
--- was put on, `repaired` every split, drop and fix.
--- @return table { seeded, appended, repaired }
function Lib.Prepare()
    local p = P()
    local result = { seeded = false, appended = 0, repaired = 0 }
    normalize(p, result)
    dropBadColors(p, result)
    liftNextId(p)
    seedSurfaces(p, result)
    repairParents(p, result)
    seedNew(p, result)
    splitShared(p, result)
    repairGroups(p, result)
    dropLoose(p, result)
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

-- A surface's group list from a share result, pointing at the fresh copies: an imported group
-- becomes its new id, anything else (gone since the check) is left out.
local function remapGroups(list, map)
    local out = {}
    for _, gid in ipairs(list) do
        local id = map[gid]
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

-- Each imported group the string nests (Share's checked `parent`, one level) goes inside its parent's
-- fresh copy, through the seam, which refuses what it would refuse a player; a refusal is counted as
-- ignored. Before the surfaces, so an imported pad never lists a child.
local function nestImported(res, map, tally)
    for _, e in ipairs(res.groups) do
        local id, parent = map[e.id], e.parent and map[e.parent]
        if id and parent and not NS.SchemaRuntime.Set("group.parent", parent, id) then
            tally.ignored = tally.ignored + 1
        end
    end
end

-- One owner: each group makes its own copy of each callout it lists, so groups that share a callout
-- id get one copy each, and a callout no group lists is never made. `map` keeps an old callout id's
-- first copy.
local function importMembers(res, map, tally)
    local entries = {}
    for _, e in ipairs(res.callouts) do entries[e.id] = e end
    for _, e in ipairs(res.groups) do
        local ids = {}
        for _, cid in ipairs(e.callouts) do
            local id = entries[cid] and Lib.CreateCallout(entries[cid].fields)
            if id then
                ids[#ids + 1] = id
                map[cid], tally.callouts = map[cid] or id, tally.callouts + 1
            end
        end
        local f = e.fields
        local id = Lib.CreateGroup({ name = f.name, icon = f.icon, iconColor = f.iconColor, when = f.when,
            openInto = f.openInto, enabled = f.enabled, inheritWhen = f.inheritWhen, callouts = ids })
        if id then map[e.id], tally.groups = id, tally.groups + 1 end
    end
    nestImported(res, map, tally)
    for _, e in ipairs(res.pads) do importSurface("pad", e, map, tally) end
    for _, e in ipairs(res.dials) do importSurface("dial", e, map, tally) end
end

--- Apply a checked share result (modules/Share.lua Validate): every member under a fresh id (spec
--- §18: ids are always re-mapped, names may repeat), each group's callouts and each surface's groups
--- pointing at the new copies, a nested group inside its parent's copy. Nothing arrives seeded: an
--- import carries no origin.
--- Each group gets its own copy of each callout
--- it lists, and a callout no group lists is not imported (one owner). A pad or a dial arrives unbound (spec §15): no
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
