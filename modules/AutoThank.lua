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
--- under `settings` (the profile's `thank`): "emote" is the client's /thank on the caster, "line"
--- a whisper of the filled text, "both" the emote, a newline, then the whisper. The whole macro is
--- held to B.MAX_MACRO and the whisper line to B.MAX_BYTES. A whisper that cannot be built (an
--- empty filled text, or one that starts with "/") refuses "line" and leaves "both" the emote alone,
--- with the reason either way (AT.REASON says it).
--- @return string|nil macro, string|nil reason
function AT.Macro(caster, buff, settings)
    if type(caster) ~= "table" or type(caster.whisperName) ~= "string" then return nil, "noCaster" end
    local B = NS.Bake
    local send = settings.send or "emote"
    local emote
    if send == "emote" or send == "both" then
        local cmd = NS.Emotes.Command("THANK")
        if not cmd then return nil, "noEmote" end
        emote = cmd .. " " .. caster.whisperName
        if send == "emote" then return emote end
    end
    local whisper = NS.Compat.WhisperCommand()
    if not whisper then return emote, "noWhisper" end
    local head = whisper .. " " .. caster.whisperName .. " "
    local cap = math.min(B.MAX_BYTES, B.MAX_MACRO - (emote and #emote + 1 or 0))
    local text, why = AT.Fill(settings.text, caster.name, buff, cap - #head)
    if not text then return emote, why end
    if emote then return emote .. "\n" .. head .. text end
    return head .. text
end
