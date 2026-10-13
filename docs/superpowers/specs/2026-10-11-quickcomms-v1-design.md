# Ka0s Quick Comms: design spec for the first version (v0.1.0)

**Date:** 2026-10-11
**Status:** draft for owner review. Nothing is built until this spec is approved, and then an implementation plan is written and approved.

**Inputs:**
- the brainstorm, [`docs/brainstorm/04-brainstorm.md`](../../brainstorm/04-brainstorm.md), with decisions D1–D12
- the research notes 01–03
- the in-game go/no-go record, [`docs/brainstorm/go-no-go/`](../../brainstorm/go-no-go/README.md)
- the Ka0s WoW Addon Standard v2.78.3, and LibKa0s v1.71.0

**How the work is cut:** one spec, built in phases (§19), as the owner chose.

**Verbs:** "MUST" means required for v0.1.0. "Proposed" marks a decision this spec makes that the brainstorm left open. Those are collected in §21 for the owner to confirm.

---

## 1. Goal and scope

**Goal.** One keypress or click puts the right sentence in the right group channel at the right moment, including mid-pull in a Mythic+ key or a boss fight, where Midnight blocks addons from sending chat on their own.

**In v0.1.0:**
- **The callout library:** callouts and groups, with groups sharing callouts by reference (D8).
- **The situation engine and the resolver:** When conditions, the union of active groups, and the priority each surface gives them (D6).
- **The secure send engine:** the only way anything is sent (D12). It includes the global spam guard of about 1 s (D12).
- **Comms Pads:** any number of them (D4).
- **Comms Dials:** any number of them, each on its own key binding (D2, D3, D4, D9).
- **Built-in sets:** M+, raid, arena, a generic battleground set, and one set per battleground. They are on by default and read-only, with a Customize button (D7, D11).
- **The settings panel:** to the Ka0s standard, including "Preview as…" and "Why is this showing?".
- **Sharing:** export and import strings.
- **The standard plumbing:**
  - slash commands
  - the launcher
  - the debug console
  - diagnostics
  - the perf harness
  - the total disabled state
  - tests
  - docs

**Not in v0.1.0:**
- **Callout extras:** variants, confirm, per-callout cooldown, mark, and a key per callout (#1–#5).
- **Gamepad** (D10).
- **Countdown callouts.**
- **The arc layout for pads.**
- **Analytics.**
- **Faction-aware wording** (D11).
- **Per-dungeon built-in sets.**
- **Any localization beyond enUS.**

## 2. Constraints the design is built on

These come from the go/no-go test (§13 of the brainstorm) and research note 01.

| # | Fact | Consequence |
|---|---|---|
| F1 | During chat lockdown, addon code calling `C_ChatInfo.SendChatMessage` is blocked (`ADDON_ACTION_BLOCKED`). Lockdown covers bosses, **the whole of an M+ key**, and PvP matches. | Every send goes through a secure button (D12). |
| F2 | A `SecureActionButtonTemplate` with `type=macro` and `macrotext` sends `/p` and `/i` during lockdown, both by click and by `SetOverrideBindingClick`. | This is the send primitive. |
| F3 | `SetAttribute` on secure frames is refused in combat (`InCombatLockdown()`). | Button contents are **baked** out of combat and frozen during it. |
| F4 | In bosses, the game silently drops a send within about 0.5–0.8 s of the player's previous one. The limit is per player. | A global spam guard of about 1 s (D12). |
| F5 | `%t` and `{rtN}` expand when sent. `{gN}` expands only in raids. | These are the only live tokens. Everything else is baked. |
| F6 | `C_ChatInfo.InChatMessagingLockdown()` and `ADDON_RESTRICTION_STATE_CHANGED` report lockdown reliably. | They drive the padlocks and chips. |
| F7 | Combat-only data (unit health, auras, cooldowns) and some chat payloads are secret values. | The situation engine reads only non-secret inputs, through the Compat guards. |

## 3. Identity and standard compliance

**Names and files:**

| Item | Value |
|---|---|
| TOC title / brand | `Ka0s Quick Comms` |
| Folder and repo | `QuickComms` |
| Author | `add1kted2ka0s` |
| Version | `0.1.0` |
| Interface | `120100` |
| Saved variables | `QuickCommsDB` (AceDB) and `QuickCommsPerfDB` (perf ring). Nothing else. |
| Chat tag | `NS.PREFIX = "|cff00ffff[QC]|r"` |
| Bus prefix | `Ka0s_QuickComms_` |
| Slash | `/qc`, with `/quickcomms` as an alias. A collision check for `/qc` against popular addons is part of phase 0. |
| Logos | `media/logos/quickcomms.logo.128.tga` and `media/logos/quickcomms.logo.tga`, from a 2000×2000 PNG source |
| Main panel | `QuickCommsMainPanel` |
| Test global | `QUICKCOMMS_TEST` |

**Libraries.** Vendored and committed:
- Ace3: AceAddon, AceDB, AceDBOptions, AceEvent, AceTimer, AceConsole, AceGUI
- LibStub, CallbackHandler, LibSharedMedia
- LibDataBroker-1.1, LibDBIcon-1.0
- **LibSerialize** and **LibDeflate**. Quick Comms is the first Ka0s addon to use these; add them to DEPENDENCIES.md and `standards/ADDONS.md`.
  *Built (phase 5):* LibDeflate `1.0.2-release` and LibSerialize `v1.2.3`, each copied whole from its tag with its license (`DEPENDENCIES.md`). `standards/ADDONS.md` already carries this addon's row, and the roster has no library column, so the libraries are recorded in `DEPENDENCIES.md` and `docs/ARCHITECTURE.md` (owner ruling, 2026-10-13).
- **LibKa0s v1.71.0**, copied whole, as one TOC line after Ace3
- `tests/_kit/`, from LibKa0s `testkit/`

**The whole standard applies.** In particular:
- the layout and load order
- TOC field order and the `# LOAD-BEARING:` / `# Conventional:` comments
- file headers
- the six setup files as a descriptor plus a stub
- a schema with one write seam
- a named registry writer
- the Lifecycle latch
- the disabled state
- the Options rules
- reserved slash verbs
- the launcher
- debug and diagnostics
- perf
- US English
- docs
- tests
- `.pkgmeta`
- `.luacheckrc`

**Repo fix-up in phase 0.** The current `.gitattributes` pins `eol=lf`. The standard requires the client-bound body, copied byte-identically: `* text=auto eol=crlf`, the `*.sh` and `*.py` carve-outs, and the binary list.
- Phase 0 replaces the file and runs `git add --renormalize .`.
- The current repo is docs only, so the renormalize diff is small.

**`Bindings.xml` at the root (owner ruling R1, 2026-10-13).** The client reads key bindings only from a file named `Bindings.xml` in the addon's root folder, which the standard's layout rule (source never loose at the root) did not allow. The owner changed the standard upstream rather than accept a deviation: WowAddonStandards v2.80.0 names `Bindings.xml` a client-read root file that is not a TOC line (layout-§1, toc-file-§4 (standard v2.80.0)). It is a standard change, not a deviation; the deviation register in `docs/ARCHITECTURE.md` stays empty.

**Where the standard is silent.** It has no rules on SecureHandlers, restricted snippets, state drivers or key bindings. §10 and §11 set this addon's rules, consistent with events-frames-taint-§2/§4 and slash-commands-§7. They are recorded in `docs/ARCHITECTURE.md → Taint Notes` and proposed upstream as a standard addition after v0.1.0.

## 4. Architecture

### 4.1 Layers

```
                ┌──────────────── settings/ (panel pages, slash, schema) ────────────────┐
                │                                                                          │
 game events ─► Situation ──SITUATION_CHANGED──► Resolver ──ACTIVE_GROUPS_CHANGED──► Surfaces
 (zone, key,    (pure classify                 (pure: When rules → active               (Pad, Dial:
  group, spec,   + edge reader)                 groups, per-surface order, "why")       layout, render,
  restriction)                                                                           feedback)
                                                    ▲                                        │ slot plans
 Library (registry writer) ──LIBRARY_CHANGED────────┘                                        ▼
 (callouts, groups, built-in overlay)                                  Bake (pure: tokens, channel,
                                                                        sanitize → one macro line)
                                                                                             │
                                                                                             ▼
                                                     SendEngine (the ONLY secure-attribute writer:
                                                     button pool, combat queue, bindings, spam guard,
                                                     echo tracker)
```

**The rule:** pure modules (Situation's classifier, Resolver, Bake, Tokens, Channels, LayoutMath, Share's codec) never touch the client. Each has headless tests. Edges read the client and publish on the bus.

### 4.2 File layout

```
QuickComms/
  QuickComms.toc  README.md  CLAUDE.md  DEPENDENCIES.md  LICENSE
  .gitattributes  .gitignore  .pkgmeta  .luacheckrc
  libs/            Ace3…, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0,
                   LibSerialize, LibDeflate, LibKa0s/ (whole)
  locales/         enUS.lua, PostLoad.lua
  core/            Namespace, MediaSetup, Constants, State, EnvSetup, CoreSetup,
                   PoolSetup, PerfSetup, DebugLogSetup, Bus, LifecycleSetup,
                   QuickComms (entry), Database, LauncherSetup, Compat (if needed)
  defaults/        Profile.lua, Global.lua,
                   BuiltIns_MythicPlus.lua, BuiltIns_Raid.lua, BuiltIns_Arena.lua,
                   BuiltIns_Battlegrounds.lua
  modules/         Situation.lua, Restrictions.lua, Library.lua, Resolver.lua,
                   Tokens.lua, Channels.lua, Bake.lua, SendEngine.lua,
                   SendEngine_Guard.lua, Surfaces.lua,
                   Pad.lua, Pad_Layout.lua, Pad_Render.lua,
                   Dial.lua, Dial_Secure.lua, Dial_Render.lua, Dial_Layout.lua,
                   Share.lua, Preview.lua, Diagnostics.lua
  settings/        Schema.lua, SchemaRows.lua, OptionsSetup.lua, Panel.lua,
                   General.lua, Callouts.lua, Groups.lua, Groups_When.lua,
                   Pads.lua, Dials.lua, Share.lua, Slash.lua, SlashVerbs.lua, Profiles.lua
  media/logos/     quickcomms.logo.128.tga, quickcomms.logo.tga, quickcomms.logo.png
  tests/           run.lua, wow_mock.lua, perf.lua, test_*.lua, _kit/
  docs/            (see §20)
```

*Built (phase 4):* `modules/Dial_Layout.lua` is the dial's pure ring layout (as `Pad_Layout` is the pad's). `Bindings.xml` sits at the root, beside the TOC, and is not a TOC line: the client reads it there, and the standard allows it (layout-§1, toc-file-§4 (standard v2.80.0); owner ruling R1, 2026-10-13).

