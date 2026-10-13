# 04 — Technical design: closing the QC- deviations

Each change is small and local. None needs a library change, a re-vendor or a SavedVariables
migration. TDD applies (testing-§4): each code fix lands with the case that would have gone red.

## QC-01 — the reset confirmation (Medium)

**Files:** `locales/enUS.lua:63-64`, `settings/Schema.lua:333`, a new case in `tests/test_schema.lua`.

The key is the English string (localization-§2), so the fix is a key change. Replace the key **and**
its value with the canonical sentence:

```lua
L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected."] =
    "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected."
```

and point `settings/Schema.lua:333`'s `text` at the new key in the same change. `enUS.lua` is the only
locale, so there is no translation file to miss. Pin it: assert
`StaticPopupDialogs.QUICKCOMMS_RESET_ALL.text` equals the canonical sentence byte for byte, beside the
existing `preferredIndex` case (`tests/test_schema.lua:89`). Red under the current text.

**Risk:** none at runtime. The README's de-AI pass is not involved (no README change).

## QC-02 — combat-gate the page jump (Low)

**Files:** `settings/Editors.lua:435-442`, `tests/test_editors.lua`.

Put the gate inside the open function so every caller is covered (options-ui-§2):

```lua
function Ed.Open(pageKey)
    if NS.Compat.InCombat() then
        NS.Print(L["cannot open settings during combat \226\128\148 Blizzard's category-switch is protected"])
        return false
    end
    ...
end
```

The refusal is the canonical gray notice; reuse the library's string if the Options instance exposes
it, otherwise add the key. `Ed.RequestRefresh()` should move below the gate so a refused jump does not
queue a repaint. Test: with the mock in combat, `Ed.Open("groups")` returns `false`, prints one line,
and `Settings.OpenToCategory` is not called. Red under: delete the gate.

## QC-03 — complete the conformance suite (Low)

**File:** `tests/test_disabled.lua`. No production change is expected; if a step fails, that is a
real finding and its fix belongs in the module the step names.

