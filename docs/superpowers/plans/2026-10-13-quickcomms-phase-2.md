# Ka0s Quick Comms: phase 2 implementation plan (send engine and Pad, the first usable build)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first usable Quick Comms: the default Comms Pad shows the active built-in callouts and sends them through secure buttons in a key and on a boss, with the soft spam guard, the echo tracker, the combat-end queue, the stale hint, test mode, the lock and a saved position.

**Architecture:**
- **One secure writer.** `modules/SendEngine.lua` is the only file that creates secure frames, writes attributes or registers state drivers. Everything that touches a protected frame runs through `SendEngine.RunOrQueue`, so it runs now out of combat and waits in the keyed combat-end queue in combat.
- **Pure decisions, thin frames.** The guard's timing, the click edge, echo matching and the queue are in `modules/SendEngine_Guard.lua`. The pad's geometry, visibility expression and alpha are in `modules/Pad_Layout.lua`. The plan of each surface (which groups, which slots, which baked line) is `Surfaces.BuildPlan`. All three are driven by truth-table tests.
- **The edges.** `Surfaces` turns situation, library, profile and test-mode messages into one rebuild request. `Pad`, `Pad_Render` and `Preview` draw it and switch test mode. The combat edges arrive as `RESTRICTION_CHANGED`, because `modules/Restrictions.lua` owns `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`.

**Tech stack:**
- Lua 5.1, against the WoW Retail 12.1 client (Interface `120100`)
- Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole)
- LibKa0s v1.71.0 (Pool, Widgets `DragHandle`, Core `SKIN` / `ApplySkin`, Options `MasterControls`, Launcher, Lifecycle, Bus, Perf)
- the LibKa0s headless test kit (`tests/_kit/`)
- luacheck

**Spec:** [`docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`](../specs/2026-10-11-quickcomms-v1-design.md) (amended 2026-10-13). Read it alongside this plan; section numbers below (§n) refer to it. The in-game facts this plan builds on are in [`docs/brainstorm/go-no-go/README.md`](../../brainstorm/go-no-go/README.md) and [`round-4-build-checks.md`](../../brainstorm/go-no-go/round-4-build-checks.md).

**Scope note:** this plan covers **phase 2 only** (§19 row 2). Out of scope:
- the editors and "Preview as…" / "Why is this showing?" (phase 3)
- the Comms Dial, `Bindings.xml` and override key bindings (phase 4)
- Share and the full perf scenarios in `tests/perf.lua` (phase 5)

**Precedents copied, by file and symbol:**

| What | Copied from |
|---|---|
| Secure button built once, out of combat | ConsumableMaster `modules/MacroBarButton.lua` `BB.Create` |
| Keyed, last-write-wins combat queue, flushed after combat | ConsumableMaster `modules/MacroManager.lua` `queueForCombat`, `M.FlushPending` |
| Held stand-down with one pending `PLAYER_REGEN_ENABLED` | ConsumableMaster `core/LifecycleSetup.lua` `standDown`, `core/ConsumableMaster.lua` `KCM:OnRegenEnabled` |
| Visibility as a state driver expression | ConsumableMaster `core/MacroBarModel.lua` `BM.ResolveVisibility`, `modules/MacroBar.lua` `applyVisibility` |
| Position save and apply as `{point, relativePoint, x, y}` | DropWatcher `modules/Window.lua` `savePoint` / `applyPoint`; ConsumableMaster `modules/MacroBar.lua` `savePosition` |
| Grid placement (row-major cells, mirrored axis) | KickCD `modules/IconGrid_Layout.lua` `Layout.layoutBlock` |
| The drag strip, born hidden, shown when unlocked | KickCD `modules/IconGrid_Handle.lua` `buildHandle`, `IconGrid:ApplyLock` |
| Test mode: toggle, combat refusal, end at combat | DropWatcher `core/DropWatcher.lua` `NS.SetTestMode`, `testModeRefusal`, `DW.OnCombatStart` |
| Launcher Locked / Test mode entries | DropWatcher `core/LauncherSetup.lua` (`isLocked` / `toggleLock`, `isTestMode` / `toggleTestMode`) |
| Master controls with lock, test mode, Reset position | DropWatcher `settings/Panel.lua` `Helpers.MasterControls{…}` |
| `lock` / `unlock` / `test` verbs | DropWatcher `settings/Slash.lua` rows, `NS.SetLocked` |
| The Ka0s skin | LibKa0s `Core.lua` `lib.SKIN`, `lib.ApplySkin` (re-exported as `NS.ApplySkin` in `core/CoreSetup.lua`) |
| The Widgets seam file | DropWatcher `core/WidgetsSetup.lua` |

## Global Constraints

These apply to every task.

**Carried from phases 0–1:**
- Interface `120100`. Lua 5.1 syntax only: no `goto`, no integer division, no `//`.
- LibKa0s **v1.71.0** as vendored; never edit `libs/` or `tests/_kit/`.
- Title `Ka0s Quick Comms`; folder `QuickComms`; saved variables exactly `QuickCommsDB` and `QuickCommsPerfDB`; chat tag `|cff00ffff[QC]|r`; slash `/qc`, alias `/quickcomms`; bus names `Ka0s_QuickComms_<PascalCaseEvent>` declared once in `core/Bus.lua` (all nine already exist).
- Every authored `.lua` opens with `local addonName, NS = ...` (or `local _, NS = ...`), with a comment naming the file's path and purpose directly beneath it.
- No new globals except the named frames the client requires (`QuickCommsSend<n>`, `QuickCommsPad<id>`), no `print()` (use `NS.Print` / `NS.Debug`), no `_G[addonName]`.
- Modules publish idempotently (`NS.X = NS.X or {}`) and never call another module's table at file load, except a load-time upvalue the TOC marks `# LOAD-BEARING:`.
- Match game data by ID or token, never by a localized name.
- US English in all code, comments and strings. Every user-facing string goes through `NS.L["English text"]`; each task adds its new keys to `locales/enUS.lua` (a key that file already defines is not added twice).
- **Secret values:** anything read from the client goes through `NS.Compat` and becomes a plain value or nil. Never compare, concatenate or format a value that might be secret. The echo tracker never reads chat text.
- **Commit gate:** before every commit, `lua tests/run.lua` exits 0 **and** `luacheck .` reports 0 warnings and 0 errors.
- **Suite and TOC bookkeeping:** every new `tests/test_*.lua` joins the `suites` list in `tests/run.lua`. Every new `.lua` file is listed in `QuickComms.toc`, with its `# LOAD-BEARING:` or `# Conventional:` comment on **its own line directly above** the entry (a trailing comment breaks the file name).
- **Line endings:** CRLF (`.gitattributes` is `* text=auto eol=crlf`); let git normalize, never hand-write LF-only files into the index.
- **Git:** commit on `main` only after the gate passes. Do not push unless the owner asks.

**Phase 2's own:**
- **One secure writer (§9).** Only `modules/SendEngine.lua` calls `SetAttribute`, `RegisterStateDriver` / `UnregisterStateDriver`, `SetOverrideBinding*` / `ClearOverrideBindings`, or names a `Secure*` template. Task 3 pins this with a grep test.
- **Never a protected write in combat** (events-frames-taint-§2). The guard is `NS.Compat.InCombat()` (`InCombatLockdown()`), never `UnitAffectingCombat`. Protected-frame `Show` / `Hide` / `SetPoint` / `SetSize` / `SetScale` and every attribute or driver write run inside `SendEngine.RunOrQueue` or a function only it calls. In combat the work is queued and the surface shows its stale hint.
- **One send path (D12).** No `SendChatMessage` / `C_ChatInfo.SendChatMessage` anywhere in shipped code; a callout reaches chat only as a secure button's `macrotext`. Task 3 pins this.
- **The soft spam guard (§9.2, plan of record).** `behavior.spamGuard` (default 1.0 s, 0.6–2.0). The guard never cancels a click: it classifies the press, dims every chip for the window and reports `guarded`. A real drop is reported by the echo tracker.
- **The echo tracker (§9.3).** A press with no echo of its chat type within 1.5 s is `dropped`. An unreadable (secret) sender is unknown and counts as the echo; it is never a drop.
- **One press can yield two `SEND_RESULT`s** (controller ruling, 2026-10-13): `guarded` at the press when it lands inside the window, then `sent` or `dropped` from the echo. Consumers treat each as an event, never as the press's one final state.
- **Never rely on `InCombatLockdown()` being false inside a `PLAYER_REGEN_DISABLED` handler.** Work started from the combat edge (test mode's end, a rebuild) goes through `SendEngine.RunOrQueue`, which queues when lockdown has already begun. Tests drive both orders.
- **`modules/Library.lua` is the only writer of `profile.pads` / `profile.dials`** (architecture-§5, spec §5). The pad writes its saved anchor only through `Library.SetSurfacePoint`; the active tab and the collapsed state are session state in `NS.State`, never profile. Task 10 pins this with a grep test.
- **No second `PLAYER_REGEN_*` feature row.** `Restrictions` owns both; AceEvent keys handlers by (event, object). Combat edges are consumed through `RESTRICTION_CHANGED` plus `NS.Restrictions.InCombat()`. The single exception is SendEngine's private pending-teardown target (slash-commands-§7).
- **Frames are never destroyed.** Chips are pooled per pad with `NS.Pool` (the array family; the keyed family stays unwired, as `tests/test_surface_parity.lua` records). The pad's look comes from `NS.ApplySkin`; no host copy of the skin.
- **Perf (performance-§2/§3).** Shape A brackets with the load-time `local Perf = NS.Perf`. Each bucket is declared in `core/PerfSetup.lua` in the same task as its bracket (`tests/test_setup.lua` fails a declared bucket with no bracket).
- **Disabled is total (slash-commands-§7).** Stood down, every pad is hidden and every chip disarmed (held to `PLAYER_REGEN_ENABLED` if in combat), every timer canceled, every event and message unregistered.
- **Test mode** is session-only (`NS.State.testMode`), refused in combat, ended at the start of combat, ended by Reset all settings, and renders placeholder chips that send nothing.

## Review Focus

These are the inputs most likely to hurt a real player that no feature test would naturally cover. Each one has a pinning test, tagged `[review n]`, in the task named in brackets.

1. **A situation or profile change during combat** (a member joins, the group becomes an instance group, `/qc profile Other` mid-pull) must queue the rebuild: no protected call is attempted, the chips keep their old lines, the stale hint shows, and at combat end the pad rebuilds with the new lines and the hint clears. [Task 11]
2. **Disabling the addon mid-combat** must not touch a protected frame. The teardown is held in exactly one `PLAYER_REGEN_ENABLED` registration, and at combat end every pad hides, every chip disarms and that registration is released. [Task 11]
3. **A rapid double press in a boss** (two presses 0.3 s apart, the game drops the second): the click's two edges count as one press; the second press is reported `guarded` and, when its echo never arrives, `dropped`, with exactly one `[QC]` note. The guard never cancels a click. [Task 4]
4. **A rebuild while the pad is hidden or locked** (visibility Never, or in combat under "Only out of combat") still re-bakes and re-arms every chip, drives visibility only through the state driver, and keeps the drag strip hidden while locked. [Task 10]
5. **A callout whose bake is refused** (`/run x`, too long, solo with no fallback) renders as a dimmed chip whose tooltip gives the reason. It is disarmed: a click sends nothing and reports nothing, and the other chips still send. [Tasks 8 and 10]

---

### Task 1: Secure frames in the mock

**Files:**
- Modify: `tests/wow_mock.lua` (append the secure-frame block inside `build()`, before `return M`)
- Create: `tests/test_mock_secure.lua`
- Modify: `tests/run.lua` (add `"test_mock_secure",` after `"test_harness",`)

**Interfaces:**
- Consumes: the kit's `M.CreateFrame`, `M.__stubFrame` frames (`__name`, `__parent`, `__template`, `__scripts`, `__fire`), `M.GetTime` / `M.__now`, `M.inCombat` (this file's).
- Produces (mock fields every later suite uses):
  - `m.blocked` — list of `{ frame, call }`, every protected call refused in combat
  - `m.sentMacros` — list of `{ text, at, frame }`, every macrotext a secure click ran
  - `m.stateDrivers[frame][state] = expression`
  - `m.cvars` (`ActionButtonUseKeyDown = "1"` by default), `m.GetCVarBool`, `m.C_CVar.GetCVarBool`
  - `m.playerGUID`, `m.UnitGUID(unit)`, `m.SOUNDKIT`, `m.ChatTypeInfo`
  - `m.RegisterStateDriver(frame, state, expr)`, `m.UnregisterStateDriver(frame, state)`
  - `m.__click(button[, mouseButton])` — the down edge then the up edge, as registered
  - `m.__setCombat(on)` — sets `inCombat` and re-evaluates every visibility driver
  - `m.__secureFrames()` — every secure frame built
  - Secure frames: `GetName()`, `SetAttribute` / `GetAttribute`, `__attrs`, `__clicks`. Frames under a root whose name starts `QuickComms`: distinct `CreateTexture` / `CreateFontString` regions (`Show`/`Hide`/`IsShown`, `SetText`/`GetText`, `SetTexture`, color setters recorded in `__color`), and recorded `SetPoint` / `GetPoint` / `ClearAllPoints`, `SetAlpha` / `GetAlpha`, `SetSize`.

- [ ] **Step 1: Write the failing test**

`tests/test_mock_secure.lua`:
```lua
-- tests/test_mock_secure.lua — the secure-frame half of tests/wow_mock.lua (testing-§1 fidelity):
-- a protected call refused in combat is RECORDED in m.blocked, never silently applied; a click acts
-- on one edge, as SecureActionButtonTemplate does; a visibility state driver follows combat.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function secureButton(m, parent)
    local b = m.CreateFrame("Button", "QCMockSend", parent or m.UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    return b
end

test("mock: a secure button keeps its attributes and answers its name", function()
    local _, m = T.newAddon()
    local b = secureButton(m)
    b:SetAttribute("type", "macro")
    assertEqual(b:GetAttribute("type"), "macro")
    assertEqual(b:GetName(), "QCMockSend")
end)

test("mock: SetAttribute in combat is refused and recorded, never applied", function()
    local _, m = T.newAddon()
    local b = secureButton(m)
    m.inCombat = true
    b:SetAttribute("macrotext", "/p x")
    assertNil(b:GetAttribute("macrotext"))
    assertEqual(#m.blocked, 1)
    assertEqual(m.blocked[1].call, "SetAttribute")
end)

test("mock: a secure child protects its ancestors in combat, and only them", function()
    local _, m = T.newAddon()
    local root = m.CreateFrame("Frame", "QCMockRoot", m.UIParent)
    local other = m.CreateFrame("Frame", "QCMockOther", m.UIParent)
    secureButton(m, root)
    m.inCombat = true
    root:Hide()
    other:Hide()
    assertTrue(root:IsShown(), "the protected parent stays shown")
    assertFalse(other:IsShown(), "a plain frame still hides in combat")
    assertEqual(#m.blocked, 1)
    assertEqual(m.blocked[1].call, "Hide")
end)

test("mock: a click acts once, on the edge the cvar names, and hooks hear both edges", function()
    local _, m = T.newAddon()
    local b = secureButton(m)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/p hello")
    local edges = {}
    b:HookScript("OnClick", function(_, _, down) edges[#edges + 1] = down end)
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, "/p hello")
    assertEqual(#edges, 2, "the hook hears both edges")
    m.cvars.ActionButtonUseKeyDown = "0"
    m.__click(b)
    assertEqual(#m.sentMacros, 2, "acting on key-up also sends once")
end)

test("mock: the useOnKeyDown attribute wins over the cvar", function()
    local _, m = T.newAddon()
    local b = secureButton(m)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/p a")
    b:SetAttribute("useOnKeyDown", false)
    local acted = {}
    b:HookScript("OnClick", function(_, _, down) acted[#acted + 1] = #m.sentMacros .. tostring(down) end)
    m.__click(b)
    -- red under: drop the attribute branch from actsOn in tests/wow_mock.lua
    assertEqual(table.concat(acted, ","), "0true,1false", "sent on the up edge")
end)

test("mock: a button with no macrotext sends nothing", function()
    local _, m = T.newAddon()
    m.__click(secureButton(m))
    assertEqual(#m.sentMacros, 0)
end)

test("mock: a visibility state driver follows combat", function()
    local _, m = T.newAddon()
    local root = m.CreateFrame("Frame", "QCMockRoot", m.UIParent)
    m.RegisterStateDriver(root, "visibility", "[combat] show; hide")
    assertFalse(root:IsShown())
    m.__setCombat(true)
    assertTrue(root:IsShown())
    m.__setCombat(false)
    assertFalse(root:IsShown())
    m.RegisterStateDriver(root, "visibility", "show")
    assertTrue(root:IsShown())
end)

test("mock: registering a state driver in combat is refused", function()
    local _, m = T.newAddon()
    local root = m.CreateFrame("Frame", "QCMockRoot", m.UIParent)
    m.inCombat = true
    m.RegisterStateDriver(root, "visibility", "hide")
    assertEqual(#m.blocked, 1)
    assertTrue(root:IsShown())
end)

test("mock: frames under a QuickComms-named root get regions and points of their own", function()
    local _, m = T.newAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    local tex = root:CreateTexture()
    assertTrue(tex ~= root, "a distinct region")
    tex:Hide()
    assertTrue(root:IsShown(), "hiding the region leaves the frame alone")
    root:SetPoint("TOPLEFT", m.UIParent, "TOPLEFT", 5, -6)
    local p, _, rp, x, y = root:GetPoint(1)
    assertEqual(p, "TOPLEFT")
    assertEqual(rp, "TOPLEFT")
    assertEqual(x, 5)
    assertEqual(y, -6)
    root:SetAlpha(0.4)
    assertEqual(root:GetAlpha(), 0.4)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_mock_secure",` to `tests/run.lua` after `"test_harness",`. Run: `lua tests/run.lua`
