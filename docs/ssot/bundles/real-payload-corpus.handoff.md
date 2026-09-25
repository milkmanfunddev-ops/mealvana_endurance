# Handoff — real-payload-corpus@v1 (frozen 2026-09-20)

Implementer: **Xuan's app coding session** ($APP_ROOT via `workspace.env`/`find_workspace`).
Authority order: `bundles/real-payload-corpus.yaml` (manifest) → this handoff →
`spec/integrations/lifecycle.md` L-7 + the ruled corpus intake → the vectors' `note` fields.
`done_when` (manifest, verbatim) is the definition of done. Load the postgres best-practices
skill before any schema work. No previous version → no deferred ledger carried.

## Hard date
**~2026-10-02 (TP trial expiry).** The trial's four specimens are the ONLY payloads that can
ever satisfy DI-24's populated twin for planned-load fields, and they exist nowhere at rest.
**Sequence: provider_raw_payloads migration + ONE sync of the trial account FIRST** — before
the scrubber if necessary. Everything else can follow.

## Build items (detail: `intake/2026-09-20-handback-corpus-rulings.md`, folded here by reference)
1. `provider_raw_payloads` — UNIQUE (provider, provider_workout_id, last_modified); changed
   lm INSERTS (history kept), unchanged writes nothing; `user_id REFERENCES users(id) ON
   DELETE CASCADE` (W2); RLS per the VERIFIED garmin_health_data posture (W4); server-only.
2. Phone→server raw upload in FS/TP sync — async, never blocking (old clients simply don't
   upload; see W6).
3. pg_cron sweep (FIRST scheduled DB job — W1): purge strictly-older-than-90d per row across
   provider_raw_payloads + garmin raw/sample types; audit row per run (sizes + counts);
   two-sided alerts (over-size 2 GB/60%-plan · under-arrival per `expected_flows`); corpus
   novelty is NOT a flow; **the sweep body is a callable function with `now` injected** or
   DI-18/19 are untestable.
4. Dead-man: client-side check during sync — newest audit row > 48 h → Sentry warning.
5. Scrubber + fingerprint as **pure functions** (payload→skeleton; payload→identity), per
   the vectors' property notes; fingerprint identity EXCLUDES optional-classed keys (ruling A).
6. Corpus export: novelty-gated, append-only, frozen exemplars →
   `qa/vectors/integrations/samples/<provider>/<fingerprint>.json`.
7. Sample/HRV prod graduation in garmin-push under a REAL size guard (W7 — today a comment).
8. IsPremium A1 re-key: ungate metrics fetch (handle 401), write-back eligibility from TP's
   actual response, column re-documented. Casing fix ships under its own ops-Critical ticket.
9. Test-plan rows DI-18..24 flip per the plan's rules; superseded pins in W5 flip red-first
   with commit messages citing the spec change.

## Conflict watchlist (recon 2026-09-20, `bundles/real-payload-corpus.recon.md` — verified, not recalled)
W1 first-ever pg_cron (extension + local-CI story) · W2 CASCADE FK or new orphan surface ·
W3 disconnect hard-purge must cover the new table (Q-INT2 application) · W4 RLS posture
unverified — verify then replicate · W5 superseded test pins (`training_peaks_transformer_test.dart`
casing fixtures; `manual_live/training_peaks_api_test.dart` IsPremium; sweep
`intensity_distribution_test.dart` before assuming) · W6 mixed fleet → expected_flows are
SELF-ARMING (arm on first-ever row; never key on last_sync_status) · W7 size guard is a
comment, not code · W8 deploy order: table → clients → cron → flow seeding (seeding first
instant-alerts); alert email reuses the send-nutrition-plan-email pattern.

