local _, NS = ...
-- settings/Groups_When.lua — the When editor (design spec §5.3, §13.2), the Groups page's When tab.
--
-- One drawer per condition (LibKa0s O.Drawer, 2026-10-18-when-drawers-design.md §1): a header bar
-- with the condition's name (gold while it is set) and a summary of its values ("Any" while unset),
-- which opens a box holding its choices: checkboxes in three columns for a short list, a lowest and
-- highest box for the key level, and an id list (the library's IdList: an add box with suggestions,
-- one line per entry with Remove) for instances, battlegrounds, arenas and characters; under them
-- Select all (a checkbox list) and Clear (Any). Values are ids and tokens, never localized names
-- (localization-§4): instances, battlegrounds and arenas by instanceID, classes by classFile,
-- specializations by specID, characters by Name-Realm; a name is shown, never matched. The list
-- data is shipped (defaults/GameIds_Instances.lua, defaults/GameIds.lua and the battleground sets);
-- "Add the instance you are in" covers an id the tables do not list yet. A live line says whether
-- the group is active now, or in the previewed situation, and which row stops it. Under it, Inherit when
-- conditions (group.inheritWhen; Settings.Groups.InheritItem, on the General tab until item 020,
-- QUI-L03), grayed out for a group with no parent: a group inside another that inherits its When
-- conditions shows its parent's When here, read-only, under a line that says so.
--
-- Every change writes the group's WHOLE When through the seam (`group.when`, a structured member
-- row, settings/SchemaMembers.lua), read fresh from the profile at the click, so two clicks before a
-- repaint never lose one. There is no enable checkbox: a condition is set while it has values. Which
-- drawers are open is session state, per group (NS.State.whenOpen), so an open drawer survives the
-- repaint a write brings and a profile switch closes them all. A seeded built-in set's When is edited
-- as any group's (2026-10-18-builtins-as-groups-design.md). The pure half is tested headlessly in
-- tests/test_groups_when.lua.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L
local State = NS.State

Settings.GroupsWhen = Settings.GroupsWhen or {}
local W = Settings.GroupsWhen

W.ROWS = { "content", "instances", "difficulty", "keyLevel", "group", "leadership", "class", "spec", "role",
    "characters", "battleground", "arena" }

-- The labels of the token rows' values. The tokens themselves, and their order, are
-- NS.Resolver.TOKENS (read at call time), which Library.ValidWhen checks against too.
local LABELS = {
    difficulty = { normal = L["Normal"], heroic = L["Heroic"], mythic = L["Mythic"], keystone = L["Mythic Keystone"],
        lfr = L["LFR"], story = L["Story"], follower = L["Follower"] },
    group = { solo = L["Solo"], party = L["Party"], raid = L["Raid"],
        instance = L["Instance group (LFG, LFR or a battleground)"] },
    leadership = { leader = L["Leader"], assist = L["Assist"] },
    role = { TANK = L["Tank"], HEALER = L["Healer"], DAMAGER = L["Damage"] },
}

W.TIP = {
    content = L["The kind of place you are in."],
    instances = L["Specific dungeons or raids, by instance."],
    difficulty = L["The instance's difficulty."],
    keyLevel = L["The Mythic+ key level, from the lowest to the highest. Leave a box empty for no limit."],
    group = L["The kind of group you are in."],
    leadership = L["Whether you lead the group or assist."],
    class = L["Your class."],
    spec = L["Your specialization."],
    role = L["Your group role."],
    characters = L["Specific characters, as Name-Realm."],
    battleground = L["Specific battlegrounds."],
    arena = L["Specific arenas."],
}

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- ── the pure half ───────────────────────────────────────────────────────────────────────────

--- Whether a When row takes part (spec §5.3: a nil or empty row is ignored).
function W.IsSet(when, row)
    local v = type(when) == "table" and when[row] or nil
    if type(v) ~= "table" then return false end
    if row == "keyLevel" then return type(v.min) == "number" or type(v.max) == "number" end
    return next(v) ~= nil
end

