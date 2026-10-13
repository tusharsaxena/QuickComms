local _, NS = ...
-- settings/Groups_When.lua — the When editor (design spec §5.3, §13.2), the Groups page's When tab.
--
-- Shaped after the WeakAuras Load tab: one row per condition, each an enable checkbox and, while on,
-- its values: checkboxes for a short list, a lowest and highest box for the key level, and an id list
-- (the library's IdList: an add box with suggestions, one line per entry with Remove) for instances,
-- battlegrounds and characters. Values are ids and tokens, never localized names
-- (localization-§4): instances and battlegrounds by instanceID, classes by classFile,
-- specializations by specID, characters by Name-Realm; a name is shown, never matched. The list
-- data is shipped (defaults/GameIds.lua and the battleground sets); "Add the instance you are in"
-- covers an id the table does not list yet. A live line says whether the group is active now, or in
-- the previewed situation, and which row stops it.
--
-- Every change writes the group's WHOLE When through the seam (`group.when`, a structured member
-- row, settings/SchemaMembers.lua), read fresh from the profile at the click, so two clicks before a
-- repaint never lose one. A row switched on with nothing chosen yet stays open for the session
-- (NS.State.whenOpen); switched off, its values are cleared. A built-in group's When is fixed: the
-- tab describes it. The pure half is tested headlessly in tests/test_groups_when.lua.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L
local State = NS.State

Settings.GroupsWhen = Settings.GroupsWhen or {}
local W = Settings.GroupsWhen

W.ROWS = { "content", "instances", "difficulty", "keyLevel", "group", "leadership", "class", "spec", "role",
    "characters", "battleground" }

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

