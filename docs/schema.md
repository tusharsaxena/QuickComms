# Schema — Ka0s Quick Comms

The SavedVariables shape, every default, and the migration path. Defaults live in
`defaults/Profile.lua` (`NS.C`); `settings/Schema.lua`'s `Settings.BuildDefaults` merges them with
every stored schema row's own default and hands the tree to AceDB.

## SavedVariables

Exactly two (savedvariables-§4):

- `QuickCommsDB` — AceDB, with profiles.
- `QuickCommsPerfDB` — LibKa0s-Perf's capture ring, outside the profile tree (performance-§5).

## `QuickCommsDB.profile`

| Key | Default | Set by | What it is |
|---|---|---|---|
| `enabled` | `true` | the Enable row, `/qc enable|disable`, the launcher | the master switch; `false` takes the latch's `disabled` hold |
| `visibility` | `"always"` | the General visibility row | the master visibility, applied on top of each pad's own |
| `scale` | `1.0` | the Master scale row | multiplied into every pad's own scale |
| `alpha` | `1.0` | the Master alpha row | the ceiling of every pad's fade |
| `locked` | `true` | the Lock frame row, `/qc lock|unlock`, the launcher's Locked entry | pads start locked; unlocked, each shows its drag strip |
| `behavior.soloFallback` | `"none"` | the Behavior rows, `/qc set` | what a smart channel does when solo: `none`, `self` or `say` |
| `behavior.spamGuard` | `1.0` | Behavior | seconds between sends, 0.6-2.0 (phase 2's send engine; no hard guard in combat, spec §9.2) |
| `behavior.dropNotes`, `whyTooltips`, `lockdownChip` | `true` | Behavior | the `[QC]` drop note, the why tooltips, the lockdown chip |
| `behavior.sounds`, `autoPromote` | `false` | Behavior | sounds; a narrower When floats up within a surface's order |
| `behavior.previewOnEdit` | `true` | the Groups page band's Preview while editing box (`skipRender`, page `groups`), `/qc set` | while the Groups page is on screen, every pad and dial shows only the group it edits (session state `State.editPreview`) |
| `nextId` | `1` | `Library.NewId` | the id counter for every user id (`c<n>`, `g<n>`, `p<n>`, `d<n>`); past the seeded sets' ids after the first load |
| `callouts` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | user callouts keyed by id: name, text, channel, icon, and `iconColor` (a LibKa0s glyph's color, `"rrggbb"` lowercase; absent or `false` for none); each id sits in exactly one user group's `callouts` list. A seeded callout also keeps `origin`, the shipped callout id it was copied from (`"bi.mplus.lust"`), which only Library reads |
| `groups` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | user groups keyed by id: name, icon, `iconColor` (as a callout's), callouts (the group owns them: no other group holds the same id), when, openInto, enabled, `parent` (the top-level group it sits inside; absent or `false` for none, one level only), and `inheritWhen` (`true`: while it has a parent, the group is judged by the parent's When instead of its own; `false`: its own; absent reads as `true`). A seeded group also keeps `origin` (the shipped set or node id, `"bi.mplus"`, `"bi.bg.ab.mine"`), and a seeded battleground node its `compass` wind; neither is a member row, and a copy keeps neither |
| `seededSets` | `{}` | `Library` only (seeding, Restore, migration step 3) | the shipped set and node ids this profile was given as groups, `{ [id] = true }`: Prepare seeds a set not listed here (one a later version ships), and never seeds again a set the player deleted |
| `pads` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | surfaces keyed by id: groups (ordered, top-level groups only: a child shows with its parent), and the surface's own settings; a pad's `look` holds visibility, fade, faded alpha and the Look groups' fields (font, size, color and its companion, flags, shadow; border style, thickness, color and its companion; background and its companion), and its `icon` holds the Icons tab's fields (below) |
| `dials` | `{}` | `Library` (membership and order); member fields through the seam (`dial.name\|enabled\|mode\|slices\|openAt\|point\|key`) | surfaces keyed by id: groups (ordered, top-level groups only), and the dial's own settings (its `icon`: the Icons tab's fields, below); a new dial stores `interaction = "relaxed"`, and `delay`, `tapAction` and `depth` are kept but nothing reads them |
| `pads[id].point` | absent (the pad sits 150 px below the center) | the `pad.point` member row: the drag strip, the X/Y boxes, Reset position | the saved anchor, the positional array `{ point, relativePoint, x, y }` |
| `dials[id].point` | absent (the dial opens at the center) | the `dial.point` member row: the X/Y boxes, Reset position | the saved anchor, the positional array `{ point, relativePoint, x, y }` |
| `dials[id].key` | absent (`false`: no key) | the `dial.key` member row: the Comms Dial page's key capture, `/qc set dial.key` | the dial's key, upper-case (`SHIFT-G`); bound as an override binding, never in WoW's own bindings |
| `padOrder`, `dialOrder` | `{}` | `Library` only | display order of the surfaces |
| `pads[id].icon`, `dials[id].icon` | `defaults/Icons.lua` (`IconDefaults.For`) | the Icons tab's member rows `pad.icon.*` / `dial.icon.*` | how the chips' or wedges' icons are drawn (B9): `size` (pad 12-40, default 20, feeding the chip's height; dial 16-40, default 32, inside the fixed 44-pixel wedge), `zoom` 0-0.25 (0), `desaturate` (`false`), `alpha` 0.1-1 (1), `tint` and `useClassColorTint` (white: a glyph keeps its own color), `borderShow` (`false`), `borderStyle` (`"Solid"`), `borderSize` 1-16 (1), `borderColor` (black) and `useClassColorBorder`, `glowEnabled` (`false`), `glowWhen` (`always`, `hover` or `send`), `glowType` (`pixel`, `autocast`, `button` or `proc`), `glowColor` (gold) and `useClassColorGlow`, and DropWatcher's knobs (`pixelLines` 8, `pixelFrequency` 0.1, `pixelLength` 0 = automatic, `pixelThickness` 1, `pixelBorder` `true`, `autocastParticles` 4, `autocastFrequency` 0.125, `autocastScale` 1, `buttonFrequency` 0.25, `procDuration` 1, `procStartAnim` `true`, `xOffset` and `yOffset` 0). Flat leaves of one table, so `Library.Prepare`'s fillShape gives a surface saved before them every field; they travel in a share string |
| `seeded` | `false` | `Library.Prepare` | true once the default pad and dial exist (and the shipped sets are seeded into them) |

