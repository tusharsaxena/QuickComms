## Scout report: built-in groups and callouts (rename, icons, migration)

### 0. The user's request overrides the computed task on icons
The relayed user request says: *"For the new icons, add them to LibKa0s directly … Vendor the new LibKa0s version to this addon only."* So the new icons should be **LibKa0s-Media glyphs** (Open Iconic). The computed task asked for WoW game icons; those are kept below in §4 only as a fallback. `library-stack-§8` points the same way: "A mark the catalog lacks is added UPSTREAM, in the same style, by the generator that produced the rest — never drawn one-off into an addon."

### 1. How built-ins work
- **Seed API.** `defaults/BuiltIns.lua:12-31`:
  - `BI.Callout(groupId, short, name, text, channel, icon)` stores `{name,text,channel,icon}`.
  - `BI.Callouts(groupId, channel, rows)` takes rows `{short,name,text[,icon]}`.
  - Neither has an **iconColor** parameter.
- **TOC load order.** `defaults\BuiltIns*.lua` load at TOC lines 88-96. That is after `core\MediaSetup.lua` (line 54), so `NS.Icon(name)` can be called at defaults load. It answers nil when the library is absent, and the renderer then falls back to `INV_Misc_QuestionMark`.
- **Seeding copies fields into the profile.** `modules/Library.lua`:
  - `seedCallout` (`:726-731`) copies `name,text,channel,icon,origin=cid`. It does **not** copy iconColor.
  - `seedGroup` (`:736-748`) copies `name, icon, when=copyTable(def.when)`, `origin=gid`, and sets `p.seededSets[gid]=true`.
  - `seedNew` (`:794-809`) seeds only sets missing from `seededSets`.
- **Restore.** `Lib.RestoreBuiltins` (`:836-870`) finds members with `byOrigin` (`:125-131`). It only re-adds sets, nodes or callouts whose origin is missing, and "what the player still has is never changed". So **Restore will not rename or re-icon existing members.**
- **Migrations.** `core/Database.lua:16-24`. `NS.MIGRATIONS` currently has `to=1` (stamp), `to=2` (`MoveGenericBattlegroundLast`) and `to=3` (`SeedFromOverlay`, perProfile). `NS.SCHEMA_VERSION` is the highest `to` (`:27`).
- **Telling "never set" from "cleared".** A seeded callout with no shipped icon has `icon` absent (nil). A player who cleared the icon stores `false` (`settings/SchemaMembers.lua:183`, default false). A migration can use this difference.

### 2. "M+ (generic)" → "Dungeon (generic)"
- **Defined at** `defaults/BuiltIns_MythicPlus.lua:5-23`:
  - `ID="bi.mplus"`, `name=L["M+ (generic)"]`, group icon `Interface\Icons\INV_Relics_Hourglass`, `when={content={mythicPlus=true}}`, channel `smartGroup`.
  - `BI.SNAPSHOTS["bi.mplus"]` is a keystone/mythicPlus snapshot with `lockdown={chat=true,challengeMode=true}`. It is used only by the bake audit.
- **Content keys are valid.** `"dungeon"` and `"mythicPlus"` are both in `modules/Resolver.lua:26`. `Situation.content` (`modules/Situation.lua:24-36`) returns `mythicPlus` when a key is active, else `dungeon` for a party instance. The `content` matcher is `v[s.content]==true` (`Resolver.lua:59`), so the new When must be `{content={dungeon=true, mythicPlus=true}}`.
- **Keep the id and origin `bi.mplus`.** Ids are stable once shipped (`BuiltIns.lua:3-5`). Renaming the id would cause two problems:
  - `seedNew` would seed a duplicate group for every profile.
  - The old origin would stop matching, so Restore would lose track of the group.
  
  So change only `name` and `when`, plus optionally the header comment ("the generic M+ set") and the file name.
- **Existing profiles keep the old name and When.** These were copied at seed time. A **new perProfile step `to=4`** is needed, for example `Lib.UpdateDungeonSet(profile)` in Library (Library is the registry writer). For each `profile.groups` entry with `origin=="bi.mplus"`:
  - **Name:** if `name=="M+ (generic)"` (the literal; `locales/` has only `enUS.lua`), set it to `"Dungeon (generic)"`. A player-renamed group is left alone.
  - **When:** if `when` deep-equals `{content={mythicPlus=true}}`, set `content.dungeon=true`. A player-edited When is left alone.
  - The step must be idempotent and must tolerate a raw SV profile (`savedvariables-§1`; the runner owns the stamp and the step never writes `schemaVersion`).
