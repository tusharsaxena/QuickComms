local _, NS = ...
-- settings/SlashVerbs.lua — the bodies of the feature verbs settings/Slash.lua's NS.COMMANDS rows
-- call (spec §14). Today: `check`, `lock`, `unlock`, `toggle`, `preview` (bare, a name, `off`, `list`),
-- `why` and `probe` (bare, `ids` or `clear`). The rows are positional triples; the work lives here so it
-- can be tested without the dispatcher.

NS.SlashVerbs = NS.SlashVerbs or {}
local V = NS.SlashVerbs
local L = NS.L

-- "{a}, {b}" from a list of raw token names.
local function braced(list)
    local out = {}
    for i, raw in ipairs(list) do out[i] = "{" .. tostring(raw) .. "}" end
    return table.concat(out, ", ")
end

-- A ping or a marker action (combined actions §7): its line and bytes, or why it does not bake.
local function targetActionLines(id, a)
    if not a.line then return { L["%s -> not sent here (%s)"]:format(id, tostring(a.reason)) } end
    return { ("%s -> %s"):format(id, a.line), L["  action: %s, %d of 255 bytes"]:format(a.kind, a.length) }
end

-- The Line's notes: its lock, the tokens filled at send time and the unknown tokens.
local function lineNotes(out, lock, missing, unknown)
    if lock then out[#out + 1] = L["  locked: %s"]:format(lock) end
    if missing and #missing > 0 then out[#out + 1] = L["  baked at send time: %s"]:format(braced(missing)) end
    if unknown and #unknown > 0 then out[#out + 1] = L["  unknown tokens: %s"]:format(braced(unknown)) end
end

-- One action of a combined callout (combined actions §7): "<kind>: <line>, N of 255 bytes", the
-- Line's channel and notes under it; or why it does not bake.
local function actionLines(out, a)
    if not a.line then
        if a.kind == "line" and a.reason == "solo" and a.selfPrint then
            out[#out + 1] = L["  %s: would print locally, not sent (solo fallback: self)"]:format(a.kind)
        elseif a.kind == "line" and a.reason == "tooLong" and a.budget then
            -- held by the macro's budget (D13): its bytes against the share it had (CA-M2-R2)
            out[#out + 1] = L["  %s: not sent here (%s), %d of %d bytes"]:format(a.kind, a.reason, a.length, a.budget)
        else
            out[#out + 1] = L["  %s: not sent here (%s)"]:format(a.kind, tostring(a.reason))
        end
        return
    end
    out[#out + 1] = L["  %s: %s, %d of 255 bytes"]:format(a.kind, a.line, a.length)
    if a.kind == "line" then
        out[#out + 1] = L["  channel: %s"]:format(tostring(a.concrete))
        lineNotes(out, a.lock, a.missing, a.unknown)
    elseif a.lock then
        out[#out + 1] = L["  locked: %s"]:format(a.lock)
    end
end

-- `/qc check` for a callout with several actions: one row per action, then the macro's total.
local function combinedLines(id, info)
    local out = { L["%s -> %d actions"]:format(id, #info.actions) }
    for _, a in ipairs(info.actions) do actionLines(out, a) end
    if #info.baked > 0 then out[#out + 1] = L["  macro: %d of 255 bytes"]:format(info.total) end
    return out
end

--- The lines `/qc check <id>` prints: the baked line under the current situation, the channel,
--- any lock, and the tokens the line leaves out (a ping or a marker: its line and bytes; a callout
--- with several actions: one row per action, then the macro's bytes). Pure formatting, never sends
--- (spec P8, D12). No ctx is passed, so the baked tokens ({me}, {spec}, {role}, {key}, {dungeon},
--- {spell:ID}) are listed as filled at send time rather than guessed here.
--- @param id string
--- @return string[]
function V.CheckLines(id)
    id = (id or ""):match("^%s*(%S+)") or ""
    local callout = NS.Library.Callout(id)
    if not callout then return { L["No callout with id %s."]:format(id) } end
    local snap = NS.Situation.Current()
    local soloFallback = NS.Setting("behavior.soloFallback")
    local _, _, actions = NS.Bake.BakeActions(callout, snap, { soloFallback = soloFallback })
    if #actions.actions > 1 then return combinedLines(id, actions) end
    local first = actions.actions[1]
    if first and (first.kind == "ping" or first.kind == "marker") then return targetActionLines(id, first) end
    local line, reason, info = NS.Bake.Bake(callout, snap, { soloFallback = soloFallback })
    if not line then
        if reason == "solo" and info.selfPrint then
            return { L["%s -> would print locally, not sent (solo fallback: self)"]:format(id) }
        end
        return { L["%s -> not sent here (%s)"]:format(id, tostring(reason)) }
    end
    local out = { ("%s -> %s"):format(id, line),
        L["  channel: %s, %d of 255 bytes"]:format(tostring(info.concrete), info.length) }
    lineNotes(out, info.lock, info.missing, info.unknown)
    return out
end

--- `/qc check <id>`: print the lines.
function V.Check(rest)
    for _, line in ipairs(V.CheckLines(rest)) do NS.Print(line) end
end

--- `/qc lock|unlock` and the launcher's Locked entry: the Lock frame row's stored path through the
--- one write seam (slash-commands-§8), confirmed on one line in `set`'s shape.
function V.SetLocked(on)
    local S = NS.SchemaRuntime
    local ok, err = S.Set("locked", on and true or false)
    if ok == false then return NS.Print(tostring(err)) end
    NS.Print(("locked = %s"):format(tostring(S.Get("locked"))))
end

function V.ToggleLock()
    V.SetLocked(NS.Setting("locked") == false)
end

--- `/qc toggle`, the launcher's Show window entry and the Toggle Comms Pads key binding: hide or show
--- every Comms Pad, remembered per character (`db.char.padsHidden`, so a /reload or the next login
--- restores it). The pads' secure visibility driver carries the flag, so the change goes through
--- Surfaces.Request: now, or at the end of combat with the stale hint meanwhile. Test mode still shows
--- them (an explicit preview); dials are not pads and are not affected. Stood down, it refuses by
--- hold (NS.StoodDownRefusal): the disabled line under `disabled`, the capture line under `perf` alone.
function V.TogglePads()
    local refusal = NS.StoodDownRefusal()
    if refusal then return NS.Print(refusal) end
    local hidden = V.PadsShown()
    NS.db.char.padsHidden = hidden
    NS.Surfaces.Request("padsHidden")
    -- Not a chat line (owner, 2026-10-21): the pads showing or going is the answer; the debug log keeps it.
    NS.Debug("Pads", hidden and "hidden on this character until shown again" or "shown")
end

-- The key bindings menu's Toggle Comms Pads (Bindings.xml, 2026-10-20; launcher-§6): a CLICK on this
-- plain, hidden, named button, whose click runs V.TogglePads, the one handler `/qc toggle` and the
-- launcher's Show window call. A Bindings.xml body runs in the global environment, so the binding
-- reaches the handler through a frame the client finds by name rather than through a global function.
-- Registered for the down edge, as the dial headers are, so one press toggles once. Its label is a
-- global the menu reads by the binding's name, which holds a space and a colon: rawset, as
-- modules/Dial.lua's.
--
-- THE CATEGORY (item 015, launcher-§6 as of standard v2.88.0): every Bindings.xml line names
-- category="BINDING_HEADER_QUICKCOMMS", and the client titles that section of Options -> Keybindings
-- with this global, the brand. Assigned at file scope, here beside the button, because the client
-- reads it at registration. An identifier, declared in .luacheckrc `globals` with its reason.
V.TOGGLE_BUTTON = "QuickCommsTogglePads"
V.TOGGLE_COMMAND = ("CLICK %s:LeftButton"):format(V.TOGGLE_BUTTON)
BINDING_HEADER_QUICKCOMMS = NS.BRAND
do
    local button = CreateFrame("Button", V.TOGGLE_BUTTON, UIParent)
    button:RegisterForClicks("AnyDown")
    button:SetScript("OnClick", function() V.TogglePads() end)
    button:Hide()
    rawset(_G, "BINDING_NAME_" .. V.TOGGLE_COMMAND, L["Toggle Comms Pads"])
end

-- NS.BINDINGS (launcher-§6): the addon's one bindings table, in Bindings.xml order, Show window first:
-- Toggle Comms Pads, then Open Comms Dial 1 to Dial.BINDINGS (their labels are modules/Dial.lua's).
-- The General page's Keybindings tab (settings/Panel.lua, O.KeybindingsTab) draws one row per entry,
-- and tests/test_dial.lua holds Bindings.xml to it (Kit.assertBindingsXml).
NS.BINDINGS = { { command = V.TOGGLE_COMMAND,
                  tooltip = L["Hides or shows every Comms Pad on this character, as /qc toggle does."] } }
for i = 1, NS.Dial.BINDINGS do
    NS.BINDINGS[#NS.BINDINGS + 1] = { command = NS.Dial.Command(i),
        tooltip = L["Opens or closes the dial at place %d in the dial list."]:format(i) }
end

--- Whether the pads are shown, as far as `/qc toggle` is concerned: this character's last choice.
function V.PadsShown()
    local char = NS.db and NS.db.char
    return not (char and char.padsHidden == true)
end

-- `/qc preview` bare: start Current when nothing is previewed, else keep the one on and put the
-- window up again.
local function previewBareLines(P)
    if P.PreviewAs() == nil then
        if not P.SetPreviewAs(P.CURRENT) then return {} end
    elseif NS.PreviewWindow then
        NS.PreviewWindow.Sync()
    end
    return { L["Previewing: %s"]:format(P.Label(P.PreviewAs())) }
end

-- `/qc preview list`: the menu, headed by the one on now; changes nothing.
local function previewListLines(P)
    local out = { L["Preview as (now: %s):"]:format(P.Label(P.PreviewAs() or P.OFF)) }
    for _, e in ipairs(P.Presets()) do out[#out + 1] = L["  %s: %s"]:format(e.key, e.label) end
    return out
end

-- `/qc preview off`: every preview the window shows, as its End preview does (QF-02): the edit
-- preview too.
local function previewOffLines(P)
    if P.PreviewAs() ~= nil or P.EditGroup() ~= nil then P.EndPreview() end
    return { L["Preview off."] }
end

-- `/qc preview <name>`: switch to a preset, unless it is the one on already.
local function previewSwitchLines(P, key)
    if not P.FindPreset(key) then
        return { L["No situation named %s. Type /qc preview list for the list."]:format(key) }
    end
    if P.PreviewAs() ~= key and not P.SetPreviewAs(key) then return {} end
    return { L["Previewing: %s"]:format(P.Label(key)) }
end

--- The lines `/qc preview [name|off|list]` prints (spec §14, design-qc-preview §2.3). Bare starts a
--- preview of the current situation when nothing is previewed, or keeps the one on, and either way
--- puts the selector window up; `list` prints the menu with the one on now and changes nothing; a
--- name or `off` switches. A refused start prints its own line from Preview.SetPreviewAs.
--- @return string[]
function V.PreviewLines(rest)
    local P = NS.Preview
    local key = (rest or ""):match("^%s*(%S+)")
    if not key then return previewBareLines(P) end
    key = key:lower()   -- as the dispatcher reads verbs; every preset key is lower case
    if key == "list" then return previewListLines(P) end
    if key == P.OFF then return previewOffLines(P) end
    return previewSwitchLines(P, key)
end

function V.Preview(rest)
    for _, line in ipairs(V.PreviewLines(rest)) do NS.Print(line) end
end

--- The lines `/qc why` prints (spec §14): the role the When editor's Role row matches and where it
--- came from (QFE-F4), then every built pad, in the pad order, then every built dial, in the dial
--- order, each followed by why it shows what it shows (Surfaces.WhyLines).
--- @return string[]
function V.WhyLines()
    local p = NS.db and NS.db.profile
    local s = NS.Situation.Current()
    local out = {}
    local roleLine = L["Your role: %s."]:format(NS.Situation.DescribeRole(s.role, s.roleSource, s.roleDetail))
    if p then
        local kinds = {
            { set = p.pads, order = p.padOrder, plans = NS.Surfaces.Plans() },
            { set = p.dials, order = p.dialOrder, plans = NS.Surfaces.DialPlans() },
        }
        for _, k in ipairs(kinds) do
            for _, id in ipairs(k.order) do
                if k.plans[id] then
                    out[#out + 1] = L["%s (%s):"]:format(k.set[id].name or id, id)
                    for _, line in ipairs(NS.Surfaces.WhyLines(id)) do out[#out + 1] = "  " .. line end
                end
            end
        end
    end
    if #out == 0 then out[1] = L["Nothing is showing: no pad or dial has been built yet."] end
    table.insert(out, 1, roleLine)
    return out
end

function V.Why()
    for _, line in ipairs(V.WhyLines()) do NS.Print(line) end
end

-- ── /qc probe (QFE-F5, design §4.5, C4) ─────────────────────────────────────────────────────
--
-- A record of where the player is, as the client reports it, for checking the WoW Forever seeds
-- (instance ids, difficulty ids, content kinds, talent trees, emote tokens) off a saved file. It
-- writes into this addon's own SavedVariables, `QuickCommsDB.global.probes[<client key>]`, an array
-- in probe order (never a new SavedVariables global, owner-rulings C4); `/qc probe clear` empties
-- it. Out of combat only: the emote scan reads several hundred globals. Both clients. The chat gets
-- a short summary; the full record is in the file once the client writes it (at logout or /reload).

-- The newest records a client keeps; an older one is dropped as a new one lands.
V.PROBE_KEEP = 50

-- The snapshot's fields a probe keeps (modules/Situation.lua Classify).
local PROBE_SITUATION = { "content", "instanceID", "difficultyID", "difficulty", "keyLevel", "challengeMapID",
    "group", "instanceGroup", "classFile", "specID", "character" }

-- The probe store, `db.global.probes`, made on first use when `create`; nil before the database.
local function probeStore(create)
    local g = NS.db and NS.db.global
    if type(g) ~= "table" then return nil end
    if type(g.probes) ~= "table" then
        if not create then return nil end
        g.probes = {}
    end
    return g.probes
end

--- One probe record, read now (never stored): the place, the situation, the role, the spec, the
--- talent groups and the client's emote tokens.
--- @return table
function V.ProbeRecord()
    local C = NS.Compat
    local snap = NS.Situation.Classify(NS.Situation.ReadInputs())
    local situation = {}
    for _, field in ipairs(PROBE_SITUATION) do situation[field] = snap[field] end
    local specID, specName = C.ActiveSpec()
    local tokens = C.EmoteTokens()
    return {
        client = C.ClientKey(),
        time = GetServerTime and C.PlainNumber(GetServerTime()) or nil,
        instance = C.ProbeInstance(),
        content = snap.content,
        situation = situation,
        role = { role = snap.role, source = snap.roleSource, detail = snap.roleDetail },
        spec = { id = specID, name = specName },
        groups = C.TalentGroups(),
        emotes = { count = #tokens, tokens = tokens },
    }
end

local function orDash(v)
    if v == nil then return "-" end
    return tostring(v)
end

-- "Protection 31, Arms 0", or "none".
local function groupsText(groups)
    local parts = {}
    for i, g in ipairs(groups) do parts[i] = ("%s %s"):format(orDash(g.name), orDash(g.spent)) end
    if #parts == 0 then return L["none"] end
    return table.concat(parts, ", ")
end

--- The lines `/qc probe` prints for a stored record and its place in the list.
--- @return string[]
function V.ProbeSummary(rec, n)
    local i = rec.instance
    return {
        L["Probe %d saved for %s (QuickCommsDB.global.probes; /qc probe clear empties it)."]:format(n, rec.client),
        L["  place: %s, type %s, difficulty %s (%s), %s players, instance %s"]:format(orDash(i.name),
            orDash(i.instanceType), orDash(i.difficultyID), orDash(i.difficultyName), orDash(i.maxPlayers),
            orDash(i.instanceID)),
        L["  content: %s; group: %s; role: %s"]:format(orDash(rec.content), orDash(rec.situation.group),
            NS.Situation.DescribeRole(rec.role.role, rec.role.source, rec.role.detail)),
        L["  spec: %s (%s); talent groups: %s; emotes: %d"]:format(orDash(rec.spec.name), orDash(rec.spec.id),
            groupsText(rec.groups), rec.emotes.count),
    }
end

-- ── /qc probe ids (QuickComms#21, the forever-ids design "#1 in game") ──────────────────────
--
-- The client's own names, read with no travel, for checking the shipped ids (defaults/GameIds_Clients.lua
-- and the battleground sets) off a saved file: every map id 0..PROBE_MAP_MAX GetRealZoneText names, the
-- dungeon finder's list, the battlegrounds and the group finder's activities. One `kind = "ids"` record
-- in the same store, under the same PROBE_KEEP cap. The chat gets how many maps were named, each shipped
-- id the client does not name, each dungeon finder name no shipped id carries, and the group finder
-- check (the forever-ids design's D5).

-- The last map id the sweep reads (the highest Forever or Retail id is under it today).
V.PROBE_MAP_MAX = 4000

--- One ids record, read now (never stored).
--- @return table
function V.ProbeIdsRecord()
    local C = NS.Compat
    return {
        kind = "ids",
        client = C.ClientKey(),
        time = GetServerTime and C.PlainNumber(GetServerTime()) or nil,
        maps = C.ProbeMapNames(V.PROBE_MAP_MAX),
        lfg = C.ProbeDungeonFinder(),
        battlegrounds = C.ProbeBattlegrounds(),
        groupFinder = C.ProbeGroupFinder(),
    }
end

-- This client's shipped battleground sets that match on ids, in seeding order: { key, ids }, the
-- ids sorted. A set carries both clients' map ids, so it is checked as a whole.
local function shippedBattlegroundSets()
    local BI, out = NS.BuiltIns, {}
    for _, gid in ipairs(BI.Seeded()) do
        local when = BI.groups[gid].when
        if when and when.battleground then
            local ids = {}
            for id in pairs(when.battleground) do ids[#ids + 1] = id end
            table.sort(ids)
            out[#out + 1] = { key = gid:match("^bi%.bg%.(.+)$") or gid, ids = ids }
        end
    end
    return out
end

-- The shipped ids the record's maps do not name, as text pieces, and the names it gives the rest.
local function unnamedShipped(maps)
    local G, missing, names = NS.GameIds, {}, {}
    for _, kind in ipairs({ { G.DUNGEONS, L["dungeon %d"] }, { G.RAIDS, L["raid %d"] } }) do
        for _, id in ipairs(kind[1] or {}) do
            if maps[id] then names[maps[id]] = true else missing[#missing + 1] = kind[2]:format(id) end
        end
    end
    for _, s in ipairs(shippedBattlegroundSets()) do
        local named = false
        for _, id in ipairs(s.ids) do
            if maps[id] then names[maps[id]], named = true, true end
        end
        if not named then missing[#missing + 1] = L["battleground set %s (%s)"]:format(s.key, table.concat(s.ids, ", ")) end
    end
    return missing, names
end

-- The dungeon finder's names (random entries left out) that no shipped id carries: neither a name
-- the client gives a shipped id, nor an entry whose lfgMapID is one. The summary reports an empty list
-- as not checked, never as "none": WoW Forever's own UI never calls the dungeon finder APIs, so they
-- may answer nothing there.
local function uncarriedFinderNames(lfg, names)
    local G, shipped, out, seen = NS.GameIds, {}, {}, {}
    for _, list in ipairs({ G.DUNGEONS or {}, G.RAIDS or {} }) do
        for _, id in ipairs(list) do shipped[id] = true end
    end
    for _, s in ipairs(shippedBattlegroundSets()) do
        for _, id in ipairs(s.ids) do shipped[id] = true end
    end
    for _, e in ipairs(lfg) do
        local n = e.name
        if n and not e.random and not names[n] and not (e.mapID and shipped[e.mapID]) and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    return out
end

local function listOrNone(list)
    if #list == 0 then return L["none"] end
    return table.concat(list, ", ")
end

-- The group finder line (D5): the shipped ids its activities do not list (a battleground set counts
-- as listed when any of its ids is), and the maps it lists that no shipped id carries, "Name (id)",
-- each once in the order read. Zone activities (maxNumPlayers 0) are not places; a nil count is kept.
-- An empty list reads as not checked, never as "none".
-- The shipped ids the group finder does not list, each "dungeon 123", "raid 456" or a whole
-- battleground set; every shipped id is marked in `shipped` on the way.
local function missingShipped(listed, shipped)
    local G, missing = NS.GameIds, {}
    for _, kind in ipairs({ { G.DUNGEONS, L["dungeon %d"] }, { G.RAIDS, L["raid %d"] } }) do
        for _, id in ipairs(kind[1] or {}) do
            shipped[id] = true
            if not listed[id] then missing[#missing + 1] = kind[2]:format(id) end
        end
    end
    for _, s in ipairs(shippedBattlegroundSets()) do
        local any = false
        for _, id in ipairs(s.ids) do
            shipped[id], any = true, any or listed[id] == true
        end
        if not any then missing[#missing + 1] = L["battleground set %s (%s)"]:format(s.key, table.concat(s.ids, ", ")) end
    end
    return missing
end

-- The maps the group finder lists that no shipped id carries, "Name (id)", each once.
local function extraMaps(acts, shipped)
    local extra, seen = {}, {}
    for _, a in ipairs(acts) do
        local id = a.mapID
        if id and a.maxNumPlayers ~= 0 and not shipped[id] and not seen[id] then
            seen[id] = true
            extra[#extra + 1] = L["%s (%d)"]:format(orDash(a.name), id)
        end
    end
    return extra
end

local function groupFinderLine(acts)
    if #acts == 0 then return L["  group finder: not checked, the group finder listed no activities"] end
    local listed, shipped = {}, {}
    for _, a in ipairs(acts) do
        if a.mapID then listed[a.mapID] = true end
    end
    local missing = missingShipped(listed, shipped)
    local extra = extraMaps(acts, shipped)
    return L["  group finder: %d activities; shipped ids it does not list: %s; maps it lists that no shipped id carries: %s"]
        :format(#acts, listOrNone(missing), listOrNone(extra))
end

--- The lines `/qc probe ids` prints for a stored ids record and its place in the list.
--- @return string[]
function V.ProbeIdsSummary(rec, n)
    local count = 0
    for _ in pairs(rec.maps) do count = count + 1 end
    local missing, names = unnamedShipped(rec.maps)
    return {
        L["Ids probe %d saved for %s (QuickCommsDB.global.probes; /qc probe clear empties it)."]:format(n, rec.client),
        L["  map names read: %d of ids 0 to %d; dungeon finder: %d entries; battlegrounds: %d"]:format(count,
            V.PROBE_MAP_MAX, #rec.lfg, #rec.battlegrounds),
        L["  shipped ids the client does not name: %s"]:format(listOrNone(missing)),
        L["  dungeon finder names no shipped id carries: %s"]:format(#rec.lfg == 0
            and L["not checked, the dungeon finder listed no entries"]
            or listOrNone(uncarriedFinderNames(rec.lfg, names))),
        groupFinderLine(rec.groupFinder or {}),
    }
end

-- `/qc probe clear`: every client's records go.
local function probeClearLines()
    local store = probeStore(false)
    local removed = 0
    for _, list in pairs(store or {}) do
        if type(list) == "table" then removed = removed + #list end
    end
    if store then NS.db.global.probes = nil end
    return { L["Probes cleared: %d removed."]:format(removed) }
end

--- The lines `/qc probe [ids|clear]` prints. Bare records the place and summarizes it, `ids` records
--- the client's map, dungeon finder and battleground names and summarizes them; either is refused in
--- combat with one line. `clear` empties the store (any time); anything else names the three forms.
--- @return string[]
function V.ProbeLines(rest)
    local word = ((rest or ""):match("^%s*(%S+)") or ""):lower()
    if word == "clear" then return probeClearLines() end
    if word ~= "" and word ~= "ids" then
        return { L["/qc probe records where you are; /qc probe ids records the client's map, dungeon finder and battleground names; /qc probe clear empties the records."] }
    end
    if NS.Restrictions.InCombat() or NS.Compat.InCombat() then return { L["The probe is not available in combat."] } end
    local store = probeStore(true)
    if not store then return { L["The probe is not available before the saved settings load."] } end
    local ids = word == "ids"
    local rec = ids and V.ProbeIdsRecord() or V.ProbeRecord()
    local list = type(store[rec.client]) == "table" and store[rec.client] or {}
    store[rec.client] = list
    list[#list + 1] = rec
    while #list > V.PROBE_KEEP do table.remove(list, 1) end
    if ids then return V.ProbeIdsSummary(rec, #list) end
    return V.ProbeSummary(rec, #list)
end

function V.Probe(rest)
    for _, line in ipairs(V.ProbeLines(rest)) do NS.Print(line) end
end
