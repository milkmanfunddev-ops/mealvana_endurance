> **RESOLVED 2026-09-21 → ruled in-session (interview): all three clauses + tolerances; fold to matching.md M-1.2/M-3, own slice — NOT 1.27.1**

type: ruling-request
bundle: data-integrations (matching family) → own seam-tested slice, post-1.27.1

## Why this matters
A provider completion can never complete anything in the shipped client: `decideKeyed` /
`MatcherIncomingKeyed` (M-1.2 t1/t3) passes its ratified vectors in BOTH twins and has ZERO
production callers, and matching only ever runs on GARMIN-ACTIVITY arrival. Live case
(2026-09-20, Xuan's dev account): an FS echo of his own Garmin run was inserted as a second,
`planned` row 3h53m after the activity landed; his coach's Saturday plan for the same run
never matched because he ran it Sunday.

## The rulings (Xuan, 2026-09-21, interview — items 5 and 6 closed together)
**R1 — first-sight keyed completion is born COMPLETED** (item 5): a keyed provider row
carrying completion + actuals, with nothing to attach to, inserts as `completed` with its
actuals — never `planned`. (`final_surge_transformer.dart:201`'s hard-coded 'planned' is the
defect; `:265`'s `providerReportsCompletion` is the signal that must reach the decision layer.)

**R2 — ATTACH, never a second row** (the reconciliation rule): a keyed provider row whose
MEASURED signature matches an existing activity is the SAME physical workout — stamp its
`provider_workout_id` onto that row and merge provenance; do not insert. R1 fires only when
nothing matches. (M-0's one-row invariant, now reachable.)

**R3 — the device wins**: the measurement-bearing provider (the device/Garmin row) stays
authoritative for measured values; the echo contributes identity and any plan linkage. Read
-time precedence per the ratified F22 ladder — never overwrite measurements at ingest.

**R4 — RETRO-MATCH** (item 6): matching runs on PROVIDER-ROW arrival as well as activity
arrival. Covers both observed directions — a late echo (provider row after activity) and a
late/cross-day plan (Xuan's Saturday plan, Sunday run).

**R5 — tolerances** (QA-proposed, ruled as proposed): same local day · |start delta| ≤ 90 s ·
|duration delta| ≤ 2 %. Evidence: the live case matched start to the second (07:08:09 vs
07:08) and duration to a tenth of a minute (66.08 vs 66) — loose enough to be safe, far too
tight to pair two different workouts.

## Supporting observed facts (from the same investigation, banked in
## `intake/2026-09-21-fs-completion-echo-first-observation.md`)
- FS `provider_workout_id` is STABLE across syncs and IDENTICAL across accounts for one source
  workout — the identity guarantee R2/R4 rely on, observed not assumed.
- Echo detection rule: a provider row whose scheduled time carries sub-hour precision matching
  an existing activity's measured start, created AFTER that activity, is an echo — regardless
  of any completion flag.

## Release scope (ruled)
NOT `fix/1.27.1` — wiring keyed signals through the decision layer changes offline-first sync
write paths and needs its own seam-tested slice.

## Gates
- [ ] Fold R1–R5 into `matching.md` (M-1.2 keyed tier + M-3) as dated post-ratification
      additions; cross-reference `final-surge.md` FS-2 for the echo facts.
- [ ] Vectors: attach-not-insert (both arrival orders), device-wins precedence, retro-match
      trigger, and the tolerance boundaries (±90 s / ±2 % on both sides) — spec-derived.
- [ ] REACHABILITY attestation (land-bundle doctrine): a named production call site reaches
      the keyed decision path; a vector-green path with no caller does not count as shipped.
- [ ] Test-plan rows with their reds, named before implementation (name-your-red rule).