*Built (phase 5):* `modules/Share.lua` is the share string's codec, checks and edge; `libs/LibDeflate/` and `libs/LibSerialize/` are vendored.

**Where the core files come from:** the core set and its order follow DropWatcher, the most compliant sibling, minus its addon-specific files (SimSeam, ClassData, ItemSetup, TextParse).

**`core/Compat.lua`** is created only if the addon owns a version-variant call. Likely candidates:
- `C_ChatInfo.InChatMessagingLockdown`
- `C_RestrictedActions`
- `C_ChallengeMode` keystone reads
- the `issecretvalue` fallback

DropWatcher's restriction readers are the template.

### 4.3 Modules

| Module | Kind | Owns |
|---|---|---|
| `Situation` | pure classifier + edge | Reads inputs, builds the **snapshot** (§6), coalesces bursts of events, publishes `SITUATION_CHANGED` |
| `Restrictions` | edge | Lockdown state and per-type restrictions (a copy of DropWatcher's `Restrictions.lua`). Publishes `RESTRICTION_CHANGED`. |
| `Library` | **the registry writer** (architecture-§5) | Callouts, groups, pads and dials (create, delete, duplicate, order, ids). The built-in overlay. Customize. Import. **The only module that writes those collections.** *Built (phase 3):* membership, the order of every list, the references a group and a surface hold, the ids and the seeding. A member's own fields (a callout's text, a group's When, a pad's layout and position, a built-in's overlay) are schema rows written through the one seam (architecture-§5), resolved by `Library.Member` and announced by `Library.Touch`. |
| `Resolver` | pure | When evaluation → active group set. The order for each surface. "Why" explanations. |
| `Tokens` | pure | Friendly token chips → engine tokens and baked values |
| `Channels` | pure | Channel kind + snapshot → chat prefix (`/p`, `/i`, `/raid`, `/rw`, `/s`, `/y`, `/w name`), or a refusal reason. The lock matrix (§8.4). |
| `Bake` | pure | Callout + snapshot → a single-line macro string, or a refusal. Sanitizing (§8.3). Length check. |
| `SendEngine` | edge, **the only secure writer** | Secure button pool, attribute writes, combat-end queue, override bindings, the spam guard, the echo tracker. Stand-down. |
| `Surfaces` | edge | Pad and Dial instances. Rebuilds on `ACTIVE_GROUPS_CHANGED` / `LIBRARY_CHANGED` (deferred in combat). The stale hint. |
| `Pad*` | edge | Pad frames, layout math (pure), render, feedback |
| `Dial*` | edge | The dial's secure header and snippets (`Dial_Secure`, which hands its writes to SendEngine), render, feedback. *Built (phase 4):* `Dial_Layout` (pure: rings, pages, geometry), `Dial_Secure` (the header's snippets; Relaxed only), `Dial_Render` (insecure regions on the secure frames, as `Pad_Render` paints chips), `Dial` (the frames, the pools, the keys). |
| `Share` | pure codec + edge UI | Export and import strings |
| `Preview` | edge | "Preview as…": feeds a synthetic snapshot to the Resolver and the surfaces in test mode |
| `Diagnostics` | edge | Diagnostics sections |

## 5. Data model

### 5.1 SavedVariables

`QuickCommsDB` is AceDB, with profiles. `defaults/Profile.lua` holds every default literal.

```lua
global = {
  schemaVersion = 0,                       -- the migration runner stamps it
  minimap = { hide = false },              -- LibDBIcon; global; vetoed from resets
}
profile = {
  -- Master controls (options-ui-§15)
  enabled = true, visibility = "always", scale = 1.0, alpha = 1.0, locked = true,

  behavior = {
    soloFallback   = "none",               -- "none" | "self" | "say"   (smart channels only)
    spamGuard      = 1.0,                  -- seconds, 0.6–2.0; global lockout (D12)
    dropNotes      = true,                 -- the [QC] chat note when a drop is inferred
    whyTooltips    = true,
    lockdownChip   = true,                 -- shown only when it matters (brainstorm §3.4)
    sounds         = false,
    autoPromote    = false,                -- narrower When floats up (Flat dial / merged pad)
  },

  nextId = 1,                              -- the registry writer's id counter
  callouts = {                             -- user callouts, keyed by id
    -- ["c12"] = { name = "Lust", text = "Lust on this pack {rt8}", channel = "smartGroup",
    --             icon = 136012 | "ka0s:chat" },
  },
  groups = {                               -- user groups, keyed by id
    -- ["g3"] = { name = "My M+", icon = …, callouts = { "c12", "c14" },
    --            when = { …see 5.3… }, openInto = false, enabled = true },
  },
  builtins = {                             -- overlay on the shipped sets; never their content
    -- ["bi.mplus"] = { enabled = true, hidden = { ["bi.mplus.lust"] = true } },
  },
  pads  = { --[[ ["p1"] = { name, enabled, groups = {ordered ids}, groupsAs, layout = {…}, look = {…}, point = {…},
                                seenBuiltins = { ["bi.mplus"] = true } } ]] },
  dials = { --[[ ["d1"] = { name, enabled, groups = {ordered ids}, mode, slices, depth, openAt, delay, interaction, key, tapAction,
                                seenBuiltins = { } } ]] },
  padOrder  = { },                         -- display order of pads in the nav rail
  dialOrder = { },
}
```

