local _, NS = ...
-- modules/AutoThank.lua — auto-thank (#19, spec §9): a stranger who buffs the player gets a toast
-- with a Thank button. This file holds the PURE decisions (AT.Accept, AT.Fill, AT.Macro) and the
-- per-caster cooldown map; the client is read only through NS.Compat. The Thank button's macro is
-- the client's /thank on the caster, a whisper, or both on two lines, held to B.MAX_MACRO in total.
-- Anti-pattern #20: the thank-you text is chat text, never a command, so a text that starts with
-- "/" is refused and control bytes flatten, as a callout's Line does (modules/Bake.lua).

NS.AutoThank = NS.AutoThank or {}
local AT = NS.AutoThank
local State = NS.State
local L = NS.L

--- Why a whisper was not built (AT.Macro's reason), as the toast says it.
AT.REASON = {
    empty           = L["Nothing to whisper: the thank-you text is empty."],
    startsWithSlash = L["The thank-you text cannot start with /."],
}

local function plain(v)
    if NS.Compat.IsSecret(v) then return nil end
    return v
end

local function cooldownKey(caster, spellId) return caster.guid .. ":" .. spellId end

-- The last time each caster and spell was thanked, [guid .. ":" .. spellId] = GetTime(). Session-only.
State.thankCooldown = State.thankCooldown or {}

--- Record that `caster`'s `spellId` was thanked at `now`, starting its cooldown.
function AT.Stamp(caster, spellId, now)
    State.thankCooldown[cooldownKey(caster, spellId)] = now
end

local function muted(caster, mute)
    if mute == "strangers" then return caster.known == false end
    if mute == "known" then return caster.known == true end
    return false
end

--- True when the player's aura `aura`, cast by `caster` (Compat.AuraCaster's answer, nil when it is
--- no other player outside the group), is one to thank under `settings` (the profile's `thank`) at
--- `now` (D3). Every field must read plain: a secret reads as a refusal. isFromPlayerOrPlayerPet is
--- true for ANY player's aura (the old castByPlayer); the caster read already rejects self and pets.
--- @return boolean
function AT.Accept(aura, caster, settings, now)
    if type(aura) ~= "table" or NS.Compat.IsSecret(aura) or type(caster) ~= "table" then return false end
    if plain(aura.isHelpful) ~= true or plain(aura.isFromPlayerOrPlayerPet) ~= true then return false end
    local duration = NS.Compat.PlainNumber(aura.duration)
    if not duration or duration < NS.Constants.THANK.MIN_DURATION then return false end
    local spellId = NS.Compat.PlainNumber(aura.spellId)
    if not spellId then return false end
    settings = settings or {}
    if settings.raidBuffsOnly and not (NS.GameIds.THANK_RAID_BUFFS or {})[spellId] then return false end
    if muted(caster, settings.mute) then return false end
    local last = State.thankCooldown[cooldownKey(caster, spellId)]
    return last == nil or now - last >= NS.Constants.THANK.COOLDOWN
end

-- The bytes `ch` takes once escaped: a pipe is doubled.
local function cost(ch) return ch == "|" and 2 or #ch end

--- The thank-you text: `text` with {name} and {buff} filled, flattened to one clean line (control
--- bytes become spaces), pipes doubled, and cut to `budget` bytes at a character boundary (never
--- inside a UTF-8 character or a doubled pipe). Nil and a reason ("empty" | "startsWithSlash") when
--- nothing can be sent.
--- @return string|nil text, string|nil reason
function AT.Fill(text, name, buff, budget)
    if type(text) ~= "string" then return nil, "empty" end
    local filled = text:gsub("{name}", function() return name or "" end)
    filled = filled:gsub("{buff}", function() return buff or "" end)
    local clean, why = NS.Bake.CleanText(filled)
    if not clean then return nil, why end
    local out, used = {}, 0
    for ch in clean:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local n = cost(ch)
        if used + n > budget then break end
        out[#out + 1] = ch == "|" and "||" or ch
        used = used + n
    end
    local s = table.concat(out):gsub(" $", "")
    if s == "" then return nil, "empty" end
    return s
end

--- The Thank button's macro for `caster` (Compat.AuraCaster's answer) and the buff named `buff`,
--- under `settings` (the profile's `thank`): "emote" is the client's /thank on the caster, named by
--- `caster.emoteName` (the bare name: the emote did not resolve the whisper form "Name-Realm", while
--- "/thank <Name>" typed by hand did; owner's smoke, 2026-11-11), "line"
--- a whisper of the filled text, "both" the emote, a newline, then the whisper. The whole macro is
--- held to B.MAX_MACRO and the whisper line to B.MAX_BYTES. A whisper that cannot be built (an
--- empty filled text, or one that starts with "/") refuses "line" and leaves "both" the emote alone,
--- with the reason either way (AT.REASON says it). The third answer is whether a whisper line is in.
--- @return string|nil macro, string|nil reason, boolean whisper
function AT.Macro(caster, buff, settings)
    if type(caster) ~= "table" or type(caster.whisperName) ~= "string" then return nil, "noCaster", false end
    local B = NS.Bake
    local send = settings.send or "emote"
    local emote
    if send == "emote" or send == "both" then
        local cmd = NS.Emotes.Command("THANK")
        if not cmd then return nil, "noEmote", false end
        local who = type(caster.emoteName) == "string" and caster.emoteName ~= "" and caster.emoteName
            or caster.whisperName
        emote = cmd .. " " .. who
        if send == "emote" then return emote, nil, false end
    end
    local whisper = NS.Compat.WhisperCommand()
    if not whisper then return emote, "noWhisper", false end
    local head = whisper .. " " .. caster.whisperName .. " "
    local cap = math.min(B.MAX_BYTES, B.MAX_MACRO - (emote and #emote + 1 or 0))
    local text, why = AT.Fill(settings.text, caster.name, buff, cap - #head)
    if not text then return emote, why, false end
    if emote then return emote .. "\n" .. head .. text, nil, true end
    return head .. text, nil, true
end

-- ── the unit-filter frame (spec §9 The event; events-frames-taint-§1's carve-out) ───────────────
-- A private frame whose one job is UNIT_AURA filtered to "player" by the client, so no unit compare
-- (the payload may be secret) is ever made. Made once at load and re-used across a disable and an
-- enable; registered only while auto-thank is on for the current content kind, so the default (the
-- open world alone, R-B) costs nothing in an instance. AceAddon's UnregisterAllEvents never reaches
-- it, so the stand-down below takes it down itself.

local function thankSettings()
    local db = NS.db
    return db and db.profile and db.profile.thank
end

-- True when auto-thank should hear the player's auras now.
local function wanted()
    if NS.IsStoodDown() then return false end
    local t = thankSettings()
    if not (t and t.enabled) then return false end
    local content = NS.Situation.Current().content
    return type(t.content) == "table" and t.content[content] == true
end

-- ── detection (spec §9 Detection, D3) ───────────────────────────────────────────────────────────
-- State.thankKnown is the plain set of the player's helpful auraInstanceIDs, so a buff is offered
-- once, when it is new. State.thankDirty says a change went unread (in combat, or a secret payload):
-- the after-combat diff (CA-M4-7) catches it up. State.thankNeedsBaseline says the last snapshot was
-- restricted (a login, /reload or registration in combat), so the set is no baseline at all: the next
-- diff re-snapshots quietly instead of taking every buff the player holds as new.

State.thankKnown = State.thankKnown or {}

--- Where a candidate goes: { aura, caster, key = guid .. ":" .. spellId }. The toast host
--- (modules/AutoThank_Toast.lua, CA-M4-9) replaces this.
function AT.Offer(candidate) -- luacheck: ignore 212
end

--- Re-read the known set from the player's helpful auras, quietly. A restricted read (nil) leaves
--- the set as it is, marks it dirty and asks the next diff for a baseline.
function AT.Snapshot()
    local ids = NS.Compat.HelpfulAuraIds()
    if not ids then
        State.thankDirty, State.thankNeedsBaseline = true, true
        return false
    end
    local known = {}
    for _, id in ipairs(ids) do known[id] = true end
    State.thankKnown, State.thankNeedsBaseline = known, nil
    return true
end

-- Offer `aura` (a plain table, its id already plain) when it is one to thank.
local function consider(aura, id, settings)
    local caster = NS.Compat.AuraCaster(id, aura)
    if not AT.Accept(aura, caster, settings, GetTime()) then return end
    AT.Offer({ aura = aura, caster = caster, key = caster.guid .. ":" .. aura.spellId })
end

local function removeIds(ids)
    if type(ids) ~= "table" or NS.Compat.IsSecret(ids) then return end
    for _, id in ipairs(ids) do
        id = NS.Compat.PlainNumber(id)
        if id then State.thankKnown[id] = nil end
    end
end

local function addAuras(list, settings)
    if list == nil then return end
    if type(list) ~= "table" or NS.Compat.IsSecret(list) then
        State.thankDirty = true
        return
    end
    for _, aura in ipairs(list) do
        local id = type(aura) == "table" and not NS.Compat.IsSecret(aura) and NS.Compat.PlainNumber(aura.auraInstanceID)
        if not id then
            State.thankDirty = true
        elseif not State.thankKnown[id] then
            State.thankKnown[id] = true
            consider(aura, id, settings)
        end
    end
end

-- In combat, or on the PLAYER_REGEN_DISABLED edge before lockdown reads true.
local function fighting()
    return NS.Compat.InCombat() or State.combatEdge == true
end

-- ── the after-combat diff (spec §9 Combat, F4c) ─────────────────────────────────────────────────
-- A change in combat is read as dirty, never by id (the payload is secret while auras are
-- restricted). After the fight the player's helpful auras are diffed against the known set. Nothing
-- is filed at the edge: lockdown still reads false there, so SE.RunOrQueue would run at once and the
-- edge's own RESTRICTION_CHANGED drains SE's queue; AT.Diff itself waits while fighting() holds.

local function byNewest(a, b) return a > b end

--- Catch a dirty known set up: every helpful aura the player holds that the set lacks, the newest
--- C.THANK.COMBAT_QUEUE first, is offered when it passes AT.Accept; an expired aura or an unreadable
--- caster drops quietly. Does nothing when the set is clean, while fighting, when auto-thank is off
--- here, or while the read is still restricted (the set stays dirty). With no baseline (a restricted
--- snapshot, State.thankNeedsBaseline) it only re-snapshots, so a login or /reload never bursts.
--- @return boolean diffed
function AT.Diff()
    if not State.thankDirty or fighting() or not wanted() then return false end
    if State.thankNeedsBaseline then
        if not AT.Snapshot() then return false end
        State.thankDirty = false
        return true
    end
    local current = NS.Compat.HelpfulAuraIds()
    if not current then return false end
    local fresh = {}
    for _, id in ipairs(current) do
        if not State.thankKnown[id] then fresh[#fresh + 1] = id end
    end
    table.sort(fresh, byNewest)
    local known = {}
    for _, id in ipairs(current) do known[id] = true end
    State.thankKnown, State.thankDirty = known, false
    local settings = thankSettings()
    for i = 1, math.min(#fresh, NS.Constants.THANK.COMBAT_QUEUE) do
        local aura = NS.Compat.AuraByInstance(fresh[i])
        if aura then consider(aura, fresh[i], settings) end
    end
    return true
end

--- The toast host's release at the end of combat, before the diff's own shows. The toast host
--- (modules/AutoThank_Toast.lua, CA-M4-10) replaces this.
function AT.ReleaseToast()
end

--- The end of combat, from R.OnCombatEdge(false) after State.combatEdge is cleared, and from the
--- "thank.diff" entry SE drains: the toast is released before the diff's own shows, and neither
--- waits on RESTRICTION_CHANGED, which a login or /reload in combat may never send. Both refuse
--- while fighting, so an entry drained at the combat edge does nothing.
function AT.OnCombatEnd()
    AT.ReleaseToast()
    AT.Diff()
end

-- SE's combat-end entry for the diff: one function for the session, filed once per fight.
local DIFF_KEY = "thank.diff"
local function diffAfterCombat() AT.OnCombatEnd() end

--- The UNIT_AURA handler: `unit` is "player" (the frame's filter, never compared), `info` the
--- client's updateInfo, which is secret while auras are restricted. In combat, or on the combat edge
--- before lockdown reads true, it only marks the set dirty and files the diff on SE's combat-end
--- queue, once a fight: the player's auras change often in combat, so a later change makes nothing
--- and files nothing. Nothing is indexed before the secret test.
function AT.OnAura(unit, info) -- luacheck: ignore 212
    if not wanted() then return end
    if fighting() then
        State.thankDirty = true
        if not NS.SendEngine.Queued(DIFF_KEY) then NS.SendEngine.Queue(DIFF_KEY, diffAfterCombat) end
        return
    end
    if NS.Compat.IsSecret(info) or type(info) ~= "table" then
        State.thankDirty = true
        return
    end
    if NS.Compat.IsSecret(info.isFullUpdate) then
        State.thankDirty = true
        return
    end
    if info.isFullUpdate == true then
        AT.Snapshot()
        return
    end
    removeIds(info.removedAuraInstanceIDs)
    addAuras(info.addedAuras, thankSettings())
end

AT.frame = AT.frame or CreateFrame("Frame")
AT.frame:SetScript("OnEvent", function(_, _, unit, info) AT.OnAura(unit, info) end)

--- Register the frame's UNIT_AURA when auto-thank is on, the addon is up and the current content kind
--- is switched on; otherwise unregister it. Runs on SITUATION_CHANGED, PROFILE_CHANGED, a thank.*
--- setting change (the rows' onChange) and the stand-up.
function AT.Rewire()
    local frame = AT.frame
    if wanted() then
        if not frame.qcAuraOn then
            frame.qcAuraOn = NS.SafeRegisterUnitEvent(frame, "UNIT_AURA", NS.rejectedEvents, "player") or nil
            if frame.qcAuraOn then AT.Snapshot() end
        end
    else
        frame:UnregisterAllEvents()
        frame.qcAuraOn = nil
    end
end

-- Its own target (core/Bus.lua); on the tracked bus the stand-down and stand-up take it down and
-- replay it, on the degraded bus this module does both itself. RESTRICTION_CHANGED is the toast
-- host's (modules/AutoThank_Toast.lua): it releases the toast before it runs the diff.
local HANDLERS = {
    { NS.MSG.SITUATION_CHANGED, function() AT.Rewire() end },
    { NS.MSG.PROFILE_CHANGED, function() AT.Rewire() end },
}
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if not receiver then return end
    for _, h in ipairs(HANDLERS) do receiver:RegisterMessage(h[1], h[2]) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    AT.frame:UnregisterAllEvents()
    AT.frame.qcAuraOn = nil
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    AT.Rewire()
end
