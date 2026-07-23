# API Exploration — What Our Training Integrations Actually Give Us

**Audience:** anyone who needs to know what data we can get from our five implemented training-platform
integrations, what fields are exposed, and what we currently do with them.
**Last verified:** 2026-07-23, against the code on `main`.

---

## Start here

If you read nothing else, read these:

1. **[onboarding-matrix.md](./onboarding-matrix.md)** - which fields in the active onboarding flow
   each provider can supply, plus what the app currently prefills.
2. The **Capability matrix** below - what each provider can and cannot give us.
3. Each provider's **field reference** - the complete endpoint-by-endpoint data dictionary with
   field names, types, units, descriptions, and examples.

Then go to whichever provider you care about.

| Provider | Folder | Model | Docs |
|---|---|---|---|
| **Garmin** | [`garmin/`](./garmin/) | Server-to-server **push** | README · authentication · endpoints · activity-data · health-data · training/courses/women's · field-reference |
| **TrainingPeaks** | [`training-peaks/`](./training-peaks/) | **Pull + write-back** | README · authentication · endpoints · workout-data · athlete-data · **writeback** · field-reference |
| **Final Surge** | [`final-surge/`](./final-surge/) | Pull (OAuth) | README · authentication · endpoints · workout-data · field-reference |
| **VDOT O2 (V.O2)** | [`vdot-o2/`](./vdot-o2/) | Pull (OAuth) | README · authentication · endpoints · workout-data · field-reference |
| **Runna** | [`runna/`](./runna/) | Pull (personal iCalendar feed) | Complete endpoint, calendar-envelope, VEVENT, derived-field, and sync reference |

The four JSON APIs have `examples/` directories with **66 JSON-validated payloads**. Runna is an
iCalendar feed rather than JSON; its evidence comes from committed parser/client fixtures and unit
tests.

The standalone [master HTML reference](./index.html) contains all provider documents and examples in
one file. Its search box performs full-text search across every hidden page, table, field name,
description, type, unit, endpoint, and payload example; use `Cmd/Ctrl+K` to focus it.

---

## How to read the evidence markers

This doc set distinguishes what we have **observed** from what we **infer**. This matters: some
providers have rich test fixtures, others have none, and a doc that reads uniformly authoritative
would mislead you about which fields you can actually rely on.

| Marker | Means |
|---|---|
| *(unmarked)* | Grounded in code, tests, or committed fixtures — with a `file:line` citation |
| `_(spec, not yet observed in our code)_` | From the provider's published spec; we have not seen it arrive |
| `_(inferred — not observed in fixtures)_` | Derived from our parsing code, not from a captured payload |
| `_(reconstructed from parser)_` | The example was built by reading the parser, not captured live |

**Evidence strength by provider — read this before trusting an example:**

| Provider | Fixtures | Unit tests | Confidence |
|---|---|---|---|
| Garmin | Extensive (`index.test.ts`, `mappers.test.ts`) | Yes | **High** — most examples are observed |
| TrainingPeaks | `training_peaks_fixtures.dart` (424 lines) | Yes | **High** |
| Final Surge | `final_surge_fixtures.dart` (481 lines) | Yes | **High** for planned; **low for completed** (see below) |
| VDOT O2 | **None committed** | **None** | **Low** — most examples reconstructed from the parser |
| Runna | Calendar strings in client/parser/transformer tests | Yes | **High** for the supported iCalendar subset |

---

## Capability matrix

What each provider can give us, and what we actually take.

| Capability | Garmin | TrainingPeaks | Final Surge | VDOT O2 | Runna |
|---|:--:|:--:|:--:|:--:|:--:|
| Planned workouts | ✗ (scope not requested) | ✅ | ✅ | ✅ | ✅ running calendar |
| Completed workouts / actuals | ✅ | ✅ | ⚠️ never observed | ⚠️ no actuals | ✗ |
| GPS / HR / power samples | ⚠️ **received, discarded** | ✗ | ✗ | ✗ | ✗ |
| Lap splits | ⚠️ **received, discarded** | ✗ | ✗ | ✗ | ✗ |
| Structured intervals | ✗ | ✅ | ✅ | ✅ (targets discarded) | ⚠️ text only |
| Health / wellness (sleep, stress, HR) | ✅ | ✗ | ✗ | ✗ | ✗ |
| Body composition / weight | ✅ | ✅ (profile) | ✗ | ✗ | ✗ |
| Training zones | ✗ | ✅ | ✗ | ⚠️ **available, unused** | ✗ |
| VDOT score / E-M-T-I-R paces | ✗ | ✗ | ✗ | ⚠️ **available, unused** | ✗ |
| Race / event calendar | ✗ | ✅ | ✗ | ✗ | ⚠️ undifferentiated events |
| **Write back into the platform** | ✗ | ✅ **only one** | ✗ | ✗ (GPS upload only) | ✗ |

