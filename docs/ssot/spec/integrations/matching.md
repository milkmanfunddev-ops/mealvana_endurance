# SSOT — Integrations: workout matching & completion (incl. brick verification)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). The complete matching contract: how an incoming provider
activity finds (or fails to find) its planned row, what the completion write does, and —
the open design at its center — how a planned **brick** becomes Garmin-verified.
Contested clauses: [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). App-repo-relative paths.

> One measured session, one planned row, one upgrade — that is the contract this file
> exists to pin. Today four matchers with four different keys decide it, no guard checks
> that the measured session plausibly *is* the plan, and an entire workout class (bricks)
> is unreachable by verification.

## M-0 — The one-row invariant (cross-provider completion reconciliation) `[observed + proposed]`
One physical workout = ONE `activities` row, no matter how many platforms report it
(raised by Xuan, 2026-09-09). How the pieces already compose:
1. A TP/FS workout is keyed by `provider_workout_id` (L-1.1) — every re-sync, including
   any future completion signal or captured actuals, merges into ITS OWN row, never a
   second one. Today TP/FS completion signals barely exist in practice: FS completions
   have never been observed, and TP imports land `status='planned'`.
2. A Garmin completion targets that SAME row via the M-1 gates and stamps
   `garmin_summary_id`; L-2 keeps provider planning fields intact and preserves
   `actual_time`/`calories_burned` across later TP/FS re-syncs — so the row cannot
   revert or fork, and "verified" (= `garmin_summary_id`) is Garmin-won by construction.
3. Therefore two platforms reporting the same workout converge on one row and one
   energy count; precedence between their values is the read-time ladder (F22), never a
   second row. **Sufficiency (Xuan, 2026-09-09): the Garmin signal alone completes and
   verifies; a later TP/FS "completed" status on the same provider-keyed row changes
   nothing** (the row is already `completed`, L-2 preserves the measured actuals, and
   verified remains `garmin_summary_id`-only). Proposed as the ratified invariant: **no ingest path may create a second
   row for a workout already owned by a provider key or summary id.**
The places the invariant is genuinely violable today are already register rows: Q-INT24
(a mark-done `completed` row is unreachable by the matchers → Garmin auto-inserts a
duplicate), Q-INT23 (multisport parent + child legs all import independently), and
Q-INT4/Q-INT21 (window/guard mismatches completing the wrong row). Ruling those closes
every known double-count path.

## M-1 — The Garmin pipeline (ordered gates) `[observed]`
Source: `supabase/functions/_shared/garmin/activity_completion.ts`; identical gates in
`garmin-push` and `garmin-ping`. Per inbound activity:

| # | Gate | Conditions | Winner on multiple | Outcome |
|---|---|---|---|---|
| 0 | Tombstone T1 | `status='deleted'` ∧ `garmin_summary_id = summaryId` | arbitrary (`limit 1`, no order) | **DROP** |
| 0 | Tombstone T2 | `status='deleted'` ∧ same sport ∧ start **±15 min**; skipped for sport `other` | arbitrary | DROP |
| 1a | `other` refusal | `!sportType ∨ sportType='other'` → no matching at all (*"would let any generic planned activity get silently completed"*, `:238-243`) | — | fall to insert |
| 1b | Skipped T1 | `status='skipped'` ∧ summary-id equal — **but unreachable for `other`** because 1a sits above it (asymmetric with tombstone, whose id-tier runs before its `other` check) | `limit 1` | complete |
| 1b | Skipped T2 | `status='skipped'` ∧ same sport ∧ `deleted_at IS NULL` ∧ start **±15 min** | **earliest** in window | complete ("sync beats skip", G6) |
| 1c | Planned | `status IN ('planned','draft')` ∧ same sport (exact string) ∧ `deleted_at IS NULL` ∧ scheduled within the **naive local calendar day** — **no provider filter, no duration/distance/proximity guard** | **earliest planned row of that sport that day** | complete |
| 2 | Auto-insert | endurance sports + `other` bucket → new completed row; literal `transition` type skipped; dup by `UNIQUE(user_id, garmin_summary_id)` → 23505 → "duplicate" | — | insert |

