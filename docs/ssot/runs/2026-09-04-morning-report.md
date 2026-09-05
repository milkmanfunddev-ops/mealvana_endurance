# Morning report — 2026-09-04 (overnight after landing food-recommendation@v1.1)

## Landed (recap)
`food-recommendation@v1.1` merged to **qa main** (`6c4ed2d`, pushed) and **app develop**
(`db73e7b0`, merged locally, **27 commits awaiting your push** — the push spends a Codemagic build,
so it is deliberately yours). Gate at land time: 28/0 (+ twin differential byte-equal on 26
vectors) · 88 · 28 · 21.

## Correction to what I told you last night
I reported that the Patrol flow `formula_pin_flow` had **failed** with a Riverpod disposal error.
**That was wrong.** The run had been killed mid-flight by a 2-minute tool timeout on my side; the
error was the harness dying, not the test. Re-run properly in the background:
**✅ 1 passed / 0 failed** — including the exact case I quoted ("pin a During formula, see it in
pinned-only view, then unpin it", 6 s). I should have re-run before reporting a failure.

## Patrol results
(filled below as each flow completes)

## What Patrol needs vs what it does not
Also corrected: Patrol needs **no pushed dev build**. `patrol test --flavor dev` compiles from
local source onto the simulator and talks to the already-deployed dev backend (verified: catalog
`solvent_min_ml` live, §10 ledger columns present). Only the Codemagic TestFlight artifact needs
your push — a different thing entirely.

## New Patrol flows (added on your "add both patrol tests")

Two flows, both written against the ratified contract, not against observed behaviour.

### 1. `formula_pin_conflict_flow_test.dart` — ✅ **1 passed / 0 failed**
Walks FP-4a → §1a → FP-4b on a real conflicting formula: it discovers one by tapping thumbtacks
(un-pinning any clean card it opens), self-skips if the shared account has no conflict to find,
and never mutates the account's allergy profile. Keys pinned: `formula_kit.pin_conflict_warning`,
`_choose_another`, `_pin_anyway`, `_label`, `_label_header`.

### 2. `fueling_window_persistence_flow_test.dart` — the D-018 wiring guard
Pins what the unit suite structurally cannot see: that the create SCREEN calls
`resetFuelingWindowForNewActivity()`. Delete that call and every unit test still passes.

**The D-018 assertion itself passed on the first run** — a window stepped on activity A does not
seed activity B. What failed was **my own final assertion**, and it is worth writing down because
it is a spec-literacy trap, not a flake:

> I asserted Race Pace ⇒ `3 HOURS`. The app returned `1 HOUR 9 MIN`.

That is §3 doing exactly what it was ruled to do. `defaultNewActivityDateTime` seeds a new activity
at **now + 1 h rounded up to the next 15 min**, so time-until-start is *always* 60–75 minutes and
the clamp caps anything above it. **Race Pace's 180 can never render as 3 h on a fresh create
form.** Worse, the moderate default (120) clamps to the *same* ceiling — so a Race Pace assertion
cannot distinguish re-derivation from suppression at all, and would have been a test that could
only ever be green by accident.

I then tried to rescue the assertion and hit the deeper version of the same problem, which is
worth recording as a **testability finding about the surface**:

> On a fresh create form, **every §3a row above ~64 min collapses to the same clamped ceiling** —
> race's 180, mid's 150 and the moderate default's 120 all render identically. So *no preset tap
> can distinguish a real re-derivation from a suppressed one* while the clamp binds.

The only rows below the ceiling are `<60` (45 min) and `easy 60–90` (60 min), and both require
moving the estimated duration — which on this screen is coupled to pace and gets re-derived when an
intensity preset changes the pace zone, so a typed duration does not survive. (Two secondary facts
found on the way: the duration `TextField`s report as non-hit-testable to the Patrol finder inside
the CF-6 dashed shell, and typing a duration *before* tapping an intensity chip is silently
overwritten.) Reaching an unclamped state needs the date/time picker.

**Decision: the §3a mapping assertion is cut from this flow, with the reasoning written into the
test file.** §3a's table is already covered directly by the unit suite; what only this flow can see
is the wiring — that the create screen resets the window per activity. Adding a clamped-value
assertion would have produced a test that could only ever be green by accident, which is worse than
no test.

## Incidental finding — dead widget carrying live-looking test keys
`lib/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart` (`DurationPaceToggle`) has
**zero call sites in `lib/`**, yet owns `activity_create.by_duration_toggle` and
`activity_create.by_pace_toggle`. Those keys read like a supported test surface and are
unreachable — the mode is really switched by the duration/pace fields' own `onActivate`
(`WorkoutDetailsWidget`). It cost me one Patrol iteration. Low severity, but it is a trap laid for
the next person writing a flow. Candidate for deletion or for a comment saying the keys are dead.