*Built (phase 4):* the member rows are `dial.name`, `dial.enabled`, `dial.mode`, `dial.slices`, `dial.openAt`, `dial.point` and `dial.key` (`false` is no key, and the default place; a named `/qc reset` reaches both, a page's Defaults keeps them); a new dial stores `interaction = "relaxed"`; `delay` and `tapAction` are kept for the C7 upgrade and `depth` for R5, and nothing reads them.

- **No `char` scope.** Per-character behavior comes from the When conditions **Character** and **Class/Spec** (brainstorm §9).
- **Sessions only.** Test mode, the debug console, "Preview as…" and the active settings tab are kept in `NS.State` and never saved.
- **Named non-setting state** (documented in ARCHITECTURE.md): `pads[id].point` is the `pad.point` member row: the drag, the X/Y boxes and Reset position write it through the seam (the drag through `Library.SetSurfacePoint`). It is a preference, not named state, because a control sets it. `dials[id].point` is the `dial.point` member row, written by the Comms Dial page's X/Y boxes and Reset position (through `Library.SetSurfacePoint`). `global.minimap.minimapPos` is owned by LibDBIcon.
- **The editors' selection** (`NS.State.editing`, session-only) is the member each editor page has selected; a member row written with no instance argument writes it.

### 5.2 IDs and references

- **User ids:** `c<n>`, `g<n>`, `p<n>`, `d<n>`, taken from `profile.nextId`.
- **Built-in ids:** stable dotted strings: `bi.mplus`, `bi.mplus.lust`, `bi.bg.ab`, `bi.bg.ab.lumbermill.inc3`. They never change once shipped. Renaming one requires a migration.
- **What groups can contain:** a user group holds user callout ids only. Adding a built-in callout to a user group **copies** it into the library first (Proposed P2). This keeps built-ins read-only and makes "used in N groups" exact.
- **What surfaces can list:** a surface's `groups` list may hold user group ids and built-in group ids.
- **Dangling references** are dropped at read time and repaired by the migration and prepare pass.

### 5.3 When conditions

```lua
when = {                     -- a nil or empty row is ignored; rows are ANDed, values in a row ORed
  content    = { mythicPlus = true, raid = true },   -- openWorld dungeon mythicPlus raid delve
                                                     -- scenario battleground arena housing
  instances  = { [2526] = true },                    -- instanceID (GetInstanceInfo 8th return)
  difficulty = { heroic = true },                    -- normal heroic mythic keystone lfr story follower
  keyLevel   = { min = 10, max = nil },              -- applies when the content is mythicPlus
  group      = { party = true },                     -- solo party raid instance
  leadership = { leader = true, assist = true },
  class      = { WARLOCK = true },                   -- classFile tokens
  spec       = { [265] = true },                     -- specIDs
  role       = { HEALER = true },                    -- TANK HEALER DAMAGER
  characters = { ["Traxex-Area52"] = true },
  battleground = { [2107] = true },                  -- instanceID (map) of a battleground
}
```

**Everything is matched by ID or token, never by a localized name** (localization-§4).

**Proposed P1:** the brainstorm's **Combat**, **Lockdown** and **Specific boss** conditions are **left out of v0.1.0**.
- **Why:** all three change *inside* combat, but surfaces can only be rebuilt outside it (F3). A boss-specific group would never appear in time, because every pull starts in combat.
- **What v0.1.0 does instead:** combat-time swaps are filed as a future issue. The idea there is pre-baked pages that a secure state driver switches between.
- **What remains possible now:** the "lockdown" idea survives as the padlock on locked channels (§8.4).

### 5.4 Migrations

- `core/Database.lua` holds `STEPS = { {to = 1, run = noop} }`, with `NS.SCHEMA_VERSION = 1`.
- The runner runs straight after `AceDB:New`.
- **A prepare pass on every profile load** does three things:
  - seeds a fresh profile with one default pad (`p1`) and one default dial (`d2`, unbound; pads and dials share one id counter), whose group lists hold every built-in group in the default order (D7)
  - repairs dangling ids
  - adds new built-in groups (shipped in a later version) to the **end** of each surface's list. A per-surface `seenBuiltins` sentinel records which ones each surface has already been offered.
- A global reset is `db:ResetProfile()` followed by the profile-changed handler (options-ui-§12), using the verbatim confirmation text.

*Built (phase 4):* step 2 (`perProfile`) moves the generic battleground set below the per-battleground sets on every pad and dial (`Library.MoveGenericBattlegroundLast`), so a node set can be the first active group (D9); `NS.SCHEMA_VERSION` is 2.

## 6. Situation engine

**The snapshot.** It is pure data, and the Resolver's only input.

```lua
snapshot = {
  content      = "mythicPlus",       -- openWorld dungeon mythicPlus raid delve scenario battleground arena housing
  instanceID   = 2526,  difficultyID = 8,  difficulty = "keystone",
  keyLevel     = 14,    challengeMapID = 556,
  group        = "party",            -- solo party raid ; instanceGroup = true|false
  instanceGroup = false,
  leader = true, assist = false,
  classFile = "WARLOCK", specID = 265, role = "DAMAGER",
  character = "Traxex-Area52",
  inCombat = false,                  -- display only (the stale hint), never a condition
  lockdown = { chat = true, encounter = false, challengeMode = true, pvpMatch = false },
}
```

**Classifier.**
- Start from DropWatcher `Situations.lua`: the pure `Classify`, the `ReadInputs` edge, and the `confirmedDifficulty` trick.
- Extend it with:
  - keystone level and `challengeMapID` (`C_ChallengeMode.GetActiveKeystoneInfo` / `GetActiveChallengeMapID`)
  - `instanceID`
  - `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)`
  - arena vs battleground (`instanceType` `"arena"` / `"pvp"`)
  - housing (`C_Housing.IsInsideHouseOrPlot`, behind a Compat guard)
  - class, spec, role, leadership
- Every read goes through `plainNumber` / `plainString`, so a secret value becomes nil and never errors.

**Events.** These all feed `Refresh(reason)`:
- `PLAYER_ENTERING_WORLD`
- `ZONE_CHANGED_NEW_AREA`
- `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_RESET`
- `GROUP_ROSTER_UPDATE`, `PARTY_LEADER_CHANGED`
- `PLAYER_DIFFICULTY_CHANGED`
- `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_ROLES_ASSIGNED`
- `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`

`Restrictions` publishes separately on `ADDON_RESTRICTION_STATE_CHANGED`.

**What triggers a re-resolve.** `inCombat` and `lockdown` are carried for display (padlocks, chips, the stale hint) and are left out of the signature that triggers a re-resolve. Entering combat never queues a rebuild.

**Coalescing.** `Refresh` schedules one read 0.1 s later. A burst of events (for example PEW, ZCNA and GRU on a zone change) gives one read and one publish. The publish happens only when the snapshot's signature changes.

## 7. Resolver

**`Resolver.ActiveGroups(snapshot, library) -> { [groupId] = matchInfo }`:**
- A group is active when it is enabled and every non-empty When row matches (D6 union).
- `matchInfo` lists the rows that matched. This is what "Why is this showing?" displays.

**`Resolver.SurfaceOrder(surface, active) -> { groupId… }`:**
- The surface's own list is filtered to the active groups, keeping the player's order.
- With `autoPromote` on, a stable sort moves narrower groups up within that order. Narrowness counts the non-empty rows, and a specific instance or battleground outweighs everything else. A badge records this.

**`Resolver.Explain(...)`** produces the lines for the "why" tooltip: "M+ (built-in): Content = Mythic+ ✓". *Built (phases 1, 3):* `Explain` names the When rows that matched (`M+ (generic) (built-in): Content`), not their values (`Content = Mythic+ ✓`): the row is what a player changes on the When tab, and the values are on that tab.

**Testing.** The Resolver is pure, so the When truth tables, the ordering and the explanations are all tested headlessly.

## 8. Callout text: tokens, channel, bake

### 8.1 Tokens (`Tokens`)

| Chip in the editor | Becomes | When |
|---|---|---|
| `{target}` | `%t` | Sent by the game, so it is live in combat |
| `{focus}` | `%f` | Live. **C9 unverified:** the owner tests `%f` with real messages. If it fails, remove the `{focus}` chip. |
| `{rt1}`–`{rt8}`, `{skull}`… | `{rtN}` | Live; each receiver renders it |
| `{group1}`–`{group8}` | `{gN}` | Live, raid only. The picker offers it only when the channel can resolve to Raid. |
| `{me}` | the player's name | Baked |
| `{spec}`, `{role}` | spec name, role | Baked |
| `{key}`, `{dungeon}` | key level, dungeon name | Baked. Empty outside M+, and the preview warns. |
| `{spell:ID}` | `C_Spell.GetSpellLink(ID)` | Baked. A fixed ID only. |

*Built (phase 3):* the Callouts page's picker offers `{target}`, `{focus}`, the eight markers by name (`{star}`…`{skull}`; a typed `{rt1}`…`{rt8}` works the same), `{me}`, `{spec}`, `{role}`, `{key}` and `{dungeon}`, plus `{group1}`…`{group8}` only when the callout's channel can resolve to Raid (raid, raid warning, smart group, smart lead). `{spell:ID}` needs an id, so it is typed, never picked; the Text row's tooltip names it.

An unknown token is left as typed and flagged in the editor's preview (the DropWatcher `Messaging.Expand` contract).

### 8.2 Channels (`Channels`)

**Kinds:** `say`, `yell`, `party`, `raid`, `instance`, `raidWarning`, `smartGroup`, `smartLead`.

**Resolution happens at bake time** from the snapshot (Proposed P3):
- `smartGroup` → `/i` if in an instance group, else `/raid` if in a raid, else `/p` if in a party, else the solo fallback.
- `smartLead` → `/rw` if leader or assist in a raid, or in a party (where anyone may send it); otherwise the same as `smartGroup`. An instance group (LFG, LFR, a battleground) gets `/i`, never `/rw`: its leader is assigned, so a warning there is noise (ruling, phase 1).
- Chat slash commands don't accept macro conditionals, so the resolution can't happen live.
- If the group changes during combat, the baked prefix may be stale until combat ends. It is refreshed then, like everything else.
- **C4 unverified (owner, 2026-10-13).** Re-baking between pulls during an active key assumes `SetAttribute("macrotext")` works out of combat inside a key (only `InCombatLockdown` should block it). If a real key shows otherwise, the fallback is the switch: bake once at key start, and situation changes inside the key wait until it ends.

**Solo fallback** (smart kinds only): `none` (the button shows as inactive), `self` (an insecure local print; nothing is sent), or `say`.

**Whispers are not in v0.1.0.** The owner's in-game test on 2026-10-13 showed that `%t` expands only in message text, never in the `/w` recipient slot (`No player named '%t' is currently playing.`, while `/s %t` works). `%t` and `%f` in message text work on every channel. Re-evaluation is tracked in [issue #7](https://github.com/tusharsaxena/QuickComms/issues/7).

### 8.3 Bake and sanitize (`Bake`): anti-pattern #20

`Bake(callout, snapshot) -> line | nil, reason`.

**Steps:**
1. Expand tokens.
2. Resolve the channel.
3. Sanitize:
   - Strip `\r`, `\n` and every other control character, so one callout is always **exactly one macro line**.
   - Collapse runs of whitespace and trim.
   - **Refuse** text whose first non-space character is `/`. Callout text is chat text, never a command, so `/run`, `/script`, `/dump`, `/cast` and friends can never reach `macrotext`.
   - Escape a stray `|` as `||`, except inside a game-generated `{spell:ID}` link.
4. Check the length: at most 255 bytes for the **whole** baked line, prefix and space included, because `macrotext` runs through the edit-box path whose cap counts the line as typed. Live tokens are counted at a nominal 12 bytes, and the editor's counter shows that.
5. Output `"<prefix> <text>"`.

**Imported text** goes through the same sanitizer when it's imported, and again at every bake.

*Built (phase 5):* an import stores `Bake.CleanText`'s answer: this sanitizer short of the `|` escape, which every bake still applies, so a stored `|` is escaped once. That covers callout text, which is sent; a name or a field's string is only drawn, so an import stores it with its `|` escapes made literal (§15), as a typed `|` already is.

### 8.4 The lock matrix

`Channels.LockState(kind, snapshot) -> nil | reason`.

A locked callout stays visible with a padlock and a tooltip (brainstorm §3.3).

| Kind | Locked when | Source |
|---|---|---|
| say, yell | `lockdown.encounter` or `lockdown.pvpMatch`. Outside an instance, it needs a hardware event, which a click or key press provides. | C2 unverified |
| raid, raidWarning | Not in a raid (or, for RW, not leader or assist in a raid) | game rule. **C1 unverified** (`/raid` and `/rw` on a premade-raid boss) |
| party, instance | Not in that kind of group | game rule. **C3 unverified** (battleground `/i`, arena `/p`) |
| guild, community, custom | Not offered at all in v0.1.0. Lockdown blocks them. | research 01 |

**Unverified checks C1 and C3 (owner, 2026-10-13).** The owner skipped the in-game checks and tests with real messages instead. The primary design stands: these channels send during encounters. If a real message shows `/raid`, `/rw`, battleground `/i` or arena `/p` fails during an encounter, the fallback is the switch: add that channel to the `lockdown.encounter` (or `pvpMatch`) row above, with the same padlock as Say.

**The lockdown chip** shows on a surface only when at least one of its visible callouts is locked *because of lockdown* (brainstorm §3.4).

## 9. Send engine (`SendEngine`): the only secure writer

**This module is the protected-API firewall** (events-frames-taint-§4). It is the only code that:
- calls `SetAttribute` on secure frames
- calls `SetOverrideBinding*` / `ClearOverrideBindings`
- calls `RegisterStateDriver` / `UnregisterStateDriver`
- creates secure frames

`Dial_Secure` writes its snippet text and attributes through SendEngine's API. A luacheck/grep test asserts that no other file contains those calls.

### 9.1 Send buttons

**Pool.** Secure buttons come from a `LibKa0s-Pool` keyed pool:
- template `SecureActionButtonTemplate`
- `RegisterForClicks("AnyUp", "AnyDown")`, which the test showed is needed for `type=macro`
- names `QuickCommsSend<n>`, needed for `SetOverrideBindingClick`

*Built (phase 2):* one array pool per pad (`NS.Pool.New`), the family the addon already wires; the pad keeps a `byCallout` index for its flashes, so the keyed family is not needed.

**`SendEngine.Arm(button, line)`:** `type=macro` and `macrotext=line`. **`Disarm`:** sets both to nil, and never calls `:Disable()` (the WhatGroup pattern).

**Who owns which buttons:**
- **Pads:** each pad chip *is* a send button, parented to the pad.
- **Dials:** each dial owns a set of hidden send buttons, one per slot, which its secure header clicks (§11).
  *Built (phase 4):* each wedge *is* its slot's send button (as §11.2 says), parented to its ring's protected container; the player clicks it, not the header. The header's snippets wrap each wedge's click before SendEngine's hook (the client's wrap replaces the script). A wedge acts on the up edge, and only a left click (or a number key) is a press.

