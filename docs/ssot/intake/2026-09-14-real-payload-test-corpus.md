> **RESOLVED 2026-09-20 → Q-INT1 RULED — lifecycle.md L-7 fold, register flip; interview 2026-09-20**

# Intake — Real-payload test corpus from de-identified production payloads

**Filed 2026-09-14 (Xuan + QA). Ties into Q-INT1 (retention, DEFERRED 2026-09-10).**
**Class: ruling-request (policy gate) + a downstream capture task once ruled.**
**Home when ruled: `spec/integrations/lifecycle.md` L-7 (retention) + a new capture
clause; register row Q-INT1 (or a dedicated Q-INT29 if Xuan wants it split).**

## The problem this solves

Our mock-payload coverage can only contain shapes we have already seen. The `run-audit`
probe proved prod payload key-sets vary by activity type in ways we cannot enumerate
from a desk, and the Aug-24 FS bug was "archaeology, not a lookup" precisely because
inbound activity payloads were not persisted at the time.

**Raw-material reality — asymmetric by provider (verified 2026-09-14):**
- **Garmin — raw IS retained.** `garmin_health_data(data_type='activity_raw'/'act:'/
  'actdet:', data jsonb)` (2026-09-11 capture migration; Supabase, keyed by `user_id`,
  verbatim provider JSON per activity — a forensic log, `garmin.md` G-2.56).
- **Final Surge & TrainingPeaks — raw is NOT retained.** Both transform in memory and
  discard the payload; only the transformed `activities` row survives (`final-surge.md`
  FS-2.6 "No raw payloads are persisted for FS — transform in memory, discard";
  `training-peaks.md` TP-2 "No raw payloads persisted").

So a batch scan can build a corpus for **Garmin only**. FS/TP have no raw material at
rest — and FS is exactly the provider whose shape the hand-authored mocks got WRONG on
2026-09-14, i.e. where a real corpus would help most and where we currently retain least.
This asymmetry is the crux of the capture design below.

## What is proposed

A **sampling-and-promotion** pipeline (Garmin promotes already-stored raw; FS/TP capture
the shape inline at transform, retaining no raw — see topology below):
1. Fingerprint each payload by its STRUCTURE (key-set + types + enum values +
   null-pattern + array cardinality-bucket — e.g. "multisport parent with N children").
   Granularity is the convergence knob: too coarse misses real variation, too fine never
   converges; this level is the sweet spot.
2. Keep ONE exemplar per novel fingerprint; discard duplicates. The corpus stays small;
   every addition is a genuinely new shape. When the fingerprint set stops growing, that
   is the signal we have seen the shape space.
3. De-identify each exemplar (standard below) and emit it into the QA corpus at
   `vectors/integrations/samples/<provider>/<fingerprint>.json`.
4. These become the `inputs` half of producer-shape vectors; the expected row (oracle)
   stays SPEC-DERIVED from `field-map.md`, never copied from transformer output — else
   the corpus silently becomes characterization, not conformance.

**Capture topology — splits by provider (because raw retention does, verified above):**
- **Garmin → batch scan of stored raw.** A periodic server-side scan (e.g. nightly) over
  new `garmin_health_data(activity_raw/…)` rows. No new retention; the raw already sits
  there.
- **FS/TP → inline shape-capture at transform time; NO raw retention.** The FS/TP payload
  is already in memory during transform; in that same pass, fingerprint it and — on
  novelty only — emit the DE-IDENTIFIED skeleton directly. The raw is NEVER persisted at
  rest. This is a SMALLER consent ask than "start retaining raw FS/TP payloads" (it does
  not), and is more privacy-preserving than the Garmin path (where raw sits at rest for
  forensics). Recommended over adding raw FS/TP retention precisely to avoid widening the
  raw-data footprint.

**Cadence & immutability (design decisions, Xuan asked 2026-09-14):**
- **Novelty-gated, self-throttling either way.** Both topologies READ every payload but
  WRITE only on a novel fingerprint, so write volume decays to near-zero within weeks.
  Garmin's batch scan and FS/TP's inline hook are both off any latency-critical path
  (batch by construction; inline emits async, never blocking the sync).