The completion write (`buildGarminCompletionUpdate:300-406`) is applied atomically with
`.in("status", ['planned','draft','skipped'])`; race losers go to
`enrichCompletedGarminActivity` (fills null/0 gaps only, never flips status). Always
written: `status='completed'`, `scheduled_date_time` **← measured start** (bug 3a6e3fdb),
`actual_time` (naive local), `completed_at` (UTC), HR/kcal (or explicit null); distance
replaces planned **including 0** but only when reported.

### M-1.1 The known hole `[divergence → Q-INT21]`
Gate 1c has **no plausibility guard**: prod bug
`ops/data/bug-reports/2026-08-24-garmin-day-wide-matcher-overwrites-planned-workout.md` —
*"a 9-second test swim overwrote the athlete's real morning workout … ANY swim uploaded on
a day with a planned swim completes that plan."* Proposed clause (the bug report's own
suggestion, needing a ruling): **refuse the match when measured duration < 20% of planned
or < 2 min absolute**; on refusal the activity falls through to auto-insert. Thresholds
are Xuan's call → **Q-INT21**. **Corroboration tiebreaker (Xuan, 2026-09-09):** when the
candidate set ties, a TP/FS completion signal on a provider-keyed row whose timestamp
falls near the Garmin activity's start supports matching that row — a confidence booster
only, never a gate (M-0 sufficiency stands; missing/late corroboration cannot block or
downgrade a match), with a generous tolerance since provider ingestion delays run minutes
to hours. **The signature (Xuan, 2026-09-09): both records carry workout-time
timestamps, not sync-time** — Garmin's measured start + duration and TP/FS actuals'
measured start + duration describe the same physical event regardless of when each
record arrives; matching on that pair (start within ~1–2 min, duration within a few
percent — platforms round differently, and TP actuals sometimes derive from the same
Garmin file) is near-fingerprint strength, well above the date+sport heuristic.
Empirical caveat: FS completion signals have never been observed (FS-2.1) — its
`ActualTime`/`ActualDistanceMeters` fields are spec-defined but never seen populated —
so capturing the columns (Q-INT26) makes this live only if FS actually sends them;
the handback should include a one-time probe with a genuinely completed FS workout
(Xuan will run it on his own FS connection, keeping the raw payload — it also settles
whether FS timestamps carry an offset or are naive local). **Timezone caveat (Xuan,
2026-09-09):** signature comparison must not be confused by timezone representation.
Garmin is unambiguous (UTC epoch + explicit local offset); TP sends ISO strings (offset
presence unverified); FS `WorkoutDate` is documented tz-naive. Mitigation: the matcher
compares **instants** — resolving each record via its own offset when present, else the
athlete's profile timezone — while STORAGE stays naive local wall-clock per the ratified
L-9.2 convention (normalizing storage to UTC would reintroduce bug 3a6e3fdb). Defensive
heuristic: duration is timezone-immune, so candidates whose durations match within
tolerance but whose starts differ by an exact whole-hour (or half-hour) multiple are
scored as probable timezone drift, not rejected. The window itself (day-wide vs ±15) is
**Q-INT4**; the
cross-provider scope facet is `intake/2026-09-09-planned-completion-cross-provider-match-scope.md`
(unstamped, homed here), which also carries the `other`-refusal duplicate guarantee.

### M-1.2 — Trigger-based matching contract `[Xuan's design, 2026-09-10 — proposed verbatim]`
No manual-resolution UI: the matcher always decides. By trigger:
1. **Trainer-platform signal carrying a plan ID** → match by key; mark that plan
   completed; **no plausibility threshold applies** (the ID is certainty).
2. **Garmin signal** (no plan reference) → heuristic match: the M-1.1 plausibility guard
   (< 20% of planned or < 2 min → refuse) plus best-fit selection among that day's
   guard-passing candidates — closest planned slot to measured start first, duration fit
   second; a true tie (identical plans, no times) falls back to earliest-slot, never a
   user prompt.
