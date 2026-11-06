# Candidates (QuickComms, LibKa0s v1.86.0 -> v1.89.0)

Sources: `git -C ../LibKa0s log --oneline v1.86.0..v1.89.0`, the tag's `CHANGELOG.md` blocks v1.87.0,
v1.88.0 and v1.89.0, and the `Since` markers in `docs/api/Widgets/version-23.5.12.6.7.5-docs.md`
against `version-22.5.12.6.7.5-docs.md`. No blocker from `01_DELTA.md` 3g is listed here.

## A. Delivered on the re-vendor alone

- **Kit revision 51** (CHANGELOG v1.89.0, *The kit's unregister guard*): `mock_ace.lua`'s
  CallbackHandler unregister clears an entry only where one exists, so an `Unregister*` of a target
  with no registration during a dispatch no longer raises `invalid key to 'next'`. No member moves; the
  suite here is the beneficiary.
- **Widgets 23 `CloseMenu()` closes every cascading level** (v23 doc, members table, `CloseMenu`
  row). `modules/PreviewWindow.lua:184,257` already calls it; with no cascade opened here it does what
  minor 22 did.
- **Widgets 23 flat menus unchanged**: `W.Dropdown` (`modules/PreviewWindow.lua:165`) ignores
  `submenu`, `radio`, `selected` (v23 doc, *What changed at this version*).

## B. Host change required

- **Widgets 23 cascading-menu fields** (`submenu`, `radio`, `selected`, `opts.check` on
  `W.ContextMenu` rows; CHANGELOG v1.87.0, *Cascading menus*). Files it would touch: none. This addon
  has no `W.ContextMenu` use site and no client menu of its own outside `libs/` (`grep -rn
  'ContextMenu\|MenuUtil\|EasyMenu'` over `core modules settings`). Recommendation: not applicable.
  Blast radius: none.

## C. Whole-module adoption

- **`LibKa0s-Toast-1.0` minor 4 (the stack)** (CHANGELOG v1.88.0). This addon looks up no Toast major
  (3e) and shows no alert toasts of its own; Toast is a module it does not consume at all, and the
  minor that moved is a stack for hosts that already toast. Recommendation: not applicable, nothing to
  stack. Blast radius: would be a new module.
- **`LibKa0s-IconBrowser-1.0`**: already adopted at v1.86.0 (`core/IconBrowserSetup.lua`), and it did
  not move a minor in this range. Not a candidate.