- **Same step can migrate icons.** A seeded callout whose `origin` maps to a new shipped icon gets it only when its icon is nil, or equals the old shipped path (the two `Spell_Nature_Bloodlust` and `Spell_Nature_Reincarnation`). A `false` icon (cleared by the player) stays cleared. The same rule applies to group icons.
- **Locale.** Add `L["Dungeon (generic)"]` and drop `locales/enUS.lua:106` (`L["M+ (generic)"]`), unless the migration reads it.
- **Tests that pin the old name.** Each needs the new string:
  - `tests/test_members.lua:92` asserts the shipped name.
  - `tests/test_dial.lua:24` (title).
  - `tests/test_pad.lua:457` and `tests/test_surfaces.lua:381` assert `"M+ (generic): Content"`.
  - `tests/test_page_groups.lua:77`.
  - `tests/test_slash.lua:127`.
  - `tests/test_surfaces.lua:50` (section title).
- **Tests that pin the When.** `tests/test_library.lua:62` and `tests/test_groups_when.lua:119` assert `when.content.mythicPlus`; both still pass.
- **Snapshot-dependent tests to check.** Some tests build an M+ snapshot and expect bi.mplus active (`test_surfaces`, `test_pad`, `test_dial`, `test_diagnostics:71,108`). They should still pass. A non-key dungeon snapshot will now also activate the set; grep for tests that assert bi.mplus is inactive in a plain dungeon.
- **Docs.** `docs/smoke-tests.md` lines 145, 186, 213, 216, 219, 273, 365 and 596 name "M+ (generic)". `docs/brainstorm`, `docs/superpowers` and the spec are history; leave them.
- **New migration test.** In `tests/test_database.lua` (existing pattern at `:60-200`, which builds raw `db.sv.profiles` and calls `originOf`), cover:
  - an unrenamed group gets the new name and When;
  - a renamed or edited one is untouched;
  - running the step twice is a no-op;
  - a cleared (`false`) icon is kept.
  
  `tests/test_database.lua:17-19` already checks `SCHEMA_VERSION == last.to`.

### 3. Every prebuilt callout and its icon now
There are 208 callouts in total. Only **3** have an icon:
- `bi.mplus.lust`: `Spell_Nature_Bloodlust`
- `bi.mplus.res`: `Spell_Nature_Reincarnation`
- `bi.raid.lust`: `Spell_Nature_Bloodlust`

Group icons exist only on the four generic sets: mplus `INV_Relics_Hourglass`, raid `Achievement_Boss_Ragnaros`, arena `Achievement_Arena_2v2_7`, bg `Achievement_BG_winWSG`. Per-battleground sets and nodes have none.

Proposed glyph per callout. `*` means the glyph is already in `LibKa0s/Media.lua:92-139` ICONS. **NEW** means it must be added to `tools/artwork/icon_cleaner.py` GLYPHS (semantic name → Open Iconic name). All NEW names are real Open Iconic glyphs: bolt, droplet, medical-cross, loop, beaker, badge, bullhorn, flag, bell, media-play.