3. **Late platform signal on an already-matched day** → acts as VERIFICATION: same
   measured signature (M-1.1) and same plan ID as the earlier heuristic match →
   confirmed; any mismatch → **revert the heuristic match and rebind per the keyed
   evidence**, the displaced activity re-scoring against the remaining open plans.
Manually-confirmed matches remain the one thing never silently moved (M-0 note); the
no-prompt rule governs automatic flows only.

### M-1.3 — Provable-fact primacy `[RULED (Xuan, 2026-09-10): the family's rule of thumb]`
**"We should always abide by what can be proved — what is undeniable fact."** A
platform-keyed or device-measured signal cannot be faked or accidentally triggered by the
athlete; athlete declarations and heuristic inferences yield to it. Concretely:
1. **Keyed completion overrides a tombstone**: if a platform reports plan-ID X completed
   while the athlete had DELETED that workout, it happened — the tombstone row revives to
   `completed` (reported done). Deletion still sticks against everything weaker: a
   provider re-sending the PLAN (a planned-status re-import, keyed or not) drops against
   the tombstone as before — the tombstone's re-import protection is untouched; only
   proven completion pierces it.
2. This principle already governs the ratified ladder: sync-beats-skip (G6), measured
   Garmin data upgrading mark-done (M-3), keyed signals bypassing the plausibility guard
   (M-1.2 t1), and late keyed evidence reverting heuristic matches (M-1.2 t3) are all the
   same rule: **fact > declaration > heuristic.**

## M-2 — FS/TP re-sync matching `[observed]`
`change_detection_service.dart`: per remote workout, in order — (0) null provider id →
ignored; (1) no provider-id hit but an `archivedForBrick` row matches by **fingerprint**
(`type|title|exact-UTC-timestamp|duration|distance` — any schedule drift breaks it) →
treated as update, *"keep provider workouts grouped in brick state"*; (2) new; (3)
provider-id hit on `status='deleted'` → **tombstone drop**; (4) significant schedule
change (>30 min, different day, Δduration >15 min, Δdistance >10%); (5) minor field
changes; (6) unchanged. Deletion scan: provider id present ∧ not in remote set ∧ not
already `provider_deleted_at` ∧ not tombstone → soft-delete (`provider_deleted_at` only —
meaning open at Q-INT5). Tombstone gate reachable **only** via provider-id — a deleted row
whose provider id changed can be re-imported.

Cross-origin dedup on insert (`activities_repository.dart:1362-1413`): user-created rows
only (no provider linkage), same type, ±1 day, distance within 10% — **latest** candidate
wins; when the incoming distance is null the distance test is skipped entirely (any
same-type row in the window matches). A second, third fingerprint definition — three
different keys across the codebase do the "same session?" job → unify under Q-INT4.

## M-3 — Manual completion & the MANUAL → GARMIN upgrade `[divergence → Q-INT24]`
Mark-done writes `status='completed'`, `actual_time = planned_time ?? scheduled ?? now`
(`activities_repository.dart:753-788`). The ratified expectation
(`platform-resolution.md:250-252`, `workout-card.md`) is that a later Garmin sync
upgrades it (MANUAL → GARMIN). **But the code cannot do it**: the matchers only search
`planned/draft/skipped`, and the atomic guard excludes `'completed'` — so a mark-done row
is never found, never upgraded; Garmin instead auto-inserts a **second** completed row.
The client-side cross-origin dedup can reconcile them later only if the local row has no
provider linkage. Proposed contract (revised per Xuan, 2026-09-10): **any completed row
without a `garmin_summary_id` — marked-done or created by hand — is an upgrade target
under a day-wide key: same sport, same local calendar day, closest start winning among
multiple candidates.** Deliberately NOT ±15 min: mark-done copies the planned slot
(frequently a 07:00 default) into `actual_time`, so a tight window would compare Garmin's
measured start against a placeholder and recreate the duplicate. The M-1.1 plausibility
guard still applies to upgrades (measured < 20% of the row's recorded duration or < 2 min
→ no upgrade; the activity imports standalone) — a stray 9-second start must not hijack a
marked-done 45-minute run. Ruling at **Q-INT24**.

