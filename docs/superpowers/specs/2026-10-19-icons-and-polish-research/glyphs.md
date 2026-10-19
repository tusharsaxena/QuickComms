# Glyph pipeline scout: LibKa0s Media and the Quick Comms (QC) icon browser

## Corrections to the brief

- **The current icon count is 113, not 114.** LibKa0s ships 113 names, from 112 distinct Open Iconic glyphs (`add` and `expand` both use `plus`). The 114th file in `LibKa0s/media/icons/` is `LICENSE-open-iconic.txt`. The cache `tools/artwork/.cache/` holds all 223 upstream PNGs, so **111 Open Iconic glyphs are still missing**. None of their upstream names collides with an existing semantic key, so they can be added under their upstream names. The list was computed from the `GLYPHS` map and the cache: audio, audio-spectrum, badge, … , wifi, yen.
- **`resvg_py` is not installed.** `import resvg_py` raises `ModuleNotFoundError`. Pillow and numpy are installed.

## 1. `tools/artwork/icon_cleaner.py` (467 lines)

- **Source and fetch:** `REPO = "iconic/open-iconic"`, `SUFFIX = "-8x"`. The 8px base icon times 8 gives the 64px render. Fetching is one `gh api repos/.../contents/png/<name>-8x.png` call per file (`_gh_file`), with base64 inside JSON. The tool says it chose Open Iconic because "this machine has no rasteriser", which resvg now changes.
- **`GLYPHS`:** a dict from semantic key to upstream name. 38 entries are aliases, for example `minimise→minus`, `clear→trash`, `chevron-up→chevron-top`. The comments say a semantic key exists so the upstream glyph behind it can be swapped in one line.
- **Pipeline (`convert_one`):**
  1. `recolor_white`: RGB set to 255, alpha untouched.
  2. `solidify`: 3 iterations.
  3. `fit_square`: centers on a 64×64 canvas, using Lanczos when resizing, never crops.
  4. `normalize_transparent`: fully transparent pixels become `(0,0,0,0)`.
  5. Save with `compression="tga_rle"`.
- **Output:** `OUT = ROOT/LibKa0s/media/icons/<semantic>.tga`, flat. `LICENSE_SRC="ICON-LICENSE"` is copied to `OUT/LICENSE-open-iconic.txt`.
- **CLI:** `--fetch`, `--build`, or both. The cache is gitignored (`.gitignore`, "tools/artwork/.cache/").
- **What a new set needs:** an SVG stage that runs `resvg_py.svg_to_bytes(svg_string=..., width=64, height=64)`, then feeds PIL into the same `recolor_white → … → tga_rle` chain.
  - `fit_square` passes a 64px render through untouched.
  - Fetch with a shallow `git clone` or a tarball, not 5,500 `gh api` calls.
- **Game-icons background:** each SVG is `<path d="M0 0h512v512H0z"/>` followed by a white path. Two ways to remove it:
  - (a) Strip that first path with a regex, then assert that the corner pixel's alpha is 0 after rendering.
  - (b) More robust: render, then set alpha to the luminance. The art is white on black, and `recolor_white` sets RGB anyway.
- **Phosphor:** drop `*-logo`.
- **Game-icons author:** the subfolder name is the author. Record it per icon, since CC BY needs it.

## 2. `LibKa0s/Media.lua` (327 lines, `MINOR = 4`, line 56)

- **`lib.ICONS`** (`:92-137`) is a flat array of names. `KNOWN_ICON` is a set built from it (`:178-179`).
- **`lib.Icon(addonName, name, vendorPath)`** (`:202-207`) returns nil unless the name is in `KNOWN_ICON`. Otherwise it returns `root .. "media\\icons" .. "\\" .. name`, extensionless. **The name is the file basename**, so a subfolder cannot be reached today.
- `ICON_DIR` is at `:73`. The white-art contract is at `:84-87`. `MODULES.Media` is set at `:65`.

**Hard constraints from consumers:**

- The 113 existing keys and paths must not move. QC stores the **full texture path** as the member icon value, in SavedVariables and in share strings. `Lib.IsGlyph` maps path to name.
- Every consumer calls `Icon(addonName, "close")` and similar names.
- The `minimise` key is pinned by a register row in LibKa0s's `CLAUDE.md`.

**Recommended catalog design:**

- Keep `lib.ICONS` as the single enumerable list of every name, so QC's `NS.IconNames`, `IsGlyph` and the browser keep working unchanged. Existing names stay unprefixed and in the flat directory.
- Add new sets under a prefix that maps to a subfolder: `ph:star` resolves to `media\icons\phosphor\star`, `gi:sword` to `media\icons\game-icons\sword`.
  - The prefix is required because Phosphor reuses names such as star, heart and bug.
  - `:` cannot occur in an Open Iconic name, so the split is unambiguous.
