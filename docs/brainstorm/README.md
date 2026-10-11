# Brainstorm: Ka0s Quick Comms

The brainstorming stage. There is no spec and no implementation plan yet, and nothing is built.

| File | What's in it |
|---|---|
| [`04-brainstorm.md`](04-brainstorm.md) | **Start here.** Owner decisions D1–D11, then how the addon should behave, look and feel: the Midnight constraint, dial, pad, callouts, groups and situations, predefined sets, settings structure, risks, and the go/no-go test plan |
| [`mockup/index.html`](mockup/index.html) | Clickable UX mockup. Open it in a browser. A situation simulator drives a live Comms Dial, a Comms Pad and a Ka0s-standard settings window |
| [`01-research-platform.md`](01-research-platform.md) | What the 12.x client allows: chat messaging lockdown, secure vs direct send, tokens, bindings, situation APIs |
| [`02-research-ux-prior-art.md`](02-research-ux-prior-art.md) | Radial-menu research, game comms wheels, OPie, rule editors, accessibility |
| [`03-research-ka0s-fit.md`](03-research-ka0s-fit.md) | What the Ka0s WoW Addon Standard already decides, and the sibling-addon precedents to reuse |
| [`reference/blizzard-ping-wheel.png`](reference/blizzard-ping-wheel.png) | The look-and-feel reference for the dial |

## The five things that shape the design

1. **Midnight locks addon chat** during M+ keys, boss pulls and PvP matches. Secure macro buttons can still send to party, raid, RW and instance, so callouts are "baked" before combat. The game's own `%t` and `{rt8}` substitutions handle the live parts. **Go/no-go test: passed (GO)**, in a real M+ key and an LFR boss; see §13 of the brainstorm.
2. **Dial: 4 wedges by default, 8 max per ring, 2 levels deep.** These numbers come from marking-menu research and Blizzard's ping wheel.
3. **Groups switch on by situation (union); each surface orders them.** "Why is this showing?" and "Preview as…" make the rules visible.
4. **Predefined sets ship built in:** M+ (generic), raid (generic), arena (generic), and a set per battleground. They are read-only templates with a Customize button that makes an editable copy.
5. **Everything follows the Ka0s standard:** landing page, Master controls, nav-rail editors, ReorderList, the window skin, test mode, `/qc`.