**Combat-end queue.** It is keyed, and copies WhatGroup and PanelMaster's Unlock:
- `Queue(key, fn)` replaces any earlier entry under the same key.
- `Drain()` runs first on `PLAYER_REGEN_ENABLED`.
  *Built (phase 2, fix wave):* `Restrictions` owns the edge and calls `Drain` from it directly, not only through a `RESTRICTION_CHANGED` that the edge may not send (after a login or `/reload` in combat no signature was seeded, so the end of combat moves nothing).
- `Drop(reason)` runs on stand-down or a profile switch.
  *Built (phase 2, fix wave):* stand-down drops every entry; a profile switch drops only what it supersedes (`surfaces`, `positions`) and keeps a held drag's stop (`padDrag`), which saves the point only into the profile it was dragged in.
- `Snapshot()` feeds diagnostics.

Every rebuild requested in combat goes through this queue and sets the surface's **stale hint**.

### 9.2 Spam guard (D12)

**Goal:** never send twice within `behavior.spamGuard` seconds (about 1 s), across every callout and surface. That keeps sends under the boss throttle (F4).

**There is no hard guard in combat** (owner, 2026-10-13), because insecure code can't cancel a secure click. The guard is soft:
- **Insecure part.** `HookScript("OnClick")` on each button, which never taints the secure path:
  - starts the visual cooldown (the chip and wedge dim for the guard window), which discourages a second press
  - records the click for the echo tracker
- an actual drop is detected and reported instead (§9.3)

**Upgrade once C5 is verified.** If `GetTime()` is available inside restricted snippets, one shared **guard header** (`SecureHandlerBaseTemplate`) wraps every send button's OnClick with `SecureHandlerWrapScript`. Its pre-click snippet reads the last send time from a header attribute and returns `false` to cancel the click if the guard window hasn't passed; otherwise it stamps the time.

### 9.3 Echo tracker: inferring "dropped"

**How it works:**
- For each click, it records `{at = GetTime(), chatType}`.
- It listens to the `CHAT_MSG_*` events for the player's own channels and **never reads their text**, which may be secret (F7).
- A click with no matching event of that `chatType` within 1.5 s counts as **dropped**: the wedge or chip flashes red and, if `dropNotes` is on, one `[QC]` line is printed.
- Other players' messages on the same channel can mask a drop. This is accepted as best effort.
- *Built (phase 2, fix wave):* a press on a padlocked chip (§8.4; it stays armed) is not tracked: no guard stamp, no dim, no echo awaited, so the game's refusal is never reported as a drop. With `dropNotes` on, one `[QC]` line names the lock instead.
- *Built (phase 2, fix wave):* without a readable GUID the sender's full name decides. A sender with a realm is the player only on the player's own realm (a cross-realm namesake is not); when the player's realm cannot be read that answer is unknown.

**C6** checks whether the sender of the returning message can be read. **Unverified (owner, 2026-10-13).** The tracker must tolerate an unreadable (secret) sender: it treats that as unknown and never as dropped. If the sender can be read, it matches on sender and the false "sent" goes away.

*Built (phase 4, §9.2 and §9.3):* a wedge's press dims every chip and every wedge for the guard window, and `SEND_RESULT` flashes the callout's wedges; the dial closes on a send, so both show on the next open, and a drop stays red for 5 s so the player can reopen the dial and see it.

### 9.4 Key bindings

*Phase 2 ships no binding:* a pad chip has no key in v0.1.0. Override bindings, `Bindings.xml` and their stand-down arrive with the Comms Dial (phase 4).

**Binding storage.** Dial keys are bound with `SetOverrideBindingClick(owner, true, key, "QuickCommsDial<n>")` out of combat. They are stored in the dial's `key` field, **not** in WoW's own key bindings.

**Lifecycle:**
- Bindings are re-applied at login, on a profile switch, and on stand-up.
- They are cleared on stand-down, deferred if in combat (slash-commands-§7).
- A key conflict with an existing WoW binding shows a warning in the dial editor and still binds: an override binding wins only while QuickComms is enabled.

**`Bindings.xml`:** v0.1.0 also ships one, with `BINDING_HEADER_QUICKCOMMS` and "Open Comms Dial 1–4". Players who prefer the game's own key bindings menu can use it. Those bindings click the same named buttons.

*Built (phase 4):* a header is named `QuickCommsDial<n>` for its place in the dial order, and the key clicks it with the button `Toggle`; `Bindings.xml`'s entries are `CLICK QuickCommsDial1:Toggle` … `4`. Escape, the left and right mouse buttons and the mouse wheel cannot be a dial's key whatever the modifiers, nor 1–8 without one, because the open dial uses them; one key opens one dial. A key is one base key with ALT-, CTRL-, SHIFT- or META- in front, none twice; a modifier alone, a dangling or unknown one is refused, and a key is stored with its modifiers in the client's order (SHIFT-CTRL-G is stored CTRL-SHIFT-G), so one chord is one key. Every rebuild re-binds the whole set (`SendEngine.BindKeys`), so a profile switch, the stand-up and a key edit re-bind. `Bindings.xml` sits at the addon root and is not a TOC line, as the standard allows (layout-§1, toc-file-§4 (standard v2.80.0)).

### 9.5 Stand-down

The disabled state is total (slash-commands-§7):
- Disarm all send buttons and hide every surface.
- Clear override bindings and unregister state drivers.
- Unregister every event and message, and cancel timers and OnUpdates.

If this happens in combat, the secure parts are held in the one permitted pending registration and finished on `PLAYER_REGEN_ENABLED`.

## 10. Comms Pad

### 10.1 Frames

**The pad itself:**
- The root is a plain frame. Because it has secure children, it becomes protected in combat.
- Its header is a LibKa0s `DragHandle`. `canDrag` is refused when locked or in combat.