- Publish `lib.ICON_SETS = { {id="open-iconic", prefix="", dir="", license="LICENSE-open-iconic.txt"}, {id="phosphor", prefix="ph:", dir="phosphor", ...}, {id="game-icons", prefix="gi:", dir="game-icons", ...} }`. Consumers can then filter by set.
- The extra Open Iconic glyphs go in flat and unprefixed, under their upstream names.
- `Icon()` resolves the prefix and directory through a table lookup, still gated by `KNOWN_ICON`.

**Where the generated list lives:** about 5,600 names will not fit in `Media.lua`.

- `layout-§1` caps every shipping `.lua` at 1,500 lines. The generated-data exemption covers *non-shipping* data only.
- `max_line_length = false` in `.luacheckrc`, so either pack about 8 names per line, or use one long string per set split with `gmatch` at load.
- A new file such as `MediaIcons.lua`, written by `icon_cleaner.py`, changes the major's shape:
  - a row in `LibKa0s.xml` after `Media.lua`;
  - a `paired` entry in the Media row of `tests/majors.lua` (`:57-61`);
  - a new `ICONS_MINOR` constant;
  - a multi-part Media version key, for example `5.1`, per `docs/releasing.md` step 3.
- The simpler alternative is to inline the data in `Media.lua` only if it stays under 1,500 lines, which it will not.

**Spelling gate risk:** `tests/test_prose.lua` scans every shipped `.lua` file for British spellings.

- The scan is non-recursive (comment at `:56-57`), so `media/` itself is not scanned.
- Generated name lists in a `.lua` file **are** scanned. Any British-spelled game-icons name fails the suite.
- The generator should check names against `testkit/prose_lists.lua` and rename or alias any hits. The ASCII gate (`:589-594`) also applies to `.lua` files only.

## 3. LibKa0s tests covering the area

`tests/test_media.lua`:

- **`:34-52`** checks both directions: every name in `ICONS` has `<ICON_DIR>/<name>.tga`, and every `.tga` file has a name. It lists the directory with `ls -A` one level deep, so it skips subdirectories silently. **It must be extended to recurse per set, using the prefix-to-directory map.** Otherwise the new art is unchecked.
- **`:54-60`**: `LICENSE-open-iconic.txt` exists. Needs a case per set license.
- **`:120`**: no duplicate names.
- **`:130-147`**: the path spelling is extensionless, and the file on disk is `<rel>.tga`. Add a case for a prefixed name: its path, its file, and nil for an unknown prefix.

Other places:

- `tests/test_core.lua:88` pins the `close` path.
- `tests/test_versioning.lua` and `tools/gen-api-members.lua` derive `docs/api/Media/version-<key>-docs.md` and `members-<key>.json` from `lib.MODULES`, so a new member such as `ICON_SETS` fails the suite until both are written.
- `testkit/vendor_sync.lua:200-240` (`gitShowMany`) loads every payload blob into one Lua string. At roughly 20MB, measure the gate's runtime in QC.

## 4. Release mechanics (`docs/releasing.md`)

1. Change plus tests, then green: `lua tests/run.lua` and `luacheck .`.
2. Bump the minor of each touched file: `MINOR` in Media to 5, plus the new file's constant.
3. New-file rules (step 3).
4. CHANGELOG version block naming each new minor. `test_versioning` enforces it.
5. API docs: `docs/api/Media/version-<key>-docs.md`, then `lua tools/gen-api-members.lua`. The current doc says "adding a mark is one row in GLYPHS plus a row in ICONS" at `version-4-docs.md:210-213`; that needs rewriting.
6. `lua tests/run.lua --list` into `docs/test-cases.md`, keeping CRLF.
7. Move the provenance template (`releasing.md` "Re-vendoring consumers", currently v1.73.0) and check the README standards pointer (standard is v2.83.0). Commit, then on a clean tree `tests/_kit/run-automated-tests.sh --release <X.Y.Z>`, then the write-up commit and tag `vX.Y.Z`. **No tag without the bundle.**

Re-vendor into QC:

- `cp -r LibKa0s/. QC/libs/LibKa0s/`, plus `tests/_kit/` if the kit moved.
- Run both `diff -r` checks.
- Move the QC `CLAUDE.md` line "Bundles … v1.73.0" in the same commit. `tests/test_vendor_sync.lua` resolves that tag in `../LibKa0s`, so **tag first**.
- Vendoring only QC is fine: provenance is per addon.

## 5. QC consumer

- **`core/MediaSetup.lua:51`:** `NS.IconNames()` returns `Media.ICONS`. `NS.Icon` is at `:16`.
- **`modules/Library.lua:266-281` (`IsGlyph`):** lazily builds a path-to-name map over all of `ICONS`, built once. At 5,700 entries that is about 5,700 path strings of roughly 70 bytes, a few hundred KB. Acceptable.
  - `IconTint` (`:307`) and `glyphColor` (`:327`) call it per draw. Each call is a hash lookup, which is fine.