--- A copy of `when` with `value` on or off in `row`; a row left empty is dropped.
function W.Toggle(when, row, value, on)
    local w = copy(when or {})
    local set = type(w[row]) == "table" and w[row] or {}
    set[value] = on and true or nil
    w[row] = next(set) ~= nil and set or nil
    return w
end

function W.ClearRow(when, row)
    local w = copy(when or {})
    w[row] = nil
    return w
end

--- A copy of `when` with the key-level range set (nil ends are open; both nil drops the row).
--- @return table|nil when, string|nil reason ("badWhen" | "badRange")
function W.SetKeyLevel(when, lo, hi)
    if (lo ~= nil and type(lo) ~= "number") or (hi ~= nil and type(hi) ~= "number") then return nil, "badWhen" end
    if lo and hi and lo > hi then return nil, "badRange" end
    local w = copy(when or {})
    w.keyLevel = (lo or hi) and { min = lo, max = hi } or nil
    return w
end

function W.InstanceName(id)
    return NS.Compat.InstanceName(id) or L["Instance %d"]:format(id)
end

local bgNames
local function battlegroundNames()
    if bgNames then return bgNames end
    bgNames = {}
    for _, def in pairs(NS.BuiltIns.groups) do
        local ids = def.when and def.when.battleground
        if type(ids) == "table" then
            for id in pairs(ids) do bgNames[id] = def.name end
        end
    end
    return bgNames
end

function W.BattlegroundName(id)
    return battlegroundNames()[id] or W.InstanceName(id)
end