Expected: FAIL (`m.__click` is nil; `SetAttribute` is the stub's no-op).

- [ ] **Step 3: Write the mock block**

In `tests/wow_mock.lua`, add these lines to the header's "Mock fields" list:
```lua
--   blocked        every protected call refused in combat: { frame, call } (ADDON_ACTION_BLOCKED)
--   sentMacros     every macrotext a secure click ran: { text, at, frame }
--   stateDrivers   [frame] = { [state] = expression }
--   cvars          GetCVarBool's answers ("1" is true); ActionButtonUseKeyDown defaults on
--   playerGUID     UnitGUID("player")
--   __click(b[, mouseButton])  a full press: the registered down edge, then the up edge
--   __setCombat(on)            sets inCombat and re-evaluates every visibility driver
```
Then, inside `build()`, directly before `return M`, insert:
```lua
    -- ── secure frames (phase 2: the send engine and the Comms Pad) ─────────────────────────────
    -- The client's protected-frame rules, modeled so a suite sees a refusal instead of trusting
    -- that none happened (testing-§1, fidelity rules 3 and 5). A frame built from a Secure*
    -- template is protected, and so is every ancestor below UIParent once it has such a child. In
    -- combat a PROTECTED call on a protected frame is refused: nothing is applied and the refusal
    -- is recorded in `blocked`. A click acts on ONE edge, as SecureActionButtonTemplate does: the
    -- `useOnKeyDown` attribute when set, else the ActionButtonUseKeyDown cvar; hooks still hear
    -- both edges. Frames under a root whose name starts "QuickComms" get regions of their own (the
    -- base aliases CreateTexture to the frame itself, its documented divergence) and record
    -- SetPoint, SetAlpha and SetSize, so a pad's chips, padlocks and flashes can be asserted on.
    M.blocked      = {}
    M.sentMacros   = {}
    M.stateDrivers = {}
    M.cvars        = { ActionButtonUseKeyDown = "1" }
    M.playerGUID   = "Player-1-00000001"

    M.GetCVarBool = function(name) return M.cvars[name] == "1" end
    M.C_CVar      = { GetCVarBool = function(name) return M.cvars[name] == "1" end }
    M.UnitGUID    = function(unit)
        if unit == "player" then return M.playerGUID end
        return nil
    end
    M.SOUNDKIT     = { TELL_MESSAGE = 3081 }
    M.ChatTypeInfo = {
        PARTY = { r = 0.67, g = 0.67, b = 1.0 }, RAID = { r = 1.0, g = 0.5, b = 0.0 },
        INSTANCE_CHAT = { r = 1.0, g = 0.5, b = 0.0 }, RAID_WARNING = { r = 1.0, g = 0.28, b = 0.0 },
        SAY = { r = 1.0, g = 1.0, b = 1.0 }, YELL = { r = 1.0, g = 0.25, b = 0.25 },
    }

    local function refuse(frame, call)
        M.blocked[#M.blocked + 1] = { frame = frame, call = call }
    end

    local PROTECTED_CALLS = { "SetAttribute", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints",
        "SetAllPoints", "SetParent", "SetScale", "SetSize", "SetWidth", "SetHeight", "RegisterForClicks",
        "EnableMouse", "StartMoving", "SetFrameStrata" }

    local function protect(frame)
        if frame.__protected then return end
        frame.__protected = true
        for _, call in ipairs(PROTECTED_CALLS) do
            local inner = frame[call]
            frame[call] = function(self, ...)
                if M.inCombat then
                    refuse(self, call)
                    return self
                end
                return inner(self, ...)
            end
        end
    end

    -- A texture or font string of its own. Getters the region does not record answer 0, so a
    -- library measuring a label gets a number rather than a table.
    local function region(kind)
        local r = { __kind = kind, __shown = true }
        function r:Show() self.__shown = true return self end
        function r:Hide() self.__shown = false return self end
        function r:SetShown(v) self.__shown = not not v return self end
        function r:IsShown() return self.__shown end
        function r:SetText(v) self.__text = v return self end
        function r:GetText() return self.__text end
        function r:SetTexture(v) self.__texture = v return self end
        function r:SetColorTexture(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetVertexColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetTextColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetAlpha(a) self.__alpha = a return self end
        function r:GetAlpha() return self.__alpha or 1 end
        return setmetatable(r, { __index = function(_, key)
            if type(key) ~= "string" then return nil end
            if key:match("^Get") then return function() return 0 end end
            if key:match("^%u") then return function(self) return self end end
            return nil
        end })
    end

    local function ours(frame)
        local f = frame
        while type(f) == "table" do
            if type(f.__name) == "string" and f.__name:find("^QuickComms") then return true end
            f = f.__parent
        end
        return false
    end

    local function dress(frame)
        frame.CreateTexture = function() return region("Texture") end
        frame.CreateFontString = function() return region("FontString") end
        frame.__points = {}
        frame.SetPoint = function(self, point, rel, relPoint, x, y)
            self.__points[#self.__points + 1] = { point, rel, relPoint, x, y }
            return self
        end
        frame.ClearAllPoints = function(self)
            self.__points = {}
            return self
        end
        frame.GetPoint = function(self, i)
            local p = self.__points[i or 1]
            if not p then return nil end
            return p[1], p[2], p[3], p[4], p[5]
        end
        frame.SetAlpha = function(self, a)
            self.__alpha = a
            return self
        end
        frame.GetAlpha = function(self) return self.__alpha or 1 end
        frame.SetSize = function(self, w, h)
            self.__w, self.__h = w, h
            return self
        end
    end

    local function actsOn(button, down)
        local useDown = button.__attrs.useOnKeyDown
        if useDown == nil then useDown = M.cvars.ActionButtonUseKeyDown == "1" end
        return (down and true or false) == (useDown and true or false)
    end

    local function secureOnClick(button, _, down)
        if not actsOn(button, down) then return end
        local a = button.__attrs
        if a.type == "macro" and type(a.macrotext) == "string" then
            M.sentMacros[#M.sentMacros + 1] = { text = a.macrotext, at = M.GetTime(), frame = button }
        end
    end

    local secureFrames = {}
    local baseCreateFrame = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if ours(f) then dress(f) end
        if type(template) == "string" and template:find("Secure", 1, true) then
            if M.inCombat then refuse(f, "CreateFrame") end
            f.__attrs, f.__clicks = {}, {}
            f.GetName = function() return name end
            f.SetAttribute = function(self, key, value)
                self.__attrs[key] = value
                return self
            end
            f.GetAttribute = function(self, key) return self.__attrs[key] end
            f.RegisterForClicks = function(self, ...)
                self.__clicks = { ... }
                return self
            end
            f.__scripts.OnClick = secureOnClick
            protect(f)
            local p = parent
            while type(p) == "table" and p ~= M.UIParent do
                protect(p)
                p = p.__parent
            end
            secureFrames[#secureFrames + 1] = f
        end
        return f
    end
    M.__secureFrames = function() return secureFrames end

    M.__click = function(button, mouseButton)
        mouseButton = mouseButton or "LeftButton"
        local function registered(edge)
            for _, c in ipairs(button.__clicks or {}) do
                if c == "Any" .. edge or c == mouseButton .. edge then return true end
            end
            return false
        end
        if registered("Down") then button:__fire("OnClick", mouseButton, true) end
        if registered("Up") then button:__fire("OnClick", mouseButton, false) end
    end

    -- "[combat] a; b" or "a": the first clause whose condition holds.
    local function evaluate(expression)
        for clause in (expression .. ";"):gmatch("([^;]*);") do
            local c = clause:match("^%s*(.-)%s*$")
            local cond, value = c:match("^%[(%w+)%]%s*(%S+)$")
            if cond then
                if cond == "combat" and M.inCombat then return value end
            elseif c ~= "" then
                return c
            end
        end
        return nil
    end

    -- The driver is the secure environment's own: it shows and hides past the combat refusal.
    M.__applyStateDrivers = function()
        for frame, drivers in pairs(M.stateDrivers) do
            local value = drivers.visibility and evaluate(drivers.visibility)
            if value == "show" then
                frame.__shown = true
            elseif value == "hide" then
                frame.__shown = false
            end
        end
    end

    M.RegisterStateDriver = function(frame, state, expression)
        if M.inCombat then
            refuse(frame, "RegisterStateDriver")
            return
        end
        M.stateDrivers[frame] = M.stateDrivers[frame] or {}
        M.stateDrivers[frame][state] = expression
        M.__applyStateDrivers()
    end

    M.UnregisterStateDriver = function(frame, state)
        if M.inCombat then
            refuse(frame, "UnregisterStateDriver")
            return
        end
        if M.stateDrivers[frame] then M.stateDrivers[frame][state] = nil end
    end

    M.__setCombat = function(on)
        M.inCombat = on and true or false
        M.__applyStateDrivers()
    end
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS (every suite, including the nine new cases; luacheck 0/0).

- [ ] **Step 5: Commit**

```bash
git add tests/wow_mock.lua tests/test_mock_secure.lua tests/run.lua
git commit -m "Mock: secure frames, protected calls refused in combat, clicks and state drivers"
```

---

### Task 2: The send engine's pure decisions (guard, edge, echo, queue)

**Files:**
- Create: `modules/SendEngine_Guard.lua`
- Create: `tests/test_send_guard.lua`
- Modify: `QuickComms.toc` (after `modules\Library.lua`), `tests/run.lua` (add `"test_send_guard",` after `"test_check",`)

**Interfaces:**
- Consumes: nothing.
- Produces `NS.SendGuard` (`G`):
  - `G.ECHO_WINDOW = 1.5`
  - `G.CHAT_TYPE_BY_EVENT[event] -> chatType` (`"SAY"`, `"YELL"`, `"PARTY"`, `"RAID"`, `"RAID_WARNING"`, `"INSTANCE_CHAT"`), `G.ECHO_EVENTS` (sorted event names)
  - `G.IsActingEdge(down, useKeyDown) -> boolean`
  - `G.Decide(now, last, window) -> "ok" | "guarded"`, `G.Remaining(now, last, window) -> seconds`
  - `G.NewEcho() -> { pending = {}, sent, dropped, unknown, ignored }`
  - `G.Record(e, at, chatType, meta)`, `G.Match(e, chatType, now, fromMe) -> entry | nil` (`fromMe` is `true`, `false` or `nil` for unknown), `G.Expire(e, now) -> { entry… }` (oldest first). An entry is `{ at, chatType, meta }`.
  - `G.NewQueue()`, `G.Put(q, key, fn) -> replaced`, `G.Take(q) -> { { key, fn }… }`, `G.Keys(q) -> { key… }`, `G.Count(q) -> n`

- [ ] **Step 1: Write the failing test**

`tests/test_send_guard.lua`:
```lua
-- tests/test_send_guard.lua — modules/SendEngine_Guard.lua (spec §9.1-§9.3): the soft guard's
-- timing, the acting click edge, the echo tracker and the keyed combat-end queue. Pure.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function G() return T.newAddon().SendGuard end

test("guard: Decide is ok outside the window and guarded inside it", function()
    local g = G()
    assertEqual(g.Decide(10, nil, 1.0), "ok", "first press")
    assertEqual(g.Decide(10.5, 10, 1.0), "guarded")
    assertEqual(g.Decide(10.99, 10, 1.0), "guarded")
    assertEqual(g.Decide(11.0, 10, 1.0), "ok", "the boundary is outside")
    assertEqual(g.Decide(12, 10, 1.0), "ok")
    assertEqual(g.Decide(10.5, 10, nil), "ok", "no window, no guard")
end)

test("guard: Remaining counts down to zero", function()
    local g = G()
    assertEqual(g.Remaining(10.25, 10, 1.0), 0.75)
    assertEqual(g.Remaining(12, 10, 1.0), 0)
    assertEqual(g.Remaining(10, nil, 1.0), 0)
end)

test("guard: the acting edge follows the key-down setting", function()
    local g = G()
    assertTrue(g.IsActingEdge(true, true))
    assertFalse(g.IsActingEdge(false, true))
    assertTrue(g.IsActingEdge(false, false))
    assertFalse(g.IsActingEdge(true, false))
    assertTrue(g.IsActingEdge(nil, nil), "an unknown edge with key-up acting")
end)

test("guard: every echo event maps to one chat type", function()
    local g = G()
    assertEqual(#g.ECHO_EVENTS, 9)
    assertEqual(g.CHAT_TYPE_BY_EVENT.CHAT_MSG_PARTY_LEADER, "PARTY")
    assertEqual(g.CHAT_TYPE_BY_EVENT.CHAT_MSG_INSTANCE_CHAT_LEADER, "INSTANCE_CHAT")
    assertEqual(g.CHAT_TYPE_BY_EVENT.CHAT_MSG_RAID_WARNING, "RAID_WARNING")
    for i = 2, #g.ECHO_EVENTS do assertTrue(g.ECHO_EVENTS[i - 1] < g.ECHO_EVENTS[i], "sorted") end
end)

test("echo: our own echo consumes the oldest pending press of its type", function()
    local g = G()
    local e = g.NewEcho()
    g.Record(e, 10, "PARTY", { id = "a" })
    g.Record(e, 10.2, "PARTY", { id = "b" })
    g.Record(e, 10.1, "RAID", { id = "r" })
    local hit = g.Match(e, "PARTY", 10.6, true)
    assertEqual(hit.meta.id, "a")
    assertEqual(#e.pending, 2)
    assertEqual(e.sent, 1)
end)

test("echo: another player's readable message is ignored", function()
    local g = G()
    local e = g.NewEcho()
    g.Record(e, 10, "PARTY", {})
    assertNil(g.Match(e, "PARTY", 10.5, false))
    assertEqual(#e.pending, 1)
    assertEqual(e.ignored, 1)
end)

test("echo: an unreadable sender is unknown, counts as the echo, and is never a drop", function()
    local g = G()
    local e = g.NewEcho()
    g.Record(e, 10, "PARTY", { id = "a" })
    local hit = g.Match(e, "PARTY", 10.5, nil)
    -- red under: treat a nil fromMe like false in G.Match
    assertEqual(hit.meta.id, "a")
    assertEqual(e.unknown, 1)
    assertEqual(#g.Expire(e, 20), 0)
end)

test("echo: a message of another type or after the window matches nothing", function()
    local g = G()
    local e = g.NewEcho()
    g.Record(e, 10, "PARTY", {})
    assertNil(g.Match(e, "RAID", 10.5, true))
    assertNil(g.Match(e, "PARTY", 11.6, true), "past the 1.5 s window")
    assertNil(g.Match(e, nil, 10.5, true))
end)

test("echo: Expire drops only presses older than the window, oldest first", function()
    local g = G()
    local e = g.NewEcho()
    g.Record(e, 10, "PARTY", { id = "a" })
    g.Record(e, 10.3, "PARTY", { id = "b" })
    g.Record(e, 11.4, "PARTY", { id = "c" })
    local out = g.Expire(e, 11.85)
    assertEqual(#out, 2)
    assertEqual(out[1].meta.id, "a")
    assertEqual(out[2].meta.id, "b")
    assertEqual(#e.pending, 1)
    assertEqual(e.dropped, 2)
end)

test("queue: a key replaces its earlier entry and keeps its place", function()
    local g = G()
    local q = g.NewQueue()
    assertFalse(g.Put(q, "surfaces", function() return 1 end))
    assertFalse(g.Put(q, "positions", function() return 2 end))
    assertTrue(g.Put(q, "surfaces", function() return 3 end))
    assertEqual(table.concat(g.Keys(q), ","), "surfaces,positions")
    assertEqual(g.Count(q), 2)
    local taken = g.Take(q)
    assertEqual(taken[1].key, "surfaces")
    assertEqual(taken[1].fn(), 3, "the last write wins")
    assertEqual(g.Count(q), 0)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_send_guard",` to `tests/run.lua` after `"test_check",`. Run: `lua tests/run.lua`
Expected: FAIL (`SendGuard` is nil).

- [ ] **Step 3: Write the module**

`modules/SendEngine_Guard.lua`:
```lua
local _, NS = ...
-- modules/SendEngine_Guard.lua — the send engine's PURE decisions (spec §9.1-§9.3): the soft spam
-- guard's timing, which click edge a secure button acts on, the echo tracker that infers a drop
-- from a missing CHAT_MSG_* echo, and the keyed combat-end queue. Plain values in, plain values
-- out; no client call, no frame. modules/SendEngine.lua is the edge that feeds it.
--
-- THE GUARD IS SOFT (owner, 2026-10-13; C5 unverified): insecure code cannot cancel a secure
-- click, so Decide only classifies a press. A "guarded" press still reaches the game; the pads dim
-- for the window to discourage it, and the echo tracker reports the drop if the game swallows it.
--
-- THE ECHO NEVER READS TEXT (F7). It matches on the chat type and, when it can be read, on whether
-- the sender is the player. An unreadable (secret) sender is UNKNOWN (C6 unverified): it may be
-- our echo, so it consumes the oldest pending press of that type and is never counted as a drop.
-- Other players' messages on the channel can still mask a drop: accepted as best effort (§9.3).

NS.SendGuard = NS.SendGuard or {}
local G = NS.SendGuard

-- Seconds a press waits for its echo (spec §9.3; the measured round trip was 0.5-0.75 s).
G.ECHO_WINDOW = 1.5

-- The player's own channels, by the event that echoes them. Never a guild or custom channel (§8.4).
G.CHAT_TYPE_BY_EVENT = {
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_YELL = "YELL",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID_WARNING",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}

G.ECHO_EVENTS = {}
for event in pairs(G.CHAT_TYPE_BY_EVENT) do G.ECHO_EVENTS[#G.ECHO_EVENTS + 1] = event end
table.sort(G.ECHO_EVENTS)

-- ── the click and the guard ─────────────────────────────────────────────────────────────────

--- True on the edge the secure template acts on. A button registered for AnyUp and AnyDown hears
--- both edges in its OnClick hook; the action fires on one of them (go/no-go finding 6).
--- @param down boolean|nil the hook's `down` argument
--- @param useKeyDown boolean|nil the useOnKeyDown attribute, else the ActionButtonUseKeyDown cvar
--- @return boolean
function G.IsActingEdge(down, useKeyDown)
    return (down and true or false) == (useKeyDown and true or false)
end

--- Classify a press against the last one (spec §9.2). Never a cancel: the press is sent either way.
--- @return string "ok" | "guarded"
function G.Decide(now, last, window)
    if type(now) ~= "number" or type(last) ~= "number" or type(window) ~= "number" then return "ok" end
    if now - last < window then return "guarded" end
    return "ok"
end

--- Seconds left in the guard window, never negative.
function G.Remaining(now, last, window)
    if type(now) ~= "number" or type(last) ~= "number" or type(window) ~= "number" then return 0 end
    return math.max(0, window - (now - last))
end

-- ── the echo tracker ────────────────────────────────────────────────────────────────────────

function G.NewEcho()
    return { pending = {}, sent = 0, dropped = 0, unknown = 0, ignored = 0 }
end

--- Remember a press that should come back as a CHAT_MSG_* of `chatType`.
function G.Record(e, at, chatType, meta)
    e.pending[#e.pending + 1] = { at = at, chatType = chatType, meta = meta }
end

--- An echo arrived. `fromMe` is true (the player sent it), false (someone else did) or nil (the
--- sender could not be read). Consumes and returns the oldest matching press within the window.
--- @return table|nil entry
function G.Match(e, chatType, now, fromMe)
    if chatType == nil then return nil end
    if fromMe == false then
        e.ignored = e.ignored + 1
        return nil
    end
    for i, p in ipairs(e.pending) do
        if p.chatType == chatType and type(now) == "number" and now - p.at <= G.ECHO_WINDOW then
            table.remove(e.pending, i)
            e.sent = e.sent + 1
            if fromMe == nil then e.unknown = e.unknown + 1 end
            return p
        end
    end
    return nil
end

--- The presses whose window has passed with no echo, oldest first: each one is a drop.
--- @return table entries
function G.Expire(e, now)
    local out, keep = {}, {}
    for _, p in ipairs(e.pending) do
        if type(now) == "number" and now - p.at > G.ECHO_WINDOW then
            out[#out + 1] = p
        else
            keep[#keep + 1] = p
        end
    end
    e.pending = keep
    e.dropped = e.dropped + #out
    return out
end

-- ── the keyed combat-end queue (spec §9.1) ──────────────────────────────────────────────────

function G.NewQueue()
    return { keys = {}, fns = {} }
end

--- File `fn` under `key`, replacing an earlier entry under the same key (which keeps its place).
--- @return boolean replaced
function G.Put(q, key, fn)
    local replaced = q.fns[key] ~= nil
    if not replaced then q.keys[#q.keys + 1] = key end
    q.fns[key] = fn
    return replaced
end

--- Every entry in filing order, emptying the queue.
function G.Take(q)
    local out = {}
    for i, key in ipairs(q.keys) do out[i] = { key = key, fn = q.fns[key] } end
    q.keys, q.fns = {}, {}
    return out
end

function G.Keys(q)
    local out = {}
    for i, key in ipairs(q.keys) do out[i] = key end
    return out
end

function G.Count(q)
    return #q.keys
end
```

In `QuickComms.toc`, directly after `modules\Library.lua`:
```
# LOAD-BEARING: publishes NS.SendGuard, which modules\SendEngine.lua takes as a load-time upvalue.
modules\SendEngine_Guard.lua
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/SendEngine_Guard.lua tests/test_send_guard.lua QuickComms.toc tests/run.lua
git commit -m "SendEngine_Guard: soft guard timing, acting edge, echo tracker, keyed queue (pure)"
```

---

### Task 3: SendEngine: secure buttons, the combat-end queue, the held teardown, the firewall

**Files:**
- Create: `modules/SendEngine.lua`
- Create: `tests/test_sendengine.lua`
- Modify: `QuickComms.toc` (after `modules\SendEngine_Guard.lua`), `tests/run.lua` (add `"test_sendengine",` after `"test_send_guard",`), `.luacheckrc`, `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.SendGuard` (Task 2), `NS.Compat.InCombat()`, `NS.Bus:NewTarget()`, `NS.MSG.RESTRICTION_CHANGED`, `NS.MSG.COMBAT_QUEUE_DRAINED`, `NS.STAND_DOWN` / `NS.STAND_UP`.
- Produces `NS.SendEngine` (`SE`):
  - `SE.NewButton(parent, onPress) -> button | nil` (nil in combat). `onPress(button, verdict, window)` is called by Task 4's hook.
  - `SE.ButtonCount() -> n`
  - `SE.Arm(button, line, meta) -> boolean` (`meta = { calloutId, surfaceId, name, chatType, selfText }`); `SE.Disarm(button[, meta]) -> boolean` (the meta it keeps never carries a `chatType` that sends)
  - `SE.ArmedButtons() -> { button… }`, `SE.Escaped(button) -> string`
  - `SE.SetVisibility(frame, expression) -> boolean`, `SE.ClearVisibility(frame) -> boolean` (unregisters and hides)
  - `SE.Queue(key, fn)`, `SE.RunOrQueue(key, fn) -> ranNow`, `SE.Drain(cause) -> count`, `SE.Drop(reason) -> count`, `SE.Snapshot() -> { key… }`
  - `SE.Teardown(fn) -> ranNow`, `SE.CancelTeardown()`
  - Button fields: `qcArmed` (boolean), `qcMeta` (table|nil), `qcOnPress`.
  - Message `COMBAT_QUEUE_DRAINED (count)`.

- [ ] **Step 1: Write the failing test**

`tests/test_sendengine.lua`:
```lua
-- tests/test_sendengine.lua — modules/SendEngine.lua, the only secure writer (spec §9): send
-- buttons, arm and disarm, the combat-end queue, the held stand-down, and the firewall that keeps
-- every secure call in this one file.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function read(rel)
    local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("%-%-[^\r\n]*", ""))   -- comments may name a call; only code is checked
end

-- The two combat edges as the client delivers them: PLAYER_REGEN_DISABLED fires while secure
-- writes are still allowed, then lockdown begins; lockdown ends before PLAYER_REGEN_ENABLED fires.
local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

test("sendengine: a send button is a named secure button registered for both edges", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    assertEqual(b.__template, "SecureActionButtonTemplate")
    assertTrue(b:GetName():match("^QuickCommsSend%d+$") ~= nil, b:GetName())
    assertEqual(table.concat(b.__clicks, ","), "AnyUp,AnyDown")
    assertEqual(NS.SendEngine.ButtonCount(), 1)
end)

test("sendengine: Arm sends exactly the line; Disarm clears both attributes and sends nothing", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    assertTrue(NS.SendEngine.Arm(b, "/p Pulling next pack", { calloutId = "c1" }))
    assertEqual(b:GetAttribute("type"), "macro")
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, "/p Pulling next pack")
    assertEqual(#NS.SendEngine.ArmedButtons(), 1)
    assertTrue(NS.SendEngine.Disarm(b))
    assertNil(b:GetAttribute("type"))
    assertNil(b:GetAttribute("macrotext"))
    assertTrue(b:IsEnabled(), "never :Disable()")
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
end)

test("sendengine: in combat, building, arming and disarming are declined, so nothing is blocked", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Arm(b, "/p a", {})
    combat(m, true)
    assertNil(NS.SendEngine.NewButton(m.UIParent))
    assertFalse(NS.SendEngine.Arm(b, "/p b", {}))
    assertFalse(NS.SendEngine.Disarm(b))
    assertEqual(b:GetAttribute("macrotext"), "/p a", "frozen in combat")
    assertEqual(#m.blocked, 0)
end)

test("sendengine: RunOrQueue runs now out of combat", function()
    local NS = T.enableAddon()
    local ran = 0
    assertTrue(NS.SendEngine.RunOrQueue("k", function() ran = ran + 1 end))
    assertEqual(ran, 1)
    assertEqual(#NS.SendEngine.Snapshot(), 0)
end)

test("sendengine: in combat the queue keeps the last write per key and drains once at combat end", function()
    local NS, m = T.enableAddon()
    local ran, drained = {}, {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.COMBAT_QUEUE_DRAINED, function(_, n) drained[#drained + 1] = n end)
    combat(m, true)
    assertFalse(NS.SendEngine.RunOrQueue("k", function() ran[#ran + 1] = "first" end))
    NS.SendEngine.RunOrQueue("k", function() ran[#ran + 1] = "second" end)
    assertEqual(table.concat(NS.SendEngine.Snapshot(), ","), "k")
    assertEqual(#ran, 0)
    combat(m, false)
    -- red under: drop the RESTRICTION_CHANGED receiver in modules/SendEngine.lua
    assertEqual(table.concat(ran, ","), "second")
    assertEqual(table.concat(drained, ","), "1")
    assertEqual(#NS.SendEngine.Snapshot(), 0)
end)

test("sendengine: Drop empties the queue and nothing runs at combat end", function()
    local NS, m = T.enableAddon()
    local ran = 0
    combat(m, true)
    NS.SendEngine.RunOrQueue("k", function() ran = ran + 1 end)
    assertEqual(NS.SendEngine.Drop("test"), 1)
    combat(m, false)
    assertEqual(ran, 0)
end)

test("sendengine: a failing queued entry is reported and the others still run", function()
    local NS, m = T.enableAddon()
    local ran = 0
    combat(m, true)
    NS.SendEngine.RunOrQueue("bad", function() error("boom") end)
    NS.SendEngine.RunOrQueue("good", function() ran = ran + 1 end)
    m.prints = {}
    combat(m, false)
    assertEqual(ran, 1)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("bad", 1, true) ~= nil, m.prints[1])
end)

test("sendengine: Teardown in combat holds one PLAYER_REGEN_ENABLED and releases it when it fires", function()
    local NS, m = T.enableAddon()
    local function held()
        local n = 0
        for _, r in ipairs(m.__registrations()) do
            if r.event == "PLAYER_REGEN_ENABLED" and r.target ~= NS.addon then n = n + 1 end
        end
        return n
    end
    combat(m, true)
    local done = 0
    assertFalse(NS.SendEngine.Teardown(function() done = done + 1 end))
    assertEqual(held(), 1)
    combat(m, false)
    assertEqual(done, 1)
    assertEqual(held(), 0, "released the moment it fired")
end)

test("sendengine: CancelTeardown releases the held registration without running it", function()
    local NS, m = T.enableAddon()
    combat(m, true)
    local done = 0
    NS.SendEngine.Teardown(function() done = done + 1 end)
    NS.SendEngine.CancelTeardown()
    combat(m, false)
    assertEqual(done, 0)
end)

test("sendengine: the visibility driver is set out of combat and declined in it", function()
    local NS, m = T.enableAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    assertTrue(NS.SendEngine.SetVisibility(root, "hide"))
    assertFalse(root:IsShown())
    assertTrue(NS.SendEngine.SetVisibility(root, "show"))
    assertTrue(root:IsShown())
    combat(m, true)
    assertFalse(NS.SendEngine.SetVisibility(root, "hide"))
    assertFalse(NS.SendEngine.ClearVisibility(root))
    assertEqual(#m.blocked, 0)
    combat(m, false)
    assertTrue(NS.SendEngine.ClearVisibility(root))
    assertFalse(root:IsShown())
    assertNil(m.stateDrivers[root].visibility)
end)

test("sendengine: [firewall] no other shipped file makes a secure call (spec §9)", function()
    local FORBIDDEN = { "SetAttribute%(", "SetOverrideBinding", "ClearOverrideBindings", "RegisterStateDriver%(",
        "UnregisterStateDriver%(", "SecureActionButtonTemplate", "SecureHandler" }
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "modules/SendEngine.lua" then
            local src = read(rel)
            for _, pat in ipairs(FORBIDDEN) do
                assertTrue(not src:find(pat), rel .. " makes a secure call: " .. pat)
            end
        end
    end
    assertTrue(read("modules/SendEngine.lua"):find("SetAttribute%(") ~= nil, "the firewall file is the writer")
end)

test("sendengine: [D12] nothing calls SendChatMessage: the secure button is the one send path", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        assertTrue(not read(rel):find("SendChatMessage", 1, true), rel)
    end
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_sendengine",` to `tests/run.lua` after `"test_send_guard",`. Run: `lua tests/run.lua`
Expected: FAIL (`SendEngine` is nil).

- [ ] **Step 3: Write the module**

`modules/SendEngine.lua`:
```lua
local _, NS = ...
-- modules/SendEngine.lua — THE ONLY SECURE WRITER (spec §9, events-frames-taint-§2/§4). It alone
-- creates frames from a Secure* template, calls SetAttribute and registers or unregisters state
-- drivers; tests/test_sendengine.lua greps every other shipped file for those calls. Every write is
-- made out of combat. A caller asks through RunOrQueue, which runs the work now or, in combat
-- (InCombatLockdown(), never UnitAffectingCombat), files it under a key in the combat-end queue,
-- replacing an earlier entry under that key. The queue drains when RESTRICTION_CHANGED says the
-- combat edge has passed and InCombatLockdown() agrees (Restrictions owns PLAYER_REGEN_*), then
-- COMBAT_QUEUE_DRAINED (count) is sent. Drop empties it on stand-down and on a profile switch.
--
-- Send buttons (spec §9.1): SecureActionButtonTemplate, RegisterForClicks("AnyUp", "AnyDown") as the
-- go/no-go test needed for type=macro, named QuickCommsSend<n>. Arm writes type=macro and the baked
-- line as macrotext; Disarm writes both to nil and never calls :Disable() (the WhatGroup pattern).
-- Frames are never destroyed: the pads reuse them through NS.Pool. The shapes are ConsumableMaster's:
-- modules/MacroBarButton.lua `BB.Create` (built once, out of combat), modules/MacroManager.lua
-- `queueForCombat` / `M.FlushPending` (a keyed, last-write-wins queue flushed after combat), and
-- core/LifecycleSetup.lua `standDown` for the held teardown below.
--
-- Stand-down (spec §9.5, slash-commands-§7): Teardown(fn) runs the secure half now or, in combat,
-- holds it in the one registration a disabled addon may keep: a private AceEvent target listening
-- for PLAYER_REGEN_ENABLED, released the moment it fires. Its own target, because AceEvent keys a
-- handler by (event, object) and Restrictions holds PLAYER_REGEN_ENABLED on NS.addon.

NS.SendEngine = NS.SendEngine or {}
local SE = NS.SendEngine
local G = NS.SendGuard
local State = NS.State
local L = NS.L

local TAG_Q, TAG_S = "Queue", "Send"

local buttons = {}   -- every send button built this session, in build order
local seq = 0

local function inCombat() return NS.Compat.InCombat() end

local function queue()
    State.sendQueue = State.sendQueue or G.NewQueue()
    return State.sendQueue
end

-- ── send buttons ────────────────────────────────────────────────────────────────────────────

--- A new secure send button, or nil in combat (building a secure frame is out of combat only).
--- @param parent table the frame it belongs to (a pad's root)
--- @param onPress function|nil onPress(button, verdict, window), called by the click hook
--- @return table|nil
function SE.NewButton(parent, onPress)
    if inCombat() then
        NS.Debug(TAG_S, "button refused: in combat")
        return nil
    end
    seq = seq + 1
    local b = CreateFrame("Button", "QuickCommsSend" .. seq, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.qcOnPress = onPress
    b.qcArmed = false
    buttons[#buttons + 1] = b
    return b
end

function SE.ButtonCount()
    return #buttons
end

--- Arm a button with one baked line. Out of combat only; an unchanged line rewrites nothing.
--- @return boolean armed
function SE.Arm(b, line, meta)
    if inCombat() then
        NS.Debug(TAG_S, "arm refused: in combat")
        return false
    end
    if b.qcArmed and b:GetAttribute("macrotext") == line then
        b.qcMeta = meta
        return true
    end
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", line)
    b.qcArmed, b.qcMeta = true, meta
    return true
end

--- Disarm a button: nothing it does reaches chat. `meta` (optional) is what the click hook may
--- still use, such as a solo fallback's local print. Out of combat only.
--- @return boolean disarmed
function SE.Disarm(b, meta)
    if inCombat() then
        NS.Debug(TAG_S, "disarm refused: in combat")
        return false
    end
    if b.qcArmed or b:GetAttribute("type") ~= nil then
        b:SetAttribute("type", nil)
        b:SetAttribute("macrotext", nil)
    end
    b.qcArmed, b.qcMeta = false, meta
    return true
end

function SE.ArmedButtons()
    local out = {}
    for _, b in ipairs(buttons) do
        if b.qcArmed then out[#out + 1] = b end
    end
    return out
end

--- A button's baked line with its pipes doubled, for display (spec §16: shown escaped).
function SE.Escaped(b)
    local text = b:GetAttribute("macrotext")
    if type(text) ~= "string" then return "" end
    return (text:gsub("|", "||"))
end

-- ── visibility (spec §10.3): a state driver, never an insecure Show/Hide in combat ─────────

function SE.SetVisibility(frame, expression)
    if inCombat() then return false end
    RegisterStateDriver(frame, "visibility", expression)
    frame.qcDriver = expression
    return true
end

function SE.ClearVisibility(frame)
    if inCombat() then return false end
    if frame.qcDriver then
        UnregisterStateDriver(frame, "visibility")
        frame.qcDriver = nil
    end
    frame:Hide()
    return true
end

-- ── the combat-end queue (spec §9.1) ────────────────────────────────────────────────────────

function SE.Queue(key, fn)
    local replaced = G.Put(queue(), key, fn)
    NS.Debug(TAG_Q, "%s %s (%s pending)", replaced and "replaced" or "queued", key, G.Count(queue()))
end

--- Run `fn` now, or queue it under `key` until combat ends.
--- @return boolean ranNow
function SE.RunOrQueue(key, fn)
    if inCombat() then
        SE.Queue(key, fn)
        return false
    end
    fn()
    return true
end

--- Run every queued entry, in filing order, then send COMBAT_QUEUE_DRAINED. A failing entry is
--- reported on one line and the others still run.
--- @return number count
function SE.Drain(cause)
    if inCombat() then return 0 end
    local q = State.sendQueue
    if not q or G.Count(q) == 0 then return 0 end
    local entries = G.Take(q)
    for _, e in ipairs(entries) do
        local ok, err = pcall(e.fn)
        if not ok then NS.Print(L["A deferred update failed (%s): %s"]:format(e.key, tostring(err))) end
    end
    NS.Debug(TAG_Q, "drained %s (%s)", #entries, tostring(cause))
    NS.addon:SendMessage(NS.MSG.COMBAT_QUEUE_DRAINED, #entries)
    return #entries
end

--- Forget every queued entry (stand-down, profile switch).
--- @return number dropped
function SE.Drop(reason)
    local q = State.sendQueue
    local n = q and G.Count(q) or 0
    State.sendQueue = nil
    if n > 0 then NS.Debug(TAG_Q, "dropped %s (%s)", n, tostring(reason)) end
    return n
end

--- The pending keys, for diagnostics.
function SE.Snapshot()
    local q = State.sendQueue
    return q and G.Keys(q) or {}
end

-- ── the held stand-down (spec §9.5) ─────────────────────────────────────────────────────────

local pending   -- the private target; built on first use

local function releasePending()
    if pending then pending:UnregisterEvent("PLAYER_REGEN_ENABLED") end
end

--- Run the secure half of a stand-down now, or hold it until combat ends.
--- @return boolean ranNow
function SE.Teardown(fn)
    if not inCombat() then
        fn()
        return true
    end
    State.pendingTeardown = fn
    pending = pending or LibStub("AceEvent-3.0"):Embed({})
    pending:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        releasePending()
        local held = State.pendingTeardown
        State.pendingTeardown = nil
        if held then held() end
        NS.Debug(TAG_Q, "held stand-down finished")
    end)
    NS.Debug(TAG_Q, "stand-down held until combat ends")
    return false
end

--- A stand-up while a stand-down is held: the held half must not run any more.
function SE.CancelTeardown()
    if State.pendingTeardown == nil then return end
    State.pendingTeardown = nil
    releasePending()
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local function onRestrictionChanged()
    if not inCombat() then SE.Drain("RESTRICTION_CHANGED") end
end

-- Its own target (core/Bus.lua). On the tracked bus the stand-down and stand-up take it down and
-- replay it; on the degraded bus this module does both itself.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    SE.Drop("standDown")
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    SE.CancelTeardown()
    if not NS.Bus.tracked then listen() end
end
```

In `QuickComms.toc`, directly after `modules\SendEngine_Guard.lua`:
```
# Conventional: the only secure writer; appends to NS.STAND_DOWN / NS.STAND_UP (and, Task 4, NS.FEATURE_EVENTS)
modules\SendEngine.lua
```

In `.luacheckrc`, add to `read_globals`:
```lua
  -- modules/SendEngine.lua: the secure frame API (the firewall test keeps it in that one file).
  "CreateFrame", "UIParent", "RegisterStateDriver", "UnregisterStateDriver", "GetTime",
```

In `locales/enUS.lua`, add a `-- Send engine (modules/SendEngine.lua)` block:
```lua
L["A deferred update failed (%s): %s"] = "A deferred update failed (%s): %s"
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/SendEngine.lua tests/test_sendengine.lua QuickComms.toc tests/run.lua .luacheckrc locales/enUS.lua
git commit -m "SendEngine: secure send buttons, keyed combat-end queue, held stand-down, firewall test"
```

---

### Task 4: SendEngine: the click hook, the soft guard, the echo tracker, SEND_RESULT

**Files:**
- Modify: `modules/SendEngine.lua` (one line in `SE.NewButton`; append the click and echo section)
- Modify: `core/Compat.lua` (two readers), `core/PerfSetup.lua` (two buckets)
- Modify: `tests/test_sendengine.lua` (append), `tests/test_compat.lua` (append), `tests/test_disabled.lua` (the pinned event list)
- Modify: `.luacheckrc`, `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 2's `G.IsActingEdge`, `G.Decide`, `G.Remaining`, `G.NewEcho`, `G.Record`, `G.Match`, `G.Expire`, `G.ECHO_EVENTS`, `G.CHAT_TYPE_BY_EVENT`, `G.ECHO_WINDOW`; Task 3's button fields; `NS.Setting("behavior.spamGuard")`, `NS.Setting("behavior.dropNotes")`.
- Produces:
  - `SE.OnClick(button, mouseButton, down)` (the hook every send button carries)
  - `SE.GuardState() -> { window, last, remaining }`, `SE.EchoState() -> { pending, sent, dropped, unknown, ignored }`
  - Message `SEND_RESULT (calloutId, surfaceId, result)` with `result` `"guarded"` (at the press, when inside the window), then `"sent"` or `"dropped"` (from the echo). One press can produce `guarded` and then `sent` or `dropped` (controller ruling, 2026-10-13; Task 13 writes it into spec §17).
  - `NS.Compat.UseKeyDown() -> boolean`, `NS.Compat.SenderIsPlayer(sender, guid) -> true | false | nil`
  - Feature events: the nine `CHAT_MSG_*` of `G.ECHO_EVENTS`, handler `NS.addon.OnSendEcho`
  - Perf buckets `send.click`, `echo.match`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_compat.lua`:
```lua
test("compat: UseKeyDown reads the cvar, and defaults on when it cannot", function()
    local NS, env = T.newAddon()
    assertTrue(NS.Compat.UseKeyDown())
    env.cvars.ActionButtonUseKeyDown = "0"
    assertFalse(NS.Compat.UseKeyDown())
    env.C_CVar, env.GetCVarBool = nil, nil
    assertTrue(NS.Compat.UseKeyDown())
end)

test("compat: SenderIsPlayer answers by GUID, then by name, and nil when it cannot read either", function()
    local NS, env = T.newAddon()
    env.issecretvalue = T.isSecret
    local C = NS.Compat
    assertTrue(C.SenderIsPlayer("Someone", env.playerGUID), "the GUID decides")
    assertFalse(C.SenderIsPlayer("Testchar", "Player-1-99999999"), "a readable other GUID")
    assertTrue(C.SenderIsPlayer("Testchar-Testrealm", nil), "the name, realm stripped")
    assertFalse(C.SenderIsPlayer("Other-Testrealm", nil))
    assertNil(C.SenderIsPlayer(T.secret("Testchar"), T.secret("guid")), "secret is unknown")
    assertNil(C.SenderIsPlayer(nil, nil))
end)
```

Append to `tests/test_sendengine.lua`:
```lua
-- ── the click, the guard and the echo (spec §9.2, §9.3) ─────────────────────────────────────

local META = { calloutId = "c1", surfaceId = "p1", chatType = "PARTY", name = "Pull" }

local function armed(NS, m, meta)
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Arm(b, "/p Pulling", meta or META)
    return b
end

local function results(NS)
    local out = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function(_, cid, sid, what) out[#out + 1] = cid .. "@" .. sid .. "=" .. what end)
    return out
end

-- A CHAT_MSG_* as the client sends it: text, sender, then nine fields, then the sender's GUID.
local function echo(m, event, sender, guid)
    m.__fire(event or "CHAT_MSG_PARTY", "never read", sender or "Testchar-Testrealm", "", "", "", "", 0, 0, "", 0, 1,
        guid or m.playerGUID)
end

test("send: one press is one send and one pending echo, though the hook hears both edges", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    m.__now = 100
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    -- red under: drop the IsActingEdge check from SE.OnClick
    assertEqual(NS.SendEngine.EchoState().pending, 1)
    m.__now = 100.6
    echo(m)
    assertEqual(table.concat(out, ","), "c1@p1=sent")
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("send: [review 3] a double press in a boss: guarded, then dropped, with one note, never canceled", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    m.__now = 100
    m.__click(b)
    m.__now = 100.3
    m.__click(b)
    assertEqual(#m.sentMacros, 2, "soft: the guard never cancels a click")
    assertEqual(table.concat(out, ","), "c1@p1=guarded")
    m.__now = 100.8
    echo(m)                               -- the game delivered only the first
    m.prints = {}
    m.__now = 102.5
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=guarded,c1@p1=sent,c1@p1=dropped")
    assertEqual(#m.prints, 1, "exactly one note")
    assertTrue(m.prints[1]:find("Pull", 1, true) ~= nil, m.prints[1])
end)

test("send: the drop note follows behavior.dropNotes", function()
    local NS, m = T.enableAddon()
    NS.SchemaRuntime.Set("behavior.dropNotes", false)
    local out = results(NS)
    m.__now = 100
    m.__click(armed(NS, m))
    m.prints = {}
    m.__now = 103
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=dropped")
    assertEqual(#m.prints, 0)
end)

test("send: presses further apart than the guard are never guarded", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    m.__now = 100
    m.__click(b)
    m.__now = 101.2
    m.__click(b)
    assertEqual(#out, 0)
end)

test("send: an unreadable sender counts as our echo and is never a drop", function()
    local NS, m = T.enableAddon()
    m.issecretvalue = T.isSecret
    local out = results(NS)
    m.__now = 100
    m.__click(armed(NS, m))
    echo(m, "CHAT_MSG_PARTY_LEADER", T.secret("Someone"), T.secret("Player-1-2"))
    m.__now = 103
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=sent")
    assertEqual(NS.SendEngine.EchoState().unknown, 1)
end)

test("send: another player's message on the channel is not our echo", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    m.__now = 100
    m.__click(armed(NS, m))
    echo(m, "CHAT_MSG_PARTY", "Other-Testrealm", "Player-1-99999999")
    m.__now = 103
    m.__fireTimers()
    assertEqual(table.concat(out, ","), "c1@p1=dropped")
end)

test("send: a disarmed button reports nothing and tracks nothing", function()
    local NS, m = T.enableAddon()
    local out = results(NS)
    local b = armed(NS, m)
    NS.SendEngine.Disarm(b)
    m.__click(b)
    assertEqual(#out, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("send: a solo self-fallback prints locally and sends nothing", function()
    local NS, m = T.enableAddon()
    local b = NS.SendEngine.NewButton(m.UIParent)
    NS.SendEngine.Disarm(b, { calloutId = "c1", surfaceId = "p1", selfText = "Lust on this pack" })
    m.prints = {}
    m.__click(b)
    assertEqual(#m.sentMacros, 0)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Lust on this pack", 1, true) ~= nil)
end)

test("send: onPress hears the verdict and the window", function()
    local NS, m = T.enableAddon()
    local heard = {}
    local b = NS.SendEngine.NewButton(m.UIParent, function(_, verdict, window) heard[#heard + 1] = verdict .. ":" .. window end)
    NS.SendEngine.Arm(b, "/p a", META)
    m.__now = 100
    m.__click(b)
    m.__now = 100.2
    m.__click(b)
    assertEqual(table.concat(heard, ","), "ok:1,guarded:1")
end)

test("send: every echo event is a declared feature event", function()
    local NS = T.newAddon()
    local declared = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do declared[row[1]] = row[2] end
    for _, event in ipairs(NS.SendGuard.ECHO_EVENTS) do assertEqual(declared[event], "OnSendEcho", event) end
end)

test("send: the stand-down cancels the echo timers and forgets the presses", function()
    local NS, m = T.enableAddon()
    m.__click(armed(NS, m))
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(#m.__timers(), 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)
```

In `tests/test_disabled.lua`, replace the `PINNED` table with:
```lua
local PINNED = {
    "ADDON_RESTRICTION_STATE_CHANGED", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "CHALLENGE_MODE_START",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_DIFFICULTY_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ROLES_ASSIGNED", "PLAYER_SPECIALIZATION_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
}
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`UseKeyDown` is nil; no `SEND_RESULT` is sent; `disabled 1` differs).

- [ ] **Step 3: Write the readers, the hook and the echo**

Append to `core/Compat.lua`:
```lua
-- ── The send engine (spec §9.2, §9.3) ────────────────────────────────────────────────────────

--- True when secure action buttons act on key DOWN: the ActionButtonUseKeyDown cvar, on by
--- default in the client, and assumed on when it cannot be read.
function Compat.UseKeyDown()
    local cv = C_CVar
    local get = (cv and cv.GetCVarBool) or GetCVarBool
    if not get then return true end
    local v = get("ActionButtonUseKeyDown")
    if Compat.IsSecret(v) then return true end
    return v == true
end

--- Whether a chat line came from the player: true, false, or nil when neither the GUID nor the
--- name can be read (secret or absent). Never compares a secret.
function Compat.SenderIsPlayer(sender, guid)
    local g = PlainString(guid)
    local me = UnitGUID and PlainString(UnitGUID("player")) or nil
    if g and me then return g == me end
    local name = PlainString(sender)
    if not name then return nil end
    local mine = UnitName and PlainString((UnitName("player"))) or nil
    if not mine then return nil end
    return (name:match("^([^%-]+)") or name) == mine
end
```

In `modules/SendEngine.lua`, inside `SE.NewButton`, directly after `b:RegisterForClicks("AnyUp", "AnyDown")`, add:
```lua
    b:HookScript("OnClick", function(...) SE.OnClick(...) end)
```
Also add `local Perf = NS.Perf` directly under `local L = NS.L`, and extend the file's header comment with:
```lua
--
-- The click (spec §9.2, §9.3): every button carries one insecure OnClick HOOK, which never taints the
-- secure path and cannot cancel it. On the acting edge it runs the soft guard (SEND_RESULT
-- "guarded" inside the window; onPress dims the pads), records the press for the echo tracker and
-- schedules its expiry. The CHAT_MSG_* rows below match echoes without reading their text.
```

Then insert this section into `modules/SendEngine.lua` directly **above** the `-- ── the edge ──` section:
```lua
-- ── the click, the soft guard and the echo tracker (spec §9.2, §9.3) ────────────────────────

local function echoState()
    State.sendEcho = State.sendEcho or G.NewEcho()
    return State.sendEcho
end

local function result(meta, what)
    NS.Debug(what == "guarded" and "Guard" or "Echo", "%s %s on %s", meta.calloutId, what, meta.surfaceId)
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, meta.calloutId, meta.surfaceId, what)
end

local function expire()
    local e = State.sendEcho
    if not e then return end
    for _, p in ipairs(G.Expire(e, GetTime())) do
        result(p.meta, "dropped")
        if NS.Setting("behavior.dropNotes") then
            NS.Print(L["%s may have been dropped by the game (sent too soon after another message)."]
                :format(tostring(p.meta.name)))
        end
    end
end

local function scheduleExpiry()
    State.echoTimers = State.echoTimers or {}
    local handle
    handle = NS.addon:ScheduleTimer(function()
        State.echoTimers[handle] = nil
        expire()
    end, G.ECHO_WINDOW + 0.05)
    State.echoTimers[handle] = true
end

local function useKeyDown(b)
    local v = b:GetAttribute("useOnKeyDown")
    if v == nil then return NS.Compat.UseKeyDown() end
    return v == true
end

local function press(b)
    local meta = b.qcMeta
    if not meta or NS.IsStoodDown() then return end
    if meta.selfText then
        NS.Print(meta.selfText)
        return
    end
    if not (b.qcArmed and meta.chatType) then return end
    local now = GetTime()
    local window = NS.Setting("behavior.spamGuard")
    local verdict = G.Decide(now, State.lastSendAt, window)
    State.lastSendAt = now
    G.Record(echoState(), now, meta.chatType, meta)
    scheduleExpiry()
    if verdict == "guarded" then result(meta, "guarded") end
    if b.qcOnPress then b.qcOnPress(b, verdict, window) end
end

--- The OnClick hook every send button carries. Acts once per press, on the edge the secure
--- template acts on.
function SE.OnClick(b, _, down)
    if not G.IsActingEdge(down, useKeyDown(b)) then return end
    local t0 = Perf.on and debugprofilestop()
    press(b)
    if t0 then Perf.Note("send.click", debugprofilestop() - t0) end
end

function SE.GuardState()
    local window = NS.Setting("behavior.spamGuard")
    return { window = window, last = State.lastSendAt, remaining = G.Remaining(GetTime(), State.lastSendAt, window) }
end

function SE.EchoState()
    local e = State.sendEcho or G.NewEcho()
    return { pending = #e.pending, sent = e.sent, dropped = e.dropped, unknown = e.unknown, ignored = e.ignored }
end

for _, event in ipairs(G.ECHO_EVENTS) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSendEcho" }
end

-- CHAT_MSG_* (text, sender, ..., guid as the 12th payload field). The text is never read (F7).
function NS.addon.OnSendEcho(_, event, ...)
    local e = State.sendEcho
    if not (e and e.pending[1]) then return end
    local t0 = Perf.on and debugprofilestop()
    local sender = select(2, ...)
    local guid = select(12, ...)
    local hit = G.Match(e, G.CHAT_TYPE_BY_EVENT[event], GetTime(), NS.Compat.SenderIsPlayer(sender, guid))
    if hit then result(hit.meta, "sent") end
    if t0 then Perf.Note("echo.match", debugprofilestop() - t0) end
end

-- Stood down, no echo can arrive: the timers are canceled and the presses forgotten.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.echoTimers or {}) do NS.addon:CancelTimer(handle) end
    State.echoTimers, State.sendEcho, State.lastSendAt = nil, nil, nil
end
```

In `core/PerfSetup.lua`, replace `local BUCKETS = {}` with:
```lua
local BUCKETS = {
    { key = "send.click" },   -- modules/SendEngine.lua: the OnClick hook
    { key = "echo.match" },   -- modules/SendEngine.lua: a CHAT_MSG_* echo while a press waits
}
```
and change the comment above it from "None is declared yet: the scaffold has no hot path." to "Phase 2 declares the send engine's and the pad's."

In `.luacheckrc`, add to `read_globals`:
```lua
  "C_CVar", "GetCVarBool", "UnitGUID", "UnitName",
```

In `locales/enUS.lua`, in the Send engine block:
```lua
L["%s may have been dropped by the game (sent too soon after another message)."] =
    "%s may have been dropped by the game (sent too soon after another message)."
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including `perf: every declared bucket has a bracket` and `disabled 1`/`disabled 2`.

- [ ] **Step 5: Commit**

```bash
git add modules/SendEngine.lua core/Compat.lua core/PerfSetup.lua tests/test_sendengine.lua tests/test_compat.lua tests/test_disabled.lua .luacheckrc locales/enUS.lua
git commit -m "SendEngine: click hook, soft spam guard, echo tracker and SEND_RESULT"
```

---
### Task 5: Preview: test mode

**Files:**
- Create: `modules/Preview.lua`
- Create: `tests/test_preview.lua`
- Modify: `QuickComms.toc` (after `modules\SendEngine.lua`), `tests/run.lua` (add `"test_preview",` after `"test_sendengine",`), `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.Restrictions.InCombat()`, `NS.Compat.InCombat()`, `NS.IsStoodDown()`, `NS.SlashCommands:DisabledLine()`, `NS.MSG.RESTRICTION_CHANGED`, `NS.MSG.TEST_MODE_CHANGED`, `NS.addon.Settings.Helpers.RefreshAll`.
- Produces `NS.Preview` (`P`):
  - `P.IsTestMode() -> boolean`
  - `P.SetTestMode(on) -> changed` (refused with one printed line in combat or while stood down)
  - `P.ToggleTestMode() -> changed`
  - Message `TEST_MODE_CHANGED (on)`; session state `NS.State.testMode`.

- [ ] **Step 1: Write the failing test**

`tests/test_preview.lua`:
```lua
-- tests/test_preview.lua — test mode (spec §10.4, preview-mode, options-ui-§15): session-only,
-- refused in combat with one line, ended when combat starts, ended silently by the stand-down.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local function heard(NS)
    local out = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.TEST_MODE_CHANGED, function(_, on) out[#out + 1] = tostring(on) end)
    return out
end

test("preview: test mode turns on and off, announcing each edge once", function()
    local NS = T.enableAddon()
    local out = heard(NS)
    assertTrue(NS.Preview.SetTestMode(true))
    assertTrue(NS.Preview.IsTestMode())
    assertFalse(NS.Preview.SetTestMode(true), "already on: no edge")
    assertTrue(NS.Preview.ToggleTestMode())
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(table.concat(out, ","), "true,false")
end)

test("preview: a start in combat is refused with one line", function()
    local NS, m = T.enableAddon()
    combat(m, true)
    m.prints = {}
    assertFalse(NS.Preview.SetTestMode(true))
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("not available in combat", 1, true) ~= nil, m.prints[1])
end)

test("preview: the start of combat ends test mode, with one line", function()
    local NS, m = T.enableAddon()
    local out = heard(NS)
    NS.Preview.SetTestMode(true)
    m.prints = {}
    combat(m, true)
    -- red under: drop the RESTRICTION_CHANGED receiver in modules/Preview.lua
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(table.concat(out, ","), "true,false")
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("entered combat", 1, true) ~= nil, m.prints[1])
end)

test("preview: test mode still ends when lockdown has already begun at the combat edge", function()
    local NS, m = T.enableAddon()
    NS.Preview.SetTestMode(true)
    m.__setCombat(true)                    -- InCombatLockdown() is already true when the edge fires
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.blocked, 0)
end)

test("preview: the stand-down ends test mode silently, and stood down a start is refused", function()
    local NS, m = T.enableAddon()
    NS.Preview.SetTestMode(true)
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Preview.IsTestMode())
    m.prints = {}
    assertFalse(NS.Preview.SetTestMode(true))
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("is disabled", 1, true) ~= nil, m.prints[1])
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_preview",` to `tests/run.lua` after `"test_sendengine",`. Run: `lua tests/run.lua`
Expected: FAIL (`Preview` is nil).

- [ ] **Step 3: Write the module**

`modules/Preview.lua`:
```lua
local _, NS = ...
-- modules/Preview.lua — test mode (spec §10.4, preview-mode, options-ui-§15) and the one sender of
-- TEST_MODE_CHANGED (spec §17). Phase 2 owns the switch; "Preview as…" (spec §13.3) joins this file
-- in phase 3. Session-only (NS.State.testMode, never saved): refused while stood down or in combat
-- with one line, ended when combat starts (while secure writes are still allowed, so the pads swap
-- back to live chips at once), and ended by the stand-down. The checkbox, the `test` verb and the
-- launcher entry all call SetTestMode. Copied from DropWatcher core/DropWatcher.lua `NS.SetTestMode`,
-- `testModeRefusal` and `DW.OnCombatStart`; the combat edge arrives as RESTRICTION_CHANGED here,
-- because modules/Restrictions.lua owns PLAYER_REGEN_DISABLED.

NS.Preview = NS.Preview or {}
local P = NS.Preview
local State = NS.State
local L = NS.L

local function fighting()
    return NS.Restrictions.InCombat() or NS.Compat.InCombat()
end

-- The Test mode checkbox follows every start and stop (options-ui-§15).
local function refreshPanel()
    local S = NS.addon.Settings
    local H = S and S.Helpers
    if H and H.RefreshAll then H.RefreshAll() end
end

function P.IsTestMode()
    return State.testMode == true
end

--- Turn test mode on or off. A start is refused, with one line, while stood down or in combat.
--- @return boolean changed
function P.SetTestMode(on)
    on = on and true or false
    if on == P.IsTestMode() then return false end
    if on then
        if NS.IsStoodDown() then
            NS.Print(NS.SlashCommands:DisabledLine())
            return false
        end
        if fighting() then
            NS.Print(L["Test mode is not available in combat."])
            return false
        end
    end
    State.testMode = on
    NS.Debug("Pad", "test mode %s", on and "on" or "off")
    NS.addon:SendMessage(NS.MSG.TEST_MODE_CHANGED, on)
    refreshPanel()
    return true
end

function P.ToggleTestMode()
    return P.SetTestMode(not P.IsTestMode())
end

local function onRestrictionChanged()
    if P.IsTestMode() and NS.Restrictions.InCombat() then
        P.SetTestMode(false)
        NS.Print(L["Test mode ended: you entered combat."])
    end
end

-- Its own target (core/Bus.lua); the degraded bus is handled here, as in modules/Situation.lua.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.testMode = nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
```

In `QuickComms.toc`, directly after `modules\SendEngine.lua`:
```
# Conventional: test mode, TEST_MODE_CHANGED's sender; appends to NS.STAND_DOWN / NS.STAND_UP
modules\Preview.lua
```

In `locales/enUS.lua`, add a `-- Test mode (modules/Preview.lua)` block:
```lua
L["Test mode is not available in combat."] = "Test mode is not available in combat."
L["Test mode ended: you entered combat."] = "Test mode ended: you entered combat."
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/Preview.lua tests/test_preview.lua QuickComms.toc tests/run.lua locales/enUS.lua
git commit -m "Preview: session test mode, refused and ended by combat"
```

---

### Task 6: Master controls with lock, test mode and Reset position; the verbs and the launcher entries

**Files:**
- Modify: `defaults/Profile.lua` (four Master controls values)
- Modify: `settings/Panel.lua` (the `MasterControls` call and the header comment)
- Modify: `settings/Schema.lua` (the `state.testMode` session row, `REACTIONS`, `Settings.RebuildSurfaces`)
- Modify: `settings/SchemaRows.lua` (`onChange` on the Behavior rows that change a pad)
- Modify: `settings/SlashVerbs.lua` (`SetLocked`, `ToggleLock`), `settings/Slash.lua` (`lock`, `unlock`, `test` rows)
- Modify: `core/LauncherSetup.lua` (Locked and Test mode entries)
- Create: `tests/test_master.lua`
- Modify: `tests/test_schema.lua`, `tests/test_setup.lua`, `tests/run.lua` (add `"test_master",` after `"test_preview",`), `locales/enUS.lua`

**Interfaces:**
- Consumes: Task 5's `NS.Preview.IsTestMode` / `SetTestMode` / `ToggleTestMode`. At run time only, and only when present: `NS.Surfaces.Request(reason)` (Task 11), `NS.Pad.ApplyLock()` and `NS.Pad.ResetPositions()` (Task 10).
- Produces:
  - profile defaults `visibility = "always"`, `scale = 1.0`, `alpha = 1.0`, `locked = true` (spec §5.1) and their composed rows at paths `visibility`, `scale`, `alpha`, `locked`
  - the session row `state.testMode`
  - `Settings.RebuildSurfaces()` (a reaction other rows reuse)
  - `NS.SlashVerbs.SetLocked(on)`, `NS.SlashVerbs.ToggleLock()`
  - verbs `/qc lock`, `/qc unlock`, `/qc test`; launcher entries Locked and Test mode

- [ ] **Step 1: Write the failing tests**

`tests/test_master.lua`:
```lua
-- tests/test_master.lua — the Master controls the Comms Pad brings back (options-ui-§15): the lock
-- and test mode, each driven from the panel row, the verb and the launcher entry through ONE
-- handler (slash-commands-§8, launcher-§2, preview-mode).

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local function openMenu(m)
    local root = { boxes = {} }
    function root.CreateTitle(_, t) root.title = t end
    function root.CreateCheckbox(_, label, isChecked, onClick)
        local box = { label = label, checked = isChecked, click = onClick }
        root.boxes[#root.boxes + 1] = box
        return box
    end
    m.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    m.ldbObjects.QuickComms.OnClick(m.UIParent, "RightButton")
    return root
end

test("master: the frame defaults are spec §5.1's: always shown, scale and alpha 1, locked", function()
    local NS = T.bootAddon()
    local p = NS.db.profile
    assertEqual(p.visibility, "always")
    assertEqual(p.scale, 1.0)
    assertEqual(p.alpha, 1.0)
    assertEqual(p.locked, true)
end)

test("master: /qc unlock and /qc lock write the Lock frame row's path and confirm on one line", function()
    local NS, m = T.enableAddon()
    m.prints = {}
    NS.addon:OnSlashCommand("unlock")
    assertFalse(NS.Setting("locked"))
    assertEqual(#m.prints, 1)
    NS.addon:OnSlashCommand("lock")
    assertTrue(NS.Setting("locked"))
end)

test("master: the launcher's Locked and Test mode entries call the same handlers", function()
    local NS, m = T.enableAddon()
    local boxes = openMenu(m).boxes
    assertEqual(boxes[2].label, "Locked")
    assertEqual(boxes[3].label, "Test mode")
    boxes[2].click()
    assertFalse(NS.Setting("locked"))
    boxes[3].click()
    assertTrue(NS.Preview.IsTestMode())
end)

test("master: /qc test toggles test mode, and in combat says why it will not", function()
    local NS, m = T.enableAddon()
    NS.addon:OnSlashCommand("test")
    assertTrue(NS.Preview.IsTestMode())
    NS.addon:OnSlashCommand("test")
    assertFalse(NS.Preview.IsTestMode())
    combat(m, true)
    m.prints = {}
    NS.addon:OnSlashCommand("test")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.prints, 1)
end)

test("master: the Test mode row reads and writes the one switch, and Reset all ends it", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    S.Set("state.testMode", true)
    assertTrue(NS.Preview.IsTestMode())
    assertTrue(S.Get("state.testMode"))
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    -- red under: drop the state.testMode entry from SESSION in settings/Schema.lua
    assertFalse(NS.Preview.IsTestMode())
end)
```

In `tests/test_schema.lua`, replace the test `"schema: the Master controls rows are the frameless canonical set, in the canonical order"` with:
```lua
test("schema: the Master controls rows are the framed canonical set, in the canonical order", function()
    local NS = T.newAddon()
    local paths = {}
    for i, row in ipairs(NS.addon.Settings.Schema) do paths[i] = row.path end
    -- red under: put `frameless = true` back in settings/Panel.lua (the pad has a frame to lock)
    -- The Master controls block leads; the Behavior rows (settings/SchemaRows.lua) follow it.
    assertEqual(table.concat(paths, ",", 1, 8),
        "enabled,visibility,scale,alpha,locked,state.debugConsole,global.minimap.shown,state.testMode")
    assertEqual(paths[9], "behavior.soloFallback")
end)
```
and replace the test `"schema: degraded, a row-less path not in the list is still refused"` with:
```lua
test("schema: degraded, a row-less path not in the list is still refused", function()
    local D = T.bootAddon{ skip = NO_LIBKA0S }
    assertFalse(D.SchemaRuntime.Set("locked", false))
    assertEqual(D.addon.db.profile.locked, true, "nothing stored: the default stands")
end)
```

In `tests/test_setup.lua`, replace the test `"launcher: the right-click menu is Enabled alone"` with:
```lua
test("launcher: the right-click menu is Enabled, Locked and Test mode", function()
    local _, _, m = T.enableAddon()
    local root = openMenu(m)
    assertEqual(root.title, "Ka0s Quick Comms")
    local labels = {}
    for i, box in ipairs(root.boxes) do labels[i] = box.label end
    -- red under: drop isTestMode/toggleTestMode from core/LauncherSetup.lua
    assertEqual(table.concat(labels, ","), "Enabled,Locked,Test mode")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_master",` to `tests/run.lua` after `"test_preview",`. Run: `lua tests/run.lua`
Expected: FAIL (no `locked` default, no `unlock` verb, the frameless row list).

- [ ] **Step 3: Write the defaults, rows, verbs and launcher entries**

In `defaults/Profile.lua`, replace the line `enabled = true,   -- master switch (the `disabled` hold reads it)` with:
```lua
        enabled    = true,       -- master switch (the `disabled` hold reads it)
        visibility = "always",   -- Master controls: General visibility (options-ui-§15)
        scale      = 1.0,        -- Master scale, multiplied into every pad's own scale
        alpha      = 1.0,        -- Master alpha, the ceiling of every pad's fade
        locked     = true,       -- Lock frame: pads start locked (spec §5.1)
```

In `settings/Panel.lua`, replace the `Helpers.MasterControls{…}` call with:
```lua
local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{
    prefix           = "",
    page             = "general",
    addonName        = NS.BRAND,
    debugConsolePath = "state.debugConsole",
    minimapPath      = Settings.MINIMAP_PATH,
    testModePath     = "state.testMode",
    defaults         = {
        enabled = C.PROFILE.enabled, visibility = C.PROFILE.visibility, scale = C.PROFILE.scale,
        alpha = C.PROFILE.alpha, locked = C.PROFILE.locked, debugConsole = false, testMode = false,
    },
    -- Reset position resets every pad's anchor (spec §10.4); the dials join it in phase 4.
    onResetPosition  = function() if NS.Pad and NS.Pad.ResetPositions then NS.Pad.ResetPositions() end end,
    onResetAll       = showResetPopup,
}
```
and replace the header sentences "Nothing positionable is drawn yet, so the block is `frameless` (no Master scale, Master alpha, Lock frame or Reset position) and omits General visibility; the Comms Pad brings those rows and Test mode back (design spec §10.3/§10.4)." with "The Comms Pad is positionable, so the block is the full framed set: General visibility, Master scale and alpha, Lock frame, Test mode and Reset position (design spec §10.3/§10.4)."

In `settings/Schema.lua`, add to the `SESSION` table (after `state.debugConsole`):
```lua
    -- Test mode (spec §10.4): the one switch is modules/Preview.lua's; the row reads and writes it.
    ["state.testMode"] = {
        get = function() return NS.Preview ~= nil and NS.Preview.IsTestMode() end,
        set = function(v) if NS.Preview then NS.Preview.SetTestMode(v and true or false) end end,
    },
```
and replace the `Settings.REACTIONS = {…}` table with:
```lua
-- A write that changes what a pad draws asks the surfaces for one rebuild, which waits for the end
-- of combat on its own (spec §13.1: setters that rebuild secure frames queue through SendEngine).
local function rebuildSurfaces()
    if NS.Surfaces and NS.Surfaces.Request then NS.Surfaces.Request("settings") end
end
Settings.RebuildSurfaces = rebuildSurfaces

Settings.REACTIONS = {
    enabled = function(v)
        if NS.Lifecycle then NS.Lifecycle:Set(NS.HOLD_DISABLED, v == false) end
    end,
    visibility = rebuildSurfaces,
    scale      = rebuildSurfaces,
    alpha      = rebuildSurfaces,
    -- The drag strip is not protected: it shows and hides at once, in combat too.
    locked     = function() if NS.Pad and NS.Pad.ApplyLock then NS.Pad.ApplyLock() end end,
}
```
Also change the comment "Test mode joins it with the Comms Pad (design spec §10.4)." above `SESSION` to "And the test mode (design spec §10.4)."

In `settings/SchemaRows.lua`, add `local rebuild = NS.addon.Settings.RebuildSurfaces` under `local B = NS.C.PROFILE.behavior`, and add `onChange = rebuild,` to the `behavior.soloFallback`, `behavior.lockdownChip` and `behavior.autoPromote` rows (each changes a pad's baked lines, chip or order).

In `settings/SlashVerbs.lua`, append:
```lua
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
```
and change its header's "Today: `check`." to "Today: `check`, `lock` and `unlock`."

In `settings/Slash.lua`, add directly after the `disable` row:
```lua
    {"lock",     L["Lock the Comms Pads in place"],
        function() NS.SlashVerbs.SetLocked(true) end},
    {"unlock",   L["Unlock the Comms Pads so they can be dragged"],
        function() NS.SlashVerbs.SetLocked(false) end},
```
and directly after the `check` row:
```lua
    {"test",     L["Turn test mode on or off (placeholder chips; combat ends it)"],
        function() NS.Preview.ToggleTestMode() end},
```
and change the header's "(§14: lock, unlock and test with the Comms Pad; preview and why with the features they report on; check is here)" to "(§14: preview and why arrive with the features they report on; check, lock, unlock and test are here)".

In `core/LauncherSetup.lua`, add after `setEnabled = …`:
```lua

    -- The Lock frame row's path and the test-mode switch, each through the handler its verb and its
    -- Master controls row call (launcher-§2, slash-commands-§8, preview-mode).
    isLocked       = function() return NS.SchemaRuntime ~= nil and NS.SchemaRuntime.Get("locked") ~= false end,
    toggleLock     = function() NS.SlashVerbs.ToggleLock() end,
    isTestMode     = function() return NS.Preview ~= nil and NS.Preview.IsTestMode() end,
    toggleTestMode = function() NS.Preview.ToggleTestMode() end,
```
and replace the header's "Today that is Enabled alone, calling the handler `/qc enable|disable` calls (settings/Slash.lua). Locked and Test mode join it with the Comms Pad, which brings the lock and the preview they toggle (design spec §16)." with "Enabled calls the handler `/qc enable|disable` calls (settings/Slash.lua); Locked calls `/qc lock|unlock`'s, and Test mode `/qc test`'s (design spec §16)."

In `locales/enUS.lua`, in the slash-command block:
```lua
L["Lock the Comms Pads in place"] = "Lock the Comms Pads in place"
L["Unlock the Comms Pads so they can be dragged"] = "Unlock the Comms Pads so they can be dragged"
L["Turn test mode on or off (placeholder chips; combat ends it)"] =
    "Turn test mode on or off (placeholder chips; combat ends it)"
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including the kit's `test_diagnostics_contract` (the new rows appear in its settings walk) and `disabled 5` (the new verbs are feature verbs, refused while disabled).

- [ ] **Step 5: Commit**

```bash
git add defaults/Profile.lua settings/ core/LauncherSetup.lua tests/test_master.lua tests/test_schema.lua tests/test_setup.lua tests/run.lua locales/enUS.lua
git commit -m "Master controls: lock, test mode, Reset position; lock/unlock/test verbs and launcher entries"
```

---

### Task 7: Pad_Layout: the pad's geometry, visibility and fade (pure)

**Files:**
- Create: `modules/Pad_Layout.lua`
- Create: `tests/test_pad_layout.lua`
- Modify: `QuickComms.toc` (after `modules\Preview.lua`), `tests/run.lua` (add `"test_pad_layout",` after `"test_master",`)

**Interfaces:**
- Consumes: nothing.
- Produces `NS.PadLayout` (`PL`):
  - constants `HEADER_H = 18`, `PAD = 4`, `SECTION_H = 14`, `CHIP_H = 24`, `ICON = 20`, `ICON_ONLY = 28`, `LABEL_H = 22`, `MIN_W = 120`, `DEFAULT_W = 140`
  - `PL.Tag(concrete) -> "P" | "R" | "I" | "RW" | "S" | "Y" | nil`
  - `PL.ClampTab(tab, n) -> i`, `PL.NextTab(tab, n, delta) -> i` (wheel up, `delta > 0`, goes back one; wraps)
  - `PL.VisibleSections(sections, groupsAs, tab) -> sections` (`groupsAs` `"sections"` | `"merged"` | `"tabs"`; a tab section carries `tabIndex`, `tabCount`)
  - `PL.CellSize(layout) -> w, h`, `PL.Columns(layout, count) -> cols`
  - `PL.Compute(sections, layout, opts) -> { width, height, items }`; an item is `{ kind = "title", text, tabIndex, tabCount, x, y, w, h }` or `{ kind = "chip", slot, row, col, x, y, w, h }`, with `x`/`y` offsets from the root's TOPLEFT, y growing down. `opts.collapsed` draws the header only.
  - `PL.VisibilityDriver(master, padVis, hasActive, testMode) -> "show" | "hide" | "[combat] show; hide" | "[combat] hide; show"`
  - `PL.Alpha(masterAlpha, look, inCombat, hovered) -> 0..1`
  - A section is `{ title, slots = { slot… } }`; `layout` is the pad's `{ orientation, columns, growth, style, scale, spacing, width }` (Library's `SURFACE_DEFAULTS.pad.layout`).

- [ ] **Step 1: Write the failing test**

`tests/test_pad_layout.lua`:
```lua
-- tests/test_pad_layout.lua — modules/Pad_Layout.lua (spec §10.2, §10.3): geometry, the sections a
-- pad draws for each groups-as mode, the visibility expression and the fade. Pure truth tables.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function PL() return T.newAddon().PadLayout end

local function slots(n)
    local out = {}
    for i = 1, n do out[i] = { calloutId = "c" .. i } end
    return out
end

local function chips(box)
    local out = {}
    for _, it in ipairs(box.items) do if it.kind == "chip" then out[#out + 1] = it end end
    return out
end

local H = { orientation = "horizontal", columns = 4, growth = "right", style = "iconLabel", spacing = 4, width = 140 }

test("layout: horizontal puts a section's chips on one row under the header", function()
    local pl = PL()
    local box = pl.Compute({ { slots = slots(3) } }, H)
    local c = chips(box)
    assertEqual(#c, 3)
    assertEqual(c[1].x, 4)
    assertEqual(c[2].x, 148)
    assertEqual(c[3].x, 292)
    assertEqual(c[1].y, 22)
    assertEqual(c[1].w, 140)
    assertEqual(c[1].h, 24)
    assertEqual(box.width, 436)
    assertEqual(box.height, 54)
end)

test("layout: a titled section draws its label row first", function()
    local pl = PL()
    local box = pl.Compute({ { title = "M+", slots = slots(1) } }, H)
    assertEqual(box.items[1].kind, "title")
    assertEqual(box.items[1].y, 22)
    assertEqual(box.items[2].y, 36)
    assertEqual(box.height, 68)
end)

test("layout: grid wraps at its column count; vertical is one column", function()
    local pl = PL()
    local grid = { orientation = "grid", columns = 2, style = "iconLabel", spacing = 4, width = 140 }
    local c = chips(pl.Compute({ { slots = slots(3) } }, grid))
    assertEqual(c[3].col, 0)
    assertEqual(c[3].row, 1)
    assertEqual(c[3].y, 50)
    local v = chips(pl.Compute({ { slots = slots(3) } }, { orientation = "vertical", spacing = 4 }))
    assertEqual(v[3].x, 4)
    assertEqual(v[3].row, 2)
end)

test("layout: the style sets the cell", function()
    local pl = PL()
    local w, h = pl.CellSize({ style = "icon" })
    assertEqual(w, 28)
    assertEqual(h, 28)
    w, h = pl.CellSize({ style = "label", width = 160 })
    assertEqual(w, 160)
    assertEqual(h, 22)
    w = pl.CellSize({ style = "iconLabel", width = 60 })
    assertEqual(w, 120, "never narrower than MIN_W")
end)

test("layout: leftward growth mirrors the row; collapsed is the header alone", function()
    local pl = PL()
    local left = { orientation = "horizontal", growth = "left", style = "iconLabel", spacing = 4, width = 140 }
    local c = chips(pl.Compute({ { slots = slots(2) } }, left))
    assertEqual(c[1].x, 148)
    assertEqual(c[2].x, 4)
    local box = pl.Compute({ { slots = slots(2) } }, H, { collapsed = true })
    assertEqual(#box.items, 0)
    assertEqual(box.height, 18)
    assertEqual(box.width, 120)
end)

test("layout: groups-as picks the sections: sections, merged, one tab at a time", function()
    local pl = PL()
    local secs = { { title = "A", slots = slots(2) }, { title = "B", slots = slots(1) } }
    assertEqual(#pl.VisibleSections(secs, "sections"), 2)
    local merged = pl.VisibleSections(secs, "merged")
    assertEqual(#merged, 1)
    assertEqual(#merged[1].slots, 3)
    assertTrue(merged[1].title == nil)
    local tab = pl.VisibleSections(secs, "tabs", 2)
    assertEqual(#tab, 1)
    assertEqual(tab[1].title, "B")
    assertEqual(tab[1].tabIndex, 2)
    assertEqual(tab[1].tabCount, 2)
    assertEqual(pl.VisibleSections(secs, "tabs", 9)[1].title, "B", "clamped")
    assertEqual(#pl.VisibleSections({}, "tabs", 1), 0)
end)

test("layout: the wheel steps tabs and wraps both ways", function()
    local pl = PL()
    assertEqual(pl.NextTab(1, 3, -1), 2)
    assertEqual(pl.NextTab(3, 3, -1), 1)
    assertEqual(pl.NextTab(1, 3, 1), 3)
    assertEqual(pl.NextTab(nil, 0, 1), 1)
end)

test("layout: the visibility expression combines the master and the pad", function()
    local pl = PL()
    local V = pl.VisibilityDriver
    assertEqual(V("always", "always", true, false), "show")
    assertEqual(V("never", "always", true, false), "hide")
    assertEqual(V("always", "never", true, false), "hide")
    assertEqual(V("inCombat", "always", true, false), "[combat] show; hide")
    assertEqual(V("always", "outOfCombat", true, false), "[combat] hide; show")
    assertEqual(V("inCombat", "outOfCombat", true, false), "hide")
    assertEqual(V("always", "whenActive", false, false), "hide")
    assertEqual(V("always", "whenActive", true, false), "show")
    assertEqual(V("never", "never", false, true), "show", "test mode shows the display")
    assertEqual(V(nil, nil, true, false), "show")
end)

test("layout: the fade follows combat and the mouse, under the master alpha", function()
    local pl = PL()
    local A = pl.Alpha
    assertEqual(A(1, { fade = "none" }, false, false), 1)
    assertEqual(A(1, { fade = "outOfCombat", fadeAlpha = 0.4 }, false, false), 0.4)
    assertEqual(A(1, { fade = "outOfCombat", fadeAlpha = 0.4 }, true, false), 1)
    assertEqual(A(1, { fade = "mouseover", fadeAlpha = 0.5 }, true, false), 0.5)
    assertEqual(A(1, { fade = "mouseover", fadeAlpha = 0.5 }, true, true), 1)
    assertEqual(A(0.5, { fade = "none" }, false, false), 0.5)
    assertEqual(A(nil, nil, false, false), 1)
end)

test("layout: the channel tag names the resolved channel", function()
    local pl = PL()
    assertEqual(pl.Tag("party"), "P")
    assertEqual(pl.Tag("instance"), "I")
    assertEqual(pl.Tag("raidWarning"), "RW")
    assertTrue(pl.Tag(nil) == nil)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_pad_layout",` to `tests/run.lua` after `"test_master",`. Run: `lua tests/run.lua`
Expected: FAIL (`PadLayout` is nil).

- [ ] **Step 3: Write the module**

`modules/Pad_Layout.lua`:
```lua
local _, NS = ...
-- modules/Pad_Layout.lua — the Comms Pad's geometry and look decisions (spec §10.2, §10.3). PURE:
-- plain tables in, plain tables out; no frame and no client read. Coordinates are offsets from the
-- pad root's TOPLEFT with y growing down; modules/Pad.lua flips y for SetPoint. The cell placement
-- copies KickCD modules/IconGrid_Layout.lua `Layout.layoutBlock` (row-major cells, an axis mirrored
-- for leftward or upward growth); the visibility expression copies ConsumableMaster
-- core/MacroBarModel.lua `BM.ResolveVisibility` (a constant or one [combat] state-driver
-- expression, never an insecure Show/Hide in combat).

NS.PadLayout = NS.PadLayout or {}
local PL = NS.PadLayout

PL.HEADER_H  = 18    -- the header row: situation chip, lockdown chip, stale hint, collapse
PL.PAD       = 4     -- inner padding
PL.SECTION_H = 14    -- a section's small-caps label row
PL.CHIP_H    = 24    -- icon + label chip height
PL.ICON      = 20    -- the icon tile inside an icon + label chip
PL.ICON_ONLY = 28    -- an icon-only chip is square
PL.LABEL_H   = 22    -- label-only chip height
PL.MIN_W     = 120   -- the narrowest pad and the narrowest labeled chip
PL.DEFAULT_W = 140

local TAG = { party = "P", raid = "R", instance = "I", raidWarning = "RW", say = "S", yell = "Y" }

--- The chip's channel tag: the channel a callout resolved to (a smart kind shows its result).
function PL.Tag(concrete)
    return TAG[concrete]
end

function PL.ClampTab(tab, n)
    n = tonumber(n) or 0
    if n < 1 then return 1 end
    tab = math.floor(tonumber(tab) or 1)
    if tab < 1 then return 1 end
    if tab > n then return n end
    return tab
end

--- The tab after a mouse-wheel step: wheel up (delta > 0) goes back one, down goes on; wraps.
function PL.NextTab(tab, n, delta)
    n = tonumber(n) or 0
    if n < 1 then return 1 end
    local step = (tonumber(delta) or 0) > 0 and -1 or 1
    return (PL.ClampTab(tab, n) - 1 + step) % n + 1
end

--- The sections a pad draws for its groups-as mode (spec §10.2).
function PL.VisibleSections(sections, groupsAs, tab)
    sections = type(sections) == "table" and sections or {}
    if groupsAs == "merged" then
        local all = {}
        for _, s in ipairs(sections) do
            for _, slot in ipairs(s.slots or {}) do all[#all + 1] = slot end
        end
        if #all == 0 then return {} end
        return { { slots = all } }
    end
    if groupsAs == "tabs" then
        local n = #sections
        if n == 0 then return {} end
        local i = PL.ClampTab(tab, n)
        return { { title = sections[i].title, slots = sections[i].slots or {}, tabIndex = i, tabCount = n } }
    end
    return sections
end

--- One chip's width and height for the pad's style.
function PL.CellSize(layout)
    layout = type(layout) == "table" and layout or {}
    if layout.style == "icon" then return PL.ICON_ONLY, PL.ICON_ONLY end
    local w = math.max(PL.MIN_W, tonumber(layout.width) or PL.DEFAULT_W)
    if layout.style == "label" then return w, PL.LABEL_H end
    return w, PL.CHIP_H
end

--- Columns for a section of `count` chips: one row (horizontal), one column (vertical) or N (grid).
function PL.Columns(layout, count)
    layout = type(layout) == "table" and layout or {}
    if layout.orientation == "vertical" then return 1 end
    if layout.orientation == "grid" then return math.max(1, math.floor(tonumber(layout.columns) or 4)) end
    return math.max(1, count)
end

local function mirror(items, width, height, growth)
    for _, it in ipairs(items) do
        if growth == "left" and it.kind == "chip" then it.x = width - it.x - it.w end
        if growth == "up" then it.y = PL.HEADER_H + (height - it.y - it.h) end
    end
end

--- Place every title row and chip.
--- @param sections table from VisibleSections
--- @param layout table the pad's layout table
--- @param opts table|nil { collapsed = boolean }
--- @return table { width, height, items }
function PL.Compute(sections, layout, opts)
    layout = type(layout) == "table" and layout or {}
    opts = type(opts) == "table" and opts or {}
    local cw, ch = PL.CellSize(layout)
    local gap = math.max(0, tonumber(layout.spacing) or 4)
    local items, contentW, used = {}, 0, false
    local y = PL.HEADER_H + PL.PAD
    if not opts.collapsed then
        for _, s in ipairs(type(sections) == "table" and sections or {}) do
            if s.title then
                items[#items + 1] = { kind = "title", text = s.title, tabIndex = s.tabIndex, tabCount = s.tabCount,
                    x = PL.PAD, y = y, w = 0, h = PL.SECTION_H }
                y = y + PL.SECTION_H
                used = true
            end
            local list = s.slots or {}
            local n = #list
            if n > 0 then
                local cols = math.min(PL.Columns(layout, n), n)
                local rows = math.ceil(n / cols)
                for i, slot in ipairs(list) do
                    local r = math.floor((i - 1) / cols)
                    local c = (i - 1) - r * cols
                    items[#items + 1] = { kind = "chip", slot = slot, row = r, col = c,
                        x = PL.PAD + c * (cw + gap), y = y + r * (ch + gap), w = cw, h = ch }
                end
                contentW = math.max(contentW, cols * cw + (cols - 1) * gap)
                y = y + rows * ch + (rows - 1) * gap + gap
                used = true
            end
        end
    end
    local width = math.max(PL.MIN_W, contentW + 2 * PL.PAD)
    local height = used and (y + PL.PAD) or PL.HEADER_H
    mirror(items, width, height, layout.growth)
    return { width = width, height = height, items = items }
end

--- The pad's visibility as one state-driver expression (spec §10.3). The master visibility applies
--- on top of the pad's own; "whenActive" is decided at the last out-of-combat rebuild; test mode
--- shows the display (options-ui-§15).
function PL.VisibilityDriver(master, padVis, hasActive, testMode)
    if testMode then return "show" end
    if master == "never" or padVis == "never" then return "hide" end
    if padVis == "whenActive" then
        if not hasActive then return "hide" end
        padVis = "always"
    end
    local wantIn = master == "inCombat" or padVis == "inCombat"
    local wantOut = master == "outOfCombat" or padVis == "outOfCombat"
    if wantIn and wantOut then return "hide" end
    if wantIn then return "[combat] show; hide" end
    if wantOut then return "[combat] hide; show" end
    return "show"
end

--- The pad's alpha (SetAlpha is allowed in combat): the master alpha, faded out of combat or
--- until the mouse is over the pad, as the pad's look says.
function PL.Alpha(masterAlpha, look, inCombat, hovered)
    local a = tonumber(masterAlpha) or 1
    look = type(look) == "table" and look or {}
    local faded = (look.fade == "outOfCombat" and not inCombat and not hovered)
        or (look.fade == "mouseover" and not hovered)
    if faded then a = a * (tonumber(look.fadeAlpha) or 0.4) end
    return math.max(0, math.min(1, a))
end
```

In `QuickComms.toc`, directly after `modules\Preview.lua`:
```
# LOAD-BEARING: publishes NS.PadLayout, which modules\Pad_Render.lua and modules\Pad.lua take at load.
modules\Pad_Layout.lua
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/Pad_Layout.lua tests/test_pad_layout.lua QuickComms.toc tests/run.lua
git commit -m "Pad_Layout: pad geometry, groups-as sections, visibility expression and fade (pure)"
```

---
### Task 8: Surfaces: a pad's plan (active groups, sections, baked slots)

**Files:**
- Create: `modules/Surfaces.lua` (the plan half; Task 11 appends the edge)
- Modify: `core/Compat.lua` (four bake-context readers)
- Create: `tests/test_surfaces.lua`
- Modify: `QuickComms.toc` (after `modules\Pad_Layout.lua`), `tests/run.lua` (add `"test_surfaces",` after `"test_pad_layout",`), `.luacheckrc`, `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.Resolver.ActiveGroups(groups, snap)`, `NS.Resolver.SurfaceOrder(list, active, groups, autoPromote)`, `NS.Library.AllGroups()`, `NS.Library.Group(id)`, `NS.Library.Callout(id)`, `NS.Bake.Bake(callout, snap, opts) -> line, reason, info`, `NS.Bake.Sanitize(text)`, `NS.Channels.ChatType(concrete)`, `NS.Setting(...)`.
- Produces `NS.Surfaces` (`S`), the plan half:
  - `S.Sections(groupId, groupOf) -> { { groupId, title, callouts = { id… } }… }`
  - `S.Slot(calloutId, callout, snap, opts) -> slot`, where a slot is `{ calloutId, surfaceId, name, icon, line, reason, concrete, chatType, lock, selfText }`; `line` is nil when refused, and `reason` then names why (`startsWithSlash`, `tooLong`, `empty`, `solo`, `badChannel`, `badCallout`, `noCallout`, `testMode`)
  - `S.BakeContext(snap) -> ctx` (`me`, `spec`, `role`, `key`, `dungeon`, `spellLink`)
  - `S.Deps(snap) -> { groups, group, callout, soloFallback, autoPromote, ctx }`
  - `S.BuildPlan(surfaceId, pad, snap, deps) -> plan`, where a plan is `{ surfaceId, snapshot, order = { groupId… }, sections = { { groupId, title, slots }… }, lockdownChip, hasActive, test }`
  - `S.TestPlan(surfaceId) -> plan` (two sections of four placeholder slots, each `reason = "testMode"`, no line)
  - `NS.Compat.PlayerName()`, `NS.Compat.SpecName()`, `NS.Compat.DungeonName(mapID)`, `NS.Compat.SpellLink(id)`
  - Perf bucket `bake.surface`

- [ ] **Step 1: Write the failing test**

`tests/test_surfaces.lua`:
```lua
-- tests/test_surfaces.lua — modules/Surfaces.lua: a pad's plan (spec §7, §8, §10) and, from Task 11,
-- the rebuild edge: queued in combat, the stale hint, the stand-down.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- A keyed dungeon in a party: the M+ built-in is active and smart channels resolve to /p.
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
-- Arathi Basin (instanceID 2107) in its instance group: the generic battleground set and the node set.
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function planFor(NS, snap)
    snap = snap or NS.Situation.Current()
    return NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))
end

-- A user group (an empty When is always active) holding one new callout, first on the default pad.
local function userCallout(NS, fields)
    local cid = assert(NS.Library.CreateCallout(fields))
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    return cid, gid
end

local function slotOf(plan, cid)
    for _, sec in ipairs(plan.sections) do
        for _, slot in ipairs(sec.slots) do
            if slot.calloutId == cid then return slot end
        end
    end
    return nil
end

test("surfaces: in a key the default pad's plan is the M+ set, baked to /p", function()
    local NS = live()
    local plan = planFor(NS)
    assertEqual(table.concat(plan.order, ","), "bi.mplus")
    assertTrue(plan.hasActive)
    assertEqual(plan.sections[1].title, "M+ (generic)")
    assertEqual(#plan.sections[1].slots, 8)
    local pull = plan.sections[1].slots[1]
    assertEqual(pull.calloutId, "bi.mplus.pull")
    assertEqual(pull.line, "/p Pulling next pack")
    assertEqual(pull.chatType, "PARTY")
    assertEqual(pull.surfaceId, "p1")
    assertEqual(pull.name, "Pulling")
end)

test("surfaces: [review 5] a refused callout is a slot with its reason and no line", function()
    local NS = live()
    local cid = userCallout(NS, { name = "Bad", text = "/run x", channel = "party" })
    local slot = slotOf(planFor(NS), cid)
    assertNil(slot.line)
    assertNil(slot.chatType)
    assertEqual(slot.reason, "startsWithSlash")
    assertEqual(slotOf(planFor(NS), "bi.mplus.pull").line, "/p Pulling next pack", "the others still bake")
end)

test("surfaces: a node battleground gives one section per node, baked to /i", function()
    local NS = live(AB)
    local plan = planFor(NS)
    assertEqual(table.concat(plan.order, ","), "bi.bg,bi.bg.ab")
    assertEqual(#plan.sections, 6)
    assertEqual(plan.sections[1].title, "Battleground (generic)")
    assertEqual(plan.sections[3].title, "Lumber Mill")
    assertEqual(plan.sections[3].slots[3].line, "/i INC 3 Lumber Mill")
end)

test("surfaces: a Say callout locked by an encounter lights the plan's lockdown chip", function()
    local NS = live()
    local cid = userCallout(NS, { name = "Shout", text = "Go go", channel = "say" })
    local snap = { content = "mythicPlus", group = "party", instanceGroup = false, lockdown = { encounter = true } }
    local plan = planFor(NS, snap)
    assertEqual(slotOf(plan, cid).lock, "lockdown")
    assertEqual(slotOf(plan, cid).line, "/s Go go", "locked, still baked")
    assertTrue(plan.lockdownChip)
end)

test("surfaces: solo with the self fallback, a smart callout carries the text to print", function()
    local NS = live({})
    NS.SchemaRuntime.Set("behavior.soloFallback", "self")
    local cid = userCallout(NS, { name = "Hi", text = "Hello {rt8}", channel = "smartGroup" })
    local slot = slotOf(planFor(NS), cid)
    assertNil(slot.line)
    assertEqual(slot.reason, "solo")
    assertEqual(slot.selfText, "Hello {rt8}")
end)

test("surfaces: the bake context fills {me} from the client", function()
    local NS = live()
    local cid = userCallout(NS, { name = "Me", text = "{me} pulling", channel = "party" })
    assertEqual(slotOf(planFor(NS), cid).line, "/p Testchar pulling")
end)

test("surfaces: a disabled built-in leaves the plan", function()
    local NS = live()
    NS.Library.SetBuiltinEnabled("bi.mplus", false)
    local plan = planFor(NS)
    assertEqual(#plan.order, 0)
    assertFalse(plan.hasActive)
    assertEqual(#plan.sections, 0)
end)

test("surfaces: the test plan is placeholder chips that carry no line", function()
    local NS = live()
    local plan = NS.Surfaces.TestPlan("p1")
    assertTrue(plan.test)
    assertTrue(plan.hasActive)
    assertEqual(#plan.sections, 2)
    for _, sec in ipairs(plan.sections) do
        assertEqual(#sec.slots, 4)
        for _, slot in ipairs(sec.slots) do
            assertNil(slot.line)
            assertEqual(slot.reason, "testMode")
        end
    end
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_surfaces",` to `tests/run.lua` after `"test_pad_layout",`. Run: `lua tests/run.lua`
Expected: FAIL (`Surfaces` is nil).

- [ ] **Step 3: Write the readers and the plan**

Append to `core/Compat.lua`:
```lua
-- ── The bake context (spec §8.1): the values {me}, {spec}, {dungeon} and {spell:ID} bake from ──

--- The player's name, without the realm.
function Compat.PlayerName()
    if not UnitName then return nil end
    return PlainString((UnitName("player")))
end

--- The current specialization's display name.
function Compat.SpecName()
    local index = specIndex()
    if not index then return nil end
    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not get then return nil end
    local _, name = get(index)
    return PlainString(name)
end

--- A Mythic+ dungeon's display name from its challenge map id.
function Compat.DungeonName(mapID)
    local cm = C_ChallengeMode
    if not (PlainNumber(mapID) and cm and cm.GetMapUIInfo) then return nil end
    return PlainString((cm.GetMapUIInfo(mapID)))
end

--- A spell's chat link, for {spell:ID}.
function Compat.SpellLink(id)
    local sp = C_Spell
    if not (PlainNumber(id) and sp and sp.GetSpellLink) then return nil end
    return PlainString(sp.GetSpellLink(id))
end
```

`modules/Surfaces.lua`:
```lua
local _, NS = ...
-- modules/Surfaces.lua — the surfaces' plans and their rebuild (spec §4.3, §7, §10).
--
-- THE PLAN (this half): for one pad and one snapshot, the active groups in the pad's own order
-- (Resolver, D6), one section per group (a built-in with children, the node battlegrounds, gives
-- one section per child), and one slot per callout: baked to its single macro line, or refused
-- with the reason its chip's tooltip shows (Bake, §8.3; §18 "a baked line fails validation"). A
-- locked slot keeps its line and carries the lock (§8.4). Library, Resolver and Bake are reached
-- through `deps`, so a test can hand in any snapshot. Test mode's plan is placeholder slots that
-- carry no line, drawn through the same render path (preview-mode).

NS.Surfaces = NS.Surfaces or {}
local S = NS.Surfaces
local L = NS.L
local Perf = NS.Perf

local ROLE = { TANK = L["Tank"], HEALER = L["Healer"], DAMAGER = L["Damage"] }

S.TEST_SECTIONS, S.TEST_SLOTS = 2, 4

--- A group's sections: itself, or one per child for a built-in with children.
--- @param groupOf function Library.Group
function S.Sections(groupId, groupOf)
    local g = groupOf(groupId)
    if not g then return {} end
    local out = {}
    if type(g.children) == "table" and #g.children > 0 then
        for _, child in ipairs(g.children) do
            local c = groupOf(child)
            if c then out[#out + 1] = { groupId = child, title = c.name, callouts = c.callouts or {} } end
        end
    else
        out[1] = { groupId = groupId, title = g.name, callouts = g.callouts or {} }
    end
    return out
end

--- One chip's slot: the baked line, or the reason there is none.
function S.Slot(calloutId, callout, snap, opts)
    local slot = { calloutId = calloutId }
    if type(callout) ~= "table" then
        slot.reason = "noCallout"
        return slot
    end
    slot.name, slot.icon = callout.name, callout.icon
    local line, reason, info = NS.Bake.Bake(callout, snap, opts)
    slot.line, slot.reason = line, reason
    slot.concrete, slot.lock = info.concrete, info.lock
    if line then slot.chatType = NS.Channels.ChatType(info.concrete) end
    if not line and reason == "solo" and info.selfPrint then slot.selfText = NS.Bake.Sanitize(callout.text) end
    return slot
end

--- The baked token values (spec §8.1), read out of combat.
function S.BakeContext(snap)
    snap = type(snap) == "table" and snap or {}
    local C = NS.Compat
    return {
        me = C.PlayerName(),
        spec = C.SpecName(),
        role = ROLE[snap.role],
        key = type(snap.keyLevel) == "number" and tostring(snap.keyLevel) or nil,
        dungeon = C.DungeonName(snap.challengeMapID),
        spellLink = C.SpellLink,
    }
end

--- Everything BuildPlan reads, from the live addon.
function S.Deps(snap)
    return {
        groups = NS.Library.AllGroups(),
        group = NS.Library.Group,
        callout = NS.Library.Callout,
        soloFallback = NS.Setting("behavior.soloFallback"),
        autoPromote = NS.Setting("behavior.autoPromote"),
        ctx = S.BakeContext(snap),
    }
end

--- One pad's plan.
--- @param pad table profile.pads[surfaceId]
--- @param snap table the situation snapshot
--- @param deps table from S.Deps (or a test)
--- @return table plan
function S.BuildPlan(surfaceId, pad, snap, deps)
    local t0 = Perf.on and debugprofilestop()
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(pad and pad.groups, active, deps.groups, deps.autoPromote)
    local opts = { soloFallback = deps.soloFallback, ctx = deps.ctx }
    local plan = { surfaceId = surfaceId, snapshot = snap, order = order, sections = {},
        lockdownChip = false, hasActive = #order > 0 }
    for _, gid in ipairs(order) do
        for _, sec in ipairs(S.Sections(gid, deps.group)) do
            local slots = {}
            for _, cid in ipairs(sec.callouts) do
                local slot = S.Slot(cid, deps.callout(cid), snap, opts)
                slot.surfaceId = surfaceId
                if slot.lock == "lockdown" then plan.lockdownChip = true end
                slots[#slots + 1] = slot
            end
            plan.sections[#plan.sections + 1] = { groupId = sec.groupId, title = sec.title, slots = slots }
        end
    end
    if t0 then Perf.Note("bake.surface", debugprofilestop() - t0) end
    return plan
end

--- Test mode's plan: placeholder chips that send nothing (spec §10.4).
function S.TestPlan(surfaceId)
    local sections = {}
    for s = 1, S.TEST_SECTIONS do
        local slots = {}
        for i = 1, S.TEST_SLOTS do
            slots[i] = { calloutId = ("test.%d.%d"):format(s, i), surfaceId = surfaceId,
                name = L["Callout %d"]:format(i), reason = "testMode",
                concrete = (i % 2 == 1) and "party" or "raid" }
        end
        sections[s] = { groupId = "test." .. s, title = L["Test group %d"]:format(s), slots = slots }
    end
    return { surfaceId = surfaceId, snapshot = {}, order = {}, sections = sections, lockdownChip = false,
        hasActive = true, test = true }
end
```

In `QuickComms.toc`, directly after `modules\Pad_Layout.lua`:
```
# Conventional: the surfaces' plans and rebuild; calls modules\Pad.lua at run time only
modules\Surfaces.lua
```

In `core/PerfSetup.lua`, add to `BUCKETS`:
```lua
    { key = "bake.surface" }, -- modules/Surfaces.lua: one pad's plan (resolve, order, bake every slot)
```

In `.luacheckrc`, add `"C_Spell",` to `read_globals`.

In `locales/enUS.lua`, add a `-- Surfaces (modules/Surfaces.lua)` block (skip any key the file already defines):
```lua
L["Tank"] = "Tank"
L["Healer"] = "Healer"
L["Damage"] = "Damage"
L["Callout %d"] = "Callout %d"
L["Test group %d"] = "Test group %d"
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/Surfaces.lua core/Compat.lua core/PerfSetup.lua tests/test_surfaces.lua QuickComms.toc tests/run.lua .luacheckrc locales/enUS.lua
git commit -m "Surfaces: a pad's plan of active groups, sections and baked or refused slots"
```

---
### Task 9: The drag-strip seam and Pad_Render (chip and header visuals)

**Files:**
- Create: `core/WidgetsSetup.lua`
- Create: `modules/Pad_Render.lua`
- Modify: `core/Constants.lua` (chat colors, flash colors), `core/Compat.lua` (`ChatColor`)
- Create: `tests/test_pad_render.lua`
- Modify: `tests/test_compat.lua` (append), `QuickComms.toc` (two entries), `tests/run.lua` (add `"test_pad_render",` after `"test_surfaces",`), `.luacheckrc`, `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.PadLayout` (Task 7: `PL.Tag`, `PL.ICON`), Task 8's slot shape, `NS.Channels.ChatType`, `NS.Constants.GOLD`, `NS.Icon`, LibKa0s-Widgets-1.0 `DragHandle` / `DRAG_HANDLE.GAP`.
- Produces:
  - `NS.MakeDragHandle(parent, spec) -> handle | nil`, `NS.DRAG_GAP`
  - `NS.Constants.CHAT_COLORS[chatType] = { r, g, b }`, `NS.Constants.FLASH[result] = { r, g, b }`
  - `NS.Compat.ChatColor(chatType) -> r, g, b | nil`
  - `NS.PadRender` (`R`): `R.REASON_TEXT`, `R.LOCK_TEXT`, `R.CONTENT`, `R.SituationText(snap, dungeon) -> string`, `R.TooltipLines(slot) -> { string… }`, `R.SectionTitle(item) -> string`, `R.ShowTooltip(button)`, `R.Dress(button, onEnter, onLeave) -> button`, `R.Paint(button, slot, style)`, `R.RefreshLock(button)`, `R.Flash(button, result)`, `R.Unflash(button)`, `R.SetCooling(button, on)`, `R.DressHeader(header, onCollapse)`, `R.PaintHeader(header, state)` where `state = { situation, lockdown, stale, test, collapsed }`
  - Chip regions: `qcBg`, `qcIcon`, `qcLabel`, `qcTag`, `qcLock`, `qcDim`, `qcCool`, `qcFlash`; `qcSlot` is the slot last painted. Header regions: `qcSituation`, `qcLockdown`, `qcTest`, `qcStale`, and the button `qcCollapse` (its text `qcText`).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_compat.lua`:
```lua
test("compat: ChatColor reads the client's chat colors and declines what it cannot read", function()
    local NS, env = T.newAddon()
    local r, g, b = NS.Compat.ChatColor("PARTY")
    assertEqual(r, 0.67)
    assertEqual(g, 0.67)
    assertEqual(b, 1.0)
    assertNil(NS.Compat.ChatColor("NOPE"))
    assertNil(NS.Compat.ChatColor(nil))
    env.ChatTypeInfo = nil
    assertNil(NS.Compat.ChatColor("PARTY"))
end)
```

`tests/test_pad_render.lua`:
```lua
-- tests/test_pad_render.lua — modules/Pad_Render.lua (spec §10.1): what a chip and the pad's header
-- show, and the drag-strip seam (core/WidgetsSetup.lua). Frames come from the mock's QuickComms
-- branch, whose regions are objects of their own.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local ARMED = { calloutId = "c1", name = "Pull", line = "/p Pull", concrete = "party", chatType = "PARTY" }

local function chip(NS, m)
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    return NS.PadRender.Dress(NS.SendEngine.NewButton(root)), root
end

test("render: Dress builds a chip's regions once, each its own object", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local icon = b.qcIcon
    assertTrue(icon ~= b and b.qcLabel ~= b and b.qcLock ~= b)
    NS.PadRender.Dress(b)
    assertTrue(b.qcIcon == icon, "dressed once")
    assertFalse(b.qcDim:IsShown())
    assertFalse(b.qcFlash:IsShown())
end)

test("render: an armed chip shows its name, its channel tag in the chat color, no lock, no dim", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    NS.PadRender.Paint(b, ARMED, "iconLabel")
    assertEqual(b.qcLabel:GetText(), "Pull")
    assertEqual(b.qcTag:GetText(), "P")
    assertEqual(b.qcTag.__color[1], 0.67)
    assertFalse(b.qcLock:IsShown())
    assertFalse(b.qcDim:IsShown())
    assertTrue(b.qcIcon:IsShown())
    assertTrue(b.qcSlot == ARMED)
end)

test("render: [review 5] a refused chip is dimmed and its tooltip says why", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local slot = { calloutId = "c2", name = "Bad", reason = "startsWithSlash" }
    NS.PadRender.Paint(b, slot, "iconLabel")
    assertTrue(b.qcDim:IsShown())
    local lines = NS.PadRender.TooltipLines(slot)
    assertEqual(lines[1], "Bad")
    assertEqual(lines[2], "Callout text cannot start with /.")
end)

test("render: a locked chip shows the padlock and names the lock; RefreshLock follows the slot", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local slot = { calloutId = "c3", name = "Shout", line = "/s Go", concrete = "say", chatType = "SAY", lock = "lockdown" }
    NS.PadRender.Paint(b, slot, "iconLabel")
    assertTrue(b.qcLock:IsShown())
    assertFalse(b.qcDim:IsShown(), "locked is not refused: it stays armed")
    local lines = NS.PadRender.TooltipLines(slot)
    assertEqual(lines[2], "/s Go")
    assertEqual(lines[3], "Locked: Say and Yell are blocked during this encounter.")
    slot.lock = nil
    NS.PadRender.RefreshLock(b)
    assertFalse(b.qcLock:IsShown())
end)

test("render: the style decides icon and label", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    NS.PadRender.Paint(b, ARMED, "icon")
    assertEqual(b.qcLabel:GetText(), "")
    assertTrue(b.qcIcon:IsShown())
    NS.PadRender.Paint(b, ARMED, "label")
    assertEqual(b.qcLabel:GetText(), "Pull")
    assertFalse(b.qcIcon:IsShown())
end)

test("render: a test-mode chip and a solo self-print chip are not dimmed, and say what they do", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    local test1 = { calloutId = "test.1.1", name = "Callout 1", reason = "testMode", concrete = "party" }
    NS.PadRender.Paint(b, test1, "iconLabel")
    assertFalse(b.qcDim:IsShown())
    assertEqual(NS.PadRender.TooltipLines(test1)[2], "Test mode: a placeholder that sends nothing.")
    local solo = { calloutId = "c4", name = "Hi", reason = "solo", selfText = "Hello" }
    NS.PadRender.Paint(b, solo, "iconLabel")
    assertFalse(b.qcDim:IsShown())
    assertEqual(NS.PadRender.TooltipLines(solo)[2], "Solo: prints to you, sends nothing.")
end)

test("render: flashes take the result's color; the cooldown dims and clears", function()
    local NS, m = T.enableAddon()
    local b = chip(NS, m)
    NS.PadRender.Flash(b, "dropped")
    assertTrue(b.qcFlash:IsShown())
    assertEqual(b.qcFlash.__color[1], 0.9)
    NS.PadRender.Unflash(b)
    assertFalse(b.qcFlash:IsShown())
    NS.PadRender.SetCooling(b, true)
    assertTrue(b.qcCool:IsShown())
    NS.PadRender.SetCooling(b, false)
    assertFalse(b.qcCool:IsShown())
end)

test("render: the situation chip names the content, the dungeon and the key", function()
    local NS = T.newAddon()
    local R = NS.PadRender
    assertEqual(R.SituationText({ content = "mythicPlus", keyLevel = 14 }, "Windrunner Spire"),
        "M+ \194\183 Windrunner Spire +14")
    assertEqual(R.SituationText({ content = "raid" }), "Raid")
    assertEqual(R.SituationText(nil), "World")
    assertEqual(R.SectionTitle({ text = "Raid" }), "Raid")
    assertEqual(R.SectionTitle({ text = "Raid", tabIndex = 2, tabCount = 3 }), "Raid (2 of 3)")
end)

test("render: the header shows the lockdown chip, the stale hint and the test label on demand", function()
    local NS, m = T.enableAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    local header = m.CreateFrame("Frame", nil, root)
    local collapsed = 0
    NS.PadRender.DressHeader(header, function() collapsed = collapsed + 1 end)
    NS.PadRender.PaintHeader(header, { situation = "M+", lockdown = true, stale = false, test = false })
    assertEqual(header.qcSituation:GetText(), "M+")
    assertTrue(header.qcLockdown:IsShown())
    assertFalse(header.qcStale:IsShown())
    assertFalse(header.qcTest:IsShown())
    NS.PadRender.PaintHeader(header, { situation = "M+", stale = true, test = true, collapsed = true })
    assertFalse(header.qcLockdown:IsShown())
    assertTrue(header.qcStale:IsShown())
    assertTrue(header.qcTest:IsShown())
    assertEqual(header.qcCollapse.qcText:GetText(), "+")
    header.qcCollapse:__fire("OnClick")
    assertEqual(collapsed, 1)
end)

test("render: the drag-strip seam builds a hidden strip, and answers nil without the library", function()
    local NS, m = T.enableAddon()
    local root = m.CreateFrame("Frame", "QuickCommsPadTest", m.UIParent)
    local handle = NS.MakeDragHandle(root, { label = "Comms Pad", moveFrame = root })
    assertTrue(handle ~= nil)
    assertFalse(handle:IsShown(), "born hidden; the pad shows it when unlocked")
    local D = T.newAddon{ skip = T.loadAddon.libFiles }
    assertNil(D.MakeDragHandle(root, { label = "x", moveFrame = root }))
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_pad_render",` to `tests/run.lua` after `"test_surfaces",`. Run: `lua tests/run.lua`
Expected: FAIL (`ChatColor`, `PadRender` and `MakeDragHandle` are nil).

- [ ] **Step 3: Write the seam, the constants, the reader and the renderer**

`core/WidgetsSetup.lua`:
```lua
local _, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDragHandle from LibKa0s-Widgets-1.0: the Comms Pad's drag strip.
--
-- A seam, nothing else (library-stack-§7), shaped like DropWatcher core/WidgetsSetup.lua: one file
-- leases the major, and the help mark's art arrives resolved from the addon's media seam
-- (core/MediaSetup.lua), because a vendored library cannot know its folder. The strip is born
-- hidden; modules/Pad.lua shows it while the pads are unlocked (KickCD modules/IconGrid_Handle.lua
-- `IconGrid:ApplyLock`). DEGRADED (the library absent): NS.MakeDragHandle answers nil and a pad
-- stays where its saved point puts it.

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

-- The gap between a strip and the frame it moves.
NS.DRAG_GAP = (W and W.DRAG_HANDLE and W.DRAG_HANDLE.GAP) or 2

--- A drag strip over `parent`, or nil when the library is absent.
--- @param spec table LibKa0s DragHandle spec: label, moveFrame, canDrag, onDragStop, onRightClick, tooltip
--- @return table|nil
function NS.MakeDragHandle(parent, spec)
    if not (W and W.DragHandle) then return nil end
    spec.helpIcon = spec.helpIcon or (NS.Icon and NS.Icon("help")) or nil
    return W.DragHandle(parent, spec)
end
```

In `QuickComms.toc`, directly after `core\PoolSetup.lua`:
```
# Conventional: NS.MakeDragHandle is read inside functions only (modules\Pad.lua).
core\WidgetsSetup.lua
```

Append to `core/Constants.lua`:
```lua

-- The channel tag's color per chat type: WoW's chat colors, used when ChatTypeInfo cannot be read
-- (spec §10.1).
C.CHAT_COLORS = {
    PARTY = { 0.67, 0.67, 1.0 }, RAID = { 1.0, 0.5, 0.0 }, INSTANCE_CHAT = { 1.0, 0.5, 0.0 },
    RAID_WARNING = { 1.0, 0.28, 0.0 }, SAY = { 1.0, 1.0, 1.0 }, YELL = { 1.0, 0.25, 0.25 },
}

-- A chip's flash for each send result: gold sent, red dropped, amber guarded (spec §10.1).
C.FLASH = {
    sent = { 1.0, 0.82, 0.0 }, dropped = { 0.9, 0.15, 0.15 }, guarded = { 1.0, 0.5, 0.0 },
}
```

Append to `core/Compat.lua`:
```lua
-- ── The pad (spec §10.1) ─────────────────────────────────────────────────────────────────────

--- The client's color for a chat type, or nil when it cannot be read.
function Compat.ChatColor(chatType)
    local info = ChatTypeInfo
    if type(info) ~= "table" or not Compat.IsSafeKey(chatType) then return nil end
    local c = info[chatType]
    if type(c) ~= "table" then return nil end
    local r, g, b = PlainNumber(c.r), PlainNumber(c.g), PlainNumber(c.b)
    if r and g and b then return r, g, b end
    return nil
end
```

`modules/Pad_Render.lua`:
```lua
local _, NS = ...
-- modules/Pad_Render.lua — what a Comms Pad chip and the pad's header show (spec §10.1). INSECURE
-- visuals only: textures and font strings on the chips and the header, their text, color and
-- visibility, which the client allows in combat too. It never touches a secure attribute, a
-- protected frame's geometry or a protected frame's Show/Hide; modules/Pad.lua does the protected
-- work, out of combat. A chip shows a square icon tile, its label, the channel tag in WoW's chat
-- color (a smart kind shows the channel it resolved to), a padlock when locked, a dim veil when its
-- bake was refused, a dim veil during the spam guard's window, a gold hover and a flash per send
-- result. The tooltip names the line it sends, or why it sends nothing, and any lock.

NS.PadRender = NS.PadRender or {}
local R = NS.PadRender
local PL = NS.PadLayout
local L = NS.L

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local DOT = " \194\183 "

-- Why a chip sends nothing (Bake's and Channels' reasons, spec §8.3/§18; test mode).
R.REASON_TEXT = {
    startsWithSlash = L["Callout text cannot start with /."],
    tooLong = L["Too long: a chat line holds 255 bytes."],
    empty = L["This callout has no text."],
    solo = L["You are not in a group."],
    badChannel = L["This callout has no valid channel."],
    badCallout = L["This callout is damaged."],
    noCallout = L["This callout no longer exists."],
    testMode = L["Test mode: a placeholder that sends nothing."],
}

-- Why a locked chip may not reach anyone (Channels.LockState, spec §8.4).
R.LOCK_TEXT = {
    notInRaid = L["Locked: you are not in a raid."],
    notLeader = L["Locked: needs raid leader or assist."],
    notInGroup = L["Locked: you are not in a group."],
    notInInstanceGroup = L["Locked: you are not in an instance group."],
    lockdown = L["Locked: Say and Yell are blocked during this encounter."],
}

R.CONTENT = {
    mythicPlus = L["M+"], raid = L["Raid"], dungeon = L["Dungeon"], arena = L["Arena"],
    battleground = L["Battleground"], delve = L["Delve"], scenario = L["Scenario"], housing = L["Housing"],
    openWorld = L["World"],
}

--- The header's situation chip: "M+ · Windrunner Spire +14".
function R.SituationText(snap, dungeon)
    snap = type(snap) == "table" and snap or {}
    local text = R.CONTENT[snap.content] or R.CONTENT.openWorld
    if type(dungeon) == "string" and dungeon ~= "" then text = text .. DOT .. dungeon end
    if snap.content == "mythicPlus" and type(snap.keyLevel) == "number" then
        text = text .. " +" .. snap.keyLevel
    end
    return text
end

--- A chip's tooltip: its name, then the line it sends or why it sends nothing, then any lock.
function R.TooltipLines(slot)
    local lines = { slot.name or "?" }
    if slot.line then
        lines[2] = slot.line
    elseif slot.selfText then
        lines[2] = L["Solo: prints to you, sends nothing."]
    else
        lines[2] = R.REASON_TEXT[slot.reason] or L["Not available here."]
    end
    if slot.lock then lines[#lines + 1] = R.LOCK_TEXT[slot.lock] or tostring(slot.lock) end
    return lines
end

--- A section's label; a tab names its place ("Raid (2 of 3)").
function R.SectionTitle(item)
    if item.tabCount then return L["%s (%d of %d)"]:format(item.text, item.tabIndex, item.tabCount) end
    return item.text
end

local function tagColor(chatType)
    local r, g, b = NS.Compat.ChatColor(chatType)
    if r then return r, g, b end
    local c = NS.Constants.CHAT_COLORS[chatType] or NS.Constants.CHAT_COLORS.SAY
    return c[1], c[2], c[3]
end

local function veil(btn, r, g, b, a)
    local t = btn:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(btn)
    t:SetColorTexture(r, g, b, a)
    t:Hide()
    return t
end

function R.ShowTooltip(btn)
    local slot = btn.qcSlot
    if not slot then return end
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    for i, line in ipairs(R.TooltipLines(slot)) do
        if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
end

--- Build a chip's regions and hover hooks, once per button.
function R.Dress(btn, onEnter, onLeave)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.qcBg:SetAllPoints(btn)
    btn.qcBg:SetColorTexture(0.10, 0.10, 0.12, 0.90)
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetSize(PL.ICON, PL.ICON)
    btn.qcIcon:SetPoint("LEFT", btn, "LEFT", 2, 0)
    btn.qcLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.qcLabel:SetJustifyH("LEFT")
    btn.qcTag = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.qcTag:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.qcLock = btn:CreateTexture(nil, "OVERLAY")
    btn.qcLock:SetSize(12, 12)
    btn.qcLock:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    btn.qcLock:SetTexture(LOCK_ICON)
    btn.qcDim = veil(btn, 0, 0, 0, 0.55)
    btn.qcCool = veil(btn, 0, 0, 0, 0.35)
    btn.qcFlash = veil(btn, 1.0, 0.82, 0.0, 0.45)
    local gold = NS.Constants.GOLD
    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(btn)
    hover:SetColorTexture(gold.r, gold.g, gold.b, 0.25)
    btn:HookScript("OnEnter", function(self)
        R.ShowTooltip(self)
        if onEnter then onEnter(self) end
    end)
    btn:HookScript("OnLeave", function(self)
        GameTooltip:Hide()
        if onLeave then onLeave(self) end
    end)
    return btn
end

--- Show one slot on a chip. `style` is the pad's layout style.
function R.Paint(btn, slot, style)
    btn.qcSlot = slot
    local live = slot.line ~= nil or slot.selfText ~= nil or slot.reason == "testMode"
    btn.qcIcon:SetTexture(slot.icon or DEFAULT_ICON)
    btn.qcIcon:SetShown(style ~= "label")
    btn.qcLabel:ClearAllPoints()
    if style == "label" then
        btn.qcLabel:SetPoint("LEFT", btn, "LEFT", 4, 0)
    else
        btn.qcLabel:SetPoint("LEFT", btn.qcIcon, "RIGHT", 4, 0)
    end
    btn.qcLabel:SetText(style == "icon" and "" or (slot.name or "?"))
    btn.qcTag:SetText(PL.Tag(slot.concrete) or "")
    btn.qcTag:SetTextColor(tagColor(slot.chatType or NS.Channels.ChatType(slot.concrete)))
    btn.qcLock:SetShown(slot.lock ~= nil)
    btn.qcDim:SetShown(not live)
    btn.qcCool:Hide()
    btn.qcFlash:Hide()
end

function R.RefreshLock(btn)
    btn.qcLock:SetShown(btn.qcSlot ~= nil and btn.qcSlot.lock ~= nil)
end

function R.Flash(btn, what)
    local c = NS.Constants.FLASH[what] or NS.Constants.FLASH.sent
    btn.qcFlash:SetColorTexture(c[1], c[2], c[3], 0.45)
    btn.qcFlash:Show()
end

function R.Unflash(btn)
    btn.qcFlash:Hide()
end

function R.SetCooling(btn, on)
    btn.qcCool:SetShown(on and true or false)
end

--- Build the header row: the situation chip, the lockdown chip, the test label, the stale hint and
--- the collapse toggle.
function R.DressHeader(header, onCollapse)
    header.qcSituation = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.qcSituation:SetPoint("LEFT", header, "LEFT", 6, 0)
    header.qcLockdown = header:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    header.qcLockdown:SetPoint("LEFT", header.qcSituation, "RIGHT", 6, 0)
    header.qcLockdown:SetText(L["LOCKDOWN"])
    header.qcTest = header:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    header.qcTest:SetPoint("LEFT", header.qcLockdown, "RIGHT", 6, 0)
    header.qcTest:SetText(L["TEST MODE"])
    local collapse = CreateFrame("Button", nil, header)
    collapse:SetSize(16, 16)
    collapse:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    collapse.qcText = collapse:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    collapse.qcText:SetAllPoints(collapse)
    collapse:SetScript("OnClick", function() onCollapse() end)
    header.qcCollapse = collapse
    header.qcStale = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.qcStale:SetPoint("RIGHT", collapse, "LEFT", -4, 0)
    header.qcStale:SetText(L["updates after combat"])
    header.qcLockdown:Hide()
    header.qcTest:Hide()
    header.qcStale:Hide()
end

function R.PaintHeader(header, state)
    header.qcSituation:SetText(state.situation or "")
    header.qcLockdown:SetShown(state.lockdown == true)
    header.qcTest:SetShown(state.test == true)
    header.qcStale:SetShown(state.stale == true)
    header.qcCollapse.qcText:SetText(state.collapsed and "+" or "-")
end
```

In `QuickComms.toc`, directly after `modules\Surfaces.lua`:
```
# LOAD-BEARING: publishes NS.PadRender, which modules\Pad.lua takes as a load-time upvalue.
modules\Pad_Render.lua
```

In `.luacheckrc`, add `"GameTooltip", "ChatTypeInfo",` to `read_globals`.

In `locales/enUS.lua`, add a `-- Comms Pad chips and header (modules/Pad_Render.lua)` block (skip any key the file already defines, such as "Raid" or "Battleground"):
```lua
L["Callout text cannot start with /."] = "Callout text cannot start with /."
L["Too long: a chat line holds 255 bytes."] = "Too long: a chat line holds 255 bytes."
L["This callout has no text."] = "This callout has no text."
L["You are not in a group."] = "You are not in a group."
L["This callout has no valid channel."] = "This callout has no valid channel."
L["This callout is damaged."] = "This callout is damaged."
L["This callout no longer exists."] = "This callout no longer exists."
L["Test mode: a placeholder that sends nothing."] = "Test mode: a placeholder that sends nothing."
L["Locked: you are not in a raid."] = "Locked: you are not in a raid."
L["Locked: needs raid leader or assist."] = "Locked: needs raid leader or assist."
L["Locked: you are not in a group."] = "Locked: you are not in a group."
L["Locked: you are not in an instance group."] = "Locked: you are not in an instance group."
L["Locked: Say and Yell are blocked during this encounter."] =
    "Locked: Say and Yell are blocked during this encounter."
L["Solo: prints to you, sends nothing."] = "Solo: prints to you, sends nothing."
L["Not available here."] = "Not available here."
L["%s (%d of %d)"] = "%s (%d of %d)"
L["M+"] = "M+"
L["Raid"] = "Raid"
L["Dungeon"] = "Dungeon"
L["Arena"] = "Arena"
L["Battleground"] = "Battleground"
L["Delve"] = "Delve"
L["Scenario"] = "Scenario"
L["Housing"] = "Housing"
L["World"] = "World"
L["LOCKDOWN"] = "LOCKDOWN"
L["TEST MODE"] = "TEST MODE"
L["updates after combat"] = "updates after combat"
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including `test_surface_parity` (both the live and the degraded namespace carry `MakeDragHandle` and `DRAG_GAP`).

- [ ] **Step 4b: Confirm the library's DragHandle runs headlessly (controller ruling 9a)**

The case `render: the drag-strip seam builds a hidden strip…` loads LibKa0s-Widgets-1.0's real `DragHandle` in the harness, under a QuickComms-named root with a secure child. A probe made while planning (the Task 1 mock block, a `QuickCommsPadX` root, LibKa0s v1.71.0) ran it cleanly: built hidden, `ApplyWidth(0)` answered 58, `Show()` showed it, `OnDragStart`/`OnDragStop` reached `onDragStop` once, `SetPoint` and `NS.ApplySkin` ran. So no stub is expected.

If that case raises inside the library instead, do not edit `libs/`. Stub at the seam: replace `NS.MakeDragHandle` in `core/WidgetsSetup.lua` with the version below, put the library's error message, verbatim, and the date into its comment, and file an issue against LibKa0s. The pad then has no drag strip where the library raises (it stays at its saved point), and Task 10's two strip assertions (`inst.handle:IsShown()` and the drag case) are replaced by `assertNil(inst.handle)`, with the drag checked in game by PAD-3.
```lua
--- A drag strip over `parent`, or nil when the library is absent or cannot build one.
--- STUBBED <date>: LibKa0s-Widgets-1.0 DragHandle raised "<the error, verbatim>" when it built a
--- strip; until the library is fixed, a raise here costs the strip and one debug line, never the pad.
function NS.MakeDragHandle(parent, spec)
    if not (W and W.DragHandle) then return nil end
    spec.helpIcon = spec.helpIcon or (NS.Icon and NS.Icon("help")) or nil
    local ok, handle = pcall(W.DragHandle, parent, spec)
    if ok then return handle end
    NS.Debug("Pad", "drag strip unavailable: %s", tostring(handle))
    return nil
end
```

- [ ] **Step 5: Commit**

```bash
git add core/WidgetsSetup.lua core/Constants.lua core/Compat.lua modules/Pad_Render.lua tests/test_pad_render.lua tests/test_compat.lua QuickComms.toc tests/run.lua .luacheckrc locales/enUS.lua
git commit -m "Pad_Render: chip and header visuals; the drag-strip seam"
```

---
### Task 10: Pad: the frames, the pooled chips, lock, position, tabs, collapse, feedback

**Files:**
- Create: `modules/Pad.lua`
- Create: `tests/test_pad.lua`
- Modify: `modules/Library.lua` (the writer `SetSurfacePoint`), `tests/test_library.lua` (append)
- Modify: `core/PerfSetup.lua` (one bucket), `QuickComms.toc` (after `modules\Pad_Render.lua`), `tests/run.lua` (add `"test_pad",` after `"test_pad_render",`), `.luacheckrc`, `locales/enUS.lua`

**Interfaces:**
- Consumes: `NS.SendEngine.NewButton` / `Arm` / `Disarm` / `SetVisibility` / `ClearVisibility` / `RunOrQueue` (Tasks 3–4; `onPress(button, verdict, window)`), Task 7's `PL.VisibleSections`, `PL.Compute`, `PL.NextTab`, `PL.VisibilityDriver`, `PL.Alpha`, `PL.HEADER_H`; Task 8's plan and slot shapes and `NS.Compat.DungeonName`; Task 9's `R.Dress`, `R.Paint`, `R.RefreshLock`, `R.Flash`, `R.Unflash`, `R.SetCooling`, `R.DressHeader`, `R.PaintHeader`, `R.SituationText`, `R.SectionTitle`, `NS.MakeDragHandle`, `NS.DRAG_GAP`; `NS.Pool.New` / `Acquire` / `ReleaseAll` / `Counts`; `NS.ApplySkin`; `NS.Restrictions.InCombat()`; the settings `visibility`, `scale`, `alpha`, `locked`, `behavior.lockdownChip`, `behavior.sounds`; `NS.MSG.SEND_RESULT`.
- Produces `NS.Pad`:
  - `Pad.Apply(id, plan) -> boolean` (out of combat only), `Pad.Sync(plans)` (releases every pad not in `plans`, applies the rest), `Pad.Release(id) -> boolean`, `Pad.HideAll()`
  - `Pad.SetStale(id, on)`, `Pad.RefreshLocks(id, showLockdownChip)`, `Pad.ApplyLock()`, `Pad.ApplyAlpha(id)`, `Pad.SetHover(id, on)`, `Pad.Cooldown(window)`
  - `Pad.Wheel(id, delta) -> boolean`, `Pad.ToggleCollapsed(id) -> boolean`, `Pad.ResetPositions()`
  - `Pad.Instance(id) -> { id, root, header, handle, chips, titles, byCallout, plan, live, hover }`, `Pad.ChipsFor(id, calloutId) -> { button… }`, `Pad.Ids() -> { id… }`
  - Frames: root `QuickCommsPad<id>` (`BackdropTemplate`, the Ka0s skin)
  - `NS.Library.SetSurfacePoint(kind, id, point) -> boolean`: the only writer of `pads[id].point` / `dials[id].point` (spec §5.1's named non-setting state; architecture-§5's one registry writer). `point` is `{ point, relativePoint, x, y }` (two strings, two numbers), copied; `nil` clears it. Refuses an unknown kind or id, or a malformed point. Announces `LIBRARY_CHANGED (kind, id)`. The pad calls it on drag stop and from Reset position.
  - Session state, never profile: `NS.State.padTab[id]`, `NS.State.padCollapsed[id]`
  - Perf bucket `pad.layout`

- [ ] **Step 1: Write the failing test**

`tests/test_pad.lua`:
```lua
-- tests/test_pad.lua — modules/Pad.lua (spec §10): the pad's frames and chips. Each chip is a pooled
-- secure send button armed with its baked line; a refused chip is disarmed; visibility goes through
-- the state driver; the drag strip shows only while unlocked and out of combat.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

local function planFor(NS)
    local snap = NS.Situation.Current()
    return NS.Surfaces.BuildPlan("p1", NS.db.profile.pads.p1, snap, NS.Surfaces.Deps(snap))
end

local function applied(inputs)
    local NS, m = live(inputs)
    assertTrue(NS.Pad.Apply("p1", planFor(NS)))
    return NS, m
end

local function pull(NS) return NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1] end

test("pad: the default pad shows the M+ callouts, each chip armed with its baked line", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    assertEqual(inst.root.__name, "QuickCommsPadp1")
    assertTrue(inst.root:IsShown())
    local _, active = NS.Pool.Counts(inst.chips)
    assertEqual(active, 8)
    local chip = pull(NS)
    assertEqual(chip:GetAttribute("type"), "macro")
    assertEqual(chip:GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(chip.qcLabel:GetText(), "Pulling")
    assertEqual(chip.qcTag:GetText(), "P")
    m.__click(chip)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p Pulling next pack")
    assertEqual(inst.header.qcSituation:GetText(), "M+ +12")
end)

test("pad: [review 5] a refused chip is dimmed and disarmed: a click sends and reports nothing", function()
    local NS, m = live()
    local cid = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    NS.Pad.Apply("p1", planFor(NS))
    local chip = NS.Pad.ChipsFor("p1", cid)[1]
    assertNil(chip:GetAttribute("type"))
    assertNil(chip:GetAttribute("macrotext"))
    assertTrue(chip.qcDim:IsShown())
    assertEqual(NS.PadRender.TooltipLines(chip.qcSlot)[2], "Callout text cannot start with /.")
    local heard = 0
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SEND_RESULT, function() heard = heard + 1 end)
    local before = #m.sentMacros
    m.__click(chip)
    assertEqual(#m.sentMacros, before)
    assertEqual(heard, 0)
    assertEqual(pull(NS):GetAttribute("type"), "macro", "the other chips still send")
end)

test("pad: [review 4] a hidden or locked pad still rebuilds; the driver hides; the strip stays hidden", function()
    local NS, m = live()
    NS.SchemaRuntime.Set("visibility", "never")
    NS.Pad.Apply("p1", planFor(NS))
    local inst = NS.Pad.Instance("p1")
    assertFalse(inst.root:IsShown())
    assertEqual(m.stateDrivers[inst.root].visibility, "hide")
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack", "re-armed while hidden")
    assertTrue(NS.Setting("locked"))
    assertFalse(inst.handle:IsShown(), "locked: no drag strip")
    NS.SchemaRuntime.Set("visibility", "always")
    NS.Pad.Apply("p1", planFor(NS))
    assertTrue(inst.root:IsShown())
    NS.SchemaRuntime.Set("locked", false)
    NS.Pad.ApplyLock()
    assertTrue(inst.handle:IsShown())
    NS.db.profile.pads.p1.look.visibility = "outOfCombat"
    NS.Pad.Apply("p1", planFor(NS))
    combat(m, true)
    assertFalse(inst.root:IsShown(), "the driver hides it in combat")
    assertEqual(#m.blocked, 0)
end)

test("pad: a rebuild with fewer chips parks the rest, disarmed, for the next", function()
    local NS = applied()
    local inst = NS.Pad.Instance("p1")
    NS.Library.SetBuiltinEnabled("bi.mplus", false)
    NS.Pad.Apply("p1", planFor(NS))
    local free, active = NS.Pool.Counts(inst.chips)
    assertEqual(active, 0)
    assertEqual(free, 8)
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    NS.Library.SetBuiltinEnabled("bi.mplus", true)
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(NS.SendEngine.ButtonCount(), 8, "the same eight buttons, reused")
end)

test("pad: [registry] no file but Library writes a surface's point", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "modules/Library.lua" then
            local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
            local src = fh:read("*a"):gsub("%-%-[^\r\n]*", "")
            fh:close()
            -- red under: write `pad.point = …` in modules/Pad.lua instead of calling SetSurfacePoint
            assertTrue(not src:find("%.point%s*=[^=]"), rel .. " writes a surface's point")
        end
    end
end)

test("pad: the drag saves the point; locked or in combat it does not move; Reset position clears it", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    local p, _, _, _, y = inst.root:GetPoint(1)
    assertEqual(p, "CENTER")
    assertEqual(y, -150)
    local function drag(x, yy)
        inst.handle:__fire("OnDragStart")
        inst.root:ClearAllPoints()
        inst.root:SetPoint("TOPLEFT", m.UIParent, "TOPLEFT", x, yy)
        inst.handle:__fire("OnDragStop")
    end
    drag(10, -10)
    assertNil(NS.db.profile.pads.p1.point, "locked: canDrag refuses")
    NS.SchemaRuntime.Set("locked", false)
    drag(40, -60)
    assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,40,-60")
    NS.Pad.ResetPositions()
    assertNil(NS.db.profile.pads.p1.point)
    p = inst.root:GetPoint(1)
    assertEqual(p, "CENTER")
end)

test("pad: tabs show one section; the wheel steps them out of combat and is refused in it", function()
    local NS, m = live(AB)
    NS.db.profile.pads.p1.groupsAs = "tabs"
    NS.Pad.Apply("p1", planFor(NS))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.help"), 1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 0)
    assertTrue(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1)
    combat(m, true)
    assertFalse(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1, "unchanged in combat")
    assertEqual(#m.blocked, 0)
end)

test("pad: collapse hides the chips out of combat and is refused, with one line, in it", function()
    local NS, m = applied()
    assertTrue(NS.Pad.ToggleCollapsed("p1"))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.mplus.pull"), 0)
    assertEqual(NS.Pad.Instance("p1").header.qcCollapse.qcText:GetText(), "+")
    assertTrue(NS.Pad.ToggleCollapsed("p1"))
    combat(m, true)
    m.prints = {}
    assertFalse(NS.Pad.ToggleCollapsed("p1"))
    assertEqual(#m.prints, 1)
    assertEqual(#m.blocked, 0)
end)

test("pad: a send result flashes its chips; a press dims every chip for the guard window", function()
    local NS, m = applied()
    local chip = pull(NS)
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, "bi.mplus.pull", "p1", "dropped")
    assertTrue(chip.qcFlash:IsShown())
    m.__fireTimers()
    assertFalse(chip.qcFlash:IsShown())
    m.__click(chip)
    local other = NS.Pad.ChipsFor("p1", "bi.mplus.lust")[1]
    assertTrue(other.qcCool:IsShown(), "the guard is global: every chip dims")
    m.__fireTimers()
    assertFalse(other.qcCool:IsShown())
end)

test("pad: the fade follows the mouse and combat through SetAlpha alone", function()
    local NS, m = applied()
    local inst = NS.Pad.Instance("p1")
    NS.db.profile.pads.p1.look.fade = "mouseover"
    NS.Pad.ApplyAlpha("p1")
    assertEqual(inst.root:GetAlpha(), 0.4)
    NS.Pad.SetHover("p1", true)
    assertEqual(inst.root:GetAlpha(), 1)
    NS.Pad.SetHover("p1", false)
    assertEqual(inst.root:GetAlpha(), 0.4)
    combat(m, true)
    NS.Pad.SetHover("p1", true)
    assertEqual(inst.root:GetAlpha(), 1, "SetAlpha is allowed in combat")
    assertEqual(#m.blocked, 0)
end)

test("pad: Sync releases a pad no plan names: hidden, its chips disarmed", function()
    local NS = applied()
    NS.Pad.Sync({})
    local inst = NS.Pad.Instance("p1")
    assertFalse(inst.root:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    assertFalse(inst.live)
end)
```

Append to `tests/test_library.lua` (it calls the kit's assertions through `T` so it adds no locals):
```lua
test("library: SetSurfacePoint stores a copy of a plain anchor, announces it, and nil clears it", function()
    local NS = T.bootAddon()
    local heard = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.LIBRARY_CHANGED, function(_, kind, id) heard[#heard + 1] = kind .. ":" .. id end)
    local pt = { "TOPLEFT", "TOPLEFT", 40, -60 }
    T.assertTrue(NS.Library.SetSurfacePoint("pad", "p1", pt))
    pt[3] = 999
    T.assertEqual(table.concat(NS.db.profile.pads.p1.point, ","), "TOPLEFT,TOPLEFT,40,-60", "a copy")
    T.assertTrue(NS.Library.SetSurfacePoint("pad", "p1", nil))
    T.assertNil(NS.db.profile.pads.p1.point)
    T.assertEqual(table.concat(heard, ","), "pad:p1,pad:p1")
end)

test("library: SetSurfacePoint refuses an unknown surface or a malformed anchor, and stores nothing", function()
    local NS = T.bootAddon()
    local pt = { "CENTER", "CENTER", 0, 0 }
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p99", pt))
    T.assertFalse(NS.Library.SetSurfacePoint("nope", "p1", pt))
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "d2", pt), "d2 is a dial, not a pad")
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p1", { "CENTER" }))
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p1", { "CENTER", "CENTER", "0", 0 }))
    T.assertFalse(NS.Library.SetSurfacePoint("pad", "p1", "CENTER"))
    T.assertNil(NS.db.profile.pads.p1.point)
    T.assertTrue(NS.Library.SetSurfacePoint("dial", "d2", pt), "the dial's anchor has the same writer")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Add `"test_pad",` to `tests/run.lua` after `"test_pad_render",`. Run: `lua tests/run.lua`
Expected: FAIL (`Pad` and `Library.SetSurfacePoint` are nil).

- [ ] **Step 3: Write the Library writer and the module**

In `modules/Library.lua`, add directly after `Lib.RemoveGroupFromSurface`:
```lua
--- Set, or with nil clear, a pad's or dial's saved anchor (spec §5.1, the named non-setting state).
--- The drag strip and Reset position call it; nothing else writes `point`. A plain copy is stored,
--- so the caller's table never aliases the profile.
--- @param point table|nil { point, relativePoint, x, y }: two strings, then two numbers
--- @return boolean
function Lib.SetSurfacePoint(kind, sid, point)
    local s = surface(kind, sid)
    if not s then return false end
    if point ~= nil then
        if type(point) ~= "table" or type(point[1]) ~= "string" or type(point[2]) ~= "string"
            or type(point[3]) ~= "number" or type(point[4]) ~= "number" then
            return false
        end
        s.point = { point[1], point[2], point[3], point[4] }
    else
        s.point = nil
    end
    announce(kind, sid)
    return true
end
```
and add `point` to the list in the file's header comment ("The only module that creates, deletes, orders or re-references … and the surfaces' saved anchors").

`modules/Pad.lua`:
```lua
local _, NS = ...
-- modules/Pad.lua — the Comms Pad's frames (spec §10.1, §10.3, §10.4).
--
-- The root is a plain BackdropTemplate frame wearing the Ka0s skin (NS.ApplySkin); it becomes
-- protected in combat because its chips are secure. Every chip IS a send button (spec §9.1),
-- built by SendEngine, dressed by Pad_Render, pooled per pad with NS.Pool and never destroyed. The
-- header row (situation chip, lockdown chip, test label, stale hint, collapse) is a plain child;
-- the LibKa0s drag strip sits above the root and shows only while unlocked (KickCD
-- modules/IconGrid_Handle.lua `buildHandle` / `IconGrid:ApplyLock`), and its canDrag refuses while
-- locked or in combat.
--
-- PROTECTED WORK IS OUT OF COMBAT ONLY. Apply, Release and ResetPositions' anchoring run through
-- Surfaces and SendEngine.RunOrQueue; Apply also declines on its own in combat. Visibility is the
-- SendEngine state driver (spec §10.3), never an insecure Show/Hide on the root. What may change in
-- combat is insecure: alpha (the fade), the padlocks, the lockdown chip, the stale hint, the
-- cooldown veil and the flashes. Tab switching and collapse are refused in combat with one line
-- (spec §10.2, the C8 fallback). The position is `pads[id].point = { point, relativePoint, x, y }`
-- (the named non-setting state, spec §5.1), shaped as DropWatcher modules/Window.lua `savePoint` /
-- `applyPoint`. It is registry data, so the drag and Reset position write it only through
-- Library.SetSurfacePoint (architecture-§5); the active tab and the collapsed state are session
-- state in NS.State.

NS.Pad = NS.Pad or {}
local Pad = NS.Pad
local PL = NS.PadLayout
local R = NS.PadRender
local State = NS.State
local L = NS.L
local Perf = NS.Perf

local TAG = "Pad"
local FLASH_SECONDS = 0.4
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -150 }

local pads = {}   -- [padId] = instance; frames are reused across rebuilds and profiles

local function profilePad(id)
    local db = NS.db
    return db and db.profile.pads[id]
end

local function inCombat() return NS.Compat.InCombat() end
local function isLocked() return NS.Setting("locked") ~= false end

local function session(key)
    State[key] = State[key] or {}
    return State[key]
end

local function applyPoint(inst)
    local pad = profilePad(inst.id)
    local pt = (pad and type(pad.point) == "table") and pad.point or DEFAULT_POINT
    inst.root:ClearAllPoints()
    inst.root:SetPoint(pt[1] or "CENTER", UIParent, pt[2] or "CENTER", tonumber(pt[3]) or 0, tonumber(pt[4]) or 0)
end

-- The point is registry data: Library is its only writer (architecture-§5); the pad only asks.
local function savePoint(inst)
    local point, _, relativePoint, x, y = inst.root:GetPoint(1)
    if not point then return end
    if NS.Library.SetSurfacePoint("pad", inst.id, { point, relativePoint, x, y }) then
        NS.Debug(TAG, "%s moved to %s %s,%s", inst.id, point, x, y)
    end
end

-- ── chips ───────────────────────────────────────────────────────────────────────────────────

local function forEachChip(fn)
    for _, inst in pairs(pads) do
        for _, btn in ipairs(inst.chips.active) do fn(btn) end
    end
end

--- The spam guard is global (D12): one press dims every chip on every pad for the window.
function Pad.Cooldown(window)
    forEachChip(function(btn) R.SetCooling(btn, true) end)
    if State.padCoolTimer then NS.addon:CancelTimer(State.padCoolTimer) end
    State.padCoolTimer = NS.addon:ScheduleTimer(function()
        State.padCoolTimer = nil
        forEachChip(function(btn) R.SetCooling(btn, false) end)
    end, tonumber(window) or 1)
end

local function newChip(inst)
    local btn = NS.SendEngine.NewButton(inst.root, function(_, _, window) Pad.Cooldown(window) end)
    R.Dress(btn, function() Pad.SetHover(inst.id, true) end, function() Pad.SetHover(inst.id, false) end)
    return btn
end

local function newTitle(inst)
    return inst.root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
end

local function releaseChip(btn)
    NS.SendEngine.Disarm(btn)
    btn.qcSlot = nil
end

-- Armed when the slot baked; otherwise disarmed, keeping only what a click may still do (a solo
-- self-print). A refused or placeholder chip carries no chat type, so its click reports nothing.
local function arm(btn, slot)
    local meta = { calloutId = slot.calloutId, surfaceId = slot.surfaceId, name = slot.name,
        chatType = slot.chatType, selfText = slot.selfText }
    if slot.line and slot.chatType then
        NS.SendEngine.Arm(btn, slot.line, meta)
    else
        meta.chatType = nil
        NS.SendEngine.Disarm(btn, meta)
    end
end

local function place(inst, box, style)
    for _, item in ipairs(box.items) do
        if item.kind == "chip" then
            local btn = NS.Pool.Acquire(inst.chips, function() return newChip(inst) end)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", inst.root, "TOPLEFT", item.x, -item.y)
            btn:SetSize(item.w, item.h)
            R.Paint(btn, item.slot, style)
            arm(btn, item.slot)
            local list = inst.byCallout[item.slot.calloutId] or {}
            list[#list + 1] = btn
            inst.byCallout[item.slot.calloutId] = list
        else
            local fs = NS.Pool.Acquire(inst.titles, function() return newTitle(inst) end)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", inst.root, "TOPLEFT", item.x, -item.y)
            fs:SetText(R.SectionTitle(item))
        end
    end
end

-- ── the frame ───────────────────────────────────────────────────────────────────────────────

local function build(id)
    local pad = profilePad(id) or {}
    local root = CreateFrame("Frame", "QuickCommsPad" .. id, UIParent, "BackdropTemplate")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:SetFrameStrata("MEDIUM")
    NS.ApplySkin(root)
    local inst = { id = id, root = root, chips = NS.Pool.New(), titles = NS.Pool.New(), byCallout = {},
        hover = 0, live = false }
    local header = CreateFrame("Frame", nil, root)
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    header:SetHeight(PL.HEADER_H)
    header:EnableMouse(true)
    header:EnableMouseWheel(true)
    header:SetScript("OnMouseWheel", function(_, delta) Pad.Wheel(id, delta) end)
    header:SetScript("OnEnter", function() Pad.SetHover(id, true) end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
        Pad.SetHover(id, false)
    end)
    R.DressHeader(header, function() Pad.ToggleCollapsed(id) end)
    inst.header = header
    local label = pad.name or L["Comms Pad"]
    inst.handle = NS.MakeDragHandle(root, {
        label = label,
        moveFrame = root,
        canDrag = function() return not isLocked() and not inCombat() end,
        onDragStop = function() savePoint(inst) end,
        onRightClick = function() NS.addon:OpenSettings() end,
        tooltip = { title = label, body = { L["Drag to move. Right-click for settings."] } },
    })
    if inst.handle then inst.handle:SetPoint("BOTTOM", root, "TOP", 0, NS.DRAG_GAP) end
    pads[id] = inst
    applyPoint(inst)
    NS.Debug(TAG, "built %s", id)
    return inst
end

local function headerState(inst, plan)
    local snap = plan.snapshot or {}
    return {
        situation = plan.test and L["Test mode"] or R.SituationText(snap, NS.Compat.DungeonName(snap.challengeMapID)),
        lockdown = plan.lockdownChip == true and NS.Setting("behavior.lockdownChip") ~= false,
        stale = State.surfaceStale ~= nil and State.surfaceStale[inst.id] == true,
        test = plan.test == true,
        collapsed = session("padCollapsed")[inst.id] == true,
    }
end

--- Rebuild one pad from its plan. Out of combat only: Surfaces runs it through RunOrQueue.
--- @return boolean applied
function Pad.Apply(id, plan)
    if inCombat() then return false end
    local pad = profilePad(id)
    if not (pad and plan) then return false end
    local t0 = Perf.on and debugprofilestop()
    local inst = pads[id] or build(id)
    inst.plan, inst.live = plan, true
    NS.Pool.ReleaseAll(inst.chips, releaseChip)
    NS.Pool.ReleaseAll(inst.titles)
    inst.byCallout = {}
    local layout = type(pad.layout) == "table" and pad.layout or {}
    local look = type(pad.look) == "table" and pad.look or {}
    local sections = PL.VisibleSections(plan.sections, pad.groupsAs, session("padTab")[id])
    local box = PL.Compute(sections, layout, { collapsed = session("padCollapsed")[id] == true })
    inst.root:SetScale(math.max(0.3, (tonumber(NS.Setting("scale")) or 1) * (tonumber(layout.scale) or 1)))
    inst.root:SetSize(box.width, box.height)
    place(inst, box, layout.style)
    R.PaintHeader(inst.header, headerState(inst, plan))
    Pad.ApplyLock()
    NS.SendEngine.SetVisibility(inst.root,
        PL.VisibilityDriver(NS.Setting("visibility"), look.visibility, plan.hasActive, plan.test == true))
    Pad.ApplyAlpha(id)
    if t0 then Perf.Note("pad.layout", debugprofilestop() - t0) end
    return true
end

--- Take a pad off screen: its chips disarmed and parked, its driver cleared. Out of combat only.
function Pad.Release(id)
    local inst = pads[id]
    if not inst or inCombat() then return false end
    NS.Pool.ReleaseAll(inst.chips, releaseChip)
    NS.Pool.ReleaseAll(inst.titles)
    inst.byCallout, inst.plan, inst.live = {}, nil, false
    if inst.handle then inst.handle:Hide() end
    NS.SendEngine.ClearVisibility(inst.root)
    return true
end

function Pad.HideAll()
    for id in pairs(pads) do Pad.Release(id) end
end

--- Make the pads match a set of plans: release every pad no plan names, then apply each plan.
function Pad.Sync(plans)
    for id in pairs(pads) do
        if not plans[id] then Pad.Release(id) end
    end
    for id, plan in pairs(plans) do Pad.Apply(id, plan) end
end

-- ── insecure updates, allowed in combat ─────────────────────────────────────────────────────

function Pad.SetStale(id, on)
    local inst = pads[id]
    if inst then inst.header.qcStale:SetShown(on and true or false) end
end

function Pad.RefreshLocks(id, showLockdownChip)
    local inst = pads[id]
    if not inst then return end
    for _, btn in ipairs(inst.chips.active) do R.RefreshLock(btn) end
    inst.header.qcLockdown:SetShown(showLockdownChip and true or false)
end

--- The drag strip: shown on a live pad while unlocked. The strip is not protected.
function Pad.ApplyLock()
    local locked = isLocked()
    for _, inst in pairs(pads) do
        if inst.handle then
            if locked or not inst.live then
                inst.handle:Hide()
            else
                inst.handle:ApplyWidth(0)
                inst.handle:Show()
            end
        end
    end
end

function Pad.ApplyAlpha(id)
    local inst, pad = pads[id], profilePad(id)
    if not (inst and pad) then return end
    inst.root:SetAlpha(PL.Alpha(NS.Setting("alpha"), pad.look, NS.Restrictions.InCombat(), inst.hover > 0))
end

function Pad.SetHover(id, on)
    local inst = pads[id]
    if not inst then return end
    inst.hover = math.max(0, inst.hover + (on and 1 or -1))
    Pad.ApplyAlpha(id)
end

-- ── tabs, collapse, position ────────────────────────────────────────────────────────────────

--- The mouse wheel over the header switches tabs; refused in combat with a one-line tooltip.
function Pad.Wheel(id, delta)
    local inst, pad = pads[id], profilePad(id)
    if not (inst and inst.plan and pad and pad.groupsAs == "tabs") then return false end
    if inCombat() then
        GameTooltip:SetOwner(inst.header, "ANCHOR_TOP")
        GameTooltip:SetText(L["Tabs switch after combat."])
        GameTooltip:Show()
        return false
    end
    local tabs = session("padTab")
    tabs[id] = PL.NextTab(tabs[id], #inst.plan.sections, delta)
    return Pad.Apply(id, inst.plan)
end

function Pad.ToggleCollapsed(id)
    local inst = pads[id]
    if not (inst and inst.plan) then return false end
    if inCombat() then
        NS.Print(L["The pad can be collapsed or expanded after combat."])
        return false
    end
    local c = session("padCollapsed")
    c[id] = (not c[id]) or nil
    return Pad.Apply(id, inst.plan)
end

--- Master controls' Reset position (spec §10.4): every pad back to its default anchor.
function Pad.ResetPositions()
    local p = NS.db and NS.db.profile
    if not p then return end
    for id in pairs(p.pads) do NS.Library.SetSurfacePoint("pad", id, nil) end
    NS.SendEngine.RunOrQueue("positions", function()
        for _, inst in pairs(pads) do applyPoint(inst) end
    end)
    NS.Print(L["Pad positions reset."])
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

function Pad.Instance(id)
    return pads[id]
end

function Pad.ChipsFor(id, calloutId)
    local inst = pads[id]
    return inst and inst.byCallout[calloutId] or {}
end

function Pad.Ids()
    local out = {}
    for id in pairs(pads) do out[#out + 1] = id end
    table.sort(out)
    return out
end

-- ── the edge: send results ──────────────────────────────────────────────────────────────────

local function onSendResult(_, calloutId, surfaceId, what)
    local inst = pads[surfaceId]
    local list = inst and inst.byCallout[calloutId]
    if not list then return end
    for _, btn in ipairs(list) do R.Flash(btn, what) end
    local timers = session("padFlashTimers")
    local handle
    handle = NS.addon:ScheduleTimer(function()
        timers[handle] = nil
        for _, btn in ipairs(list) do R.Unflash(btn) end
    end, FLASH_SECONDS)
    timers[handle] = true
    if what == "sent" and NS.Setting("behavior.sounds") then
        PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master")
    end
end

local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.SEND_RESULT, onSendResult) end
end
listen()

-- The insecure half of the stand-down; the secure half (hide, disarm) is Surfaces' Teardown.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.padFlashTimers or {}) do NS.addon:CancelTimer(handle) end
    if State.padCoolTimer then NS.addon:CancelTimer(State.padCoolTimer) end
    State.padFlashTimers, State.padCoolTimer = nil, nil
    for _, inst in pairs(pads) do inst.hover = 0 end
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.SEND_RESULT) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
```

In `QuickComms.toc`, directly after `modules\Pad_Render.lua`:
```
# Conventional: the Comms Pad frames; appends to NS.STAND_DOWN / NS.STAND_UP
modules\Pad.lua
```

In `core/PerfSetup.lua`, add to `BUCKETS`:
```lua
    { key = "pad.layout" },   -- modules/Pad.lua: one pad's rebuild (geometry, chips, arm)
```

In `.luacheckrc`, add `"PlaySound", "SOUNDKIT",` to `read_globals`.

In `locales/enUS.lua`, add a `-- Comms Pad (modules/Pad.lua)` block (skip any key the file already defines, such as "Comms Pad"):
```lua
L["Drag to move. Right-click for settings."] = "Drag to move. Right-click for settings."
L["Tabs switch after combat."] = "Tabs switch after combat."
L["The pad can be collapsed or expanded after combat."] = "The pad can be collapsed or expanded after combat."
L["Pad positions reset."] = "Pad positions reset."
L["Test mode"] = "Test mode"
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including the firewall test (Pad.lua makes no secure call of its own).

- [ ] **Step 5: Commit**

```bash
git add modules/Pad.lua modules/Library.lua tests/test_pad.lua tests/test_library.lua core/PerfSetup.lua QuickComms.toc tests/run.lua .luacheckrc locales/enUS.lua
git commit -m "Pad: pooled secure chips, header, drag strip and lock, position via Library, tabs, collapse, feedback"
```

---
### Task 11: Surfaces: the rebuild edge, the stale hint, the profile switch, the stand-down

**Files:**
- Modify: `modules/Surfaces.lua` (append the edge; extend the header)
- Modify: `modules/Situation.lua` (publish `Sit.Restamp`)
- Modify: `tests/test_surfaces.lua` (append)

**Interfaces:**
- Consumes: Task 8's `S.BuildPlan`, `S.TestPlan`, `S.Deps`; Task 10's `NS.Pad.Sync`, `HideAll`, `SetStale`, `RefreshLocks`, `ApplyAlpha`, `Ids`, `Instance`, `ChipsFor`; Task 3's `NS.SendEngine.RunOrQueue`, `Drop`, `Teardown`; Task 5's `NS.Preview.IsTestMode`; `NS.Channels.LockState`; `NS.Situation.Current`; the messages `SITUATION_CHANGED`, `LIBRARY_CHANGED`, `TEST_MODE_CHANGED`, `PROFILE_CHANGED`, `RESTRICTION_CHANGED`, `COMBAT_QUEUE_DRAINED`.
- Produces:
  - `S.Request(reason) -> ranNow` (the one rebuild entry point: settings reactions, messages, stand-up)
  - `S.ApplyAll(reason) -> count` (out of combat; recomputes every enabled pad's plan from the CURRENT snapshot)
  - `S.RefreshLocks()` (insecure, in combat too: padlocks, the lockdown chip, the fade)
  - `S.Plans() -> { [padId] = plan }`
  - `NS.Situation.Restamp()` (refreshes the current snapshot's lockdown and combat in place)
  - Messages `ACTIVE_GROUPS_CHANGED (surfaceId)` when a pad's ordered active groups change, and `SURFACE_REBUILT (surfaceId, stale)` (`true` when the rebuild was held for combat, `false` when it ran)
  - Session state `NS.State.surfacePlans`, `surfaceOrder`, `surfaceStale`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_surfaces.lua`:
```lua
-- ── the rebuild edge (Task 11) ──────────────────────────────────────────────────────────────

local function combat(m, on)
    if on then
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_DISABLED")
        m.__setCombat(true)
    else
        m.__setCombat(false)
        m.__fire("PLAYER_REGEN_ENABLED")
    end
end

local function pull(NS) return NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1] end
local function staleShown(NS) return NS.Pad.Instance("p1").header.qcStale:IsShown() end

local function nonMessages(m)
    local out = {}
    for _, r in ipairs(m.__registrations()) do
        if r.kind ~= "message" then out[#out + 1] = r.event end
    end
    table.sort(out)
    return table.concat(out, ",")
end

local function withInputs(base, extra)
    local i = {}
    for k, v in pairs(base) do i[k] = v end
    for k, v in pairs(extra) do i[k] = v end
    return i
end

test("surfaces: the first situation read builds the default pad, armed and shown", function()
    local NS = live()
    local inst = NS.Pad.Instance("p1")
    assertTrue(inst ~= nil)
    assertTrue(inst.root:IsShown())
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
end)

test("surfaces: ACTIVE_GROUPS_CHANGED is sent once per real change of a pad's active groups", function()
    local NS = live()
    local heard = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.ACTIVE_GROUPS_CHANGED, function(_, id) heard[#heard + 1] = id end)
    NS.Library.CreateCallout({ name = "Loose", text = "hi", channel = "party" })
    assertEqual(#heard, 0, "a library write that moves no group")
    NS.Situation.ReadInputs = function() return AB end
    NS.Situation.RefreshNow("test")
    assertEqual(table.concat(heard, ","), "p1")
    NS.Surfaces.Request("again")
    NS.Surfaces.Request("and again")
    -- red under: drop the `sig ~= State.surfaceOrder[id]` check in S.ApplyAll
    assertEqual(table.concat(heard, ","), "p1", "a rebuild with the same groups sends nothing")
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    assertEqual(table.concat(heard, ","), "p1,p1", "back to M+ is a second real change")
end)

test("surfaces: [review 1] a situation change in combat queues: nothing blocked, stale shows, combat end rebuilds", function()
    local NS, m = live()
    local chip = pull(NS)
    local rebuilt = {}
    local t = NS.Bus:NewTarget()
    t:RegisterMessage(NS.MSG.SURFACE_REBUILT, function(_, id, stale) rebuilt[#rebuilt + 1] = id .. ":" .. tostring(stale) end)
    combat(m, true)
    NS.Situation.ReadInputs = function() return withInputs(MPLUS, { inInstanceGroup = true }) end
    NS.Situation.RefreshNow("test")
    assertEqual(#m.blocked, 0)
    assertEqual(chip:GetAttribute("macrotext"), "/p Pulling next pack", "frozen in combat")
    assertTrue(staleShown(NS))
    assertEqual(table.concat(rebuilt, ","), "p1:true")
    combat(m, false)
    -- red under: drop the RunOrQueue in S.Request (the rebuild would run, and be blocked, in combat)
    assertEqual(pull(NS):GetAttribute("macrotext"), "/i Pulling next pack")
    assertFalse(staleShown(NS))
    assertEqual(table.concat(rebuilt, ","), "p1:true,p1:false")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: [review 1] a profile switch in combat queues the new profile's pads", function()
    local NS, m = live()
    combat(m, true)
    NS.addon.db:SetProfile("Other")
    assertEqual(#m.blocked, 0)
    assertTrue(staleShown(NS))
    combat(m, false)
    assertEqual(#m.blocked, 0)
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
    assertFalse(staleShown(NS))
end)

test("surfaces: a setting written in combat waits for combat end, with the stale hint", function()
    local NS, m = live()
    combat(m, true)
    NS.SchemaRuntime.Set("behavior.autoPromote", true)
    assertTrue(staleShown(NS))
    combat(m, false)
    assertFalse(staleShown(NS))
    assertEqual(#m.blocked, 0)
end)

test("surfaces: an encounter lockdown in combat padlocks a Say chip and lights the chip, nothing blocked", function()
    local NS, m = live()
    local cid = userCallout(NS, { name = "Shout", text = "Go go", channel = "say" })
    local chip = NS.Pad.ChipsFor("p1", cid)[1]
    assertFalse(chip.qcLock:IsShown())
    combat(m, true)
    local enc = m.Enum.AddOnRestrictionType.Encounter
    m.restrictionStates[enc] = m.Enum.AddOnRestrictionState.Active
    m.__fire("ADDON_RESTRICTION_STATE_CHANGED", enc, m.Enum.AddOnRestrictionState.Active)
    assertTrue(chip.qcLock:IsShown())
    assertTrue(NS.Pad.Instance("p1").header.qcLockdown:IsShown())
    assertEqual(chip:GetAttribute("macrotext"), "/s Go go", "a lock never disarms")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: test mode draws placeholders that send nothing; combat start brings the live chips back", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    local inst = NS.Pad.Instance("p1")
    assertTrue(inst.header.qcTest:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0, "placeholders are disarmed")
    m.__click(NS.Pad.ChipsFor("p1", "test.1.1")[1])
    assertEqual(#m.sentMacros, 0)
    combat(m, true)
    assertFalse(NS.Preview.IsTestMode())
    assertFalse(inst.header.qcTest:IsShown())
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(#m.blocked, 0)
end)

test("surfaces: if lockdown has already begun at the combat edge, test mode's end is queued, not blocked", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    m.__setCombat(true)                    -- InCombatLockdown() is already true when the edge fires
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.blocked, 0)
    assertTrue(staleShown(NS))
    assertEqual(#NS.SendEngine.ArmedButtons(), 0, "the placeholders stay, disarmed, until combat ends")
    combat(m, false)
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
    assertFalse(staleShown(NS))
    assertFalse(NS.Pad.Instance("p1").header.qcTest:IsShown())
end)

test("surfaces: disabled out of combat, every pad hides and every chip disarms; enabled, they return", function()
    local NS = live()
    local inst = NS.Pad.Instance("p1")
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(inst.root:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    NS.SchemaRuntime.Set("enabled", true)
    assertTrue(inst.root:IsShown())
    assertEqual(pull(NS):GetAttribute("macrotext"), "/p Pulling next pack")
end)

test("surfaces: [review 2] disabled mid-combat: nothing blocked, one held registration, finished at combat end", function()
    local NS, m = live()
    local inst = NS.Pad.Instance("p1")
    combat(m, true)
    NS.SchemaRuntime.Set("enabled", false)
    assertTrue(NS.IsStoodDown())
    assertEqual(#m.blocked, 0)
    assertTrue(inst.root:IsShown(), "held: no protected call in combat")
    -- red under: register the held teardown on NS.addon instead of SendEngine's own target
    assertEqual(nonMessages(m), "PLAYER_REGEN_ENABLED", "the one permitted registration")
    combat(m, false)
    assertFalse(inst.root:IsShown())
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    assertEqual(nonMessages(m), "", "released the moment it fired")
    assertEqual(#m.blocked, 0)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (`NS.Pad.Instance("p1")` is nil after the first situation read: nothing requests a rebuild yet).

- [ ] **Step 3: Write the edge**

In `modules/Situation.lua`, replace:
```lua
local function onRestrictionChanged()
    local s = State.situation
    if s then withRestrictions(s) end
end
```
with:
```lua
--- Refresh the current snapshot's lockdown and combat in place; never moves the signature. A
--- module that reads the lockdown on RESTRICTION_CHANGED calls this first, so the order in which
--- receivers hear the message never matters.
function Sit.Restamp()
    local s = State.situation
    if s then withRestrictions(s) end
end

local function onRestrictionChanged()
    Sit.Restamp()
end
```

In `modules/Surfaces.lua`, extend the header comment with:
```lua
--
-- THE EDGE (below): one entry point, Request, for everything that changes what a pad draws: the
-- situation, the library, the profile, test mode, a settings write and the stand-up. Out of combat
-- it rebuilds every enabled pad from the CURRENT snapshot at once; in combat it files one keyed
-- entry ("surfaces") in SendEngine's combat-end queue, shows each pad's stale hint and sends
-- SURFACE_REBUILT (id, true); the drain rebuilds from the snapshot as it is THEN, and
-- COMBAT_QUEUE_DRAINED clears the hints (spec §9.1, §18). A profile switch first drops whatever the
-- old profile queued. RESTRICTION_CHANGED only re-reads the locks, the lockdown chip and the fade,
-- which are insecure and change in combat too. The stand-down hands the secure half (hide every
-- pad, disarm every chip) to SendEngine.Teardown, which holds it to combat end if need be.
```

Append to `modules/Surfaces.lua`:
```lua
-- ── the edge: one rebuild request, queued in combat (spec §9.1, §18) ────────────────────────

local State = NS.State
local TAG = "Pad"

local function enabledPadIds()
    local p = NS.db and NS.db.profile
    local out = {}
    if not p then return out end
    for _, id in ipairs(p.padOrder) do
        local pad = p.pads[id]
        if type(pad) == "table" and pad.enabled ~= false then out[#out + 1] = id end
    end
    return out
end

local function staleSet()
    State.surfaceStale = State.surfaceStale or {}
    return State.surfaceStale
end

function S.Plans()
    return State.surfacePlans or {}
end

--- Rebuild every enabled pad from the current snapshot. Out of combat (RunOrQueue's caller).
--- @return number pads rebuilt
function S.ApplyAll(reason)
    if NS.IsStoodDown() or not State.situation then return 0 end
    local snap = NS.Situation.Current()
    local deps = S.Deps(snap)
    local test = NS.Preview.IsTestMode()
    local pads = NS.db.profile.pads
    local plans, n = {}, 0
    State.surfaceOrder = State.surfaceOrder or {}
    for _, id in ipairs(enabledPadIds()) do
        local plan = test and S.TestPlan(id) or S.BuildPlan(id, pads[id], snap, deps)
        plans[id] = plan
        n = n + 1
        local sig = table.concat(plan.order, ",")
        if sig ~= State.surfaceOrder[id] then
            State.surfaceOrder[id] = sig
            NS.addon:SendMessage(NS.MSG.ACTIVE_GROUPS_CHANGED, id)
        end
    end
    State.surfacePlans = plans
    local stale = staleSet()
    for id in pairs(stale) do stale[id] = nil end
    NS.Pad.Sync(plans)
    for id in pairs(plans) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    NS.Debug(TAG, "rebuilt %s pad(s) (%s)", n, tostring(reason))
    return n
end

--- Ask for a rebuild: now, or at the end of combat with the stale hint showing meanwhile.
--- Nothing is built before the first situation read, or while stood down.
--- @return boolean ranNow
function S.Request(reason)
    if NS.IsStoodDown() or not State.situation then return false end
    if NS.SendEngine.RunOrQueue("surfaces", function() S.ApplyAll(reason) end) then return true end
    local stale = staleSet()
    for _, id in ipairs(NS.Pad.Ids()) do
        if not stale[id] then
            stale[id] = true
            NS.Pad.SetStale(id, true)
            NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, true)
        end
    end
    NS.Debug(TAG, "rebuild held for combat (%s)", tostring(reason))
    return false
end

--- Re-read every slot's lock (spec §8.4), the lockdown chip and the fade. Insecure: runs in combat.
function S.RefreshLocks()
    local plans = State.surfacePlans
    if not plans then return end
    NS.Situation.Restamp()
    local snap = NS.Situation.Current()
    local showChip = NS.Setting("behavior.lockdownChip") ~= false
    for id, plan in pairs(plans) do
        if not plan.test then
            plan.lockdownChip = false
            for _, sec in ipairs(plan.sections) do
                for _, slot in ipairs(sec.slots) do
                    if slot.concrete then slot.lock = NS.Channels.LockState(slot.concrete, snap) end
                    if slot.lock == "lockdown" then plan.lockdownChip = true end
                end
            end
            NS.Pad.RefreshLocks(id, plan.lockdownChip and showChip)
        end
        NS.Pad.ApplyAlpha(id)
    end
end

local function onDrained()
    local stale = State.surfaceStale
    if not stale then return end
    for id in pairs(stale) do
        stale[id] = nil
        NS.Pad.SetStale(id, false)
    end
end

local function onProfileChanged()
    NS.SendEngine.Drop("profile")
    State.surfaceOrder = nil
    S.Request("profile")
end

local HANDLERS = {
    { NS.MSG.SITUATION_CHANGED, function() S.Request("situation") end },
    { NS.MSG.LIBRARY_CHANGED, function() S.Request("library") end },
    { NS.MSG.TEST_MODE_CHANGED, function() S.Request("testMode") end },
    { NS.MSG.PROFILE_CHANGED, onProfileChanged },
    { NS.MSG.RESTRICTION_CHANGED, function() S.RefreshLocks() end },
    { NS.MSG.COMBAT_QUEUE_DRAINED, onDrained },
}

-- Its own target (core/Bus.lua); one target holds several different messages.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if not receiver then return end
    for _, h in ipairs(HANDLERS) do receiver:RegisterMessage(h[1], h[2]) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.surfacePlans, State.surfaceOrder, State.surfaceStale = nil, nil, nil
    NS.SendEngine.Teardown(function() NS.Pad.HideAll() end)
    if receiver and not NS.Bus.tracked then
        for _, h in ipairs(HANDLERS) do receiver:UnregisterMessage(h[1]) end
    end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    S.Request("standUp")
end
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS: every suite, including Tasks 6–10's (their reactions now reach `Request`), `test_disabled` and the kit's `test_diagnostics_contract`.

- [ ] **Step 5: Commit**

```bash
git add modules/Surfaces.lua modules/Situation.lua tests/test_surfaces.lua
git commit -m "Surfaces: one rebuild request, queued in combat with the stale hint; held stand-down"
```

---

### Task 12: Diagnostics: the surfaces and the send engine

**Files:**
- Modify: `modules/Diagnostics.lua` (two sections)
- Modify: `tests/test_diagnostics.lua`

**Interfaces:**
- Consumes: `NS.Surfaces.Plans()`, `NS.State.surfaceStale`, `NS.Preview.IsTestMode()`, `NS.SendEngine.ButtonCount()`, `ArmedButtons()`, `Escaped(button)`, `Snapshot()`, `GuardState()`, `EchoState()`, `NS.Pad.Ids()`.
- Produces: diagnostics sections `surfaces` and `send` (spec §16: the active groups per surface, the armed buttons with each slot's callout and its escaped baked text, the pending queue keys, the guard state and the echo counts). Override bindings arrive with the Dial (phase 4).

- [ ] **Step 1: Write the failing test**

In `tests/test_diagnostics.lua`, change the expected list in `"diagnostics: the sections are the addon's, in report order"` to:
```lua
    assertEqual(table.concat(names, ","),
        "identity,settings,registration,integrations,situation,restrictions,library,surfaces,send")
```
and append:
```lua
test("diagnostics: the surfaces and send sections name the pads, the armed chips and the guard", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    local text = report(NS)
    assertTrue(text:find("p1 active=bi.mplus stale=false", 1, true) ~= nil, text)
    assertTrue(text:find("buttons=8 armed=8", 1, true) ~= nil, text)
    assertTrue(text:find("p1:bi.mplus.pull /p Pulling next pack", 1, true) ~= nil, text)
    assertTrue(text:find("pending -", 1, true) ~= nil, "no queued keys")
    assertTrue(text:find("window=1", 1, true) ~= nil, "the guard")
    assertTrue(text:find("sent=0 dropped=0", 1, true) ~= nil, "the echo counts")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `lua tests/run.lua`
Expected: FAIL (two sections missing).

- [ ] **Step 3: Write the sections**

In `modules/Diagnostics.lua`, add above `function NS.Diagnostics.Sections()`:
```lua
-- The surfaces (spec §16): each pad's active groups, its stale hint, its lockdown chip.
local function surfaces(out)
    local plans = NS.Surfaces.Plans()
    local stale = NS.State.surfaceStale or {}
    out:joined("Pad", "pads built", NS.Pad.Ids())
    out:add("Pad", "testMode=%s", NS.Preview.IsTestMode())
    local ids = {}
    for id in pairs(plans) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local plan = plans[id]
        out:add("Pad", "%s active=%s stale=%s lockdownChip=%s", id, table.concat(plan.order, ","),
            stale[id] == true, plan.lockdownChip)
    end
end

-- The send engine (spec §16): the armed buttons, each with its pad, callout and escaped line; the
-- combat-end queue's keys; the guard; the echo tracker's counts.
local function send(out)
    local SE = NS.SendEngine
    local armed = SE.ArmedButtons()
    out:add("Send", "buttons=%s armed=%s", SE.ButtonCount(), #armed)
    for _, b in ipairs(armed) do
        local meta = b.qcMeta or {}
        out:add("Send", "%s %s:%s %s", b:GetName(), meta.surfaceId, meta.calloutId, SE.Escaped(b))
    end
    out:joined("Queue", "pending", SE.Snapshot())
    local g = SE.GuardState()
    out:add("Guard", "window=%s last=%s remaining=%s", g.window, g.last, g.remaining)
    local e = SE.EchoState()
    out:add("Echo", "pending=%s sent=%s dropped=%s unknownSender=%s ignored=%s", e.pending, e.sent, e.dropped,
        e.unknown, e.ignored)
end
```
and add the two rows to the end of the list `NS.Diagnostics.Sections()` returns:
```lua
        { "surfaces",     surfaces },
        { "send",         send },
```
Update the file's header sentence "The feature tasks add their own sections (design spec §16: the snapshot, restrictions, active groups, armed buttons, the combat queue, bindings, the guard, the echo tracker) here." to "The sections cover design spec §16's list; override bindings join with the Dial (phase 4)."

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including the kit's `test_diagnostics_contract` (each section reads and never acts: no hold, no event, no timer).

- [ ] **Step 5: Commit**

```bash
git add modules/Diagnostics.lua tests/test_diagnostics.lua
git commit -m "Diagnostics: the surfaces and send-engine sections"
```

---
### Task 13: The docs for phase 2

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md` (the controller's rulings, Step 0)
- Modify: `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/data-flow.md`, `docs/smoke-tests.md`, `docs/slash-dispatch.md`, `docs/debug.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/scope.md`, `docs/performance.md`, `docs/testing.md`, `docs/test-cases.md` (regenerated), `README.md`

**Interfaces:**
- Consumes: everything Tasks 1–12 built, by the names they produce.
- Produces: documentation only; no code changes. Step 7 is a separate, local-only commit in the sibling `WowAddonStandards` repository.

- [ ] **Step 0: Write the controller's rulings into the spec**

In `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`:
- **§9.1, Pool:** append to the Pool paragraph: "*Built (phase 2):* one array pool per pad (`NS.Pool.New`), the family the addon already wires; the pad keeps a `byCallout` index for its flashes, so the keyed family is not needed."
- **§9.4:** add at the top of the section: "*Phase 2 ships no binding:* a pad chip has no key in v0.1.0. Override bindings, `Bindings.xml` and their stand-down arrive with the Comms Dial (phase 4)."
- **§10.1:** append to "The pad itself": "*Built (phase 2):* the header is a plain row that always shows its chips; the LibKa0s `DragHandle` is a strip above the pad, shown only while unlocked (KickCD's shape), and its `canDrag` refuses while locked or in combat."
- **§5.1, named non-setting state:** replace "`pads[id].point` is written by drag, and its one owner is `Pad`." with "`pads[id].point` is written by drag, through `Library.SetSurfacePoint`: `Library` stays the one registry writer, and `Pad` only asks."
- **§17, the `SEND_RESULT` row:** change the Payload cell to "calloutId, surfaceId, `"guarded"` at the press when inside the guard window, then `"sent"` or `"dropped"` from the echo: one press can yield two results".
- **§19, the phase 2 row's Exit cell:** replace "The guard blocks double presses." with "A double press inside the guard window is marked guarded (dimmed, noted) and the extra send is reported dropped if the echo doesn't arrive."

- [ ] **Step 1: ARCHITECTURE.md**

Make these edits to `docs/ARCHITECTURE.md`:
- **Module Map:** add one row per new file, in TOC order: `core/WidgetsSetup.lua` (the drag-strip seam), `modules/SendEngine_Guard.lua` (pure: guard, acting edge, echo, keyed queue), `modules/SendEngine.lua` (the only secure writer), `modules/Preview.lua` (test mode), `modules/Pad_Layout.lua` (pure geometry, visibility, fade), `modules/Surfaces.lua` (plans and the one rebuild request), `modules/Pad_Render.lua` (insecure chip and header visuals), `modules/Pad.lua` (the pad's frames).
- **Settings Schema:** add the Master controls rows `visibility`, `scale`, `alpha`, `locked` (defaults `always`, 1, 1, `true`), the session row `state.testMode`, and under the named non-setting state: "`pads[id].point = { point, relativePoint, x, y }`, written only through `Library.SetSurfacePoint` (the registry writer), which the drag strip and Reset position in `modules/Pad.lua` call; the per-pad X/Y rows arrive with the Pads page (phase 3). The pad's active tab and collapsed state are session-only (`NS.State`)."
- **Message Bus:** delete the paragraph "Declared and not yet sent (phase 2): …" and add these rows to the table (and fill the Consumers cells of `PROFILE_CHANGED`, `SITUATION_CHANGED` and `LIBRARY_CHANGED` with "Surfaces (`Request`)"):

| `NS.MSG` key | Wire suffix | Sender | Payload | Consumers |
|---|---|---|---|---|
| `ACTIVE_GROUPS_CHANGED` | `ActiveGroupsChanged` | `modules/Surfaces.lua` `ApplyAll`, when a pad's ordered active groups change | surfaceId | diagnostics; the settings dots (phase 3) |
| `SURFACE_REBUILT` | `SurfaceRebuilt` | `modules/Surfaces.lua`: `true` when a rebuild is held for combat, `false` when it ran | surfaceId, stale | none yet; the settings pages (phase 3) |
| `SEND_RESULT` | `SendResult` | `modules/SendEngine.lua`: `guarded` at the press, then `sent` or `dropped` from the echo, so one press can yield two | calloutId, surfaceId, result | `modules/Pad.lua` (the flash, the sound) |
| `COMBAT_QUEUE_DRAINED` | `CombatQueueDrained` | `modules/SendEngine.lua` `Drain` | count | `modules/Surfaces.lua` (clears the stale hints) |
| `TEST_MODE_CHANGED` | `TestModeChanged` | `modules/Preview.lua` `SetTestMode` | on | `modules/Surfaces.lua` (`Request`) |

- **Slash Commands:** add `lock`, `unlock` (reserved, slash-commands-§8: the Lock frame row's path through the seam) and the feature verb `test` (test mode) to the sentence listing the verbs.
- **Event Subscriptions:** add "The send engine's nine `CHAT_MSG_*` rows (say, yell, party and its leader, raid and its leader, raid warning, instance and its leader), whose handler matches an echo to a press without reading the text. The one registration outside `NS.FEATURE_EVENTS` is `SendEngine`'s private `PLAYER_REGEN_ENABLED` target, which exists only while a stand-down is held in combat and is released when it fires (slash-commands-§7)."
- **Taint Notes:** replace the whole paragraph with:

> Every secure rule lives in one file. `modules/SendEngine.lua` is the only code that creates a frame from a `Secure*` template, calls `SetAttribute` or registers a state driver; `tests/test_sendengine.lua` greps every other shipped file for those calls and for `SendChatMessage` (D12: the secure button is the one send path). Send buttons are `SecureActionButtonTemplate`, named `QuickCommsSend<n>`, registered for `AnyUp` and `AnyDown`, armed with `type=macro` and one baked `macrotext` line, and only out of combat (`InCombatLockdown()`, events-frames-taint-§2). A pad's root becomes protected in combat because its chips are secure: its visibility is a `visibility` state driver, and its geometry is set only in rebuilds. A rebuild asked for in combat is filed in SendEngine's keyed combat-end queue (one entry per key, the last write winning) and drained on the `RESTRICTION_CHANGED` that follows `PLAYER_REGEN_ENABLED`; `Restrictions` owns both combat edges. The click hook is an insecure `HookScript("OnClick")`: it cannot cancel the secure click, so the spam guard is soft (spec §9.2), and it never reads chat text. A stand-down in combat holds its secure half in one private `PLAYER_REGEN_ENABLED` registration, released when it fires. Tabs and collapse are refused in combat. No override binding exists until the Dial (phase 4). Opening the settings panel stays refused in combat by the options library.

- **Known Limitations:** replace the first two bullets ("Phase 1 has no pad…" and "The Master controls tab is frameless…") with:

> - The spam guard is soft: insecure code cannot cancel a secure click, so a press inside the window still reaches the game. A boss may drop it; the echo tracker then reports the drop (spec §9.2, the C5 upgrade).
> - Another player's message on the same channel can mask a drop, and an unreadable sender counts as the player's own echo (spec §9.3, C6).
> - In combat a rebuild waits for combat to end: chips keep the lines baked at the last rebuild out of combat (a stale `/p` after leaving a group, spec §18).
> - Disabled in combat, a pad stays on screen, and its chips still send, until combat ends and the held stand-down finishes.
> - Rebuilding between pulls inside a key assumes `SetAttribute` works out of combat in a key (C4, unverified).
> - There are no editors yet: the pad shows the built-in sets; groups-as tabs, layout and look are profile data until the Pads page lands (phase 3).

- [ ] **Step 2: module-map.md, data-flow.md, schema.md, settings-panel.md, scope.md, performance.md, debug.md, slash-dispatch.md, testing.md**

- `docs/module-map.md`, **Load order:** insert the eight new files where the TOC has them, each with its one-line role (as in Step 1). **Tests:** add `test_mock_secure`, `test_send_guard`, `test_sendengine`, `test_preview`, `test_master`, `test_pad_layout`, `test_surfaces`, `test_pad_render`, `test_pad`, one line each naming what it pins.
- `docs/data-flow.md`: add three sections after "Today: `/qc check <id>`":

> ## Today: a callout is pressed
>
> The chip is a secure button armed with one baked line. The game sends the line (the secure path; nothing in Lua sends). The button's `OnClick` hook runs on the acting edge: `SendEngine` classifies the press against the last one (`guarded` inside `behavior.spamGuard`, reported at once), records it for the echo tracker, and dims every chip for the window. A `CHAT_MSG_*` of the same chat type from the player within 1.5 s makes it `sent`; none makes it `dropped`, with one `[QC]` note. `SEND_RESULT` flashes the chip.
>
> ## Today: something changes that a pad draws
>
> `SITUATION_CHANGED`, `LIBRARY_CHANGED`, `PROFILE_CHANGED`, `TEST_MODE_CHANGED` and the settings reactions all call `Surfaces.Request`. Out of combat it rebuilds every enabled pad from the current snapshot (`BuildPlan` → `Pad.Sync`). In combat it files one `surfaces` entry in the combat-end queue, shows the stale hint and sends `SURFACE_REBUILT (id, true)`; at combat end the queue drains, the pads rebuild from the snapshot as it is then, and `COMBAT_QUEUE_DRAINED` clears the hints. `RESTRICTION_CHANGED` re-reads only the padlocks, the lockdown chip and the fade, which change in combat too.
>
> ## Today: test mode
>
> The checkbox, `/qc test` and the launcher entry call `Preview.SetTestMode`. It is refused in combat and stood down, and `RESTRICTION_CHANGED` with the combat edge ends it. `TEST_MODE_CHANGED` makes `Surfaces` draw each pad from `TestPlan`: placeholder chips, disarmed, that send nothing.

- `docs/schema.md`: under `QuickCommsDB.profile`, add `visibility`, `scale`, `alpha`, `locked` with their defaults, and `pads[id].point`; under "Session-only", add `testMode`, `padTab`, `padCollapsed`, `surfacePlans`, `surfaceOrder`, `surfaceStale`, `sendQueue`, `sendEcho`, `lastSendAt`, `pendingTeardown`.
- `docs/settings-panel.md`, **General → Master controls:** list the full framed set in order (Enable, General visibility, Master scale, Master alpha, Lock frame, Debug console, Minimap button, Test mode, then Reset position and Reset all settings), and remove from "Still to come" whatever this phase delivered.
- `docs/scope.md`: rename "What exists at the end of phase 1" to "What exists at the end of phase 2" and add: the send engine (secure buttons, the soft spam guard, the echo tracker, the combat-end queue), the default Comms Pad showing the active built-in sets, test mode, the lock, the saved position.
- `docs/performance.md`, **The buckets:** list `send.click`, `echo.match`, `bake.surface` and `pad.layout`, each with the file that brackets it.
- `docs/debug.md`, **Tags:** add `Send`, `Guard`, `Echo`, `Queue` and `Pad`; **The diagnostics report:** add the `surfaces` and `send` sections.
- `docs/slash-dispatch.md`: add rows:

| Verb | Kind | Live while disabled | Handler |
|---|---|---|---|
| `lock` / `unlock` | reserved (slash-commands-§8) | no (refused while disabled) | `NS.SlashVerbs.SetLocked`, writing `locked` through the seam; the Lock frame row and the launcher's Locked entry write the same path |
| `test` | feature | no (refused while disabled) | `NS.Preview.ToggleTestMode`; refused in combat with one line; the Test mode row and the launcher entry call the same switch |

- `docs/testing.md`, **The harness:** add the nine new suites to the sentence listing the addon's own suites, and add after the `tests/wow_mock.lua` sentence: "Phase 2 adds the secure-frame half: protected calls refused in combat are recorded in `m.blocked`, a click acts on one edge (`m.__click`), `m.sentMacros` records what a secure click sent, and `m.__setCombat` drives the visibility state drivers."

- [ ] **Step 3: smoke-tests.md**

In `docs/smoke-tests.md`, change the index rows `SEND-1..n` and `PAD-1..n` to `SEND-1..5` and `PAD-1..7` (drop "reserved, phase 2"), and add two sections after the existing ones:

```markdown
## Send

**SEND-1. Trash in a key.** In a Mythic+ key, out of combat and then on trash in combat, click
`Pulling` on the default pad → the party sees "Pulling next pack" both times; with `/qc debug on`,
the console shows an `Echo` line ending `sent`. Result:

**SEND-2. A boss in a key.** On a key's boss, click `Lust` once → the party sees the line; the chip
flashes gold. Result:

**SEND-3. The spam guard on a boss.** On a boss, click two chips about half a second apart → every
chip dims for about a second after the first press; the second chip flashes amber. If the game
drops it, the chip flashes red and exactly one `[QC] … may have been dropped by the game` line
prints; if it arrives, no line prints. Never two lines for one press. Result:

**SEND-4. A raid boss (C1).** In a raid (LFR is enough), the pad shows the raid set; on a boss,
click a `/raid` chip → the raid sees it, the chip flashes gold. A lead callout shows `RW` only when
you are leader or assist; otherwise its chip carries a padlock and its tooltip says why. A `/raid`
line that never arrives during the encounter is C1 failing: record it. Result:

**SEND-5. Rebuilt between pulls in a key (C4).** In a key, between pulls, `/qc set
behavior.autoPromote true` → the pad rebuilds with no error and the next click still sends. An
"interface action blocked" error here is C4 failing: record it (the fallback bakes once at key
start). Result:

## Pad

**PAD-1. First run.** On a fresh profile, enter a key → the default pad shows "M+ (generic)" with
eight chips, each tagged `P`; the header reads `M+ · <dungeon> +<level>`. Hovering a chip shows its
name and the exact line it sends. Result:

**PAD-2. The stale hint.** In combat, `/qc set behavior.autoPromote false` → the header shows
"updates after combat"; when combat ends it clears and the pad has rebuilt. Result:

**PAD-3. Lock, drag, position.** `/qc unlock` → a drag strip appears above the pad; drag it
elsewhere; `/reload` → it is where you left it. In combat the strip will not drag. `/qc lock` → the
strip is gone. General → Master controls → Reset position → the pad returns to the center. The
launcher's Locked entry toggles the same lock. Result:

**PAD-4. Test mode.** `/qc test` → placeholder chips and a TEST MODE label; clicking one sends
nothing. Pull something → test mode ends with one line and the real chips return. `/qc test` in
combat → refused with one line. The Master controls checkbox and the launcher entry follow every
change. Result:

**PAD-5. Visibility and fade.** General visibility "Only out of combat" → the pad hides on the pull
with no error and returns after; Master alpha 50% → the pad is half transparent. Result:

**PAD-6. Disabled mid-combat.** `/qc disable` during combat → no "action blocked" error; the pad
stays until combat ends, then hides. `/qc enable` → it returns with live chips. Result:

**PAD-7. A profile switch in combat.** `/qc profile <another>` during combat → the stale hint
shows, no error; after combat the pad is the other profile's. Result:
```

- [ ] **Step 4: test-cases.md and the README**

Run:
```bash
lua tests/run.lua --list > docs/test-cases.md
lua tests/run.lua | tail -3
```
In `README.md`:
- Set the `Tests` badge to the run's passing / total counts (`Tests-<X>%2F<Y>_passing`), matching `docs/test-cases.md`'s Total.
- Replace the paragraph "**Quick Comms is in development.** Version 0.1.0 is the shell for now: …" with: "**Quick Comms is in development.** The Comms Pad works: it shows the built-in callouts for where you are (Mythic+, raid, arena, battlegrounds) and sends them through secure buttons, with a spam guard and a note when the game drops a message. The editors and the Comms Dial come in later builds. The full plan is in the [design spec](docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md)."
- Replace the Usage paragraph "There is not much to use yet. …" with: "Enter a key, a raid, an arena or a battleground and the Comms Pad shows the callouts that fit; click one to send it. `/qc unlock` lets you drag the pad, `/qc lock` fixes it, and `/qc test` shows placeholder chips so you can place it anywhere. `/qc` opens the settings panel; the minimap button's right-click menu has Enabled, Locked and Test mode."

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: PASS, including the kit's `test_prose` (US English in every edited doc) and `test_layout_cap`.

- [ ] **Step 6: Commit**

```bash
git add docs/ README.md
git commit -m "Docs: phase 2 send engine and Comms Pad; smoke checks SEND-1..5 and PAD-1..7; spec rulings"
```

- [ ] **Step 7: The roster row in the standard (sibling repo, local commit only, never pushed)**

The Pad's launcher now has Enabled, Locked and Test mode (Task 6), and launcher-§2 records each addon's entries in `standards/ADDONS.md`. Follow the precedent commit `c1f1cdc` in `../WowAddonStandards` (a roster row plus a patch bump and its ripple). Work in `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards` on its default branch:

1. Read the current version from the first line of `standards/STANDARDS.md` (v2.79.1 when this plan was written; call it `vX.Y.Z` and the next patch `vX.Y.(Z+1)`).
2. In `standards/ADDONS.md`, change the Quick Comms row's last cell from `Enabled` to `Enabled · Locked · Test mode`.
3. Move the current `- **vX.Y.Z (…):**` entry from `standards/STANDARDS.md`'s `## Changelog` to the top of the list in `standards/CHANGELOG.md`, verbatim, and put this entry in its place:
```markdown
- **vX.Y.(Z+1) (2026-10-13):** **Ka0s Quick Comms' launcher row lists Locked and Test mode.** **The finding.** Quick Comms' phase 2 built the Comms Pad, which brings a lock and a test mode, and its `core/LauncherSetup.lua` descriptor now supplies `isLocked`/`toggleLock` and `isTestMode`/`toggleTestMode`, so its menu draws three entries while `ADDONS.md` listed Enabled alone. **The row.** `ADDONS.md`'s Quick Comms row reads `Enabled · Locked · Test mode`, as Aura Master's does. **The counts.** None move: the dated subset counts are not re-measured by a row edit. Version rippled to `CLAUDE.md`, `README.md`, `EXECUTIVE_SUMMARY.md` and `NEW_ADDON_CONTEXT.md`. Patch: no rule changes, a roster cell only.
```
4. Bump the version to `vX.Y.(Z+1)` (date 2026-10-13) in the five places the precedent touched: the title line of `standards/STANDARDS.md`, the title line of `standards/NEW_ADDON_CONTEXT.md`, the "current:" sentence in `standards/EXECUTIVE_SUMMARY.md`, the Status sentence in `README.md`, and the "As of vX.Y.Z the sets are" sentence in `CLAUDE.md`. Find them with `grep -n "vX.Y.Z" CLAUDE.md README.md standards/STANDARDS.md standards/EXECUTIVE_SUMMARY.md standards/NEW_ADDON_CONTEXT.md` and change only those current-version mentions, never a changelog line.
5. Run `bash scripts/check-standard.sh`. Expected: it passes.
6. Commit there, and do not push:
```bash
git add standards/ADDONS.md standards/STANDARDS.md standards/CHANGELOG.md standards/EXECUTIVE_SUMMARY.md standards/NEW_ADDON_CONTEXT.md README.md CLAUDE.md
git commit -m "QC-02: Ka0s Quick Comms' launcher row lists Locked and Test mode"
```

---

### Task 14: In-game smoke test (owner)

The §19 exit criteria for phase 2, run by the owner in the client. An agent never marks a check passed.

**Files:**
- Modify (owner only): `docs/smoke-tests.md` (the `Result:` lines)

**Interfaces:**
- Consumes: the whole phase.
- Produces: the recorded results.

- [ ] **Step 1: Install and load**

Link or copy the repo into `Interface\AddOns\QuickComms` (the existing `symlinks.txt` pattern), `/reload`, and run INSTALL-1 and STATE-1 again: no Lua error, the minimap menu now shows Enabled, Locked and Test mode.

- [ ] **Step 2: The exit criteria (spec §19, row 2)**

| Exit criterion | Smoke checks |
|---|---|
| The default pad shows M+ callouts in a key | PAD-1 |
| It sends on trash and on a boss | SEND-1, SEND-2 |
| A double press inside the guard window is marked guarded (dimmed, noted) and the extra send is reported dropped if the echo doesn't arrive (§19 as amended, controller ruling) | SEND-3 |
| The stale hint appears and clears | PAD-2 |

Run them in one key, then run PAD-3 to PAD-7, SEND-4 and SEND-5, recording each `Result:` line with the date, the client build and pass or fail.

- [ ] **Step 3: Capture what fails**

For any failure: `/qc diagnostics`, copy the console's `surfaces` and `send` sections, and file an issue with the check's ID. A blocked-action error names the frame and the call; attach it as text.

- [ ] **Step 4: Commit the results (owner)**

```bash
git add docs/smoke-tests.md
git commit -m "Smoke: phase 2 results"
```

---

## Self-review

**1. Spec coverage (phase 2):**

| Spec section | Task |
|---|---|
| §4.2/§4.3 files and modules (`SendEngine`, `SendEngine_Guard`, `Surfaces`, `Pad`, `Pad_Layout`, `Pad_Render`, `Preview`) | Tasks 2–11 |
| §9 the only secure writer, the firewall test, D12 one send path | Task 3 |
| §9.1 send buttons, Arm/Disarm, the keyed combat-end queue (Queue, Drain, Drop, Snapshot) | Tasks 2, 3 |
| §9.2 the soft spam guard, `behavior.spamGuard` | Tasks 2, 4, 10 (the dim) |
| §9.3 the echo tracker, secret sender as unknown, drop notes | Tasks 2, 4 |
| §9.5 stand-down, held to combat end | Tasks 3, 11 |
| §10.1 frames, header, chips, padlock, skin, flashes | Tasks 9, 10 |
| §10.2 layout, groups-as, tabs refused in combat | Tasks 7, 10 |
| §10.3 visibility by state driver, master on top, fade, whenActive | Tasks 7, 10 |
| §10.4 test mode, position, Reset position | Tasks 5, 6, 10 |
| §12.2 default pad seeded with the built-ins | already done by `Library.Prepare` (phase 1); exercised by every pad test |
| §13.1 Master controls rows the pad needs; setters that rebuild queue | Task 6 |
| §14 `lock`, `unlock`, `test` | Task 6 |
| §16 launcher Locked / Test mode; diagnostics; perf buckets `send.click`, `echo.match`, `bake.surface`, `pad.layout` | Tasks 4, 6, 8, 10, 12 |
| §17 senders of `ACTIVE_GROUPS_CHANGED`, `SURFACE_REBUILT`, `SEND_RESULT`, `COMBAT_QUEUE_DRAINED`, `TEST_MODE_CHANGED` | Tasks 3, 4, 5, 11 |
| §18 rebuild in combat, refused bake, profile switch in combat, leaving a group mid-combat | Tasks 8, 10, 11 (and Known Limitations) |
| §19 phase 2 exit | Task 14 |

**Not in this plan, on purpose:** §9.4 key bindings and `Bindings.xml` (no pad chip has a key in v0.1.0; the Dial brings them, phase 4), the `situation.refresh`, `resolver.resolve` and `dial.render` buckets and the `tests/perf.lua` scenarios (phase 5), "Preview as…" and the "why" tooltip (phase 3), the per-pad X/Y rows (phase 3).

**2. Placeholders:** none. Task 6's reactions name `NS.Surfaces.Request`, `NS.Pad.ApplyLock` and `NS.Pad.ResetPositions`, which Tasks 10 and 11 define; they are guarded so that Task 6 stays green before those land.

**3. Type consistency:**
- A slot is `{ calloutId, surfaceId, name, icon, line, reason, concrete, chatType, lock, selfText }` in Tasks 8, 9, 10 and 11.
- A plan is `{ surfaceId, snapshot, order, sections, lockdownChip, hasActive, test }` in Tasks 8, 10, 11 and 12.
- Send meta is `{ calloutId, surfaceId, name, chatType, selfText }` in Tasks 3, 4 and 10; `onPress(button, verdict, window)` in Tasks 3, 4 and 10.
- `SEND_RESULT (calloutId, surfaceId, result)`, `SURFACE_REBUILT (surfaceId, stale)`, `TEST_MODE_CHANGED (on)`, `COMBAT_QUEUE_DRAINED (count)` match spec §17.

**4. Review Focus:** each line carries a `[review n]` test: 1 in Task 11 (two cases), 2 in Task 11, 3 in Task 4, 4 in Task 10, 5 in Tasks 8, 9 and 10.

**Controller rulings applied (2026-10-13):**
1. The guard is soft (§9.2 binding). §19's exit row is reworded in Task 13 Step 0; Task 14 checks the reworded criterion.
2. One press can yield two `SEND_RESULT`s (`guarded`, then `sent` or `dropped`): Global Constraints, Task 4's interface, spec §17 (Task 13 Step 0) and ARCHITECTURE's bus table.
3. One array pool per pad: accepted; the spec note is in Task 13 Step 0 (§9.1).
4. Header row plus a DragHandle strip shown when unlocked: accepted; the spec note is in Task 13 Step 0 (§10.1).
5. `ACTIVE_GROUPS_CHANGED` is still sent by Surfaces, with no Pad consumer; Task 11 pins "once per real change" (sent on a change, silent on a same-groups rebuild, sent again on the next change).
6. `Library.SetSurfacePoint` is the only writer of a surface's point (Task 10, with two `test_library` cases and a grep test). The pad's tab and collapsed state are session state in `NS.State`, so they need no registry writer.
7. `locked = true` per §5.1: unchanged.
8. Bindings deferred to phase 4: spec note in Task 13 Step 0.
9. The standard's roster row: Task 13 Step 7, a local patch-level commit in `WowAddonStandards`, never pushed.
10. DragHandle headlessly: Task 9 Step 4b records the planning probe (it runs) and the seam stub to use if it ever does not. A combat edge where `InCombatLockdown()` is already true: Task 5 (test mode still ends, nothing blocked) and Task 11 (the end is queued, placeholders stay disarmed, live chips at combat end).
