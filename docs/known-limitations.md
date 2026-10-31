# Known limitations — Ka0s Quick Comms

What the addon cannot do, or does only under a condition, and why. The hub,
[`ARCHITECTURE.md`](ARCHITECTURE.md), carries the summary; the in-game checks named here are in
[`smoke-tests.md`](smoke-tests.md).

## Sending, channels and restrictions

- The spam guard is soft: insecure code cannot cancel a secure click, so a press inside the window
  still reaches the game. A boss may drop it; the echo tracker then reports the drop (spec §9.2, the
  C5 upgrade).
- Another player's message on the same channel can mask a drop, and an unreadable sender counts as the
  player's own echo (spec §9.3, C6).
- General (`/1`) is sent only when the client says channel 1 is the zone General channel:
  `C_ChatInfo.GetGeneralChannelLocalID()` must answer 1 (F-007, owner ruling 2026-10-25: verify, else
  Say). If the player moved General off `/1`, made a custom channel `/1`, or the client gives no plain
  answer (the API missing or the value secret), a General callout goes to Say, exactly as when General
  is not joined; it never follows General to `/2` or later. The channel is never matched by its
  localized name (localization-§4). The in-client check is smoke check SEND-6.
- A chat lockdown that clears with no event of its own is re-read on `ENCOUNTER_END` and
  `CHALLENGE_MODE_COMPLETED`, at the event and once more 1 s later (`Restrictions.RefreshAfterLift`;
  the delay is `LIFT_DELAY` in `modules/Restrictions.lua`). A lockdown that clears later than that,
  with no restriction or combat event after it, keeps the padlock and the lockdown chip until the next
  restriction event, combat edge or stand-up. A press still sends, but prints the
  may-not-have-been-sent line. The in-client check is smoke check SEND-7.
- In combat a rebuild waits for combat to end: buttons keep the lines baked at the last rebuild out of
  combat (a stale `/p` after leaving a group, spec §18).
- Disabled in combat, a pad stays on screen, and its buttons still send, until combat ends and the
  held stand-down finishes. Those presses are not tracked: no guard, no echo timer, no note.
- Rebuilding between pulls inside a key assumes `SetAttribute` works out of combat in a key (C4,
  unverified).

## The Comms Pad

- The mouse wheel over a pad belongs to the pad (spec §10.2): with groups as tabs it switches the tab,
  otherwise it does nothing there, so the camera does not zoom while the cursor is over a pad.
- The Buttons tab's glow has no trigger: it is on around every button while enabled, at the Icons
  tab's knob defaults (only its style and color are settings).
- A grid pad packs a parent's child sections side by side only while consecutive ones fit its columns;
  a lone or wide child keeps a row of its own, and horizontal and vertical pads never pack.
- A pad's saved point is read as its growth edge's (its top for down growth, its bottom for up growth,
  B2). Before 2026-10-19 a saved point named whatever point the client returned, and a never-dragged
  pad's default `CENTER 0 -150` was its center's; such a pad moves once on its first load, by half its
  height or its whole height; a drag saves the edge point and it stays put from then on. No migration
  converts the old point, which would need the pad's drawn height (the addon is unreleased, so only
  pre-release profiles carry one).

## The Comms Dial

- The Comms Dial is Relaxed only: the hold, flick and release dial, its draw delay and tap action wait
  for C7 (spec §11.2).
- A slice clicks anywhere from the hub's circle to the rim through the ring's catcher, and the hub
  clicks inside its circle through the same catcher (the header takes no mouse, so the hub is round
  like its drawing; `Dial_Layout.InHub` and `Dial_Layout.SliceAt` are the one rule the tracker and the
  catcher share), which reads the cursor with the restricted `GetMousePosition` (dial polish,
  2026-10-21): that API was the C7 item the go/no-go record never verified, and DIAL-28 passed in game
  on 2026-10-21, the in-combat click and the hub's included (the fallback it kept in reserve was
  forwarding tiles). A point in a slice gap belongs to the slice whose bearing it is in. A right click
  on a slice goes up a ring through the header's `qc-back` (nothing on the first ring; owner,
  2026-10-22), and a key open shows the ring and page the last key open closed on, found by the ring's
  key and page (`qc-key-<r>`, `qc-page-<r>`), kept in the header's restricted environment for the
  session.
- While a dial is open from its key, its full-screen catcher takes every click outside it (it closes
  the dial and does nothing else), so a world click or an action-bar click needs a second press.
- A dial whose groups are all inactive opens nothing when its key is pressed (there is no empty ring).
- Open at the cursor relies on the restricted `SetPoint` accepting `$cursor` (DIAL-7 passed,
  2026-10-21); the fallback, if a patch breaks it, is opening at the dial's place.
- A dial closes on a send, so its guard dim and its drop flash show only on the next open: the dim for
  the guard window, a drop's red for 5 s; the chat note reports a drop either way.
- Disabled in combat, a dial keeps working (and its key keeps opening it) until combat ends and the
  held stand-down finishes.