*Built (phase 2):* the header is a plain row that always shows its chips; the LibKa0s `DragHandle` is a strip above the pad, shown only while unlocked (KickCD's shape), and its `canDrag` refuses while locked or in combat. A drag in progress when combat starts is ended at the combat edge, so the root's `StopMovingOrSizing` is never blocked.

**Header contents:**
- the situation chip (e.g. "M+ · Windrunner Spire +14")
- the lockdown chip (§8.4)
- the stale hint ("⟳ updates after combat")
- a collapse toggle

**Chips.** Each chip is a pooled secure send button with:
- a square icon tile
- a label
- a channel tag colored with WoW's chat colors; `smart*` shows the channel it resolved to
- a padlock overlay when locked

**Skin:**
- the Ka0s skin: body 0.06, 0.06, 0.08, 0.92, with a 1px edge
- a gold hover outline
- a gold flash on send and a red flash on an inferred drop

*Accepted deviations (phase 2):* the hover is drawn as a gold fill over the chip, not an outline, and the stale hint is the text "updates after combat" with no glyph.

### 10.2 Layout (`Pad_Layout`, pure)

**Options:**
- **Orientation:** horizontal, vertical, or grid (N columns).
- **Growth:** from the anchor.
- **Style:** icon + label, icon only (the label goes in the tooltip), or label only.
- **Size:** scale, spacing and button width.
- **Groups as:**
  - sections (small-caps labels)
  - merged (one list)
  - tabs (one group at a time; the mouse wheel over the pad switches)

**Implementation.** It reuses KickCD `IconGrid_Layout`'s `placeBlock` / `layoutBlock` math, and is tested headlessly.

**Tabs in combat:** tab switching is refused in combat, with a one-line tooltip, and sections are the default (owner, 2026-10-13).

**Upgrade once C8 is verified.** Switching tabs would show and hide prebuilt per-tab containers of secure children, done by a `SecureHandlerWrapScript` on the pad's `OnMouseWheel` in the restricted environment.

### 10.3 Visibility and look

**Visibility:** `always`, `inCombat`, `outOfCombat`, `whenActive` (at least one active group), or `never`.
- The combat-dependent values use a secure **state driver**: `RegisterStateDriver(pad, "visibility", "[combat] show; hide")` or the reverse. Insecure Show/Hide would be refused in combat.
- The master `visibility` applies on top.

**Fade** is applied with `SetAlpha`, which is allowed in combat:
- fade when out of combat, or
- fade to x% until the mouse is over the pad

**Hide when no group is active** is evaluated at the last out-of-combat rebuild.

*Built (phase 3, 5):* the pad's Look tab has visibility, fade and the faded alpha, then the composed Font, Border and Background groups (options-ui-§16, §17) under their own headings. The font draws the chips' labels and the section titles (a title keeps its gold until the player picks a font color or Use class color); the border's style "None" is the flat Ka0s edge and a thickness of 0 is none (the Ka0s 1px inner line is worn only on the default flat 1px edge, never at 0, over a thicker edge or over border art, which insets the background by a quarter of its size); the background is a swatch and its class-color companion. A larger font size grows the labeled chips and the title rows to hold it (the default 10 keeps the shipped 24/22/14 heights), and a chip's label is one line that stops short of the channel tag. The class color is the player's; the defaults are the skin a pad always wore; a font or border this machine does not have draws the default.

### 10.4 Test mode and position

**Test mode** (preview-mode) fills every pad with placeholder chips through the same render path, and shows a "TEST MODE" label. It:
- ends at `PLAYER_REGEN_DISABLED`
- is refused in combat, with one line

**"Preview as…"** (§13.3) feeds a synthetic snapshot to the same path.

**Position:**
- `point` lives in the profile.
  *Built (phase 2, fix wave):* every rebuild re-anchors the pad from the active profile, so a profile switch, copy or reset moves an existing pad (in combat, at the drained rebuild). A pad being dragged keeps the cursor's place.
- X and Y rows sit on the pad's Layout tab.
- Reset position is in Master controls, and resets every pad and dial anchor.

*Built (phase 2, 4):* Reset position resets every pad and dial anchor, with one chat line; the per-pad X/Y rows arrived with the Pads page (phase 3), the per-dial ones with the Comms Dial page (phase 4).

## 11. Comms Dial

### 11.1 Feel

The Blizzard ping wheel's look (brainstorm §4):
- a dark translucent disc
- thin spokes
- a large icon on each wedge and a white label outside the disc
- a gold glow on the selected wedge, with a pointer
- a round ✕ hub in the middle

**Rendering is insecure** (`Dial_Render`): textures and font strings on a non-protected frame. Insecure code may show and hide it even in combat.

**Wedge geometry.** The wedges sit on compass directions, with on-axis directions first: 4 wedges are N/E/S/W. A battleground node set may pin each node to its real compass direction.

*Built (phase 4):* the paint is insecure regions on the secure frames (the disc and ✕ on the header, spokes and a title per ring, an icon, label, padlock, dim veil and gold hover glow per wedge); the pointer is a plain child whose `OnUpdate` runs only while the dial is open (perf `dialRender`).

*Built (phase 5):* node sets are pinned to their compass winds, derived from the client's AreaPOI table by `tools/derive-winds.py` (each node's position against the center of its set's nodes, north up; a node near that center is the middle). A pinned ring has eight wedges, whatever the dial's slices, and is never paged; a middle node takes the first wind left free clockwise from N; a wind with no node has no wedge; the number keys pick the shown wedges clockwise from N. Flat mode is not pinned. Deepwind Gorge's current map has five nodes: Shrine and Ruins joined Market, Farm and Quarry (owner ruling, 2026-10-13; brainstorm §8 listed three).

### 11.2 Secure structure (`Dial_Secure`)

**Frames:**
- **The header:** one secure header per dial, `SecureHandlerClickTemplate`, named `QuickCommsDial<n>`, with the dial's key bound to it.
- **Send buttons:** one hidden secure send button per slot, armed by SendEngine with the baked line.
- **Attributes on the header:** the ring layout (slot count, the ring id for each slot, child rings, the open-into flag, `openAt`) and `state` (`closed`, `ring:<id>`).

**Relaxed mode (the v0.1.0 design, owner 2026-10-13).** Pressing the dial's key toggles the dial open and pressing it again closes it. While it is open, the wedges are real secure buttons (each one is that slot's send button, armed with the baked line) and the player clicks one to send; the dial then closes. Escape, a right click or a click in the hub also closes it, and the hub's ✕ goes up a ring when there is one. The insecure render only draws and hides; the secure header holds the ring state.

