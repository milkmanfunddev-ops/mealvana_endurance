# spec/integrations/ — OPEN QUESTIONS (INT register)

Status/ownership register for the integrations family. Argument lives in the section files;
this file holds the decision state. Rulings are Xuan's alone. Created 2026-09-08 with the
PROPOSED drafts. Ruling desk pass applied 2026-09-10: 21 RULED, 6 DEFERRED.

| ID | Subject | Where argued | Ruling |
|---|---|---|---|
| Q-INT0 | Ratify the family itself: name, scope, that it subsumes the `producers` proposal | `intake/2026-09-08-data-integration-lifecycle-family.md` | **RULED** (2026-09-10) |
| Q-INT1 | Retention: no TTL/purge anywhere (activities, `garmin_health_data` incl. raw payloads, deactivated `integrations` rows, zero-consumer wellness types) — ratify "indefinite, deliberately" or set windows | `lifecycle.md` L-7, `garmin.md` G-4 | **RULED** (2026-09-20) — 90-day raw TTL + permanent de-identified corpus |
| Q-INT2 | Disconnect custody: tokens, `garmin_health_data`, and `users` body-comp mirrors all survive disconnect, against the stated intent "removes what the provider gave us, not just the token" | `lifecycle.md` L-5.2 | **RULED** (2026-09-10) |
| Q-INT3 | Provider-side revocation: TP deauthorize exists but is never invoked; FS has no revoke; `garmin-deregistration` fails to deactivate the integration row | `lifecycle.md` L-5.3, `training-peaks.md` TP-3, `garmin.md` G-5 | **DEFERRED** (2026-09-10) |
| Q-INT4 | ONE match window: ruled ±15 min key vs the day-wide Garmin planned-completion matcher (home of unstamped `intake/2026-08-18-skipped-row-sync-match-window.md`) | `lifecycle.md` L-3 | **RULED** (2026-09-10) |
| Q-INT5 | What a `provider_deleted_at` row means — display? engine input? eventual tombstone? Today it is set and nothing defines it | `lifecycle.md` L-4.2 | **DEFERRED** (2026-09-10) |
| Q-INT6 | Platform-declared skip vs athlete Skip press (home of unstamped `intake/2026-08-18-platform-declared-skip-semantics.md`) | `lifecycle.md` L-4.3 | **DEFERRED** (2026-09-10) |
| Q-INT7 | Orphaned `garmin_health_data` rows with `user_id = NULL` (unmapped pushes) escape account-deletion CASCADE | `lifecycle.md` L-6 | **DEFERRED** (2026-09-10) |
| Q-INT8 | Token custody: single-custodian rule vs today's dual store (`integrations` + `garmin_user_mappings`), stale third store (auth `user_metadata` via dead `sync-final-surge`), plaintext columns, RLS unverified | `lifecycle.md` L-8 | **RULED** (2026-09-10) |
| Q-INT9 | Routing of the manual's security findings (Garmin header-optional webhook auth, ping SSRF, committed FS/TP secrets, web-bundle TP secret): ratified contract clauses here, or app-side engineering remediation tracked outside this family? | `garmin.md` G-1.4, `training-peaks.md` (NOT-ruled) | **RULED** (2026-09-10) |
| Q-INT10 | Server CHECK on `integrations.last_sync_status` lacks `'requires_reauth'`, a value the FS client writes — align which side? | `final-surge.md` FS-1.4 | **RULED** (2026-09-10) |
| Q-INT11 | `scheduled_date_time` semantics: FS/TP write planned time, Garmin completion overwrites with measured start — ratify the per-provider meaning (engine-day bucketing stays with `intake/2026-08-20-engine-session-bucketing-day-key.md`) | `lifecycle.md` L-9.3 | **RULED** (2026-09-10) |
| Q-INT12 | The FS `duration_minutes = NULL` producer contract — ratify jointly with the single-ladder rule (the founding 2026-08-22 defect) | `final-surge.md` FS-2.3 | **RULED** (2026-09-10) |
| Q-INT13 | Computed-then-discarded transform fields: FS pace min/max, swim meters, subtype; TP tss/if/intensity distribution/elevation/calories/tags — ratify as deliberate discard or as gap (today `activities.tss` is never fed from TP and speed-work exclusion is blind to FS/TP) | `final-surge.md` FS-2.5, `training-peaks.md` TP-2.4 | **RULED** (2026-09-10) |
| Q-INT14 | TP sandbox-by-default in code (`useSandbox = true`) — ratified prod posture and who owns the env flag | `training-peaks.md` TP-1.2 | **RULED** (2026-09-10) |
| Q-INT15 | Sport-mapping table ratification, esp. TP Rowing → `cycling` and Walk → `running`+easy | `training-peaks.md` TP-2.3, `final-surge.md` FS-2.2 | **DEFERRED** (2026-09-10) |
| Q-INT16 | TP write-back: default ON in code vs documented opt-in OFF; unverified full-object PUT; unimplemented disconnect/plan-deletion cleanup | `training-peaks.md` TP-5 | **RULED** (2026-09-10; consent posture AMENDED to opt-out 2026-09-11) |
| Q-INT17 | CTL/ATL: ratified engine inputs (F12 CTL volume tier, F26 ATL/CTL weekly ratio; `neat-tef.md`) with **no extractor** — TP metrics endpoint never called, no storage column. Build the feed, or strike the slots from the spec? | `field-map.md` §3 | **RULED** (2026-09-10) |
| Q-INT18 | Garmin-only athletes: request an `activities` backfill at connect (30-day windows, chainable; Garmin allows backfill only in the first month after connection) and run `TrainingInsightService` heavy/light-weekday insights without a forward calendar? Also: `garmin-backfill` clamps at 90 days, above Garmin's 30-day Activity max | `field-map.md` §4 | **RULED** (2026-09-10) |
| Q-INT19 | Athlete threshold/zones data (LTHR, FTP, threshold pace, HR/power/pace zones, manual FTP/CSS): wire into intensity/IF derivation (the zone→intensity classifier is a no-op today) or ratify as display-only | `performance-data.md` P-1 | **RULED** (2026-09-10) |
| Q-INT20 | Measured session metrics (Garmin HR, power, pace) are server-only columns with zero readers — add client columns + consumers, or ratify server-side-forensics-only | `performance-data.md` P-2, P-4 | **RULED** (2026-09-10) |
| Q-INT21 | Planned-match plausibility guard: thresholds for refusing a match (proposed: measured < 20% of planned duration or < 2 min absolute → fall to insert) — the 9-second-swim prod bug | `matching.md` M-1.1 | **RULED** (2026-09-10) |
| Q-INT22 | Brick Garmin verification contract: clauses B-1..B-5 incl. B-2′ sequential independent legs (the primary real-world case — separate per-sport starts; prod evidence: 3 MULTI_SPORT parents + 38 child legs since 2026-08-24) | `matching.md` M-5.3 | **RULED** (2026-09-10) |
| Q-INT23 | Multisport ingestion model: persist `parentSummaryId`, map all `TRANSITION_*` variants (today they auto-insert as `other`), dedup parent vs children | `matching.md` M-5.2, M-6 | **RULED** (2026-09-10) |
| Q-INT24 | MANUAL → GARMIN upgrade path: spec expects it, code cannot reach a `completed` row — ratify the upgrade key (same sport ±15 min, summary-id-less completed rows) | `matching.md` M-3 | **RULED** (2026-09-10) |
| Q-INT26 | The capture contract: one ruling adopting (or trimming) the 10-item capture shortlist in `payload-usage-map.md` §6 — TP TSS/IF actuals+planned, parentSummaryId, TP Metric fetch (weight/HRV), zones consumption, subtypes/pace, IsPremium, Garmin hrv type, TP calories planned+completed as record-only comparison columns, race flags. Packages Q-INT13/17/19/20/23 into one infrastructure handback | `payload-usage-map.md` §6 | **RULED** (2026-09-10) |
| Q-INT25 | Schema hygiene batch: dual `archivedForBrick` casings, brick schema only in archived migration, `'draft'` not in status enum, `'transition'` missing from type enums, dead columns (`activities.tss`, `integrations.threshold_pace_min_per_mile`, `users.prefers_*`, activity FTP/CSS/speed orphans), three competing fingerprints | `matching.md` M-6, `performance-data.md` P-4 | **RULED** (2026-09-10) |
| Q-INT27 | First-connect sync-window contract: FS forward 28 days (was our 14-day clamp), Garmin activities backfill 30 days at connect, no TP/FS history import (dated decision) | `final-surge.md` FS-1, `garmin.md` G-1, `training-peaks.md` TP-1 | **RULED** (2026-09-11) |
| Q-INT28 | Computed zone-2 pace fallback: when the athlete never reports a pace and no platform syncs zones, derive Z2 instead of the hardcoded 9:00 default (candidates: recent easy-run history; age/HR heuristics; labeled conservative default). Plausibility bounds 4-20 min/mi apply to whatever is computed | `performance-data.md` P-1; review-artifact thread ed163233 (2026-09-11) | **STAGED** — Xuan: "remind me to ratify this later" |
| Q-INT29 | Zone splits persisted only when parsed from a real workout `Structure` | `payload-usage-map.md` §7.3; `intake/2026-09-18-q-int29-tp-disposition.md` | **RULED** (2026-09-17; narrowed 2026-09-20 — no-op for TP, pending FS evidence) |