**Member rows** address a member's fields through the seam (`settings/SchemaMembers.lua`): `callout.name|text|channel|icon|iconColor`, `group.name|icon|iconColor|enabled|openInto|parent|inheritWhen|when`, `pad.name|enabled|groupsAs`, `pad.layout.orientation|columns|growth|style|scale|spacing|width`, `pad.point`, `pad.look.visibility|fade|fadeAlpha`, the twelve Look rows `pad.look.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow|borderStyle|borderSize|borderColor|useClassColorBorder|background|useClassColorBackground` (composed by the options library; the colors are the `color` row type), `dial.name|enabled|mode|slices|openAt|point|key`, and the Icons tab's `pad.icon.*` and `dial.icon.*` (the fields above; the Tint, Border and Glow color pairs and the Border block composed by the options library). They are not AceDB defaults; `Library.TEMPLATES` is their shape. A `callout.*` row is addressed by the callout's id alone (no page selects a callout): its `page = "callouts"` is the `/qc list` heading, not a registered panel page. An icon is a texture path (a LibKa0s glyph or a raid marker) or a texture id (a number: a game icon from the macro icon lists); `false` is none. `callout.iconColor` and `group.iconColor` default to `false` (none: the glyph is drawn white) and take six hex digits (typed text may carry `#`, spaces or capitals; it is stored lowercase), only on a member whose icon is a LibKa0s glyph; an icon write that leaves a colored member without a glyph clears its color in the same act. Both are reset-exempt with the icon rows (`settings/Schema.lua`): a named `/qc reset` clears the color, a page's Defaults keeps it. `group.parent` takes a group id, or `false` (`none` or empty text on the CLI) for none; `Library.ValidParent` refuses itself, a group that is not a top-level user group, and any parent for a group that holds groups. Its write takes the group off every pad and dial in the same act (`Library.SettleParent`). It is reset-exempt too. `group.when`'s place rows (`Resolver.ID_ROWS`: `instances`, `battleground`, `arena`) take map ids and, beside them, `all` (`Resolver.ALL`): the whole kind (any dungeon, Mythic+ key or raid; any battleground; any arena), matched whatever ids are listed; the `arena` row matches only while the content is `arena`; `Library.ValidWhenValue` refuses it on every other row. `group.inheritWhen` (bool, default `true`) is Inherit when conditions: a group inside another uses its parent's When instead of its own (`Resolver.WhenOf`), and its own stored When is kept, unread. A new group stores `true` (`CreateGroup`, so a Duplicate or an import passes its value on, and the seeding); a group stored before the setting has no field, which reads as on, and `/qc get group.inheritWhen` prints nil for it until it is written. It is not reset-exempt: a page's Defaults ticks it again.