**Upgrade (C7): hold, flick and release.** This needs restricted `GetMousePosition` / `SetBindingClick` (after OPie's published approach, new to Ka0s) and is tried once C7 is verified in game.

**Key down** (the header's restricted `OnClick` snippet, `down == true`):
- Record the cursor origin with `self:GetMousePosition()` and set `state=ring:<top>`. If open-into applies, the top ring is the first active group's ring (D9).
- `SetBindingClick` captures LeftButton, RightButton, Escape and the mouse wheel to the header while the dial is open, as OPie does.
- The insecure render is told to open through a hook.

**Key up** (the restricted snippet, `down == false`):
- Compute the angle and distance from the origin.
- If the cursor is outside the dead zone (Quick mode):
  - **Callout wedge:** set `type=click` and `clickbutton=<that slot's send button>` on a relay, so the press goes on to the send button. Then close.
  - **Group wedge (Categories mode):** switch `state` to that group's ring and recentre the origin. **The dial stays open for a second stroke** (Proposed P4). A left click or a second press and release of the dial key sends, and Escape, right click or a release in the hub cancels.
- If the cursor is inside the dead zone on a tap:
  - `tapAction = "first"` sends the first callout of the highest-priority active group (brainstorm §4).
  - `"none"` cancels.

**Number keys 1–8 and the mouse wheel** are captured while the dial is open. The numbers pick wedges clockwise from N; the wheel pages a Flat ring.

**Draw delay of about 300 ms (Upgrade, C7):**
- The insecure render waits `delay` before drawing. A flick within that time sends without the dial ever being drawn.
- The secure side never waits: selection is purely geometric.

In Relaxed mode the dial is drawn as soon as it opens.

*Built (phase 4):* the header is the hub. The ring on screen lives in the header's restricted environment (a snippet global); no snippet writes an attribute, so every attribute and frame ref is written out of combat through SendEngine. Only a left click (or a number key, which clicks with it) sends from a wedge or goes up a ring from the hub; any other mouse button closes the dial, so a dial whose key is a mouse button (BUTTON3–5) closes, and sends nothing, when its key is pressed again over a wedge or the hub. One dial is open at a time: opening a dial closes any other that is open (each header holds the others as frame refs), so two never overlap or share the number keys. Opened by its key, the snippets bind Escape (close), the mouse wheel (pages) and 1–8 (the shown ring's wedges) with `SetBindingClick`, released on close; opened from the insecure side (test mode, Preview as…) they bind nothing, so the settings window keeps Escape. Open at the cursor re-anchors the hub with a restricted `SetPoint("CENTER", "$cursor")` (unverified until DIAL-7).

### 11.3 Modes and limits

**Modes:**
- **Categories** (the default, D2): the top ring holds groups, and each group's sub-ring holds its callouts. Choosing a group takes a second click in v0.1.0.
- **Flat:** the top ring holds callouts from the highest-priority group down. Any overflow goes to "More ▸" pages, which the wheel or the More wedge switches between.

**Limits:**
- Slices per ring: 4 (the default), 6 or 8. 12 is allowed only on a ring with no children.
- Depth is 2. Depth 3 (a battleground node set under Categories when open-into is off) is allowed, with the editor warning.

**Open-into** (D9) is a flag per group. It is on for the battleground node sets. When the first active group in the dial's order has the flag, the dial opens on that group's ring, and the hub's ✕ goes up to the group ring instead of cancelling.

*Built (phase 4):* a ring with more items than its wedges is paged on every ring, Categories included: each page but the last holds `slices − 1` items and a More wedge, and the hub and the wheel go back a page. The wedge count is the slices setting, never grown; a ring that holds a ring (a More included) gets 8 on a 12-slice dial. In Flat a node's callout is titled with its node ("INC 3 · Lumber Mill"). Depth counts rings from the one the dial opens on: groups, then callouts, is 2; a node set reached under the group ring is 3, and the Comms Dial page's Groups tab warns, naming the set (`Dial_Layout.DeepGroups`, built under that battleground's preview); open-into skips the group ring, so a set that opens into itself is 2. On the open-into ring the hub's ✕ goes up to the group ring rather than closing the dial. With a single active group, Categories opens straight on its ring, as open-into does; the hub still goes up to it (owner ruling R2, 2026-10-13). Depth is this limit, not a setting: the Wheel tab has no depth control (owner ruling R5, 2026-10-13).

### 11.4 Other

**Where the dial opens:** `openAt` = `center` (the default) or `cursor` (D3). It is set by the insecure render; the secure maths uses positions relative to the origin, so neither choice affects selection.

**Test mode** shows dial 1 open with placeholder wedges, at the configured position. **The dial editor's Preview tab** renders the dial inside the panel. It is insecure and display only.

*Built (phase 4):* test mode and Preview as… open dial 1 on its first ring (or the open-into ring) at its place, with placeholder or disarmed wedges and TEST MODE or PREVIEW above the hub, taking no key (the settings window may be open: Escape still closes it, and 1–8 stay the action bar's); the hub or the dial's key closes it. It opens when the mode turns on or changes (another Preview as… situation), and a rebuild keeps it open only if it was open: once the player closes it, later edits do not bring it back over the settings window. The Comms Dial page's Preview tab lists the rings wedge by wedge; the drawn dial is the in-game preview (owner ruling R3, 2026-10-13).

**Stale and lockdown:** the hub shows the same stale hint and lockdown chip as a pad.

## 12. Built-in sets

### 12.1 Data

The sets are in `defaults/BuiltIns_*.lua`. This is shipped data, not registry members (architecture-§5). Shape:

```lua
NS.BuiltIns.groups["bi.mplus"] = {
  name = L["M+ (generic)"], icon = …, when = { content = { mythicPlus = true } },
  callouts = { "bi.mplus.pull", "bi.mplus.lust", … },
}
NS.BuiltIns.callouts["bi.mplus.lust"] = { name = L["Lust"], text = L["Lust on this pack {rt8}"],
  channel = "smartGroup", icon = … }
```

**Content and channels** come from brainstorm §8:
- **M+:** smartGroup.
- **Raid:** raid, with RW only on the lead callouts.
- **Arena:** party.
- **Generic battleground:** smartGroup, which resolves to instance chat.
- **One set per battleground:** matched on the battleground's `instanceID`. Nodes are pinned to compass directions, with `openInto = true`. The battleground list is the 14 from brainstorm §8, and phase 5 confirms their instance IDs.
  *Built (phase 4):* the generic battleground set ships after every per-battleground set (and migration step 2 moves it there on stored profiles): D9 opens into the first active group, so a node set must come first.
  *Built (phase 4):* the paint is insecure regions on the secure frames (the disc and ✕ on the header, spokes and a title per ring, an icon, label, padlock, dim veil and gold hover glow per wedge); the pointer is a plain child whose `OnUpdate` runs only while the dial is open (perf `dialRender`).
  *Built (phase 5):* node sets are pinned to their compass winds, derived from the client's AreaPOI table by `tools/derive-winds.py` (each node's position against the center of its set's nodes, north up; a node near that center is the middle). A pinned ring has eight wedges, whatever the dial's slices, and is never paged; a middle node takes the first wind left free clockwise from N; a wind with no node has no wedge; the number keys pick the shown wedges clockwise from N. Flat mode is not pinned. Deepwind Gorge's current map has five nodes: Shrine and Ruins joined Market, Farm and Quarry (owner ruling, 2026-10-13; brainstorm §8 listed three).
  *Built (phase 5):* every id the fourteen sets list is a battleground map in the client's Map table (build 12.1.5.70340), matched by `tools/derive-gameids.py` and `tests/test_gameids.lua`; none changed. The in-game confirmation is smoke check BG-2, owed until it passes. Midnight's Slayer's Rise (map 2799) is not among the fourteen; the generic battleground set covers it.
- **Wording** is faction-neutral (D11).

**Battleground node structure** (brainstorm §8): each battleground group has one child group per node, and each node's sub-ring is INC 1 / INC 2 / INC 3 / INC Many / Clear / Help.
- The callout text is built from a template, `"INC 3 {node}"`, with the node name baked in.
- These are the only built-in groups with children. The `children` field on a group is used **only by built-ins** in v0.1.0. User nesting is a future issue.

### 12.2 Behavior

**On by default (D7):** the prepare pass puts every built-in group in the default pad's and dial's lists.

**The overlay** (`profile.builtins[id]`) has:
- `enabled`
- `hidden[calloutId]`, which hides a callout without copying the set

**Customize** is a `Library` writer operation. It:
- deep-copies the group and its callouts into user ids
- copies `when` and `openInto`
- swaps the copy into every surface list at the built-in's position
- sets the built-in's `enabled = false`

It is one act: the pads rebuild once. A set on no surface is customized onto none, and the chat line says so. **Deleting the copy** undoes it (ruling, phase 3 final fixes): the built-in goes back into the copy's place on every surface that does not list it already, it is turned back on, and it forgets the copy, so Customize can run again.

**Updates.** A new addon version may change built-in text freely. Customized copies never change.

**Bake audit** (a test): every built-in callout must bake under its expected snapshot to a whole line of 255 bytes or fewer, with a valid channel and no `/` start.

## 13. Settings panel

### 13.1 Pages

**Blizzard Settings ▸ AddOns ▸ Ka0s Quick Comms**, built with LibKa0s-Options. The body is built lazily, and a library breadcrumb sits on every page.

| Page | Structure |
|---|---|
| **Landing** | Library `BuildLandingPage`: logo, notes, the slash command list |
| **General** | Tabs: **Master controls** (the exact standard rows), **Behavior**: solo fallback, spam guard slider, drop notes, why tooltips, lockdown chip, sounds, auto-promote |
| **Callouts** | Banner: a callout picker and a "Create callout" box. Tabs: **General** has name, text with a token picker and the live line (the baked line and its byte count under the current or previewed situation, or why it sends nothing, and the padlock text), channel, an icon box (a texture id or path; a LibKa0s icon by its path; under it, Choose an icon: the eight raid markers, the icons the built-in sets wear (read from the sets) and the LibKa0s catalog's marks an allowlist keeps; a click is the icon (built phase 5; any other texture is typed)), then Duplicate and Delete (options-ui-§14: a page's acts sit on its first tab, named General). The live line is the byte counter: it follows each committed write (Enter in the Text box), not each keystroke. **Used by** lists the groups that reference it, each a link to the Groups page. |
| **Groups** | The banner picker (user groups by name, then the built-in sets; a green dot marks a group active now or in the preview) and New group, which puts the group at the top of every pad and dial; no nav rail (options-ui-§14: the rail is not a picker). Tabs: **General** (name, icon, enabled, open-into, delete/duplicate, and Customize for a built-in), **Callouts** (ReorderList, plus add from the library), **When** (§13.2), **Preview**. For a built-in, General has its Enabled row and Customize, and Callouts is the hidden-callouts editor. A user group's General tab has the same picker as a callout's (Choose an icon; built phase 5). |
| **Comms Pad** | The banner picker and New pad; no nav rail. Tabs: **General** (name, enabled, unlock, delete), **Groups** (priority ReorderList, plus groups-as), **Layout**, **Look** (visibility, fade, font group, border group, colors with class-color companions) (built phase 5: the background is the one color group). General also has Preview as, Unlock pads and Delete pad; Layout ends with the X and Y offsets and Reset this pad's position. |
| **Comms Dial** | The banner picker and New dial; no nav rail. Tabs: **General** (Preview as, name, enabled, Delete dial), **Groups** (Categories/Flat, the depth-3 warning, the priority ReorderList, Add a group), **Wheel** (wedges per ring, open at, the X and Y offsets and Reset this dial's position), **Binding** (how Relaxed works; a key capture box; the key's line: what it opens, or the WoW binding it shares, which still binds), **Preview** (each ring wedge by wedge). Quick mode's delay and tap action return with the C7 upgrade. |
| **Share** | Tabs: **Export** (select callouts, groups, pads and dials → string → `CopyWindow`), **Import** (a paste box → validation report → apply), **Built-in** (the list of built-in sets with an enabled toggle, Customize, and a hidden-callouts editor). *Built (phase 3, 5):* Export (a checkbox per callout, group, Comms Pad and Comms Dial, under a heading per kind; what is ticked brings what it needs; the string opens selected in the copy window), Import (the paste box; Accept checks, the report shows, Import adds) and Built-in (one line per set). |
| **Profiles** | AceDBOptions, the one permitted AceConfigDialog page |

**Every page has a tab strip**, and every row has a `group`.

**Panel rules:**
- The panel refuses to open in combat, and the library locks any page shown in combat.
- Setters that rebuild secure frames gate on `InCombatLockdown()` and queue through SendEngine.

### 13.2 The When editor (`Groups_When`)

It looks like the WeakAuras Load tab:
- One row per condition from §5.3, each with an enable checkbox and a multi-select (or a range for the key level).
- Instance and battleground pickers are searchable lists keyed by `instanceID`, and use LibKa0s `Autocomplete`.
- The list data comes from a shipped ID table; there is no localized-name matching.
- A live line reads "Active now ✓ / ✗", with the reason.

*Built (phase 3):* checkbox rows for content, difficulty, group, leadership, class, specialization (the classes picked, else the player's) and role; a lowest and highest box for the key level; the library's IdList for instances, battlegrounds and characters (`Name-Realm`), each with an add-the-one-you-are-in button. The shipped id table (`defaults/GameIds.lua`) lists the season's returning dungeons; the Midnight dungeons (Windrunner Spire 2805, Magisters' Terrace 2811, Nexus-Point Xenas 2915, Maisara Caverns 2874) and raids (The Voidspire 2912, The Dreamrift 2939, March on Quel'Danas 2913) and spec 1480 are matched against the client's data tables in phase 5 (`tools/derive-gameids.py`); the in-game confirmation is smoke check IDS-1, owed until it passes. Sporefall (1592) is left out by owner ruling R4.

### 13.3 Preview as… and Why is this showing?

**Preview as…:**
- A session row, `state.previewAs`, drawn first on the General tab of the Groups and Comms Pad pages and the Comms Dial page, and `/qc preview <name>` from the command line, with these entries:
  - **Current**
  - **M+ · <dungeon> · <spec>**
  - **Raid · <difficulty>**
  - **Arena**
  - one entry per battleground
  - **World solo**
- It builds a synthetic snapshot and turns on test mode for the surfaces, so they render the resolved groups live.
- It is session-only, and switches off when the panel closes or combat starts. *Built (phase 3):* it is test mode's second flavor: one switch at a time with the placeholders, refused in combat and while disabled, ended at the start of combat, by the stand-down and when the settings window closes. Every previewed chip is disarmed (it sends, prints and reports nothing) and its tooltip says so; the header reads `Preview: <situation>` and shows PREVIEW. The dungeon entries are the shipped ids (`defaults/GameIds.lua`), each `M+ · <dungeon> · <spec>` as listed above (`M+ · <dungeon>` when the spec is unknown), after a generic `M+ · <spec>`.

**Why is this showing?** is the tooltip on the pad header and the dial hub. It lists the groups shown in priority order, with `Resolver.Explain` lines, plus any locks.

## 14. Slash commands

Through `LibKa0s-Slash`.

**Reserved verbs:**
- `help`, `config` (and bare `/qc`), `version`
- `list`, `get`, `set`, `reset <path>`, `resetall`
- `debug`, `diagnostics`, `perf`
- `enable`, `disable`, `lock`, `unlock`

**Feature verbs** (`docs/slash-dispatch.md`):

| Verb | Does |
|---|---|
| `test` | Toggle test mode. It is the same handler as the checkbox and the launcher entry. |
| `preview <situation>` | Set "Preview as…" from the command line |
| `check <calloutId>` | Prints the baked line, the resolved channel and any lock reason. **It never sends.** Addon code can't send during lockdown, and a slash-command send would be a second path (D12). It is named `check` rather than `send` (it doesn't send) or `test` (the reserved test-mode toggle). |
| `why` | Print "Why is this showing?" for every surface |

While the addon is disabled, feature verbs answer with the standard one-line refusal.

## 15. Share (export and import)

**Format:** `!QC1!` + `LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(payload)))`.

```lua
payload = { v = 1, addon = "QuickComms", kind = "bundle",
            callouts = {…}, groups = {…}, pads = {…}?, dials = {…}? }
```

**Import:**
1. Decode.
2. Check `v`. Older versions migrate forward; newer versions are refused with a message.
3. Validate against the schema:
   - types
   - ID shapes
   - channel kinds
   - lengths
4. Run the §8.3 sanitizer over every text field.
5. Show a report: "3 callouts, 1 group; 1 callout refused: starts with /".
6. Apply through `Library.Import` (the registry writer). Ids are re-mapped into fresh user ids, and nothing is executed (anti-pattern #20).

**Restrictions:**
- Imported pads and dials arrive **unbound**.
- Export and import are refused in combat.

**UI:** export uses LibKa0s `CopyWindow`. Import uses an AceGUI MultiLineEditBox on the Share page.

*Built (phase 5):* `v = 1` is the first version; `MIGRATIONS` is empty and already walked. The checks: a name is 1 to 32 characters, a callout's text and an icon path at most 255 bytes after sanitizing (bytes, as `Bake` caps a line; the editor's Text box counts characters, so a text that types in may still be refused on import, and could never have baked), a pasted string at most 50,000 characters (whitespace in it ignored), its decompressed payload at most 512 KiB before anything reads it, one string at most 500 members; ids are `c<n>`, `g<n>`, `p<n>`, `d<n>`; every text and icon path passes `Bake.CleanText`, and so does every string in a surface's field values, nested ones and their keys included (a key the sanitizer would change, one past 255 bytes or holding a `|`, or a number key that is not finite, leaves the value out); a name is flattened to one line and trimmed but may start with `/` (it is never sent); names and a field's strings are drawn, never sent, so each is stored with its `|` escapes literal (a lone `|` doubled, as the game's edit box stores a typed one); a When's Name-Realm holds no control or `|` character and is at most 96 bytes; a refused member is reported by its name, or by its id only when that id is at most 32 letters, digits and dots, else "(unnamed)"; a field value that is not finite, not plain data or nested too deep is left out; a check that still raises reads as a damaged string. A callout travels as `{ name, text, channel, icon }`, a group as `{ name, icon, callouts, when, openInto, enabled }`, a pad or a dial as `{ name, enabled, groups, fields }`, `fields` its portable member rows by path (never its position or key). Ticking a pad or a dial brings its user groups, and a group its callouts; a built-in set travels by id. A reference to something the string does not carry is left out and counted, and so is a field this version does not take. An imported pad or dial is unbound: no key, the default place, the end of its kind's order, every shipped built-in marked seen. `Share.Export` and `Share.Apply` refuse in combat with one line.

## 16. Launcher, debug, diagnostics, perf

**Launcher** (`LibKa0s-Launcher`):
- Left-click opens settings.
- The right-click menu has Enabled, Locked and Test mode.
- The label is `Ka0s Quick Comms`.

**Debug** (`LibKa0s-DebugLog`). The tags are:
- `Situation`, `Resolver`, `Bake`, `Send`, `Guard`, `Echo`, `Queue`, `Pad`, `Dial`, `Bind`, `Share`, `Library`
- `Set` (from the seam)

What is traced:
- state edges
- every deferral and flush
- every refusal, naming its guard
- inferred drops

Repeating paths log only on change.

**Diagnostics sections:**
- the snapshot and its raw inputs
- the restriction state
- the active groups for each surface
- the armed send buttons (count, plus each surface's slot → callout id; the baked text is shown escaped)
- the pending combat-queue keys
- override bindings
- the guard state
- echo tracker counts
- `NS.rejectedEvents`

*Built (phase 4):* the `dials` section (each dial's header, key, rings, open ring, open now, active groups, stale, lockdown chip) and the `bindings` section (every override binding).

**Perf buckets:**
- `situationRefresh`
- `resolverResolve`
- `bakeSurface`
- `padLayout`
- `dialRender` (the OnUpdate while open)
- `sendClick` (the insecure hook)
- `echoMatch`

*Renamed (phase 5, audit QC-12):* the keys are lowerCamelCase (naming-cheatsheet); this list read
`situation.refresh`, `resolver.resolve`, `bake.surface`, `pad.layout`, `dial.render`, `send.click`
and `echo.match` before.

*Built (phase 4):* `dialRender` is bracketed; the dial open/close scenario in `tests/perf.lua` is phase 5.

`tests/perf.lua` covers a 12-chip pad rebuild, a full dial open/close and a zero-overhead scenario.

*Built (phase 5):* all seven buckets are bracketed (`resolverResolve` inside `bakeSurface`). `tests/perf.lua`'s scenarios: `padRebuild12`, `dialOpenClose`, `situationRefresh`, and the zero-overhead pair, the dial pointer's `OnUpdate` with capture off against an instance with no Perf library (`dialPointerCaptureOff`, `dialPointerNoHarness`), beside `bracketCaptureOff`.

## 17. Message bus

Every name is declared once in `core/Bus.lua` as `Ka0s_QuickComms_*`. Each message has one sender, and each receiver registers on its own target.

| Constant | Sender | Payload | Consumers |
|---|---|---|---|
| `SITUATION_CHANGED` | Situation | snapshot, previous | Resolver edge (Surfaces), Preview, settings live lines |
| `RESTRICTION_CHANGED` | Restrictions | reason, canSendChat (consumers read `Restrictions.ActiveSet()`) | Situation (merges into the snapshot), Surfaces (chips, padlocks), SendEngine (drains the combat-end queue), Preview (ends test mode), Pad (ends a drag) |
| `LIBRARY_CHANGED` | Library (its own writes, and `Library.Touch` for every member row the seam writes) | kind, id, field (the member row's path for a field write; none for membership, order or a batch) | Surfaces, settings pages |
| `ACTIVE_GROUPS_CHANGED` | Surfaces (the resolver edge) | surfaceId | none (Surfaces rebuilds pads and dials itself) |
| `SURFACE_REBUILT` | Surfaces | surfaceId, stale | Diagnostics, settings |
| `SEND_RESULT` | SendEngine | calloutId, surfaceId, `"guarded"` at the press when inside the guard window, then `"sent"` or `"dropped"` from the echo: one press can yield two results | Pad, Dial (the flash; built phase 4) |
| `COMBAT_QUEUE_DRAINED` | SendEngine | count | Surfaces (clears the stale hint) |
| `PROFILE_CHANGED` | the entry (`core/QuickComms.lua`, `reloadProfile`) | — | everyone that caches |
| `TEST_MODE_CHANGED` | Preview | on (true while test mode or Preview as… is on) | Surfaces (rebuilds the pads and dials from the test or preview plan, opening dial 1), the editor pages (repaint) |

The count is nine, under the ten-message trigger, so there is no `message-bus.md` until it grows past ten.

## 18. Errors and edge cases

| Case | Behavior |
|---|---|
| A rebuild is needed in combat | Queued under the surface's key. The stale hint shows. It drains on regen. |
| A baked line fails validation | That slot shows as disabled with the reason in its tooltip. The other slots still work. |
| The player leaves the group mid-combat | The baked `/p` goes to nobody, and the game prints its own "not in a party". Slots refresh at regen. |
| Two dials bound to the same key | The editor refuses, naming the other dial |
| A key conflicts with a WoW binding | A warning. The override wins while the addon is enabled. |
| A profile switch in combat | AceDB switches; surfaces mark stale and the rebuild is queued |
| A callout is deleted while it's on a surface | `Library` removes the references, and `LIBRARY_CHANGED` triggers a rebuild |
| A dangling built-in id (a set removed in a later version) | Dropped by the prepare pass |
| A secret value in an input | Becomes nil through the Compat guards; that condition simply doesn't match |
| The LibKa0s library is missing | The load-completing stubs and one refusal line (standard) |
| Import into a profile with id collisions | Ids are always re-mapped; names may duplicate (allowed) |

## 19. Phased build

Each phase ends green: `lua tests/run.lua` and `luacheck .` both pass. Each also has its own exit check.

| Phase | Content | Exit |
|---|---|---|
| **0. Scaffold and spikes** | `/dev-copilot:wow-new-addon` scaffold. `.gitattributes` fix. Vendoring. Logos. TOC. Setup files. Landing page and Master controls. Launcher. Debug console. Diagnostics stub. `test_disabled`. The dev-only spike harness for C1–C9 was built and then deleted when the owner skipped the checks. | Scaffold green. **C1–C9 skipped by the owner (2026-10-13); fallbacks adopted per the round-4 record** in `docs/brainstorm/go-no-go/round-4-build-checks.md`. |
| **1. Core data** | Database and migrations. Schema rows. `Library` (writer). `Situation` (with tests). `Restrictions`. `Resolver`. `Tokens`. `Channels`. `Bake` (sanitizer tests). Built-in data files and the bake audit test. | Headless suites cover truth tables, ordering, bake, sanitize and every built-in. |
| **2. Send engine and Pad: first usable build** | `SendEngine` (pool, arm, queue, guard, echo, stand-down). `Surfaces`. `Pad*`. Test mode. Default pad seeded with built-ins. | In game: the default pad shows M+ callouts in a key and sends on trash and a boss. A double press inside the guard window is marked guarded (dimmed, noted) and the extra send is reported dropped if the echo doesn't arrive. The stale hint appears and clears. |
| **3. Editors** | Callouts, Groups (with When and Preview), Pads pages. Preview as…. Why tooltips. Built-in tab (enable, hide, Customize). | Smoke test: create a callout and a group, set When, see it on the pad in the right situation. Customize a built-in. |
| **4. Comms Dial** | `Dial_Secure` (Relaxed only; C7 skipped), `Dial_Render`, Dial page, Bindings.xml, the battleground node dial with open-into | In game: open the dial, click a wedge and it sends in a boss. The Categories two-stroke works. The Arathi Basin node dial sends "INC 3 Lumber Mill" in two clicks. *Built:* see smoke checks DIAL-1..10. |
| **5. Share, polish, release** | Share (codec tests, import report). Editor polish: the pad's Look font group, border group and colors with class-color companions (options-ui-§16/§17, the composed controls), and a visual icon picker for callouts and groups. Perf buckets and `tests/perf.lua`. Battleground ID confirmation. Node sets pinned to compass directions, with the battleground id confirmation. Docs set. Automated-test bundle. First audit. README. `ADDONS.md` roster row. | Release gate (complexity ≤ 15, blind files 0). Tag v0.1.0 only on the owner's word. *Built:* see smoke checks SHARE-1..6, LOOK-1..2, ICON-1, BG-1..2, IDS-1; the release gate's bundle is Task 13's. |

### In-game checks, carried over from brainstorm §11

These are now the owner's later real-message test list, not a phase gate. C1–C7 as written there, plus:
- **C8:** pad tab switching in combat through a secure `OnMouseWheel` wrap.
- **C9:** does `%f` expand?
- **C2, whisper part: answered 2026-10-13.** `/w %t` does not resolve `%t` in the recipient slot, so whispers are not in v0.1.0 (issue #7).

## 20. Docs to produce

These follow documentation-§1–§3.

**Root:**
- README.md, with the canonical sections
- the CLAUDE.md stub
- DEPENDENCIES.md
- LICENSE

**`docs/`:**
- **The trio:** ARCHITECTURE.md (ten sections, including Taint Notes for §9–§11's secure rules, the registry writer, the named non-setting state, the bus table, and the cap census), testing.md, smoke-tests.md.
- **Tier 1:** scope.md, module-map.md, schema.md, settings-panel.md, data-flow.md, common-tasks.md.
- **Records:** test-cases.md, performance.md, perf-analysis/README.md, automated-tests/README.md and RESULTS.md.
- **Tier 2:** slash-dispatch.md, debug.md, profiles.md, and compat-layer.md if there are three or more shims.

**What happens to the brainstorm:** it stays under `docs/brainstorm/` as history. The spec and plan live under `docs/superpowers/`.

## 21. Decisions this spec proposes

Owner review on 2026-10-11 accepted P1, P4, P8 (renamed to `check`) and P9, and changed P5. P2, P3, P6 and P7 were not raised, and are taken as accepted unless the owner says otherwise.

| # | Proposal | Why |
|---|---|---|
| P1 | Leave the **Combat**, **Lockdown** and **Specific boss** When conditions out of v0.1.0, and file combat-time page swaps as a future issue | They change only during combat, when surfaces can't be rebuilt (§5.3) |
| P2 | Adding a built-in callout to a user group **copies** it into the library | Keeps built-ins read-only and "used in N groups" exact (§5.2) |
| P3 | Smart channels are resolved **when baked**, and refresh after combat | Chat commands take no macro conditionals (§8.2) |
| P4 | In Categories mode, choosing a group keeps the dial open for a **second stroke** (click, or press and release again) instead of a single press with a hover delay | The restricted environment has no timers, and research favors a fresh stroke per level (§11.2) |
| P5 | **Changed by the owner on 2026-10-11, then reversed on 2026-10-13:** whispers are dropped from v0.1.0 ([issue #7](https://github.com/tusharsaxena/QuickComms/issues/7)) | The owner's in-game test showed `%t` does not expand in the `/w` recipient slot (§8.2) |
| P6 | The spam guard is global and set in General ▸ Behavior (0.6–2.0 s, default 1.0) | Adjustable if Blizzard changes the throttle (§9.2) |
| P7 | A `Bindings.xml` with "Open Comms Dial 1–4", alongside each dial's own key setting | Players can use the game's key bindings menu if they prefer (§9.4) |
| P8 | `/qc check <id>` prints the baked line and never sends | No second send path (D12). It isn't named `send` because it doesn't send, or `test` because `/qc test` is the test-mode toggle. |
| P9 | Replace `.gitattributes` with the standard's CRLF body in phase 0 | The standard requires it (line-endings) |

### Owner rulings for phase 4 (2026-10-13)

The phase 4 plan (`docs/superpowers/plans/2026-10-13-quickcomms-phase-4.md`, pre-flight P2) named five places where the build would depart from binding text. The owner ruled on each on 2026-10-13.

| # | Ruling | What it settles |
|---|---|---|
| R1 | `Bindings.xml` ships at the addon root, not as a TOC line. **A change to the standard, not a deviation:** WowAddonStandards v2.80.0 allows it (layout-§1, toc-file-§4 (standard v2.80.0)). | §3, §4.2, §9.4. The deviation register in `docs/ARCHITECTURE.md` stays empty. |
| R2 | With a single active group, Categories opens straight on that group's ring; the hub still goes up to it | §11.3 ("Choosing a group takes a second click"): a one-wedge first ring would cost a click for nothing |
| R3 | The Comms Dial page's Preview tab is a listing, each ring wedge by wedge; the drawn dial is the in-game preview (test mode, Preview as…) | §11.4 ("renders the dial inside the panel") |
| R4 | Battleground node sets are placed clockwise from N in their shipped order; the compass pins move to phase 5 with the battleground id confirmation (§19 row 5) | §11.1, §12.1 ("Nodes are pinned to compass directions") |
| R5 | No depth control on the Wheel tab: depth is §11.3's limit (2 by construction, 3 allowed with the Groups tab's warning); the stored `depth` field stays inert | §13.1 ("**Wheel** (slices, depth, open at, delay)") |