## Direction (Xuan, 2026-09-09 — goals, not rulings; desk options should align)
1. **Minimize user input where a partner already has the datum**; every formula gets the
   right input, never a subpar proxy — mapping accuracy is examinable (first case: the
   Garmin activity-kcal BMR embedding, `intake/2026-09-09-garmin-activity-kcal-includes-bmr.md`).
2. **Platform-less athletes get a schedule synthesized from history** (Garmin backfill →
   pattern → planned template), not just insights — Q-INT18's scope is widened to this.
3. **Lose nothing; store efficiently**: volatile fields get a refresh schedule; every
   arriving field is captured even if unconsumed today, parsed into typed columns rather
   than one blob where practical — bears on Q-INT1 (retention), Q-INT26 (capture), and
   the erratum option choices (correct at use, keep raw verbatim).
5. **Bucketed ⇒ documented + raw kept** (artifact thread, 2026-09-09): every bucketed
   field's method is documented (`payload-usage-map.md` §7 — cutoffs, precedence, defaults)
   and the raw value is also captured; discarding raw later is a cheap reversible ruling,
   re-creating it is impossible.
4. **Per-source columns for multi-source data points** (artifact thread, 2026-09-09): when
   the same quantity can arrive from more than one provider (e.g. session kcal from Garmin
   AND TP, weight from Garmin AND TP), capture each source in its own typed column — never
   overwrite one source with another at ingest. Precedence is decided only at read time by
   the ratified resolution ladder (F22 pattern: Garmin wins when present, TP otherwise),
   so priority can be re-ruled later without re-ingesting anything. This is the storage
   convention Q-INT26's new columns follow.

