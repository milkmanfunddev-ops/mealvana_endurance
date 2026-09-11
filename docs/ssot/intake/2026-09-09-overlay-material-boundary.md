# Overlay material boundary — what may a surface floating over scrolling content be made of?

`type:` ruling-request
`bundle:` (cross-cutting — `tokens.md` §Materials)

## Why this matters

Until this is ruled, every new floating/docked surface is a coin flip: `tokens.md` §Materials
names two recipes and a boundary for *cards*, but says nothing about the general case, so a
developer with a rounded rect that is neither a card nor a capsule has no rule to follow and
picks an alpha fill. One such surface shipped in 1.26.0 (below).

## The evidence — the surface that shipped

`app: lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart`,
`_brickActionBar` (the docked LEG ORDER panel) and `_brickPickHint`. Both were plain
`Container`s in a `Positioned` overlay with:

```dart
color: MeTokens.orangeAlpha(0.08),   // panel
color: MeTokens.creamAlpha(0.05),    // hint
```

No backdrop filter, no scrim, no fade. On device (Xuan, 2026-09-09) the timeline read straight
through the panel: workout-card text collided with the panel's own "Cancel"/"Swap" row, and the
brick group card behind was legible *inside* the panel's `Create Brick (3)` button — the button
is `KyleSecondaryButtonSmall`, whose `backgroundColor` is `Colors.transparent` by design.

Two things went wrong at once, and both are the same mistake:

1. **An alpha fill on docked chrome composites against moving content, not against the ground.**
   8 % is a perfectly reasonable tint *over `blackberry`*. It is not a surface *over a timeline*.
2. **A transparent-by-design control (an outline button) was placed on a non-opaque ground.**
   The control is correct; the composition is not. Nothing in the specs forbids this pairing.

The screen already gets its *top* edge right — `GlassTopFade()`, the ratified `top-fade`
dissolve (RULING #3/#4, 2026-09-06). Only the bottom edge was hand-rolled.

## The question

Does `tokens.md` §Materials gain a **composition boundary**, stated over surfaces rather than
over component categories? Proposed wording for the ruling to accept, amend or reject:

> A surface that overlays scrolling content is either **opaque**, or one of the named
> translucent materials (`glass`, `glass-sheet`, `top-fade`) — never a bare alpha fill.
> A control whose own fill is transparent may only sit on an opaque ground.

## Options

| # | Option | Trade-off |
|---|---|---|
| A | Rule the boundary as worded above, general over all surfaces | Covers surfaces nobody has designed yet; costs one prose paragraph. Makes the *next* panel correct without a per-surface ruling. |
| B | Rule it only for docked/floating chrome, leave other overlays open | Narrower, but "docked/floating" is exactly the category that has no definition yet — pushes the ambiguity one level down. |
| C | No general rule; rule each surface as it is designed | Matches the current per-component practice, but the failure mode is a shipped defect each time a surface arrives without a design session (the brick flow is a CANDIDATE carry-over precisely because it never had one). |

Recommendation: **A**. The existing boundary clause ("timeline/content cards NEVER take glass —
solid fill + hairline stays their ratified treatment; glass is floating chrome + summoned sheets
only") is written over *component categories*, which is why a surface belonging to no category
fell through it. A rule written over *what is behind the surface* has no such gap.

## What this gates

- **App-side, unblocked and already done** (fix landed on `fix/brick-docked-panel-opacity`): both
  panels now take opaque grounds — `Color.alphaBlend(<the same tint>, MeTokens.blackberry)`, i.e.
  the colour the author intended, resolved against the ground once instead of per-frame against
  the timeline. The list also now reserves the docked panel's measured height so the last card
  can be scrolled clear of it. Three regression tests in
  `test/features/macro_dashboard/macro_dashboard_brick_test.dart` (verified red without the fix).
  This is a legibility repair using only ratified tokens — it deliberately invents no material.
- **Gated on this ruling:** whether that opaque ground is the *final* treatment or a placeholder
  for a named material. See the sibling, [`2026-09-09-docked-action-panel-material.md`](2026-09-09-docked-action-panel-material.md).
- **Gated on this ruling:** an app-side static check (no `BoxDecoration` alpha fill under
  `lib/features/` outside an explicit allowlist for the ratified card hairlines). Worth building
  only once there is a rule for it to enforce — `lib/features/macro_dashboard/` alone carries 16
  hand-rolled alpha fills today, and no gate distinguishes the legitimate ones (a chip nested on
  an opaque panel) from this defect.

## Suggested spec home

`spec/design/tokens.md` §Materials — as a post-ratification addition to the **Boundaries**
paragraph (the `intraday-display.md` §4b pattern), no version bump.