Legend: ✅ we consume it · ⚠️ available but we don't use it, or unverified · ✗ not available to us

### The three biggest gaps

1. **VDOT O2 gives us no pace science.** The platform whose entire value proposition is Jack
   Daniels' pace methodology contributes **zero** pace data. No VDOT score, no E/M/T/I/R zones, no
   race equivalencies — no endpoint is wired for any of them. The one pace-carrying field that
   *does* arrive (`steps[].target`) is parsed and discarded. See
   [vdot-o2/training-paces.md](./vdot-o2/training-paces.md).
2. **Garmin sends us rich sample data we throw away.** GPS tracks, heart-rate series, power samples
   and lap splits arrive on every `activityDetails` push; only `detail.summary` is read. See
   [garmin/activity-data.md](./garmin/activity-data.md).
3. **Garmin training plans are unavailable by choice.** The Training API endpoint is enabled, but we
   only request `ACTIVITY_EXPORT HEALTH_EXPORT` scopes (`garmin_oauth_service.dart:76`). The gap is
   a scope decision on our side, not a Garmin limitation.

---

## Integration models — two very different shapes

**Garmin pushes to us.** It is server-to-server and **we cannot pull on demand**. Data arrives at
`garmin-push` / `garmin-ping` edge functions when Garmin decides to send it. A "ping" is a pointer:
we must then GET the supplied `callbackURL` to retrieve the payload.

**TrainingPeaks, Final Surge, VDOT O2, and Runna are pulled** by `IntegrationSyncCoordinator`
(`lib/features/integrations/application/integration_sync_coordinator.dart`):

| Rule | Value |
|---|---|
| Staleness threshold | 4 hours |
| Failure cooldown | 5 minutes |
| Concurrency | one sync per provider (`_syncingNow` dedup) |
| Failure surface | **silent — logs only, no user-facing error** |

Sync windows differ per provider — Final Surge and TrainingPeaks by date range, VDOT `−14d/+45d`
chunked into 60-day requests, and Runna by the date window present in its subscribed calendar feed.
Runna uses a user-supplied feed URL with an embedded token, not OAuth.

---

## Findings register

Documenting these integrations surfaced defects. They are recorded here rather than fixed, because
this task was documentation. **Nothing in this list has been fixed.**

### Security — needs action

| # | Finding | Evidence |
|---|---|---|
| S1 | **Garmin webhooks accept unauthenticated requests.** `validateGarminRequest` returns *valid* when the `garmin-client-id` header is **absent** (a wrong header is rejected; no header is accepted). `garmin-push`/`garmin-ping` run with `verify_jwt = false`, so this is the only auth. | `_shared/garmin/auth.ts:33-37`, `supabase/config.toml:316-320` |
| S2 | **SSRF via Garmin ping.** `fetchGarminCallback` fetches a URL taken from the request body with no host allowlist. Combined with S1, an unauthenticated caller can make our server fetch arbitrary URLs and ingest the response. | `garmin-ping/index.ts:127` + ~9 more sites |
| S3 | **Final Surge client id *and secret* committed to git.** Both files are tracked and not gitignored. | `tool/final_surge_api_test.dart:23-24`, `test/integration/final_surge_api_test.dart:31` |
| S4 | **TrainingPeaks client secret committed to git** (sandbox credential). | `tools/tp_writeback_test.dart:21` |

For S1/S2, the correct pattern already exists in this repo: `revenuecat-webhook` uses
`verify_jwt = false` at the gateway and validates a shared secret *inside* the function
(`supabase/config.toml:331-333`). Note S1's bypass appears deliberate — the comment cites Garmin's
Data Generator omitting the header — so tightening it needs knowledge of real production traffic.

### Correctness

