# Ka0s Quick Comms: phase 5 implementation plan (Share, polish and the release gate)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship sharing (a `!QC1!` export string from the Share page, an import that checks, reports and adds what a string holds as new, unbound members), the deferred polish (the pad's Look font, border and background groups with their class-color companions, a visual icon picker, battleground node sets pinned to their compass winds, the battleground and Midnight instance ids matched against the client's data (confirmed in game by the owner's smoke test)), the perf buckets and `tests/perf.lua`, the full docs set, the first standards audit and a green release gate, stopping before any version bump, tag or publish.

**Architecture:**
- **Share is a pure codec and checker with a thin edge, and Library writes what arrives** (spec §15). `modules/Share.lua` encodes a payload as `!QC1!` + `LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(payload)))`, decodes a pasted string (whitespace ignored), and checks a payload against the schema: the version (newer refused, older migrated forward), the id shapes, the channel kinds, the lengths, every When, and every text field through the §8.3 sanitizer (`Bake.CleanText`, the new half of `Bake.Sanitize` that stops short of the `|` escape). The result is a plan plus a refusal list; `Library.Import`, the registry writer, makes every member under a fresh id, remaps the references, writes a pad's or a dial's portable fields through the seam, and never writes a key or a position, as one `Library.Batch`. The edge collects the picked members and what they need (a group's callouts, a surface's groups), shows the string in the LibKa0s `CopyWindow` (a new `core/WidgetsSetup.lua` seam), and refuses export and import in combat. The Share page gains Export and Import tabs ahead of Built-in; the import box is an AceGUI `MultiLineEditBox`.
- **Polish through the seams that exist.** The pad's Look gains three groups composed by the options library (`FontGroup`, `BorderGroup`, `ColorPair` for the background), stamped as `pad.look.*` member rows; `Pad_Render` turns a Look into a font and a skin (`LabelFont`, `SkinFor`, through a new `NS.ResolveColor` and `NS.MediaFetch`), and `Pad.Apply` wears them out of combat. The icon picker is one editor helper (`Ed.IconPicker`) under the Callouts and Groups pages' Icon rows. Node sets carry each node's compass wind (read from the client's AreaPOI table), and `Dial_Layout.PinNodes` puts a node set on an eight-wedge ring, each node on its wind. The shipped instance ids are checked headlessly against an extraction of the client's Map, MapChallengeMode, Mythic+ season and journal tables, which `tools/derive-gameids.py` re-derives and diffs; the node winds come from `tools/derive-winds.py` (layout-§1: an authored generator lives under `tools/`).
- **The release gate is measured, not assumed.** Task 1 brings the eight functions over CCN 15 down first; every later task keeps its own code at 15 or under; `tests/perf.lua` gains the spec's scenarios and a real zero-overhead pair; the last code-side task runs the vendored runner and records a frozen bundle whose manifest shows all four suites at `pass`, no function over CCN 15 and no blind file. The version stays `0.1.0` and nothing is tagged.

**Tech stack:**
- Lua 5.1, against the WoW Retail 12.1 client (Interface `120100`)
- Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, including its `MultiLineEditBox`, `Icon` and `ColorPicker` widgets)
- LibKa0s v1.71.0 (Options `FontGroup`, `BorderGroup`, `ColorPair`, `RenderRows`, `RenderGrid`, `Section`, `TextRow`, `InlineButtonPair`; Widgets `CopyWindow`; Core `ResolveColor`, `ApplySkin`; Media `Icon`; Perf; Schema)
- LibDeflate `1.0.2-release` and LibSerialize `v1.2.3`, vendored in this phase (library-stack-§2, §3)
- LibSharedMedia-3.0 (`Fetch`) for the Look's font and border names
- the LibKa0s headless test kit (`tests/_kit/`), extended in `tests/wow_mock.lua` (Task 8) and `tests/page_helpers.lua` (Task 5)
- luacheck, lizard (through the kit's sighted shadow), and the bounded runner `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded` for every gate command

**Spec:** [`docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`](../specs/2026-10-11-quickcomms-v1-design.md) (amended through phase 4). Read §3 (the libraries line), §4.2, §4.3 (the `Share` row), §8.3, §10.1, §10.3, §11.1, §12.1, §13.1 (the Callouts, Comms Pad and Share rows), §13.2, §15, §16, §18, §19 (row 5) and §20 beside this plan; section numbers (§n) refer to it. The Ka0s WoW Addon Standard is at `../WowAddonStandards/standards/` (v2.80.x when this plan was written); section names below (options-ui-§16, automated-tests-§3) refer to it. The previous plans, `docs/superpowers/plans/2026-10-13-quickcomms-phase-3.md` and `…-phase-4.md`, are the model this one follows.

**Scope note:** this plan covers **phase 5 only** (§19 row 5). Out of scope:
- bumping the version, rolling `## Version History`, tagging `v0.1.0`, packaging or publishing (the owner gives the word for v0.1.0 later; `/dev-copilot:bump-version` is that later step)
- an open-world built-in set (the owner declined one)
- Quick mode for the dial and the rest of the C7 upgrade, combat-time page swaps, whispers (issue #7), and every other item §1 lists as not in v0.1.0
- a battleground the brainstorm's fourteen do not list (the client's data has Midnight's Slayer's Rise, map 2799; the generic battleground set covers it, and Task 11 records it as a known limitation)
- the Midnight raids the client's data gates behind a later season (The Tidebound Grotto, The Venomous Abyss, The Unbinding of Kith'ix)

**Precedents copied, by file and symbol:**

| What | Copied from |
|---|---|
| `!<tag>!` + LibDeflate `EncodeForPrint(CompressDeflate(LibSerialize:Serialize(t)))`, a version gate that refuses newer strings | WeakAuras' `!WA:2!` strings, as `../WowAddonStandards/standards/INDUSTRY_RESEARCH.md` §2.8 records them |
| A whole-folder vendored library, one TOC line per `.xml`, never edited | this addon's `libs/LibKa0s/` (library-stack-§3, §7) |
| One `Library.Batch` around a bulk write, one `[Set] <act> <scope>` bracket | `settings/Share.lua` `SH.RestoreAll` (phase 3) |
| A composed options block (font, border, color pair) | `libs/LibKa0s/OptionsCompose.lua` `O.FontGroup`, `O.BorderGroup`, `O.ColorPair`; this addon's Master controls (`settings/Panel.lua`) |
| A LibKa0s seam with a degraded `nil` | `core/WidgetsSetup.lua` `NS.MakeDragHandle` (phase 2) |
| A read-only copy window | `libs/LibKa0s/Widgets.lua` `lib.CopyWindow` (the debug console's Copy uses the same one) |
| A page test that drives AceGUI widgets headlessly | `tests/page_helpers.lua` (phase 3, phase 4's Keybinding wrap) |
| A gated perf bracket with a declared parent | performance-§2/§3; `core/PerfSetup.lua`'s descriptor |

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

**Phase 5's amendments** (each adds to the carried line it names; the Git line supersedes phase 4's branch):
- **Git:** commit on the current branch, `feat/phase-5-share-release`, in this worktree (`/mnt/d/Profile/Users/Tushar/Documents/GIT/QuickComms-p5`), after the gate passes (the repo owner authorized commits on this branch). Never switch branches, never commit to `main`, never merge, never push, never bump the version, never tag, never publish. The branch is rebased onto phase 4's final head before Task 1 (Pre-flight P1). Work only in this worktree: `../WowAddonStandards` and `../LibKa0s` are read, never written, from here.
- **Version:** `QuickComms.toc` keeps `## Version: 0.1.0`; the README's Version History row stays `0.1.0 | Unreleased`; no tag is cut. A task that finds itself about to change either stops and asks.
- **Line endings** (adds to the carried line): a file a tool wrote whole, a new file included, is refreshed from the index after `git add` with `rm <file> && git checkout -- <file>` (a bare `git checkout --` leaves a file whose stat looks clean alone, and the kit's `test_eol` then reports its bare LF); a vendored folder with `rm -r <dir> && git checkout -- <dir>`. The gate then runs once more, because `test_eol` reads every staged file, and only then is the commit made. Each task's commit step is written in that order.
- **Libraries:** LibDeflate `1.0.2-release` (commit `6831edcaa915154e7769d622e0de72ee5d25a882`) and LibSerialize `v1.2.3` (commit `aa6e50dddad28f8dfa6c27c9b1e15ae40262b4a5`) are vendored whole under `libs/LibDeflate/` and `libs/LibSerialize/` (the `.lua`, the `lib.xml`, the license) and never edited, like everything under `libs/`; each is one TOC line (its `lib.xml`) after the LibKa0s line, marked `# LOAD-BEARING:` naming `modules\Share.lua`, and named in `## OptionalDeps:`. `tests/loader.lua` loads them (Task 2).
- **No new globals** (adds to the carried line): the copy window's two named frames, `QuickCommsShareWindow` and `QuickCommsShareScroll`, and nothing else.
- **The bus:** no new message. An import announces through `Library.Batch`'s one `LIBRARY_CHANGED`, which rebuilds the surfaces and repaints the pages as any other write does.
- **The registry writer** (adds to the carried line): `Library.Import` is the only writer of what an import makes. `modules/Share.lua` decodes, checks and plans; it never writes a registry collection or a member field.
- **Nothing from a share string runs** (anti-pattern #20, spec §8.3): every name, callout text and icon path passes `Bake.CleanText` when it is checked, and so does every string inside a pad's or a dial's field values, nested ones included (`cleanValue`, which also refuses a number that is not finite and a value nested deeper than `Share.MAX_DEPTH`); the seam's row validation then checks each surface field against its row when `Library.Import` writes it. No stored text can start with `/` or hold a second line; `Bake` checks again at every bake. A pad's or a dial's key and position never travel and are never written by an import. A hand-made string never raises: `Share.Check` fails closed (`damaged`).
- **Perf** (adds to the carried line): phase 5 declares the spec's last two buckets with their brackets in Task 10: `situation.refresh` (`modules/Situation.lua`) and `resolver.resolve` (`modules/Surfaces.lua`, declared `within = "bake.surface"` and noted with that parent, and gated exactly as its parent is: an editor's unmeasured plan, `deps.unmeasured` (phase 4's fix wave), notes neither).
- **Complexity:** every function a task adds or edits is at CCN 15 or under, measured through the kit's sighted shadow, never raw `lizard` (automated-tests-§3). Each task's gate step runs `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` and expects `0 warnings`. The release gate (Task 13) reads the same measurement from a bundle.
- **Prose:** US English in everything the kit's prose gate scans, docs included: "center", "color", "canceled", "gray". The gate rejects the British forms.
- **Generators** (layout-§1, "Where an authored generator lives", MUST): a script this repository authors that derives shipped or fixture data from the client's tables lives under `tools/`, is never loaded by the client or listed in the TOC, and is `.pkgmeta`-ignored (Task 6 adds `- tools`). Each fails loudly (exits non-zero) on a missing row, a name that does not match its id, or a mismatch with the repository, and its output is read as a diff before anything derived from it is committed. `DEPENDENCIES.md` names the interpreter (Python 3, standard library only).

**From the spec (phase 5), verbatim** (quotes only; the readings follow):
- §15: "**Format:** `!QC1!` + `LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(payload)))`." / "`payload = { v = 1, addon = "QuickComms", kind = "bundle", callouts = {…}, groups = {…}, pads = {…}?, dials = {…}? }`" / "1. Decode. 2. Check `v`. Older versions migrate forward; newer versions are refused with a message. 3. Validate against the schema: types, ID shapes, channel kinds, lengths. 4. Run the §8.3 sanitizer over every text field. 5. Show a report: "3 callouts, 1 group; 1 callout refused: starts with /". 6. Apply through `Library.Import` (the registry writer). Ids are re-mapped into fresh user ids, and nothing is executed (anti-pattern #20)." / "Imported pads and dials arrive **unbound**." / "Export and import are refused in combat." / "**UI:** export uses LibKa0s `CopyWindow`. Import uses an AceGUI MultiLineEditBox on the Share page."
- §8.3: "**Imported text** goes through the same sanitizer when it's imported, and again at every bake."
- §18: "Import into a profile with id collisions | Ids are always re-mapped; names may duplicate (allowed)"
- §3: "**LibSerialize** and **LibDeflate**. Quick Comms is the first Ka0s addon to use these; add them to DEPENDENCIES.md and `standards/ADDONS.md`."
- §10.3, *Built (phase 3)*: "the pad's Look tab has visibility, fade and the faded alpha; the font group, border group and colors with their class-color companions arrive with phase 5's polish (§19 row 5)."
- §13.1, Callouts: "an icon box (a texture id or path; a LibKa0s icon by its path; the visual picker arrives with phase 5's polish, §19 row 5)"; Share: "**Export** (select callouts, groups, pads and dials → string → `CopyWindow`), **Import** (a paste box → validation report → apply), **Built-in** (…)"
- §12.1: "**One set per battleground:** matched on the battleground's `instanceID`. Nodes are pinned to compass directions, with `openInto = true`. The battleground list is the 14 from brainstorm §8, and phase 5 confirms their instance IDs." / §11.1: "A battleground node set may pin each node to its real compass direction."
- §13.2, *Built (phase 3)*: "the Midnight dungeon and raid ids are confirmed in game in phase 5, with the battleground ids."
- §16: "**Perf buckets:** `situation.refresh`, `resolver.resolve`, `bake.surface`, `pad.layout`, `dial.render` (the OnUpdate while open), `send.click` (the insecure hook), `echo.match`" / "`tests/perf.lua` covers a 12-chip pad rebuild, a full dial open/close and a zero-overhead scenario."
- §19, row 5: "Share (codec tests, import report). Editor polish: the pad's Look font group, border group and colors with class-color companions (options-ui-§16/§17, the composed controls), and a visual icon picker for callouts and groups. Perf buckets and `tests/perf.lua`. Battleground ID confirmation. Docs set. Automated-test bundle. First audit. README. `ADDONS.md` roster row." / Exit: "Release gate (complexity ≤ 15, blind files 0). Tag v0.1.0 only on the owner's word."
- §20: "These follow documentation-§1–§3." (the list that follows it: the root files, the trio, Tier 1, the records, Tier 2)

**How this plan reads those quotes** (rulings within the spec's text; Task 11 writes each into the spec as a *Built (phase 5):* note):
- §15 "older versions migrate forward": `v = 1` is the first version, so `MIGRATIONS` is an empty table the check already walks; a `v` below 1, or not a whole number, is a damaged string.
- §15 step 3 "lengths": a name is 1 to 32 characters (`Library.NAME_MAX`), a callout's text and an icon path at most 255 bytes after sanitizing (bytes, as `Bake` caps a whole line; the editor's Text box counts characters, so a text of 200 Cyrillic letters types in but is refused on import, and could never bake anyway), a pasted string at most 50,000 characters (checked before anything is decompressed), the decompressed payload at most 512 KiB (`Share.MAX_RAW`, checked before LibSerialize reads it), and one string at most 500 members.
- §15 step 4 and §8.3: the sanitizer an import stores is `Bake.CleanText`: §8.3's flattening, squeezing and leading-`/` refusal, short of the `|` escape, which every bake still applies (storing escaped text would escape it twice). "Every text field" is every name, a callout's text, an icon path, and every string in a pad's or a dial's field values, nested ones included. A name or a text the sanitizer refuses refuses its member; a field value holding a refused string is left out and counted; a callout may have no text yet (the editor allows it), and an empty string in a field is kept for the seam to judge rather than counted as a refusal.
- §15 payload: a callout is `{ name, text, channel, icon }`, a group `{ name, icon, callouts, when, openInto, enabled }`, a pad or a dial `{ name, enabled, groups, fields }` where `fields` holds its portable member rows by path (every row of its kind but its name, Enabled, position and key). A field this version does not know is left out and counted; the seam checks each field again when Library writes it.
- §15 "arrive unbound": no key (a dial's `key` stays unset), no position (a pad's and a dial's `point` stay the default place), and a place at the end of its kind's order. A surface's groups are the imported groups' new ids plus any top-level built-in set by id; a built-in set this version does not ship, a node, or anything else is left out and counted.
- §15 Export "select callouts, groups, pads and dials": a checkbox per member, and what is ticked brings what it needs: a pad or a dial its user groups, a group its callouts.
- §15 "refused in combat": `Share.Export` and `Share.Apply` refuse with one chat line, "Export and import are not available in combat." (a refusal, not a deferral: nothing runs later; options-ui-§2). The options library already locks the panel in combat; the refusal covers a call that arrives some other way.
- §10.3 and §19 row 5, the Look: the font block draws the chips' labels and the section titles (a title takes the face, size, flags and shadow, and keeps its gold template color unless the player sets a color or ticks Use class color); the border block draws the pad's edge ("None" is the flat Ka0s line, a thickness of 0 is no edge, a LibSharedMedia border by name otherwise); the background is a swatch and its companion only (options-ui-§16: "A group over a background is not a bar group"). The class color is the player's. Defaults are the skin a pad already wore, so nothing changes until the player changes it. A font or border this machine does not have draws the default.
- §13.1 and §19 row 5, the icon picker: a palette (the eight raid markers under their localized names, the game icons the built-in sets use, read from `NS.BuiltIns` when the picker draws, and the LibKa0s icon catalog's entries whose names a short allowlist keeps, enumerated from `Media.ICONS`, never a hard-coded path list: library-stack-§8) under the Icon row of the Callouts page and a user group's General tab; a click writes the icon row through the seam. Any other texture is still typed into the Icon box.
- §12.1 "phase 5 confirms their instance IDs" and §13.2's "confirmed in game": what can be checked without the client is matched against the client's own data tables (Map, MapChallengeMode, MythicPlusSeasonTrackedMap, JournalTier, JournalTierXInstance, JournalInstance and ChrSpecialization, as exported from build 12.1.5.70340 by wago.tools), derived and diffed by `tools/derive-gameids.py` and held as an extraction in `tests/test_gameids.lua`. That is a match, not a confirmation: the shipped files say "matched against the client's data tables; in-game confirmation is BG-2 / IDS-1" until Task 14 records a pass (owner ruling 10). The dungeons are the eight maps of Mythic+ display season 34 (the four returning and Windrunner Spire 2805, Magisters' Terrace 2811, Nexus-Point Xenas 2915, Maisara Caverns 2874); the raids are the journal's Current Season raid maps under the launch season's condition, world-boss entries left out (The Voidspire 2912, The Dreamrift 2939, March on Quel'Danas 2913, and Sporefall 1592 as ruling R4 decides). Spec 1480 is matched in ChrSpecialization (the Demon Hunter's Devourer) and checked in game in IDS-1. Every shipped battleground id is a battleground map; none changes.
- §12.1 "pinned to compass directions": each node's wind is read from the client's AreaPOI table (the node's map position against the center of the set's nodes, north up; a node within a third of the spread of that center is the middle), stored on the node, and placed by `Dial_Layout.PinNodes`: an eight-wedge ring whatever the dial's slices, never paged, a middle node on the first wind left free clockwise from N, no wedge on a wind with no node. The number keys pick the shown wedges clockwise from N. The winds are derived and checked by `tools/derive-winds.py`. Deepwind Gorge's current map has five nodes; what its set ships is ruling R2's (this plan's text builds the recommended reading: Shrine and Ruins join Market, Farm and Quarry).
- §16: `tests/perf.lua`'s scenarios are a 12-chip pad rebuilt from its plan (`padRebuild12`), the default dial opened, one pointer frame drawn and closed (`dialOpenClose`), a situation read that moves nothing (`situationRefresh`), and performance-§9's zero-overhead pair on the hottest bracketed path, the open dial's pointer `OnUpdate`, with capture off (`dialPointerCaptureOff`) against an instance loaded without the Perf library (`dialPointerNoHarness`).
- §19 row 5, "First audit" and "`ADDONS.md` roster row": the audit runs `/dev-copilot:wow-standards-audit`, and every finding is fixed in this phase or recorded durably with its disposition (Task 12): a pending finding as a GitHub issue on this repo through `/dev-copilot:issue-audit` (audit-review-history: pending decisions live in issues, not in a file), an accepted limit under `docs/ARCHITECTURE.md` → Known Limitations, a deviation only as the owner rules it. The roster row already exists in `../WowAddonStandards/standards/ADDONS.md` and is verified, never duplicated; updating it is the standards repo's step, so a wrong row goes to the owner with the exact row text to apply there (Task 12, Step 5).

## Review Focus

These are the inputs most likely to hurt a real player that no feature test would naturally cover. Each one has a pinning test, tagged `[review n]`, in the task named in brackets.

1. **A share string as it really arrives: wrapped across lines, padded with spaces, or cut short by a chat or forum copy.** Whitespace anywhere is ignored; a cut-short string says it is damaged, imports nothing and raises nothing. [Task 3]
2. **A string carrying a command or control characters** (a text starting `/run`, a line break followed by `/script`, a `|` escape, a 300-byte text). The member is refused or flattened to one line; nothing it stores can bake to a second line or a leading slash, and a stored `|` is escaped exactly once at the bake. [Task 3]
3. **Importing the same string twice, or into a profile whose ids overlap the exporter's.** Fresh ids every time, nothing that existed changes, names may repeat, and every reference points at its own new copy. [Task 4]
4. **Someone else's pad or dial.** Their key and their screen position never arrive, even if a hand-made string slips them past the checks; the dial is unbound (it cannot clash with one of yours), the pad sits at the default place, and the pad lists exactly the shared groups, with no built-in set re-added at the next load. [Task 4]
5. **A pad whose Look names a font or a border this machine does not have** (a media addon since removed, or a shared pad). The pad draws with the default face and the flat edge, and nothing errors. [Task 8]
6. **A pinned battleground ring on a dial set to four or six slices.** The player chose four wedges and now sees an eight-wedge ring in a node battleground: every node must still be reachable on that one ring, with no More; the number keys 1..n must pick the shown wedges clockwise from N (the key a player presses names the wedge they see, not a hidden slot); and Flat mode and a node set that cannot be pinned keep their paging. [Task 7]

## Milestones

Each milestone ends green and is a resume point: the plan's checkboxes and `git log` say where the work stands.

- **Pre-flight (P1, P2, P3, below).** The rebase onto phase 4's final head, the re-measured complexity list and the owner's rulings. No task starts before P1 and P2 are done; a task that depends on a ruling (Task 6 on R3 and R4, Task 7 on R2, Task 11 Step 0 on R1) does not start before that ruling is recorded.
- **Milestone 1: groundwork and Share (Tasks 1–5).** The eight functions over CCN 15 brought down; LibDeflate and LibSerialize vendored; the pure codec and checks; `Library.Import`; the edge and the Share page's Export and Import tabs. A string round-trips through the page headlessly. Checkpoint: both gate commands green, complexity `0 warnings`; commits on `feat/phase-5-share-release`.
- **Milestone 2: polish and game data (Tasks 6–10).** The instance ids matched against the client's data by a committed generator; node sets pinned to their winds; the pad's Look groups; the icon picker; the perf buckets and `tests/perf.lua`. Checkpoint: green, complexity `0 warnings`, `lua tests/perf.lua` exits 0.
- **Milestone 3: docs, audit, the release gate and the owner's smoke test (Tasks 11–14).** The docs set (with smoke checks SHARE-1..6, LOOK-1..2, ICON-1, BG-1..2, IDS-1), the first standards audit and its fixes, the release-gate bundle, then the owner's in-game run. The plan ends with Task 14; the version, the tag, merging and pushing are the owner's call.

## Pre-flight (before Task 1)

- [ ] **P1. Rebase onto phase 4's head, which this plan is anchored on.** Phase 4's docs task and its final-review fix wave have landed: `feat/phase-4-dial` is at `55194f6` ("Settings: a WoW-menu key on a dial that is off says it opens nothing"), and this branch still sits at `c5eb85c`. Every "replace" block in this plan was checked against `55194f6`'s tree (72 blocks; the three that do not match it are blocks an earlier task of this plan writes), and Tasks 1 to 10 were applied to an export of `55194f6`, gated after the last. With the owner's go-ahead, rebase this branch onto phase 4's head (`git rebase feat/phase-4-dial`) and run the gate. If `feat/phase-4-dial` has moved past `55194f6` by then, list what moved (`git diff 55194f6 feat/phase-4-dial -- modules/ settings/ core/ defaults/ tests/ docs/ README.md QuickComms.toc`), re-read each anchor a task's **Files** line names in that diff, and apply the task's change to its new shape (each change is described in words beside its block); if phase 4 already wrote a sentence Task 11 adds, keep one copy. What the fix wave moved, and this plan already follows: `S.BuildDialPlan` opens `local t0 = Perf.on and not deps.unmeasured and debugprofilestop()` (Task 10's `resolve` is gated the same way); `DD.PreviewLines` names a wedge's direction through `local dir = NS.DialLayout.Direction(i, ring.size)` with an o'clock fallback (Task 7 changes that line); `DL.Wedge` returns a label `anchor` with `lx`, `ly`, and `DL.Direction` answers clock hours past eight wedges (a pinned ring has eight, so Task 7 reads winds); `Dial.Sync` gained `wasOpen`, `link()` and the display mode (Task 1 splits it); `modules/Library.lua` is 892 lines (Tasks 1, 4 and 8 take it to about 1,012).
- [ ] **P2. Re-measure the complexity list.** Run `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`. At `55194f6` it reports `8 warnings` (max CCN 31): `PL.Compute` (21), `S.WhyLines` (18), `Dial.Sync` (19), `Ch.LockState` (20), `Lib.MemberIds` (21), `Lib.Prepare` (31), `formatWhen` (22), `W.Values` (27). Task 1 brings exactly these down. If the list differs, Task 1 covers the new list the same way (split the function into named local helpers with one job each; behavior pinned by the existing tests) and records the change in its commit message.
- [ ] **P3. The owner's rulings.** Each of these settles binding spec or brainstorm text, which CLAUDE.md says to stop and flag rather than settle in a plan. Put each to the owner, record the answer in this table (the **Ruling** cell, dated), and do not start the task that depends on it before then. The plan's text builds the recommended answer; a different answer changes only the steps named.

| # | Question | Recommended | Depends on it |
|---|---|---|---|
| R1 | Spec §3 says to add LibSerialize and LibDeflate "to DEPENDENCIES.md and `standards/ADDONS.md`", and the roster has no library column (see **Standard deviations to raise**). Is the spec satisfied by `DEPENDENCIES.md` plus the existing roster row (reading 1), or does a library column go upstream (reading 2)? | Reading 1 | Task 11 Step 0's §3 note (it writes the reading the owner chose; under reading 2 it says the column is proposed upstream and leaves the roster to that repo) |
| R2 | Deepwind Gorge. Brainstorm §8 and the shipped set list three nodes (Market, Farm, Quarry); the client's current map (2245) has five (Shrine and Ruins too). Ship (a) five nodes, two new built-in ids `bi.bg.dwg.shrine` and `bi.bg.dwg.ruins` with six callouts each, all pinned; (b) the three, pinned to winds derived from those three alone; or (c) the three, left unpinned (shipped order, paged)? | (a): pinning three of five points players at the wrong places | Task 7 (Step 3's Deepwind Gorge block, `tools/derive-winds.py`'s `NODES.dwg`, the test's `5`, the two locale keys); Task 11 (the §11.1/§12.1 note, BG-1) |
| R3 | Spec 1480. `defaults/GameIds.lua` notes the Devourer spec as "confirmed in game with the rest in phase 5". This plan matches it against ChrSpecialization (`tools/derive-gameids.py`: spec 1480 is class 12's Devourer) and checks it in game in IDS-1. Is that the phase 5 confirmation, with the note reworded to "matched; in game IDS-1" until Task 14 records a pass? | Yes | Task 6 (the header), Task 11 (IDS-1) |
| R4 | Sporefall (map 1592). The journal's Current Season tier lists it as a raid-type map under the same launch condition as the three raids, but its journal text reads as a Harandar encounter rather than a tier raid, and nothing headless says which. Leave it out of `G.RAIDS` (the generator prints it as NOT SHIPPED and IDS-1 asks the owner to look), or ship it as a fourth raid? | Leave it out; IDS-1 checks it | Task 6 (`G.RAIDS`, the test's count), Task 11 (IDS-1) |

Rulings recorded: R1 ____ · R2 ____ · R3 ____ · R4 ____

## Standard deviations to raise

None that this plan takes. One place where the spec asks for something the standard has no home for, raised for the owner rather than settled here (ruling R1 in Pre-flight P3 records the answer):

| Rule | What differs | Why |
|---|---|---|
| `standards/ADDONS.md` (the roster's row shape: Addon, Folder, Repository, Launcher menu entries) | Spec §3 says to add LibSerialize and LibDeflate "to DEPENDENCIES.md and `standards/ADDONS.md`". The roster has no column for libraries, and the row for Ka0s Quick Comms already exists. This plan records the two libraries in `DEPENDENCIES.md` and `docs/ARCHITECTURE.md` (their documentation-§7 and §3 homes) and verifies the roster row without editing it. | Writing a library list into the roster would change the standard's roster format, which is the standards repo's to decide, and this worktree does not write to `../WowAddonStandards`. Two ways to settle it: **(1)** read the spec's "and `standards/ADDONS.md`" as satisfied by the existing row (Task 11 then writes that reading into the spec as a *Built (phase 5):* note under §3); or **(2)** propose a library column upstream, in the WowAddonStandards repo, after which the row gains it there. The owner picks (R1); Task 11 writes only what was picked. |

Bindings.xml needs no row: standard v2.80.0 names it a client-mandated root file (layout-§1), so phase 4's raised deviation is settled upstream, and `docs/ARCHITECTURE.md` → Documented deviations keeps "None." unless phase 4's docs task wrote otherwise (Task 11, Step 1 checks).

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `modules/Pad_Layout.lua`, `modules/Surfaces.lua`, `modules/Channels.lua`, `modules/Library.lua`, `modules/Dial.lua`, `settings/Slash.lua`, `settings/Groups_When.lua` | modify | Task 1: the eight functions over CCN 15 split into named helpers, behavior unchanged. |
| `libs/LibDeflate/` (`LibDeflate.lua`, `lib.xml`, `LICENSE.txt`), `libs/LibSerialize/` (`LibSerialize.lua`, `lib.xml`, `LICENSE`) | create (vendored) | Task 2: the share string's compression and payload, copied whole from their release tags. |
| `QuickComms.toc`, `tests/loader.lua`, `DEPENDENCIES.md` | modify | Task 2: the two TOC lines and `## OptionalDeps:`, the harness loads them, the dependency record. Task 3: `modules\Share.lua`'s TOC line. |
| `modules/Bake.lua` | modify | Task 3: `B.CleanText`, the sanitizer short of the escape; `B.Sanitize` builds on it. |
| `modules/Share.lua` | create | Task 3: the pure codec, the checks and the report. Task 5: the edge (Collect, FieldsOf, Export, Apply, the window). |
| `modules/Library.lua` | modify | Task 4: `newSurface` (CreateSurface builds on it), `Lib.Import`. Task 8: the pad's Look defaults, `fillShape` in Prepare. |
| `core/WidgetsSetup.lua`, `core/State.lua`, `settings/Editors.lua` | modify | Task 5: `NS.MakeCopyWindow`; `NS.State.share`; a profile switch clears it. Task 9 (Editors): the icon picker. |
| `settings/Share.lua` | rewrite | Task 5: the Export and Import tabs ahead of Built-in. |
| `tests/page_helpers.lua` | modify | Task 5: `MultiLineEditBox:SetNumLines` on the kit's fake. |
| `defaults/GameIds.lua` | modify | Task 6: the Midnight dungeons and raids, and how they were matched (confirmed only by Task 14's IDS-1). |
| `tools/client_tables.py`, `tools/derive-gameids.py`, `tools/derive-winds.py`, `.pkgmeta` | create, modify | Tasks 6 and 7: the dev-only generators that derive and check the instance ids and the node winds from the client's tables (layout-§1); `.pkgmeta` ignores `tools`. |
| `defaults/BuiltIns_Battlegrounds.lua` | modify | Task 6: the header's confirmation note. Task 7: each node's wind; Deepwind Gorge's Shrine and Ruins. |
| `modules/Dial_Layout.lua`, `modules/Dial.lua`, `settings/Dials.lua` | modify | Task 7: `PinNodes`, pinned rings; a wedge's place is `item.wedge or i`. |
| `core/CoreSetup.lua`, `core/MediaSetup.lua` | modify | Task 8: `NS.ResolveColor` (and its degraded stub), `NS.MediaFetch`. |
| `settings/Schema.lua`, `settings/SchemaMembers.lua`, `settings/Pads.lua` | modify | Task 8: the `color` row type; the composed Look rows; the Look tab's headed groups. |
| `modules/Pad_Render.lua`, `modules/Pad.lua` | modify | Task 8: `LabelFont`, `ApplyFont`, `SkinFor`; the pad wears them at every rebuild. |
| `tests/wow_mock.lua` | modify | Task 8: a font string records `SetFont` and `SetShadowOffset`. |
| `settings/Callouts.lua`, `settings/Groups.lua` | modify | Task 9: the picker under the Icon row. `core/MediaSetup.lua` (Task 9): `NS.IconNames`, the icon catalog enumerated. |
| `core/PerfSetup.lua`, `modules/Situation.lua`, `modules/Surfaces.lua`, `tests/perf.lua` | modify | Task 10: two buckets and their brackets; the spec's scenarios and the zero-overhead pair. |
| `locales/enUS.lua` | modify | every task that adds a string (each block under a comment naming its file) |
| `tests/test_share.lua`, `tests/test_gameids.lua` | create | Tasks 3 and 6 |
| `tests/run.lua` | modify | Tasks 3 and 6: the two new suites |
| `tests/test_channels.lua`, `test_members.lua`, `test_setup.lua`, `test_bake.lua`, `test_library.lua`, `test_page_share.lua`, `test_dial_layout.lua`, `test_builtins.lua`, `test_dial.lua`, `test_page_dials.lua`, `test_pad_render.lua`, `test_pad.lua`, `test_page_pads.lua`, `test_page_callouts.lua`, `test_page_groups.lua` | modify | the tasks named in each |
| `docs/…`, `README.md`, `DEPENDENCIES.md`, the spec | modify | Task 11 (Task 12 for the audit bundle, Task 13 for the automated-test bundle) |

The TOC order this plan ends with (new lines marked `+`):

```
libs\LibKa0s\LibKa0s.xml
+ libs\LibDeflate\lib.xml
+ libs\LibSerialize\lib.xml
...
modules\Library.lua
+ modules\Share.lua
modules\SendEngine_Guard.lua
```

**What a share result is** (the shape Tasks 3, 4 and 5 share):

```lua
-- Share.Validate(payload) / Share.Check(text):
res = { ok = true, reason = nil,                      -- ok false: reason is "empty" | "notOurs" | "damaged"
                                                       --   | "newer" | "tooLarge" | "unavailable"
        callouts = { { id = "c3", fields = { name, text, channel, icon } } },
        groups   = { { id = "g1", callouts = { "c3" }, fields = { name, icon, when, openInto, enabled } } },
        pads     = { { id = "p4", name, enabled, groups = { "g1", "bi.mplus" }, fields = { ["pad.layout.columns"] = 6 } } },
        dials    = { { id = "d5", name, enabled, groups = { … }, fields = { ["dial.mode"] = "flat" } } },
        refused  = { { kind = "callout", id = "c4", name = "Run", reason = "startsWithSlash" } },
        dropped  = 2,                                  -- references to members the string does not carry
        ignored  = 1 }                                 -- fields that do not travel
-- Library.Import(res) -> tally { callouts, groups, pads, dials, ignored }, map { [old id] = new id }
-- Share.Collect(pick) -> payload { v = 1, addon = "QuickComms", kind = "bundle", callouts = { [id] = … }, … }
--   pick = { callout = { [id] = true }, group = { … }, pad = { … }, dial = { … } } (NS.State.share.pick)
```

---

### Task 1: The release gate's complexity: eight functions to CCN 15 or under

The release gate (automated-tests-§3) needs no function above CCN 15 through the sighted shadow. Eight are over it at phase 4's head (Pre-flight P2). Each is split into named local helpers with one job each; the behavior does not change, and the suites that already pin it (`test_pad_layout`, `test_surfaces`, `test_slash`, `test_channels`, `test_library`, `test_editors`, `test_members`, `test_groups_when`, `test_dial`) stay green unchanged. Two characterization cases are added where the existing ones leave an edge open (an unknown channel and a missing snapshot in the lock matrix; every key-level shape the CLI prints).

**Files:**
- Modify: `modules/Pad_Layout.lua` (`PL.Compute` and its doc comment), `modules/Surfaces.lua` (`S.WhyLines` and its doc comment), `modules/Channels.lua` (`Ch.LockState`), `modules/Library.lua` (`Lib.MemberIds`, `Lib.Prepare`, both with their doc comments), `modules/Dial.lua` (`Dial.Sync` and its doc comment), `settings/Slash.lua` (`formatWhen`), `settings/Groups_When.lua` (`W.Values` and its doc comment)
- Test: `tests/test_channels.lua`, `tests/test_members.lua`

**Interfaces:**
- Consumes: nothing new.
- Produces: the same public functions with the same signatures and answers. New file-local helpers only (`collectBlocks`, `stackBlocks`, `flattenBlocks`; `unbuiltLines`, `whyName`, `lockLines`; `LOCKS`; `surfaceIds`, `idsByName`, `NAMED_SETS`; `seed`, `repairGroups`, `repairSurface(s, result)`, `repairOrder`; `formatRange`, `formatRow`; `contentValues`, `classValues`, `specClasses`, `specValues`; `applyAll`, `openDisplay`). Task 8 adds a `kind` parameter to `repairSurface`.

- [ ] **Step 1: Measure, and write the characterization cases**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: `complexity  pass  — 8 warnings … (max 31)`. This is the failing check: the release gate needs `0 warnings`.

Append to `tests/test_channels.lua`:
```lua
test("channels: [phase 5] the lock matrix has no row for an unknown channel, and reads a missing snapshot as solo", function()
    local Ch = ch()
    assertNil(Ch.LockState("guild", snap({ group = "raid" })))
    assertNil(Ch.LockState(nil, nil))
    assertEqual(Ch.LockState("party", nil), "notInGroup")
    assertNil(Ch.LockState("say", nil), "no lockdown table is no lockdown")
end)
```

Append to `tests/test_members.lua`:
```lua
test("members: [phase 5] a When's key level prints as it types back in: one level, open below, open above", function()
    local NS, m = T.enableAddon()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    NS.State.editing.group = gid
    for _, typed in ipairs({ "12", "-15", "10-", "10-15" }) do
        NS.addon:OnSlashCommand("set group.when keyLevel " .. typed)
        m.prints = {}
        NS.addon:OnSlashCommand("get group.when")
        local text = table.concat(m.prints, "\n")
        assertTrue(text:find("keyLevel " .. typed, 1, true) ~= nil, typed .. ": " .. text)
    end
end)
```

- [ ] **Step 2: Run the suite: the new cases pass before the refactor**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: PASS (they pin what the refactor must keep).

- [ ] **Step 3: `PL.Compute`**

In `modules/Pad_Layout.lua`, replace
```lua
--- Place every title row and chip. The header stays on top; "up" stacks the section blocks in
--- reverse order (the first section nearest the anchor), "left" mirrors each chip row.
--- @param sections table from VisibleSections
--- @param layout table the pad's layout table
--- @param opts table|nil { collapsed = boolean }
--- @return table { width, height, items }
function PL.Compute(sections, layout, opts)
    layout = type(layout) == "table" and layout or {}
    opts = type(opts) == "table" and opts or {}
    local cw, ch = PL.CellSize(layout)
    local gap = math.max(0, tonumber(layout.spacing) or 4)
    local up = layout.growth == "up"
    local blocks, contentW = {}, 0
    if not opts.collapsed then
        for _, s in ipairs(type(sections) == "table" and sections or {}) do
            local b = sectionBlock(s, layout, cw, ch, gap, up)
            if #b.items > 0 then
                blocks[#blocks + 1] = b
                if b.cols > 0 then contentW = math.max(contentW, b.cols * cw + (b.cols - 1) * gap) end
            end
        end
    end
    local width = math.max(PL.MIN_W, contentW + 2 * PL.PAD)
    local y, nb = PL.HEADER_H + PL.PAD, #blocks
    for k = 1, nb do
        local b = blocks[up and (nb + 1 - k) or k]
        b.top = y
        y = y + b.h + b.trail
    end
    local items = {}
    for _, b in ipairs(blocks) do
        for _, it in ipairs(b.items) do
            it.y = b.top + it.y
            if layout.growth == "left" and it.kind == "chip" then it.x = width - it.x - it.w end
            items[#items + 1] = it
        end
    end
    local height = nb > 0 and (y + PL.PAD) or PL.HEADER_H
    return { width = width, height = height, items = items }
end
```
with
```lua
-- The non-empty section blocks, and the widest block's content width.
local function collectBlocks(sections, layout, cw, ch, gap, up)
    local blocks, contentW = {}, 0
    for _, s in ipairs(type(sections) == "table" and sections or {}) do
        local b = sectionBlock(s, layout, cw, ch, gap, up)
        if #b.items > 0 then
            blocks[#blocks + 1] = b
            if b.cols > 0 then contentW = math.max(contentW, b.cols * cw + (b.cols - 1) * gap) end
        end
    end
    return blocks, contentW
end

-- Stack the blocks under the header, "up" in reverse order; answers the y below the last one.
local function stackBlocks(blocks, up)
    local y, nb = PL.HEADER_H + PL.PAD, #blocks
    for k = 1, nb do
        local b = blocks[up and (nb + 1 - k) or k]
        b.top = y
        y = y + b.h + b.trail
    end
    return y
end

-- Every block's items in pad coordinates; "left" mirrors each chip across the pad's width.
local function flattenBlocks(blocks, mirror, width)
    local items = {}
    for _, b in ipairs(blocks) do
        for _, it in ipairs(b.items) do
            it.y = b.top + it.y
            if mirror and it.kind == "chip" then it.x = width - it.x - it.w end
            items[#items + 1] = it
        end
    end
    return items
end

--- Place every title row and chip. The header stays on top; "up" stacks the section blocks in
--- reverse order (the first section nearest the anchor), "left" mirrors each chip row.
--- @param sections table from VisibleSections
--- @param layout table the pad's layout table
--- @param opts table|nil { collapsed = boolean }
--- @return table { width, height, items }
function PL.Compute(sections, layout, opts)
    layout = type(layout) == "table" and layout or {}
    opts = type(opts) == "table" and opts or {}
    local cw, ch = PL.CellSize(layout)
    local gap = math.max(0, tonumber(layout.spacing) or 4)
    local up = layout.growth == "up"
    local blocks, contentW = {}, 0
    if not opts.collapsed then blocks, contentW = collectBlocks(sections, layout, cw, ch, gap, up) end
    local width = math.max(PL.MIN_W, contentW + 2 * PL.PAD)
    local y = stackBlocks(blocks, up)
    local items = flattenBlocks(blocks, layout.growth == "left", width)
    local height = #blocks > 0 and (y + PL.PAD) or PL.HEADER_H
    return { width = width, height = height, items = items }
end
```

- [ ] **Step 4: `S.WhyLines`**

In `modules/Surfaces.lua`, replace
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
with
```lua
-- The answer for a surface with no plan yet.
local function unbuiltLines(id)
    local p = NS.db and NS.db.profile
    if p and p.dials[id] then return { L["This dial has not been built yet."] } end
    return { L["This pad has not been built yet."] }
end

-- A group's name as the why lines show it: a built-in says so.
local function whyName(gid)
    local g = NS.Library.Group(gid)
    local name = g and g.name or gid
    if NS.Library.IsBuiltin(gid) then name = L["%s (built-in)"]:format(name) end
    return name
end

-- Every distinct lock on the plan's slots, sorted, as its tooltip line, appended to `out`.
local function lockLines(plan, out)
    local locks, seen = {}, {}
    S.EachSlot(plan, function(slot)
        if slot.lock and not seen[slot.lock] then
            seen[slot.lock] = true
            locks[#locks + 1] = slot.lock
        end
    end)
    table.sort(locks)
    for _, lock in ipairs(locks) do out[#out + 1] = NS.PadRender.LOCK_TEXT[lock] or tostring(lock) end
end

--- "Why is this showing?" for one pad or dial (spec §13.3): the groups it shows, in priority order,
--- each with the When rows that matched (Resolver.Explain), then every lock in effect on its slots.
--- Read from the last plan, so in combat it explains what is on screen.
--- @return string[]
function S.WhyLines(id)
    local plan = S.Plans()[id] or S.DialPlans()[id]
    if not plan then return unbuiltLines(id) end
    if plan.test and not plan.preview then
        if plan.kind == "dial" then return { L["Test mode: placeholder wedges that send nothing."] } end
        return { L["Test mode: placeholder chips that send nothing."] }
    end
    local out = {}
    if plan.preview then out[1] = L["Preview as: %s"]:format(NS.Preview.Label(plan.preview)) end
    if #plan.order == 0 then out[#out + 1] = L["No group matches this situation."] end
    for _, gid in ipairs(plan.order) do
        out[#out + 1] = NS.Resolver.Explain(whyName(gid), plan.active and plan.active[gid])
    end
    lockLines(plan, out)
    return out
end
```

- [ ] **Step 5: `Ch.LockState`**

In `modules/Channels.lua`, replace
```lua
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
```
with
```lua
-- The lock matrix (spec §8.4), one check per concrete channel: each answers why it can't send under
-- snapshot `s`, or nothing. A channel with no row is never locked.
local LOCKS = {
    raid = function(s)
        if s.group ~= "raid" then return "notInRaid" end
    end,
    raidWarning = function(s)
        if s.group == "raid" then
            if not (s.leader or s.assist) then return "notLeader" end
        elseif s.group ~= "party" then
            return "notInGroup"
        end
    end,
    party = function(s)
        if s.group ~= "party" and s.group ~= "raid" then return "notInGroup" end
    end,
    instance = function(s)
        if not s.instanceGroup then return "notInInstanceGroup" end
    end,
    say = function(_, lockdown)
        if lockdown.encounter or lockdown.pvpMatch then return "lockdown" end
    end,
}
LOCKS.yell = LOCKS.say

--- Why a concrete channel can't send right now, or nil (spec §8.4). The slot stays visible.
function Ch.LockState(concrete, s)
    s = type(s) == "table" and s or {}
    local check = LOCKS[concrete]
    if not check then return nil end
    return check(s, s.lockdown or {})
end
```

- [ ] **Step 6: `Lib.MemberIds` and `Lib.Prepare`**

In `modules/Library.lua`, replace
```lua
--- Every member of a kind, in the order its editor page's picker lists them: user callouts and user
--- groups by name (case-insensitive, then id), the built-in sets after the user groups in shipped
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
    local source = (kind == "callout" and p.callouts) or (kind == "group" and p.groups) or nil
    if not source then return out end
    local list = {}
    for id, m in pairs(source) do list[#list + 1] = { id = id, key = tostring(m.name or id):lower() } end
    table.sort(list, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.id < b.id
    end)
    for i, e in ipairs(list) do out[i] = e.id end
    if kind == "group" then
        for _, id in ipairs(NS.BuiltIns.order) do out[#out + 1] = id end
    end
    return out
end
```
with
```lua
-- A pad's or a dial's ids in the kind's display order (padOrder, dialOrder), skipping a stale entry.
local function surfaceIds(p, kind)
    local set = kind == "pad" and p.pads or p.dials
    local out = {}
    for _, id in ipairs(kind == "pad" and p.padOrder or p.dialOrder) do
        if set[id] then out[#out + 1] = id end
    end
    return out
end

-- A set's ids by name (case-insensitive), then by id.
local function idsByName(source)
    local list = {}
    for id, m in pairs(source) do list[#list + 1] = { id = id, key = tostring(m.name or id):lower() } end
    table.sort(list, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.id < b.id
    end)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.id end
    return out
end

local NAMED_SETS = { callout = "callouts", group = "groups" }

--- Every member of a kind, in the order its editor page's picker lists them: user callouts and user
--- groups by name (case-insensitive, then id), the built-in sets after the user groups in shipped
--- order, the pads in the pad order, the dials in the dial order. The seam's fallback when a page
--- has selected nothing (settings/Schema.lua Settings.EditingId), and the pages' picker order.
--- @param kind string "callout" | "group" | "pad" | "dial"
--- @return string[]
function Lib.MemberIds(kind)
    if not (NS.db and NS.db.profile) then return {} end
    local p = P()
    if kind == "pad" or kind == "dial" then return surfaceIds(p, kind) end
    local source = NAMED_SETS[kind] and p[NAMED_SETS[kind]]
    if not source then return {} end
    local out = idsByName(source)
    if kind == "group" then
        for _, id in ipairs(NS.BuiltIns.order) do out[#out + 1] = id end
    end
    return out
end
```
and replace
```lua
--- Seed, append newly shipped built-ins once per surface, and drop dangling ids. Idempotent.
--- @return table { seeded, appended, repaired }
function Lib.Prepare()
    local p = P()
    local result = { seeded = false, appended = 0, repaired = 0 }
    normalize(p, result)
    liftNextId(p)
    if not p.seeded then
        if #p.padOrder == 0 then Lib.CreateSurface("pad", L["Comms Pad"]) end
        if #p.dialOrder == 0 then Lib.CreateSurface("dial", L["Comms Dial"]) end
        p.seeded = true
        result.seeded = true
    end
    for _, g in pairs(p.groups) do
        g.callouts = type(g.callouts) == "table" and g.callouts or {}
        for i = #g.callouts, 1, -1 do
            if not p.callouts[g.callouts[i]] then table.remove(g.callouts, i) result.repaired = result.repaired + 1 end
        end
    end
    for _, set in pairs(surfaces()) do
        for _, s in pairs(set) do
            s.seenBuiltins = type(s.seenBuiltins) == "table" and s.seenBuiltins or {}
            s.groups = type(s.groups) == "table" and s.groups or {}
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
    for kind, set in pairs(surfaces()) do
        local order = kind == "pad" and p.padOrder or p.dialOrder
        for i = #order, 1, -1 do
            if not set[order[i]] then table.remove(order, i) result.repaired = result.repaired + 1 end
        end
        local ids = {}
        for id in pairs(set) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            if not indexOf(order, id) then order[#order + 1] = id result.repaired = result.repaired + 1 end
        end
    end
    if result.seeded or result.appended > 0 or result.repaired > 0 then
        NS.Debug(TAG, "prepare seeded=%s appended=%s repaired=%s", result.seeded, result.appended, result.repaired)
    end
    return result
end
```
with
```lua
-- A fresh profile's default pad and dial (D7), once.
local function seed(p, result)
    if p.seeded then return end
    if #p.padOrder == 0 then Lib.CreateSurface("pad", L["Comms Pad"]) end
    if #p.dialOrder == 0 then Lib.CreateSurface("dial", L["Comms Dial"]) end
    p.seeded = true
    result.seeded = true
end

-- Every user group's callout list as a table, its dangling ids dropped.
local function repairGroups(p, result)
    for _, g in pairs(p.groups) do
        g.callouts = type(g.callouts) == "table" and g.callouts or {}
        for i = #g.callouts, 1, -1 do
            if not p.callouts[g.callouts[i]] then table.remove(g.callouts, i) result.repaired = result.repaired + 1 end
        end
    end
end

-- One pad or dial: its lists as tables, its dangling groups dropped, and each built-in it has not
-- been offered yet appended once (seenBuiltins).
local function repairSurface(s, result)
    s.seenBuiltins = type(s.seenBuiltins) == "table" and s.seenBuiltins or {}
    s.groups = type(s.groups) == "table" and s.groups or {}
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

-- A kind's display order: entries naming no surface dropped, surfaces it misses appended by id.
local function repairOrder(order, set, result)
    for i = #order, 1, -1 do
        if not set[order[i]] then table.remove(order, i) result.repaired = result.repaired + 1 end
    end
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not indexOf(order, id) then order[#order + 1] = id result.repaired = result.repaired + 1 end
    end
end

--- Seed, append newly shipped built-ins once per surface, and drop dangling ids. Idempotent.
--- @return table { seeded, appended, repaired }
function Lib.Prepare()
    local p = P()
    local result = { seeded = false, appended = 0, repaired = 0 }
    normalize(p, result)
    liftNextId(p)
    seed(p, result)
    repairGroups(p, result)
    for kind, set in pairs(surfaces()) do
        for _, s in pairs(set) do repairSurface(s, result) end
        repairOrder(kind == "pad" and p.padOrder or p.dialOrder, set, result)
    end
    if result.seeded or result.appended > 0 or result.repaired > 0 then
        NS.Debug(TAG, "prepare seeded=%s appended=%s repaired=%s", result.seeded, result.appended, result.repaired)
    end
    return result
end
```
The merged loop repairs a kind's surfaces, then its order, kind by kind; the surfaces and the orders are independent, so this is the order the old two loops had for each kind.

- [ ] **Step 7: `formatWhen` and `W.Values`**

In `settings/Slash.lua`, replace
```lua
-- Printed in parseWhen's own syntax, `content mythicPlus,raid; keyLevel 10-`, so a printed When
-- types back in.
local function formatWhen(when)
    local parts = {}
    for _, row in ipairs(NS.Resolver.ROWS) do
        local v = type(when) == "table" and when[row] or nil
        if row == "keyLevel" and type(v) == "table" and (v.min or v.max) then
            local range = (v.min and v.min == v.max) and tostring(v.min)
                or ((v.min and tostring(v.min) or "") .. "-" .. (v.max and tostring(v.max) or ""))
            parts[#parts + 1] = "keyLevel " .. range
        elseif row ~= "keyLevel" and type(v) == "table" and next(v) then
            parts[#parts + 1] = row .. " " .. table.concat(sortedKeys(v), ",")
        end
    end
    if #parts == 0 then return L["always"] end
    return table.concat(parts, "; ")
end
```
with
```lua
-- A key-level range as parseWhen reads it: `12` (one level), `10-`, `-15` or `10-15`.
local function formatRange(v)
    if v.min and v.min == v.max then return tostring(v.min) end
    return (v.min and tostring(v.min) or "") .. "-" .. (v.max and tostring(v.max) or "")
end

-- One When row in parseWhen's syntax, or nil for an empty one.
local function formatRow(row, v)
    if type(v) ~= "table" then return nil end
    if row == "keyLevel" then
        if v.min or v.max then return "keyLevel " .. formatRange(v) end
        return nil
    end
    if next(v) then return row .. " " .. table.concat(sortedKeys(v), ",") end
    return nil
end

-- Printed in parseWhen's own syntax, `content mythicPlus,raid; keyLevel 10-`, so a printed When
-- types back in.
local function formatWhen(when)
    local parts = {}
    for _, row in ipairs(NS.Resolver.ROWS) do
        local part = formatRow(row, type(when) == "table" and when[row] or nil)
        if part then parts[#parts + 1] = part end
    end
    if #parts == 0 then return L["always"] end
    return table.concat(parts, "; ")
end
```

In `settings/Groups_When.lua`, replace
```lua
--- The values a checkbox row offers, in order. The specialization row offers the classes the class
--- row picked, or the player's own; a spec chosen earlier stays listed so it can be cleared.
--- @return table { { value, text } }
function W.Values(row, when)
    if row == "content" then
        local out = {}
        for i, v in ipairs(NS.Resolver.TOKENS.content) do out[i] = { value = v, text = NS.PadRender.CONTENT[v] or v } end
        return out
    end
    if NS.Resolver.TOKENS[row] then return tokenValues(row) end
    if row == "class" then
        local out = {}
        for i, cf in ipairs(NS.GameIds.CLASSES) do out[i] = { value = cf, text = NS.Compat.ClassName(cf) or cf } end
        return out
    end
    if row == "spec" then
        local classes = {}
        local picked = type(when) == "table" and when.class or nil
        if type(picked) == "table" and next(picked) then
            for cf in pairs(picked) do classes[#classes + 1] = cf end
            table.sort(classes)
        else
            local live = NS.Situation.Current()
            if live.classFile then classes[1] = live.classFile end
        end
        local out, seen = {}, {}
        local function add(specID)
            if seen[specID] then return end
            seen[specID] = true
            out[#out + 1] = { value = specID, text = NS.Compat.SpecInfoByID(specID) or L["Specialization %d"]:format(specID) }
        end
        for _, cf in ipairs(classes) do
            for _, specID in ipairs(NS.GameIds.SPECS[cf] or {}) do add(specID) end
        end
        local chosen = {}
        for specID in pairs(type(when) == "table" and when.spec or {}) do chosen[#chosen + 1] = specID end
        table.sort(chosen)
        for _, specID in ipairs(chosen) do add(specID) end
        return out
    end
    return {}
end
```
with
```lua
local function contentValues()
    local out = {}
    for i, v in ipairs(NS.Resolver.TOKENS.content) do out[i] = { value = v, text = NS.PadRender.CONTENT[v] or v } end
    return out
end

local function classValues()
    local out = {}
    for i, cf in ipairs(NS.GameIds.CLASSES) do out[i] = { value = cf, text = NS.Compat.ClassName(cf) or cf } end
    return out
end

-- The classes whose specializations the spec row offers: those the class row picked, else the
-- player's own.
local function specClasses(when)
    local classes = {}
    local picked = type(when) == "table" and when.class or nil
    if type(picked) == "table" and next(picked) then
        for cf in pairs(picked) do classes[#classes + 1] = cf end
        table.sort(classes)
        return classes
    end
    local live = NS.Situation.Current()
    if live.classFile then classes[1] = live.classFile end
    return classes
end

local function specValues(when)
    local out, seen = {}, {}
    local function add(specID)
        if seen[specID] then return end
        seen[specID] = true
        out[#out + 1] = { value = specID, text = NS.Compat.SpecInfoByID(specID) or L["Specialization %d"]:format(specID) }
    end
    for _, cf in ipairs(specClasses(when)) do
        for _, specID in ipairs(NS.GameIds.SPECS[cf] or {}) do add(specID) end
    end
    local chosen = {}
    for specID in pairs(type(when) == "table" and when.spec or {}) do chosen[#chosen + 1] = specID end
    table.sort(chosen)
    for _, specID in ipairs(chosen) do add(specID) end
    return out
end

--- The values a checkbox row offers, in order. The specialization row offers the classes the class
--- row picked, or the player's own; a spec chosen earlier stays listed so it can be cleared.
--- @return table { { value, text } }
function W.Values(row, when)
    if row == "content" then return contentValues() end
    if NS.Resolver.TOKENS[row] then return tokenValues(row) end
    if row == "class" then return classValues() end
    if row == "spec" then return specValues(when) end
    return {}
end
```

- [ ] **Step 8: `Dial.Sync`**

Phase 4's fix wave took `Dial.Sync` to CCN 19 (it gained `wasOpen`, `link()` and the display mode). In `modules/Dial.lua`, replace
```lua
--- Make the dials match a set of plans: apply each planned dial at its place in `order` (the dial
--- order), release every other place, bind each built dial's key to its header, and in test mode or a
--- preview open the first one (spec §11.4): when the mode turns on or changes, or when the dial was open
--- before this rebuild closed it. A dial the player closed stays closed through later rebuilds, so it
--- does not come back over the settings window after every edit. Out of combat only.
function Dial.Sync(plans, order)
    local used, keys, first = {}, {}, nil
    local wasOpen = {}
    for index, inst in pairs(byIndex) do wasOpen[index] = inst.header:IsShown() end
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
    link()
    NS.SendEngine.BindKeys(keys)
    local plan = first and plans[order[first]]
    local mode = plan and plan.test and (plan.preview or "test") or nil
    if mode and (mode ~= displayMode or wasOpen[first]) then DS.Open(byIndex[first].header) end
    displayMode = mode
end
```
with
```lua
-- Apply each planned dial at its place in `order` (the dial order). Answers the places built, the
-- keys to bind ({ key, name, button } per built dial with a key) and the first place built.
local function applyAll(plans, order)
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
    return used, keys, first
end

-- In test mode or a preview, open the first dial built (spec §11.4) when the mode turns on or
-- changes, or when that dial was open before this rebuild closed it; then remember the mode.
local function openDisplay(plans, order, first, wasOpen)
    local plan = first and plans[order[first]]
    local mode = plan and plan.test and (plan.preview or "test") or nil
    if mode and (mode ~= displayMode or wasOpen[first]) then DS.Open(byIndex[first].header) end
    displayMode = mode
end

--- Make the dials match a set of plans: apply each planned dial at its place in `order` (the dial
--- order), release every other place, bind each built dial's key to its header, and in test mode or a
--- preview open the first one (spec §11.4): when the mode turns on or changes, or when the dial was open
--- before this rebuild closed it. A dial the player closed stays closed through later rebuilds, so it
--- does not come back over the settings window after every edit. Out of combat only.
function Dial.Sync(plans, order)
    local wasOpen = {}
    for index, inst in pairs(byIndex) do wasOpen[index] = inst.header:IsShown() end
    local used, keys, first = applyAll(plans, order)
    for index in pairs(byIndex) do
        if not used[index] then Dial.Release(index) end
    end
    link()
    NS.SendEngine.BindKeys(keys)
    openDisplay(plans, order, first, wasOpen)
end
```
(The two helpers sit after `link()` and use the file's `byIndex`, `displayMode`, `profileDial`, `DS` and `Dial.Apply`, all declared above them. The cases that pin the behavior are `test_dial`'s "Sync applies each planned dial at its place in the order, binds its key, and opens dial 1 in test mode", "[final 5] test mode opens dial 1 once: a rebuild keeps it open, and after the player closes it, closed", "[final 2] two dials: opening the second closes the first, and the number keys go with it" and "Preview as opens dial 1 on the previewed situation, and its wedges send nothing"; they stay green unchanged.)

- [ ] **Step 9: Run the gate and the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: PASS, 0 / 0, and `complexity  pass  — 0 warnings` (max 15). Checked on a scratch export of `55194f6` with Steps 1 to 8: 598 passed, 3 skipped (the vendored-payload cases, which need a `../LibKa0s` sibling; they run in this worktree).

- [ ] **Step 10: Commit**

```bash
git add modules/Pad_Layout.lua modules/Surfaces.lua modules/Channels.lua modules/Library.lua modules/Dial.lua settings/Slash.lua settings/Groups_When.lua tests/test_channels.lua tests/test_members.lua
git checkout -- modules/Pad_Layout.lua modules/Surfaces.lua modules/Channels.lua modules/Library.lua modules/Dial.lua settings/Slash.lua settings/Groups_When.lua tests/test_channels.lua tests/test_members.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Complexity: the eight functions over CCN 15 split into named helpers, behavior unchanged"
```
(Every file here was edited in place, so its CRLF stands and a plain checkout is enough.)

---
### Task 2: Vendor LibDeflate and LibSerialize

Spec §3 and §15 need both libraries; neither is vendored yet. Each is copied whole from its upstream release tag into its own folder (library-stack-§3: folder per lib, its `.xml` in the TOC, committed, never edited) with its license, which the zlib license (LibDeflate) and MIT (LibSerialize) both require to travel with the code. The harness's TOC reader skips every `libs\` line, so `tests/loader.lua` names the two `.xml` files, as it does LibKa0s's.

**Files:**
- Create: `libs/LibDeflate/LibDeflate.lua`, `libs/LibDeflate/lib.xml`, `libs/LibDeflate/LICENSE.txt`, `libs/LibSerialize/LibSerialize.lua`, `libs/LibSerialize/lib.xml`, `libs/LibSerialize/LICENSE` (copied, never edited)
- Modify: `QuickComms.toc` (two library lines, `## OptionalDeps:`), `tests/loader.lua`, `DEPENDENCIES.md`
- Test: `tests/test_setup.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `LibStub("LibDeflate", true)` (`:CompressDeflate(s, { level = 9 })`, `:DecompressDeflate(s)`, `:EncodeForPrint(s)`, `:DecodeForPrint(s)`) and `LibStub("LibSerialize", true)` (`:Serialize(...)`, `:Deserialize(s)` answering `ok, value`), loaded before the addon's own files in the client and in every headless instance. Task 3 takes both at load.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_setup.lua`:
```lua
test("libs: [phase 5] LibDeflate and LibSerialize are vendored, TOC-listed and loaded before the addon", function()
    local _, m = T.newAddon()
    local toc = read("QuickComms.toc")
    for _, lib in ipairs({ "LibDeflate", "LibSerialize" }) do
        -- red under: drop the lib's line from QuickComms.toc (the client would never load it)
        assertTrue(toc:find("libs\\" .. lib .. "\\lib.xml", 1, true) ~= nil, lib .. " has a TOC line")
        assertTrue(m.LibStub(lib, true) ~= nil, lib .. " registered with LibStub")
    end
    local D, S = m.LibStub("LibDeflate"), m.LibStub("LibSerialize")
    local packed = D:EncodeForPrint(D:CompressDeflate(S:Serialize({ a = 1 })))
    local ok, back = S:Deserialize(D:DecompressDeflate(D:DecodeForPrint(packed)))
    assertTrue(ok and back.a == 1, "a round trip through both")
end)
```

- [ ] **Step 2: Run it to check it fails**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_setup` ("LibDeflate has a TOC line").

- [ ] **Step 3: Copy the two libraries from their release tags**

The clones go to the session's scratch directory, never into the repo, and nothing in them is run:
```bash
SRC="$(mktemp -d)"
git clone --depth 1 --branch 1.0.2-release https://github.com/SafeteeWoW/LibDeflate "$SRC/LibDeflate"
git clone --depth 1 --branch v1.2.3 https://github.com/rossnichols/LibSerialize "$SRC/LibSerialize"
git -C "$SRC/LibDeflate" rev-parse HEAD     # expect 6831edcaa915154e7769d622e0de72ee5d25a882
git -C "$SRC/LibSerialize" rev-parse HEAD   # expect aa6e50dddad28f8dfa6c27c9b1e15ae40262b4a5
mkdir -p libs/LibDeflate libs/LibSerialize
cp "$SRC/LibDeflate/LibDeflate.lua" "$SRC/LibDeflate/lib.xml" "$SRC/LibDeflate/LICENSE.txt" libs/LibDeflate/
cp "$SRC/LibSerialize/LibSerialize.lua" "$SRC/LibSerialize/lib.xml" "$SRC/LibSerialize/LICENSE" libs/LibSerialize/
rm -rf "$SRC"
```
If a `rev-parse` answers another commit, stop: the tag moved upstream, and the owner decides which bytes to vendor.

- [ ] **Step 4: The TOC lines and the loader**

In `QuickComms.toc`, replace
```
## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0
```
with
```
## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0, LibDeflate, LibSerialize
```
and replace
```
# ONE line: the .xml is itself the file list (library-stack-§7). After Ace3.
libs\LibKa0s\LibKa0s.xml
```
with
```
# ONE line: the .xml is itself the file list (library-stack-§7). After Ace3.
libs\LibKa0s\LibKa0s.xml
# LOAD-BEARING: modules\Share.lua takes LibDeflate at load (the share string's compression, spec §15).
libs\LibDeflate\lib.xml
# LOAD-BEARING: modules\Share.lua takes LibSerialize at load (the share string's payload, spec §15).
libs\LibSerialize\lib.xml
```

In `tests/loader.lua`, replace
```lua
local LIBKA0S = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")
```
with
```lua
local LIBKA0S = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")

-- The two libraries modules/Share.lua takes at load (spec §15), each through its own lib.xml as the
-- TOC loads it. tocFiles skips every libs\ line, so they are named here, and load after LibKa0s as
-- the TOC orders them.
local SHARE_LIBS = {}
for _, xml in ipairs({ "libs/LibDeflate/lib.xml", "libs/LibSerialize/lib.xml" }) do
    for _, rel in ipairs(Loader.xmlFiles(xml)) do SHARE_LIBS[#SHARE_LIBS + 1] = rel end
end
```
and replace
```lua
    for _, rel in ipairs(LIBKA0S) do sources[#sources + 1] = { path = rel, lib = true } end
```
with
```lua
    for _, rel in ipairs(LIBKA0S) do sources[#sources + 1] = { path = rel, lib = true } end
    for _, rel in ipairs(SHARE_LIBS) do sources[#sources + 1] = { path = rel, lib = true } end
```

- [ ] **Step 5: `DEPENDENCIES.md`**

In `## Runtime (in-game) — what a player needs`, after the `**Nothing else.**` bullet, add:
```markdown
- **The share string's two libraries are vendored like the rest** (design spec §15): LibDeflate
  `1.0.2-release` (commit `6831edca`, zlib license, kept as `libs/LibDeflate/LICENSE.txt`) from
  <https://github.com/SafeteeWoW/LibDeflate>, and LibSerialize `v1.2.3` (commit `aa6e50dd`, MIT, kept as
  `libs/LibSerialize/LICENSE`) from <https://github.com/rossnichols/LibSerialize>. Each folder is the
  tag's `.lua`, `lib.xml` and license, copied whole and never edited; a new version is a re-copy from
  its tag, in one commit with this line.
```

- [ ] **Step 6: Run the gate**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0 (`.luacheckrc` already excludes `libs/`; so do the prose, layout-cap and complexity gates).

- [ ] **Step 7: Commit**

```bash
git add libs/LibDeflate libs/LibSerialize QuickComms.toc tests/loader.lua tests/test_setup.lua DEPENDENCIES.md
rm -r libs/LibDeflate libs/LibSerialize && git checkout -- libs/LibDeflate libs/LibSerialize
git checkout -- QuickComms.toc tests/loader.lua tests/test_setup.lua DEPENDENCIES.md
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Libs: vendor LibDeflate 1.0.2 and LibSerialize 1.2.3 for the share string"
```
The copied files arrive with bare LF; the remove-and-checkout gives them the CRLF `.gitattributes` declares, and the second run is the `test_eol` check on the staged copies.

---
### Task 3: Share's codec and checks (pure), and `Bake.CleanText`

The string format, the decode a player's paste needs, the version gate and the schema checks of spec §15 steps 1 to 5, as a pure module: plain tables and strings in, a plan and a refusal list out. The sanitizer an import stores is §8.3's without the `|` escape (`Bake.CleanText`); `Bake.Sanitize` becomes CleanText then the escape, so both keep one definition.

**Files:**
- Create: `modules/Share.lua`, `tests/test_share.lua`
- Modify: `modules/Bake.lua` (`B.Sanitize` and its doc comment), `QuickComms.toc` (one line), `tests/run.lua`, `locales/enUS.lua`
- Test: `tests/test_share.lua`, `tests/test_bake.lua`

**Interfaces:**
- Consumes: Task 2's two libraries; `NS.Library.ValidName(v)`, `NS.Library.ValidWhen(w)`, `NS.Channels.IsKind(kind)`, `NS.BuiltIns.groups`, `NS.SchemaRuntime.FindRow(path)` (all at call time).
- Produces:
  - `NS.Bake.CleanText(text) -> clean|nil, reason ("empty" | "startsWithSlash")`.
  - `NS.Share.PREFIX = "!QC1!"`, `VERSION = 1`, `MAX_STRING = 50000`, `MAX_RAW = 524288`, `MAX_MEMBERS = 500`, `MAX_DEPTH = 8`, `TEXT_MAX = 255`, `KINDS` (`{ kind, key, prefix }` for callout, group, pad, dial, in that order).
  - `Share.Encode(payload) -> string|nil, "unavailable"`; `Share.Decode(text) -> payload|nil, reason`; `Share.Validate(payload) -> res`; `Share.Check(text) -> res` (the result shape above, File Structure; it never raises: a check that errors answers `damaged`); `Share.Portable(kind, path) -> boolean`.
  - `Share.REASON_TEXT[reason]`, `Share.MEMBER_REASON[reason]`, `Share.CountText(t) -> "3 callouts, 1 group"` (counts, lists or sets), `Share.ReportLines(res) -> string[]`.
  - Task 5 appends the edge to this file and replaces its header's first paragraph.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_share.lua`:
```lua
-- tests/test_share.lua — modules/Share.lua's codec and checks (spec §15, §8.3): the string's shape,
-- decoding what a player actually pastes, the version gate, the schema checks, the sanitizer over every
-- text field and the import report. Pure: no frame is touched. Library.Import is tested in
-- tests/test_library.lua, the page in tests/test_page_share.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function boot()
    local NS = T.bootAddon()
    return NS, NS.Share
end

local function bundle(t)
    t.v = t.v or 1
    t.addon = t.addon or "QuickComms"
    t.kind = t.kind or "bundle"
    return t
end

-- "kind:id:reason" for each refused member, in order.
local function refusals(res)
    local out = {}
    for _, r in ipairs(res.refused) do out[#out + 1] = r.kind .. ":" .. r.id .. ":" .. r.reason end
    return table.concat(out, ",")
end

local KICK = { name = "Kick", text = "Kick on me {rt8}", channel = "party" }

test("share: a string is !QC1! then printable text, and decodes back to the same payload", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ callouts = { c1 = KICK } }))
    assertEqual(s:sub(1, 5), "!QC1!")
    assertTrue(s:find("[%s|]") == nil, "no whitespace and no escape character")
    local back = SH.Decode(s)
    assertEqual(back.callouts.c1.text, "Kick on me {rt8}")
    assertEqual(back.v, 1)
    assertEqual(back.addon, "QuickComms")
end)

test("share: [review 1] a pasted string may wrap and carry spaces; a cut-short one is damaged and imports nothing", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ groups = { g1 = { name = "Mine", callouts = {} } } }))
    local wrapped = "  " .. s:sub(1, 20) .. "\r\n" .. s:sub(21, 40) .. " \n\t" .. s:sub(41) .. "\n"
    assertEqual(SH.Decode(wrapped).groups.g1.name, "Mine")
    local payload, why = SH.Decode(s:sub(1, #s - 12))
    assertNil(payload)
    assertEqual(why, "damaged")
    local res = SH.Check(s:sub(1, #s - 12))
    assertFalse(res.ok)
    assertEqual(#res.callouts + #res.groups + #res.pads + #res.dials, 0)
    assertEqual(SH.ReportLines(res)[1], "That string is damaged or cut short. Copy all of it again.")
end)

test("share: a string that is not ours, is empty, is garbage after the prefix or is too large is refused", function()
    local _, SH = boot()
    assertEqual(select(2, SH.Decode("hello there")), "notOurs")
    assertEqual(select(2, SH.Decode("   \n ")), "empty")
    assertEqual(select(2, SH.Decode(nil)), "empty")
    assertEqual(select(2, SH.Decode("!QC1!@@@@")), "damaged")
    assertEqual(select(2, SH.Decode("!QC1!" .. string.rep("a", SH.MAX_STRING))), "tooLarge")
    -- another addon's payload in our wrapper
    local other = SH.Encode({ v = 1, addon = "WeakAuras", kind = "bundle" })
    assertEqual(SH.Check(other).reason, "notOurs")
end)

test("share: a newer version is refused with a line to update; a damaged version is refused", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({ v = 2, callouts = { c1 = KICK } }))
    assertFalse(res.ok)
    assertEqual(res.reason, "newer")
    assertEqual(SH.ReportLines(res)[1], "That string was made by a newer Quick Comms. Update the addon, then import it.")
    assertEqual(SH.Validate(bundle({ v = 0 })).reason, "damaged")
    assertEqual(SH.Validate(bundle({ v = 1.5 })).reason, "damaged")
    assertEqual(SH.Validate(bundle({ callouts = "nope" })).reason, "damaged")
end)

test("share: [review 2] a command or control characters never survive: / is refused, lines are flattened", function()
    local NS, SH = boot()
    local res = SH.Validate(bundle({ callouts = {
        c1 = { name = "Run", text = "  /run print(1)", channel = "party" },
        c2 = { name = "Two\nlines", text = "Kick\r\n/script x\tnow", channel = "say" },
        c3 = { name = "Pipe", text = "a|cffff0000red", channel = "party" },
        c4 = { name = "Long", text = string.rep("x", 256), channel = "party" },
    } }))
    assertTrue(res.ok)
    assertEqual(refusals(res), "callout:c1:startsWithSlash,callout:c4:tooLong")
    assertEqual(res.callouts[1].fields.name, "Two lines")
    assertEqual(res.callouts[1].fields.text, "Kick /script x now", "one line, the slash no longer first")
    assertEqual(res.callouts[2].fields.text, "a|cffff0000red", "stored unescaped; Bake escapes it once")
    -- red under: store B.Sanitize's escaped text instead of B.CleanText's (the bake escapes it twice)
    assertEqual(NS.Bake.Bake(res.callouts[2].fields, { group = "party", lockdown = {} }), "/p a||cffff0000red")
end)

test("share: ids, channels, names, icons and Whens are checked against the schema", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({
        callouts = {
            x9 = KICK,
            c2 = { name = "Guild", text = "hi", channel = "guild" },
            c3 = { name = string.rep("n", 33), text = "hi", channel = "party" },
            c4 = { name = "Icon", text = "hi", channel = "party", icon = -3 },
            c5 = { name = "Fine", text = "hi", channel = "smartGroup", icon = 136012 },
            c6 = { name = "Empty", channel = "party" },
        },
        groups = {
            g1 = { name = "Bad When", when = { content = { moon = true } } },
            g2 = { name = "Good", when = { content = { mythicPlus = true } }, callouts = { "c5", "c2", "bi.mplus.lust", "c5" } },
        },
    }))
    assertEqual(refusals(res), "callout:c2:badChannel,callout:c3:badName,callout:c4:badIcon,callout:x9:badId,group:g1:badWhen")
    assertEqual(#res.callouts, 2)
    assertEqual(res.callouts[1].fields.icon, 136012)
    assertEqual(res.callouts[2].fields.text, "", "a callout may have no text yet")
    assertEqual(table.concat(res.groups[1].callouts, ","), "c5", "refused, built-in and repeated references are left out")
    assertEqual(res.dropped, 2)
    assertTrue(res.groups[1].fields.when.content.mythicPlus)
end)

test("share: a pad keeps the shared groups and the built-in sets, and only the fields that travel", function()
    local NS, SH = boot()
    local res = SH.Validate(bundle({
        groups = { g1 = { name = "Mine" } },
        pads = { p4 = { name = "Theirs", enabled = false, groups = { "g1", "bi.mplus", "bi.bg.ab.stables", "bi.gone", "g9" },
            fields = { ["pad.layout.columns"] = 6, ["pad.point"] = { "CENTER", "CENTER", 10, 10 },
                ["pad.name"] = "x", ["pad.nope"] = 1, ["dial.mode"] = "flat" } } },
        dials = { d5 = { name = "Their dial", groups = { "bi.bg.ab" },
            fields = { ["dial.key"] = "G", ["dial.mode"] = "flat", ["dial.point"] = { "CENTER", "CENTER", 0, 0 } } } },
    }))
    assertTrue(res.ok)
    local pad = res.pads[1]
    assertEqual(pad.name, "Theirs")
    assertFalse(pad.enabled)
    assertEqual(table.concat(pad.groups, ","), "g1,bi.mplus", "a node is not a top-level set; an unknown set is left out")
    assertEqual(pad.fields["pad.layout.columns"], 6)
    assertNil(pad.fields["pad.point"], "a position never travels")
    assertNil(pad.fields["pad.name"])
    local dial = res.dials[1]
    assertNil(dial.fields["dial.key"], "a key never travels")
    assertNil(dial.fields["dial.point"])
    assertEqual(dial.fields["dial.mode"], "flat")
    assertEqual(res.ignored, 6)
    assertEqual(res.dropped, 3)
    assertTrue(NS.Share.Portable("pad", "pad.look.visibility"))
    assertFalse(NS.Share.Portable("pad", "dial.mode"))
end)

test("share: the report counts what arrives, then names each member left out and why", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({
        callouts = { c1 = KICK, c2 = { name = "Sneaky", text = "/run print(1)", channel = "party" } },
        groups = { g1 = { name = "Smoke test", callouts = { "c1", "c2" } } },
    }))
    local lines = SH.ReportLines(res)
    assertEqual(lines[1], "Ready to import: 1 callout, 1 group.")
    assertEqual(lines[2], "Left out the callout 'Sneaky': its text starts with /.")
    assertEqual(lines[3], "1 reference to something the string does not carry was left out.")
    assertEqual(SH.CountText({ callouts = 3, groups = 0, pads = 2, dials = 1 }), "3 callouts, 2 pads, 1 dial")
    assertEqual(SH.ReportLines(SH.Validate(bundle({})))[1], "Nothing in this string can be imported.")
end)

test("share: more members than one string may carry is refused before any is checked", function()
    local _, SH = boot()
    local callouts = {}
    for i = 1, SH.MAX_MEMBERS + 1 do callouts["c" .. i] = KICK end
    assertEqual(SH.Validate(bundle({ callouts = callouts })).reason, "tooLarge")
end)

test("share: [review 1] a hand-made string with a NaN reference, a cyclic field or an infinite icon raises nothing", function()
    local _, SH = boot()
    local loop = { 1, 2 }
    loop.self = loop
    local s = SH.Encode(bundle({
        callouts = { c1 = KICK, c2 = { name = "Inf", text = "hi", channel = "party", icon = math.huge } },
        groups = { g1 = { name = "Odd refs", callouts = { 0 / 0, "c1", 7 } },
            g2 = { name = "Loop When", when = loop } },
        pads = { p1 = { name = "Loop", groups = { "g1" }, fields = { ["pad.layout.columns"] = loop,
            ["pad.layout.rows"] = 0 / 0 } } },
    }))
    -- red under: drop the type(ref) check from keepRefs in modules/Share.lua ("table index is NaN")
    local res = SH.Check(s)
    assertTrue(res.ok)
    assertEqual(refusals(res), "callout:c2:badIcon,group:g2:badWhen")
    assertEqual(table.concat(res.groups[1].callouts, ","), "c1", "the NaN and the number are dropped references")
    assertEqual(res.dropped, 2)
    assertNil(res.pads[1].fields["pad.layout.columns"], "a cyclic value is left out, never walked forever")
    assertNil(res.pads[1].fields["pad.layout.rows"], "a NaN value is left out")
    assertEqual(res.ignored, 2)
end)

test("share: [review 1] a payload that still raises inside the checks is damaged, never an error", function()
    local NS, SH = boot()
    local s = SH.Encode(bundle({ callouts = { c1 = KICK } }))
    NS.Library.ValidName = function() error("boom") end
    -- red under: call SH.Validate outside the pcall in SH.Check
    local res = SH.Check(s)
    assertFalse(res.ok)
    assertEqual(res.reason, "damaged")
end)

test("share: [review 2] a surface's string fields pass the sanitizer; an empty string is kept for the seam to judge", function()
    local _, SH = boot()
    local res = SH.Validate(bundle({ dials = { d1 = { name = "Mine",
        fields = { ["dial.mode"] = "  flat\n", ["dial.openAt"] = "" } } } }))
    local f = res.dials[1].fields
    assertEqual(f["dial.mode"], "flat")
    assertEqual(f["dial.openAt"], "", "kept: the seam refuses it at write, as it would a player's")
    assertEqual(res.ignored, 0)
    local run = SH.Validate(bundle({ dials = { d1 = { name = "Mine", fields = { ["dial.mode"] = "/run x" } } } }))
    assertNil(run.dials[1].fields["dial.mode"])
    assertEqual(run.ignored, 1)
end)

test("share: SHARE-3's and SHARE-4's strings (docs/smoke-tests.md) read as the checks say", function()
    local _, SH = boot()
    -- the strings the owner pastes in game: a refused /run callout, then a newer version
    local share3 = "!QC1!v4CVUjmmuuaybLPIufQdD2kdOwwqHbeZgPYatnrIz8pxLef7RJSVUuuvx6JsEIS4jcZ6rF6CotojB8U4q4TIMYp)xjmgxKcRkuLfQnEafsdOpZrHfgRTUEGrqG4xAb85kHw7WXVIDQ(9oRnW77qTugrTbstxMlzlNGFOHfhZeMdzwG9RN29xAg)rKx1kqemJbRWthE8K8SBtZVT2hr2GVdP3l)intwJGO)A6LQHm86RF)09)"
    local share4 = "!QC1!JXWsk9IYV0ckMRGsmLuYpVffyPzMC2oNFU5wStzNzEPKusLMxk5KAtjNyo5KFPLumxcvgRa("
    assertEqual(table.concat(SH.ReportLines(SH.Check(share3)), " | "),
        "Ready to import: 1 callout, 1 group. | Left out the callout 'Sneaky': its text starts with /. | "
            .. "1 reference to something the string does not carry was left out.")
    assertEqual(table.concat(SH.ReportLines(SH.Check(share4)), " | "),
        "That string was made by a newer Quick Comms. Update the addon, then import it.")
end)

test("share: [review 1] a short string that inflates past MAX_RAW is damaged before it is read", function()
    local _, SH = boot()
    local s = SH.Encode(bundle({ callouts = { c1 = { name = "Big", text = string.rep("a", SH.MAX_RAW), channel = "party" } } }))
    assertTrue(#s < 5000, "a few thousand characters")
    -- red under: drop the #raw > SH.MAX_RAW check from decodeBody in modules/Share.lua
    assertEqual(select(2, SH.Decode(s)), "damaged")
end)
```

The SHARE-3 and SHARE-4 strings above are the ones `docs/smoke-tests.md` prints (Task 11): this case decodes the exact bytes the owner pastes in game, so a drift in the encoder, the payload shape or the report wording fails here first. They were made with `Share.Encode` on a scratch run of this plan (SHARE-3: `{ callouts = { c1 = { name = "Kick", text = "Kick on me {rt8}", channel = "smartGroup" }, c2 = { name = "Sneaky", text = "/run print(1)", channel = "party" } }, groups = { g1 = { name = "Smoke test", callouts = { "c1", "c2" } } } }`; SHARE-4: the same shape with `v = 2`); if a case here fails because the strings must change, regenerate both with `Share.Encode` and paste the new ones into this case and into `docs/smoke-tests.md` together.

Append to `tests/test_bake.lua`:
```lua
test("bake: [phase 5] CleanText is the sanitizer short of the escape; Sanitize is CleanText, then the escape", function()
    local B = bake()
    assertEqual(B.CleanText("  a|b\n c  "), "a|b c")
    assertEqual(select(2, B.CleanText("\t/run x")), "startsWithSlash")
    assertEqual(select(2, B.CleanText("  ")), "empty")
    assertEqual(select(2, B.CleanText(42)), "empty")
    assertEqual(B.Sanitize("  a|b\n c  "), "a||b c")
end)
```

In `tests/run.lua`, replace
```lua
        "test_bake",
```
with
```lua
        "test_bake",
        "test_share",
```

- [ ] **Step 2: Run them to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_bake` (`CleanText` is nil) and in every `test_share` case (`NS.Share` is nil).

- [ ] **Step 3: `Bake.CleanText`**

In `modules/Bake.lua`, replace
```lua
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
```
with
```lua
--- The §8.3 sanitizer short of the escape: one line (every control character flattened to a
--- space), runs of whitespace collapsed, trimmed, and a leading "/" refused. Imported text is stored
--- this way (spec §8.3: sanitized when it is imported, and again at every bake); the "|" escape is
--- left to the bake, so a stored "|" is never escaped twice.
--- @return string|nil clean, string|nil reason ("empty" | "startsWithSlash")
function B.CleanText(text)
    if type(text) ~= "string" then return nil, "empty" end
    local s = squeeze((text:gsub("%c", " ")))
    if s == "" then return nil, "empty" end
    if s:sub(1, 1) == "/" then return nil, "startsWithSlash" end
    return s
end

--- Clean user text: one line, no leading slash, pipes escaped.
--- @return string|nil clean, string|nil reason ("empty" | "startsWithSlash")
function B.Sanitize(text)
    local s, why = B.CleanText(text)
    if not s then return nil, why end
    return (s:gsub("|", "||"))
end
```

- [ ] **Step 4: The module**

Create `modules/Share.lua`:
```lua
local _, NS = ...
-- modules/Share.lua — export and import strings (design spec §15). The codec and the checks are
-- PURE: plain tables and strings in and out, no frame and no client read; the edge (Export, Check,
-- Apply and the copy window) joins below them in Task 5 of the phase 5 plan.
--
-- THE STRING. "!QC1!" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize
-- (payload))), payload = { v = 1, addon = "QuickComms", kind = "bundle", callouts, groups, pads?,
-- dials? }. Decode ignores whitespace (a pasted string may wrap or carry spaces) and refuses, with a
-- reason, a string that is not ours, is damaged or cut short, or is too large.
--
-- THE CHECKS (spec §15 steps 2 to 4). The version first: a newer one is refused, an older one is
-- lifted through MIGRATIONS (empty while v is 1). Then each member against the schema: its id's shape
-- (c<n>, g<n>, p<n>, d<n>), its channel kind, its lengths, its When, and every text field through the
-- §8.3 sanitizer (Bake.CleanText): names, callout text, icon paths, and every string in a pad's or a
-- dial's field values, nested ones too (cleanValue, which also refuses a number that is not finite and
-- a table nested past MAX_DEPTH). Check fails closed: a hand-made payload that still raises inside the
-- checks reads as damaged. A member that fails is refused and listed with its reason; a reference
-- to something the string does not carry (a group's callout, a surface's group) is left out and
-- counted. A pad or a dial carries its name, Enabled, its groups and its portable fields, keyed by
-- member-row path; never its key or its position (spec §15: it arrives unbound). Nothing in a string
-- is ever run (anti-pattern #20): a leading "/" is refused here, and Bake refuses one again at every
-- bake. The result is a plan that Library.Import, the registry writer, applies.

NS.Share = NS.Share or {}
local SH = NS.Share
local L = NS.L

local LD = LibStub and LibStub("LibDeflate", true)
local LS = LibStub and LibStub("LibSerialize", true)

SH.PREFIX = "!QC1!"
SH.VERSION = 1
SH.MAX_STRING = 50000    -- characters of a pasted string, before anything is decompressed
SH.MAX_RAW = 524288      -- bytes of the decompressed payload, before LibSerialize reads any of it
SH.MAX_MEMBERS = 500     -- callouts, groups, pads and dials in one string
SH.MAX_DEPTH = 8         -- nested tables in one field value (a When, a color); deeper is damaged
SH.TEXT_MAX = 255        -- bytes of a callout's text and of an icon path: what Bake caps a whole
                         -- line at (the Text box counts characters; a text over 255 bytes never bakes)

-- Older payload versions, each lifted one step: MIGRATIONS[v](payload) answers the v + 1 payload.
local MIGRATIONS = {}

-- The payload's sections, in the order they are checked: a group's references need the callouts, a
-- surface's need the groups.
SH.KINDS = {
    { kind = "callout", key = "callouts", prefix = "c" },
    { kind = "group", key = "groups", prefix = "g" },
    { kind = "pad", key = "pads", prefix = "p" },
    { kind = "dial", key = "dials", prefix = "d" },
}

-- A field value as a plain copy with every string in it through the §8.3 sanitizer (an empty string
-- stays empty), or nil when it cannot be stored: a string the sanitizer refuses, a number that is not
-- finite (NaN, an infinity), a function or other non-data value, or tables nested deeper than
-- MAX_DEPTH (a hand-made cycle among them).
local function cleanValue(v, depth)
    local t = type(v)
    if t == "string" then
        local s, why = NS.Bake.CleanText(v)
        if s then return s end
        if why == "empty" then return "" end
        return nil
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        return v
    elseif t == "boolean" then
        return v
    elseif t ~= "table" or depth > SH.MAX_DEPTH then
        return nil
    end
    local out = {}
    for k, x in pairs(v) do
        local c = cleanValue(x, depth + 1)
        if c == nil or type(k) == "table" then return nil end
        out[k] = c
    end
    return out
end

-- ── the codec ───────────────────────────────────────────────────────────────────────────────

--- A payload as a share string, or nil and "unavailable" without the two libraries.
--- @return string|nil, string|nil
function SH.Encode(payload)
    if not (LD and LS) then return nil, "unavailable" end
    return SH.PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(payload), { level = 9 }))
end

local function decodeBody(body)
    local packed = LD:DecodeForPrint(body)
    if not packed then return nil end
    local raw = LD:DecompressDeflate(packed)
    if not raw or #raw > SH.MAX_RAW then return nil end
    local ok, value = LS:Deserialize(raw)
    if ok then return value end
    return nil
end

--- A share string's payload, or nil and why ("empty" | "tooLarge" | "notOurs" | "damaged" |
--- "unavailable"). Whitespace anywhere in it is ignored.
--- @return table|nil, string|nil
function SH.Decode(text)
    if not (LD and LS) then return nil, "unavailable" end
    if type(text) ~= "string" then return nil, "empty" end
    local s = text:gsub("%s+", "")
    if s == "" then return nil, "empty" end
    if #s > SH.MAX_STRING then return nil, "tooLarge" end
    if s:sub(1, #SH.PREFIX) ~= SH.PREFIX then return nil, "notOurs" end
    local ok, payload = pcall(decodeBody, s:sub(#SH.PREFIX + 1))
    if not ok or type(payload) ~= "table" then return nil, "damaged" end
    return payload
end

-- ── the checks ──────────────────────────────────────────────────────────────────────────────

local function newResult()
    return { ok = false, callouts = {}, groups = {}, pads = {}, dials = {}, refused = {}, dropped = 0,
        ignored = 0, known = {} }
end

-- A section's ids in a stable order: by the number they end in, then as text.
local function sortedIds(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local na = tonumber(tostring(a):match("(%d+)$")) or 0
        local nb = tonumber(tostring(b):match("(%d+)$")) or 0
        if na ~= nb then return na < nb end
        return tostring(a) < tostring(b)
    end)
    return ids
end

-- A text field through the §8.3 sanitizer. Empty is allowed (a callout may have no text yet).
local function cleanText(v)
    if v ~= nil and type(v) ~= "string" then return nil, "badText" end
    local s, why = NS.Bake.CleanText(v)
    if s then
        if #s > SH.TEXT_MAX then return nil, "tooLong" end
        return s
    end
    if why == "empty" then return "" end
    return nil, why
end

-- A name: sanitized, then 1 to 32 characters (Library.ValidName).
local function cleanName(v)
    if v ~= nil and type(v) ~= "string" then return nil, "badName" end
    local s = NS.Bake.CleanText(v)
    if not (s and NS.Library.ValidName(s)) then return nil, "badName" end
    return s
end

-- An icon: none (false), a whole texture id, or a sanitized texture path with no escape character.
-- Answers the icon, and a reason only when it is refused.
local function cleanIcon(v)
    if v == nil or v == false then return false end
    if type(v) == "number" then
        if v > 0 and v < 2 ^ 31 and v == math.floor(v) then return v end   -- NaN and inf fail here
        return nil, "badIcon"
    end
    local s = type(v) == "string" and NS.Bake.CleanText(v) or nil
    if not s or #s > SH.TEXT_MAX or s:find("|", 1, true) then return nil, "badIcon" end
    return s
end

local function calloutEntry(_, id, c)
    if type(c) ~= "table" then return nil, "damaged" end
    local name, why = cleanName(c.name)
    if not name then return nil, why end
    local text
    text, why = cleanText(c.text)
    if not text then return nil, why end
    if not NS.Channels.IsKind(c.channel) then return nil, "badChannel" end
    local icon
    icon, why = cleanIcon(c.icon)
    if why then return nil, why end
    return { id = id, fields = { name = name, text = text, channel = c.channel, icon = icon } }
end

-- The ids in `list` that `ok(id)` accepts, each once, in order; every other entry (one that is not a
-- string among them, a NaN included) is a dropped reference.
local function keepRefs(list, ok, res)
    local out, seen = {}, {}
    for _, ref in ipairs(type(list) == "table" and list or {}) do
        if type(ref) ~= "string" then
            res.dropped = res.dropped + 1
        elseif not seen[ref] then
            seen[ref] = true
            if ok(ref) then out[#out + 1] = ref else res.dropped = res.dropped + 1 end
        end
    end
    return out
end

local function groupEntry(_, id, g, res)
    if type(g) ~= "table" then return nil, "damaged" end
    local name, why = cleanName(g.name)
    if not name then return nil, why end
    local icon
    icon, why = cleanIcon(g.icon)
    if why then return nil, why end
    local when = cleanValue(g.when == nil and {} or g.when, 1)
    if when == nil or not NS.Library.ValidWhen(when) then return nil, "badWhen" end
    local refs = keepRefs(g.callouts, function(cid) return res.known[cid] == "callout" end, res)
    return { id = id, callouts = refs, fields = { name = name, icon = icon, when = when,
        openInto = g.openInto == true, enabled = g.enabled ~= false } }
end

-- The member rows whose value travels with a pad or a dial: every one of its kind but its name and
-- Enabled (carried beside the fields), its position and its key (spec §15: it arrives unbound).
local NOT_PORTABLE = { point = true, key = true }

--- Whether the member row at `path` travels in a share string with a `kind` ("pad" | "dial").
function SH.Portable(kind, path)
    local row = NS.SchemaRuntime and type(path) == "string" and NS.SchemaRuntime.FindRow(path)
    if not (row and row.instance == kind) or NOT_PORTABLE[row.type] then return false end
    return path ~= kind .. ".name" and path ~= kind .. ".enabled"
end

local function topBuiltin(gid)
    local def = NS.BuiltIns.groups[gid]
    return def ~= nil and def.parent == nil
end

-- A surface's portable fields, every string in each value sanitized, nested ones included
-- (cleanValue); a field that does not travel, or whose value cannot be stored, is left out and
-- counted. The seam checks each value again, against its row, when Library.Import writes it.
local function surfaceFields(kind, fields, res)
    local out = {}
    for path, value in pairs(type(fields) == "table" and fields or {}) do
        local v = nil
        if SH.Portable(kind, path) then v = cleanValue(value, 1) end
        if v ~= nil then out[path] = v else res.ignored = res.ignored + 1 end
    end
    return out
end

local function surfaceEntry(spec, id, s, res)
    if type(s) ~= "table" then return nil, "damaged" end
    local name, why = cleanName(s.name)
    if not name then return nil, why end
    local groups = keepRefs(s.groups, function(gid) return res.known[gid] == "group" or topBuiltin(gid) end, res)
    return { id = id, name = name, enabled = s.enabled ~= false, groups = groups,
        fields = surfaceFields(spec.kind, s.fields, res) }
end

local ENTRY = { callout = calloutEntry, group = groupEntry, pad = surfaceEntry, dial = surfaceEntry }

local function refuse(res, kind, id, entry, why)
    local name = type(entry) == "table" and NS.Bake.CleanText(entry.name) or nil
    res.refused[#res.refused + 1] = { kind = kind, id = tostring(id), name = name or tostring(id), reason = why }
end

local function checkSection(spec, set, res)
    for _, id in ipairs(sortedIds(set)) do
        local e, why
        if tostring(id):match("^" .. spec.prefix .. "%d+$") then
            e, why = ENTRY[spec.kind](spec, id, set[id], res)
        else
            why = "badId"
        end
        if e then
            local list = res[spec.key]
            list[#list + 1] = e
            res.known[id] = spec.kind
        else
            refuse(res, spec.kind, id, set[id], why)
        end
    end
end

-- Why a payload's header is refused, or nil: not ours, an unreadable version, or a newer one.
local function headerReason(payload)
    if type(payload) ~= "table" or payload.addon ~= "QuickComms" or payload.kind ~= "bundle" then
        return "notOurs"
    end
    local v = payload.v
    if type(v) ~= "number" or v < 1 or v ~= math.floor(v) then return "damaged" end
    if v > SH.VERSION then return "newer" end
    return nil
end

-- An older payload lifted to SH.VERSION, or nil when a step is missing or fails.
local function migrate(payload)
    local v = payload.v
    while v < SH.VERSION do
        local step = MIGRATIONS[v]
        if not step then return nil end
        payload = step(payload)
        if type(payload) ~= "table" then return nil end
        v = v + 1
    end
    return payload
end

-- The members a payload holds, or nil when a section is not a table.
local function memberCount(payload)
    local n = 0
    for _, spec in ipairs(SH.KINDS) do
        local set = payload[spec.key]
        if set ~= nil and type(set) ~= "table" then return nil end
        for _ in pairs(set or {}) do n = n + 1 end
    end
    return n
end

--- Check a decoded payload (spec §15 steps 2 to 4). On success `ok` is true and the four lists hold
--- what Library.Import will make; `refused` lists { kind, id, name, reason } for each member left out,
--- `dropped` counts references to members the string does not carry, `ignored` the fields that do not
--- travel. On a refusal of the whole string `ok` is false and `reason` says why.
--- @return table result
function SH.Validate(payload)
    local res = newResult()
    res.reason = headerReason(payload)
    if res.reason then return res end
    payload = migrate(payload)
    local n = payload and memberCount(payload)
    if not n then
        res.reason = "damaged"
        return res
    end
    if n > SH.MAX_MEMBERS then
        res.reason = "tooLarge"
        return res
    end
    for _, spec in ipairs(SH.KINDS) do checkSection(spec, payload[spec.key] or {}, res) end
    res.known = nil
    res.ok = true
    return res
end

--- Decode and check a pasted string: SH.Validate's result, or a refusal with Decode's reason. It
--- fails closed: a hand-made payload that still raises inside the checks is "damaged", never an error
--- in the player's Accept click.
function SH.Check(text)
    local payload, why = SH.Decode(text)
    if payload then
        local ok, res = pcall(SH.Validate, payload)
        if ok then return res end
        why = "damaged"
    end
    local res = newResult()
    res.known = nil
    res.reason = why
    return res
end

-- ── the report (spec §15 step 5) ────────────────────────────────────────────────────────────

-- Why a whole string, or an export, was refused.
SH.REASON_TEXT = {
    empty = L["Paste a Quick Comms string first."],
    notOurs = L["That is not a Quick Comms string: one starts with !QC1!."],
    damaged = L["That string is damaged or cut short. Copy all of it again."],
    newer = L["That string was made by a newer Quick Comms. Update the addon, then import it."],
    tooLarge = L["That string is too large to import."],
    unavailable = L["Sharing is unavailable: LibDeflate or LibSerialize did not load."],
    nothing = L["Tick at least one callout, group, pad or dial to export."],
    inCombat = L["Export and import are not available in combat."],
}

-- Why one member was left out.
SH.MEMBER_REASON = {
    startsWithSlash = L["its text starts with /"],
    tooLong = L["its text is longer than 255 bytes"],
    badText = L["its text is not text"],
    badName = L["its name is not 1 to 32 characters"],
    badChannel = L["its channel is not one Quick Comms sends on"],
    badIcon = L["its icon is not a texture id or a texture path"],
    badWhen = L["its When holds a condition Quick Comms does not know"],
    badId = L["its id is malformed"],
    damaged = L["it is damaged"],
}

local KIND_NAME = { callout = L["callout"], group = L["group"], pad = L["Comms Pad"], dial = L["Comms Dial"] }

local COUNTS = {
    { key = "callouts", one = L["1 callout"], many = L["%d callouts"] },
    { key = "groups", one = L["1 group"], many = L["%d groups"] },
    { key = "pads", one = L["1 pad"], many = L["%d pads"] },
    { key = "dials", one = L["1 dial"], many = L["%d dials"] },
}

-- A count, a list (its entries) or a set (its keys).
local function countOf(v)
    if type(v) == "number" then return v end
    local n = 0
    for _ in pairs(type(v) == "table" and v or {}) do n = n + 1 end
    return n
end

--- "3 callouts, 1 group": the members in a result, a payload or Library.Import's tally; "" for none.
function SH.CountText(t)
    local parts = {}
    for _, c in ipairs(COUNTS) do
        local n = countOf(type(t) == "table" and t[c.key])
        if n == 1 then parts[#parts + 1] = c.one elseif n > 1 then parts[#parts + 1] = c.many:format(n) end
    end
    return table.concat(parts, ", ")
end

local function plural(n, one, many)
    if n == 1 then return one end
    return many:format(n)
end

--- The import report: what will arrive, each member refused with its reason, then the references and
--- the settings left out. A refused string is one line saying why.
--- @return string[]
function SH.ReportLines(res)
    if type(res) ~= "table" or not res.ok then
        return { SH.REASON_TEXT[type(res) == "table" and res.reason or "empty"] or tostring(res and res.reason) }
    end
    local counts = SH.CountText(res)
    local out = { counts ~= "" and L["Ready to import: %s."]:format(counts) or L["Nothing in this string can be imported."] }
    for _, r in ipairs(res.refused) do
        out[#out + 1] = L["Left out the %s '%s': %s."]:format(KIND_NAME[r.kind] or r.kind, r.name,
            SH.MEMBER_REASON[r.reason] or tostring(r.reason))
    end
    if res.dropped > 0 then
        out[#out + 1] = plural(res.dropped, L["1 reference to something the string does not carry was left out."],
            L["%d references to things the string does not carry were left out."])
    end
    if res.ignored > 0 then
        out[#out + 1] = plural(res.ignored, L["1 setting this version cannot take was left out."],
            L["%d settings this version cannot take were left out."])
    end
    return out
end
```

In `QuickComms.toc`, replace
```
# Conventional: the registry writer (architecture-§5); Prepare is called from the entry after migrations
modules\Library.lua
```
with
```
# Conventional: the registry writer (architecture-§5); Prepare is called from the entry after migrations
modules\Library.lua
# Conventional: the share string's codec and checks (pure), and from Task 5 its edge; reads Bake, Library and the seam at run time
modules\Share.lua
```

Append to `locales/enUS.lua`:
```lua
-- modules/Share.lua: the share string's report and refusals (phase 5)
L["Paste a Quick Comms string first."] = "Paste a Quick Comms string first."
L["That is not a Quick Comms string: one starts with !QC1!."] = "That is not a Quick Comms string: one starts with !QC1!."
L["That string is damaged or cut short. Copy all of it again."] = "That string is damaged or cut short. Copy all of it again."
L["That string was made by a newer Quick Comms. Update the addon, then import it."] = "That string was made by a newer Quick Comms. Update the addon, then import it."
L["That string is too large to import."] = "That string is too large to import."
L["Sharing is unavailable: LibDeflate or LibSerialize did not load."] = "Sharing is unavailable: LibDeflate or LibSerialize did not load."
L["Tick at least one callout, group, pad or dial to export."] = "Tick at least one callout, group, pad or dial to export."
L["Export and import are not available in combat."] = "Export and import are not available in combat."
L["its text starts with /"] = "its text starts with /"
L["its text is longer than 255 bytes"] = "its text is longer than 255 bytes"
L["its text is not text"] = "its text is not text"
L["its name is not 1 to 32 characters"] = "its name is not 1 to 32 characters"
L["its channel is not one Quick Comms sends on"] = "its channel is not one Quick Comms sends on"
L["its icon is not a texture id or a texture path"] = "its icon is not a texture id or a texture path"
L["its When holds a condition Quick Comms does not know"] = "its When holds a condition Quick Comms does not know"
L["its id is malformed"] = "its id is malformed"
L["it is damaged"] = "it is damaged"
L["callout"] = "callout"
L["group"] = "group"
L["1 callout"] = "1 callout"
L["%d callouts"] = "%d callouts"
L["1 group"] = "1 group"
L["%d groups"] = "%d groups"
L["1 pad"] = "1 pad"
L["%d pads"] = "%d pads"
L["1 dial"] = "1 dial"
L["%d dials"] = "%d dials"
L["Ready to import: %s."] = "Ready to import: %s."
L["Nothing in this string can be imported."] = "Nothing in this string can be imported."
L["Left out the %s '%s': %s."] = "Left out the %s '%s': %s."
L["1 reference to something the string does not carry was left out."] = "1 reference to something the string does not carry was left out."
L["%d references to things the string does not carry were left out."] = "%d references to things the string does not carry were left out."
L["1 setting this version cannot take was left out."] = "1 setting this version cannot take was left out."
L["%d settings this version cannot take were left out."] = "%d settings this version cannot take were left out."
```

- [ ] **Step 5: Run the gate and the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: PASS (fourteen `share:` cases and the bake case), 0 / 0, `0 warnings`.

- [ ] **Step 6: Commit**

```bash
git add modules/Share.lua modules/Bake.lua QuickComms.toc tests/run.lua tests/test_share.lua tests/test_bake.lua locales/enUS.lua
rm modules/Share.lua tests/test_share.lua && git checkout -- modules/Share.lua tests/test_share.lua
git checkout -- modules/Bake.lua QuickComms.toc tests/run.lua tests/test_bake.lua locales/enUS.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Share: the !QC1! codec, the version gate and the schema checks, every text field sanitized"
```

---
### Task 4: `Library.Import`, the registry writer for what a string brings

Spec §15 step 6 and §18: apply a checked result through the registry writer. Every member gets a fresh id; a group's callouts and a surface's groups point at the new copies (a built-in set stays itself); a pad's or a dial's portable fields go through the seam, which refuses what it would refuse a player; a key or a position is never written, even when a hand-made result carries one. One act. `CreateSurface`'s body becomes `newSurface(kind, name, groups)`, which both use; every shipped built-in is marked seen, so the next Prepare adds nothing an imported surface left out.

**Files:**
- Modify: `modules/Library.lua` (the header's "(phase 5) import" sentence, `Lib.CreateSurface`, a new section at the end of the file)
- Test: `tests/test_library.lua`

**Interfaces:**
- Consumes: Task 3's result shape and `NS.Share.Portable(kind, path)`; `Lib.CreateCallout`, `Lib.CreateGroup`, `Lib.Batch`, `NS.SchemaRuntime.Set(path, value, id)`, `NS.SchemaRuntime.BulkRun(act, scope, fn)`.
- Produces: `Lib.Import(res) -> tally { callouts, groups, pads, dials, ignored }, map { [old id] = new id }`, or `nil, "badImport"` for a result that is not `ok`. `Lib.CreateSurface(kind, name)` unchanged in behavior.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_library.lua`:
```lua
-- ── import (phase 5) ────────────────────────────────────────────────────────────────────────

-- A share result for two callouts, a group holding both, a pad and a dial listing the group and a
-- built-in set, checked by modules/Share.lua as an import is.
local function shared(NS)
    return NS.Share.Validate({ v = 1, addon = "QuickComms", kind = "bundle",
        callouts = { c1 = { name = "Kick", text = "Kick on me", channel = "party" },
            c2 = { name = "Lust", text = "Lust now", channel = "smartGroup", icon = 136012 } },
        groups = { g1 = { name = "Mine", callouts = { "c2", "c1" }, when = { content = { mythicPlus = true } } } },
        pads = { p1 = { name = "Their pad", groups = { "g1", "bi.mplus" },
            fields = { ["pad.layout.columns"] = 6, ["pad.layout.spacing"] = 999 } } },
        dials = { d2 = { name = "Their dial", groups = { "g1" }, fields = { ["dial.mode"] = "flat" } } },
    })
end

test("library: [phase 5] Import makes every member under a fresh id, its references pointing at the copies", function()
    local NS, Lib, p = boot()
    local tally, map = Lib.Import(shared(NS))
    assertEqual(tally.callouts .. tally.groups .. tally.pads .. tally.dials, "2111")
    local gid = map.g1
    assertTrue(gid ~= "g1" and p.groups[gid] ~= nil)
    assertEqual(p.groups[gid].callouts[1], map.c2, "the group's order is kept, pointing at the new copies")
    assertEqual(p.groups[gid].callouts[2], map.c1)
    assertTrue(p.groups[gid].when.content.mythicPlus)
    assertEqual(p.callouts[map.c2].icon, 136012)
    local pad = p.pads[map.p1]
    assertEqual(table.concat(pad.groups, ","), gid .. ",bi.mplus")
    assertEqual(pad.layout.columns, 6)
    assertEqual(pad.layout.spacing, 20, "the seam clamps what it would clamp for a player")
    assertEqual(p.padOrder[#p.padOrder], map.p1, "at the end of the pad order")
    assertEqual(p.dials[map.d2].mode, "flat")
end)

test("library: [review 3] importing the same string twice makes two copies; nothing that existed changes", function()
    local NS, Lib, p = boot()
    local mine = Lib.CreateCallout({ name = "Kick", text = "Mine", channel = "say" })
    local _, first = Lib.Import(shared(NS))
    local _, second = Lib.Import(shared(NS))
    assertTrue(first.c1 ~= second.c1 and first.c1 ~= mine and second.c1 ~= mine)
    assertEqual(p.callouts[mine].text, "Mine")
    assertEqual(p.callouts[first.c1].name, "Kick", "a name may repeat")
    assertEqual(p.callouts[second.c1].name, "Kick")
    assertEqual(p.groups[second.g1].callouts[1], second.c2, "each copy points at its own callouts")
end)

test("library: [review 4] an imported pad and dial arrive unbound: no key, the default place, no built-in re-added", function()
    local NS, Lib, p = boot()
    local res = shared(NS)
    -- a hand-made result that slipped a key and a position past the checks is still refused them
    res.dials[1].fields["dial.key"] = "G"
    res.pads[1].fields["pad.point"] = { "TOPLEFT", "TOPLEFT", 10, -10 }
    local tally, map = Lib.Import(res)
    local dial, pad = p.dials[map.d2], p.pads[map.p1]
    -- red under: drop the Share.Portable check from importSurface (the seam itself takes a key)
    assertTrue(dial.key == nil or dial.key == false, "no key: " .. tostring(dial.key))
    assertTrue(pad.point == nil or pad.point == false, "the default place")
    assertEqual(tally.ignored, 2)
    Lib.Prepare()
    assertEqual(#pad.groups, 2, "every built-in was already marked seen")
end)

test("library: [phase 5] Import is one act: one LIBRARY_CHANGED; a refused result imports nothing", function()
    local NS, Lib, _, sent = boot()
    local res = shared(NS)
    for i = #sent, 1, -1 do sent[i] = nil end
    Lib.Import(res)
    local n = 0
    for _, s in ipairs(sent) do if s[1] == NS.MSG.LIBRARY_CHANGED then n = n + 1 end end
    -- red under: drop Lib.Batch from Lib.Import (one announce per member and per field)
    assertEqual(n, 1)
    assertEqual(sent[#sent][2], "callout,dial,group,pad")
    assertNil(Lib.Import({ ok = false, reason = "newer" }))
    assertNil(Lib.Import(nil))
end)
```

- [ ] **Step 2: Run them to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in the four new `test_library` cases (`Lib.Import` is nil).

- [ ] **Step 3: `newSurface`**

In `modules/Library.lua`, replace
```lua
-- Panel pages, slash verbs and (phase 5) import all call it. Built-ins are shipped data (NS.BuiltIns); the profile holds only their overlay.
```
with
```lua
-- Panel pages, slash verbs and the share import (Import, spec §15) all call it. Built-ins are shipped
-- data (NS.BuiltIns); the profile holds only their overlay.
```
and replace
```lua
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
```
with
```lua
-- A new pad or dial: its kind's defaults, `name` and a copy of `groups`, with every shipped built-in
-- marked seen (so Prepare never appends one the list leaves out), at the end of its kind's order.
local function newSurface(kind, name, groups)
    local p = P()
    local set = kind == "pad" and p.pads or p.dials
    local id = Lib.NewId(kind == "pad" and "p" or "d")
    local s = copyTable(SURFACE_DEFAULTS[kind])
    s.name, s.enabled, s.groups, s.seenBuiltins = name, true, copyTable(groups), {}
    for _, gid in ipairs(NS.BuiltIns.order) do s.seenBuiltins[gid] = true end
    set[id] = s
    local order = kind == "pad" and p.padOrder or p.dialOrder
    order[#order + 1] = id
    announce(kind, id)
    return id
end

--- Create a pad or dial holding every built-in group (in BuiltIns.order).
function Lib.CreateSurface(kind, name)
    if kind ~= "pad" and kind ~= "dial" then return nil, "badKind" end
    return newSurface(kind, name, NS.BuiltIns.order)
end
```

- [ ] **Step 4: `Lib.Import`**

Append to `modules/Library.lua` (after `Lib.Prepare`, so `exists` and `newSurface` are in scope):
```lua
-- ── import (spec §15, §18) ──────────────────────────────────────────────────────────────────

-- A surface's group list from a share result, pointing at the fresh copies: a built-in set stays
-- itself, an imported group becomes its new id, anything else (gone since the check) is left out.
local function remapGroups(list, map)
    local out = {}
    for _, gid in ipairs(list) do
        local id = isBuiltin(gid) and gid or map[gid]
        if id and exists(id) and not indexOf(out, id) then out[#out + 1] = id end
    end
    return out
end

-- One pad or dial: a new member with no key and no position, then each field that travels
-- (Share.Portable, checked again here, so no key or position is ever written) through the seam, which
-- refuses what it would refuse a player. A field left out either way is counted as ignored.
local function importSurface(kind, e, map, tally)
    local id = newSurface(kind, e.name, remapGroups(e.groups, map))
    local paths = {}
    for path in pairs(e.fields) do paths[#paths + 1] = path end
    table.sort(paths)
    for _, path in ipairs(paths) do
        local ok = NS.Share.Portable(kind, path) and NS.SchemaRuntime.Set(path, e.fields[path], id)
        if not ok then tally.ignored = tally.ignored + 1 end
    end
    if e.enabled == false then NS.SchemaRuntime.Set(kind .. ".enabled", false, id) end
    map[e.id] = id
    tally[kind .. "s"] = tally[kind .. "s"] + 1
end

local function importMembers(res, map, tally)
    for _, e in ipairs(res.callouts) do
        local id = Lib.CreateCallout(e.fields)
        if id then map[e.id], tally.callouts = id, tally.callouts + 1 end
    end
    for _, e in ipairs(res.groups) do
        local ids = {}
        for _, cid in ipairs(e.callouts) do ids[#ids + 1] = map[cid] end
        local f = e.fields
        local id = Lib.CreateGroup({ name = f.name, icon = f.icon, when = f.when, openInto = f.openInto,
            enabled = f.enabled, callouts = ids })
        if id then map[e.id], tally.groups = id, tally.groups + 1 end
    end
    for _, e in ipairs(res.pads) do importSurface("pad", e, map, tally) end
    for _, e in ipairs(res.dials) do importSurface("dial", e, map, tally) end
end

--- Apply a checked share result (modules/Share.lua Validate): every member under a fresh id (spec
--- §18: ids are always re-mapped, names may repeat), each group's callouts and each surface's groups
--- pointing at the new copies, built-in sets kept by id. A pad or a dial arrives unbound (spec §15): no
--- key, at the default place, at the end of its kind's order. One act: one LIBRARY_CHANGED, so the
--- surfaces rebuild once, and one `[Set] import share` line for every field it wrote.
--- @return table|nil tally { callouts, groups, pads, dials, ignored }, table|string map (old id ->
--- new id) or the reason nothing was imported
function Lib.Import(res)
    if type(res) ~= "table" or res.ok ~= true then return nil, "badImport" end
    local map, tally = {}, { callouts = 0, groups = 0, pads = 0, dials = 0, ignored = 0 }
    Lib.Batch(function()
        NS.SchemaRuntime.BulkRun("import", "share", function() importMembers(res, map, tally) end)
    end)
    NS.Debug(TAG, "import %s callouts, %s groups, %s pads, %s dials (%s fields ignored)", tally.callouts,
        tally.groups, tally.pads, tally.dials, tally.ignored)
    return tally, map
end
```

- [ ] **Step 5: Run the gate and the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: PASS, 0 / 0, `0 warnings`. Measure `modules/Library.lua` after the rebase (`wc -l`): about 990 lines on a scratch export of `55194f6` with Tasks 1 to 4, just under layout-§1's 1,000-line band; Task 8 takes it over 1,000 (Task 13, Step 4, says what that means).

- [ ] **Step 6: Commit**

```bash
git add modules/Library.lua tests/test_library.lua
git checkout -- modules/Library.lua tests/test_library.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Library: Import, every member under a fresh id, surfaces unbound, one act"
```

---
### Task 5: The Share page's Export and Import tabs, and the edge

The player's half of spec §15: tick members on the Export tab (what they need comes along), Export, and the string opens selected in the LibKa0s copy window; paste a string on the Import tab, Accept checks it and shows the report, Import adds it. Both acts are refused in combat. The ticks and the checked string are session state, cleared by a profile switch.

**Files:**
- Modify: `modules/Share.lua` (the header's first paragraph; the edge appended), `core/WidgetsSetup.lua` (the header, `NS.MakeCopyWindow`), `core/State.lua`, `settings/Editors.lua` (`onProfileChanged`), `tests/page_helpers.lua`, `locales/enUS.lua`
- Rewrite: `settings/Share.lua`
- Test: `tests/test_page_share.lua`

**Interfaces:**
- Consumes: Task 3's `Share.Encode`, `Share.Check`, `Share.Portable`, `Share.CountText`, `Share.ReportLines`, `Share.REASON_TEXT`, `Share.KINDS`; Task 4's `Library.Import`; LibKa0s-Widgets `CopyWindow(d)` (`:Show(text)`); `NS.Compat.InCombat()`; `NS.Library.MemberIds(kind)`.
- Produces:
  - `NS.MakeCopyWindow(d) -> handle|nil` (`core/WidgetsSetup.lua`; the addon's folder name filled in).
  - `NS.State.share = { pick = { callout, group, pad, dial }, import = res|nil }`.
  - `Share.FieldsOf(kind, id) -> { [path] = value }`, `Share.Collect(pick) -> payload|nil, n`, `Share.Window() -> handle|nil` (built once; a test may replace it), `Share.Export(pick) -> string|nil, reason`, `Share.Apply(res) -> tally|nil, reason`.
  - `Settings.Share.Pick(kind, id, on)`, `.Picked(kind, id)`, `.ClearPicks()`, `.ExportSummary()`, `.Export()`, `.Check(text)`, `.ReportText()`, `.Import()`, `.ClearImport()`; the existing `.Customize`, `.ChooseCallouts`, `.RestoreAll` unchanged. The page's tabs are keyed by their localized labels, as every page's are (`L["Export"]`, `L["Import"]`, `L["Built-in"]`).

- [ ] **Step 1: Write the failing tests**

In `tests/test_page_share.lua`, replace the header comment's first three lines
```lua
-- tests/test_page_share.lua — settings/Share.lua (spec §13.1, §12.2): the Built-in tab. Each shipped set
-- is one line: Enabled, Customize, Choose callouts. Defaults turns every set back on. Driven headlessly
-- through tests/page_helpers.lua.
```
with
```lua
-- tests/test_page_share.lua — settings/Share.lua (spec §13.1, §15, §12.2): the Export and Import tabs
-- (phase 5) and the Built-in tab. Each shipped set is one line: Enabled, Customize, Choose callouts.
-- Defaults turns every set back on. Driven headlessly through tests/page_helpers.lua.
```
replace
```lua
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
```
with
```lua
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
```
then change every `P.redraw("share")` in the file (four, in the four existing cases) to `P.tab("share", "Built-in")`: the page now opens on Export, so the existing cases name the tab they test. Append:
```lua
-- ── Export and Import (phase 5) ─────────────────────────────────────────────────────────────

-- A group of two callouts of the player's own, on no surface.
local function mine(NS)
    local Lib = NS.Library
    local a = Lib.CreateCallout({ name = "Kick", text = "Kick on me {rt8}", channel = "party" })
    local b = Lib.CreateCallout({ name = "Lust", text = "Lust now", channel = "smartGroup" })
    return Lib.CreateGroup({ name = "My keys", callouts = { a, b } }), a, b
end

-- The copy window, recorded: the export's string lands in `shown.text`.
local function spyWindow(NS)
    local shown = {}
    NS.Share.Window = function() return { Show = function(_, text) shown.text = text end } end
    return shown
end

test("share page: [phase 5] Export ticks a group; its callouts come along, and the string opens in the copy window", function()
    local NS, _, P = open()
    local gid = mine(NS)
    local shown = spyWindow(NS)
    local w = P.tab("share", "Export")
    assertTrue(P.find(w, "Heading", "Groups") ~= nil)
    P.find(w, "CheckBox", "My keys"):__fire("OnValueChanged", true)
    assertTrue(P.hasText(w, "The string will hold 2 callouts, 1 group."), "the summary follows the tick in place")
    P.find(w, "Button", "Export"):__fire("OnClick")
    assertEqual(shown.text:sub(1, 5), "!QC1!")
    local payload = NS.Share.Decode(shown.text)
    assertEqual(payload.groups[gid].name, "My keys")
    assertEqual(#payload.groups[gid].callouts, 2)
end)

test("share page: [phase 5] Export with nothing ticked says so and opens nothing", function()
    local NS, m, P = open()
    local shown = spyWindow(NS)
    local w = P.tab("share", "Export")
    m.prints = {}
    P.find(w, "Button", "Export"):__fire("OnClick")
    assertNil(shown.text)
    assertTrue(table.concat(m.prints, "\n"):find("Tick at least one callout", 1, true) ~= nil)
end)

test("share page: [phase 5] Import checks a pasted string, reports it, then adds it as new members", function()
    local NS, m, P = open()
    local gid = mine(NS)
    local text = NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } }))
    local before = 0
    for _ in pairs(NS.db.profile.groups) do before = before + 1 end
    local w = P.tab("share", "Import")
    P.find(w, "MultiLineEditBox", "Share string"):__fire("OnEnterPressed", "\n" .. text .. "\n")
    assertTrue(P.hasText(w, "Ready to import: 2 callouts, 1 group."), "the report, in place")
    m.prints = {}
    P.find(w, "Button", "Import"):__fire("OnClick")
    local after = 0
    for _ in pairs(NS.db.profile.groups) do after = after + 1 end
    assertEqual(after, before + 1, "a copy, beside the original")
    assertTrue(table.concat(m.prints, "\n"):find("Imported 2 callouts, 1 group.", 1, true) ~= nil)
    assertNil(NS.State.share.import, "the checked string is spent")
end)

test("share page: [phase 5] an imported dial says it has no key yet", function()
    local NS, m, P = open()
    NS.SchemaRuntime.Set("dial.key", "G", "d2")
    local text = NS.Share.Encode(NS.Share.Collect({ dial = { d2 = true } }))
    P.tab("share", "Import")
    NS.addon.Settings.Share.Check(text)
    m.prints = {}
    local tally = NS.addon.Settings.Share.Import()
    assertEqual(tally.dials, 1)
    assertTrue(table.concat(m.prints, "\n"):find("An imported dial has no key yet", 1, true) ~= nil)
    assertEqual(NS.db.profile.dials.d2.key, "G", "the original keeps its key")
end)

test("share page: [phase 5] an imported group no shared pad or dial lists says where to add it", function()
    local NS, m, P = open()
    local gid = mine(NS)
    local text = NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } }))
    P.tab("share", "Import")
    NS.addon.Settings.Share.Check(text)
    m.prints = {}
    assertTrue(NS.addon.Settings.Share.Import() ~= nil)
    -- red under: drop the looseGroups line from SH.Import in settings/Share.lua
    assertTrue(table.concat(m.prints, "\n"):find("is on no pad or dial yet", 1, true) ~= nil)
    m.prints = {}
    NS.addon.Settings.Share.Check(NS.Share.Encode(NS.Share.Collect({ dial = { d2 = true } })))
    NS.addon.Settings.Share.Import()
    assertTrue(table.concat(m.prints, "\n"):find("is on no pad or dial yet", 1, true) == nil, "a dial with no group of its own")
end)

test("share page: [phase 5] export and import are refused in combat; nothing is made or added", function()
    local NS, m = open()
    local gid = mine(NS)
    local SHP = NS.addon.Settings.Share
    SHP.Pick("group", gid, true)
    SHP.Check(NS.Share.Encode(NS.Share.Collect({ group = { [gid] = true } })))
    local shown = spyWindow(NS)
    m.inCombat = true
    m.prints = {}
    assertNil(SHP.Export())
    assertNil(SHP.Import())
    assertNil(shown.text)
    assertTrue(table.concat(m.prints, "\n"):find("Export and import are not available in combat.", 1, true) ~= nil)
    assertTrue(NS.State.share.import ~= nil, "the checked string waits for combat to end")
    m.inCombat = false
    assertTrue(SHP.Import() ~= nil)
end)

test("share page: [phase 5] a profile switch forgets the ticks and the checked string", function()
    local NS = open()
    local gid = mine(NS)
    local SHP = NS.addon.Settings.Share
    SHP.Pick("group", gid, true)
    SHP.Check("!QC1!nope")
    NS.addon.db:SetProfile("Other")
    assertFalse(SHP.Picked("group", gid))
    assertNil(NS.State.share.import)
end)

test("share page: [phase 5] the export window is the LibKa0s copy window, built once and named for the addon", function()
    local NS, m = open()
    local win = NS.Share.Window()
    assertTrue(win ~= nil and win == NS.Share.Window(), "built once")
    local f = win:Show("!QC1!abc")
    assertTrue(f:IsShown())
    assertEqual(m.__named.QuickCommsShareWindow, f)
end)
```

- [ ] **Step 2: Run them to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: the four existing `share page:` cases still PASS (the Built-in tab is the only one so far, and `P.tab` draws it); the eight `[phase 5]` cases FAIL (`NS.Share.Window` / `Collect` are nil, no Export tab).

- [ ] **Step 3: The copy window seam and the session state**

In `core/WidgetsSetup.lua`, replace
```lua
local _, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDragHandle from LibKa0s-Widgets-1.0: the Comms Pad's drag strip.
```
with
```lua
local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDragHandle and NS.MakeCopyWindow from LibKa0s-Widgets-1.0: the
-- Comms Pad's drag strip and the Share page's export window.
```
replace
```lua
-- `IconGrid:ApplyLock`). DEGRADED (the library absent): NS.MakeDragHandle answers nil and a pad
-- stays where its saved point puts it.
```
with
```lua
-- `IconGrid:ApplyLock`). DEGRADED (the library absent): NS.MakeDragHandle answers nil and a pad
-- stays where its saved point puts it; NS.MakeCopyWindow answers nil too (the settings panel, and
-- with it the Share page, is unavailable then anyway).
```
and append:
```lua
--- A read-only copy window (the LibKa0s CopyWindow: text in, Ctrl+C out, Escape closes), or nil when
--- the library is absent. Its frame is built on the first Show. The addon's folder name goes in so
--- the window's close control finds the collection's art.
--- @param d table CopyWindow descriptor: name, scrollName, title, width, height
--- @return table|nil the window's handle: :Show(text), :Hide(), :GetText()
function NS.MakeCopyWindow(d)
    if not (W and W.CopyWindow) then return nil end
    d.addonName = addonName
    return W.CopyWindow(d)
end
```

Append to `core/State.lua`:
```lua
-- The Share page (settings/Share.lua, spec §15): the members ticked for export, { callout, group,
-- pad, dial } each { [id] = true }, and the last checked import string's result (modules/Share.lua
-- Check), or nil. Session-only; a profile switch clears both (settings/Editors.lua).
State.share = { pick = { callout = {}, group = {}, pad = {}, dial = {} }, import = nil }
```

In `settings/Editors.lua`, replace
```lua
local function onProfileChanged()
    for kind in pairs(State.editing) do State.editing[kind] = nil end
    for gid in pairs(State.whenOpen or {}) do State.whenOpen[gid] = nil end
    Ed.RequestRefresh()
end
```
with
```lua
local function onProfileChanged()
    for kind in pairs(State.editing) do State.editing[kind] = nil end
    for gid in pairs(State.whenOpen or {}) do State.whenOpen[gid] = nil end
    -- The Share page's ticks and checked string name the old profile's ids.
    State.share.pick = { callout = {}, group = {}, pad = {}, dial = {} }
    State.share.import = nil
    Ed.RequestRefresh()
end
```

- [ ] **Step 4: The edge**

In `modules/Share.lua`, replace
```lua
-- modules/Share.lua — export and import strings (design spec §15). The codec and the checks are
-- PURE: plain tables and strings in and out, no frame and no client read; the edge (Export, Check,
-- Apply and the copy window) joins below them in Task 5 of the phase 5 plan.
```
with
```lua
-- modules/Share.lua — export and import strings (design spec §15). The codec and the checks are
-- PURE: plain tables and strings in and out, no frame and no client read. The edge is at the end:
-- Collect and Export (the picked members and what they need, encoded and shown in the LibKa0s copy
-- window) and Apply (a checked string, through Library.Import), both refused in combat.
```
and append:
```lua
-- ── the edge: export and apply ──────────────────────────────────────────────────────────────

local TAG = "Share"

-- A plain copy of a stored value for a payload. The profile's own data, so no check is needed here:
-- what comes back in a string is checked by cleanValue above.
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- The picked ids and what they need: a pad's or a dial's user groups, then every picked group's
-- callouts (spec §15: a group references its callouts, a surface its groups). Built-in sets travel
-- by id only.
local function bringGroups(want, surfaces, ids, groups)
    for sid in pairs(ids) do
        local s = surfaces[sid]
        for _, gid in ipairs(s and s.groups or {}) do
            if groups[gid] then want.group[gid] = true end
        end
    end
end

local function closure(pick, p)
    local want = { callout = {}, group = {}, pad = {}, dial = {} }
    for kind, ids in pairs(type(pick) == "table" and pick or {}) do
        if want[kind] then
            for id, on in pairs(ids) do want[kind][id] = on and true or nil end
        end
    end
    bringGroups(want, p.pads, want.pad, p.groups)
    bringGroups(want, p.dials, want.dial, p.groups)
    for gid in pairs(want.group) do
        local g = p.groups[gid]
        for _, cid in ipairs(g and g.callouts or {}) do want.callout[cid] = true end
    end
    return want
end

--- A pad's or a dial's portable fields (SH.Portable), read through the seam: what its payload's
--- `fields` carries.
function SH.FieldsOf(kind, id)
    local out = {}
    for _, row in ipairs(NS.addon.Settings.Schema) do
        if row.instance == kind and SH.Portable(kind, row.path) then
            local v = NS.SchemaRuntime.Get(row.path, id)
            if v ~= nil then out[row.path] = copy(v) end
        end
    end
    return out
end

local function exportMember(kind, id, m)
    if kind == "callout" then
        return { name = m.name, text = m.text, channel = m.channel, icon = m.icon or nil }
    end
    if kind == "group" then
        return { name = m.name, icon = m.icon or nil, callouts = copy(m.callouts), when = copy(m.when),
            openInto = m.openInto == true, enabled = m.enabled ~= false }
    end
    return { name = m.name, enabled = m.enabled ~= false, groups = copy(m.groups), fields = SH.FieldsOf(kind, id) }
end

--- The payload for the picked members ({ callout = { [id] = true }, group = …, pad = …, dial = … })
--- and what they need, or nil when nothing is picked.
--- @return table|nil payload, number members
function SH.Collect(pick)
    local p = NS.db.profile
    local want = closure(pick, p)
    local payload, n = { v = SH.VERSION, addon = "QuickComms", kind = "bundle" }, 0
    for _, spec in ipairs(SH.KINDS) do
        local set, out = p[spec.key], {}
        for id in pairs(want[spec.kind]) do
            if set[id] then
                out[id] = exportMember(spec.kind, id, set[id])
                n = n + 1
            end
        end
        payload[spec.key] = out
    end
    if n == 0 then return nil, 0 end
    return payload, n
end

--- The export window: the LibKa0s copy window (core/WidgetsSetup.lua), built on first use; nil
--- without the library.
function SH.Window()
    SH.window = SH.window or NS.MakeCopyWindow({ name = "QuickCommsShareWindow", scrollName = "QuickCommsShareScroll",
        title = L["Quick Comms: share string"], width = 560, height = 300 })
    return SH.window
end

--- Make the string for the picked members and show it, selected, in the copy window (spec §15).
--- Refused in combat.
--- @return string|nil the string, string|nil why there is none
function SH.Export(pick)
    if NS.Compat.InCombat() then return nil, "inCombat" end
    local payload = SH.Collect(pick)
    if not payload then return nil, "nothing" end
    local text, why = SH.Encode(payload)
    if not text then return nil, why end
    NS.Debug(TAG, "export %s: %d characters", SH.CountText(payload), #text)
    local win = SH.Window()
    if win then win:Show(text) end
    return text
end

--- Import a checked result through Library.Import (spec §15 step 6). Refused in combat.
--- @return table|nil Library.Import's tally, string|nil why nothing was imported
function SH.Apply(res)
    if NS.Compat.InCombat() then return nil, "inCombat" end
    if type(res) ~= "table" or not res.ok then return nil, type(res) == "table" and res.reason or "empty" end
    return NS.Library.Import(res)
end
```

- [ ] **Step 5: The page**

Replace the whole of `settings/Share.lua` with:
```lua
local _, NS = ...
-- settings/Share.lua — the Share page (design spec §13.1, §15, §12.2): three tabs.
--
--     strip     [ Export ][ Import ][ Built-in ]
--     Export    what travels; a checkbox per callout, group, Comms Pad and Comms Dial, under a heading
--               per kind; what the string will hold; Export (the string opens, selected, in the copy
--               window) and Clear
--     Import    a paste box (its Accept checks the string); the report (spec §15 step 5); Import and
--               Clear
--     Built-in  one line per shipped set: an Enabled checkbox named after the set, then Customize (or
--               Edit the copy) and Choose callouts
--
-- The ticks and the checked string are session state (NS.State.share), never saved; a profile switch
-- clears them (settings/Editors.lua). The codec, the checks, the export and the apply are
-- modules/Share.lua's, and Library.Import is the one writer of what arrives; both acts are refused in
-- combat. A tick and a check refresh their own lines in place; an import repaints every page.
-- Enabled is the set's `builtin.enabled` member row, written through the seam with the set's id.
-- Customize is Library's (the copy takes the set's place on every pad and dial, and the set is turned
-- off) and opens the Groups page on the copy. Choose callouts opens the set on the Groups page's
-- Callouts tab, the one hidden-callouts editor. The page edits no single instance, so its band has no
-- picker. Defaults turns every set back on and shows all of their callouts.

local QC = NS.addon
local Settings = QC.Settings
local Ed = Settings.Editors
local L = NS.L

local PAGE = "share"
local BUILTIN = L["Built-in"]
local EXPORT, IMPORT = L["Export"], L["Import"]

Settings.Share = Settings.Share or {}
local SH = Settings.Share

local function H() return Settings.Helpers end

-- ── Export ──────────────────────────────────────────────────────────────────────────────────

local KINDS = {
    { kind = "callout", title = L["Callouts"], set = "callouts" },
    { kind = "group", title = L["Groups"], set = "groups" },
    { kind = "pad", title = L["Comms Pads"], set = "pads" },
    { kind = "dial", title = L["Comms Dials"], set = "dials" },
}

--- Tick or untick one member for export.
function SH.Pick(kind, id, on)
    local pick = NS.State.share.pick
    pick[kind] = pick[kind] or {}
    pick[kind][id] = on and true or nil
end

function SH.Picked(kind, id)
    local ids = NS.State.share.pick[kind]
    return ids ~= nil and ids[id] == true
end

function SH.ClearPicks()
    NS.State.share.pick = { callout = {}, group = {}, pad = {}, dial = {} }
    Ed.RequestRefresh()
end

--- What the export string will hold: the ticks and what they bring with them.
function SH.ExportSummary()
    local payload = NS.Share.Collect(NS.State.share.pick)
    if not payload then return L["Nothing is ticked yet."] end
    return L["The string will hold %s."]:format(NS.Share.CountText(payload))
end

--- Export the ticked members (modules/Share.lua): the string opens in the copy window. A refusal
--- prints its reason.
--- @return string|nil
function SH.Export()
    local text, why = NS.Share.Export(NS.State.share.pick)
    if not text then NS.Print(NS.Share.REASON_TEXT[why] or tostring(why)) end
    return text
end

local function pickBox(kind, id, name, summary)
    return { make = function(_, parent, rel)
        local cb = H().AceGUI:Create("CheckBox")
        cb:SetLabel(name)
        cb:SetValue(SH.Picked(kind, id))
        cb:SetRelativeWidth(rel or 0.5)
        cb:SetCallback("OnValueChanged", function(_, _, v)
            SH.Pick(kind, id, v)
            if summary.label then summary.label:SetText(SH.ExportSummary()) end
        end)
        parent:AddChild(cb)
        return cb
    end }
end

local function renderExport(ctx)
    local h = H()
    h.TextRow(ctx, L["Tick what to share. A group brings its callouts with it, and a pad or a dial brings its groups. A pad or a dial travels without its key and its position."])
    local p, summary = NS.db.profile, {}
    for _, k in ipairs(KINDS) do
        local items = {}
        for _, id in ipairs(NS.Library.MemberIds(k.kind)) do
            local m = p[k.set][id]
            if m then items[#items + 1] = pickBox(k.kind, id, m.name or id, summary) end
        end
        if #items > 0 then
            h.Section(ctx, k.title)
            h.RenderGrid(ctx, items)
        end
    end
    summary.label = h.TextRow(ctx, SH.ExportSummary())
    h.InlineButtonPair(ctx,
        { text = L["Export"], tooltip = L["Make the string and open it, selected, in a window: press Ctrl+C to copy it."],
          onClick = function() SH.Export() end },
        { text = L["Clear"], tooltip = L["Untick everything."], onClick = SH.ClearPicks })
end

-- ── Import ──────────────────────────────────────────────────────────────────────────────────

--- Check a pasted string (modules/Share.lua Check) and keep the result for the report and Import.
--- @return table the result
function SH.Check(text)
    NS.State.share.import = NS.Share.Check(text)
    return NS.State.share.import
end

--- The report's text: the checked string's ReportLines, or how to start.
function SH.ReportText()
    local res = NS.State.share.import
    if not res then return L["Paste a string in the box, then click Accept to check it. Nothing changes until you click Import."] end
    return table.concat(NS.Share.ReportLines(res), "\n")
end

-- How many of a checked string's groups no shared pad or dial lists: they arrive on no surface
-- (Library.Import adds a group to no pad, unlike the Groups page's New group).
local function looseGroups(res)
    local listed = {}
    for _, key in ipairs({ "pads", "dials" }) do
        for _, s in ipairs(res[key]) do
            for _, gid in ipairs(s.groups) do listed[gid] = true end
        end
    end
    local n = 0
    for _, g in ipairs(res.groups) do
        if not listed[g.id] then n = n + 1 end
    end
    return n
end

--- Import the checked string and say what arrived (one chat line; one more when a dial did, since it
--- has no key yet; and one more when a group arrived that no shared pad or dial lists, since it shows
--- nowhere until it is added). A refusal prints its reason and keeps the string.
--- @return table|nil Library.Import's tally
function SH.Import()
    local res = NS.State.share.import
    local tally, why = NS.Share.Apply(res)
    if not tally then
        NS.Print(NS.Share.REASON_TEXT[why] or tostring(why))
        return nil
    end
    NS.State.share.import = nil
    local counts = NS.Share.CountText(tally)
    NS.Print(counts ~= "" and L["Imported %s."]:format(counts) or L["Nothing was imported."])
    if tally.dials > 0 then NS.Print(L["An imported dial has no key yet: give it one on the Comms Dial page."]) end
    if looseGroups(res) > 0 then
        NS.Print(L["An imported group is on no pad or dial yet: add it on the Groups tab of the Comms Pad or Comms Dial page."])
    end
    Ed.RequestRefresh()
    return tally
end

function SH.ClearImport()
    NS.State.share.import = nil
end

local function renderImport(ctx)
    local h = H()
    local report
    local function refresh()
        if report then report:SetText(SH.ReportText()) end
    end
    h.RenderGrid(ctx, { { wide = true, make = function(_, parent)
        local box = h.AceGUI:Create("MultiLineEditBox")
        box:SetLabel(L["Share string"])
        box:SetNumLines(8)
        box:SetFullWidth(true)
        box:SetCallback("OnEnterPressed", function(_, _, text)
            SH.Check(text)
            refresh()
        end)
        parent:AddChild(box)
        return box
    end } })
    report = h.TextRow(ctx, SH.ReportText())
    h.InlineButtonPair(ctx,
        { text = L["Import"], tooltip = L["Add what the checked string holds to this profile. Everything arrives as new: nothing you have is changed."],
          onClick = function()
              SH.Import()
              refresh()
          end },
        { text = L["Clear"], tooltip = L["Forget the checked string."], onClick = function()
              SH.ClearImport()
              refresh()
          end })
end

-- ── Built-in ────────────────────────────────────────────────────────────────────────────────

function SH.Customize(id)
    local copy = Settings.Groups.Customize(id)
    if copy then Ed.Open(Settings.Groups.PAGE) end
    return copy
end

function SH.ChooseCallouts(id)
    Ed.Select("group", id)
    local groups = Ed.pages[Settings.Groups.PAGE]
    if groups then groups.activeTab = "callouts" end
    return Ed.Open(Settings.Groups.PAGE)
end

--- Every set back on, every callout shown (the page's Defaults; its blast radius is the whole list).
--- One act: one bulk bracket (debug-logging-§10: one `[Set] reset share: N rows` line) and one
--- coalesced LIBRARY_CHANGED (Lib.Batch), so the pads rebuild once and the pages repaint once. The
--- Defaults button is refused in combat by the options library, at the control.
function SH.RestoreAll()
    local S = NS.SchemaRuntime
    S.BulkRun("reset", PAGE, function()
        NS.Library.Batch(function()
            for _, id in ipairs(NS.BuiltIns.order) do
                S.Set("builtin.enabled", true, id)
                S.Set("builtin.hidden", {}, id)
            end
        end)
    end)
end

local function renderBuiltIn(ctx)
    local h = H()
    h.TextRow(ctx, L["The callout sets that ship with Quick Comms. Turn a set off, Customize it into a group you can edit, or choose which of its callouts show."])
    local items = {}
    for _, id in ipairs(NS.BuiltIns.order) do
        local def = NS.BuiltIns.groups[id]
        local group = NS.Library.Group(id)
        items[#items + 1] = { make = function(_, parent, rel)
            local cb = h.AceGUI:Create("CheckBox")
            cb:SetLabel(def.name)
            cb:SetValue(group and group.enabled ~= false)
            cb:SetRelativeWidth(rel or 0.5)
            cb:SetCallback("OnValueChanged", function(_, _, v) NS.Library.SetBuiltinEnabled(id, v and true or false) end)
            h.AttachTooltip(cb, def.name, L["Show this set wherever it matches. Off keeps it, and its place on every pad."])
            parent:AddChild(cb)
            return cb
        end }
        items[#items + 1] = { make = function(_, parent, rel)
            local AceGUI = h.AceGUI
            local row = AceGUI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetRelativeWidth(rel or 0.5)
            local copy = Settings.Groups.CustomizedAs(id)
            local customize = AceGUI:Create("Button")
            customize:SetText(copy and L["Edit the copy"] or L["Customize"])
            customize:SetRelativeWidth(0.48)
            customize:SetCallback("OnClick", function() SH.Customize(id) end)
            row:AddChild(customize)
            local choose = AceGUI:Create("Button")
            choose:SetText(L["Choose callouts"])
            choose:SetRelativeWidth(0.48)
            choose:SetCallback("OnClick", function() SH.ChooseCallouts(id) end)
            row:AddChild(choose)
            parent:AddChild(row)
            return row
        end }
    end
    h.RenderGrid(ctx, items)
end

local function render(ctx)
    Ed.Tabs(ctx, PAGE, {
        { key = EXPORT, label = EXPORT, tooltip = L["Make a string of your callouts, groups, pads or dials to share."],
          render = renderExport },
        { key = IMPORT, label = IMPORT, tooltip = L["Add what someone shared with you, from their string."],
          render = renderImport },
        { key = BUILTIN, render = renderBuiltIn },
    })
end

Ed.RegisterPage(PAGE, L["Share"], "SharePanel", render, {
    tooltip = L["Turn every built-in set back on and show all of their callouts. Your customized copies are kept."],
    onClick = function() SH.RestoreAll() end,
})
```

In `tests/page_helpers.lua`, replace
```lua
    -- AceGUI's Keybinding widget shows the key it was given: the kit's fake records nothing for it,
    -- so a Keybinding made here gets SetKey/GetKey, recording the shown key as `shownKey`.
    if not ace.__qcKeyWrapped then
        ace.__qcKeyWrapped = true
        local create = ace.Create
        ace.Create = function(fake, wtype, ...)
            local w = create(fake, wtype, ...)
            if wtype == "Keybinding" and not w.SetKey then
                function w:SetKey(k) self.shownKey = k; return self end
                function w:GetKey() return self.shownKey end
            end
            return w
        end
    end
```
with
```lua
    -- AceGUI's Keybinding widget shows the key it was given: the kit's fake records nothing for it,
    -- so a Keybinding made here gets SetKey/GetKey, recording the shown key as `shownKey`. Its
    -- MultiLineEditBox sizes itself by lines: one made here gets SetNumLines, recording `numLines`.
    if not ace.__qcKeyWrapped then
        ace.__qcKeyWrapped = true
        local create = ace.Create
        ace.Create = function(fake, wtype, ...)
            local w = create(fake, wtype, ...)
            if wtype == "Keybinding" and not w.SetKey then
                function w:SetKey(k) self.shownKey = k; return self end
                function w:GetKey() return self.shownKey end
            end
            if wtype == "MultiLineEditBox" and not w.SetNumLines then
                function w:SetNumLines(n) self.numLines = n; return self end
            end
            return w
        end
    end
```

Append to `locales/enUS.lua`:
```lua
-- settings/Share.lua and core/WidgetsSetup.lua: the Export and Import tabs, and the export window (phase 5)
L["Comms Pads"] = "Comms Pads"
L["Comms Dials"] = "Comms Dials"
L["Nothing is ticked yet."] = "Nothing is ticked yet."
L["The string will hold %s."] = "The string will hold %s."
L["Tick what to share. A group brings its callouts with it, and a pad or a dial brings its groups. A pad or a dial travels without its key and its position."] = "Tick what to share. A group brings its callouts with it, and a pad or a dial brings its groups. A pad or a dial travels without its key and its position."
L["Export"] = "Export"
L["Make the string and open it, selected, in a window: press Ctrl+C to copy it."] = "Make the string and open it, selected, in a window: press Ctrl+C to copy it."
L["Untick everything."] = "Untick everything."
L["Paste a string in the box, then click Accept to check it. Nothing changes until you click Import."] = "Paste a string in the box, then click Accept to check it. Nothing changes until you click Import."
L["Imported %s."] = "Imported %s."
L["Nothing was imported."] = "Nothing was imported."
L["An imported dial has no key yet: give it one on the Comms Dial page."] = "An imported dial has no key yet: give it one on the Comms Dial page."
L["An imported group is on no pad or dial yet: add it on the Groups tab of the Comms Pad or Comms Dial page."] = "An imported group is on no pad or dial yet: add it on the Groups tab of the Comms Pad or Comms Dial page."
L["Share string"] = "Share string"
L["Import"] = "Import"
L["Add what the checked string holds to this profile. Everything arrives as new: nothing you have is changed."] = "Add what the checked string holds to this profile. Everything arrives as new: nothing you have is changed."
L["Forget the checked string."] = "Forget the checked string."
L["Make a string of your callouts, groups, pads or dials to share."] = "Make a string of your callouts, groups, pads or dials to share."
L["Add what someone shared with you, from their string."] = "Add what someone shared with you, from their string."
L["Quick Comms: share string"] = "Quick Comms: share string"
```

- [ ] **Step 6: Run the gate and the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: PASS, 0 / 0, `0 warnings`. Checked on a scratch export of `55194f6`: 626 passed, 3 skipped at the end of Milestone 1.

- [ ] **Step 7: Commit**

```bash
git add modules/Share.lua core/WidgetsSetup.lua core/State.lua settings/Editors.lua settings/Share.lua tests/page_helpers.lua tests/test_page_share.lua locales/enUS.lua
rm settings/Share.lua && git checkout -- settings/Share.lua
git checkout -- modules/Share.lua core/WidgetsSetup.lua core/State.lua settings/Editors.lua tests/page_helpers.lua tests/test_page_share.lua locales/enUS.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Share page: Export and Import tabs; the string in the copy window; both refused in combat"
```

**Milestone 1 checkpoint.** Both gate commands green, complexity `0 warnings`. Nothing is pushed.

---

### Task 6: The instance ids, matched against the client's own data

Spec §12.1 ("phase 5 confirms their instance IDs") and §13.2 (the Midnight dungeon and raid ids). An instanceID is the client's Map id, so the client's own data tables settle what a headless run can: each shipped battleground id is a battleground map, each dungeon a map of the current Mythic+ season, each raid a raid map of the current journal tier. That is a match, not the in-game confirmation owner ruling 10 asks for: the shipped files say "matched", and smoke checks BG-2 and IDS-1 (Task 11, run in Task 14) confirm. No battleground id changes; the Midnight dungeons and raids are added (Sporefall as ruling R4 decides; spec 1480's note as R3 decides). Do not start before R3 and R4 are recorded (Pre-flight P3).

The test's `CLIENT_MAPS` is typed into the test, so on its own it cannot catch an id typed wrong in both places. What makes it a check is the generator: `tools/derive-gameids.py` (layout-§1: an authored generator lives under `tools/`, is never loaded, and is `.pkgmeta`-ignored) downloads the client's tables from wago.tools (`Map`, `MapChallengeMode`, `MythicPlusSeasonTrackedMap`, `JournalTier`, `JournalTierXInstance`, `JournalInstance`, `ChrSpecialization`), re-derives every `CLIENT_MAPS` row, the season's dungeons, the tier's raids and spec 1480's class, and exits non-zero on any mismatch with `tests/test_gameids.lua` or `defaults/GameIds.lua`. Step 5 runs it before the commit; a mismatch stops the task. Run against build 12.1.5.70340 on 2026-10-13 (a scratch run of this plan), it printed the block below, `NOT SHIPPED: raid candidate 1592 Sporefall`, `spec 1480 = Devourer (class 12)` and `OK: 30 map rows, 8 dungeons, 3 raids, 1 spec`. The raid rule is the journal's Current Season tier (505) rows under the launch season's condition (149388) whose map is a raid and whose journal entry is not a world-boss entry; the dungeon rule is Mythic+ display season 34's tracked maps (season 37's eight are the next season's, behind condition 156363).

**Files:**
- Create: `tests/test_gameids.lua`, `tools/client_tables.py`, `tools/derive-gameids.py`
- Modify: `defaults/GameIds.lua` (its header and the two id lists), `defaults/BuiltIns_Battlegrounds.lua` (its header comment), `tests/run.lua`, `.pkgmeta` (`- tools`)

**Interfaces:**
- Consumes: `NS.BuiltIns.order`, `NS.BuiltIns.groups[gid].when.battleground`, `NS.GameIds.DUNGEONS`, `NS.GameIds.RAIDS`.
- Produces: `NS.GameIds.DUNGEONS` (eight ids) and `NS.GameIds.RAIDS` (three ids, or four under R4). "Preview as…" gains an `mplus:<id>` entry for each new dungeon, and the When editor's instance picker offers the new ids, with no other change. `tools/client_tables.py` (`fetch`, `read`, `fail`), shared with Task 7's `tools/derive-winds.py`; `tools/derive-gameids.py`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_gameids.lua`:
```lua
-- tests/test_gameids.lua — the shipped instance ids (spec §12.1, §13.2: "phase 5 confirms their
-- instance IDs"), matched against the client's own data. CLIENT_MAPS below is an EXTRACTION, not
-- authored data: the Map table's InstanceType (1 party, 2 raid, 3 battleground) and whether a
-- MapChallengeMode row names the map (a Mythic+ dungeon), for every id defaults/ ships, as exported
-- from client build 12.1.5.70340 by wago.tools on 2026-10-13. tools/derive-gameids.py re-derives
-- every row from those tables and fails on any difference, so an id typed wrong here and in defaults/
-- alike is still caught (docs/common-tasks.md says how to run it). Adding an id to defaults/ means
-- adding its row here and running the generator; smoke checks BG-2 and IDS-1 confirm the ids in game.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local PARTY, RAID, PVP = 1, 2, 3

local CLIENT_MAPS = {
    [529] = { type = 3, challenge = false },   -- Classic Arathi Basin
    [2107] = { type = 3, challenge = false },  -- Arathi Basin
    [1681] = { type = 3, challenge = false },  -- Arathi Basin Winter
    [566] = { type = 3, challenge = false },   -- Eye of the Storm
    [968] = { type = 3, challenge = false },   -- Rated Eye of the Storm
    [761] = { type = 3, challenge = false },   -- The Battle for Gilneas
    [1105] = { type = 3, challenge = false },  -- Deepwind Gorge (Legacy)
    [2245] = { type = 3, challenge = false },  -- Deepwind Gorge
    [628] = { type = 3, challenge = false },   -- Isle of Conquest
    [489] = { type = 3, challenge = false },   -- Classic Warsong Gulch
    [2106] = { type = 3, challenge = false },  -- Warsong Gulch
    [726] = { type = 3, challenge = false },   -- Twin Peaks
    [727] = { type = 3, challenge = false },   -- Silvershard Mines
    [998] = { type = 3, challenge = false },   -- Temple of Kotmogu
    [1803] = { type = 3, challenge = false },  -- Seething Shore
    [2656] = { type = 3, challenge = false },  -- Deephaul Ravine
    [30] = { type = 3, challenge = false },    -- Alterac Valley
    [1191] = { type = 3, challenge = false },  -- Ashran
    [2118] = { type = 3, challenge = false },  -- Battle for Wintergrasp
    [2526] = { type = 1, challenge = true },   -- Algeth'ar Academy
    [658] = { type = 1, challenge = true },    -- Pit of Saron
    [1753] = { type = 1, challenge = true },   -- Seat of the Triumvirate
    [1209] = { type = 1, challenge = true },   -- Skyreach
    [2805] = { type = 1, challenge = true },   -- Windrunner Spire
    [2811] = { type = 1, challenge = true },   -- Magisters' Terrace
    [2915] = { type = 1, challenge = true },   -- Nexus-Point Xenas
    [2874] = { type = 1, challenge = true },   -- Maisara Caverns
    [2912] = { type = 2, challenge = false },  -- The Voidspire
    [2939] = { type = 2, challenge = false },  -- The Dreamrift
    [2913] = { type = 2, challenge = false },  -- March on Quel'Danas
}

-- Every battleground set's ids: { setId = { id, ... } }.
local function battlegroundIds(NS)
    local out = {}
    for _, gid in ipairs(NS.BuiltIns.order) do
        local def = NS.BuiltIns.groups[gid]
        local ids = def.when and def.when.battleground
        if ids then
            out[gid] = {}
            for id in pairs(ids) do out[gid][#out[gid] + 1] = id end
        end
    end
    return out
end

test("game ids: every battleground set matches only battleground maps, and no map is two sets'", function()
    local NS = T.newAddon()
    local owner, sets = {}, 0
    for gid, ids in pairs(battlegroundIds(NS)) do
        sets = sets + 1
        assertTrue(#ids > 0, gid .. " lists an id")
        for _, id in ipairs(ids) do
            local row = CLIENT_MAPS[id]
            -- red under: change one of defaults/BuiltIns_Battlegrounds.lua's ids to a typo (e.g. 2017)
            assertTrue(row ~= nil, gid .. ": " .. id .. " is not in the client's Map table extraction")
            assertEqual(row.type, PVP, gid .. ": " .. id .. " is a battleground map")
            assertTrue(owner[id] == nil, id .. " is listed by " .. tostring(owner[id]) .. " and " .. gid)
            owner[id] = gid
        end
    end
    assertEqual(sets, 14, "the 14 battlegrounds of brainstorm §8 (spec §12.1)")
end)

test("game ids: the shipped dungeons are Mythic+ dungeons and the shipped raids are raids", function()
    local NS = T.newAddon()
    for _, id in ipairs(NS.GameIds.DUNGEONS) do
        local row = CLIENT_MAPS[id]
        assertTrue(row ~= nil and row.type == PARTY and row.challenge, id .. " is a dungeon with a challenge map")
    end
    for _, id in ipairs(NS.GameIds.RAIDS) do
        local row = CLIENT_MAPS[id]
        assertTrue(row ~= nil and row.type == RAID, id .. " is a raid map")
    end
    assertEqual(#NS.GameIds.DUNGEONS, 8, "the season's eight")
    assertEqual(#NS.GameIds.RAIDS, 3, "the tier's three (four, with Sporefall 1592 and its CLIENT_MAPS row, if ruling R4 ships it)")
end)
```

In `tests/run.lua`, replace
```lua
        "test_builtins",
```
with
```lua
        "test_builtins",
        "test_gameids",
```

- [ ] **Step 2: Run it to check it fails**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: the battleground case PASSES (every shipped id is already a battleground map, which is the confirmation); the dungeon and raid case FAILS (`the season's eight`: four are listed).

- [ ] **Step 3: The ids**

In `defaults/GameIds.lua`, replace
```lua
local _, NS = ...
-- defaults/GameIds.lua — the shipped game-id tables "Preview as…" and the When editor list (spec
-- §13.2, §13.3). DATA ONLY. Every entry is an id or a token, never a name (localization-§4): a name
-- is read from the client at display time (core/Compat.lua) and never matched.
--   DUNGEONS  the current Mythic+ season's instanceIDs (GetInstanceInfo's 8th return). Only the ids
--             confirmed when this table was written are listed: the season's returning dungeons.
--             The Midnight dungeons and raids join when their ids are confirmed in game (phase 5,
--             with the battleground ids); until then the When editor adds the instance you are in,
--             or a typed id.
--   RAIDS     the current raid tier's instanceIDs (none confirmed yet).
--   CLASSES   classFile tokens, in the client's class order.
--   SPECS     specIDs per classFile. 1480 is the Demon Hunter's Devourer (Midnight), confirmed in
--             game with the rest in phase 5.

NS.GameIds = NS.GameIds or {}
local G = NS.GameIds

G.DUNGEONS = {
    2526,   -- Algeth'ar Academy
    658,    -- Pit of Saron
    1753,   -- Seat of the Triumvirate
    1209,   -- Skyreach
}
G.RAIDS = {}
```
with
```lua
local _, NS = ...
-- defaults/GameIds.lua — the shipped game-id tables "Preview as…" and the When editor list (spec
-- §13.2, §13.3). DATA ONLY. Every entry is an id or a token, never a name (localization-§4): a name
-- is read from the client at display time (core/Compat.lua) and never matched.
--   DUNGEONS  the current Mythic+ season's instanceIDs (GetInstanceInfo's 8th return, which is the
--             client's Map id): the season's four returning dungeons and Midnight's four new ones.
--   RAIDS     the current raid tier's instanceIDs: Midnight's three launch raids.
--   CLASSES   classFile tokens, in the client's class order.
--   SPECS     specIDs per classFile. 1480 is the Demon Hunter's Devourer (Midnight): matched in the
--             client's ChrSpecialization table (class 12); in game, smoke check IDS-1.
-- MATCHED (phase 5), NOT YET CONFIRMED IN GAME: matched against the client's own data tables as
-- exported from build 12.1.5.70340 by wago.tools (2026-10-13). Each dungeon is a map of Mythic+
-- display season 34 (MythicPlusSeasonTrackedMap, through MapChallengeMode, to a Map row of instance
-- type 1); each raid a Map row of instance type 2 in the journal's Current Season tier under the
-- launch season's condition. tools/derive-gameids.py re-derives all of it and checks this file and
-- tests/test_gameids.lua's extraction. In-game confirmation is smoke check IDS-1 (and BG-2 for the
-- battlegrounds); this note says CONFIRMED only after the phase 5 smoke test records them as passed.
-- Not listed: the raids the client gates behind a later season (The Tidebound Grotto, The Venomous
-- Abyss, The Unbinding of Kith'ix) and Sporefall (1592; owner ruling R4): the When editor adds the
-- instance you are in, or a typed id.

NS.GameIds = NS.GameIds or {}
local G = NS.GameIds

G.DUNGEONS = {
    2526,   -- Algeth'ar Academy
    658,    -- Pit of Saron
    1753,   -- Seat of the Triumvirate
    1209,   -- Skyreach
    2805,   -- Windrunner Spire
    2811,   -- Magisters' Terrace
    2915,   -- Nexus-Point Xenas
    2874,   -- Maisara Caverns
}
G.RAIDS = {
    2912,   -- The Voidspire
    2939,   -- The Dreamrift
    2913,   -- March on Quel'Danas
}
```

In `defaults/BuiltIns_Battlegrounds.lua`, replace
```lua
local _, NS = ...
-- defaults/BuiltIns_Battlegrounds.lua — the generic battleground set and one set per
-- battleground (spec §12). Faction-neutral wording (D11). Matched on instanceID; the IDs below
-- are confirmed or corrected by the phase 0 harness (/qcs where, round-4 record). Node
-- battlegrounds nest one ring per node with INC 1/2/3/Many/Clear/Help and open into their ring.
-- The generic set is declared last, below every per-battleground set.
```
with
```lua
local _, NS = ...
-- defaults/BuiltIns_Battlegrounds.lua — the generic battleground set and one set per
-- battleground (spec §12). Faction-neutral wording (D11). Matched on instanceID (the client's Map
-- id); every id below is a battleground map in the client's own Map table (build 12.1.5.70340,
-- matched by tools/derive-gameids.py and tests/test_gameids.lua); in-game confirmation is smoke check
-- BG-2. Node
-- battlegrounds nest one ring per node with INC 1/2/3/Many/Clear/Help and open into their ring.
-- The generic set is declared last, below every per-battleground set.
```

- [ ] **Step 4: The generator**

Create `tools/client_tables.py`:
```python
# tools/client_tables.py — shared by tools/derive-gameids.py and tools/derive-winds.py: fetch the
# client's own data tables as wago.tools exports them (CSV), and read one. Dev-only: never loaded by
# the client or the TOC, and .pkgmeta-ignored (layout-§1, "Where an authored generator lives").
# Python 3, standard library only.
import csv
import os
import re
import sys
import urllib.request

URL = "https://wago.tools/db2/{}/csv"


def fail(msg):
    """Stop loudly: a thin or partial derivation must never look like a result."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def fetch(directory, tables):
    """Download each table into `directory` (made new; it must not already hold files). Answers the
    client build the export names (from its Content-Disposition file name)."""
    os.makedirs(directory, exist_ok=True)
    if os.listdir(directory):
        fail(directory + " is not empty: give --fetch a new directory")
    build = None
    for t in tables:
        req = urllib.request.Request(URL.format(t), headers={"User-Agent": "QuickComms-tools"})
        with urllib.request.urlopen(req, timeout=120) as r:
            m = re.search(r'filename="[^.]+\.([0-9.]+)\.csv"', r.headers.get("Content-Disposition", ""))
            if m:
                build = build or m.group(1)
                if m.group(1) != build:
                    fail("{} is build {}, the others {}".format(t, m.group(1), build))
            with open(os.path.join(directory, t + ".csv"), "wb") as f:
                f.write(r.read())
    return build


def read(directory, table):
    path = os.path.join(directory, table + ".csv")
    if not os.path.isfile(path):
        fail("no " + path + ": run with --fetch first")
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        fail(path + " is empty")
    return rows
```

Create `tools/derive-gameids.py`:
```python
# tools/derive-gameids.py — derive the instance-id extraction tests/test_gameids.lua holds
# (CLIENT_MAPS) and the season's candidate lists from the client's own data tables, and check the
# repository against them (spec §12.1, §13.2). Dev-only: never loaded by the client or the TOC, and
# .pkgmeta-ignored (layout-§1, "Where an authored generator lives"). Python 3, standard library only.
#
#   python3 -I tools/derive-gameids.py --fetch DIR    download the tables into DIR (a new directory)
#   python3 -I tools/derive-gameids.py DIR            derive from DIR and check; exit 1 on any mismatch
#
# What it checks, each a loud failure (exit 1):
#   - every CLIENT_MAPS row in tests/test_gameids.lua equals the row derived from Map (InstanceType)
#     and MapChallengeMode (a challenge map names it); an id Map does not have fails
#   - defaults/GameIds.lua's DUNGEONS are exactly the maps of the Mythic+ season SEASON
#     (MythicPlusSeasonTrackedMap -> MapChallengeMode)
#   - defaults/GameIds.lua's RAIDS are raid maps in the journal's Current Season tier under the launch
#     condition LAUNCH, and not a world-boss entry; a candidate not shipped is printed as NOT SHIPPED
#     (the owner's ruling decides it, never this script)
#   - each spec id in SPECS names its class in ChrSpecialization
# It prints the derived CLIENT_MAPS block and the build, for the header lines and for review as a diff.
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import client_tables as ct  # noqa: E402

TABLES = ["Map", "MapChallengeMode", "MythicPlusSeasonTrackedMap", "JournalTier",
          "JournalTierXInstance", "JournalInstance", "ChrSpecialization"]
SEASON = 34            # Midnight season 1's DisplaySeasonID in MythicPlusSeasonTrackedMap
CURRENT_TIER = 505     # the journal's "Current Season" tier (JournalTier.ID)
LAUNCH = 149388        # the AvailabilityCondition the launch season's raids carry in that tier
WORLD_BOSSES = 2       # JournalInstance.Flags bit: a world-boss entry, not an instance
SPECS = {1480: 12}     # specID -> ClassID: the Demon Hunter's Devourer
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lua_ids(path, start):
    """The integers listed in the Lua table that opens on the line starting `start`."""
    text = open(path, encoding="utf-8").read()
    m = re.search(re.escape(start) + r"(.*?)\n\}", text, re.S)
    if not m:
        ct.fail("no '" + start + "' table in " + path)
    return [int(x) for x in re.findall(r"^\s*(\d+),", m.group(1), re.M)]


def fixture_rows(path):
    text = open(path, encoding="utf-8").read()
    rows = re.findall(r"\[(\d+)\] = \{ type = (\d), challenge = (true|false) \}", text)
    if not rows:
        ct.fail("no CLIENT_MAPS rows in " + path)
    return {int(i): (int(t), c == "true") for i, t, c in rows}


def main(argv):
    if len(argv) == 3 and argv[1] == "--fetch":
        print("fetched build " + str(ct.fetch(argv[2], TABLES)))
        return
    if len(argv) != 2:
        ct.fail("usage: derive-gameids.py --fetch DIR | derive-gameids.py DIR")
    d = argv[1]
    maps = {int(r["ID"]): r for r in ct.read(d, "Map")}
    challenge = {int(r["ID"]): int(r["MapID"]) for r in ct.read(d, "MapChallengeMode")}
    challenged = set(challenge.values())
    bad = []

    fixture = fixture_rows(os.path.join(ROOT, "tests", "test_gameids.lua"))
    print("local CLIENT_MAPS = {")
    for i in fixture:
        if i not in maps:
            ct.fail(str(i) + " is not in the client's Map table")
        got = (int(maps[i]["InstanceType"]), i in challenged)
        print("    [{}] = {{ type = {}, challenge = {} }},  -- {}".format(
            i, got[0], str(got[1]).lower(), maps[i]["MapName_lang"]))
        if got != fixture[i]:
            bad.append("CLIENT_MAPS[{}] is {}, the client says {}".format(i, fixture[i], got))
    print("}")

    season = sorted(challenge[int(r["MapChallengeModeID"])] for r in ct.read(d, "MythicPlusSeasonTrackedMap")
                    if int(r["DisplaySeasonID"]) == SEASON)
    if not season:
        ct.fail("season " + str(SEASON) + " tracks no map")
    dungeons = sorted(lua_ids(os.path.join(ROOT, "defaults", "GameIds.lua"), "G.DUNGEONS = {"))
    if dungeons != season:
        bad.append("DUNGEONS {} are not season {}'s maps {}".format(dungeons, SEASON, season))

    journal = {int(r["ID"]): r for r in ct.read(d, "JournalInstance")}
    candidates = {}
    for r in ct.read(d, "JournalTierXInstance"):
        j = journal.get(int(r["JournalInstanceID"]))
        if int(r["JournalTierID"]) != CURRENT_TIER or int(r["AvailabilityCondition"]) != LAUNCH or not j:
            continue
        mid = int(j["MapID"])
        if mid in maps and int(maps[mid]["InstanceType"]) == 2 and not int(j["Flags"]) & WORLD_BOSSES:
            candidates[mid] = j["Name_lang"]
    if not candidates:
        ct.fail("the Current Season tier lists no raid under condition " + str(LAUNCH))
    raids = lua_ids(os.path.join(ROOT, "defaults", "GameIds.lua"), "G.RAIDS = {")
    for mid in raids:
        if mid not in candidates:
            bad.append("RAIDS lists {}, which is not a launch-season raid".format(mid))
    for mid in sorted(candidates):
        if mid not in raids:
            print("NOT SHIPPED: raid candidate {} {} (an owner ruling decides it)".format(mid, candidates[mid]))

    specs = {int(r["ID"]): r for r in ct.read(d, "ChrSpecialization")}
    for sid, cls in SPECS.items():
        if sid not in specs or int(specs[sid]["ClassID"]) != cls:
            bad.append("spec {} is not class {}'s".format(sid, cls))
        else:
            print("spec {} = {} (class {})".format(sid, specs[sid]["Name_lang"], cls))

    for b in bad:
        print("MISMATCH: " + b, file=sys.stderr)
    if bad:
        sys.exit(1)
    print("OK: {} map rows, {} dungeons, {} raids, {} spec".format(len(fixture), len(dungeons), len(raids), len(SPECS)))


if __name__ == "__main__":
    main(sys.argv)
```

In `.pkgmeta`, replace
```yaml
  # - tools          # ONLY once the repo HAS a tools/ (layout-§1); it has none today
```
with
```yaml
  - tools            # dev-only generators (layout-§1): the client-data derivations, Python; never loaded
```

- [ ] **Step 5: Run the derivation; a mismatch stops the task**

The downloads go to a new scratch directory, never into the repo; they are data, read only by `csv` (the `-I` flag keeps Python from importing anything from the current directory):
```bash
D="$(mktemp -d)/tables"
python3 -I tools/derive-gameids.py --fetch "$D"
python3 -I tools/derive-gameids.py "$D"; echo "exit $?"
```
Expected: `fetched build 12.1.5.70340` (a later build is fine: say which in the commit message), then the `local CLIENT_MAPS = {` block with the same thirty rows as `tests/test_gameids.lua` (compare them: the generator already failed on a difference, and the names in its comments are what to read), `NOT SHIPPED: raid candidate 1592 Sporefall (an owner ruling decides it)` (absent if R4 shipped it), `spec 1480 = Devourer (class 12)`, `OK: 30 map rows, 8 dungeons, 3 raids, 1 spec` and `exit 0`. Any `MISMATCH:` or `FAIL:` line, or a non-zero exit, stops the task: report it to the owner with the lines it printed; do not edit an id or a row to make it pass.

- [ ] **Step 6: Run the gate**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, 0 / 0 (`test_preview`'s menu case still finds `mplus:2526` and `bg:ab`; the prose gate reads the two Python files, which are US English; luacheck reads no Python).

- [ ] **Step 7: Commit**

```bash
git add tests/test_gameids.lua tests/run.lua defaults/GameIds.lua defaults/BuiltIns_Battlegrounds.lua tools/client_tables.py tools/derive-gameids.py .pkgmeta
rm tests/test_gameids.lua tools/client_tables.py tools/derive-gameids.py && git checkout -- tests/test_gameids.lua tools/client_tables.py tools/derive-gameids.py
git checkout -- tests/run.lua defaults/GameIds.lua defaults/BuiltIns_Battlegrounds.lua .pkgmeta
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Game ids: matched against the client's tables (tools/derive-gameids.py); the Midnight dungeons and raids"
```
(`.gitattributes` pins `*.py` to LF, so the refreshed Python files carry LF; every other file here, CRLF.)

---
### Task 7: Battleground node sets pinned to their compass winds

Spec §12.1 ("Nodes are pinned to compass directions") and §11.1, deferred by phase 4's ruling R4. Do not start before ruling R2 (Deepwind Gorge) is recorded (Pre-flight P3); the steps below build its recommended answer, five nodes, and say what changes under the other two. Each node carries its wind, derived by `tools/derive-winds.py` from the client's AreaPOI table: the node's world position (Pos_0 north, Pos_1 west) against the center of its set's nodes, the nearest of eight winds, and "middle" for a node within a third of the spread of that center. `Dial_Layout.PinNodes` puts a node set's nodes on an eight-wedge ring, each on its wind; a middle node takes the first wind left free clockwise from N (N in every shipped set). A pinned ring is never paged, so on a four-slice dial Arathi Basin shows all five nodes at once and Lumber Mill, then INC 3, is still two clicks. A wedge's place is its item's `wedge`, else its index, everywhere a wedge is placed or named.

The winds, from AreaPOI (build 12.1.5.70340, POI ids in brackets; `tools/derive-winds.py` printed exactly these on a scratch run of this plan, and fails on a POI id whose row is missing, on another map or under another name):
- Arathi Basin (2107): Stables NW (6080), Lumber Mill SW (6078), Blacksmith middle (6079), Gold Mine NE (6076), Farm SE (6077)
- Eye of the Storm (566): Fel Reaver Ruins SW (1944), Blood Elf Tower SE (1941), Draenei Ruins NE (1950), Mage Tower NW (1947), the flag middle (1962)
- Battle for Gilneas (761): Lighthouse W (2412), Waterworks SE (2405), Mines NE (2404)
- Deepwind Gorge (2245): Market middle (6544), Farm NE (6546), Quarry NW (6543), Shrine SE (6545), Ruins SW (6547): the current map's five nodes, two more than the set shipped with (R2 (a); under R2 (b) the set keeps three, `NODES.dwg` lists those three and the generator derives their winds from them alone; under R2 (c) Deepwind Gorge carries no winds, is left out of `NODES`, and stays unpinned)
- Isle of Conquest (628): Docks W (2356), Hangar E (2350), Workshop middle (2345), Quarry SE (2361), Refinery NW (2366)

**Files:**
- Create: `tools/derive-winds.py` (it imports Task 6's `tools/client_tables.py`)
- Modify: `defaults/BuiltIns_Battlegrounds.lua` (`nodeBattleground` and the five node lists), `modules/Dial_Layout.lua` (the header's geometry paragraph, two constants, `ringEntry`, `PinNodes`, `groupEntry`, `addRing`'s shape), `modules/Surfaces.lua` (a child's `compass` in `BuildDialPlan`), `modules/Dial.lua` (`placeWedges`), `settings/Dials.lua` (`DD.PreviewLines`), `locales/enUS.lua`
- Test: `tests/test_dial_layout.lua`, `tests/test_builtins.lua`, `tests/test_dial.lua`, `tests/test_page_dials.lua`; `tools/derive-winds.py` (run in Step 6)

**Interfaces:**
- Consumes: a dial plan's node children (`Surfaces.BuildDialPlan`), now `{ id, title, icon, compass, slots }`.
- Produces: `NS.BuiltIns.groups[nodeId].compass` (`"N"` … `"NW"` or `"middle"`); `DL.WIND_INDEX` (`{ N = 1, NE = 2, … NW = 8 }`), `DL.MIDDLE = "middle"`; `DL.PinNodes(entries) -> entries|nil` (each given `wedge`, in wedge order); a ring item's optional `wedge` (its place among the ring's `size`). New built-in ids `bi.bg.dwg.shrine` and `bi.bg.dwg.ruins` (and their six callouts each).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_dial_layout.lua`:
```lua
-- Arathi Basin with its nodes' winds, as defaults/BuiltIns_Battlegrounds.lua ships them.
local AB_WINDS = { "NW", "SW", "middle", "NE", "SE" }
local function abPinned()
    local g = ab()
    for i, c in ipairs(g.children) do c.compass = AB_WINDS[i] end
    return g
end

test("dial layout: [phase 5] a node set's nodes sit on their compass winds; the middle node takes N", function()
    local L = DL()
    local rings, open = L.Rings({ abPinned() }, { mode = "categories", slices = 4, title = "Comms Dial" })
    local ring = rings[open]
    assertEqual(ring.title, "Arathi Basin")
    assertEqual(ring.size, 8, "eight winds, whatever the dial's slices")
    assertEqual(ring.pages, 1, "never paged: no More")
    local at = {}
    for _, item in ipairs(ring.items) do at[#at + 1] = item.title .. "@" .. L.Direction(item.wedge, ring.size) end
    assertEqual(table.concat(at, ","), "Blacksmith@N,Gold Mine@NE,Farm@SE,Lumber Mill@SW,Stables@NW")
    local mill = rings[ring.items[4].target]
    assertEqual(mill.title, "Lumber Mill")
    assertEqual(mill.size, 4, "a node's own ring keeps the dial's slices")
    assertEqual(mill.items[3].slot.line, "/i INC 3 Lumber Mill", "still two clicks to INC 3 Lumber Mill")
end)

test("dial layout: [review 6] [phase 5] nodes that cannot all be pinned keep their shipped order", function()
    local L = DL()
    assertNil(L.PinNodes({ { wind = "N" }, { wind = "N" } }), "two on one wind")
    assertNil(L.PinNodes({ { wind = "N" }, { wind = "up" } }), "an unknown wind")
    assertNil(L.PinNodes({ { wind = "N" }, {} }), "a node with none")
    assertNil(L.PinNodes({}), "none")
    local g = abPinned()
    g.children[2].compass = nil
    local rings, open = L.Rings({ g }, { slices = 4 })
    assertEqual(titles(rings[open]), "Stables,Lumber Mill,Blacksmith,More")
    local two = L.PinNodes({ { wind = "middle", name = "mid" }, { wind = "N", name = "north" } })
    assertEqual(two[1].name .. two[1].wedge .. "," .. two[2].name .. two[2].wedge, "north1,mid2",
        "N is taken, so the middle node takes NE")
end)

test("dial layout: [review 6] a pinned ring ignores the dial's slices; Flat keeps its paging", function()
    local L = DL()
    for _, slices in ipairs({ 4, 6 }) do
        local rings, open = L.Rings({ abPinned() }, { mode = "categories", slices = slices })
        assertEqual(rings[open].size, 8, slices .. " slices: the pinned ring has eight wedges")
        assertEqual(#rings[open].items, 5, slices .. " slices: every node on the one ring, no More")
    end
    -- red under: make shape() answer the pinned shape for every ring in modules/Dial_Layout.lua
    local rings, open = L.Rings({ abPinned() }, { mode = "flat", slices = 4 })
    assertEqual(rings[open].size, 4, "Flat lists the callouts on the dial's own slices")
    assertEqual(rings[open].pages > 1, true, "and pages them behind More")
    for _, item in ipairs(rings[open].items) do assertNil(item.wedge, "nothing in Flat is pinned") end
end)
```

Append to `tests/test_builtins.lua`:
```lua
test("builtins: [phase 5] every node set pins each node to a wind, at most eight, Deepwind Gorge's five included", function()
    local NS, BI = bi()
    local sets = 0
    for _, gid in ipairs(BI.order) do
        local def = BI.groups[gid]
        if def.children then
            sets = sets + 1
            local nodes = {}
            for i, child in ipairs(def.children) do nodes[i] = { wind = BI.groups[child].compass } end
            -- red under: drop one node's wind from defaults/BuiltIns_Battlegrounds.lua
            assertTrue(NS.DialLayout.PinNodes(nodes) ~= nil, gid .. " pins every node")
        end
    end
    assertEqual(sets, 5)
    assertEqual(BI.groups["bi.bg.ab.lumbermill"].compass, "SW")
    assertEqual(#BI.groups["bi.bg.dwg"].children, 5)
    assertEqual(BI.callouts["bi.bg.dwg.shrine.inc2"].text, "INC 2 Shrine")
end)
```

Append to `tests/test_dial.lua`:
```lua
test("dial: [phase 5] Arathi Basin's node wedges sit on their winds: Lumber Mill is SW, Blacksmith N", function()
    local NS, m = live(AB)
    bindG(NS)
    m.__pressKey("G")
    local ring = NS.Dial.ShownRing("d2")
    local function at(title)
        local _, _, _, x, y = wedgeTitled(NS, ring, title):GetPoint(1)
        return x .. "," .. y
    end
    local sw, n = NS.DialLayout.Wedge(6, 8), NS.DialLayout.Wedge(1, 8)
    assertEqual(at("Lumber Mill"), sw.x .. "," .. sw.y)
    assertEqual(at("Blacksmith"), n.x .. "," .. n.y)
end)

test("dial: [review 6] on a four- or six-slice dial every node shows, and the number keys pick the shown wedges from N", function()
    for _, slices in ipairs({ 4, 6 }) do
        local NS, m = live(AB)
        assertTrue(NS.SchemaRuntime.Set("dial.slices", slices, "d2"))
        bindG(NS)
        m.__pressKey("G")
        local r = NS.Dial.ShownRing("d2")
        assertEqual(ringTitle(NS), "Arathi Basin")
        assertEqual(#NS.Dial.RingWedges("d2", r), 5, slices .. " slices: five nodes, no More")
        -- clockwise from N: Blacksmith (N), Gold Mine (NE), Farm (SE), Lumber Mill (SW), Stables (NW)
        m.__pressKey("4")
        assertEqual(ringTitle(NS), "Lumber Mill", slices .. " slices: key 4 is the fourth wedge shown")
        m.__pressKey("3")
        assertEqual(m.sentMacros[#m.sentMacros].text, "/i INC 3 Lumber Mill")
    end
end)
```

In `tests/test_page_dials.lua`, in the case "dials page: Preview lists the rings wedge by wedge, marking the one the dial opens on", replace
```lua
    assertTrue(P.hasText(w, "Arathi Basin (1 of 2) (opens here)"))
    assertTrue(P.hasText(w, "  2 E: Lumber Mill, opens a ring"))
```
with
```lua
    -- phase 5: the nodes are pinned to their winds, on one eight-wedge ring (spec §12.1)
    assertTrue(P.hasText(w, "Arathi Basin (opens here)"))
    assertTrue(P.hasText(w, "  4 SW: Lumber Mill, opens a ring"))
```

- [ ] **Step 2: Run them to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in `test_dial_layout` (`PinNodes` is nil), `test_builtins` (no wind), `test_dial` (Lumber Mill sits at E) and `test_page_dials` (the paged ring).

- [ ] **Step 3: The winds**

In `defaults/BuiltIns_Battlegrounds.lua`, replace
```lua
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
```
with
```lua
-- A battleground whose callouts are one ring per node. Each node is { key, name, wind }: the wind is
-- the node's compass direction on the map (N, NE … NW, or "middle"), which pins its wedge on the dial
-- (spec §12.1; modules/Dial_Layout.lua PinNodes). The winds are derived from the client's own AreaPOI
-- table (build 12.1.5.70340, via wago.tools, 2026-10-13) by tools/derive-winds.py, which also checks
-- the lists below: each node's map position against the center of the battleground's nodes, north up;
-- a node within a third of the farthest node's distance from that center is the middle. Smoke check
-- BG-1 confirms them in game.
local function nodeBattleground(key, name, ids, nodes)
    local id = "bi.bg." .. key
    local children = {}
    for n, node in ipairs(nodes) do
        local nodeId = id .. "." .. node[1]
        local rows = {}
        for i, r in ipairs(INC) do rows[i] = { r[1], r[2], r[3]:format(node[2]) } end
        BI.Group(nodeId, { name = node[2], parent = id, compass = node[3],
            callouts = BI.Callouts(nodeId, "smartGroup", rows) })
        children[n] = nodeId
    end
```
and replace
```lua
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
```
with
```lua
nodeBattleground("ab", L["Arathi Basin"], { 529, 2107, 1681 }, {
    { "stables", L["Stables"], "NW" }, { "lumbermill", L["Lumber Mill"], "SW" },
    { "blacksmith", L["Blacksmith"], "middle" }, { "mine", L["Gold Mine"], "NE" }, { "farm", L["Farm"], "SE" },
})
nodeBattleground("eots", L["Eye of the Storm"], { 566, 968 }, {
    { "felreaver", L["Fel Reaver Ruins"], "SW" }, { "bloodelf", L["Blood Elf Tower"], "SE" },
    { "draenei", L["Draenei Ruins"], "NE" }, { "magetower", L["Mage Tower"], "NW" }, { "flag", L["the flag"], "middle" },
})
nodeBattleground("bfg", L["Battle for Gilneas"], { 761 }, {
    { "lighthouse", L["Lighthouse"], "W" }, { "waterworks", L["Waterworks"], "SE" }, { "mines", L["Mines"], "NE" },
})
-- Deepwind Gorge has five nodes on its current map (2245): Shrine and Ruins joined Market, Farm and
-- Quarry (the client's AreaPOI table, as above).
nodeBattleground("dwg", L["Deepwind Gorge"], { 1105, 2245 }, {
    { "market", L["Market"], "middle" }, { "farm", L["Farm"], "NE" }, { "quarry", L["Quarry"], "NW" },
    { "shrine", L["Shrine"], "SE" }, { "ruins", L["Ruins"], "SW" },
})
nodeBattleground("ioc", L["Isle of Conquest"], { 628 }, {
    { "docks", L["Docks"], "W" }, { "hangar", L["Hangar"], "E" }, { "workshop", L["Workshop"], "middle" },
    { "quarry", L["Quarry"], "SE" }, { "refinery", L["Refinery"], "NW" },
})
```

- [ ] **Step 4: Pinned rings**

In `modules/Dial_Layout.lua`, replace
```lua
-- THE GEOMETRY. Wedges sit clockwise from N, on-axis first: four are N, E, S and W. Offsets are from
-- the hub's center, y up. A node set's nodes are placed in their shipped order; pinning each node to
-- its compass direction waits for phase 5's battleground confirmation.
```
with
```lua
-- THE GEOMETRY. Wedges sit clockwise from N, on-axis first: four are N, E, S and W. Offsets are from
-- the hub's center, y up. A node set's nodes are pinned to their compass winds (spec §12.1): its ring
-- takes eight wedges, whatever the dial's slices, and is never paged; each node sits on its own wind
-- (PinNodes), a middle node on the first wind left free clockwise from N, and a wind with no node has
-- no wedge. An item carries `wedge`, its place among the ring's `size`; an unpinned item's place is
-- its index. The number keys pick the shown wedges clockwise from N.
```
replace
```lua
local SLICE_OK = { [4] = true, [6] = true, [8] = true, [12] = true }
local WINDS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
```
with
```lua
local SLICE_OK = { [4] = true, [6] = true, [8] = true, [12] = true }
local WINDS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

--- The eight winds' wedges on a pinned ring; a node in the middle of the map has DL.MIDDLE.
DL.WIND_INDEX = { N = 1, NE = 2, E = 3, SE = 4, S = 5, SW = 6, W = 7, NW = 8 }
DL.MIDDLE = "middle"
```
replace
```lua
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
```
with
```lua
local function ringEntry(title, icon, entries, pinned)
    return { kind = "ring", title = title, icon = icon, sub = { title = title, entries = entries, pinned = pinned } }
end

--- A node set's nodes on their compass winds (spec §12.1): each entry's `wind` (N, NE … NW, or
--- DL.MIDDLE) names its wedge on an eight-wedge ring, and a middle node takes the first wind left free,
--- clockwise from N. Answers the entries, each given its `wedge`, in wedge order; nil when they cannot
--- all be pinned (a node with no wind or an unknown one, two on one wind, none, or more than eight).
--- @return table[]|nil
function DL.PinNodes(entries)
    if type(entries) ~= "table" or #entries == 0 or #entries > 8 then return nil end
    local taken, middle = {}, {}
    for _, e in ipairs(entries) do
        local w = DL.WIND_INDEX[e.wind]
        if w and taken[w] then return nil end
        if w then
            taken[w] = e
        elseif e.wind == DL.MIDDLE then
            middle[#middle + 1] = e
        else
            return nil
        end
    end
    local free = 1
    for _, e in ipairs(middle) do
        while taken[free] do free = free + 1 end
        taken[free] = e
    end
    local out = {}
    for w = 1, 8 do
        if taken[w] then
            taken[w].wedge = w
            out[#out + 1] = taken[w]
        end
    end
    return out
end

-- A group's entry on the first ring (Categories), or nil when nothing under it can be shown. A node
-- set's nodes are pinned to their winds when every one of them has one.
local function groupEntry(g)
    if type(g.children) == "table" then
        local nodes = {}
        for _, c in ipairs(g.children) do
            if #(c.slots or {}) > 0 then
                local node = ringEntry(c.title, c.icon, sendEntries(c.slots))
                node.wind = c.compass
                nodes[#nodes + 1] = node
            end
        end
        if #nodes == 0 then return nil end
        local pinned = DL.PinNodes(nodes)
        return ringEntry(g.title, g.icon, pinned or nodes, pinned ~= nil)
    end
```
replace
```lua
    -- Add `entries` as one ring (and its pages) under `parent`, at `depth`; then each ring entry's
    -- own ring, one deeper. Returns the index of the first page.
    local function addRing(title, entries, parent, depth)
        local hasChildren = #entries > slices
        for _, e in ipairs(entries) do
            if e.kind == "ring" then hasChildren = true end
        end
        local size = DL.RingSize(slices, hasChildren)
        local pages = DL.Paginate(entries, size)
```
with
```lua
    -- A ring's wedge count and pages: a pinned ring (a node set's, PinNodes) has eight wedges and one
    -- page; any other has the dial's slices (RingSize), its items paged behind More.
    local function shape(entries, pinned)
        if pinned then return 8, { entries } end
        local hasChildren = #entries > slices
        for _, e in ipairs(entries) do
            if e.kind == "ring" then hasChildren = true end
        end
        local size = DL.RingSize(slices, hasChildren)
        return size, DL.Paginate(entries, size)
    end

    -- Add `entries` as one ring (and its pages) under `parent`, at `depth`; then each ring entry's
    -- own ring, one deeper. Returns the index of the first page.
    local function addRing(title, entries, parent, depth, pinned)
        local size, pages = shape(entries, pinned)
```
(the rest of `addRing`, from `local first = #rings + 1`, is unchanged) and replace
```lua
                    item.target = addRing(item.sub.title, item.sub.entries, r, depth + 1)
```
with
```lua
                    item.target = addRing(item.sub.title, item.sub.entries, r, depth + 1, item.sub.pinned)
```

- [ ] **Step 5: The plan, the frames and the Preview tab carry the wind**

In `modules/Surfaces.lua` (`S.BuildDialPlan`), replace
```lua
                    entry.children[#entry.children + 1] = { id = child, title = c.name, icon = c.icon,
                        slots = slotsOf(c.callouts) }
```
with
```lua
                    entry.children[#entry.children + 1] = { id = child, title = c.name, icon = c.icon,
                        compass = c.compass, slots = slotsOf(c.callouts) }
```

In `modules/Dial.lua`, replace
```lua
-- One ring's wedges: placed on their compass points, painted, armed, indexed by callout.
local function placeWedges(inst, ring, spec)
    local wedges = {}
    for i, item in ipairs(spec.items) do
        local w = NS.Pool.Acquire(ring.qcWedges, function() return newWedge(inst, ring) end)
        local geo = DL.Wedge(i, spec.size)
```
with
```lua
-- One ring's wedges: placed on their compass points (a pinned node on its own wind, Dial_Layout's
-- `wedge`), painted, armed, indexed by callout.
local function placeWedges(inst, ring, spec)
    local wedges = {}
    for i, item in ipairs(spec.items) do
        local w = NS.Pool.Acquire(ring.qcWedges, function() return newWedge(inst, ring) end)
        local geo = DL.Wedge(item.wedge or i, spec.size)
```

In `settings/Dials.lua` (`DD.PreviewLines`; phase 4's fix wave gave the line a `local dir` and an o'clock fallback), replace
```lua
            local dir = NS.DialLayout.Direction(i, ring.size)
```
with
```lua
            local dir = NS.DialLayout.Direction(item.wedge or i, ring.size)
```
(The line after it, `out[#out + 1] = L["  %d %s: %s"]:format(i, DIRECTION[dir] or L["%s o'clock"]:format(dir), what)`, is unchanged: the number stays the wedge's place in the shown order, which is the number key that picks it, and the direction is its wind.)

Append to `locales/enUS.lua`:
```lua
-- defaults/BuiltIns_Battlegrounds.lua: Deepwind Gorge's two newer nodes (phase 5)
L["Shrine"] = "Shrine"
L["Ruins"] = "Ruins"
```

- [ ] **Step 6: The winds' generator; a mismatch stops the task**

Create `tools/derive-winds.py`:
```python
# tools/derive-winds.py — derive each battleground node's compass wind from the client's AreaPOI table
# and check defaults/BuiltIns_Battlegrounds.lua against it (spec §12.1). Dev-only: never loaded by the
# client or the TOC, and .pkgmeta-ignored (layout-§1, "Where an authored generator lives"). Python 3,
# standard library only.
#
#   python3 -I tools/derive-winds.py --fetch DIR    download AreaPOI into DIR (a new directory)
#   python3 -I tools/derive-winds.py DIR            derive from DIR and check; exit 1 on any mismatch
#
# A node's wind: its position (Pos_0 is north, Pos_1 west) against the center of its set's nodes,
# north up, the nearest of eight; a node within a third of the farthest node's distance from that
# center is "middle". Each node is named by its AreaPOI id with the name that row must carry, so a
# wrong id fails rather than placing the wrong point. Every node defaults/ ships must be below, and
# every node below must be shipped with the wind derived here.
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import client_tables as ct  # noqa: E402

# set key -> (map id, [(node key, AreaPOI id, the POI's name)])
NODES = {
    "ab": (2107, [("stables", 6080, "Stables"), ("lumbermill", 6078, "Lumber Mill"),
                  ("blacksmith", 6079, "Blacksmith"), ("mine", 6076, "Gold Mine"), ("farm", 6077, "Farm")]),
    "eots": (566, [("felreaver", 1944, "Fel Reaver Ruins"), ("bloodelf", 1941, "Blood Elf Tower"),
                   ("draenei", 1950, "Draenei Ruins"), ("magetower", 1947, "Mage Tower"),
                   ("flag", 1962, "Netherstorm Flag")]),
    "bfg": (761, [("lighthouse", 2412, "Lighthouse"), ("waterworks", 2405, "Waterworks"), ("mines", 2404, "Mines")]),
    "dwg": (2245, [("market", 6544, "Market"), ("farm", 6546, "Farm"), ("quarry", 6543, "Quarry"),
                   ("shrine", 6545, "Shrine"), ("ruins", 6547, "Ruins")]),
    "ioc": (628, [("docks", 2356, "Docks"), ("hangar", 2350, "Hangar"), ("workshop", 2345, "Workshop"),
                  ("quarry", 2361, "Quarry"), ("refinery", 2366, "Refinery")]),
}
WINDS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
SHIPPED = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "defaults", "BuiltIns_Battlegrounds.lua")


def winds_of(poi, mapid, nodes):
    pos = {}
    for key, pid, name in nodes:
        r = poi.get(pid)
        if r is None:
            ct.fail("AreaPOI has no row {} ({})".format(pid, name))
        if int(r["ContinentID"]) != mapid or r["Name_lang"] != name:
            ct.fail("AreaPOI {} is '{}' on map {}, not '{}' on {}".format(
                pid, r["Name_lang"], r["ContinentID"], name, mapid))
        pos[key] = (float(r["Pos_0"]), float(r["Pos_1"]))
    cx = sum(p[0] for p in pos.values()) / len(pos)
    cy = sum(p[1] for p in pos.values()) / len(pos)
    far = max(math.hypot(x - cx, y - cy) for x, y in pos.values())
    out = {}
    for key, (x, y) in pos.items():
        north, east = x - cx, -(y - cy)
        a = (math.degrees(math.atan2(east, north)) + 360) % 360
        out[key] = "middle" if math.hypot(north, east) < far / 3 else WINDS[int((a + 22.5) // 45) % 8]
    return out


def shipped():
    text = open(SHIPPED, encoding="utf-8").read()
    out = {}
    for key, body in re.findall(r'nodeBattleground\("(\w+)".*?\{(.*?)\n\}\)', text, re.S):
        out[key] = dict(re.findall(r'\{ "(\w+)", L\["[^"]+"\], "(\w+)" \}', body))
    if not out:
        ct.fail("no nodeBattleground(...) in " + SHIPPED)
    return out


def main(argv):
    if len(argv) == 3 and argv[1] == "--fetch":
        print("fetched build " + str(ct.fetch(argv[2], ["AreaPOI"])))
        return
    if len(argv) != 2:
        ct.fail("usage: derive-winds.py --fetch DIR | derive-winds.py DIR")
    poi = {int(r["ID"]): r for r in ct.read(argv[1], "AreaPOI")}
    have, bad = shipped(), []
    if set(have) != set(NODES):
        bad.append("node sets shipped {} but derived {}".format(sorted(have), sorted(NODES)))
    for setkey, (mapid, nodes) in NODES.items():
        got = winds_of(poi, mapid, nodes)
        print(setkey + ": " + ", ".join("{} {}".format(k, got[k]) for k, _, _ in nodes))
        if have.get(setkey, {}) != got:
            bad.append("{}: shipped {}, derived {}".format(setkey, have.get(setkey), got))
    for b in bad:
        print("MISMATCH: " + b, file=sys.stderr)
    if bad:
        sys.exit(1)
    print("OK: {} node sets".format(len(NODES)))


if __name__ == "__main__":
    main(sys.argv)
```

Run it against a fresh download (a new scratch directory; the data is read only by `csv`):
```bash
D="$(mktemp -d)/poi"
python3 -I tools/derive-winds.py --fetch "$D"
python3 -I tools/derive-winds.py "$D"; echo "exit $?"
```
Expected: `fetched build 12.1.5.70340` (or later: say which in the commit message), then one line per set with the winds listed above (`ab: stables NW, lumbermill SW, blacksmith middle, mine NE, farm SE` …), `OK: 5 node sets` and `exit 0`. Any `MISMATCH:` or `FAIL:` line, or a non-zero exit, stops the task: report the lines to the owner, and never edit a wind or a POI id to make it pass.

- [ ] **Step 7: Run the gate and the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: PASS (including phase 4's `[exit]` case "in Arathi Basin the dial opens on the nodes; Lumber Mill, then INC 3, sends in two clicks", the two `[review 6]` cases, and `test_builtins`' bake audit over Deepwind Gorge's twelve new callouts), 0 / 0, `0 warnings` (`addRing` stays at 15 or under because its ring shape is the separate `shape` helper).

- [ ] **Step 8: Commit**

```bash
git add defaults/BuiltIns_Battlegrounds.lua modules/Dial_Layout.lua modules/Surfaces.lua modules/Dial.lua settings/Dials.lua locales/enUS.lua tests/test_dial_layout.lua tests/test_builtins.lua tests/test_dial.lua tests/test_page_dials.lua tools/derive-winds.py
rm tools/derive-winds.py && git checkout -- tools/derive-winds.py
git checkout -- defaults/BuiltIns_Battlegrounds.lua modules/Dial_Layout.lua modules/Surfaces.lua modules/Dial.lua settings/Dials.lua locales/enUS.lua tests/test_dial_layout.lua tests/test_builtins.lua tests/test_dial.lua tests/test_page_dials.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Dial: battleground nodes pinned to their compass winds (tools/derive-winds.py); Deepwind Gorge's five nodes"
```

---
### Task 8: The pad's Look: font, border and background, with their class-color companions

Spec §10.3 and §19 row 5 (options-ui-§16, §17). Three composed groups join the Look tab under their own headings: the font block (Font, Font size, Font color with Use class color, Font flags, Font shadow), the border block (Border style, Border thickness, Border color with Use class color) and the background swatch with its companion. They are `pad.look.*` member rows written through the seam, defaulting to the skin a pad already wore. `Pad_Render` turns a Look into two plain values (a font and a skin) through two new seams, `NS.ResolveColor` (LibKa0s Core's one class-color resolver, with a degraded stub) and `NS.MediaFetch` (a LibSharedMedia entry by name, nil when it is not on this machine), and `Pad.Apply` wears them at every rebuild, out of combat. Prepare fills the new fields into a pad saved before they existed.

**Files:**
- Modify: `modules/Library.lua` (`SURFACE_DEFAULTS.pad.look`, `fillShape`, `repairSurface` and its caller), `settings/Schema.lua` (`VALID_TYPES` and its comment), `settings/SchemaMembers.lua` (`WHY`, the Look groups), `core/CoreSetup.lua` (two places), `core/MediaSetup.lua` (header, `NS.MediaFetch`), `modules/Pad_Render.lua` (header, three functions), `modules/Pad.lua` (header, `place`, `Pad.Apply`), `settings/Pads.lua` (header, `renderLook`), `tests/wow_mock.lua` (the region's `SetFont`, `SetShadowOffset`), `locales/enUS.lua`
- Test: `tests/test_pad_render.lua`, `tests/test_pad.lua`, `tests/test_page_pads.lua`, `tests/test_members.lua`, `tests/test_library.lua`

**Interfaces:**
- Consumes: `Settings.Helpers.FontGroup(spec)`, `.BorderGroup(spec)`, `.ColorPair(spec)`, `.FONT_FLAGS` (LibKa0s-Options, hollow on a degraded load); LibKa0s Core `ResolveColor(stored, on, unit)`; `LibSharedMedia-3.0:Fetch(kind, name, noDefault)`; `NS.SKIN`, `NS.ApplySkin(frame, skin)`.
- Produces:
  - member rows `pad.look.font`, `.fontSize` (6–32), `.fontColor`, `.useClassColorFont`, `.fontFlags`, `.fontShadow`, `.borderStyle`, `.borderSize` (0–16), `.borderColor`, `.useClassColorBorder`, `.background`, `.useClassColorBackground`, each `page = "pads"`, `group = "Look"`, `subgroup` "Font", "Border" or "Background"; the row type `color`.
  - `NS.ResolveColor(stored, on, unit) -> r, g, b, a`; `NS.MediaFetch(kind, name) -> path|nil`.
  - `PadRender.LabelFont(look) -> { path, size, flags, r, g, b, a, shadow, colored }`, `PadRender.TitleFont(font) -> font` (the title's gold unless `colored`), `PadRender.TITLE_COLOR`, `PadRender.ApplyFont(fs, font)`, `PadRender.SkinFor(look) -> skin` (a copy of `NS.SKIN` with `edgeFile`, `edgeSize`, `insets`, `border`, `bg`).
  - `Settings.Pads.LOOK_GROUPS`, `Settings.Pads.LookRows(rows, subgroup)`.

- [ ] **Step 1: Write the failing tests**

In `tests/wow_mock.lua` (the region a frame under a `QuickComms` root gets), replace
```lua
        function r:SetTextColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
```
with
```lua
        function r:SetTextColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        -- A font string's face, recorded; true as the client answers for a face it accepts.
        function r:SetFont(path, size, flags) self.__font = { path, size, flags } return true end
        function r:SetShadowOffset(x, y) self.__shadow = { x, y } return self end
```

Append to `tests/test_pad_render.lua`:
```lua
test("render: [phase 5] a pad's Look is a font and a skin; the defaults are the skin a pad always wore", function()
    local NS, m = T.enableAddon()
    m.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    local R, look = NS.PadRender, NS.Library.TEMPLATES.pad.look
    local font = R.LabelFont(look)
    assertEqual(font.path, "Fonts\\FRIZQT__.TTF", "no LibSharedMedia here: the standard face")
    assertEqual(font.size .. "|" .. font.flags .. "|" .. tostring(font.shadow), "10||true")
    assertEqual(font.r + font.g + font.b + font.a, 4, "white")
    local skin = R.SkinFor(look)
    assertEqual(skin.edgeFile, "Interface\\Buttons\\WHITE8x8", "None is the flat Ka0s edge")
    assertEqual(skin.edgeSize, 1)
    assertEqual(table.concat(skin.bg, ","), "0.06,0.06,0.08,0.92")
    assertEqual(table.concat(skin.border, ","), "0,0,0,1")
    assertNil(R.SkinFor({ borderSize = 0 }).edgeFile, "thickness 0 is no edge")
    local fs = chip(NS, m).qcLabel
    R.ApplyFont(fs, R.LabelFont({ fontSize = 14, fontFlags = "OUTLINE", fontShadow = false,
        fontColor = { r = 1, g = 0, b = 0, a = 1 } }))
    assertEqual(table.concat(fs.__font, ","), "Fonts\\FRIZQT__.TTF,14,OUTLINE")
    assertEqual(table.concat(fs.__color, ","), "1,0,0,1")
    assertEqual(table.concat(fs.__shadow, ","), "0,0")
end)

test("render: [phase 5] Use class color takes the player's class color and keeps the swatch's alpha", function()
    local NS, m = T.enableAddon()
    m.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.75, b = 0.5 } }
    local font = NS.PadRender.LabelFont({ fontColor = { r = 1, g = 1, b = 1, a = 0.5 }, useClassColorFont = true })
    assertEqual(font.r .. "," .. font.g .. "," .. font.b .. "," .. font.a, "0.25,0.75,0.5,0.5")
    local skin = NS.PadRender.SkinFor({ background = { r = 0, g = 0, b = 0, a = 0.8 }, useClassColorBackground = true })
    assertEqual(table.concat(skin.bg, ","), "0.25,0.75,0.5,0.8")
    assertEqual(table.concat(NS.PadRender.SkinFor({ borderColor = { 0.1, 0.2, 0.3 } }).border, ","), "0.1,0.2,0.3,1",
        "a positional swatch, alpha 1 by default")
end)

test("render: [phase 5] a section title keeps its gold until the player colors the font", function()
    local NS, m = T.enableAddon()
    m.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.75, b = 0.5 } }
    local R = NS.PadRender
    -- red under: apply the label font to the titles in modules/Pad.lua's place() (they turn white)
    local t = R.TitleFont(R.LabelFont(NS.Library.TEMPLATES.pad.look))
    assertEqual(t.r .. "," .. t.g .. "," .. t.b .. "|" .. t.size, "1,0.82,0|10", "the default Look: gold, as before")
    t = R.TitleFont(R.LabelFont({ fontSize = 12, fontColor = { r = 1, g = 0, b = 0, a = 1 } }))
    assertEqual(t.r .. "," .. t.g .. "," .. t.b .. "|" .. t.size, "1,0,0|12", "a chosen color reaches the titles")
    t = R.TitleFont(R.LabelFont({ fontColor = { r = 1, g = 1, b = 1, a = 1 }, useClassColorFont = true }))
    assertEqual(t.r .. "," .. t.g .. "," .. t.b, "0.25,0.75,0.5", "and so does the class color")
end)
```

Append to `tests/test_pad.lua`:
```lua
-- A LibSharedMedia with one font and one border, loaded before the addon reads it (core/MediaSetup.lua).
local function withMedia(mm)
    local lsm = mm.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
    local media = { font = { Arial = "Fonts\\ARIALN.TTF" }, border = { Tooltip = "Interface\\Tooltips\\UI-Tooltip-Border" } }
    function lsm.Register() end
    function lsm.IsValid() return true end
    function lsm.HashTable(_, kind) return media[kind] or {} end
    function lsm.Fetch(_, kind, name) return media[kind] and media[kind][name] end
    lsm.MediaType = {}
end

test("pad: [phase 5] the pad wears its Look: the chips' font and the edge and body it was given", function()
    local NS = T.enableAddon{ mock = withMedia }
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local skins = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin) skins[frame] = skin return apply(frame, skin) end
    local S = NS.SchemaRuntime
    assertTrue(S.Set("pad.look.font", "Arial", "p1"))
    assertTrue(S.Set("pad.look.fontSize", 13, "p1"))
    assertTrue(S.Set("pad.look.borderStyle", "Tooltip", "p1"))
    assertTrue(S.Set("pad.look.background", { r = 0.2, g = 0.1, b = 0, a = 1 }, "p1"))
    local label = NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1].qcLabel
    assertEqual(label.__font[1] .. "," .. label.__font[2], "Fonts\\ARIALN.TTF,13")
    local skin = skins[NS.Pad.Instance("p1").root]
    assertEqual(skin.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border")
    assertEqual(table.concat(skin.bg, ","), "0.2,0.1,0,1")
end)

test("pad: [review 5] a font or border this machine does not have draws the default, with no error", function()
    local NS, m = T.enableAddon{ mock = withMedia }
    m.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    NS.Situation.ReadInputs = function() return MPLUS end
    NS.Situation.RefreshNow("test")
    local skins = {}
    local apply = NS.ApplySkin
    NS.ApplySkin = function(frame, skin) skins[frame] = skin return apply(frame, skin) end
    -- a shared pad, or a media addon since removed: the names are stored, the media is not here
    assertTrue(NS.SchemaRuntime.Set("pad.look.font", "Gone Font", "p1"))
    assertTrue(NS.SchemaRuntime.Set("pad.look.borderStyle", "Gone Border", "p1"))
    local label = NS.Pad.ChipsFor("p1", "bi.mplus.pull")[1].qcLabel
    assertEqual(label.__font[1], "Fonts\\FRIZQT__.TTF")
    assertEqual(skins[NS.Pad.Instance("p1").root].edgeFile, "Interface\\Buttons\\WHITE8x8")
end)
```

Append to `tests/test_page_pads.lua`:
```lua
test("pads page: [phase 5] Look carries the composed Font, Border and Background groups under their headings", function()
    local NS, _, P = open()
    local w = P.tab("pads", "Look")
    for _, heading in ipairs({ "Font", "Border", "Background" }) do
        assertTrue(P.find(w, "Heading", heading) ~= nil, heading)
    end
    assertEqual(#P.all(w, "CheckBox", "Use class color"), 3, "a companion beside each swatch (options-ui-§17)")
    assertTrue(P.find(w, "ColorPicker", "Font color") ~= nil)
    assertTrue(P.find(w, "ColorPicker", "Border color") ~= nil)
    assertTrue(P.find(w, "ColorPicker", "Background") ~= nil)
    P.find(w, "CheckBox", "Font shadow"):__fire("OnValueChanged", false)
    assertFalse(NS.db.profile.pads.p1.look.fontShadow)
end)
```

Append to `tests/test_members.lua`:
```lua
test("members: [phase 5] a pad's Look rows are composed member rows: checked, clamped, announced", function()
    local NS, S, Lib = boot()
    local pid = Lib.CreateSurface("pad", "Mine")
    local out = heard(NS)
    assertTrue(S.Set("pad.look.fontSize", 99, pid))
    assertEqual(NS.db.profile.pads[pid].look.fontSize, 32, "clamped to the row's range")
    local ok, _, why = S.Set("pad.look.borderColor", { r = 2, g = 0, b = 0 }, pid)
    assertFalse(ok)
    assertEqual(why, "A color is red, green and blue, and optionally alpha, each from 0 to 1.")
    assertFalse((S.Set("pad.look.fontFlags", "SPARKLY", pid)))
    assertTrue(S.Set("pad.look.fontFlags", "OUTLINE", pid))
    assertTrue(S.Set("pad.look.useClassColorBorder", true, pid))
    assertEqual(table.concat(out, ","), "pad:" .. pid .. ",pad:" .. pid .. ",pad:" .. pid)
    local row = S.FindRow("pad.look.background")
    assertEqual(row.classColorSource, "player", "a pad's text and chrome describe no unit")
end)
```

Append to `tests/test_library.lua`:
```lua
test("library: [phase 5] Prepare gives a pad saved before the Look groups every field it lacks", function()
    local NS, Lib, p = boot()
    local pad = p.pads[p.padOrder[1]]
    pad.look = { visibility = "never" }
    pad.layout.width = nil
    Lib.Prepare()
    assertEqual(pad.look.visibility, "never", "a stored value is kept")
    assertEqual(pad.look.font, "Friz Quadrata TT")
    assertEqual(pad.look.background.a, 0.92)
    assertEqual(pad.layout.width, 140)
    assertTrue(pad.look.background ~= NS.Library.TEMPLATES.pad.look.background, "a copy, never the template")
end)
```

- [ ] **Step 2: Run them to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in the eight new cases (`LabelFont` is nil, no `pad.look.font` row, no Font heading, Prepare leaves `look.font` nil).

- [ ] **Step 3: The defaults and Prepare's fill**

In `modules/Library.lua`, replace
```lua
    pad = { groupsAs = "sections", layout = { orientation = "horizontal", columns = 4, growth = "right",
        style = "iconLabel", scale = 1.0, spacing = 4, width = 140 },
        look = { visibility = "always", fade = "none", fadeAlpha = 0.4 } },
```
with
```lua
    -- look: the Look tab's rows (settings/SchemaMembers.lua). The font, border and background rows
    -- (phase 5, options-ui-§16/§17) default to the Ka0s skin a pad has always worn: the chip label's
    -- small white face with its shadow, a flat 1px black edge ("None" is no border art) and the
    -- 0.06, 0.06, 0.08, 0.92 body (spec §10.1).
    pad = { groupsAs = "sections", layout = { orientation = "horizontal", columns = 4, growth = "right",
        style = "iconLabel", scale = 1.0, spacing = 4, width = 140 },
        look = { visibility = "always", fade = "none", fadeAlpha = 0.4,
            font = "Friz Quadrata TT", fontSize = 10, fontColor = { r = 1, g = 1, b = 1, a = 1 },
            useClassColorFont = false, fontFlags = "", fontShadow = true,
            borderStyle = "None", borderSize = 1, borderColor = { r = 0, g = 0, b = 0, a = 1 },
            useClassColorBorder = false,
            background = { r = 0.06, g = 0.06, b = 0.08, a = 0.92 }, useClassColorBackground = false } },
```
replace (Task 1's `repairSurface`)
```lua
-- One pad or dial: its lists as tables, its dangling groups dropped, and each built-in it has not
-- been offered yet appended once (seenBuiltins).
local function repairSurface(s, result)
    s.seenBuiltins = type(s.seenBuiltins) == "table" and s.seenBuiltins or {}
```
with
```lua
-- A stored surface's settings tables (a pad's layout and look) with every field its kind's defaults
-- have that it lacks: a pad saved before a field existed (the Look tab's font, border and background,
-- phase 5) reads like a new one.
local function fillShape(s, kind)
    for key, defaults in pairs(SURFACE_DEFAULTS[kind]) do
        if type(defaults) == "table" then
            if type(s[key]) ~= "table" then s[key] = {} end
            for field, v in pairs(defaults) do
                if s[key][field] == nil then s[key][field] = copyTable(v) end
            end
        end
    end
end

-- One pad or dial: its lists as tables, its dangling groups dropped, each built-in it has not been
-- offered yet appended once (seenBuiltins), and its settings tables filled (fillShape).
local function repairSurface(s, kind, result)
    fillShape(s, kind)
    s.seenBuiltins = type(s.seenBuiltins) == "table" and s.seenBuiltins or {}
```
and in `Lib.Prepare` replace
```lua
        for _, s in pairs(set) do repairSurface(s, result) end
```
with
```lua
        for _, s in pairs(set) do repairSurface(s, kind, result) end
```

- [ ] **Step 4: The two seams**

In `core/CoreSetup.lua`, in the library-absent branch, replace
```lua
    NS.SKIN            = {}
    NS.ApplySkin       = function() end
    NS.MakeCloseButton = function() return nil end
    NS.MakeResizable   = function() return nil end
```
with
```lua
    NS.SKIN            = {}
    NS.ApplySkin       = function() end
    NS.MakeCloseButton = function() return nil end
    NS.MakeResizable   = function() return nil end
    -- The stored swatch, keyed or positional, and never the class color: there is no resolver.
    NS.ResolveColor    = function(c)
        if type(c) ~= "table" then return 1, 1, 1, 1 end
        return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1
    end
```
and in the live half replace
```lua
NS.SKIN          = lib.SKIN
NS.ApplySkin     = lib.ApplySkin
NS.MakeResizable = lib.MakeResizable
```
with
```lua
NS.SKIN          = lib.SKIN
NS.ApplySkin     = lib.ApplySkin
NS.MakeResizable = lib.MakeResizable

-- The one class-color resolver (options-ui-§17): a stored swatch through its "Use class color"
-- companion, the swatch's alpha kept, an unresolvable class falling through to the swatch.
NS.ResolveColor  = lib.ResolveColor
```

In `core/MediaSetup.lua`, replace
```lua
-- core/MediaSetup.lua — NS.Icon / NS.MediaFont from LibKa0s-Media-1.0 and the one RegisterLSM call.
```
with
```lua
-- core/MediaSetup.lua — NS.Icon / NS.MediaFont from LibKa0s-Media-1.0, the one RegisterLSM call, and
-- NS.MediaFetch, a LibSharedMedia entry by its name.
```
and replace
```lua
-- At FILE LOAD, not PLAYER_LOGIN: LibSharedMedia is vendored under libs/ and has already run.
if Media then Media.RegisterLSM(addonName) end
```
with
```lua
-- At FILE LOAD, not PLAYER_LOGIN: LibSharedMedia is vendored under libs/ and has already run.
if Media then Media.RegisterLSM(addonName) end

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

--- The path of a LibSharedMedia entry by its name (a pad's Look font or border style), or nil: no
--- LibSharedMedia, no such name on this machine (a media addon removed, a shared pad naming one this
--- player lacks). Nil is a real answer: the caller draws its default.
--- @param kind string "font" | "border" | "statusbar" | "background"
--- @param name string|nil
--- @return string|nil
function NS.MediaFetch(kind, name)
    if not (LSM and type(name) == "string" and name ~= "") then return nil end
    local ok, path = pcall(LSM.Fetch, LSM, kind, name, true)
    if ok and type(path) == "string" and path ~= "" then return path end
    return nil
end
```

- [ ] **Step 5: The rows**

In `settings/Schema.lua`, replace
```lua
-- `point`, `when`, `idset` and `key` are the structured member rows (settings/SchemaMembers.lua): each
-- drawn by its own control on its editor page (a dial's key by a capture box) and typed and printed on
-- the CLI by settings/Slash.lua's parse and format hooks.
local VALID_TYPES = { bool = true, number = true, string = true, point = true, when = true, idset = true,
    key = true }
```
with
```lua
-- `point`, `when`, `idset` and `key` are the structured member rows (settings/SchemaMembers.lua): each
-- drawn by its own control on its editor page (a dial's key by a capture box) and typed and printed on
-- the CLI by settings/Slash.lua's parse and format hooks. `color` is a pad's Look swatches (phase 5),
-- which the options library draws and its CLI parses and prints itself.
local VALID_TYPES = { bool = true, number = true, string = true, point = true, when = true, idset = true,
    key = true, color = true }
```

In `settings/SchemaMembers.lua`, replace
```lua
    badKey    = L["A key is one key, with ALT-, CTRL- or SHIFT- in front if you like."],
```
with
```lua
    badKey    = L["A key is one key, with ALT-, CTRL- or SHIFT- in front if you like."],
    badColor  = L["A color is red, green and blue, and optionally alpha, each from 0 to 1."],
```
and replace
```lua
-- Every member row's reaction: Library.Touch announces the write (LIBRARY_CHANGED, the pads' rebuild),
-- naming the row's path as the field.
```
with
```lua
-- ── a pad's Look groups (spec §10.3, §19 row 5; options-ui-§16, §17) ───────────────────────────

-- The font block, the border block and the background swatch with its class-color companion, each
-- COMPOSED by the options library (a hand-written copy is anti-pattern #73) and then stamped as pad
-- member rows: the instance, a check per leaf, and the defaults Library ships (Library.TEMPLATES).
-- The class color is the player's (`classColorSource = "player"`, the composer's default): a pad's
-- text is about no unit. A background is not a bar, so it takes a swatch and its companion only. On
-- a degraded load the composers are hollow and these rows are absent.

local function unit01(c) return type(c) == "number" and c >= 0 and c <= 1 end

-- A color as the color picker stores it, keyed ({ r, g, b, a }) or positional, alpha optional.
local function isColor(v)
    if type(v) ~= "table" then return false, "badColor" end
    local a = v.a or v[4] or 1
    return unit01(v.r or v[1]) and unit01(v.g or v[2]) and unit01(v.b or v[3]) and unit01(a), "badColor"
end

local function isName(v) return type(v) == "string" and v ~= "", "badChoice" end

local LOOK = "pad.look."
local LOOK_DEFAULTS = T.pad.look

local function lookChecks(O)
    local flags = O.FONT_FLAGS or {}
    return {
        font = { validate = check(isName) },
        fontSize = { validate = NUMBER, normalize = clamp(6, 32, true) },
        fontColor = { validate = check(isColor) },
        fontFlags = { validate = check(function(v) return type(v) == "string" and flags[v] ~= nil, "badChoice" end) },
        borderStyle = { validate = check(isName) },
        borderSize = { validate = NUMBER, normalize = clamp(0, 16, true) },
        borderColor = { validate = check(isColor) },
        background = { validate = check(isColor) },
    }
end

local function lookSpec(subgroup, extra)
    local spec = { prefix = LOOK, page = "pads", group = L["Look"], subgroup = subgroup, defaults = LOOK_DEFAULTS }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return spec
end

local function lookRows()
    local O = NS.addon.Settings.Helpers
    local checks = lookChecks(O)
    local out = {}
    for _, list in ipairs({
        O.FontGroup(lookSpec(L["Font"])),
        O.BorderGroup(lookSpec(L["Border"])),
        O.ColorPair(lookSpec(L["Background"], { key = "background", label = L["Background"] })),
    }) do
        for _, row in ipairs(list) do
            local c = checks[row.path:sub(#LOOK + 1)] or {}
            row.instance, row.validate, row.normalize = "pad", c.validate, c.normalize
            out[#out + 1] = row
        end
    end
    return out
end

for _, row in ipairs(lookRows()) do ROWS[#ROWS + 1] = row end

-- Every member row's reaction: Library.Touch announces the write (LIBRARY_CHANGED, the pads' rebuild),
-- naming the row's path as the field.
```

Append to `locales/enUS.lua`:
```lua
-- settings/SchemaMembers.lua: a pad's Look groups (phase 5)
L["A color is red, green and blue, and optionally alpha, each from 0 to 1."] = "A color is red, green and blue, and optionally alpha, each from 0 to 1."
L["Font"] = "Font"
L["Border"] = "Border"
L["Background"] = "Background"
```

- [ ] **Step 6: The render and the pad**

In `modules/Pad_Render.lua`, replace
```lua
-- bake was refused, a dim veil during the spam guard's window, a gold hover and a flash per send
-- result. The tooltip names the line it sends, or why it sends nothing, and any lock.
```
with
```lua
-- bake was refused, a dim veil during the spam guard's window, a gold hover and a flash per send
-- result. The tooltip names the line it sends, or why it sends nothing, and any lock. The pad's Look
-- (phase 5) is read here as two plain values, a font (LabelFont) and a skin (SkinFor), which
-- modules/Pad.lua applies out of combat.
```
and replace
```lua
function R.RefreshLock(btn)
    btn.qcLock:SetShown(btn.qcSlot ~= nil and btn.qcSlot.lock ~= nil)
end
```
with
```lua
function R.RefreshLock(btn)
    btn.qcLock:SetShown(btn.qcSlot ~= nil and btn.qcSlot.lock ~= nil)
end

-- ── the pad's Look (spec §10.3; options-ui-§16, §17) ────────────────────────────────────────

local FLAT_EDGE = "Interface\\Buttons\\WHITE8x8"

--- The font a pad's text is drawn in, from its Look: { path, size, flags, r, g, b, a, shadow, colored }.
--- A face this machine does not have is the standard one; "Use class color" takes the player's class
--- color, keeping the swatch's alpha (NS.ResolveColor). `colored` is whether the player chose a color:
--- Use class color, or a swatch other than the default white.
function R.LabelFont(look)
    look = type(look) == "table" and look or {}
    local r, g, b, a = NS.ResolveColor(look.fontColor, look.useClassColorFont)
    return { path = NS.MediaFetch("font", look.font) or STANDARD_TEXT_FONT, size = tonumber(look.fontSize) or 10,
        flags = type(look.fontFlags) == "string" and look.fontFlags or "", r = r, g = g, b = b, a = a,
        shadow = look.fontShadow ~= false,
        colored = look.useClassColorFont == true or r ~= 1 or g ~= 1 or b ~= 1 }
end

-- A section title's own color, the gold of the GameFontNormalSmall it is made with.
R.TITLE_COLOR = { 1, 0.82, 0, 1 }

--- A section title's font: the pad's face, size, flags and shadow, in the title's own gold unless the
--- player chose a color for the font (Use class color, or a swatch other than white). The default Look
--- then changes nothing a pad already showed: gold titles over white chip labels.
function R.TitleFont(font)
    if font.colored then return font end
    local t = {}
    for k, v in pairs(font) do t[k] = v end
    t.r, t.g, t.b, t.a = R.TITLE_COLOR[1], R.TITLE_COLOR[2], R.TITLE_COLOR[3], R.TITLE_COLOR[4]
    return t
end

--- Draw a font string in a pad's font (R.LabelFont). A face the client refuses falls back to the
--- standard one.
function R.ApplyFont(fs, font)
    if not (fs and font) then return end
    if not fs:SetFont(font.path, font.size, font.flags) then fs:SetFont(STANDARD_TEXT_FONT, font.size, font.flags) end
    fs:SetTextColor(font.r, font.g, font.b, font.a)
    if font.shadow then fs:SetShadowOffset(1, -1) else fs:SetShadowOffset(0, 0) end
end

--- The skin a pad wears, from its Look: the Ka0s skin (NS.SKIN) with the border's art (a LibSharedMedia
--- border by name; "None", or one this machine does not have, is the flat edge), its thickness (0 is
--- no edge) and color, and the background color, each through its class-color companion.
function R.SkinFor(look)
    look = type(look) == "table" and look or {}
    local skin = {}
    for k, v in pairs(NS.SKIN or {}) do skin[k] = v end
    local size = math.max(0, math.min(16, tonumber(look.borderSize) or 1))
    local art = look.borderStyle ~= "None" and NS.MediaFetch("border", look.borderStyle) or nil
    skin.edgeFile = size > 0 and (art or FLAT_EDGE) or nil
    skin.edgeSize = size
    skin.insets = { left = size, right = size, top = size, bottom = size }
    skin.border = { NS.ResolveColor(look.borderColor, look.useClassColorBorder) }
    skin.bg = { NS.ResolveColor(look.background, look.useClassColorBackground) }
    return skin
end
```

In `modules/Pad.lua`, replace
```lua
-- The root is a plain BackdropTemplate frame wearing the Ka0s skin (NS.ApplySkin); it becomes
-- protected in combat because its chips are secure. Every chip IS a send button (spec §9.1),
```
with
```lua
-- The root is a plain BackdropTemplate frame wearing the Ka0s skin (NS.ApplySkin), dressed at every
-- rebuild by the pad's Look (Pad_Render.SkinFor: border and background; Pad_Render.LabelFont: the
-- chips' and titles' font); it becomes protected in combat because its chips are secure. Every chip
-- IS a send button (spec §9.1),
```
replace
```lua
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
```
with
```lua
-- Every chip and section title of the layout, in the pad's font (its Look's font block); a title in
-- its own variant of it (R.TitleFont).
local function place(inst, box, style, font, titleFont)
    for _, item in ipairs(box.items) do
        if item.kind == "chip" then
            local btn = NS.Pool.Acquire(inst.chips, function() return newChip(inst) end)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", inst.root, "TOPLEFT", item.x, -item.y)
            btn:SetSize(item.w, item.h)
            R.Paint(btn, item.slot, style)
            R.ApplyFont(btn.qcLabel, font)
            arm(btn, item.slot)
            local list = inst.byCallout[item.slot.calloutId] or {}
            list[#list + 1] = btn
            inst.byCallout[item.slot.calloutId] = list
        else
            local fs = NS.Pool.Acquire(inst.titles, function() return newTitle(inst) end)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", inst.root, "TOPLEFT", item.x, -item.y)
            fs:SetText(R.SectionTitle(item))
            R.ApplyFont(fs, titleFont)
        end
    end
end
```
and in `Pad.Apply` replace
```lua
    inst.root:SetSize(box.width, box.height)
    place(inst, box, layout.style)
```
with
```lua
    inst.root:SetSize(box.width, box.height)
    NS.ApplySkin(inst.root, R.SkinFor(look))
    local font = R.LabelFont(look)
    place(inst, box, layout.style, font, R.TitleFont(font))
```

- [ ] **Step 7: The Look tab**

In `settings/Pads.lua`, replace
```lua
--     Look     visibility, fade and faded alpha
```
with
```lua
--     Look     visibility, fade and faded alpha; then Font (face, size, color with Use class color,
--              flags, shadow), Border (style, thickness, color with Use class color) and Background
--              (its color with Use class color), each composed by the options library (options-ui-§16,
--              §17) under its own heading
```
and replace
```lua
local function renderLook(ctx, rows)
    local h = H()
    if not selected() then
        h.TextRow(ctx, NONE)
        return
    end
    h.RenderRows(ctx, Ed.Scalar(rows), nil, nil, { noHeadings = true })
end
```
with
```lua
-- The Look tab's groups after its own rows, each under its heading (options-ui-§16: a tab with more
-- than one group says where one stops and the next starts). The subgroup is the composed rows' own.
PD.LOOK_GROUPS = { L["Font"], L["Border"], L["Background"] }

--- The rows of `rows` whose subgroup is `subgroup` (nil: the rows in no group), in order.
function PD.LookRows(rows, subgroup)
    local out = {}
    for _, row in ipairs(rows) do
        if row.subgroup == subgroup then out[#out + 1] = row end
    end
    return out
end

local function renderLook(ctx, rows)
    local h = H()
    if not selected() then
        h.TextRow(ctx, NONE)
        return
    end
    local scalar = Ed.Scalar(rows)
    h.RenderRows(ctx, PD.LookRows(scalar, nil), nil, nil, { noHeadings = true })
    for _, subgroup in ipairs(PD.LOOK_GROUPS) do
        local mine = PD.LookRows(scalar, subgroup)
        if #mine > 0 then
            h.Section(ctx, subgroup)
            h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })
        end
    end
end
```

- [ ] **Step 8: Run the gate and the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: PASS (including `test_setup`'s boot check, which resolves every new row against `Library.TEMPLATES.pad`, its degraded-load case, where the composers are hollow and the rows are absent, and `test_page_pads`' "Defaults puts the pad's rows back as one act"), 0 / 0, `0 warnings`.

- [ ] **Step 9: Commit**

```bash
git add modules/Library.lua settings/Schema.lua settings/SchemaMembers.lua core/CoreSetup.lua core/MediaSetup.lua modules/Pad_Render.lua modules/Pad.lua settings/Pads.lua tests/wow_mock.lua locales/enUS.lua tests/test_pad_render.lua tests/test_pad.lua tests/test_page_pads.lua tests/test_members.lua tests/test_library.lua
git checkout -- modules/Library.lua settings/Schema.lua settings/SchemaMembers.lua core/CoreSetup.lua core/MediaSetup.lua modules/Pad_Render.lua modules/Pad.lua settings/Pads.lua tests/wow_mock.lua locales/enUS.lua tests/test_pad_render.lua tests/test_pad.lua tests/test_page_pads.lua tests/test_members.lua tests/test_library.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Pads: the Look's composed font, border and background groups, with class-color companions"
```

---
### Task 9: The visual icon picker for callouts and groups

Spec §13.1 and §19 row 5. One editor helper draws a "Choose an icon" heading and a grid of icons under the Icon row; a click writes the member's icon row through the seam, and the Icon box above refreshes in place. The palette: the eight raid markers under their localized names; the game icons the built-in sets wear, read from `NS.BuiltIns` when the picker draws (a set's own icon, then its callouts'); then the LibKa0s icon catalog's entries that a short allowlist keeps, enumerated from the catalog through a new `NS.IconNames` seam (library-stack-§8: the media catalogs are enumerated, never a hard-coded list; the allowlist only picks among the names the catalog has, since most of it is window chrome). Each icon is stored by its path, as the box takes it; the catalog's marks are skipped without the library. A built-in set's General tab draws no picker (built-ins are read-only).

**Files:**
- Modify: `settings/Editors.lua` (a new section before the reorder lists), `core/MediaSetup.lua` (`NS.IconNames`), `settings/Callouts.lua` (header, `renderGeneral`), `settings/Groups.lua` (header, `renderGeneral`'s user-group half), `locales/enUS.lua`
- Test: `tests/test_page_callouts.lua`, `tests/test_page_groups.lua`

**Interfaces:**
- Consumes: `NS.Icon(name)` (core/MediaSetup.lua), LibKa0s Media's `ICONS` catalog, `NS.BuiltIns.order`, `.groups`, `.callouts`, the `callout.icon` and `group.icon` member rows, `NS.SchemaRuntime.Set`.
- Produces: `NS.IconNames() -> string[]`, `Ed.ICON_MARKERS` (the eight localized marker names), `Ed.ICON_MARK_KEEP` (the allowlist, a set of catalog names), `Ed.IconPalette() -> { { path, label } }`, `Ed.SetIcon(rowPath, id, path) -> boolean`, `Ed.IconPicker(ctx, rowPath, id)` (AceGUI `Icon` widgets, each `SetImage(path)`).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_page_callouts.lua`:
```lua
-- The picker's icon showing `path`, among the widgets `w`.
local function iconFor(P, w, path)
    for _, icon in ipairs(P.all(w, "Icon")) do
        if icon.image and icon.image[1] == path then return icon end
    end
    return nil
end

test("callouts page: [phase 5] Choose an icon: a click on the skull is the callout's icon, through the seam", function()
    local NS, _, P = open()
    local id = NS.Library.CreateCallout({ name = "Kill", text = "Kill {skull}", channel = "party" })
    NS.addon.Settings.Editors.Select("callout", id)
    local w = P.redraw("callouts")
    assertTrue(P.find(w, "Heading", "Choose an icon") ~= nil)
    local skull = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
    iconFor(P, w, skull):__fire("OnClick")
    assertEqual(NS.db.profile.callouts[id].icon, skull)
    -- a LibKa0s mark is offered by its path, as the Icon box takes it
    local chat = NS.Icon("chat")
    assertTrue(chat ~= nil and iconFor(P, w, chat) ~= nil)
    -- the built-in sets' icons are read from NS.BuiltIns: their callouts' too, and nothing they do not wear
    -- red under: hard-code a list of game icons in settings/Editors.lua that leaves out the callouts'
    assertTrue(iconFor(P, w, "Interface\\Icons\\Spell_Nature_Bloodlust") ~= nil)
    assertTrue(iconFor(P, w, "Interface\\Icons\\Spell_Nature_Reincarnation") ~= nil)
    assertNil(iconFor(P, w, "Interface\\Icons\\INV_Misc_QuestionMark"))
    assertNil(iconFor(P, w, NS.Icon("close")), "the catalog's window chrome is not offered")
    local labels = {}
    for _, e in ipairs(NS.addon.Settings.Editors.IconPalette()) do labels[#labels + 1] = e.label end
    assertEqual(labels[8], "Skull", "a raid marker carries its localized name")
end)
```

Append to `tests/test_page_groups.lua`:
```lua
test("groups page: [phase 5] Choose an icon sets a user group's icon; a built-in set offers no picker", function()
    local NS, _, P = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local Ed = NS.addon.Settings.Editors
    Ed.Select("group", gid)
    local w = P.redraw("groups")
    local wanted = "Interface\\Icons\\Achievement_Boss_Ragnaros"
    for _, icon in ipairs(P.all(w, "Icon")) do
        if icon.image and icon.image[1] == wanted then icon:__fire("OnClick") end
    end
    assertEqual(NS.db.profile.groups[gid].icon, wanted)
    Ed.Select("group", "bi.mplus")
    w = P.redraw("groups")
    assertEqual(#P.all(w, "Icon"), 0, "built-ins are read-only")
end)
```

- [ ] **Step 2: Run them to check they fail**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in both new cases (no "Choose an icon" heading, no `Icon` widget).

- [ ] **Step 3: The picker**

In `settings/Editors.lua`, replace
```lua
-- ── the reorder lists (options-ui-§18) ──────────────────────────────────────────────────────
```
with
```lua
-- ── the icon picker (spec §13.1, §19 row 5) ─────────────────────────────────────────────────

-- What the picker offers, in order: the eight raid markers; the game icons the built-in sets wear,
-- read from NS.BuiltIns when the picker draws (so a set that gains an icon offers it); then the
-- LibKa0s icon catalog's entries a callout reads well with. The catalog is enumerated (NS.IconNames;
-- library-stack-§8: never a hard-coded path list), and ICON_MARK_KEEP only picks among its names:
-- most of the catalog is window chrome (close, sort, align) that means nothing on a callout, and a
-- name the catalog drops simply stops being offered. Each icon is stored by its texture path, which
-- is what the Icon box takes; any other texture is typed into the box.
Ed.ICON_MARKERS = { L["Star"], L["Circle"], L["Diamond"], L["Triangle"], L["Moon"], L["Square"], L["Cross"],
    L["Skull"] }
Ed.ICON_MARK_KEEP = { chat = true, ["speech-bubble"] = true, warning = true, info = true, help = true,
    target = true, shield = true, heart = true, star = true, ["map-marker"] = true, location = true,
    people = true, person = true, timer = true, ban = true, ["thumb-up"] = true }

-- The built-in sets' icons, each once, in the sets' order: a set's own, then its callouts'.
local function builtinIcons(out, seen)
    local BI = NS.BuiltIns
    local function add(path, label)
        if type(path) == "string" and not seen[path] then
            seen[path] = true
            out[#out + 1] = { path = path, label = label }
        end
    end
    for _, gid in ipairs(BI.order) do
        local def = BI.groups[gid]
        add(def.icon, def.name)
        for _, cid in ipairs(def.callouts or {}) do
            local c = BI.callouts[cid]
            if c then add(c.icon, c.name) end
        end
    end
end

--- The picker's icons, { path, label } in order. The catalog's marks need the library; without it
--- they are left out.
function Ed.IconPalette()
    local out, seen = {}, {}
    for i, name in ipairs(Ed.ICON_MARKERS) do
        local path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i
        seen[path] = true
        out[#out + 1] = { path = path, label = name }
    end
    builtinIcons(out, seen)
    for _, name in ipairs(NS.IconNames()) do
        local path = Ed.ICON_MARK_KEEP[name] and NS.Icon(name)
        if path then out[#out + 1] = { path = path, label = name } end
    end
    return out
end

--- Write a picked icon to the member row `rowPath` (callout.icon, group.icon) for `id`, through the
--- seam; a refusal prints its reason. The Icon box above refreshes in place.
--- @return boolean
function Ed.SetIcon(rowPath, id, path)
    local ok, err, why = NS.SchemaRuntime.Set(rowPath, path, id)
    if not ok then NS.Print(tostring(why or err)) end
    return ok == true
end

--- The picker: a "Choose an icon" heading over a grid of the palette's icons; a click on one is the
--- member's icon.
function Ed.IconPicker(ctx, rowPath, id)
    local h = H()
    h.Section(ctx, L["Choose an icon"])
    h.RenderGrid(ctx, { { wide = true, make = function(_, parent)
        local AceGUI = h.AceGUI
        local grid = AceGUI:Create("SimpleGroup")
        grid:SetLayout("Flow")
        grid:SetFullWidth(true)
        for _, e in ipairs(Ed.IconPalette()) do
            local icon = AceGUI:Create("Icon")
            icon:SetImage(e.path)
            icon:SetImageSize(24, 24)
            icon:SetWidth(36)
            icon:SetHeight(36)
            icon:SetCallback("OnClick", function() Ed.SetIcon(rowPath, id, e.path) end)
            h.AttachTooltip(icon, e.label, L["Click to use this icon."])
            grid:AddChild(icon)
        end
        parent:AddChild(grid)
        return grid
    end } })
end

-- ── the reorder lists (options-ui-§18) ──────────────────────────────────────────────────────
```

Append to `core/MediaSetup.lua`:
```lua
--- The icon catalog's names, in its order (library-stack-§8: a catalog is enumerated, never
--- hard-coded), or an empty list when the library is absent. The icon picker reads it
--- (settings/Editors.lua).
--- @return string[]
function NS.IconNames()
    return Media and Media.ICONS or {}
end
```

In `settings/Callouts.lua`, replace
```lua
--     General  Name, Text, Channel, Icon (the member rows, settings/SchemaMembers.lua), Insert a
--              token, then what it sends here (the baked line and its bytes, or why it sends
--              nothing, and any lock), then Duplicate and Delete
```
with
```lua
--     General  Name, Text, Channel, Icon (the member rows, settings/SchemaMembers.lua), Insert a
--              token, Choose an icon (settings/Editors.lua's picker), then what it sends here (the
--              baked line and its bytes, or why it sends nothing, and any lock), then Duplicate and
--              Delete
```
and in `renderGeneral` replace
```lua
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Insert a token"],
        L["Add a token to the end of the text. Tokens are filled in when the callout is sent."],
        tokenEntries(id), function(token) C.InsertToken(id, token) end, ctx) })
```
with
```lua
    h.RenderGrid(ctx, { Ed.ActionDropdown(L["Insert a token"],
        L["Add a token to the end of the text. Tokens are filled in when the callout is sent."],
        tokenEntries(id), function(token) C.InsertToken(id, token) end, ctx) })
    Ed.IconPicker(ctx, "callout.icon", id)
```

In `settings/Groups.lua`, replace
```lua
--     General   Preview as (page-wide, first), then Name, Icon, Enabled, Open the dial on this group,
--               then Duplicate and Delete. A built-in: what it is, its Enabled row, and Customize.
```
with
```lua
--     General   Preview as (page-wide, first), then Name, Icon, Enabled, Open the dial on this group,
--               Choose an icon (settings/Editors.lua's picker), then Duplicate and Delete. A built-in:
--               what it is, its Enabled row, and Customize.
```
and in `renderGeneral` (the user group's half) replace
```lua
    h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this group, with the same callouts and When. The copy is on no pad until you add it under Comms Pad > Groups."],
```
with
```lua
    h.RenderRows(ctx, mine, nil, nil, { noHeadings = true })
    Ed.IconPicker(ctx, "group.icon", gid)
    h.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this group, with the same callouts and When. The copy is on no pad until you add it under Comms Pad > Groups."],
```

Append to `locales/enUS.lua`:
```lua
-- settings/Editors.lua: the icon picker (phase 5); the raid markers' names
L["Choose an icon"] = "Choose an icon"
L["Click to use this icon."] = "Click to use this icon."
L["Star"] = "Star"
L["Circle"] = "Circle"
L["Diamond"] = "Diamond"
L["Triangle"] = "Triangle"
L["Moon"] = "Moon"
L["Square"] = "Square"
L["Cross"] = "Cross"
L["Skull"] = "Skull"
```

- [ ] **Step 4: Run the gate and the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`
Expected: PASS, 0 / 0, `0 warnings`.

- [ ] **Step 5: Commit**

```bash
git add settings/Editors.lua settings/Callouts.lua settings/Groups.lua locales/enUS.lua tests/test_page_callouts.lua tests/test_page_groups.lua
git checkout -- settings/Editors.lua settings/Callouts.lua settings/Groups.lua locales/enUS.lua tests/test_page_callouts.lua tests/test_page_groups.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Editors: a visual icon picker under the Callouts and Groups pages' Icon row"
```

---
### Task 10: The perf buckets and `tests/perf.lua`'s scenarios

Spec §16: the last two buckets, `situation.refresh` and `resolver.resolve`, and the offline scenarios (a 12-chip pad rebuild, a full dial open and close, a zero-overhead scenario). `resolver.resolve` runs inside `bake.surface`, so it is declared `within` it and noted with that parent (performance-§3). The zero-overhead scenario is the real question performance-§9 asks: the hottest bracketed path, the open dial's pointer `OnUpdate`, with capture off, against the same path on an instance loaded without the Perf library at all. The byte ceilings are the headless mock's figures (its catch-all methods allocate a closure per call), measured at a scratch clone of this plan's tree and pinned at the figure rounded up to the next KiB; compare them run to run, never with the client.

**Files:**
- Modify: `core/PerfSetup.lua` (the bucket list and its comment), `modules/Situation.lua` (`local Perf`, `RefreshNow`), `modules/Surfaces.lua` (a `resolve` helper; `BuildPlan` and `BuildDialPlan` call it), `tests/perf.lua` (its header's scenario paragraph and ceilings, the scenarios)
- Test: `tests/test_setup.lua`, `tests/perf.lua`

**Interfaces:**
- Consumes: `NS.Perf` (`on`, `Note(key, ms, parent)`), `tests/loader.lua`'s `libFiles` (to load an instance without the Perf files), `NS.DialSecure.Open/Close`, `NS.DialRender.PointerUpdate`, `NS.Pad.Apply`, `NS.Surfaces.BuildPlan`.
- Consumes also: phase 4's `deps.unmeasured` (`settings/Dials.lua`'s `lookDeps`), which `S.BuildDialPlan`'s own bracket already honors.
- Produces: buckets `situation.refresh`, `resolver.resolve` (`within = "bake.surface"`, gated by `deps.unmeasured` like its parent); scenarios `bracketCaptureOff`, `dialPointerCaptureOff`, `dialPointerNoHarness`, `padRebuild12`, `dialOpenClose`, `situationRefresh`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_setup.lua`:
```lua
test("perf: [phase 5] a refresh notes situation.refresh, and each plan resolver.resolve inside bake.surface", function()
    local NS = T.enableAddon()
    local notes = {}
    local real = NS.Perf.Note
    NS.Perf.Note = function(key, ms, parent)
        notes[#notes + 1] = key .. (parent and ("<" .. parent) or "")
        return real(key, ms, parent)
    end
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true, keyLevel = 12,
            inGroup = true }
    end
    NS.Perf.on = true
    NS.Situation.RefreshNow("test")
    NS.Perf.on = false
    local text = table.concat(notes, ",")
    assertTrue(text:find("situation.refresh", 1, true) ~= nil, text)
    -- red under: drop the parent argument from the resolver.resolve bracket in modules/Surfaces.lua
    assertTrue(text:find("resolver.resolve<bake.surface", 1, true) ~= nil, text)
end)

test("perf: [phase 5] the Comms Dial page's Preview notes neither bake.surface nor resolver.resolve", function()
    local NS = T.enableAddon()
    local notes = {}
    local real = NS.Perf.Note
    NS.Perf.Note = function(key, ms, parent)
        notes[#notes + 1] = key
        return real(key, ms, parent)
    end
    NS.Perf.on = true
    local lines = NS.addon.Settings.Dials.PreviewLines("d2")
    NS.Perf.on = false
    assertTrue(#lines > 0)
    -- red under: drop `not deps.unmeasured` from resolve() in modules/Surfaces.lua
    assertEqual(table.concat(notes, ","), "", "an editor's look is not a surface's bake")
end)
```

- [ ] **Step 2: Run it to check it fails**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
Expected: FAIL in the first case (`situation.refresh` is never noted); the second PASSES already (nothing notes `resolver.resolve` yet, and `bake.surface` is gated) and pins the gate from Step 3 on.

- [ ] **Step 3: The buckets and the brackets**

In `core/PerfSetup.lua`, replace
```lua
-- The buckets, in report order. Each one is bracketed by the module named beside it. Phase 2
-- declares the send engine's and the pad's. The tasks that add one add its bucket here together
-- with the bracket that reaches it (design spec §16: situation.refresh, resolver.resolve,
-- bake.surface, pad.layout, dial.render, send.click, echo.match), so a declared bucket is never left
-- unreached (tests/test_setup.lua).
local BUCKETS = {
    { key = "bake.surface" }, -- modules/Surfaces.lua: one pad's or dial's plan (resolve, order, bake every slot)
```
with
```lua
-- The buckets, in report order: design spec §16's seven, each bracketed by the module named beside
-- it, and each declared with the bracket that reaches it, so a declared bucket is never left
-- unreached (tests/test_setup.lua). resolver.resolve runs inside bake.surface and says so (`within`,
-- performance-§3).
local BUCKETS = {
    { key = "situation.refresh" }, -- modules/Situation.lua: one read, classify and signature (RefreshNow)
    { key = "bake.surface" }, -- modules/Surfaces.lua: one pad's or dial's plan (resolve, order, bake every slot)
    { key = "resolver.resolve", within = "bake.surface" }, -- modules/Surfaces.lua: a plan's active groups and their order
```

In `modules/Situation.lua`, replace
```lua
NS.Situation = NS.Situation or {}
local Sit = NS.Situation
local State = NS.State
```
with
```lua
NS.Situation = NS.Situation or {}
local Sit = NS.Situation
local State = NS.State
local Perf = NS.Perf
```
replace
```lua
--- Read, classify, and publish when the signature moved.
--- @param reason string|nil for the debug line
--- @return boolean changed
function Sit.RefreshNow(reason)
    State.situationPending = nil
```
with
```lua
local function refresh(reason)
    State.situationPending = nil
```
and replace (the end of the same function, now `refresh`)
```lua
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED, snap, prev)
    return true
end
```
with
```lua
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED, snap, prev)
    return true
end

--- Read, classify, and publish when the signature moved. Bracketed as situation.refresh (spec §16).
--- @param reason string|nil for the debug line
--- @return boolean changed
function Sit.RefreshNow(reason)
    local t0 = Perf.on and debugprofilestop()
    local changed = refresh(reason)
    if t0 then Perf.Note("situation.refresh", debugprofilestop() - t0) end
    return changed
end
```

In `modules/Surfaces.lua`, replace
```lua
--- One pad's plan.
--- @param pad table profile.pads[surfaceId]
```
with
```lua
-- A surface's active groups and its order of them (spec §7), bracketed as resolver.resolve inside
-- bake.surface (spec §16), and gated as bake.surface is: an editor's look at a plan
-- (deps.unmeasured, settings/Dials.lua) notes neither, because a child noted under a parent that was
-- never noted would skew performance-§3's within-parent figures.
local function resolve(list, snap, deps)
    local t0 = Perf.on and not deps.unmeasured and debugprofilestop()
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(list, active, deps.groups, deps.autoPromote)
    if t0 then Perf.Note("resolver.resolve", debugprofilestop() - t0, "bake.surface") end
    return active, order
end

--- One pad's plan.
--- @param pad table profile.pads[surfaceId]
```
replace (in `S.BuildPlan`)
```lua
function S.BuildPlan(surfaceId, pad, snap, deps)
    local t0 = Perf.on and debugprofilestop()
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(pad and pad.groups, active, deps.groups, deps.autoPromote)
```
with
```lua
function S.BuildPlan(surfaceId, pad, snap, deps)
    local t0 = Perf.on and debugprofilestop()
    local active, order = resolve(pad and pad.groups, snap, deps)
```
and replace (in `S.BuildDialPlan`)
```lua
    dial = type(dial) == "table" and dial or {}
    local active = NS.Resolver.ActiveGroups(deps.groups, snap)
    local order = NS.Resolver.SurfaceOrder(dial.groups, active, deps.groups, deps.autoPromote)
```
with
```lua
    dial = type(dial) == "table" and dial or {}
    local active, order = resolve(dial.groups, snap, deps)
```

- [ ] **Step 4: Run the gate**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS (including `test_setup`'s "every declared bucket has a bracket, and every bracket a declared bucket"), 0 / 0.

- [ ] **Step 5: The scenarios**

In `tests/perf.lua`, replace
```lua
-- The scenarios grow with the hot paths. The scaffold has none, so the one scenario here is
-- performance-§9's zero-overhead question asked of the bracket shape itself, against the live
-- harness instance: with capture off, the gated form notes nothing and allocates nothing. The
-- design's scenarios (spec §16: a 12-chip pad rebuild, a full dial open and close) arrive with the
-- code they measure, each beside its bucket in core/PerfSetup.lua.
--
-- CEILINGS (measured 2026-10-13, Lua 5.1.5). Pinned hard at 0 bytes: the gated bracket must
-- allocate nothing with capture off. Raise one only by re-measuring and saying why; a rise is the
-- finding.

local BYTE_CEILING = { bracketCaptureOff = 0 }
local NOTES_PER_ITER = { bracketCaptureOff = 0 }
```
with
```lua
-- THE SCENARIOS (spec §16, performance-§9):
--   bracketCaptureOff     the bracket shape itself, around no work, capture off: notes and allocates
--                         nothing.
--   dialPointerCaptureOff the hottest bracketed path, the open dial's pointer OnUpdate (dial.render,
--   dialPointerNoHarness  every frame while a dial is open), with capture off, and again on an
--                         instance loaded WITHOUT the LibKa0s-Perf files (core/PerfSetup.lua's
--                         stub): the zero-overhead pin is that capture off allocates no more than no
--                         instrumentation at all.
--   padRebuild12          one 12-chip pad rebuilt from its plan, capture on: bake.surface,
--                         resolver.resolve and pad.layout, three notes.
--   dialOpenClose         the default dial opened, one pointer frame drawn, closed: one note.
--   situationRefresh      one situation read whose signature did not move: one note.
--
-- CEILINGS (measured 2026-10-13, Lua 5.1.5, against the headless mock, whose catch-all methods
-- allocate a closure per call, so the figures are the mock's as much as the addon's; compare them
-- run to run, never with the client). The two captureOff scenarios and bracketCaptureOff are pinned
-- by rule, not by figure; the rest sit at the measured figure rounded up to the next KiB. Raise a
-- ceiling only by re-measuring and saying why; a rise is the finding.

local BYTE_CEILING = {
    bracketCaptureOff = 0,
    dialPointerCaptureOff = 1024, dialPointerNoHarness = 1024,
    padRebuild12 = 69632, dialOpenClose = 2048, situationRefresh = 2048,
}
local NOTES_PER_ITER = {
    bracketCaptureOff = 0, dialPointerCaptureOff = 0, dialPointerNoHarness = 0,
    padRebuild12 = 3, dialOpenClose = 1, situationRefresh = 1,
}
```
and replace
```lua
Perf.on = false
measure("bracketCaptureOff", N, bracketed)
NS.Perf.Note = realNote
```
with
```lua
Perf.on = false
measure("bracketCaptureOff", N, bracketed)

-- In a Mythic+ key, so the default pad and dial have something to show.
local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }
local function live(instance)
    instance.Situation.ReadInputs = function() return MPLUS end
    instance.Situation.RefreshNow("perf")
end

-- The zero-overhead pair (performance-§9): the dial's pointer OnUpdate, the hottest bracketed path,
-- with capture off, and on an instance with no Perf library at all.
local function pointerFrame(instance, m)
    local header = instance.Dial.Instance("d2").header
    instance.DialSecure.Open(header)
    m.cursor.x, m.cursor.y = 50, 60
    local pointer = header.qcPointer
    return function() instance.DialRender.PointerUpdate(pointer) end
end

live(NS)
local pointer = pointerFrame(NS, mock)
measure("dialPointerCaptureOff", N, pointer)

local NO_PERF = {}
for _, rel in ipairs(loadAddon.libFiles) do
    if rel:find("/Perf", 1, true) then NO_PERF[#NO_PERF + 1] = rel end
end
local bare, bareMock = loadAddon({ skip = NO_PERF })
bare.addon:OnInitialize()
bare.addon:OnEnable()
check(bare.Perf.BuildRecord == nil, "the bare instance still has the Perf library: the pair compares nothing")
live(bare)
measure("dialPointerNoHarness", N, pointerFrame(bare, bareMock))
NS.DialSecure.Close(NS.Dial.Instance("d2").header)

-- A 12-chip pad: twelve callouts in one group of the player's own, the pad's only group.
local Lib = NS.Library
local twelve = {}
for i = 1, 12 do
    twelve[i] = Lib.CreateCallout({ name = "Callout " .. i, text = "Callout " .. i .. " {rt8}", channel = "party" })
end
local group = Lib.CreateGroup({ name = "Twelve", callouts = twelve })
local p1 = NS.db.profile.pads.p1
while #p1.groups > 0 do Lib.RemoveGroupFromSurface("pad", "p1", p1.groups[1]) end
Lib.AddGroupToSurface("pad", "p1", group)

Perf.on = true
measure("padRebuild12", 200, function()
    local snap = NS.Situation.Current()
    NS.Pad.Apply("p1", NS.Surfaces.BuildPlan("p1", p1, snap, NS.Surfaces.Deps(snap)))
end)
local header = NS.Dial.Instance("d2").header
measure("dialOpenClose", 200, function()
    NS.DialSecure.Open(header)
    NS.DialRender.PointerUpdate(header.qcPointer)
    NS.DialSecure.Close(header)
end)
measure("situationRefresh", 500, function() NS.Situation.RefreshNow("perf") end)
Perf.on = false
NS.Perf.Note = realNote

-- The zero-overhead claim itself: capture off costs no more than no instrumentation.
local function bytesOf(name)
    for _, r in ipairs(results) do if r.name == name then return r.bytesPerIter end end
    return math.huge
end
check(bytesOf("dialPointerCaptureOff") <= bytesOf("dialPointerNoHarness"),
    ("the pointer allocated %.1f bytes/iter with capture off and %.1f with no harness"):format(
        bytesOf("dialPointerCaptureOff"), bytesOf("dialPointerNoHarness")))
```

- [ ] **Step 6: Run the scenarios, and re-measure if the rebase moved them**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/perf.lua; echo "exit $?"`
Expected: six rows and `exit 0`. Measured on a scratch export of `55194f6` plus Tasks 1–10: `bracketCaptureOff` 0.0 bytes/iter, `dialPointerCaptureOff` 120.0, `dialPointerNoHarness` 120.0, `padRebuild12` 68960.4 (3.00 notes; the ceiling is 69632, so only 672 bytes of headroom), `dialOpenClose` 1159.3 (1.00), `situationRefresh` 1376.0 (1.00). If a figure is over its ceiling here (the title font Task 8 adds or a later phase-4 commit can move the pad's allocations), set that ceiling to the new figure rounded up to the next 1,024 bytes and say so in the commit message; a notes-per-iteration mismatch is a bracket bug, never a ceiling to raise.

- [ ] **Step 7: Run the measurement**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --suite perf --no-bundle`
Expected: `perf  pass — 6 scenarios`, `complexity  pass — 0 warnings`.

- [ ] **Step 8: Commit**

```bash
git add core/PerfSetup.lua modules/Situation.lua modules/Surfaces.lua tests/perf.lua tests/test_setup.lua
git checkout -- core/PerfSetup.lua modules/Situation.lua modules/Surfaces.lua tests/perf.lua tests/test_setup.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Perf: situation.refresh and resolver.resolve; tests/perf.lua's spec scenarios and the zero-overhead pair"
```

**Milestone 2 checkpoint.** Both gate commands green, complexity `0 warnings`, `lua tests/perf.lua` exits 0, and both generators print `OK` (`python3 -I tools/derive-gameids.py "$D"` and `tools/derive-winds.py` against the tables Tasks 6 and 7 downloaded). Checked on a scratch export of `55194f6` with Tasks 1 to 10: 646 passed, 3 skipped (the vendored-payload cases, skipped there because the export has no `../LibKa0s` sibling; they run in this worktree), luacheck 0 / 0.

---

### Task 11: The docs set for v0.1.0 (spec §20)

Documentation, the regenerated test inventory and the README, to documentation-§1–§3: the root files, the trio (with the new smoke checks the owner runs in Task 14), the Tier 1 topic docs, the records and the Tier 2 docs, each brought to what the code is at the end of this phase, plus the spec's *Built (phase 5):* notes. Phase 4's docs task may have rewritten some of the same paragraphs (Pre-flight P1); where it did, merge rather than duplicate, and keep the code as the truth.

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md` (Step 0), `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/data-flow.md`, `docs/scope.md`, `docs/common-tasks.md`, `docs/debug.md`, `docs/performance.md`, `docs/testing.md`, `docs/profiles.md`, `docs/smoke-tests.md`, `docs/test-cases.md` (regenerated), `README.md`, `DEPENDENCIES.md`
- Check, change only if stale: `CLAUDE.md` (the stub and the LibKa0s provenance line), `docs/compat-layer.md` (this phase adds no Compat shim: `NS.ResolveColor` and `NS.MediaFetch` are setup seams), `docs/slash-dispatch.md` (no verb changes), `docs/perf-analysis/README.md`, `docs/automated-tests/README.md`

**Interfaces:**
- Consumes: everything Tasks 1–10 built, by the names they produce.
- Produces: documentation only; no code changes. Smoke checks SHARE-1..6, LOOK-1..2, ICON-1, BG-1..2 and IDS-1 for Task 14.

- [ ] **Step 0: Write the readings into the spec**

In `docs/superpowers/specs/2026-10-11-quickcomms-v1-design.md`, add each as a *Built (phase 5):* note under the section named (the phase 3 and 4 notes are the model):
- **§3, Libraries:** after the LibSerialize and LibDeflate bullet, the note ruling R1 (Pre-flight P3) chose; never write it before R1 is recorded. Under reading (1): "*Built (phase 5):* LibDeflate `1.0.2-release` and LibSerialize `v1.2.3`, each copied whole from its tag with its license (`DEPENDENCIES.md`). `standards/ADDONS.md` already carries this addon's row, and the roster has no library column, so the libraries are recorded in `DEPENDENCIES.md` and `docs/ARCHITECTURE.md` (owner ruling, <date>)." Under reading (2): the same first sentence, then "A library column for `standards/ADDONS.md` is proposed upstream in the WowAddonStandards repo (owner ruling, <date>); this repo records the libraries in `DEPENDENCIES.md` until the roster takes them."
- **§4.2, file layout:** under the tree: "*Built (phase 5):* `modules/Share.lua` is the share string's codec, checks and edge; `libs/LibDeflate/` and `libs/LibSerialize/` are vendored."
- **§8.3, after "Imported text …":** "*Built (phase 5):* an import stores `Bake.CleanText`'s answer: this sanitizer short of the `|` escape, which every bake still applies, so a stored `|` is escaped once."
- **§10.3, replacing the phase 3 note's last clause:** "*Built (phase 3, 5):* the pad's Look tab has visibility, fade and the faded alpha, then the composed Font, Border and Background groups (options-ui-§16, §17) under their own headings. The font draws the chips' labels and the section titles (a title keeps its gold until the player picks a font color or Use class color); the border's style "None" is the flat Ka0s edge and a thickness of 0 is none; the background is a swatch and its class-color companion. The class color is the player's; the defaults are the skin a pad always wore; a font or border this machine does not have draws the default."
- **§11.1 and §12.1:** replace phase 4's note that node sets are "placed clockwise from N in their shipped order; pinning … moves to phase 5" with "*Built (phase 5):* node sets are pinned to their compass winds, derived from the client's AreaPOI table by `tools/derive-winds.py` (each node's position against the center of its set's nodes, north up; a node near that center is the middle). A pinned ring has eight wedges, whatever the dial's slices, and is never paged; a middle node takes the first wind left free clockwise from N; a wind with no node has no wedge; the number keys pick the shown wedges clockwise from N. Flat mode is not pinned." Then the sentence ruling R2 chose: under (a) "Deepwind Gorge's current map has five nodes: Shrine and Ruins joined Market, Farm and Quarry (owner ruling, <date>; brainstorm §8 listed three)."; under (b) "Deepwind Gorge keeps its three nodes, pinned to winds derived from those three (owner ruling, <date>)."; under (c) "Deepwind Gorge keeps its three nodes in their shipped order, unpinned (owner ruling, <date>)."
- **§12.1, battleground list:** "*Built (phase 5):* every id the fourteen sets list is a battleground map in the client's Map table (build 12.1.5.70340), matched by `tools/derive-gameids.py` and `tests/test_gameids.lua`; none changed. The in-game confirmation is smoke check BG-2, owed until it passes. Midnight's Slayer's Rise (map 2799) is not among the fourteen; the generic battleground set covers it."
- **§13.1, the Callouts row:** replace "the visual picker arrives with phase 5's polish, §19 row 5" with "under it, Choose an icon: the eight raid markers, the icons the built-in sets wear (read from the sets) and the LibKa0s catalog's marks an allowlist keeps; a click is the icon (built phase 5; any other texture is typed)". **The Groups row:** add "a user group's General tab has the same picker". **The Comms Pad row:** after "**Look** (visibility, fade, font group, border group, colors with class-color companions)" add "(built phase 5: the background is the one color group)". **The Share row:** replace the phase 3 note with "*Built (phase 3, 5):* Export (a checkbox per callout, group, Comms Pad and Comms Dial, under a heading per kind; what is ticked brings what it needs; the string opens selected in the copy window), Import (the paste box; Accept checks, the report shows, Import adds) and Built-in (one line per set)."
- **§13.2:** replace "the Midnight dungeon and raid ids are confirmed in game in phase 5, with the battleground ids" with "the Midnight dungeons (Windrunner Spire 2805, Magisters' Terrace 2811, Nexus-Point Xenas 2915, Maisara Caverns 2874) and raids (The Voidspire 2912, The Dreamrift 2939, March on Quel'Danas 2913) and spec 1480 are matched against the client's data tables in phase 5 (`tools/derive-gameids.py`); the in-game confirmation is smoke check IDS-1, owed until it passes. Sporefall (1592) is <shipped / left out> by owner ruling R4".
- **§15:** append "*Built (phase 5):* `v = 1` is the first version; `MIGRATIONS` is empty and already walked. The checks: a name is 1 to 32 characters, a callout's text and an icon path at most 255 bytes after sanitizing (bytes, as `Bake` caps a line; the editor's Text box counts characters, so a text that types in may still be refused on import, and could never have baked), a pasted string at most 50,000 characters (whitespace in it ignored), its decompressed payload at most 512 KiB before anything reads it, one string at most 500 members; ids are `c<n>`, `g<n>`, `p<n>`, `d<n>`; every name, text and icon path passes `Bake.CleanText`, and so does every string in a surface's field values, nested ones included; a field value that is not finite, not plain data or nested too deep is left out; a check that still raises reads as a damaged string. A callout travels as `{ name, text, channel, icon }`, a group as `{ name, icon, callouts, when, openInto, enabled }`, a pad or a dial as `{ name, enabled, groups, fields }`, `fields` its portable member rows by path (never its position or key). Ticking a pad or a dial brings its user groups, and a group its callouts; a built-in set travels by id. A reference to something the string does not carry is left out and counted, and so is a field this version does not take. An imported pad or dial is unbound: no key, the default place, the end of its kind's order, every shipped built-in marked seen. `Share.Export` and `Share.Apply` refuse in combat with one line."
- **§16, the perf list:** "*Built (phase 5):* all seven buckets are bracketed (`resolver.resolve` inside `bake.surface`). `tests/perf.lua`'s scenarios: `padRebuild12`, `dialOpenClose`, `situationRefresh`, and the zero-overhead pair, the dial pointer's `OnUpdate` with capture off against an instance with no Perf library (`dialPointerCaptureOff`, `dialPointerNoHarness`), beside `bracketCaptureOff`."
- **§19, row 5:** append to the Exit cell "*Built:* see smoke checks SHARE-1..6, LOOK-1..2, ICON-1, BG-1..2, IDS-1; the release gate's bundle is Task 13's."

- [ ] **Step 1: `docs/ARCHITECTURE.md`**

- **Intro:** add `[superpowers/plans/2026-10-13-quickcomms-phase-5.md](superpowers/plans/2026-10-13-quickcomms-phase-5.md)` to the build-order sentence.
- **Overview:** the "At the end of phase 4 …" sentence becomes "At the end of phase 5 the data layer feeds the secure send engine, the Comms Pads and the Comms Dials, and the player edits callouts, groups (with their When), pads (with their Look), dials and the built-in sets on the Callouts, Groups, Comms Pad, Comms Dial and Share pages, and shares any of them as a `!QC1!` string; "Preview as…" draws the surfaces in another situation and "Why is this showing?" explains them." In the libraries paragraph add "LibDeflate and LibSerialize (the share string, spec §15; versions and licenses in `DEPENDENCIES.md`)" after LibDBIcon; in the Widgets row's Gives cell add "and the Share page's export window (`NS.MakeCopyWindow`, the library's `CopyWindow`)"; in the Core row add "and the class-color resolver (`NS.ResolveColor`)"; in the Media row add "and `NS.MediaFetch` (a LibSharedMedia entry by name)"; and in the sentence after the table change "of the Widgets major `DragHandle` and `ReorderList` are used" to "of the Widgets major `DragHandle`, `ReorderList` and `CopyWindow` are used".
- **Module Map:** add the row `Share` | `modules/Share.lua` | "pure codec and checks (the `!QC1!` string, the version gate, the schema checks, the sanitizer over every text field, the report), and the edge: Collect, Export (the copy window), Apply (through `Library.Import`); both acts refused in combat"; on the `Library` row add "and `Import`, the one writer of what a share string brings"; on the `Share` settings row replace the description with "the Share page: Export, Import, Built-in".
- **Settings Schema:** in the member-rows paragraph add the Look rows (`pad.look.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow|borderStyle|borderSize|borderColor|useClassColorBorder|background|useClassColorBackground`, composed by the options library and stamped as pad member rows) and the `color` row type. In the registry-writer paragraph, replace "Panel pages, slash verbs and (phase 5) import call it or the seam; they never write those keys." with "Panel pages and slash verbs call it or the seam; they never write those keys. What a share string makes is written by `Library.Import` alone: fresh ids, the order lists, the references remapped, every shipped built-in marked seen (`seenBuiltins`) on each imported pad and dial, and the surfaces' fields through the seam (`modules/Share.lua` only decodes and checks)." Under **Named non-setting state**, add: "The Share page's session state, `NS.State.share`: `pick` (the members ticked for export, per kind) and `import` (the last checked string's result); a profile switch clears both, and neither is ever saved."
- **Taint Notes:** add: "Sharing writes no frame. An export reads the profile and shows a plain copy window; an import is data, written by `Library.Import` through the seam, and reaches the surfaces as any write does (`LIBRARY_CHANGED` → `Surfaces.Request`, queued in combat behind the stale hint). Both acts also refuse in combat. Nothing in a share string is executed: every text field is sanitized when it is checked, and `Bake` refuses a leading `/` again at every bake."
- **Known Limitations:** add: "A share string carries at most 500 members and 50,000 characters; a larger collection is shared in parts." / "A hostile share string can still make the client inflate up to about 25 MB once when Accept is clicked (LibDeflate has no output cap, so the 50,000-character limit bounds the input, not the output); that is a hitch of about a second, after which the string is refused as damaged because its payload is over 512 KiB, and nothing reads it." / "An imported callout's text is limited to 255 bytes, while the editor's Text box counts 255 characters: a non-Latin text the box accepts can be refused on import, and could never have baked." / "Midnight's Slayer's Rise (map 2799) has no battleground set of its own; the generic set covers it." / "The shipped raids are the current tier's three; a later tier joins `defaults/GameIds.lua` when it is current (the When editor adds the instance you are in meanwhile)." / "Node winds come from the client's map data as of build 12.1.5.70340; a battleground a patch redraws needs its winds re-read (`docs/common-tasks.md`)." / "`tests/perf.lua`'s byte ceilings are the headless mock's figures (its catch-all methods allocate per call); compare them run to run, never with the client."
- **Documented deviations:** keep "None." (phase 4's docs task kept the register "None." at `55194f6`: standard v2.80.0 names `Bindings.xml` a client-mandated root file). Add any deviation the owner ratified in Pre-flight P3 or Task 12, and only those. The census stays "Nothing is over the cap today." and its scope sentence becomes "Vendored code (`libs/`, `tests/_kit/`) is out of scope; the generators under `tools/` are authored Python, under the cap, and the repository has no generated data file." Measure before writing anything about size (`wc -l modules/*.lua settings/*.lua core/*.lua`): on the scratch run `modules/Library.lua` is the largest authored file at about 1,012 lines, inside layout-§1's 1,000–1,500 band, which the census does not record (the release watch list observes it: Task 13, Step 4).

- [ ] **Step 2: The maps**

- `docs/module-map.md`, **intro:** the vendored list becomes "(Ace3, LibSharedMedia, LibDataBroker, LibDBIcon, LibDeflate, LibSerialize, LibKa0s v1.71.0 whole)". **Load order:** after `modules/Library.lua` add the row `16i2` | `modules/Share.lua` | pure + edge | "the share string: codec, checks, report; Collect, Export, Apply"; on `core/WidgetsSetup.lua` add "and the export window, `NS.MakeCopyWindow`"; on `core/MediaSetup.lua` add "`NS.MediaFetch`"; on `core/CoreSetup.lua` add "the class-color resolver"; on `settings/Share.lua` "the Share page (Export, Import, Built-in)"; on `settings/Editors.lua` add "the icon picker"; on `defaults/GameIds.lua` add "(matched against the client's data by `tools/derive-gameids.py` and `tests/test_gameids.lua`; confirmed in game by IDS-1)"; above the table add one line: "The TOC loads `libs\LibDeflate\lib.xml` and `libs\LibSerialize\lib.xml` after LibKa0s; `modules/Share.lua` takes both at load." Below the table add: "`tools/` holds the dev-only generators (`derive-gameids.py`, `derive-winds.py` and their shared `client_tables.py`): Python, never loaded by the client or the TOC, `.pkgmeta`-ignored (layout-§1)." **Tests:** add `test_share` (the codec, the checks, the sanitizer, the report; pure) and `test_gameids` (the shipped instance ids against an extraction of the client's Map tables), and note that `test_page_share` covers the Export and Import tabs and `tests/perf.lua` has six scenarios.
- `docs/schema.md`: in the profile table, the `pads, dials` row's last cell adds "; a pad's `look` holds visibility, fade, faded alpha and the Look groups' fields (font, size, color and its companion, flags, shadow; border style, thickness, color and its companion; background and its companion)"; in the member-rows paragraph add the twelve `pad.look.*` Look rows; under **Session-only** add "Phase 5 adds `share` (the Share page's ticks, `pick`, and the last checked string's result, `import`; a profile switch clears both)." Under **Migrations** add "No schema step in phase 5: `Library.Prepare` fills a stored pad's missing layout and look fields from the defaults (`fillShape`), so a pad saved before the Look groups reads like a new one."
- `docs/settings-panel.md`: the `Share` row of the `Page | Covers` table becomes "`Export`, `Import`, `Built-in`"; the `Comms Pad` section's Look line lists the three headed groups; the Callouts diagram's General line and the Groups section gain "Choose an icon"; replace the `## Share` section's body with `settings/Share.lua`'s header diagram (the four lines from `strip` to `Built-in`) and one paragraph: "The ticks and the checked string are session state, cleared by a profile switch. Export and Import refuse in combat with one line (the panel is locked in combat anyway). Defaults resets the Built-in tab only." Replace **Still to come** with "Quick mode's delay and tap action with the C7 upgrade."
- `docs/data-flow.md`: add after the Comms Dial section:

> ## Today: sharing
>
> Export: the ticks (`NS.State.share.pick`) go to `Share.Collect`, which adds what they need (a pad's or a dial's user groups, a group's callouts) and reads each pad's and dial's portable fields through the seam (`Share.FieldsOf`); `Share.Encode` makes the `!QC1!` string, and the copy window shows it selected. Import: the pasted string goes to `Share.Check` (decode, version, schema checks, `Bake.CleanText` over every text field), the page shows `Share.ReportLines`, and Import hands the result to `Share.Apply`, which calls `Library.Import`: fresh ids, references remapped, a surface's fields through the seam, no key or position, all in one `Library.Batch`, so one `LIBRARY_CHANGED` rebuilds the surfaces (at combat end, if need be) and repaints the pages.

- `docs/scope.md`: rename "What exists at the end of phase 4" to "What exists at the end of phase 5"; add "Phase 5 added sharing (an export string and an import that checks, reports and adds what a string holds as new, unbound members), the pad's Look font, border and background with class colors, the icon picker, battleground node sets pinned to their compass winds, and the instance ids matched against the client's data (their in-game confirmation is the smoke test's); the release gate is green, and v0.1.0 waits for the owner's word."; point the closing sentence at the phase 5 plan too.
- `docs/common-tasks.md`: add

> ## Re-derive the client-data extractions
>
> `tests/test_gameids.lua`'s `CLIENT_MAPS`, `defaults/GameIds.lua`'s dungeon and raid lists, and the node winds in `defaults/BuiltIns_Battlegrounds.lua` come from the client's own tables, as wago.tools exports them. Two generators re-derive them and check the repository against them (layout-§1: they live under `tools/`, are never loaded, and are `.pkgmeta`-ignored); both need Python 3 and nothing else, download into a new scratch directory, and exit non-zero on any mismatch:
>
> ```sh
> D="$(mktemp -d)/tables"
> python3 -I tools/derive-gameids.py --fetch "$D" && python3 -I tools/derive-gameids.py "$D"
> P="$(mktemp -d)/poi"
> python3 -I tools/derive-winds.py --fetch "$P" && python3 -I tools/derive-winds.py "$P"
> ```
>
> For a new season or patch: change `SEASON`, `LAUNCH` (and `CURRENT_TIER` if the journal renumbers it) at the top of `tools/derive-gameids.py`, run it, and read every `MISMATCH:` and `NOT SHIPPED:` line; change the shipped lists and the test's rows to match only after reading them, then run it again until it prints `OK`. A new shipped id gets its `CLIENT_MAPS` row from the block the script prints. For a battleground a patch redraws, change its entry in `NODES` at the top of `tools/derive-winds.py` (the AreaPOI id and the name that row must carry) and copy the winds it prints into `defaults/BuiltIns_Battlegrounds.lua`. Update the build named in the headers (`defaults/GameIds.lua`, `defaults/BuiltIns_Battlegrounds.lua`, `tests/test_gameids.lua`) with the build `--fetch` printed. A match is not an in-game confirmation: the headers say "matched" until smoke checks BG-1, BG-2 and IDS-1 pass.
>
> ## Change what a share string carries
>
> A new member row of a pad or a dial travels with it on its own (`Share.Portable`: every row of its kind but its name, Enabled, position and key). A new callout or group field needs three places: `exportMember` in `modules/Share.lua`, the kind's entry check above it (`calloutEntry`, `groupEntry`), and `importMembers` in `modules/Library.lua`; pin it in `tests/test_share.lua` and `tests/test_library.lua`. Raise `Share.VERSION` only when an older Quick Comms would misread the new string, and add `MIGRATIONS[old]` lifting an old payload one step.

- `docs/debug.md`, **Tags:** add phase 5's: "`Share` (an export: what it held and its length)" and note that `Library` logs each import's tally; the import's field writes share one `[Set] import share: N rows` line.
- `docs/performance.md`: "Five are declared" becomes "Seven are declared, all of the design's"; add the rows `situation.refresh` | `modules/Situation.lua` | "one situation read: inputs, classify, signature, and the publish when it moved" and `resolver.resolve` | `modules/Surfaces.lua` | "a plan's active groups and their order; declared and noted within `bake.surface`"; delete the paragraph explaining why `Situation.Refresh` has no bucket and the sentence about "the design's other buckets"; replace the **Offline scenarios** table with:

> | Scenario | What it shows | Ceiling |
> |---|---|---|
> | `bracketCaptureOff` | the gated bracket shape, capture off, notes nothing and allocates nothing | 0 bytes, 0 notes |
> | `dialPointerCaptureOff` | the hottest bracketed path, the open dial's pointer `OnUpdate`, capture off | 1 KiB, 0 notes |
> | `dialPointerNoHarness` | the same path on an instance with no Perf library; the run fails if capture off allocates more (zero overhead, performance-§9) | 1 KiB, 0 notes |
> | `padRebuild12` | a 12-chip pad built from its plan and applied, capture on | 68 KiB, 3 notes |
> | `dialOpenClose` | the default dial opened, one pointer frame, closed | 2 KiB, 1 note |
> | `situationRefresh` | a situation read whose signature did not move | 2 KiB, 1 note |
>
> The ceilings are the headless mock's figures, rounded up to the next KiB; its catch-all methods allocate a closure per call, so compare runs with runs, never with the client.

  and delete "The design's scenarios … arrive with phase 5's `tests/perf.lua`."
- `docs/testing.md`, **The harness:** add phase 5's `test_share` and `test_gameids` to the suites sentence; add "`tests/loader.lua` also loads `libs/LibDeflate` and `libs/LibSerialize` through their `lib.xml`, as the TOC does. A font string under a `QuickComms` root records `SetFont` and `SetShadowOffset` (`__font`, `__shadow`)." In **The four suites**, add that the release gate (Task 13 of the phase 5 plan; automated-tests-§3) is a bundle whose manifest shows all four at `pass`, no function above CCN 15 and `blindFiles` 0, and that it never gates a commit.
- `docs/profiles.md`: add "A profile switch also forgets the Share page's ticks and its checked string (they name the old profile's ids)."

- [ ] **Step 3: `docs/smoke-tests.md`**

Rewrite DIAL-4 for the pinned ring (Task 7): the check as phase 4 wrote it expects a paged ring with More, which the owner's re-run in Task 14 would fail for a stale script rather than a defect. In DIAL-4, replace
```
**DIAL-4. The Arathi Basin node dial (the phase 4 exit).** In Arathi Basin: press G → the dial opens
straight on the nodes (Stables, Lumber Mill, Blacksmith, More); click Lumber Mill, then INC 3 → instance
chat shows "INC 3 Lumber Mill": two clicks. Open again; click More → Gold Mine and Farm; the hub goes
back a page.
```
with
```
**DIAL-4. The Arathi Basin node dial (the phase 4 exit; pinned in phase 5).** In Arathi Basin, with
Wedges per ring at 4: press G → the dial opens straight on the nodes, all five on one ring with no
More, each on its compass wind (Blacksmith N, Gold Mine NE, Farm SE, Lumber Mill SW, Stables NW);
click Lumber Mill, then INC 3 → instance chat shows "INC 3 Lumber Mill": two clicks. Open again and
press 4 → Lumber Mill's ring opens (the number keys count the shown wedges clockwise from N).
```
(If phase 4 reworded those lines after `55194f6`, keep its wording for the rest and change only what the pinned ring changes: five nodes, no More, the winds, key 4.) In the **Pending sign-off** table, change the phase 4 row's last cell to "No client pass recorded yet; DIAL-4 rewritten in phase 5 for the pinned ring".

Add to the index, after the Dial row:
```
| SHARE-1..6 | Share | Export and import strings, the report, refusals, unbound pads and dials |
| LOOK-1..2 | Look | The Comms Pad's font, border and background |
| ICON-1 | Icons | The icon picker |
| BG-1..2 | Battlegrounds | Node winds on the dial; the battleground instance ids |
| IDS-1 | Instance ids | The Midnight dungeons and raids |
```
Add these sections after `## Dial`:
````markdown
## Share

**SHARE-1. Export a group.** Settings → Callouts: make `Kick` (`Kick on me {skull}`, Party) and
`Lust` (`Lust now`, Smart group). Groups → New group `My keys`, add both. Share → Export: tick
`My keys` → the line under the boxes reads "The string will hold 2 callouts, 1 group."; Export → a
window opens with a string starting `!QC1!`, already selected; Ctrl+C copies it; Escape closes the
window. Result:

**SHARE-2. Import it, twice.** Profiles → make a profile `Share test`. Share → Import: paste the
string and click Accept → "Ready to import: 2 callouts, 1 group."; Import → chat says "Imported 2
callouts, 1 group." and "An imported group is on no pad or dial yet: add it on the Groups tab of the
Comms Pad or Comms Dial page.", and Groups lists `My keys` with both callouts. Paste and import it
again → a second `My keys`, and the first one is untouched. Result:

**SHARE-3. A string that tries a command.** Paste this on Import and click Accept:

```
!QC1!v4CVUjmmuuaybLPIufQdD2kdOwwqHbeZgPYatnrIz8pxLef7RJSVUuuvx6JsEIS4jcZ6rF6CotojB8U4q4TIMYp)xjmgxKcRkuLfQnEafsdOpZrHfgRTUEGrqG4xAb85kHw7WXVIDQ(9oRnW77qTugrTbstxMlzlNGFOHfhZeMdzwG9RN29xAg)rKx1kqemJbRWthE8K8SBtZVT2hr2GVdP3l)intwJGO)A6LQHm86RF)09)
```

→ "Ready to import: 1 callout, 1 group.", "Left out the callout 'Sneaky': its text starts with /." and
"1 reference to something the string does not carry was left out."; Import → the group `Smoke test`
holds `Kick` only, and nothing ran. Result:

**SHARE-4. Damaged, foreign and newer strings.** On Import, Accept each: the SHARE-1 string with its
last ten characters deleted → "That string is damaged or cut short. Copy all of it again."; `hello`
→ "That is not a Quick Comms string: one starts with !QC1!."; and this →
"That string was made by a newer Quick Comms. Update the addon, then import it.":

```
!QC1!JXWsk9IYV0ckMRGsmLuYpVffyPzMC2oNFU5wStzNzEPKusLMxk5KAtjNyo5KFPLumxcvgRa(
```

Clicking Import after any of them prints the same line and adds nothing. Result:

**SHARE-5. A pad and a dial travel unbound.** Give the Comms Dial the key G. Share → Export: tick
the Comms Pad and the Comms Dial; Export, copy. Switch to `Share test`, import it → chat also says
"An imported dial has no key yet: give it one on the Comms Dial page."; the new pad sits in the
default place (not where yours is), the new dial's Binding tab shows no key, and G does nothing on
this profile until you give one. Switch back → G opens your dial as before. Result:

**SHARE-6. A string that wrapped.** Paste a SHARE-1 string into a chat message or a forum post so it
breaks across lines, copy it back out with the line breaks, and paste that on Import → Accept reads
it as before. Result:

## Look

**LOOK-1. Font.** Comms Pad → Look → Font: pick another face, Font size 14, Font flags Outline,
untick Font shadow → the chip labels and the section titles redraw that way, the titles still gold;
tick Use class color → both take your class color, and Font color's opacity still applies; untick it
and set Font color to red → both turn red. Result:

**LOOK-2. Border and background.** Border style: a LibSharedMedia border (Blizzard Tooltip, for one),
thickness 3, color red → the pad's edge changes; thickness 0 → no edge. Background: dark blue at 50%
opacity → the body changes; Use class color → your class color at 50%. Change one in combat → no
error, the header shows "updates after combat", and it lands at combat end. Defaults → the Ka0s look
again. Result:

## Icons

**ICON-1. The icon picker.** Callouts → a callout → General → Choose an icon: click the skull → the
Icon box shows its path and the chip shows the skull. Groups → a group of yours → General → click a
mark → the group's wedge on the Comms Dial shows it. A built-in set's General tab has no picker.
Result:

## Battlegrounds

**BG-1. Node winds.** In each node battleground you play (Arathi Basin, Eye of the Storm, Battle for
Gilneas, Deepwind Gorge, Isle of Conquest), open the dial → the nodes sit where they are on the map,
north up (Arathi Basin: Stables top left, Gold Mine top right, Farm bottom right, Lumber Mill bottom
left, Blacksmith, the middle node, at the top), and Deepwind Gorge shows five nodes (the count ruling
R2 chose: write three under its (b) or (c), and under (c) say its nodes keep their shipped order).
Lumber Mill, then INC 3 is still two clicks. A node that points the wrong way is filed with this
check's ID and its battleground. Result:

**BG-2. Battleground instance ids.** In each battleground you play: `/qc diagnostics` → the
`situation` section's instanceID is one its set lists (`defaults/BuiltIns_Battlegrounds.lua`), and
the pad and the dial show that set. Write each id into the "Battleground instance IDs seen" table of
`docs/brainstorm/go-no-go/round-4-build-checks.md`. Result:

## Instance ids

**IDS-1. The Midnight dungeons and raids.** In each of the eight dungeons and three raids you visit
(Windrunner Spire 2805, Magisters' Terrace 2811, Nexus-Point Xenas 2915, Maisara Caverns 2874, and
the four returning dungeons; The Voidspire 2912, The Dreamrift 2939, March on Quel'Danas 2913):
`/qc diagnostics` → the instanceID matches; a group's When → Instances → "add the one you are in" adds
that id. Groups → Preview as lists "M+ · Windrunner Spire" and the other seven by name. On a Devourer
Demon Hunter, `/qc diagnostics` → the Situation line reads `spec=1480`, and a When's Spec row
offers Devourer. If you can enter Sporefall (map 1592), note whether it is a raid and its instanceID
(ruling R4 left it out of the shipped raids, or shipped it: say which). Only after this check passes
does `defaults/GameIds.lua`'s note change from "matched" to "confirmed". Result:
````
and add `SHARE-1..6, LOOK-1..2, ICON-1, BG-1..2, IDS-1` to the **Pending sign-off** table with origin "Phase 5: share, polish and the instance ids".

- [ ] **Step 4: `README.md`**

The README is for players (documentation-§1). Keep the H1, the badge row and the sections in the canonical order; replace the description (the two paragraphs under the badges), `## Usage`, `## How the callouts work`, `## FAQ`, `## Troubleshooting` and the Version History row with the text below, then run `/humanize` over the changed text (documentation-§1's de-AI pass) and fix what it finds. The `## Reporting a bug` and `## Issues and feature requests` sections stay exactly as they are.

Description:
```markdown
Quick Comms puts your usual group callouts one click or one keypress away. "Kick on me", "Lust
now", "INC 3 Lumber Mill": set them up once and they sit on a Comms Pad or open from a
ping-wheel-style Comms Dial. The addon works out where you are, whether that's a Mythic+ key, a raid
boss, an arena or a battleground, and shows the callouts that fit. Every message goes out through a
secure button, the only kind of send Midnight still allows mid-pull, so it keeps working in keys and
on bosses.

It ships with callout sets for Mythic+, raids, arenas and every battleground, switched on and ready.
You can write your own callouts, sort them into groups, say when each group shows, style the pad,
and share any of it with a friend as a string you copy and paste.
```

Usage:
```markdown
## Usage

Enter a key, a raid, an arena or a battleground and the Comms Pad shows the callouts that fit; click
one to send it. `/qc unlock` lets you drag the pad, `/qc lock` fixes it, and `/qc test` shows
placeholder chips so you can place it anywhere. The minimap button's right-click menu has Enabled,
Locked and Test mode.

The Comms Dial opens on a key. Pick one on Settings → Comms Dial → Binding (or in WoW's key bindings
menu), press it, click a group, then click a callout to send it. In a battleground the dial opens
straight on the map's nodes, each where it sits on the map, so INC 3 at the Lumber Mill is two
clicks. The key again, Escape or a right click closes it; the number keys 1 to 8 pick a wedge.

Settings → Callouts makes a callout and gives it an icon; Groups puts callouts in a group and, on its
When tab, says where it shows; Comms Pad arranges a pad, and its Look tab sets the font, the border
and the background, each with a Use class color box. "Preview as…" (or `/qc preview`) shows the pads
and the dial as they would look somewhere else, and hovering a pad's header or the dial's middle (or
`/qc why`) tells you why each group is there.

To share, open Settings → Share → Export, tick what you want to send and click Export, then copy the
string with Ctrl+C. To take one in, paste it on the Import tab and click Accept: Quick Comms lists
what's in it and anything it left out, and nothing changes until you click Import. Everything
arrives as a new copy, and a shared pad or dial comes without a key or a screen position.

Everything is configured under **Settings → AddOns → Ka0s Quick Comms**, and `/qc help` (or
`/quickcomms help`) prints the full command list.
```

How the callouts work:
```markdown
## How the callouts work

- Callouts are short lines of text. You put them in groups, and one callout can be in several.
- Each group has conditions for when it applies, such as "in a Mythic+ key" or "I'm the tank". The
  addon checks those against where you are and shows the groups that match, in the order you set.
- Text is prepared ahead of time, out of combat, and loaded onto secure buttons. Pressing one sends
  the line to the right channel (say, yell, party, instance, raid or raid warning), even during a boss.
- After a press, every button dims for about a second. On a boss the game quietly drops anything
  sent faster than that, so if a line never arrives you get a note in chat.
- The built-in sets are read-only, but you can copy one and edit the copy.
- A shared string is checked before anything is added. A callout whose text starts with a slash
  command is left out, and the text is checked again every time a line is prepared.
```

FAQ:
```markdown
## FAQ

| Question | Answer |
|---|---|
| Does it send anything on its own? | No. A callout is only ever sent when you press its button or its key. |
| Why secure buttons? | In Midnight an addon can't send chat by itself during a boss, a Mythic+ key or a PvP match. A button you press can, so that's the one way Quick Comms sends anything. |
| Can a shared string run a command? | No. Callout text is always chat text. A shared callout that starts with a slash is left out, and nothing in a string is ever run. |
| Will importing overwrite my callouts? | No. Everything in a string arrives as a new copy beside what you have. |
```

Troubleshooting:
```markdown
## Troubleshooting

| Symptom | Fix |
|---|---|
| `/qc` says the addon is disabled | Type `/qc enable`, or tick **Enable Ka0s Quick Comms** on the General page. |
| The minimap button is gone | Tick **Minimap button** on the General page. |
| The pad won't move | Type `/qc unlock` and drag the strip above it; it can't move in combat. |
| The dial's key does nothing | Check Settings → Comms Dial → Binding. The dial opens only where at least one of its groups is active. |
| An imported dial won't open | Shared dials arrive without a key. Give it one on Settings → Comms Dial → Binding. |
| The import says the string is damaged | It was cut short when it was copied. Ask for it again and copy all of it; line breaks and spaces in it are fine. |
| The import says the string is from a newer Quick Comms | Update the addon, then import it again. |
| A message didn't arrive and chat says it may have been dropped | The game drops messages sent too close together on a boss. Wait for the buttons to brighten before pressing again. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |
```

Version History (the row stays `0.1.0 | Unreleased`; nothing is bumped):
```markdown
| 0.1.0 | Unreleased | - The Comms Pad and the Comms Dial, with built-in callouts for Mythic+, raids, arenas and every battleground, sent through secure buttons<br>- Your own callouts and groups, with conditions for when each group shows, Preview as… and Why is this showing?<br>- The spam guard, drop notes, test mode and the lock<br>- The pad's font, border and background, with class colors<br>- Sharing callouts, groups, pads and dials as a string<br>- The settings panel, the minimap button, the `/qc` command and the debug tools |
```

- [ ] **Step 5: `DEPENDENCIES.md`, then the test inventory and the badge**

In `DEPENDENCIES.md` → `## Release / assets`, after the Pillow block and before "**None of this group is required …**", add:
```markdown
**Python 3 (standard library only)**, and only for **re-deriving the client-data extractions**:
`tools/derive-gameids.py` (the instance ids and `tests/test_gameids.lua`'s map table) and
`tools/derive-winds.py` (the node winds in `defaults/BuiltIns_Battlegrounds.lua`), with their shared
`tools/client_tables.py`. They download wago.tools' exports of the client's tables and check the
repository against them; neither is loaded by the client, and `.pkgmeta` ignores `tools/`. How to run
them: `docs/common-tasks.md` → "Re-derive the client-data extractions".
```

Run:
```bash
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
```
Set the README's `Tests` badge to the run's passing / total (`Tests-<X>%2F<Y>_passing`), matching `docs/test-cases.md`'s Total.

- [ ] **Step 6: Run the gate**

Run: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .`
Expected: PASS, including the kit's `test_prose` (US English in every edited doc), `test_layout_cap` (the census) and `test_eol`.

- [ ] **Step 7: Commit**

```bash
git add docs/ README.md DEPENDENCIES.md
git checkout -- docs/ README.md DEPENDENCIES.md
rm docs/test-cases.md && git checkout -- docs/test-cases.md
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Docs: phase 5 sharing, the Look, icons, node winds and ids; smoke checks; spec notes; README"
```

---
### Task 12: The first standards audit, and what it finds

Spec §19 row 5 ("First audit"). The audit is the dev-copilot flow over the whole addon against the living standard; it writes a frozen, dated bundle and never changes code. This task then fixes every finding that is in this phase's scope and needs no ruling, and records every other one durably: the bundle is frozen, so no disposition is written into it. Where each lands is what the standard says (audit-review-history: pending decisions live in GitHub issues on the addon's own repo, not in a file): a finding left for the owner or for a later version becomes an issue through `/dev-copilot:issue-audit`; an accepted limit is a Known Limitations line; a deviation is a `## Documented deviations` row only when the owner ratifies it. It also verifies the roster row in `../WowAddonStandards/standards/ADDONS.md`; updating that row is the standards repo's step, so this task never edits it and gives the owner the exact text instead.

**Files:**
- Create: `docs/audits/<YYYY-MM-DD>/01_CURRENT_STATE.md` … `05_EXECUTION_PLAN.md` (written by the audit; never edited afterwards)
- Modify: whatever an in-scope finding names (each fix its own commit); `docs/ARCHITECTURE.md` → Known Limitations for an accepted limit
- Create (remote, through the skill): one GitHub issue per finding left unfixed, labeled `state:untriaged` and `severity:`

**Interfaces:**
- Consumes: the whole addon at the end of Task 11.
- Produces: the audit bundle; fix commits; an issue for each finding left unfixed (or a Known Limitations line for an accepted limit), and a hand-off message listing them with their issue numbers.

- [ ] **Step 1: Run the audit**

Invoke the skill `dev-copilot:wow-standards-audit` (the `/dev-copilot:wow-standards-audit` command) from the worktree's root. It fetches `AUDIT.md` and every standard section, and writes `docs/audits/<today>/01_CURRENT_STATE.md`, `02_DEVIATIONS.md`, `03_EVIDENCE.md`, `04_TECHNICAL_DESIGN.md` and `05_EXECUTION_PLAN.md`. Do not edit the bundle afterwards (audit-review-history: a frozen run).

- [ ] **Step 2: Commit the bundle as written**

```bash
git add docs/audits/
rm -r docs/audits/<today> && git checkout -- docs/audits/<today>
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Audit: the first standards audit (docs/audits/<today>/)"
```

- [ ] **Step 3: Sort the findings**

Read `02_DEVIATIONS.md` and `05_EXECUTION_PLAN.md`. Put each finding in exactly one of three lists:
- **Fix here**: the change is to this addon, needs no owner ruling, does not change behavior the spec fixes, and does not touch `libs/` or `tests/_kit/` (for example: a stale doc sentence, a missing header comment, a TOC comment's wording, a lint-clean code-shape rule).
- **Needs the owner**: anything that would ratify a deviation (a `## Documented deviations` row is the owner's call, CLAUDE.md), change the standard, change shipped behavior or a default, re-vendor LibKa0s, or touch another repo.
- **Out of this phase**: a real finding whose fix belongs to a later version (the spec's §1 "Not in v0.1.0" list, the C7 upgrade).

- [ ] **Step 4: Fix each "fix here" finding**

For each, in the order `05_EXECUTION_PLAN.md` gives: when it changes code, write the test that pins it first (the house style above), watch it fail, fix, watch it pass; when it changes docs only, edit the doc. Then run `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . && /home/tushar/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` (PASS, 0 / 0, `0 warnings`) and commit with the finding's id in the message: `git commit -m "Audit <id>: <what changed>"` (with the add-and-refresh sequence of the Global Constraints). Never edit the audit bundle to mark a finding done: the next audit sees the fix.

- [ ] **Step 5: Verify the roster row (this repo never edits it)**

```bash
grep -n "Ka0s Quick Comms" ../WowAddonStandards/standards/ADDONS.md
```
Expected: one row, exactly
```
| Ka0s Quick Comms | `../../QuickComms/` | https://github.com/tusharsaxena/QuickComms | Enabled · Locked · Test mode |
```
(it reads so today). Check the launcher column against `core/LauncherSetup.lua`'s menu (Enabled, Locked, Test mode, in that order). The brief's "verify or update" splits here: verifying is this task's; updating is the standards repo's step (the roster is the standard's input, and this worktree writes nothing under `../WowAddonStandards`). So on a mismatch, or no row, put the exact row the owner should apply there in the hand-off, built from this repo's facts: the title from `QuickComms.toc`'s `## Title:` (without color codes), the folder as `` `../../QuickComms/` ``, the repository URL from `git remote get-url origin` (as an `https://github.com/...` URL), and the launcher menu's entries from `core/LauncherSetup.lua` in order, joined with ` · `.

- [ ] **Step 6: Record what is left, durably**

- **An accepted limit** (a finding whose answer is "this is how v0.1.0 is, by design or by the client"): add its line to `docs/ARCHITECTURE.md` → `## Known Limitations`, citing the finding's id, and commit it (`git commit -m "Audit <id>: recorded as a known limitation"`, with the add-and-refresh sequence).
- **Every other finding left unfixed** ("needs the owner", "out of this phase"): invoke the skill `dev-copilot:issue-audit` (the `/dev-copilot:issue-audit` command) from the worktree's root. It sweeps the unexecuted items of the bundle's `05_EXECUTION_PLAN.md` (and the rest of the repo's hanging work) into the repo's GitHub issues, each labeled `state:untriaged` and with a severity; it never changes code. Check its result names every finding on the two lists; one it did not file, file with `/dev-copilot:issue-add`, naming the finding's id. If `gh` is not authenticated, or the owner has not cleared filing issues for this run, stop and ask: the findings must not live only in a chat message.
- **A deviation** is never recorded by this task: a `## Documented deviations` row is the owner's ratification (CLAUDE.md). List it in the hand-off with the row it would take (`| Rule | What differs | Why | Decided | Re-check trigger |`).

Then report to the owner: each finding left unfixed with its id, its issue number (or its Known Limitations line), one line on what it would take, and the ruling it needs; and the roster row's state from Step 5. Triage (`/dev-copilot:issue-triage`) is the owner's.

---
### Task 13: The release gate: the automated-test bundle (no bump, no tag)

Spec §19 row 5's exit: "Release gate (complexity ≤ 15, blind files 0)". automated-tests-§3 defines the gate: a run whose `manifest.json` shows all four suites at `pass` (lint 0 / 0, tests with no failure, perf, complexity with no function above CCN 15 and `blindFiles` 0). This task makes that run on the committed tree and records it. It is a release **candidate** record, labeled as such: the version is not bumped, `## Version History` is not rolled, and no tag is cut; the owner's later release step (`/dev-copilot:bump-version 0.1.0`) makes its own release run.

**Files:**
- Create: `docs/automated-tests/<YYYYMMDD-HHMMSS>/` (the bundle: `manifest.json`, `lint.txt`, `tests.txt`, `perf.txt`, `perf.json`, `complexity.txt`, `test-cases.md`, `ANALYSIS.md`), written by the runner and the skill
- Modify: `docs/automated-tests/RESULTS.md` (the runner rolls the run in; the watch list's `Disposition` cells are the only authored cells), and, only if the counts moved since Task 11, `docs/test-cases.md` and the README's `Tests` badge

**Interfaces:**
- Consumes: everything before it, committed.
- Produces: a bundle whose verdict is `green` and whose manifest is the release gate's evidence.

- [ ] **Step 1: A clean tree, and the inventory current**

Run: `git status --short` → nothing. Then `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md` and `git diff --stat`; if it changed (Task 12 added cases), set the README badge to the new counts and commit both (`git commit -m "Docs: test inventory after the audit fixes"`, with the add-and-refresh sequence) before going on.

- [ ] **Step 2: Run the bundle**

Invoke the skill `dev-copilot:wow-automated-tests` with the label `phase-5-release-gate` (it runs `tests/_kit/run-automated-tests.sh --label phase-5-release-gate` through the bounded runner, writes the bundle, rolls `RESULTS.md` and writes `ANALYSIS.md`). Do not pass `--release`: that marks a bundle as a version's release record, and this phase stops before the release.

- [ ] **Step 3: Read the gate off the manifest**

```bash
B="$(ls -1d docs/automated-tests/2*/ | tail -1)"
grep -E '"(status|warnings|errors|failed|blindFiles|maxCcn|verdict)"' "$B/manifest.json"
```
Expected: `lint` pass (0 warnings, 0 errors), `tests` pass (0 failed), `perf` pass, `complexity` pass with `"warnings": 0`, `"maxCcn"` 15 or less and `"blindFiles": 0`, `"verdict": "green"`.

If any of these fails, report every failed gate at once (automated-tests-§3), fix each (test first where it is code; a function over CCN 15 is split as Task 1 did; a blind file is fixed in the source the parity row names), commit, and run Step 2 again: a new bundle, never an edited one. The failed bundle stays in the record.

- [ ] **Step 4: The watch list's dispositions**

In `docs/automated-tests/RESULTS.md`, fill each watch-list row's `Disposition` cell the runner left blank (automated-tests-§4); no other cell of `RESULTS.md` is typed. Expect a row for `modules/Library.lua`: on a scratch export of `55194f6` with Tasks 1 to 10 it is about 1,012 lines, inside layout-§1's 1,000–1,500 band, which is on notice (not a breach: the census records only the over-cap band). Its cell: "On notice: the registry writer holds every membership, order, id and reference write by design (architecture-§5), and phase 5 added Import and the Look's defaults; no peel planned for v0.1.0. If it nears 1,500, peel the import section (`newSurface`, `importMembers`, `importSurface`, `Lib.Import`) into `modules/Library_Import.lua`." If the owner would rather stay under 1,000 for v0.1.0, that peel is the change, made test-first with its own commit before Step 2 is run again. Any other row says what it is and what will be done.

- [ ] **Step 5: Commit the record**

```bash
git add docs/automated-tests/
B="$(ls -1d docs/automated-tests/2*/ | tail -1)"
rm -r "$B" docs/automated-tests/RESULTS.md && git checkout -- "$B" docs/automated-tests/RESULTS.md
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Automated tests: the phase 5 release-gate run, green (all four suites pass, CCN <= 15, no blind file)"
```

**Milestone 3 checkpoint (code side).** The release gate is green on a recorded bundle; the version is `0.1.0`, unbumped and untagged. Nothing is pushed.

---
### Task 14: In-game smoke test (owner)

The §19 row 5 exit criteria that only the client can show, run by the owner. An agent never marks a check passed.

**Files:**
- Modify (owner only): `docs/smoke-tests.md` (the `Result:` lines), `docs/brainstorm/go-no-go/round-4-build-checks.md` (BG-2's ids), and, once BG-2 and IDS-1 pass, the confirmation notes in `defaults/GameIds.lua` and `defaults/BuiltIns_Battlegrounds.lua`

**Interfaces:**
- Consumes: the whole phase.
- Produces: the recorded results.

- [ ] **Step 1: Install and load**

Link the worktree into `Interface\AddOns\QuickComms`, `/reload`, and run INSTALL-1 and PANEL-1 again: no Lua error; the settings sidebar reads General, Callouts, Groups, Comms Pad, Comms Dial, Share, Profiles; Share opens on its Export tab.

- [ ] **Step 2: The phase 5 checks**

| What the phase delivers | Smoke checks |
|---|---|
| Share: export, import, the report, the refusals, unbound pads and dials | SHARE-1 to SHARE-6 |
| The pad's Look font, border and background with class colors | LOOK-1, LOOK-2 |
| The icon picker | ICON-1 |
| Battleground node winds; the battleground instance ids | BG-1, BG-2 |
| The Midnight dungeon and raid ids | IDS-1 |

Then run PAD-2, EDIT-1, EDIT-5 and DIAL-4 again (the pad's rebuild now wears the Look; the Arathi Basin dial is pinned, and DIAL-4 is the version Task 11 rewrote for it), and any check still in the **Pending sign-off** table that the owner has the content for. Record each `Result:` line with the date, the client build and pass or fail. When BG-2 and IDS-1 pass, change the "MATCHED … NOT YET CONFIRMED IN GAME" note in `defaults/GameIds.lua` and the "in-game confirmation is smoke check BG-2" clause in `defaults/BuiltIns_Battlegrounds.lua` to say they were confirmed in game on that date and build (owner ruling 10: confirmed only by the client).

- [ ] **Step 3: Capture what fails**

For any failure: `/qc diagnostics`, copy the `situation`, `surfaces`, `dials` and `send` sections, and file an issue with the check's ID. A Lua error names the file and line; attach it as text. A node wind that points the wrong way (BG-1) names its battleground and node; a wrong instance id (BG-2, IDS-1) names the id the client reported.

- [ ] **Step 4: Commit the results (owner)**

```bash
git add docs/smoke-tests.md docs/brainstorm/go-no-go/round-4-build-checks.md defaults/GameIds.lua defaults/BuiltIns_Battlegrounds.lua
git checkout -- docs/smoke-tests.md docs/brainstorm/go-no-go/round-4-build-checks.md defaults/GameIds.lua defaults/BuiltIns_Battlegrounds.lua
/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua | tail -1
git commit -m "Smoke: phase 5 results"
```

After this the owner decides the release: `/dev-copilot:bump-version 0.1.0` (which re-runs the four-suite gate and refuses on red), the tag, merging and pushing.

---
## Self-review

**1. Spec coverage (phase 5):**

| Spec section | Task |
|---|---|
| §19 row 5: Share, codec tests, import report (§15) | 3 (codec, checks, report), 4 (`Library.Import`), 5 (the edge and the page) |
| §15: `!QC1!` + LibDeflate EncodeForPrint/CompressDeflate + LibSerialize | 2 (vendored), 3 (`Encode`, `Decode`) |
| §15: version check, older migrate, newer refused with a message | 3 (`headerReason`, `MIGRATIONS`, the "newer" line) |
| §15: validate types, id shapes, channel kinds, lengths | 3 (`checkSection`, the entry checks, `MAX_*`) |
| §15 and §8.3: the sanitizer over every text field; again at every bake | 3 (`Bake.CleanText`, `cleanText`, `cleanName`, `cleanIcon`, `surfaceFields`), `[review 2]` with the bake check |
| §15: apply through `Library.Import`; fresh ids; nothing executed | 4 (`Lib.Import`, `[review 3]`) |
| §15: imported pads and dials arrive unbound | 3 (`Portable` excludes point and key), 4 (re-checked at write, `[review 4]`) |
| §15: export and import refused in combat | 5 (`Share.Export`, `Share.Apply`, the page case) |
| §15 UI: export via LibKa0s `CopyWindow`; import via AceGUI `MultiLineEditBox` on the Share page | 5 (`NS.MakeCopyWindow`, `renderImport`) |
| §18: import into a profile with id collisions | 4 (`[review 3]`) |
| §3: LibSerialize and LibDeflate in DEPENDENCIES.md and ADDONS.md | 2 (DEPENDENCIES.md), 12 (the roster row, read only); the ADDONS.md point is raised above |
| §19 row 5: the Look's font group, border group, colors with class-color companions (options-ui-§16/§17) | 8 |
| §19 row 5: a visual icon picker for callouts and groups | 9 |
| §16: perf buckets (all seven) and `tests/perf.lua` (12-chip pad rebuild, dial open/close, zero overhead) | 10 |
| §12.1 / §13.2: battleground id confirmation; Midnight dungeon and raid ids; spec 1480 | P3 (R3, R4), 6 (matched against the client's data by `tools/derive-gameids.py`, which fails on a mismatch), 14 (BG-2, IDS-1: the confirmation) |
| §12.1 / §11.1: nodes pinned to compass directions (phase 4's R4) | P3 (R2), 7 (with `tools/derive-winds.py`), 14 (BG-1, DIAL-4 rewritten by 11) |
| §20: the docs set (documentation-§1–§3), README | 11 |
| §19 row 5: automated-test bundle; release gate (complexity ≤ 15, blind files 0) | 1 (the eight functions), every task's complexity step, 13 |
| §19 row 5: first audit (fixed, or recorded durably: issues, Known Limitations, owner-ratified deviations) | 12 |
| §19 row 5: tag v0.1.0 only on the owner's word | Global Constraints (Version), 13, 14 |

**Not in this plan, on purpose:** the version bump, the tag and the publish; an open-world set (declined); Slayer's Rise and the later raids (recorded as known limitations); everything §1 lists as not in v0.1.0.

**2. Placeholders:** none in the code steps: every code step carries the code, or the exact text it replaces and the text that replaces it, and every test step its test. Tasks 12 and 13 run tools whose output is not known in advance; each says exactly what to do with every kind of result, and the bundle names (`<today>`, `<YYYYMMDD-HHMMSS>`) are the date the tool writes.

**3. Type consistency:**
- The share result `{ ok, reason, callouts, groups, pads, dials, refused, dropped, ignored }` and its entries (`{ id, fields }`, `{ id, callouts, fields }`, `{ id, name, enabled, groups, fields }`) are the same in Task 3 (`Validate`, `checkSection`, the entries), Task 4 (`importMembers`, `importSurface`, the tests' `shared`) and Task 5 (`Share.Apply`, `SH.ReportText`).
- `Share.Portable(kind, path)` is the one portability rule, used by `surfaceFields` (Task 3), `importSurface` (Task 4) and `FieldsOf` (Task 5).
- `Lib.Import(res)` answers `tally, map`; `tally` is `{ callouts, groups, pads, dials, ignored }` (numbers), which `Share.CountText` reads (Task 3's `countOf` takes numbers, lists and sets) in Task 5's `SH.Import`.
- `NS.State.share = { pick = { callout, group, pad, dial }, import }` in Task 5's `State.lua`, `Editors.lua`, `settings/Share.lua` and `Share.Collect`.
- A ring item's `wedge` is set only by `DL.PinNodes` and read as `item.wedge or i` in `Dial.lua`'s `placeWedges` and `settings/Dials.lua`'s `DD.PreviewLines` (Task 7). A node's wind is `compass` on the built-in group, carried as `compass` on the plan's child and read as `wind` on the node's ring entry.
- `repairSurface(s, result)` (Task 1) becomes `repairSurface(s, kind, result)` in Task 8, both call sites changed there.
- The Look rows' paths are `pad.look.<leaf>` with the composer's leaf names (`font`, `fontSize`, `fontColor`, `useClassColorFont`, `fontFlags`, `fontShadow`, `borderStyle`, `borderSize`, `borderColor`, `useClassColorBorder`, `background`, `useClassColorBackground`) in `Library`'s defaults, `lookChecks`, `R.LabelFont`, `R.SkinFor` and the tests (Task 8).
- `Ed.IconPicker(ctx, rowPath, id)` with `rowPath` `callout.icon` or `group.icon` (Task 9); `Ed.IconPalette` reads `NS.IconNames()` (Task 9's seam) and `NS.BuiltIns`.
- `Share.MAX_RAW`, `Share.MAX_DEPTH` and `cleanValue` (Task 3) are used only inside `modules/Share.lua`; Task 5's edge has its own `copy` for stored data.
- `R.LabelFont(look).colored` is read by `R.TitleFont` and nowhere else; `place(inst, box, style, font, titleFont)` has one caller, `Pad.Apply` (Task 8).
- `tools/client_tables.py`'s `fetch(directory, tables)`, `read(directory, table)` and `fail(msg)` are used by both generators (Tasks 6 and 7).
- The buckets `situation.refresh` and `resolver.resolve` (`within = "bake.surface"`) in `core/PerfSetup.lua`, their `Perf.Note` calls and `tests/perf.lua`'s `NOTES_PER_ITER` (Task 10: `padRebuild12` notes `bake.surface`, `resolver.resolve` and `pad.layout`; `situationRefresh` notes `situation.refresh`; the rebuild a refresh triggers is not part of that scenario because the signature does not move).

**4. Review Focus:** each line carries a `[review n]` test: 1 and 2 in Task 3 (1 also covers a NaN reference, a cyclic field, an infinite icon, a check that raises and a string that inflates past `MAX_RAW`); 3 and 4 in Task 4; 5 in Task 8; 6 in Task 7.

**5. Gate hazards checked** (Tasks 1 to 10 applied to a scratch export of phase 4's head, `55194f6`, by a script that follows each step's replace, create and append blocks: 646 passed, 3 skipped and luacheck 0 / 0 at the end; the sighted complexity suite `0 warnings`, max CCN 15; `lua tests/perf.lua` exit 0; `tools/derive-gameids.py` and `tools/derive-winds.py` `OK` against wago.tools' build 12.1.5.70340 tables. Earlier, the first draft was also run step by step on `c5eb85c`):
- `test_eol`: the vendored files and every new or wholly rewritten file arrive with bare LF; the commit steps remove and re-check them out from the index and run the suite again before committing (found on the scratch clone: six vendored files failed until refreshed).
- The prose gate: "center", never the British form, in every new comment (the scratch run caught one in Task 7's first draft).
- `addRing` went to CCN 16 when the pinned shape was inlined; Task 7 keeps it in the separate `shape` helper (found by the scratch run's complexity step).
- `test_page_dials`' Preview case reads the AB ring's lines; Task 7 updates it (the paged ring is now one pinned ring).
- `test_page_share`'s four existing cases drew the page's first tab; Task 5 points them at `Built-in`.
- `test_setup`'s degraded load: the Look rows come from composers that are hollow without the library, so the degraded schema still holds member rows only.
- `test_setup`'s bucket check: both new buckets are declared in the task that brackets them (Task 10).
- `.luacheckrc`: no new global is read or written by shipped code (`STANDARD_TEXT_FONT`, `debugprofilestop` are already declared; `LibStub` too). One unused-variable warning in Task 8's first draft of a test was fixed in the plan's text.
- `libs/` is excluded by luacheck, the prose gate, the layout cap and the complexity suite, so the vendored libraries add nothing to any of them.
- Found re-anchoring on `55194f6`: phase 4's fix wave took `Dial.Sync` to CCN 19 (Task 1, Step 8 splits it); moved `DD.PreviewLines`' direction into `local dir` (Task 7 names the new line); and gated `bake.surface` on `deps.unmeasured`, which `resolve` now honors too (a Preview redraw during a capture would otherwise note a child under a parent never noted; `test_setup`'s second `[phase 5]` case pins it).
- Task 3 replaced the unbounded `copy` with `cleanValue`; Task 5's edge still copies stored data into a payload, so it brings its own `copy` (luacheck caught the undefined global on the scratch run).
- `tests/test_dial_layout.lua` imports no `assertTrue`; its `[review 6]` case uses `assertEqual(…, true)`.
- The generators: `.gitattributes` pins `*.py` to LF, so the refresh after `git add` gives them LF and `test_eol` agrees; wago.tools answers 403 without a User-Agent, so `client_tables.fetch` sends one; `python3 -I` drops the script's folder from `sys.path`, so each script adds it back to import `client_tables`.
- `padRebuild12` measured 68960.4 bytes/iter against its 69632 ceiling at `55194f6`: 672 bytes of headroom (Task 10, Step 6 says what to do if the rebase moves it).

## Open questions ruled (the brief said decide and report)

These are readings within the spec's text; the one place the spec asks for something the standard has no home for is under **Standard deviations to raise**.

1. **Imported text is stored un-escaped.** The sanitizer an import stores is `Bake.CleanText` (§8.3 short of the `|` escape), because every bake escapes; storing `Sanitize`'s output would show `||` in chat.
2. **A name is sanitized too**, and one the sanitizer refuses (a leading `/`) refuses its member as "not 1 to 32 characters" rather than as a command, because a name never reaches chat.
3. **A callout may arrive with no text**, as the editor allows; a missing or empty text is `""`, not a refusal.
4. **Limits**: 50,000 characters per string (checked before decompressing), 512 KiB of decompressed payload (checked before LibSerialize reads it, since LibDeflate has no output cap; the residual cost, one inflate of up to about 25 MB on Accept, is a Known Limitation), 500 members per string, 255 bytes per text and icon path (bytes, as the bake caps a line; the editor counts characters, and the difference is recorded).
5. **What travels with a pad or a dial** is every member row of its kind but its name and Enabled (carried beside the fields), its position and its key, keyed by row path, so a field added later travels without a format change. The seam re-checks each value at import; a field this version does not take is counted, not fatal.
6. **Unbound** means no key and no position (the default place); everything else (layout, look, mode, slices, Enabled) arrives as shared.
7. **Export closure**: a pad or a dial brings its user groups, a group its callouts; built-in sets travel by id.
8. **A node or a vanished built-in id** on a shared surface is left out and counted; a node is never a surface group.
9. **The Look's border style "None" is the flat Ka0s edge** and thickness 0 is no edge, so the defaults are the skin a pad already wore; the background is a swatch and its companion only (options-ui-§16's background rule). The class color is the player's.
10. **The Look font draws the chip labels and section titles**, the titles in their own gold until the player picks a font color or Use class color (so the default Look changes nothing a pad showed); the header's situation chip keeps the game font (it is chrome, like the drag strip).
11. **The icon picker is a curated palette**, not a browser of every game icon: the raid markers, the icons the built-in sets wear (read from `NS.BuiltIns`), and the LibKa0s catalog enumerated and filtered by an allowlist of names (library-stack-§8); any other texture is still typed into the Icon box.
12. **The instance ids are matched against the client's own data tables** (wago.tools' DB2 exports of build 12.1.5.70340) by a committed generator that fails on a mismatch, not guessed; that is a match, and the shipped notes say so until BG-2 and IDS-1 pass in game (owner ruling 10). The four Midnight dungeons are Mythic+ season 34's maps; the three raids are the current journal tier's under the launch condition; the three later raids, gated behind another season's condition, are left out until they are current; Sporefall is ruling R4's.
13. **Node winds come from the client's AreaPOI table**, and a middle node takes the first free wind from N; this puts Arathi Basin's Blacksmith at N.
14. **Deepwind Gorge is the owner's call (R2)**, because adding Shrine and Ruins departs from brainstorm §8's node list. The plan builds the recommendation (five nodes: the current map, 2245, has five, and pinning three of five would point players at the wrong places; existing built-in ids are unchanged and the two are new ids) and says what changes under the other answers.
15. **Slayer's Rise is not added**: the spec's list is the brainstorm's fourteen; the generic battleground set covers it.
16. **The zero-overhead scenario is measured on the dial pointer's `OnUpdate`**, the only per-frame bracketed path, against an instance loaded without the Perf files, rather than restating the bracket-shape scenario.
17. **The release-gate bundle is labeled, not marked `--release`**: this phase stops before the release, and the owner's release step makes its own run.
18. **Audit findings this phase does not fix are filed, not only reported**: `/dev-copilot:issue-audit` files each as a `state:untriaged` issue (audit-review-history: pending decisions live in issues), an accepted limit goes to Known Limitations, and a deviation waits for the owner's ratification. The bundle stays frozen.
19. **The share page's tabs are keyed by their localized labels**, as every other page's are (`L["Export"]`, `L["Import"]`, `L["Built-in"]`).
20. **An imported group that no shared pad or dial lists says so** in one more chat line, rather than landing silently on no surface; the import never adds it to a pad itself (New group's top-of-every-surface rule is the Groups page's, for a group the player just made).
21. **Export and import in combat are refused, not deferred**: the line says they are not available in combat, and nothing runs at combat end.
22. **The generators are Python under `tools/`** (layout-§1's MUST for an authored generator), shared by one `client_tables.py`, each failing loudly; the derivation is a step of the task that ships what it derives (Tasks 6 and 7), not only a recipe in a doc.
