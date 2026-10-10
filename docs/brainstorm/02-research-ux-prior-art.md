# Research 02: Radial menus, game comms wheels, rule editors

Brainstorm input, gathered 2026-10-11. **[V]** means confirmed against a primary source, **[S]** means secondary or community sources only, **[U]** means uncertain.

## How many slices, how deep

| Finding | Source |
|---|---|
| Pie menus were about 15% faster with fewer errors than linear menus. Every item is the same short distance away and wedges widen outward (Fitts's law). | Callahan et al., CHI '88 [V] |
| Errors, not time, set the limit. Errors stay **under 10% up to 8 wide × 2 deep** or **4 wide × 4 deep**. At 12 wide, anything past one level is unreliable. | Kurtenbach & Buxton, CHI '93 [V] [link](https://www.billbuxton.com/MMExpert.html) |
| **On-axis** slices (N/E/S/W, then the diagonals) are clearly faster and more accurate. Put favourites there and put opposites opposite. | same |
| **Press and wait about 300 ms before drawing.** A flick sooner than that is a "mark" and needs no menu. Experts end up 3–4× faster than menu use. | Kurtenbach & Buxton, CHI '94 [V] [link](https://billbuxton.com/MMUserLearn.html) |
| For nested menus, **a fresh straight stroke per level** beats one zig-zag drag. Open the sub-ring where the cursor is (or recentre). | Zhao & Balakrishnan, UIST '04 [S] |
| OPie's guide recommends no more than 8 slices for combat rings. | [OPie guide](https://www.townlong-yak.com/addons/opie/guide) [V] |

**Proposed limits for the Comms Dial**
- **4 slices** is the default. It matches Blizzard's ping wheel, is the most accurate, and works with a d-pad.
- **8 slices** is the recommended maximum per ring. **12** is a hard cap, allowed only on a ring with no children.
- **Depth 2**, with depth 3 allowed but warned about.
- That gives **64 callouts** at 8 × 8, far more than anyone can remember. So the real limit is memory, not the screen.

## Game comms wheels

| Game | Pattern worth stealing |
|---|---|
| **WoW ping** (10.1.7) [V] | Tap for a contextual ping, hold to open a 4-option wheel, flick to choose. A *Quick* (hold-flick) and a *Relaxed* (click) mode. Spam lockout. Leaders can restrict pings. |
| **Rocket League quick chat** [V] | **4 categories × 4 messages** on the d-pad: Up then Up sends "I got it!". This is the closest analogue to "groups as categories". Spam gives "Chat disabled for 3 seconds". |
| **Overwatch** [S] | 8 sectors, each assignable from 26 options, **per hero**. Settings show a wheel diagram: click a sector, pick from a list. |
| **Valorant** [V] | Scroll the mouse wheel while the wheel is open to **cycle pages** (Combat / Social / Strategic). |
| **Dota 2** [S] | 8 directions, a "Customize Chat Wheel" editor, and a second wheel. |
| **Apex** [S] | Tap or double-tap for context pings; feedback is a voice line plus a world marker. |
| **League** [S] | 3 pings per 6 s *per type*, with a clear "you must wait" error. |
| **Fortnite** [V] | 6-slot wheel plus a second wheel filled from favourites. |

**Patterns across them:**
- Hold-and-release is how experts use these wheels, with a click mode for accessibility.
- A **tap with no direction does the default action**.
- Past 8 items, the options are pages (scroll), nesting (categories), or a second wheel/bind. **Nobody scrolls a list inside a wheel.**
- Spam control is a small burst allowance, then a short lockout with a visible message.
- Feedback combines sound, a visual confirmation and the message echoed in chat.

## OPie, the WoW reference

- **Quick** (hold, aim, release) and **Relaxed** (tap, then click) presets. You only need to move *toward* a slice, not onto it. Release in the centre, right-click or Esc to cancel.
- **Nested rings** can be shown three ways:
  - *nested* (a sub-ring opens on hover; scroll to rotate which child is shown)
  - *jump slice*
  - *embed* (the sub-ring is flattened into the parent)
- **Per-slice visibility** uses macro conditionals (`[combat]`, `[group]`), which are powerful but intimidating.
- The editor is a slice list plus a detail pane, with share/import strings.
- Common complaints **[S]/[U]**: the default skin looks dated (hence OPieMasque), macro-syntax conditions are hard to read, and the editor is dense.

## What "sleek and modern" means to WoW players in 2026

The EllesmereUI / ElvUI / Plater look **[S]**:
- flat dark panels at 70–85% opacity, 1px pixel-perfect borders, a single accent colour (gold or class colour)
- clean sans fonts instead of Friz Quadrata
- no parchment or gilt frames
- an "Unlock mode" with snapping, and Masque support for icons

The Ka0s house skin already fits this: background `0.06, 0.06, 0.08, 0.92`, a 1px black outer border, a 1px grey inner line, a gold `1, 0.82, 0` title, and a red **TEST MODE** label in preview.

## Rule ("situation") editors

- **WeakAuras Load tab:** checkbox rows of conditions (instance type, spec, role, encounter, leader…), ANDed together, with OR inside a multi-select. WoW players know it best, though WeakAuras itself is gone in Midnight.
- **Edit Mode** remembers a layout per spec. Addons such as AutoSwitcher layer per-content overrides on top, which amounts to "most specific wins".
- **OPie:** macro conditionals where the first match wins.

**Three ways to resolve priority:**
1. **Ordered list, first match wins:** predictable, but users must order rules by hand.
2. **Most specific wins:** feels natural (*Windrunner Spire* beats *any M+*, which beats *any party*), but ties need a rule.
3. **Union:** show every group that matches, sorted by a key.

**Making it understandable:**
- a **"Why is this showing?"** tooltip that lists the matched conditions
- a **"Preview as…"** situation picker in settings that live-previews the pad and dial
- a "currently active" marker
- an indicator for chat lockdown

## Accessibility

- **Colour-blind support:** don't signal the selected wedge with gold alone. Also enlarge the icon by 10–15%, thicken the outline, keep the pointer arrow, and bold the label.
- **Keyboard:** number keys 1–8 clockwise from 12 o'clock while the dial is open, Esc to cancel, and a Relaxed (toggle) mode for players who can't hold a key.
- **Gamepad** (ConsolePort and the native gamepad mode): stick angle selects the wedge with a 25–35% dead zone, a bumper pages or enters a sub-ring, B backs out.
- **Scale and opacity sliders** for each surface, and labels of at least 12 pt.
