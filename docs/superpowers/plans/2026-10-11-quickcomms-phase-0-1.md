# Ka0s Quick Comms: phases 0–1 implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold a standard-compliant Ka0s Quick Comms addon, settle the remaining in-game unknowns (C1–C9), and build the pure, headlessly tested core it rests on:
- the data model and migrations
- the situation engine
- the restrictions tracker
- tokens, channels and bake
- the resolver
- the built-in sets
- the registry writer
- the `/qc check` verb

**Architecture:**
- **Scaffold:** produced by the standard's `/dev-copilot:wow-new-addon` playbook, so it starts out compliant.
- **Pure modules:** `Tokens`, `Channels`, `Bake`, `Resolver`, and Situation's `Classify`. They take plain tables and return plain tables, and are driven by truth-table tests.
- **Edges:** Situation's reader and `Restrictions` read the client through `core/Compat.lua`.
- **Writer:** `Library` is the only module that writes the callout, group, pad and dial collections.
- **Not in this plan:** no secure frames are created. They start in phase 2, whose plan is written after the C1–C9 results.

**Tech stack:**
- Lua 5.1, against the WoW Retail 12.1 client (Interface `120100`)
- Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole)
- LibKa0s v1.71.0
- the LibKa0s headless test kit (`tests/_kit/`)
- luacheck

**Spec:** [`docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`](../specs/2026-10-11-quickcomms-v1-design.md). Read it alongside this plan; section numbers below (§n) refer to it.

**Scope note:** the spec is one document built in phases (§19). This plan covers **phase 0 and phase 1 only**. Phases 2–5 each get their own plan once phase 0's in-game checks have answered how the secure code must be built: C5 (a guard in combat), C7 (the secure dial) and C8 (pad tabs in combat) change phase 2 and phase 4 directly.

## Global Constraints

These apply to every task.

**Client and versions:**
- Interface `120100`.
- Lua 5.1 syntax only: no `goto`, no integer division, no `//`.
- LibKa0s **v1.71.0**, copied whole into `libs/LibKa0s/`, plus `tests/_kit/` from the same tag.

**Names:**
- Title `Ka0s Quick Comms`; folder `QuickComms`.
- Saved variables are exactly `QuickCommsDB` and `QuickCommsPerfDB`.
- Chat tag `|cff00ffff[QC]|r`; slash `/qc`, alias `/quickcomms`.
- Bus names `Ka0s_QuickComms_<PascalCaseEvent>`, declared once in `core/Bus.lua`.

**Code conventions:**
- Every authored `.lua` opens with `local addonName, NS = ...` (or `local _, NS = ...`). Directly beneath it goes a comment naming the file's path and purpose.
- No new globals, no `print()` (use `NS.Print` / `NS.Debug`), and no `_G[addonName]`.
- Modules publish idempotently, as `NS.X = NS.X or {}`, and never call another module's table at file load.
- Match game data by ID or token (instanceID, difficultyID, classFile, specID), never by a localized name.
- US English in all code, comments and strings: color, behavior, center, canceled, customize.
- Every user-facing string goes through `NS.L["English text"]`, and the key is the English text.

**Secret values:** any value read from the client goes through `NS.Compat` and becomes a plain value or nil. Never compare, concatenate or format a value that might be secret.

**The commit gate:** before every commit, `lua tests/run.lua` exits 0 **and** `luacheck .` reports 0 warnings and 0 errors.

**Suite and TOC bookkeeping:**
- Every new `tests/test_*.lua` is added to the `suites` list in `tests/run.lua`; the kit fails the run in both directions.
- Every new `.lua` source file is listed in `QuickComms.toc` under its `#` section, with a `# LOAD-BEARING:` or `# Conventional:` comment.

**Git:** commit on `main` only after the gate passes. Do not push unless the owner asks.

## Review Focus

These are the inputs most likely to hurt a real player that no feature test would naturally cover. Each one has a pinning test in the task named in brackets.

1. **A leading slash or newline in callout text** (`"  /run x"`, `"hi\n/script y"`, `"\t/dump 1"`, or a `/` reached only after control characters are stripped) must never produce a second macro line or a slash command; it is refused or flattened to one line of chat text. [Task 10]
2. **Multibyte text** (é, CJK): the 255 limit counts **bytes**, the boundary is exact (255 passes, 256 fails), and live tokens add their nominal 12 bytes. [Task 10]
3. **A snapshot read during a loading screen or with secret answers**, where `GetInstanceInfo` returns nils or a secret instanceID, must classify as `openWorld` / `solo` without raising. [Task 6]
4. **Deleting a callout used by several groups, or a group listed on surfaces,** leaves no dangling ids anywhere. Customizing a built-in and then deleting the copy leaves the surfaces holding neither. [Task 13]
5. **A profile from an older version that lacks a newly shipped built-in** gets it appended to each surface exactly **once**. A built-in the player removed from a surface is **not** re-added at the next login. [Task 13]

---

## Phase 0: scaffold and in-game checks

### Task 1: Scaffold the addon with the standard playbook

**Files:**
- Create: the whole scaffold the playbook produces (TOC, `core/`, `defaults/`, `settings/`, `locales/`, `modules/Diagnostics.lua`, `libs/`, `media/logos/`, `tests/`, root docs, `docs/` trio and Tier 1 docs, `.pkgmeta`, `.luacheckrc`)
- Modify: `.gitattributes` (replaced by the standard's client-bound body, spec P9), `.gitignore`, `README.md`
- Keep untouched: `docs/brainstorm/**`, `docs/superpowers/**`

**Interfaces:**
- Consumes: nothing.
- Produces: the conventions every later task relies on. Step 4 confirms they exist under these exact names; if the scaffold names them differently, Step 4 adds these names as thin aliases.
  - `NS.addon` (the AceAddon object, with AceEvent, AceTimer and AceConsole embedded)
  - `NS.L`
  - `NS.Print(fmt, ...)`, `NS.Debug(tag, fmt, ...)`
  - `NS.State` (a session table)
  - `NS.MSG`, `NS.Bus`
  - `NS.FEATURE_EVENTS` (a list of `{event, methodName}`), `NS.STAND_DOWN`, `NS.STAND_UP` (lists of functions)
  - `NS.Setting(path)`
  - `NS.db`
  - `NS.SCHEMA_VERSION`, `NS.MIGRATIONS`
  - `NS.COMMANDS` (positional triples `{name, desc, fn}`)
  - `NS.Diagnostics.Sections()`
  - test global `QUICKCOMMS_TEST`, exposing `newAddon`, `bootAddon`, `enableAddon`, `secret`, `isSecret`, `test`, `assertEqual`, `assertTrue`, `assertFalse`, `assertNil`, `assertError`

- [ ] **Step 1: Run the scaffold playbook in the repo root**

Run the Claude Code command (the dev-copilot plugin is installed):

```
/dev-copilot:wow-new-addon QuickComms Context-aware quick callouts on a Comms Pad and a ping-wheel-style Comms Dial, sent through secure buttons so they work in M+ keys and boss pulls
```

Answer the playbook's prompts with the values in this plan's Global Constraints.

Repo-specific instructions for the playbook run:
- **Line endings:** the repo already has commits. Replace `.gitattributes` with the standard's client-bound body, byte-identical (`* text=auto eol=crlf`, the `*.sh` / `*.py` carve-outs, the binary list). Then run `git add --renormalize .` and include the result in this task's commit.
- **Docs:** keep `docs/brainstorm/` and `docs/superpowers/` as they are.
- **`.gitignore`:** keep the existing `.playwright-mcp/` line.
- **README:** replace it with the canonical one. Its description paragraph says the addon is in development, and links to the spec.
- **Logo:** if the owner hasn't supplied artwork, generate a simple placeholder 2000×2000 PNG with a speech bubble on a dark disc in Ka0s gold (`#FFD100`). Derive both TGAs from it with the standard's PIL recipe.

- [ ] **Step 2: Run the gate on the fresh scaffold**

Run: `lua tests/run.lua && luacheck .`
Expected: every suite passes (`0 failed`), and luacheck prints `Total: 0 warnings / 0 errors`.

- [ ] **Step 3: Check that line endings are correct**

Run: `git add --renormalize . && git status --porcelain | grep -v '^??' | wc -l`
Expected: the count printed is the same before and after a second `git add --renormalize .`. In other words, the second run stages nothing new.

- [ ] **Step 4: Confirm or alias the interface names**

Run:
```
grep -n "NS.FEATURE_EVENTS\|NS.STAND_DOWN\|NS.STAND_UP\|function NS.Setting\|NS.COMMANDS\|QUICKCOMMS_TEST" -r core settings tests/run.lua | head -20
```
Expected: each name appears.

For any that is missing, add it the way DropWatcher does:
- `NS.FEATURE_EVENTS`, `NS.STAND_DOWN` / `NS.STAND_UP`: `../DropWatcher/core/DropWatcher.lua:20-95`.
- `NS.Setting`: `NS.Setting = function(path) return NS.SchemaRuntime.Get(path) end`, in `settings/Schema.lua`.

Re-run the gate.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Scaffold Ka0s Quick Comms from the standard playbook

Born-compliant skeleton (standard v2.78.3, LibKa0s v1.71.0) and the
client-bound .gitattributes (spec P9), renormalized."
```

---

### Task 2: In-game check harness for C1–C9 (dev only, not shipped)

**Files:**
- Create: `_dev/QCSpike/QCSpike.toc`
- Create: `_dev/QCSpike/QCSpike.lua`
- Modify: `.luacheckrc` and `.pkgmeta` only if `_dev` is not already excluded (the standard's snippets exclude it; confirm with `grep -n _dev .luacheckrc .pkgmeta`)

**Interfaces:**
- Consumes: nothing from the addon. It is a separate throwaway addon.
- Produces: in-game answers to C1–C9 (spec §19), recorded in Task 3.

- [ ] **Step 1: Write the TOC**

`_dev/QCSpike/QCSpike.toc`:
```
## Interface: 120100
## Title: QC Spike (dev only)
## Notes: In-game checks C1-C9 for the Quick Comms spec. Never shipped; delete after use.
## Author: add1kted2ka0s

QCSpike.lua
```

- [ ] **Step 2: Write the harness**

`_dev/QCSpike/QCSpike.lua`:
```lua
-- _dev/QCSpike/QCSpike.lua — throwaway in-game checks C1-C9 (spec §19). Not part of the addon.
-- /qcs               show or hide the panel (out of combat)
-- /qcs where         print instance info (confirm battleground instance IDs)
-- /qcs rebake        rewrite button P's macrotext with a counter (C4: works between pulls in a key?)
-- /qcs bind KEY      bind KEY to the spike dial (C7), /qcs unbind to clear
-- /qcs echo on|off   print whether the sender of your own returning messages is readable (C6)

local function say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100QCSpike|r " .. tostring(msg)) end

local panel = CreateFrame("Frame", "QCSpikePanel", UIParent, "BackdropTemplate")
panel:SetSize(240, 330)
panel:SetPoint("CENTER", -300, 0)
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
panel:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
panel:SetBackdropBorderColor(0, 0, 0, 1)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -6)
title:SetText("QC spike: C1-C9")

