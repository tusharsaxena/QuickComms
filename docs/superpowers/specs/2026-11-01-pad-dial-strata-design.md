# Pad and dial strata — design (2026-11-01)

Issue [#14](https://github.com/tusharsaxena/QuickComms/issues/14): the Comms Pad and the dial can open
under other addons' windows. Built on `feat/2026-11-01-full-skinning`. The owner's standing rule applied:
every decision here was taken without asking.

## The stack

| Frame | Strata | Level over UIParent |
|---|---|---|
| Comms Pad root | `DIALOG` | `HUD` 1000 |
| Dial screen catcher | `FULLSCREEN` | 998 (header - 2) |
| Dial ring catchers | `FULLSCREEN` | 999 (header - 1) |
| Dial header, wedges, hub front | `FULLSCREEN` | `DIAL` 1000, to 1020 |
| Preview window | `FULLSCREEN` | `WINDOW` 1100 |
| Callout popup | `FULLSCREEN` | `MODAL` 1200 |
| Icon browser | `FULLSCREEN` | `MODAL_OVER` 1400 |
| Confirms, link window, menus, pull-outs | `FULLSCREEN_DIALOG` | as they come |
| Tooltips | `TOOLTIP` | as they come |

## Decisions

1. **The pad is `DIALOG`, level 1000.** The lower of the issue's two options. `FULLSCREEN` for the pad
   would leave the dial nowhere to be a strata above it. This breaks frame-layering-§1 T1, so it is
   an owner-driven row in `docs/ARCHITECTURE.md` -> `## Documented deviations`.
2. **The dial is `FULLSCREEN`, not the issue's `FULLSCREEN_DIALOG`.** This is the one departure from the
   issue's proposal. The issue also requires that the modals and the preview window keep covering a
   preview dial, and dial 1 is one header whose strata cannot switch for the preview (§4; protected in
   combat). At `FULLSCREEN_DIALOG` the only tier over the dial is `TOOLTIP`, where a modal would cover
   its own library menu and the color picker; a modal at `FULLSCREEN_DIALOG` loses the same race
   inside the strata. `FULLSCREEN` still clears the `MEDIUM`, `HIGH` and `DIALOG` windows the issue
   names, keeps §1's rule that only transients use `FULLSCREEN_DIALOG`, and keeps the confirms and
   pull-outs over the dial by strata. It is exactly §1's HUD popup tier: one over its root.
3. **Bands, not strata, inside `FULLSCREEN`.** Dial, preview window and modals share it, in
   explicit level bands. Every level is relative to UIParent, named in `LAYERS.LEVEL`. The gap from
   `MODAL` to `MODAL_OVER` stays over the popup's combat cover (page + 100).
4. **The screen catcher moves with the dial,** by level, not strata: in `HIGH` it would sit under a pad,
   which would take the outside click. `LAYERS.STRATA.DIAL_SCREEN` is gone, `LEVEL.DIAL_SCREEN` replaces
   it. As a side effect a click on the settings window now closes a key-opened dial (it used to reach
   the settings window, QUI-Z09); clicks on the preview window and the modals still reach them.
5. **The cost is accepted.** A pad covers the settings window, and overlapping Blizzard confirms and
   library tool windows until a click raises them. `docs/known-limitations.md` says so, and LAYER-6
   asks the owner to look at it.
6. **The skin picker is raised on a show (review, 2026-11-01).** Decision 5 missed it: the library's
   picker is `DIALOG` at its inherited level, so a pad covered it and took its clicks.
   `NS.MaybeShowSkinPicker` and `NS.RunSkinVerb` now `Raise` the frame the library answers, the host
   fix, since `libs/` is vendored. It does not reach a picker queued behind another Ka0s addon's, which
   the library shows later with no hook; that needs a raise on show upstream in LibKa0s's
   `OptionsSkinPicker`, and until then `docs/known-limitations.md` names it. An open dial still covers
   the picker: it is a strata up, and it is transient.
