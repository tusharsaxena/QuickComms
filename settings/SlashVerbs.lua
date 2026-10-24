local _, NS = ...
-- settings/SlashVerbs.lua — the bodies of the feature verbs settings/Slash.lua's NS.COMMANDS rows
-- call (spec §14). Today: `check`, `lock`, `unlock`, `toggle`, `preview` (bare, a name, `off`, `list`)
-- and `why`. The rows are positional triples; the work lives here so it can be tested without the
-- dispatcher.

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

--- The lines `/qc preview [name|off|list]` prints (spec §14, design-qc-preview §2.3). Bare starts a
--- preview of the current situation when nothing is previewed, or keeps the one on, and either way
--- puts the selector window up; `list` prints the menu with the one on now and changes nothing; a
--- name or `off` switches. A refused start prints its own line from Preview.SetPreviewAs.
--- @return string[]
function V.PreviewLines(rest)
    local P = NS.Preview
    local key = (rest or ""):match("^%s*(%S+)")
    if not key then
        if P.PreviewAs() == nil then
            if not P.SetPreviewAs(P.CURRENT) then return {} end
        elseif NS.PreviewWindow then
            NS.PreviewWindow.Sync()
        end
        return { L["Previewing: %s"]:format(P.Label(P.PreviewAs())) }
    end
    key = key:lower()   -- as the dispatcher reads verbs; every preset key is lower case
    if key == "list" then
        local out = { L["Preview as (now: %s):"]:format(P.Label(P.PreviewAs() or P.OFF)) }
        for _, e in ipairs(P.Presets()) do out[#out + 1] = L["  %s: %s"]:format(e.key, e.label) end
        return out
    end
    if key ~= P.OFF and not P.FindPreset(key) then
        return { L["No situation named %s. Type /qc preview list for the list."]:format(key) }
    end
    if key == P.OFF then
        -- Every preview the window shows, as its End preview does (QF-02): the edit preview too.
        if P.PreviewAs() ~= nil or P.EditGroup() ~= nil then P.EndPreview() end
        return { L["Preview off."] }
    end
    if P.PreviewAs() ~= key and not P.SetPreviewAs(key) then return {} end
    return { L["Previewing: %s"]:format(P.Label(key)) }
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