local function battlegroundIds()
    local out = {}
    for id in pairs(battlegroundNames()) do out[#out + 1] = id end
    table.sort(out)
    return out
end

-- A character name as the client shows it: the first letter upper case, the rest lower case. Only
-- ASCII letters change case; a name that starts with a multi-byte letter keeps that letter.
local function nameCase(name)
    return name:sub(1, 1):upper() .. name:sub(2):lower()
end

--- A typed character as Name-Realm, the name in the client's case: with the typed realm when it
--- carries one, else with the player's realm. Nil for an empty name, a space, or an empty part.
--- @param live table a snapshot (its `character` is the player's Name-Realm)
function W.CharacterId(text, live)
    local typed = (text or ""):match("^%s*(.-)%s*$")
    if typed == "" or typed:find("%s") then return nil end
    local name, realm = typed:match("^([^%-]*)%-(.*)$")
    if not name then
        name = typed
        realm = live and live.character and live.character:match("%-(.+)$")
    end
    if not realm or name == "" or realm == "" then return nil end
    return nameCase(name) .. "-" .. realm
end

local function tokenValues(row)
    local out = {}
    for i, token in ipairs(NS.Resolver.TOKENS[row] or {}) do
        out[i] = { value = token, text = (LABELS[row] and LABELS[row][token]) or token }
    end
    return out
end

local function contentValues()
    local out = {}
    for i, v in ipairs(NS.Resolver.TOKENS.content) do out[i] = { value = v, text = NS.PadRender.CONTENT[v] or v } end
    return out
end

local function classValues()
    local out = {}
    for i, cf in ipairs(NS.GameIds.CLASSES) do out[i] = { value = cf, text = NS.Compat.ClassName(cf) or cf } end
    return out
end

-- The classes whose specializations the spec row offers: those the class row picked, else the
-- player's own.
local function specClasses(when)
    local classes = {}
    local picked = type(when) == "table" and when.class or nil
    if type(picked) == "table" and next(picked) then
        for cf in pairs(picked) do classes[#classes + 1] = cf end
        table.sort(classes)
        return classes
    end
    local live = NS.Situation.Current()
    if live.classFile then classes[1] = live.classFile end
    return classes
end

local function specValues(when)
    local out, seen = {}, {}
    local function add(specID)
        if seen[specID] then return end
        seen[specID] = true
        out[#out + 1] = { value = specID, text = NS.Compat.SpecInfoByID(specID) or L["Specialization %d"]:format(specID) }
    end
    for _, cf in ipairs(specClasses(when)) do
        for _, specID in ipairs(NS.GameIds.SPECS[cf] or {}) do add(specID) end
    end
    local chosen = {}
    for specID in pairs(type(when) == "table" and when.spec or {}) do chosen[#chosen + 1] = specID end
    table.sort(chosen)
    for _, specID in ipairs(chosen) do add(specID) end
    return out
end

--- The values a checkbox row offers, in order. The specialization row offers the classes the class
--- row picked, or the player's own; a spec chosen earlier stays listed so it can be cleared.
--- @return table { { value, text } }
function W.Values(row, when)
    if row == "content" then return contentValues() end
    if NS.Resolver.TOKENS[row] then return tokenValues(row) end
    if row == "class" then return classValues() end
    if row == "spec" then return specValues(when) end
    return {}
end

--- The live line (spec §13.2) for a group: off when the group is turned
--- off (Resolver.ActiveGroups skips it, so the picker's dot agrees), else active now or the row that
--- does not match; prefixed with the preview when "Preview as…" is on.
function W.ActiveLine(group, snap, previewLabel)
    local ok, _, failed = NS.Resolver.Matches(group and group.when, snap)
    local line
    if group and group.enabled == false then
        line = L["|cffa0a0a0Off: this group is turned off.|r"]
    elseif ok then
        line = L["|cff40ff40Active now.|r"]
    else
        line = L["|cffff6060Not active now:|r %s does not match."]:format(NS.Resolver.LABEL[failed] or tostring(failed))
    end
    if previewLabel then line = L["In the preview (%s): %s"]:format(previewLabel, line) end
    return line
end

--- The group whose When judges group `gid` (Resolver.WhenOf), and whether that is another's: a group
--- inside another that inherits shows and is judged by its parent's (2026-10-18-when-drawers-design.md
--- §3).
--- @return string id, boolean inherited
function W.Source(gid)
    local _, from = NS.Resolver.WhenOf(NS.Library.AllGroups(), gid)
    from = from or gid
    return from, from ~= gid
end

--- The live line for group `gid` as it is now, under the editors' snapshot and the preview, judged by
--- the When that judges it (W.Source).
function W.ActiveText(gid)
    local g = gid and NS.Library.Group(gid)
    if not g then return "" end
    local src = NS.Library.Group(W.Source(gid))
    local key = NS.Preview.PreviewAs()
    return W.ActiveLine({ enabled = g.enabled, when = src and src.when }, Ed.Snapshot(), key and NS.Preview.Label(key))
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local function fresh(gid)
    local g = NS.Library.Group(gid)
    return g and g.when or {}
end

local function openRows(gid)
    State.whenOpen[gid] = State.whenOpen[gid] or {}
    return State.whenOpen[gid]
end

--- Write a group's whole When through the seam; a refusal prints its reason.
--- @return boolean
function W.Write(gid, when)
    local ok, _, why = NS.SchemaRuntime.Set("group.when", when, gid)
    if not ok and why then NS.Print(tostring(why)) end
    return ok == true
end

--- One end of the key-level range from typed text ("" clears that end).
--- @return boolean stored
function W.SetKeyField(gid, field, text)
    local when = fresh(gid)
    local kl = when.keyLevel or {}
    local lo, hi = kl.min, kl.max
    local typed = (text or ""):match("^%s*(.-)%s*$")
    local n = typed ~= "" and tonumber(typed:match("^(%d+)$")) or nil
    if typed ~= "" and not n then
        NS.Print(L["A key level is a whole number."])
        return false
    end
    if field == "min" then lo = n else hi = n end
    local w, why = W.SetKeyLevel(when, lo, hi)
    if not w then
        NS.Print(why == "badRange" and L["The lowest key level is above the highest."] or L["That condition is not one Quick Comms knows."])
        return false
    end
    return W.Write(gid, w)
end

local function H() return Settings.Helpers end

-- A checkbox list's columns, and each cell's share of its line: under a third, so a line never sums
-- to 1 (the ScrollFrame's clip, options-ui-§8).
local CHECK_COLUMNS = 3
local CHECK_REL = 0.32

-- One line of up to CHECK_COLUMNS checkboxes, as one wide RenderGrid item (RenderGrid pairs its
-- cells two to a line). `cells`: { { text, value, onChange } }. Drawn disabled under the page's
-- render-disabled flag (the drawer's `disabled`), which a bespoke widget reads itself.
local function checkLine(cells)
    return { wide = true, make = function(ctx, parent)
        local h = H()
        for _, c in ipairs(cells) do
            local cb = h.AceGUI:Create("CheckBox")
            cb:SetLabel(c.text)
            cb:SetValue(c.value and true or false)
            cb:SetRelativeWidth(CHECK_REL)
            if ctx.__renderDisabled then cb:SetDisabled(true) end
            cb:SetCallback("OnValueChanged", function(_, _, v) c.onChange(v and true or false) end)
            if c.tooltip then
                cb:SetCallback("OnEnter", function(w)
                    GameTooltip:SetOwner(w.frame, "ANCHOR_RIGHT")
                    GameTooltip:SetText(c.text, 1, 1, 1)
                    GameTooltip:AddLine(c.tooltip, nil, nil, nil, true)
                    GameTooltip:Show()
                end)
                cb:SetCallback("OnLeave", function() GameTooltip:Hide() end)
            end
            parent:AddChild(cb)
        end
    end }
end

local function renderKeyLevel(ctx, gid)
    local kl = fresh(gid).keyLevel or {}
    local function box(label, field)
        return { make = function(c, parent, rel)
            local eb = H().AceGUI:Create("EditBox")
            eb:SetLabel(label)
            eb:SetText(kl[field] and tostring(kl[field]) or "")
            eb:SetRelativeWidth(rel or 0.5)
            if c.__renderDisabled then eb:SetDisabled(true) end
            eb:SetCallback("OnEnterPressed", function(_, _, text)
                -- A refusal (its line already printed) puts the box back to the stored end.
                if not W.SetKeyField(gid, field, text) then
                    local stored = (fresh(gid).keyLevel or {})[field]
                    eb:SetText(stored and tostring(stored) or "")
                end
            end)
            parent:AddChild(eb)
            return eb
        end }
    end
    H().RenderGrid(ctx, { box(L["Lowest key level"], "min"), box(L["Highest key level"], "max") })
end

-- Typed text -> one of `candidates` by exact name (case-insensitive), through `nameFn`. A name two
-- ids carry is "ambiguous", unless exactly one of them is in `prefer` (a set): that one wins.
local function byName(text, candidates, nameFn, prefer)
    local want = (text or ""):lower()
    local found, preferred, many
    for _, id in ipairs(type(candidates) == "function" and candidates() or {}) do
        if nameFn(id):lower() == want and id ~= found then
            many = found ~= nil
            found = found or id
            if prefer and prefer[id] then
                if preferred then return nil, "ambiguous" end
                preferred = id
            end
        end
    end
    if many then found = preferred end
    if found then return found, nameFn(found) end
    return nil, many and "ambiguous" or "notFound"
end

-- A typed id: a positive whole number, never a fraction or a negative (which can never match).
local function wholeId(text)
    local n = tonumber((text or ""):match("^%s*(%d+)%s*$"))
    if n and n > 0 then return n end
    return nil
end

local function idKind(nameFn, noun, plural, prefer)
    return {
        noun = noun, plural = plural,
        info = function(id) return nameFn(id), nil end,
        resolve = function(text, candidates)
            local n = wholeId(text)
            if n then return n, nameFn(n) end
            return byName(text, candidates, nameFn, prefer and prefer())
        end,
    }
end

-- The season's dungeons and raids (Preview as…'s): the instance a name two maps share means.
local function seasonInstances()
    local out = {}
    for _, id in ipairs(NS.GameIds.DUNGEONS) do out[id] = true end
    for _, id in ipairs(NS.GameIds.RAIDS) do out[id] = true end
    return out
end

local function shipped(list)
    return function()
        local out = {}
        for i, id in ipairs(NS.GameIds[list] or {}) do out[i] = id end
        return out
    end
end

local KIND = {
    instances = function() return idKind(W.InstanceName, L["instance"], L["instances"], seasonInstances) end,
    battleground = function() return idKind(W.BattlegroundName, L["battleground"], L["battlegrounds"]) end,
    arena = function() return idKind(W.InstanceName, L["arena"], L["arenas"]) end,
    characters = function()
        return { noun = L["character"], plural = L["characters"],
            info = function(id) return tostring(id), nil end,
            resolve = function(text)
                local id = W.CharacterId(text, NS.Situation.Current())
                if id then return id, id end
                return nil, "notFound"
            end }
    end,
}

local CANDIDATES = {
    instances = shipped("INSTANCES"),
    battleground = battlegroundIds,
    arena = shipped("ARENAS"),
    characters = function() return {} end,
}

local ADD = {
    instances = { L["Add an instance"], L["Type an instance id or a listed name, then press Enter or Add."],
        L["Add the instance you are in"] },
    battleground = { L["Add a battleground"], L["Type a battleground's id or name, then press Enter or Add."],
        L["Add the battleground you are in"] },
    arena = { L["Add an arena"], L["Type an arena's id or name, then press Enter or Add."],
        L["Add the arena you are in"] },
    characters = { L["Add a character"], L["Type Name-Realm, or a name on your realm, then press Enter or Add."],
        L["Add this character"] },
}

-- The id rows with a whole-kind checkbox on top of their drawer (NS.Resolver.ALL), and its label and
-- tooltip. The character row has none: every character is what Any already means.
local ALL = {
    instances = { L["All dungeons and raids"],
        L["Match in any dungeon, Mythic+ key or raid. The instances listed below are kept, unused, until you untick this."] },
    battleground = { L["All battlegrounds"],
        L["Match in any battleground. The battlegrounds listed below are kept, unused, until you untick this."] },
    arena = { L["All arenas"],
        L["Match in any arena. The arenas listed below are kept, unused, until you untick this."] },
}

--- A copy of `when` with id row `row`'s whole kind on or off; its listed ids are kept either way, and
--- a row left empty is dropped.
function W.SetAll(when, row, on)
    return W.Toggle(when, row, NS.Resolver.ALL, on)
end

-- An id row's summary for several entries.
local COUNT = {
    instances = L["%d instances"], battleground = L["%d battlegrounds"], arena = L["%d arenas"],
    characters = L["%d characters"],
}

-- The key level's summary: one level, a range, or an open end.
local function keyLevelSummary(v)
    if v.min and v.max then
        if v.min == v.max then return tostring(v.min) end
        return L["%d to %d"]:format(v.min, v.max)
    end
    if v.min then return L["%d or higher"]:format(v.min) end
    return L["%d or lower"]:format(v.max)
end

-- An id row's summary: its whole kind by the checkbox's label, one entry by its name, several by
-- their count (the whole-kind key is never counted as an id).
local function idSummary(row, v)
    if ALL[row] and v[NS.Resolver.ALL] == true then return ALL[row][1] end
    local only, n = nil, 0
    for id in pairs(v) do
        if id ~= NS.Resolver.ALL then only, n = id, n + 1 end
    end
    if n == 1 then return (KIND[row]().info(only)) end
    return COUNT[row]:format(n)
end

--- A drawer's summary (spec §1): "Any" while the row is unset; else the chosen values in the row's
--- own order, comma-separated (the drawer cuts a long one with an ellipsis); an id row's one entry by
--- its name and several by their count; the key level as a short phrase.
function W.Summary(row, when)
    if not W.IsSet(when, row) then return L["Any"] end
    local v = when[row]
    if row == "keyLevel" then return keyLevelSummary(v) end
    if KIND[row] then return idSummary(row, v) end
    local out = {}
    for _, item in ipairs(W.Values(row, when)) do
        if v[item.value] == true then out[#out + 1] = item.text end
    end
    return table.concat(out, ", ")
end

--- A copy of `when` with every value checkbox row `row` offers ticked (W.Values, so the
--- specialization row ticks the classes it lists, and no other).
function W.SelectAll(when, row)
    local w = copy(when or {})
    local set = {}
    for _, v in ipairs(W.Values(row, when)) do set[v.value] = true end
    w[row] = next(set) ~= nil and set or nil
    return w
end

-- The one the player is in now (the live snapshot, never the preview).
local function here(row)
    local live = NS.Situation.Current()
    if row == "instances" then return live.content ~= "openWorld" and live.instanceID or nil end
    if row == "battleground" then return live.content == "battleground" and live.instanceID or nil end
    if row == "arena" then return live.content == "arena" and live.instanceID or nil end
    if row == "characters" then return live.character end
    return nil
end

local NOT_HERE = {
    instances = L["You are not in an instance."],
    battleground = L["You are not in a battleground."],
    arena = L["You are not in an arena."],
    characters = L["Your character is not known yet."],
}

--- "Add the instance you are in" (and its battleground and character twins): the one the player is
--- in at the click, read then, not when the tab was drawn. Out of one, a line says so.
--- @return boolean stored
function W.AddHere(gid, row)
    local now = here(row)
    if now == nil then
        NS.Print(NOT_HERE[row])
        return false
    end
    return W.Write(gid, W.Toggle(fresh(gid), row, now, true))
end

--- One value typed for When row `row` on the command line, as the value the row stores
--- (localization-§4: ids and tokens, never a name): a token matched without regard to case; an
--- instance, battleground or arena by its id or its listed name; a specialization by its id; a character
--- as Name-Realm. Nil and the reason for a value the row can never match.
--- @return any|nil value, string|nil reason
function W.ResolveValue(row, text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if row == "characters" then
        local id = W.CharacterId(text, NS.Situation.Current())
        if id then return id end
        return nil, L["A character is Name-Realm, or a name on your realm."]
    end
    if ALL[row] and text:lower() == NS.Resolver.ALL then return NS.Resolver.ALL end
    if KIND[row] then
        local kind = KIND[row]()
        local id = kind.resolve(text, CANDIDATES[row])
        if id ~= nil then return id end
        return nil, L["%s does not take %s. It takes an id, or a listed name."]:format(NS.Resolver.LABEL[row] or row, text)
    end
    if row == "spec" then
        local n = wholeId(text)
        if n then return n end
        return nil, L["%s does not take %s. It takes: %s."]:format(NS.Resolver.LABEL[row], text, L["a specialization id (a whole number)"])
    end
    local list = row == "class" and NS.GameIds.CLASSES or NS.Resolver.TOKENS[row] or {}
    local want = text:lower()
    for _, token in ipairs(list) do
        if token:lower() == want then return token end
    end
    return nil, L["%s does not take %s. It takes: %s."]:format(NS.Resolver.LABEL[row] or row, text, table.concat(list, ", "))
end

local renderIdList

local function renderIdRow(ctx, gid, row)
    local h = H()
    -- The whole-kind checkbox, on top; while it is ticked the list under it is drawn dimmed and inert
    -- (the page's render-disabled flag, put back after), and keeps its entries for an untick.
    local all = ALL[row] and type(fresh(gid)[row]) == "table" and fresh(gid)[row][NS.Resolver.ALL] == true
    if ALL[row] then
        h.RenderGrid(ctx, { checkLine({ { text = ALL[row][1], tooltip = ALL[row][2], value = all,
            onChange = function(x) W.Write(gid, W.SetAll(fresh(gid), row, x)) end } }) })
    end
    local outer = ctx.__renderDisabled
    if all then ctx.__renderDisabled = true end
    local ok, err = pcall(renderIdList, ctx, gid, row)
    ctx.__renderDisabled = outer
    if not ok then error(err, 0) end
end

renderIdList = function(ctx, gid, row)
    local h = H()
    h.IdList(ctx, {
        kind = KIND[row](),
        label = ADD[row][1], tooltip = ADD[row][2],
        candidates = CANDIDATES[row],
        emptyText = L["None yet."],
        entries = function()
            local list = {}
            for id in pairs(fresh(gid)[row] or {}) do
                if id ~= NS.Resolver.ALL then list[#list + 1] = id end
            end
            table.sort(list, function(a, b) return tostring(a) < tostring(b) end)
            local out = {}
            for i, id in ipairs(list) do out[i] = { id = id } end
            return out
        end,
        onAdd = function(id) W.Write(gid, W.Toggle(fresh(gid), row, id, true)) end,
        onRemove = function(id) W.Write(gid, W.Toggle(fresh(gid), row, id, false)) end,
    })
    -- Always drawn, and read at the click (W.AddHere): a zone change does not redraw the tab.
    h.InlineButtonPair(ctx, { text = ADD[row][3], tooltip = ADD[row][2],
        onClick = function() W.AddHere(gid, row) end }, nil)
end

local function renderChecks(ctx, gid, row)
    local when = fresh(gid)
    local items, cells = {}, {}
    for _, v in ipairs(W.Values(row, when)) do
        cells[#cells + 1] = { text = v.text, value = type(when[row]) == "table" and when[row][v.value] == true,
            onChange = function(x) W.Write(gid, W.Toggle(fresh(gid), row, v.value, x)) end }
        if #cells == CHECK_COLUMNS then
            items[#items + 1] = checkLine(cells)
            cells = {}
        end
    end
    if #cells > 0 then items[#items + 1] = checkLine(cells) end
    H().RenderGrid(ctx, items)
end

-- What a drawer holds: its choices, by the kind of row.
local function renderChoices(ctx, gid, row)
    if row == "keyLevel" then return renderKeyLevel(ctx, gid) end
    if KIND[row] then return renderIdRow(ctx, gid, row) end
    return renderChecks(ctx, gid, row)
end

-- A drawer's buttons: Select all on a checkbox list, then Clear (Any) on every row, which unsets the
-- condition and leaves the drawer open. Both read the profile at the click.
local function actions(gid, row)
    local out = {}
    if row ~= "keyLevel" and not KIND[row] then
        out[1] = { text = L["Select all"], tooltip = L["Tick every choice listed here."],
            onClick = function() W.Write(gid, W.SelectAll(fresh(gid), row)) end }
    end
    out[#out + 1] = { text = L["Clear (Any)"], tooltip = L["Untick every choice, so this condition does not limit the group."],
        onClick = function() W.Write(gid, W.ClearRow(fresh(gid), row)) end }
    return out
end

-- One condition's drawer for group `gid`, showing the When of group `from` (gid itself, or the parent
-- it inherits from). An inherited When is read-only: the choices are drawn disabled (the drawer's
-- `disabled`) and there is no Select all or Clear (Any). The open set is gid's either way.
local function renderDrawer(ctx, gid, row, from)
    local label = NS.Resolver.LABEL[row] or row
    local readOnly = from ~= gid
    H().Drawer(ctx, {
        label = label,
        tooltip = W.TIP[row],
        summary = function() return W.Summary(row, fresh(from)) end,
        set = function() return W.IsSet(fresh(from), row) end,
        -- The library re-renders the page after the toggle; nothing else to refresh here.
        open = openRows(gid)[row] == true,
        onToggle = function(open) openRows(gid)[row] = open or nil end,
        body = function(c) renderChoices(c, from, row) end,
        actions = not readOnly and actions(gid, row) or nil,
        disabled = readOnly,
    })
end

--- The When tab for group `gid` (spec §13.2).
function W.Render(ctx, gid)
    local h = H()
    local g = gid and NS.Library.Group(gid)
    if not g then
        h.TextRow(ctx, L["No groups yet. Click New group to make one."])
        return
    end
    -- Refreshed in place (Ed.Live): a write to this group or a situation change re-reads it.
    local active = h.TextRow(ctx, W.ActiveText(gid))
    Ed.Live(ctx, function() if active then active:SetText(W.ActiveText(gid)) end end)
    h.RenderGrid(ctx, { Settings.Groups.InheritItem(gid) })
    local from, inherited = W.Source(gid)
    if inherited then
        local parent = NS.Library.Group(from)
        h.TextRow(ctx, L["|cffc9a66bUses %s's conditions. Untick Inherit when conditions above to set this group's own.|r"]
            :format(parent.name or from))
    end
    h.TextRow(ctx, L["|cffa0a0a0Every condition you set must match. A condition left as Any does not limit the group.|r"])
    h.AddSpacer(h.EnsureScroll(ctx), h.ROW_VSPACER)
    for _, row in ipairs(W.ROWS) do renderDrawer(ctx, gid, row, from) end
end
