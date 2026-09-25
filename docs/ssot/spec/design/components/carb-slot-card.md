# Design SSOT — Component: Carb Slot Card (loading-day timeline group)

**Status: RATIFIED (Xuan, 2026-09-25, riding confirm on the Q-D batch read-back; extraction from prototype v21).** Earns a component file: it has states, gestures, and suppressions.
**Numbers authority:** `spec/fueling/carb-loading.md` CL-4/CL-5 (slot targets, clock times) —
this file contracts presentation and behavior, never values.
**Behavior imports (ruled, cited not restated):** slots are roll-up containers, one card per
slot, no Recovery group on loading days; dashboard cards carry NO idea rows and NO editing
(2026-09-24 "the card is a gauge and a door").

## States (today-variant; walked)
| State | Trigger | Shows |
|---|---|---|
| `EMPTY` | no logs in slot | header only: slot name · clock · `0 / <target> g`; dashed treatment |
| `FILLED` | ≥1 log | header `<eaten> / <target> g` + ONE summary line (register below) |
| `PEEK` | chevron on a FILLED card | read-only receipt: one row per item (name · grams) + `Edit in <slot> ›` exit; no steppers, no remove |

Day variants (surface-driven): FUTURE day → all cards `EMPTY`-form at that day's own targets,
no logging affordance implied; PAST day → `FILLED` summaries only, no peek-to-edit expectation
(page still opens read-only-in-effect; the day is history).

## Gestures
| # | Gesture | Contract |
|---|---|---|
| SC-1 | Tap card body (any state, today) | Opens the slot interior page. The WHOLE surface is the door — not just a button |
| SC-2 | Tap chevron | Toggles `PEEK` only; never navigates; face/other cards unaffected |
| SC-3 | Tap `Edit in <slot> ›` inside peek | Opens the slot interior page (same destination as SC-1) |
| SC-4 | — suppression — | No swipe actions, no inline add, no idea rows (ruled 2026-09-24; negative test) |

## Data contract
- Card target = `slot_target_g` (CL-4, stored day target); clock = CL-5 grid.
- Eaten may EXCEED target (`55 / 54 g`, `116 / 109 g` walked) — no clamp, no warning state.
- Receipt rows sum to the card's eaten figure exactly (124 = 58+39+27 walked; a mismatch is a
  red, not a rounding allowance).
- **Summary-line register:** 1 item → `<Name>` · 2 items → `<A> + <B>` · ≥3 →
  `<First> +N more` (walked: "Granola Bar + Chocolate Milk", "Turkey Sandwich + Pretzels
  +1 more", "Everything Bagel with Cream Cheese +2 more").

## Conformance
- L1 goldens: EMPTY / FILLED / PEEK on the canonical mock day; future-day and past-day card
  forms ride the surface goldens.
- L2: SC-1 whole-surface hit target; SC-2 peek isolation (face unchanged — walked); SC-3
  destination equality with SC-1; SC-4 negative tests; receipt-sum assertion; summary-line
  register per branch.
