type: ruling-request
bundle: data-integrations (matching + capture families) → the keyed-completion slice

## Why this matters
Live on Xuan's PROD account 2026-09-21, two provider-sync defects that the ruled
planned/actual split and the ruled raw-versioning contract were supposed to prevent — both
invisible to every existing gate because both happen on the PROVIDER SYNC path, not the
matcher path.

## F1 — provider-side matching DESTROYS our planned record (the sharp one)
FS's own matcher attached Xuan's Garmin activities to his FS plans. Our sync then wrote FS's
mutated values into PLANNER columns:
| row | before his re-sync | after |
|---|---|---|
| swim (planned 30 min @ 07:00) | `duration_minutes=30, planned_time=07:00, actual=70` | **`duration_minutes=70, planned_time=06:25`** |
| ARCOR routine (planned, open duration) | `duration_minutes=NULL, planned_time=07:00` | **`duration_minutes=7, planned_time=11:57`** — his measured start |
The coach's plan is GONE: a 30-minute prescribed swim now reads as a 70-minute plan, and a
routine with no prescribed duration now reads as a 7-minute plan. DI-7 ("completion never
writes a planner column") holds on the MATCHER path and was tested there; the provider-sync
update path was never covered. On the wire, "the coach edited the plan" and "FS attached my
actuals to the plan" are indistinguishable — which is why this needs a ruling, not a patch.

**The question:** once a row carries a measured completion, may a later provider update
overwrite its planner columns?
- **(a) Freeze the plan at completion (recommended).** After a row is completed, provider
  updates may refresh provenance/identity but never `duration_minutes`, `planned_time`,
  `distance_*` planner fields. Plan-vs-actual stays answerable forever.
- **(b) Accept provider values always** — ratify today's behaviour; the plan is whatever the
  provider currently says, and planned-vs-actual analysis is abandoned for FS/TP athletes.
- **(c) Accept only when the provider's value DIFFERS from our measured actual** (i.e. treat
  equality with our actuals as the echo signature and refuse it). Cheaper than (a) but
  heuristic; fails when a coach legitimately edits a plan to match what was done.

## F2 — FS raw capture is FROZEN AT FIRST SIGHT (contract gap)
`final_surge_sync_service.dart:65` documents identity as `(WorkoutKey, '')` — "one stored
version per workout" — and the repository is insert-or-ignore. FS has no `LastModifiedDate`,
so EVERY later version of an FS workout is silently refused. The ruled versioning contract
(L-7 item 2: a changed version INSERTS a new row; history kept) is therefore **disabled for
Final Surge**, and our FS forensic record is the first version we ever saw.
Consequence, observed: the FS payloads captured for 2026-09-21 predate Xuan's workout, so the
raw store cannot say what FS sent after its own matcher ran.
**Also an erratum against a QA conclusion:** the 2026-09-21 finding "FS sent no completion for
the swim" was drawn from these captures and is therefore UNRELIABLE — it reflects first-sight
only. Corrected in the record; the underlying echo diagnosis for Sunday's run is unaffected
(that workout's first sight WAS the echo).
**Proposed correction (mechanical, not a ruling):** derive an FS version token from the
payload itself — a content hash of the workout object — so a changed FS workout inserts a new
version row exactly as the ruling intends.

## F3 — open question the capture gap prevents answering
Does FS set `WorkoutCompleted: true` on a workout its own matcher completed? Unknown: the
captured versions predate the event. F2's fix answers it on the next sync at zero extra cost.

## Gates
- [ ] Ruling on F1 (a/b/c) → fold into `lifecycle.md` L-2 (planned/actual split) as a
      post-ratification addition naming the provider-sync path explicitly.
- [ ] F2 content-hash version token → `final-surge.md` FS-2 + the capture contract; DI-18's
      red extends to "an FS workout that changes inserts a second version row".
- [ ] Vectors: planner-column immutability after completion; FS version-token behaviour.
