type: spec-erratum
bundle: data-integrations@v1 (final-surge.md FS-2 observed layer; field-map completion facts)

## Why this matters
The ruled record says FS completion is "structurally unobservable for our tenant"
(2026-09-13: both past-workout endpoints 404, folded into final-surge.md). The 2026-09-21
matcher investigation OBSERVED an FS completion signal in the wild — the claim needs
narrowing, and FS-2.1 gains its first completion facts.

## The observation (durable evidence: dev provider_raw_payloads row; ops report
## 2026-09-21-provider-completion-echo-imports-as-planned-never-reconciled.md)
When Garmin auto-bridges a completed run into FS, FS's UpcomingWorkouts feed RETURNS the
workout as an ECHO carrying `WorkoutCompleted: true`, `ActualTime` (seconds, 3964.8),
`ActualDistanceMeters` (11276.37 — exactly the 7.00683 mi). `WorkoutTime` carries seconds
naive-local; `WorkoutDate` is tz-naive midnight. This organically answers the Q-INT26
one-time FS-completion probe Xuan had planned.

## The smallest correction
final-surge.md: "completion structurally unobservable" narrows to "unobservable via the
past-workout endpoints; OBSERVED arriving through the UpcomingWorkouts echo
(WorkoutCompleted + Actual*) when an activity bridges into FS" — dated, with the census
facts above added to FS-2.1's observed layer. field-map completion rows gain the three
fields. (The transformer defect this exposed — echo imported as a NEW status='planned' row,
`final_surge_transformer.dart:201`, while :265's providerReportsCompletion has no consumer —
is the ops report's half; ruling asks 5/6 in the 1.27.1 queue govern what the matcher does
with keyed completions.)

## Addendum — FS identity guarantee, OBSERVED (2026-09-21)
Investigating an apparent triplicate (refuted: three dev accounts × one copy each, not one
account × three imports) established a fact items 5/6 will rely on:
**`provider_workout_id` for an FS workout is STABLE across syncs AND IDENTICAL across
accounts** connected to the same FS athlete (verified: one FS workout, three accounts, one
row each, same pwid; account-first-connect dates explain the differing `created_at`). So FS
does not re-key per fetch and our FS identity assumption holds — now observed, not assumed.
Belongs in `final-surge.md` FS-2's observed layer alongside the completion facts above.

## Addendum — the echo detection rule (adopted into the ops report 2026-09-21)
A provider row whose scheduled time carries **sub-hour precision matching an existing
activity's measured start**, and which was **created after** that activity, is an echo —
regardless of whether the provider flagged completion. Canonical case: coach's plan 07:00 /
7 mi / duration NULL created days before; echo 07:08 / 7.00683 mi / 66 min created 3h53m
after the Garmin row (start 07:08:09, 7.00682 mi). A plan never carries a measured start.
