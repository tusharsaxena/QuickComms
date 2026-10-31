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
| `alpha` | `1.0` | the Master opacity row | the ceiling of every pad's fade |
| `locked` | `false` | the Lock frame row, `/qc lock|unlock`, the launcher's Locked entry | a new profile starts unlocked (owner, 2026-10-22; locked before); unlocked, each pad shows its drag strip |
| `behavior.soloFallback` | `"none"` | the Behavior rows, `/qc set` | what a smart channel does when solo: `none`, `self` or `say` |
| `behavior.spamGuard` | `1.0` | Behavior | seconds between sends, 0.6-2.0 (phase 2's send engine; no hard guard in combat, spec §9.2) |
| `behavior.dropNotes`, `whyTooltips`, `lockdownChip` | `true` | Behavior | the `[QC]` drop note, the why tooltips, the lockdown chip |
| `behavior.sounds`, `autoPromote` | `false` | Behavior | sounds; a narrower When floats up within a surface's order |
| `behavior.previewOnEdit` | `true` | the Groups page band's Preview while editing box (`skipRender`, page `groups`), `/qc set` | while the Groups page is on screen, every pad and dial shows only the group it edits (session state `State.editPreview`) |
| `skin.source`, `skin.skin` | `"ka0s"`, `"ka0s"` | the Skin tab (General, the library's `O.AppearanceTab`), the first-run picker's Apply and gear, another Ka0s addon's Copy to every Ka0s addon, `/qc set` (skinning-§2) | the skin this addon wears: the source (`ka0s` or `eui`, EllesmereUI) and the Ka0s skin (`NS.SKIN_OPTIONS`: `ka0s` Ka0s Default, `obsidian`, `azeroth`, `glass`, `contrast`, `ember`, `wow`, `midnight`, `forever`). Written only through `NS.WriteSkinChoice` (`core/SkinSetup.lua`), which writes through the seam; each row's `onChange` applies only its own half |
| `skin.ignorePanel`, `skin.ignoreFonts` | `true`, `false` | the Skin tab's Scope, `/qc set` | the two exceptions: keep this addon's settings pages stock (on for every profile, the owner's 2026-10-27 call, as LootHistory), keep every font the game's |
| `skin.font`, `skin.texture` | `""`, `""` | the Skin tab's Font and texture, `/qc set` | the overrides, a LibSharedMedia key each, `""` for the skin's own; free text, so a media pack registering late is still accepted |
| `skin.outline` | `"hud"` | the Skin tab's Font outline (LibKa0s v1.82.0, Skin minor 9, D-06), `/qc set` | where the skin outlines this addon's text: `all` text, `hud` text only (the default, D-10 of LibKa0s v1.83.0's run; a stored value is never migrated), or `off` (`Skin:SetOutline`); a font block whose flags are *From skin* follows it; Ignore fonts wins. Written through `NS.WriteSkinChoice`'s `media.outline` |
| `skin.pickerSeen` | `false` | the first-run skin picker's `onClose` (`core/SkinSetup.lua`), `/qc set` | whether the player closed the first-run picker on this profile (owner ruling O3: `false` for every profile, old or new). Drawn by nothing; a reset puts it back |
| `nextId` | `1` | `Library.NewId` | the id counter for every user id (`c<n>`, `g<n>`, `p<n>`, `d<n>`); past the seeded sets' ids after the first load |
| `callouts` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | user callouts keyed by id: name, text, channel (a `Channels.KINDS` kind: `smartGroup`, `smartLead`, `party`, `raid`, `instance`, `raidWarning`, `say`, `yell` or `general`, chat channel 1 with Say where it is not joined, QF-04), icon, and `iconColor` (a LibKa0s glyph's color, `"rrggbb"` lowercase; absent or `false` for none); each id sits in exactly one user group's `callouts` list. A seeded callout also keeps `origin`, the shipped callout id it was copied from (`"bi.mplus.lust"`), which only Library reads |
| `groups` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | user groups keyed by id: name, icon, `iconColor` (as a callout's), callouts (the group owns them: no other group holds the same id), when, enabled, `parent` (the top-level group it sits inside; absent or `false` for none, one level only), and `inheritWhen` (`true`: while it has a parent, the group is judged by the parent's When instead of its own; `false`: its own; absent reads as `true`). A seeded group also keeps `origin` (the shipped set or node id, `"bi.mplus"`, `"bi.bg.ab.mine"`); it is not a member row (a seeded node's `compass` wind, which pinned its dial slice, retired 2026-10-25: a profile seeded before keeps it, unread), and a copy does not keep it |
| `seededSets` | `{}` | `Library` only (seeding, Restore, migration step 3) | the shipped set and node ids this profile was given as groups, `{ [id] = true }`: Prepare seeds a set not listed here (one a later version ships), and never seeds again a set the player deleted |
| `pads` | `{}` | `Library` (membership and order); member fields through the seam (member rows) | surfaces keyed by id: groups (ordered, top-level groups only: a child shows with its parent), and the surface's own settings; a pad's `layout` holds orientation, columns, growth, style, scale and spacing (no `width` since 2026-10-20: it is the Buttons tab's); its `look` holds the Window tab's fields (the Look tab, then the one Window tab, then Main window, until 2026-10-20; the key kept): border style, thickness, color and its companion, `borderStyleFromSkin` (`true`: the style is the skin's `bar.borderStyle` while on, QC-03), background and its companion (no font since 2026-10-20: the section titles' moved to `section`), and the General tab's visibility, fade and faded alpha (Main window's until 2026-10-20); its `header`, `section` and `button` hold the Header, Section titles and Buttons tabs (below), and its `icon` the Icons tab's fields (below) |
| `dials` | `{}` | `Library` (membership and order); member fields through the seam (`dial.name\|enabled\|mode\|slices\|radius\|iconOffset\|openAt\|point`, `dial.label.*`, `dial.slice.*`, `dial.hub.*`, `dial.title.*`, `dial.page.*`) | surfaces keyed by id: groups (ordered, top-level groups only), and the dial's own settings (`slices`: 0 Auto, a new dial's default since the dial rework of 2026-10-21, or 4, 6, 8, 12, a stored value kept as it was; `radius` 70-180, default 120 (100 before 2026-10-22; a stored radius is kept), absent read as 120; `iconOffset` 0-250, 0 (automatic: the icon's place in its slice kept at any ring radius, the ring radius at 100), absent read as 0, an Icons tab row since the dial polish; its `label`: the Labels tab's Slice labels and Tooltip headings' fields, below; its `slice`: the Slices tab's, and the Layout tab's Slice gap, below; its `hub`: the Hub tab's Hub heading, below; its `title`: the Labels tab's Group labels heading's, below; its `page`: the Paging tab's, below; its `icon`: the Icons tab's fields, below); a new dial stores `interaction = "relaxed"`, and `delay`, `tapAction` and `depth` are kept but nothing reads them. A dial has no `key` (2026-10-20): its key is WoW's own binding of its place's Open Comms Dial entry (below) |
| `pads[id].point` | absent (the pad sits 150 px below the center) | the `pad.point` member row: the drag strip, the X/Y boxes, Reset position | the saved anchor, the positional array `{ point, relativePoint, x, y }` |
| `dials[id].point` | absent (the dial opens at the center) | the `dial.point` member row: the X/Y boxes, Reset position | the saved anchor, the positional array `{ point, relativePoint, x, y }` |
| `pads[id].header` | `defaults/PadStyle.lua` (`PadDefaults.Header`) | the Header tab (Pad header until item 020), member rows `pad.header.*` | the pad's top row (2026-10-20): `height` 14-40 (24, the owner's default; it was a fixed 18), `font` (`"Friz Quadrata TT"`), `fontSize` 6-32 (16), `fontColor` (gold, `{ 1, 0.82, 0, 1 }`) and `useClassColorFont` (`false`), `fontFlags` (`"@skin"`, From skin: the Skin tab's Font outline decides, LibKa0s v1.82.0; `"OUTLINE"` until then, which schema step 11 moved), `fontShadow` (`true`), `background` (`{ 0, 0, 0, 0 }`: none) and `useClassColorBackground` (`false`), `borderStyle` (`"None"`), `borderSize` 0-16 (0: no edge), `borderColor` (white, `{ 1, 1, 1, 1 }`) and `useClassColorBorder` (`false`), and the companions `fontFromSkin` and `borderStyleFromSkin` (`true`: the face is the skin's `hud.font` and the style its `bar.borderStyle` while on, QC-03). Flat leaves, filled by fillShape |
| `pads[id].section` | `defaults/PadStyle.lua` (`PadDefaults.Section`) | the Section titles tab (Section header until item 020), member rows `pad.section.*` | each section title's row (2026-10-20): `height` 0-40 (0: automatic, grown with its font as `PadLayout.TitleHeight` always did; above 0, that tall), `font` (`"Friz Quadrata TT"`), `fontSize` 6-32 (12), `fontColor` (the titles' gold, `{ 1, 0.82, 0, 1 }`) and `useClassColorFont` (`false`), `fontFlags` (`"@skin"`, From skin: the Skin tab's Font outline decides, LibKa0s v1.82.0; `"OUTLINE"` until then, which schema step 11 moved), `fontShadow` (`true`), and the band drawn behind each title across its row: `background` (`{ 0, 0, 0, 0 }`: none) and `useClassColorBackground` (`false`), `borderStyle` (`"None"`), `borderSize` 0-16 (0: no edge), `borderColor` (white) and `useClassColorBorder` (`false`), and the companions `fontFromSkin` and `borderStyleFromSkin` (`true`, QC-03, as the header's). The font leaves were `pad.look.font*` until 2026-10-20. Flat leaves, filled by fillShape |
| `pads[id].button` | `defaults/PadStyle.lua` (`PadDefaults.Button`) | the Buttons tab (the Chip tab, `pad.chip`, until 2026-10-20), member rows `pad.button.*` | the buttons (2026-10-20): `width` 1-300 (100; `pad.layout.width` until then), `height` 0-80 (0: automatic), `background` (#3F3F3F at 25%, `{ 0x3F/255, 0x3F/255, 0x3F/255, 0.25 }`) and `useClassColorBackground` (`false`), `borderStyle` (`"None"`), `borderSize` 0-16 (1: a flat 1-pixel edge, as `"None"` is no border art; 0 is no edge), `borderColor` (#3F3F3F at 10%, `{ 0x3F/255, 0x3F/255, 0x3F/255, 0.10 }`; #EAEAEA until 2026-10-22) and `useClassColorBorder` (`false`), `font` (`"Friz Quadrata TT"`), `fontSize` 6-32 (10), `fontColor` (white) and `useClassColorFont` (`false`), `fontFlags` (`"@skin"`, From skin, as the header's; `"OUTLINE"` (owner, 2026-10-22) until LibKa0s v1.82.0), `fontShadow` (`true`), the companions `fontFromSkin` and `borderStyleFromSkin` (`true`, QC-03, as the header's), `glowEnabled` (`false`), `glowType` (`pixel`, `autocast`, `button` or `proc`; `pixel`), `glowColor` (gold) and `useClassColorGlow` (`false`); the Shine heading's (shine overlay, 2026-10-21) `shineLook` (a pad button's `"glossfade"` at 80 with a #1B1B1B tint, a dial slice's `"orb"` at 85 with a #808080 tint, owner 2026-10-22; `"none"` before; `none`, `gloss`, `glossfade`, `orb`, `frost`, `fluid`, `bevel` or `rim`), `shineStrength` 0-100 in steps of 5, `shineTint` with `useClassColorShineTint` (`false`), `shineBloomA` (#ff9ad5, `{ 1, 0.604, 0.835, 1 }`) and `shineBloomB` (#8affc1, `{ 0.541, 1, 0.757, 1 }`), each with its `useClassColorShineBloomA|B` (`false`; Fluid glass only). Flat leaves, filled by fillShape (no migration: a pad saved before the shine draws None) |
| a dial's key | none (WoW's own key bindings, not the profile) | Options → Keybindings → Ka0s Quick Comms → Open Comms Dial <n>, or General → Keybindings in this addon's settings (item 015, 2026-10-24, the library's tab; the Dial page's Binding tab retired in the dial rework, 2026-10-21) | WoW's binding of `CLICK QuickCommsDial<n>:Toggle`, n the dial's place in the dial order (1-4); account-wide unless the player ticks Character Specific Keybindings, saved with `SaveBindings(GetCurrentBindingSet())`. Not in SavedVariables: a profile switch, copy or reset never moves it |
| `padOrder`, `dialOrder` | `{}` | `Library` only | display order of the surfaces |
| `previewWindow` | `{ point = "TOP", relPoint = "TOP", x = 0, y = -140 }` | `modules/PreviewWindow.lua` only: `remember`, the window's drag stop | the Preview as selector window's place (standalone-windows' persist MUST), read on every show and on a profile switch; no migration step: a profile saved before it reads the default |
| `dials[id].label` | `defaults/PadStyle.lua` (`PadDefaults.DialLabel`) | the Labels tab's Slice labels and Tooltip headings (its own Slice labels tab from the dial polish, 2026-10-21, until item 020), member rows `dial.label.*` | the wedges' labels (dial rework, 2026-10-21), drawn wholly outside the disc: `show` (`true`), `font` (`"Friz Quadrata TT"`), `fontSize` 6-32 (12), `fontColor` (white), `useClassColorFont` (`false`), `fontFlags` (`"@skin"`, From skin, as the header's; `"OUTLINE"` (owner, 2026-10-22) until LibKa0s v1.82.0), `fontShadow` (`true`), `fontFromSkin` (`true`: the skin's `hud.font` while on, QC-03); `offset` 0-300 (0: automatic, just past the disc), the labels' distance from the center; and the tooltip's place (2026-10-21): `tooltipSide` (`"top"`; `"bottom"`, `"left"`, `"right"`), `tooltipOffset` 0-80 (8); `fillShape` backfills a dial saved before them |
| `dials[id].slice` | `defaults/PadStyle.lua` (`PadDefaults.DialSlice`) | the Slices tab (the pointer leaves on the Hub tab's Pointer heading), member rows `dial.slice.*` | the slices (2026-10-21): `background` (dark, alpha 0.8) with `useClassColorBackground` (`false`); `gap` 0-20 (0: the slices touch), the Slice gap, each slice moved out along its middle line so its straight edges sit `gap/2` off the spoke (dial polish, 2026-10-21, which retired `borderSize`, `borderColor` and `useClassColorBorder`: migration step 9); `highlight`, the hovered slice's fill (gold, alpha 0.25) with `useClassColorHighlight` (`false`); `pointerShow` (`true`), `pointerSize` 10-48 (24 (owner, 2026-10-22)), `pointerOffset` 0-150 (24 (owner, 2026-10-22); 0 is automatic, just outside the hub) and `pointerColor` (gold) with `useClassColorPointer` (`false`); the Shine heading's (shine overlay, 2026-10-21) leaves, the pad button's, the dial's own: `shineLook` (a pad button's `"glossfade"` at 80 with a #1B1B1B tint, a dial slice's `"orb"` at 85 with a #808080 tint, owner 2026-10-22; `"none"` before; `none`, `gloss`, `glossfade`, `orb`, `frost`, `fluid`, `bevel` or `rim`), `shineStrength` 0-100 in steps of 5, `shineTint` with `useClassColorShineTint` (`false`), `shineBloomA` (#ff9ad5, `{ 1, 0.604, 0.835, 1 }`) and `shineBloomB` (#8affc1, `{ 0.541, 1, 0.757, 1 }`), each with its `useClassColorShineBloomA|B` (`false`; Fluid glass only); `fillShape` backfills a dial saved before them (no migration: it draws None) |
| `dials[id].hub` | `defaults/PadStyle.lua` (`PadDefaults.DialHub`) | the Hub tab's Hub heading (the Slices tab's until the Hub tab, dial polish), member rows `dial.hub.*` | the hub (dial polish, 2026-10-21; the red close mark it replaced was not a setting): `style` (`"solid"`; `"ring"`, `"target"`, `"rimmed"`), `size` 24-80 (32 (owner, 2026-10-22), the backdrop's diameter: the hub's geometry, `qc-hub` on the catcher, the slices' and pointer's inner edge), `circleSize` 4-60 (24), `lineWidth` 1-6 (4, the ring styles'), `background` (dark, alpha 0.95) with `useClassColorBackground` (`false`), `borderSize` 0-6 (1 (owner, 2026-10-22); Rimmed disc draws one anyway), `borderColor` (gold) with `useClassColorBorder` (`false`), `circleColor` (gold) with `useClassColorCircle` (`false`); `fillShape` backfills a dial saved before them |
| `dials[id].title` | `defaults/PadStyle.lua` (`PadDefaults.DialTitle`) | the Labels tab's Group labels heading (its own tab until item 020), member rows `dial.title.*` | the ring's title above the dial (dial polish, 2026-10-21): `show` (`true`), `font` (`"Friz Quadrata TT"`), `fontSize` 6-32 (16 (owner, 2026-10-22)), `fontColor` (gold), `useClassColorFont` (`false`), `fontFlags` (`"@skin"`, From skin: the Skin tab's Font outline decides, LibKa0s v1.82.0; `"OUTLINE"` until then, which schema step 11 moved), `fontShadow` (`true`), `fontFromSkin` (`true`, QC-03); the font rows gray out while `show` is off; `fillShape` backfills a dial saved before them |
| `dials[id].page` | `defaults/PadStyle.lua` (`PadDefaults.DialPage`) | the Paging tab, member rows `dial.page.*` | a paged ring's row under the dial (2026-10-21): `offset` 0-80 (6), under the labels; `arrowSize` 12-48 (24), `arrowGap` 0-60 (10), `arrowColor` (gold) with `useClassColorArrow` (`false`), `plateColor` (the slices' dark fill) with `useClassColorPlate` (`false`); `dotSize` 2-20 (8 (owner, 2026-10-22), also the pill's height), `pillWidth` 2-60 (18), `dotGap` 0-30 (6), `currentColor` (gold) with `useClassColorCurrent` (`false`), `dotColor` (gray 0.4) with `useClassColorDot` (`false`); the indicators' background and border (dial polish, 2026-10-21): `dotBackShow` (`true`), `dotBackColor` (the plates' fill) with `useClassColorDotBack` (`false`), `dotBackPadding` 0-20 (4), `dotBorder` 0-4 (2 (owner, 2026-10-22), 0 none), `dotBorderColor` (black, alpha 0.9) with `useClassColorDotBorder` (`false`); `fillShape` backfills a dial saved before them, so no migration step |
| `pads[id].icon`, `dials[id].icon` | `defaults/Icons.lua` (`IconDefaults.For`) | the Icons tab's member rows `pad.icon.*` / `dial.icon.*` | how the buttons' or wedges' icons are drawn (B9): `size` (pad 12-40, default 16, feeding the button's height; dial 0 or 16-128, default 0, automatic: 48 at the default ring radius, 0.4 of it, `DialLayout.AutoIconSize`; a stored size is kept, the wedge's 44-pixel button kept; past 64 a game icon is upscaled, and Auto pages sooner when big icons no longer fit their slices), `zoom` 0-0.25 (0), `desaturate` (`false`), `alpha` 0.1-1 (1), `tint` and `useClassColorTint` (white: a glyph keeps its own color), `borderShow` (`false`), `borderStyle` (`"Solid"`), `borderSize` 1-16 (1), `borderColor` (black) and `useClassColorBorder`, `borderStyleFromSkin` (`true`: while on, the style and thickness are the skin's icon border, `icon.borderStyle` and `icon.borderSize`, QC-03; Border style and thickness gray out), `glowEnabled` (`false`), `glowWhen` (`always`, `hover` or `send`), `glowType` (`pixel`, `autocast`, `button` or `proc`), `glowColor` (gold) and `useClassColorGlow`, and DropWatcher's knobs (`pixelLines` 8, `pixelFrequency` 0.1, `pixelLength` 0 = automatic, `pixelThickness` 1, `pixelBorder` `true`, `autocastParticles` 4, `autocastFrequency` 0.125, `autocastScale` 1, `buttonFrequency` 0.25, `procDuration` 1, `procStartAnim` `true`, `xOffset` and `yOffset` 0). Flat leaves of one table, so `Library.Prepare`'s fillShape gives a surface saved before them every field |
| `seeded` | `false` | `Library.Prepare` | true once the default pad and dial exist (and the shipped sets are seeded into them) |

**Member rows** are how a member's fields are reached. Every field a player sets on a member is a
row whose path starts with the member's kind (`callout.*`, `group.*`, `pad.*`, `dial.*`). The seam's
`resolveRoot` hands it to `Library.Member(kind, id)`; the id is the instance argument, or the member
that kind's editor page has selected (`NS.State.editing`), or, with nothing selected, the first member
the page lists (`Settings.EditingId`). A callout is addressed by its id alone (`Settings.BY_ID_KINDS`):
no page selects one, so a `callout.*` write that names no id is refused with a line naming the id form
(`/qc set callout.<field> <id> <value>`). Each row's `onChange` is `Library.Touch`. The structured rows
(`pad.point`, `dial.point`, `group.when`) hold tables: their pages draw their own controls, and
`settings/Slash.lua`'s descriptor `parse` and `format` hooks type and print them on the CLI. The
Icons tab's rows are made by `settings/SchemaIcons.lua` and spliced in by `settings/SchemaMembers.lua`,
a pad's after its Window and Button rows, a dial's after its Labels rows.

The member rows address a member's fields through the seam (`settings/SchemaMembers.lua`): `callout.name|text|channel|icon|iconColor`, `group.name|icon|iconColor|enabled|parent|inheritWhen|when`, `pad.name|enabled|groupsAs`, `pad.layout.orientation|columns|growth|style|scale|spacing`, `pad.point`, the General tab's Visibility rows `pad.look.visibility|fade|fadeAlpha` (under its Visibility heading; Main window's until 2026-10-20), the Window tab's six composed rows `pad.look.borderStyle|borderSize|borderColor|useClassColorBorder|background|useClassColorBackground` (composed by the options library; the colors are the `color` row type; every composed font and border block also carries its "Use the skin's font / border" companion row, `<picker>FromSkin`, default on, which grays its picker out and shows the skin's value, QC-03), the Header tab `pad.header.height` and its twelve composed rows (the font block's `font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow` and the six above, under `pad.header.`), the Section titles tab `pad.section.height` and the same twelve under `pad.section.`, the Buttons tab `pad.button.width|height|glowEnabled|glowType` and its composed rows (`background|useClassColorBackground`, the border block, the font block, `glowColor|useClassColorGlow`) and its Shine heading's `pad.button.shineLook|shineStrength` with the composed pairs `shineTint|useClassColorShineTint`, `shineBloomA|useClassColorShineBloomA`, `shineBloomB|useClassColorShineBloomB` (Strength and Tint grayed out at None, the blooms unless the look is Fluid glass), `dial.name|enabled|mode|slices|radius|iconOffset|openAt|point`, the Labels tab's Slice labels heading's `dial.label.show|offset` and its composed font block `dial.label.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow` (grayed out while Show labels is off) and its Tooltip heading's `dial.label.tooltipSide|tooltipOffset`, the Layout tab's `dial.slice.gap` (Slice gap; on the Slices tab until item 020, the path kept) and the Hub tab's `dial.slice.pointerShow|pointerSize|pointerOffset` (its Pointer heading; on Slices until the dial polish, the paths kept), with their composed color pairs `dial.slice.background|useClassColorBackground`, `highlight|useClassColorHighlight`, `pointerColor|useClassColorPointer` (the pointer rows grayed out while Show pointer is off), the Slices tab's Shine heading's `dial.slice.shine*` (the pad's leaves and gray-outs), the Hub tab's Hub heading's `dial.hub.style|size|circleSize|lineWidth|borderSize` and composed pairs `dial.hub.background|useClassColorBackground`, `borderColor|useClassColorBorder`, `circleColor|useClassColorCircle` (Line width grayed out under Solid circle), the Labels tab's Group labels heading's `dial.title.show` and its composed font block `dial.title.font|fontSize|fontColor|useClassColorFont|fontFlags|fontShadow` (grayed out while Show group labels is off), the Paging tab's `dial.page.offset|arrowSize|arrowGap|dotSize|pillWidth|dotGap|dotBackShow|dotBackPadding|dotBorder` and its composed pairs `arrowColor|useClassColorArrow`, `plateColor|useClassColorPlate`, `currentColor|useClassColorCurrent`, `dotColor|useClassColorDot`, `dotBackColor|useClassColorDotBack` (grayed out with the padding while Show indicator background is off), `dotBorderColor|useClassColorDotBorder` (grayed out while Dot border is 0), and the Icons tab's `pad.icon.*` and `dial.icon.*` (the fields above; the Tint, Border and Glow color pairs and the Border block composed by the options library). They are not AceDB defaults; `Library.TEMPLATES` is their shape. A `callout.*` row is addressed by the callout's id alone (no page selects a callout): its `page = "callouts"` is the `/qc list` heading, not a registered panel page. An icon is a texture path (a LibKa0s glyph or a raid marker) or a texture id (a number: a game icon from the macro icon lists); `false` is none. `callout.iconColor` and `group.iconColor` default to `false` (none: the glyph is drawn white) and take six hex digits (typed text may carry `#`, spaces or capitals; it is stored lowercase), only on a member whose icon is a LibKa0s glyph; an icon write that leaves a colored member without a glyph clears its color in the same act. Both are reset-exempt with the icon rows (`settings/Schema.lua`): a named `/qc reset` clears the color, a page's Defaults keeps it. `group.parent` takes a group id, or `false` (`none` or empty text on the CLI) for none; `Library.ValidParent` refuses itself, a group that is not a top-level user group, and any parent for a group that holds groups. Its write takes the group off every pad and dial in the same act (`Library.SettleParent`). It is reset-exempt too. `group.when`'s place rows (`Resolver.ID_ROWS`: `instances`, `battleground`, `arena`) take map ids and, beside them, `all` (`Resolver.ALL`): the whole kind (any dungeon, Mythic+ key or raid; any battleground; any arena), matched whatever ids are listed; the `arena` row matches only while the content is `arena`; `Library.ValidWhenValue` refuses it on every other row. `group.inheritWhen` (bool, default `true`) is Inherit when conditions: a group inside another uses its parent's When instead of its own (`Resolver.WhenOf`), and its own stored When is kept, unread. A new group stores `true` (`CreateGroup`, so a Duplicate passes its value on, and the seeding); a group stored before the setting has no field, which reads as on, and `/qc get group.inheritWhen` prints nil for it until it is written. It is not reset-exempt: a page's Defaults ticks it again. Open the dial on this group (`openInto`) and Skip on the dial in content (`dialYield`) are retired (dial rework, 2026-10-21): migration step 8 drops them from every stored group, and a dial opens straight on its one active group or on a ring of them.

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

## `QuickCommsDB.char` (per character)

AceDB's `char` section, keyed by the character (`"<name> - <realm>"`), for what is genuinely
per-character (savedvariables-§1): `defaults/Profile.lua` `CHAR_DEFAULTS`, merged in by
`Settings.BuildDefaults`. A profile switch, copy or reset never touches it.

| Key | Default | What it is |
|---|---|---|
| `padsHidden` | `false` | whether `/qc toggle`, the launcher's Show window or the Toggle Comms Pads key last hid this character's Comms Pads (2026-10-21; a session-only `NS.State.padsHidden` until then); a /reload or the next login restores it |

## Named non-setting state (architecture-§5)

Every key written outside the schema seam, with the module that owns it and every function that
writes it. This is the one list; the hub points here.

Saved:

| Key | Owner | Writers | What it is |
|---|---|---|---|
| `profile.previewWindow` | `modules/PreviewWindow.lua` | `remember`, the window's drag stop | the Preview as window's place (above) |
| `char.padsHidden` | `settings/SlashVerbs.lua` | `V.TogglePads`, reached by `/qc toggle`, the launcher's Show window entry and the Toggle Comms Pads key | whether this character's Comms Pads are hidden (above) |
| `global.minimap.minimapPos` | LibDBIcon | LibDBIcon's own drag write, into the table `core/LauncherSetup.lua` hands it | the minimap button's angle |
| the structural registry: membership of `callouts`, `groups`, `pads` and `dials`, `padOrder`, `dialOrder`, each group's `callouts` and each surface's `groups`, `nextId`, `seeded`, `seededSets`, a seeded member's `origin` | `modules/Library.lua` | Library's own functions and its schemaVersion steps in `modules/Library_Migrate.lua` (the same `NS.Library`); panel pages and slash verbs call it or the seam and never write these keys | above |
| `global.schemaVersion` | `core/Database.lua` | the migration runner, after each step returns | the migration stamp |

Session-only, in `NS.State` (`core/State.lua` declares the shared ones) and reset by `/reload`:

| Key | Owner | Writers | What it is |
|---|---|---|---|
| `debug` | `core/DebugLogSetup.lua` | the console's switch (the Debug console row, `sessionOnly`, stores through its own closure) | the logging flag |
| `testMode` | `modules/Preview.lua` | `P.SetTestMode`, `P.SetPreviewAs` (starting Preview as ends it), the stand-down | test mode (the Test mode row's store) |
| `previewAs` | `modules/Preview.lua` | `P.SetPreviewAs`, `P.SetTestMode` (turning test mode on ends it), the stand-down | the "Preview as…" situation; outlives the settings window, ended by End preview, Escape or the window's close mark, `off`, test mode, combat or the stand-down |
| `editPreview` | `modules/Preview.lua` | `P.SetEditPreview`, the stand-down | the group the Groups page shows alone on every pad and dial while Preview while editing (`behavior.previewOnEdit`, the saved switch) is on |
| `editPreviewDismissed` | `modules/Preview.lua` | `P.DismissEditPreview` (Escape on the preview window), `P.ClearEditPreviewDismissal`, `P.EndPreview`, the stand-down | the group whose edit preview Escape dismissed: the page leaves it off until another group is picked, the page is shown again or the setting is written |
| `editing` | `settings/Editors.lua` | `Ed.Select`; cleared on a profile switch | each editor page's selected member; never a callout |
| `whenOpen` | `settings/Groups_When.lua` | the drawers' open state (`openRows`); cleared by `settings/Editors.lua` on a profile switch | the When editor's open drawers, per group and condition |
| `padTab`, `padCollapsed` | `modules/Pad.lua` | `Pad.Wheel` and a tab click; `Pad.ToggleCollapsed` | per pad: the active tab, the collapsed state |
| `padCoolTimer`, `padFlashTimers` | `modules/Pad.lua` | `Pad.Cooldown`, the send-result listener; the stand-down | the guard dim and send-flash timers |
| `surfacePlans`, `dialPlans`, `surfaceOrder`, `surfaceStale` | `modules/Surfaces.lua` | `S.ApplyAll`, the rebuild queued in combat; the stand-down | the plans, the floated order, the stale hints |
| `sendQueue`, `sendEcho`, `echoTimers`, `lastSendAt`, `pendingTeardown` | `modules/SendEngine.lua` | the queue, the press, the echo handler, `SE.Teardown`; the stand-down | the combat-end queue, the presses awaiting an echo and their timers, the guard's last press, a stand-down held for combat's end |
| `restrictionLiftTimer` | `modules/Restrictions.lua` | `R.RefreshAfterLift`; canceled by the stand-down | the one pending late re-read after an encounter or a key ends |

Local to one file, never in `NS.State`: the callout popup's draft (`settings/CalloutPopup.lua`,
dropped whenever the popup closes); the icon browser's open request, tab, filter, selection and color
(`settings/IconBrowser.lua`, dropped whenever it closes), its search text (kept for the session) and
its game icon lists (kept for the session once the client answers with icons).

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
pad with no layout, is left as it is.
Step 5 (2026-10-19, `perProfile`, `Library.MigrateBuiltins` in `modules/Library_Migrate.lua`): every
group whose origin is `bi.mplus` and whose name is still "M+ (generic)" becomes "Dungeon"
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
Solo set needs no step: `Library.Prepare` seeds it as any newly shipped set (`seededSets`).
Seeding now copies a shipped group's `iconColor` too. A second run changes nothing.
Step 7 (2026-10-20 battleground sub-groups, `perProfile`, `Library.MigrateBattlegroundNodes` in
`modules/Library_Migrate.lua`): every node a later version ships goes inside its set's copy while that
copy is a top-level group (`Library.SeedNewNodes`, the node half of Prepare's seeding, shared): a node
`seededSets` already lists (kept, moved or deleted by the player) is passed over, and one whose set
was deleted or sits inside another group is only listed, so neither ever comes back; each new node
takes fresh ids above every stored one, after the nodes already there, and nothing the profile holds
is changed. This is how Alterac Valley's 19 objectives, Isle of Conquest's Our base and Enemy base,
and the objective groups of Warsong Gulch, Twin Peaks, Wintergrasp, Ashran, Deephaul Ravine and
Seething Shore reach stored profiles, the inactive ones included; a copy nested in another group
takes no nodes. (Until the dial rework the step also turned each flat set's `openInto` on; that half
is gone with the field.) A second run changes nothing. `Library.Prepare` seeds the same nodes on a
profile never prepared.

Step 8 (dial rework, 2026-10-21, `Library.MigrateDialFields`, `modules/Library_Migrate.lua`): every
stored group drops `openInto` (Open the dial on this group) and `dialYield` (Skip on the dial in
content); nothing else is touched, a damaged group is left as it is, and a second run changes
nothing. A stored dial's `slices` is not migrated: a dial still on 4 keeps 4, and only a new dial
starts on Auto.
Step 9 (dial polish, 2026-10-21, `perProfile`, `Library.MigrateSliceBorder`, `modules/Library_Migrate.lua`):
every stored dial's `slice` table drops the retired border leaves `borderSize`, `borderColor` and
`useClassColorBorder` (the Slice gap parts the slices now); a dial with no `slice` table, or a
damaged one, is left as it is, and a second run changes nothing. The new `slice.gap`, `hub` and
`title` leaves need no step: `fillShape` backfills them. A stored fixed 4, 6, 8 or 12 now starts at W
(it started at N), with no step: placement is worked out at every rebuild.
Step 10 (the skinning rollout, QC-03, 2026-10-29, `perProfile`, `Library.MigrateFollowSkin`,
`modules/Library_Migrate.lua`): the one-time reset onto the skin (the owner's ruling O2). Every stored
pad's and dial's font and border blocks (`Library.FROM_SKIN_KEYS`: a pad's `look.borderStyle`,
`header.font|borderStyle`, `section.font|borderStyle`, `button.font|borderStyle`, `icon.borderStyle`;
a dial's `icon.borderStyle`, `label.font`, `title.font`) get their "Use the skin's font / border"
companion (`<picker>FromSkin`) turned on: a stored companion through LibKa0s-Skin-1.0's
`ResetToSkin`, an absent one written `true` (ResetToSkin would write its `"@skin"` sentinel into the
picker). The picks themselves are kept, and no color, size or flag is touched (DECISIONS X4). The
stamp makes it once: a companion the player turns off afterwards stays off.
Step 11 (LibKa0s v1.82.0, QC-01, 2026-10-30, `perProfile`, `Library.MigrateFontFlags`,
`modules/Library_Migrate.lua`): Font flags gain From skin (DECISIONS D-07, Addendum 01). Every stored
pad's `header`, `section` and `button` and every stored dial's `label` and `title`
(`Library.FONT_FLAG_BLOCKS`) whose `fontFlags` is `"OUTLINE"`, the old default, becomes `"@skin"` once,
so the block follows the Skin tab's Font outline; any other value (`THICKOUTLINE`, `""`, ...) is the
player's pick and stays, and a damaged surface is left as it is. A player who explicitly picked OUTLINE
before the update cannot be told from the default and moves to From skin (Addendum 01 accepts that).
The stamp makes it once: an OUTLINE picked afterwards stays.
`NS.SCHEMA_VERSION` is 11.
No schema step for the bg buttons (2026-10-20, owner ruling: the addon is unreleased, so a profile is
reset rather than migrated): In Group and Silvershard Mines' and Temple of Kotmogu's groups reach a
stored profile through `Library.Prepare`'s seeding as any newly shipped set or node (In Group at the
end of every pad and dial), but a stored node keeps the INC 1/2/3/Many/Clear/Help callouts it was
seeded with, Isle of Conquest's bases their two, and a stored Silvershard Mines or Temple of Kotmogu
copy kept Open into off (a field the dial rework retired); a reset profile (or Restore built-in groups, which adds the four new rows beside the old)
takes the Attack, Defend, INC and Clear rows.
No schema step for the replaced prebuilts (2026-10-23, owner ruling: pre-release, no migration):
Chain pull's yellow, Hello's sky blue, In Group's At Stone (`bi.group.stone`, 2nd), Solo on General (/1)
and Solo's `{coordinates}` lines reach only a new profile and Restore built-in groups; a stored
profile keeps the callouts it was seeded with.
No schema step for nested groups (2026-10-18): a group without `parent` is top-level, and
`Library.Prepare` drops a bad one.
No schema step in phase 5: `Library.Prepare` fills a stored pad's missing layout and look fields from
the defaults (`fillShape`), so a pad saved before the Look groups reads like a new one.
No schema step for the window tabs and the Buttons tab or the dial keys (2026-10-20, owner ruling: the
addon is unreleased, so a profile is reset rather than migrated): fillShape gives a stored pad its
`header`, `section` and `button` tables; a stored `layout.width`, a stored `look.font*` (the section
titles' font before it moved to `section`) and a stored dial's `key` are left unread, and a key a stored
dial carried is not moved into WoW's bindings (bind it again on the Dial page).
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