- A dial places a battleground set's nodes like any ring's items (owner, 2026-10-25): one slice each
  under Auto, A–Z after the set's own wedge, so a node's slice does not match where it is on the map.
  Until then each seeded node was pinned to its compass wind on an eight-slice ring, and the slices
  with no node were drawn empty.

## Keys

- A dial's key belongs to its place in the dial order, not to the dial (2026-10-20): it is WoW's
  binding of Open Comms Dial <n>, so deleting or reordering dials hands a key to the dial that takes
  the place, and a dial past the fourth place has no key. The key lives in WoW's bindings, not the
  profile: a profile switch, copy or reset never moves it, and a stand-down or a disabled dial leaves
  it bound and opening nothing rather than giving it back to the game. It is set in Options →
  Keybindings, which the game itself keeps out of combat, or on General → Keybindings, which refuses
  every write in combat.
- The Toggle Comms Pads binding and the dials' entries are CLICK bindings on buttons registered for
  the down edge; a plain (insecure) button's CLICK binding fires on the key press (KEY-3 passed,
  2026-10-21).

## Previews and test mode

- Test mode and Preview as… open the dial without taking any key (`qc-display`), so the settings
  window behind it keeps Escape and 1–8 (under Preview as…, the preview window takes the first
  Escape): on a paged ring the Left and Right arrow keys and the wheel do not turn the page there; the
  page arrows under the disc do (owner, 2026-10-22: kept as is).
- Test mode or Preview as… ended by a combat whose lockdown began first leaves dial 1 open, its
  placeholder wedges sending nothing and holding no key, until combat ends (the hub or its key closes
  it sooner).
- Preview as… outlives the settings window, so dial 1, open in display mode, can stay on screen with
  no settings behind it; End preview or Escape (through the preview window) ends the preview and
  closes it, and its hub closes it sooner.
- With the settings window open and a Preview as… on, the first Escape ends the preview (the preview
  window is in `UISpecialFrames`) and a second closes the settings, as the callout popup behaves.

## Groups, When and the built-in data

- Inherit when conditions is all or nothing: an inheriting group takes its parent's whole When, with
  no way to add a condition of its own on top (untick it to set its own instead). A group stored
  before the setting reads as inheriting; `/qc get group.inheritWhen` prints nil for it until it is
  written.
- Groups nest one level only: a group inside another cannot hold groups, and a group that holds groups
  cannot go inside another. A group's children are drawn, listed and offered A–Z by name,
  case-insensitive, then in the order they were made (owner, 2026-10-25); there is no control to
  reorder them.
- Restore built-in groups puts back only what is missing (a seeded set, node or callout no member
  keeps the origin of); it never resets a seeded group the player changed. To get a stock set back,
  delete its group and restore. A copy (Duplicate, Reuse) keeps no origin, so it never stands in for
  the stock set.
- The battleground colors of 2026-10-25 (a faction-themed location in its faction's color, a neutral
  one in a color for what it is, Attack crimson and Defend cyan) are seed data, not migrated (owner):
  a profile seeded before keeps its colors until it is reset; Restore built-in groups brings back only
  what was deleted.
- Alterac Valley's 19 objective groups page its dial ring: its own callouts as one wedge first, then
  the objectives A–Z a few wedges a page, turned by the arrows under the dial (five pages on a
  four-slice dial, three on Auto). Its pad sets the objectives two to a row, still about 560 px tall
  beside the generic set on a default pad; groups as tabs, or switching the generic set off, shortens
  it (smoke check BG-3).
- A battleground's objective groups have no faction condition (owner ruling, 2026-10-20): "Our base"
  and "Enemy base", "Our flag" and "Enemy flag" read the same for either side, so nothing names
  Alliance or Horde, and a group is not hidden for the side it does not fit. Seething Shore's groups
  are the node in front of you and the next spawn, not its dozen sites, because its azerite erupts at
  random among them.
- Silvershard Mines' tracks are named Lava, Water and North as players call them, not from client data
  (smoke check BG-8).
- In Group (party, raid or instance group, no content condition) is active in every dungeon, raid and
  battleground beside the content's own set, and it is always on the pad there. It ships last, after
  the generic battleground set, so a content set stays the first active group on the pad. On a dial it
  is one more group (the dial rework retired Skip on the dial in content, 2026-10-21): with the
  content's set active too, a dungeon, raid or battleground dial opens on the ring of groups, so a
  battleground's node callouts sit three rings deep (groups, the set's nodes, a node's callouts).
- The Midnight dungeon and raid ids, spec 1480 and the battleground ids are matched against the
  client's data tables and confirmed in game by smoke checks IDS-1 and BG-2 (2026-10-21); Sporefall
  (1592) is left out (owner ruling R4). So are the When editor's place lists
  (`defaults/GameIds_Instances.lua`: every journal dungeon and raid, every arena less two legacy
  copies), checked by IDS-1.
- Two journal instances share a client name with another map (Blackrock Depths 230 and 2792;
  Magisters' Terrace 585 and 2811): a typed name for the first pair is refused as ambiguous (pick it
  from the suggestions, or type the id), and for the second the season's 2811 wins.