| id | label / text | glyph |
|---|---|---|
| mplus.pull | Pulling / Pulling next pack | target* |
| mplus.lust | Lust / Lust on this pack {rt8} | bolt NEW |
| mplus.mana | Need mana / Wait, need mana | droplet NEW |
| mplus.kicks | Kick order / Kick order: {rt1} {rt2} {rt3} | ban* |
| mplus.skip | Skipping / Skipping with invis/shroud | eye* |
| mplus.res | Res me / Res me pls | medical-cross NEW |
| mplus.chain | Chain pull / Key time is tight, chain pull | loop NEW |
| mplus.gg | GG / gg, thanks all | thumb-up* |
| raid.lust | Bloodlust / Bloodlust now | bolt |
| raid.brez | Battle rez / Battle rez used on %t | heart* |
| raid.soak | Soak / Soak {rt3} | target* |
| raid.spread | Spread / Spread for mechanic | fullscreen-enter* |
| raid.stack | Stack / Stack on {rt1} | fullscreen-exit* |
| raid.stones | Healthstones / Healthstones/cauldron down | beaker NEW |
| raid.pull10 (smartLead) | Pull in 10 | timer* |
| raid.wipe (smartLead) | Wipe / Wipe it, run back | reset* |
| arena.trinket | Trinket used | badge NEW |
| arena.cc | CC / CC {rt1} now | lock* |
| arena.swap | Swap / Swap to %t | transfer* |
| arena.incc | I'm in CC | warning* |
| arena.kill | Kill / Going for kill on %t | target* |
| arena.drink | Drink / Drink, reset | droplet |
| bg.help | Need help / Need help here | bullhorn NEW |
| bg.inc | INC / INC {rt8} | warning* |
| bg.hold | Hold / Hold this | pin* |
| bg.capping | Capping | flag NEW |
| bg.defend | Defend | shield* |
| bg.push | Push / Push now | arrow-thick-up* |
| node inc1 (×23 nodes) | INC 1 / INC 1 <node> | person* |
| node inc2 / inc3 | INC 2/3 <node> | people* |
| node many | INC many <node> | warning* |
| node clear | <node> is clear | circle-check* |
| node help | Need help at <node> | bullhorn |
| wsg/tp efcmid, efctun, efcroof | EFC mid / in the tunnel / on the roof | flag |
| tp efcwater | EFC in the water | droplet |
| wsg/tp fcheals | Our FC needs heals | medical-cross |
| wsg/tp killefc | Kill the EFC %t | target* |
| wsg/tp fcsafe | FC is safe | circle-check* |
| ssm escort / contest / help | cart | shield* / warning* / bullhorn |
| tok heals / kill / mid | orb | medical-cross / target* / map-marker* |
| ss here / next / help | azerite | map-marker* / arrow-thick-right* / bullhorn |
| dhr crystal / cart / defend | | bullhorn / media-play NEW / shield* |
| av general / push / gy / tower | | shield* / arrow-thick-up* / flag / warning* |
| ashran road / event / regroup | | arrow-thick-right* / bell NEW / home* |
| wg walls / siege / workshop | | shield* / settings* (cog) / wrench* |

The 23 nodes are: ab stables, lumbermill, blacksmith, mine, farm; eots felreaver, bloodelf, draenei, magetower, flag; bfg lighthouse, waterworks, mines; dwg market, farm, quarry, shrine, ruins; ioc docks, hangar, workshop, quarry, refinery.

Two caveats:
- A glyph draws white unless `iconColor` is set. To ship colors (red kill, green clear), extend `BI.Callout`, `BI.Callouts` rows and `seedCallout` with `iconColor` (`"rrggbb"`, validated by `Lib.ValidIconColor`, `Library.lua:296`; `Lib.IconTint`, `:306`).
- Built-ins should store `NS.Icon("bolt")`, which yields `Interface\AddOns\QuickComms\libs\LibKa0s\media\icons\bolt`, extensionless.

### 4. Icon field format and the browser tabs
- **Icon value.** nil or false (none), a number (texture fileID), or a texture path string (`Lib.ValidIcon`, `Library.lua:258`). A glyph is a path that `Lib.IsGlyph` maps back to its catalog name (`:271`). Only glyphs take `iconColor` (`settings/SchemaMembers.lua:94-100`, refusal `notGlyph`).
- **There is no "Suggested" tab.** `settings/IconBrowser_Sources.lua` has three tabs:
  - `markers`: the 8 `UI-RaidTargetingIcon_N` (`:44-57`).
  - `game`: `Compat.MacroIcons` fileIDs (`:93-125`).
  - `glyphs`: every `NS.IconNames()` entry (`:59-66`).
- **Labels.** `Src.GLYPH_LABELS` (`:36-40`) holds curated localized labels. Each new glyph used by built-ins should get a label and a matching `L[...]` key (Bolt, Droplet, Medical cross, Loop, Beaker, Badge, Bullhorn, Flag, Bell, Play).
- **Browser tests.** `tests/test_icon_browser.lua:211-214` asserts `#Src.Glyphs()==#NS.IconNames()`. It will pick up new glyphs automatically.