-- C1, C2, C3, C9: one secure macro button per channel. Each logs its click time.
local CHANNEL_BUTTONS = {
    { "P",    "/p QC spike party" },
    { "I",    "/i QC spike instance" },
    { "RAID", "/raid QC spike raid" },
    { "RW",   "/rw QC spike raid warning" },
    { "S",    "/s QC spike say" },
    { "Y",    "/y QC spike yell" },
    { "W%t",  "/w %t QC spike whisper to target" },
    { "%f",   "/p QC spike focus=%f" },
}
local buttons = {}
for i, def in ipairs(CHANNEL_BUTTONS) do
    local b = CreateFrame("Button", "QCSpikeBtn" .. i, panel, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    b:SetSize(105, 22)
    b:SetPoint("TOPLEFT", 10 + ((i - 1) % 2) * 115, -26 - math.floor((i - 1) / 2) * 26)
    b:SetText(def[1])
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", def[2])
    b:HookScript("OnClick", function(_, _, down)
        if down == false then say(("click %s at %.2f"):format(def[1], GetTime())) end
    end)
    buttons[def[1]] = b
end

-- C5: a guard snippet on its own button. Does GetTime() exist in the restricted environment, and
-- does returning false cancel a send? Press G fast during a boss: at most one send per second.
local header = CreateFrame("Frame", "QCSpikeHeader", UIParent, "SecureHandlerBaseTemplate")
local guard = CreateFrame("Button", "QCSpikeGuard", panel, "UIPanelButtonTemplate,SecureActionButtonTemplate")
guard:SetSize(220, 22)
guard:SetPoint("TOPLEFT", 10, -134)
guard:SetText("G: guarded /p (1 s)")
guard:RegisterForClicks("AnyUp", "AnyDown")
guard:SetAttribute("type", "macro")
guard:SetAttribute("macrotext", "/p QC spike guarded")
SecureHandlerWrapScript(guard, "OnClick", header, [[
    if down then return end
    local now = GetTime()
    local last = owner:GetAttribute("qc-last") or 0
    if now - last < 1.0 then return false end
    owner:SetAttribute("qc-last", now)
]])
guard:HookScript("OnClick", function(_, _, down)
    if down == false then say(("click G at %.2f"):format(GetTime())) end
end)

-- C8: a pad with two tab containers, each holding a secure button. Mouse wheel over the pad
-- swaps them through a restricted snippet. Does it work in combat?
local pad = CreateFrame("Frame", "QCSpikePad", panel)
pad:SetSize(220, 50)
pad:SetPoint("TOPLEFT", 10, -162)
pad:EnableMouseWheel(true)
local tabs = {}
for i, label in ipairs({ "Tab A: /p tab A", "Tab B: /p tab B" }) do
    local c = CreateFrame("Frame", "QCSpikeTab" .. i, pad)
    c:SetAllPoints(pad)
    local b = CreateFrame("Button", "QCSpikeTabBtn" .. i, c, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    b:SetSize(200, 22)
    b:SetPoint("CENTER")
    b:SetText(label .. " (wheel)")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", i == 1 and "/p QC spike tab A" or "/p QC spike tab B")
    tabs[i] = c
end
tabs[2]:Hide()
header:SetFrameRef("tabA", tabs[1])
header:SetFrameRef("tabB", tabs[2])
SecureHandlerWrapScript(pad, "OnMouseWheel", header, [[
    local a, b = owner:GetFrameRef("tabA"), owner:GetFrameRef("tabB")
    if a:IsShown() then a:Hide() b:Show() else b:Hide() a:Show() end
]])

-- C7: the spike dial. A full-screen secure button bound to a key. Key down records the cursor
-- origin; key up picks N/E/S/W and remaps the click to a slot button through `type-slotN` /
-- `clickbutton-slotN` attributes set out of combat. No attribute is written in combat except
-- the origin on the dial's own handle.
local slots = {}
for i, dir in ipairs({ "N", "E", "S", "W" }) do
    local s = CreateFrame("Button", "QCSpikeSlot" .. i, UIParent, "SecureActionButtonTemplate")
    s:RegisterForClicks("AnyUp", "AnyDown")
    s:SetAttribute("type", "macro")
    s:SetAttribute("macrotext", "/p QC spike dial " .. dir)
    slots[i] = s
end
local dial = CreateFrame("Button", "QCSpikeDial", UIParent, "SecureActionButtonTemplate")
dial:SetAllPoints(UIParent)
dial:EnableMouse(false)
dial:RegisterForClicks("AnyUp", "AnyDown")
for i = 1, 4 do
    dial:SetAttribute("type-slot" .. i, "click")
    dial:SetAttribute("clickbutton-slot" .. i, slots[i])
end
SecureHandlerWrapScript(dial, "OnClick", header, [[
    local x, y = self:GetMousePosition()
    if down then
        self:SetAttribute("qc-ox", x)
        self:SetAttribute("qc-oy", y)
        return false
    end
    local ox, oy = self:GetAttribute("qc-ox"), self:GetAttribute("qc-oy")
    if not (x and ox) then return false end
    local dx, dy = (x - ox) * 16, (y - oy) * 9
    if dx * dx + dy * dy < 0.25 then return false end
    local ax = dx < 0 and -dx or dx
    local ay = dy < 0 and -dy or dy
    if ay >= ax then
        if dy > 0 then return "slot1" end
        return "slot3"
    end
    if dx > 0 then return "slot2" end
    return "slot4"
]])
local marker = CreateFrame("Frame", nil, UIParent)
marker:SetSize(160, 160)
marker:Hide()
local mtex = marker:CreateTexture(nil, "OVERLAY")
mtex:SetAllPoints()
mtex:SetTexture("Interface\\Minimap\\Ping\\ping5")
dial:HookScript("OnClick", function(_, _, down)
    if down then
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        marker:Show()
    else
        marker:Hide()
        say(("dial released at %.2f"):format(GetTime()))
    end
end)

-- C6: are our own returning messages' senders readable?
local echoOn = false
local echo = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER_INFORM" }) do
    echo:RegisterEvent(e)
end
echo:SetScript("OnEvent", function(_, event, _, sender)
    if not echoOn then return end
    local secret = issecretvalue and issecretvalue(sender)
    if secret then
        say(("%s at %.2f: sender is SECRET"):format(event, GetTime()))
    else
        say(("%s at %.2f: sender=%s"):format(event, GetTime(), tostring(sender)))
    end
end)

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("BOTTOM", 0, 8)
local elapsed = 0
panel:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0
    local lock = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    status:SetText(("lockdown %s  combat %s"):format(lock and "ON" or "off", InCombatLockdown() and "yes" or "no"))
end)

local rebakes = 0
SLASH_QCSPIKE1 = "/qcs"
SlashCmdList.QCSPIKE = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "where" then
        local name, itype, diff, diffName, _, _, _, instanceID = GetInstanceInfo()
        say(("instance=%s type=%s difficulty=%s (%s) instanceID=%s"):format(
            tostring(name), tostring(itype), tostring(diff), tostring(diffName), tostring(instanceID)))
        if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
            say(("challengeMapID=%s"):format(tostring(C_ChallengeMode.GetActiveChallengeMapID())))
        end
    elseif cmd == "rebake" then
        if InCombatLockdown() then say("in combat: refused (expected)") return end
        rebakes = rebakes + 1
        buttons.P:SetAttribute("macrotext", "/p QC spike rebake #" .. rebakes)
        say("P now sends rebake #" .. rebakes .. " (lockdown " ..
            tostring(C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) .. ")")
    elseif cmd == "bind" and arg ~= "" then
        if InCombatLockdown() then say("leave combat first") return end
        SetOverrideBindingClick(panel, true, arg:upper(), "QCSpikeDial", "LeftButton")
        say("bound " .. arg:upper() .. " to the spike dial: hold, flick N/E/S/W, release")
    elseif cmd == "unbind" then
        if InCombatLockdown() then say("leave combat first") return end
        ClearOverrideBindings(panel)
        say("bindings cleared")
    elseif cmd == "echo" then
        echoOn = arg == "on"
        say("echo " .. (echoOn and "on" or "off"))
    elseif cmd == "" then
        if InCombatLockdown() then say("leave combat first") return end
        panel:SetShown(not panel:IsShown())
    else
        say("usage: /qcs | where | rebake | bind KEY | unbind | echo on|off")
    end
end
```

- [ ] **Step 3: Install it into the WoW AddOns folder and check that it loads**

Run:
```bash
cp -r _dev/QCSpike "/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/"
```
Then in game: `/reload` and `/qcs`.
Expected: the panel appears, with 8 channel buttons, G, the tab pad, and the lockdown/combat status line. No Lua error.

If loading raises an error:
- **Inside a `SecureHandlerWrapScript` body:** note the exact error text. It is itself the C5/C7/C8 answer.
- **Anywhere else:** fix it before testing.

- [ ] **Step 4: Commit the harness**

```bash
git add _dev/QCSpike
git commit -m "Dev: in-game check harness for C1-C9 (not shipped)"
```

---

### Task 3: Run C1–C9 in game and apply the outcomes (owner, in game)

**Files:**
- Create: `docs/brainstorm/go-no-go/round-4-build-checks.md`
- Modify: `docs/brainstorm/go-no-go/README.md` (add a link to round 4)
- Modify: `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`. For each check that fails, apply the "If it fails" fallback written in the spec (§9.2, §10.2, §11.2, §8.2, §8.4).
- Modify: `defaults/BuiltIns_Battlegrounds.lua` (Task 12) **if** `/qcs where` shows different battleground instanceIDs. If Task 12 isn't done yet, record the IDs for it.

**Interfaces:**
- Consumes: the Task 2 harness.
- Produces: a pass/fail for each of C1–C9, plus confirmed battleground instanceIDs.

- [ ] **Step 1: Run each check in the context it needs**

| Check | Where | How | Pass when |
|---|---|---|---|
| C1 | premade raid boss | press RAID and RW | both messages arrive |
| C2 | dungeon or raid boss, and the open world | press S, Y and W%t (with a target in the instance) | S and Y are blocked in the boss and sent outside it. W%t whispers the target. |
| C3 | a real battleground and a real arena | press I (BG) and P (arena) | both arrive |
| C4 | M+ key, between pulls | `/qcs rebake`, then press P | the new text arrives |
| C5 | a boss | press G 4 times inside 1 s | no Lua error, and at most one send per second |
| C6 | anywhere, grouped | `/qcs echo on`, then press P | the sender is printed, readable or SECRET |
| C7 | a boss | `/qcs bind G`, then hold G, flick, release | each direction sends N/E/S/W, and a short tap sends nothing |
| C8 | a boss | wheel over the tab pad, then press its button | the tab swaps in combat and the visible tab sends |
| C9 | anywhere, grouped | set a focus, press %f | the focus name expands |

In any battleground, also run `/qcs where`, and record the battleground's name and instanceID.

- [ ] **Step 2: Write the round-4 record**

Create `docs/brainstorm/go-no-go/round-4-build-checks.md`, using this skeleton:
```markdown
# Round 4: build-time checks C1–C9 (<date>)

| Check | Context | Result | Raw output |
|---|---|---|---|
| C1 /raid + /rw | | | |
| C2 say/yell/whisper | | | |
| C3 battleground + arena | | | |
| C4 rebake between pulls | | | |
| C5 guard snippet | | | |
| C6 echo sender readable | | | |
| C7 secure dial | | | |
| C8 pad tabs in combat | | | |
| C9 %f | | | |

## Battleground instance IDs seen

| Battleground | instanceID |
|---|---|

## Consequences for the spec
```

Fill in every row from the owner's results, quoting the chat output exactly. Then link the file from `docs/brainstorm/go-no-go/README.md`.

- [ ] **Step 3: Apply the fallbacks to the spec**

For each failed check, edit the named spec section so the fallback becomes the plan of record:
- **C5 fails:** §9.2. No guard in combat; dimming plus drop notes only.
- **C7 fails:** §11.2. Relaxed mode only.
- **C8 fails:** §10.2. Tabs refused in combat; sections are the default.
- **C1 or C3 fails:** §8.4. Lock that channel during encounters.
- **C2 whisper fails:** a patch note in §8.2. Whispers still ship (P5).

- [ ] **Step 4: Commit**

```bash
git add docs/
git commit -m "Record build-time checks C1-C9 and apply spec fallbacks"
```

---

## Phase 1: core data, headlessly tested

### Task 4: The bus catalog

**Files:**
- Modify: `core/Bus.lua` (the scaffold's `MSG` table)
- Create: `tests/test_bus.lua`
- Modify: `tests/run.lua` (add `"test_bus"` after `"test_harness"`)

**Interfaces:**
- Produces: `NS.MSG.SITUATION_CHANGED`, `RESTRICTION_CHANGED`, `LIBRARY_CHANGED`, `ACTIVE_GROUPS_CHANGED`, `SURFACE_REBUILT`, `SEND_RESULT`, `COMBAT_QUEUE_DRAINED`, `PROFILE_CHANGED`, `TEST_MODE_CHANGED` (spec §17).

- [ ] **Step 1: Write the failing test**

`tests/test_bus.lua`:
```lua
-- tests/test_bus.lua — core/Bus.lua: the message catalog of spec §17, one name each, all prefixed.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local EXPECTED = {
    SITUATION_CHANGED     = "Ka0s_QuickComms_SituationChanged",
    RESTRICTION_CHANGED   = "Ka0s_QuickComms_RestrictionChanged",
    LIBRARY_CHANGED       = "Ka0s_QuickComms_LibraryChanged",
    ACTIVE_GROUPS_CHANGED = "Ka0s_QuickComms_ActiveGroupsChanged",
    SURFACE_REBUILT       = "Ka0s_QuickComms_SurfaceRebuilt",
    SEND_RESULT           = "Ka0s_QuickComms_SendResult",
    COMBAT_QUEUE_DRAINED  = "Ka0s_QuickComms_CombatQueueDrained",
    PROFILE_CHANGED       = "Ka0s_QuickComms_ProfileChanged",
    TEST_MODE_CHANGED     = "Ka0s_QuickComms_TestModeChanged",
}

test("bus: every spec §17 message is declared with its exact name", function()
    local NS = T.newAddon()
    for key, name in pairs(EXPECTED) do assertEqual(NS.MSG[key], name, key) end
end)

test("bus: no two constants share a name", function()
    local NS = T.newAddon()
    local seen = {}
    for key in pairs(EXPECTED) do
        local name = NS.MSG[key]
        assertTrue(not seen[name], "duplicate " .. tostring(name))
        seen[name] = true
    end
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_bus",` after `"test_harness",` in `tests/run.lua`.
Run: `lua tests/run.lua`
Expected: FAIL in `test_bus`, with `SITUATION_CHANGED: expected "Ka0s_QuickComms_SituationChanged", got nil`. The exact wording comes from the kit's assertEqual.

- [ ] **Step 3: Declare the catalog**

In `core/Bus.lua`, replace the scaffold's `MSG` table body with:
```lua
-- The catalog of design spec §17. Each line names its one sender. Payloads and consumers:
-- docs/ARCHITECTURE.md -> Message Bus.
local MSG = {
    SITUATION_CHANGED     = "Ka0s_QuickComms_SituationChanged",     -- modules/Situation.lua
    RESTRICTION_CHANGED   = "Ka0s_QuickComms_RestrictionChanged",   -- modules/Restrictions.lua
    LIBRARY_CHANGED       = "Ka0s_QuickComms_LibraryChanged",       -- modules/Library.lua
    ACTIVE_GROUPS_CHANGED = "Ka0s_QuickComms_ActiveGroupsChanged",  -- modules/Surfaces.lua (phase 2)
    SURFACE_REBUILT       = "Ka0s_QuickComms_SurfaceRebuilt",       -- modules/Surfaces.lua (phase 2)
    SEND_RESULT           = "Ka0s_QuickComms_SendResult",           -- modules/SendEngine.lua (phase 2)
    COMBAT_QUEUE_DRAINED  = "Ka0s_QuickComms_CombatQueueDrained",   -- modules/SendEngine.lua (phase 2)
    PROFILE_CHANGED       = "Ka0s_QuickComms_ProfileChanged",       -- core/Database.lua
    TEST_MODE_CHANGED     = "Ka0s_QuickComms_TestModeChanged",      -- modules/Preview.lua (phase 2)
}
```
If the scaffold already declared `PROFILE_CHANGED` (or a similarly named constant) elsewhere, keep the single declaration here, and point the scaffold's sender at `NS.MSG.PROFILE_CHANGED`.

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, 0 warnings / 0 errors.

- [ ] **Step 5: Commit**

```bash
git add core/Bus.lua tests/test_bus.lua tests/run.lua
git commit -m "Bus: declare the spec §17 message catalog"
```

---

### Task 5: Profile defaults, the Behavior rows, and the schema-version step

**Files:**
- Modify: `defaults/Profile.lua`
- Modify: `settings/SchemaRows.lua`, or wherever the scaffold declares rows (`grep -rn "MasterControls" settings/`). The Behavior rows go there.
- Modify: `core/Database.lua` (`NS.MIGRATIONS`)
- Create: `tests/test_profile.lua`
- Modify: `tests/run.lua` (add `"test_profile"` after `"test_database"`, or after `"test_bus"` if the scaffold has no `test_database`)

**Interfaces:**
- Produces:
  - `NS.C.PROFILE` gains `behavior`, `nextId`, `callouts`, `groups`, `builtins`, `pads`, `dials`, `padOrder`, `dialOrder`, `seeded` (spec §5.1).
  - The schema rows `behavior.soloFallback`, `behavior.spamGuard`, `behavior.dropNotes`, `behavior.whyTooltips`, `behavior.lockdownChip`, `behavior.sounds`, `behavior.autoPromote`, all on page `general`, group `L["Behavior"]`.
  - `NS.SCHEMA_VERSION == 1`.

- [ ] **Step 1: Write the failing test**

`tests/test_profile.lua`:
```lua
-- tests/test_profile.lua — defaults/Profile.lua and the Behavior rows (spec §5.1).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("profile: behavior defaults match spec §5.1", function()
    local NS = T.bootAddon()
    local b = NS.db.profile.behavior
    assertEqual(b.soloFallback, "none")
    assertEqual(b.spamGuard, 1.0)
    assertEqual(b.dropNotes, true)
    assertEqual(b.whyTooltips, true)
    assertEqual(b.lockdownChip, true)
    assertEqual(b.sounds, false)
    assertEqual(b.autoPromote, false)
end)

test("profile: the collections start empty and the id counter at 1", function()
    local NS = T.bootAddon()
    local p = NS.db.profile
    assertEqual(p.nextId, 1)
    for _, key in ipairs({ "callouts", "groups", "builtins", "pads", "dials", "padOrder", "dialOrder" }) do
        assertEqual(type(p[key]), "table", key)
    end
end)

test("profile: every behavior row resolves through the seam", function()
    local NS = T.bootAddon()
    assertEqual(NS.Setting("behavior.spamGuard"), 1.0)
    NS.SchemaRuntime.Set("behavior.spamGuard", 1.5)
    assertEqual(NS.Setting("behavior.spamGuard"), 1.5)
    NS.SchemaRuntime.Set("behavior.soloFallback", "say")
    assertEqual(NS.Setting("behavior.soloFallback"), "say")
end)

test("profile: the spam guard clamps to 0.6-2.0 and fallback refuses unknown values", function()
    local NS = T.bootAddon()
    NS.SchemaRuntime.Set("behavior.spamGuard", 9)
    assertTrue(NS.Setting("behavior.spamGuard") <= 2.0, "clamped high")
    NS.SchemaRuntime.Set("behavior.soloFallback", "guild")
    assertEqual(NS.Setting("behavior.soloFallback"), "none")
end)

test("profile: schema version target is 1", function()
    local NS = T.bootAddon()
    assertEqual(NS.SCHEMA_VERSION, 1)
    assertEqual(NS.db.global.schemaVersion, 1)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_profile",` to `tests/run.lua`.
Run: `lua tests/run.lua`
Expected: FAIL in `test_profile` (`behavior` is nil).

- [ ] **Step 3: Add the defaults**

In `defaults/Profile.lua`, inside the profile defaults table, add:
```lua
    behavior = {
        soloFallback = "none",   -- "none" | "self" | "say": smart channels when solo (spec §8.2)
        spamGuard    = 1.0,      -- seconds between any two sends, 0.6-2.0 (spec §9.2, D12)
        dropNotes    = true,     -- the [QC] chat note when a drop is inferred (spec §9.3)
        whyTooltips  = true,
        lockdownChip = true,     -- shown only when lockdown affects a visible callout (spec §8.4)
        sounds       = false,
        autoPromote  = false,    -- narrower When floats up within a surface's order (spec §7)
    },
    -- The registry (spec §5.1). Library (modules/Library.lua) is the ONLY writer of these keys.
    nextId    = 1,
    callouts  = {},   -- empty is deliberate: a fresh profile has no user callouts
    groups    = {},
    builtins  = {},   -- overlay on the shipped sets: { [groupId] = { enabled, hidden = {} } }
    pads      = {},
    dials     = {},
    padOrder  = {},
    dialOrder = {},
    seeded    = false, -- set by Library.Prepare once the default pad and dial exist
```

- [ ] **Step 4: Add the Behavior rows**

In the scaffold's row file, using its row shape (`path`, `type`, `default`, `label`, `desc`, `group`, `page`, `values`, `min`, `max`, `step`, `validate`), append:
```lua
local B = NS.C.PROFILE.behavior
local BEHAVIOR = L["Behavior"]
local FALLBACKS = { "none", "self", "say" }
local function oneOf(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return function(v) return set[v] == true end
end

AddRows({
    { path = "behavior.soloFallback", type = "string", default = B.soloFallback, page = "general",
      group = BEHAVIOR, label = L["When you are solo"],
      desc = L["What a Smart group or Smart lead callout does when you are not in a group."],
      values = { { value = "none", text = L["Do nothing"] }, { value = "self", text = L["Print to me"] },
                 { value = "say", text = L["Send to Say"] } },
      validate = oneOf(FALLBACKS) },
    { path = "behavior.spamGuard", type = "number", default = B.spamGuard, page = "general",
      group = BEHAVIOR, label = L["Spam guard (seconds)"],
      desc = L["Shortest time between any two callouts. Bosses silently drop messages sent faster than about a second apart."],
      min = 0.6, max = 2.0, step = 0.1 },
    { path = "behavior.dropNotes", type = "bool", default = B.dropNotes, page = "general",
      group = BEHAVIOR, label = L["Note dropped callouts in chat"],
      desc = L["Print a one-line note when a callout seems to have been dropped by the game."] },
    { path = "behavior.whyTooltips", type = "bool", default = B.whyTooltips, page = "general",
      group = BEHAVIOR, label = L["Explain why groups show"],
      desc = L["Show which conditions matched in the pad and dial tooltips."] },
    { path = "behavior.lockdownChip", type = "bool", default = B.lockdownChip, page = "general",
      group = BEHAVIOR, label = L["Show the lockdown chip"],
      desc = L["Show LOCKDOWN on a pad or dial when lockdown is blocking one of its callouts."] },
    { path = "behavior.sounds", type = "bool", default = B.sounds, page = "general",
      group = BEHAVIOR, label = L["Play a sound on send"], desc = L["A short sound when a callout is sent."] },
    { path = "behavior.autoPromote", type = "bool", default = B.autoPromote, page = "general",
      group = BEHAVIOR, label = L["Promote specific groups"],
      desc = L["Groups for a specific dungeon or battleground move above general ones on each pad and dial."] },
})
```
`AddRows` is whatever the scaffold's row file uses to append rows. DropWatcher uses `NS.SchemaRuntime.AddRows(rows)`. If the scaffold already defines `oneOf`, use it and don't redefine it.

Add every new `L[...]` key to `locales/enUS.lua`, with each key's value equal to the key.

- [ ] **Step 5: Set the migration steps**

In `core/Database.lua`:
```lua
NS.MIGRATIONS = {
    { to = 1, run = function() end },   -- 0 -> 1: the stamp itself; v0.1.0 has nothing to reshape
}
NS.SCHEMA_VERSION = NS.MIGRATIONS[#NS.MIGRATIONS].to
```
(Keep the runner as the scaffold wrote it.)

- [ ] **Step 6: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add defaults/Profile.lua settings/ core/Database.lua locales/enUS.lua tests/test_profile.lua tests/run.lua
git commit -m "Profile: spec §5.1 data model defaults and the Behavior rows"
```

---

### Task 6: Compat readers and the situation engine

**Files:**
- Create: `core/Compat.lua`, unless the scaffold created it; if it did, add to it
- Create: `modules/Situation.lua`
- Create: `tests/test_situation.lua`
- Modify: `QuickComms.toc`:
  - `core\Compat.lua` goes after `core\CoreSetup.lua`, with the comment `# LOAD-BEARING: NS.Compat, read by modules at call time; needs NS.SafeToString`
  - `modules\Situation.lua` goes first in `# Modules`, with `# Conventional:`
- Modify: `tests/run.lua` (add `"test_compat"` and `"test_situation"`)
- Create: `tests/test_compat.lua`

**Interfaces:**
- Produces:
  - **Compat secret guards:** `NS.Compat.IsSecret(v) -> bool`, `NS.Compat.IsSafeKey(v) -> bool`, `NS.Compat.PlainNumber(v) -> number|nil`, `NS.Compat.PlainString(v) -> string|nil`.
  - **Compat readers:** `NS.Compat.InstanceInfo() -> inInstance:boolean, instanceType:string|nil, difficultyID:number|nil, instanceID:number|nil`, `NS.Compat.ActiveKeystone() -> active:boolean, level:number|nil, challengeMapID:number|nil`, `NS.Compat.GroupShape() -> inGroup, inRaid, inInstanceGroup`, `NS.Compat.Leadership() -> isLeader, isAssist`, `NS.Compat.PlayerIdentity() -> classFile, specID, role, character`, `NS.Compat.InHousing() -> boolean`, `NS.Compat.InCombat() -> boolean`.
  - **Situation:** `NS.Situation.Classify(inputs) -> snapshot`, `NS.Situation.Signature(snapshot) -> string`, `NS.Situation.ReadInputs() -> inputs`, `NS.Situation.RefreshNow(reason) -> changed:boolean`, `NS.Situation.Refresh(reason)` (coalesced, 0.1 s), and `NS.Situation.Current() -> snapshot`.
  - **Message:** `SITUATION_CHANGED (snapshot, previous)` (spec §6).
  - **Snapshot fields:** `content`, `instanceID`, `difficultyID`, `difficulty`, `keyLevel`, `challengeMapID`, `group`, `instanceGroup`, `leader`, `assist`, `classFile`, `specID`, `role`, `character`, `inCombat`, `lockdown`.
- Consumes: `NS.Restrictions.ActiveSet()` **if present** (Task 7), for `snapshot.lockdown`.

- [ ] **Step 1: Write the failing Compat test**

`tests/test_compat.lua`:
```lua
-- tests/test_compat.lua — core/Compat.lua: secret guards and readers return plain values or nil.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertNil, T.assertTrue, T.assertFalse

test("compat: plain readers pass plain values and drop secrets", function()
    local NS = T.newAddon()
    local C = NS.Compat
    assertEqual(C.PlainNumber(5), 5)
    assertNil(C.PlainNumber("5"))
    assertNil(C.PlainNumber(T.secret(5)))
    assertEqual(C.PlainString("party"), "party")
    assertNil(C.PlainString(T.secret("party")))
    assertFalse(C.IsSafeKey(nil))
    assertFalse(C.IsSafeKey(T.secret(1)))
    assertTrue(C.IsSafeKey(1))
end)

test("compat: InstanceInfo with a secret instanceID reads nil, never raises", function()
    local NS, env = T.newAddon()
    env.IsInInstance = function() return true, "party" end
    env.GetInstanceInfo = function() return "X", "party", 8, "Mythic Keystone", 5, 0, false, T.secret(2526) end
    local inInstance, itype, diff, id = NS.Compat.InstanceInfo()
    assertTrue(inInstance)
    assertEqual(itype, "party")
    assertEqual(diff, 8)
    assertNil(id)
end)

test("compat: InstanceInfo during a loading screen (all nil) reads safely", function()
    local NS, env = T.newAddon()
    env.IsInInstance = function() return nil end
    env.GetInstanceInfo = function() return nil end
    local inInstance, itype, diff, id = NS.Compat.InstanceInfo()
    assertFalse(inInstance)
    assertNil(itype) assertNil(diff) assertNil(id)
end)
```

- [ ] **Step 2: Write the failing Situation test**

`tests/test_situation.lua`:
```lua
-- tests/test_situation.lua — modules/Situation.lua (spec §6): the classifier's truth table, the
-- signature, the edge (secret and loading-screen safety), coalescing and the message.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function inputs(over)
    local i = { inInstance = false, inGroup = false, inRaid = false, inInstanceGroup = false }
    for k, v in pairs(over or {}) do i[k] = v end
    return i
end

local TRUTH = {
    { "open world solo",     inputs(),                                                    "openWorld",    "solo" },
    { "open world party",    inputs({ inGroup = true }),                                  "openWorld",    "party" },
    { "heroic dungeon",      inputs({ inInstance = true, instanceType = "party", difficultyID = 2, inGroup = true }), "dungeon", "party" },
    { "M+ by flag",          inputs({ inInstance = true, instanceType = "party", difficultyID = 23, keystoneActive = true, inGroup = true }), "mythicPlus", "party" },
    { "M+ by difficulty",    inputs({ inInstance = true, instanceType = "party", difficultyID = 8, inGroup = true }), "mythicPlus", "party" },
    { "LFR",                 inputs({ inInstance = true, instanceType = "raid", difficultyID = 17, inGroup = true, inRaid = true, inInstanceGroup = true }), "raid", "raid" },
    { "delve",               inputs({ inInstance = true, instanceType = "scenario", difficultyID = 208 }), "delve", "solo" },
    { "scenario",            inputs({ inInstance = true, instanceType = "scenario" }),    "scenario",     "solo" },
    { "battleground",        inputs({ inInstance = true, instanceType = "pvp", inGroup = true, inRaid = true, inInstanceGroup = true }), "battleground", "raid" },
    { "arena",               inputs({ inInstance = true, instanceType = "arena", inGroup = true, inInstanceGroup = true }), "arena", "party" },
    { "housing",             inputs({ inHousing = true }),                                "housing",      "solo" },
    { "unknown type inside", inputs({ inInstance = true, instanceType = "neighborhood" }), "openWorld",   "solo" },
    { "empty inputs",        {},                                                           "openWorld",    "solo" },
}

test("situation: classifier truth table (content, group)", function()
    local NS = T.newAddon()
    for _, row in ipairs(TRUTH) do
        local s = NS.Situation.Classify(row[2])
        assertEqual(s.content, row[3], row[1] .. " content")
        assertEqual(s.group, row[4], row[1] .. " group")
    end
end)

test("situation: non-table input classifies as open world solo", function()
    local NS = T.newAddon()
    local s = NS.Situation.Classify(nil)
    assertEqual(s.content, "openWorld")
    assertEqual(s.group, "solo")
end)

test("situation: difficulty names by id", function()
    local NS = T.newAddon()
    local function d(id, itype) return NS.Situation.Classify(inputs({ inInstance = true, instanceType = itype, difficultyID = id })).difficulty end
    assertEqual(d(1, "party"), "normal")
    assertEqual(d(2, "party"), "heroic")
    assertEqual(d(23, "party"), "mythic")
    assertEqual(d(8, "party"), "keystone")
    assertEqual(d(205, "party"), "follower")
    assertEqual(d(17, "raid"), "lfr")
    assertEqual(d(14, "raid"), "normal")
    assertEqual(d(15, "raid"), "heroic")
    assertEqual(d(16, "raid"), "mythic")
    assertEqual(d(220, "raid"), "story")
    assertNil(d(999, "party"))
end)

test("situation: key level and map only inside M+", function()
    local NS = T.newAddon()
    local s = NS.Situation.Classify(inputs({ inInstance = true, instanceType = "party", difficultyID = 8, keyLevel = 14, challengeMapID = 556 }))
    assertEqual(s.keyLevel, 14)
    assertEqual(s.challengeMapID, 556)
    local h = NS.Situation.Classify(inputs({ inInstance = true, instanceType = "party", difficultyID = 2, keyLevel = 14 }))
    assertNil(h.keyLevel)
end)

test("situation: signature ignores combat and lockdown", function()
    local NS = T.newAddon()
    local a = NS.Situation.Classify(inputs({ inGroup = true }))
    local b = NS.Situation.Classify(inputs({ inGroup = true, inCombat = true }))
    b.lockdown = { chat = true }
    assertEqual(NS.Situation.Signature(a), NS.Situation.Signature(b))
    local c = NS.Situation.Classify(inputs({ inGroup = true, inRaid = true }))
    assertTrue(NS.Situation.Signature(a) ~= NS.Situation.Signature(c))
end)

test("situation: RefreshNow sends SITUATION_CHANGED only when the signature moves", function()
    local NS = T.enableAddon()
    local sent = {}
    NS.addon.SendMessage = function(_, name, snap) sent[#sent + 1] = { name, snap } end
    NS.Situation.ReadInputs = function() return inputs({ inGroup = true }) end
    assertTrue(NS.Situation.RefreshNow("test"))
    assertFalse(NS.Situation.RefreshNow("test"))
    NS.Situation.ReadInputs = function() return inputs({ inGroup = true, inRaid = true }) end
    assertTrue(NS.Situation.RefreshNow("test"))
    assertEqual(#sent, 2)
    assertEqual(sent[1][1], NS.MSG.SITUATION_CHANGED)
    assertEqual(sent[2][2].group, "raid")
end)

test("situation: Refresh coalesces a burst into one read", function()
    local NS = T.enableAddon()
    local scheduled, reads = {}, 0
    NS.addon.ScheduleTimer = function(_, fn) scheduled[#scheduled + 1] = fn return #scheduled end
    NS.Situation.ReadInputs = function() reads = reads + 1 return inputs() end
    NS.Situation.Refresh("PLAYER_ENTERING_WORLD")
    NS.Situation.Refresh("ZONE_CHANGED_NEW_AREA")
    NS.Situation.Refresh("GROUP_ROSTER_UPDATE")
    assertEqual(#scheduled, 1)
    scheduled[1]()
    assertEqual(reads, 1)
end)

test("situation: ReadInputs survives a loading screen", function()
    local NS, env = T.enableAddon()
    env.IsInInstance = function() return nil end
    env.GetInstanceInfo = function() return nil end
    local s = NS.Situation.Classify(NS.Situation.ReadInputs())
    assertEqual(s.content, "openWorld")
end)
```

- [ ] **Step 3: Run the tests to check they fail**

Add `"test_compat",` and `"test_situation",` to `tests/run.lua`.
Run: `lua tests/run.lua`
Expected: FAIL, because `NS.Compat.PlainNumber` and `NS.Situation` are nil.

- [ ] **Step 4: Write `core/Compat.lua`**

```lua
local _, NS = ...
-- core/Compat.lua — the only caller of version-variant or optional client APIs, and the secret
-- guards (events-frames-taint-§8). Every reader returns plain values or nil, never a secret.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

--- True when `v` is a secret value. Exactly one boolean.
Compat.IsSecret = CompatLib and CompatLib.IsSecret or function(v)
    return issecretvalue ~= nil and issecretvalue(v) and true or false
end

--- True when `v` may be used as a table key: not secret, not nil.
Compat.IsSafeKey = CompatLib and CompatLib.IsSafeKey or function(v)
    if Compat.IsSecret(v) then return false end
    return v ~= nil
end

--- A plain number, or nil.
function Compat.PlainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

--- A plain string, or nil.
function Compat.PlainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local PlainNumber, PlainString = Compat.PlainNumber, Compat.PlainString

local function plainTrue(v)
    if Compat.IsSecret(v) then return false end
    return v == true
end

--- inInstance, instanceType, difficultyID, instanceID. Safe during loading screens.
function Compat.InstanceInfo()
    local inInstance = IsInInstance and IsInInstance()
    if not GetInstanceInfo then return plainTrue(inInstance), nil, nil, nil end
    local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    return plainTrue(inInstance), PlainString(instanceType), PlainNumber(difficultyID), PlainNumber(instanceID)
end

--- active, keystone level, challenge map id.
function Compat.ActiveKeystone()
    local cm = C_ChallengeMode
    if not cm then return false, nil, nil end
    local active = cm.IsChallengeModeActive and plainTrue(cm.IsChallengeModeActive()) or false
    local level = cm.GetActiveKeystoneInfo and PlainNumber((cm.GetActiveKeystoneInfo())) or nil
    local map = cm.GetActiveChallengeMapID and PlainNumber(cm.GetActiveChallengeMapID()) or nil
    return active, level, map
end

--- inGroup, inRaid, inInstanceGroup.
function Compat.GroupShape()
    local inGroup = IsInGroup and plainTrue(IsInGroup()) or false
    local inRaid = IsInRaid and plainTrue(IsInRaid()) or false
    local instanceCategory = LE_PARTY_CATEGORY_INSTANCE
    local inInstanceGroup = instanceCategory ~= nil and IsInGroup and plainTrue(IsInGroup(instanceCategory)) or false
    return inGroup, inRaid, inInstanceGroup
end

--- isLeader, isAssist.
function Compat.Leadership()
    local leader = UnitIsGroupLeader and plainTrue(UnitIsGroupLeader("player")) or false
    local assist = UnitIsGroupAssistant and plainTrue(UnitIsGroupAssistant("player")) or false
    return leader, assist
end

local function specIndex()
    local si = C_SpecializationInfo
    if si and si.GetSpecialization then return PlainNumber(si.GetSpecialization()) end
    if GetSpecialization then return PlainNumber(GetSpecialization()) end
    return nil
end

local function specInfo(index)
    if not index then return nil, nil end
    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not get then return nil, nil end
    local id, _, _, _, role = get(index)
    return PlainNumber(id), PlainString(role)
end

--- classFile, specID, role (TANK/HEALER/DAMAGER or nil), character ("Name-Realm" or nil).
function Compat.PlayerIdentity()
    local classFile = UnitClass and PlainString(select(2, UnitClass("player"))) or nil
    local specID, specRole = specInfo(specIndex())
    local role = UnitGroupRolesAssigned and PlainString(UnitGroupRolesAssigned("player")) or nil
    if role == nil or role == "NONE" then role = specRole end
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name, realm = PlainString(name), PlainString(realm)
    if not realm and GetNormalizedRealmName then realm = PlainString(GetNormalizedRealmName()) end
    local character = name and realm and (name .. "-" .. realm) or nil
    return classFile, specID, role, character
end

--- True inside a house or plot (housing).
function Compat.InHousing()
    local h = C_Housing
    if not (h and h.IsInsideHouseOrPlot) then return false end
    return plainTrue(h.IsInsideHouseOrPlot())
end

--- True in combat lockdown.
function Compat.InCombat()
    return InCombatLockdown ~= nil and InCombatLockdown() == true
end
```

- [ ] **Step 5: Write `modules/Situation.lua`**

```lua
local _, NS = ...
-- modules/Situation.lua — the situation snapshot (spec §6). The classifier, Classify(inputs) ->
-- snapshot, is PURE: a plain table in, a plain table out, never throws. ReadInputs is the edge:
-- the only place this module reads the client, all through NS.Compat. Refresh coalesces event
-- bursts into one read 0.1 s later and sends SITUATION_CHANGED (snapshot, previous) only when the
-- signature moves. inCombat and lockdown ride along for display and never move the signature.

NS.Situation = NS.Situation or {}
local Sit = NS.Situation
local State = NS.State

local TAG = "Situation"
local COALESCE = 0.1

-- difficultyID -> the When editor's difficulty value (spec §5.3). Unknown ids read as nil.
local DIFFICULTY = {
    [1] = "normal", [2] = "heroic", [23] = "mythic", [8] = "keystone", [205] = "follower",
    [14] = "normal", [15] = "heroic", [16] = "mythic", [17] = "lfr", [7] = "lfr", [220] = "story",
}
Sit.DIFFICULTY = DIFFICULTY
local KEYSTONE, DELVE = 8, 208

local function content(i)
    local t = i.instanceType
    if t == "arena" then return "arena" end
    if t == "pvp" then return "battleground" end
    if i.keystoneActive or i.difficultyID == KEYSTONE then return "mythicPlus" end
    if i.inHousing then return "housing" end
    if not i.inInstance then return "openWorld" end
    if i.difficultyID == DELVE then return "delve" end
    if t == "party" then return "dungeon" end
    if t == "raid" then return "raid" end
    if t == "scenario" then return "scenario" end
    return "openWorld"
end

local function group(i)
    if i.inRaid then return "raid" end
    if i.inGroup then return "party" end
    return "solo"
end

--- The snapshot for a set of inputs (spec §6). Pure.
--- @param i table|any inputs from ReadInputs (or a test)
--- @return table snapshot
function Sit.Classify(i)
    if type(i) ~= "table" then i = {} end
    local c = content(i)
    local mplus = c == "mythicPlus"
    return {
        content        = c,
        instanceID     = i.instanceID,
        difficultyID   = i.difficultyID,
        difficulty     = DIFFICULTY[i.difficultyID],
        keyLevel       = mplus and i.keyLevel or nil,
        challengeMapID = mplus and i.challengeMapID or nil,
        group          = group(i),
        instanceGroup  = i.inInstanceGroup == true,
        leader         = i.isLeader == true,
        assist         = i.isAssist == true,
        classFile      = i.classFile,
        specID         = i.specID,
        role           = i.role,
        character      = i.character,
        inCombat       = i.inCombat == true,
        lockdown       = {},
    }
end

local SIGNATURE_FIELDS = { "content", "instanceID", "difficulty", "keyLevel", "challengeMapID", "group",
    "instanceGroup", "leader", "assist", "classFile", "specID", "role", "character" }

--- The fields that decide which groups are active, joined. Combat and lockdown are left out.
--- @param s table snapshot
--- @return string
function Sit.Signature(s)
    local parts = {}
    for n, field in ipairs(SIGNATURE_FIELDS) do parts[n] = tostring(s[field]) end
    return table.concat(parts, "|")
end

--- The classifier inputs, read now. Read-only; safe in combat and stood down.
--- @return table inputs
function Sit.ReadInputs()
    local C = NS.Compat
    local inInstance, instanceType, difficultyID, instanceID = C.InstanceInfo()
    local keystoneActive, keyLevel, challengeMapID = C.ActiveKeystone()
    local inGroup, inRaid, inInstanceGroup = C.GroupShape()
    local isLeader, isAssist = C.Leadership()
    local classFile, specID, role, character = C.PlayerIdentity()
    return {
        inInstance = inInstance, instanceType = instanceType, difficultyID = difficultyID,
        instanceID = instanceID, keystoneActive = keystoneActive, keyLevel = keyLevel,
        challengeMapID = challengeMapID, inGroup = inGroup, inRaid = inRaid,
        inInstanceGroup = inInstanceGroup, isLeader = isLeader, isAssist = isAssist,
        classFile = classFile, specID = specID, role = role, character = character,
        inHousing = C.InHousing(), inCombat = C.InCombat(),
    }
end

local function withLockdown(s)
    local R = NS.Restrictions
    if R and R.ActiveSet then
        local set = R.ActiveSet()
        s.lockdown = {
            chat = set.chat == true or set.chatLockdown == true, encounter = set.encounter == true,
            challengeMode = set.challengeMode == true, pvpMatch = set.pvpMatch == true,
        }
    end
    return s
end

--- Read, classify, and publish when the signature moved.
--- @param reason string|nil for the debug line
--- @return boolean changed
function Sit.RefreshNow(reason)
    State.situationPending = nil
    local snap = withLockdown(Sit.Classify(Sit.ReadInputs()))
    local sig = Sit.Signature(snap)
    local prev = State.situation
    State.situation = snap
    if sig == State.situationSignature then return false end
    State.situationSignature = sig
    NS.Debug(TAG, "%s -> %s/%s (%s)", prev and prev.content or "none", snap.content, snap.group, tostring(reason))
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED, snap, prev)
    return true
end

--- Coalesced refresh: a burst of events within 0.1 s gives one read.
function Sit.Refresh(reason)
    if State.situationPending then return end
    State.situationPending = true
    NS.addon:ScheduleTimer(function() Sit.RefreshNow(reason) end, COALESCE)
end

--- The current snapshot, classified live (without a message) before the first refresh.
function Sit.Current()
    return State.situation or withLockdown(Sit.Classify(Sit.ReadInputs()))
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_DIFFICULTY_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ROLES_ASSIGNED",
}
for _, event in ipairs(EVENTS) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSituationEvent" }
end

function NS.addon.OnSituationEvent(_, event)
    Sit.Refresh(event)
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.situation, State.situationSignature, State.situationPending = nil, nil, nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function() Sit.RefreshNow("standUp") end
```

- [ ] **Step 6: Add the TOC lines**

In `QuickComms.toc`:
- Under `# Core`, after `core\CoreSetup.lua`:
```
core\Compat.lua            # LOAD-BEARING: NS.Compat; needs LibKa0s-Compat (optional) and NS.SafeToString
```
- First under `# Modules`:
```
modules\Situation.lua      # Conventional: feature module; appends to NS.FEATURE_EVENTS / STAND_DOWN / STAND_UP
```

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

If `T.enableAddon` doesn't hand back `env` as its second return, use `local NS, env = T.enableAddon()`. In DropWatcher's factories, `env` and the mock are the same table.

- [ ] **Step 8: Commit**

```bash
git add core/Compat.lua modules/Situation.lua tests/test_compat.lua tests/test_situation.lua tests/run.lua QuickComms.toc
git commit -m "Situation: snapshot classifier, Compat readers, coalesced refresh"
```

---

### Task 7: Restrictions tracker (copied from DropWatcher)

**Files:**
- Modify: `core/Compat.lua` (add the restriction readers)
- Create: `modules/Restrictions.lua` (copied, then adapted)
- Create: `tests/test_restrictions.lua` (copied, then adapted)
- Modify: `QuickComms.toc` (`modules\Restrictions.lua` before `modules\Situation.lua`, with `# Conventional:`), and `tests/run.lua` (add `"test_restrictions"` before `"test_situation"`)

**Interfaces:**
- Produces:
  - `NS.Restrictions.ActiveSet() -> { [reason]=true }`, where the reasons are `encounter`, `challengeMode`, `pvpMatch`, `chat`, `chatLockdown`, `combat` and `map`
  - `NS.Restrictions.CanSendChat() -> boolean`
  - `NS.Restrictions.Refresh(cause)`
  - message `RESTRICTION_CHANGED (reason, canSendChat)`. This is DropWatcher's payload; the spec §17 table is corrected to it in Step 6.
- Consumes: `NS.Compat.IsSecret`, `IsSafeKey`, `PlainNumber` (Task 6).

- [ ] **Step 1: Copy the readers into Compat**

Append to `core/Compat.lua`:
```lua
-- ── Restrictions (12.0), copied from DropWatcher core/Compat.lua:215-266 ───────────────────

--- True while the chat-messaging lockdown is in effect. A secret answer reads as locked.
function Compat.InChatMessagingLockdown()
    local chat = C_ChatInfo
    if not (chat and chat.InChatMessagingLockdown) then return false end
    local locked = chat.InChatMessagingLockdown()
    if Compat.IsSecret(locked) then return true end
    return locked == true
end

--- Enum.AddOnRestrictionType (name -> value), or an empty table.
function Compat.RestrictionTypes()
    local enum = Enum and Enum.AddOnRestrictionType
    return type(enum) == "table" and enum or {}
end

--- True when a restriction STATE is not Inactive. Boolean payloads answer themselves; secret is active.
function Compat.IsRestrictionStateActive(state)
    if Compat.IsSecret(state) then return true end
    if type(state) == "boolean" then return state end
    local n = PlainNumber(state)
    if n == nil then return false end
    local enum = Enum and Enum.AddOnRestrictionState
    local inactive = enum and PlainNumber(enum.Inactive) or 0
    return n ~= inactive
end

--- True while restriction `rtype` is in effect.
function Compat.IsRestrictionActive(rtype)
    local ra = C_RestrictedActions
    if not ra or rtype == nil then return false end
    if ra.IsAddOnRestrictionActive then
        local active = ra.IsAddOnRestrictionActive(rtype)
        if Compat.IsSecret(active) then return true end
        return active == true
    end
    if ra.GetAddOnRestrictionState then
        return Compat.IsRestrictionStateActive(ra.GetAddOnRestrictionState(rtype))
    end
    return false
end
```

- [ ] **Step 2: Copy and adapt the module and its tests**

Run:
```bash
cp ../DropWatcher/modules/Restrictions.lua modules/Restrictions.lua
cp ../DropWatcher/tests/test_restrictions.lua tests/test_restrictions.lua
sed -i 's/_G\.DW_TEST/_G.QUICKCOMMS_TEST/; s/Drop Watcher/Quick Comms/g; s/DropWatcher/QuickComms/g; s/core\/QuickComms\.lua/core\/QuickComms.lua/' modules/Restrictions.lua tests/test_restrictions.lua
grep -n "design spec §4\|Asks.lua\|window's badge" modules/Restrictions.lua
```

Then make these hand edits to `modules/Restrictions.lua`:
- **Header comment:** replace the DropWatcher spec references ("design spec §4", "the window's badge", "modules/Asks.lua") with Quick Comms ones: "spec §8.4 (the lock matrix) and §9 (the send engine)", "the surfaces' lockdown chip", "phase 2's SendEngine".
- **`R.ActiveSet`:** confirm the function exists. DropWatcher exposes it as `R.ActiveSet()`. If it is local there, publish it: `R.ActiveSet = activeSet`.

In `tests/test_restrictions.lua`, delete any case that reaches a DropWatcher-only module (`NS.Asks`, `NS.Window`, `NS.Toast`). Run:
```
grep -n "Asks\|Window\|Toast\|LootFeed" tests/test_restrictions.lua
```
Expected: no output after the edits.

- [ ] **Step 3: Add the TOC line and the suite**

```
modules\Restrictions.lua   # Conventional: read by Situation at call time; appends to NS.FEATURE_EVENTS
```
Place it **before** `modules\Situation.lua`. Add `"test_restrictions",` to `tests/run.lua` before `"test_situation"`.

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS. If a copied case fails because it relied on a DropWatcher-only mock field, port that field from `../DropWatcher/tests/wow_mock.lua` into `tests/wow_mock.lua`. Copy the same lines; don't rewrite them.

- [ ] **Step 5: Check that Situation picks up lockdown**

Append to `tests/test_situation.lua`:
```lua
test("situation: snapshot.lockdown mirrors Restrictions.ActiveSet", function()
    local NS = T.enableAddon()
    NS.Restrictions.ActiveSet = function() return { encounter = true, chatLockdown = true } end
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    local s = NS.Situation.Current()
    assertTrue(s.lockdown.encounter)
    assertTrue(s.lockdown.chat)
    assertFalse(s.lockdown.pvpMatch)
end)
```
Run: `lua tests/run.lua`
Expected: PASS.

- [ ] **Step 6: Correct the spec's bus row**

In `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md` §17, change the `RESTRICTION_CHANGED` payload cell from "lockdown table" to "reason, canSendChat (consumers read `Restrictions.ActiveSet()`)".

- [ ] **Step 7: Commit**

```bash
git add core/Compat.lua modules/Restrictions.lua tests/test_restrictions.lua tests/test_situation.lua tests/run.lua QuickComms.toc docs/superpowers/specs/
git commit -m "Restrictions: lockdown tracker from DropWatcher; snapshot carries it"
```

---

### Task 8: Tokens

**Files:**
- Create: `modules/Tokens.lua`
- Create: `tests/test_tokens.lua`
- Modify: `QuickComms.toc` (after `modules\Situation.lua`, with `# Conventional: pure`), and `tests/run.lua` (add `"test_tokens"`)

**Interfaces:**
- Produces:
  - `NS.Tokens.Expand(text, ctx) -> out:string, unknown:string[], missing:string[], live:number`, where `ctx = { me, spec, role, key, dungeon, spellLink = function(id) -> string|nil }`
  - `NS.Tokens.UsesGroupToken(text) -> boolean`
  - `NS.Tokens.LIVE_NOMINAL == 12`

- [ ] **Step 1: Write the failing test**

`tests/test_tokens.lua`:
```lua
-- tests/test_tokens.lua — modules/Tokens.lua (spec §8.1): chips to engine tokens and baked values.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function tok() return T.newAddon().Tokens end

test("tokens: target and focus become engine tokens and count as live", function()
    local out, unknown, missing, live = tok().Expand("Kick {target} then {focus}")
    assertEqual(out, "Kick %t then %f")
    assertEqual(#unknown, 0)
    assertEqual(#missing, 0)
    assertEqual(live, 2)
end)

test("tokens: raid markers by number and name, any case", function()
    local Tok = tok()
    assertEqual((Tok.Expand("{rt8} {Skull} {STAR} {x}")), "{rt8} {rt8} {rt1} {rt7}")
end)

test("tokens: group tokens map to {gN}", function()
    local Tok = tok()
    assertEqual((Tok.Expand("{group3} soak, {g1} stack")), "{g3} soak, {g1} stack")
    assertTrue(Tok.UsesGroupToken("stack {group2}"))
    assertTrue(Tok.UsesGroupToken("{g8}"))
    assertFalse(Tok.UsesGroupToken("{rt8}"))
end)

test("tokens: baked values come from ctx; absent ones are missing", function()
    local out, _, missing = tok().Expand("{me} at +{key} in {dungeon} as {spec}/{role}",
        { me = "Traxex", key = 14, dungeon = "Windrunner Spire", spec = "Destruction" })
    assertEqual(out, "Traxex at +14 in Windrunner Spire as Destruction/")
    assertEqual(#missing, 1)
    assertEqual(missing[1], "role")
end)

test("tokens: spell links bake through ctx.spellLink; unknown ids are missing", function()
    local ctx = { spellLink = function(id) if id == 2825 then return "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r" end end }
    local out, _, missing = tok().Expand("{spell:2825} now, {spell:1}", ctx)
    assertEqual(out, "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r now, ")
    assertEqual(missing[1], "spell:1")
end)

test("tokens: unknown chips stay as typed and are reported", function()
    local out, unknown = tok().Expand("{location} help")
    assertEqual(out, "{location} help")
    assertEqual(unknown[1], "location")
end)

test("tokens: non-string text expands to empty", function()
    assertEqual((tok().Expand(nil)), "")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_tokens",` to `tests/run.lua`. Run: `lua tests/run.lua`
Expected: FAIL (`NS.Tokens` is nil).

- [ ] **Step 3: Write `modules/Tokens.lua`**

```lua
local _, NS = ...
-- modules/Tokens.lua — the editor's token chips -> engine tokens and baked values (spec §8.1).
-- PURE: no client call. Live tokens (%t, %f, {rtN}, {gN}) are expanded by the game at send time;
-- baked ones ({me}, {spec}, {role}, {key}, {dungeon}, {spell:ID}) come from `ctx`, which the
-- caller fills out of combat.

NS.Tokens = NS.Tokens or {}
local Tok = NS.Tokens

Tok.LIVE_NOMINAL = 12   -- bytes each live token is assumed to add when sent (spec §8.3)

local ENGINE = { target = "%t", focus = "%f" }
local RT_BY_NAME = { star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6, cross = 7, x = 7, skull = 8 }
local BAKED = { me = true, spec = true, role = true, key = true, dungeon = true }

local function expandOne(raw, ctx, acc)
    local name = raw:lower()
    if ENGINE[name] then acc.live = acc.live + 1 return ENGINE[name] end
    local rt = name:match("^rt([1-8])$") or RT_BY_NAME[name]
    if rt then acc.live = acc.live + 1 return "{rt" .. rt .. "}" end
    local g = name:match("^group([1-8])$") or name:match("^g([1-8])$")
    if g then acc.live = acc.live + 1 return "{g" .. g .. "}" end
    local id = name:match("^spell:(%d+)$")
    if id then
        local link = type(ctx.spellLink) == "function" and ctx.spellLink(tonumber(id)) or nil
        if type(link) == "string" and link ~= "" then return link end
        acc.missing[#acc.missing + 1] = raw
        return ""
    end
    if BAKED[name] then
        local v = ctx[name]
        if v == nil or v == "" then acc.missing[#acc.missing + 1] = raw return "" end
        return tostring(v)
    end
    acc.unknown[#acc.unknown + 1] = raw
    return "{" .. raw .. "}"
end

--- Expand every {chip} in `text`.
--- @param text string|any
--- @param ctx table|nil baked values (see header)
--- @return string out, table unknown, table missing, number live
function Tok.Expand(text, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local acc = { unknown = {}, missing = {}, live = 0 }
    if type(text) ~= "string" then return "", acc.unknown, acc.missing, 0 end
    local out = text:gsub("{([%w:]+)}", function(raw) return expandOne(raw, ctx, acc) end)
    return out, acc.unknown, acc.missing, acc.live
end

--- True when `text` uses a raid-group token, which expands only in a raid (spec §8.1).
function Tok.UsesGroupToken(text)
    if type(text) ~= "string" then return false end
    local lower = text:lower()
    return lower:find("{g[1-8]}") ~= nil or lower:find("{group[1-8]}") ~= nil
end
```

- [ ] **Step 4: Add the TOC line and run the gate**

```
modules\Tokens.lua         # Conventional: pure
```
Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/Tokens.lua tests/test_tokens.lua tests/run.lua QuickComms.toc
git commit -m "Tokens: chips to engine tokens and baked values"
```

---

### Task 9: Channels and the lock matrix

**Files:**
- Create: `modules/Channels.lua`
- Create: `tests/test_channels.lua`
- Modify: `QuickComms.toc` (after Tokens, `# Conventional: pure`), and `tests/run.lua`

**Interfaces:**
- Produces:
  - `NS.Channels.KINDS` (an ordered list)
  - `NS.Channels.IsKind(kind) -> boolean`
  - `NS.Channels.Resolve(kind, snapshot, soloFallback) -> concrete|nil, reason|nil, selfPrint:boolean`
  - `NS.Channels.Prefix(concrete) -> string`
  - `NS.Channels.ChatType(concrete) -> string`
  - `NS.Channels.LockState(concrete, snapshot) -> reason|nil`
  - `NS.Channels.SoftWarning(concrete, snapshot) -> reason|nil`

- [ ] **Step 1: Write the failing test**

`tests/test_channels.lua`:
```lua
-- tests/test_channels.lua — modules/Channels.lua (spec §8.2, §8.4).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertNil, T.assertTrue, T.assertFalse

local function ch() return T.newAddon().Channels end
local function snap(over)
    local s = { group = "solo", instanceGroup = false, leader = false, assist = false, lockdown = {} }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

test("channels: smartGroup prefers instance, then raid, then party", function()
    local Ch = ch()
    assertEqual((Ch.Resolve("smartGroup", snap({ group = "raid", instanceGroup = true }))), "instance")
    assertEqual((Ch.Resolve("smartGroup", snap({ group = "raid" }))), "raid")
    assertEqual((Ch.Resolve("smartGroup", snap({ group = "party" }))), "party")
end)

test("channels: smartGroup solo follows the fallback", function()
    local Ch = ch()
    local c, reason, selfPrint = Ch.Resolve("smartGroup", snap(), "none")
    assertNil(c) assertEqual(reason, "solo") assertFalse(selfPrint)
    c, reason, selfPrint = Ch.Resolve("smartGroup", snap(), "self")
    assertNil(c) assertEqual(reason, "solo") assertTrue(selfPrint)
    assertEqual((Ch.Resolve("smartGroup", snap(), "say")), "say")
end)

test("channels: smartLead is RW for raid leader/assist and in a home party", function()
    local Ch = ch()
    assertEqual((Ch.Resolve("smartLead", snap({ group = "raid", leader = true }))), "raidWarning")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "raid", assist = true }))), "raidWarning")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "raid" }))), "raid")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "party" }))), "raidWarning")
    assertEqual((Ch.Resolve("smartLead", snap({ group = "party", instanceGroup = true }))), "instance")
end)

test("channels: fixed kinds pass through; unknown kinds refuse", function()
    local Ch = ch()
    for _, k in ipairs({ "say", "yell", "party", "raid", "instance", "raidWarning", "whisperTarget", "whisperFocus" }) do
        assertEqual((Ch.Resolve(k, snap())), k, k)
    end
    local c, reason = Ch.Resolve("guild", snap())
    assertNil(c) assertEqual(reason, "badChannel")
end)

test("channels: prefixes and chat types", function()
    local Ch = ch()
    assertEqual(Ch.Prefix("party"), "/p")
    assertEqual(Ch.Prefix("instance"), "/i")
    assertEqual(Ch.Prefix("raidWarning"), "/rw")
    assertEqual(Ch.Prefix("whisperTarget"), "/w %t")
    assertEqual(Ch.Prefix("whisperFocus"), "/w %f")
    assertEqual(Ch.ChatType("instance"), "INSTANCE_CHAT")
    assertEqual(Ch.ChatType("raidWarning"), "RAID_WARNING")
end)

test("channels: the lock matrix", function()
    local Ch = ch()
    assertEqual(Ch.LockState("raid", snap({ group = "party" })), "notInRaid")
    assertNil(Ch.LockState("raid", snap({ group = "raid" })))
    assertEqual(Ch.LockState("raidWarning", snap({ group = "raid" })), "notLeader")
    assertNil(Ch.LockState("raidWarning", snap({ group = "party" })))
    assertEqual(Ch.LockState("raidWarning", snap()), "notInGroup")
    assertEqual(Ch.LockState("party", snap()), "notInGroup")
    assertEqual(Ch.LockState("instance", snap({ group = "party" })), "notInInstanceGroup")
    assertEqual(Ch.LockState("say", snap({ lockdown = { encounter = true } })), "lockdown")
    assertEqual(Ch.LockState("yell", snap({ lockdown = { pvpMatch = true } })), "lockdown")
    assertNil(Ch.LockState("say", snap({ lockdown = { challengeMode = true } })))
    assertNil(Ch.LockState("whisperTarget", snap({ lockdown = { encounter = true } })))
    assertEqual(Ch.SoftWarning("whisperTarget", snap({ lockdown = { chat = true } })), "whisperInstanceOnly")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_channels",` to `tests/run.lua`. Run: `lua tests/run.lua`
Expected: FAIL (`NS.Channels` is nil).

- [ ] **Step 3: Write `modules/Channels.lua`**

```lua
local _, NS = ...
-- modules/Channels.lua — channel kinds -> a concrete channel, its slash prefix, and the lock
-- matrix (spec §8.2, §8.4). PURE. Smart kinds resolve at bake time from the snapshot, because chat
-- slash commands take no macro conditionals (spec P3).

NS.Channels = NS.Channels or {}
local Ch = NS.Channels

Ch.KINDS = { "smartGroup", "smartLead", "party", "raid", "instance", "raidWarning", "say", "yell",
    "whisperTarget", "whisperFocus" }

local PREFIX = {
    say = "/s", yell = "/y", party = "/p", raid = "/raid", instance = "/i", raidWarning = "/rw",
    whisperTarget = "/w %t", whisperFocus = "/w %f",
}
local CHAT_TYPE = {
    say = "SAY", yell = "YELL", party = "PARTY", raid = "RAID", instance = "INSTANCE_CHAT",
    raidWarning = "RAID_WARNING", whisperTarget = "WHISPER", whisperFocus = "WHISPER",
}
local IS_KIND = {}
for _, k in ipairs(Ch.KINDS) do IS_KIND[k] = true end

function Ch.IsKind(kind) return IS_KIND[kind] == true end
function Ch.Prefix(concrete) return PREFIX[concrete] end
function Ch.ChatType(concrete) return CHAT_TYPE[concrete] end

local function smartGroup(s)
    if s.instanceGroup then return "instance" end
    if s.group == "raid" then return "raid" end
    if s.group == "party" then return "party" end
    return nil
end

local function smartLead(s)
    if s.group == "raid" and not s.instanceGroup and (s.leader or s.assist) then return "raidWarning" end
    if s.group == "party" and not s.instanceGroup then return "raidWarning" end
    return smartGroup(s)
end

--- Resolve a kind against a snapshot.
--- @param kind string one of Ch.KINDS
--- @param s table snapshot
--- @param soloFallback string|nil "none" | "self" | "say"
--- @return string|nil concrete, string|nil reason, boolean selfPrint
function Ch.Resolve(kind, s, soloFallback)
    s = type(s) == "table" and s or {}
    if PREFIX[kind] then return kind, nil, false end
    local concrete
    if kind == "smartGroup" then concrete = smartGroup(s)
    elseif kind == "smartLead" then concrete = smartLead(s)
    else return nil, "badChannel", false end
    if concrete then return concrete, nil, false end
    if soloFallback == "say" then return "say", nil, false end
    return nil, "solo", soloFallback == "self"
end

--- Why a concrete channel can't send right now, or nil (spec §8.4). The slot stays visible.
function Ch.LockState(concrete, s)
    s = type(s) == "table" and s or {}
    local lockdown = s.lockdown or {}
    if concrete == "raid" then
        if s.group ~= "raid" then return "notInRaid" end
    elseif concrete == "raidWarning" then
        if s.group == "raid" then
            if not (s.leader or s.assist) then return "notLeader" end
        elseif s.group ~= "party" then
            return "notInGroup"
        end
    elseif concrete == "party" then
        if s.group ~= "party" and s.group ~= "raid" then return "notInGroup" end
    elseif concrete == "instance" then
        if not s.instanceGroup then return "notInInstanceGroup" end
    elseif concrete == "say" or concrete == "yell" then
        if lockdown.encounter or lockdown.pvpMatch then return "lockdown" end
    end
    return nil
end

--- A non-blocking caution (whispers reach only players in the instance during lockdown).
function Ch.SoftWarning(concrete, s)
    if (concrete == "whisperTarget" or concrete == "whisperFocus") and type(s) == "table"
        and s.lockdown and s.lockdown.chat then
        return "whisperInstanceOnly"
    end
    return nil
end
```

- [ ] **Step 4: Add the TOC line and run the gate**

```
modules\Channels.lua       # Conventional: pure
```
Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/Channels.lua tests/test_channels.lua tests/run.lua QuickComms.toc
git commit -m "Channels: smart resolution, prefixes and the lock matrix"
```

---

### Task 10: Bake and the sanitizer (anti-pattern #20)

**Files:**
- Create: `modules/Bake.lua`
- Create: `tests/test_bake.lua`
- Modify: `QuickComms.toc` (after Channels, `# Conventional: pure`), and `tests/run.lua`

**Interfaces:**
- Consumes:
  - `NS.Tokens.Expand`, `NS.Tokens.LIVE_NOMINAL` (Task 8)
  - `NS.Channels.Resolve`, `Prefix`, `LockState`, `SoftWarning` (Task 9)
- Produces:
  - `NS.Bake.MAX_BYTES == 255`
  - `NS.Bake.Sanitize(text) -> clean|nil, reason|nil`
  - `NS.Bake.Length(text, live) -> number`
  - `NS.Bake.Bake(callout, snapshot, opts) -> line|nil, reason|nil, info`, where:
    - `opts = { soloFallback, ctx }`
    - `info = { concrete, length, unknown, missing, lock, warning, selfPrint, text }`

- [ ] **Step 1: Write the failing test**

`tests/test_bake.lua`:
```lua
-- tests/test_bake.lua — modules/Bake.lua (spec §8.3): one macro line, never a command, <= 255 bytes.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil, assertTrue = T.test, T.assertEqual, T.assertNil, T.assertTrue

local function bake() return T.newAddon().Bake end
local PARTY = { group = "party", instanceGroup = false, lockdown = {} }
local function callout(text, channel) return { name = "x", text = text, channel = channel or "smartGroup" } end

test("bake: a plain callout bakes to prefix + text", function()
    local line, reason, info = bake().Bake(callout("Lust on this pack {rt8}"), PARTY)
    assertEqual(line, "/p Lust on this pack {rt8}")
    assertNil(reason)
    assertEqual(info.concrete, "party")
end)

test("bake: [review 1] a leading slash is refused, even after whitespace", function()
    local B = bake()
    for _, t in ipairs({ "/run x()", "  /script y", "\t/dump 1", "\n/cast Fireball" }) do
        local line, reason = B.Bake(callout(t), PARTY)
        assertNil(line, t)
        assertEqual(reason, "startsWithSlash", t)
    end
end)

test("bake: [review 1] newlines and control characters flatten to one line", function()
    local line = bake().Bake(callout("hi\n/script y\r\nok\tthere"), PARTY)
    assertEqual(line, "/p hi /script y ok there")
    assertTrue(not line:find("\n"), "no newline")
end)

test("bake: pipes are escaped, spell links are not", function()
    local ctx = { spellLink = function() return "|cff71d5ff|Hspell:2825|h[Bloodlust]|h|r" end }
    local line = bake().Bake(callout("a|b {spell:2825}"), PARTY, { ctx = ctx })
    assertEqual(line, "/p a||b |cff71d5ff|Hspell:2825|h[Bloodlust]|h|r")
end)

test("bake: [review 2] the 255-byte boundary counts bytes and live tokens", function()
    local B = bake()
    local e = "\195\169"                                   -- é is two bytes
    local ok = callout(string.rep(e, 127) .. "x")          -- 255 bytes
    local over = callout(string.rep(e, 128))               -- 256 bytes
    assertTrue(B.Bake(ok, PARTY) ~= nil, "255 passes")
    local line, reason = B.Bake(over, PARTY)
    assertNil(line) assertEqual(reason, "tooLong")
    local live = callout(string.rep("a", 241) .. " {target}")  -- 244 bytes + 12 nominal = 256
    line, reason = B.Bake(live, PARTY)
    assertNil(line) assertEqual(reason, "tooLong")
    assertEqual(B.Length("abc", 2), 3 + 2 * 12)
end)

test("bake: empty or whitespace-only text is refused", function()
    local B = bake()
    for _, t in ipairs({ "", "   ", "\n\t" }) do
        local line, reason = B.Bake(callout(t), PARTY)
        assertNil(line) assertEqual(reason, "empty")
    end
    local line, reason = B.Bake(callout("{me}"), PARTY, { ctx = {} })
    assertNil(line) assertEqual(reason, "empty")
end)

test("bake: solo smart callouts follow the fallback", function()
    local B = bake()
    local SOLO = { group = "solo", lockdown = {} }
    local line, reason, info = B.Bake(callout("hi"), SOLO, { soloFallback = "self" })
    assertNil(line) assertEqual(reason, "solo") assertTrue(info.selfPrint)
    line = B.Bake(callout("hi"), SOLO, { soloFallback = "say" })
    assertEqual(line, "/s hi")
end)

test("bake: locks and warnings ride along without blocking the bake", function()
    local B = bake()
    local line, _, info = B.Bake(callout("inc", "say"), { group = "party", lockdown = { encounter = true } })
    assertEqual(line, "/s inc")
    assertEqual(info.lock, "lockdown")
    _, _, info = B.Bake(callout("hi", "whisperTarget"), { group = "party", lockdown = { chat = true } })
    assertEqual(info.warning, "whisperInstanceOnly")
end)

test("bake: unknown channel and non-table callout refuse", function()
    local B = bake()
    local line, reason = B.Bake(callout("hi", "guild"), PARTY)
    assertNil(line) assertEqual(reason, "badChannel")
    line, reason = B.Bake(nil, PARTY)
    assertNil(line) assertEqual(reason, "badCallout")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_bake",` to `tests/run.lua`. Run: `lua tests/run.lua`
Expected: FAIL (`NS.Bake` is nil).

- [ ] **Step 3: Write `modules/Bake.lua`**

```lua
local _, NS = ...
-- modules/Bake.lua — a callout + a snapshot -> exactly one macro line (spec §8.3). PURE.
-- Anti-pattern #20: callout text is chat text, never a command. The sanitizer flattens control
-- characters (so there is never a second macro line), refuses a leading "/", and escapes "|"
-- before tokens expand, so only game-made spell links carry escape sequences.

NS.Bake = NS.Bake or {}
local B = NS.Bake

B.MAX_BYTES = 255

local function squeeze(s)
    s = s:gsub("%s+", " ")
    s = s:gsub("^ ", "")
    s = s:gsub(" $", "")
    return s
end

--- Clean user text: one line, no leading slash, pipes escaped.
--- @return string|nil clean, string|nil reason ("empty" | "startsWithSlash")
function B.Sanitize(text)
    if type(text) ~= "string" then return nil, "empty" end
    local s = squeeze((text:gsub("%c", " ")))
    if s == "" then return nil, "empty" end
    if s:sub(1, 1) == "/" then return nil, "startsWithSlash" end
    s = s:gsub("|", "||")
    return s
end

--- Bytes the line's text will take: its own bytes plus a nominal 12 for each live token.
function B.Length(text, live)
    return #text + (live or 0) * NS.Tokens.LIVE_NOMINAL
end

--- Bake one callout.
--- @param callout table { text, channel, ... }
--- @param s table snapshot
--- @param opts table|nil { soloFallback, ctx }
--- @return string|nil line, string|nil reason, table info
function B.Bake(callout, s, opts)
    opts = type(opts) == "table" and opts or {}
    local info = {}
    if type(callout) ~= "table" then return nil, "badCallout", info end
    local clean, why = B.Sanitize(callout.text)
    if not clean then return nil, why, info end
    local concrete, reason, selfPrint = NS.Channels.Resolve(callout.channel, s, opts.soloFallback)
    info.selfPrint = selfPrint
    if not concrete then return nil, reason, info end
    local text, unknown, missing, live = NS.Tokens.Expand(clean, opts.ctx)
    text = squeeze(text)
    info.concrete, info.unknown, info.missing, info.text = concrete, unknown, missing, text
    if text == "" then return nil, "empty", info end
    if text:sub(1, 1) == "/" then return nil, "startsWithSlash", info end
    info.length = B.Length(text, live)
    if info.length > B.MAX_BYTES then return nil, "tooLong", info end
    info.lock = NS.Channels.LockState(concrete, s)
    info.warning = NS.Channels.SoftWarning(concrete, s)
    return NS.Channels.Prefix(concrete) .. " " .. text, nil, info
end
```

- [ ] **Step 4: Add the TOC line and run the gate**

```
modules\Bake.lua           # Conventional: pure; calls Tokens and Channels at call time
```
Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/Bake.lua tests/test_bake.lua tests/run.lua QuickComms.toc
git commit -m "Bake: one-line sanitizer, slash refusal and the 255-byte check"
```

---

### Task 11: Resolver

**Files:**
- Create: `modules/Resolver.lua`
- Create: `tests/test_resolver.lua`
- Modify: `QuickComms.toc` (after Bake, `# Conventional: pure`), and `tests/run.lua`

**Interfaces:**
- Produces:
  - `NS.Resolver.ROWS` (ordered row names)
  - `NS.Resolver.Matches(when, snapshot) -> ok:boolean, matched:string[]|nil, failedRow:string|nil`
  - `NS.Resolver.ActiveGroups(groups, snapshot) -> { [id] = { matched = string[] } }`, where `groups` is `{ [id] = { when, enabled } }`
  - `NS.Resolver.Narrowness(when) -> number`
  - `NS.Resolver.SurfaceOrder(list, active, groups, autoPromote) -> id[]`
  - `NS.Resolver.Explain(name, matchInfo) -> string`

- [ ] **Step 1: Write the failing test**

`tests/test_resolver.lua`:
```lua
-- tests/test_resolver.lua — modules/Resolver.lua (spec §5.3, §7).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function res() return T.newAddon().Resolver end
local MPLUS = { content = "mythicPlus", instanceID = 2526, difficulty = "keystone", keyLevel = 14,
    group = "party", instanceGroup = false, leader = true, assist = false, classFile = "WARLOCK",
    specID = 265, role = "DAMAGER", character = "Traxex-Area52" }

test("resolver: an empty When always matches", function()
    local ok, matched = res().Matches({}, MPLUS)
    assertTrue(ok) assertEqual(#matched, 0)
    assertTrue((res().Matches(nil, MPLUS)))
end)

test("resolver: each row matches and fails on its own", function()
    local R = res()
    local CASES = {
        { { content = { mythicPlus = true } }, true },
        { { content = { raid = true } }, false },
        { { instances = { [2526] = true } }, true },
        { { instances = { [1] = true } }, false },
        { { difficulty = { keystone = true } }, true },
        { { keyLevel = { min = 10 } }, true },
        { { keyLevel = { min = 15 } }, false },
        { { keyLevel = { max = 12 } }, false },
        { { group = { party = true } }, true },
        { { group = { instance = true } }, false },
        { { leadership = { leader = true } }, true },
        { { leadership = { assist = true } }, false },
        { { class = { WARLOCK = true } }, true },
        { { spec = { [266] = true } }, false },
        { { role = { DAMAGER = true } }, true },
        { { characters = { ["Traxex-Area52"] = true } }, true },
        { { battleground = { [2107] = true } }, false },
    }
    for n, c in ipairs(CASES) do assertEqual((R.Matches(c[1], MPLUS)), c[2], "case " .. n) end
end)

test("resolver: rows AND, values OR, empty rows ignored", function()
    local R = res()
    assertTrue((R.Matches({ content = { raid = true, mythicPlus = true }, role = { DAMAGER = true }, class = {} }, MPLUS)))
    local ok, _, failed = R.Matches({ content = { mythicPlus = true }, role = { HEALER = true } }, MPLUS)
    assertFalse(ok) assertEqual(failed, "role")
end)

test("resolver: keyLevel never matches outside M+", function()
    assertFalse((res().Matches({ keyLevel = { min = 2 } }, { content = "dungeon", group = "party" })))
end)

test("resolver: ActiveGroups unions enabled matches", function()
    local groups = {
        a = { enabled = true, when = { content = { mythicPlus = true } } },
        b = { enabled = true, when = { instances = { [2526] = true } } },
        c = { enabled = false, when = {} },
        d = { enabled = true, when = { content = { raid = true } } },
    }
    local active = res().ActiveGroups(groups, MPLUS)
    assertTrue(active.a ~= nil) assertTrue(active.b ~= nil)
    assertTrue(active.c == nil) assertTrue(active.d == nil)
    assertEqual(active.a.matched[1], "content")
end)

test("resolver: SurfaceOrder keeps the surface's order; autoPromote floats narrower groups", function()
    local R = res()
    local groups = {
        mplus = { enabled = true, when = { content = { mythicPlus = true } } },
        spire = { enabled = true, when = { content = { mythicPlus = true }, instances = { [2526] = true } } },
        always = { enabled = true, when = {} },
        raid = { enabled = true, when = { content = { raid = true } } },
    }
    local active = R.ActiveGroups(groups, MPLUS)
    local list = { "always", "mplus", "raid", "spire", "ghost" }
    local plain = R.SurfaceOrder(list, active, groups, false)
    assertEqual(table.concat(plain, ","), "always,mplus,spire")
    local promoted = R.SurfaceOrder(list, active, groups, true)
    assertEqual(table.concat(promoted, ","), "spire,mplus,always")
end)

test("resolver: Explain names the matched rows", function()
    local R = res()
    assertEqual(R.Explain("M+", { matched = { "content", "keyLevel" } }), "M+: Content, Key level")
    assertEqual(R.Explain("Always", { matched = {} }), "Always: always on")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_resolver",` to `tests/run.lua`. Run: `lua tests/run.lua`
Expected: FAIL (`NS.Resolver` is nil).

- [ ] **Step 3: Write `modules/Resolver.lua`**

```lua
local _, NS = ...
-- modules/Resolver.lua — When rules -> the active group set, each surface's order, and the "why"
-- lines (spec §5.3, §7). PURE. Rows AND; values inside a row OR; an empty or absent row is ignored,
-- so an empty When is "always on" (D6: every matching group is active, a union).

NS.Resolver = NS.Resolver or {}
local R = NS.Resolver
local L = NS.L

R.ROWS = { "content", "instances", "battleground", "difficulty", "keyLevel", "group", "leadership",
    "class", "spec", "role", "characters" }

local LABEL = {
    content = L["Content"], instances = L["Instance"], battleground = L["Battleground"],
    difficulty = L["Difficulty"], keyLevel = L["Key level"], group = L["Group"],
    leadership = L["Leader or assist"], class = L["Class"], spec = L["Specialization"], role = L["Role"],
    characters = L["Character"],
}

local function isSet(row, v)
    if type(v) ~= "table" then return false end
    if row == "keyLevel" then return v.min ~= nil or v.max ~= nil end
    return next(v) ~= nil
end

local CHECK = {
    content      = function(v, s) return v[s.content] == true end,
    instances    = function(v, s) return s.instanceID ~= nil and v[s.instanceID] == true end,
    battleground = function(v, s) return s.content == "battleground" and s.instanceID ~= nil and v[s.instanceID] == true end,
    difficulty   = function(v, s) return s.difficulty ~= nil and v[s.difficulty] == true end,
    keyLevel     = function(v, s)
        if s.content ~= "mythicPlus" or type(s.keyLevel) ~= "number" then return false end
        return (v.min == nil or s.keyLevel >= v.min) and (v.max == nil or s.keyLevel <= v.max)
    end,
    group        = function(v, s) return (v.instance == true and s.instanceGroup == true) or v[s.group] == true end,
    leadership   = function(v, s) return (v.leader == true and s.leader == true) or (v.assist == true and s.assist == true) end,
    class        = function(v, s) return s.classFile ~= nil and v[s.classFile] == true end,
    spec         = function(v, s) return s.specID ~= nil and v[s.specID] == true end,
    role         = function(v, s) return s.role ~= nil and v[s.role] == true end,
    characters   = function(v, s) return s.character ~= nil and v[s.character] == true end,
}

--- Whether a When matches a snapshot.
--- @return boolean ok, table|nil matched rows, string|nil the first failing row
function R.Matches(when, s)
    local matched = {}
    if type(when) ~= "table" then return true, matched end
    s = type(s) == "table" and s or {}
    for _, row in ipairs(R.ROWS) do
        local v = when[row]
        if isSet(row, v) then
            if not CHECK[row](v, s) then return false, nil, row end
            matched[#matched + 1] = row
        end
    end
    return true, matched
end

--- Every enabled group whose When matches (D6 union).
--- @param groups table { [id] = { enabled, when } }
--- @return table { [id] = { matched = rows } }
function R.ActiveGroups(groups, s)
    local active = {}
    for id, g in pairs(type(groups) == "table" and groups or {}) do
        if type(g) == "table" and g.enabled ~= false then
            local ok, matched = R.Matches(g.when, s)
            if ok then active[id] = { matched = matched } end
        end
    end
    return active
end

--- How narrow a When is: the number of set rows, plus 100 for a specific instance or battleground.
function R.Narrowness(when)
    if type(when) ~= "table" then return 0 end
    local n = 0
    for _, row in ipairs(R.ROWS) do
        if isSet(row, when[row]) then
            n = n + ((row == "instances" or row == "battleground") and 101 or 1)
        end
    end
    return n
end

--- A surface's active groups, in its own order; with autoPromote, narrower groups first (stable).
--- @param list table ordered group ids from the surface
--- @return table ordered active ids
function R.SurfaceOrder(list, active, groups, autoPromote)
    local out = {}
    for i, id in ipairs(type(list) == "table" and list or {}) do
        if active[id] then out[#out + 1] = { id = id, i = i } end
    end
    if autoPromote then
        local narrow = {}
        for _, e in ipairs(out) do narrow[e.id] = R.Narrowness(groups[e.id] and groups[e.id].when) end
        table.sort(out, function(a, b)
            if narrow[a.id] ~= narrow[b.id] then return narrow[a.id] > narrow[b.id] end
            return a.i < b.i
        end)
    end
    for n, e in ipairs(out) do out[n] = e.id end
    return out
end

--- One "why" line for a group.
function R.Explain(name, info)
    local rows = info and info.matched or {}
    if #rows == 0 then return ("%s: %s"):format(tostring(name), L["always on"]) end
    local labels = {}
    for n, row in ipairs(rows) do labels[n] = LABEL[row] or row end
    return ("%s: %s"):format(tostring(name), table.concat(labels, ", "))
end
```

Add every `L[...]` key used here to `locales/enUS.lua`.

- [ ] **Step 4: Add the TOC line and run the gate**

```
modules\Resolver.lua       # Conventional: pure
```
Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/Resolver.lua tests/test_resolver.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Resolver: When matching, union, surface order and why lines"
```

---

### Task 12: Built-in sets and the bake audit

**Files:**
- Create: `defaults/BuiltIns.lua` (the registry table and helpers)
- Create: `defaults/BuiltIns_MythicPlus.lua`, `defaults/BuiltIns_Raid.lua`, `defaults/BuiltIns_Arena.lua`, `defaults/BuiltIns_Battlegrounds.lua`
- Create: `tests/test_builtins.lua`
- Modify: `QuickComms.toc`, under `# Defaults` after `defaults\Profile.lua`: `BuiltIns.lua` with `# LOAD-BEARING: NS.BuiltIns, filled by the next four files`, then the four sets with `# Conventional: data`. Also `tests/run.lua`.

**Interfaces:**
- Produces:
  - `NS.BuiltIns.groups`: `{ [id] = { name, icon, when, callouts = id[], openInto, children = id[]|nil, parent = id|nil } }`
  - `NS.BuiltIns.callouts`: `{ [id] = { name, text, channel, icon } }`
  - `NS.BuiltIns.order`: the top-level group ids, in default surface order
  - `NS.BuiltIns.SNAPSHOTS`: `{ [topGroupId] = snapshot }`, used by the bake audit and by "Preview as…"

- [ ] **Step 1: Write the failing test**

`tests/test_builtins.lua`:
```lua
-- tests/test_builtins.lua — defaults/BuiltIns*.lua (spec §12): integrity and the bake audit.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function bi() local NS = T.newAddon() return NS, NS.BuiltIns end

test("builtins: the expected top-level sets exist in order", function()
    local _, BI = bi()
    assertEqual(BI.order[1], "bi.mplus")
    assertEqual(BI.order[2], "bi.raid")
    assertEqual(BI.order[3], "bi.arena")
    assertEqual(BI.order[4], "bi.bg")
    assertTrue(#BI.order >= 18, "generic sets plus one per battleground")
end)

test("builtins: ids are unique, referenced and well formed", function()
    local _, BI = bi()
    local seen = {}
    for id, g in pairs(BI.groups) do
        assertTrue(id:match("^bi%.[%w%.]+$") ~= nil, "group id " .. id)
        for _, cid in ipairs(g.callouts or {}) do
            assertTrue(BI.callouts[cid] ~= nil, id .. " -> " .. cid)
            assertTrue(not seen[cid], "callout in two groups: " .. cid)
            seen[cid] = true
        end
        for _, child in ipairs(g.children or {}) do
            assertEqual(BI.groups[child].parent, id, "parent of " .. child)
        end
    end
    for cid in pairs(BI.callouts) do assertTrue(seen[cid], "orphan callout " .. cid) end
end)

test("builtins: only top-level groups are in the order, and every top-level group is", function()
    local _, BI = bi()
    local inOrder = {}
    for _, id in ipairs(BI.order) do inOrder[id] = true assertTrue(BI.groups[id].parent == nil, id) end
    for id, g in pairs(BI.groups) do if g.parent == nil then assertTrue(inOrder[id], "missing " .. id) end end
end)

test("builtins: node sets open into their ring and nest one level", function()
    local _, BI = bi()
    local ab = BI.groups["bi.bg.ab"]
    assertTrue(ab.openInto)
    assertEqual(#ab.children, 5)
    local stables = BI.groups[ab.children[1]]
    assertEqual(#stables.callouts, 6)
    assertEqual(BI.callouts[stables.callouts[3]].text, "INC 3 Stables")
end)

test("builtins: bake audit, every callout bakes under its set's snapshot", function()
    local NS, BI = bi()
    local function topOf(id) local g = BI.groups[id] while g.parent do id = g.parent g = BI.groups[id] end return id end
    for gid, g in pairs(BI.groups) do
        local snap = BI.SNAPSHOTS[topOf(gid)]
        assertTrue(snap ~= nil, "snapshot for " .. topOf(gid))
        for _, cid in ipairs(g.callouts or {}) do
            local line, reason, info = NS.Bake.Bake(BI.callouts[cid], snap, { ctx = { me = "Traxex" } })
            assertTrue(line ~= nil, cid .. ": " .. tostring(reason))
            assertTrue(info.length <= 255, cid .. " length")
            assertTrue(#(info.unknown or {}) == 0, cid .. " unknown token")
            assertTrue(info.lock == nil, cid .. " locked under its own snapshot: " .. tostring(info.lock))
        end
    end
end)

test("builtins: battlegrounds use smart group; arena uses party; raid lead uses smart lead", function()
    local _, BI = bi()
    for cid, c in pairs(BI.callouts) do
        if cid:match("^bi%.bg") then assertEqual(c.channel, "smartGroup", cid) end
        if cid:match("^bi%.arena") then assertEqual(c.channel, "party", cid) end
    end
    assertEqual(BI.callouts["bi.raid.pull10"].channel, "smartLead")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_builtins",` to `tests/run.lua`. Run: `lua tests/run.lua`
Expected: FAIL (`NS.BuiltIns` is nil).

- [ ] **Step 3: Write `defaults/BuiltIns.lua`**

```lua
local _, NS = ...
-- defaults/BuiltIns.lua — the shipped, read-only callout sets (spec §12): the registry table and
-- the helpers the four data files use. Shipped data, not registry members (architecture-§5): the
-- profile stores only the overlay (profile.builtins). Built-in ids are stable once shipped.

NS.BuiltIns = NS.BuiltIns or { groups = {}, callouts = {}, order = {}, SNAPSHOTS = {} }
local BI = NS.BuiltIns

--- Declare a callout. `short` is appended to the group id: "bi.mplus" + "lust" -> "bi.mplus.lust".
--- @return string id
function BI.Callout(groupId, short, name, text, channel, icon)
    local id = groupId .. "." .. short
    BI.callouts[id] = { name = name, text = text, channel = channel, icon = icon }
    return id
end

--- Declare a group. Top-level groups (no parent) join BI.order in declaration order.
function BI.Group(id, def)
    def.callouts = def.callouts or {}
    BI.groups[id] = def
    if def.parent == nil then BI.order[#BI.order + 1] = id end
    return def
end

--- Callouts from a list of { short, name, text[, icon] } rows, all on `channel`.
function BI.Callouts(groupId, channel, rows)
    local ids = {}
    for n, r in ipairs(rows) do ids[n] = BI.Callout(groupId, r[1], r[2], r[3], channel, r[4]) end
    return ids
end
```

- [ ] **Step 4: Write `defaults/BuiltIns_MythicPlus.lua`**

```lua
local _, NS = ...
-- defaults/BuiltIns_MythicPlus.lua — the generic M+ set (spec §12, brainstorm §8).

local BI, L = NS.BuiltIns, NS.L
local ID = "bi.mplus"

BI.Group(ID, {
    name = L["M+ (generic)"], icon = "Interface\\Icons\\INV_Relics_Hourglass",
    when = { content = { mythicPlus = true } },
    callouts = BI.Callouts(ID, "smartGroup", {
        { "pull",   L["Pulling"],        L["Pulling next pack"] },
        { "lust",   L["Lust"],           L["Lust on this pack {rt8}"], "Interface\\Icons\\Spell_Nature_Bloodlust" },
        { "mana",   L["Need mana"],      L["Wait, need mana"] },
        { "kicks",  L["Kick order"],     L["Kick order: {rt1} {rt2} {rt3}"] },
        { "skip",   L["Skipping"],       L["Skipping with invis/shroud"] },
        { "res",    L["Res me"],         L["Res me pls"], "Interface\\Icons\\Spell_Nature_Reincarnation" },
        { "chain",  L["Chain pull"],     L["Key time is tight, chain pull"] },
        { "gg",     L["GG"],             L["gg, thanks all"] },
    }),
})

BI.SNAPSHOTS[ID] = { content = "mythicPlus", group = "party", instanceGroup = false, difficulty = "keystone",
    keyLevel = 10, lockdown = { chat = true, challengeMode = true } }
```

- [ ] **Step 5: Write `defaults/BuiltIns_Raid.lua`**

```lua
local _, NS = ...
-- defaults/BuiltIns_Raid.lua — the generic raid set (spec §12). Lead callouts use Smart lead
-- (raid warning for the leader or an assistant, raid chat otherwise).

local BI, L = NS.BuiltIns, NS.L
local ID = "bi.raid"

local raid = BI.Callouts(ID, "raid", {
    { "lust",    L["Bloodlust"],     L["Bloodlust now"], "Interface\\Icons\\Spell_Nature_Bloodlust" },
    { "brez",    L["Battle rez"],    L["Battle rez used on %t"] },
    { "soak",    L["Soak"],          L["Soak {rt3}"] },
    { "spread",  L["Spread"],        L["Spread for mechanic"] },
    { "stack",   L["Stack"],         L["Stack on {rt1}"] },
    { "stones",  L["Healthstones"],  L["Healthstones/cauldron down"] },
})
local lead = BI.Callouts(ID, "smartLead", {
    { "pull10",  L["Pull in 10"],    L["Pull in 10"] },
    { "wipe",    L["Wipe"],          L["Wipe it, run back"] },
})
for _, id in ipairs(lead) do raid[#raid + 1] = id end

BI.Group(ID, {
    name = L["Raid (generic)"], icon = "Interface\\Icons\\Achievement_Boss_Ragnaros",
    when = { content = { raid = true } }, callouts = raid,
})

BI.SNAPSHOTS[ID] = { content = "raid", group = "raid", instanceGroup = false, leader = true, lockdown = {} }
```

Note: `"Battle rez used on %t"` contains a literal `%t`. That is fine: `%t` is an engine token, Tokens leaves it as is, and Bake counts its literal 2 bytes.

- [ ] **Step 6: Write `defaults/BuiltIns_Arena.lua`**

```lua
local _, NS = ...
-- defaults/BuiltIns_Arena.lua — the generic arena set (spec §12): party chat.

local BI, L = NS.BuiltIns, NS.L
local ID = "bi.arena"

BI.Group(ID, {
    name = L["Arena (generic)"], icon = "Interface\\Icons\\Achievement_Arena_2v2_7",
    when = { content = { arena = true } },
    callouts = BI.Callouts(ID, "party", {
        { "trinket", L["Trinket used"],  L["Trinket used"] },
        { "cc",      L["CC"],            L["CC {rt1} now"] },
        { "swap",    L["Swap"],          L["Swap to %t"] },
        { "incc",    L["I'm in CC"],     L["I'm in CC"] },
        { "kill",    L["Kill"],          L["Going for kill on %t"] },
        { "drink",   L["Drink"],         L["Drink, reset"] },
    }),
})

BI.SNAPSHOTS[ID] = { content = "arena", group = "party", instanceGroup = false, lockdown = { pvpMatch = true } }
```

Arena groups are instance groups in game, but the arena set deliberately sends to Party (brainstorm §8). The audit snapshot therefore uses a home party, so `/p` isn't locked there. **C3 confirms `/p` in a real arena.** If C3 shows `/p` fails in arena, change the channel to `smartGroup`.

- [ ] **Step 7: Write `defaults/BuiltIns_Battlegrounds.lua`**

```lua
local _, NS = ...
-- defaults/BuiltIns_Battlegrounds.lua — the generic battleground set and one set per
-- battleground (spec §12). Faction-neutral wording (D11). Matched on instanceID; the IDs below
-- are confirmed or corrected by the phase 0 harness (/qcs where, round-4 record). Node
-- battlegrounds nest one ring per node with INC 1/2/3/Many/Clear/Help and open into their ring.

local BI, L = NS.BuiltIns, NS.L
local BG = { content = "battleground", group = "raid", instanceGroup = true, lockdown = { pvpMatch = true } }

BI.Group("bi.bg", {
    name = L["Battleground (generic)"], icon = "Interface\\Icons\\Achievement_BG_winWSG",
    when = { content = { battleground = true } },
    callouts = BI.Callouts("bi.bg", "smartGroup", {
        { "help",    L["Need help"],  L["Need help here"] },
        { "inc",     L["INC"],        L["INC {rt8}"] },
        { "hold",    L["Hold"],       L["Hold this"] },
        { "capping", L["Capping"],    L["Capping"] },
        { "defend",  L["Defend"],     L["Defend"] },
        { "push",    L["Push"],       L["Push now"] },
    }),
})
BI.SNAPSHOTS["bi.bg"] = BG

local INC = {
    { "inc1",  L["INC 1"],    L["INC 1 %s"] },
    { "inc2",  L["INC 2"],    L["INC 2 %s"] },
    { "inc3",  L["INC 3"],    L["INC 3 %s"] },
    { "many",  L["INC many"], L["INC many %s"] },
    { "clear", L["Clear"],    L["%s is clear"] },
    { "help",  L["Help"],     L["Need help at %s"] },
}

local function idSet(ids)
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

-- A battleground whose callouts are one ring per node.
local function nodeBattleground(key, name, ids, nodes)
    local id = "bi.bg." .. key
    local children = {}
    for n, node in ipairs(nodes) do
        local nodeId = id .. "." .. node[1]
        local rows = {}
        for i, r in ipairs(INC) do rows[i] = { r[1], r[2], r[3]:format(node[2]) } end
        BI.Group(nodeId, { name = node[2], parent = id, callouts = BI.Callouts(nodeId, "smartGroup", rows) })
        children[n] = nodeId
    end
    BI.Group(id, { name = name, openInto = true, children = children,
        when = { content = { battleground = true }, battleground = idSet(ids) } })
    BI.SNAPSHOTS[id] = BG
end

-- A battleground with a flat list of callouts.
local function flatBattleground(key, name, ids, rows)
    local id = "bi.bg." .. key
    BI.Group(id, { name = name, when = { content = { battleground = true }, battleground = idSet(ids) },
        callouts = BI.Callouts(id, "smartGroup", rows) })
    BI.SNAPSHOTS[id] = BG
end

nodeBattleground("ab", L["Arathi Basin"], { 529, 2107, 1681 }, {
    { "stables", L["Stables"] }, { "lumbermill", L["Lumber Mill"] }, { "blacksmith", L["Blacksmith"] },
    { "mine", L["Gold Mine"] }, { "farm", L["Farm"] },
})
nodeBattleground("eots", L["Eye of the Storm"], { 566, 968 }, {
    { "felreaver", L["Fel Reaver Ruins"] }, { "bloodelf", L["Blood Elf Tower"] },
    { "draenei", L["Draenei Ruins"] }, { "magetower", L["Mage Tower"] }, { "flag", L["the flag"] },
})
nodeBattleground("bfg", L["Battle for Gilneas"], { 761 }, {
    { "lighthouse", L["Lighthouse"] }, { "waterworks", L["Waterworks"] }, { "mines", L["Mines"] },
})
nodeBattleground("dwg", L["Deepwind Gorge"], { 1105, 2245 }, {
    { "market", L["Market"] }, { "farm", L["Farm"] }, { "quarry", L["Quarry"] },
})
nodeBattleground("ioc", L["Isle of Conquest"], { 628 }, {
    { "docks", L["Docks"] }, { "hangar", L["Hangar"] }, { "workshop", L["Workshop"] },
    { "quarry", L["Quarry"] }, { "refinery", L["Refinery"] },
})

flatBattleground("wsg", L["Warsong Gulch"], { 489, 2106 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"] },
    { "efctun",   L["EFC tunnel"],     L["EFC in the tunnel"] },
    { "efcroof",  L["EFC roof"],       L["EFC on the roof"] },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"] },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"] },
    { "fcsafe",   L["FC safe"],        L["FC is safe"] },
})
flatBattleground("tp", L["Twin Peaks"], { 726 }, {
    { "efcmid",   L["EFC mid"],        L["EFC mid"] },
    { "efcwater", L["EFC water"],      L["EFC in the water"] },
    { "fcheals",  L["FC needs heals"], L["Our FC needs heals"] },
    { "killefc",  L["Kill EFC"],       L["Kill the EFC %t"] },
    { "fcsafe",   L["FC safe"],        L["FC is safe"] },
})
flatBattleground("ssm", L["Silvershard Mines"], { 727 }, {
    { "escort",   L["Escort"],         L["Escort the cart"] },
    { "contest",  L["Contest"],        L["Contest the cart"] },
    { "help",     L["Cart help"],      L["Need help at a cart"] },
})
flatBattleground("tok", L["Temple of Kotmogu"], { 998 }, {
    { "heals",    L["Orb heals"],      L["Orb carrier needs heals"] },
    { "kill",     L["Kill orb"],       L["Kill orb carrier %t"] },
    { "mid",      L["Go mid"],         L["Orbs to the middle"] },
})
flatBattleground("ss", L["Seething Shore"], { 1803 }, {
    { "here",     L["Azerite here"],   L["Azerite spawning here"] },
    { "next",     L["Next node"],      L["Moving to the next node"] },
    { "help",     L["Need help"],      L["Need help at the azerite"] },
})
flatBattleground("dhr", L["Deephaul Ravine"], { 2656 }, {
    { "crystal",  L["Crystal"],        L["Need help at the crystal"] },
    { "cart",     L["Cart"],           L["Cart is moving"] },
    { "defend",   L["Defend"],         L["Defend the cart"] },
})
flatBattleground("av", L["Alterac Valley"], { 30 }, {
    { "general",  L["Defend general"], L["Defend our general"] },
    { "push",     L["Push general"],   L["Push the general"] },
    { "gy",       L["Graveyard"],      L["Take the graveyard"] },
    { "tower",    L["Tower"],          L["Tower under attack"] },
})
flatBattleground("ashran", L["Ashran"], { 1191 }, {
    { "road",     L["Road"],           L["Push the road"] },
    { "event",    L["Event"],          L["Event is up, go"] },
    { "regroup",  L["Regroup"],        L["Regroup at the base"] },
})
flatBattleground("wg", L["Wintergrasp"], { 2118 }, {
    { "walls",    L["Walls"],          L["Defend the walls"] },
    { "siege",    L["Siege"],          L["Siege engine incoming"] },
    { "workshop", L["Workshop"],       L["Take the workshop"] },
})
```

- [ ] **Step 8: Add the TOC lines and the locale keys, then run the gate**

In `QuickComms.toc`, under `# Defaults` after `defaults\Profile.lua`:
```
defaults\BuiltIns.lua                # LOAD-BEARING: NS.BuiltIns and its helpers, used by the next four files
defaults\BuiltIns_MythicPlus.lua     # Conventional: data
defaults\BuiltIns_Raid.lua           # Conventional: data
defaults\BuiltIns_Arena.lua          # Conventional: data
defaults\BuiltIns_Battlegrounds.lua  # Conventional: data
```
Add every new `L[...]` key to `locales/enUS.lua`. Format keys such as `"INC 3 %s"` keep their `%s` in the key.

Run: `lua tests/run.lua && luacheck .`
Expected: PASS. If the bake audit fails on one callout, fix that callout's text or channel. Never loosen the audit.

- [ ] **Step 9: Commit**

```bash
git add defaults/ tests/test_builtins.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Built-in sets: M+, raid, arena, generic and per-battleground, with the bake audit"
```

---

### Task 13: Library, the registry writer

**Files:**
- Create: `modules/Library.lua`
- Create: `tests/test_library.lua`
- Modify: `QuickComms.toc` (after Resolver, `# Conventional: registry writer (architecture-§5)`), and `tests/run.lua`
- Modify: the entry file `core/QuickComms.lua`. Call `NS.Library.Prepare()` straight after `NS:RunMigrations()` in `OnInitialize`, and again in the profile-changed handler after the migrations.

**Interfaces:**
- Consumes: `NS.BuiltIns` (Task 12), `NS.Channels.IsKind` (Task 9), `NS.db.profile` (Task 5).
- Produces (every mutation sends `LIBRARY_CHANGED (kind, id)`):
  - **Ids and prepare:** `Library.NewId(prefix) -> id`, `Library.Prepare() -> { seeded:boolean, appended:number, repaired:number }`.
  - **Callouts:** `Library.CreateCallout(fields) -> id|nil, reason`, `Library.DeleteCallout(id) -> boolean`.
  - **Groups:** `Library.CreateGroup(fields) -> id|nil, reason`, `Library.DeleteGroup(id) -> boolean`, `Library.AddToGroup(groupId, calloutId, index) -> calloutIdAdded|nil, reason`, `Library.RemoveFromGroup(groupId, index) -> boolean`, `Library.MoveInGroup(groupId, from, to) -> boolean`, `Library.UsedBy(calloutId) -> groupId[]`.
  - **Built-ins:** `Library.Customize(builtinGroupId) -> newGroupId|nil, reason`, `Library.SetBuiltinEnabled(id, on)`, `Library.SetBuiltinCalloutHidden(groupId, calloutId, hidden)`.
  - **Surfaces:** `Library.CreateSurface(kind, name) -> id`, where kind is `"pad"` or `"dial"`; `Library.DeleteSurface(kind, id) -> boolean`; `Library.AddGroupToSurface(kind, sid, gid, index) -> boolean`; `Library.RemoveGroupFromSurface(kind, sid, gid) -> boolean`.
  - **Reads:** `Library.Callout(id) -> table|nil` (built-ins carry `builtin = true`), `Library.Group(id) -> table|nil` (built-ins merged with the overlay: `enabled`, callouts filtered by `hidden`), `Library.AllGroups() -> { [id] = group }` (top-level only: user groups plus built-ins, no child node groups).

- [ ] **Step 1: Write the failing test**

`tests/test_library.lua`:
```lua
-- tests/test_library.lua — modules/Library.lua (spec §5, §12.2): the only writer of the registry.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function boot()
    local NS = T.bootAddon()
    local sent = {}
    NS.addon.SendMessage = function(_, name, kind, id) sent[#sent + 1] = { name, kind, id } end
    return NS, NS.Library, NS.db.profile, sent
end

test("library: Prepare seeds one pad and one dial with every built-in, once", function()
    local NS, Lib, p = boot()
    assertTrue(p.seeded)
    assertEqual(#p.padOrder, 1)
    assertEqual(#p.dialOrder, 1)
    local pad = p.pads[p.padOrder[1]]
    assertEqual(#pad.groups, #NS.BuiltIns.order)
    local again = Lib.Prepare()
    assertFalse(again.seeded)
    assertEqual(#p.padOrder, 1)
end)

test("library: callouts validate on create", function()
    local _, Lib = boot()
    assertNil((Lib.CreateCallout({ name = "", text = "x", channel = "party" })))
    assertNil((Lib.CreateCallout({ name = "A", text = "x", channel = "guild" })))
    assertNil((Lib.CreateCallout({ name = "A", text = 5, channel = "party" })))
    local id = Lib.CreateCallout({ name = "Lust", text = "Lust {rt8}", channel = "smartGroup" })
    assertTrue(id:match("^c%d+$") ~= nil)
end)

test("library: [review 4] deleting a shared callout clears every group", function()
    local _, Lib, p = boot()
    local c = Lib.CreateCallout({ name = "Lust", text = "Lust", channel = "party" })
    local g1 = Lib.CreateGroup({ name = "One" })
    local g2 = Lib.CreateGroup({ name = "Two" })
    Lib.AddToGroup(g1, c) Lib.AddToGroup(g2, c)
    assertEqual(#Lib.UsedBy(c), 2)
    assertTrue(Lib.DeleteCallout(c))
    assertEqual(#p.groups[g1].callouts, 0)
    assertEqual(#p.groups[g2].callouts, 0)
    assertNil(p.callouts[c])
end)

test("library: [review 4] deleting a group clears every surface", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local pad = p.padOrder[1]
    assertTrue(Lib.AddGroupToSurface("pad", pad, g, 1))
    assertTrue(Lib.DeleteGroup(g))
    for _, gid in ipairs(p.pads[pad].groups) do assertTrue(gid ~= g) end
end)

test("library: adding a built-in callout copies it (P2)", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    local added = Lib.AddToGroup(g, "bi.mplus.lust")
    assertTrue(added:match("^c%d+$") ~= nil)
    assertEqual(p.callouts[added].text, "Lust on this pack {rt8}")
    assertEqual(p.groups[g].callouts[1], added)
end)

test("library: [review 4] Customize swaps the copy in place, then deleting it leaves neither", function()
    local _, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    local pos
    for i, gid in ipairs(pad.groups) do if gid == "bi.mplus" then pos = i end end
    local copy = Lib.Customize("bi.mplus")
    assertEqual(pad.groups[pos], copy)
    assertFalse(Lib.Group("bi.mplus").enabled)
    assertEqual(#p.groups[copy].callouts, 8)
    assertTrue(p.groups[copy].callouts[1]:match("^c%d+$") ~= nil)
    Lib.DeleteGroup(copy)
    for _, gid in ipairs(pad.groups) do assertTrue(gid ~= copy and gid ~= "bi.mplus") end
end)

test("library: hidden built-in callouts drop out of the merged group", function()
    local _, Lib = boot()
    Lib.SetBuiltinCalloutHidden("bi.mplus", "bi.mplus.gg", true)
    local g = Lib.Group("bi.mplus")
    for _, cid in ipairs(g.callouts) do assertTrue(cid ~= "bi.mplus.gg") end
    assertTrue(Lib.Callout("bi.mplus.gg").builtin)
end)

test("library: [review 5] a newly shipped built-in is appended once; a removed one stays removed", function()
    local NS, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    NS.BuiltIns.Group("bi.test", { name = "New set", when = {} })
    local r = Lib.Prepare()
    assertEqual(r.appended, 2)                        -- the pad and the dial
    assertEqual(pad.groups[#pad.groups], "bi.test")
    Lib.Prepare()
    local count = 0
    for _, gid in ipairs(pad.groups) do if gid == "bi.test" then count = count + 1 end end
    assertEqual(count, 1)
    Lib.RemoveGroupFromSurface("pad", p.padOrder[1], "bi.arena")
    Lib.Prepare()
    for _, gid in ipairs(pad.groups) do assertTrue(gid ~= "bi.arena") end
end)

test("library: Prepare repairs dangling ids", function()
    local _, Lib, p = boot()
    local g = Lib.CreateGroup({ name = "Mine" })
    p.groups[g].callouts = { "c999" }
    p.pads[p.padOrder[1]].groups[#p.pads[p.padOrder[1]].groups + 1] = "g999"
    local r = Lib.Prepare()
    assertEqual(r.repaired, 2)
    assertEqual(#p.groups[g].callouts, 0)
end)

test("library: AllGroups is top-level only and merges the overlay", function()
    local _, Lib = boot()
    Lib.SetBuiltinEnabled("bi.raid", false)
    local all = Lib.AllGroups()
    assertTrue(all["bi.bg.ab"] ~= nil)
    assertNil(all["bi.bg.ab.stables"])
    assertFalse(all["bi.raid"].enabled)
end)

test("library: every mutation announces LIBRARY_CHANGED", function()
    local NS, Lib, _, sent = boot()
    Lib.CreateCallout({ name = "A", text = "a", channel = "party" })
    assertEqual(sent[#sent][1], NS.MSG.LIBRARY_CHANGED)
    assertEqual(sent[#sent][2], "callout")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_library",` to `tests/run.lua`. Run: `lua tests/run.lua`
Expected: FAIL (`NS.Library` is nil).

- [ ] **Step 3: Write `modules/Library.lua`**

```lua
local _, NS = ...
-- modules/Library.lua — THE registry writer (architecture-§5, spec §5, §12.2). The only module
-- that creates, deletes, orders or re-references profile.callouts / groups / pads / dials /
-- builtins / padOrder / dialOrder / nextId / seeded. Panel pages, slash verbs and (phase 5) import
-- all call it. Built-ins are shipped data (NS.BuiltIns); the profile holds only their overlay.
-- Prepare runs after migrations on every profile load: it seeds, appends new built-ins once per
-- surface (seenBuiltins), and drops dangling ids.

NS.Library = NS.Library or {}
local Lib = NS.Library
local L = NS.L

local TAG = "Library"

local function P() return NS.db.profile end

local function announce(kind, id)
    NS.Debug(TAG, "%s %s", kind, tostring(id))
    NS.addon:SendMessage(NS.MSG.LIBRARY_CHANGED, kind, id)
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

-- ── callouts ────────────────────────────────────────────────────────────────────────────────

local function validCallout(f)
    if type(f) ~= "table" then return false, "badCallout" end
    if type(f.name) ~= "string" or f.name == "" or #f.name > 32 then return false, "badName" end
    if type(f.text) ~= "string" then return false, "badText" end
    if not NS.Channels.IsKind(f.channel) then return false, "badChannel" end
    if f.icon ~= nil and type(f.icon) ~= "number" and type(f.icon) ~= "string" then return false, "badIcon" end
    return true
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

-- ── groups ──────────────────────────────────────────────────────────────────────────────────

--- Create a user group.
function Lib.CreateGroup(fields)
    if type(fields) ~= "table" or type(fields.name) ~= "string" or fields.name == "" then return nil, "badName" end
    local id = Lib.NewId("g")
    P().groups[id] = { name = fields.name, icon = fields.icon, callouts = {}, when = copyTable(fields.when) or {},
        openInto = fields.openInto == true, enabled = fields.enabled ~= false }
    announce("group", id)
    return id
end

local function surfaces()
    local p = P()
    return { pad = p.pads, dial = p.dials }
end

--- Delete a user group and every surface reference to it.
function Lib.DeleteGroup(id)
    local p = P()
    if not p.groups[id] then return false end
    p.groups[id] = nil
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do removeAll(s.groups, id) end
    end
    announce("group", id)
    return true
end

--- Add a callout to a user group at `index` (end by default). A built-in callout is copied first (P2).
--- @return string|nil the callout id actually added, string|nil reason
function Lib.AddToGroup(groupId, calloutId, index)
    local g = P().groups[groupId]
    if not g then return nil, "noGroup" end
    local id = calloutId
    if isBuiltin(calloutId) then
        local src = NS.BuiltIns.callouts[calloutId]
        if not src then return nil, "noCallout" end
        id = Lib.CreateCallout({ name = src.name, text = src.text, channel = src.channel, icon = src.icon })
    elseif not P().callouts[calloutId] then
        return nil, "noCallout"
    end
    index = math.max(1, math.min(index or (#g.callouts + 1), #g.callouts + 1))
    table.insert(g.callouts, index, id)
    announce("group", groupId)
    return id
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
    if not (g and g.callouts[from]) then return false end
    to = math.max(1, math.min(to, #g.callouts))
    table.insert(g.callouts, to, table.remove(g.callouts, from))
    announce("group", groupId)
    return true
end

-- ── built-ins ───────────────────────────────────────────────────────────────────────────────

function Lib.SetBuiltinEnabled(id, on)
    if not NS.BuiltIns.groups[id] then return false end
    overlay(id).enabled = on and true or false
    announce("builtin", id)
    return true
end

function Lib.SetBuiltinCalloutHidden(groupId, calloutId, hidden)
    if not NS.BuiltIns.groups[groupId] then return false end
    overlay(groupId).hidden[calloutId] = hidden and true or nil
    announce("builtin", groupId)
    return true
end

--- Copy a top-level built-in into an editable user group, swap it into every surface at the same
--- place, and turn the built-in off (spec §12.2). Node children are flattened: v0.1.0 has no user
--- nesting, so a customized node battleground keeps every node's callouts in one list.
function Lib.Customize(builtinId)
    local def = NS.BuiltIns.groups[builtinId]
    if not def or def.parent then return nil, "notTopLevel" end
    local id = Lib.CreateGroup({ name = def.name .. " " .. L["(custom)"], icon = def.icon, when = def.when,
        openInto = false })
    local function copyFrom(gid)
        for _, cid in ipairs(Lib.Group(gid).callouts) do Lib.AddToGroup(id, cid) end
        for _, child in ipairs(NS.BuiltIns.groups[gid].children or {}) do copyFrom(child) end
    end
    copyFrom(builtinId)
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do
            local at = indexOf(s.groups, builtinId)
            if at then s.groups[at] = id end
        end
    end
    overlay(builtinId).enabled = false
    announce("builtin", builtinId)
    return id
end

-- ── surfaces ────────────────────────────────────────────────────────────────────────────────

local SURFACE_DEFAULTS = {
    pad = { groupsAs = "sections", layout = { orientation = "horizontal", columns = 4, growth = "right",
        style = "iconLabel", scale = 1.0, spacing = 4, width = 140 },
        look = { visibility = "always", fade = "none", fadeAlpha = 0.4 } },
    dial = { mode = "categories", slices = 4, depth = 2, openAt = "center", delay = 0.3,
        interaction = "quick", key = nil, tapAction = "first" },
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
    if not s or not (P().groups[gid] or NS.BuiltIns.groups[gid]) or indexOf(s.groups, gid) then return false end
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

-- ── prepare ─────────────────────────────────────────────────────────────────────────────────

local function exists(gid) return P().groups[gid] ~= nil or (NS.BuiltIns.groups[gid] ~= nil and not NS.BuiltIns.groups[gid].parent) end

--- Seed, append newly shipped built-ins once per surface, and drop dangling ids. Idempotent.
--- @return table { seeded, appended, repaired }
function Lib.Prepare()
    local p = P()
    local result = { seeded = false, appended = 0, repaired = 0 }
    if not p.seeded then
        if #p.padOrder == 0 then Lib.CreateSurface("pad", L["Comms Pad"]) end
        if #p.dialOrder == 0 then Lib.CreateSurface("dial", L["Comms Dial"]) end
        p.seeded = true
        result.seeded = true
    end
    for _, g in pairs(p.groups) do
        for i = #g.callouts, 1, -1 do
            if not p.callouts[g.callouts[i]] then table.remove(g.callouts, i) result.repaired = result.repaired + 1 end
        end
    end
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do
            s.seenBuiltins = s.seenBuiltins or {}
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
    if result.seeded or result.appended > 0 or result.repaired > 0 then
        NS.Debug(TAG, "prepare seeded=%s appended=%s repaired=%s", result.seeded, result.appended, result.repaired)
    end
    return result
end
```

- [ ] **Step 4: Hook Prepare into the lifecycle**

In `core/QuickComms.lua` (the entry), immediately after each `NS:RunMigrations()` call (in `OnInitialize`, and in the profile callback), add:
```lua
    NS.Library.Prepare()
```
Add the `L[...]` keys `"(custom)"`, `"Comms Pad"` and `"Comms Dial"` to `locales/enUS.lua`.

- [ ] **Step 5: Add the TOC line and run the gate**

```
modules\Library.lua        # Conventional: the registry writer (architecture-§5); Prepare is called from the entry after migrations
```
Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

The `[review 5]` test removes `bi.arena` from the pad and expects it to stay removed. That works because `CreateSurface` marks every built-in as seen, so Prepare never re-adds it.

- [ ] **Step 6: Commit**

```bash
git add modules/Library.lua tests/test_library.lua tests/run.lua QuickComms.toc core/QuickComms.lua locales/enUS.lua
git commit -m "Library: the registry writer, built-in overlay, Customize and Prepare"
```

---

### Task 14: `/qc check`, diagnostics sections and the docs for phase 1

**Files:**
- Modify: `settings/SlashVerbs.lua` and `settings/Slash.lua`. Add the `check` verb to `NS.COMMANDS`.
- Modify: `modules/Diagnostics.lua` (add the sections)
- Create: `tests/test_check.lua`
- Modify: `tests/run.lua`
- Modify: `docs/ARCHITECTURE.md`, covering:
  - Module Map: Situation, Restrictions, Tokens, Channels, Bake, Resolver, Library, BuiltIns
  - Settings Schema: the registry writer is `modules/Library.lua`; its storage keys; the load pass is `Library.Prepare` after `RunMigrations`
  - Message Bus: the §17 table, with Task 7's payload correction
  - Taint Notes: no secure frames yet
- Modify: `docs/slash-dispatch.md` (the `check` verb), `docs/debug.md` (the new tags and sections), and `docs/test-cases.md` (regenerated)

**Interfaces:**
- Consumes: `Library.Callout`, `Bake.Bake`, `Situation.Current`, `Resolver.ActiveGroups`, `Library.AllGroups`, `NS.Setting("behavior.soloFallback")`.
- Produces: `NS.SlashVerbs.Check(rest)` and `NS.SlashVerbs.CheckLines(id) -> string[]` (pure formatting, for tests).

- [ ] **Step 1: Write the failing test**

`tests/test_check.lua`:
```lua
-- tests/test_check.lua — /qc check <id> (spec §14, P8): prints the baked line, never sends.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function boot()
    local NS, env = T.enableAddon()
    NS.Situation.Current = function()
        return { content = "mythicPlus", group = "party", instanceGroup = false, lockdown = { chat = true } }
    end
    return NS, env
end

test("check: a built-in callout prints its line and channel", function()
    local NS = boot()
    local lines = NS.SlashVerbs.CheckLines("bi.mplus.lust")
    assertEqual(lines[1], "bi.mplus.lust -> /p Lust on this pack {rt8}")
    assertTrue(lines[2]:find("party", 1, true) ~= nil)
end)

test("check: a refused callout prints the reason", function()
    local NS = boot()
    local id = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    local lines = NS.SlashVerbs.CheckLines(id)
    assertTrue(lines[1]:find("startsWithSlash", 1, true) ~= nil)
end)

test("check: an unknown id says so", function()
    local NS = boot()
    local lines = NS.SlashVerbs.CheckLines("c999")
    assertEqual(#lines, 1)
    assertTrue(lines[1]:find("c999", 1, true) ~= nil)
end)

test("check: never calls SendChatMessage", function()
    local NS, env = boot()
    local called = false
    env.C_ChatInfo = env.C_ChatInfo or {}
    env.C_ChatInfo.SendChatMessage = function() called = true end
    env.SendChatMessage = function() called = true end
    NS.SlashVerbs.Check("bi.mplus.lust")
    assertTrue(not called, "check must not send")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_check",` to `tests/run.lua`. Run: `lua tests/run.lua`
Expected: FAIL (`CheckLines` is nil).

- [ ] **Step 3: Write the verb**

In `settings/SlashVerbs.lua`:
```lua
--- The lines `/qc check <id>` prints: the baked line under the current situation, the channel,
--- and any lock or warning. Never sends (spec P8, D12).
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
    if info.warning then out[#out + 1] = L["  note: %s"]:format(info.warning) end
    return out
end

function V.Check(rest)
    for _, line in ipairs(V.CheckLines(rest)) do NS.Print(line) end
end
```
In `settings/Slash.lua`, add to `NS.COMMANDS`, using the same positional-triple shape and the same `fn` signature as the scaffold's existing entries:
```lua
{ "check", L["Show the line a callout would send here (never sends)"], function(rest) NS.SlashVerbs.Check(rest) end },
```
Add the new `L[...]` keys to `locales/enUS.lua`.

The first assertion in the built-in test expects the line without a chat tag, because `CheckLines` returns raw lines and `NS.Print` adds the tag.

- [ ] **Step 4: Add the diagnostics sections**

In `modules/Diagnostics.lua`, inside the sections list the scaffold returns, add:
```lua
function(out)
    local s = NS.Situation.Current()
    out:add("Situation", "content=%s instanceID=%s difficulty=%s key=%s group=%s instanceGroup=%s",
        s.content, s.instanceID, s.difficulty, s.keyLevel, s.group, s.instanceGroup)
    out:add("Situation", "leader=%s assist=%s class=%s spec=%s role=%s combat=%s",
        s.leader, s.assist, s.classFile, s.specID, s.role, s.inCombat)
    local lock = {}
    for k, v in pairs(s.lockdown or {}) do if v then lock[#lock + 1] = k end end
    table.sort(lock)
    out:add("Situation", "lockdown=%s", table.concat(lock, ","))
end,
function(out)
    local p = NS.db.profile
    local n = function(t) local c = 0 for _ in pairs(t) do c = c + 1 end return c end
    out:add("Library", "callouts=%s groups=%s pads=%s dials=%s nextId=%s seeded=%s",
        n(p.callouts), n(p.groups), #p.padOrder, #p.dialOrder, p.nextId, p.seeded)
    local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), NS.Situation.Current())
    local ids = {}
    for id in pairs(active) do ids[#ids + 1] = id end
    table.sort(ids)
    out:add("Library", "active=%s", table.concat(ids, ","))
end,
```

- [ ] **Step 5: Update the docs**

Make the edits listed under **Files** above. Regenerate `docs/test-cases.md` and update the tests badge:
```bash
lua tests/run.lua --list > docs/test-cases.md
```
Then update the `[tests]` badge count in `README.md` to the number of cases the run reports.

- [ ] **Step 6: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including the kit's `test_diagnostics_contract`.

- [ ] **Step 7: In-game smoke test (owner)**

Copy the addon into AddOns. Run:
```bash
cp -r . "/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/QuickComms"
```
Then exclude dev files, or use the existing symlink pattern from `symlinks.txt`:
```
mklink /d "G:\...\AddOns\QuickComms" "D:\...\GIT\QuickComms"
```
In game:
- `/reload`, then `/qc check bi.mplus.lust` → prints the line under the current situation.
- `/qc diagnostics` → the Situation and Library sections are present.

- [ ] **Step 8: Commit**

```bash
git add settings/ modules/Diagnostics.lua tests/test_check.lua tests/run.lua locales/enUS.lua docs/ README.md
git commit -m "Phase 1: /qc check, diagnostics sections and docs"
```

---

## Self-review

**1. Spec coverage (phases 0 and 1):**

| Spec section | Task |
|---|---|
| §3 identity, compliance, P9 | Task 1 |
| §19 checks C1–C9 | Tasks 2–3 |
| §17 bus | Task 4 |
| §5.1 data model, Behavior | Task 5 |
| §5.4 migrations | Task 5, plus `Prepare` in Task 13 |
| §6 situation | Task 6 |
| Restrictions (§4.3, §8.4) | Task 7 |
| §8.1 tokens | Task 8 |
| §8.2 and §8.4 channels | Task 9 |
| §8.3 bake | Task 10 |
| §7 resolver | Task 11 |
| §12 built-ins and the bake audit | Task 12 |
| §5.2 ids/references, §12.2 overlay, Customize, P2 | Task 13 |
| §14 `check` (P8) | Task 14 |
| §16 diagnostics (partial) | Task 14 |

Deferred to later plans: §9 SendEngine, §10 Pad, §11 Dial, §13 settings pages beyond Behavior, §15 Share, and §16 perf buckets. They are listed in the spec's phases 2–5.

**2. Placeholders:** none. Task 3's round-4 skeleton is a form the owner fills in from game output, by design.

**3. Type consistency:**
- `Channels.Resolve` returns `(concrete, reason, selfPrint)` everywhere.
- `Bake.Bake` returns `(line, reason, info)` everywhere.
- `Resolver.ActiveGroups` takes the `Library.AllGroups()` shape `{ [id] = { enabled, when } }`.
- Snapshot field names are the same in Situation, Channels, Resolver, the built-in snapshots and the tests.
- `NS.BuiltIns.order`, `groups`, `callouts` and `SNAPSHOTS` are used consistently.

**4. Review focus:** each of the five lines has a test, tagged `[review n]`, in Tasks 6, 10 and 13.