| # | Finding | Evidence |
|---|---|---|
| C1 | **Pace conversion inverted in a fallback path.** min/km → min/mile requires `×1.60934`; this branch multiplies by `kmToMiles` (0.621371), the reciprocal. A 5:00/km target becomes 3:06/mi instead of 8:03/mi. No test covers the branch. | `final_surge_transformer.dart:1331` vs correct path `:1252` |
| C2 | **TP write-back defaults ON in code, spec says OFF.** `tpWritebackEnabled` returns `?? true`; the spec says "Default: **OFF** (opt-in to avoid surprising users)". We write into athletes' TrainingPeaks calendars without opt-in. | `preferences_service.dart:37` vs `docs/tp_write/README.md:232` |
| C3 | **TP write-back `PUT` is a full-object replace** — omitted fields are nulled. We GET→mutate→PUT, but nothing verifies the GET returns every PUT-preservable field. Highest unverified risk in the write path. | [training-peaks/writeback.md](./training-peaks/writeback.md) |
| C4 | **Garmin `calendar_date` derivation inconsistent** — body composition computes it in UTC *without* applying the offset; epochs apply it correctly. Same measurement can land on different days. | [garmin/health-data.md](./garmin/health-data.md) |
| C5 | **TP `PercentOfThresholdHr/Speed` missing from the intensity switch** — classified against FTP thresholds, the wrong scale. | [training-peaks/workout-data.md](./training-peaks/workout-data.md) |
| C6 | **TP zone cache never expires.** The 24h cache keys off `integration.updatedAt`, which token refresh bumps hourly. | [training-peaks/athlete-data.md](./training-peaks/athlete-data.md) |

### Stale / dead

| # | Finding | Evidence |
|---|---|---|
| D1 | **`supabase/functions/sync-final-surge/index.ts` is dead code** — no caller, and its field names (`data.workouts`, `sport: 'RUNNING'`) don't match the real API. It would return empty against live data. **Do not use it as a reference** — it is the most misleading file in the Final Surge surface. | |
| D2 | `docs/vdot/README.md:107` states a `−7d/+14d` sync window; the code is `−14d/+45d`. | `vdot_sync_service.dart:68-69` |
| D3 | `garmin-push/index.ts:10-15` header comment describes a "match-only" strategy the code no longer implements. | |
| D4 | `garmin-ping` duplicates record construction inline instead of sharing `mappers.ts` — a field added to one path won't appear in the other. | |
| D5 | TP: documented rate-limiting, batching, retry, and disconnect-cleanup are unimplemented. | |

### Data we receive but do not use

Garmin GPS/HR/power samples and lap splits · VDOT `steps[].target` pace targets · TP scopes granted
but unrequested (`workouts:details`, `metrics:*`, `file:write`, `events:write`, `webhook:*`) ·
VDOT `GET /v1/vdot-workouts/{eventId}` implemented with zero callers · TP
`POST /v1/athletes/{id}/nutrition` implemented with no caller in `lib/`.

---

## Caveats worth stating plainly

- **`integrations.provider` permits `'strava'`, but there is no Strava integration.** It is a
  reserved slot in a CHECK constraint, not a shipped capability.
- **Final Surge completion data has never been observed.** `Actual*` fields are read by our code but
  never seen non-null, and `WorkoutCompleted` is never read at all — so every Final Surge import
  lands as `planned`. Documented as schema-level, not confirmed behaviour.
- **VDOT has no committed fixtures and no unit tests.** Treat its examples as reconstructions.
- **VDOT gives us no athlete identity** — the name is hardcoded `'V.O2'` and we store our own userId
  as `provider_athlete_id`.
- **Runna has no athlete profile or actuals.** It is a read-only calendar subscription containing
  planned events; every imported event is treated as a planned run and interval steps remain text.
- **Strava and TriDot are currently shown as coming soon.** They have no implemented data surface
  to inventory, so they are not counted as integrations in this reference.
- Nothing here was verified against live production traffic. It is verified against **code and
  committed tests** as of 2026-07-23.

---

## Source map

| Layer | Path |
|---|---|
| API clients | `lib/features/integrations/data/*_api_client.dart` |
| Transformers (field mapping) | `lib/features/integrations/application/*_transformer.dart` |
| Sync services | `lib/features/integrations/application/*_sync_service.dart` |
| OAuth | `lib/features/integrations/application/*_oauth_service.dart` |
| Runna calendar feed | `lib/features/integrations/data/runna_ics_client.dart`; `lib/features/integrations/application/runna_{ics_parser,transformer,sync_service}.dart` |
| TP write-back | `lib/features/integrations/application/tp_writeback_{service,formatter}.dart` |
| Garmin edge functions | `supabase/functions/garmin-*/`, `supabase/functions/_shared/garmin/` |
| Fixtures | `test/fixtures/{final_surge,training_peaks}_fixtures.dart` |
| Provider specs (PDF) | `docs/integration/*.pdf` (Garmin Activity/Health/Training/Courses/Women's) |
