# Dial polish — design (2026-10-21)

Owner request after the dial rework merge (`239b665`). The dial works; this batch makes it look and
behave the way the owner expects when actually using it: slices laid out predictably whatever the
slice setting, every point of a slice selectable, a proper centre piece instead of a red X, the ring
title styled like the slice labels, and a dial that gets out of the way when you click elsewhere.

Mockups of the centre piece: https://claude.ai/artifact/XmCFj3onYBQTQYz4DsGAjB

Conformance: the Ka0s WoW Addon Standard applies throughout (schema-driven rows, locales, the green
gate, docs in the same change). Nothing here is meant to deviate; if building one of these needs a
deviation, stop and flag it (CLAUDE.md).

## Goals (the owner's, item by item)

1. **Remove Slices → Border.** The Border heading, `dial.slice.borderSize`, `dial.slice.borderColor`,
   `dial.slice.useClassColorBorder` go, and the spokes and rim drawing with them
   (`modules/Dial_Slices.lua` `paintBorder`). Saved profiles that hold those leaves must load clean
   (dropped by migration or ignored; builder's call, following how earlier retired rows were handled).

2. **Slice gap (owner: pixels, 0–20).** A new Slices row, *Slice gap*, `dial.slice.gap`, default 0.
   Neighbouring slices have a parallel transparent gap of that many pixels between them. Owner-accepted
   approach: the "exploded pie" — each slice keeps its sector texture but is moved outward along its
   own bisector by `d = (gap/2) / sin(π/n)` and shrunk to radius `R − d`, so its outer edge stays on
   the disc and its straight edges sit `gap/2` off the spoke line. One slice (n = 1) has no gap.
   The highlight slice moves with its slice. **Auto counts the gap:** Auto's per-page wedge count is
   no longer just "one wedge per item, at most 12": it is capped at the number of slices whose arc at
   the icon reach, less the gap, still fits the icon (icon size plus a small margin). Past that cap a
   ring pages. Fixed counts are never changed by the gap.

3. **Slice placement (owner: keep the fixed count, fill W/E).** One placement rule for Auto *and*
   fixed counts. Places are numbered clockwise from W. With 4 places (Auto's 3- and 4-item rings, and
   fixed 4 with any item count), the item→place mapping depends on the item count (the owner's
   sheet): 1 item: W · 2 items: W, E · 3 items: W, N, E · 4 items: W, N, E, S. On a fixed 4 ring the unused places are
   drawn as empty slices (not lit, not selectable). Auto keeps its current shapes (1 item: whole
   disc; 2: two halves W/E; 3: four quarters, S empty; 4: quarters). 5 or more places (Auto with 5+
   items, fixed 6/8/12): evenly spaced, place 1 at W, items clockwise in order, slice width 360/n.
   Fixed counts start at W from now on (today they start at N). A fixed 6/8/12 ring with fewer items
   fills places 1..k clockwise from W and leaves the rest empty. Pinned battleground node rings keep
   their compass places (unchanged). The number keys 1–8 keep following item order.

4. **Select a slice all the way to the hub.** Today a wedge is a square button; between the hub and
   the square there is a dead band (on a 4-slice ring at radius 100 the square's inner edge sits about
   58 px out), so near the pointer nothing is hovered, no tooltip, no click. Wanted: anywhere inside a
   used slice, from the hub's edge to the rim, hovers that slice (highlight + tooltip) and clicks it.
   - **Hover / tooltip**: driven by the per-frame angle tracker that already lights the slice
     (`Slices.Track`): the tracked slice shows its wedge's tooltip (and its hover glow). The wedge
     buttons no longer take the mouse (builder's calls, below). Leaving the disc or entering the hub
     clears it.
   - **Click** (secure, must work in combat): one secure *catcher* button per ring, covering the disc
     (the wedge buttons above it are mouse-off). Its wrapped pre-click snippet reads the cursor with the restricted
     `self:GetMousePosition()`, works out the slice from the ring's size and start (attributes written
     out of combat by `DS.Load` through SendEngine, like every other), and returns a per-slice button
     name (`"w3"`); the catcher's `type-w3 = "click"` / `clickbutton-w3 = <wedge 3's button>`
     forwards the click to that wedge, whose own wrap and SendEngine hooks then run unchanged (the
     wedge pre-snippet accepts `w%d` as a left click). An empty place or the hub area does nothing.
     Snippets still never write an attribute.
   - **Risk**: restricted `GetMousePosition` is the C7 item the go/no-go record never verified in
     game. The headless mock gets the API; the smoke tests get an in-combat check. If it fails in game
     the fallback is forwarding tiles (several `type=click` rectangles per slice approximating the
     wedge); not built unless needed.

5. **Centre piece (owner: all four styles, a setting; default "Solid circle").** The red X goes. The
   hub is two layers: a **Backdrop** disc and a **Circle** mark. A new *Hub* heading (on the Slices
   tab, after Highlight; builder may give it its own tab if the Slices tab gets too long — flag it)
   with:
   - *Hub style*: Solid circle (default: a filled circle the size of the hollow ring), Hollow ring,
     Target (ring + centre dot), Rimmed disc (backdrop with its own rim, filled circle inside).
   - *Hub size* (the backdrop's diameter; default today's 40) and *Circle size* (default 22).
   - Backdrop: color + class color, opacity (the color's alpha), border size + border color + class
     color (border used by Rimmed disc, available to all).
   - Circle: color + class color, opacity, line width (ring styles).
   Hub size feeds the geometry that uses `DL.HUB` today (dead zone, pointer reach, hit areas, slice
   gap start). Hover: the circle brightens (the hub is clickable: up a ring, or close). The stale,
   lockdown and test labels stay where they are.

6. **Group labels tab; Labels → Slice labels.** The ring title above the dial ("World (solo)",
   "Comms Dial") gets its own tab, *Group labels*, after *Slice labels* (the renamed *Labels* tab;
   UI rename only, `dial.label.*` paths kept): *Show group labels* (default on) and the composed Font
   block (font, size, color + class color, outline flags, shadow), grayed out while off, as the slice
   labels' block. New leaves under a top-level `dial.title` table (defaults `DialTitle` in
   `defaults/PadStyle.lua`), defaulting to today's look (GameFontNormal, gold). Geometry: the title
   sits above the N label as now, measured with its own line height.

7. **Icon offset moves Wheel → Icons.** `dial.iconOffset` keeps its path; only its row moves to the
   dial's Icons tab (first under its own heading or with Size; builder's call).

8. **Icon size up to 128 (dial).** `D.SIZE.dial.max` 40 → 128. The answer to the owner: Blizzard
   icons are 64×64 art, so past 64 they are upscaled (softer, not broken); catalog glyphs scale the
   same way. At the default ring radius 100 icons past ~70 px crowd their neighbours and the rim; at
   128 a ring wants radius ~180. No auto-scaling: the owner wants to play with it. (Pads unchanged;
   say so.)

9. **Page renames.** The settings pages *Comms Pad* → *Pad*, *Comms Dial* → *Dial* (page titles
   only; the default member names "Comms Pad"/"Comms Dial", the share kind names and the ring-of-groups
   title stay).

10. **Click outside closes the dial (owner: yes, even though world clicks are blocked while open).**
    A full-screen secure catcher, a child of the header anchored to UIParent, below the dial's
    frames, shown while the dial is open from its key (not in the insecure test/preview open, so the
    settings window stays usable). Its wrapped click (left or right, any button) runs `qc-close`.
    While the dial is open, clicks outside it close it and do nothing else.

11. **Pad header reads "Quick Comms: <situation>"** ("Quick Comms: World", "Quick Comms: M+ ·
    Windrunner Spire +14"), via a locale string `"Quick Comms: %s"` around `R.SituationText`.

## Non-goals

- No hold/flick/release dial (C7 proper); only the restricted mouse read for clicks.
- No new icon size range for pads; no auto-fitting of large icons.
- No change to pinned battleground rings, key bindings, or the Paging tab.

## Anti-goals

- A dial that misbehaves in combat (every click path here must be secure-clean, tested in the mock
  under combat lockdown).
- A highlight that says one slice while a click sends another (tracker and catcher use the same math).
- Settings pages that lose what users saved (renames are UI only; removed rows migrate cleanly).

## Builder's calls (made here, owner may override)

- "Solid circle" and the mockup's "Solid dot" are one style; the dot is just a smaller Circle size.
- Exploded-pie gap; Hub heading on the Slices tab; dial-only icon size change.
- Fixed counts now start at W (needed for "fill W/E").
- Wedge buttons stop taking the mouse (`EnableMouse(false)`, set out of combat); `DL.HitSize` and the
  wedges' hit insets retire. Every mouse click goes through the ring's catcher and every hover comes
  from the tracker, so one function decides the slice. The number keys still click wedges by name.
- A point in a gap (the strips between exploded slices, or between the hub and a slice's moved-out
  tip) belongs to the slice whose angle it is in: angle-only, the same as `Slices.Track` today, so
  neither the tracker nor the catcher snippet needs the gap.

## Owner answers (2026-10-21)

- Auto always fits icons (owner): the icon-fit cap on Auto's per-page count applies with gap 0 too,
  so large icons make Auto page sooner (128 px at radius 100: about 4 per page). At today's defaults
  nothing changes.

## Verification

Green gate (`lua tests/run.lua`, `luacheck .` 0/0) with tests for: placement table for 1–4 items on
Auto and fixed 4, 5+ clockwise from W, fixed 8 with 2 items; gap geometry and Auto's gap cap; the
catcher's slice math (same function as the tracker) and its forward in combat; outside-click close;
hub style paints; tab and page renames; pad header text; removed border rows migrating. Docs
(ARCHITECTURE, schema, settings-panel, smoke-tests, test-cases, README badge) in the same change.
Smoke tests added for each item, with an in-combat check of item 4's click and item 10.
