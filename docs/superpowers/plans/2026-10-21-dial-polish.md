# Dial Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The 11 owner items of the dial polish spec: slice placement, slice gap, select-to-the-hub, hub styles, group labels, outside-click close, icon moves and size, renames, pad header text; Slices → Border removed.

**Architecture:** Pure geometry in `modules/Dial_Layout.lua` (placement, gap shift, Auto's icon-fit cap, the one slice-at-a-point function); insecure drawing in `modules/Dial_Slices.lua` / `modules/Dial_Render.lua`; secure frames only through `modules/SendEngine.lua`, snippets in `modules/Dial_Secure.lua` (they read attributes, never write them); settings as member rows in `settings/SchemaMembers.lua` with defaults in `defaults/PadStyle.lua`.

**Tech Stack:** Lua 5.1 (WoW), Ace3, LibKa0s, headless harness `tests/run.lua` with `tests/wow_mock.lua`, luacheck.

**Spec:** `docs/superpowers/specs/2026-10-21-dial-polish-design.md` (read it beside this plan; item numbers below are the spec's).

## Status ledger (resume here)

Each task ends in one commit whose subject starts with `Dial polish T<n>:`. To resume, `git log --oneline master..` and tick what is committed.

- [x] T1 Layout: placement, gap shift, Auto icon-fit cap, SliceAt
- [x] T2 Slices: border out, gap in, migration step 9
- [x] T3 Select to the hub: tracker hover, ring catcher, mouse-off wedges
- [x] T4 Click outside closes
- [x] T5 Hub styles
- [x] T6 Labels: Group labels tab, Slice labels rename, Icon offset to Icons, icon size 128
- [ ] T7 Renames: Pad / Dial pages, pad header "Quick Comms: <situation>"
- [ ] T8 Docs, diagnostics, smoke tests, final gate — push branch

## Global Constraints

- Green gate before every commit: `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` (0 failed) and `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0 warnings / 0 errors). Never run either unbounded.
- Files are CRLF on disk (`.gitattributes`); after any tool that writes LF (Python, sed heredocs), restore CRLF (`sed -i 's/\r\?$/\r/' <file>`). The `eol` test catches misses.
- Never edit `libs/` or `tests/_kit/`. Never bump the version. Commit on `feat/2026-10-21-dial-polish` only; no merge.
- Only `modules/SendEngine.lua` creates `Secure*` frames, calls `SetAttribute`, `SetFrameRef`, `WrapScript` (`tests/test_sendengine.lua` firewall grep). Snippets never write an attribute (`tests/test_dial_secure.lua` firewall case).
- Every user-visible string through `L[...]` with an entry in `locales/enUS.lua`.
- Every new test carries a `-- red under: <the change that breaks it>` line, as the suites do.
- Comment and naming style: match the surrounding file (dense explanatory header comments, `---` doc lines on public functions).
- A deviation from the Ka0s standard: stop and report it, do not work around it (CLAUDE.md).

## Review Focus

1. A saved profile holding `dial.slice.borderSize/borderColor/useClassColorBorder` loads and rebuilds clean (T2 test `migrate: step 9 drops the retired slice border`).
2. Clicking in combat on a slice, in a gap, on an empty place, on the hub: sends exactly the lit slice / nothing / nothing / hub action (T3 tests under `m.inCombat = true`).
3. An insecure open (test mode, Preview as…) with the settings window open: an outside click does nothing (T4 test `display open shows no screen catcher`).
4. Hub size changed: pointer reach, dead zone, tracker inner edge and catcher inner edge all follow it (T5 test `hub size moves the inner edge everywhere`).
5. Icon size 128 at radius 100 on Auto pages at the cap and the number keys still reach items 1–8 of each page (T1 test `auto cap at 128 px`, T3 test `keys still click by name`).

---

### Task 1: Layout — placement, gap shift, Auto icon-fit cap, SliceAt

**Files:**
- Modify: `modules/Dial_Layout.lua` (header comment's WEDGE COUNT paragraph, `PageShape`, `PageSize`, `Rings`'s `pagesOf`; new functions below)
- Modify: `modules/Surfaces.lua:197,267` (pass `fit` to `DL.Rings`)
- Test: `tests/test_dial_layout.lua`

**Interfaces:**
- Produces:
  - `DL.START = 270` — every unpinned page's place 1 sits at W (fixed counts included).
  - `DL.PageShape(slices, pageSize, count) -> size, start, places` — `places[i]` is item i's place (1-based, clockwise from `start`). Auto: count 1 → size 1; 2 → size 2; 3 → size 4, places {1,2,3}; 4 → size 4; ≥5 → size count; places 1..count except as given. Fixed n: size n; if n == 4 places by count: 1→{1}, 2→{1,3}, 3→{1,2,3}, 4→{1,2,3,4}; n ≥ 5 → {1..count}. Start always `DL.START`.
  - `Rings` sets `item.wedge = places[i]` on unpinned items (pinned rings untouched, start 0, size 8).
  - `DL.SliceShift(gap, n) -> number` — `0` when `n <= 1` or `gap <= 0`, else `(gap / 2) / math.sin(math.pi / n)`.
  - `DL.FIT_MARGIN = 4`; `DL.AutoCap(radius, at, iconSize, gap) -> integer` — the largest n in 1..`DL.MAX_SLICES` with `2 * math.pi * IconReach(radius, at) / n - gap >= iconSize + DL.FIT_MARGIN`, else 1.
  - `DL.PageSize(slices, hasChildren, cap)` — under Auto `math.min(hasChildren and DL.KEYS or DL.MAX_SLICES, cap or DL.MAX_SLICES)`; fixed unchanged.
  - `DL.Rings(groups, opts)` — `opts.fit = { radius, iconOffset, iconSize, gap }` (nil: no cap).
  - `DL.SliceAt(angle, dist, size, start, hub, disc) -> j|nil` — slice index holding bearing `angle` (radians clockwise from N) when `hub / 2 < dist <= disc / 2`, else nil. Body = the math now inside `Slices.Track` (`step = 2π/size; from = rad(start) − step/2; j = floor(((angle − from) % 2π) / step) + 1`). No `used` check here (callers check).
- Consumes: nothing new.

- [ ] **Step 1: Write the failing tests** in `tests/test_dial_layout.lua`:
  - `dial layout: [polish] fixed 4 places 1-4 items W; W,E; W,N,E; W,N,E,S` — for count 1..4 assert `select(3, DL.PageShape(4, 4, count))` equals `{1}`, `{1,3}`, `{1,2,3}`, `{1,2,3,4}` and size 4, start 270; and `DL.Direction(places[k], 4, 270)` gives `"W"`, then `"W","E"`, `"W","N","E"`, `"W","N","E","S"`.
  - `dial layout: [polish] auto keeps its shapes from W` — Auto count 1→size 1; 2→size 2 directions W,E; 3→size 4 places {1,2,3}; 5→size 5 places 1..5, start 270.
  - `dial layout: [polish] fixed 8 with 2 items fills W then clockwise` — size 8, places {1,2}, directions `"W","NW"`.
  - `dial layout: [polish] slice shift` — `SliceShift(0, 4) == 0`, `SliceShift(10, 1) == 0`, `SliceShift(10, 2) == 5`, `SliceShift(10, 4)` ≈ `5 / math.sin(math.pi/4)` (±0.01).
  - `dial layout: [polish] auto cap` — `AutoCap(100, 0, 32, 0) == 12`; `AutoCap(100, 0, 128, 0) == 4`; `AutoCap(100, 0, 32, 20)` == largest n with `2π·100/n − 20 ≥ 36` (= 11); `AutoCap(70, 0, 128, 20) == 2`; `AutoCap(70, 0, 128, 300) == 1` (floor at 1).
  - `dial layout: [polish] auto cap at 128 px pages the ring` — `DL.Rings` of one group with 9 callouts, `{ slices = 0, fit = { radius = 100, iconOffset = 0, iconSize = 128, gap = 0 } }` gives 3 pages of sizes 4,4,1-item (third page shape size 1).
  - `dial layout: [polish] SliceAt` — size 4 start 270, hub 40, disc 300: bearing W (3π/2) at dist 30 → 1; N (0) → 2; E → 3; dist 15 → nil; dist 151 → nil; bearing just past the W/N boundary (7π/4 + 0.01) → 2.
  - Update existing cases that asserted fixed rings start at N (`start == 0`) to `270`, each with its `-- red under` line kept.
- [ ] **Step 2: Run** the bounded harness; expect the new cases FAIL.
- [ ] **Step 3: Implement** the Interfaces above in `modules/Dial_Layout.lua`; rewrite the header's WEDGE COUNT paragraph to the new rule. `Surfaces.lua` passes `fit = { radius = dial.radius, iconOffset = dial.iconOffset, iconSize = (dial.icon or {}).size or NS.IconStyle size default for "dial", gap = (dial.slice or {}).gap or 0 }` at both `DL.Rings` call sites (use the same default source `defaults/Icons.lua` `D.SIZE.dial.default`).
- [ ] **Step 4: Run** the gate; all pass (fix older dial tests whose expectations encoded N-start; never weaken an assertion).
- [ ] **Step 5: Commit** `Dial polish T1: one placement rule from W, slice shift, Auto icon-fit cap, SliceAt`.

### Task 2: Slices — border out, gap in, migration step 9

**Files:**
- Modify: `modules/Dial_Slices.lua` (drop `paintBorder`, spokes, rim, `qcSpokes`/`qcRim`; fills and highlight shifted by the gap; `Track` calls `DL.SliceAt`)
- Modify: `modules/Dial_Render.lua` `R.Look` (drop `borderSize`/`border`; add `gap`)
- Modify: `settings/SchemaMembers.lua` `sliceRows` (drop Border rows; add `dial.slice.gap`)
- Modify: `defaults/PadStyle.lua` `D.DialSlice` (drop the three border leaves; `gap = 0`)
- Modify: `modules/Library_Migrate.lua` (step 9), `core/Database.lua` `NS.MIGRATIONS` (append `{ to = 9, ... }` following step 8's shape)
- Modify: `locales/enUS.lua` (drop dead strings, add new)
- Test: `tests/test_dial.lua` (or the slices tests' current home — grep `qcSpokes`), `tests/test_library.lua` or wherever step 8 is tested (grep `MigrateDialFields`), `tests/test_page_dials.lua`

**Interfaces:**
- Consumes: `DL.SliceShift`, `DL.SliceAt` (T1).
- Produces: `look.gap` (number ≥ 0) on `R.Look`'s result; row `dial.slice.gap` (number, 0–20, step 1, default 0, Slices tab, subgroup `L["Gap"]`, label `L["Slice gap"]`, desc `L["The space between slices, in pixels. 0 draws them touching."]`); `Lib.MigrateSliceBorder(profile)` dropping `borderSize`, `borderColor`, `useClassColorBorder` from every `profile.dials[*].slice`.

- [ ] **Step 1: Failing tests:**
  - `dial slices: [polish] no border lines are drawn` — after a rebuild, the ring has no `qcSpokes`/`qcRim` textures shown (red under: paintBorder kept).
  - `dial slices: [polish] a gap shifts each fill outward along its bisector` — `dial.slice.gap = 10`, 4-slice ring: fill j's anchor offset equals `(d·sin a, d·cos a)` with `d = DL.SliceShift(10, 4)` and `a` its middle; its size `2 * (R − d)` with `R` = disc/2; the highlight takes the lit slice's offset.
  - `dial slices: [polish] gap 0 draws as before` — offsets 0, size = disc.
  - `migrate: step 9 drops the retired slice border` — a stored dial with the three leaves loses them; others kept; idempotent on a second run.
  - `page dials: [polish] Slices tab has Slice gap and no Border heading`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** Fill j: `SetPoint("CENTER", ring, "CENTER", d*sin(a), d*cos(a))`, `SetSize(2*(R-d), 2*(R-d))`. `S.Track` → `DL.SliceAt(angle, dist, shape.size, shape.start, DL.HUB, shape.disc)` then the `used` check (T5 swaps `DL.HUB` for the hub size). Migration step 9 mirrors step 8's style and wiring.
- [ ] **Step 4: Run** the gate.
- [ ] **Step 5: Commit** `Dial polish T2: slice border removed, slice gap, migration step 9`.

### Task 3: Select to the hub — tracker hover, ring catcher, mouse-off wedges

**Files:**
- Modify: `tests/wow_mock.lua` — restricted handle `GetMousePosition()` (returns `(cursor.x − left)/width, (cursor.y − bottom)/height` from `M.cursor` and the frame's mock rect, nil when outside); `secureOnClick` honors `type = "click"`: resolves the modified attribute with the button suffix (`type-<button>` / `clickbutton-<button>` for a non-standard button name, falling back to plain `type`/`clickbutton`) and calls `delegate:Click(button)`; a `Click(button)` method on secure buttons running OnClick down/up as registered. Add `tests/test_mock_secure.lua` cases for each.
- Modify: `modules/SendEngine.lua` — `SE.NewDialCatcher(header, ring) -> Button` (SecureActionButtonTemplate, child of `ring`, `RegisterForClicks("AnyUp")`, wrapped by `header` with the catcher snippet; frame level just under the ring's wedges).
- Modify: `modules/Dial_Secure.lua` — `CATCHER_PRE` snippet; `WEDGE_PRE` accepts `button:match("^w%d+$")` as a left click (`return "LeftButton", "sent"`); `DS.NewCatcher(header, ring)`; `DS.Load` writes per ring on the catcher: `qc-size`, `qc-start`, `qc-hub`, `qc-disc`, and per place j: `type-w<j> = "click"`, `clickbutton-w<j> = <wedge button>` for used places, `type-w<j> = nil` for empty ones (through SendEngine).
- Modify: `modules/Dial.lua` — `newRing` makes the catcher (sized to the disc in `Apply`); `placeWedges` drops `DL.HitSize` and `SetHitRectInsets`, calls `w:EnableMouse(false)` (out of combat, under Apply) and records `ring.qcPlaceWedge[place] = w`.
- Modify: `modules/Dial_Render.lua` / `modules/Dial_Slices.lua` — when `Slices.Track`'s lit slice changes, call `R.HoverWedge(ring, old, new)`: OnLeave work for the old wedge (tooltip hide, `Glow` hover off), OnEnter work for the new (its `R.ShowTip` lines, `Glow` hover on). Move the wedge's existing OnEnter/OnLeave bodies into those functions.
- Modify: `modules/Dial_Layout.lua` — delete `DL.HitSize` and its tests.
- Test: `tests/test_dial_secure.lua`, `tests/test_dial.lua`, `tests/test_mock_secure.lua`

**Catcher snippet (restricted Lua; the algorithm is pinned because the tests compare it to `DL.SliceAt`):**
```lua
if down then return false end
if button ~= "LeftButton" then owner:RunAttribute("qc-close") return false end
local x, y = self:GetMousePosition()
if not x then return false end
local disc = self:GetAttribute("qc-disc") or 0
local dx, dy = (x - 0.5) * disc, (y - 0.5) * disc
local dist = math.sqrt(dx * dx + dy * dy)
if dist <= (self:GetAttribute("qc-hub") or 0) / 2 or dist > disc / 2 then return false end
local size = self:GetAttribute("qc-size") or 1
local step = 2 * math.pi / size
local from = math.rad(self:GetAttribute("qc-start") or 0) - step / 2
local j = math.floor(((math.atan2(dx, dy) - from) % (2 * math.pi)) / step) + 1
if not self:GetAttribute("type-w" .. j) then return false end
return "w" .. j
```
(A click inside the hub radius never reaches the catcher in game — the header is above it — but the snippet refuses it anyway.)

- [ ] **Step 1: Failing tests:**
  - `mock secure: GetMousePosition reads the cursor inside a frame, nil outside`.
  - `mock secure: type click forwards to clickbutton-<button>`.
  - `dial secure: [polish] catcher and SliceAt agree` — for a 4- and an 8-slice ring, sweep 72 bearings × 3 radii (just outside hub, middle, just inside disc): running the catcher snippet (via `m.__runSnippet` or a click with `m.cursor` set) yields `"w"..j` exactly when `DL.SliceAt(...)` gives a used j; nil otherwise.
  - `dial: [polish] a click near the hub sends the lit slice, in combat` — fixed 4 with 2 groups' callout ring, `m.inCombat = true`, cursor 25 px east of center: click the catcher → one `m.sentMacros` entry for the E item; the dial closes.
  - `dial: [polish] a click on an empty place or in the hub sends nothing`.
  - `dial: [polish] hovering anywhere in a slice shows its tooltip` — cursor moved into the slice 25 px out, run the pointer update: `GameTooltip` owner is that wedge and shows its title; moving into the hub hides it.
  - `dial: [polish] wedges take no mouse; keys still click by name` — every wedge `IsMouseEnabled() == false`; `m.__pressKey("1")` with the dial open from its key sends item 1.
- [ ] **Step 2: Run**; FAIL.
- [ ] **Step 3: Implement** per Files.
- [ ] **Step 4: Run** the gate (firewall greps must stay green).
- [ ] **Step 5: Commit** `Dial polish T3: every point of a slice hovers and clicks it, to the hub, in combat`.

### Task 4: Click outside closes

**Files:**
- Modify: `modules/SendEngine.lua` — `SE.NewDialScreen(header) -> Button`: SecureActionButtonTemplate child of `header`, `SetAllPoints(UIParent)`, `RegisterForClicks("AnyUp")`, frame level below the rings (`header:GetFrameLevel()` − 1 floor 0, or strata one lower — implementer picks what the mock and the client both honor; document it), hidden, wrapped: `if down then return false end owner:RunAttribute("qc-close") return false`.
- Modify: `modules/Dial_Secure.lua` — header frame ref `screen`; `SHOW` shows it when `not display`, hides it when `display`; `CLOSE` hides it. `DS.NewHeader` stays as is; `Dial.build` makes the screen and `DS.Load` sets the ref.
- Test: `tests/test_dial_secure.lua`

- [ ] **Step 1: Failing tests:** `dial secure: [polish] an outside click closes a key-opened dial, in combat` (left and right buttons); `dial secure: [polish] display open shows no screen catcher`; `dial secure: [polish] closing hides the screen catcher`.
- [ ] **Step 2–4:** run (FAIL), implement, gate green.
- [ ] **Step 5: Commit** `Dial polish T4: a click outside the open dial closes it`.

### Task 5: Hub styles

**Files:**
- Modify: `defaults/PadStyle.lua` — `D.DialHub()`: `style = "solid"`, `size = 40`, `circleSize = 22`, `lineWidth = 2`, `background = { r = 0.12, g = 0.12, b = 0.14, a = 0.95 }`, `useClassColorBackground = false`, `borderSize = 0`, `borderColor = { r = 1, g = 0.82, b = 0, a = 1 }`, `useClassColorBorder = false`, `circleColor = { r = 1, g = 0.82, b = 0, a = 1 }`, `useClassColorCircle = false`. Wire into the dial member template the way `DialSlice` is (top-level `hub` table, `fillShape` backfill).
- Modify: `settings/SchemaMembers.lua` — `hubRows()` spliced after the Slices rows' Highlight block, group Slices, subgroup `L["Hub"]`: `dial.hub.style` (values solid/ring/target/rimmed → `L["Solid circle"]`, `L["Hollow ring"]`, `L["Target"]`, `L["Rimmed disc"]`), `dial.hub.size` (24–80), `dial.hub.circleSize` (4–60), `dial.hub.lineWidth` (1–6, disabled for solid), backdrop ColorPair `background`, `borderSize` (0–6), border ColorPair `borderColor`, circle ColorPair `circleColor`. Opacity is the color's alpha (the swatches carry alpha, as every other color row).
- Modify: `modules/Dial_Render.lua` — `R.Look` gains `hub = { style, size, circleSize, lineWidth, background, borderSize, border, circle }`; `R.DressHub` drops `qcClose`, builds `qcHub` (backdrop), `qcHubRim` and `qcHubRing` (each a pool of `DL.ARC` segments, drawn as the old rim was), `qcHubDot`; `R.PaintHubLook(header, look)` draws per style: solid = dot of `circleSize`; ring = ring of `circleSize`/`lineWidth`; target = ring + dot of `max(4, circleSize/4)`; rimmed = rim on the backdrop at `max(borderSize, 2)` + dot of `circleSize`; any style draws the backdrop rim when `borderSize > 0`. Header OnEnter/OnLeave brighten the circle (alpha × 1.0 vs × 0.8 resting, builder may tune).
- Modify: every `DL.HUB` use that means the drawn hub (`Dial.build`'s `SetSize` → in `Apply` from `look.hub.size`; `DL.PointerReach(size, hub)`; `DL.Pointer` dead zone stays `DL.DEAD`; `Slices.Track` and `DS.Load`'s `qc-hub` use `look.hub.size`).
- Modify: `locales/enUS.lua`.
- Test: `tests/test_dial.lua`, `tests/test_page_dials.lua`

- [ ] **Step 1: Failing tests:** `dial: [polish] default hub is a solid gold circle of 22 on a 40 backdrop, no red X`; one case per style asserting which regions show and their sizes; `dial: [polish] hub size moves the inner edge everywhere` (hub 60: header 60×60, `qc-hub` 60, tracker gives nil at dist 29 and a slice at 31, pointer reach > 30); `page dials: [polish] Hub heading rows on the Slices tab`.
- [ ] **Step 2–4:** run (FAIL), implement, gate green.
- [ ] **Step 5: Commit** `Dial polish T5: hub styles with backdrop and circle settings`.

### Task 6: Labels and icons

**Files:**
- Modify: `defaults/PadStyle.lua` — `D.DialTitle()`: `show = true`, `font = "Friz Quadrata TT"`, `fontSize = 12`, `fontColor = { r = 1, g = 0.82, b = 0, a = 1 }`, `useClassColorFont = false`, `fontFlags = ""`, `fontShadow = true` (matches today's GameFontNormal title); dial member template gets top-level `title`.
- Modify: `settings/SchemaMembers.lua` — `LABELS` → `L["Slice labels"]` (paths unchanged); new `titleRows()` group `L["Group labels"]` after the slice label rows: `dial.title.show` (`L["Show group labels"]`, desc `L["Write the ring's name above the dial."]`), then the composed Font block disabled while off; move `dial.iconOffset`'s row into the dial Icons rows (group `L["Icons"]`, first row under Size and crop, path kept).
- Modify: `defaults/Icons.lua` — `D.SIZE.dial.max = 128`.
- Modify: `settings/Dials.lua` — header comment's tab strip and tab list (`Slices`, `Paging`, `Slice labels`, `Group labels`, `Icons`); the Wheel tab no longer lists Icon offset.
- Modify: `modules/Dial_Render.lua` — `R.Look` gains `title = { show, font, line }`; `R.PaintRing` applies the title font and hides it when off; `DL.Geometry` takes the title's line height (new optional 4th param `titleLine`, default `DL.LINE`) so the title sits clear of the N label.
- Modify: `locales/enUS.lua`.
- Test: `tests/test_page_dials.lua`, `tests/test_dial.lua`, `tests/test_icon_style.lua` (size range)

- [ ] **Step 1: Failing tests:** `page dials: [polish] tabs read Slices, Paging, Slice labels, Group labels, Icons`; `page dials: [polish] Icon offset is on the Icons tab, not Wheel`; `dial: [polish] group labels take their font and hide when off`; `icon style: [polish] dial icon size reaches 128, pad stays 40`.
- [ ] **Step 2–4:** run (FAIL), implement, gate green.
- [ ] **Step 5: Commit** `Dial polish T6: Group labels tab, Slice labels, Icon offset on Icons, dial icons to 128`.

### Task 7: Renames and pad header

**Files:**
- Modify: `settings/Pads.lua:281` → `L["Pad"]`; `settings/Dials.lua:307` → `L["Dial"]` (page titles only; member default names, share kind names, ring-of-groups title unchanged).
- Modify: `modules/Pad.lua` / `modules/Pad_Render.lua` — the header's situation text becomes `L["Quick Comms: %s"]:format(R.SituationText(...))` at the one place the header text is set.
- Modify: `locales/enUS.lua`.
- Test: `tests/test_page_pads.lua`, `tests/test_page_dials.lua`, `tests/test_pad_render.lua` or `tests/test_pad.lua` (wherever the header text is asserted)

- [ ] **Step 1: Failing tests:** `page pads: [polish] the page is titled Pad`; `page dials: [polish] the page is titled Dial`; `pad: [polish] header reads Quick Comms: World` and `Quick Comms: M+ · Windrunner Spire +14`. Update existing header-text assertions.
- [ ] **Step 2–4:** run (FAIL), implement, gate green.
- [ ] **Step 5: Commit** `Dial polish T7: Pad and Dial pages, pad header reads Quick Comms: <situation>`.

### Task 8: Docs, diagnostics, smoke tests, final gate

**Files:**
- Modify: `modules/Diagnostics.lua` `dialLook` — replace `border=` with `gap=`; add a `hub` line (`style size circle line border`) and the title `show`; update `tests/test_diagnostics.lua`'s expected strings.
- Modify docs: `docs/ARCHITECTURE.md` (settings schema paragraph: border retired, gap, hub, title, Slice/Group labels, Icon offset on Icons, icon size 128; secure paragraph: catcher, screen catcher, mouse-off wedges, `HitSize` retired; schema step 9), `docs/schema.md`, `docs/settings-panel.md`, `docs/debug.md` (diagnostics fields), `docs/module-map.md` (if function lists change), `docs/test-cases.md` (every new/renamed case, per-file counts, Total), `README.md` badge = Total, `docs/smoke-tests.md` (one case per spec item; item 4 and 10 checked in combat; the Pad/Dial page names and header text where older cases quote them).
- Test: whole suite.

- [ ] **Step 1:** update diagnostics + its test; run (FAIL first, then implement, PASS).
- [ ] **Step 2:** docs sweep: `grep -rn "Comms Pad page\|Comms Dial page\|Border size\|borderSize\|Labels tab\|HitSize\|Icon offset" docs README.md` (excluding `docs/audits docs/reviews docs/automated-tests docs/brainstorm docs/superpowers`) and fix each hit that this batch made stale.
- [ ] **Step 3:** full gate green; `test-cases.md` Total == harness pass count == README badge.
- [ ] **Step 4: Commit** `Dial polish T8: docs, diagnostics and smoke tests` and `git push -u origin feat/2026-10-21-dial-polish`.