--- The values a checkbox row offers, in order. The specialization row offers the classes the class
--- row picked, or the player's own; a spec chosen earlier stays listed so it can be cleared.
--- @return table { { value, text } }
function W.Values(row, when)
    if row == "content" then
        local out = {}
        for i, v in ipairs(NS.Resolver.TOKENS.content) do out[i] = { value = v, text = NS.PadRender.CONTENT[v] or v } end
        return out
    end
    if NS.Resolver.TOKENS[row] then return tokenValues(row) end
    if row == "class" then
        local out = {}
        for i, cf in ipairs(NS.GameIds.CLASSES) do out[i] = { value = cf, text = NS.Compat.ClassName(cf) or cf } end
        return out
    end
    if row == "spec" then
        local classes = {}
        local picked = type(when) == "table" and when.class or nil
        if type(picked) == "table" and next(picked) then
            for cf in pairs(picked) do classes[#classes + 1] = cf end
            table.sort(classes)
        else
            local live = NS.Situation.Current()
            if live.classFile then classes[1] = live.classFile end
        end
        local out, seen = {}, {}
        local function add(specID)
            if seen[specID] then return end
            seen[specID] = true
            out[#out + 1] = { value = specID, text = NS.Compat.SpecInfoByID(specID) or L["Specialization %d"]:format(specID) }
        end
        for _, cf in ipairs(classes) do
            for _, specID in ipairs(NS.GameIds.SPECS[cf] or {}) do add(specID) end
        end
        local chosen = {}
        for specID in pairs(type(when) == "table" and when.spec or {}) do chosen[#chosen + 1] = specID end
        table.sort(chosen)
        for _, specID in ipairs(chosen) do add(specID) end
        return out
    end
    return {}
end

local function nameOf(row, value)
    if row == "instances" then return W.InstanceName(value) end
    if row == "battleground" then return W.BattlegroundName(value) end
    if row == "characters" then return tostring(value) end
    for _, v in ipairs(W.Values(row, {})) do
        if v.value == value then return v.text end
    end
    if row == "spec" then return NS.Compat.SpecInfoByID(value) or L["Specialization %d"]:format(value) end
    return tostring(value)
end

--- A When read back as lines: "Content: M+, Raid", "Key level: 10 to any". A built-in's When tab
--- shows these.
--- @return string[]
function W.Describe(when)
    local out = {}
    for _, row in ipairs(W.ROWS) do
        if W.IsSet(when, row) then
            local label = NS.Resolver.LABEL[row] or row
            if row == "keyLevel" then
                local kl = when.keyLevel
                out[#out + 1] = L["%s: %s to %s"]:format(label, kl.min and tostring(kl.min) or L["any"],
                    kl.max and tostring(kl.max) or L["any"])
            else
                local names = {}
                for value in pairs(when[row]) do names[#names + 1] = nameOf(row, value) end
                table.sort(names)
                out[#out + 1] = L["%s: %s"]:format(label, table.concat(names, ", "))
            end
        end
    end
    if #out == 0 then out[1] = L["Always: this group has no conditions."] end
    return out
end

--- The live line (spec §13.2) for a group (user or merged built-in): off when the group is turned
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

--- The live line for group `gid` as it is now, under the editors' snapshot and the preview.
function W.ActiveText(gid)
    local g = gid and NS.Library.Group(gid)
    if not g then return "" end
    local key = NS.Preview.PreviewAs()
    return W.ActiveLine(g, Ed.Snapshot(), key and NS.Preview.Label(key))
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

local function checkbox(label, value, tooltip, onChange)
    return { make = function(_, parent, rel)
        local h = H()
        local cb = h.AceGUI:Create("CheckBox")
        cb:SetLabel(label)
        cb:SetValue(value and true or false)
        cb:SetRelativeWidth(rel or 0.5)
        cb:SetCallback("OnValueChanged", function(_, _, v) onChange(v and true or false) end)
        if tooltip then h.AttachTooltip(cb, label, tooltip) end
        parent:AddChild(cb)
        return cb
    end }
end

local function renderKeyLevel(ctx, gid)
    local kl = fresh(gid).keyLevel or {}
    local function box(label, field)
        return { make = function(_, parent, rel)
            local eb = H().AceGUI:Create("EditBox")
            eb:SetLabel(label)
            eb:SetText(kl[field] and tostring(kl[field]) or "")
            eb:SetRelativeWidth(rel or 0.5)
            eb:SetCallback("OnEnterPressed", function(_, _, text) W.SetKeyField(gid, field, text) end)
            parent:AddChild(eb)
            return eb
        end }
    end
    H().RenderGrid(ctx, { box(L["Lowest key level"], "min"), box(L["Highest key level"], "max") })
end

-- Typed text -> one of `candidates` by exact name (case-insensitive), through `nameFn`.
local function byName(text, candidates, nameFn)
    local want = (text or ""):lower()
    local found
    for _, id in ipairs(type(candidates) == "function" and candidates() or {}) do
        if nameFn(id):lower() == want then
            if found and found ~= id then return nil, "ambiguous" end
            found = id
        end
    end
    if found then return found, nameFn(found) end
    return nil, "notFound"
end

-- A typed id: a positive whole number, never a fraction or a negative (which can never match).
local function wholeId(text)
    local n = tonumber((text or ""):match("^%s*(%d+)%s*$"))
    if n and n > 0 then return n end
    return nil
end

local function idKind(nameFn, noun, plural)
    return {
        noun = noun, plural = plural,
        info = function(id) return nameFn(id), nil end,
        resolve = function(text, candidates)
            local n = wholeId(text)
            if n then return n, nameFn(n) end
            return byName(text, candidates, nameFn)
        end,
    }
end

local KIND = {
    instances = function() return idKind(W.InstanceName, L["instance"], L["instances"]) end,
    battleground = function() return idKind(W.BattlegroundName, L["battleground"], L["battlegrounds"]) end,
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
    instances = function()
        local out = {}
        for _, id in ipairs(NS.GameIds.DUNGEONS) do out[#out + 1] = id end
        for _, id in ipairs(NS.GameIds.RAIDS) do out[#out + 1] = id end
        return out
    end,
    battleground = battlegroundIds,
    characters = function() return {} end,
}

local ADD = {
    instances = { L["Add an instance"], L["Type an instance id or a listed name, then press Enter or Add."],
        L["Add the instance you are in"] },
    battleground = { L["Add a battleground"], L["Type a battleground's id or name, then press Enter or Add."],
        L["Add the battleground you are in"] },
    characters = { L["Add a character"], L["Type Name-Realm, or a name on your realm, then press Enter or Add."],
        L["Add this character"] },
}

-- The one the player is in now (the live snapshot, never the preview).
local function here(row)
    local live = NS.Situation.Current()
    if row == "instances" then return live.content ~= "openWorld" and live.instanceID or nil end
    if row == "battleground" then return live.content == "battleground" and live.instanceID or nil end
    if row == "characters" then return live.character end
    return nil
end

local NOT_HERE = {
    instances = L["You are not in an instance."],
    battleground = L["You are not in a battleground."],
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
--- instance or battleground by its id or its listed name; a specialization by its id; a character
--- as Name-Realm. Nil and the reason for a value the row can never match.
--- @return any|nil value, string|nil reason
function W.ResolveValue(row, text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if row == "characters" then
        local id = W.CharacterId(text, NS.Situation.Current())
        if id then return id end
        return nil, L["A character is Name-Realm, or a name on your realm."]
    end
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

local function renderIdRow(ctx, gid, row)
    local h = H()
    h.IdList(ctx, {
        kind = KIND[row](),
        label = ADD[row][1], tooltip = ADD[row][2],
        candidates = CANDIDATES[row],
        emptyText = L["None yet."],
        entries = function()
            local list = {}
            for id in pairs(fresh(gid)[row] or {}) do list[#list + 1] = id end
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

local function renderRow(ctx, gid, row)
    local when = fresh(gid)
    local on = W.IsSet(when, row) or openRows(gid)[row] == true
    local label = NS.Resolver.LABEL[row] or row
    H().RenderGrid(ctx, { { wide = true, make = function(_, parent)
        local h = H()
        local cb = h.AceGUI:Create("CheckBox")
        cb:SetLabel(label)
        cb:SetValue(on)
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, v)
            if v then
                openRows(gid)[row] = true
                Ed.RequestRefresh()
            else
                openRows(gid)[row] = nil
                W.Write(gid, W.ClearRow(fresh(gid), row))
            end
        end)
        h.AttachTooltip(cb, label, W.TIP[row])
        parent:AddChild(cb)
        return cb
    end } })
    if not on then return end
    if row == "keyLevel" then return renderKeyLevel(ctx, gid) end
    if KIND[row] then return renderIdRow(ctx, gid, row) end
    local items = {}
    for _, v in ipairs(W.Values(row, when)) do
        local chosen = type(when[row]) == "table" and when[row][v.value] == true
        items[#items + 1] = checkbox(v.text, chosen, nil, function(x)
            W.Write(gid, W.Toggle(fresh(gid), row, v.value, x))
        end)
    end
    H().RenderGrid(ctx, items)
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
    if NS.Library.IsBuiltin(gid) then
        h.TextRow(ctx, L["A built-in set's conditions are fixed. Customize it to change them."])
        for _, line in ipairs(W.Describe(g.when)) do h.TextRow(ctx, line) end
        return
    end
    for _, row in ipairs(W.ROWS) do renderRow(ctx, gid, row) end
end