- **Append-only; exemplars are frozen; new NEVER replaces old.** Same fingerprint → the
  new payload is structurally identical → discard. Different fingerprint → a NEW entry,
  not a replacement. An existing exemplar is touched ONLY to correct it (re-scrub if the
  de-id standard tightens, or fix a discovered leak) — never routine replacement. This is
  the bench-corpus discipline: a fixture edited between runs makes every comparison
  meaningless.

## The de-identification standard (the load-bearing decision)

**Proposed guarantee — de-identify the CONTENT, not merely the source.** Dropping the
user id / name / account link ("de-identify where it comes from") is NOT sufficient and
must not be treated as sufficient: the retained payload is itself re-identifying. GPS
start/route is often a home address; exact workout timestamps over a few sessions are
near-unique; HR/weight/VO2max/body-composition are personal and, combined, distinctive.
Pseudonymized ≠ anonymized. A fixture must keep the SHAPE and destroy the CONTENT:

| Payload element | Corpus rule |
|---|---|
| Structure — keys present, types, enum values, null-pattern, array cardinality | **KEEP verbatim** — this is the entire test value |
| User/account identifiers (user_id, athlete id, name, email, device serial) | **DROP** |
| GPS — start/end lat-lon, route/track/samples | **DROP entirely** (not fuzzed — removed) |
| Physiology scalars — HR, power, pace, weight, VO2max, calories, body-comp | **REPLACE with plausible synthetic values** (fuzz), preserving type/range so bucketing/ladder logic still exercises |
| Timestamps | **SHIFT to a fixed synthetic epoch**, preserving relative offsets (so multisport gaps, tz/DST behavior survive) |
| summary_id / parentSummaryId / plan ids | **REPLACE with synthetic ids**, preserving referential links between parent and children |
| Free-text (workout title, description, notes) | **REPLACE with neutral placeholder** unless structurally required |

