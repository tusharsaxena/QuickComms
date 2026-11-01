# Open and close animations (#13): design

Status: the owner's rulings below were taken in an interview on 2026-11-01 and BIND this work. They override the issue body and any default of the implementer's. The implementer adds the technical design under its own heading and changes nothing in this section.

## Owner's rulings, 2026-11-01

**Four independent animations** (pad open, pad close, dial open, dial close), each set per surface instance on that surface's own page (`pads.<id>`, `dials.<id>`). One never affects another. The preview window follows the surface it previews.

**Knobs per animation:** a style dropdown and a duration slider, about 0.05 to 0.3 s, hidden while the style is None. No easing setting. No master switch and no reduced-motion setting: None on each is enough.

**Defaults:** 0.15 s open, 0.1 s close. On for everyone, existing pads and dials included, so a player's existing surfaces animate after the update.

**Dial styles:** None, Fade, Scale and fade, Fan. The default for open and close is Scale and fade: from about 80% scale with a fade, about the dial's center, never the cursor. Fan is the staggered sweep around the ring.

**Pad styles:** None, Fade, Fade and scale, Slide, Pop. The default is Fade and scale. Slide has a direction dropdown, Up, Down, Left or Right, per animation, shown only while the style is Slide. Pop is a small overshoot.

**Send:** on a send the chosen slice stays bright and pulses slightly while the rest collapse. The send itself fires at once and never waits on the animation. A cancel has no emphasis.

**Combat:** the same in and out of combat. Where a surface cannot be animated safely it snaps instantly and never risks taint.

**Interrupts:** a reopen during a close, or a close during an open, reverses from the current alpha and scale, with no jump.

## Technical design (implementer)

**The problem that shapes everything.** Both surfaces are shown and hidden by secure code: the dial by the header's snippets, a pad by its visibility state driver. Neither can be delayed from the insecure side, so by the time an `OnHide` hook runs the real frames are gone; and `SetScale` and `SetPoint` on them are protected in combat. The real frames therefore never move. Only `SetAlpha`, which the client allows on a protected frame and `Pad.ApplyAlpha` already uses in combat, touches them.

**The ghost.** Each surface owns one insecure, mouse-off copy (`modules/Anim_Ghost.lua`): a plain frame under UIParent, anchored to the real frame's center, in the real frame's strata, carrying a mirror of what the surface draws. Capture walks the live regions (textures and font strings, masks included), grouped by source frame level so the stacking holds, and is read-only on the secure frames, so it is safe in combat. The ghost plays every animation:

- **Open:** the real frame is held at alpha 0 and is fully live (clicks, keys, sends) while the ghost plays; on landing the ghost hides and the real alpha comes back.
- **Close:** the real frame is already hidden; the ghost is captured from it (hidden frames keep their regions and their children's own shown flags) and plays out.

Same path in and out of combat, as ruled. If a capture finds nothing it can draw (no rect yet), the surface snaps: the safe fallback the rulings ask for.

**The state machine (`modules/Anim.lua`).** A track holds a pose (`alpha`, `scale`, `x`, `y`, `fan`) and tweens `from` to `to` with one OnUpdate on a parentless driver frame, which runs only while a track is live and is cleared when the last one lands. A parentless frame keeps running when UIParent is hidden. Every interrupt starts `from` at the current pose, so a reversal never jumps; its time is the setting's scaled by the alpha left to travel, floored at a quarter. Pure parts (`Hidden`, `Ease`, `FanAlpha`, `Step`) are testable without frames. `A.Snap` is the one way off a track: ghost hidden, real alpha back.

**Which edges animate.** An open hook arms on the header's `OnShow` and starts on the ring's `OnShow`, since the snippet shows the ring after the header. A page turn or group wedge during an open snaps (the ghost holds the old ring). Silent, by design: a rebuild's close and reopen (`Dial.Apply`, `Dial.Release`, `openDisplay` reopening a dial that was already open, otherwise every settings edit would flicker), `Pad.Release` (a pad deleted or disabled, the buttons are already pooled) and a hidden UIParent (`OnHide` with the frame's own flag still on). A stand-down snaps every track through `NS.STAND_DOWN`.

**The send.** A wedge's press names its place on the track (`A.Emphasize`), whichever way round the click hook and the wrap's close run. That group's ghost stays at full alpha and pulses by 8% for 70% of the close, then fades. A guarded press and a cancel emphasize nothing. The send is the real wedge's own click and never waits.

**Fan.** Each wedge's elements and its slice fill are tagged with their place (`qcGhostGroup`), and a place's alpha is delayed by `(place - 1) / size`.

**Schema.** `pad.anim` and `dial.anim`: `openStyle`, `openDuration`, `closeStyle`, `closeDuration`, and on a pad `openDirection`, `closeDirection`. The Slide direction reads as motion: Up on open rises into place, Up on close leaves upward. Pop is a back ease, overshoot on open and a small wind-up on close. A new Animation tab on each page, headed Open and Close. Migration 11 to 12 fills `anim` on every stored pad and dial, keeping any key already there.

**Decisions.** The dial's preview dial and the preview pad are the same frames as the live ones, so they follow their surface with no code. A color texture cannot be read back from the client, so `Pad_Render` records what it painted (`qcGhostColor`); a color texture the addon did not paint is left out of the ghost. The drag strip stays out of the ghost: it ignores the pad's alpha already. The animation settings rebuild the surface like every other member row.
