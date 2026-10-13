local _, NS = ...
-- settings/SlashVerbs.lua — the bodies of the feature verbs settings/Slash.lua's NS.COMMANDS rows
-- call (spec §14). Today: `check`. The rows are positional triples; the work lives here so it can
-- be tested without the dispatcher.

NS.SlashVerbs = NS.SlashVerbs or {}
local V = NS.SlashVerbs
local L = NS.L

--- The lines `/qc check <id>` prints: the baked line under the current situation, the channel,
--- and any lock. Pure formatting, never sends (spec P8, D12).
--- @param id string
--- @return string[]
function V.CheckLines(id)
    id = (id or ""):match("^%s*(%S+)") or ""
    local callout = NS.Library.Callout(id)
    if not callout then return { L["No callout with id %s."]:format(id) } end
    local snap = NS.Situation.Current()
    local line, reason, info = NS.Bake.Bake(callout, snap, { soloFallback = NS.Setting("behavior.soloFallback") })
    if not line then
        return { L["%s -> not sent here (%s)"]:format(id, tostring(reason)) }
    end
    local out = { ("%s -> %s"):format(id, line),
        L["  channel: %s, %d of 255 bytes"]:format(tostring(info.concrete), info.length) }
    if info.lock then out[#out + 1] = L["  locked: %s"]:format(info.lock) end
    return out
end

--- `/qc check <id>`: print the lines.
function V.Check(rest)
    for _, line in ipairs(V.CheckLines(rest)) do NS.Print(line) end
end
