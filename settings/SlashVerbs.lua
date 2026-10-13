local _, NS = ...
-- settings/SlashVerbs.lua — the bodies of the feature verbs settings/Slash.lua's NS.COMMANDS rows
-- call (spec §14). Today: `check`, `lock`, `unlock`, `preview` and `why`. The rows are positional triples; the work lives here so it can
-- be tested without the dispatcher.

NS.SlashVerbs = NS.SlashVerbs or {}
local V = NS.SlashVerbs
local L = NS.L

-- "{a}, {b}" from a list of raw token names.
local function braced(list)
    local out = {}
    for i, raw in ipairs(list) do out[i] = "{" .. tostring(raw) .. "}" end
    return table.concat(out, ", ")
end

--- The lines `/qc check <id>` prints: the baked line under the current situation, the channel,
--- any lock, and the tokens the line leaves out. Pure formatting, never sends (spec P8, D12). No
--- ctx is passed, so the baked tokens ({me}, {spec}, {role}, {key}, {dungeon}, {spell:ID}) are
--- listed as filled at send time rather than guessed here.
--- @param id string
--- @return string[]
function V.CheckLines(id)
    id = (id or ""):match("^%s*(%S+)") or ""
    local callout = NS.Library.Callout(id)
    if not callout then return { L["No callout with id %s."]:format(id) } end
    local snap = NS.Situation.Current()
    local line, reason, info = NS.Bake.Bake(callout, snap, { soloFallback = NS.Setting("behavior.soloFallback") })
    if not line then
        if reason == "solo" and info.selfPrint then
            return { L["%s -> would print locally, not sent (solo fallback: self)"]:format(id) }
        end
        return { L["%s -> not sent here (%s)"]:format(id, tostring(reason)) }
    end
    local out = { ("%s -> %s"):format(id, line),
        L["  channel: %s, %d of 255 bytes"]:format(tostring(info.concrete), info.length) }
    if info.lock then out[#out + 1] = L["  locked: %s"]:format(info.lock) end
    if #info.missing > 0 then
        out[#out + 1] = L["  baked at send time: %s"]:format(braced(info.missing))
    end
    if #info.unknown > 0 then
        out[#out + 1] = L["  unknown tokens: %s"]:format(braced(info.unknown))
    end
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

--- The lines `/qc preview [name|off]` prints (spec §14): the menu with the one on now, or the result
--- of switching. A refused start prints its own line from Preview.SetPreviewAs.
--- @return string[]
function V.PreviewLines(rest)
    local P = NS.Preview
    local key = (rest or ""):match("^%s*(%S+)")
    if not key then
        local out = { L["Preview as (now: %s):"]:format(P.Label(P.PreviewAs() or P.CURRENT)) }
        for _, e in ipairs(P.Presets()) do out[#out + 1] = L["  %s: %s"]:format(e.key, e.label) end
        return out
    end
    key = key:lower()   -- as the dispatcher reads verbs; every preset key is lower case
    if key == "off" then key = P.CURRENT end
    if not P.FindPreset(key) then
        return { L["No situation named %s. Type /qc preview for the list."]:format(key) }
    end
    local want = key ~= P.CURRENT and key or nil
    if P.PreviewAs() ~= want and not P.SetPreviewAs(key) then return {} end
    if want then return { L["Previewing: %s"]:format(P.Label(key)) } end
    return { L["Preview off."] }
end

function V.Preview(rest)
    for _, line in ipairs(V.PreviewLines(rest)) do NS.Print(line) end
end

--- The lines `/qc why` prints (spec §14): every built pad, in the pad order, then every built dial, in
--- the dial order, each followed by why it shows what it shows (Surfaces.WhyLines).
--- @return string[]
function V.WhyLines()
    local p = NS.db and NS.db.profile
    local out = {}
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
    return out
end

function V.Why()
    for _, line in ipairs(V.WhyLines()) do NS.Print(line) end
end
