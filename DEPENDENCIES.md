# Dependencies — Ka0s Quick Comms

What you need installed to build, run, test or release this addon. Commands are for
**WSL2 / Ubuntu** (the collection's development environment). How to *verify* the addon once
you are set up is `docs/testing.md`; this file only covers *what to install*.

Every entry says what needs it and how that is known. Anything only plausibly required is
marked as such rather than listed as a requirement.

## Runtime (in-game) — what a player needs

- **World of Warcraft (Retail).** Single `## Interface: 120105` line in `QuickComms.toc` — Retail
  only.
- **Nothing else.** Every library is vendored under `libs/` and committed (library-stack), so the
  player installs no separate library addon. `## OptionalDeps:` names the vendored libs for load
  ordering, not as things to download.
- **EllesmereUI, optional and never vendored.** `## OptionalDeps:` also names EllesmereUI, an
  optional suite (library-stack-§6), so it loads first when installed. With it, its Blizzard Skin
  module (EllesmereUIBlizzardSkin), its third-party skinning and Quick Comms' entry in its
  Third-Party Addons list all on, the callout popup takes EllesmereUI's look through its public
  skinning API (`EllesmereUI.RegisterSkin`, read against its `SKINNING_API.md`, apiVersion 3).
  Without it the popup keeps Blizzard's settings-window look and nothing else changes.
- **LibCustomGlow-1.0 is vendored too**: `libs/LibCustomGlow-1.0/` (MIT, minor 24, copied whole from
  the DropWatcher sibling's vendored copy, which came from KickCD's) draws the Icons tab's glows on the
  Comms Pad's buttons and the Comms Dial's wedges. LibKa0s-Glow-1.0 (`core/GlowSetup.lua`) resolves it at call time; without
  it no glow is drawn and nothing else changes. Its TOC line sits before `LibKa0s.xml`, and it is
  named in `## OptionalDeps:`.

## Development — the contributor toolchain

| Tool | Version | Needed for | Evidence |
|---|---|---|---|
| `lua5.1` (+ `luac`) | **5.1 exactly** | the headless suite, `lua tests/run.lua`, and the offline scenarios, `lua tests/perf.lua` | `tests/_kit/loader.lua` uses `setfenv` |
| `luacheck` | any recent | `luacheck .`, the other half of the green gate | `.luacheckrc` at the repo root |
| `lizard` | any recent | the `complexity` suite of `tests/_kit/run-automated-tests.sh`, which runs it over a sanitized shadow and checks function-count parity, because `lizard` alone is blind in Lua (automated-tests-§3) | `lizard --version` |
| `git` | any recent | vendoring, the vendored-payload gate (`tests/test_vendor_sync.lua` reads the index and compares against the sibling `../LibKa0s` checkout) and the line-ending gate (`git check-attr`) | `tests/_kit/vendor_sync.lua`, `tests/_kit/test_eol.lua` |
| POSIX shell (`bash`) | any | `tests/_kit/run-automated-tests.sh` and the commands in this file | the runner's shebang |

**Lua 5.1 is a requirement, not a preference.** The harness sandboxes each source file with
`setfenv`, which was removed in 5.2 — "5.2 will probably work" is false and costs an hour to
disprove.

```sh
# Lua 5.1 and luacheck
sudo apt-get update
sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck

# lizard — via pipx, NOT pip. Ubuntu 24.04 marks its Python EXTERNALLY-MANAGED (PEP 668),
# so `pip install lizard` fails; pipx installs it into its own venv and puts it on PATH.
sudo apt-get install -y pipx
pipx ensurepath          # then open a new shell, or: source ~/.bashrc
pipx install lizard

# verify — each of these must print a version
lua5.1 -v                # Lua 5.1.5 …   (if `lua` is not 5.1, use lua5.1 explicitly)
luacheck --version
lizard --version
git --version
```

Versions are pinned only where a version matters: `lua5.1` is hard, `luacheck` and `lizard` are
"any recent" and pinning them would be false precision.

## Release / assets

**Python 3 with Pillow**, and only for **regenerating** the logo TGAs —
`media/logos/quickcomms.logo.128.tga` and `media/logos/quickcomms.logo.tga` are committed, so
nothing is generated at package time. The recipe is layout-§4's, run by hand from the committed
2000×2000 source when the art changes. (The v0.1.0 source is a placeholder drawn with Pillow for the
scaffold, a gold speech bubble on a dark disc; owner artwork replaces it the same way.)

```sh
sudo apt-get install -y python3-pil
python3 -c 'from PIL import Image; Image.open("media/logos/quickcomms.logo.png").convert("RGBA").resize((128, 128), Image.LANCZOS).save("media/logos/quickcomms.logo.128.tga", format="TGA")'
python3 -c 'from PIL import Image; Image.open("media/logos/quickcomms.logo.png").convert("RGBA").resize((300, 300), Image.LANCZOS).save("media/logos/quickcomms.logo.tga", format="TGA")'

# verify
python3 -c 'import PIL; print(PIL.__version__)'
```

The same Pillow regenerates the Comms Dial's slice textures: `tools/gen-dial-textures.py` writes
`media/textures/dial-sector-2.tga` … `dial-sector-12.tga` (one pie slice of an n-slice dial, white
on transparent), `media/textures/dial-disc.tga` (every filled circle the dial draws, and in halves
the round caps of the page pill, the indicators' background and their borders) and
`media/textures/dial-ring-1.tga` … `dial-ring-12.tga` (the hub's hollow rings and rims, a ladder of
line widths from 1.25% to 50% of the diameter). Run it from the repo
root after changing the shapes; never edit the TGAs by hand. It is not loaded by the client, and
`.pkgmeta` ignores `tools/`.

```sh
python3 -I tools/gen-dial-textures.py
```

**NumPy** (with the same Pillow), and only for **regenerating the shine overlay's textures**:
`tools/gen-shine-textures.py` writes the 52 `media/textures/shine-*.tga` files (about 10.7 MB) that
`modules/Shine.lua` names (a pad look per button, the dial's whole-disc art, the per-count slice
rims, Frosted glass streaks and Bevel edges, and three sprites: Glass orb's bead and Fluid glass's two
blooms; light and shade on transparent). Run it from the repo
root after changing the art; never edit the TGAs by hand. It is not loaded by the client, and
`.pkgmeta` ignores `tools/`. No other generator needs NumPy.

```sh
sudo apt-get install -y python3-numpy
python3 -I tools/gen-shine-textures.py

# verify
python3 -I -c 'import numpy; print(numpy.__version__)'
```

`-I` (isolated mode) leaves the user site-packages out, so the `-I` commands in this section find
NumPy and Pillow only where apt puts them: a NumPy installed with `pip install --user` fails under `-I` with
`ModuleNotFoundError: No module named 'numpy'`. Install `python3-numpy` as above, or drop the `-I`.

**Lua 5.1 with the same Pillow and NumPy**, and only for **previewing the shine overlay offline**:
`tools/render-shine-preview.lua` loads the addon headless through the test harness
(`tests/loader.lua` over `tests/wow_mock.lua`, the same lifecycle as `tests/run.lua`), builds the
stock dial at 4, 8 and 12 slices and the stock pad under every look, and dumps every region they
painted (texture, layer, size, anchors, turn, color, texcoords, masks) to JSON;
`tools/render-shine-preview.py` composites the dump the way the client blends it (layer order, turned
quads, vertex color, BLEND, MaskTexture alpha) into
`docs/superpowers/specs/2026-10-21-shine-overlay/render-dial-4.png`, `render-dial-8.png`,
`render-dial-12.png` and `render-pad.png`. The Python script runs the Lua one itself, as `lua` on the `PATH`
(`tools/render-shine-preview.py`), which must be Lua 5.1. It needs the
DejaVu Sans font for its labels (any font works; it falls back to Pillow's own). Re-run it after a
change to the shine's art or recipes and look at the result before an in-game pass: the renders are
what the code draws, not a copy of the recipe. It is not loaded by the client, and `.pkgmeta` ignores
`tools/`.

```sh
python3 -I tools/render-shine-preview.py            # all four renders
python3 -I tools/render-shine-preview.py --scenes --out /tmp/shine   # every scene alone, elsewhere
python3 -I tools/render-shine-preview.py --bg 6a4d6a   # over another scene color (hex)
python3 -I tools/render-shine-preview.py --radius 100,150,180 --out /tmp/shine   # the dial at those ring radii
```

**Python 3 (standard library only)**, and only for **re-deriving the client-data extractions**:
`tools/derive-gameids.py` (the instance ids and `tests/test_gameids.lua`'s map table), with its
`tools/client_tables.py`. It downloads wago.tools' exports of the client's tables and checks the
repository against them; neither is loaded by the client, and `.pkgmeta` ignores `tools/`. How to run
them: `docs/common-tasks.md` → "Re-derive the client-data extractions".

**None of this group is required to build, run or test the addon.**

## Am I set up correctly?

```sh
lua tests/run.lua                                     # the suite — must be green
lua tests/run.lua -j auto                             # same, fanned across CPUs (testing-§14)
# every run above is bounded by the vendored kit on load (testing-§15); KA0S_KIT_GUARD=off only under a debugger
luacheck .                                            # must be 0 warnings / 0 errors
bash tests/_kit/run-automated-tests.sh --suite complexity   # the sighted complexity report (release-time);
                                                      # never raw `lizard`, which is blind in Lua (automated-tests-§3)
```

See `docs/testing.md` for what those commands mean and when each is run.