## Notes for the ruling desk
- **Tiering suggestion:** Q-INT0 gates everything. Q-INT1/Q2/Q3/Q16 are the
  consent-and-custody core (the "stored … discarded" of Xuan's ask) and carry user-facing
  risk today, Q-INT16 most of all. Q-INT4/Q5/Q6/Q11/Q12 are correctness contracts the
  conformance vectors will pin. Q-INT7/Q8/Q9/Q10/Q14 are custody/engineering routing calls.
  Q-INT13/Q15 are data-completeness calls that change what future engines can read.
- Related but owned elsewhere (not rows here): unknown-sport F4 fallback
  (`intake/2026-08-20-session-cost-unknown-activity-types.md`), engine-day bucketing
  (`intake/2026-08-20-engine-session-bucketing-day-key.md`), HR-derived IF (Q-010, RULED
  deferred), value ladders (F22–F27).

## Register entries

### Q-INT1 — Retention policy for imported third-party data
> **DEFERRED (Xuan, 2026-09-10, ruling desk).**
> **RULED (Xuan, 2026-09-20, corpus interview):** option-2 family — 90-day TTL on all raw
> provider payloads (Garmin raw types, the new `provider_raw_payloads` FS/TP window, and
> prod-graduated sample/HRV capture); the permanent record is the de-identified corpus
> (promotion starts now; privacy-declaration line rides the next terms update). Full
> contract: `lifecycle.md` L-7 fold. Size meter + alert resurfaces this ruling if raw
> exceeds 2 GB collectively or 60% of plan storage.

No TTL, purge job, or data-minimisation statement exists for `activities`,
`garmin_health_data` (including verbatim `activity_raw` payloads and the four wellness
types with zero consumers), or deactivated `integrations` rows. Argued: `lifecycle.md` L-7,
`garmin.md` G-4.
#### Options
1. Ratify indefinite retention as deliberate (documented in the privacy declaration).
2. Set concrete windows (e.g. raw payloads 90 days, zero-consumer wellness until a consumer ships).
3. Defer to a dedicated privacy pass.

### Q-INT2 — What survives a disconnect
> **RULED (Xuan, 2026-09-10, ruling desk):** default disconnect soft-hides provider rows and Garmin wellness behind a hidden-by-disconnect flag (distinct from the tombstone: hidden rows match-and-REVIVE on reconnect via provider id/summary id, never suppress), clears tokens, and reruns F27 so totals deflate; an explicit 'also delete my synced data' choice performs the hard purge incl. wellness and users mirrors

Tokens (`integrations` row soft-deactivated), all `garmin_health_data`, and the
`users.weight_pounds`/`body_fat_pct` Garmin mirrors all survive disconnect — against the
code's own stated intent ("removes what the provider gave us, not just the token").
Argued: `lifecycle.md` L-5.2.
#### Options
1. Full purge: wellness + mirrors + tokens go with the workouts.
2. Tokens cleared, wellness retained (it is the athlete's own biometrics).
3. Ratify current behaviour as deliberate.

### Q-INT3 — Provider-side revocation on disconnect
> **DEFERRED (Xuan, 2026-09-10, ruling desk).**

TP `deauthorize` exists but the UI never invokes it; FS has no revoke; `garmin-deregistration`
fails to deactivate the `integrations` row despite its own header. Argued: `lifecycle.md`
L-5.3, `training-peaks.md` TP-3, `garmin.md` G-5.

### Q-INT4 — ONE match window (home of intake 2026-08-18-skipped-row-sync-match-window)
> **RULED (Xuan, 2026-09-10, ruling desk):** ±15 min ruled key governs tombstone, skipped, and upgrade matching; the trigger-based contract (M-1.2) governs completion: platform-keyed signals match by ID with no threshold, Garmin signals match via the plausibility guard + best-fit (closest slot, then duration; ties fall to earliest slot — no manual-resolution UI), and a late platform signal verifies or reverts-and-rebinds the heuristic match with displaced activities re-scoring; M-0 one-row invariant, Garmin-signal sufficiency, measured-signature tiebreaker, and timezone-defensive instant comparison ratified. [Applier note: the word 'upgrade' here is superseded by Q-INT24's explicit day-wide upgrade key, ruled in the same batch.]

Ruled ±15 min key vs the day-wide Garmin planned-completion matcher. Decide once, for all
providers. Argued: `lifecycle.md` L-3.

### Q-INT5 — Meaning of `provider_deleted_at`
> **DEFERRED (Xuan, 2026-09-10, ruling desk).**

Set on provider-removed workouts; NOT a tombstone, NOT `status='deleted'`; no spec says
what display or the engine does with such a row. Argued: `lifecycle.md` L-4.2.

### Q-INT6 — Platform-declared skip (home of intake 2026-08-18-platform-declared-skip-semantics)
> **DEFERRED (Xuan, 2026-09-10, ruling desk).**

Is a TP/FS-declared `skipped` the same fact as the athlete's Skip press (unskip, re-assert,
provenance chip)? Argued: `lifecycle.md` L-4.3.

### Q-INT7 — Orphaned unmapped-user Garmin rows
> **DEFERRED (Xuan, 2026-09-10, ruling desk).**

`garmin_health_data` rows written with `user_id = NULL` escape the account-deletion CASCADE.
Argued: `lifecycle.md` L-6.

### Q-INT8 — Token custody: one custodian per provider
> **RULED (Xuan, 2026-09-10, ruling desk):** integrations is the sole token store per provider; RLS on token tables verified; garmin_user_mappings token copies and the auth user_metadata store removed

Dual Garmin store (`integrations` + `garmin_user_mappings`, known refresh drift), stale third
FS store in auth `user_metadata` (dead `sync-final-surge`), plaintext columns, RLS on
token-bearing tables unverified (audit action #1). Argued: `lifecycle.md` L-8.

### Q-INT9 — Routing of the security findings
> **RULED (Xuan, 2026-09-10, ruling desk):** security findings routed to app-side engineering remediation tracked ops-side; spec/integrations references but does not own them

Garmin webhook accepts header-less requests; ping SSRF; committed FS/TP secrets; TP web-bundle
secret. Ratified contract clauses in this family, or app-side engineering remediation tracked
outside it? Argued: `garmin.md` G-1.4.

### Q-INT10 — `last_sync_status` CHECK mismatch
> **RULED (Xuan, 2026-09-10, ruling desk):** server CHECK widened to include requires_reauth

Server CHECK lacks `'requires_reauth'`, a value the FS client writes. Align which side?
Argued: `final-surge.md` FS-1.4.

### Q-INT11 — `scheduled_date_time` per-provider semantics
> **RULED (Xuan, 2026-09-10, ruling desk):** scheduled_date_time = planned time for FS/TP rows and measured start after Garmin completion; planned_time/actual_time carry the two-time truth

FS/TP write planned time; Garmin completion overwrites with measured start. Ratify the
per-provider meaning (engine-day bucketing stays with intake 2026-08-20). Argued:
`lifecycle.md` L-9.3.

### Q-INT12 — The FS NULL-duration producer contract
> **RULED (Xuan, 2026-09-10, ruling desk):** FS duration_minutes=NULL-when-distance/pace ratified jointly with the single-ladder rule: SessionInputResolver is the only resolver

Ratify `duration_minutes = NULL` when distance/pace present, jointly with the single-ladder
rule (the founding 2026-08-22 defect). Argued: `final-surge.md` FS-2.3.

### Q-INT13 — Computed-then-discarded transform fields
> **RULED (Xuan, 2026-09-10, ruling desk):** satisfied by the capture contract (C5): subtype/pace/zone-source fields captured per payload-usage-map

FS pace min/max, swim meters, subtype; TP tss/if/intensity distribution/elevation/calories/tags —
all computed and never written. `activities.tss` is never fed; speed-work exclusion is blind
to FS/TP. Deliberate discard, or gap to fix? Argued: `final-surge.md` FS-2.5,
`training-peaks.md` TP-2.4.

### Q-INT14 — TP sandbox-by-default
> **RULED (Xuan, 2026-09-10, ruling desk):** TP host selection is env-driven; release builds default to production; sandbox reachable only via the dev flag

`useSandbox = true` hard-coded default, env-overridable. Ratified prod posture and flag
ownership. Argued: `training-peaks.md` TP-1.2.

### Q-INT15 — Sport-mapping table
> **DEFERRED (Xuan, 2026-09-10, ruling desk).**

Esp. TP Rowing → `cycling` ("similar metabolic profile") and Walk → `running`+easy.
Argued: `training-peaks.md` TP-2.3, `final-surge.md` FS-2.2.

### Q-INT16 — TP write-back consent & cleanup
> **RULED (Xuan, 2026-09-10, ruling desk):** TP write-back defaults OFF (opt-in); a server-side write-back ledger is created and required before any push; disconnect strips Mealvana blocks best-effort and purges the ledger; the full-object PUT verified end-to-end before re-enable
> **AMENDED (Xuan, 2026-09-10, evening):** (a) prominent opt-in consent prompt at TP connect; the settings toggle stays (Connected Apps already has one — only the `?? true` default flips); every push records success/failure per row in the ledger (the local Drift `tp_writeback_log` already does this with status+planHash; the server-side ledger mirrors it).

Code defaults write-back ON (`?? true`) vs documented opt-in OFF; full-object PUT never
verified end-to-end; disconnect/plan-deletion cleanup unimplemented. Proposed contract:
opt-in OFF, best-effort strip on disconnect, ledger purged with it. Argued:
`training-peaks.md` TP-5.

### Q-INT17 — CTL/ATL: ratified inputs with no extractor
> **RULED (Xuan, 2026-09-10, ruling desk):** CTL/ATL computed in-house from captured TSS when the feed exists; engine slots stay, fed by the capture contract (C5)

Engine slots (F12 CTL volume tier, F26 ATL/CTL weekly ratio) and `neat-tef.md` both speak
CTL; the TP metrics endpoint is never called and no column stores it. Build the feed, or
strike the slots? Argued: `field-map.md` §3.

### Q-INT18 — History-derived training schedule for platform-less athletes (scope widened 2026-09-09)
> **RULED (Xuan, 2026-09-10, ruling desk):** Garmin-only athletes get an activities backfill at connect (chained ≤30-day windows), TrainingInsightService insights, and a synthesized forward template tagged as generated and confirmed by the athlete; the 90-day clamp above Garmin's 30-day activity max is fixed. Xuan addendum: create/test the insight engine (TrainingInsightService exists; live test queued in the handback)

Request an `activities` backfill at connect (30-day windows, chainable; Garmin allows
backfill only in the athlete's first month) and use the history two ways: (a) the existing
`TrainingInsightService` heavy/light-weekday insights, and (b) **synthesize a
forward-looking training template from the observed pattern** (weekday × sport × typical
duration/intensity → generated planned rows the athlete can confirm/edit), per Xuan's
goal 2 (2026-09-09): "import their training schedule from their history information."
Open sub-questions: how many weeks of history anchor the template; regeneration cadence as
new completions arrive; how synthesized rows are provenance-tagged so they never masquerade
as coach-planned. Also: `garmin-backfill` clamps at 90 days, above Garmin's 30-day
Activity max. Argued: `field-map.md` §4.

### Q-INT19 — Athlete threshold/zones data: wire or display-only
> **RULED (Xuan, 2026-09-10, ruling desk):** zones wired into intensity classification + FTP prefill per the capture contract (C5)

TP zones (LTHR, max/resting HR, FTP, per-sport pace zones) are fetched and stored; only two
Zone-2 pace prefills read anything. The zone→intensity classifier receives the zones and
ignores them (fixed thresholds). Manual `users.cycling_ftp_watts`/`swimming_css` are
display-only. Argued: `performance-data.md` P-1.
#### Options
1. Wire: zones drive `_classifyIntensity` boundaries and a per-athlete IF derivation.
2. Ratify display-only; strike the dead helpers and unread stored fields.
3. Defer until an engine iteration needs athlete thresholds.

### Q-INT20 — Measured session metrics custody
> **RULED (Xuan, 2026-09-10, ruling desk):** measured session metrics gain client columns + consumers per the capture contract (C5)

Garmin writes `average_heart_rate`, `max_heart_rate`, `cycling_power_watts`,
`average_pace_minutes_per_mile` to Supabase-only columns with zero readers (no Drift
columns, engine ignores them). Add client columns + consumers, or ratify
server-side-forensics-only. Argued: `performance-data.md` P-2/P-4.

### Q-INT21 — Planned-match plausibility guard
> **RULED (Xuan, 2026-09-10, ruling desk):** planned-completion refused when measured duration < 20% of planned or < 2 min absolute; refusal falls to auto-insert

The day-wide planned matcher has no duration/distance/proximity guard; prod bug: a
9-second swim completed the athlete's planned morning swim. Proposed: refuse when measured
duration < 20% of planned or < 2 min absolute; refusal falls through to auto-insert.
Thresholds are the ruling. Argued: `matching.md` M-1.1.

### Q-INT22 — Brick Garmin verification contract (B-1..B-5, incl. sequential legs)
> **RULED (Xuan, 2026-09-10, ruling desk):** B-1..B-5 ratified with B-2' sequential legs as primary (gap ≤ 30 min, plausibility guard per leg); verified requires all endurance legs matched

No code path today can verify a brick (type/statuses unreachable by every gate; no summary
id ever written to parent or leg). Proposed clauses: B-1 parent match
(multisport≈brick + duration guard), B-2 positional leg matching by `parentSummaryId`,
**B-2′ sequential independent legs** — the primary path per Xuan's stated usage
(each sport started individually; multisport rare outside races) — sports in start order
equal segment order, inter-leg gap ≤ tolerance (proposed 30 min), each leg passing the
M-1.1 guard; B-3 verified predicate, B-4 transition folding, B-5 no double import.
Production evidence (raw log since 2026-08-24, push path only): 3 MULTI_SPORT parents,
38 `parentSummaryId` children, 0 TRANSITION-typed. Argued: `matching.md` M-5.
#### Options
1. B-3 as written: verified when parent (or first sequential leg) stamped AND every endurance leg matched.
2. Parent-match / any-leg-match alone suffices for verified (rest enrich when present).
3. Majority-of-duration matched → verified.
4. Sequential path only (drop B-1/B-2 multisport handling until demand appears).

### Q-INT23 — Multisport ingestion model
> **RULED (Xuan, 2026-09-10, ruling desk):** parentSummaryId/isParent persisted, TRANSITION_* variants mapped and folded, parent/child dedup per B-5 (C5)

`isParent`/`parentSummaryId` never persisted; `TRANSITION_V2`/`BIKE_TO_RUN_TRANSITION`/
`SWIM_TO_BIKE_TRANSITION`/`RUN_TO_BIKE_TRANSITION` are not in the type map → auto-insert
as `other` (contradicting the "transitions are skipped" comment); parent + child legs all
import independently with no dedup. Argued: `matching.md` M-5.2/M-6.

### Q-INT24 — MANUAL → GARMIN upgrade path
> **RULED (Xuan, 2026-09-10, ruling desk):** any completed row without a garmin_summary_id (mark-done or hand-created) is an upgrade target: same sport, same local calendar day; among multiple candidates the closest start wins — no ±15-min restriction, because mark-done actual_time inherits the planned slot (often a 7am default); the plausibility guard still applies (measured < 20% of the row's duration or < 2 min → no upgrade, import standalone)

`platform-resolution.md` and `workout-card.md` ratify the upgrade; the matchers only
search planned/draft/skipped and the atomic guard excludes `completed`, so a mark-done row
is never upgraded — Garmin auto-inserts a duplicate instead. Ratify the upgrade key
(proposed: summary-id-less `completed` rows, same sport, start ±15 min). Argued:
`matching.md` M-3.

### Q-INT25 — Schema hygiene batch
> **RULED (Xuan, 2026-09-10, ruling desk):** the full hygiene list ships as one cleanup handback: enum-casing migration, live brick migration, draft + transition enum decisions, dead-column removals, fingerprint unification

Dual `archivedForBrick`/`archived_for_brick` enum casings (failed rename, audit-flagged);
brick schema only in an archived migration; `'draft'` in matcher filters but absent from
`activity_status_enum` migrations; `'transition'` absent from Dart/Postgres type enums
(queries 22P02); dead columns (`activities.tss`, `integrations.threshold_pace_min_per_mile`,
`users.prefers_cycling_power`/`prefers_swimming_pace`, `activities.cycling_ftp_watts`/
`swimming_css_seconds_per_100m`/`swimming_speed_per_100m`); three competing session
fingerprints. Route: one ratified cleanup handback vs individual app-side fixes. Argued:
`matching.md` M-6, `performance-data.md` P-4.

### Q-INT26 — The capture contract (data-infrastructure update)
> **RULED (Xuan, 2026-09-10, ruling desk):** maximal capture: every DISCARDED and UNHANDLED field in payload-usage-map is captured into per-source typed columns; sole exception = per-sample streams (dated decision 2026-09-09); the 10-item shortlist orders the implementation

Xuan (2026-09-09): "update the data infrastructure so we can make sure all the critical
data are captured." `payload-usage-map.md` enumerates every provider field with its
disposition; §6 is the ordered capture shortlist. Ruling this row adopts/trims that list
as ONE handback to Lee; it satisfies Q-INT13/Q-INT17/Q-INT19/Q-INT20/Q-INT23 where its
items overlap them (stamp those accordingly). Key facts: TP sends IF and TSS on both
planned and completed workouts (discarded today; null for basic athletes); FS sends
neither but does send per-step watts/HR/pace targets (bucketed); the TP Metric endpoint
(weight, HRV — premium, NOT-FETCHED) is the TP weight-staleness fix; no provider exposes
CTL/ATL, sweat data, or race priority.
#### Options
1. Adopt the full §6 shortlist as one capture handback.
2. Adopt items 1–5 only (engine-critical); defer the rest.
3. Trim per-item on the desk (name keeps/drops in the RULED line).

### Q-INT27 — First-connect sync-window contract (post-ratification, 2026-09-11)
> **RULED (Xuan, 2026-09-11): FS forward window 28 days (gated on the date-range probe);
> Garmin activities backfill 30 days at connect; no TP/FS history import — dated
> decision, revisit with a load-context feature.**

Grew out of the 2026-09-11 window audit: every provider's first-connect window was an
observed code default, none ratified. Facts established before ruling: TP/FS fetch zero
history by our own client choice (both APIs take arbitrary date ranges; FS's 14-day
forward limit is our clamp, not an FS cap); Garmin's connect-time backfill requested only
body-comp + user metrics (90-day clamp above Garmin's 30-day Activity max = recorded bug,
Q-INT18); V.O2 alone pulled 14 days back. Rationale recorded with the ruling: each
provider is fetched for what it is authoritative about — forward plan from TP/FS, actuals
history from Garmin; the only ratified history consumer (Q-INT18 insight→template) exists
for platform-less athletes; a TP/FS bulk history import would stress the rewritten
matching pipeline at every first connect on unproven data (FS `Actual*` never observed
populated live).

Gates: the FS 28-day window ships behind the FS date-range server-cap probe (handback §7)
+ one live check of the 404-fallback path (`UpcomingWorkouts` at `NumDays` > 14).
Applier note: Q-INT18's "chained ≤30-day windows" is fixed by this ruling at ONE 30-day
window; chaining to 60–90 days remains a future additive option if the insight engine's
live test finds one month too thin. TP's 45-day forward window is unchanged.

### Q-INT29 — Zone splits from structured workouts
> **RULED (Xuan, 2026-09-17):** persist zone splits only when parsed from a real workout `Structure` — never derived from titles or guesses.
> **NARROWED (Xuan, 2026-09-20, corpus interview):** no-op for TP by provider capability —
> a `Structure` is unreachable under our current OAuth grant (every route, every tier;
> evidence `runs/2026-09-18-tp-structure-hunt.md`, `runs/2026-09-18-tp-premium-trial-probe.md`).
> TP zone columns stay NULL; FS is NULL-UNTIL-EVIDENCE (the ruling applies unchanged when a
> `json_fs_v1` structured detail is first captured); the engine's zoneless default at
> computation time is explicitly unchanged; the fabricating fallback branches
> (`_classifyIntensity` ≤1.5⇒%FTP, unknown-length⇒seconds, FS twin) are deleted app-side.
> Reopens if TrainingPeaks grants the file-export scope (provider-relations request sent
> 2026-09-20). Note: this branch's register lacked the 2026-09-17 row (it lives on
> `qa/data-integrations-v1.1`); reconcile on merge.