**Fallback game icons** (shipped as `Interface\Icons\<name>`; `?` means unsure the texture exists):

| Group | Callout → icon |
|---|---|
| mplus | pull Ability_Warrior_Charge, lust Spell_Nature_Bloodlust, mana INV_Drink_18?, kicks Ability_Kick, skip Ability_Stealth, res Spell_Nature_Reincarnation, chain Spell_Frost_ChainsOfIce, gg Achievement_General? |
| raid | brez Spell_Holy_Resurrection, soak Spell_Holy_PowerWordShield, spread Ability_Rogue_Sprint, stack Spell_Holy_PrayerOfHealing02?, stones INV_Stone_04, pull10 INV_Misc_PocketWatch_01, wipe INV_Misc_Bone_HumanSkull_01 |
| arena | trinket INV_Jewelry_TrinketPVP_01, cc Spell_Nature_Polymorph, swap Ability_Hunter_MarkedForDeath?, incc Ability_Rogue_KidneyShot, kill Ability_Rogue_Eviscerate, drink INV_Drink_07 |
| battleground | help Ability_Warrior_BattleShout, capping and flags INV_BannerPVP_01 / INV_BannerPVP_02, defend INV_Shield_06, heals Spell_Holy_FlashHeal, orb INV_Misc_Orb_01? |

### 5. LibKa0s side (adding glyphs upstream)
- **Generator.** `tools/artwork/icon_cleaner.py` (`GLYPHS` at `:90`). Run `--fetch` (needs `gh`) and `--build` (Pillow and numpy). Output goes to `LibKa0s/media/icons/<name>.tga`; 114 files exist now.
- **Catalog.** `LibKa0s/Media.lua:92-139` `lib.ICONS`. Media is `MAJOR "LibKa0s-Media-1.0", MINOR 4` (`:56`). A catalog change means minor 5, a new `docs/api/Media/version-5-docs.md` and `members-5.json`, a row in `tests/majors.lua`, and a CHANGELOG entry.
- **Library tests.** `tests/test_media.lua:34-50` checks both directions (every ICONS name has a file and every file has a name); `:120` checks for duplicates.
- **Vendoring into QC.**
  - `libs/LibKa0s/` and `tests/_kit/` are copied whole (never edited in place).
  - The CLAUDE.md provenance line `v1.73.0` must roll in the same commit.
  - `tests/test_vendor_sync.lua` enforces byte-identity with the named tag (`testing-§11`), so the new LibKa0s version must be **tagged** first.
  - The user asked for QC only, so the other addons are left alone.

### 6. `tests/test_builtins.lua`
- `:8-17` pins the order: `order[1]=="bi.mplus"`, raid, arena, `bi.bg.ab` fourth, `bi.bg` last, and ≥18 sets. The id stays, so this passes.
- `:19-35` checks that ids are unique and referenced and that callouts are not orphaned.
- `:53-69` is the bake audit under `SNAPSHOTS` (length ≤255, no unknown tokens, no lock).
- `:71-78` pins channels. `:80-95` pins node winds.
- **Nothing pins icons or names.** Worth adding:
  - every callout has an icon;
  - every glyph-named icon resolves (`NS.Icon(name) ~= nil`), so the vendored catalog really carries it;
  - `bi.mplus` name is "Dungeon (generic)" and its When content is dungeon + mythicPlus;
  - `test_library.lua:56-70` already checks seeded `g.icon == def.icon`; an equivalent check for callout icon and iconColor would help.

### 7. Standard constraints
- **`savedvariables-§1`:** a perProfile, idempotent step; the runner advances the stamp; the defaults `schemaVersion` stays 0.
- **`library-stack-§8`:** the catalog is the vocabulary. Missing marks are added upstream through the generator, never as a private QC icon. Enumerate `ICONS` rather than hard-coding a list (Src already does this; the built-in data naming specific glyphs by name through `NS.Icon` is fine).
- **`library-stack-§7`:** the vendored payload is copied whole and never edited.
- **Repo `CLAUDE.md`:** green gate is `lua tests/run.lua` plus `luacheck .`; no version bump without an instruction.
- **Possible deviation to flag.** The bake audit snapshot stays M+ only, so plain-dungeon baking of these callouts goes untested. That is not a standard violation, but adding a dungeon snapshot is worth considering.