## Producer/consumer inventory (stage-6b item 7 — every field the new surface reads/writes)
| Field | Producers | Shapes actually written | Existing consumers + resolution | New consumer's rule |
|---|---|---|---|---|
| `provider_raw_payloads.data` | phone FS/TP sync (NEW) | verbatim provider JSON; TP list objects 46–48 keys, key sets vary PER INSTANCE (optional dropout); FS shape UNSEEN until first capture | none today | sweep deletes by fetched_at only; scrubber treats null-vs-absent as STRUCTURE (DI-20); census counts only |
| `garmin_health_data` raw/sample rows | garmin-push (server) | summary-only today (~800 B detail rows, `n_samples=0`); samples ADDED by this bundle, size-guarded | run-audit arm (today-only reads ✓); forensic ad-hoc queries | **the sweep is a NEW DELETING consumer of rows nothing ever deleted** — any playbook assuming indefinite raw now has a 90-day horizon; forensics beyond 90 d = the corpus |
| `integrations.provider_is_premium` | TP OAuth connect (once) | 0 true / 2 false / 9 null in prod — never true, never re-captured | three gates (BEING REMOVED) | observation only; NOTHING branches on it (ruling A1) |
| `expected_flows` rows | seeding migration + future rulings | `(flow, precondition, min_rows, window)`; preconditions read active-connection counts | sweep (sole reader) | self-arming (W6); novelty excluded by name |
| sweep audit rows | the sweep | one row/run: per-table sizes + counts | dead-man client check; query-ledger liveness arm | the freshness of THIS row is the liveness signal for everything else |
| `tss_planned`/`if_planned` | transformers (casing fix, ops ticket) | decimal, PER-ACCOUNT exposure (basic = null even hand-typed) | F22 ladder reads via DI-17 — **v1.1 scope, NOT this bundle** | this bundle only counts populated rows (census flow); no engine feed here |

Seam rule: every stored-vs-recomputed seam gets a test fed PRODUCER-shaped data (the wire's
casing and rounding), tolerance + log, never hard asserts (app docs/test/README.md §seam tests).

## Baseline (step 4c — asked and answered)
A ruled number exists and its before-picture is ALREADY frozen: populated
`tss_planned`/`if_planned`/zone counts are **0 across both environments**, documented with
protocol in `runs/2026-09-17-tp-structure-shape-probe.md` (zones-audit table) — that IS the
baseline. Re-run `scripts/query-ledger.sh zones-audit all` post-implementation and report the
delta; synthetic traffic is already identifiable by the 'QA zone probe' title prefix.

## Out of scope (named in the manifest)
Producer-shapes re-authoring · pace-vs-threshold rung · TP metrics/file-export capture
(blocked-on-provider) · DI-17 engine feed. No user-facing surface changes → no sim-explore
charter (write-back gating change is behavioral, not visual).

---

## Addendum — 2026-09-20 (post-ship, same day): DO-FIRST complete via a route change

**DI-24's live populated twin is OBSERVED on dev** (app-a9, feature/real-payload-corpus off
release/1.27.0): 4 provider_raw_payloads rows through the real path (sync → capture upload →
table), all with TssPlanned+IFPlanned as numbers; the completed row carries TssActual+IF (C3).

**Route change, superseding this handoff's hard-date framing:** the prod trial couldn't log
into sandbox (Saturday copy drops credentials), so a NEW sandbox athlete (Xuan's,
xuan@mealvana.io) was created — sandbox signup grants its own 14-day premium trial, renewable
after every Saturday wipe, no prod exposure, dev app already points there. The prod trial's
four specimens are NO LONGER the only possible exemplars; **~2026-10-02 is no longer
load-bearing.** PROVENANCE REQUIREMENT carried forward: exemplars promoted from these rows
are stamped `sandbox-host + hand-typed-values`.

**Evidence bonus:** the Description key-dropout reproduced ON DEMAND (typed a description
only on the strength workout; the key materialized only there — 48 vs 47 keys, same day,
same endpoint). First controlled datum for Addendum 2's open sport-vs-optionality question:
points at OPTIONALITY-OF-THE-VALUE. The corpus's own convergence analysis remains the
decider; noted, not ruled.

**Ownership answer (asked by app-a9):** `run_dart.sh` harness arms = the implementer's, on a
qa branch (harness/engine co-evolution per the manifest note). `query-ledger.sh` size-audit +
liveness arms = QA's (qa-70) — added once the audit table's migration lands and names it.

## Addendum 2 — 2026-09-20 (later): all three slices GREEN; two implementation conventions recorded

