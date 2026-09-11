# Bottom-chrome clearance — how far above the tab bar does docked content sit?

`type:` ruling-request
`bundle:` `home-shell@v1` (the shell's contract with the bodies it hosts)

## Why this matters

The shell's bottom chrome is the one piece of geometry every hosted body must respect, and it is
not written down anywhere. The first body to dock something at the bottom guessed, and the guess
was wrong by 17 px — the tab bar clipped it. The next body (Vana, the reserved utility slot, the
iPad rail) will guess too.

## The defect this came from

Found on device 2026-09-09 (iPhone 17 sim, populated day, brick leg-picking), verified by
arithmetic rather than by eye:

| | |
|---|---|
| `home_shell_chrome.dart` tab-bar `Positioned(bottom:)` | 28 |
| `KyleTabBar.expandedHeight` | 60 |
| ⇒ bar's top edge | **88** |
| `macro_dashboard_screen.dart` `_dockedBottomInset` | **71** |

The docked LEG ORDER panel's bottom 17 px sat under the glass bar, which clipped the
`Create Brick (n)` button's lower-left corner. 71 was not arbitrary when it was written — it was
tuned against `FloatingActionButtonsBar`, which the `home-shell@v1` switchover **deleted**. The
constant was never re-tuned against the taller bar that replaced it, and nothing failed when the
thing it described ceased to exist.

Sibling defect, same surface, same day:
[`2026-09-09-overlay-material-boundary.md`](2026-09-09-overlay-material-boundary.md) ·
[`2026-09-09-docked-action-panel-material.md`](2026-09-09-docked-action-panel-material.md).

## The question

**How much breathing room sits between a body's docked content and the shell's bottom chrome —
and is that gap fixed, or does it scale?**

The *clearance* (the 88) is a fact about the shell and needs no ruling — it is derivable. The
**gap on top of it** is a design value, and it is the only thing being asked here.

## Suggestion (responsive-conducive)

Three properties, in the order they matter:

1. **The shell publishes the clearance; bodies never encode it.** `HomeShellChrome` already
   publishes `headerClearancePx` for the top edge and `TabsScreen` passes it as
   `MacroDashboardBody(topInset:)`. The bottom should be the mirror image of that — one derived
   constant (`tabBarBottomMargin + KyleTabBar.expandedHeight`), passed as `bottomInset`. A body
   hosted by a shell with **no** bottom bar (the iPad rail) is then correct for free: it receives
   0 and docks to the surface edge. This is the part that keeps the number from going stale
   again — it is computed from the same constants that *position* the bar.

2. **Reserve the EXPANDED height, always — never the live one.** The bar collapses to a home
   button on scroll. Sizing docked chrome to the current bar height would slide the panel down
   as the bar shrinks, i.e. move a button under the user's thumb mid-gesture. Stability beats
   tightness; the collapsed state simply shows more empty space below the panel.

3. **The gap itself scales by height class, not by device.** Per
   `docs/technical/responsiveness.md` the house primitive is
   `AdaptiveSpacing.byHeightClass(context, short:, regular:, tall:)`
   (`short < 700`, `regular 700–900`, `tall ≥ 900`). A docked panel is a fixed cost against a
   variable viewport: on a `short` phone the LEG ORDER panel plus the pinned instrument block
   already claim most of the screen, so the gap should give way there — it is the least valuable
   pixel in the layout. On `regular`/`tall` it can hold the standard rhythm.

**Proposed values: `short: 12`, `regular`/`tall`: 16.** Rationale for the numbers rather than
neighbours: 16 is the vertical rhythm the dashboard's pinned block already uses between the
energy card and the filter row, so a docked panel reads as part of the same stack; 12 is one
step down and still clears the glass bar's rim shadow. Total docked inset therefore becomes
**100** (short) / **104** (regular, tall), against the old flat 71.

Reject freely — the shape of the suggestion (derived clearance + height-scaled gap) matters more
than the two integers, and only the integers need your signature.

## What this gates

- **Already applied** on app `fix/brick-docked-panel-opacity`, as the repair to a clipping defect:
  `HomeShellChrome.bottomChromeClearancePx` published and consumed via a new
  `MacroDashboardBody(bottomInset:)`; the dashboard's timeline padding (a second hardcoded ~88,
  written as `90`) now derives from the same source; gap via `AdaptiveSpacing.byHeightClass`.
  Regression test in `test/features/home_shell/home_shell_gestures_test.dart` asserts the
  published clearance actually clears the real `KyleTabBar` rect in **both** bar states
  (verified red at the old 71: 781 > 764).
- **Gated:** the two integers, and whether the gap belongs to the shell (one clearance for every
  body) or to each body (each decides its own breathing room). The repair assumes the latter —
  the shell states the fact, the body chooses the gap — which is what makes the rail case work
  without the shell knowing what its body docks.

## A second contract the same geometry carries (Xuan, 2026-09-09)

**A docked panel may be tall, but it must never cost the athlete content.** However high the
LEG ORDER panel grows — it scales with leg count — scrolling to the end of the day must bring the
**bottom of the timeline past the top of the panel**, so every card can be reached and picked.
The panel occludes; it must not truncate.

This is a *contract*, not a value, so it needs no ruling — but it is the reason the docked inset
must be **measured, not assumed**: the panel's height is a function of leg count (and, once the
leg chips wrap, of width), so a constant can only be right for one of its states. As built, the
timeline reserves the panel's measured height plus one gap, so the last card comes to rest just
above the panel rather than flush against it.

Worth pinning as a row wherever the panel's spec lands, because it is quietly easy to violate in
BOTH directions and the failure looks like nothing:
- reserve too little → the last cards are permanently unreachable (the original defect: a flat
  90 px reserved against a ~215 px panel);
- reserve too much → the timeline overscrolls into a screenful of dead space above the panel
  (found while fixing the above: reserving the shell clearance on top of a measured panel that
  already carries it double-counted by ~104 px).

Neither shows in a widget test that pumps the dashboard *without* a shell — with `bottomInset`
at 0 the two arithmetics are identical. The regression guard has to compose the body the way the
shell does.

## Conformance

No golden covers a body's docked content against the bar. If the gap is ratified, the natural
home is the leg-picking golden requested in the docked-action-panel sibling — one capture at
`short` and one at `regular` pins both branches at once.

## Suggested spec home

`spec/design/components/tab-bar.md` — a §Clearance row alongside the existing Q2 geometry (the
bar already owns `utilitySlotGap`/`utilitySlotSize` for its *horizontal* neighbour; this is the
vertical counterpart), cross-referenced from whatever surface spec the docked panel lands in.