- **`settings/IconBrowser.lua`:** the grid is **virtualized** (`:30-31`, `B.COLS, B.ROWS = 12, 7` at `:55`). 84 cells are built once and redrawn at the scroll offset (`draw` at `:220-232`, `maxOffset` at `:148`). The game tab already handles about 30k icons, so 5,700 glyphs is not a rendering problem.
- **Confirmed perf bug:** `fill` (`:297-311`) calls `Src.List`, which calls `Src.Glyphs()` (`IconBrowser_Sources.lua:61-68`). That builds a **new table** on every keystroke and tab switch.
  - `Src.Search` memoizes its search text (`textOf[list]`) and its narrow-from-last-result (`last[list]`) **by list identity** (`:159-185`). Both memos miss on every glyph search.
  - Each keystroke therefore recomputes 5,700 `NS.Icon` concatenations and 5,700 `searchText` strings.
  - Fix: cache `Src.Glyphs()`'s result for the session, the way `GameIcons` caches through `cache[key]` (`:109-110`).
- **`Src.GlyphLabel`** (`:48-52`) needs to strip the set prefix: `ph:arrow-up` should read "Arrow up", not "Ph:arrow-up". Optionally append the set name to the label.
  - Search reads key plus label (`searchText` at `:148-154`), so "ph:" queries work.
- **Recommended:** a Glyphs filter (All, Open Iconic, Phosphor, Game-icons) mirroring the game filter (`B.SetFilter` at `:601`), read from `lib.ICON_SETS`, with locale keys for the three set names. `Src.TabFor` (`:129`) stays as it is through `IsGlyph`.
- **QC tests:**
  - `tests/test_icon_browser.lua:209-221` asserts `#names > 100`, `#Src.Glyphs() == #names`, and the count text `#names .. " icons"`. Both are count-agnostic and pass.
  - `:638-645` covers glyph search on `thumb-up` / "Thumbs up".
  - `:271-275` checks no extra cells are built.
  - `tests/test_library.lua:868-873` covers `IsGlyph`.
  - Add: a prefixed glyph's label and its search hit, a filter case, and a case that the list stays the same table across `SetSearch` calls (fails under today's code).
- **QC docs:** the `IconBrowserSources` row in `docs/ARCHITECTURE.md` (`:108`), plus `settings-panel.md`. A README `## Credits` section is allowed for third-party art (documentation-§1 item 12, last section) and is the place for the CC BY credit.

## 6. Size estimate

- Measured: 113 TGAs total 191,577 bytes. Mean 1,695 B, median 1,516 B, min 364 B, max 4,376 B (target, ban). Zipped with `-9` they are 69,306 B, 36% of the original.
- Projected (actual 64×64 RLE size depends on edge density; render a 50-icon sample per set before committing):

| Set | Count | Per icon | Raw | Zipped |
|---|---|---|---|---|
| Open Iconic, the rest | 111 | ~1.7 KB | ~0.19 MB | — |
| Phosphor Fill | ~1,500 | ~1.5–2.5 KB | ~3 MB | ~1.1 MB |
| Game-icons | ~4,000 | ~3–6 KB | ~18 MB | ~6.5 MB |

- Total: about 20–22MB unpacked and about 7–8MB in the zip, per addon.
- **`library-stack-§7` and `§8`: the payload is whole-folder.** Every Ka0s addon that later re-vendors carries all of it, including addons that never draw a glyph.
- Option: render Game-icons at 32×32 for roughly a quarter of the size. The browser draws icons at 32 (`ICON=32`) and the header strip at 18.
- WoW loads textures only on `SetTexture`, so runtime cost is limited to catalog strings.

## 7. Standard and licensing constraints

- **`library-stack-§8`** ("The catalog is the vocabulary"):
  - A missing mark is added **upstream, by the generator that produced the rest**. `icon_cleaner.py` stays the provenance record and must hold the source repo or commit, the filters (`-logo`, background removal) and the author per icon.
  - **Art must ship white**, with the shape in alpha.
  - Callers must treat nil as an answer.
  - Paths are extensionless.
- **Anti-pattern #63:** no private copies in an addon.
- **License files ship beside the art** (pattern at `test_media.lua:54`):
  - `media/icons/phosphor/LICENSE-phosphor.txt` (MIT).
  - `media/icons/game-icons/LICENSE-game-icons.txt`: CC BY 3.0 text, the authors, a link, and **a statement of changes** ("recolored white, background removed, rasterized 64px TGA"). CC BY requires indicating changes.
  - A name-to-author manifest, for example `AUTHORS.txt` in that folder, since attribution is per author.
  - `.txt` files are normalized to CRLF by `* text=auto eol=crlf`. `*.tga` is pinned binary.
- **Credits:** add game-icons credit (Lorc, Delapouite and the other authors) to the LibKa0s README and to QC's README `## Credits` (documentation-§1 item 12). It must not list libraries (anti-pattern #58).
- **Deviation registers:**
  - LibKa0s `docs/api/CONSUMERS.md:176` says "no host reads `lib.ICONS` by name". This is stale, since QC reads it through `NS.IconNames`. Update it when the catalog's contract changes.
  - No new deviation is needed if the generated catalog file stays under 1,500 lines and has no British names.
  - A one-consumer surface such as `ICON_SETS` is plain catalog data, not a promoted widget, so `library-stack-§7`'s promotion bar does not apply.