**AMENDED (Xuan, 2026-09-20, post-land arbitration — governs the scrubber's default):**
the table's per-key census is a floor, not the mechanism. The scrubber is **DEFAULT-DENY on
content**: any key not deliberately classified keeps KEY + TYPE + null-pattern while its
VALUE is fuzzed (numeric) or placeholdered (string/other). Values survive verbatim ONLY via
a deliberate **KEEP-ENUM allowlist** (enum-bearing keys, e.g. WorkoutType-class fields,
added by name — an enum cannot be auto-distinguished from a free string). Identifier-bearing
composites (URLs with account/workout params) are values like any other: placeholdered by
default. Authority: samples-leak arbitration, `intake/2026-09-20-samples-deid-leak.md`.

Result: every scalar is fake, every structural feature is real — no living person's data
remains, only their data's skeleton. That is exactly what the transformer/matcher tests
need and carries no identity.

## What the corpus ENABLES (the point — the task is the payoff, not just having the library)

Building the corpus is the means; these five uses are the end, and the task is scoped to
deliver them, not merely to accumulate files:

1. **Real inputs for the conformance vectors.** The library is the `inputs` half of the
   producer-shape vectors (`producer-shapes.json`), replacing hand-guessed shapes — which
   already failed once: the 2026-09-14 FS mock used invented keys (`IconType`/`Name`)
   vs the real wire (`WorkoutTypeName`/`WorkoutTitle`/`PlannedDistance`). A real payload
   cannot have the wrong key. Oracle stays spec-derived; only inputs come from the corpus.
2. **A provider drift alarm.** A payload with a never-seen fingerprint = a provider
   changed something (new field/enum/activity type) or an athlete did something unusual.
   That fires an alert BEFORE it becomes a silent bug — the Aug-24 FS bug was exactly an
   unhandled shape that could not even be diagnosed because the payload was not kept.
3. **A completeness meter — the answer mock data can never give.** "Have we tested enough
   shapes?" becomes fingerprints-with-a-vector ÷ fingerprints-seen; and the corpus tells
   us when we are DONE — when the fingerprint set stops growing, we have seen the space.
4. **A self-loading regression guard.** A real user hits an integration bug → its
   de-identified payload drops in as a failing vector → fix → permanent guard. The
   department's bug-becomes-a-failing-vector-first loop, applied to integration, filling
   itself from real incidents instead of imagined cases.
5. **Offline replay for any future change.** A new capture column, a new provider, a
   transformer refactor → replay the ENTIRE real-shape library through the new code path
   offline in seconds, before shipping, with no live account needed each time.

Through-line: converts "test the shapes we know" into "know the shapes there are," and
makes the eventual real-account testing sharper (any live shape not already a known
fingerprint is immediately a finding). Payoff is gated on the corpus being BOTH
shape-complete AND content-clean — hence the de-identification standard is load-bearing,
not a footnote.

## Open questions for the ruling (Xuan)

1. **May we promote de-identified samples into the QA corpus at all?** (The purpose
   differs from the current "forensics only" retention — data collected to fuel an
   athlete, reused as a test fixture, is a new purpose even de-identified.)
2. **Does the de-identification standard above meet the bar**, or must it be stricter
   (e.g. drop timestamps entirely; whitelist keys rather than blocklist PII)?
3. **Consent posture** — is a terms/privacy line required before ANY promotion, even
   shape-only? (This is a Mealvana privacy-owner call, not QA's and not Claude's — flagged,
   not decided here.)
4. **Where scrubbing runs** — app-side job over `garmin_health_data` (raw never leaves
   the server un-scrubbed) is the safe topology; confirm.
5. **Retention of the RAW rows** — still the open Q-INT1 question underneath this: the
   corpus proposal does not require indefinite raw retention; a short raw window + a
   permanent de-identified corpus may be the cleaner answer, and would let Q-INT1 set a
   TTL it currently lacks.
6. **Do we add raw FS/TP retention, or take the inline path?** Recommended: inline
   shape-capture for FS/TP (no new raw at rest) rather than starting to persist raw FS/TP
   payloads. Confirm — this decides whether the FS/TP corpus costs a new retention
   surface or none.

## Boundaries / non-asks

- Not a request to build anything now — the de-identification standard is a POLICY gate
  Xuan rules first; the scrub job + corpus wiring follow only if ruled yes.
- Raw payloads must never leave the server un-scrubbed; Claude/QA never handles raw
  production payloads to build this (the standing "secrets/PII only via the sanctioned
  path" posture).
- Independent of the live-real-account sim testing thread (that needs real accounts +
  Xuan-owned auth); this corpus is the offline complement — together they cover
  "shapes we know" (corpus) and "shapes we don't yet" (real accounts).

## Gates (if ruled yes) — scoped to the ENABLED uses, not just the library

- [ ] Spec fold: `lifecycle.md` L-7 gains the corpus-capture + de-identification clause;
      Q-INT1 register row updated (retention window + corpus purpose).
- [ ] App: structural-fingerprint sampler, SPLIT by provider — Garmin: nightly batch
      scan of new `garmin_health_data(activity_raw/…)` rows; FS/TP: inline shape-capture
      at transform time (no raw retention). Both novelty-write only, append-only, frozen
      exemplars; scrubber implementing the de-id standard; export to the QA corpus path.
- [ ] QA corpus: `vectors/integrations/samples/<provider>/` (one frozen exemplar per
      fingerprint).
- [ ] Use 1 — producer-shape vectors: inputs = de-identified samples, oracle spec-derived
      (feeds the existing `producer-shapes.json` slice + its harness arm).
- [ ] Use 2 — drift alarm: a novel-fingerprint signal wired to notify (before silent bug).
- [ ] Use 3 — completeness meter: report fingerprints-with-vector ÷ fingerprints-seen,
      and a "fingerprint set stopped growing" convergence readout.
- [ ] Use 4 — regression loop: the intake path for a real bug's de-identified payload → a
      failing vector (the seam test carrying a sample payload transform → store → rendered
      card also closes the transform↔display join gap noted 2026-09-14).
- [ ] Use 5 — offline replay: a one-command harness that replays the whole corpus through
      the current transformers.

---

## Amendment 2026-09-14 (later) — the Garmin raw we retain is SUMMARY-ONLY; fold sample-level + HRV capture into this ruling (Xuan + Claude)

**Correction to the raw-material reality above.** The claim "Garmin — raw IS retained …
verbatim provider JSON per activity" is only *partly* true, verified live 2026-09-14
against dev `garmin_health_data`:

- **`activityDetails` samples are DROPPED, by design.** `garmin-push` receives Garmin's
  `activityDetails` webhook with `detail.samples[]` attached (the per-sample HR / speed /
  distance / cadence / power / GPS stream, ~every few seconds), but persists only
  `detail.summary` — the code says so verbatim: *"Only the SUMMARY is stored —
  ActivityDetails carries per-second sample arrays that would bloat the row for no
  diagnostic value."* Evidence: today's swim (`act:24356702044`) detail row = 618 bytes,
  and **all 73** `activity_detail_raw` rows across every user and sport are ~800 bytes,
  `has_samples=false`, `n_samples=0`. So the intra-session shape — the HR/pace/power
  curve, interval structure, per-length swim splits (we keep only `numberOfActiveLengths`,
  not the lengths) — is **not** in the corpus's raw material.
- **HRV is not captured at all.** A full scan of this athlete's rows for `hrv` returns
  empty; `user_metrics` holds only `fitness_age` (not even VO2max). Garmin's overnight
  HRV summary is simply not a type we subscribe to or store.

So the Garmin "shape space" the corpus can currently build from **excludes its richest
shapes** — activity sample streams, HRV, per-length swim data. A corpus that claims
shape-completeness while silently missing these would be a false completeness meter (Use 3).

**Proposal — a dev-only, self-scoped full-capture, ratified under THIS retention gate.**
Xuan has consented on their own account ("just keep all my data"), for **shape study
toward a potential future feature** (intra-session intensity / time-in-zone / recovery),
not immediate feature use:

1. **Dev-only, opt-in-by-owner capture** that retains the FULL raw `activityDetails`
   payload (samples included) into a distinct `data_type` (e.g. `activity_detail_full`,
   size-guarded), plus the **HRV** summary and **per-length swim** data — initially
   scoped to Xuan's own athlete id, in **dev only**. Prod `garmin-push` is untouched.
2. This is a genuine **widening of the raw-retention surface** (samples/HRV are more
   sensitive and far larger than the summaries we keep today), so it belongs under the
   same policy gate as the corpus retention decision — hence folding it in here rather
   than as a silent capture change. The **owner-consent** for the dev self-capture is
   settled (Xuan); the **corpus PROMOTION** of any de-identified sample/HRV shapes still
   rides Q1/Q3 below, and the de-identification standard needs two additions:
   **GPS route samples → DROP entirely** (already implied) and **the sample time-series →
   fuzz every physiological scalar per the table while keeping cadence + array length**
   (the array cardinality *is* the shape).
3. Payoff for the corpus specifically: it unlocks producer-shape vectors and the drift
   alarm for the *sample* layer (Uses 1–2), and lets the completeness meter (Use 3)
   honestly cover intra-session shapes instead of quietly excluding them.

**Added open questions (for the same ruling):**
7. **Do we widen raw retention to sample-level + HRV at all** (vs. summary-only forever)?
   The dev self-capture answers "yes for shape study on the owner's own data"; the
   question for the ruling is whether it graduates beyond dev/self, and under what TTL
   (ties Q5 — a short raw window + permanent de-identified corpus is likely the answer for
   the bulky sample streams especially).
8. **De-id standard for sample streams + HRV** — confirm the two additions in (2): GPS
   sample points dropped, physiological sample scalars fuzzed while array cardinality and
   time-cadence are preserved verbatim (they carry the shape).

**Added gate (if ruled yes):**
- [ ] App (dev-first): `garmin-push` retains the FULL `activityDetails` (samples), HRV
      summary, and per-length swim data under a new size-guarded `data_type`, owner-scoped
      in dev; the scrubber's de-id standard is extended to sample streams + HRV per Q8;
      one exemplar per novel *sample-layer* fingerprint promotes to the corpus.

**Boundary reaffirmed:** the dev self-capture stores Xuan's own raw on the dev server;
Claude never handles the raw sample/HRV payloads to build the corpus (same sanctioned-path
posture as the rest of this intake). Prod remains summary-only until the ruling says otherwise.

---

# ADDENDUM — 2026-09-17/18 (QA, session qa-33): the corpus now has a proven, dated cost

This intake argued the corpus from a near-miss (the Aug-24 FS archaeology, the hand-authored FS
mocks corrected 2026-09-14). It is no longer hypothetical. In one afternoon of probing the live
TP API (`scripts/tp-payload-probe.sh`, route A — Xuan runs it, token never leaves his shell), the
absence of a corpus produced **four wrong artifacts and two wrong theories**, all inside the
`data-integrations` family:

1. **A ratified capture contract that cannot execute.** TP sends `TssPlanned`; the app reads
   `TSSPlanned` (`training_peaks_transformer.dart:326`, `:712`). `tss_planned` is structurally
   dead for every athlete, and the ratified `payload-usage-map.md` §7.1 TSS/hr bucketing rung has
   **never once executed** — so a workout named "Endurance Ride" is priced by its name.
   Ops bug: `ops/data/bug-reports/2026-09-17-trainingpeaks-tss-planned-key-casing-never-populates.md`.
2. **Four QA vectors that pinned the defect as the contract.** Every `training_peaks` row in
   `vectors/integrations/producer-shapes.json` fed `TSSPlanned` in its INPUT, so each ran GREEN
   against the mis-cased parser and would go RED when the bug is fixed. One also invented a
   `Structure` field. All four are now `status: blocked-fixture-unvalidated` (qa `df9b693`). They
   were authored from our own `docs/integration/api-exploration` samples — the failure mode this
   intake predicted, committed by QA one day after QA documented it.
3. **A spec drafted from a payload one-third the real size.** The live TP list object has **47
   keys**; `payload-usage-map.md` §1 was written from a ~15-key sample. Never mentioned anywhere
   in the spec: `TssCalculationMethod`, `NormalizedSpeed`, `VelocityPlanned/Average/Maximum`,
   `Energy`/`EnergyPlanned`, `TempAvg/Max/Min`, `TorqueAverage/Maximum`,
   `CadenceAverage/Maximum`, `ElevationAverage/Loss/Maximum/Minimum`, `DistanceCustomized`,
   `Completed`, `LastModifiedDate`, `Url`. **Q-INT26's "every DISCARDED and UNHANDLED field gets
   a per-source column" was therefore ruled against an inventory missing two thirds of the
   payload** — the capture shortlist cannot be called complete until §1 is re-drafted from a real
   object.
4. **A ruling that may have no reachable input.** Q-INT29 (RULED 2026-09-17, structure-parsed-only
   zone splits) presumes a `Structure` reaches us. The wire says otherwise: absent from the range
   endpoint AND from `/v2/workouts/id/{id}` for a workout TP itself derived IF 0.85 / TSS 42 from
   in its own builder. Two theories died on that same evidence — our parser (no: the keys are
   present and null) and premium/tier gating (no: same account shows the numbers on screen and
   nulls on the wire). See `runs/2026-09-17-tp-structure-shape-probe.md`.

**The generalised lesson, now an invariant** (`docs/feature-test-plans/data-integrations.md`
DI-13c): a null that is indistinguishable from a legitimately-null field can never be caught from
inside the app — only a wire read separates "the provider didn't send it" from "we asked for the
wrong key". Every capture contract needs a POPULATED twin asserted through the real repository,
and its fixture must be a real payload or be marked hand-authored and never be the only evidence.

## Consequence for sequencing (the reason this addendum exists)
`data-integrations@v1.1` was being ruled on guessed shapes. Xuan's call 2026-09-18: **corpus and
producer-shape vectors ship FIRST**; v1.1 keeps only the work that needs no corpus (the casing
erratum, subtype-is-title, invented distance, DI-13c, the FS-unobservability correction), and the
zone semantics + the IF/TSS engine feed (DI-17) wait for corpus-backed vectors. The dependency is
strictly ordered: corpus → re-authored vectors → rulings.

## Capture priority list — the shapes v1.1 and its successor are still GUESSING
Ordered by what each unblocks. Every row is "we have never seen this payload" unless noted.

| # | Payload | Endpoint / source | What it decides | Blocks |
|---|---|---|---|---|
| C1 | **TP structured workout, any route** | `/v2/workouts/wod/file/{id}?format=json\|mrc`, `/v2/workouts/plan/{id}` — the hunt is written into `scripts/tp-payload-probe.sh` and NOT yet run | Whether a `Structure` is reachable AT ALL for our OAuth app. If not, Q-INT29 is a no-op for TP, its sub-questions 1–3 evaporate, and zones stay null by provider capability | Q-INT29; the whole zone slice |
| C2 | **A TP payload carrying populated `IFPlanned`/`TssPlanned`** — candidate: a COACHED/premium athlete's planned workout (athlete `1167912` is coached; its completed run carries `IF` 0.9606 / `TssActual` 53, both correctly cased) | same list endpoint, different athlete | Whether Q-INT26 §6.2 is achievable at all, and whether the casing fix changes any number. Today: keys present-and-null on every planned workout seen, so the fix is correct but inert | DI-17 (IF/TSS engine feed); the casing fix's acceptance test |
| C3 | **TP completed workout** (exemplar already observed: id `3953753751`) | list endpoint | The actual-side capture path end-to-end — the only populated load fields we have ever seen. Promote as the first real TP exemplar | DI-13c populated twin; `if_actual`/`tss_actual` |
| C4 | **The 47-key inventory itself** (planned + completed + strength variants) | list endpoint | Re-drafting `payload-usage-map.md` §1 and re-scoping Q-INT26's capture list against a true inventory | Q-INT26 completeness; `field-map.md` §2 |
| C5 | **FS structured detail (`json_fs_v1`)** | the per-workout `urls['json_fs_v1']` link (`final_surge_sync_service.dart:220`, fetched only when flagged) | Q-INT29 sub-question 4: FS steps carry ABSOLUTE watts/bpm/pace while §7.3's thresholds are fractions — which athlete threshold converts them, from which source. No vector can exist until we see one | Q-INT29 sub-q 4; FS zone splits |
| C6 | **FS `UpcomingWorkouts` real object** | `/API/v1/UpcomingWorkouts` | Our FS mocks were already wrong once (corrected 2026-09-14 from `WorkoutTypeName`/`WorkoutTitle`/`PlannedDistance`); the remaining FS producer-shape vectors rest on the corrected guess, not on a payload | the FS producer-shape rows (currently NOT quarantined — they may deserve it) |
| C7 | **TP athlete zones** | `/v1/athlete/profile/zones` (`training_peaks_api_client.dart:505`) | The threshold-relative conversion Q-INT29 sub-q 1 and Q-INT19/Q-INT28 need: what a real zones object contains (LTHR? threshold pace? FTP?) decides whether `percentOfThresholdHr`/`percentOfThresholdPace` can ever be bucketed | Q-INT29 sub-q 1; Q-INT19; Q-INT28 |
| C8 | **TP events / `Goals[]`** | `/v2/events/next`, `/v2/events/{date}` | Race-flag prefill (capture shortlist item 10). Partially observed in probe B (2026-09-13, `Goals[]` populated, horizon ≥34 d) but never captured as a shape | shortlist 10; event-page prefill |
| C9 | **Garmin multisport parent + children** | already retained raw: `garmin_health_data(data_type='activity_raw')`, written by `garmin-push/index.ts:294` | `parentSummaryId`/`isParent` linkage for brick verification B-2/B-5. **Cheapest row on this list — promotion only, no new capture** | Q-INT23; brick matching |
| C10 | **Garmin unhandled push types** (hrv, pulseOx, respiration, healthSnapshot, bloodPressures, skinTemp) | `garmin-push` | Shortlist item 8 — shapes unknown, so the columns they would land in are unspecified | shortlist 8 |
| C11 | **Runna `.ics` feed + VDOT workout object** | `runna_ics_client.dart`; `/v1/vdot-workouts/{from}/{to}` | The `SUMMARY`-keyword parse (§7.5) and VDOT's step targets are both documented from code reading, never from a captured feed | §7.5; Q-INT15 sport mapping |

**Not capturable, record as such:** FS completion (`ActualTime`/`ActualDistanceMeters`) — proven
structurally unobservable for our tenant 2026-09-13 (both past-workout endpoints 404; folded as
an erratum into `final-surge.md`). TP `/v2/metrics` (weight/HRV) — premium-gated, NOT-FETCHED.

**C1 and C2 ANSWERED 2026-09-18** (qa-70, `runs/2026-09-18-tp-structure-hunt.md` +
`runs/2026-09-18-tp-premium-trial-probe.md` on `qa/real-payload-corpus`):
- **C1 — closed, negative and tier-independent.** `Structure` is unreachable under our OAuth grant:
  `wod/file?format=json|mrc` 401 (scope refusal), `plan/{id}` 405 to GET, absent by id — identical
  results on a PREMIUM token against premium-built structured workouts. Residuals stay honest: 401
  is not-for-this-grant (a file-export scope may be grantable — provider relations), 405 is
  wrong-method. Q-INT29's disposition is on qa-70's desk brief, not stamped.
- **C2 — answered, and it inverted a finding.** Premium-trial (`6635555`) and training-plan
  (`4297587`) athletes DO receive populated `IFPlanned`/`TssPlanned`; Lee's basic account does not,
  with an owner token, on the same calls. **Account state decides exposure — and `IsPremium` is NOT
  the predicate** (it reads FALSE on the premium-featured trial). **CONFIRMED 2026-09-18 by the
  controlled mirror experiment (qa-70 `26a59ec`): the same hand-typed planned-TSS workout built on
  Lee's BASIC calendar returns `TotalTimePlanned 1.0` with NULL TSS/IF, where the trial account's
  identical specimen delivers 55.0/0.8 — so it is per-ACCOUNT, not per-workout-source and not
  derived-vs-stored.** Mechanism left open (API withholds vs TP drops the typed value at save);
  the capture consequence is identical. **This makes C2 a prerequisite of the DI-13c invariant
  itself**, not only of the vectors: a populated-path assertion cannot be written against a
  basic-account fixture, because no basic-account payload can carry the field. Consequence outside the corpus:
  the `TssPlanned` casing bug is **live data loss**, not a dormant defect — 21 populated workouts
  synced to prod on 2026-09-18 and every value was discarded.
- New shape facts for the fingerprint rule: key-set spread 46/47/48 (`PreActivityComment` joins
  `Description` as a per-instance dropout — optionality is per-instance, not per-sport), and
  `/v2/events/next` returns a full OBJECT or a BARE STRING. **Corrected 2026-09-18 (four-cell
  matrix, qa-70 `f878705`): the variant tracks WHETHER AN UPCOMING EVENT EXISTS, not account
  state** — the two-athlete reading was a coincidence of one athlete having no event yet.
  `/v2/events/{date}` is a LIST in all four cells, so only `/events/next` varies its root type.
  `Goals` cardinality varies 0–3. C7 zones: 200 under the existing grant, per-athlete
  substructure variance. `metrics:read`: scope-refused, now evidence rather than assumption.
  Token life bracketed at ~30 minutes.

**Sequencing note for whoever works this branch:** C1–C4 are all TP list/id reads that one probe
run can capture together, and C9 needs no provider call at all. C1 is the single highest-value
row: it decides whether an entire ratified ruling has any input. C2 needs a second athlete, so it
is the one that may need Xuan to connect a coached/premium account.

**Boundary unchanged:** Claude does not read provider tokens. `scripts/tp-payload-probe.sh` is run
by Xuan; the token stays in his shell and only a field audit (key sets, presence/casing, unit
strings — never a raw body) comes back into the session. Promoting any of the above into the repo
as an exemplar requires the de-identification standard in this intake and the Q1/Q3 ruling.

---

## ADDENDUM 2 — 2026-09-18 (QA, session qa-70): design corrections from the first real objects

**C-list status:** C1 **ANSWERED** — a TP workout structure is unreachable under our current
OAuth grant (range, by-id with the owning athlete's token, `wod/file` 401 = scope refusal,
`plan/{id}` 405 to GET; evidence `runs/2026-09-18-tp-structure-hunt.md`, residuals recorded
there; disposition is its own ruling-request,
`intake/2026-09-18-q-int29-tp-disposition.md`). C3/C4 **partial** — three planned TP variants
(run / bike / strength) captured as field audits, the completed-run shape observed 2026-09-17.
C2 **open** — needs a coached/premium athlete (Xuan's connect). C9 **material confirmed** —
prod `activity_raw`: 3 `MULTI_SPORT` parents, 38 children with `parentSummaryId` (dev: 0);
promotion still gated on Q1/Q3.

### 1. The fingerprint needs a three-state key alphabet
Evidence (2026-09-18, same endpoint, same day): the Strength object has **47 keys including
`Description`**; the run and bike have **46 keys without the key at all**, while the load
fields are present-and-null on every object. So "the provider omits a field" has **two
distinct wire forms — KEY ABSENT and KEY PRESENT WITH NULL — and TP uses both, per instance,
not per schema.** Corrections to the fingerprint definition above ("key-set + types + enum
values + null-pattern + array cardinality-bucket"):

- **RULED A (Xuan, 2026-09-20, stage-4 ambiguity resolution — supersedes the collapse
  wording below):** stratum-classed optional keys drop out of fingerprint identity
  ENTIRELY (value, null, or absent — all one shape); the collapse line below is the
  superseded narrower form, kept for the trail. Load keys are unaffected: never absent,
  never optional-classed, so NULL-vs-VALUE still splits identity.
- Per key, the observation records one of **ABSENT / NULL / VALUE(type)**. The proposal's
  null-pattern already separates NULL from VALUE; ABSENT is the missing third state.
- **Fragmentation guard:** fingerprints are computed within a **stratum** (endpoint ×
  `WorkoutType`, or the provider's sport-equivalent discriminator). A key observed both
  ABSENT and non-ABSENT across instances of one stratum is classed **optional**, and optional
  keys collapse (ABSENT ≡ NULL) for fingerprint IDENTITY while the stored exemplar audit
  stays three-state. Without this rule, one workout-that-happens-to-have-a-description is a
  novel shape forever and the convergence meter (Use 3) never converges — or lies.
- **Open empirical question the corpus itself must answer — do not pre-decide it:** does key
  dropout track the SPORT, or the OPTIONALITY of the underlying value? (The Strength object
  *had* a description and the run did not, so the second, less obvious explanation is live.)
  The optional-classing rule above is robust to either answer; this flag exists so nobody
  hardens a sport-keyed rule on one day's evidence.

### 2. Vector-schema requirement (promoted beyond fingerprinting)
Re-authored producer-shape vectors must encode **ABSENT vs PRESENT-NULL distinctly in their
INPUTS — in the schema, not in prose.** DI-13/DI-13c's "a provider omitting a field" is two
cases, and the quarantined TP vectors encode neither (vectors-side record: the v1.1 vectors
note, qa `e336f6b`). The corpus half of the same requirement: exemplars preserve the
distinction verbatim — **nulls and absences are structure** under the de-identification
table's "KEEP verbatim" row.

### 3. Suspect-source rule for `docs/integration/api-exploration`
Both the ~15-key §1 draft and the four quarantined TP vectors trace to that app-side sample
set. Proposed rule: those docs are **suspect input, never reference**. If the corpus is ruled
yes, they are regenerated from exemplars or stamped historical; until then, any artifact
citing them carries a provenance flag.

### 4. The granularity claim, corrected
"This level is the sweet spot" was argued from a ~15-key object one-third the real size. It
is replaced: granularity is the three-state alphabet + optional-collapse + stratum rule of
§1, and the sweet-spot **claim** becomes a convergence **criterion** — the knob is right when
per-stratum fingerprint growth stops while exemplar counts keep rising. First datum: the
46/47 `Description` dropout.

**Added gate (if ruled yes):**
- [ ] `docs/integration/api-exploration` regenerated from corpus exemplars or stamped
      historical; provenance flags on artifacts citing it in the meantime.

(Units facts from the same run — `TotalTimePlanned` in decimal hours, `DistancePlanned` in
meters — are C4/field-map re-draft material, recorded in the run file, not duplicated here.)

---

## ADDENDUM 3 — 2026-09-18 (qa-33 + qa-70): per-account exposure makes C2 a prerequisite of DI-13c itself

The mirror experiment (`runs/2026-09-18-tp-premium-trial-probe.md`, qa 26a59ec) proved TP
planned-load exposure is per-ACCOUNT even for hand-typed values: a basic account's payload
can never carry `IFPlanned`/`TssPlanned`. Consequence: **DI-13c's populated twin — "a
payload that CARRIES the field produces a non-null column" — is unwritable for these
fields without an account-gated exemplar.** C2 is therefore a prerequisite of the
INVARIANT, not merely of the producer-shape vectors, which raises its rank in this
intake's own ordering — and makes the premium trial's lifetime (expires ~2026-10-02) a
constraint on the invariant landing. The trial's four specimens are the exemplar
candidates; their promotion still rides the Q1/Q3 de-identification ruling, which is one
more reason this ruling should not wait.

Mechanism footnote (pending one glance at Lee's calendar card): if the basic account's
typed TSS *displays* on the card, TP stores it and the API withholds — a scope/permission
conversation with TP could recover it; if the card is blank, TP dropped it at save — the
data does not exist to be asked for. Capture contract wording is identical either way.