`run_dart.sh` green: raw-retention 7/7 (local-db arm applies the app's migration files
byte-identical into ephemeral supabase-local Postgres, drives `raw_retention_sweep` at the
vectors' synthetic clocks — W1's local-CI story CLOSED) · corpus-fingerprint 7/7 ·
corpus-deid 3/3. With DI-24 observed, the manifest `done_when`'s conformance legs are met;
the remaining legs are app-a9's tail list (dead-man client check, W3 purge extension, W5
pin flips, IsPremium re-key, pg_net email leg, zones-audit delta + DI-row flips).
Land-bundle re-runs every slice on the MERGED state (qa/real-payload-corpus +
qa/real-payload-corpus-harness, 3cd580e local) as its hard gate — greens here are the
implementer's claim, re-proven at landing.

Conventions adopted in implementation (flagged in code, contradicting no vector):
1. **Fingerprint array values carry a cardinality BUCKET** (0 / 1 / few≤10 / many) per the
   intake's cardinality-bucket knob; the boundaries are convention and Addendum 2's
   convergence criterion arbitrates them.
2. **De-id offset sign**: `offsetSeconds = between[1] − between[0]` — derivable from the
   garmin vector's own values. (The first harness draft had it backwards and the vector
   caught it: expected-red doing its job before merge.)

## Addendum 3 — 2026-09-20 (pre-land sweep, qa-70): READY FOR LAND-BUNDLE

Tail complete (app 6 commits to 57d2db55→bfceb8bf; qa harness 3cd580e..7c0c3fb; flips
fd06bde off this branch). QA second readings:
- **The first four exemplars PASS the de-id review** (samples/training_peaks/, frozen,
  novelty gate live-proven: duplicate run scanned 4 / novel 0): 47-key inventory, no
  identifiers/GPS/emails, synthetic 2026-01-01 epoch with offsets preserved (negative
  offsets fine), load values fuzzed away from BOTH the typed and derived originals,
  actuals verbatim-null, provenance stamped sandbox-host + hand-typed. (One scan false
  positive worth recording: 'lat' ⊂ TssCalcuLATionMethod.)
- **DI-18..24 flips shape-correct** (invariant text untouched; DI-19 names its open
  remainder — first PROD sweep liveness read — and the audit-row-is-the-record acceptance).
- **Stratum endpoint axis = CAPTURE CHANNEL** (tp/workouts-list, fs/workouts-list):
  accepted as a documented CONVENTION within Addendum 2's design (capture stores no
  per-request endpoint; channels keep future event/detail captures separable; the
  convergence criterion arbitrates) — no ruling needed.
- **Casing-bug evidence, now end-to-end in-house**: dev if_planned 0→4 via the specimens
  while tss_planned stays 0 DESPITE captured raw proving TssPlanned populated on the wire
  (prod signature identical: 11/0) — handed to ops for the Critical ticket.
- Attestation halves all banked for Xuan: first sweep audit row · trial-sync capture ·
  alert email received. Land-bundle merges qa/real-payload-corpus + -harness + -flips and
  the app feature branch, re-runs all slices as the hard gate. v1.1 register merge rule
  (qa-33's Q-INT29 block wins) applies at whichever lands second.

## Addendum 4 — 2026-09-20: dev attestation (recorded verbatim; relayed provenance)

Relayed by app-a9 at Xuan's stated instruction; every observation HIS OWN (his terminal,
his inbox): (1) sweep liveness self-checked via the query-ledger retention arm — newest
sweep 0.5h [OK], genuine first row + two forced-alert test rows, flows correctly unseeded;
(2) capture self-read — his four hand-typed sandbox specimens back off the wire with
populated planned load, completed run TssActual=55; (3) the forced over-size alert email
received at his daily-checked inbox and confirmed; (4) BEYOND the banked halves: a live
versioned-row proof — he edited Corpus Tempo Run (0:50→0:55), resynced, observed the
original row untouched and the edited version inserted alongside (L-7 versioning, live),
with the novelty gate holding at novel 0 / 5 scanned.

**Land authorization: pending Xuan's in-session word** (relay ≠ gate for a trunk merge;
qa-70's session rule). This addendum records the attestation so his one word is the only
missing piece.
