# Reconciliation — "Create Activity Plan" (Claude Design, 2026-09-03) vs the ratified specs

**Prototype:** `~/Downloads/Create Activity Plan.html` (copy: scratchpad/proto). Walked in Chrome
(RUNNING + BRICK tabs, INDOOR toggle, scroll states). **Specs:** `create-flow-fueling-controls.md`
(RATIFIED), `food-recommendation.md` §3/§3a/§7 (RATIFIED), `spec/domain/brick.md` v1.
**Per Xuan:** date/time pickers deliberately inert in the prototype — not ratified yet, NOT an app
regression; excluded from findings.

## TRACED
| # | Finding |
|---|---|
| T-01 | Fasted toggle ABSENT on every tab — CF-3/§7 implemented ✓ |
| T-02 | Brick window: 124-min legs → **2 HOURS 30 MIN**, caption "2.5 h — mid-distance" = §3a row `1.5–2.5h → 2.5h` ✓ — and the caption answers **Q-CF1: YES** (design chose captions) |
| T-03 | Run window: 108-min Long Run → **3 HOURS**, caption "3 h — long session" = §3a `1.5–2.5h` row **nudged one up by intensity** — exactly the §3a Notes rule, now with a concrete mapping (Long Run ⇒ +1 row) that §3a should name |
| T-04 | ENVIRONMENT · OUTDOOR/INDOOR ⇒ the engine's existing `is_indoor` input (1.30× sweat); INDOOR hides the weather block entirely — a clean conditional worth a CF-4a contract line |
| T-05 | Weather: TEMPERATURE/HUMIDITY steppers with AUTO badges + "Auto-filled from location" ✓ CF-4 shape |

## DESIGN-FIX
| # | Finding |
|---|---|
| D-01 | Copy: **"View Forecast"** vs ratified CF-5 **"Get Forecast"** — either the design reverts or CF-5 amends; one must move |
| D-02 | **CF-2's clamp-bound state is missing** (stepper opening AT the ceiling, inert +) and **CF-4's location-blocked state is missing** — both are ratified display states with no artboard. Follow-up frames for the design session (clamp state acknowledged as entangled with the un-ratified time picker) |

## SPEC-ADD (design found holes)
| # | Finding |
|---|---|
| S-01 | **Pace default semantics:** "your usual · 9:00 /mi" chip + editable pace + Duration `EST.` hr/min shown TOGETHER (as-built has By-Duration/By-Pace modes). No spec documents the default-pace source (saved usual), the 9:00 fallback, or the pace⇄duration linkage. Fixes the F-27 4:30/mi class — needs a §3b or CF-6 drafting task |
| S-02 | **Window label is sport-dynamic:** "PRE-RUN…" on running, "PRE-ACTIVITY…" on brick. CF-5's copy register pins only PRE-RUN — needs the label rule |
| S-03 | AUTO badge semantics (auto-filled vs manually-overridden weather) — display state no spec names |

## RULING-NEEDED
| # | Question |
|---|---|
| R-01 | **Inline brick creation** (leg chips, drag-order rows, per-leg durations, remove ✕) vs `brick.md` R1's link-based model ("brick action offered iff the day holds 2+ eligible workouts"). Does inline creation REPLACE linking, COEXIST, or is R1 amended to two creation paths? Biggest structural question in the prototype |
| R-02 | **"BRICK IS FULL · 3 LEGS"** — a max-leg constant no spec holds (brick.md is silent; Q-BR2 adjacent). Ratify 3, or another number? |

## MOCK-NOTES (non-blocking)
86°F/54% weather, 30/67/27-min legs, "SWIM/BIKE/RUN BRICK" name, Sep 3 · 1:30 pm (inert by
instruction). Swim-first leg order is eligible per brick.md R3 ✓.

## Disposition
Design is a faithful superset of the ratified contracts (T-01..05) with two copy/state fixes
(D-01/02), three small spec-drafting tasks (S-01..03), and two rulings (R-01/02) — R-01 being the
one that must be answered before this prototype goes to extraction, since it changes the brick
creation model brick.md just ratified.

## RULINGS APPLIED (Xuan, 2026-09-03 — all eight, option 1)
R-01 coexist → brick.md R1a · R-02 max 3 → brick.md R9 · NUDGE mapping → §3a Notes ·
S-01 → CF-6 · S-02 + D-01 → CF-5 amended · S-03 → CF-7 · D-02 acknowledged (follow-up frames
listed in the spec). CF-8 (ENVIRONMENT toggle) confirmed by Xuan 2026-09-03 — the create-flow surface is
contract-complete; NOTHING remains before extraction.
