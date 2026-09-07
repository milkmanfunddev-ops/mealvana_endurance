# RULING #4 — the pinned instrument block (RESOLVED)

**Ruled: Xuan, 2026-09-06 (evening — Bevel references IMG_8930/IMG_8931: "what do you think
making the bright yellow line and above unscrollable and glass effect (top layer) when the
timeline scroll under it?").**
**Status: RESOLVED — applied same day to date-header.md, macro-dashboard.md §home-shell
recomposition, tokens.md §Materials (top-fade generalization), home-shell.gestures.yaml (dh3
rewritten, dh2 noted), and the app (feature/home-shell-v1).**

## The ruling

Everything above Xuan's yellow line — date header (REST) + energy card + filter row + add
row — is a PINNED instrument block that never scrolls. The timeline runs full-height beneath
it and dissolves under the block's `top-fade` backdrop (blur + blackberry dim, transparent at
the block's bottom edge). Bevel's pinned-header-over-scrolling-stream architecture, in the
Mealvana material vocabulary.

## Consequences

- **dh3 rewritten**: the REST⇄COMPACT scroll pair is replaced by the pinned-block contract
  (block geometry identical across scrolls; no COMPACT renders on the home; timeline scrolls
  and dissolves beneath). The `compact_threshold_px: 56` pin is retired with it.
- **COMPACT stays ratified at the component level** (golden `date_header_compact` unchanged,
  rendering ruling #3's dissolve): a future composition that scrolls its header may drive it;
  dh2's parity is exercised through a component-state parity host.
- **`top-fade` generalized**: the ratified 104 px fade runs at the block's bottom edge;
  everything above holds the fade's peak (tokens §Materials).
- **S-1 glanceability restored**: with the energy card pinned, a workout-card swipe updates
  net balance in a frame the athlete can actually see — the same-pump story reads on screen.
  This also supersedes the interim "whole home scrolls" commit from earlier today.

## Deliberate trade

The pinned block costs ~360 px of vertical space (~3½ visible timeline cards on a 6.1"
device). Accepted for v1; the known refinement if it feels cramped is auto-condensing the
energy card on scroll — a future ruling, not a defect.
