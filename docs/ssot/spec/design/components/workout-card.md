# Design SSOT — Component: Workout Card

**Status: RATIFIED v1 (Xuan, 2026-08-14).**
**Component contract** — owns this card's states, gestures and data binding wherever the card
appears. Composition into a screen (and cross-component side-effects) belongs to the surface spec
that uses it, e.g. [`../surfaces/macro-dashboard.md`](../surfaces/macro-dashboard.md).
**Tokens:** [`../tokens.md`](../tokens.md). **Reference rendering:**
`prototypes/macro-dashboard/index.html` — the prototype illustrates, this file governs.

## States — state × visual × chip

| State | Visual contract | Chip |
|---|---|---|
| `PLANNED` | Dashed outline, dimmed fill, no solid border | `Planned` |
| `DONE_CONFIRMED` | Solid fill, solid border | `self-reported` |
| `DONE_VERIFIED` | Solid fill, solid border, icon disc in `electrolyte` | `✓ verified · Garmin` |
| `SKIPPED?` (end of day, neither sync nor confirmation) | Planned treatment + skipped prompt | `Planned` |

Exactly one state at a time; every state reachable in the reference rendering.
*The visual column names each state's **distinguishing signature** only — full appearance is
screenshot-held (port loop) and golden-held (conformance); do not grow this column into a frame
description.*

## Gesture contracts

| # | Gesture | On state | Contract |
|---|---|---|---|
| G1 | Swipe right (full) | `PLANNED` | → `DONE_CONFIRMED`. **`actual_time` = now** (W-7 ruling); `planned_time` never modified; card moves to the current time on any time-ordered surface |
| G2 | Swipe right (full) | `DONE_CONFIRMED` | → `PLANNED`. **`actual_time` cleared**; card returns to `planned_time` |
| G3 | Swipe right | `DONE_VERIFIED` | **Suppressed entirely** (Q-D1 RULED, Xuan, 2026-08-14): no reveal renders, no translation past a token nudge — a verified card simply does not respond to the done gesture. Garmin fact is not contradictable, and no dead affordance is shown |
| G4 | Swipe left (partial reveal) | any non-verified | Reveals a **labeled** `Delete` button in `dragonfruit`; deletion only on button press, never by the swipe itself (Xuan: two-step judged sufficient; clipped title accepted) |
| G5 | Delete press | revealed | Removes the workout and all its contributions; the *scope* of "all" is the surface's contract |
| G7 | State-change emission | — | The card **emits** its state change; it never repaints only itself. What listens is the surface's business |

## Data contract (authority: `spec/daily-macros/platform-resolution.md`)

`planned_time` immutable by gesture · `actual_time` written by Garmin sync or mark-done(=now),
cleared by mark-undone, upgraded MANUAL → GARMIN on later sync · display shows
`actual_time ?? planned_time`.

## Conformance (design vectors)

- **Golden (L1):** one image per state row, at token-resolved colors.
- **Widget/Patrol (L2):** G1–G5 as scripted gestures asserting state, `actual_time` writes/clears,
  and G7 emission (assert a listener fires; whole-surface propagation is tested by the surface).
  **G3 negative test:** a right-swipe on `DONE_VERIFIED` produces no reveal and no state change —
  assert zero translation after release and no "Mark undone" node in the tree.
- Known reference-rendering defects — do **not** encode as truth: Delete no-op (W-3), no undo
  (W-4), reveal never auto-dismisses (W-6).
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.
  Regeneration commits cite the spec change.

## Open ratification questions
None — Q-D1 ruled 2026-08-14 (suppression, folded into G3).