- Midnight's Slayer's Rise (map 2799) has no battleground set of its own; the generic set covers it.
- The shipped raids are the current tier's three; a later tier joins `defaults/GameIds.lua` when it is
  current (the When editor adds the instance you are in meanwhile).

## The editors and their windows

- A member row written from the CLI addresses the member its page has selected, else the first that
  page lists; the echo does not name which member it was. A callout row is the exception: it names its
  callout by id.
- A `/qc set` to the callout the popup has open is not merged into the draft: Save writes the fields
  the draft changed, measured against the values the popup opened with, so it overwrites the slash
  write on those fields and keeps it on the rest.
- The Profiles page builds only where AceDBOptions and AceConfigDialog resolve, which the headless
  mock does not model; PROFILE-1 is its in-game check.
- The callout popup has no scrollbar: its window is as tall as its content, so on a screen too short
  for it (a very large UI scale) it runs past the top and bottom edges, Cancel and Save included;
  Escape still cancels.
- A change of skin source away from EllesmereUI is one-way, as EllesmereUI's skins are: it takes
  effect after a reload, which the Skin tab offers. A client without `SettingsFrameTemplate` gets the
  callout popup's older shape (a plain frame in the skin's window fill and edge, and the shared close
  mark) instead of the settings template's window.
- A skin change in combat repaints the pads and dials only when combat ends (a rebuild waits for it,
  with the stale hint meanwhile), as every rebuild does: a face or a border style moves a pad's
  measured widths, and a secure pad cannot be re-laid out in combat. The one-time reset onto the
  skin (schema step 10) moves every pad's and dial's faces to the skin's HUD font (Prototype under
  Ka0s Default since LibKa0s v1.82.0, Oxanium SemiBold before) and their border styles to its own;
  the colors stay the player's. Step 11 moves every stored OUTLINE Font flags to From skin once, so
  a player who had picked Outline on purpose now follows the Font outline (the same pixels under
  its default, HUD text only, because pads and dials are HUD text); picking Outline again keeps it.
- A block on the skin's face draws at the skin's HUD size (`NS.Skin.HudFontSize`, LibKa0s v1.82.0,
  D-09), so under Obsidian a stored 12 draws at 13 and the pad's buttons grow with it; the stored
  size is never rewritten. A block on its own face, or Ignore fonts, draws the stored size.
- The client reads an addon's new files only at start-up, so a font file that arrives with a LibKa0s
  update needs a full client restart, not `/reload`, before a skin can draw it.
- The icon browser searches game icons by texture id only: the client gives them as texture ids, with
  no names, and has no API that names one, so a game icon is named by its id and a name is looked up
  on Wowhead (the tab's hint; the game cannot open a web page, so the address is shown to copy). No
  icon name table is shipped. Its game icon lists are read once the client has loaded its own; on a
  first open before that the Game icons tab says so and fills on a later visit.
- A glyph's color applies to LibKa0s glyphs only (white on transparent); a raid marker, a game icon or
  a typed texture is drawn as it is, and choosing one clears the member's color.

## Art, measurement and the library

- The dial's shine cuts its Gloss cap, Gloss fade, Glass orb, Frosted glass, Fluid glass and Rim light
  layers to each slice with a MaskTexture turned like the slice's fill; Bevel is slice-shaped art per
  slice count (`shine-edge-bevel-<n>`), unmasked. The headless mock records the mask's texture, place
  and turn, not the cut it makes; `tools/render-shine-preview.py` composites the cut the way the
  client is understood to (a mask's alpha times the layer's, a turned quad drawing nothing outside
  itself) and reproduced the owner's first in-game screenshots, but a clean cut at every slice place
  stays an in-game check (SHINE-2). The fallback, should the client cut a turned mask badly, is in the
  spec: per-slice-count masked textures for Gloss cap.
- The art is ours and generated: `tools/gen-dial-textures.py` draws the dial's sectors,
  `dial-disc.tga` and the twelve-step ring ladder; `tools/gen-shine-textures.py` the 52 `shine-*.tga`
  textures (about 10.7 MB). What the addon draws with them is rendered offline by
  `tools/render-shine-preview.lua` (the addon loaded headless, its regions dumped) and
  `tools/render-shine-preview.py` (composited as the client blends them) into
  `docs/superpowers/specs/2026-10-21-shine-overlay/render-*.png`. A ring between two ladder steps
  draws the nearer, so its line can be up to about 18% off (under 1 pixel at the largest Line width);
  a change to the art is a re-run of the generator, never a hand edit (`DEPENDENCIES.md`).
- `tests/perf.lua`'s byte ceilings are the headless mock's figures (its catch-all methods allocate per
  call); compare them run to run, never with the client.
- Quick Comms bundles LibKa0s v1.84.0. LibStub keeps the highest minor of each module, so when another
  Ka0s addon loaded beside it carries a newer LibKa0s, those modules run the newer code, whatever the
  load order. The headless suite measures v1.84.0 only. The remedy is this addon's own re-vendor
  (`/dev-copilot:wow-revendor-libka0s`), never an edit under `libs/` (F-010).