Build each step on `T.enableAddon()` (the real addon, every module's receivers and frames live)
rather than the probe alone:

1. **Baseline:** capture `R_on` (events **and** messages, by target and name), `T_on`
   (`m.__timers()`), and `F_on` (every pad root and dial header shown, read off `NS.Pad` / `NS.Dial`).
3. Keep the event assertion, and add the message half: every message registration in `R_on` is gone
   (`m.__registrations()` filtered `kind == "message"`). Comment it with `-- red under: drop NS.Bus:StandDown() in NS.StandDown`.
4. Re-assert zero timers after step 6 fires.
5. **New:** every frame in `F_on` reports `IsShown() == false` out of combat.
6. **Rewrite:** fire every event in `R_on` with `__fireUnconditional`, `PLAYER_REGEN_DISABLED` named
   explicitly; assert zero `__svWrites`, zero `m.prints`, zero frame shows. `-- red under: register
   PLAYER_REGEN_DISABLED outside NS.FEATURE_EVENTS`.
7. Iterate `NS.COMMANDS` itself, plus the bare `""`: the live list and `profile` produce their normal
   output; each real feature verb (`lock`, `unlock`, `check`, `test`, `preview`, `why`) prints exactly
   the refusal line and reaches no write seam (spy on `NS.SchemaRuntime.Set`).
8. Left-click opens the panel (spy on `NS.addon.OpenSettings`) with zero writes; right-click shows
   *Locked* and *Test mode* disabled with no handler call.
9. Change a setting while disabled (for example `behavior.*` through the seam) and assert the stand-up
   rebuilds from it.
10. **New:** take `perf`, write `enabled=false`, release `perf` → still stood down; then
   `enabled=true` → up. Repeat in the other order. `-- red under: make NS.StandUp unconditional on release`.

Steps 3, 6 and 10 carry the testing-§12 comment. Regenerate `docs/test-cases.md` and move the README
`[tests]` badge in the same change (testing-§5).

## QC-04 — prove the reset's blast radius (Low)

**File:** `tests/test_schema.lua`. One case: create two callouts, one group and one extra pad through
`NS.Library`; create a second profile; switch back; subscribe a tracked receiver to
`PROFILE_CHANGED`; run `Helpers.RestoreAllDefaults()`. Assert the registry equals a fresh profile's
(the seeded pad and dial only), `db:GetProfiles()` unchanged and the current profile still current,
`state.testMode` false, and the receiver fired once. Ships with QC-01, since both are about the same act.

## QC-05 — a degraded `DebugVerb` that routes (Low)

**File:** `core/DebugLogSetup.lua` (the stub), `tests/test_slash.lua`.

```lua
DebugVerb = function(self, rest)
    local word = (rest or ""):match("^%s*(%S*)"):lower()
    if word == "diagnostics" then self:RunDiagnostics(); return true end
    if word == "on" or word == "off" then self:SetEnabled(word == "on"); return true end
    return false
end,
```

This is host routing, not a copy of the library's formatters, so the no-copy MUST is not engaged.
Test on `T.enableAddon{ skip = NO_LIBKA0S }`: `debug on` sets `NS.State.debug` and prints the ON ack;
`debug diagnostics` prints the library-absent line naming `/qc diagnostics`. The parity suite keeps
checking the member exists.

## QC-06 — the held stand-down through the helper (Low)

**File:** `modules/SendEngine.lua:328-339`.

```lua
if not NS.SafeRegisterEvent(pending, "PLAYER_REGEN_ENABLED", onRegenEnabled, NS.rejectedEvents) then
    -- rejected: fall back to the next out-of-combat RESTRICTION_CHANGED, which Restrictions sends
end
```

`SafeRegisterEvent` accepts an AceEvent-embedded target. Keep the handler a named local so
`releasePending` is unchanged. The fallback branch is unreachable on a real client (the event exists)
and need not be elaborate: the stand-up path already re-evaluates on the next edge.

## QC-07 — catalog marks (Low)

**Files:** `modules/Pad_Render.lua:19,131`, `modules/Dial_Render.lua:23-24,65,175`.

Resolve at draw time, falling back to the current Blizzard texture when the catalog answers `nil`
(library-stack-§8: `nil` is a real answer):

```lua
btn.qcLock:SetTexture(NS.Icon("lock") or LOCK_ICON)
header.qcClose:SetTexture(NS.Icon("close") or CLOSE_ICON)
```

The catalog art is white. Set the tint the current textures imply with `SetVertexColor`. The padlock
and close glyph change on screen, so the change goes into the smoke tests (a PAD and a DIAL check).
`MORE_ICON` and `POINTER_ICON` are candidates (`chevron-right`, an arrow) but not required. Decide
them in the same pass. `DEFAULT_ICON` is a callout's own icon slot, not a mark, and stays.

## QC-08 — doc drift (Low)

**Files:** `docs/compat-layer.md:9-10` and its table, `docs/ARCHITECTURE.md:47` and `:232`.
Re-run `cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'` (27 today) and
write the result into both places. Add table rows for `BindingLabel(action)` (`BINDING_NAME_*`) and
`BindingKey(command)` (`GetBindingKey`). Rewrite the hub sentence: Compat is wired for its two
guards, Item is vendored and not wired. Docs only, no test change.

## QC-09 — guard-arm comment (Low)

**File:** `core/Compat.lua:9-17`. One comment above the two assignments:
`-- Library-absent guard arm: LibKa0s docs/api/Compat/version-1-docs.md, "Degradation" (options-ui-§1).`

## QC-10 — comments (Info)

`QuickComms.toc:48` → `# Conventional: publishes NS.Compat, read inside functions only; resolves
LibKa0s-Compat-1.0 at load (libraries load first).` `QuickComms.toc:54` → say that modules take
`NS.State` at load, pinned by the folder order, and that within `# Core` the position is free.
`core/QuickComms.lua:18-19` → drop "None yet". Read each comment before moving any line
(toc-file-§5).

## QC-11 — `DebugChanged` (Low, SHOULD)

**File:** `modules/SendEngine.lua:293-297`. Replace the memo with
`NS.DebugChanged("bindings", "Bind", "bound %s", sig ~= "" and sig or "nothing")` and delete
`boundSig`. Move the `parts` / `table.concat` build behind the gate if nothing else reads `sig`.

## QC-12 — bucket names (Low, convention)

**Files:** `core/PerfSetup.lua:24-30`, the seven `Perf.Note` sites, the `within`, `tests/test_setup.lua`'s
bucket cases, `docs/performance.md`. Rename `situation.refresh` → `situationRefresh`, `bake.surface` →
`bakeSurface`, `resolver.resolve` → `resolverResolve`, `send.click` → `sendClick`, `pad.layout` →
`padLayout`, `echo.match` → `echoMatch`, `dial.render` → `dialRender`. One change. There are no
captures under `docs/perf-analysis/` to orphan.

## QC-13 — color codec written out (Info, SHOULD)

**File:** `settings/OptionsSetup.lua`. Pass `colorDecode = function(c) return c end` and
`colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end` with a comment naming
the stored shape. Match the library's codec signature, or skip this if it is not a pure identity.

## QC-14 — the release run (Info)

At the 0.1.0 release (automated-tests-§6, performance-§10): run the full four-suite bundle on a clean
tree, write its `ANALYSIS.md`, and give `modules/Library.lua` (1017 lines) a band disposition in
`RESULTS.md`. The band is where it sits, so the honest choices are "accepted: the registry writer
plus `Import`" or "peel next: `Import` to `modules/Library_Import.lua`". Not a pre-release change.

## QC-15 — `.pkgmeta` line (Info)

Comment out `  - .playwright-mcp` in the template's conditional shape, or delete it. It costs
nothing at package time either way.

## Ordering constraints

- QC-01 and QC-04 go together: both are about the reset, and QC-04's case is the place to also pin
  the QC-01 text.
- QC-03 comes after QC-06 and QC-07: its step 6 (no frame shows) and step 3 (registration set) then pin
  the final shapes.
- QC-12 renames before any in-game capture exists, so no record in `docs/perf-analysis/` names an old
  key.
- QC-14 is the last item and happens at release.