## M-4 — Brick: storage model `[observed]`
A planned brick is **one parent row** (`activity_type='brick'`, `status='planned'`,
`brick_metadata` JSONB: `segment_order`, `segments[]` with per-leg sport/order(1-based)/
duration/intensity/distance/pace, `original_activity_ids`, `total_duration_minutes`) plus
its **leg rows** archived under it (`status='archivedForBrick'|'archived_for_brick'` —
both casings live, a failed rename; `brick_id` → parent). Transitions have **no row** —
they exist positionally as the gap after leg *i* (`T{i}`, ratified R8; the sport-pair
keying in code is DEVIATIONS D-008). Legs are hidden from every read path and from the
engine's queries. Brick schema exists only in an **archived** migration
(`_archived/20260120000000_add_brick_support.sql`) → Q-INT25.

## M-5 — Brick: Garmin verification `[gap → Q-INT22, Q-INT23]`

### M-5.1 What Garmin sends
A multisport session arrives as **N+1+(N−1) separate activities**: a parent
(`MULTI_SPORT`, `isParent: true`), child legs referencing it via `parentSummaryId`, and
`TRANSITION_*` legs (`docs/integration/api-exploration/garmin/activity-data.md:128-133`).

**Observed in production** (raw-payload log, 2026-08-24 → 2026-09-09, prod Supabase via
`scripts/query-ledger.sh integrations`): 3 `MULTI_SPORT` parents, **38 child legs with
`parentSummaryId`**, 0 `TRANSITION`-typed activities. Undercount caveats: the raw log
only exists since 2026-08-24 and only on the `garmin-push` path (`garmin-ping` logs
nothing), so this is a floor, not a census.

**But the dominant real-world brick is NOT multisport** — Xuan (2026-09-09, design
input): *"when doing a brick, I start each sport individually … very rarely do I use
multisport; during a race you don't have time to set them up."* A brick therefore
usually arrives as **two or more independent single-sport completed activities with no
`parentSummaryId` linkage at all** — the contract below must verify that case first,
with the MULTI_SPORT parent/child case as the secondary path.

### M-5.2 What the app does today — nothing brick-shaped
1. **A brick parent is unreachable**: `mapGarminSportType` can never return `'brick'`
   (MULTI_SPORT → `'multisport'`, a different enum value), so gate 1c never finds it.
2. **Legs are unreachable**: `archivedForBrick` appears in no matcher filter and not in
   the completable-status guard.
3. `isParent`/`parentSummaryId` are typed and parse-tested but **never read, never
   persisted** — no `parent_summary_id` column exists.
4. Only the literal `transition` type is skipped; `TRANSITION_V2`,
   `BIKE_TO_RUN_TRANSITION`, `SWIM_TO_BIKE_TRANSITION`, `RUN_TO_BIKE_TRANSITION` are
   **not in the type map** → they map to `'other'` and are **auto-inserted**,
   contradicting the code's own "transition legs are skipped" comment.
5. Net observed behaviour: a Garmin triathlon imports as a completed `multisport` row
   **plus** one completed row per child leg (or the child completes an unrelated planned
   row of its sport that day) **plus** an `other` row per transition variant — nothing
   deduplicates parent against children, and the planned brick stays `planned`.
6. Therefore a brick can reach `DONE_CONFIRMED` (manual mark-done on the parent) but
   **never `DONE_VERIFIED`** — verification is `garmin_summary_id != null`
   (`workout_state_resolver.dart:36`), and nothing ever writes a summary id to a brick.
   No test anywhere exercises brick + Garmin.

### M-5.3 Proposed contract (Xuan rules — **Q-INT22**)
Stated as clauses so the ruling can strike or amend each:

**B-1 (parent match).** A Garmin `MULTI_SPORT` parent is a completion candidate for a
planned `brick` row via the standard gates with sport equivalence
`multisport|triathlon|duathlon ≈ brick`, same-day window, subject to the M-1.1 guard
(measured total duration vs `brick_metadata.total_duration_minutes`).

