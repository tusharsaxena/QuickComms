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
- **The share string's two libraries are vendored like the rest** (design spec §15): LibDeflate
  `1.0.2-release` (commit `6831edca`, zlib license, kept as `libs/LibDeflate/LICENSE.txt`) from
  <https://github.com/SafeteeWoW/LibDeflate>, and LibSerialize `v1.2.3` (commit `aa6e50dd`, MIT, kept as
  `libs/LibSerialize/LICENSE`) from <https://github.com/rossnichols/LibSerialize>. Each folder is the
  tag's `.lua`, `lib.xml` and license, copied whole and never edited; a new version is a re-copy from
  its tag, in one commit with this line.
- **LibCustomGlow-1.0 is vendored too**: `libs/LibCustomGlow-1.0/` (MIT, minor 24, copied whole from
  the DropWatcher sibling's vendored copy, which came from KickCD's) draws the Icons tab's glows on the
  Comms Pad's buttons and the Comms Dial's wedges. `modules/Glow.lua` resolves it at call time; without
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

**Python 3 (standard library only)**, and only for **re-deriving the client-data extractions**:
`tools/derive-gameids.py` (the instance ids and `tests/test_gameids.lua`'s map table) and
`tools/derive-winds.py` (the node winds in `defaults/BuiltIns_Battlegrounds.lua`), with their shared
`tools/client_tables.py`. They download wago.tools' exports of the client's tables and check the
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
