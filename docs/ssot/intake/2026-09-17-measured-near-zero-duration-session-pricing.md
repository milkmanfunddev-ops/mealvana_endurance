type: ruling-request
bundle: daily-macros-dashboard (session pricing / F4a family)

## Why this matters
The matcher now REFUSES to match a 9-second Garmin swim to a planned workout
(guard `guard-9-second-swim-refused`, app `3b7abf48` + `4fa3268a`, prod since 2026-09-14), so
the original overwrite is fixed. But the refused session still lands as its own activity with
~0 measured duration, and the pricing layer then falls back to **60 minutes** — an athlete's
device test shows up as an hour of training in the day's burn. Fix scope waits on this ruling
(`ops/data/bug-reports/2026-08-24-garmin-day-wide-matcher-overwrites-planned-workout.md`,
PARTIAL).

## The question
What duration does session pricing use for a **measured** activity whose duration is 0 (or a
few seconds), and is that different from the fallback for a **planned** activity with no
duration and no derivable pace?

## Current behaviour
`SessionInputResolver.durationMinutes` treats 0 as "absent" (`explicitMinutes ?? 0;
if (minutes > 0) … else fallback`) and returns the planned-session fallback chain, ending at
60 min (`session_input_resolver.dart:93`, same on `release/1.27.0` and `mealplanning`). The
same helper serves both provenances, so a measured 9-second swim and a planned run with no
inputs are priced identically.

## Options
1. **Measured duration is authoritative, including near-zero: price it as measured** (a
   9-second swim ⇒ ~0 kcal). Clean and honest; a device test costs nothing. Cost: a provider
   that reports duration late (duration 0 on first webhook, filled on a later push) would
   briefly price at 0 — check whether that shape occurs before ruling.
2. **Floor measured sessions at a minimum (e.g. 5 min) and never apply the planned fallback to
   a measured row.** Avoids 0-kcal cards; the floor is an invented number needing its own note.
3. **Keep the shared fallback (status quo)** and instead suppress/park refused micro-sessions
   so they never reach pricing. Moves the problem to import policy rather than pricing.

## Recommendation
Option 1, with the provider-late-duration shape checked first: it follows the F4a direction
already ruled for unknown sports (do not invent a number to fill a non-nullable field —
`intake/2026-09-17-strength-and-mobility-as-first-class-sports.md` raises the same principle
on the display side).

## Suggested spec home
The session-pricing section that F4a amended (`spec/daily-macros/…` session cost / oxidation
family), stating the provenance split — measured vs planned — for duration resolution, plus a
vector for a measured near-zero session.
