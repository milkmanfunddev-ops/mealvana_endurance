# Design SSOT — Component: Slide-over Pager

**Status: PROPOSED v1 (Lee, 2026-09-21) — authored app-side, awaiting Xuan.** Written from paywall
ticket 14 (decisions mp-493 §1 and §6, mp-497 §4, approved as mp-498). No reference rendering yet.

**Component contract** — two pages and one move between them: the second page slides over the
first. It owns the motion and which page takes input. It never decides when to move; the page that
composes it does (for the paywall: when the opening clip ends, or on a tap).

**Tokens / material:** [`../tokens.md`](../tokens.md) §Materials — the first page dims under the
`glass-sheet` scrim (blackberry 60 %) as it is covered, the same scrim every summoned surface
inherits. No colour of its own.

## Contracts

- **SOP-1 — one way.** Once told to move, the pager never goes back, and no gesture moves it either
  way.
- **SOP-2 — the move.** The second page slides in from the trailing edge over 480 ms on an ease-out
  (cubic) curve. The first page drifts back a third as far (parallax) and dims under the scrim up
  to its full 60 %.
- **SOP-3 — Reduce Motion jumps.** With Reduce Motion on (or when the owner asks for no animation)
  the second page is there on the next frame, with no slide and no fade.
- **SOP-4 — one page at a time.** Nothing takes a tap during the move. Once it ends the first page
  leaves the tree, so whatever it was playing stops and it is gone from the screen reader. A pager
  that starts on the second page never builds the first.

## Implementation

`lib/shared/widgets/kyle_design/navigation/slide_over_pager.dart` — `SlideOverPager`.

## Open questions for Xuan

- **Q-SOP1** — duration and curve. 480 ms ease-out cubic is the app's reading of Bevel's move; the
  token registry has no motion tokens yet.
