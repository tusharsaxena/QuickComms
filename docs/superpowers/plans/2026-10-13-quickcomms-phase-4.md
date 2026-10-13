# Ka0s Quick Comms: phase 4 implementation plan (the Comms Dial)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Comms Dial in Relaxed mode: a key opens a ping-wheel dial, a click on a wedge sends its callout through a secure button (in a boss too), a group wedge opens that group's ring (the Categories two-stroke), a battleground node set opens straight on its nodes (Arathi Basin's "INC 3 Lumber Mill" in two clicks), and the player sets it all up on a Comms Dial page, with the key also offered in WoW's key bindings menu.

**Architecture:**
- **The secure structure is one header per dial, and its snippets run the dial in combat** (spec §11.2, Relaxed only: the C7 fallback in `docs/brainstorm/go-no-go/round-4-build-checks.md`). The header is a `SecureHandlerClickTemplate` button named `QuickCommsDial<n>` (`n` is the dial's place in the dial order), and it is the hub. Each ring is an explicitly protected container (`SecureFrameTemplate`) under it, and each wedge *is* its slot's pooled send button (`QuickCommsSend<n>`), armed out of combat with the baked line. The header's restricted snippets open the dial (the key, `Toggle`), show one ring at a time, bind Escape, the number keys and the mouse wheel to the open ring with `SetBindingClick`, go up a ring from the hub, and close it after a send (test mode and Preview as… open it through `qc-display`, which binds no key); a wrap on each wedge's click turns a group wedge into a ring switch and a right click into a close. The ring on screen lives in the header's own restricted environment, so no snippet writes an attribute; every attribute, frame ref, wrap, snippet run and override binding is written out of combat by `modules/SendEngine.lua`, still the only secure writer.
- **Pure layout, insecure paint, one rebuild path.** `modules/Dial_Layout.lua` (pure) turns a dial plan's groups into rings (Categories, Flat, open-into, pages behind a More wedge) and wedge geometry. `modules/Dial_Render.lua` dresses the secure frames with insecure regions, as `Pad_Render` dresses chips: the disc, spokes, icons, labels outside the disc, padlocks, a gold hover glow, the guard's dim and the result flash, the ✕ hub with its stale hint and lockdown chip, and a pointer whose `OnUpdate` exists only while the dial is open. `modules/Dial.lua` owns the frames and hears `SEND_RESULT` as `Pad` does. `modules/Surfaces.lua` builds a plan for every enabled dial beside the pads' and hands both to the one rebuild (`Surfaces.Request` → `SendEngine.RunOrQueue`), which also re-binds every dial's key; the stand-down's held teardown clears them.
- **Settings as in phase 3.** A dial's fields are member rows (`dial.name|enabled|mode|slices|openAt|point|key`) written through the one seam; Library stays the registry writer (membership, order, the battleground-order migration). The Comms Dial page is a phase-3 editor page (banner picker, New dial, tabs General, Groups, Wheel, Binding, Preview), mirroring the Comms Pad page as the phase-3 fix wave left it. If the owner accepts it (R1), `Bindings.xml` offers "Open Comms Dial 1–4", each a `CLICK QuickCommsDial<n>:Toggle` binding.

**Tech stack:**
- Lua 5.1, against the WoW Retail 12.1 client (Interface `120100`)
- Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, including AceGUI's `Keybinding` widget)
- LibKa0s v1.71.0 (Options `PageBanner`, `RenderTabbedSchema`, `RenderRows`, `RenderGrid`, `TextRow`, `Section`, `InlineButtonPair`, `RestoreDefaults`; Widgets `ReorderList`; Pool; Perf; Schema)
- the client's secure handlers: `SecureHandlerClickTemplate`, `SecureFrameTemplate`, `SecureActionButtonTemplate`, `SecureHandlerWrapScript` (the header's `WrapScript`), `SetFrameRef`, `Execute`, restricted `RunAttribute`, `SetBindingClick`, `ClearBindings`, `SetPoint(..., "$cursor")`; `SetOverrideBindingClick` / `ClearOverrideBindings`; `Bindings.xml` `CLICK` bindings
- the LibKa0s headless test kit (`tests/_kit/`), extended in `tests/wow_mock.lua` (Task 1) with secure handlers, restricted snippets and key bindings
- luacheck, and the bounded runner `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded` for both gate commands

**Spec:** [`docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`](../specs/2026-10-11-quickcomms-v1-design.md) (amended through phase 3). Read §9 (§9.1, §9.2, §9.3, §9.4, §9.5), §10.4, §11, §12, §13.1 (the Comms Dial row), §14, §16, §17, §18 and §20 beside this plan; section numbers (§n) refer to it. The round-4 record, `docs/brainstorm/go-no-go/round-4-build-checks.md`, says what Relaxed means here: C7 was skipped, so the hold, flick and release dial (restricted `GetMousePosition`, the draw delay, the tap action) is not built. The Ka0s WoW Addon Standard is at `../WowAddonStandards/standards/` (v2.79.x); section names below (options-ui-§14, architecture-§5) refer to it.

**Scope note:** this plan covers **phase 4 only** (§19 row 4). Out of scope:
- Quick mode (hold, flick, release), the draw delay and the tap action (the C7 upgrade, which the round-4 record names)
- Share's Export and Import tabs, `LibSerialize` / `LibDeflate` (phase 5)
- `tests/perf.lua`'s scenarios, including the dial open and close (phase 5); this phase only declares and brackets the `dial.render` bucket
- confirming the battleground instance ids (phase 5)
- the audit, the automated-test bundle and the release (phase 5)

Depth is **not** part of the C7 upgrade. Spec §11.3's limit (depth 2; depth 3, a node set reached under Categories when open-into does not apply, allowed with the editor warning) is built here: `Dial_Layout.DeepGroups` (Task 3) finds such a set and the Comms Dial page's Groups tab warns (Task 9). Whether the Wheel tab also carries a depth control is owner ruling R5.

**Precedents copied, by file and symbol:**

| What | Copied from |
|---|---|
| A secure header whose restricted snippets grab Escape, the number keys and the wheel while a ring is open | OPie's published approach, as research note 01 records it (`docs/brainstorm/01-research-platform.md`, "Inside a `SecureHandler` snippet, frame handles can call `SetBindingClick` … OPie uses this to grab the mouse buttons and wheel while a ring is open") |
| A pooled secure send button armed out of combat, a keyed combat-end queue, a held stand-down | this addon's `modules/SendEngine.lua` (phase 2) |
| A send button's insecure dress, tooltip lines, lock texts, the guard's dim and the result flash | this addon's `modules/Pad_Render.lua` (`TooltipLines`, `LOCK_TEXT`, `ShowLines`, `Flash`, `SetCooling`) and `modules/Pad.lua` (`Pad.Cooldown`, `onSendResult`, the receiver's stand-down and stand-up) |
| An editor page for one of many surfaces: picker, New with a free number, Groups as a reorder list, X/Y offsets that put the box back on a refusal, Delete, Defaults as one act | this addon's `settings/Pads.lua` as the phase-3 fix wave left it (`PD.NewName`, `PD.SetOffset`, `offsetBox`, the `Library.Batch` around `RestoreDefaults`) |
| A position row with a default that only a named reset reaches | the `pad.point` row in `settings/SchemaMembers.lua` (`default = false`) and `resetExempt` in `settings/Schema.lua` (phase-3 fix wave) |
| `SetOverrideBindingClick` on a named secure button | the go/no-go harness, `docs/brainstorm/go-no-go/harness/QCTest.lua` (`SetOverrideBindingClick(panel, true, arg:upper(), "QCTestA")`) |
| A key capture box | AceGUI-3.0's `Keybinding` widget (`libs/AceGUI-3.0/widgets/AceGUIWidget-Keybinding.lua`: `OnKeyChanged`, Escape answers `""`) |

## Global Constraints

These apply to every task.

**Carried from phases 0–3** (phase 3's blocks, word for word, including their own phase-3 marks; phase 4's amendments are marked *(Phase 4:)* and add to the line they follow, except the Git line's, which supersedes phase 3's branch):
- Interface `120100`. Lua 5.1 syntax only: no `goto`, no integer division, no `//`.
- LibKa0s **v1.71.0** as vendored; never edit `libs/` or `tests/_kit/`.
- Title `Ka0s Quick Comms`; folder `QuickComms`; saved variables exactly `QuickCommsDB` and `QuickCommsPerfDB`; chat tag `|cff00ffff[QC]|r`; slash `/qc`, alias `/quickcomms`; bus names `Ka0s_QuickComms_<PascalCaseEvent>` declared once in `core/Bus.lua` (all nine already exist). *(Phase 4:)* this phase adds none.
- Every authored `.lua` opens with `local addonName, NS = ...` (or `local _, NS = ...`), with a comment naming the file's path and purpose directly beneath it.
- No new globals except the named frames the client requires (`QuickCommsSend<n>`, `QuickCommsPad<id>`, and from this phase the editor pages' canvases `QuickComms<Callouts|Groups|Pads|Share>Panel` and the `QUICKCOMMS_DELETE_MEMBER` entry in `StaticPopupDialogs`), no `print()` (use `NS.Print` / `NS.Debug`), no `_G[addonName]`. *(Phase 4:)* also the dial headers `QuickCommsDial<n>`, the canvas `QuickCommsDialsPanel`, and, if the owner accepts `Bindings.xml` (ruling R1), the key bindings menu's labels the client reads by name: `BINDING_HEADER_QUICKCOMMS`, declared in `.luacheckrc` `globals` beside the comment that justifies it (lint), and the four `BINDING_NAME_CLICK QuickCommsDial<n>:Toggle` entries, which are not Lua identifiers (the space and the colon), so they are written with `rawset(_G, …)` beside a comment saying so.
- Modules publish idempotently (`NS.X = NS.X or {}`) and never call another module's table at file load, except a load-time upvalue the TOC marks `# LOAD-BEARING:`. *(Phase 4:)* the mark sits on the publisher's line and names the taker (as `modules\SendEngine_Guard.lua`'s does).
- Match game data by ID or token, never by a localized name.
- US English in all code, comments and strings. Every user-facing string goes through `NS.L["English text"]`; each task adds its new keys to `locales/enUS.lua` (a key that file already defines is not added twice). *(Phase 4:)* the kit's prose gate rejects British spellings in code, strings and every doc it scans: "canceled", never the double-l form.
- **Secret values:** anything read from the client goes through `NS.Compat` and becomes a plain value or nil. Never compare, concatenate or format a value that might be secret. The echo tracker never reads chat text.
- **Commit gate:** before every commit, `lua tests/run.lua` exits 0 **and** `luacheck .` reports 0 warnings and 0 errors. *(Phase 4:)* run both through the bounded runner: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`.
- **Suite and TOC bookkeeping:** every new `tests/test_*.lua` joins the `suites` list in `tests/run.lua`. Every new `.lua` file is listed in `QuickComms.toc`, with its `# LOAD-BEARING:` or `# Conventional:` comment on **its own line directly above** the entry (a trailing comment breaks the file name). *(Phase 4:)* `Bindings.xml` is **not** a TOC line: the client loads it from the addon's root by name.
- **Line endings:** CRLF (`.gitattributes` is `* text=auto eol=crlf`); let git normalize, never hand-write LF-only files into the index. *(Amended for phase 3:* after `git add`, refresh the working tree from the index so the files on disk carry CRLF: `git add <files> && git checkout -- <files>`; the checkout rewrites only the paths just added.) *(Phase 4:)* the kit's `test_eol` reads the working-tree bytes of every tracked file, and the gate runs before the commit step's add-and-checkout, so a tracked file rewritten with bare LF fails the gate (`declared crlf, but N of N terminators are bare LF`). Edit a tracked file in place (an in-place edit keeps its CRLF); when a tool rewrote a tracked file whole (a whole-file write, a scripted rewrite), run `git add <files> && git checkout -- <files>` for it before the gate. A new, untracked file is not read until it is added.
- **Git:** ~~commit on `main` only after the gate passes. Do not push unless the owner asks.~~ *(Amended for phase 3:* commit on the current branch, `feat/phase-3-editors`, after the gate passes. Never commit to `main`, never merge, never bump the version. A task's executor never pushes; the controller pushes the branch to `origin` at each milestone checkpoint (the owner's run instructions), and merging waits for the owner's word.) *(Amended for phase 4, superseding phase 3's branch and push lines:)* commit on the current branch, `feat/phase-4-dial`, in this worktree (`/mnt/d/Profile/Users/Tushar/Documents/GIT/QuickComms-p4`), after the gate passes (the repo owner authorized commits on this branch). Never switch branches, never commit to `main`, never merge, never push, never bump the version. The branch is rebased onto the phase-3 branch's final head before Task 1 (Pre-flight P1), and each task names the phase-3 symbols it consumes.

**Refinements phase 3 added to that block** (word for word):
- Game data is matched by ID or token, never by a localized name (localization-§4). A display name read from the client (an instance, a class, a specialization) is for display only.
- Each task adds its locale keys under a comment naming the file; each task's key list below was checked against `locales/enUS.lua` as it stood when this plan was written. If an earlier task already added one, skip it.
- `tests/page_helpers.lua` is a helper, not a suite (no `test_` prefix), and is not listed in `tests/run.lua`.

**Carried from phase 2** (phase 3's block, word for word; this phase adds secure frames, so read each line as covering the dial too, as the *(Phase 4:)* marks say):
- **One secure writer (§9).** Only `modules/SendEngine.lua` calls `SetAttribute`, `RegisterStateDriver` / `UnregisterStateDriver`, `SetOverrideBinding*` / `ClearOverrideBindings`, or names a `Secure*` template. Its grep test (phase 2, Task 3) stays green. *(Phase 4:)* it is also the only file that names `SecureHandler` or calls a header's `SetFrameRef`, `WrapScript` or `Execute`; the grep test's `FORBIDDEN` list (`tests/test_sendengine.lua`) gains `:SetFrameRef%s*%(`, `:WrapScript%s*%(` and `:Execute%s*%(` (Task 2). `modules/Dial_Secure.lua` holds the snippet **text** and hands it to SendEngine; no snippet writes an attribute (Task 4's own check).
- **Never a protected write in combat** (events-frames-taint-§2). The guard is `NS.Compat.InCombat()` (`InCombatLockdown()`), never `UnitAffectingCombat`. Protected-frame `Show` / `Hide` / `SetPoint` / `SetSize` / `SetScale` and every attribute or driver write run inside `SendEngine.RunOrQueue` or a function only it calls. In combat the work is queued and the surface shows its stale hint. *(Phase 4:)* so does every frame ref, wrap, snippet run and override binding write. The header's restricted snippets are the client's own exception: they show, hide, anchor and bind in combat, and nothing else does.
- **One send path (D12).** No `SendChatMessage` / `C_ChatInfo.SendChatMessage` anywhere in shipped code; a callout reaches chat only as a secure button's `macrotext`.
- **The soft spam guard (§9.2)** and **the echo tracker (§9.3)** are unchanged; one press can yield two `SEND_RESULT`s (`guarded`, then `sent` or `dropped`). A previewed or placeholder chip yields none. *(Phase 4:)* nor does a previewed, placeholder or ring-switch wedge, and a right click on a wedge is no press. The guard window dims every wedge on every dial as well as every chip, and a result flashes its wedge, a drop for long enough to show on the next open (Task 6).
- **Never rely on `InCombatLockdown()` being false inside a `PLAYER_REGEN_DISABLED` handler.** Work started from the combat edge (test mode's or the preview's end, a rebuild) goes through `SendEngine.RunOrQueue`, which queues when lockdown has already begun. Tests drive both orders. *(Phase 4:)* including the dial that test mode and Preview as… open (Task 7, `[review 6]`).
- **The registry writer, as amended for phase 3** (architecture-§5, spec §5). Phase 2's "`modules/Library.lua` is the only writer of `profile.pads` / `profile.dials`; the pad writes its anchor only through `Library.SetSurfacePoint`" becomes: **membership, order, ids, references and seeding** of every registry collection are written only by `modules/Library.lua`; **a member's own fields** are written only through the seam (`NS.SchemaRuntime.Set`, the member rows of Task 3a). The pad still writes its anchor only by asking `Library.SetSurfacePoint`, which hands it to the seam's `pad.point` row. The `[registry]` grep test in `tests/test_pad.lua` still pins that no file but Library assigns `.point`. The active tab and the collapsed state stay session state in `NS.State`. *(Phase 4:)* the dial's anchor likewise goes only through `Library.SetSurfacePoint`, to the seam's `dial.point` row (Task 5a). The schema migration that reorders surface lists (Task 5b) calls a Library function; `core/Database.lua` never edits a list itself.
- **No second `PLAYER_REGEN_*` feature row.** `Restrictions` owns both; AceEvent keys handlers by (event, object). Combat edges are consumed through `RESTRICTION_CHANGED` plus `NS.Restrictions.InCombat()`. The single exception is SendEngine's private pending-teardown target (slash-commands-§7).
- **Frames are never destroyed.** Chips are pooled per pad with `NS.Pool`; a deleted pad's frame is released to its pool, never destroyed. The pad's look comes from `NS.ApplySkin`; no host copy of the skin. *(Phase 4:)* wedges are pooled per ring container and ring containers per dial; a released dial's header is closed, emptied and kept for reuse.
- **Perf (performance-§2/§3).** Shape A brackets with the load-time `local Perf = NS.Perf`. This phase adds no bucket; a bucket added later is declared in `core/PerfSetup.lua` in the same task as its bracket. *(Phase 4:)* phase 4 adds one, `dial.render`, declared and bracketed in Task 6.
- **Disabled is total (slash-commands-§7).** Stood down, every pad is hidden and every chip disarmed (held to `PLAYER_REGEN_ENABLED` if in combat), every timer canceled, every event and message unregistered. Every new bus receiver is torn down and replayed by the stand-down and stand-up; every new timer is canceled by the stand-down. *(Phase 4:)* every dial too: released, its wedges disarmed and every override binding cleared (held the same way), its `SEND_RESULT` receiver and its flash and dim timers handled as the pad's, and no `OnUpdate` left set (the pointer has one only while a dial is open).
- **Test mode** is session-only (`NS.State.testMode`), refused in combat, ended at the start of combat, ended by Reset all settings, and renders placeholder chips that send nothing. From this phase "Preview as…" is its second flavor (`NS.State.previewAs`), with the same rules. *(Phase 4:)* both also open dial 1, without taking any key: Escape stays the settings window's and 1–8 stay the action bar's (Task 4's `qc-display`).

**From the spec (phase 3)** (word for word; it binds the Comms Dial page, Task 9, as it bound the Comms Pad page):
- **The panel refuses to open in combat, and the library locks any page shown in combat** (§13.1). No page adds a combat guard of its own (options-ui-§2, §13). A popup accepted after combat started may still write data: data writes are allowed in combat, and the pads pick them up at combat end.
- **Setters that rebuild secure frames gate on `InCombatLockdown()` and queue through SendEngine** (§13.1): every member write reaches the pads only through `LIBRARY_CHANGED` → `Surfaces.Request`, which is `SendEngine.RunOrQueue` with the stale hint. Protected calls only via `SendEngine.RunOrQueue`; no page touches a pad frame.
- **Member fields go through the seam** (architecture-§5: "a member field a row addresses goes through the helper even when the registry writer is the caller"; the registry-writer constraint above, as amended). Panel code and slash handlers call Library or the seam; they never append to, splice or `table.remove` a stored collection, and never assign a member field directly.
- **Built-ins are read-only** (§12.2): every group row refuses to write a built-in id with a reason; the overlay rows (`builtin.enabled`, `builtin.hidden`) are the only writable part of a built-in, and Customize is the way to edit one.
- **Every page has a tab strip, and every row has a `group`** (§13.1, options-ui-§13). The band above the strip carries the picker and the create action only (options-ui-§14); a page's acts live on its first tab, named `General`.
- **"Preview as…" and test mode are session-only** (`NS.State`), never saved; both are refused in combat and while stood down, ended at the start of combat, ended by the stand-down; a previewed or placeholder chip sends nothing and prints nothing.
- **A re-rendering refresh only when the layout changes** (options-ui-§11): an editor page is torn down and redrawn only when what it draws changes shape (membership, order, the selection, a name, a group's When or Enabled, Customize, a profile switch, the preview switch, a change in the set of active groups). A scalar member write refreshes in place.

**From the spec (phase 4), verbatim** (quotes only; this plan's readings of them follow in the next block):
- §9: "This module is the protected-API firewall (events-frames-taint-§4). It is the only code that: calls `SetAttribute` on secure frames; calls `SetOverrideBinding*` / `ClearOverrideBindings`; calls `RegisterStateDriver` / `UnregisterStateDriver`; creates secure frames." / "`Dial_Secure` writes its snippet text and attributes through SendEngine's API."
- §9.1: "**Dials:** each dial owns a set of hidden send buttons, one per slot, which its secure header clicks (§11)."
- §9.2: "starts the visual cooldown (the chip and wedge dim for the guard window), which discourages a second press"
- §9.3: "A click with no matching event of that `chatType` within 1.5 s counts as **dropped**: the wedge or chip flashes red and, if `dropNotes` is on, one `[QC]` line is printed."
- §9.4: "Dial keys are bound with `SetOverrideBindingClick(owner, true, key, "QuickCommsDial<n>")` out of combat. They are stored in the dial's `key` field, **not** in WoW's own key bindings." / "Bindings are re-applied at login, on a profile switch, and on stand-up." / "They are cleared on stand-down, deferred if in combat (slash-commands-§7)." / "A key conflict with an existing WoW binding shows a warning in the dial editor and still binds: an override binding wins only while QuickComms is enabled." / "**`Bindings.xml`:** v0.1.0 also ships one, with `BINDING_HEADER_QUICKCOMMS` and "Open Comms Dial 1–4"."
- §11.2: "**Relaxed mode (the v0.1.0 design, owner 2026-10-13).** Pressing the dial's key toggles the dial open and pressing it again closes it. While it is open, the wedges are real secure buttons (each one is that slot's send button, armed with the baked line) and the player clicks one to send; the dial then closes. Escape, a right click or a click in the hub also closes it, and the hub's ✕ goes up a ring when there is one. The insecure render only draws and hides; the secure header holds the ring state."
- §11.3: "Slices per ring: 4 (the default), 6 or 8. 12 is allowed only on a ring with no children." / "Depth is 2. Depth 3 (a battleground node set under Categories when open-into is off) is allowed, with the editor warning." / "**Open-into** (D9) is a flag per group. It is on for the battleground node sets. When the first active group in the dial's order has the flag, the dial opens on that group's ring, and the hub's ✕ goes up to the group ring instead of cancelling."
- §11.4: "**Test mode** shows dial 1 open with placeholder wedges, at the configured position. **The dial editor's Preview tab** renders the dial inside the panel. It is insecure and display only." / "**Stale and lockdown:** the hub shows the same stale hint and lockdown chip as a pad."
- §10.4: "Reset position is in Master controls, and resets every pad and dial anchor."
- §13.1: "The panel refuses to open in combat, and the library locks any page shown in combat." / "Setters that rebuild secure frames gate on `InCombatLockdown()` and queue through SendEngine."
- §18: "Two dials bound to the same key | The editor refuses, naming the other dial" / "A key conflicts with a WoW binding | A warning. The override wins while the addon is enabled."

**How this plan reads those quotes** (rulings within the spec's text; the ones that depart from it are in **Owner rulings needed**):
- §9.1: each wedge *is* its slot's send button (as §11.2 says), parented to its ring's protected container; the header does not click it, the player does. Task 11 records the reading under §9.1.
- §9.2 and §9.3: the dial closes on a send, so the dim and the flash show on the next open: the guard's dim lasts its window, and a drop's red flash lasts `Dial.DROP_SECONDS` (5 s), long enough to reopen the dial and see which line was lost. Task 6 builds both.
- §11.3, open-into: the hub on the open-into ring goes up to the group ring (rather than closing the dial, which "cancelling" means in Relaxed mode).
- §11.3, depth: "depth" counts rings from the one the dial opens on. Groups, then callouts, is depth 2; a node set's callouts under the group ring are depth 3, and the Groups tab warns (Task 9). Open-into skips the group ring, so a node set that opens into itself is depth 2.
- §11.4, test mode: dial 1 opens without capturing Escape, the number keys or the wheel (the settings window may be open; Task 4's `qc-display`).
- §9.4 and §18: Escape, the left and right mouse buttons and the mouse wheel cannot be a dial's key, nor 1–8 without a modifier, because the open dial captures them (Task 5a; Task 11 records it under §9.4).

## Review Focus

These are the inputs most likely to hurt a real player that no feature test would naturally cover. Each one has a pinning test, tagged `[review n]`, in the task named in brackets.

1. **The dial's key pressed where nothing can show** (solo in the open world with no always-on group, or after `/qc disable`): nothing opens, no Lua error, no blocked call; while disabled the key is the game's own again, and after `/qc enable` it opens the dial again. [Task 7]
2. **A right click, Escape, the key again or a hub click on an open dial**: the dial closes or goes up a ring and sends nothing; a right click on a callout wedge is not tracked as a press (no guard stamp, no echo awaited, no drop note). [Task 4]
3. **Editing a dial (its key, its wedges per ring, its groups), switching profiles or disabling the addon during combat**: the write lands, no protected call is attempted, the old key keeps opening the old dial and the hub shows "updates after combat", and at combat end the dial is rebuilt with the new key bound (the old one released) or, if disabled, hidden with its key released. [Task 7]
4. **Two dials on one key, a reserved key, a key WoW already uses**: another dial's key, Escape, the left or right mouse button, the mouse wheel and an unmodified 1–8 (the open dial uses them) are refused with the reason (naming the other dial) and nothing is stored; a key WoW already uses is stored, bound, and warned about on the Binding tab. [Tasks 5a and 9]
5. **More callouts than wedges on a ring** (a node's six callouts on a four-wedge dial, a Flat dial with thirty): the extra go on pages behind a More wedge, More and the wheel reach every one, and the number keys pick on the page shown. [Tasks 3 and 4]
6. **Test mode or Preview as… with the settings window open, then a combat that begins before the end's rebuild runs**: the opened dial takes no key (Escape still closes the settings window, 1–8 stay the action bar's), nothing is blocked, and at combat end the dial is closed with no restricted binding left. [Tasks 4 and 7]

## Milestones

Each milestone ends green and is a resume point: the plan's checkboxes and `git log` say where the work stands.

- **Pre-flight (P1, P2, below).** The rebase onto the phase-3 branch's final head, and the owner's rulings R1–R5. No task starts before both are done.
- **Milestone 1: the secure dial, headless (Tasks 1–4).** The mock learns secure handlers, restricted snippets and key bindings; SendEngine gains the dial's secure frames and the override bindings; the pure ring layout; the Relaxed-mode snippets. A hand-built dial opens, switches rings, sends and closes in and out of combat in the suite; nothing is wired into the addon's surfaces yet. Checkpoint: both gate commands green; commits on `feat/phase-4-dial`.
- **Milestone 2: the dial in the addon (Tasks 5a, 5b, 6–10).** The dial's member rows and keys, the battleground order and its migration, the frames and the hub, the rebuild path and the key bindings, `Bindings.xml` (as ruled), the Comms Dial page, diagnostics and `/qc why`. The three exit paths run headlessly (Task 7). Checkpoint: green; every new suite drives its module through the mock.
- **Milestone 3: docs and the owner's smoke test (Tasks 11–12).** The spec's notes (as ruled), ARCHITECTURE and the maps, the new smoke checks DIAL-1..10, then the owner's in-game run. The plan ends with Task 12; merging and pushing are the owner's call.

## Pre-flight (before Task 1)

- [ ] **P1. Rebase, then re-read what this plan mirrors.** This plan was checked against `feat/phase-3-editors` at `818603e` (every "replace" anchor in it matches that head). With the owner's go-ahead, rebase this branch onto the phase-3 branch's final head (`git rebase feat/phase-3-editors`), run the gate, then list what moved since: `git diff 818603e feat/phase-3-editors -- settings/Pads.lua settings/SchemaMembers.lua settings/Schema.lua settings/Slash.lua modules/Library.lua modules/Pad.lua modules/Surfaces.lua tests/`. Tasks 5a, 6 and 9 mirror `settings/Pads.lua` (`PD.NewName`, `PD.SetOffset`, `offsetBox`, the `Library.Batch` around `RestoreDefaults`), the `pad.point` row (`default = false`, `resetExempt`) and `Lib.ValidPoint` / `Lib.MIN_SURFACE_SCALE`. If any of them moved again, re-read it and mirror the new shape in the task before running that task. An empty diff needs nothing.
- [ ] **P2. The owner's rulings.** Ask the owner for R1–R5 below and record each answer here (accepted, or the alternative). An agent's say-so is never a ruling. R1 decides Task 8 and two strings in Tasks 9 and 11; R2–R5 decide what Task 11 writes into the spec and, where the alternative is taken, the task changes the table names.

## Owner rulings needed

Five places where this plan would depart from binding text (the standard for R1, the spec for R2–R5). Each needs the owner's word before Task 1; the plan builds the recommended column and names the change the alternative makes.

| # | Ruling | Binding text | Recommended (what the tasks build) | The alternative, and what it changes |
|---|---|---|---|---|
| R1 | `Bindings.xml` at the addon root | layout-§1 (see **Standard deviations to raise**) | Ship it (Task 8), recorded as an accepted deviation or with the standard changed upstream | Not shipped: skip Task 8; Task 9's `DD.KeyLine` uses its short no-key line and drops the last Binding-tab row (both strings are given in Task 9); Task 11 records §9.4's file as not shipped and DIAL-6 loses its first sentence |
| R2 | One active group opens straight on its ring | §11.3: "Choosing a group takes a second click in v0.1.0." | With a single active group, Categories opens on that group's ring (a one-wedge first ring costs a click for nothing); the hub still goes up to it | Always open on the group ring: drop `or #entries == 1` from the last line of `DL.Rings` (Task 3); in Task 3's case "without the flag first…" the single group opens on ring 1; Task 6's first case and Task 7's raid exit click the group wedge before the callout; Task 10's dials line reads `openRing=1`; DIAL-2 reads "click the group, then a callout" |
| R3 | The Preview tab is a listing | §11.4: "The dial editor's Preview tab renders the dial inside the panel." | Each ring, wedge by wedge, with its compass word and the ring it opens on (Task 9); the drawn dial is the in-game preview (test mode, Preview as…) | A drawn preview: a Task 9b adds an insecure dial on a plain frame inside the Preview tab, dressed by `Dial_Render`'s `DressRing`, `DressWedge` and `PaintWedge` (plain buttons, no secure frame, no key), a group wedge stepping into its ring |
| R4 | Node sets are not pinned to compass directions yet | §12.1: "Nodes are pinned to compass directions, with `openInto = true`." (§11.1: "may pin") | Placed clockwise from N in their shipped order; the pins move to phase 5 with the battleground id confirmation (§19 row 5). Lumber Mill stays the second wedge, so the exit stays two clicks | Pins now: Task 5b adds a `compass` word to each node child in `defaults/BuiltIns_Battlegrounds.lua`, and Task 3 places a node ring's items on their winds (such a ring takes 8 wedges); DIAL-4's wedge positions change, its clicks do not |
| R5 | No depth control on the Wheel tab | §13.1: "**Wheel** (slices, depth, open at, delay)" | Depth is §11.3's limit, not a setting: depth 2 by construction, depth 3 allowed with the Groups tab's warning (Tasks 3 and 9); the stored `depth` field stays inert | The owner names what a depth setting changes, and a task is added for it; nothing here assumes one |

## Standard deviations to raise

One, ruling R1 above. The owner decides it in pre-flight (P2); this plan does not ratify it on its own.

| Rule | What differs | Why |
|---|---|---|
| layout-§1: "source lives under `core/`, `defaults/`, `settings/`, `locales/`, `modules/`; never loose at the root" | `Bindings.xml` sits at the addon's root, beside the TOC, and is not a TOC line. | The client reads key bindings only from a file named `Bindings.xml` in the addon's root folder; a file under `settings/` (or a TOC line) is never read as bindings. Spec §9.4 and P7 require one. It carries no Lua: the menu's labels are set from `modules/Dial.lua`. |

Two ways to settle it, as CLAUDE.md asks: **(1) an accepted deviation**, recorded by Task 11 as a row in `docs/ARCHITECTURE.md` → `## Documented deviations` (`| layout-§1 | Bindings.xml at the addon root | the client loads key bindings only from the root | 2026-10-13 | the client loading bindings from a TOC-listed path |`); or **(2) a change to the standard**: layout-§1 names `Bindings.xml` as a client-mandated root file (like the TOC), upstream in WowAddonStandards, after which Task 11 cites the new rule and the register stays "None." If the owner declines both, Task 8 is skipped and the alternative column of R1 applies; the dial's own key (Task 7) is unaffected.

No other deviation: the restricted snippets, the override bindings and the binding labels are where the standard is silent (spec §3, "Where the standard is silent"); they are recorded in `docs/ARCHITECTURE.md → Taint Notes` (Task 11) and proposed upstream after v0.1.0, as spec §3 already says. lint's rule on globals ("MUST NOT add globals (write access) without a comment justifying it") is met as written: `BINDING_HEADER_QUICKCOMMS` is declared in `.luacheckrc` `globals` beside its reason (Task 8), and only the four `BINDING_NAME_CLICK …` labels, which are not identifiers and so cannot be declared there, are written with `rawset(_G, …)` beside a comment saying why.

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `tests/wow_mock.lua` | modify | Task 1: secure handler headers (`_onclick`, `Execute`, `WrapScript`, `SetFrameRef`), restricted snippets in a per-header environment with protected calls allowed, the restricted handle methods, header `OnShow`/`OnHide`, override bindings, `GetBindingAction`, `GetCursorPosition`, `__pressKey`, `__named`, `GetCenter`. |
| `modules/SendEngine.lua` | modify | Task 2: `NewDialHeader`, `NewDialRing`, a wrapped `NewButton`, `SetAttributes`, `SetFrameRef`, `RunSnippet`, `BindKeys`, `ClearKeys`, `Bindings`; a wedge's right click is no press. |
| `modules/Dial_Layout.lua` | create | Task 3: pure rings (Categories, Flat, open-into, pages, More, each ring's depth), ring sizes, wedge and spoke geometry, the pointer's angle, compass words, `DeepGroups` (spec §11.3's depth 3). |
| `modules/Dial_Secure.lua` | create | Task 4: the header's snippets (`_onclick`, `qc-open`, `qc-display`, `qc-show`, `qc-close`) and the wedge wrap; `NewHeader`, `NewRing`, `NewWedge`, `Load`, `Open`, `Close`. |
| `modules/Library.lua` | modify | Task 5a: the dial's template, `MemberIds("dial")`, `SetSurfacePoint` for dials through the seam, `DIAL_DEFAULT_POINT`, `KeyValue`, `ValidKey`, `KeyOwner`; the dial's stored `interaction` is `relaxed`. Task 5b: `MoveGenericBattlegroundLast`. |
| `settings/SchemaMembers.lua` | modify | Task 5a: the dial member rows; the group's open-into tooltip. |
| `settings/Schema.lua`, `settings/Editors.lua`, `settings/Slash.lua` | modify | Task 5a: the `dial` kind, `dial.point` and `dial.key` in `resetExempt`, the `key` row type (structured), `dial.name` repaints, the CLI's `point` and `key` forms. |
| `core/Database.lua` | modify | Task 5b: migration step 2. |
| `defaults/BuiltIns_Battlegrounds.lua` | modify | Task 5b: the generic battleground set ships after the per-battleground sets. |
| `modules/Dial_Render.lua` | create | Task 6: the hub, rings and wedges' insecure regions, tooltips, the guard's dim and the result flash, the pointer's `OnUpdate` (perf `dial.render`). |
| `modules/Dial.lua` | create | Task 6: the dial's frames: `Apply`, `Release`, `Sync` (with the keys), `HideAll`, stale, locks, `Cooldown`, the `SEND_RESULT` flash, the hub's why tooltip, Reset position, reads; its receiver's stand-down and stand-up. Task 8: the binding labels. |
| `modules/Pad.lua` | modify | Task 6: publishes `Pad.ArmSlot`; `Pad.Cooldown` also dims the dials. Task 7: `ResetPositions(quiet)`. |
| `core/PerfSetup.lua` | modify | Task 6: the `dial.render` bucket; `bake.surface` names dial plans too. |
| `modules/Surfaces.lua` | modify | Task 7: `BuildDialPlan`, `TestDialPlan`, `EachSlot`, `DialPlans`, dial plans in `ApplyAll`, `Request`, `RefreshLocks`, `WhyLines`, the stand-down; `ResetPositions`. |
| `settings/Panel.lua` | modify | Task 7: Reset position covers the dials. |
| `Bindings.xml` | create | Task 8 (ruling R1): "Open Comms Dial 1–4". |
| `settings/Dials.lua` | create | Task 9: the Comms Dial page. |
| `core/Compat.lua` | modify | Task 9: `BindingAction`. |
| `modules/Diagnostics.lua` | modify | Task 10: the `dials` and `bindings` sections. |
| `settings/SlashVerbs.lua`, `settings/Slash.lua` | modify | Task 10: `/qc why` covers the dials. |
| `tests/test_mock_secure.lua`, `test_sendengine.lua`, `test_members.lua`, `test_library.lua`, `test_builtins.lua`, `test_database.lua`, `test_profile.lua`, `test_surfaces.lua`, `test_pad.lua`, `test_diagnostics.lua`, `test_compat.lua`, `test_slash.lua` | modify | the tasks named in each |
| `tests/test_dial_layout.lua` | create | Task 3 |
| `tests/test_dial_secure.lua` | create | Task 4 |
| `tests/test_dial.lua` | create | Task 6 (Tasks 7 and 8 append) |
| `tests/test_page_dials.lua` | create | Task 9 |
| `QuickComms.toc`, `tests/run.lua`, `locales/enUS.lua`, `.luacheckrc` | modify | bookkeeping, per task |
| `docs/…` (including `debug.md` and `performance.md`), `README.md`, the spec | modify | Task 11 |

The TOC order this plan ends with (new lines marked `+`; Task 4 also retags `modules\SendEngine.lua`'s line `# LOAD-BEARING:`, since `modules\Dial_Secure.lua` takes `NS.SendEngine` at load):

```
modules\SendEngine.lua
...
modules\Pad.lua
+ modules\Dial_Layout.lua
+ modules\Dial_Secure.lua
+ modules\Dial_Render.lua
+ modules\Dial.lua
modules\Diagnostics.lua
...
settings\Pads.lua
+ settings\Dials.lua
settings\Share.lua
```

The settings sidebar then reads: Ka0s Quick Comms (landing), General, Callouts, Groups, Comms Pad, Comms Dial, Share, Profiles.

**What a dial is at run time** (the shapes every task shares):

```lua
-- A dial plan (Surfaces.BuildDialPlan / TestDialPlan; State.dialPlans[id]):
plan = { kind = "dial", surfaceId = "d2", snapshot = snap, order = { gid… }, active = { [gid] = { matched } },
         rings = { ring… }, openRing = 2,            -- 0 when there is nothing to show
         lockdownChip = false, hasActive = true, test = nil|true, preview = nil|"bg:ab" }
-- A ring (Dial_Layout.Rings):
ring = { title = "Arathi Basin", page = 1, pages = 2, size = 4,       -- size: the wedge count (slices)
         depth = 2,                                                   -- 1 for the first ring; a page keeps its first page's
         parent = 1, prev = 0, next = 3,                              -- ring indices, 0 for none
         items = { { kind = "send", slot = slot, title = "INC 3", icon = … },
                   { kind = "ring", target = 6, title = "Lumber Mill", icon = … },
                   { kind = "ring", target = 3, title = "More", more = true } } }
-- A dial instance (Dial.Instance(id)):
inst = { index = 1, id = "d2", header = <QuickCommsDial1>, rings = <NS.Pool of ring containers>,
         byCallout = { [calloutId] = { wedge… } }, plan = plan, live = true }
-- A ring container: <SecureFrameTemplate frame>, .qcWedges = <NS.Pool of wedges>
-- A wedge: <QuickCommsSend<n>>, .qcItem = the ring item it shows
```

---
### Task 1: The mock: secure handlers, restricted snippets, key bindings, the cursor

The headless mock today models `SecureActionButtonTemplate` buttons, the combat refusal and visibility drivers. The dial needs what the client's secure handlers do: a header whose `_onclick` snippet runs on a click; snippets that run in a per-header environment whose globals persist, with protected calls allowed in combat; the restricted handle methods (`GetFrameRef`, `SetBindingClick`, `ClearBindings`, `RunAttribute`); `Execute`, `SetFrameRef` and `WrapScript` on the insecure side (refused in combat); override bindings; and a key press routed through both binding layers. Fidelity rules this task adds: a restricted-only call made from insecure code raises; a wrap on a button that already has an `OnClick` hook raises (the client's wrap replaces the script and would silently drop the hook).

**Files:**
- Modify: `tests/wow_mock.lua` (the header comment's field list; `refuse` / `protect`; `PROTECTED_CALLS`; `dress`; the `CreateFrame` wrapper; new functions after `M.__secureFrames`)
- Test: `tests/test_mock_secure.lua` (append)

**Interfaces:**
- Consumes: the existing mock (`M.CreateFrame` wrapper, `refuse`, `protect`, `dress`, `secureOnClick`, `M.__click`, `M.blocked`, `M.sentMacros`).
- Produces (later tasks' tests rely on exactly these):
  - a frame made from any template containing `SecureHandler` has `SetFrameRef(name, frame)`, `Execute(body)`, `WrapScript(frame, "OnClick", pre, post)` (all refused in combat), runs its `_onclick` attribute as a snippet `(self, button, down)` on a click, and fires `OnShow` / `OnHide` when `Show` / `Hide` / `SetShown` change it;
  - every secure frame has the restricted methods `GetFrameRef(name)`, `SetBindingClick(priority, key, target, button)`, `ClearBindings()`, `RunAttribute(attr, ...)` (each raises outside a snippet);
  - a header's snippet environment is `header.__env` (its globals persist);
  - `M.restrictedBindings[key] = { owner, target, button }`, `M.overrideBindings[key] = { owner, name, button }`, `M.bindingActions[key]` (what `GetBindingAction` answers), `M.cursor = { x, y }`, `M.__named[name]`;
  - `M.SetOverrideBindingClick(owner, priority, key, name, button)`, `M.ClearOverrideBindings(owner)`, `M.GetBindingAction(key)`, `M.GetCursorPosition()`, `M.__pressKey(key) -> boolean`, `M.__runSnippet(header, params, body, ...)`;
  - frames under a `QuickComms`-named root answer `GetCenter()` (`__cx`, `__cy`, default 0, 0) and `GetEffectiveScale()` (1).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_mock_secure.lua`:
```lua
-- ── secure handlers and key bindings (phase 4: the Comms Dial) ───────────────────────────────

local function header(m, name)
    local h = m.CreateFrame("Button", name or "QCMockHeader", m.UIParent, "SecureHandlerClickTemplate")
    h:RegisterForClicks("AnyDown")
    return h
end

test("mock: [phase 4] a header's _onclick runs as a snippet, and its globals persist between snippets", function()
    local _, m = T.newAddon()
    local h = header(m)
    h:SetAttribute("_onclick", [[ count = (count or 0) + 1  last = button .. tostring(down) ]])
    m.__click(h, "Toggle")
    m.__click(h, "Toggle")
    assertEqual(h.__env.count, 2)
    assertEqual(h.__env.last, "Toggletrue", "registered for the down edge only")
end)

test("mock: [phase 4] in combat a snippet may show a protected frame; insecure code may not", function()
    local _, m = T.newAddon()
    local h = header(m)
    local ring = m.CreateFrame("Frame", nil, h, "SecureFrameTemplate")
    ring:Hide()
    h:SetFrameRef("ring1", ring)
    h:SetAttribute("_onclick", [[ self:GetFrameRef("ring1"):Show() ]])
    m.inCombat = true
    ring:Show()
    assertFalse(ring:IsShown())
    assertEqual(#m.blocked, 1)
    m.__click(h, "LeftButton")
    -- red under: drop `secureDepth == 0` from protect() in tests/wow_mock.lua
    assertTrue(ring:IsShown(), "the restricted environment's privilege")
    assertEqual(#m.blocked, 1)
end)

test("mock: [phase 4] the restricted-only handle calls raise outside a snippet", function()
    local _, m = T.newAddon()
    local h = header(m)
    for _, call in ipairs({ "GetFrameRef", "SetBindingClick", "ClearBindings", "RunAttribute" }) do
        local ok, err = pcall(h[call], h, "x")
        assertFalse(ok, call)
        assertTrue(tostring(err):find("restricted%-environment call") ~= nil, tostring(err))
    end
end)

test("mock: [phase 4] a wrap's pre snippet can suppress a click, and its message runs the post snippet", function()
    local _, m = T.newAddon()
    local h = header(m)
    h:SetAttribute("note", [[ note = ... ]])
    local b = m.CreateFrame("Button", "QCMockWedge", h, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/p hi")
    b:SetAttribute("useOnKeyDown", false)
    h:WrapScript(b, "OnClick", [[ if down or button == "RightButton" then return false end return button, "sent" ]],
        [[ owner:RunAttribute("note", message) ]])
    m.__click(b, "RightButton")
    assertEqual(#m.sentMacros, 0, "suppressed")
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(h.__env.note, "sent", "the post snippet heard the message")
end)

test("mock: [phase 4] a wrap after an OnClick hook raises (the client's wrap discards the hook)", function()
    local _, m = T.newAddon()
    local h = header(m)
    local b = m.CreateFrame("Button", "QCMockWedge", h, "SecureActionButtonTemplate")
    b:HookScript("OnClick", function() end)
    local ok, err = pcall(h.WrapScript, h, b, "OnClick", "return", nil)
    assertFalse(ok)
    assertTrue(tostring(err):find("discards the hook", 1, true) ~= nil, tostring(err))
end)

test("mock: [phase 4] a snippet's key binding routes a key press to a named button until it is cleared", function()
    local _, m = T.newAddon()
    local h = header(m)
    local b = m.CreateFrame("Button", "QCMockWedge", h, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/p one")
    h:SetAttribute("_onclick", [[
        if button == "Bind" then self:SetBindingClick(true, "1", "QCMockWedge", "LeftButton") else self:ClearBindings() end
    ]])
    m.__click(h, "Bind")
    assertTrue(m.__pressKey("1"))
    assertEqual(#m.sentMacros, 1)
    m.__click(h, "Clear")
    assertFalse(m.__pressKey("1"), "released")
end)

test("mock: [phase 4] override bindings are refused in combat; a press clicks the bound frame by name", function()
    local _, m = T.newAddon()
    local h = header(m, "QCMockDial")
    h:SetAttribute("_onclick", [[ pressed = button ]])
    local owner = m.CreateFrame("Frame")
    m.SetOverrideBindingClick(owner, true, "G", "QCMockDial", "Toggle")
    assertTrue(m.__pressKey("G"))
    assertEqual(h.__env.pressed, "Toggle")
    m.inCombat = true
    m.ClearOverrideBindings(owner)
    assertEqual(#m.blocked, 1)
    assertTrue(m.overrideBindings.G ~= nil, "still bound")
    m.inCombat = false
    m.ClearOverrideBindings(owner)
    assertFalse(m.__pressKey("G"))
end)

test("mock: [phase 4] a header's Show and Hide fire OnShow and OnHide on a change; Execute is refused in combat", function()
    local _, m = T.newAddon()
    local h = header(m)
    local seen = {}
    h:HookScript("OnShow", function() seen[#seen + 1] = "show" end)
    h:HookScript("OnHide", function() seen[#seen + 1] = "hide" end)
    h:Hide()
    h:Hide()
    h:Show()
    assertEqual(table.concat(seen, ","), "hide,show")
    m.inCombat = true
    h:Execute([[ ran = true ]])
    assertNil(h.__env and h.__env.ran)
    assertEqual(m.blocked[#m.blocked].call, "Execute")
end)

test("mock: [phase 4] the cursor and a frame's center are numbers a suite can set", function()
    local _, m = T.newAddon()
    m.cursor.x, m.cursor.y = 12, -3
    local x, y = m.GetCursorPosition()
    assertEqual(x .. "," .. y, "12,-3")
    local f = m.CreateFrame("Frame", "QuickCommsDialTest", m.UIParent)
    local cx, cy = f:GetCenter()
    assertEqual(cx .. "," .. cy, "0,0")
    assertEqual(f:GetEffectiveScale(), 1)
    assertEqual(m.GetBindingAction("F"), "")
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_mock_secure` (the first: `h.__env` is nil, because a `SecureHandler` frame has no `_onclick` dispatch yet).

- [ ] **Step 3: Document the new fields**

In `tests/wow_mock.lua`, in the header comment's `-- Mock fields:` list, after the `--   __setCombat(on) ...` line, add:
```lua
--   restrictedBindings  [key] = { owner, target, button }: what a header's snippet bound with SetBindingClick
--   overrideBindings    [key] = { owner, name, button }: SetOverrideBindingClick (refused in combat)
--   bindingActions      [key] = the action the player's own WoW binding names (GetBindingAction)
--   cursor              { x, y }: GetCursorPosition's answer
--   __named[name]       every named frame (a binding clicks a frame by its name)
--   __pressKey(key)     a key press: a snippet's binding first, then an override binding; false if unbound
--   __runSnippet(h, params, body, ...)  run restricted source in header h's environment
-- A frame made from a SecureHandler template runs its `_onclick` attribute as a snippet on a click;
-- its snippets run in its own environment (`h.__env`, globals persist), where the protected calls
-- refused in combat are allowed. The restricted handle methods raise outside a snippet; a WrapScript
-- on a button that already has an OnClick hook raises (the client's wrap discards the hook).
```

- [ ] **Step 4: Let snippets make protected calls in combat**

In `tests/wow_mock.lua`, replace
```lua
    local function refuse(frame, call)
        M.blocked[#M.blocked + 1] = { frame = frame, call = call }
    end

    local PROTECTED_CALLS = { "SetAttribute", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints",
        "SetAllPoints", "SetParent", "SetScale", "SetSize", "SetWidth", "SetHeight", "RegisterForClicks",
        "EnableMouse", "StartMoving", "StopMovingOrSizing", "SetFrameStrata", "SetFrameLevel", "SetMovable",
        "SetClampedToScreen" }

    local function protect(frame)
        if frame.__protected then return end
        frame.__protected = true
        for _, call in ipairs(PROTECTED_CALLS) do
            local inner = frame[call]
            frame[call] = function(self, ...)
                if M.inCombat then
```
with
```lua
    local function refuse(frame, call)
        M.blocked[#M.blocked + 1] = { frame = frame, call = call }
    end

    -- Inside a restricted snippet (a SecureHandler header's), the protected calls the insecure side is
    -- refused in combat are allowed: the restricted environment's own privilege.
    local secureDepth = 0

    local PROTECTED_CALLS = { "SetAttribute", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints",
        "SetAllPoints", "SetParent", "SetScale", "SetSize", "SetWidth", "SetHeight", "RegisterForClicks",
        "EnableMouse", "StartMoving", "StopMovingOrSizing", "SetFrameStrata", "SetFrameLevel", "SetMovable",
        "SetClampedToScreen", "Execute", "WrapScript", "SetFrameRef" }

    local function protect(frame)
        if frame.__protected then return end
        frame.__protected = true
        for _, call in ipairs(PROTECTED_CALLS) do
            local inner = frame[call]
            frame[call] = function(self, ...)
                if M.inCombat and secureDepth == 0 then
```

- [ ] **Step 5: Frames answer a center and a scale**

In `dress(frame)`, after the `frame.GetAlpha = …` line, add:
```lua
        frame.GetCenter = function(self) return self.__cx or 0, self.__cy or 0 end
        frame.GetEffectiveScale = function() return 1 end
```

- [ ] **Step 6: The restricted environment, the handle methods and the header**

Directly above `local secureFrames = {}`, add:
```lua
    -- ── secure handlers and key bindings (phase 4: the Comms Dial) ──────────────────────────────
    M.restrictedBindings = {}
    M.overrideBindings   = {}
    M.bindingActions     = {}
    M.cursor             = { x = 0, y = 0 }
    M.__named            = {}

    -- What a snippet may reach besides its handles. The client's restricted environment is wider;
    -- these are the ones this addon's snippets use, so a snippet reaching for anything else fails here.
    local SNIPPET_GLOBALS = { tonumber = tonumber, tostring = tostring, type = type, select = select,
        math = math, string = string }

    local makers = {}
    local function maker(params, body)
        local key = params .. "\0" .. body
        local fn = makers[key]
        if not fn then
            local chunk, err = loadstring("return function(" .. params .. ")\n" .. body .. "\nend", "=snippet")
            if not chunk then error("wow_mock: a snippet does not compile: " .. tostring(err), 3) end
            makers[key], fn = chunk, chunk
        end
        return fn
    end

    -- Run `body` as a function of `params` in `header`'s environment, protected calls allowed.
    local function runSnippet(header, params, body, ...)
        header.__env = header.__env or setmetatable({}, { __index = SNIPPET_GLOBALS })
        local make = maker(params, body)
        setfenv(make, header.__env)
        local fn = make()
        secureDepth = secureDepth + 1
        local results = { pcall(fn, ...) }
        secureDepth = secureDepth - 1
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2, table.maxn(results))
    end
    M.__runSnippet = runSnippet

    local function restricted(name)
        if secureDepth == 0 then error("wow_mock: " .. name .. " is a restricted-environment call", 3) end
    end

    -- What a snippet may call on a handle beyond the frame's own methods.
    local function addHandleMethods(f)
        f.GetFrameRef = function(self, ref)
            restricted("GetFrameRef")
            return self.__frameRefs and self.__frameRefs[ref]
        end
        f.SetBindingClick = function(self, _, key, target, button)
            restricted("SetBindingClick")
            M.restrictedBindings[key] = { owner = self, target = target, button = button or "LeftButton" }
        end
        f.ClearBindings = function(self)
            restricted("ClearBindings")
            for key, b in pairs(M.restrictedBindings) do
                if b.owner == self then M.restrictedBindings[key] = nil end
            end
        end
        f.RunAttribute = function(self, attr, ...)
            restricted("RunAttribute")
            local body = self.__attrs[attr]
            if type(body) ~= "string" then return nil end
            return runSnippet(self, "self, ...", body, self, ...)
        end
    end

    -- The SecureHandler template's insecure-side API (refused in combat by protect()), its click (the
    -- `_onclick` snippet), and OnShow / OnHide on a change.
    local function makeHeader(f)
        f.__frameRefs = {}
        f.SetFrameRef = function(self, ref, frame)
            self.__frameRefs[ref] = frame
            return self
        end
        f.Execute = function(self, body)
            runSnippet(self, "self", body, self)
            return self
        end
        f.WrapScript = function(self, frame, script, pre, post)
            if script ~= "OnClick" then error("wow_mock: only an OnClick wrap is modeled", 2) end
            if frame.__hooked then
                error("wow_mock: WrapScript after HookScript(\"OnClick\"): the client's wrap discards the hook", 2)
            end
            local inner, header = frame.__scripts.OnClick, self
            frame.__scripts.OnClick = function(btn, button, down)
                local newButton, message
                if pre then
                    local r1, r2 = runSnippet(header, "self, button, down, owner", pre, btn, button, down, header)
                    if r1 == false then return end
                    newButton, message = r1, r2
                end
                if inner then inner(btn, newButton or button, down) end
                if post and message ~= nil then
                    runSnippet(header, "self, message, button, down, owner", post, btn, message, button, down, header)
                end
            end
            return self
        end
        f.__scripts.OnClick = function(self, button, down)
            local body = self.__attrs._onclick
            if type(body) == "string" then runSnippet(self, "self, button, down", body, self, button, down) end
        end
        local show, hide = f.Show, f.Hide
        f.Show = function(self)
            local was = self.__shown
            show(self)
            if not was then self:__fire("OnShow") end
            return self
        end
        f.Hide = function(self)
            local was = self.__shown
            hide(self)
            if was then self:__fire("OnHide") end
            return self
        end
        f.SetShown = function(self, v)
            if v then return self:Show() end
            return self:Hide()
        end
    end

```

- [ ] **Step 7: Wire them into CreateFrame**

Replace
```lua
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if ours(f) then dress(f) end
        if type(template) == "string" and template:find("Secure", 1, true) then
```
with
```lua
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if ours(f) then dress(f) end
        if type(name) == "string" then M.__named[name] = f end
        if type(template) == "string" and template:find("Secure", 1, true) then
```
and replace
```lua
            f.__scripts.OnClick = secureOnClick
            protect(f)
```
with
```lua
            f.__scripts.OnClick = secureOnClick
            -- A wrap must come before an OnClick hook (makeHeader's WrapScript checks this flag).
            local hook = f.HookScript
            f.HookScript = function(self, script, fn)
                if script == "OnClick" then self.__hooked = true end
                return hook(self, script, fn)
            end
            addHandleMethods(f)
            if template:find("SecureHandler", 1, true) then makeHeader(f) end
            protect(f)
```

- [ ] **Step 8: Override bindings, the binding menu's read, the cursor and a key press**

Directly after the `M.__click = function(button, mouseButton) … end` block, add:
```lua
    M.SetOverrideBindingClick = function(owner, _, key, name, button)
        if M.inCombat then
            refuse(owner, "SetOverrideBindingClick")
            return
        end
        M.overrideBindings[key] = { owner = owner, name = name, button = button or "LeftButton" }
    end

    M.ClearOverrideBindings = function(owner)
        if M.inCombat then
            refuse(owner, "ClearOverrideBindings")
            return
        end
        for key, b in pairs(M.overrideBindings) do
            if b.owner == owner then M.overrideBindings[key] = nil end
        end
    end

    M.GetBindingAction = function(key) return M.bindingActions[key] or "" end
    M.GetCursorPosition = function() return M.cursor.x, M.cursor.y end

    --- A key press as the client routes it: a snippet's binding first, then an override binding;
    --- the target is clicked with the binding's button, down then up as `__click` presses it.
    --- @return boolean routed
    M.__pressKey = function(key)
        local b = M.restrictedBindings[key] or M.overrideBindings[key]
        if not b then return false end
        local target = b.target or b.name
        if type(target) == "string" then target = M.__named[target] end
        if type(target) ~= "table" then return false end
        M.__click(target, b.button)
        return true
    end
```

- [ ] **Step 9: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 warnings / 0 errors. Every earlier suite still passes: the pads' secure buttons now also carry the restricted methods and the `HookScript` flag, which nothing before this phase reads.

- [ ] **Step 10: Commit**

```bash
git add tests/wow_mock.lua tests/test_mock_secure.lua
git checkout -- tests/wow_mock.lua tests/test_mock_secure.lua
git commit -m "Tests: the mock models secure handlers, restricted snippets and key bindings"
```

---
### Task 2: SendEngine: the dial's secure frames and the override bindings

SendEngine stays the only secure writer (§9). It gains what `Dial_Secure` asks for: a dial header and its ring containers, a send button wrapped by a header's snippets (wrapped **before** SendEngine's own click hook, because the client's wrap replaces the script), attribute and frame-ref writes, running one of a header's snippets, and the override bindings for the dials' keys (one owner frame; the whole set replaced at once). All of it is out of combat only: in combat each call declines and answers `false` or `nil`, and the caller runs it through `RunOrQueue`. A wedge acts on the up edge and only a left click (or a number key, which clicks with `LeftButton`) is a press: a right click closes the dial, so its hook must not stamp the guard or await an echo.

**Files:**
- Modify: `modules/SendEngine.lua` (the header comment; `SE.NewButton`; `SE.OnClick`; a new section after `SE.ClearVisibility`; a new section after `SE.Snapshot`)
- Modify: `.luacheckrc` (`read_globals`)
- Test: `tests/test_sendengine.lua` (append; and the `[firewall]` list with its `[fix wave]` samples)

**Interfaces:**
- Consumes: Task 1's mock (`SecureHandlerClickTemplate`, `WrapScript`, `Execute`, `SetFrameRef`, override bindings).
- Produces:
  - `SE.NewButton(parent, onPress, wrap) -> button|nil`; `wrap = { header, pre, post }` (optional): wrapped before the hook, `useOnKeyDown = false`, `button.qcLeftOnly = true`
  - `SE.NewDialHeader(name) -> header|nil` (a `SecureHandlerClickTemplate` `Button` on `UIParent`, `RegisterForClicks("AnyDown")`, strata `DIALOG`, hidden)
  - `SE.NewDialRing(header) -> frame|nil` (`SecureFrameTemplate`, hidden)
  - `SE.SetAttributes(frame, attrs) -> boolean`, `SE.SetFrameRef(header, name, frame) -> boolean`, `SE.RunSnippet(header, attr) -> boolean`
  - `SE.BindKeys(list) -> boolean` with `list = { { key, name, button }… }` (replaces the whole set), `SE.ClearKeys() -> boolean`, `SE.Bindings() -> { { key, name, button }… }` (a copy)

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_sendengine.lua`:
```lua
-- ── the Comms Dial's secure frames and the override bindings (phase 4) ──────────────────────

test("sendengine: [phase 4] a dial header is a named click handler for the down edge, hidden; none in combat", function()
    local NS, m = T.enableAddon()
    local h = NS.SendEngine.NewDialHeader("QuickCommsDialT")
    assertEqual(h.__template, "SecureHandlerClickTemplate")
    assertEqual(h:GetName(), "QuickCommsDialT")
    assertEqual(table.concat(h.__clicks, ","), "AnyDown")
    assertFalse(h:IsShown())
    local ring = NS.SendEngine.NewDialRing(h)
    assertEqual(ring.__template, "SecureFrameTemplate")
    assertFalse(ring:IsShown())
    combat(m, true)
    assertNil(NS.SendEngine.NewDialHeader("QuickCommsDialU"))
    assertNil(NS.SendEngine.NewDialRing(h))
    assertEqual(#m.blocked, 0)
end)

test("sendengine: [phase 4] a wedge is wrapped before it is hooked, acts on the up edge, and only a left click is a press", function()
    local NS, m = T.enableAddon()
    local h = NS.SendEngine.NewDialHeader("QuickCommsDialT")
    local pre = [[ if down or button == "RightButton" then return false end return button ]]
    -- red under: hook before wrapping in SE.NewButton (the mock's wrap raises: the client discards the hook)
    local b = NS.SendEngine.NewButton(h, nil, { header = h, pre = pre })
    assertEqual(b:GetAttribute("useOnKeyDown"), false)
    NS.SendEngine.Arm(b, "/p Pulling", META)
    m.__click(b, "RightButton")
    assertEqual(#m.sentMacros, 0)
    -- red under: drop the qcLeftOnly check from SE.OnClick (the hook would track a press nothing sent)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
    m.__click(b)
    assertEqual(#m.sentMacros, 1)
    assertEqual(NS.SendEngine.EchoState().pending, 1)
end)

test("sendengine: [phase 4] attributes, frame refs and snippets are written out of combat only, never blocked", function()
    local NS, m = T.enableAddon()
    local SE = NS.SendEngine
    local h = SE.NewDialHeader("QuickCommsDialT")
    local ring = SE.NewDialRing(h)
    assertTrue(SE.SetAttributes(h, { ["qc-open"] = [[ opened = true ]], ["qc-rings"] = 1 }))
    assertTrue(SE.SetFrameRef(h, "ring1", ring))
    assertTrue(SE.RunSnippet(h, "qc-open"))
    assertTrue(h.__env.opened)
    combat(m, true)
    assertFalse(SE.SetAttributes(h, { ["qc-rings"] = 2 }))
    assertFalse(SE.SetFrameRef(h, "ring2", ring))
    assertFalse(SE.RunSnippet(h, "qc-open"))
    assertEqual(h:GetAttribute("qc-rings"), 1)
    assertEqual(#m.blocked, 0)
end)

test("sendengine: [phase 4] BindKeys replaces the whole set, out of combat only; ClearKeys empties it", function()
    local NS, m = T.enableAddon()
    local SE = NS.SendEngine
    assertTrue(SE.BindKeys({ { key = "G", name = "QuickCommsDial1", button = "Toggle" } }))
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1")
    assertEqual(m.overrideBindings.G.button, "Toggle")
    assertTrue(SE.BindKeys({ { key = "H", name = "QuickCommsDial2", button = "Toggle" } }))
    assertNil(m.overrideBindings.G, "the earlier set is gone")
    assertEqual(SE.Bindings()[1].key, "H")
    combat(m, true)
    assertFalse(SE.BindKeys({}))
    assertEqual(m.overrideBindings.H.name, "QuickCommsDial2", "kept until combat ends")
    assertEqual(#m.blocked, 0)
    combat(m, false)
    assertTrue(SE.ClearKeys())
    assertNil(m.overrideBindings.H)
    assertEqual(#SE.Bindings(), 0)
end)
```

In the same file, widen the firewall to the header's three insecure-side calls (they wire a header's snippets to frames, so they are secure writes too). Replace
```lua
local FORBIDDEN = { "SetAttribute%s*%(", "[\"']SetAttribute[\"']", "SetOverrideBinding", "ClearOverrideBindings",
    "RegisterStateDriver%s*%(", "UnregisterStateDriver%s*%(", "Secure%w*Template", "SecureHandler" }
```
with
```lua
local FORBIDDEN = { "SetAttribute%s*%(", "[\"']SetAttribute[\"']", "SetOverrideBinding", "ClearOverrideBindings",
    "RegisterStateDriver%s*%(", "UnregisterStateDriver%s*%(", "Secure%w*Template", "SecureHandler",
    -- phase 4: a header's frame refs, wraps and snippet runs (the restricted side's GetFrameRef,
    -- RunAttribute, SetBindingClick and ClearBindings are not writes and stay allowed)
    ":SetFrameRef%s*%(", ":WrapScript%s*%(", ":Execute%s*%(" }
```
and in the case `"sendengine: [fix wave] the firewall's patterns catch every Secure* template and SetAttribute spelling"`, replace
```lua
        'b["SetAttribute"](b, "type", "macro")', "RegisterStateDriver (f, 'visibility', 'show')" }) do
        assertTrue(caught(src), src)
    end
    assertFalse(caught("b:GetAttribute('type')"))
```
with
```lua
        'b["SetAttribute"](b, "type", "macro")', "RegisterStateDriver (f, 'visibility', 'show')",
        -- phase 4; red under: drop the three header patterns from FORBIDDEN
        'h:SetFrameRef("ring1", r)', "h:WrapScript (b, 'OnClick', pre, post)", 'h:Execute([[ x = 1 ]])' }) do
        assertTrue(caught(src), src)
    end
    assertFalse(caught("b:GetAttribute('type')"))
    -- What Dial_Secure's snippets do inside the restricted environment is not a write.
    for _, src in ipairs({ 'self:GetFrameRef("ring1"):Show()', 'owner:RunAttribute("qc-close")',
        'self:SetBindingClick(true, "ESCAPE", self, "Close")', "self:ClearBindings()", "SE.SetFrameRef(h, n, f)" }) do
        assertFalse(caught(src), src)
    end
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_sendengine` (`attempt to call field 'NewDialHeader' (a nil value)`). The widened firewall cases already pass: no shipped file but `modules/SendEngine.lua` calls a header's `SetFrameRef`, `WrapScript` or `Execute` yet.

- [ ] **Step 3: The header comment**

In `modules/SendEngine.lua`, replace the first two comment lines
```lua
-- modules/SendEngine.lua — THE ONLY SECURE WRITER (spec §9, events-frames-taint-§2/§4). It alone
-- creates frames from a Secure* template, calls SetAttribute and registers or unregisters state
-- drivers; tests/test_sendengine.lua greps every other shipped file for those calls. Every write is
```
with
```lua
-- modules/SendEngine.lua — THE ONLY SECURE WRITER (spec §9, events-frames-taint-§2/§4). It alone
-- creates frames from a Secure* template, calls SetAttribute, registers or unregisters state
-- drivers, sets and clears override bindings, and (phase 4, the Comms Dial) sets a header's frame
-- refs, wraps a button's click in a header's snippets and runs a header's snippet;
-- tests/test_sendengine.lua greps every other shipped file for those calls. Every write is
```
and, after the paragraph ending `… core/LifecycleSetup.lua \`standDown\` for the held teardown below.`, add:
```lua
--
-- The Comms Dial (spec §11.2, Relaxed mode): modules/Dial_Secure.lua holds the snippet text and asks
-- here for the header (a SecureHandlerClickTemplate button named QuickCommsDial<n>), its ring
-- containers (SecureFrameTemplate), its wedges (send buttons wrapped by the header's snippets BEFORE
-- the click hook below, because the client's wrap replaces the script and would drop the hook), and
-- every attribute, frame ref and snippet run. The dials' keys are override bindings on one owner
-- frame, replaced as a set at each rebuild and cleared by the stand-down (spec §9.4).
```

- [ ] **Step 4: The wrapped button and the left-click press**

Replace
```lua
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
    b:HookScript("OnClick", function(...) SE.OnClick(...) end)
```
with
```lua
--- A new secure send button, or nil in combat (building a secure frame is out of combat only).
--- @param parent table the frame it belongs to (a pad's root, a dial's ring)
--- @param onPress function|nil onPress(button, verdict, window), called by the click hook
--- @param wrap table|nil a dial wedge: { header, pre, post }, the header's snippets around its click
--- @return table|nil
function SE.NewButton(parent, onPress, wrap)
    if inCombat() then
        NS.Debug(TAG_S, "button refused: in combat")
        return nil
    end
    seq = seq + 1
    local b = CreateFrame("Button", "QuickCommsSend" .. seq, parent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    if wrap then
        -- Wrapped before the hook below: the client's wrap replaces the script, dropping any earlier
        -- hook. A wedge acts on the up edge, so its pre snippet can tell the edges apart, and only a
        -- left click (a number key clicks with LeftButton) is a press: a right click closes the dial.
        wrap.header:WrapScript(b, "OnClick", wrap.pre, wrap.post)
        b:SetAttribute("useOnKeyDown", false)
        b.qcLeftOnly = true
    end
    b:HookScript("OnClick", function(...) SE.OnClick(...) end)
```
and replace
```lua
function SE.OnClick(b, _, down)
    if not G.IsActingEdge(down, useKeyDown(b)) then return end
```
with
```lua
function SE.OnClick(b, mouseButton, down)
    if b.qcLeftOnly and mouseButton ~= "LeftButton" then return end
    if not G.IsActingEdge(down, useKeyDown(b)) then return end
```

- [ ] **Step 5: The dial's secure frames**

After `SE.ClearVisibility` (before the `-- ── the combat-end queue` divider), add:
```lua
-- ── the Comms Dial's secure frames (spec §11.2): Dial_Secure asks, this file writes ─────────

--- A dial's header: a named SecureHandlerClickTemplate button (Bindings.xml and the dial's key click
--- it by name), registered for the down edge only, hidden until its snippet opens it. Nil in combat.
function SE.NewDialHeader(name)
    if inCombat() then
        NS.Debug("Dial", "header refused: in combat")
        return nil
    end
    local h = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
    h:RegisterForClicks("AnyDown")
    h:SetFrameStrata("DIALOG")
    h:Hide()
    return h
end

--- One ring's container under a dial's header: explicitly protected, so the header's snippets can show
--- and hide it in combat. Hidden. Nil in combat.
function SE.NewDialRing(header)
    if inCombat() then return nil end
    local r = CreateFrame("Frame", nil, header, "SecureFrameTemplate")
    r:Hide()
    return r
end

--- Write several attributes (a header's snippets and ring layout, a wedge's target). Out of combat.
--- @return boolean written
function SE.SetAttributes(frame, attrs)
    if inCombat() then
        NS.Debug("Dial", "attributes refused: in combat")
        return false
    end
    for k, v in pairs(attrs) do frame:SetAttribute(k, v) end
    return true
end

--- Hand a header a frame its snippets reach by name. Out of combat.
--- @return boolean set
function SE.SetFrameRef(header, name, frame)
    if inCombat() then return false end
    header:SetFrameRef(name, frame)
    return true
end

--- Run one of a header's snippets now (a rebuild closes the dial; test mode opens it). Out of combat.
--- @return boolean ran
function SE.RunSnippet(header, attr)
    if inCombat() then return false end
    header:Execute(("self:RunAttribute(%q)"):format(attr))
    return true
end
```

- [ ] **Step 6: The override bindings**

After `SE.Snapshot` (before the `-- ── the held stand-down` divider), add:
```lua
-- ── the override bindings (spec §9.4): the dials' keys ──────────────────────────────────────

local bindOwner          -- a plain frame; every override binding this addon holds is its
local bound, boundSig = {}, nil

--- Bind each { key, name, button } as an override click, replacing every binding this addon held.
--- Out of combat only: the client refuses override bindings in combat. Logged only on a change.
--- @return boolean applied
function SE.BindKeys(list)
    if inCombat() then
        NS.Debug("Bind", "bindings refused: in combat")
        return false
    end
    bindOwner = bindOwner or CreateFrame("Frame")
    ClearOverrideBindings(bindOwner)
    bound = {}
    local parts = {}
    for _, b in ipairs(list or {}) do
        SetOverrideBindingClick(bindOwner, true, b.key, b.name, b.button)
        bound[#bound + 1] = { key = b.key, name = b.name, button = b.button }
        parts[#parts + 1] = b.key .. "=" .. b.name
    end
    local sig = table.concat(parts, ",")
    if sig ~= boundSig then
        boundSig = sig
        NS.Debug("Bind", "bound %s", sig ~= "" and sig or "nothing")
    end
    return true
end

--- Release every key this addon bound. Out of combat only.
function SE.ClearKeys()
    return SE.BindKeys({})
end

--- The bindings in force, for diagnostics and the Binding tab: { key, name, button } each, a copy.
function SE.Bindings()
    local out = {}
    for i, b in ipairs(bound) do out[i] = { key = b.key, name = b.name, button = b.button } end
    return out
end
```

- [ ] **Step 7: Lint knows the binding calls**

In `.luacheckrc`, replace
```lua
  -- modules/SendEngine.lua: the secure frame API (the firewall test keeps it in that one file).
  "CreateFrame", "UIParent", "RegisterStateDriver", "UnregisterStateDriver", "GetTime",
```
with
```lua
  -- modules/SendEngine.lua: the secure frame API (the firewall test keeps it in that one file).
  "CreateFrame", "UIParent", "RegisterStateDriver", "UnregisterStateDriver", "GetTime",
  "SetOverrideBindingClick", "ClearOverrideBindings",
```

- [ ] **Step 8: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0. The `[firewall]` case passes with the widened list: every new secure call, the three header calls included, is in `modules/SendEngine.lua`.

- [ ] **Step 9: Commit**

```bash
git add modules/SendEngine.lua .luacheckrc tests/test_sendengine.lua
git checkout -- modules/SendEngine.lua .luacheckrc tests/test_sendengine.lua
git commit -m "SendEngine: the dial's headers, rings, wrapped wedges, snippet runs and override bindings"
```

---
### Task 3: Dial_Layout: rings, pages, open-into and geometry (pure)

The dial's shape, decided headlessly: which rings a dial's active groups make and how they link (spec §11.3), and where each wedge sits (§11.1). Categories (D2) puts the groups on the first ring and each group's callouts on its own ring; a battleground node set's ring holds its nodes and each node's ring its six callouts. Flat puts every callout on the first ring, highest group first. A ring with more items than wedges is paged: each page but the last holds `size - 1` items and a More wedge to the next page; a later page's parent and previous are the page before it, so the hub and the wheel go back. Open-into (D9): when the first group has the flag, the dial opens on that group's ring and the hub goes up to the group ring; the same holds when there is only one group (owner ruling R2: a one-wedge first ring would cost a click for nothing). In Flat, a node's callout is titled with its node ("INC 3 · Lumber Mill"), so five wedges never read the same. Each ring records its depth (1 for the first ring, a page keeping its first page's), and `DeepGroups` names the node sets whose callouts sit three rings deep, for the Groups tab's warning (spec §11.3: depth 3 is allowed, with the editor warning). The wedge count per ring is the dial's slices setting, never grown; a 12-slice dial gives 8 to a ring that holds a ring (spec §11.3: 12 only on a ring with no children; a More wedge is a child).

**Files:**
- Create: `modules/Dial_Layout.lua`
- Modify: `QuickComms.toc` (after `modules\Pad.lua`), `tests/run.lua` (suites), `locales/enUS.lua`
- Test: `tests/test_dial_layout.lua`

**Interfaces:**
- Consumes: `NS.L` (load-time).
- Produces (`NS.DialLayout`, `DL`):
  - constants `DL.RADIUS = 92`, `DL.WEDGE = 44`, `DL.HUB = 40`, `DL.LABEL = 40`, `DL.DISC`, `DL.POINTER`, `DL.DEAD = 8`, `DL.KEYS = 8`
  - `DL.ClampSlices(v) -> 4|6|8|12`, `DL.RingSize(slices, hasChildren) -> number`
  - `DL.Paginate(items, size) -> { page… }` (each page a list)
  - `DL.Wedge(i, n[, radius]) -> { angle, x, y, lx, ly }` (clockwise from N; `lx, ly` the label's offset from the wedge's center)
  - `DL.Spoke(j, n) -> { x, y, rotation, length }`
  - `DL.Direction(i, n) -> "N"|"NE"|…|"NW"`
  - `DL.Pointer(cx, cy, mx, my) -> angle, x, y` or nil inside the dead zone
  - `DL.Rings(groups, opts) -> rings, openRing`; `groups` = `{ { id, title, icon, openInto, slots = { slot… } } | { …, children = { { id, title, icon, slots }… } } }` in the dial's order; `opts = { mode = "categories"|"flat", slices, title }`; `rings[i] = { title, page, pages, size, depth, parent, prev, next, items }`, each item `{ kind = "send", slot, title, icon }` or `{ kind = "ring", target, title, icon[, more = true] }`; `openRing` is 0 when there is nothing to show
  - `DL.DeepGroups(rings, openRing) -> { title… }`: the node sets reached three rings deep (a ring at depth 2 that holds rings other than More, and is not the ring the dial opens on)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_dial_layout.lua`:
```lua
-- tests/test_dial_layout.lua — modules/Dial_Layout.lua (spec §11.1, §11.3): the rings a dial's groups
-- make (Categories, Flat, open-into, pages behind More) and the wedges' geometry. Pure.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertNil = T.test, T.assertEqual, T.assertNil

local function DL() return T.newAddon().DialLayout end

local function slots(prefix, n)
    local out = {}
    for i = 1, n do out[i] = { calloutId = prefix .. i, name = prefix .. " " .. i } end
    return out
end

local function titles(ring)
    local out = {}
    for i, item in ipairs(ring.items) do out[i] = item.title end
    return table.concat(out, ",")
end

-- Arathi Basin as a dial plan hands it over: five nodes, six callouts each, open-into on.
local function ab()
    local children = {}
    for i, node in ipairs({ "Stables", "Lumber Mill", "Blacksmith", "Gold Mine", "Farm" }) do
        local s = {}
        for k, word in ipairs({ "INC 1", "INC 2", "INC 3", "INC many", "Clear", "Help" }) do
            s[k] = { calloutId = node .. k, name = word, line = "/i " .. word .. " " .. node }
        end
        children[i] = { id = "n" .. i, title = node, slots = s }
    end
    return { id = "bi.bg.ab", title = "Arathi Basin", openInto = true, children = children }
end

test("dial layout: four wedges sit on N, E, S and W, clockwise from the top", function()
    local L = DL()
    local pts = {}
    for i = 1, 4 do
        local w = L.Wedge(i, 4)
        pts[i] = w.x .. "," .. w.y
    end
    assertEqual(table.concat(pts, " "), "0,92 92,0 0,-92 -92,0")
    assertEqual(L.Wedge(2, 4).lx, 40, "the label sits outward from the wedge")
    assertEqual(L.Direction(1, 4) .. L.Direction(2, 4) .. L.Direction(3, 4) .. L.Direction(4, 4), "NESW")
    assertEqual(L.Direction(2, 8), "NE")
end)

test("dial layout: slices are 4, 6, 8 or 12, and 12 only on a ring with no children", function()
    local L = DL()
    assertEqual(L.ClampSlices(6), 6)
    assertEqual(L.ClampSlices(5), 4)
    assertEqual(L.ClampSlices(nil), 4)
    assertEqual(L.RingSize(12, false), 12)
    assertEqual(L.RingSize(12, true), 8)
    assertEqual(L.RingSize(6, true), 6)
end)

test("dial layout: [review 5] more items than wedges go on pages: size-1 each, the rest on the last", function()
    local L = DL()
    local pages = L.Paginate({ 1, 2, 3, 4, 5, 6, 7, 8 }, 4)
    assertEqual(#pages, 3)
    assertEqual(table.concat(pages[1], ","), "1,2,3")
    assertEqual(table.concat(pages[2], ","), "4,5,6")
    assertEqual(table.concat(pages[3], ","), "7,8")
    assertEqual(#L.Paginate({ 1, 2, 3, 4 }, 4), 1, "a full ring needs no More")
end)

test("dial layout: [exit] Categories in Arathi Basin opens on the node ring; Lumber Mill, then INC 3", function()
    local L = DL()
    local generic = { id = "bi.bg", title = "Battleground (generic)", slots = slots("g", 6) }
    local rings, open = L.Rings({ ab(), generic }, { mode = "categories", slices = 4, title = "Comms Dial" })
    assertEqual(rings[1].title, "Comms Dial")
    assertEqual(titles(rings[1]), "Arathi Basin,Battleground (generic)")
    -- red under: drop the open-into branch at the end of DL.Rings
    assertEqual(rings[open].title, "Arathi Basin", "open-into: the first active group has the flag")
    assertEqual(rings[open].parent, 1, "the hub goes up to the group ring")
    assertEqual(titles(rings[open]), "Stables,Lumber Mill,Blacksmith,More")
    local mill = rings[rings[open].items[2].target]
    assertEqual(mill.title, "Lumber Mill")
    assertEqual(titles(mill), "INC 1,INC 2,INC 3,More")
    assertEqual(mill.items[3].slot.line, "/i INC 3 Lumber Mill")
    assertEqual(rings[mill.items[4].target].prev, rings[open].items[2].target, "More's page goes back")
end)

test("dial layout: without the flag first, Categories opens on the group ring; one group opens straight on it", function()
    local L = DL()
    local mplus = { id = "bi.mplus", title = "M+", slots = slots("m", 3) }
    local mine = { id = "g1", title = "Mine", slots = slots("c", 2) }
    local rings, open = L.Rings({ mine, mplus }, { slices = 4 })
    assertEqual(open, 1)
    assertEqual(rings[1].items[1].kind, "ring")
    assertEqual(rings[rings[1].items[2].target].title, "M+")
    rings, open = L.Rings({ mplus }, { slices = 4 })
    assertEqual(rings[open].title, "M+", "a single group: no stroke for a ring of one")
    assertEqual(rings[open].parent, 1)
end)

test("dial layout: [review 5] Flat puts every callout on the first ring, highest group first, with More pages", function()
    local L = DL()
    local rings, open = L.Rings({ ab(), { id = "x", title = "X", slots = slots("x", 2) } },
        { mode = "flat", slices = 8, title = "D" })
    assertEqual(open, 1)
    -- red under: title a Flat node callout with slot.name alone (five wedges would read "INC 1")
    assertEqual(rings[1].items[1].title, "INC 1 · Stables", "a node's callout names its node")
    assertEqual(rings[1].items[1].slot.name, "INC 1", "the slot itself is unchanged")
    assertEqual(rings[1].items[8].title, "More")
    assertEqual(rings[1].next, 2)
    assertEqual(rings[2].prev, 1)
    assertEqual(rings[2].parent, 1, "the hub goes back a page")
    local total = 0
    for _, r in ipairs(rings) do
        for _, item in ipairs(r.items) do
            if item.kind == "send" then total = total + 1 end
        end
    end
    assertEqual(total, 32, "every callout reachable")
end)

test("dial layout: [phase 4] a node set below another active group is three rings deep, and named for the warning", function()
    local L = DL()
    local mine = { id = "g1", title = "Mine", slots = slots("c", 2) }
    local rings, open = L.Rings({ mine, ab() }, { slices = 4, title = "D" })
    assertEqual(open, 1, "the first group has no open-into")
    assertEqual(rings[1].depth, 1)
    -- red under: answer {} from DL.DeepGroups
    assertEqual(table.concat(L.DeepGroups(rings, open), ","), "Arathi Basin", "named once, though paged")
    rings, open = L.Rings({ ab(), mine }, { slices = 4 })
    assertEqual(#L.DeepGroups(rings, open), 0, "open-into: the nodes are the ring it opens on")
    rings, open = L.Rings({ mine, ab() }, { mode = "flat", slices = 4 })
    assertEqual(#L.DeepGroups(rings, open), 0, "Flat has no depth")
end)

test("dial layout: nothing to show is no ring at all; an empty group is left out", function()
    local L = DL()
    local rings, open = L.Rings({}, {})
    assertEqual(#rings, 0)
    assertEqual(open, 0)
    rings = L.Rings({ { id = "e", title = "Empty", slots = {} } }, {})
    assertEqual(#rings, 0)
end)

test("dial layout: the pointer follows the cursor outside the dead zone", function()
    local L = DL()
    assertNil((L.Pointer(100, 100, 102, 101)))
    local a, x, y = L.Pointer(100, 100, 200, 100)
    assertEqual(math.floor(a * 1000 + 0.5), 1571, "east is a quarter turn clockwise")
    assertEqual(x, L.POINTER)
    assertEqual(y, 0)
end)
```

In `tests/run.lua`, add `"test_dial_layout",` after `"test_pad_layout",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_dial_layout` (`attempt to index ... DialLayout (a nil value)`).

- [ ] **Step 3: Write the module**

Create `modules/Dial_Layout.lua`:
```lua
local _, NS = ...
-- modules/Dial_Layout.lua — the Comms Dial's rings and geometry (spec §11.1, §11.3). PURE: plain
-- tables in, plain tables out; no frame and no client read.
--
-- THE RINGS. A dial plan's groups, in the dial's order, become a list of rings, each one page of at
-- most `size` items: a callout (kind "send", its baked slot) or a ring to open (kind "ring", the index
-- of its target). Categories (D2): the first ring holds the groups; a group's ring holds its callouts;
-- a battleground node set's ring holds its nodes, and each node's ring its callouts. Flat: the first
-- ring holds every callout, highest group first. A ring with more items than wedges is paged: each
-- page but the last holds size - 1 items and a More wedge to the next page, and a later page's parent
-- and previous are the page before it (the hub and the wheel go back). Open-into (D9): when the first
-- group has the flag, or is the only group (owner ruling R2), the dial opens on its ring and the hub
-- goes up to the group ring. The wedge count is the dial's slices, never grown; 12 only on a ring with
-- no children (spec §11.3), and a More wedge is a child, so such a ring gets 8. In Flat a node's
-- callout is titled with its node ("INC 3 · Lumber Mill"); the slot keeps its own name.
--
-- DEPTH (spec §11.3: depth 2; depth 3 allowed, with the editor warning). Each ring records its depth,
-- 1 for the first ring, a later page keeping its first page's. DeepGroups names the node sets whose
-- callouts sit three rings deep: a set's ring at depth 2, holding node rings, that is not the ring the
-- dial opens on (open-into skips the group ring, so a set it opens into is depth 2).
--
-- THE GEOMETRY. Wedges sit clockwise from N, on-axis first: four are N, E, S and W. Offsets are from
-- the hub's center, y up. A node set's nodes are placed in their shipped order; pinning each node to
-- its compass direction waits for phase 5's battleground confirmation.

NS.DialLayout = NS.DialLayout or {}
local DL = NS.DialLayout
local L = NS.L

DL.RADIUS  = 92                                -- a wedge's center from the hub's center
DL.WEDGE   = 44                                -- a wedge button, square
DL.HUB     = 40                                -- the hub (the header button)
DL.LABEL   = 40                                -- a wedge's label, outward from the wedge's center
DL.DISC    = 2 * (DL.RADIUS + DL.WEDGE / 2 + 8)
DL.POINTER = DL.HUB / 2 + 8                    -- the pointer's distance from the hub's center
DL.DEAD    = 8                                 -- inside this, the pointer hides
DL.KEYS    = 8                                 -- the number keys 1-8 pick wedges

local SLICE_OK = { [4] = true, [6] = true, [8] = true, [12] = true }
local WINDS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local function round(x) return math.floor(x * 100 + 0.5) / 100 end

--- A dial's slices: 4, 6, 8 or 12; anything else is the default 4.
function DL.ClampSlices(v)
    if SLICE_OK[v] then return v end
    return 4
end

--- A ring's wedge count: the dial's slices, but 8 on a 12-slice dial for a ring that holds a ring.
function DL.RingSize(slices, hasChildren)
    slices = DL.ClampSlices(slices)
    if slices == 12 and hasChildren then return 8 end
    return slices
end

--- Split `items` into pages of `size`: every page but the last keeps size - 1 items, leaving the last
--- wedge for More.
--- @return table[] pages
function DL.Paginate(items, size)
    items = type(items) == "table" and items or {}
    if #items <= size then return { items } end
    local pages, i, per = {}, 1, size - 1
    while #items - i + 1 > size do
        local page = {}
        for k = i, i + per - 1 do page[#page + 1] = items[k] end
        pages[#pages + 1] = page
        i = i + per
    end
    local last = {}
    for k = i, #items do last[#last + 1] = items[k] end
    pages[#pages + 1] = last
    return pages
end

--- Wedge i of n: its angle (radians clockwise from N), its center and its label's offset from it.
function DL.Wedge(i, n, radius)
    n = math.max(1, tonumber(n) or 4)
    radius = radius or DL.RADIUS
    local a = (i - 1) * 2 * math.pi / n
    local sx, sy = math.sin(a), math.cos(a)
    return { angle = a, x = round(radius * sx), y = round(radius * sy),
        lx = round(DL.LABEL * sx), ly = round(DL.LABEL * sy) }
end

--- The spoke between wedge j and wedge j + 1 of n: its center, rotation and length.
function DL.Spoke(j, n)
    n = math.max(1, tonumber(n) or 4)
    local a = (j - 0.5) * 2 * math.pi / n
    local inner, outer = DL.HUB / 2 + 4, DL.DISC / 2 - 4
    local mid = (inner + outer) / 2
    return { x = round(mid * math.sin(a)), y = round(mid * math.cos(a)), rotation = -a, length = outer - inner }
end

--- Wedge i of n as the nearest of the eight compass winds.
function DL.Direction(i, n)
    n = math.max(1, tonumber(n) or 4)
    local deg = (i - 1) * 360 / n
    return WINDS[math.floor(deg / 45 + 0.5) % 8 + 1]
end

--- The pointer from the hub's center (cx, cy) toward the cursor (mx, my), both in screen units: its
--- angle (clockwise from N) and its offset from the hub's center. Nil inside the dead zone.
function DL.Pointer(cx, cy, mx, my)
    local dx, dy = (mx or 0) - (cx or 0), (my or 0) - (cy or 0)
    local d = math.sqrt(dx * dx + dy * dy)
    if d < DL.DEAD then return nil end
    return math.atan2(dx, dy), round(DL.POINTER * dx / d), round(DL.POINTER * dy / d)
end

-- ── the rings ───────────────────────────────────────────────────────────────────────────────

-- `node`: the node's title, for a Flat ring, where the node's own ring is gone.
local function sendEntries(slots, node)
    local out = {}
    for i, slot in ipairs(slots or {}) do
        local title = slot.name
        if node then title = L["%s · %s"]:format(tostring(slot.name), node) end
        out[i] = { kind = "send", slot = slot, title = title, icon = slot.icon }
    end
    return out
end

local function ringEntry(title, icon, entries)
    return { kind = "ring", title = title, icon = icon, sub = { title = title, entries = entries } }
end

-- A group's entry on the first ring (Categories), or nil when nothing under it can be shown.
local function groupEntry(g)
    if type(g.children) == "table" then
        local nodes = {}
        for _, c in ipairs(g.children) do
            if #(c.slots or {}) > 0 then nodes[#nodes + 1] = ringEntry(c.title, c.icon, sendEntries(c.slots)) end
        end
        if #nodes == 0 then return nil end
        return ringEntry(g.title, g.icon, nodes)
    end
    if #(g.slots or {}) == 0 then return nil end
    return ringEntry(g.title, g.icon, sendEntries(g.slots))
end

-- Every callout, highest group first, a node set's nodes in order (Flat).
local function flatEntries(groups)
    local out = {}
    for _, g in ipairs(groups) do
        local lists = {}
        if type(g.children) == "table" then
            for _, c in ipairs(g.children) do lists[#lists + 1] = { slots = c.slots, node = c.title } end
        else
            lists[1] = { slots = g.slots }
        end
        for _, list in ipairs(lists) do
            for _, e in ipairs(sendEntries(list.slots, list.node)) do out[#out + 1] = e end
        end
    end
    return out
end

--- A dial's rings, and the ring it opens on (0: nothing to show).
--- @param groups table the dial's active groups in its order (see the Interfaces block of Task 3)
--- @param opts table { mode = "categories"|"flat", slices, title }
--- @return table rings, number openRing
function DL.Rings(groups, opts)
    groups = type(groups) == "table" and groups or {}
    opts = type(opts) == "table" and opts or {}
    local slices = DL.ClampSlices(opts.slices)
    local rings = {}

    -- Add `entries` as one ring (and its pages) under `parent`, at `depth`; then each ring entry's
    -- own ring, one deeper. Returns the index of the first page.
    local function addRing(title, entries, parent, depth)
        local hasChildren = #entries > slices
        for _, e in ipairs(entries) do
            if e.kind == "ring" then hasChildren = true end
        end
        local size = DL.RingSize(slices, hasChildren)
        local pages = DL.Paginate(entries, size)
        local first = #rings + 1
        for p, items in ipairs(pages) do
            local idx = #rings + 1
            rings[idx] = { title = title, page = p, pages = #pages, size = size, items = items, depth = depth,
                parent = p == 1 and parent or idx - 1, prev = p > 1 and idx - 1 or 0, next = 0 }
            if p > 1 then
                local before = rings[idx - 1]
                before.next = idx
                before.items[#before.items + 1] = { kind = "ring", target = idx, title = L["More"], more = true }
            end
        end
        for r = first, first + #pages - 1 do
            for _, item in ipairs(rings[r].items) do
                if item.sub then
                    item.target = addRing(item.sub.title, item.sub.entries, r, depth + 1)
                    item.sub = nil
                end
            end
        end
        return first
    end

    local title = opts.title or L["Comms Dial"]
    if opts.mode == "flat" then
        local entries = flatEntries(groups)
        if #entries == 0 then return rings, 0 end
        addRing(title, entries, 0, 1)
        return rings, 1
    end
    local entries, first = {}, nil
    for _, g in ipairs(groups) do
        local e = groupEntry(g)
        if e then
            entries[#entries + 1] = e
            first = first or { entry = e, openInto = g.openInto == true }
        end
    end
    if #entries == 0 then return rings, 0 end
    addRing(title, entries, 0, 1)
    -- Owner ruling R2: a single group opens straight on its ring, as open-into does.
    if first.openInto or #entries == 1 then return rings, first.entry.target end
    return rings, 1
end

--- The node sets whose callouts sit three rings deep (spec §11.3: allowed, with the editor
--- warning): each ring at depth 2, first page only, that holds a ring other than More and is not the
--- ring the dial opens on. Their titles, in ring order.
--- @return string[]
function DL.DeepGroups(rings, openRing)
    local out = {}
    for r, ring in ipairs(type(rings) == "table" and rings or {}) do
        if ring.depth == 2 and ring.page == 1 and r ~= openRing then
            for _, item in ipairs(ring.items) do
                if item.kind == "ring" and not item.more then
                    out[#out + 1] = ring.title
                    break
                end
            end
        end
    end
    return out
end
```

- [ ] **Step 4: The TOC line and the locale key**

In `QuickComms.toc`, after the two lines
```
# Conventional: the Comms Pad frames; appends to NS.STAND_DOWN / NS.STAND_UP
modules\Pad.lua
```
add
```
# LOAD-BEARING: publishes NS.DialLayout, which modules\Dial_Render.lua and modules\Dial.lua take at load.
modules\Dial_Layout.lua
```

In `locales/enUS.lua`, add at the end:
```lua

-- The Comms Dial's rings (modules/Dial_Layout.lua)
L["More"] = "More"
L["%s · %s"] = "%s · %s"
```

- [ ] **Step 5: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0.

- [ ] **Step 6: Commit**

```bash
git add modules/Dial_Layout.lua tests/test_dial_layout.lua tests/run.lua QuickComms.toc locales/enUS.lua
git checkout -- modules/Dial_Layout.lua tests/test_dial_layout.lua tests/run.lua QuickComms.toc locales/enUS.lua
git commit -m "Dial: the pure ring layout (Categories, Flat, open-into, More pages) and wedge geometry"
```

---
### Task 4: Dial_Secure: the Relaxed-mode snippets and the ring wiring

The secure half of the dial (spec §11.2, Relaxed). One header per dial is the hub. Its `_onclick` snippet answers four buttons: `Toggle` (the dial's key and `Bindings.xml`: open on the ring the plan says, or close), `Close` (Escape, bound while open) and `RightButton` (close), `Next` / `Prev` (the mouse wheel, bound while open: a page on or back), and any other click on the hub (up a ring, or close at the top). `qc-show` shows one ring container and hides the rest, then binds Escape, the wheel and the number keys 1–8 to that ring with `SetBindingClick`, except when the dial was opened from the insecure side: `qc-display` (test mode and Preview as…, which may run with the settings window open) opens it without taking any key, so Escape still closes the window and 1–8 stay the action bar's. The ring the dial opens on is its own attribute, `qc-openRing`, never the `qc-open` snippet's name. Each wedge's click is wrapped: on the down edge nothing; a right click closes; a ring wedge (`qc-target` > 0) switches ring without sending; a callout wedge lets the click through and closes after it. The ring on screen is the snippets' own `current` global in the header's restricted environment, so **no snippet writes an attribute** (the firewall's grep finds none in this file). Every attribute and frame ref is written out of combat by `DS.Load` through SendEngine.

**Files:**
- Create: `modules/Dial_Secure.lua`
- Modify: `QuickComms.toc` (after `modules\Dial_Layout.lua`; and `modules\SendEngine.lua`'s comment line), `tests/run.lua` (suites)
- Test: `tests/test_dial_secure.lua`

**Interfaces:**
- Consumes: Task 2's `SE.NewDialHeader(name)`, `SE.NewDialRing(header)`, `SE.NewButton(parent, onPress, wrap)`, `SE.SetAttributes(frame, attrs)`, `SE.SetFrameRef(header, name, frame)`, `SE.RunSnippet(header, attr)`; Task 1's mock.
- Produces (`NS.DialSecure`, `DS`):
  - `DS.HEADER = "QuickCommsDial%d"`, `DS.TOGGLE = "Toggle"`
  - `DS.NewHeader(index) -> header|nil` (named `DS.HEADER:format(index)`, its four snippets set)
  - `DS.NewRing(header) -> frame|nil`
  - `DS.NewWedge(header, ring[, onPress]) -> button|nil` (a send button wrapped by the wedge snippets)
  - `DS.Load(header, rings, opts) -> boolean`; `rings[r] = { frame, parent, prev, next, wedges = { { button, target }… } }` (`target` 0 for a callout wedge, else the ring index), `opts = { openRing, openAt = "center"|"cursor" }`, written as the attributes `qc-openRing` and `qc-openAt`
  - `DS.Open(header) -> boolean` (runs `qc-display`: open, no key taken), `DS.Close(header) -> boolean` (out of combat only)
  - `DS.SNIPPETS` (`onclick`, `open`, `display`, `show`, `close`, `pre`, `post`; for tests)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_dial_secure.lua`:
```lua
-- tests/test_dial_secure.lua — modules/Dial_Secure.lua (spec §11.2, Relaxed mode): a dial built by hand
-- from its header, ring containers and wedges opens on the key, switches rings, sends once and closes,
-- in and out of combat, with Escape, the number keys and the wheel bound only while it is open.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

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

-- Ring 1 holds a ring wedge (to ring 2) and a callout; ring 2 holds two callouts, goes up to ring 1 and
-- pages on to ring 3; ring 3 holds one callout and goes back to ring 2.
local function built(opts)
    opts = opts or {}
    local NS, m = T.enableAddon()
    local DS, SE = NS.DialSecure, NS.SendEngine
    local h = DS.NewHeader(7)
    local function wedge(ring, line, target)
        local b = DS.NewWedge(h, ring)
        if line then SE.Arm(b, line, { calloutId = "c-" .. line, surfaceId = "d9", chatType = "PARTY", name = line }) end
        return { button = b, target = target or 0 }
    end
    local frames = { DS.NewRing(h), DS.NewRing(h), DS.NewRing(h) }
    local rings = {
        { frame = frames[1], parent = 0, prev = 0, next = 0, wedges = { wedge(frames[1], nil, 2), wedge(frames[1], "/p one") } },
        { frame = frames[2], parent = 1, prev = 0, next = 3, wedges = { wedge(frames[2], "/p two"), wedge(frames[2], "/p three") } },
        { frame = frames[3], parent = 2, prev = 2, next = 0, wedges = { wedge(frames[3], "/p four") } },
    }
    assertTrue(DS.Load(h, rings, { openRing = opts.openRing or 1, openAt = opts.openAt }))
    return NS, m, h, frames, rings
end

local function shown(frames)
    for r, f in ipairs(frames) do
        if f:IsShown() then return r end
    end
    return nil
end

test("dial secure: the header is QuickCommsDial<n>, hidden until the toggle opens it; open, the dial owns Escape and 1-8", function()
    local _, m, h, frames, rings = built()
    assertEqual(h:GetName(), "QuickCommsDial7")
    assertFalse(h:IsShown())
    m.__click(h, "Toggle")
    assertTrue(h:IsShown())
    assertEqual(shown(frames), 1)
    assertTrue(m.restrictedBindings.ESCAPE ~= nil)
    assertEqual(m.restrictedBindings["2"].target, rings[1].wedges[2].button:GetName())
    m.__click(h, "Toggle")
    assertFalse(h:IsShown())
    assertNil(shown(frames))
    -- red under: drop `self:ClearBindings()` from the close snippet
    assertNil(m.restrictedBindings.ESCAPE, "released on close")
end)

test("dial secure: [exit] a group wedge opens its ring (the two-stroke); a callout wedge sends once and closes", function()
    local _, m, h, frames, rings = built()
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button)
    assertEqual(shown(frames), 2)
    assertEqual(#m.sentMacros, 0, "a group wedge sends nothing")
    m.__click(rings[2].wedges[2].button)
    assertEqual(#m.sentMacros, 1)
    assertEqual(m.sentMacros[1].text, "/p three")
    assertFalse(h:IsShown(), "the dial closes after a send")
end)

test("dial secure: [review 2] right click, Escape and the hub close without sending; the hub goes up a ring first", function()
    local NS, m, h, frames, rings = built()
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button)
    m.__click(h, "LeftButton")
    assertEqual(shown(frames), 1, "the hub goes up a ring")
    m.__click(rings[1].wedges[2].button, "RightButton")
    assertFalse(h:IsShown())
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0, "a right click is no press")
    m.__click(h, "Toggle")
    assertTrue(m.__pressKey("ESCAPE"))
    assertFalse(h:IsShown())
    m.__click(h, "Toggle")
    m.__click(h, "LeftButton")
    assertFalse(h:IsShown(), "the hub on the first ring closes")
    assertEqual(#m.sentMacros, 0)
end)

test("dial secure: [review 5] the wheel turns pages; the number keys pick the shown ring's wedges", function()
    local _, m, h, frames = built({ openRing = 2 })
    m.__click(h, "Toggle")
    assertEqual(shown(frames), 2, "opens on the ring it is told")
    m.__pressKey("MOUSEWHEELDOWN")
    assertEqual(shown(frames), 3)
    m.__pressKey("MOUSEWHEELUP")
    assertEqual(shown(frames), 2)
    m.__pressKey("1")
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p two")
    assertFalse(h:IsShown())
    assertFalse(m.__pressKey("1"), "the number keys are released with the dial")
end)

test("dial secure: [exit] in combat the dial opens, switches rings and sends, with nothing blocked", function()
    local NS, m, h, _, rings = built()
    combat(m, true)
    m.__click(h, "Toggle")
    m.__click(rings[1].wedges[1].button)
    m.__click(rings[2].wedges[1].button)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p two")
    assertFalse(h:IsShown())
    assertEqual(#m.blocked, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 1, "tracked like a chip's send")
end)

test("dial secure: open at the cursor anchors the hub to it; a dial with no ring opens nothing", function()
    local NS, m, h = built({ openAt = "cursor" })
    m.__click(h, "Toggle")
    local _, rel = h:GetPoint(1)
    assertEqual(rel, "$cursor")
    m.__click(h, "Toggle")
    assertTrue(NS.DialSecure.Load(h, {}, {}))
    m.__click(h, "Toggle")
    assertFalse(h:IsShown())
end)

test("dial secure: [review 6] Open from the insecure side takes no key; the key still closes it; out of combat only", function()
    local NS, m, h, frames, rings = built({ openRing = 2 })
    assertTrue(NS.DialSecure.Open(h))
    assertTrue(h:IsShown())
    assertEqual(shown(frames), 2, "on the ring Load named (qc-openRing)")
    -- red under: drop the `if not display` guard from the show snippet
    assertNil(next(m.restrictedBindings), "Escape, 1-8 and the wheel stay the game's (the settings window may be open)")
    m.__click(rings[2].wedges[1].button)
    assertEqual(#m.sentMacros, 1, "a wedge still works")
    assertFalse(h:IsShown())
    assertTrue(NS.DialSecure.Open(h))
    m.__click(h, "Toggle")
    assertFalse(h:IsShown(), "the key closes it")
    m.__click(h, "Toggle")
    assertTrue(m.restrictedBindings.ESCAPE ~= nil, "opened by the key, it takes them again")
    m.__click(h, "Toggle")
    assertTrue(NS.DialSecure.Open(h))
    combat(m, true)
    assertFalse(NS.DialSecure.Close(h))
    assertTrue(h:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("dial secure: [firewall] no snippet writes an attribute; the ring on screen lives in the header's environment", function()
    local NS = T.newAddon()
    for name, body in pairs(NS.DialSecure.SNIPPETS) do
        assertTrue(not body:find("SetAttribute", 1, true), name)
    end
end)
```

In `tests/run.lua`, add `"test_dial_secure",` after `"test_sendengine",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_dial_secure` (`attempt to index ... DialSecure (a nil value)`).

- [ ] **Step 3: Write the module**

Create `modules/Dial_Secure.lua`:
```lua
local _, NS = ...
-- modules/Dial_Secure.lua — the Comms Dial's secure structure (spec §11.2), RELAXED MODE ONLY (the C7
-- fallback in docs/brainstorm/go-no-go/round-4-build-checks.md: the hold, flick and release dial is the
-- upgrade once C7 is verified). One header per dial, named QuickCommsDial<n> for its place in the dial
-- order, is the hub; under it one protected container per ring, holding that ring's wedges; each wedge
-- IS its slot's send button (spec §9.1), armed out of combat with the baked line.
--
-- The snippets below are restricted Lua the client runs in the header's own environment, whose globals
-- persist from one snippet to the next: `current` is the ring on screen, nil while the dial is closed,
-- and `display` is set while an insecure open (test mode, Preview as…) holds it. They show and hide the
-- rings, anchor the hub, and bind Escape, the mouse wheel and the number keys 1-8 while the dial is
-- open from its key (SetBindingClick, released by ClearBindings on close) — all allowed in combat. An
-- insecure open takes no key, because the settings window may be open behind it. They NEVER write an attribute: every attribute and frame ref is written out of combat by
-- DS.Load, through modules/SendEngine.lua, the only secure writer (tests/test_sendengine.lua greps
-- this file like every other).
--
-- The header's click (_onclick): Toggle (the dial's key, Bindings.xml) opens or closes; Close (Escape)
-- and RightButton close; Next and Prev (the wheel) turn a page; any other click is the hub: up a ring,
-- or close on the first ring. A wedge's click is wrapped: the down edge does nothing (a wedge acts on
-- the up edge), a right click closes, a ring wedge (attribute qc-target > 0) shows its ring and sends
-- nothing, and a callout wedge lets the click through, then closes the dial.

NS.DialSecure = NS.DialSecure or {}
local DS = NS.DialSecure
local SE = NS.SendEngine

DS.HEADER = "QuickCommsDial%d"   -- Bindings.xml clicks these by name
DS.TOGGLE = "Toggle"             -- the button the key and Bindings.xml click the header with

local ONCLICK = [[
if button == "Toggle" then
    if current then
        self:RunAttribute("qc-close")
    else
        display = nil
        self:RunAttribute("qc-open")
    end
elseif button == "Close" or button == "RightButton" then
    self:RunAttribute("qc-close")
elseif button == "Next" or button == "Prev" then
    if current then
        local to = self:GetAttribute((button == "Next" and "qc-next-" or "qc-prev-") .. current) or 0
        if to > 0 then self:RunAttribute("qc-show", to) end
    end
elseif current then
    local up = self:GetAttribute("qc-parent-" .. current) or 0
    if up > 0 then
        self:RunAttribute("qc-show", up)
    else
        self:RunAttribute("qc-close")
    end
end
]]

local OPEN = [[
if (self:GetAttribute("qc-rings") or 0) < 1 then return end
if self:GetAttribute("qc-openAt") == "cursor" then
    self:ClearAllPoints()
    self:SetPoint("CENTER", "$cursor")
end
self:Show()
self:RunAttribute("qc-show", self:GetAttribute("qc-openRing") or 1)
]]

-- Opened from the insecure side (test mode, Preview as…), perhaps with the settings window open: the
-- same open, but no key is taken, so Escape still closes the window and 1-8 stay the action bar's.
local DISPLAY = [[
display = true
self:RunAttribute("qc-open")
]]

local SHOW = [[
local r = tonumber((...)) or 0
local count = self:GetAttribute("qc-rings") or 0
if r < 1 or r > count then return end
for i = 1, count do
    local ring = self:GetFrameRef("ring" .. i)
    if ring then
        if i == r then ring:Show() else ring:Hide() end
    end
end
current = r
self:ClearBindings()
if not display then
    self:SetBindingClick(true, "ESCAPE", self, "Close")
    self:SetBindingClick(true, "MOUSEWHEELUP", self, "Prev")
    self:SetBindingClick(true, "MOUSEWHEELDOWN", self, "Next")
    local n = self:GetAttribute("qc-n-" .. r) or 0
    for i = 1, n do
        local name = self:GetAttribute("qc-name-" .. r .. "-" .. i)
        if name and i <= 8 then self:SetBindingClick(true, tostring(i), name, "LeftButton") end
    end
end
]]

local CLOSE = [[
local count = self:GetAttribute("qc-rings") or 0
for i = 1, count do
    local ring = self:GetFrameRef("ring" .. i)
    if ring then ring:Hide() end
end
current = nil
display = nil
self:ClearBindings()
self:Hide()
]]

local WEDGE_PRE = [[
if down then return false end
if button == "RightButton" then
    owner:RunAttribute("qc-close")
    return false
end
local target = self:GetAttribute("qc-target") or 0
if target > 0 then
    owner:RunAttribute("qc-show", target)
    return false
end
return button, "sent"
]]

local WEDGE_POST = [[
owner:RunAttribute("qc-close")
]]

DS.SNIPPETS = { onclick = ONCLICK, open = OPEN, display = DISPLAY, show = SHOW, close = CLOSE, pre = WEDGE_PRE,
    post = WEDGE_POST }

--- A dial's header (its hub), named for its place in the dial order, carrying its snippets. Out of
--- combat only; nil in combat.
function DS.NewHeader(index)
    local header = SE.NewDialHeader(DS.HEADER:format(index))
    if not header then return nil end
    SE.SetAttributes(header, { _onclick = ONCLICK, ["qc-open"] = OPEN, ["qc-display"] = DISPLAY, ["qc-show"] = SHOW,
        ["qc-close"] = CLOSE })
    return header
end

--- One ring's container under the header. Out of combat only.
function DS.NewRing(header)
    return SE.NewDialRing(header)
end

--- One wedge: a send button in `ring`, its click wrapped by the header's wedge snippets. Out of combat.
function DS.NewWedge(header, ring, onPress)
    return SE.NewButton(ring, onPress, { header = header, pre = WEDGE_PRE, post = WEDGE_POST })
end

--- Hand the header a plan's rings: per ring its container, its parent, previous and next page, and its
--- wedges ({ button, target }: 0 for a callout, else the ring a click opens); the ring it opens on and
--- where it opens. Out of combat only.
--- @return boolean loaded
function DS.Load(header, rings, opts)
    if NS.Compat.InCombat() then return false end
    opts = opts or {}
    -- The ring it opens on has its own attribute: `qc-open` is the open snippet's.
    local attrs = { ["qc-rings"] = #rings, ["qc-openRing"] = opts.openRing or 1,
        ["qc-openAt"] = opts.openAt == "cursor" and "cursor" or "center" }
    for r, ring in ipairs(rings) do
        attrs["qc-parent-" .. r] = ring.parent or 0
        attrs["qc-prev-" .. r] = ring.prev or 0
        attrs["qc-next-" .. r] = ring.next or 0
        attrs["qc-n-" .. r] = #ring.wedges
        for i, w in ipairs(ring.wedges) do
            attrs["qc-name-" .. r .. "-" .. i] = w.button:GetName()
            SE.SetAttributes(w.button, { ["qc-target"] = w.target or 0 })
        end
        SE.SetFrameRef(header, "ring" .. r, ring.frame)
    end
    return SE.SetAttributes(header, attrs)
end

--- Open the dial from the insecure side (test mode, Preview as…), taking no key. Out of combat only.
function DS.Open(header)
    return SE.RunSnippet(header, "qc-display")
end

--- Close the dial from the insecure side (a rebuild, a release). Out of combat only.
function DS.Close(header)
    return SE.RunSnippet(header, "qc-close")
end
```

- [ ] **Step 4: The TOC line**

In `QuickComms.toc`, after the `modules\Dial_Layout.lua` line, add:
```
# LOAD-BEARING: publishes NS.DialSecure, which modules\Dial.lua takes as a load-time upvalue.
modules\Dial_Secure.lua
```
and, because `modules/Dial_Secure.lua` takes `NS.SendEngine` at load, retag the publisher's line: replace
```
# Conventional: the only secure writer; appends to NS.STAND_DOWN / NS.STAND_UP (and, Task 4, NS.FEATURE_EVENTS)
modules\SendEngine.lua
```
with
```
# LOAD-BEARING: the only secure writer; publishes NS.SendEngine, which modules\Dial_Secure.lua takes as a load-time upvalue; appends to NS.STAND_DOWN / NS.STAND_UP (and, Task 4, NS.FEATURE_EVENTS)
modules\SendEngine.lua
```

- [ ] **Step 5: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0, including `test_sendengine`'s `[firewall]` (this file names no template, calls no attribute writer, and calls a header's `SetFrameRef`, `WrapScript` or `Execute` only through SendEngine's dotted API).

- [ ] **Step 6: Commit**

```bash
git add modules/Dial_Secure.lua tests/test_dial_secure.lua tests/run.lua QuickComms.toc
git checkout -- modules/Dial_Secure.lua tests/test_dial_secure.lua tests/run.lua QuickComms.toc
git commit -m "Dial: the Relaxed-mode secure header, its ring snippets and the wedge wrap"
```

---
### Task 5a: The dial's data: member rows, keys, and its position through the seam

A dial's fields become member rows (architecture-§5), like a pad's: `dial.name`, `dial.enabled`, `dial.mode` (Categories or Flat), `dial.slices` (4, 6, 8 or 12), `dial.openAt` (its place or the cursor), `dial.point` (its place, the structured `point` type the pad uses) and `dial.key` (a new structured `key` type: drawn by the Comms Dial page's capture box, typed on the CLI). Relaxed is the only interaction in v0.1.0, so there is no interaction, delay or tap-action row (the C7 upgrade brings them) and no depth row (owner ruling R5); a new dial stores `interaction = "relaxed"`. `Library.SetSurfacePoint("dial", …)` now goes through the seam like the pad's. The two rows mirror the `pad.point` row as the phase-3 fix wave left it (Pre-flight P1): `dial.point` and `dial.key` have `default = false` ("the default place", "no key") and sit in `settings/Schema.lua`'s `resetExempt`, so a named `/qc reset dial.point` or `/qc reset dial.key` reaches them and the page's Defaults keeps them; an offset off the screen is refused by `Lib.ValidPoint` (`offScreen`). A key is stored upper-case (`shift-g` → `SHIFT-G`), `""` / `none` clear it (`false`), and the row refuses what the open dial itself uses (Escape, the left and right mouse buttons and the mouse wheel whatever the modifiers, and 1–8 without one) and a key another dial has, naming that dial (spec §18).

**Files:**
- Modify: `modules/Library.lua` (`SURFACE_DEFAULTS.dial`; `Lib.TEMPLATES`; `Lib.MemberIds`; `Lib.SetSurfacePoint`; a new keys section)
- Modify: `settings/SchemaMembers.lua` (the `WHY` table; the choice lists; the dial rows; the `group.openInto` tooltip)
- Modify: `settings/Schema.lua` (`INSTANCE`, `NO_MEMBER`, `VALID_TYPES`, `resetExempt`)
- Modify: `settings/Editors.lua` (`Ed.STRUCTURAL`, `STRUCTURED`)
- Modify: `settings/Slash.lua` (the structured-rows comment, `parsePoint`, `PARSE`, `FORMAT`, the descriptor's `parse`)
- Modify: `locales/enUS.lua`
- Test: `tests/test_members.lua`, `tests/test_library.lua`

**Interfaces:**
- Consumes: the phase-3 seam (`NS.SchemaRuntime.Set/Get`, `Settings.EditingId(kind)`), `Lib.Member(kind, id)` (already answers `"dial"`), `Lib.Touch`, `Lib.ValidPoint` (with `offScreen`, phase-3 fix wave), the `WHY.offScreen` reason.
- Produces:
  - member rows `dial.name|enabled|mode|slices|openAt|point|key` (`page = "dials"`; tabs `General`, `Groups`, `Wheel`, `Binding`)
  - `Lib.TEMPLATES.dial = { name, enabled, mode, slices, openAt, key = false, point = false }`
  - `Lib.DIAL_DEFAULT_POINT = { "CENTER", "CENTER", 0, 0 }`
  - `Lib.MemberIds("dial") -> { id… }` (the dial order)
  - `Lib.SetSurfacePoint(kind, sid, point) -> boolean` (both kinds through the seam's `<kind>.point`)
  - `Lib.KeyValue(v) -> string|false`, `Lib.ValidKey(v) -> ok, reason`, `Lib.KeyOwner(key, exceptId) -> id|nil`
  - the `key` row type (`VALID_TYPES`, `Ed.Scalar` skips it, the CLI's `PARSE.key` / `FORMAT.key`)

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_members.lua`:
```lua
-- ── the Comms Dial's member rows (phase 4) ──────────────────────────────────────────────────

test("members: [phase 4] a dial's fields are member rows, and its position goes through SetSurfacePoint", function()
    local NS, S, Lib = boot()
    assertTrue(S.Set("dial.slices", 6, "d2"))
    assertEqual(NS.db.profile.dials.d2.slices, 6)
    assertFalse((S.Set("dial.slices", 5, "d2")))
    assertTrue(S.Set("dial.mode", "flat", "d2"))
    assertEqual(NS.db.profile.dials.d2.mode, "flat")
    local fields = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.LIBRARY_CHANGED, function(_, kind, id, field)
        fields[#fields + 1] = tostring(kind) .. ":" .. tostring(id) .. ":" .. tostring(field)
    end)
    assertTrue(Lib.SetSurfacePoint("dial", "d2", { "CENTER", "CENTER", 0, 120 }))
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
    -- red under: keep Library's own dial branch in SetSurfacePoint (it announces with no field)
    assertEqual(table.concat(fields, ","), "dial:d2:dial.point", "the row's onChange, through Library.Touch")
    assertEqual(Lib.MemberIds("dial")[1], "d2")
    assertEqual(S.Get("dial.openAt"), "center", "no id: the first dial the page lists")
    local id = Lib.CreateSurface("dial", "Lead")
    assertEqual(NS.db.profile.dials[id].interaction, "relaxed", "Relaxed is the only interaction in v0.1.0")
end)

test("members: [review 4] a dial's key is stored upper-case; none clears it; a reserved key or another dial's is refused", function()
    local NS, S, Lib = boot()
    assertTrue(S.Set("dial.key", "shift-g", "d2"))
    assertEqual(NS.db.profile.dials.d2.key, "SHIFT-G")
    local other = Lib.CreateSurface("dial", "Lead")
    local ok, _, why = S.Set("dial.key", "SHIFT-G", other)
    assertFalse(ok)
    -- red under: drop the KeyOwner check from keyCheck in settings/SchemaMembers.lua
    assertEqual(why, "SHIFT-G already opens Comms Dial.")
    assertNil(NS.db.profile.dials[other].key)
    ok, _, why = S.Set("dial.key", "Escape", other)
    assertFalse(ok)
    assertEqual(why, "Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot open a dial: the open dial uses them.")
    assertFalse((S.Set("dial.key", "CTRL-BUTTON1", other)))
    assertFalse((S.Set("dial.key", "SHIFT-MOUSEWHEELDOWN", other)), "the open dial turns pages with the wheel")
    assertFalse((S.Set("dial.key", "1", other)), "and picks wedges with 1-8")
    assertTrue(S.Set("dial.key", "ALT-1", other), "a modified number is another key")
    assertTrue(S.Set("dial.key", "none", "d2"))
    assertEqual(NS.db.profile.dials.d2.key, false)
    assertTrue(S.Set("dial.key", "SHIFT-G", other), "free again")
end)

test("members: [phase 4] the CLI types and prints a dial's key and position", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("set dial.key ctrl-f")
    assertEqual(NS.db.profile.dials.d2.key, "CTRL-F")
    NS.addon:OnSlashCommand("set dial.point 10 -20")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,10,-20")
    m.prints = {}
    NS.addon:OnSlashCommand("get dial.key")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("CTRL-F", 1, true) ~= nil, text)
    NS.addon:OnSlashCommand("set dial.key none")
    m.prints = {}
    NS.addon:OnSlashCommand("get dial.key")
    text = table.concat(m.prints, "\n")
    assertTrue(text:find("none", 1, true) ~= nil, text)
end)

test("members: [phase 4] an off-screen dial.point is refused; `/qc reset` brings the dial back and frees its key", function()
    local NS, m = T.enableAddon()
    NS.State.editing.dial = "d2"
    NS.addon:OnSlashCommand("set dial.point 10 -20")
    NS.addon:OnSlashCommand("set dial.key g")
    m.prints = {}
    NS.addon:OnSlashCommand("set dial.point 90000 0")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,10,-20", "refused: nothing stored")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, table.concat(m.prints, "\n"))
    -- red under: dial.point has no default ("has no default to restore")
    NS.addon:OnSlashCommand("reset dial.point")
    assertTrue(NS.db.profile.dials.d2.point == false, "the default place")
    -- red under: dial.key has no default
    NS.addon:OnSlashCommand("reset dial.key")
    assertTrue(NS.db.profile.dials.d2.key == false, "no key")
end)
```

Append to `tests/test_library.lua`:
```lua
test("library: [phase 4] keys: upper-cased, none is false; what the open dial uses is reserved", function()
    local _, Lib = boot()
    assertEqual(Lib.KeyValue(" shift-g "), "SHIFT-G")
    assertEqual(Lib.KeyValue("none"), false)
    assertEqual(Lib.KeyValue(""), false)
    assertTrue(Lib.ValidKey("SHIFT--"), "the minus key with a modifier")
    assertTrue(Lib.ValidKey(false))
    T.assertFalse((Lib.ValidKey("ESCAPE")))
    T.assertFalse((Lib.ValidKey("ALT-BUTTON2")))
    -- red under: drop MOUSEWHEELUP from RESERVED_KEYS (the open dial turns its pages with it)
    T.assertFalse((Lib.ValidKey("SHIFT-MOUSEWHEELUP")))
    -- red under: drop RESERVED_BARE (an open dial's 1-8 pick its wedges)
    T.assertFalse((Lib.ValidKey("3")))
    assertTrue(Lib.ValidKey("CTRL-3"), "a modified number is another key")
    assertTrue(Lib.ValidKey("9"))
    T.assertFalse((Lib.ValidKey("SHIFT G")))
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_members` (no `dial.slices` row) and `test_library` (`KeyValue` is nil).

- [ ] **Step 3: Library: the dial's template, its ids and its position**

In `modules/Library.lua`, replace
```lua
    dial = { mode = "categories", slices = 4, depth = 2, openAt = "center", delay = 0.3,
        interaction = "quick", key = nil, tapAction = "first" },
}
```
with
```lua
    -- Relaxed is the only interaction in v0.1.0 (the C7 fallback, round-4 record). `delay` and
    -- `tapAction` are kept for the hold, flick and release upgrade, and `depth` until owner ruling R5
    -- gives it a meaning; nothing reads them yet.
    dial = { mode = "categories", slices = 4, depth = 2, openAt = "center", delay = 0.3,
        interaction = "relaxed", key = nil, tapAction = "first" },
}
```
replace
```lua
    builtin = { enabled = true, hidden = {} },
}
```
with
```lua
    builtin = { enabled = true, hidden = {} },
    -- `key` and `point` are false, not nil, for the same reason as above: false is "no key" and "the
    -- default place".
    dial = { name = "", enabled = true, mode = SURFACE_DEFAULTS.dial.mode, slices = SURFACE_DEFAULTS.dial.slices,
        openAt = SURFACE_DEFAULTS.dial.openAt, key = false, point = false },
}

--- A dial's place when its `point` is unset: the middle of the screen (read at run time by
--- modules/Dial.lua, the CLI and the Comms Dial page).
Lib.DIAL_DEFAULT_POINT = { "CENTER", "CENTER", 0, 0 }
```
In `Lib.MemberIds`, replace
```lua
--- order, the pads in the pad order. The seam's fallback when a page has selected nothing
--- (settings/Schema.lua Settings.EditingId), and the pages' picker order.
--- @param kind string "callout" | "group" | "pad"
--- @return string[]
function Lib.MemberIds(kind)
    if not (NS.db and NS.db.profile) then return {} end
    local p = P()
    local out = {}
    if kind == "pad" then
        for _, id in ipairs(p.padOrder) do
            if p.pads[id] then out[#out + 1] = id end
        end
        return out
    end
```
with
```lua
--- order, the pads in the pad order, the dials in the dial order. The seam's fallback when a page
--- has selected nothing (settings/Schema.lua Settings.EditingId), and the pages' picker order.
--- @param kind string "callout" | "group" | "pad" | "dial"
--- @return string[]
function Lib.MemberIds(kind)
    if not (NS.db and NS.db.profile) then return {} end
    local p = P()
    local out = {}
    if kind == "pad" or kind == "dial" then
        local set = kind == "pad" and p.pads or p.dials
        for _, id in ipairs(kind == "pad" and p.padOrder or p.dialOrder) do
            if set[id] then out[#out + 1] = id end
        end
        return out
    end
```
(the doc comment's first two lines stay as they are.)

Replace the whole of `Lib.SetSurfacePoint` and its doc comment:
```lua
--- Set, or with nil clear, a surface's saved anchor (spec §5.1). A pad's is the `pad.point` member
--- row, through the seam: the drag, the X/Y boxes and Reset position all write it there. A dial's has
--- no row until the dial's page (phase 4) and stays Library's write. A plain copy is stored, so the
--- caller's table never aliases the profile.
--- @param point table|nil { point, relativePoint, x, y }: two strings, then two numbers
--- @return boolean
function Lib.SetSurfacePoint(kind, sid, point)
    if kind == "pad" then return (NS.SchemaRuntime.Set("pad.point", point, sid)) == true end
    local s = kind == "dial" and surface(kind, sid)
    if not s or not Lib.ValidPoint(point) then return false end
    s.point = point and { point[1], point[2], point[3], point[4] } or nil
    announce(kind, sid)
    return true
end
```
with
```lua
--- Set, or with nil clear, a surface's saved anchor (spec §5.1): the `pad.point` or `dial.point`
--- member row, through the seam (the seam stores a copy, so the caller's table never aliases the
--- profile). The pad's drag, the X/Y boxes and Reset position all write it here.
--- @param point table|nil { point, relativePoint, x, y }: two strings, then two numbers
--- @return boolean
function Lib.SetSurfacePoint(kind, sid, point)
    if kind ~= "pad" and kind ~= "dial" then return false end
    return (NS.SchemaRuntime.Set(kind .. ".point", point, sid)) == true
end
```

- [ ] **Step 4: Library: keys**

In `modules/Library.lua`, directly before `-- ── prepare ──…`, add:
```lua
-- ── dial keys (spec §9.4, §18) ──────────────────────────────────────────────────────────────

-- Keys a dial may not take, because the open dial uses them. Whatever the modifiers: Escape (the game
-- menu, and the open dial's close), the left and right mouse buttons, and the mouse wheel (the open
-- dial turns its pages with it). Without a modifier: 1-8, which pick the open dial's wedges (ALT-1 is
-- another key, and free).
local RESERVED_KEYS = { ESCAPE = true, BUTTON1 = true, BUTTON2 = true, MOUSEWHEELUP = true, MOUSEWHEELDOWN = true }
local RESERVED_BARE = { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, ["6"] = true,
    ["7"] = true, ["8"] = true }

--- A key as stored: trimmed and upper-cased; nil, false, "" and "none" are no key (false).
--- @return string|false|any
function Lib.KeyValue(v)
    if v == nil or v == false then return false end
    if type(v) ~= "string" then return v end
    local t = v:match("^%s*(.-)%s*$"):upper()
    if t == "" or t == "NONE" then return false end
    return t
end

--- Whether `v` is a key a dial may take: no key, or one key name with optional modifiers (no space,
--- at most 40 characters), not a reserved key.
--- @return boolean ok, string|nil reason ("badKey" | "reservedKey")
function Lib.ValidKey(v)
    v = Lib.KeyValue(v)
    if v == false then return true end
    if type(v) ~= "string" or #v > 40 or v:find("%s") then return false, "badKey" end
    local base = v:match("^.*%-(.+)$") or v
    if RESERVED_KEYS[base] or RESERVED_BARE[v] then return false, "reservedKey" end
    return true
end

--- The other dial that already has `key` (spec §18: one key opens one dial), or nil.
function Lib.KeyOwner(key, exceptId)
    key = Lib.KeyValue(key)
    if type(key) ~= "string" then return nil end
    local ids = {}
    for id, d in pairs(P().dials) do
        if id ~= exceptId and type(d) == "table" and d.key == key then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids[1]
end

```

- [ ] **Step 5: The dial rows**

In `settings/SchemaMembers.lua`, in the `WHY` table, after `badChoice = …,` add:
```lua
    badKey    = L["A key is one key, with ALT-, CTRL- or SHIFT- in front if you like."],
    reservedKey = L["Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot open a dial: the open dial uses them."],
```
After the line `local FADE = choices(…)`, add:
```lua
local MODE = choices({ { "categories", L["Categories"] }, { "flat", L["Flat"] } })
local OPEN_AT = choices({ { "center", L["At its place"] }, { "cursor", L["At the cursor"] } })
local SLICES = {}
for i, n in ipairs({ 4, 6, 8, 12 }) do SLICES[i] = { value = n, text = tostring(n) } end

-- A dial's key: none, or a key that is not reserved and that no other dial has (spec §18: the editor
-- refuses, naming the other dial). The seam then stores it as Library.KeyValue normalizes it.
local function keyCheck(v, id)
    local ok, code = Lib.ValidKey(v)
    if not ok then return false, WHY[code] end
    local other = Lib.KeyOwner(v, id)
    if other then
        local d = NS.db.profile.dials[other]
        return false, L["%s already opens %s."]:format(Lib.KeyValue(v), tostring(d and d.name or other))
    end
    return true
end
```
Replace the `group.openInto` row's `desc`:
```lua
      desc = L["When this is the first active group on a Comms Dial, the dial opens on its callouts. The Comms Dial arrives in a later build."],
```
with
```lua
      desc = L["When this is the first active group on a Comms Dial, the dial opens straight on its ring, and the middle of the dial goes back to the groups."],
```
Before the `-- A built-in set's overlay (spec §12.2)…` comment, add:
```lua
    -- Comms Dial page (spec §11, §13.1). Relaxed is the only interaction in v0.1.0, so there is no
    -- interaction, delay or tap-action row (Quick mode brings them with the C7 upgrade), and no depth
    -- row (owner ruling R5: depth is §11.3's limit, warned about on the Groups tab).
    { path = "dial.name", instance = "dial", type = "string", dialogControl = "EditBox", maxLetters = Lib.NAME_MAX,
      page = "dials", group = GENERAL, label = L["Name"],
      desc = L["What the lists and the dial's first ring call this dial. Press Enter to apply."],
      validate = check(Lib.ValidName) },
    { path = "dial.enabled", instance = "dial", type = "bool", default = T.dial.enabled,
      page = "dials", group = GENERAL, label = L["Enabled"],
      desc = L["Build this dial and bind its key. A disabled dial keeps its groups, key and settings."] },
    { path = "dial.mode", instance = "dial", type = "string", default = T.dial.mode, values = MODE,
      page = "dials", group = L["Groups"], label = L["Show groups as"],
      desc = L["Categories: the first ring holds your groups and a click opens one. Flat: the first ring holds callouts, highest group first, with More for the rest."],
      validate = oneOf(MODE) },
    { path = "dial.slices", instance = "dial", type = "number", default = T.dial.slices, values = SLICES,
      page = "dials", group = L["Wheel"], label = L["Wedges per ring"],
      desc = L["How many wedges a ring has. A ring with more puts the rest behind More. 12 applies only to a ring of callouts."],
      validate = oneOf(SLICES) },
    { path = "dial.openAt", instance = "dial", type = "string", default = T.dial.openAt, values = OPEN_AT,
      page = "dials", group = L["Wheel"], label = L["Open at"],
      desc = L["Where the dial opens: at its place (set below), or wherever the cursor is."],
      validate = oneOf(OPEN_AT) },
    -- Position's and Key's default is false (the default place, no key), so `/qc reset dial.point` and
    -- `/qc reset dial.key` reach them; the page's Defaults keeps both (settings/Schema.lua
    -- resetExempt), as its tooltip says. As the pad.point row.
    { path = "dial.point", instance = "dial", type = "point", default = false,
      page = "dials", group = L["Wheel"], label = L["Position"],
      desc = L["Where the dial opens at its place. Type an offset from the middle of the screen."],
      validate = check(Lib.ValidPoint) },
    { path = "dial.key", instance = "dial", type = "key", default = false,
      page = "dials", group = L["Binding"], label = L["Key"],
      desc = L["The key that opens and closes this dial. One key opens one dial. Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot be used: the open dial uses them."],
      validate = keyCheck, normalize = Lib.KeyValue },

```
In the file's header comment (the phrases wrap across its lines; rewrap the paragraph after the change), change `callout, a group, a Comms Pad or a built-in set's overlay` to `callout, a group, a Comms Pad, a Comms Dial or a built-in set's overlay`, and `Three rows hold a table (a pad's point, a group's When, a set's hidden callouts): their pages draw their own controls` to `Four row types are structured (a pad's or a dial's point, a group's When, a set's hidden callouts, a dial's key): their pages draw their own controls`.

- [ ] **Step 6: The seam knows dials and the key type**

In `settings/Schema.lua`, replace
```lua
local INSTANCE = { callout = true, group = true, pad = true, builtin = true }
```
with
```lua
local INSTANCE = { callout = true, group = true, pad = true, dial = true, builtin = true }
```
in `NO_MEMBER`, after the `pad = …,` line, add:
```lua
    dial    = L["No dial to edit: make one on the Comms Dial page."],
```
and replace
```lua
-- `point`, `when` and `idset` are the structured member rows (settings/SchemaMembers.lua): a table
-- each, drawn by their own controls on the editor pages and typed and printed on the CLI by
-- settings/Slash.lua's parse and format hooks.
local VALID_TYPES = { bool = true, number = true, string = true, point = true, when = true, idset = true }
```
with
```lua
-- `point`, `when`, `idset` and `key` are the structured member rows (settings/SchemaMembers.lua): each
-- drawn by its own control on its editor page (a dial's key by a capture box) and typed and printed on
-- the CLI by settings/Slash.lua's parse and format hooks.
local VALID_TYPES = { bool = true, number = true, string = true, point = true, when = true, idset = true,
    key = true }
```
and replace
```lua
    -- The minimap button is a per-installation display preference: neither reset may touch it. A
    -- member's icon and a pad's position have a default only so a named `/qc reset` restores them;
    -- a page's Defaults (a bracketed sweep) keeps them.
    resetExempt  = { [MINIMAP_PATH] = true, ["callout.icon"] = true, ["group.icon"] = true, ["pad.point"] = true },
```
with
```lua
    -- The minimap button is a per-installation display preference: neither reset may touch it. A
    -- member's icon, a pad's or dial's position and a dial's key have a default only so a named
    -- `/qc reset` restores them; a page's Defaults (a bracketed sweep) keeps them.
    resetExempt  = { [MINIMAP_PATH] = true, ["callout.icon"] = true, ["group.icon"] = true, ["pad.point"] = true,
        ["dial.point"] = true, ["dial.key"] = true },
```

In `settings/Editors.lua`, replace
```lua
Ed.STRUCTURAL = { ["callout.name"] = true, ["group.name"] = true, ["group.enabled"] = true,
    ["group.when"] = true, ["pad.name"] = true, ["builtin.enabled"] = true }
```
with
```lua
Ed.STRUCTURAL = { ["callout.name"] = true, ["group.name"] = true, ["group.enabled"] = true,
    ["group.when"] = true, ["pad.name"] = true, ["dial.name"] = true, ["builtin.enabled"] = true }
```
and
```lua
local STRUCTURED = { point = true, when = true, idset = true }
```
with
```lua
local STRUCTURED = { point = true, when = true, idset = true, key = true }
```

- [ ] **Step 7: The CLI's forms**

In `settings/Slash.lua`, in the comment block above `wordsOf`, replace
```lua
-- Three member rows hold a table (settings/SchemaMembers.lua). The library parses and prints bool,
-- number, string and color; the descriptor's `parse` and `format` hooks teach it these three and
-- hand every other row back to it:
--   pad.point       `x y` (keeps the pad's anchor points) or `POINT RELATIVEPOINT x y`
```
with
```lua
-- Four row types are structured (settings/SchemaMembers.lua): point, when, idset and key. The
-- library parses and prints bool, number, string and color; the descriptor's `parse` and `format`
-- hooks teach it these four and hand every other row back to it:
--   pad.point, dial.point  `x y` (keeps the anchor points) or `POINT RELATIVEPOINT x y`
--   dial.key        one key, `shift-g` or `SHIFT-G`; `none` clears it
```
replace
```lua
local function parsePoint(text)
    local w = wordsOf(text)
    local x, y = tonumber(w[#w - 1] or ""), tonumber(w[#w] or "")
    if not (x and y) or (#w ~= 2 and #w ~= 4) then
        return nil, L["A position is `x y` or `POINT RELATIVEPOINT x y`."]
    end
    if #w == 4 then return { w[1]:upper(), w[2]:upper(), x, y } end
    local current = NS.SchemaRuntime.Get("pad.point")
    local base = type(current) == "table" and current or NS.Pad.DEFAULT_POINT
    return { base[1], base[2], x, y }
end
```
with
```lua
local function parsePoint(text, row)
    local w = wordsOf(text)
    local x, y = tonumber(w[#w - 1] or ""), tonumber(w[#w] or "")
    if not (x and y) or (#w ~= 2 and #w ~= 4) then
        return nil, L["A position is `x y` or `POINT RELATIVEPOINT x y`."]
    end
    if #w == 4 then return { w[1]:upper(), w[2]:upper(), x, y } end
    local current = NS.SchemaRuntime.Get(row.path)
    local fallback = row.instance == "dial" and NS.Library.DIAL_DEFAULT_POINT or NS.Pad.DEFAULT_POINT
    local base = type(current) == "table" and current or fallback
    return { base[1], base[2], x, y }
end
```
replace
```lua
local PARSE = { point = parsePoint, when = parseWhen, idset = parseIdSet }
```
with
```lua
-- A key as typed; the row's validate and normalize do the rest (Library.KeyValue).
local function parseKey(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local PARSE = { point = parsePoint, when = parseWhen, idset = parseIdSet, key = parseKey }
```
in `FORMAT`, after the `idset = function(v) … end,` entry, add:
```lua
    key = function(v)
        if type(v) ~= "string" then return L["none"] end
        return v
    end,
```
and in the descriptor replace
```lua
            local fn = row and PARSE[row.type]
            if fn then return fn(text) end
```
with
```lua
            local fn = row and PARSE[row.type]
            if fn then return fn(text, row) end
```

- [ ] **Step 8: Locale keys**

In `locales/enUS.lua`, replace the line
```lua
L["When this is the first active group on a Comms Dial, the dial opens on its callouts. The Comms Dial arrives in a later build."] = "When this is the first active group on a Comms Dial, the dial opens on its callouts. The Comms Dial arrives in a later build."
```
with
```lua
L["When this is the first active group on a Comms Dial, the dial opens straight on its ring, and the middle of the dial goes back to the groups."] = "When this is the first active group on a Comms Dial, the dial opens straight on its ring, and the middle of the dial goes back to the groups."
```
and add at the end:
```lua

-- The Comms Dial's member rows (settings/SchemaMembers.lua, settings/Schema.lua)
L["A key is one key, with ALT-, CTRL- or SHIFT- in front if you like."] = "A key is one key, with ALT-, CTRL- or SHIFT- in front if you like."
L["Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot open a dial: the open dial uses them."] = "Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot open a dial: the open dial uses them."
L["Categories"] = "Categories"
L["Flat"] = "Flat"
L["At its place"] = "At its place"
L["At the cursor"] = "At the cursor"
L["%s already opens %s."] = "%s already opens %s."
L["What the lists and the dial's first ring call this dial. Press Enter to apply."] = "What the lists and the dial's first ring call this dial. Press Enter to apply."
L["Build this dial and bind its key. A disabled dial keeps its groups, key and settings."] = "Build this dial and bind its key. A disabled dial keeps its groups, key and settings."
L["Categories: the first ring holds your groups and a click opens one. Flat: the first ring holds callouts, highest group first, with More for the rest."] = "Categories: the first ring holds your groups and a click opens one. Flat: the first ring holds callouts, highest group first, with More for the rest."
L["Wheel"] = "Wheel"
L["Wedges per ring"] = "Wedges per ring"
L["How many wedges a ring has. A ring with more puts the rest behind More. 12 applies only to a ring of callouts."] = "How many wedges a ring has. A ring with more puts the rest behind More. 12 applies only to a ring of callouts."
L["Open at"] = "Open at"
L["Where the dial opens: at its place (set below), or wherever the cursor is."] = "Where the dial opens: at its place (set below), or wherever the cursor is."
L["Where the dial opens at its place. Type an offset from the middle of the screen."] = "Where the dial opens at its place. Type an offset from the middle of the screen."
L["Binding"] = "Binding"
L["Key"] = "Key"
L["The key that opens and closes this dial. One key opens one dial. Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot be used: the open dial uses them."] = "The key that opens and closes this dial. One key opens one dial. Escape, the left and right mouse buttons, the mouse wheel and 1 to 8 without a modifier cannot be used: the open dial uses them."
L["No dial to edit: make one on the Comms Dial page."] = "No dial to edit: make one on the Comms Dial page."
```

- [ ] **Step 9: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0. `test_schema`'s boot check passes because every dial row's path resolves against `Library.TEMPLATES.dial`, and each row's default (`false` for `dial.point` and `dial.key`) matches the template. `test_library`'s `SetSurfacePoint refuses …` case still passes: `("pad", "d2", …)` finds no pad `d2`, and `("dial", "d2", …)` now writes through the seam.

- [ ] **Step 10: Commit**

```bash
git add modules/Library.lua settings/SchemaMembers.lua settings/Schema.lua settings/Editors.lua settings/Slash.lua locales/enUS.lua tests/test_members.lua tests/test_library.lua
git checkout -- modules/Library.lua settings/SchemaMembers.lua settings/Schema.lua settings/Editors.lua settings/Slash.lua locales/enUS.lua tests/test_members.lua tests/test_library.lua
git commit -m "Dial: member rows, keys, and the dial's position through the seam"
```

---
### Task 5b: The battleground order: the generic set last, and migration step 2

Two data changes make open-into reach Arathi Basin: D9 opens into the **first** active group, and the generic battleground set (shipped before the per-battleground sets) would come first in every battleground. The generic set now ships after every per-battleground set, and migration step 2 moves it below them on every stored profile's pads and dials (Library does the move; it is the registry writer, and `core/Database.lua` only calls it). Its own task, so a red case here never holds back Task 5a's rows. Seven existing cases read the old order or the old schema stamp; each is listed in Step 1 with its replacement.

**Files:**
- Modify: `modules/Library.lua` (a new migrations section, after Task 5a's keys section)
- Modify: `core/Database.lua` (`NS.MIGRATIONS`)
- Modify: `defaults/BuiltIns_Battlegrounds.lua` (the generic set moves to the end)
- Test: `tests/test_library.lua`, `tests/test_builtins.lua`, `tests/test_database.lua`, `tests/test_profile.lua`, `tests/test_surfaces.lua`, `tests/test_pad.lua`, `tests/test_diagnostics.lua`

**Interfaces:**
- Consumes: `NS.MIGRATIONS`' `perProfile` steps (phase 1), `NS.addon:RunMigrations()`.
- Produces:
  - `Lib.MoveGenericBattlegroundLast(profile) -> number` (lists changed)
  - `NS.SCHEMA_VERSION == 2`; `NS.BuiltIns.order` ends with `"bi.bg"`

- [ ] **Step 1: Write the failing tests, and the cases the new order changes**

Append to `tests/test_library.lua`:
```lua
test("library: [phase 4] the generic battleground set moves below the per-battleground sets, once", function()
    local _, Lib = boot()
    local profile = { pads = { p1 = { groups = { "g1", "bi.bg", "bi.bg.ab", "bi.mplus", "bi.bg.wsg" } } },
        dials = { d2 = { groups = { "bi.bg.ab", "bi.bg" } } } }
    assertEqual(Lib.MoveGenericBattlegroundLast(profile), 1)
    assertEqual(table.concat(profile.pads.p1.groups, ","), "g1,bi.bg.ab,bi.mplus,bi.bg.wsg,bi.bg")
    assertEqual(table.concat(profile.dials.d2.groups, ","), "bi.bg.ab,bi.bg", "already below: untouched")
    assertEqual(Lib.MoveGenericBattlegroundLast(profile), 0, "idempotent")
    assertEqual(Lib.MoveGenericBattlegroundLast({ pads = "junk" }), 0)
end)
```

In `tests/test_builtins.lua`, replace
```lua
    assertEqual(BI.order[4], "bi.bg")
```
with
```lua
    -- A battleground's own set comes before the generic one, so the dial opens into it (D9, phase 4).
    assertEqual(BI.order[4], "bi.bg.ab")
    assertEqual(BI.order[#BI.order], "bi.bg")
```

In `tests/test_database.lua`, replace the whole case `test("database: a perProfile step runs once for every stored profile", …)` with:
```lua
test("database: a perProfile step runs once for every stored profile", function()
    local NS = T.bootAddon()
    NS.addon.db:SetProfile("Second")
    local target = NS.SCHEMA_VERSION + 1
    NS.addon.db.global.schemaVersion = NS.SCHEMA_VERSION
    local seen = {}
    NS.MIGRATIONS[#NS.MIGRATIONS + 1] = { to = target, perProfile = true,
        run = function(_, profile) seen[#seen + 1] = profile end }
    NS.addon:RunMigrations()
    NS.MIGRATIONS[#NS.MIGRATIONS] = nil
    assertEqual(#seen, 2, "Default and Second")
    assertEqual(NS.addon.db.global.schemaVersion, target)
end)

test("database: [phase 4] step 2 moves the generic battleground set below the per-battleground sets", function()
    local NS = T.bootAddon()
    local p = NS.addon.db.profile
    p.pads[p.padOrder[1]].groups = { "bi.mplus", "bi.bg", "bi.bg.ab", "bi.bg.wsg" }
    NS.addon.db.global.schemaVersion = 1
    NS.addon:RunMigrations()
    assertEqual(NS.addon.db.global.schemaVersion, 2)
    assertEqual(table.concat(p.pads[p.padOrder[1]].groups, ","), "bi.mplus,bi.bg.ab,bi.bg.wsg,bi.bg")
end)
```

In `tests/test_surfaces.lua`, replace the case `test("surfaces: a node battleground gives one section per node, baked to /i", …)` with:
```lua
test("surfaces: a node battleground gives one section per node, baked to /i", function()
    local NS = live(AB)
    local plan = planFor(NS)
    assertEqual(table.concat(plan.order, ","), "bi.bg.ab,bi.bg")
    assertEqual(#plan.sections, 6)
    assertEqual(plan.sections[2].title, "Lumber Mill")
    assertEqual(plan.sections[2].slots[3].line, "/i INC 3 Lumber Mill")
    assertEqual(plan.sections[6].title, "Battleground (generic)")
end)
```

In `tests/test_diagnostics.lua`, replace
```lua
    assertTrue(text:find("schema stored=1 code=1", 1, true) ~= nil, "identity")
```
with
```lua
    assertTrue(text:find("schema stored=2 code=2", 1, true) ~= nil, "identity")
```

In `tests/test_profile.lua`, replace
```lua
test("profile: schema version target is 1", function()
    local NS = T.bootAddon()
    assertEqual(NS.SCHEMA_VERSION, 1)
    assertEqual(NS.db.global.schemaVersion, 1)
end)
```
with
```lua
test("profile: schema version target is 2 (phase 4: the battleground order)", function()
    local NS = T.bootAddon()
    assertEqual(NS.SCHEMA_VERSION, 2)
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)
```

In `tests/test_pad.lua`, Arathi Basin's own set is now the first tab, so its first node starts and the wheel steps to the second. In case `"pad: tabs show one section; the wheel steps them out of combat and is refused in it"`, replace
```lua
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.help"), 1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 0)
    assertTrue(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1)
    combat(m, true)
    assertFalse(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1, "unchanged in combat")
```
with
```lua
    -- Arathi Basin's own set comes first (phase 4), so its first node is the first tab.
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.lumbermill.inc1"), 0)
    assertTrue(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.lumbermill.inc1"), 1)
    combat(m, true)
    assertFalse(NS.Pad.Wheel("p1", -1))
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.lumbermill.inc1"), 1, "unchanged in combat")
```
and in case `"pad: [fix wave] tabs switch on a wheel over a chip or the pad, not only the header"`, replace
```lua
    local chip = NS.Pad.ChipsFor("p1", "bi.bg.help")[1]
    -- red under: enable the wheel on the header alone
    chip:__fire("OnMouseWheel", -1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1)
    NS.Pad.Instance("p1").root:__fire("OnMouseWheel", 1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.help"), 1)
```
with
```lua
    local chip = NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1")[1]
    -- red under: enable the wheel on the header alone
    chip:__fire("OnMouseWheel", -1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.lumbermill.inc1"), 1)
    NS.Pad.Instance("p1").root:__fire("OnMouseWheel", 1)
    assertEqual(#NS.Pad.ChipsFor("p1", "bi.bg.ab.stables.inc1"), 1, "back to Stables")
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_library` (`MoveGenericBattlegroundLast` is nil), `test_builtins`, `test_surfaces` and both `test_pad` cases (the old order), and `test_database`, `test_profile` and `test_diagnostics` (the old schema stamp).

- [ ] **Step 3: Library: the migration's move**

In `modules/Library.lua`, directly before `-- ── prepare ──…` (after Task 5a's keys section), add:
```lua
-- ── migrations (core/Database.lua calls these; Library writes the lists) ────────────────────

--- Schema step 2 for one stored profile: on every pad and dial, the generic battleground set moves to
--- just below the last per-battleground set, so a node set can be the first active group and the dial
--- opens into it (D9). The shipped order changed the same way (defaults/BuiltIns_Battlegrounds.lua).
--- A raw SavedVariables profile: anything missing or malformed is skipped. Idempotent.
--- @return number the lists changed
function Lib.MoveGenericBattlegroundLast(profile)
    local n = 0
    for _, key in ipairs({ "pads", "dials" }) do
        local set = type(profile) == "table" and profile[key]
        for _, s in pairs(type(set) == "table" and set or {}) do
            local list = type(s) == "table" and s.groups
            if type(list) == "table" then
                local at, last
                for i, gid in ipairs(list) do
                    if gid == "bi.bg" then
                        at = i
                    elseif type(gid) == "string" and gid:find("^bi%.bg%.") then
                        last = i
                    end
                end
                if at and last and at < last then
                    table.remove(list, at)
                    table.insert(list, last, "bi.bg")
                    n = n + 1
                end
            end
        end
    end
    return n
end
```

- [ ] **Step 4: Migration step 2**

In `core/Database.lua`, replace
```lua
NS.MIGRATIONS = {
    { to = 1, run = function() end },   -- 0 -> 1: the stamp itself; v0.1.0 has nothing to reshape
}
```
with
```lua
NS.MIGRATIONS = {
    { to = 1, run = function() end },   -- 0 -> 1: the stamp itself
    -- 1 -> 2 (phase 4): the generic battleground set moves below the per-battleground sets on every
    -- pad and dial, so the dial opens into a node set (D9). Library is the registry writer; it moves.
    { to = 2, perProfile = true, run = function(_, profile) NS.Library.MoveGenericBattlegroundLast(profile) end },
}
```

- [ ] **Step 5: The generic battleground set ships last**

In `defaults/BuiltIns_Battlegrounds.lua`, cut the block
```lua
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
```
from its place under `local BG = …` and paste it at the end of the file, after the last `flatBattleground(...)` call, preceded by:
```lua

-- The generic set comes last (phase 4): a battleground's own set is then the first active group on a
-- default dial, so the dial opens straight on its nodes (D9). Migration step 2 moves it on stored
-- profiles (modules/Library.lua MoveGenericBattlegroundLast).
```
In the file's header comment, after `… and open into their ring.`, add ` The generic set is declared last, below every per-battleground set.`

- [ ] **Step 6: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0. If another case fails on the order, it reads the generic set before a node set; compare it with the cases in Step 1 before changing anything.

- [ ] **Step 7: Commit**

```bash
git add modules/Library.lua core/Database.lua defaults/BuiltIns_Battlegrounds.lua tests/test_library.lua tests/test_builtins.lua tests/test_database.lua tests/test_profile.lua tests/test_surfaces.lua tests/test_pad.lua tests/test_diagnostics.lua
git checkout -- modules/Library.lua core/Database.lua defaults/BuiltIns_Battlegrounds.lua tests/test_library.lua tests/test_builtins.lua tests/test_database.lua tests/test_profile.lua tests/test_surfaces.lua tests/test_pad.lua tests/test_diagnostics.lua
git commit -m "Built-ins: the generic battleground set ships last; migration step 2 moves it on stored profiles"
```

---
### Task 6: Dial_Render and Dial: the dial's frames, the hub and the pointer

The dial's frames, built from a plan (Task 7 makes the plans; this task's tests build them by hand with `Dial_Layout.Rings`). `modules/Dial.lua` keeps one instance per place in the dial order: the header from `Dial_Secure`, a pool of ring containers, and in each container a pool of wedges. `Apply(index, id, plan)` closes the dial, re-acquires the containers and wedges in plan order, places each wedge on its compass point, paints it, arms it (a callout wedge exactly as a pad chip is armed, through `Pad.ArmSlot`; a ring wedge disarmed), hands the rings to the header (`DialSecure.Load`), anchors the header at the dial's place and paints the hub. `Sync(plans, order)` applies every planned dial, releases the rest, binds each dial's key to its header (`SendEngine.BindKeys`) and, when the plan is test mode or a preview, opens dial 1. `modules/Dial_Render.lua` is the insecure paint, on regions of the secure frames as `Pad_Render` paints chips: the dark disc and the ✕ hub on the header, spokes and a title on each ring, an icon, a label outside the disc, a padlock, a dim veil, the guard's cooling veil, a result flash and a gold hover glow on each wedge; the hub's stale hint, lockdown chip and test label; and the pointer, a plain child of the header whose `OnUpdate` is set when the header shows and cleared when it hides (spec §16's `dial.render` bucket). It never sizes or places a protected frame: `Dial.lua` does, out of combat. Hovering the hub shows "Why is this showing?". The guard and the echo reach the dial as they reach the pad (spec §9.2, §9.3, §17): a wedge's press calls `Pad.Cooldown`, which now dims every wedge on every dial (`Dial.Cooldown`) as well as every chip, and `Dial.lua` hears `SEND_RESULT` and flashes the wedges of that callout. The dial closes on a send, so both show on the next open: the dim for the guard window, a drop's red for `Dial.DROP_SECONDS` (5 s). The receiver and the timers are torn down and replayed by the stand-down and stand-up, as the pad's are.

**Files:**
- Create: `modules/Dial_Render.lua`, `modules/Dial.lua`
- Modify: `modules/Pad.lua` (publishes `Pad.ArmSlot`; `Pad.Cooldown` dims the dials too), `core/PerfSetup.lua` (the `dial.render` bucket; `bake.surface`'s comment), `QuickComms.toc`, `tests/run.lua`, `locales/enUS.lua`, `.luacheckrc`
- Test: `tests/test_dial.lua` (create)

**Interfaces:**
- Consumes: Task 3's `DL.Wedge`, `DL.Spoke`, `DL.Pointer`, `DL.Rings`, the `DL` sizes; Task 4's `DS.NewHeader`, `DS.NewRing`, `DS.NewWedge`, `DS.Load`, `DS.Open`, `DS.Close`, `DS.HEADER`, `DS.TOGGLE`; Task 2's `SE.Disarm`, `SE.BindKeys`, `SE.ClearKeys`, `SE.RunOrQueue`; Task 5a's `Lib.DIAL_DEFAULT_POINT` (read at run time), `Lib.SetSurfacePoint("dial", …)`, `profile.dials[id].key|openAt|point` (Task 5a); phase 3's `NS.PadRender.TooltipLines(slot)`, `NS.PadRender.ShowLines(owner, title, lines)`, `NS.PadRender.LOCK_TEXT`, `NS.Surfaces.Slot(...)`, `NS.Surfaces.WhyLines(id)`, `NS.Constants.FLASH`, `NS.Library.MIN_SURFACE_SCALE` (phase-3 fix wave), `Pad.Cooldown(window)`.
- Produces:
  - `NS.Pad.ArmSlot(button, slot)` (the pad's own arm, shared); `Pad.Cooldown(window)` now also calls `Dial.Cooldown(window)`
  - `NS.DialRender` (`R`): `R.DressHub(header, onEnter)`, `R.DressRing(ring)`, `R.PaintRing(ring, spec)`, `R.RingTitle(spec) -> string`, `R.DressWedge(btn)`, `R.PaintWedge(btn, item, geo)`, `R.RefreshLock(btn)`, `R.Flash(btn, what)`, `R.Unflash(btn)`, `R.SetCooling(btn, on)`, `R.WedgeLines(item) -> string[]`, `R.ShowTooltip(btn)`, `R.PaintHub(header, state)`, `R.PointerUpdate(pointer)`; `header.qcStale`, `header.qcLockdown`, `header.qcTest`, `header.qcPointer` (`.qcArrow`); `btn.qcItem`, `btn.qcLabel`, `btn.qcDim`, `btn.qcCool`, `btn.qcFlash`, `btn.qcLock`
  - `NS.Dial`: `Dial.DROP_SECONDS = 5`, `Dial.Cooldown(window)`, `Dial.Apply(index, id, plan) -> boolean`, `Dial.Release(index) -> boolean`, `Dial.Sync(plans, order)`, `Dial.HideAll()`, `Dial.SetStale(id, on)`, `Dial.RefreshLocks(id, showLockdownChip)`, `Dial.ShowWhy(id, owner) -> boolean`, `Dial.ResetPositions()`, `Dial.Instance(id)`, `Dial.Ids() -> sorted ids`, `Dial.WedgesFor(id, calloutId)`, `Dial.RingWedges(id, r)`, `Dial.IsOpen(id)`, `Dial.ShownRing(id) -> r|nil`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_dial.lua`:
```lua
-- tests/test_dial.lua — modules/Dial.lua and modules/Dial_Render.lua (spec §11): the dial's frames built
-- from a plan, armed wedges, the hub and the pointer. From Task 7: the rebuild edge, the keys and the
-- exit paths; from Task 8: Bindings.xml.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function live(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    return NS, m
end

-- A plan for the default dial straight from slots, without Surfaces: the M+ set's first `n` callouts
-- baked under the current snapshot, as one group (or two, with `second`).
local function planOf(NS, opts)
    opts = opts or {}
    local snap = NS.Situation.Current()
    local group = { id = "bi.mplus", title = "M+ (generic)", slots = {} }
    for i, cid in ipairs(NS.BuiltIns.groups["bi.mplus"].callouts) do
        if i > (opts.n or 8) then break end
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    local rings, open = NS.DialLayout.Rings({ group }, { slices = opts.slices or 4, title = "Comms Dial" })
    return { kind = "dial", surfaceId = "d2", snapshot = snap, order = { "bi.mplus" }, active = {}, rings = rings,
        openRing = open, lockdownChip = opts.lockdown == true, test = opts.test }
end

test("dial: Apply builds QuickCommsDial<n> with a ring per page, each callout wedge armed with its baked line", function()
    local NS, m = live()
    assertTrue(NS.Dial.Apply(1, "d2", planOf(NS)))
    local inst = NS.Dial.Instance("d2")
    assertEqual(inst.header:GetName(), "QuickCommsDial1")
    assertFalse(inst.header:IsShown(), "closed until its key opens it")
    local _, rings = NS.Pool.Counts(inst.rings)
    assertEqual(rings, 4, "the group ring, then three pages of eight callouts on four wedges")
    local w = NS.Dial.WedgesFor("d2", "bi.mplus.pull")[1]
    assertEqual(w:GetAttribute("macrotext"), "/p Pulling next pack")
    assertEqual(w.qcLabel:GetText(), "Pulling")
    assertEqual(NS.DialRender.WedgeLines(w.qcItem)[2], "/p Pulling next pack")
    m.__click(inst.header, "Toggle")
    assertTrue(NS.Dial.IsOpen("d2"))
    assertEqual(NS.Dial.ShownRing("d2"), 2, "one group: open straight on its ring")
    m.__click(w)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p Pulling next pack")
    assertFalse(NS.Dial.IsOpen("d2"))
end)

test("dial: a refused callout is a dimmed, disarmed wedge; a ring wedge is disarmed", function()
    local NS = live()
    local cid = NS.Library.CreateCallout({ name = "Bad", text = "/run x", channel = "party" })
    local plan = planOf(NS)
    local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), NS.Situation.Current(), {})
    slot.surfaceId = "d2"
    plan.rings[2].items[1] = { kind = "send", slot = slot, title = "Bad" }
    NS.Dial.Apply(1, "d2", plan)
    local w = NS.Dial.WedgesFor("d2", cid)[1]
    assertNil(w:GetAttribute("type"))
    assertTrue(w.qcDim:IsShown())
    local ringWedge = NS.Dial.RingWedges("d2", 1)[1]
    assertEqual(ringWedge.qcItem.kind, "ring")
    assertNil(ringWedge:GetAttribute("type"))
end)

test("dial: the hub shows the lockdown chip, the stale hint and TEST MODE; the pointer runs only while open", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS, { lockdown = true, test = true }))
    local h = NS.Dial.Instance("d2").header
    assertTrue(h.qcLockdown:IsShown())
    assertTrue(h.qcTest:IsShown())
    NS.Dial.SetStale("d2", true)
    assertTrue(h.qcStale:IsShown())
    local pointer = h.qcPointer
    assertNil(pointer:GetScript("OnUpdate"), "closed: no OnUpdate")
    m.__click(h, "Toggle")
    -- red under: set the pointer's OnUpdate at build instead of on the hub's OnShow
    assertTrue(pointer:GetScript("OnUpdate") ~= nil)
    m.cursor.x, m.cursor.y = 300, 0
    pointer:__fire("OnUpdate", 0.01)
    assertTrue(pointer.qcArrow:IsShown())
    m.cursor.x = 2
    pointer:__fire("OnUpdate", 0.01)
    assertFalse(pointer.qcArrow:IsShown(), "inside the dead zone")
    m.__click(h, "Toggle")
    assertNil(pointer:GetScript("OnUpdate"))
end)

test("dial: a press dims every wedge and chip for the guard window; a drop stays red long enough to reopen and see", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS))
    local h = NS.Dial.Instance("d2").header
    local w = NS.Dial.WedgesFor("d2", "bi.mplus.pull")[1]
    local other = NS.Dial.WedgesFor("d2", "bi.mplus.lust")[1]
    NS.addon:SendMessage(NS.MSG.SEND_RESULT, "bi.mplus.pull", "d2", "dropped")
    assertTrue(w.qcFlash:IsShown())
    -- red under: flash a drop for the pad's 0.4 s (gone before the closed dial can be reopened)
    assertEqual(m.__timers[#m.__timers].delay, NS.Dial.DROP_SECONDS)
    m.__fireTimers()
    assertFalse(w.qcFlash:IsShown())
    m.__click(h, "Toggle")
    m.__click(w)
    -- red under: drop the NS.Dial.Cooldown call from Pad.Cooldown
    assertTrue(other.qcCool:IsShown(), "the guard is global: every wedge dims")
    assertTrue(NS.Pad.ChipsFor("p1", "bi.mplus.lust")[1].qcCool:IsShown(), "and every chip")
    m.__fireTimers()
    assertFalse(other.qcCool:IsShown())
end)

test("dial: Release closes, disarms and forgets a dial; HideAll also releases the keys", function()
    local NS, m = live()
    NS.Dial.Apply(1, "d2", planOf(NS))
    local h = NS.Dial.Instance("d2").header
    m.__click(h, "Toggle")
    assertTrue(NS.Dial.Release(1))
    assertFalse(h:IsShown())
    assertNil(NS.Dial.Instance("d2"))
    for _, b in ipairs(NS.SendEngine.ArmedButtons()) do assertTrue(b.qcMeta.surfaceId ~= "d2") end
    m.__click(h, "Toggle")
    assertFalse(h:IsShown(), "nothing left to open")
    NS.SendEngine.BindKeys({ { key = "G", name = "QuickCommsDial1", button = "Toggle" } })
    NS.Dial.HideAll()
    assertNil(m.overrideBindings.G)
end)

test("dial: Sync applies each planned dial at its place in the order, binds its key, and opens dial 1 in test mode", function()
    local NS, m = live()
    NS.db.profile.dials.d2.key = "G"
    NS.Dial.Sync({ d2 = planOf(NS) }, { "d2" })
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1")
    assertEqual(m.overrideBindings.G.button, "Toggle")
    assertFalse(NS.Dial.IsOpen("d2"))
    NS.Dial.Sync({ d2 = planOf(NS, { test = true }) }, { "d2" })
    assertTrue(NS.Dial.IsOpen("d2"), "test mode shows dial 1 open")
    NS.Dial.Sync({}, { "d2" })
    assertNil(NS.Dial.Instance("d2"))
    assertNil(m.overrideBindings.G)
end)
```
(Task 5a's member row is the normal writer of `dials[id].key`; the case above sets the stored field directly so it tests `Sync` alone, before Task 7 wires the rebuild.)

In `tests/run.lua`, add `"test_dial",` after `"test_pad",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_dial` (`attempt to index ... Dial (a nil value)`).

- [ ] **Step 3: Share the pad's arm and the guard's dim**

In `modules/Pad.lua`, directly after the `local function arm(btn, slot) … end` block, add:
```lua
-- The dial's callout wedges are armed exactly as a chip is (modules/Dial.lua).
Pad.ArmSlot = arm
```
and replace
```lua
--- The spam guard is global (D12): one press dims every chip on every pad for the window.
function Pad.Cooldown(window)
```
with
```lua
--- The spam guard is global (D12): one press dims every chip on every pad, and every wedge on every
--- dial (modules/Dial.lua, which a wedge's press reaches through here too), for the window.
function Pad.Cooldown(window)
    if NS.Dial and NS.Dial.Cooldown then NS.Dial.Cooldown(window) end
```

- [ ] **Step 4: The perf bucket**

In `core/PerfSetup.lua`, in `BUCKETS`, replace
```lua
    { key = "bake.surface" }, -- modules/Surfaces.lua: one pad's plan (resolve, order, bake every slot)
```
with
```lua
    { key = "bake.surface" }, -- modules/Surfaces.lua: one pad's or dial's plan (resolve, order, bake every slot)
```
and after `{ key = "echo.match" },   -- …`, add:
```lua
    { key = "dial.render" },  -- modules/Dial_Render.lua: the pointer's OnUpdate while a dial is open
```

- [ ] **Step 5: Write the render**

Create `modules/Dial_Render.lua`:
```lua
local _, NS = ...
-- modules/Dial_Render.lua — what the Comms Dial shows (spec §11.1, §11.4). INSECURE visuals only:
-- textures and font strings on the dial's frames, their text, color and visibility, which the client
-- allows in combat; it never touches an attribute or a protected frame's geometry or visibility (the
-- header's snippets show and hide the rings; modules/Dial.lua sizes and places the frames, out of
-- combat). As modules/Pad_Render.lua dresses a pad's secure chips, this dresses the dial's secure
-- frames: the dark disc and the hub's close mark on the header, spokes and a title on each ring, and
-- on each wedge an icon, its label outside the disc, a padlock, a dim veil when it sends nothing, the
-- guard's cooling veil, a result flash and a gold glow under the mouse (the selected wedge). The hub carries the stale hint, the lockdown chip and the test
-- or preview label. The pointer is a plain (unprotected) child of the header that turns toward the
-- cursor: its OnUpdate is set when the header shows and cleared when it hides, so a closed or
-- stood-down dial runs nothing per frame (perf bucket dial.render).

NS.DialRender = NS.DialRender or {}
local R = NS.DialRender
local DL = NS.DialLayout
local L = NS.L
local Perf = NS.Perf

local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local MORE_ICON = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local CLOSE_ICON = "Interface\\Buttons\\UI-StopButton"
local POINTER_ICON = "Interface\\Minimap\\MinimapArrow"
local SPOKES = 12

-- A round texture: the circular alpha mask, tinted.
local function circle(frame, layer, size, r, g, b, a)
    local t = frame:CreateTexture(nil, layer)
    t:SetTexture(CIRCLE)
    t:SetVertexColor(r, g, b, a)
    t:SetSize(size, size)
    t:SetPoint("CENTER", frame, "CENTER", 0, 0)
    return t
end

--- The pointer, while the dial is open: toward the cursor, hidden inside the dead zone.
function R.PointerUpdate(pointer)
    local t0 = Perf.on and debugprofilestop()
    local header = pointer.qcHeader
    local cx, cy = header:GetCenter()
    local scale = header:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    local a, ox, oy = DL.Pointer((cx or 0) * scale, (cy or 0) * scale, mx, my)
    local arrow = pointer.qcArrow
    if a then
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", header, "CENTER", ox, oy)
        arrow:SetRotation(-a)
        arrow:Show()
    else
        arrow:Hide()
    end
    if t0 then Perf.Note("dial.render", debugprofilestop() - t0) end
end

--- Build the hub's regions and the pointer, once per header. `onEnter(header)` runs on hover.
function R.DressHub(header, onEnter)
    if header.qcDressed then return header end
    header.qcDressed = true
    header.qcDisc = circle(header, "BACKGROUND", DL.DISC, 0.06, 0.06, 0.08, 0.80)
    header.qcHub = circle(header, "BORDER", DL.HUB, 0.12, 0.12, 0.14, 0.95)
    header.qcClose = header:CreateTexture(nil, "ARTWORK")
    header.qcClose:SetTexture(CLOSE_ICON)
    header.qcClose:SetSize(DL.HUB - 16, DL.HUB - 16)
    header.qcClose:SetPoint("CENTER", header, "CENTER", 0, 0)
    header.qcStale = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.qcStale:SetPoint("TOP", header, "BOTTOM", 0, -2)
    header.qcStale:SetText(L["updates after combat"])
    header.qcStale:Hide()
    header.qcLockdown = header:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    header.qcLockdown:SetPoint("BOTTOM", header, "TOP", 0, 2)
    header.qcLockdown:SetText(L["LOCKDOWN"])
    header.qcLockdown:Hide()
    header.qcTest = header:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    header.qcTest:SetPoint("BOTTOM", header.qcLockdown, "TOP", 0, 2)
    header.qcTest:Hide()
    local pointer = CreateFrame("Frame", nil, header)
    pointer:SetAllPoints(header)
    pointer.qcHeader = header
    local gold = NS.Constants.GOLD
    pointer.qcArrow = pointer:CreateTexture(nil, "OVERLAY")
    pointer.qcArrow:SetTexture(POINTER_ICON)
    pointer.qcArrow:SetSize(16, 16)
    pointer.qcArrow:SetVertexColor(gold.r, gold.g, gold.b, 1)
    pointer.qcArrow:Hide()
    header.qcPointer = pointer
    header:HookScript("OnShow", function() pointer:SetScript("OnUpdate", R.PointerUpdate) end)
    header:HookScript("OnHide", function()
        pointer:SetScript("OnUpdate", nil)
        pointer.qcArrow:Hide()
    end)
    header:HookScript("OnEnter", function(self) if onEnter then onEnter(self) end end)
    header:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return header
end

--- The hub's labels: the lockdown chip, the stale hint, and TEST MODE or PREVIEW.
function R.PaintHub(header, state)
    header.qcLockdown:SetShown(state.lockdown == true)
    header.qcStale:SetShown(state.stale == true)
    header.qcTest:SetShown(state.testText ~= nil)
    header.qcTest:SetText(state.testText or "")
end

--- Build a ring container's spokes and title, once per container.
function R.DressRing(ring)
    if ring.qcDressed then return ring end
    ring.qcDressed = true
    ring.qcSpokes = {}
    for j = 1, SPOKES do
        local s = ring:CreateTexture(nil, "BORDER")
        s:SetColorTexture(1, 1, 1, 0.12)
        s:Hide()
        ring.qcSpokes[j] = s
    end
    ring.qcTitle = ring:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ring.qcTitle:SetPoint("BOTTOM", ring, "TOP", 0, 4)
    return ring
end

--- A ring's title: its name, and its page when it has several ("Arathi Basin (1 of 2)").
function R.RingTitle(spec)
    if (spec.pages or 1) > 1 then return L["%s (%d of %d)"]:format(spec.title or "", spec.page, spec.pages) end
    return spec.title or ""
end

--- Show one ring's spokes (one between each pair of its wedges) and its title.
function R.PaintRing(ring, spec)
    for j, s in ipairs(ring.qcSpokes) do
        if j <= spec.size then
            local g = DL.Spoke(j, spec.size)
            s:ClearAllPoints()
            s:SetPoint("CENTER", ring, "CENTER", g.x, g.y)
            s:SetSize(1, g.length)
            s:SetRotation(g.rotation)
            s:Show()
        else
            s:Hide()
        end
    end
    ring.qcTitle:SetText(R.RingTitle(spec))
end

--- A wedge's tooltip lines: a callout's as its pad chip's (name, its line or why it sends nothing,
--- any lock), a ring's name and what a click does.
function R.WedgeLines(item)
    if item.slot then return NS.PadRender.TooltipLines(item.slot) end
    if item.more then return { L["More"], L["Click for the next page. The mouse wheel turns pages too."] } end
    return { item.title or "?", L["Click to open."] }
end

function R.ShowTooltip(btn)
    local item = btn.qcItem
    if not item then return end
    local lines = R.WedgeLines(item)
    local rest = {}
    for i = 2, #lines do rest[#rest + 1] = lines[i] end
    NS.PadRender.ShowLines(btn, lines[1], rest)
end

--- Build a wedge's regions and hover hooks, once per button.
function R.DressWedge(btn)
    if btn.qcDressed then return btn end
    btn.qcDressed = true
    btn.qcBg = circle(btn, "BACKGROUND", DL.WEDGE, 0.10, 0.10, 0.12, 0.95)
    btn.qcIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.qcIcon:SetSize(DL.WEDGE - 12, DL.WEDGE - 12)
    btn.qcIcon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.qcLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.qcLock = btn:CreateTexture(nil, "OVERLAY")
    btn.qcLock:SetSize(14, 14)
    btn.qcLock:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    btn.qcLock:SetTexture(LOCK_ICON)
    btn.qcDim = circle(btn, "OVERLAY", DL.WEDGE, 0, 0, 0, 0.55)
    btn.qcDim:Hide()
    btn.qcCool = circle(btn, "OVERLAY", DL.WEDGE, 0, 0, 0, 0.35)
    btn.qcCool:Hide()
    btn.qcFlash = circle(btn, "OVERLAY", DL.WEDGE, 1, 1, 1, 0.45)
    btn.qcFlash:Hide()
    local gold = NS.Constants.GOLD
    btn.qcGlow = circle(btn, "HIGHLIGHT", DL.WEDGE + 8, gold.r, gold.g, gold.b, 0.45)
    btn:HookScript("OnEnter", R.ShowTooltip)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

--- Show one ring item on a wedge: its icon, its label outward at `geo.lx, geo.ly`, a padlock when its
--- callout is locked, and the dim veil when it sends nothing here.
function R.PaintWedge(btn, item, geo)
    btn.qcItem = item
    local slot = item.slot
    btn.qcIcon:SetTexture(item.icon or (item.more and MORE_ICON) or DEFAULT_ICON)
    btn.qcLabel:ClearAllPoints()
    btn.qcLabel:SetPoint("CENTER", btn, "CENTER", geo.lx, geo.ly)
    btn.qcLabel:SetText(item.title or "?")
    btn.qcLock:SetShown(slot ~= nil and slot.lock ~= nil)
    local live = slot == nil or slot.line ~= nil or slot.selfText ~= nil or slot.reason == "testMode"
    btn.qcDim:SetShown(not live)
end

function R.RefreshLock(btn)
    local slot = btn.qcItem and btn.qcItem.slot
    btn.qcLock:SetShown(slot ~= nil and slot.lock ~= nil)
end

--- A send result on a wedge (spec §9.3): the pad's colors (NS.Constants.FLASH), red for a drop.
function R.Flash(btn, what)
    local c = NS.Constants.FLASH[what] or NS.Constants.FLASH.sent
    btn.qcFlash:SetVertexColor(c[1], c[2], c[3], 0.45)
    btn.qcFlash:Show()
end

function R.Unflash(btn)
    btn.qcFlash:Hide()
end

--- The guard's dim (spec §9.2).
function R.SetCooling(btn, on)
    btn.qcCool:SetShown(on and true or false)
end
```

- [ ] **Step 6: Write the frames**

Create `modules/Dial.lua`:
```lua
local _, NS = ...
-- modules/Dial.lua — the Comms Dial's frames (spec §11). One instance per place in the dial order: the
-- header (modules/Dial_Secure.lua) named QuickCommsDial<place>, which Bindings.xml and the dial's key
-- click; a pool of ring containers under it; in each container a pool of wedges, each the slot's send
-- button (spec §9.1). Frames are never destroyed: a released place keeps its header, closed and
-- emptied, for the next dial that takes it.
--
-- PROTECTED WORK IS OUT OF COMBAT ONLY. Apply, Release, Sync and HideAll run through Surfaces and
-- SendEngine.RunOrQueue (and the stand-down's held Teardown), and Apply also declines on its own in
-- combat. In combat only the header's snippets act (open, switch rings, send, close) and only insecure
-- paint changes here: the stale hint, the padlocks, the lockdown chip, the hub's tooltip. A callout
-- wedge is armed exactly as a pad chip is (Pad.ArmSlot): a refused, placeholder or previewed slot is
-- disarmed. The dial's place is `dials[id].point` (the `dial.point` member row; Reset position writes
-- it through Library.SetSurfacePoint); "Open at the cursor" re-anchors in the snippet instead. Sync
-- binds every built dial's key to its header (SendEngine.BindKeys) after the rebuild, so a profile
-- switch, a stand-up or a key edit re-binds; and in test mode or a preview it opens dial 1 (spec
-- §11.4), taking no key. The guard's dim and the result flash (spec §9.2, §9.3) are insecure and
-- reach every wedge as they reach every chip: Pad.Cooldown calls Dial.Cooldown, and SEND_RESULT
-- flashes a callout's wedges. The dial closes on a send, so both show on the next open; a drop stays
-- red for DROP_SECONDS so the player can reopen it and see which line was lost.

NS.Dial = NS.Dial or {}
local Dial = NS.Dial
local DL = NS.DialLayout
local DS = NS.DialSecure
local R = NS.DialRender
local State = NS.State
local L = NS.L

local TAG = "Dial"
local FLASH_SECONDS = 0.4
Dial.DROP_SECONDS = 5          -- a drop stays red long enough to reopen the dial and see it

local byIndex, byId = {}, {}   -- [place] = instance; [dialId] = instance

local function profileDial(id)
    local db = NS.db
    return db and db.profile.dials[id]
end

local function inCombat() return NS.Compat.InCombat() end

local function applyPoint(inst)
    local dial = profileDial(inst.id)
    -- Read here, not at load: Library is not a load-time upvalue of this file.
    local pt = (dial and type(dial.point) == "table") and dial.point or NS.Library.DIAL_DEFAULT_POINT
    inst.header:ClearAllPoints()
    inst.header:SetPoint(pt[1] or "CENTER", UIParent, pt[2] or "CENTER", tonumber(pt[3]) or 0, tonumber(pt[4]) or 0)
end

-- A callout wedge is armed as a chip is; a ring wedge sends nothing (its click switches the ring).
local function arm(btn, item)
    if item.slot then return NS.Pad.ArmSlot(btn, item.slot) end
    NS.SendEngine.Disarm(btn)
end

local function newRing(inst)
    local ring = DS.NewRing(inst.header)
    R.DressRing(ring)
    ring:SetSize(DL.DISC, DL.DISC)   -- protected geometry: here, under Apply, out of combat
    ring:SetPoint("CENTER", inst.header, "CENTER", 0, 0)
    ring.qcWedges = NS.Pool.New()
    return ring
end

-- A wedge's press dims every chip and wedge for the guard window (Pad.Cooldown calls Dial.Cooldown).
local function newWedge(inst, ring)
    return R.DressWedge(DS.NewWedge(inst.header, ring, function(_, _, window) NS.Pad.Cooldown(window) end))
end

local function releaseWedge(w)
    NS.SendEngine.Disarm(w)
    R.Unflash(w)
    R.SetCooling(w, false)
    w.qcItem = nil
end

local function releaseRings(inst)
    for _, ring in ipairs(inst.rings.active) do NS.Pool.ReleaseAll(ring.qcWedges, releaseWedge) end
    NS.Pool.ReleaseAll(inst.rings)
    inst.byCallout = {}
end

local function build(index)
    local header = DS.NewHeader(index)
    header:SetSize(DL.HUB, DL.HUB)   -- protected geometry: here, under Apply, out of combat
    local inst = { index = index, header = header, rings = NS.Pool.New(), byCallout = {}, live = false }
    R.DressHub(header, function(self)
        if inst.id then Dial.ShowWhy(inst.id, self) end
    end)
    byIndex[index] = inst
    NS.Debug(TAG, "built %s", header:GetName())
    return inst
end

local function hubState(inst, plan)
    return {
        lockdown = plan.lockdownChip == true and NS.Setting("behavior.lockdownChip") ~= false,
        stale = State.surfaceStale ~= nil and State.surfaceStale[inst.id] == true,
        testText = (plan.preview and L["PREVIEW"]) or (plan.test and L["TEST MODE"]) or nil,
    }
end

-- One ring's wedges: placed on their compass points, painted, armed, indexed by callout.
local function placeWedges(inst, ring, spec)
    local wedges = {}
    for i, item in ipairs(spec.items) do
        local w = NS.Pool.Acquire(ring.qcWedges, function() return newWedge(inst, ring) end)
        local geo = DL.Wedge(i, spec.size)
        w:ClearAllPoints()
        w:SetPoint("CENTER", ring, "CENTER", geo.x, geo.y)
        w:SetSize(DL.WEDGE, DL.WEDGE)
        R.PaintWedge(w, item, geo)
        arm(w, item)
        if item.slot then
            local list = inst.byCallout[item.slot.calloutId] or {}
            list[#list + 1] = w
            inst.byCallout[item.slot.calloutId] = list
        end
        wedges[i] = { button = w, target = item.kind == "ring" and item.target or 0 }
    end
    return wedges
end

--- Rebuild the dial at `index` (its place in the dial order, which names its header) from a plan.
--- Out of combat only: Surfaces runs it through RunOrQueue.
--- @return boolean applied
function Dial.Apply(index, id, plan)
    if inCombat() then return false end
    local dial = profileDial(id)
    if not (dial and plan) then return false end
    local inst = byIndex[index] or build(index)
    if inst.id and inst.id ~= id and byId[inst.id] == inst then byId[inst.id] = nil end
    inst.id, inst.plan, inst.live = id, plan, true
    byId[id] = inst
    DS.Close(inst.header)
    releaseRings(inst)
    local loaded = {}
    for r, spec in ipairs(plan.rings) do
        local ring = NS.Pool.Acquire(inst.rings, function() return newRing(inst) end)
        ring:Hide()
        R.PaintRing(ring, spec)
        loaded[r] = { frame = ring, parent = spec.parent, prev = spec.prev, next = spec.next,
            wedges = placeWedges(inst, ring, spec) }
    end
    DS.Load(inst.header, loaded, { openRing = plan.openRing, openAt = plan.test and "center" or dial.openAt })
    applyPoint(inst)
    inst.header:SetScale(math.max(NS.Library.MIN_SURFACE_SCALE, tonumber(NS.Setting("scale")) or 1))
    inst.header:SetAlpha(math.max(0, math.min(1, tonumber(NS.Setting("alpha")) or 1)))
    R.PaintHub(inst.header, hubState(inst, plan))
    return true
end

--- Take the dial at `index` away: closed, its wedges disarmed and parked, nothing left to open. Out of
--- combat only.
--- @return boolean released
function Dial.Release(index)
    local inst = byIndex[index]
    if not inst or inCombat() then return false end
    DS.Close(inst.header)
    releaseRings(inst)
    DS.Load(inst.header, {}, {})
    if inst.id and byId[inst.id] == inst then byId[inst.id] = nil end
    inst.id, inst.plan, inst.live = nil, nil, false
    return true
end

--- Make the dials match a set of plans: apply each planned dial at its place in `order` (the dial
--- order), release every other place, bind each built dial's key to its header, and in test mode or a
--- preview open the first one (spec §11.4). Out of combat only.
function Dial.Sync(plans, order)
    local used, keys, first = {}, {}, nil
    for index, id in ipairs(order or {}) do
        local plan = plans[id]
        if plan and Dial.Apply(index, id, plan) then
            used[index] = true
            first = first or index
            local key = profileDial(id).key
            if type(key) == "string" and key ~= "" then
                keys[#keys + 1] = { key = key, name = DS.HEADER:format(index), button = DS.TOGGLE }
            end
        end
    end
    for index in pairs(byIndex) do
        if not used[index] then Dial.Release(index) end
    end
    NS.SendEngine.BindKeys(keys)
    if first and plans[order[first]].test then DS.Open(byIndex[first].header) end
end

--- The secure half of the stand-down: every dial released, every key unbound. Out of combat (the
--- stand-down holds it to combat end).
function Dial.HideAll()
    for index in pairs(byIndex) do Dial.Release(index) end
    NS.SendEngine.ClearKeys()
end

-- ── insecure updates, allowed in combat ─────────────────────────────────────────────────────

local function forEachWedge(fn)
    for _, inst in pairs(byIndex) do
        for _, ring in ipairs(inst.rings.active) do
            for _, w in ipairs(ring.qcWedges.active) do fn(w) end
        end
    end
end

--- The guard's dim on every wedge of every dial, for the window (spec §9.2, D12: the guard is
--- global). Pad.Cooldown calls it, so a chip's press and a wedge's dim the same set.
function Dial.Cooldown(window)
    forEachWedge(function(w) R.SetCooling(w, true) end)
    if State.dialCoolTimer then NS.addon:CancelTimer(State.dialCoolTimer) end
    State.dialCoolTimer = NS.addon:ScheduleTimer(function()
        State.dialCoolTimer = nil
        forEachWedge(function(w) R.SetCooling(w, false) end)
    end, tonumber(window) or 1)
end

function Dial.SetStale(id, on)
    local inst = byId[id]
    if inst then inst.header.qcStale:SetShown(on and true or false) end
end

function Dial.RefreshLocks(id, showLockdownChip)
    local inst = byId[id]
    if not inst then return end
    for _, ring in ipairs(inst.rings.active) do
        for _, w in ipairs(ring.qcWedges.active) do R.RefreshLock(w) end
    end
    inst.header.qcLockdown:SetShown(showLockdownChip and true or false)
end

--- "Why is this showing?" (spec §13.3) over the hub, unless behavior.whyTooltips is off.
function Dial.ShowWhy(id, owner)
    if NS.Setting("behavior.whyTooltips") == false then return false end
    NS.PadRender.ShowLines(owner, L["Why is this showing?"], NS.Surfaces.WhyLines(id))
    return true
end

--- Master controls' Reset position (spec §10.4), the dials' half: every dial back to the middle.
function Dial.ResetPositions()
    local p = NS.db and NS.db.profile
    if not p then return end
    for id in pairs(p.dials) do NS.Library.SetSurfacePoint("dial", id, nil) end
    NS.SendEngine.RunOrQueue("dialPositions", function()
        for _, inst in pairs(byIndex) do
            if inst.id then applyPoint(inst) end
        end
    end)
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

function Dial.Instance(id)
    return byId[id]
end

function Dial.Ids()
    local out = {}
    for id in pairs(byId) do out[#out + 1] = id end
    table.sort(out)
    return out
end

function Dial.WedgesFor(id, calloutId)
    local inst = byId[id]
    return inst and inst.byCallout[calloutId] or {}
end

--- Ring r's wedges, in wedge order (clockwise from N).
function Dial.RingWedges(id, r)
    local inst = byId[id]
    local ring = inst and inst.rings.active[r]
    return ring and ring.qcWedges.active or {}
end

function Dial.IsOpen(id)
    local inst = byId[id]
    return inst ~= nil and inst.header:IsShown()
end

--- The ring on screen, or nil while closed.
function Dial.ShownRing(id)
    local inst = byId[id]
    if not (inst and inst.header:IsShown()) then return nil end
    for r, ring in ipairs(inst.rings.active) do
        if ring:IsShown() then return r end
    end
    return nil
end

-- ── the edge: send results (as modules/Pad.lua's) ───────────────────────────────────────────

local function onSendResult(_, calloutId, surfaceId, what)
    local inst = byId[surfaceId]
    local list = inst and inst.byCallout[calloutId]
    if not list then return end
    for _, w in ipairs(list) do R.Flash(w, what) end
    local timers = State.dialFlashTimers or {}
    State.dialFlashTimers = timers
    local handle
    handle = NS.addon:ScheduleTimer(function()
        timers[handle] = nil
        for _, w in ipairs(list) do R.Unflash(w) end
    end, what == "dropped" and Dial.DROP_SECONDS or FLASH_SECONDS)
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

-- The insecure half of the stand-down; the secure half (release, unbind) is Surfaces' Teardown.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    for handle in pairs(State.dialFlashTimers or {}) do NS.addon:CancelTimer(handle) end
    if State.dialCoolTimer then NS.addon:CancelTimer(State.dialCoolTimer) end
    State.dialFlashTimers, State.dialCoolTimer = nil, nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.SEND_RESULT) end
end

NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
```

- [ ] **Step 7: TOC lines, locale keys, lint**

(`modules/Dial.lua`'s `PlaySound` and `SOUNDKIT` are already `read_globals`, for `modules/Pad.lua`.)

In `QuickComms.toc`, after the `modules\Dial_Secure.lua` line, add:
```
# LOAD-BEARING: publishes NS.DialRender, which modules\Dial.lua takes as a load-time upvalue.
modules\Dial_Render.lua
# Conventional: the Comms Dial frames; appends to NS.STAND_DOWN / NS.STAND_UP; modules\Surfaces.lua calls it at run time only.
modules\Dial.lua
```

In `locales/enUS.lua`, add at the end:
```lua

-- The Comms Dial's paint (modules/Dial_Render.lua)
L["Click to open."] = "Click to open."
L["Click for the next page. The mouse wheel turns pages too."] = "Click for the next page. The mouse wheel turns pages too."
```

In `.luacheckrc`, replace
```lua
  -- modules/Pad.lua: the sent-chip sound.
  "PlaySound", "SOUNDKIT",
```
with
```lua
  -- modules/Pad.lua: the sent-chip sound.
  "PlaySound", "SOUNDKIT",
  -- modules/Dial_Render.lua: the pointer follows the cursor.
  "GetCursorPosition",
```

- [ ] **Step 8: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0, including `test_setup`'s "every declared bucket has a bracket" (`dial.render`, `Dial_Render.PointerUpdate`) and `test_disabled` (nothing builds a dial yet outside these cases; the dial's `SEND_RESULT` receiver and its timers follow the pad's stand-down and stand-up).

- [ ] **Step 9: Commit**

```bash
git add modules/Dial_Render.lua modules/Dial.lua modules/Pad.lua core/PerfSetup.lua QuickComms.toc locales/enUS.lua .luacheckrc tests/test_dial.lua tests/run.lua
git checkout -- modules/Dial_Render.lua modules/Dial.lua modules/Pad.lua core/PerfSetup.lua QuickComms.toc locales/enUS.lua .luacheckrc tests/test_dial.lua tests/run.lua
git commit -m "Dial: the frames (header, rings, wedges), the insecure paint, the guard's dim and the flash, the hub and the pointer"
```

---
### Task 7: Surfaces: the dial's plans and rebuilds, its key, test mode, Reset position, and the exit paths

The dial joins the one rebuild path (test mode and Preview as… open dial 1 through `DialSecure.Open`, which takes no key; `[review 6]` drives the combat edge's other order). `Surfaces.BuildDialPlan` is the pad's plan in rings: the dial's active groups in its order (Resolver, D6), each slot baked (Bake, §8.3), then `Dial_Layout.Rings`. `ApplyAll` builds a plan for every enabled pad and dial from the current (or previewed) snapshot, or test plans in test mode, and hands the dials to `Dial.Sync`, which also re-binds every key; so a key edit, a profile switch, the stand-up and the first situation read after login all (re)bind (spec §9.4). In combat `Request` queues as before and now also shows each dial hub's stale hint. `RefreshLocks` and "Why is this showing?" read dial plans too, and the stand-down's held teardown releases the dials and their keys. Master controls' Reset position now resets every pad and dial anchor (spec §10.4). This is where the phase's three exit paths run headlessly: a wedge sends in a boss, the Categories two-stroke, and Arathi Basin's "INC 3 Lumber Mill" in two clicks.

Building the default dial changes what a few phase-2/3 cases count (each listed in Step 1 with its replacement): the dial's wedges are send buttons too, and its id is sent beside the pad's on `ACTIVE_GROUPS_CHANGED` and `SURFACE_REBUILT`.

**Files:**
- Modify: `modules/Surfaces.lua` (header comment; `S.MarkPreview`; `S.WhyLines`; new `S.EachSlot`, `S.BuildDialPlan`, `S.TestDialPlan`, `S.DialPlans`, `S.ResetPositions`; `enabledPadIds`; `S.ApplyAll`; `S.Request`; `S.RefreshLocks`; `onDrained`; `onProfileChanged`; the stand-down)
- Modify: `modules/Pad.lua` (`Pad.ResetPositions(quiet)`), `settings/Panel.lua` (Reset position), `locales/enUS.lua`
- Test: `tests/test_dial.lua` (append); `tests/test_surfaces.lua`, `tests/test_pad.lua`, `tests/test_diagnostics.lua` (the counts the default dial changes)

**Interfaces:**
- Consumes: Task 6's `Dial.Sync(plans, order)`, `Dial.HideAll()`, `Dial.Ids()`, `Dial.SetStale(id, on)`, `Dial.RefreshLocks(id, on)`, `Dial.ResetPositions()`, `Dial.Instance`, `Dial.RingWedges`, `Dial.ShownRing`, `Dial.IsOpen`; Task 3's `DL.Rings(groups, opts)`; Task 5a's dial rows; phase 3's `S.Slot`, `S.Deps`, `S.Plans`, `NS.Resolver.ActiveGroups/SurfaceOrder/Explain`, `NS.Preview.PreviewSnapshot/PreviewAs/IsTestMode/Label`.
- Produces:
  - `S.BuildDialPlan(surfaceId, dial, snap, deps) -> plan` and `S.TestDialPlan(surfaceId, dial) -> plan` (the dial plan shape in the File Structure section)
  - `S.EachSlot(plan, fn)` (every slot of a pad's or a dial's plan)
  - `S.DialPlans() -> { [dialId] = plan }`
  - `S.ResetPositions()` (Master controls' Reset position: pads and dials, one chat line)
  - `NS.Pad.ResetPositions(quiet)`
  - `S.WhyLines(id)` answers for a dial id as for a pad's

- [ ] **Step 1: Write the failing tests, and the counts the default dial changes**

Append to `tests/test_dial.lua`:
```lua
-- ── the rebuild edge, the keys and the exit paths (Task 7) ──────────────────────────────────

local RAID = { inInstance = true, instanceType = "raid", difficultyID = 15, inGroup = true, inRaid = true }
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

local function bindG(NS) assertTrue(NS.SchemaRuntime.Set("dial.key", "G", "d2")) end

local function wedgeTitled(NS, r, title)
    for _, w in ipairs(NS.Dial.RingWedges("d2", r)) do
        if w.qcItem and w.qcItem.title == title then return w end
    end
    return nil
end

local function ringTitle(NS)
    local r = NS.Dial.ShownRing("d2")
    return r and NS.Surfaces.DialPlans().d2.rings[r].title
end

test("dial: the first situation read builds the default dial, closed; setting its key binds it", function()
    local NS, m = live()
    local inst = NS.Dial.Instance("d2")
    assertTrue(inst ~= nil)
    assertEqual(inst.header:GetName(), "QuickCommsDial1")
    assertFalse(inst.header:IsShown())
    assertNil(next(m.overrideBindings))
    bindG(NS)
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1")
    assertEqual(m.overrideBindings.G.button, "Toggle")
end)

test("dial: [exit] in Arathi Basin the dial opens on the nodes; Lumber Mill, then INC 3, sends in two clicks", function()
    local NS, m = live(AB)
    bindG(NS)
    m.__pressKey("G")
    assertEqual(ringTitle(NS), "Arathi Basin", "open-into: the node set is the first active group")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Lumber Mill"))
    assertEqual(ringTitle(NS), "Lumber Mill")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "INC 3"))
    assertEqual(m.sentMacros[#m.sentMacros].text, "/i INC 3 Lumber Mill")
    assertEqual(#m.sentMacros, 1, "two clicks, one send")
    assertFalse(NS.Dial.IsOpen("d2"))
end)

test("dial: [exit] on a raid boss the dial opens and a click on a wedge sends, with nothing blocked", function()
    local NS, m = live(RAID)
    bindG(NS)
    combat(m, true)
    m.__pressKey("G")
    local w = NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1]
    m.__click(w)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/raid Bloodlust now")
    assertFalse(NS.Dial.IsOpen("d2"))
    assertEqual(#m.blocked, 0)
end)

test("dial: [exit] the Categories two-stroke: a group wedge opens its ring, a callout wedge sends", function()
    local NS, m = live()
    local cid = NS.Library.CreateCallout({ name = "Inc", text = "INC {skull}", channel = "smartGroup" })
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.OfferGroup(gid)
    bindG(NS)
    m.__pressKey("G")
    assertEqual(NS.Dial.ShownRing("d2"), 1, "two active groups: the group ring")
    m.__click(wedgeTitled(NS, 1, "Mine"))
    assertEqual(ringTitle(NS), "Mine")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Inc"))
    assertEqual(m.sentMacros[#m.sentMacros].text, "/p INC {rt8}")
    m.__pressKey("G")
    m.__click(wedgeTitled(NS, 1, "Mine"))
    m.__click(NS.Dial.Instance("d2").header, "LeftButton")
    assertEqual(NS.Dial.ShownRing("d2"), 1, "the hub goes back to the groups")
end)

test("dial: test mode opens dial 1 with placeholder wedges that send nothing, and takes no key", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    assertTrue(NS.Dial.IsOpen("d2"))
    assertTrue(NS.Dial.Instance("d2").header.qcTest:IsShown())
    -- red under: open test mode's dial with DS's key-taking open (qc-open) instead of qc-display
    assertNil(next(m.restrictedBindings), "Escape stays the settings window's, 1-8 the action bar's")
    m.__click(NS.Dial.RingWedges("d2", 1)[1])
    m.__click(NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1])
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("dial: combat start ends test mode and the live dial comes back closed", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    combat(m, true)
    assertFalse(NS.Preview.IsTestMode())
    assertFalse(NS.Dial.IsOpen("d2"))
    assertFalse(NS.Dial.Instance("d2").header.qcTest:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("dial: [review 6] test mode ended by a combat whose lockdown began first: no key held, closed at combat end", function()
    local NS, m = live()
    NS.Preview.SetTestMode(true)
    m.__setCombat(true)                   -- lockdown first, then the edge (the other order)
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.Preview.IsTestMode())
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.IsOpen("d2"), "the rebuild that closes it waits for combat end")
    assertNil(next(m.restrictedBindings), "and the placeholder dial holds no key meanwhile")
    combat(m, false)
    assertFalse(NS.Dial.IsOpen("d2"))
    assertFalse(NS.Dial.Instance("d2").header.qcTest:IsShown())
    assertNil(next(m.restrictedBindings))
    assertEqual(#m.blocked, 0)
end)

test("dial: Preview as opens dial 1 on the previewed situation, and its wedges send nothing", function()
    local NS, m = live({})
    NS.Preview.SetPreviewAs("bg:ab")
    assertTrue(NS.Dial.IsOpen("d2"))
    assertNil(next(m.restrictedBindings), "opened from the settings window: no key taken")
    assertEqual(ringTitle(NS), "Arathi Basin")
    m.__click(wedgeTitled(NS, NS.Dial.ShownRing("d2"), "Stables"))
    m.__click(NS.Dial.RingWedges("d2", NS.Dial.ShownRing("d2"))[1])
    assertEqual(#m.sentMacros, 0)
    assertEqual(NS.Dial.Instance("d2").header.qcTest:GetText(), "PREVIEW")
end)

test("dial: [review 3] a key or wedge change in combat waits for combat end, behind the hub's stale hint", function()
    local NS, m = live()
    bindG(NS)
    combat(m, true)
    assertTrue(NS.SchemaRuntime.Set("dial.key", "H", "d2"))
    assertTrue(NS.SchemaRuntime.Set("dial.slices", 8, "d2"))
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.Instance("d2").header.qcStale:IsShown())
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1", "the old key still opens the dial")
    m.__pressKey("G")
    assertTrue(NS.Dial.IsOpen("d2"), "and it works in combat")
    combat(m, false)
    assertNil(m.overrideBindings.G)
    assertEqual(m.overrideBindings.H.name, "QuickCommsDial1")
    assertFalse(NS.Dial.Instance("d2").header.qcStale:IsShown())
    assertEqual(NS.Surfaces.DialPlans().d2.rings[2].size, 8)
    assertEqual(#m.blocked, 0)
end)

test("dial: [review 1] the key opens nothing where no group is active, and is the game's again while disabled", function()
    local NS, m = live({})
    bindG(NS)
    m.__pressKey("G")
    assertFalse(NS.Dial.IsOpen("d2"), "solo in the open world: no ring to show")
    NS.SchemaRuntime.Set("enabled", false)
    -- red under: drop NS.Dial.HideAll() from the stand-down's Teardown in modules/Surfaces.lua
    assertFalse(m.__pressKey("G"))
    assertEqual(#m.blocked, 0)
    NS.SchemaRuntime.Set("enabled", true)
    -- red under: bind the keys only on a key edit (spec §9.4: re-applied on stand-up)
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1", "re-applied on stand-up")
end)

test("dial: [review 3] disabled in combat with the dial open: nothing blocked; combat end hides it and frees the key", function()
    local NS, m = live()
    bindG(NS)
    combat(m, true)
    m.__pressKey("G")
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(#m.blocked, 0)
    assertTrue(NS.Dial.IsOpen("d2"), "held: no protected call in combat")
    combat(m, false)
    assertNil(NS.Dial.Instance("d2"))
    assertNil(m.overrideBindings.G)
    assertEqual(#m.blocked, 0)
end)

test("dial: [review 3] a profile switch in combat waits: the old key still opens the dial, then combat end binds the new", function()
    local NS, m = live()
    bindG(NS)
    combat(m, true)
    NS.addon.db:SetProfile("Other")
    assertTrue(NS.SchemaRuntime.Set("dial.key", "H", NS.db.profile.dialOrder[1]))
    assertEqual(#m.blocked, 0)
    local h = m.__named.QuickCommsDial1
    assertTrue(h.qcStale:IsShown(), "updates after combat")
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1", "the old profile's key until combat ends")
    combat(m, false)
    assertNil(m.overrideBindings.G)
    assertEqual(m.overrideBindings.H.name, "QuickCommsDial1")
    assertFalse(h.qcStale:IsShown())
    assertEqual(#m.blocked, 0)
end)

test("dial: a profile switch binds the new profile's key and releases the old one", function()
    local NS, m = live()
    bindG(NS)
    NS.addon.db:SetProfile("Other")
    assertNil(m.overrideBindings.G, "Other's dial has no key")
    assertTrue(NS.SchemaRuntime.Set("dial.key", "H", NS.db.profile.dialOrder[1]))
    assertEqual(m.overrideBindings.H.name, "QuickCommsDial1")
    NS.addon.db:SetProfile("Default")
    assertEqual(m.overrideBindings.G.name, "QuickCommsDial1")
    assertNil(m.overrideBindings.H)
end)

test("dial: Reset position puts every pad and dial back, through their point rows, on one line", function()
    local NS, m = live()
    assertTrue(NS.Library.SetSurfacePoint("dial", "d2", { "CENTER", "CENTER", 0, 200 }))
    local h = NS.Dial.Instance("d2").header
    assertEqual(select(5, h:GetPoint(1)), 200)
    m.prints = {}
    NS.Surfaces.ResetPositions()
    assertNil(NS.db.profile.dials.d2.point)
    assertEqual(select(5, h:GetPoint(1)), 0)
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("Pad and dial positions reset.", 1, true) ~= nil, m.prints[1])
end)

test("dial: the hub's tooltip says why each group shows, unless the player turned it off", function()
    local NS = live(AB)
    local shown = {}
    NS.PadRender.ShowLines = function(_, title, lines) shown[#shown + 1] = { title = title, lines = lines } end
    local h = NS.Dial.Instance("d2").header
    h:__fire("OnEnter")
    assertEqual(#shown, 1)
    assertEqual(shown[1].title, "Why is this showing?")
    assertEqual(shown[1].lines[1], "Arathi Basin (built-in): Content, Battleground")
    NS.SchemaRuntime.Set("behavior.whyTooltips", false)
    h:__fire("OnEnter")
    assertEqual(#shown, 1)
    assertEqual(NS.Surfaces.WhyLines("d9")[1], "This pad has not been built yet.")
    NS.Preview.SetTestMode(true)
    assertEqual(NS.Surfaces.WhyLines("d2")[1], "Test mode: placeholder wedges that send nothing.")
end)
```

Then update the cases the default dial changes. In `tests/test_surfaces.lua`, case `"surfaces: ACTIVE_GROUPS_CHANGED is sent once per real change of a pad's active groups"`, replace
```lua
    assertEqual(table.concat(heard, ","), "p1")
    NS.Surfaces.Request("again")
    NS.Surfaces.Request("and again")
    -- red under: drop the `sig ~= State.surfaceOrder[id]` check in S.ApplyAll
    assertEqual(table.concat(heard, ","), "p1", "a rebuild with the same groups sends nothing")
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    assertEqual(table.concat(heard, ","), "p1,p1", "back to M+ is a second real change")
```
with
```lua
    assertEqual(table.concat(heard, ","), "p1,d2", "the pad, then the dial")
    NS.Surfaces.Request("again")
    NS.Surfaces.Request("and again")
    -- red under: drop the `sig ~= State.surfaceOrder[id]` check in S.ApplyAll
    assertEqual(table.concat(heard, ","), "p1,d2", "a rebuild with the same groups sends nothing")
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    assertEqual(table.concat(heard, ","), "p1,d2,p1,d2", "back to M+ is a second real change")
```
and, in case `"surfaces: [review 1] a situation change in combat queues: nothing blocked, stale shows, combat end rebuilds"`, replace
```lua
    assertEqual(table.concat(rebuilt, ","), "p1:true")
```
with
```lua
    assertEqual(table.concat(rebuilt, ","), "p1:true,d2:true")
```
and
```lua
    assertEqual(table.concat(rebuilt, ","), "p1:true,p1:false")
```
with
```lua
    assertEqual(table.concat(rebuilt, ","), "p1:true,d2:true,p1:false,d2:false")
```

In `tests/test_pad.lua`, case `"pad: a rebuild with fewer chips parks the rest, disarmed, for the next"`, replace
```lua
    local NS = applied()
    local inst = NS.Pad.Instance("p1")
    NS.Library.SetBuiltinEnabled("bi.mplus", false)
```
with
```lua
    local NS = applied()
    local inst = NS.Pad.Instance("p1")
    local before = NS.SendEngine.ButtonCount()   -- the pad's eight chips and the default dial's wedges
    NS.Library.SetBuiltinEnabled("bi.mplus", false)
```
and
```lua
    assertEqual(NS.SendEngine.ButtonCount(), 8, "the same eight buttons, reused")
```
with
```lua
    assertEqual(NS.SendEngine.ButtonCount(), before, "the same buttons, reused")
```
and, in case `"pad: Sync releases a pad no plan names: hidden, its chips disarmed"`, replace
```lua
    assertEqual(#NS.SendEngine.ArmedButtons(), 0)
    assertFalse(inst.live)
```
with
```lua
    for _, b in ipairs(NS.SendEngine.ArmedButtons()) do assertTrue(b.qcMeta.surfaceId ~= "p1", "only the dial's stay armed") end
    assertFalse(inst.live)
```

In `tests/test_diagnostics.lua`, replace
```lua
    assertTrue(text:find("buttons=8 armed=8", 1, true) ~= nil, text)
```
with
```lua
    -- the pad's 8 chips, and the default dial's 11 wedges: 1 group wedge, then 8 callouts on three
    -- pages of 4 (two More wedges), so 16 armed
    assertTrue(text:find("buttons=19 armed=16", 1, true) ~= nil, text)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_dial` (no dial is built by a situation read: `Dial.Instance("d2")` is nil), and in the four updated cases.

- [ ] **Step 3: Surfaces: every slot, the dial's plans**

In `modules/Surfaces.lua`, replace the header comment's first paragraph's end and add a dial paragraph: replace
```lua
-- carry no line, drawn through the same render path (preview-mode). A "Preview as…" plan is a real
-- plan for the previewed snapshot, marked so every chip is disarmed (spec §13.3).
```
with
```lua
-- carry no line, drawn through the same render path (preview-mode). A "Preview as…" plan is a real
-- plan for the previewed snapshot, marked so every chip is disarmed (spec §13.3).
--
-- A Comms Dial's plan (spec §11) is the same resolve and bake in rings: its active groups in its
-- order, a node set's children as nodes, each slot baked, then modules/Dial_Layout.lua's Rings.
```
and replace the edge paragraph
```lua
-- THE EDGE (below): one entry point, Request, for everything that changes what a pad draws: the
-- situation, the library, the profile, test mode, a settings write and the stand-up. Out of combat
-- it rebuilds every enabled pad from the CURRENT snapshot at once; in combat it files one keyed
-- entry ("surfaces") in SendEngine's combat-end queue, shows each pad's stale hint and sends
-- SURFACE_REBUILT (id, true); the drain rebuilds from the snapshot as it is THEN, and
-- COMBAT_QUEUE_DRAINED clears the hints (spec §9.1, §18). A profile switch first drops the old
-- profile's rebuild and positions entries; a held drag's stop stays queued. RESTRICTION_CHANGED only re-reads the locks, the lockdown chip and the fade,
-- which are insecure and change in combat too. The stand-down hands the secure half (hide every
-- pad, disarm every chip) to SendEngine.Teardown, which holds it to combat end if need be.
```
with
```lua
-- THE EDGE (below): one entry point, Request, for everything that changes what a pad or a dial
-- draws: the situation, the library, the profile, test mode, a settings write and the stand-up. Out
-- of combat it rebuilds every enabled pad and dial from the CURRENT snapshot at once (the dials'
-- rebuild also re-binds their keys); in combat it files one keyed entry ("surfaces") in
-- SendEngine's combat-end queue, shows each pad's and dial hub's stale hint and sends
-- SURFACE_REBUILT (id, true); the drain rebuilds from the snapshot as it is THEN, and
-- COMBAT_QUEUE_DRAINED clears the hints (spec §9.1, §18). A profile switch first drops the old
-- profile's rebuild and positions entries; a held drag's stop stays queued. RESTRICTION_CHANGED only
-- re-reads the locks, the lockdown chip and the fade, which are insecure and change in combat too.
-- The stand-down hands the secure half (hide every pad, release every dial, disarm every send
-- button, unbind every key) to SendEngine.Teardown, which holds it to combat end if need be.
```

Replace
```lua
function S.MarkPreview(plan, key)
    plan.test, plan.preview = true, key
    for _, sec in ipairs(plan.sections) do
        for _, slot in ipairs(sec.slots) do slot.preview = true end
    end
    return plan
end
```
with
```lua
function S.MarkPreview(plan, key)
    plan.test, plan.preview = true, key
    S.EachSlot(plan, function(slot) slot.preview = true end)
    return plan
end

--- Every slot of a pad's plan (its sections) or a dial's (its rings' callout items).
function S.EachSlot(plan, fn)
    for _, sec in ipairs(plan.sections or {}) do
        for _, slot in ipairs(sec.slots) do fn(slot) end
    end
    for _, ring in ipairs(plan.rings or {}) do
        for _, item in ipairs(ring.items) do
            if item.slot then fn(item.slot) end
        end
    end
end

--- One dial's plan (spec §11): its active groups in its order (D6), a node set's children as nodes,
--- each slot baked, then the rings (Dial_Layout.Rings, Categories or Flat, open-into, pages).
--- @param dial table profile.dials[surfaceId]
--- @return table plan
function S.BuildDialPlan(surfaceId, dial, snap, deps)
    local t0 = Perf.on and debugprofilestop()
    dial = type(dial) == "table" and dial or {}
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(dial.groups, active, deps.groups, deps.autoPromote)
    local opts = { soloFallback = deps.soloFallback, ctx = deps.ctx }
    local plan = { kind = "dial", surfaceId = surfaceId, snapshot = snap, order = order, active = active,
        lockdownChip = false, hasActive = #order > 0 }
    local function slotsOf(ids)
        local out = {}
        for _, cid in ipairs(ids or {}) do
            local slot = S.Slot(cid, deps.callout(cid), snap, opts)
            slot.surfaceId = surfaceId
            if slot.lock == "lockdown" then plan.lockdownChip = true end
            out[#out + 1] = slot
        end
        return out
    end
    local groups = {}
    for _, gid in ipairs(order) do
        local g = deps.group(gid)
        local entry = { id = gid, title = g.name, icon = g.icon, openInto = g.openInto == true }
        if type(g.children) == "table" and #g.children > 0 then
            entry.children = {}
            for _, child in ipairs(g.children) do
                local c = deps.group(child)
                if c then
                    entry.children[#entry.children + 1] = { id = child, title = c.name, icon = c.icon,
                        slots = slotsOf(c.callouts) }
                end
            end
        else
            entry.slots = slotsOf(g.callouts)
        end
        groups[#groups + 1] = entry
    end
    plan.rings, plan.openRing = NS.DialLayout.Rings(groups, { mode = dial.mode, slices = dial.slices, title = dial.name })
    if t0 then Perf.Note("bake.surface", debugprofilestop() - t0) end
    return plan
end
```

Replace the whole of `S.TestPlan`, with its doc comment, with:
```lua
-- Test mode's placeholder slots for one section or group: they carry no line and send nothing.
local function testSlots(surfaceId, s)
    local slots = {}
    for i = 1, S.TEST_SLOTS do
        slots[i] = { calloutId = ("test.%d.%d"):format(s, i), surfaceId = surfaceId,
            name = L["Callout %d"]:format(i), reason = "testMode",
            concrete = (i % 2 == 1) and "party" or "raid" }
    end
    return slots
end

--- Test mode's plan: placeholder chips that send nothing (spec §10.4).
function S.TestPlan(surfaceId)
    local sections = {}
    for s = 1, S.TEST_SECTIONS do
        sections[s] = { groupId = "test." .. s, title = L["Test group %d"]:format(s), slots = testSlots(surfaceId, s) }
    end
    return { surfaceId = surfaceId, snapshot = {}, order = {}, sections = sections, lockdownChip = false,
        hasActive = true, test = true }
end

--- Test mode's dial plan: placeholder groups and wedges that send nothing, laid out as the dial's own
--- (spec §11.4: test mode shows dial 1 open).
function S.TestDialPlan(surfaceId, dial)
    dial = type(dial) == "table" and dial or {}
    local groups = {}
    for s = 1, S.TEST_SECTIONS do
        groups[s] = { id = "test." .. s, title = L["Test group %d"]:format(s), slots = testSlots(surfaceId, s) }
    end
    local rings, open = NS.DialLayout.Rings(groups, { mode = dial.mode, slices = dial.slices, title = dial.name })
    return { kind = "dial", surfaceId = surfaceId, snapshot = {}, order = {}, rings = rings, openRing = open,
        lockdownChip = false, hasActive = true, test = true }
end
```

- [ ] **Step 4: Surfaces: "Why is this showing?" for a dial**

Replace the whole of `S.WhyLines`, with its doc comment, with:
```lua
--- "Why is this showing?" for one pad or dial (spec §13.3): the groups it shows, in priority order,
--- each with the When rows that matched (Resolver.Explain), then every lock in effect on its slots.
--- Read from the last plan, so in combat it explains what is on screen.
--- @return string[]
function S.WhyLines(id)
    local plan = S.Plans()[id] or S.DialPlans()[id]
    if not plan then
        local p = NS.db and NS.db.profile
        if p and p.dials[id] then return { L["This dial has not been built yet."] } end
        return { L["This pad has not been built yet."] }
    end
    if plan.test and not plan.preview then
        if plan.kind == "dial" then return { L["Test mode: placeholder wedges that send nothing."] } end
        return { L["Test mode: placeholder chips that send nothing."] }
    end
    local out = {}
    if plan.preview then out[1] = L["Preview as: %s"]:format(NS.Preview.Label(plan.preview)) end
    if #plan.order == 0 then out[#out + 1] = L["No group matches this situation."] end
    for _, gid in ipairs(plan.order) do
        local g = NS.Library.Group(gid)
        local name = g and g.name or gid
        if NS.Library.IsBuiltin(gid) then name = L["%s (built-in)"]:format(name) end
        out[#out + 1] = NS.Resolver.Explain(name, plan.active and plan.active[gid])
    end
    local locks, seen = {}, {}
    S.EachSlot(plan, function(slot)
        if slot.lock and not seen[slot.lock] then
            seen[slot.lock] = true
            locks[#locks + 1] = slot.lock
        end
    end)
    table.sort(locks)
    for _, lock in ipairs(locks) do out[#out + 1] = NS.PadRender.LOCK_TEXT[lock] or tostring(lock) end
    return out
end
```

- [ ] **Step 5: Surfaces: the edge builds and queues the dials**

Replace
```lua
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
```
with
```lua
-- The enabled pads, or dials, in their order.
local function enabledIds(kind)
    local p = NS.db and NS.db.profile
    local out = {}
    if not p then return out end
    local set = kind == "pad" and p.pads or p.dials
    for _, id in ipairs(kind == "pad" and p.padOrder or p.dialOrder) do
        local s = set[id]
        if type(s) == "table" and s.enabled ~= false then out[#out + 1] = id end
    end
    return out
end
```
replace
```lua
function S.Plans()
    return State.surfacePlans or {}
end
```
with
```lua
function S.Plans()
    return State.surfacePlans or {}
end

function S.DialPlans()
    return State.dialPlans or {}
end
```
replace the whole of `S.ApplyAll`, with its two-line doc comment, with:
```lua
--- Rebuild every enabled pad and dial from the current snapshot, and re-bind the dials' keys. Out of
--- combat (RunOrQueue's caller).
--- @return number surfaces rebuilt
function S.ApplyAll(reason)
    if NS.IsStoodDown() or not State.situation then return 0 end
    local preview = NS.Preview.PreviewSnapshot()
    local snap = preview or NS.Situation.Current()
    local deps = S.Deps(snap)
    local test = preview == nil and NS.Preview.IsTestMode()
    local p = NS.db.profile
    local plans, dialPlans, n = {}, {}, 0
    State.surfaceOrder = State.surfaceOrder or {}
    local function done(id, plan)
        if preview then S.MarkPreview(plan, NS.Preview.PreviewAs()) end
        n = n + 1
        local sig = table.concat(plan.order, ",")
        if sig ~= State.surfaceOrder[id] then
            State.surfaceOrder[id] = sig
            NS.addon:SendMessage(NS.MSG.ACTIVE_GROUPS_CHANGED, id)
        end
        return plan
    end
    for _, id in ipairs(enabledIds("pad")) do
        plans[id] = done(id, test and S.TestPlan(id) or S.BuildPlan(id, p.pads[id], snap, deps))
    end
    for _, id in ipairs(enabledIds("dial")) do
        dialPlans[id] = done(id, test and S.TestDialPlan(id, p.dials[id]) or S.BuildDialPlan(id, p.dials[id], snap, deps))
    end
    State.surfacePlans, State.dialPlans = plans, dialPlans
    local stale = staleSet()
    for id in pairs(stale) do stale[id] = nil end
    NS.Pad.Sync(plans)
    NS.Dial.Sync(dialPlans, p.dialOrder)
    for _, id in ipairs(enabledIds("pad")) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    for _, id in ipairs(enabledIds("dial")) do NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, false) end
    NS.Debug(TAG, "rebuilt %s surface(s) (%s)", n, tostring(reason))
    return n
end
```
in `S.Request`, replace
```lua
    local stale = staleSet()
    for _, id in ipairs(NS.Pad.Ids()) do
        if not stale[id] then
            stale[id] = true
            NS.Pad.SetStale(id, true)
            NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, true)
        end
    end
```
with
```lua
    local stale = staleSet()
    local function mark(ids, setStale)
        for _, id in ipairs(ids) do
            if not stale[id] then
                stale[id] = true
                setStale(id, true)
                NS.addon:SendMessage(NS.MSG.SURFACE_REBUILT, id, true)
            end
        end
    end
    mark(NS.Pad.Ids(), NS.Pad.SetStale)
    mark(NS.Dial.Ids(), NS.Dial.SetStale)
```
replace the whole of `S.RefreshLocks`, with its doc comment, with:
```lua
--- Re-read every slot's lock (spec §8.4), the lockdown chip and the pads' fade. Insecure: runs in combat.
function S.RefreshLocks()
    local plans, dialPlans = State.surfacePlans, State.dialPlans
    if not (plans or dialPlans) then return end
    NS.Situation.Restamp()
    local snap = NS.Situation.Current()
    local showChip = NS.Setting("behavior.lockdownChip") ~= false
    local function relock(plan)
        if plan.test then return false end
        plan.lockdownChip = false
        S.EachSlot(plan, function(slot)
            if slot.concrete then slot.lock = NS.Channels.LockState(slot.concrete, snap) end
            if slot.lock == "lockdown" then plan.lockdownChip = true end
        end)
        return true
    end
    for id, plan in pairs(plans or {}) do
        if relock(plan) then NS.Pad.RefreshLocks(id, plan.lockdownChip and showChip) end
        NS.Pad.ApplyAlpha(id)
    end
    for id, plan in pairs(dialPlans or {}) do
        if relock(plan) then NS.Dial.RefreshLocks(id, plan.lockdownChip and showChip) end
    end
end

--- Master controls' Reset position (spec §10.4): every pad and every dial back to its default place.
function S.ResetPositions()
    NS.Pad.ResetPositions(true)
    NS.Dial.ResetPositions()
    NS.Print(L["Pad and dial positions reset."])
end
```
in `onDrained`, replace
```lua
        stale[id] = nil
        NS.Pad.SetStale(id, false)
```
with
```lua
        stale[id] = nil
        NS.Pad.SetStale(id, false)
        NS.Dial.SetStale(id, false)
```
in `onProfileChanged`, replace
```lua
    NS.SendEngine.Drop("profile", { "surfaces", "positions" })
```
with
```lua
    NS.SendEngine.Drop("profile", { "surfaces", "positions", "dialPositions" })
```
and in the stand-down step replace
```lua
    State.surfacePlans, State.surfaceOrder, State.surfaceStale = nil, nil, nil
    NS.SendEngine.Teardown(function() NS.Pad.HideAll() end)
```
with
```lua
    State.surfacePlans, State.dialPlans, State.surfaceOrder, State.surfaceStale = nil, nil, nil, nil
    NS.SendEngine.Teardown(function()
        NS.Pad.HideAll()
        NS.Dial.HideAll()
    end)
```

- [ ] **Step 6: Reset position covers the dials**

In `modules/Pad.lua`, replace
```lua
--- Master controls' Reset position (spec §10.4): every pad back to its default anchor.
function Pad.ResetPositions()
```
with
```lua
--- The pads' half of Master controls' Reset position (spec §10.4): every pad back to its default
--- anchor. `quiet`: Surfaces.ResetPositions prints one line for pads and dials together.
function Pad.ResetPositions(quiet)
```
and, in it, replace
```lua
    NS.Print(L["Pad positions reset."])
```
with
```lua
    if not quiet then NS.Print(L["Pad positions reset."]) end
```

In `settings/Panel.lua`, replace
```lua
    -- Reset position resets every pad's anchor (spec §10.4); the dials join it in phase 4.
    onResetPosition  = function() if NS.Pad and NS.Pad.ResetPositions then NS.Pad.ResetPositions() end end,
```
with
```lua
    -- Reset position resets every pad and dial anchor (spec §10.4).
    onResetPosition  = function() if NS.Surfaces and NS.Surfaces.ResetPositions then NS.Surfaces.ResetPositions() end end,
```
and in the file's header comment replace `Lock frame, Test mode and Reset position (design spec` with `Lock frame, Test mode and Reset position (every pad and dial, design spec`.

- [ ] **Step 7: Locale keys**

In `locales/enUS.lua`, add at the end:
```lua

-- The Comms Dial's plans and rebuild (modules/Surfaces.lua)
L["This dial has not been built yet."] = "This dial has not been built yet."
L["Test mode: placeholder wedges that send nothing."] = "Test mode: placeholder wedges that send nothing."
L["Pad and dial positions reset."] = "Pad and dial positions reset."
```

- [ ] **Step 8: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0. `test_disabled` stays green: the dial adds no event and no receiver, and its pointer's `OnUpdate` exists only while a dial is open. If any other phase-2/3 case fails, it is counting something the default dial now adds; compare it with the four updated cases before changing anything.

- [ ] **Step 9: Commit**

```bash
git add modules/Surfaces.lua modules/Pad.lua settings/Panel.lua locales/enUS.lua tests/test_dial.lua tests/test_surfaces.lua tests/test_pad.lua tests/test_diagnostics.lua
git checkout -- modules/Surfaces.lua modules/Pad.lua settings/Panel.lua locales/enUS.lua tests/test_dial.lua tests/test_surfaces.lua tests/test_pad.lua tests/test_diagnostics.lua
git commit -m "Surfaces: the dials' plans, rebuilds and keys; Reset position covers dials; the exit paths headless"
```

---
### Task 8: Bindings.xml: Open Comms Dial 1–4 in the key bindings menu

Spec §9.4 and P7: besides each dial's own key, WoW's key bindings menu offers "Open Comms Dial 1–4" under a "Ka0s Quick Comms" header. Each entry is a `CLICK QuickCommsDial<n>:Toggle` binding: it clicks the header at that place in the dial order with the `Toggle` button, exactly as the dial's own key does (and works while the header is hidden, which is how a closed dial is opened). The client reads the menu's labels from globals by name, which `modules/Dial.lua` sets (client-required globals, listed in the Global Constraints): the header, `BINDING_HEADER_QUICKCOMMS`, is an identifier, so it is declared in `.luacheckrc` `globals` beside its reason and assigned as a plain global (lint's rule on write access, met as written; `_G.X = …` would be W122, since `_G` is a read-only global there); the four entry labels, `BINDING_NAME_CLICK QuickCommsDial<n>:Toggle`, hold a space and a colon, cannot be declared there, and are written with `rawset(_G, …)` beside a comment saying why. The file sits at the addon's root and is not a TOC line: **this is the layout-§1 deviation, owner ruling R1.**

**Files:**
- Create: `Bindings.xml`
- Modify: `modules/Dial.lua` (the labels, after `Dial.DROP_SECONDS`), `.luacheckrc` (`globals`), `locales/enUS.lua`
- Test: `tests/test_dial.lua` (append)

**Interfaces:**
- Consumes: Task 4's `DS.HEADER`, `DS.TOGGLE`; Task 6's `NS.Dial`.
- Produces: `Dial.BINDINGS = 4`; the globals `BINDING_HEADER_QUICKCOMMS` and `BINDING_NAME_CLICK QuickCommsDial<n>:Toggle` (n = 1–4); `Bindings.xml`.

- [ ] **Step 0: Read ruling R1 (recorded in pre-flight P2)**

R1 was settled before Task 1. Accepted as a deviation, or the standard changed upstream: run this task. Declined: skip it; Tasks 9 and 11 already carry the strings for that case. An agent's say-so is never the ruling.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_dial.lua`:
```lua
-- ── Bindings.xml (Task 8) ───────────────────────────────────────────────────────────────────

local function readFile(rel)
    local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
    local s = fh:read("*a")
    fh:close()
    return s
end

test("dial: Bindings.xml offers Open Comms Dial 1 to 4, each clicking that dial's header with Toggle", function()
    -- A plain global write leaves the chunk's environment for the process's _G (tests/_kit/loader.lua
    -- makeEnv's __newindex), so the header is read there; cleared first so this load is the writer.
    rawset(_G, "BINDING_HEADER_QUICKCOMMS", nil)
    local NS, m = T.newAddon()
    local xml = readFile("Bindings.xml")
    local names = {}
    for name in xml:gmatch('<Binding name="([^"]+)"') do names[#names + 1] = name end
    assertEqual(#names, NS.Dial.BINDINGS)
    for i, name in ipairs(names) do
        assertEqual(name, ("CLICK QuickCommsDial%d:Toggle"):format(i))
        -- red under: drop the rawset loop from modules/Dial.lua (the menu would show the raw name)
        assertEqual(m["BINDING_NAME_" .. name], ("Open Comms Dial %d"):format(i))
    end
    assertTrue(xml:find('header="QUICKCOMMS"', 1, true) ~= nil)
    -- red under: drop the BINDING_HEADER_QUICKCOMMS line from modules/Dial.lua
    assertEqual(rawget(_G, "BINDING_HEADER_QUICKCOMMS"), "Ka0s Quick Comms")
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        assertTrue(rel ~= "Bindings.xml", "the client loads it by name, never through the TOC")
    end
end)

test("dial: the key bindings menu's click opens the dial, even while it is hidden", function()
    local NS, m = live()
    local h = NS.Dial.Instance("d2").header
    assertFalse(h:IsShown())
    m.__click(h, "Toggle")   -- what "CLICK QuickCommsDial1:Toggle" does
    assertTrue(NS.Dial.IsOpen("d2"))
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_dial` (`Bindings.xml` cannot be opened).

- [ ] **Step 3: Write Bindings.xml**

Create `Bindings.xml` at the repository root:
```xml
<Bindings>
	<!-- Ka0s Quick Comms: Open Comms Dial 1-4 (design spec §9.4, P7). Each clicks the dial header at that
	     place in the dial order (modules/Dial_Secure.lua names them QuickCommsDial<n>) with the Toggle
	     button, as the dial's own key does. The labels are set in modules/Dial.lua. -->
	<Binding name="CLICK QuickCommsDial1:Toggle" header="QUICKCOMMS" category="ADDONS"/>
	<Binding name="CLICK QuickCommsDial2:Toggle" category="ADDONS"/>
	<Binding name="CLICK QuickCommsDial3:Toggle" category="ADDONS"/>
	<Binding name="CLICK QuickCommsDial4:Toggle" category="ADDONS"/>
</Bindings>
```

- [ ] **Step 4: The menu's labels**

In `modules/Dial.lua`, after the line `Dial.DROP_SECONDS = 5 …`, add:
```lua

-- Bindings.xml's "Open Comms Dial 1-4" (spec §9.4). The key bindings menu reads its header and its
-- entries' labels from these globals by name; the client requires them, so they are the one place
-- this addon writes a global that is not a frame. The header is an identifier, declared in
-- .luacheckrc `globals` with its reason. An entry's label is named after its binding, which holds a
-- space and a colon ("BINDING_NAME_CLICK QuickCommsDial1:Toggle"): no identifier can spell it, so it
-- cannot be declared there, and rawset writes it.
Dial.BINDINGS = 4
BINDING_HEADER_QUICKCOMMS = NS.BRAND
for i = 1, Dial.BINDINGS do
    rawset(_G, ("BINDING_NAME_CLICK %s:%s"):format(DS.HEADER:format(i), DS.TOGGLE), L["Open Comms Dial %d"]:format(i))
end
```
In `.luacheckrc`, replace
```lua
globals = {
  "QuickCommsDB",       -- AceDB
  "QuickCommsPerfDB",   -- the diagnostics capture ring (performance-§5)
  "StaticPopupDialogs",
}
```
with
```lua
globals = {
  "QuickCommsDB",       -- AceDB
  "QuickCommsPerfDB",   -- the diagnostics capture ring (performance-§5)
  "StaticPopupDialogs",
  -- modules/Dial.lua: the key bindings menu's header for Bindings.xml, which the client reads by this
  -- name (spec §9.4). Its four entry labels hold a space and a colon, so they are rawset beside a
  -- comment instead of declared here.
  "BINDING_HEADER_QUICKCOMMS",
}
```
and in the file's header comment, at the end of its first paragraph (after `… for the next dial that takes it.`), add ` Bindings.xml's menu labels are set below.`

In `locales/enUS.lua`, add at the end:
```lua

-- The key bindings menu (modules/Dial.lua, Bindings.xml)
L["Open Comms Dial %d"] = "Open Comms Dial %d"
```

- [ ] **Step 5: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0. (The kit's `test_eol` reads only tracked files; Step 6's add-and-checkout gives `Bindings.xml` its CRLF.)

- [ ] **Step 6: Commit**

```bash
git add Bindings.xml modules/Dial.lua .luacheckrc locales/enUS.lua tests/test_dial.lua
git checkout -- Bindings.xml modules/Dial.lua .luacheckrc locales/enUS.lua tests/test_dial.lua
git commit -m "Dial: Bindings.xml offers Open Comms Dial 1-4 in the key bindings menu"
```

---
### Task 9: The Comms Dial page

The editor page for dials (spec §13.1's Comms Dial row), built on phase 3's shared frame exactly as the Comms Pad page is: the band holds the dial picker and New dial (options-ui-§14); the tabs are **General** (Preview as, then Name and Enabled, then Delete dial), **Groups** (Categories or Flat, the depth-3 warning when there is one, then the dial's groups as a drag-to-reorder list with Remove, then Add a group), **Wheel** (wedges per ring, open at, then X and Y and Reset this dial's position), **Binding** (how Relaxed mode works, the key capture, and the key's line: what it opens, or the WoW binding it shares, spec §9.4 / §18) and **Preview** (each ring as the current or previewed situation builds it, wedge by wedge with its compass word). Every field is a member row written to the selected dial; the dial rebuilds and re-binds through `LIBRARY_CHANGED` → `Surfaces.Request`. Relaxed is the only interaction in v0.1.0, so the page has no delay or tap-action control (the C7 upgrade brings them), and depth is §11.3's limit, not a control (owner ruling R5): the Groups tab warns when a battleground node set on the dial would open three rings deep (spec §11.3, `Dial_Layout.DeepGroups` under that battleground's preview). The key capture is AceGUI's `Keybinding` widget; Escape in it answers `""`, which clears the key. A WoW binding on the same key is read through a new Compat shim, `BindingAction`. The page mirrors `settings/Pads.lua` as the phase-3 fix wave left it (Pre-flight P1): New dial takes the lowest free number (`DD.NewName`, as `PD.NewName`), a refused X or Y prints its reason and puts the box back to the stored offset (as `PD.SetOffset` and `offsetBox`), and Defaults is one act, `Library.Batch` around `RestoreDefaults`, so the dials rebuild and re-bind once, not once per row; it keeps the dial's key and position (`resetExempt`, Task 5a). The Preview tab is a listing (owner ruling R3).

**Files:**
- Create: `settings/Dials.lua`
- Modify: `core/Compat.lua` (`BindingAction`), `QuickComms.toc` (after `settings\Pads.lua`), `tests/run.lua`, `locales/enUS.lua`, `.luacheckrc`
- Test: `tests/test_page_dials.lua` (create), `tests/test_compat.lua` (append)

**Interfaces:**
- Consumes: phase 3's `Settings.Editors` (`Ed.Select`, `Ed.Selected`, `Ed.Heal`, `Ed.PickerList`, `Ed.Row`, `Ed.Scalar`, `Ed.Tabs`, `Ed.RegisterPage`, `Ed.ReorderRows`, `Ed.ActionDropdown`, `Ed.ConfirmDelete`, `Ed.RequestRefresh`, `Ed.Live`, `Ed.Snapshot`, `Ed.ACTIVE_DOT`), `Settings.Helpers` (`PageBanner`, `RenderRows`, `RenderGrid`, `TextRow`, `Section`, `InlineButtonPair`, `RestoreDefaults`, `AttachTooltip`, `AceGUI`), `NS.Library.Batch` and `NS.Preview.FindPreset` (phase 3), `tests/page_helpers.lua`; Task 5a's dial rows and `Lib.DIAL_DEFAULT_POINT`; Task 7's `NS.Surfaces.BuildDialPlan`, `NS.Surfaces.Deps`; Task 6's `NS.DialRender.RingTitle`; Task 3's `NS.DialLayout.Direction`, `NS.DialLayout.DeepGroups`; Task 4's `NS.DialSecure.HEADER`, `NS.DialSecure.TOGGLE`.
- Produces:
  - `NS.Compat.BindingAction(key) -> string|nil`
  - `Settings.Dials` (`DD`): `DD.Entries()`, `DD.NewName() -> string`, `DD.Create() -> id`, `DD.Delete(id)`, `DD.Point(id)`, `DD.SetOffset(id, axis, text) -> boolean`, `DD.ResetPoint(id) -> boolean`, `DD.SetKey(id, key) -> boolean`, `DD.KeyLine(id) -> string`, `DD.DepthWarning(id) -> string|nil`, `DD.PreviewLines(id) -> string[]`, `DD.AddableGroups(id)`
  - the page `dials`, titled `Comms Dial`, canvas `QuickCommsDialsPanel`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_compat.lua`:
```lua
test("compat: [phase 4] BindingAction reads the player's WoW binding; none, a secret or a missing API is nil", function()
    local NS, m = T.newAddon()
    m.bindingActions.G = "MOVEFORWARD"
    assertEqual(NS.Compat.BindingAction("G"), "MOVEFORWARD")
    T.assertNil(NS.Compat.BindingAction("H"))
    m.issecretvalue = T.isSecret
    m.bindingActions.G = T.secret("MOVEFORWARD")
    T.assertNil(NS.Compat.BindingAction("G"))
    m.GetBindingAction = nil
    T.assertNil(NS.Compat.BindingAction("G"))
end)
```

Create `tests/test_page_dials.lua`:
```lua
-- tests/test_page_dials.lua — settings/Dials.lua (spec §11, §13.1): the dial picker and New dial,
-- General's acts, Groups (Categories or Flat, the priority list), Wheel with the X/Y position, the
-- Binding tab's key capture and its line, and the Preview tab. Driven headlessly through
-- tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local AB = { inInstance = true, instanceType = "pvp", instanceID = 2107, inGroup = true, inRaid = true,
    inInstanceGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or MPLUS end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Comms Dial")
    NS.addon.Settings.Editors.Select("dial", "d2")
    return NS, m, P
end

local function key(P)
    return P.find(P.tab("dials", "Binding"), "Keybinding", "Key")
end

test("dials page: New dial makes a second dial holding every built-in, selects it, and builds QuickCommsDial2", function()
    local NS, _, P = open()
    P.bannerAction(P.ctx("dials")):__fire("OnClick")
    P.flush()
    local id = NS.State.editing.dial
    assertTrue(id ~= "d2" and NS.db.profile.dials[id] ~= nil)
    assertEqual(NS.db.profile.dials[id].name, "Comms Dial 2")
    assertEqual(#NS.db.profile.dials[id].groups, #NS.BuiltIns.order)
    assertEqual(NS.Dial.Instance(id).header:GetName(), "QuickCommsDial2")
end)

test("dials page: New dial takes the lowest free number, so a delete never leads to two names alike", function()
    local NS = open()
    local Dials = NS.addon.Settings.Dials
    local two = Dials.Create()
    local three = Dials.Create()
    assertEqual(NS.db.profile.dials[three].name, "Comms Dial 3")
    NS.Library.DeleteSurface("dial", two)
    -- red under: name a new dial after the dial count ("Comms Dial 3" twice)
    local again = Dials.Create()
    assertEqual(NS.db.profile.dials[again].name, "Comms Dial 2")
end)

test("dials page: General has Preview as first; Enabled off takes the dial down", function()
    local NS, _, P = open()
    local w = P.redraw("dials")
    assertTrue(P.find(w, "Dropdown", "Preview as") ~= nil, "Preview as is page-wide, first")
    P.find(w, "CheckBox", "Enabled"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.dials.d2.enabled)
    assertNil(NS.Dial.Instance("d2"), "a disabled dial is not built")
end)

test("dials page: Wheel writes wedges per ring and where it opens; X and Y move the dial; Reset puts it back", function()
    local NS, _, P = open()
    local w = P.tab("dials", "Wheel")
    P.find(w, "Dropdown", "Wedges per ring"):__fire("OnValueChanged", 8)
    w = P.tab("dials", "Wheel")
    P.find(w, "Dropdown", "Open at"):__fire("OnValueChanged", "cursor")
    assertEqual(NS.db.profile.dials.d2.slices, 8)
    assertEqual(NS.db.profile.dials.d2.openAt, "cursor")
    w = P.tab("dials", "Wheel")
    P.find(w, "EditBox", "Y offset"):__fire("OnEnterPressed", "120")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
    assertEqual(select(5, NS.Dial.Instance("d2").header:GetPoint(1)), 120)
    w = P.tab("dials", "Wheel")
    P.find(w, "Button", "Reset this dial's position"):__fire("OnClick")
    assertNil(NS.db.profile.dials.d2.point)
end)

test("dials page: a refused X or Y says why and puts the box back to the stored offset", function()
    local NS, m, P = open()
    P.find(P.tab("dials", "Wheel"), "EditBox", "X offset"):__fire("OnEnterPressed", "40")
    local xbox = P.find(P.tab("dials", "Wheel"), "EditBox", "X offset")
    m.prints = {}
    xbox:SetText("90000")   -- as the player's typing leaves it
    xbox:__fire("OnEnterPressed", "90000")
    assertEqual(NS.db.profile.dials.d2.point[3], 40, "off the screen: refused")
    assertTrue(table.concat(m.prints, "\n"):find("off the screen", 1, true) ~= nil, "with its reason")
    -- red under: leave a refused box holding the refused text
    assertEqual(xbox.text, "40")
end)

test("dials page: Defaults puts the dial's rows back as one act, and keeps its key and position", function()
    local NS, _, P = open()
    local S = NS.SchemaRuntime
    S.Set("dial.slices", 8, "d2")
    S.Set("dial.mode", "flat", "d2")
    S.Set("dial.key", "G", "d2")
    S.Set("dial.point", { "CENTER", "CENTER", 0, 120 }, "d2")
    local applied = 0
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) applied = applied + 1 return apply(...) end
    P.ctx("dials").panel.defaultsOnClick()
    NS.Surfaces.ApplyAll = apply
    assertEqual(NS.db.profile.dials.d2.slices, 4)
    assertEqual(NS.db.profile.dials.d2.mode, "categories")
    -- red under: drop Library.Batch from the page's Defaults (one rebuild, and one re-bind, per row)
    assertEqual(applied, 1)
    -- red under: drop dial.key or dial.point from settings/Schema.lua's resetExempt
    assertEqual(NS.db.profile.dials.d2.key, "G")
    assertEqual(table.concat(NS.db.profile.dials.d2.point, ","), "CENTER,CENTER,0,120")
end)

test("dials page: [review 4] the Binding tab binds the key; another dial's is refused naming it; a WoW key warns and binds", function()
    local NS, m, P = open()
    key(P):__fire("OnKeyChanged", "SHIFT-G")
    assertEqual(NS.db.profile.dials.d2.key, "SHIFT-G")
    assertEqual(m.overrideBindings["SHIFT-G"].name, "QuickCommsDial1")
    assertTrue(P.hasText(P.tab("dials", "Binding"), "SHIFT-G opens and closes this dial."))
    local id = NS.addon.Settings.Dials.Create()
    P.flush()
    m.prints = {}
    key(P):__fire("OnKeyChanged", "SHIFT-G")
    assertNil(NS.db.profile.dials[id].key)
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("SHIFT-G already opens Comms Dial.", 1, true) ~= nil, text)
    m.bindingActions.TAB = "TARGETNEARESTENEMY"
    key(P):__fire("OnKeyChanged", "TAB")
    assertEqual(NS.db.profile.dials[id].key, "TAB")
    assertEqual(m.overrideBindings.TAB.name, "QuickCommsDial2", "it still binds")
    assertTrue(P.hasText(P.tab("dials", "Binding"), "TAB is also TARGETNEARESTENEMY in WoW's key bindings."))
    key(P):__fire("OnKeyChanged", "")
    assertEqual(NS.db.profile.dials[id].key, false, "Escape in the box clears the key")
    assertNil(m.overrideBindings.TAB)
end)

test("dials page: Groups switches Categories and Flat, and reorders the dial's groups", function()
    local NS, _, P = open()
    local lists = P.reorderSpy()
    local w = P.tab("dials", "Groups")
    P.find(w, "Dropdown", "Show groups as"):__fire("OnValueChanged", "flat")
    assertEqual(NS.db.profile.dials.d2.mode, "flat")
    local groups = NS.db.profile.dials.d2.groups
    local count, last = #groups, groups[#groups]
    P.tab("dials", "Groups")
    lists[#lists].opts.onMove(count, 1)
    assertEqual(NS.db.profile.dials.d2.groups[1], last)
end)

test("dials page: [phase 4] Groups warns when a node set would open three rings deep, and not once it is first", function()
    local NS, _, P = open()
    local Dials = NS.addon.Settings.Dials
    assertNil(Dials.DepthWarning("d2"), "the shipped order: every node set opens into itself")
    local cid = NS.Library.CreateCallout({ name = "Inc", text = "INC", channel = "smartGroup" })
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.Library.AddToGroup(gid, cid)
    NS.Library.OfferGroup(gid)   -- an always-on group, now at the top of every dial
    P.flush()
    local warning = Dials.DepthWarning("d2")
    -- red under: answer nil from DD.DepthWarning (spec §11.3: depth 3 needs the editor warning)
    assertTrue(warning ~= nil and warning:find("Arathi Basin", 1, true) ~= nil, tostring(warning))
    assertTrue(P.hasText(P.tab("dials", "Groups"), warning))
    NS.SchemaRuntime.Set("dial.mode", "flat", "d2")
    assertNil(Dials.DepthWarning("d2"), "Flat has no depth")
    NS.SchemaRuntime.Set("dial.mode", "categories", "d2")
    NS.Library.RemoveGroupFromSurface("dial", "d2", gid)
    assertNil(Dials.DepthWarning("d2"))
end)

test("dials page: Preview lists the rings wedge by wedge, marking the one the dial opens on", function()
    local _, _, P = open(AB)
    local w = P.tab("dials", "preview")
    assertTrue(P.hasText(w, "Arathi Basin (1 of 2) (opens here)"))
    assertTrue(P.hasText(w, "  2 E: Lumber Mill, opens a ring"))
end)

test("dials page: Delete dial asks, then the dial is gone, its header released, and the page heals", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Dials.Create()
    P.flush()
    assertTrue(NS.Dial.Instance(id) ~= nil)
    local w = P.redraw("dials")
    P.find(w, "Button", "Delete dial"):__fire("OnClick")
    assertTrue(NS.db.profile.dials[id] ~= nil, "asks first")
    P.accept()
    assertNil(NS.db.profile.dials[id])
    assertNil(NS.Dial.Instance(id), "released by Dial.Sync")
    P.flush()
    P.redraw("dials")
    assertEqual(NS.State.editing.dial, "d2")
end)
```

In `tests/run.lua`, add `"test_page_dials",` after `"test_page_pads",`.

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_compat` (`BindingAction` is nil) and `test_page_dials` (no "Comms Dial" subcategory).

- [ ] **Step 3: The Compat shim**

In `core/Compat.lua`, after `Compat.ClassName`'s block and before `-- ── The pad (spec §10.1) ──…`, add:
```lua
-- ── The dial's key (spec §9.4) ───────────────────────────────────────────────────────────────

--- The action the player's own WoW binding gives `key` (a binding name such as MOVEFORWARD, or a
--- CLICK binding), or nil when it has none, it is secret, or the API is absent. Shown, never matched.
function Compat.BindingAction(key)
    if not (GetBindingAction and Compat.IsSafeKey(key)) then return nil end
    local action = PlainString(GetBindingAction(key))
    if action == nil or action == "" then return nil end
    return action
end
```

In `.luacheckrc`, replace
```lua
  -- core/Compat.lua: the editors' display names (shown, never matched).
  "GetRealZoneText", "GetSpecializationInfoByID", "LOCALIZED_CLASS_NAMES_MALE",
```
with
```lua
  -- core/Compat.lua: the editors' display names (shown, never matched).
  "GetRealZoneText", "GetSpecializationInfoByID", "LOCALIZED_CLASS_NAMES_MALE",
  -- core/Compat.lua: the Comms Dial page's warning when a dial's key is also a WoW binding.
  "GetBindingAction",
```

- [ ] **Step 4: Write the page**

Create `settings/Dials.lua`:
```lua
local _, NS = ...
-- settings/Dials.lua — the Comms Dial page (design spec §11, §13.1): one dial at a time.
--
--     band     [ Dial v (picker) ][ New dial ]
--     strip    [ General ][ Groups ][ Wheel ][ Binding ][ Preview ]
--     General  Preview as (page-wide, first), Name, Enabled, then Delete dial
--     Groups   Show groups as (Categories or Flat), the depth-3 warning (spec §11.3), then the dial's
--              groups as a drag-to-reorder list with Remove (its priority order, spec §7), then Add a
--              group
--     Wheel    wedges per ring, open at, then Position: X and Y and Reset this dial's position
--     Binding  how Relaxed mode works, the key capture, and the key's line (what it opens, or the WoW
--              binding it shares, spec §9.4 / §18)
--     Preview  each ring as the current or previewed situation builds it, wedge by wedge
--
-- The band holds the picker and the create action (options-ui-§14). Every field is a member row
-- (settings/SchemaMembers.lua) written to the selected dial; the dial rebuilds, and its key is bound
-- again, through LIBRARY_CHANGED -> Surfaces.Request, which waits for combat end when it must. The key
-- is the `dial.key` row, written by AceGUI's Keybinding widget (Escape in it answers "", no key); the
-- row refuses a key another dial has, naming that dial. Relaxed is the only interaction in v0.1.0 (the
-- C7 fallback), so there is no delay or tap-action control, and depth is spec §11.3's limit, not a
-- control (owner ruling R5): the Groups tab warns when a battleground node set would open three rings
-- deep (DD.DepthWarning). The Preview tab is a listing, not a drawn wheel (owner ruling R3): the wheel
-- itself shows in game (test mode and Preview as… open dial 1). As settings/Pads.lua: New dial takes
-- the lowest free number, a refused X or Y says why and puts the box back, and Defaults is one act
-- (Library.Batch) that keeps the dial's key and position.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "dials"
local GENERAL = L["General"]
local GROUPS = L["Groups"]
local WHEEL = L["Wheel"]
local BINDING = L["Binding"]

local DIRECTION = { N = L["N"], NE = L["NE"], E = L["E"], SE = L["SE"], S = L["S"], SW = L["SW"], W = L["W"],
    NW = L["NW"] }

Settings.Dials = Settings.Dials or {}
local DD = Settings.Dials

local function H() return Settings.Helpers end

function DD.Entries()
    local dials = NS.db.profile.dials
    local out = {}
    for _, id in ipairs(NS.Library.MemberIds("dial")) do out[#out + 1] = { id = id, label = dials[id].name or id } end
    return out
end

--- A new dial's name: "Comms Dial <n>", the lowest n from 2 that no dial is named, so a delete never
--- leads to two dials with one name (as settings/Pads.lua PD.NewName).
function DD.NewName()
    local taken = {}
    for _, dial in pairs(NS.db.profile.dials) do
        if dial.name then taken[dial.name] = true end
    end
    local n = 2
    while taken[L["Comms Dial %d"]:format(n)] do n = n + 1 end
    return L["Comms Dial %d"]:format(n)
end

function DD.Create()
    local id = NS.Library.CreateSurface("dial", DD.NewName())
    if id then
        Ed.Select("dial", id)
        Ed.RequestRefresh()
    end
    return id
end

function DD.Delete(id)
    local dial = NS.db.profile.dials[id]
    if not dial then return end
    Ed.ConfirmDelete(dial.name or id, function() NS.Library.DeleteSurface("dial", id) end)
end

--- The dial's place, or the default one; a copy.
function DD.Point(id)
    local dial = NS.db.profile.dials[id]
    local pt = (dial and type(dial.point) == "table") and dial.point or NS.Library.DIAL_DEFAULT_POINT
    return { pt[1], pt[2], pt[3], pt[4] }
end

--- Move the dial by a typed X or Y offset: the whole `dial.point` row, through the seam. A refusal
--- prints its reason.
function DD.SetOffset(id, axis, text)
    local n = tonumber((text or ""):match("^%s*(-?%d+%.?%d*)%s*$"))
    if not n then
        NS.Print(L["A position is a number of pixels."])
        return false
    end
    local pt = DD.Point(id)
    if axis == "x" then pt[3] = n else pt[4] = n end
    local ok, err, why = NS.SchemaRuntime.Set("dial.point", pt, id)
    if not ok then NS.Print(tostring(why or err)) end
    return ok == true
end

function DD.ResetPoint(id)
    return (NS.SchemaRuntime.Set("dial.point", nil, id)) == true
end

--- Write the dial's key through the seam ("" is no key); a refusal prints its reason.
--- @return boolean
function DD.SetKey(id, key)
    local ok, _, why = NS.SchemaRuntime.Set("dial.key", key or "", id)
    if not ok and why then NS.Print(tostring(why)) end
    return ok == true
end

local function placeOf(id)
    for i, did in ipairs(NS.db.profile.dialOrder) do
        if did == id then return i end
    end
    return nil
end

--- The Binding tab's line: the dial's key and what it does, or the WoW binding it shares (spec §9.4).
function DD.KeyLine(id)
    local dial = NS.db.profile.dials[id]
    local key = dial and dial.key
    if type(key) ~= "string" or key == "" then
        return L["No key yet. Click the box and press one, or bind Open Comms Dial in WoW's key bindings."]
    end
    local action = NS.Compat.BindingAction(key)
    local place = placeOf(id)
    local own = place and ("CLICK %s:%s"):format(NS.DialSecure.HEADER:format(place), NS.DialSecure.TOGGLE)
    if action and action ~= own then
        return L["%s is also %s in WoW's key bindings. While Quick Comms is enabled, it opens this dial instead."]
            :format(key, action)
    end
    return L["%s opens and closes this dial."]:format(key)
end

--- The Groups tab's warning (spec §11.3: depth 3 is allowed, with the editor warning): the
--- battleground node sets on this dial that would open three rings deep in their own battleground,
--- because a group listed above is active there too (built under that battleground's Preview as…
--- snapshot). Nil when there is none, or in Flat, which has no depth.
--- @return string|nil
function DD.DepthWarning(id)
    local dial = NS.db.profile.dials[id]
    if not dial or dial.mode == "flat" then return nil end
    local names = {}
    for _, gid in ipairs(dial.groups) do
        local short = type(gid) == "string" and gid:match("^bi%.bg%.([^.]+)$")
        local def = short and NS.BuiltIns.groups[gid]
        local preset = def and def.children and NS.Preview.FindPreset("bg:" .. short)
        if preset and preset.snapshot then
            local snap = preset.snapshot
            local plan = NS.Surfaces.BuildDialPlan(id, dial, snap, NS.Surfaces.Deps(snap))
            for _, title in ipairs(NS.DialLayout.DeepGroups(plan.rings, plan.openRing)) do names[#names + 1] = title end
        end
    end
    if #names == 0 then return nil end
    return L["Three rings deep: %s. A group listed above it is active in that battleground too, so the dial opens on the groups instead of the nodes. Move the battleground to the top of the list to open straight on its nodes."]:format(table.concat(names, ", "))
end

--- The Preview tab's lines: each ring as the current or previewed situation builds it.
--- @return string[]
function DD.PreviewLines(id)
    local snap = Ed.Snapshot()
    local plan = NS.Surfaces.BuildDialPlan(id, NS.db.profile.dials[id], snap, NS.Surfaces.Deps(snap))
    if #plan.rings == 0 then return { L["Nothing to show: no group on this dial is active here."] } end
    local out = {}
    for r, ring in ipairs(plan.rings) do
        local title = NS.DialRender.RingTitle(ring)
        out[#out + 1] = r == plan.openRing and L["%s (opens here)"]:format(title) or title
        for i, item in ipairs(ring.items) do
            local what = item.title or "?"
            if item.kind == "ring" then what = L["%s, opens a ring"]:format(what) end
            out[#out + 1] = L["  %d %s: %s"]:format(i, DIRECTION[NS.DialLayout.Direction(i, ring.size)] or "", what)
        end
    end
    return out
end

local function groupLabel(gid, active)
    local g = NS.Library.Group(gid)
    local name = g and g.name or gid
    if NS.Library.IsBuiltin(gid) then name = L["%s (built-in)"]:format(name) end
    return ((active and active[gid]) and Ed.ACTIVE_DOT or "") .. name
end

--- The groups the dial does not list: user groups by name, then the top-level built-ins in order.
function DD.AddableGroups(id)
    local on = {}
    for _, gid in ipairs(NS.db.profile.dials[id].groups) do on[gid] = true end
    local out = {}
    for gid, g in pairs(NS.db.profile.groups) do
        if not on[gid] then out[#out + 1] = { id = gid, label = g.name or gid } end
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    for _, gid in ipairs(NS.BuiltIns.order) do
        if not on[gid] then out[#out + 1] = { id = gid, label = groupLabel(gid) } end
    end
    return out
end

local NONE = L["No dials yet. Click New dial to make one."]

local function selected()
    local id = Ed.Selected("dial")
    return (id and NS.db.profile.dials[id]) and id or nil
end

local function renderGeneral(ctx, rows)
    local h = H()
    h.RenderRows(ctx, { Ed.Row("state.previewAs") }, nil, nil, { noHeadings = true })
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    h.InlineButtonPair(ctx, { text = L["Delete dial"],
        tooltip = L["Delete this dial. Its groups and callouts are kept, and its key is released. Asks first."],
        onClick = function() DD.Delete(id) end }, nil)
end

local function renderGroups(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    -- Spec §11.3's editor warning; a mode write refreshes in place, so the line follows it.
    local warn = h.TextRow(ctx, DD.DepthWarning(id) or "")
    Ed.Live(ctx, function() if warn then warn:SetText(DD.DepthWarning(id) or "") end end)
    local list = NS.db.profile.dials[id].groups
    if #list == 0 then
        h.TextRow(ctx, L["This dial lists no group. Add one below."])
    else
        h.TextRow(ctx, L["Higher groups come first on the dial. Drag to reorder."])
        local active = NS.Resolver.ActiveGroups(NS.Library.AllGroups(), Ed.Snapshot())
        local entries = {}
        for i, gid in ipairs(list) do
            entries[i] = { id = gid, label = groupLabel(gid, active),
                remove = function() NS.Library.RemoveGroupFromSurface("dial", id, gid) end }
        end
        Ed.ReorderRows(ctx, PAGE, entries, function(from, to) NS.Library.MoveGroupOnSurface("dial", id, from, to) end)
    end
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Add a group"], L["Add a group to the end of this dial's list."],
        DD.AddableGroups(id), function(gid) NS.Library.AddGroupToSurface("dial", id, gid) end) })
end

-- One offset box. Its refresher (a scalar refresh) puts it back to the stored point after any write.
local function offsetBox(ctx, id, label, axis)
    local index = axis == "x" and 3 or 4
    return { make = function(_, parent, rel)
        local eb = H().AceGUI:Create("EditBox")
        eb:SetLabel(label)
        eb:SetText(tostring(DD.Point(id)[index]))
        if ctx.refreshers then
            ctx.refreshers[#ctx.refreshers + 1] = function() eb:SetText(tostring(DD.Point(id)[index])) end
        end
        eb:SetRelativeWidth(rel or 0.5)
        eb:SetCallback("OnEnterPressed", function(_, _, text)
            -- A refusal (its line already printed) puts the box back to the stored offset.
            if not DD.SetOffset(id, axis, text) then eb:SetText(tostring(DD.Point(id)[index])) end
        end)
        H().AttachTooltip(eb, label, L["Pixels from the middle of the screen. Press Enter to apply."])
        parent:AddChild(eb)
        return eb
    end }
end

local function renderWheel(ctx, rows)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
    h.Section(ctx, L["Position"])
    h.RenderGrid(ctx, { offsetBox(ctx, id, L["X offset"], "x"), offsetBox(ctx, id, L["Y offset"], "y") })
    h.InlineButtonPair(ctx, { text = L["Reset this dial's position"],
        tooltip = L["Put this dial back in the middle of the screen."], onClick = function() DD.ResetPoint(id) end }, nil)
end

-- The key capture: AceGUI's Keybinding widget. Its refresher puts it back to the stored key after a
-- refused write. (The headless recorder has no SetKey; the guard keeps the page drawable there.)
local function keyBox(ctx, id)
    local function show(kb)
        local k = NS.db.profile.dials[id] and NS.db.profile.dials[id].key
        if kb.SetKey then kb:SetKey(type(k) == "string" and k or "") end
    end
    return { make = function(_, parent, rel)
        local kb = H().AceGUI:Create("Keybinding")
        kb:SetLabel(L["Key"])
        show(kb)
        if ctx.refreshers then ctx.refreshers[#ctx.refreshers + 1] = function() show(kb) end end
        kb:SetRelativeWidth(rel or 0.5)
        kb:SetCallback("OnKeyChanged", function(_, _, value) DD.SetKey(id, value) end)
        H().AttachTooltip(kb, L["Key"], L["Click, then press the key you want, with Alt, Ctrl or Shift if you like. Escape clears it."])
        parent:AddChild(kb)
        return kb
    end }
end

local function renderBinding(ctx)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    h.TextRow(ctx, L["Relaxed: press the key to open the dial and click a wedge to send. The key again, Escape or a right click closes it; a click in the middle goes back a ring. The number keys 1 to 8 pick a wedge, and the mouse wheel turns pages."])
    h.RenderGrid(ctx, { keyBox(ctx, id) })
    local line = h.TextRow(ctx, DD.KeyLine(id))
    Ed.Live(ctx, function() if line then line:SetText(DD.KeyLine(id)) end end)
    h.TextRow(ctx, L["WoW's key bindings menu also lists Open Comms Dial 1 to 4, under Ka0s Quick Comms."])
end

local function renderPreview(ctx)
    local h = H()
    local id = selected()
    if not id then
        h.TextRow(ctx, NONE)
        return
    end
    local label = h.TextRow(ctx, table.concat(DD.PreviewLines(id), "\n"))
    Ed.Live(ctx, function() if label then label:SetText(table.concat(DD.PreviewLines(id), "\n")) end end)
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return out
end

local function render(ctx)
    local h = H()
    local entries = DD.Entries()
    local sel = Ed.Heal("dial", ids(entries))
    local list, order = Ed.PickerList(entries)
    h.PageBanner(ctx, {
        label = L["Dial"], list = list, order = order, value = sel,
        tooltip = L["Which Comms Dial this page edits."],
        onSelect = function(v)
            Ed.Select("dial", v)
            Ed.RequestRefresh()
        end,
        action = { text = L["New dial"], tooltip = L["Make a new Comms Dial showing every built-in set, and edit it here."],
            onClick = DD.Create },
    })
    Ed.Tabs(ctx, PAGE, {
        { key = GENERAL, render = renderGeneral },
        { key = GROUPS, render = renderGroups },
        { key = WHEEL, render = renderWheel },
        { key = BINDING, render = renderBinding },
        { key = "preview", label = L["Preview"], tooltip = L["What each ring holds here, or in the preview."],
          render = renderPreview },
    })
end

Ed.RegisterPage(PAGE, L["Comms Dial"], "DialsPanel", render, {
    tooltip = L["Put the selected dial's groups-as, wedges per ring and where it opens back to their defaults, and turn it on. Its name, groups, key and position are kept."],
    -- One act (Library.Batch): the dials rebuild, and their keys re-bind, once, not once per row.
    onClick = function(ctx) NS.Library.Batch(function() H().RestoreDefaults(PAGE, ctx) end) end,
})
```

**If the owner declined `Bindings.xml` (ruling R1):** in `DD.KeyLine` use `L["No key yet. Click the box and press one."]` for the no-key line, drop the last `h.TextRow` of `renderBinding` (the line naming WoW's key bindings menu), and in Step 5 add the shorter key in place of the two it replaces. Nothing else on the page depends on R1.

- [ ] **Step 5: The TOC line and the locale keys**

In `QuickComms.toc`, after the two lines
```
# LOAD-BEARING: takes Settings.Editors at load and registers the Comms Pad page (after Groups).
settings\Pads.lua
```
add
```
# LOAD-BEARING: takes Settings.Editors at load and registers the Comms Dial page (after Comms Pad, before Share).
settings\Dials.lua
```
and change the Share line's comment from `(after Comms Pad, before Profiles)` to `(after Comms Dial, before Profiles)`.

In `locales/enUS.lua`, add at the end:
```lua

-- Comms Dial page (settings/Dials.lua)
L["N"] = "N"
L["NE"] = "NE"
L["E"] = "E"
L["SE"] = "SE"
L["S"] = "S"
L["SW"] = "SW"
L["W"] = "W"
L["NW"] = "NW"
L["Comms Dial %d"] = "Comms Dial %d"
L["No key yet. Click the box and press one, or bind Open Comms Dial in WoW's key bindings."] = "No key yet. Click the box and press one, or bind Open Comms Dial in WoW's key bindings."
L["%s is also %s in WoW's key bindings. While Quick Comms is enabled, it opens this dial instead."] = "%s is also %s in WoW's key bindings. While Quick Comms is enabled, it opens this dial instead."
L["%s opens and closes this dial."] = "%s opens and closes this dial."
L["Nothing to show: no group on this dial is active here."] = "Nothing to show: no group on this dial is active here."
L["%s (opens here)"] = "%s (opens here)"
L["%s, opens a ring"] = "%s, opens a ring"
L["  %d %s: %s"] = "  %d %s: %s"
L["No dials yet. Click New dial to make one."] = "No dials yet. Click New dial to make one."
L["Delete dial"] = "Delete dial"
L["Delete this dial. Its groups and callouts are kept, and its key is released. Asks first."] = "Delete this dial. Its groups and callouts are kept, and its key is released. Asks first."
L["This dial lists no group. Add one below."] = "This dial lists no group. Add one below."
L["Higher groups come first on the dial. Drag to reorder."] = "Higher groups come first on the dial. Drag to reorder."
L["Add a group to the end of this dial's list."] = "Add a group to the end of this dial's list."
L["Pixels from the middle of the screen. Press Enter to apply."] = "Pixels from the middle of the screen. Press Enter to apply."
L["Reset this dial's position"] = "Reset this dial's position"
L["Put this dial back in the middle of the screen."] = "Put this dial back in the middle of the screen."
L["Click, then press the key you want, with Alt, Ctrl or Shift if you like. Escape clears it."] = "Click, then press the key you want, with Alt, Ctrl or Shift if you like. Escape clears it."
L["Relaxed: press the key to open the dial and click a wedge to send. The key again, Escape or a right click closes it; a click in the middle goes back a ring. The number keys 1 to 8 pick a wedge, and the mouse wheel turns pages."] = "Relaxed: press the key to open the dial and click a wedge to send. The key again, Escape or a right click closes it; a click in the middle goes back a ring. The number keys 1 to 8 pick a wedge, and the mouse wheel turns pages."
L["WoW's key bindings menu also lists Open Comms Dial 1 to 4, under Ka0s Quick Comms."] = "WoW's key bindings menu also lists Open Comms Dial 1 to 4, under Ka0s Quick Comms."
L["Dial"] = "Dial"
L["Which Comms Dial this page edits."] = "Which Comms Dial this page edits."
L["New dial"] = "New dial"
L["Make a new Comms Dial showing every built-in set, and edit it here."] = "Make a new Comms Dial showing every built-in set, and edit it here."
L["What each ring holds here, or in the preview."] = "What each ring holds here, or in the preview."
L["Put the selected dial's groups-as, wedges per ring and where it opens back to their defaults, and turn it on. Its name, groups, key and position are kept."] = "Put the selected dial's groups-as, wedges per ring and where it opens back to their defaults, and turn it on. Its name, groups, key and position are kept."
L["Three rings deep: %s. A group listed above it is active in that battleground too, so the dial opens on the groups instead of the nodes. Move the battleground to the top of the list to open straight on its nodes."] = "Three rings deep: %s. A group listed above it is active in that battleground too, so the dial opens on the groups instead of the nodes. Move the battleground to the top of the list to open straight on its nodes."
```

- [ ] **Step 6: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0. `test_setup`'s degraded load still holds only member rows: this page adds none.

- [ ] **Step 7: Commit**

```bash
git add settings/Dials.lua core/Compat.lua QuickComms.toc locales/enUS.lua .luacheckrc tests/test_page_dials.lua tests/test_compat.lua tests/run.lua
git checkout -- settings/Dials.lua core/Compat.lua QuickComms.toc locales/enUS.lua .luacheckrc tests/test_page_dials.lua tests/test_compat.lua tests/run.lua
git commit -m "Settings: the Comms Dial page (picker, groups, wheel with X/Y, key capture with its warning, preview)"
```

---
### Task 10: Diagnostics and `/qc why` for the dials

Spec §16 lists override bindings among the diagnostics sections and the dial among the surfaces; §14's `why` covers "every surface". Two sections join the report after `surfaces`: **dials** (each built dial: its header, key, ring count, the ring it opens on, open now, its active groups, its stale hint and lockdown chip) and **bindings** (every override binding the addon holds and the frame and button it clicks). The armed wedges already appear in the `send` section, as `d2:<calloutId>`. `/qc why` prints each built dial after the pads, through the same `Surfaces.WhyLines`.

**Files:**
- Modify: `modules/Diagnostics.lua` (header comment; two sections; `Sections`), `settings/SlashVerbs.lua` (`V.WhyLines`), `settings/Slash.lua` (the `why` row's description), `locales/enUS.lua`
- Test: `tests/test_diagnostics.lua`, `tests/test_slash.lua`

**Interfaces:**
- Consumes: Task 7's `NS.Surfaces.DialPlans()`, `NS.Surfaces.WhyLines(id)`; Task 6's `NS.Dial.Ids()`, `NS.Dial.Instance(id)`, `NS.Dial.IsOpen(id)`; Task 2's `NS.SendEngine.Bindings()`.
- Produces: diagnostics sections `dials` and `bindings` (in that order, after `surfaces`); `V.WhyLines()` covers dials.

- [ ] **Step 1: Write the failing tests**

In `tests/test_diagnostics.lua`, replace
```lua
        "identity,settings,registration,integrations,situation,restrictions,library,surfaces,send")
```
with
```lua
        "identity,settings,registration,integrations,situation,restrictions,library,surfaces,dials,bindings,send")
```
and append:
```lua
test("diagnostics: [phase 4] the dials and bindings sections name each dial, its key and the override bindings", function()
    local NS = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    NS.SchemaRuntime.Set("dial.key", "G", "d2")
    local text = report(NS)
    assertTrue(text:find("d2 QuickCommsDial1 key=G rings=4 openRing=2 open=false active=bi.mplus stale=false", 1, true)
        ~= nil, text)
    assertTrue(text:find("override bindings=1", 1, true) ~= nil, text)
    assertTrue(text:find("G -> QuickCommsDial1:Toggle", 1, true) ~= nil, text)
    assertTrue(text:find("d2:bi.mplus.pull /p Pulling next pack", 1, true) ~= nil, "the armed wedges")
end)
```

Append to `tests/test_slash.lua`:
```lua
test("slash: [phase 4] `why` covers the dials too", function()
    local NS, _, m = T.enableAddon()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Situation.RefreshNow("test")
    m.prints = {}
    NS.addon:OnSlashCommand("why")
    local text = table.concat(m.prints, "\n")
    assertTrue(text:find("Comms Pad (p1):", 1, true) ~= nil, text)
    assertTrue(text:find("Comms Dial (d2):", 1, true) ~= nil, text)
end)
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_diagnostics` (the section list) and `test_slash` (no dial in `why`).

- [ ] **Step 3: The sections**

In `modules/Diagnostics.lua`, replace the header's last sentence
```lua
-- cover design spec §16's list; override bindings join with the Dial (phase 4).
```
with
```lua
-- cover design spec §16's list, the Comms Dial's and its override bindings included.
```
after the `surfaces` function, add:
```lua
-- The dials (spec §16): each built dial's header, key, rings, the ring it opens on, whether it is open
-- now, its active groups, its stale hint and its lockdown chip.
local function dials(out)
    local plans = NS.Surfaces.DialPlans()
    local stale = NS.State.surfaceStale or {}
    local p = NS.db.profile
    out:joined("Dial", "dials built", NS.Dial.Ids())
    for _, id in ipairs(NS.Dial.Ids()) do
        local inst, plan, d = NS.Dial.Instance(id), plans[id], p.dials[id]
        out:add("Dial", "%s %s key=%s rings=%s openRing=%s open=%s active=%s stale=%s lockdownChip=%s", id,
            inst.header:GetName(), d and d.key, plan and #plan.rings, plan and plan.openRing, NS.Dial.IsOpen(id),
            plan and table.concat(plan.order, ","), stale[id] == true, plan and plan.lockdownChip)
    end
end

-- The override bindings (spec §9.4, §16): every key the addon holds, and the frame and button it clicks.
local function bindings(out)
    local list = NS.SendEngine.Bindings()
    out:add("Bind", "override bindings=%s", #list)
    for _, b in ipairs(list) do out:add("Bind", "%s -> %s:%s", b.key, b.name, b.button) end
end
```
and in `NS.Diagnostics.Sections`, replace
```lua
        { "surfaces",     surfaces },
        { "send",         send },
```
with
```lua
        { "surfaces",     surfaces },
        { "dials",        dials },
        { "bindings",     bindings },
        { "send",         send },
```

- [ ] **Step 4: `/qc why` covers the dials**

In `settings/SlashVerbs.lua`, replace the whole of `V.WhyLines` (and its doc comment) with:
```lua
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
    if #out == 0 then out[1] = L["No pad is showing: nothing has been built yet."] end
    return out
end
```
and in the file's header comment change `Today: \`check\`, \`lock\`, \`unlock\` and \`preview\`.` to `Today: \`check\`, \`lock\`, \`unlock\`, \`preview\` and \`why\`.`

In `settings/Slash.lua`, replace
```lua
    {"why",      L["Say why each pad shows the groups it shows"],
```
with
```lua
    {"why",      L["Say why each pad and dial shows the groups it shows"],
```

In `locales/enUS.lua`, replace the line
```lua
L["Say why each pad shows the groups it shows"] = "Say why each pad shows the groups it shows"
```
with
```lua
L["Say why each pad and dial shows the groups it shows"] = "Say why each pad and dial shows the groups it shows"
```

- [ ] **Step 5: Run the tests to check they pass**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0, including the kit's `test_diagnostics_contract` (each section reads, never acts) and the stood-down report (no dial is built then: `dials built -`).

- [ ] **Step 6: Commit**

```bash
git add modules/Diagnostics.lua settings/SlashVerbs.lua settings/Slash.lua locales/enUS.lua tests/test_diagnostics.lua tests/test_slash.lua
git checkout -- modules/Diagnostics.lua settings/SlashVerbs.lua settings/Slash.lua locales/enUS.lua tests/test_diagnostics.lua tests/test_slash.lua
git commit -m "Diagnostics: the dials and their override bindings; /qc why covers the dials"
```

---
### Task 11: The docs for phase 4

Documentation only, plus the regenerated test inventory and the README badge. It records this phase's readings of the spec and the owner's rulings R1–R5 as they were given in pre-flight P2 (Step 0: each note says which ruling it follows; where the owner took the alternative, write the alternative's note instead, and never write a ruling the owner did not give), describes the dial in the hub and the maps, writes the in-game checks DIAL-1..10 the owner runs in Task 12, and records the layout-§1 deviation as ruled (R1).

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md` (the rulings, Step 0)
- Modify: `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/data-flow.md`, `docs/scope.md`, `docs/slash-dispatch.md`, `docs/compat-layer.md`, `docs/common-tasks.md`, `docs/debug.md`, `docs/performance.md`, `docs/testing.md`, `docs/smoke-tests.md`, `docs/test-cases.md` (regenerated), `README.md`

**Interfaces:**
- Consumes: everything Tasks 1–10 built, by the names they produce.
- Produces: documentation only; no code changes.

- [ ] **Step 0: Write the readings and the rulings into the spec**

In `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`, add each as a *Built (phase 4):* note under the section named (the phase-3 notes are the model). A note marked (R*n*) records an owner ruling: write it only as the owner ruled in P2, adding "(owner, <date>)"; with the alternative taken, describe what was built instead.
- **§4.2, file layout:** in `modules/`, add `Dial_Layout.lua` after `Dial.lua, Dial_Secure.lua, Dial_Render.lua`; under the tree add "*Built (phase 4):* `modules/Dial_Layout.lua` is the dial's pure ring layout (as `Pad_Layout` is the pad's). `Bindings.xml` sits at the root, beside the TOC (the client reads it there; see `docs/ARCHITECTURE.md` → Documented deviations)." (R1: drop the second sentence's parenthesis if the owner changed the standard instead, and the whole second sentence if `Bindings.xml` was declined.)
- **§4.3, the `Dial*` row:** append "*Built (phase 4):* `Dial_Layout` (pure: rings, pages, geometry), `Dial_Secure` (the header's snippets; Relaxed only), `Dial_Render` (insecure regions on the secure frames, as `Pad_Render` paints chips), `Dial` (the frames, the pools, the keys)."
- **§5.1, the `dials` entry:** append "*Built (phase 4):* the member rows are `dial.name`, `dial.enabled`, `dial.mode`, `dial.slices`, `dial.openAt`, `dial.point` and `dial.key` (`false` is no key, and the default place; a named `/qc reset` reaches both, a page's Defaults keeps them); a new dial stores `interaction = "relaxed"`; `delay` and `tapAction` are kept for the C7 upgrade and `depth` for R5, and nothing reads them." In the named-non-setting-state bullet add "`dials[id].point` is the `dial.point` member row, written by the Comms Dial page's X/Y boxes and Reset position (through `Library.SetSurfacePoint`)."
- **§5.4:** append "*Built (phase 4):* step 2 (`perProfile`) moves the generic battleground set below the per-battleground sets on every pad and dial (`Library.MoveGenericBattlegroundLast`), so a node set can be the first active group (D9); `NS.SCHEMA_VERSION` is 2."
- **§9.1, Who owns which buttons, Dials:** append "*Built (phase 4):* each wedge *is* its slot's send button (as §11.2 says), parented to its ring's protected container; the player clicks it, not the header. The header's snippets wrap each wedge's click before SendEngine's hook (the client's wrap replaces the script). A wedge acts on the up edge, and only a left click (or a number key) is a press."
- **§9.2 and §9.3:** append "*Built (phase 4):* a wedge's press dims every chip and every wedge for the guard window, and `SEND_RESULT` flashes the callout's wedges; the dial closes on a send, so both show on the next open, and a drop stays red for 5 s so the player can reopen the dial and see it."
- **§9.4:** append "*Built (phase 4):* a header is named `QuickCommsDial<n>` for its place in the dial order, and the key clicks it with the button `Toggle`; `Bindings.xml`'s entries are `CLICK QuickCommsDial1:Toggle` … `4`. Escape, the left and right mouse buttons and the mouse wheel cannot be a dial's key whatever the modifiers, nor 1–8 without one, because the open dial uses them; one key opens one dial. Every rebuild re-binds the whole set (`SendEngine.BindKeys`), so a profile switch, the stand-up and a key edit re-bind." (R1: without `Bindings.xml`, drop the sentence naming its entries and add "`Bindings.xml` is not shipped (owner, <date>).")
- **§10.4, Position:** replace the phase-2 note "*Built (phase 2):* Reset position resets the pads only; …" with "*Built (phase 2, 4):* Reset position resets every pad and dial anchor, with one chat line; the per-pad X/Y rows arrived with the Pads page (phase 3), the per-dial ones with the Comms Dial page (phase 4)."
- **§11.1:** append "*Built (phase 4):* the paint is insecure regions on the secure frames (the disc and ✕ on the header, spokes and a title per ring, an icon, label, padlock, dim veil and gold hover glow per wedge); the pointer is a plain child whose `OnUpdate` runs only while the dial is open (perf `dial.render`). Node sets are placed clockwise from N in their shipped order; pinning each node to its compass direction moves to phase 5 with the battleground id confirmation (§19 row 5)." (R4; the same note goes under §12.1's "Nodes are pinned to compass directions".)
- **§11.2, after Relaxed mode:** append "*Built (phase 4):* the header is the hub. The ring on screen lives in the header's restricted environment (a snippet global); no snippet writes an attribute, so every attribute and frame ref is written out of combat through SendEngine. Opened by its key, the snippets bind Escape (close), the mouse wheel (pages) and 1–8 (the shown ring's wedges) with `SetBindingClick`, released on close; opened from the insecure side (test mode, Preview as…) they bind nothing, so the settings window keeps Escape. Open at the cursor re-anchors the hub with a restricted `SetPoint("CENTER", "$cursor")` (unverified until DIAL-7)."
- **§11.3:** append "*Built (phase 4):* a ring with more items than its wedges is paged on every ring, Categories included: each page but the last holds `slices − 1` items and a More wedge, and the hub and the wheel go back a page. The wedge count is the slices setting, never grown; a ring that holds a ring (a More included) gets 8 on a 12-slice dial. In Flat a node's callout is titled with its node ("INC 3 · Lumber Mill"). Depth counts rings from the one the dial opens on: groups, then callouts, is 2; a node set reached under the group ring is 3, and the Comms Dial page's Groups tab warns, naming the set (`Dial_Layout.DeepGroups`, built under that battleground's preview); open-into skips the group ring, so a set that opens into itself is 2. On the open-into ring the hub's ✕ goes up to the group ring rather than closing the dial." Then, (R2): "With a single active group, Categories opens straight on its ring, as open-into does; the hub still goes up to it." (R5): "Depth is this limit, not a setting: the Wheel tab has no depth control."
- **§11.4:** append "*Built (phase 4):* test mode and Preview as… open dial 1 on its first ring (or the open-into ring) at its place, with placeholder or disarmed wedges and TEST MODE or PREVIEW above the hub, taking no key (the settings window may be open: Escape still closes it, and 1–8 stay the action bar's); the hub or the dial's key closes it." Then, (R3): "The Comms Dial page's Preview tab lists the rings wedge by wedge; the drawn dial is the in-game preview."
- **§12.1, battleground sets:** append "*Built (phase 4):* the generic battleground set ships after every per-battleground set (and migration step 2 moves it there on stored profiles): D9 opens into the first active group, so a node set must come first."
- **§13.1, the Comms Dial row:** replace its Structure cell with "The banner picker and New dial; no nav rail. Tabs: **General** (Preview as, name, enabled, Delete dial), **Groups** (Categories/Flat, the depth-3 warning, the priority ReorderList, Add a group), **Wheel** (wedges per ring, open at, the X and Y offsets and Reset this dial's position), **Binding** (how Relaxed works; a key capture box; the key's line: what it opens, or the WoW binding it shares, which still binds), **Preview** (each ring wedge by wedge). Quick mode's delay and tap action return with the C7 upgrade." Keep the original cell's wording for any part the owner ruled the other way (R3's drawn preview, R5's depth control).
- **§13.3:** replace "(and the Dial page in phase 4)" with "and the Comms Dial page".
- **§16:** append to the diagnostics list "*Built (phase 4):* the `dials` section (each dial's header, key, rings, open ring, open now, active groups, stale, lockdown chip) and the `bindings` section (every override binding)"; and to the perf list "*Built (phase 4):* `dial.render` is bracketed; the dial open/close scenario in `tests/perf.lua` is phase 5."
- **§17:** `SEND_RESULT` consumers: "Pad, Dial (the flash; built phase 4)"; `ACTIVE_GROUPS_CHANGED` consumers: "none (Surfaces rebuilds pads and dials itself)"; `TEST_MODE_CHANGED` consumers: "Surfaces (rebuilds the pads and dials from the test or preview plan, opening dial 1), the editor pages (repaint)".
- **§19, row 4:** append to the Exit cell "*Built:* see smoke checks DIAL-1..10."
- **§19, row 5:** (R4) add "Node sets pinned to compass directions, with the battleground id confirmation." after "Battleground ID confirmation."

- [ ] **Step 1: ARCHITECTURE.md**

- **Intro:** add `[superpowers/plans/2026-10-13-quickcomms-phase-4.md](superpowers/plans/2026-10-13-quickcomms-phase-4.md)` to the build-order sentence (before "this page describes what exists").
- **Overview:** replace "At the end of phase 3 … The Comms Dial is phase 4." with "At the end of phase 4 the data layer feeds the secure send engine, the Comms Pads and the Comms Dials, and the player edits callouts, groups (with their When), pads, dials and the built-in sets on the Callouts, Groups, Comms Pad, Comms Dial and Share pages; "Preview as…" draws the surfaces in another situation and "Why is this showing?" explains them. A dial opens on its key (or on WoW's key bindings menu, through `Bindings.xml`) in Relaxed mode: click a wedge to send." In the Pool row's Gives cell replace "(one array pool per pad for its chips; the dial's wedges in phase 4)" with "(one array pool per pad for its chips; per dial, one for its ring containers and one per container for its wedges)". In "On screen:" add "the Comms Dial (when its key opens it)".
- **Module Map:** add rows `DialLayout` (pure: rings, pages, open-into, geometry), `DialSecure` (the header's restricted snippets and the ring wiring; asks SendEngine for every write), `DialRender` (the dial's insecure paint and pointer), `Dial` (the dial's frames, pools and keys), `Dials` (the Comms Dial page); note on the `SendEngine` row that it now also owns the dial headers and rings, the wedge wrap, frame refs, snippet runs and the override bindings, and on `Surfaces` that it plans and rebuilds the dials beside the pads.
- **Settings Schema:** in the member-rows paragraph add `dial.*` to the list of kinds and "`key`" to the structured types.
- **Message Bus:** in `SURFACE_REBUILT` and `ACTIVE_GROUPS_CHANGED` note the id may be a dial's; in `TEST_MODE_CHANGED` consumers, "(and opens dial 1)".
- **Slash Commands:** note `why` covers dials.
- **Taint Notes:** replace the sentence "No override binding exists until the Dial (phase 4)." with: "The Comms Dial (Relaxed mode) is one `SecureHandlerClickTemplate` header per dial, `QuickCommsDial<n>`, created by SendEngine; its ring containers are `SecureFrameTemplate` frames and its wedges are send buttons. `modules/Dial_Secure.lua` holds the header's restricted snippets as text and hands them, every attribute and every frame ref to SendEngine out of combat; the snippets themselves write no attribute (the ring on screen is a global in the header's restricted environment; Task 4's case checks the snippet text, and the firewall grep, whose list now includes a header's `SetFrameRef`, `WrapScript` and `Execute`, covers the file). In combat only the snippets act: they show and hide the rings and the hub, anchor the hub at the cursor, and bind Escape, the wheel and 1–8 with `SetBindingClick` while the dial is open from its key, releasing them with `ClearBindings`; an open from the insecure side (test mode, Preview as…, `qc-display`) binds nothing. Each wedge's click is wrapped by the header before SendEngine hooks it (the client's wrap replaces the script, which would drop an earlier hook); a wedge acts on the up edge and only a left click is a press. The dials' keys are override bindings (`SetOverrideBindingClick`) on one SendEngine owner frame, replaced as a set at every rebuild out of combat and cleared by the stand-down (held to combat end if need be). `Bindings.xml` adds `CLICK QuickCommsDial<n>:Toggle` entries to WoW's own key bindings menu; its labels are client-read globals: the header declared in `.luacheckrc` `globals`, the four entry labels (not identifiers) set with `rawset`." (R1: without `Bindings.xml`, drop that last sentence.)
- **Known Limitations:** add: "The Comms Dial is Relaxed only: the hold, flick and release dial, its draw delay and tap action wait for C7 (spec §11.2)." / "A dial whose groups are all inactive opens nothing when its key is pressed (there is no empty ring)." / "Open at the cursor relies on the restricted `SetPoint` accepting `$cursor` (unverified until DIAL-7); the fallback is opening at the dial's place." / "A dial closes on a send, so its guard dim and its drop flash show only on the next open: the dim for the guard window, a drop's red for 5 s; the chat note reports a drop either way." / "Disabled in combat, a dial keeps working (and its key keeps opening it) until combat ends and the held stand-down finishes." / "Test mode or Preview as… ended by a combat whose lockdown began first leaves dial 1 open, its placeholder wedges sending nothing and holding no key, until combat ends (the hub or its key closes it sooner)." / (R4) "Battleground node sets are placed clockwise from N in their shipped order; compass pins come with phase 5's battleground id confirmation."
- **Documentation map:** no new doc. In the Tier 2 table, `compat-layer.md`'s trigger becomes "`core/Compat.lua` publishes 24 shims, three or more".
- **Documented deviations:** as the owner ruled R1 in pre-flight P2: either replace "None." with the table
```
| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| layout-§1 (source never loose at the root) | `Bindings.xml` sits at the addon root and is not a TOC line | The client reads key bindings only from `Bindings.xml` in the addon's root folder (spec §9.4, P7) | 2026-10-13 | The client loading bindings from a TOC-listed path, or the standard naming `Bindings.xml` a root file |
```
or, if the standard changed upstream, keep "None." and cite the new layout-§1 rule in the module map's `Bindings.xml` line.

- [ ] **Step 2: The maps**

- `docs/module-map.md`, **Load order:** insert `modules/Dial_Layout.lua`, `modules/Dial_Secure.lua`, `modules/Dial_Render.lua`, `modules/Dial.lua` after `modules/Pad.lua`, and `settings/Dials.lua` after `settings/Pads.lua`, one line each naming its responsibility; add a line after the TOC list: "`Bindings.xml` (root, not a TOC line): Open Comms Dial 1–4 in WoW's key bindings menu." **Tests:** add `test_dial_layout` (rings, pages, open-into, geometry), `test_dial_secure` (the snippets on a hand-built dial, in and out of combat), `test_dial` (the frames, the rebuild and keys, the three exit paths, `Bindings.xml`), `test_page_dials` (the Comms Dial page), and note that `test_mock_secure` now covers the mock's secure handlers and key bindings.
- `docs/schema.md`: in the profile table, the `dials` row's Set by cell becomes "`Library` (membership and order); member fields through the seam (`dial.name|enabled|mode|slices|openAt|point|key`)"; add `dials[id].point` (the `dial.point` member row: the X/Y boxes, Reset position) and `dials[id].key` (the `dial.key` row; `false` is no key, upper-case otherwise); under **Migrations** add "Step 2 (phase 4, `perProfile`): the generic battleground set below the per-battleground sets on every pad and dial (`Library.MoveGenericBattlegroundLast`). `NS.SCHEMA_VERSION` is 2."
- `docs/settings-panel.md`: add a `Comms Dial` row to the `Page | Covers` table and a `## Comms Dial` section after `## Comms Pad`, copying `settings/Dials.lua`'s header diagram and listing each tab's rows; replace **Still to come** with "Share's Export and Import tabs (phase 5), and Quick mode's delay and tap action with the C7 upgrade" (R3, R5: if the owner took an alternative whose task is not done yet, name it there too).
- `docs/data-flow.md`: add after "Today: Preview as…":

> ## Today: the Comms Dial
>
> A rebuild (`Surfaces.ApplyAll`, out of combat) builds each enabled dial's plan (`Surfaces.BuildDialPlan`: the active groups in the dial's order, each slot baked, then `Dial_Layout.Rings`), and `Dial.Sync` re-acquires the dial's ring containers and wedges, arms each callout wedge with its baked line, hands the rings to the header (`DialSecure.Load`, through SendEngine) and re-binds every dial's key (`SendEngine.BindKeys`). Pressing the key clicks the header with `Toggle`: its snippet shows the ring the plan opens on and binds Escape, the wheel and 1–8. A group wedge's wrapped click shows that group's ring; a callout wedge's click sends its `macrotext` (the hook tracks it like a chip's) and its post snippet closes the dial. In combat only the snippets run; a change waits for combat end behind the hub's stale hint.

  and in "The design's callout pipeline" paragraph replace "apart from the Dial and the bindings (phase 4);" with "including the Dial and its bindings;".
- `docs/scope.md`: rename "What exists at the end of phase 3" to "What exists at the end of phase 4", add "Phase 4 added the Comms Dial in Relaxed mode: a key (or WoW's key bindings menu) opens it, a click on a wedge sends, a group wedge opens its ring, battleground node sets open straight on their nodes, and the Comms Dial page sets it up.", replace "The Comms Dial is phase 4." accordingly, and point the closing sentence at the phase 4 plan too. Under "What it deliberately does not do (yet)", add "the hold, flick and release dial (C7)".
- `docs/slash-dispatch.md`: the `why` row's Handler cell now reads "`NS.SlashVerbs.Why`: each built pad, then each built dial, then `Surfaces.WhyLines` (the groups shown, each with the When rows that matched, then the locks)"; under the table add "`/qc set dial.key shift-g` (or `none`) binds or frees a dial's key on the CLI; `/qc set dial.point x y` moves it."
- `docs/compat-layer.md`: change "Twenty-three shims" to "Twenty-four shims" and "answers `23`" to "answers `24`"; add the row `BindingAction(key)` | `GetBindingAction` | a secret, empty or unsafe key is `nil` | `nil` | `settings/Dials.lua` (the Binding tab's warning).
- `docs/common-tasks.md`: add

> ## Change what the dial does in combat
>
> The dial's in-combat behavior is the restricted snippets in `modules/Dial_Secure.lua` (`ONCLICK`, `OPEN`, `SHOW`, `CLOSE`, `WEDGE_PRE`, `WEDGE_POST`). A snippet may show, hide, anchor and bind, and reads attributes; it never writes one (the firewall greps the file). Anything it needs to know arrives as an attribute written by `DialSecure.Load` out of combat. Pin the change in `tests/test_dial_secure.lua`, in and out of combat; `tests/wow_mock.lua` runs the snippets in the header's own environment.

- `docs/debug.md`: in the diagnostics table, add after `surfaces` the rows `dials` | "each built dial: its id, header (`QuickCommsDial<n>`), key, ring count, the ring it opens on, whether it is open, its ordered active groups, its stale hint and its lockdown chip" and `bindings` | "every override binding the addon holds: the key, and the header and button it clicks"; in the `surfaces` row's text add "(the pads; the dials have their own section)"; in the `send` row, "each armed one with its pad or dial, callout and escaped line". Replace the sentence "The bindings section (spec §16) arrives with the Comms Dial (phase 4)." with nothing (delete it). In **Tags**, after phase 2's list add "and phase 4's: `Dial` (a dial header built, an attribute or header write refused in combat) and `Bind` (the override bindings applied, logged only on a change, or refused in combat)", and change the closing sentence's list to "(spec §16: `Resolver`, `Bake`, `Share`)".
- `docs/performance.md`: "Four are declared" becomes "Five are declared"; the `bake.surface` row's Measures cell becomes "one pad's or dial's plan: resolve, order, bake every slot (and, for a dial, the ring layout)"; add the row `dial.render` | `modules/Dial_Render.lua` | "the pointer's `OnUpdate` while a dial is open: one cursor read, one angle, one texture move"; in the paragraph after the table, drop `dial.render` from "The design's other buckets (…)" so it lists `situation.refresh` and `resolver.resolve`; in **Offline scenarios** the closing sentence becomes "The design's scenarios (a 12-chip pad rebuild, a full dial open and close) arrive with phase 5's `tests/perf.lua`."
- `docs/testing.md`, **The harness:** add phase 4's `test_dial_layout`, `test_dial_secure`, `test_dial` and `test_page_dials` to the sentence listing the suites, and add: "`tests/wow_mock.lua` models the client's secure handlers: a header's `_onclick` and `RunAttribute` snippets run in the header's own environment with protected calls allowed in combat; `WrapScript` (raising if a hook came first), `SetFrameRef`, `Execute`, override bindings, `GetBindingAction`, the cursor, and `__pressKey(key)`, which routes a key through a snippet's binding, then an override binding."

- [ ] **Step 3: smoke-tests.md**

In `docs/smoke-tests.md`, replace the index row
```
| DIAL-1..n | Dial | The Comms Dial and its bindings (reserved, phase 4) |
```
with
```
| DIAL-1..10 | Dial | The Comms Dial (Relaxed), its key and Bindings.xml, the battleground node dial |
```
replace the `## Dial` section's body ("Reserved for the Comms Dial (phase 4): …") with:
```markdown
**DIAL-1. Open and close (Relaxed).** Settings → Comms Dial → Binding: click Key, press G → the line
reads "G opens and closes this dial." Close the settings. In a key (any content with an active group),
press G → the dial opens in the middle of the screen: a dark disc, wedges with icons and white labels
outside the disc, the ✕ hub, and a gold pointer that follows the cursor. Press G → it closes. Open it;
Escape → it closes and the game menu does not open. Open it; right-click a wedge → it closes and nothing
is sent. Result:

**DIAL-2. A wedge sends in a boss (the phase 4 exit).** On a raid or M+ boss, press G and click a
callout wedge → the group sees the line, the dial closes, and there is no "action blocked" error or red
text. With the dial closed, 1 still fires your action bar's first button. Press G again at once → every
wedge is dimmed for about a second (the spam guard). Result:

**DIAL-3. The Categories two-stroke (the phase 4 exit).** With two groups active (an always-on group of
your own and M+ in a key): press G → the first ring shows the groups; click one → its callouts; click
a callout → it is sent. Open again, click a group, click the hub → back to the groups; click the hub
again → the dial closes. Result:

**DIAL-4. The Arathi Basin node dial (the phase 4 exit).** In Arathi Basin: press G → the dial opens
straight on the nodes (Stables, Lumber Mill, Blacksmith, More); click Lumber Mill, then INC 3 → instance
chat shows "INC 3 Lumber Mill": two clicks. Open again; click More → Gold Mine and Farm; the hub goes
back a page. (If it opens on the group ring instead, check the Groups tab: Arathi Basin must sit above
Battleground (generic) and every group active there, and the tab's "Three rings deep" warning names the
cause; a `/reload` after updating runs the migration that moves the generic set. If the dial does not
show Arathi Basin at all, the instance id may be wrong: run `/qc diagnostics`, copy the `situation`
section's instanceID into the "Battleground instance IDs seen" table of
`docs/brainstorm/go-no-go/round-4-build-checks.md`, and file it with this check's ID; phase 5 confirms
the ids.) Result:

**DIAL-5. Number keys, the wheel and pages.** Wheel → Wedges per ring 4, in a key: open, press 3 → the
third wedge's callout is sent; open, scroll down → the next page, up → back; the More wedge does the
same. After the dial closes, 1–8, Escape and the mouse wheel do what they did before. Result:

**DIAL-6. Key bindings and conflicts.** Escape → Options → Keybindings → AddOns → "Ka0s Quick Comms"
lists Open Comms Dial 1 to 4; bind Open Comms Dial 1 to F → F opens dial 1 like its own key. On the
Binding tab set the key to TAB → the line warns that TAB is also a WoW binding, and TAB opens the dial;
`/qc disable` → TAB targets again; `/qc enable` → TAB opens the dial again. New dial → give it TAB →
refused with "TAB already opens Comms Dial."; give it 3, or the mouse wheel → refused, saying the open
dial uses them; ALT-3 is taken. (R1: without `Bindings.xml`, drop this check's first sentence.) Result:

**DIAL-7. Open at the cursor, the dial's place, Reset position.** Wheel → Open at → At the cursor →
press G away from the middle → the dial opens centered on the cursor, in combat too (unverified: a
restricted `SetPoint` to `$cursor`). Back to At its place; set Y to 150 → it opens higher; Reset this
dial's position → the middle again. General → Master controls → Reset position → pads and dials back,
one chat line. Result:

**DIAL-8. Edits and disable in combat.** In combat: `/qc set dial.key H` → no error, and the hub shows
"updates after combat" when G opens it; after combat H opens it and G no longer does. In combat with
the dial open: `/qc disable` → no error, the dial keeps working until combat ends, then it is gone and
the key is the game's again. Result:

**DIAL-9. Test mode and Preview as.** Out of combat: `/qc test` → dial 1 opens at its place with
placeholder wedges and TEST MODE above the hub; clicking sends nothing; 1 still fires the action bar.
Comms Dial → General → Preview as → Arathi Basin → the dial opens on the nodes with PREVIEW; nothing
sends; Escape closes the settings window (not the dial), which ends the preview and closes the dial.
Turn test mode on, then pull a target dummy → test mode ends; the dial closes at once or, if combat
won the race, at combat end, and in between 1–8 and Escape still do what they always do. Result:

**DIAL-10. The hub and the drop flash.** Hover the hub → "Why is this showing?" lists the groups and their matched rows;
with a Say callout on the dial during an encounter, LOCKDOWN shows above the hub; Behavior → Explain
why groups show off → no tooltip. `/qc why` lists the dials too; `/qc diagnostics` has `dials` and
`bindings` sections naming the key. If a wedge's send is ever reported dropped (the [QC] note), reopen the
dial within 5 s → that wedge shows red. Result:
```
and add `DIAL-1..10` to the **Pending sign-off** table with origin "Phase 4: the Comms Dial".

- [ ] **Step 4: test-cases.md and the README**

Run:
```bash
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -3
```
In `README.md`:
- Set the `Tests` badge to the run's passing / total counts (`Tests-<X>%2F<Y>_passing`), matching `docs/test-cases.md`'s Total.
- Replace "The Comms Dial comes in a later build." with "The Comms Dial works too: give it a key on the Comms Dial page (or in WoW's key bindings menu), press it, and click a wedge to send. In a battleground it opens straight on the map's nodes."
- In Usage, add: "Settings → Comms Dial → Binding sets the dial's key. Press it to open the dial; click a group to open its callouts, click a callout to send it. The key again, Escape or a right click closes it; the number keys 1 to 8 pick a wedge."

- [ ] **Step 5: Run the gate**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, including the kit's `test_prose` (US English in every edited doc) and `test_layout_cap`.

- [ ] **Step 6: Commit**

```bash
git add docs/ README.md
git checkout -- docs/ README.md
git commit -m "Docs: phase 4 Comms Dial; smoke checks DIAL-1..10; spec rulings"
```

---

### Task 12: In-game smoke test (owner)

The §19 exit criteria for phase 4, run by the owner in the client. An agent never marks a check passed.

**Files:**
- Modify (owner only): `docs/smoke-tests.md` (the `Result:` lines)

**Interfaces:**
- Consumes: the whole phase.
- Produces: the recorded results.

- [ ] **Step 1: Install and load**

Link the repo into `Interface\AddOns\QuickComms`, `/reload`, and run INSTALL-1 and PANEL-1 again: no Lua error; the settings sidebar reads General, Callouts, Groups, Comms Pad, Comms Dial, Share, Profiles; Escape → Options → Keybindings → AddOns lists "Ka0s Quick Comms".

- [ ] **Step 2: The exit criteria (spec §19, row 4)**

| Exit criterion | Smoke checks |
|---|---|
| Open the dial, click a wedge and it sends in a boss | DIAL-1, DIAL-2 |
| The Categories two-stroke works | DIAL-3 |
| The Arathi Basin node dial sends "INC 3 Lumber Mill" in two clicks | DIAL-4 |

Then run DIAL-5 to DIAL-10, and PAD-2 and EDIT-5 again (the pads share the rebuild the dial joined), recording each `Result:` line with the date, the client build and pass or fail. DIAL-1, DIAL-2 and DIAL-7 also exercise what round 4 left unverified for the dial (C7's restricted environment: the snippets' bindings in combat, the hidden header's click, `$cursor`); a failure there is filed against spec §11.2 with the check's ID.

- [ ] **Step 3: Capture what fails**

For any failure: `/qc diagnostics`, copy the `situation`, `surfaces`, `dials`, `bindings` and `send` sections, and file an issue with the check's ID. The `situation` section's instanceID is what DIAL-4 needs when the dial does not show Arathi Basin: the shipped ids are unconfirmed until phase 5. A Lua error names the file and line; attach it as text.

- [ ] **Step 4: Commit the results (owner)**

```bash
git add docs/smoke-tests.md && git checkout -- docs/smoke-tests.md
git commit -m "Smoke: phase 4 results"
```

---
## Self-review

**1. Spec coverage (phase 4):**

| Spec section | Task |
|---|---|
| §19 row 4: `Dial_Secure`, Relaxed only (§11.2; the round-4 C7 fallback) | 2 (the secure API), 4 (the snippets) |
| §19 row 4: `Dial_Render` (§11.1, §11.4) | 6 |
| §19 row 4: the Comms Dial page (§13.1) | 5a (rows), 9 |
| §19 row 4: `Bindings.xml` (§9.4, P7) | 8 (ruling R1, pre-flight) |
| §19 row 4: the battleground node dial with open-into (§11.3, §12.1, D9) | 3 (open-into), 5b (the order and migration step 2), 7 (the AB exit path) |
| §19 row 4 exits: a wedge sends in a boss; the Categories two-stroke (P4); AB in two clicks | 4, 7 (headless), 12 (DIAL-2, DIAL-3, DIAL-4, with DIAL-4's fallback for an unconfirmed instance id) |
| §9: SendEngine the only secure writer; `Dial_Secure` writes through it | 2 (the `[firewall]` list widened to a header's `SetFrameRef`, `WrapScript`, `Execute`), 4 (the snippet check) |
| §9.1: a dial's send buttons, one per slot | 4, 6 (the reading recorded by 11) |
| §9.2, §9.3: the wedge dims for the guard window; a dropped wedge flashes red | 6 (`Dial.Cooldown`, the `SEND_RESULT` flash, shown on the next open) |
| §9.4: `SetOverrideBindingClick` out of combat; re-applied at login, profile switch, stand-up; cleared on stand-down (held in combat); conflict warning that still binds | 2, 6 (`Sync`), 7 (every rebuild; the held teardown; the stand-up and the in-combat profile switch, `[review 1]` and `[review 3]`), 9 (the warning) |
| §9.5: stand-down clears override bindings, hides every surface | 6 (the receiver and timers), 7 |
| §10.4: Reset position resets every pad and dial anchor | 6 (`Dial.ResetPositions`), 7 (`Surfaces.ResetPositions`, the Master control) |
| §11.1: disc, spokes, icons, labels outside, gold glow, pointer, ✕ hub; wedges on compass directions | 3 (geometry), 6 (paint); node compass pins are ruling R4 |
| §11.2: key toggles; wedges are secure send buttons; a click sends and closes; Escape, right click, hub close; the ✕ goes up a ring; number keys and the wheel captured while open | 4 |
| §11.3: Categories (default) and Flat; More pages; slices 4/6/8, 12 only on a ring with no children; depth 2, depth 3 with the editor warning; open-into | 3 (`DeepGroups`, ring depth), 9 (the warning); the single-group shortcut is ruling R2 |
| §11.4: open at center or cursor; test mode shows dial 1 open; the Preview tab; the hub's stale hint and lockdown chip | 4 (cursor, `qc-display`), 6 (hub), 7 (test mode, preview, stale, `[review 6]`), 9 (Preview tab, ruling R3) |
| §13.1: the panel's combat rules; the Comms Dial row | 9 (no page combat guard; Defaults as one act; the reorder list through Library) |
| §13.3: "Why is this showing?" on the dial hub (deferred from phase 3); Preview as on the Dial page | 6 (the hook), 7 (`WhyLines` for dials, the test), 9 (the row) |
| §14: `why` for every surface | 10 |
| §16: diagnostics (override bindings, the dials); perf `dial.render`; debug tags `Dial`, `Bind` | 2 (`Bind`), 6 (`Dial`, the bucket), 10, 11 (`docs/debug.md`, `docs/performance.md`) |
| §17: no new message; the payloads now carry dial ids; Dial consumes `SEND_RESULT` | 6, 7 |
| §18: two dials on one key refused naming the other; a WoW binding conflict warns and binds; a change in combat waits behind the stale hint | 5a, 7, 9 |
| §20: docs | 11 |
| `Library.SetSurfacePoint` for dials | 5a |

**Not in this plan, on purpose:** Quick mode and the C7 upgrade (hold, flick, release; restricted `GetMousePosition`; the draw delay; the tap action); Share's Export and Import; `tests/perf.lua`'s dial scenario; the battleground id confirmation; the audit and the release. Pending the owner (recommended column built, alternative described): R1 `Bindings.xml`, R2 the single-group shortcut, R3 the listed Preview tab, R4 the compass pins, R5 no depth control.

**2. Placeholders:** none. Each code step carries the full code or the exact text it replaces and the text that replaces it; each test step carries the full test. The alternatives of R1–R5 are described by the change they make, for the owner to choose before Task 1; the R1 alternative's strings are given in Task 9.

**3. Type consistency:**
- A dial plan is `{ kind = "dial", surfaceId, snapshot, order, active, rings, openRing, lockdownChip, hasActive, test?, preview? }` in Tasks 6 (the tests' `planOf`), 7 (`BuildDialPlan`, `TestDialPlan`, `MarkPreview`, `EachSlot`, `WhyLines`, `RefreshLocks`), 9 (`DD.PreviewLines`, `DD.DepthWarning`) and 10 (diagnostics).
- A ring is `{ title, page, pages, size, depth, parent, prev, next, items }` and an item `{ kind = "send", slot, title, icon }` or `{ kind = "ring", target, title, icon, more? }` in Tasks 3 (`DL.Rings`, `DL.DeepGroups`), 6 (`Dial.Apply`, `R.PaintRing`, `R.PaintWedge`, `R.RingTitle`, `R.WedgeLines`), 7 and 9.
- `DS.Load(header, rings, opts)` takes `rings[r] = { frame, parent, prev, next, wedges = { { button, target } } }` and `opts = { openRing, openAt }` in Tasks 4 and 6. The header's snippet attributes are `_onclick`, `qc-open`, `qc-display`, `qc-show`, `qc-close`; its data attributes are `qc-rings`, `qc-openRing`, `qc-openAt`, `qc-parent-<r>`, `qc-prev-<r>`, `qc-next-<r>`, `qc-n-<r>`, `qc-name-<r>-<i>`; the wedge's is `qc-target`; the frame refs are `ring<r>`. No name serves two of these: the ring the dial opens on is `qc-openRing`, and `qc-open` is only the open snippet (Task 4's `DS.NewHeader`, `DS.Load` and the `OPEN` snippet alike). The snippets' environment globals are `current` and `display`.
- The header is `DS.HEADER:format(place)` = `QuickCommsDial<place>`, clicked with `DS.TOGGLE` = `"Toggle"` in Tasks 4, 6 (`Sync`'s key list), 8 (`Bindings.xml`, the labels), 9 (`DD.KeyLine`'s own-binding check) and 10 (diagnostics).
- `DS.Open(header)` runs `qc-display` (no key taken) in Tasks 4, 6 (`Sync` in test mode or a preview) and 7.
- `SE.BindKeys(list)` with `{ key, name, button }` entries and `SE.Bindings()` answering the same shape in Tasks 2, 6 and 10; the mock's `overrideBindings[key] = { owner, name, button }` in Tasks 1, 2, 6, 7 and 9.
- A dial's key is `Lib.KeyValue`'s answer, an upper-case string or `false`, in Tasks 5a (`ValidKey` with `RESERVED_KEYS` and `RESERVED_BARE`, `KeyOwner`, the row's `normalize`, the CLI's `PARSE.key` / `FORMAT.key`), 6 (`Sync` binds only a non-empty string), 9 (`DD.SetKey`, `DD.KeyLine`) and 10.
- `Lib.DIAL_DEFAULT_POINT` is the one default place, read at run time by `Dial.lua`'s `applyPoint` (Task 6), the CLI's `parsePoint` (Task 5a) and `DD.Point` (Task 9); nothing takes it at load, so `modules\Library.lua`'s TOC line stays `# Conventional:`. `modules\SendEngine.lua`'s line becomes `# LOAD-BEARING:` in Task 4, naming `modules\Dial_Secure.lua`.
- `NS.Pad.ArmSlot(button, slot)` (Task 6) is the pad's own `arm`, used by `Dial`'s `arm` for callout wedges; `Pad.Cooldown(window)` calls `Dial.Cooldown(window)`, and a wedge's `onPress` calls `Pad.Cooldown` (Task 6).
- The member kinds are `callout`, `group`, `pad`, `dial`, `builtin` in `Settings.INSTANCE_KINDS`, `NO_MEMBER`, `Lib.Member`, `Lib.MemberIds` (`dial` added), `Lib.TEMPLATES` (`dial` added) and `NS.State.editing` (Tasks 5a, 9); the structured types are `point`, `when`, `idset`, `key` in `VALID_TYPES`, `Ed.Scalar`'s `STRUCTURED`, the CLI's `PARSE` / `FORMAT` and `settings/Slash.lua`'s comment (Task 5a); `resetExempt` holds `pad.point`, `dial.point` and `dial.key` (Task 5a).

**4. Review Focus:** each line carries a `[review n]` test: 1 in Task 7; 2 in Task 4; 3 in Task 7 (three cases: an edit, a disable, a profile switch); 4 in Tasks 5a and 9; 5 in Tasks 3 (two cases) and 4; 6 in Tasks 4 and 7.

**5. Gate hazards checked:**
- The firewall grep (`tests/test_sendengine.lua`) reads every TOC file: with the widened list, `modules/Dial_Secure.lua` still matches nothing (it names no template, never says `SecureHandler`, calls `SE.SetAttributes(` and `SE.SetFrameRef(` with a dot, and its snippets use `GetFrameRef`, `RunAttribute`, `SetBindingClick` and `ClearBindings`, which the `[fix wave]` case pins as allowed); no shipped file today calls `:SetFrameRef(`, `:WrapScript(` or `:Execute(` (checked against `feat/phase-3-editors`).
- The attribute name clash: `qc-open` is the snippet, `qc-openRing` the ring (Task 4); Task 4's `[review 6]` case opens on ring 2 through `DS.Open`, which reads it.
- Cases the default dial changes are listed with their replacements in Task 7, Step 1 (`test_surfaces` ×2, `test_pad` ×2, `test_diagnostics`); the battleground reorder and schema step 2 change seven cases, listed in Task 5b, Step 1 (`test_builtins`, `test_database`, `test_profile`, `test_surfaces`, `test_pad` ×2, `test_diagnostics`); `test_database`'s "perProfile step" case now appends past `NS.SCHEMA_VERSION`.
- `tests/test_dial.lua` declares `AB` in Task 7's block, where its first use is, so Task 6's gate has no unused variable (W211).
- `test_eol` reads the working tree: every task edits tracked files in place, and the Line endings constraint says what to do when a tool rewrote one whole.
- `test_disabled`'s "no live timer": the pointer's `OnUpdate` exists only while a dial is open (Task 6), the stand-down closes every dial and cancels the dial's flash and dim timers, and its `SEND_RESULT` receiver follows the pad's.
- `test_setup`'s perf bracket check: `dial.render` is declared and bracketed in the same task (Task 6).
- `test_setup`'s degraded load: the dial rows are member rows (`instance = "dial"`), the only kind allowed there.
- The prose gate: "canceled" spellings; no British forms in the new strings or docs (this plan quotes the spec's own "cancelling" only inside `docs/superpowers/`, which the gate skips).
- `.luacheckrc`: `SetOverrideBindingClick`, `ClearOverrideBindings` (Task 2), `GetCursorPosition` (Task 6), `GetBindingAction` (Task 9) join `read_globals`; `BINDING_HEADER_QUICKCOMMS` joins `globals` with its reason (Task 8), and the four entry labels are `rawset`.
- Applied mechanically, step by step, to a scratch clone of `feat/phase-3-editors` at `818603e`, Tasks 1–10 run green (the gate run after Task 4, then after each task from 5a to 10; 575 passed and luacheck 0 / 0 at the end). That run found the one lint trap fixed here: `_G.BINDING_HEADER_QUICKCOMMS = …` is W122 (`_G` is a read-only global in `.luacheckrc`), so Task 8 assigns the declared global plainly and its test reads the process's `_G`, where the loader's environment sends a global write.
- Phase-3 shapes mirrored as they stand at `818603e` (Pre-flight P1): `PD.NewName`, the refused-offset box, `Library.Batch` around Defaults, `default = false` with `resetExempt`, `Lib.MIN_SURFACE_SCALE`, `Lib.ValidPoint`'s `offScreen`.

## Open questions ruled (the brief said decide and report)

These are readings within the spec's text. The five that depart from binding text are **Owner rulings needed** R1–R5, not ruled here.

1. **Relaxed only.** No Quick mode, no draw delay, no tap action; a new dial stores `interaction = "relaxed"` and the inert fields stay for the C7 upgrade. Depth is not part of C7: §11.3's limit is built, with the Groups tab's warning (Tasks 3 and 9); whether a depth control also exists is R5.
2. **The header is the hub**, named `QuickCommsDial<n>` by the dial's place in the dial order (so `Bindings.xml`'s "Open Comms Dial 1" is the first dial on the page), clicked with the button `Toggle`.
3. **No snippet writes an attribute:** the ring on screen is a global in the header's restricted environment, and every attribute, frame ref, wrap and snippet run is SendEngine's (the firewall's list now names the header's three insecure-side calls).
4. **A wedge is its slot's send button** (§11.2's own words; §9.1 read accordingly), wrapped by the header before SendEngine's hook; it acts on the up edge, a right click closes the dial, and only a left click (or a number key) is a tracked press.
5. **Open-into reaches Arathi Basin by data, not by a new rule.** D9 opens into the *first* active group; the generic battleground set now ships last, and schema migration step 2 (run by Library) moves it on stored profiles.
6. **More pages on every ring**, Categories included; the wedge count is never grown past the slices setting; a ring holding a ring (a More included) gets 8 on a 12-slice dial. In Flat a node's callout names its node.
7. **The paint lives on the secure frames' regions** (as `Pad_Render`'s does), not on a separate unprotected frame, and never sizes or places a protected frame (`Dial.lua` does, under Apply); the pointer is a plain child whose `OnUpdate` exists only while the dial is open. A new pure file, `modules/Dial_Layout.lua`, joins the spec's file list.
8. **The guard's dim and the drop flash are built** (§9.2, §9.3, §17): they show on the next open, a drop for 5 s.
9. **The dial's place is the `dial.point` member row**, set by X/Y on the Wheel tab and Reset; there is no drag strip, and Lock frame governs the pads only. Open at the cursor re-anchors in the snippet (`$cursor`, unverified until DIAL-7).
10. **Master visibility does not hide a dial** (it opens only on its key); master scale and alpha apply to it.
11. **Test mode and Preview as… open dial 1 taking no key** (`qc-display`), on its first (or open-into) ring at its place; other dials are rebuilt from the same plan, closed. A combat whose lockdown began first leaves it open, keyless, until combat end (a Known Limitation, DIAL-9).
12. **Keys:** stored upper-case; `none` clears; Escape, the left and right mouse buttons and the mouse wheel are refused whatever the modifiers, and 1–8 without one (the open dial uses them); one key per dial, the refusal naming the other dial; a WoW binding on the same key warns on the Binding tab and still binds (spec §18). `/qc reset dial.key` frees it.
13. **The binding labels are globals the client reads by name**: the header declared in `.luacheckrc` `globals`, the four entry labels `rawset` because they are not identifiers (if R1 ships `Bindings.xml`).