**B-2 (leg verification, multisport path).** Child legs (by `parentSummaryId`) match the
brick's `segments[]` **positionally by sport order** (R8-consistent): leg *i*'s sport must
equal `segments[i].sport`. Each matched child writes its measured metrics onto the
corresponding leg row (which keeps `archivedForBrick` status) and stamps it with the
child's `garmin_summary_id`.

**B-2′ (sequential-leg verification, the primary path).** When no MULTI_SPORT parent
exists — the athlete started each sport as its own workout (Xuan's stated norm) — a set
of independent completed Garmin activities verifies a planned brick when ALL of:
(a) their sports, in start-time order, equal `segments[].sport` in segment order;
(b) each falls on the brick's day and each starts within a **gap tolerance** of the
previous leg's end (proposed: ≤ 30 min — covers T1/T2 plus real-world faff; the
tolerance is part of the ruling); (c) each passes the M-1.1 plausibility guard against
its segment's planned duration. Matched legs are stamped as in B-2; the parent is stamped
with the **first** leg's summary id (no parent id exists). Ordering rule when a
same-sport standalone plan also exists that day: the brick-sequence match is attempted
only if the single-activity gates 1b/1c found no match — alternatives: brick-first, or
brick-only-when-two-plus-legs-arrive. This sequencing is part of Q-INT22.

**B-3 (verified predicate).** The brick parent becomes `DONE_VERIFIED` when the parent
summary id is stamped AND every endurance segment has a matched child
(transitions excluded from the requirement). Partial matches (some legs) →
`DONE_CONFIRMED`-equivalent with the parent completed, never verified — alternatives:
(a) parent-match alone suffices for verified; (b) all-legs required (as written);
(c) majority-of-duration. **The condition combination is exactly Xuan's ask — options
land on the desk.**

**B-4 (transitions).** All `TRANSITION_*` variants are mapped to `transition` and
**dropped as standalone rows** (fixing M-5.2.4); their durations may be recorded into
`brick_metadata` per positional identity (T1…T(n-1)) for transition-nutrition consumers.

**B-5 (no double import).** Once a parent matches a planned brick, child legs and
transitions must not auto-insert standalone rows; when no planned brick exists, the
parent auto-inserts as `multisport` and children are folded, not inserted —
the ingestion model is **Q-INT23**.

**Schema required** (adequacy — Q-INT23/Q-INT25): a persisted `parent_summary_id` (column
or `brick_metadata` extension), per-leg `garmin_summary_id` writability while
`archivedForBrick`, and a decision on the `transition` enum value (the server's
`OurSportType` has it; Dart `ActivityType` and Postgres `activity_type_enum` do not).

## M-6 — Storage adequacy (matching & brick)
For the "right structure" question, gaps that block the proposed contracts:
1. No `parent_summary_id` persisted anywhere (blocks B-2/B-5).
2. `'transition'` absent from Dart enum + Postgres enum (any query with it 22P02s —
   today this silently disables tombstone/skip/planned matching for transition legs).
3. `'draft'` is in the matcher filters and completable statuses but **no migration adds
   it to `activity_status_enum`** — either dead or an unrecorded manual enum edit.
4. Dual brick status casings (`archivedForBrick` / `archived_for_brick`) — audit-flagged
   failed rename; every consumer must test both.
5. Brick schema lives only in an archived migration — not reproducible from the live
   migration set.
6. Three different fingerprints (change-detection, repository cross-origin, dedup
   service) implement "same session?" with different keys.
→ **Q-INT25** (hygiene batch) and per-contract rows above.

## Explicitly NOT ruled here
Q-INT4 (the window itself) and the cross-provider scope intake; Q-INT5/Q-INT6 (deletion/
skip semantics); engine-day bucketing (2026-08-20 intake); brick eligibility/composition
(`spec/domain/brick.md`); transition fuel math (`transition-nutrition.md`).