`modules/Library.lua` is the one writer of every structural key above (architecture-§5). The
shipped sets in `NS.BuiltIns` are seed data: a profile is given them once as ordinary groups and
callouts (fresh ids from `nextId`; each group's callouts take their ids before it, a set's nodes
after it, so the nodes keep their shipped order), placed on the default pad and dial, a battleground's
nodes inside its set. `Library.Prepare` is the load
pass, run after `RunMigrations` on `OnInitialize` and on every profile event: it makes the default
pad and dial and seeds the sets once, seeds a set a later version ships (one `seededSets` does not
list) at the end of every pad and dial, normalizes malformed shapes, drops a malformed stored
`iconColor` from any user callout or group, drops a parent that is gone, the group itself or a group
inside another (judged on the parents as stored) and takes any child off every surface, repairs
`padOrder` / `dialOrder`, and keeps
the ownership rule: a callout a second group holds is replaced there by a fresh copy with equal
fields, and a callout no group holds is deleted, each counted as a repair. A second run changes
nothing.

## `QuickCommsDB.global`

| Key | Default | What it is |
|---|---|---|
| `schemaVersion` | `0` | the migration stamp; the runner owns it |
| `minimap.hide` | `false` | LibDBIcon's own key; the Minimap button row inverts onto it, and no `shown` twin exists (launcher-§3) |
| `minimap.minimapPos` | absent | LibDBIcon's own write |

## Session-only (never saved)

