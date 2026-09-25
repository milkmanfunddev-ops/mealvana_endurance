type: ruling-request
bundle: NONE YET — this file IS the scope of the next bundle (provider-reconciliation).
        EXPLICITLY EXCLUDED from fix/1.27.1 (Xuan, 2026-09-21).

## Why this file exists
A day of live investigation on Xuan's own accounts produced a coherent family of defects and
rulings about how PROVIDER signals (Final Surge, TrainingPeaks) reconcile with DEVICE signals
(Garmin). Xuan's call 2026-09-21: this area gets its OWN ratification pass and its own bundle
— not a rider on the imminent bugfix release — because every conclusion so far is drawn from
Final Surge alone, and the TrainingPeaks half is unexamined (see OPEN-1). One index file so a
future QA session can pick the whole family up without re-deriving it.

## A · ALREADY RULED (Xuan, in-session 2026-09-21) — carried into this bundle, not re-opened
- **R1–R5**, `intake/2026-09-21-keyed-completion-reconciliation-ruling.md` (RESOLVED):
  born-completed · attach-never-insert · device-wins · retro-match on provider arrival ·
  tolerances (same local day, start ±90 s, duration ±2 %).
- **Release scope**: the keyed-completion slice is its own seam-tested slice, never a bugfix
  rider — re-affirmed 2026-09-21 and now widened to this whole family.

## B · RULED IN SUBSTANCE 2026-09-21, to be FOLDED with this bundle's ratification
(Xuan's stated positions in the reconciliation interview; recorded here so the fold is his
act at ratification time, not a QA self-ratification now.)
1. **No duplicates, absolutely.** Once a device signal has established a workout at a start
   time and duration, no provider row may occupy that same start+duration — whether by
   inserting (Sunday's echo) or by mutating a different row into its shape (today's ARCOR).
2. **Strength and mobility become FIRST-CLASS sports.** FS's `Strength Training` must be kept
   as strength, never flattened to `other` — the flattening is what made the ARCOR duplicate
   inevitable (see C-2). Converges with the pending
   `intake/2026-09-17-strength-and-mobility-as-first-class-sports.md` and the strength/mobility
   ship Xuan has already ruled gets its own release.
3. **Provider pairings are EVIDENCE, never truth.** Accept a provider's pairing only when we
   have none of our own: a provider guesses with strictly less context (no cross-provider
   calendar, no history). Structural justification: for non-structured workouts no keyed link
   can exist (`HasStructuredWorkout=False`; FS cannot push an ARCOR routine to the watch), so
   EVERY such pairing — theirs and ours — is inference.
4. **Ordering is a fast path, never a correctness premise.** Garmin-before-provider held in
   both observed cases, but webhook retries, a healed-then-backfilled connection, or a
   non-Garmin source break it; R2+R4 are order-independent by construction and stay that way.
5. **Completion discriminator**: `ActualTime` / `ActualDistanceMeters` present, or
   `WorkoutCompleted: true`. NOT "has a start time and a duration" — every coach-written plan
   has those (FS plans carry `planned_t=07:00` + durations). Secondary tell: sub-hour precision
   on the start (plans are round; measurements are not).
6. **Athlete's last word — AGREED IN PRINCIPLE, HELD OUT OF SCOPE** (Xuan, 2026-09-21): an
   undoable pairing ("this wasn't my ARCOR routine") is the right end state and honours the
   ruled no-prompts posture, but it is an interface change and belongs to a design
   ratification, not to this bundle.

## C · FILED DEFECTS in this family (all evidenced on live accounts)
1. `intake/2026-09-21-provider-plan-mutation-and-fs-capture-freeze.md` —
   **F1** provider-side matching DESTROYS our planned record (a coach's 30-min prescribed swim
   now reads as a 70-min PLAN); ruling options (a) freeze-at-completion (recommended) / (b)
   accept always / (c) refuse-when-equal-to-actuals — **still unruled, belongs to this bundle**.
   **F2** FS raw capture is frozen at first sight (`(WorkoutKey, '')` identity + insert-or-ignore),
   disabling the ruled versioning contract for FS; fix = content-hash version token.
   **F3** does FS set `WorkoutCompleted` on a workout its own matcher completed — unanswerable
   until F2 is fixed.
2. **The `other` refusal's revisit trigger HAS FIRED.** `matching.md` tier 1a refuses matching
   for sport `other` outright; `intake/2026-09-09-planned-completion-cross-provider-match-scope.md`
   (RESOLVED 2026-09-10) says in terms: *"the matcher refuses `other` outright — so such a plan
   can never be completed, and a duplicate is guaranteed rather than merely likely"*, ruled
   "keep the refusal, **revisit after the guard lands**". The plausibility guard landed
   2026-09-14; ARCOR (2026-09-21) is the predicted duplicate. Revisit belongs here.
3. `ops/data/bug-reports/2026-09-21-provider-completion-echo-imports-as-planned-never-reconciled.md`
   (Major) — the Sunday echo; the keyed decision path is vector-green with ZERO production
   callers (the reachability doctrine's founding case).
4. **Unruled and still open**: near-zero-duration measured session pricing
   (`intake/2026-09-17-measured-near-zero-duration-session-pricing.md`) — Xuan left it optional
   for 1.27.1; with this exclusion it rides this family or the strength/mobility ship.

## D · OPEN QUESTIONS this bundle must answer (not yet investigated)
- **OPEN-1 (the big one): is TrainingPeaks the same?** Every conclusion above is drawn from
  Final Surge behaviour. TP's echo/mutation behaviour is UNEXAMINED. Specifically: **Coach
  Claudia's reported duplicate workout** may be this same family on the TP side — it must be
  investigated before the contract is ratified, or we will ratify a one-provider contract.
- **OPEN-2**: may a workout with NO prescribed duration be matchable at all? Today the
  plausibility guard cannot protect it (nothing to compare against), so a 30-second accidental
  start would credit an open-ended routine exactly as a real session would.
- **OPEN-3**: when a provider's pairing disagrees with ours on the same activity, and both are
  heuristic, what is recorded — ours, with theirs as provenance? (B-3 proposes ours wins.)
- **OPEN-4**: the merge shape for the ARCOR case — one row carrying plan identity + frozen plan
  values + measured actuals + BOTH provider keys; which physical row survives, and what happens
  to the absorbed one (tombstone vs delete).

## E · What this bundle must NOT repeat
- A ruled decision path with no production caller (reachability attestation required).
- A rule derived from one provider and ratified as universal (OPEN-1 exists for this reason).
- Vectors pinning absolute session-kcal values while the F22 BMR amendment is unshipped.
