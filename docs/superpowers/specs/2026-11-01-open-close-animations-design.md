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

**Duration, amended by the owner the same day:** the slider runs 0.1 to 2 s in 0.1 s steps on all four. This replaces the 0.05 to 0.3 s range above; the defaults stand.

**Interrupts:** a reopen during a close, or a close during an open, reverses from the current alpha and scale, with no jump.

**Pads, ruled by the owner after smoke testing, 2026-11-01:** animations are for the dial only. This replaces every line above and below that gives a pad an animation; the dial's rulings stand.

## Technical design (implementer)

Amended 2026-11-01 by the pad ruling: wherever this section names a pad, its Slide or its Pop, that part came out. A pad behaves as it did before #13, and `pad.anim` is gone: step 12 fills dials only, and step 14 drops the table from a profile that ran the first step 12 on the feature branch. `qcNoGhost`, `qcGhostColor`, `G.Watch` and `A.Holding` had no reader left, and went with it.

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

**The way back from a hidden UIParent (review, 2026-11-01).** The hide was silent and the reshow was not: every visible pad and every open dial replayed a full open. An `OnHide` with the frame's own flag on now sets `inst.quietShow`, and the next `OnShow` spends it and plays nothing (`onRootShown`, `Dial.HeaderShown`). A release or a silent close drops it. Accepted edge: a frame whose flag goes off while UIParent is hidden fires no event, so the flag outlives it and that frame's next open plays nothing, once. No alpha sticks, and watching UIParent's own OnShow would not close the gap, since its order against the children's is not ours.

**The text (owner's smoke test, 2026-11-01).** All text shimmered, worst on the title, and "Quick Comms: World" was cut short mid-animation. `stage:SetScale` moves the effective scale, so the client rasterized the font afresh at each size, and the wider layout hit the fixed width `place` gave every copy. `FontString:SetScaleAnimationMode(Enum.FontStringScaleAnimationMode.Vertex)` (12.0) is the fix, and it governs Scale animations, never `SetScale`, so:

- A string is on `ghost.text`, a sibling of the stage under UIParent that no pose scales, in a text sub-frame per source level and place. A source level now takes two frame levels, its art then its text, so text stacks over its own level's art and under the next level's, as it did when they shared a frame.
- A string's scale is its own Scale animation, one per pooled string, made once. `G.ScaleText` runs one leg per open, close or reversal, from the track's `from.scale` to `to.scale` over the track's duration, smoothing `OUT` into an open and `IN` out of a close (the nearest to `A.Ease`). A leg at 1 to 1 (Fade, Fan) plays nothing.
- The pose places it: each tick puts a string at its offset from the dial's center times the pose's scale, which is what the stage does to the art. Vertex scaling follows the string's justification, so a copy is centered both ways and its own center is the origin. Placing the string by a Scale origin at the dial's center would have been one call fewer, and would have stopped being about the center if the client honored the justification over the origin.
- A send's pulse is two legs on the one animation, up over half the close's time left and back from the middle (`G.Pose` turns it, once), rather than a chained pair: whether a chain's second Scale composes with the first is not something this addon should rest on. The sent place's strings ride the pulse's position, not the pose's.
- `G.Hide` and a capture stop every string's group, so nothing runs after a landing or a stand-down.
- A copy never takes a width. With one anchor and none set it is as wide as its text, which cannot truncate, whichever way the scale goes. Every string the dial draws is auto-sized, so its center is its text's center.
- `Compat.VertexScaleAnimation` type-checks the Enum and every method it needs. Where anything is missing a string takes no animation and no pose: it fades in place, and the art still scales. The owner ruled that over the shimmer. There is deliberately no FontSize path.

Why not a per-tick scrub (`Play` with an offset, then `Pause`) to hold the text to the script's exact curve: it leans on seek and pause semantics the client does not document for this, every frame, where one `Play` per leg is the plain case. The cost is that the art's tween is the script's and the glyphs' the client's, so they can differ slightly mid-leg if the client's smoothing is not the same quadratic. The position stays exact.

**Decisions.** The dial's preview dial and the preview pad are the same frames as the live ones, so they follow their surface with no code. A color texture cannot be read back from the client, so `Pad_Render` records what it painted (`qcGhostColor`); a color texture the addon did not paint is left out of the ghost. The drag strip stays out of the ghost: it ignores the pad's alpha already. The animation settings rebuild the surface like every other member row.

**The pose engine (the dial styles, 2026-11-01).** The owner's mockup is the spec for the motion: `e` runs 0 hidden to 1 at rest, and a close plays it back down. `modules/Anim_Pose.lua` holds it as pure functions.

- A pose is flat: `alpha`, `scale`, `scaleX`, `scaleY`, `rot`, `dx`, `dy` (in dial radii), `fan`, `hub`, `flash`, and for a per-place style `places[1..count]`, each `{ alpha, radius, angle, scale, spin }`. `rot` turns the places only. The hub and the title stay level, as in the mockup.
- A style is `{ g, w, knots }`: `g(e, pose, cfg)` writes the whole dial's keys, `w(e, i, n, place, cfg)` one place's, with `i` from 0 as the mockup has it. Each gets a pose at rest and writes what it moves. A `w` style fades the hub by `clamp(e * 2)`, as the mockup does.
- A fresh leg plays the style's curve. An interrupted one lerps from the resolved pose, every place included, to the new style's end, which is what lets an open and a close of two styles meet with no jump. A reversal's time is now the share of `e` left, not of alpha, because most styles reach full alpha early. The floor stands.
- A track owns five pose buffers, and `A.Pose` and `A.Lerp` write into them, so a tick makes no table.
- A copy now hangs off its sub-frame, not the stage. A place's radial offset is one `SetPoint` on the sub-frame, and its scale one `SetScale`, in that scale's units. A turn is per copy: a fill's texture center is its apex, near the dial's center, while its bead and icon sit far out, so no single sub-frame move can orbit them all. Each copy of a turning place is re-anchored at its turned offset, and art tagged `qcGhostTurn` (a fill, a shine layer, their masks, the highlight) takes `SetRotation` from the base the capture kept. Icons and strings stay upright. This cost is one `SetPoint` per copy per tick, only while a place turns.
- **One axis.** A Scale animation per art sub-frame (`Compat.StretchAnimation`), one leg at a time like the text's, with an end delay so a finished leg cannot let go to 1 and flash the dial. It is per sub-frame, not on the stage, so the sent place can leave it. Text takes both axes in its own Vertex leg. A style's `knots` break a curve the client's one smoothed leg cannot follow into linear legs, one Play per leg and none per tick. **The substitute:** where a frame takes no Scale animation, both axes become the smaller one, uniform, so a Squash or a Flip reads as a shrink. Whether a Scale on a 1 by 1 frame carries regions anchored outside it, masks included, needs the in-game trial the mockup asked for. The substitute covers a missing API, not a client that takes the call and draws it badly.
- **Flash.** One additive texture (`dial-glow.tga`, generated) on a frame over every level, made the first time a pose asks. A style with no flash pays for nothing.
- Every scale written is at least `G.MIN_SCALE`, because the client raises on `SetScale(0)`.
- The send, in any style: the sent place undoes the stage's offset and scale, its copies go back to their rest place and base rotation, and it leaves the one-axis leg.