`NS.State.debug` (the logging flag). The Debug console row is `sessionOnly` and stores through its
own closure. The phase 2 modules add, all reset by `/reload`: `testMode` (test mode, the Test mode
row's store), `padTab` and `padCollapsed` (per pad: the active tab, the collapsed state),
`surfacePlans`, `surfaceOrder` and `surfaceStale` (the plans, the floated order, the stale hints),
`sendQueue` (the combat-end queue), `sendEcho` (the presses awaiting an echo), `lastSendAt` (the
guard's last press) and `pendingTeardown` (a stand-down held for combat's end), plus the timer
handles (`echoTimers`, `padCoolTimer`, `padFlashTimers`). Phase 3 adds `previewAs` (the "Preview as…"
situation), `editing` (each editor page's selected member; never a callout) and `whenOpen` (the When editor's open drawers, per group and condition).
The icon browser's search text is module-local in `settings/IconBrowser.lua` and also lasts the session.
Phase 5 adds `share` (the Share page's ticks, `pick`, per group, pad and dial, and the last checked string's result, `import`; a profile switch clears both).

## Migrations

`core/Database.lua`: `NS.MIGRATIONS` is a list of steps `{ to = n, run = fn }`, plus
`perProfile = true` for a step that must run once for every stored profile (`db.sv.profiles`), and
`NS.SCHEMA_VERSION` is the last step's `to`. Step 1 is the stamp itself (0 → 1, nothing to reshape); the phase 1 keys needed no step, because
`Library.Prepare` makes a profile that predates them whole.
Step 2 (phase 4, `perProfile`): the generic battleground set below the per-battleground sets on every
pad and dial (`Library.MoveGenericBattlegroundLast`), so a battleground's node set can be the first
active group and the dial opens into it.
Step 3 (2026-10-18, `perProfile`, `Library.SeedFromOverlay`): the built-in overlay becomes seeded
groups. On a stored profile that has its surfaces (`seeded`) and no `seededSets` yet, every set is
seeded as an ordinary group and takes the set's place on every pad and dial that listed it; a set
that was off is a group that is off; its hidden callouts are left out (Restore built-in groups brings
them back); a customized set is not seeded (its copy, a user group already, keeps its place) and
counts as given; a node or stale `bi.` reference on a surface is dropped; a seeded set a surface's
`seenBuiltins` lacks (shipped after the surface last loaded) goes at that surface's end, as `Prepare`
put such a set before; `profile.builtins` and every surface's `seenBuiltins` go. A profile never prepared is left to `Library.Prepare`, which seeds it as a
new one, and one that already has `seededSets` is left alone, so the step runs once.
Step 4 (2026-10-19, `perProfile`, `Library.MigrateGrowth` in `modules/Library_Migrate.lua`): the
retired `up` (Upward) growth on any pad becomes `rightUp` (Right and up); every other value, and a
pad with no layout, is left as it is. A share string made before carries `up` too; Share's import
reads it as `rightUp`.
Step 5 (2026-10-19, `perProfile`, `Library.MigrateBuiltins` in `modules/Library_Migrate.lua`): every
group whose origin is `bi.mplus` and whose name is still "M+ (generic)" becomes "Dungeon (generic)"
(a renamed one keeps its name), and one whose When is still content M+ alone also takes Dungeon (an
edited When is left alone); every seeded callout whose icon is unset (nil) or the game icon it
shipped with takes its catalog glyph and color, while a cleared icon (`false`) or any other icon
stays. A second run changes nothing.
Step 6 (2026-10-19 groups polish, `perProfile`, `Library.MigrateBuiltinsPolish` in
`modules/Library_Migrate.lua`): every seeded group whose icon is unset (nil) or the game icon its set
shipped with, and that has no color, takes its catalog glyph and color; every seeded callout still on
its shipped glyph with no color takes the glyph's color (a picked color, or a picked or cleared icon,
stays); and each copy of the five node sets (Arathi Basin, Eye of the Storm, Battle for Gilneas,
Deepwind Gorge, Isle of Conquest) gains, at its end and under fresh ids, each of its map-wide callouts
none of its callouts keeps the origin of. A deleted set has no copy and is not brought back. The new
World (solo) set needs no step: `Library.Prepare` seeds it as any newly shipped set (`seededSets`).
Seeding now copies a shipped group's `iconColor` too. A second run changes nothing.
`NS.SCHEMA_VERSION` is 6.
No schema step for nested groups (2026-10-18): a group without `parent` is top-level, and
`Library.Prepare` drops a bad one.
No schema step in phase 5: `Library.Prepare` fills a stored pad's missing layout and look fields from
the defaults (`fillShape`), so a pad saved before the Look groups reads like a new one.
No schema step for callouts owned by groups (2026-10-17) either: `Library.Prepare` enforces the
ownership rule on every load, which also covers a profile a hand edit breaks later.
No schema step for the glyph color (2026-10-18): `iconColor` is a new optional field, absent on
every member stored before it (none, drawn white), and `Library.Prepare` drops a malformed one.
No schema step for Inherit when conditions (2026-10-18): `inheritWhen` is a new optional field read
as on while absent, so every group inside another stored before it, the seeded battleground nodes
among them, takes its parent's When at the first load.
The runner runs in `OnInitialize` before anything reads the profile, and again on every profile
event; it advances the stamp only after a step returns. A stored-value type change adds a step and
raises the target; the default stays `0`.
