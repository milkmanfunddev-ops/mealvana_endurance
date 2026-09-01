# Sentry error analysis — dev + prod (2026-07-27)

Org `milkman-24`. Two projects: `mealvana-endurance` (prod) and
`mealvana-endurance-dev`. **60 unresolved issues** in the last 90 days —
16 prod, 44 dev. Every one is categorised below.

Dashboards:
- [prod](https://milkman-24.sentry.io/issues/?project=mealvana-endurance&query=is%3Aunresolved)
- [dev](https://milkman-24.sentry.io/issues/?project=mealvana-endurance-dev&query=is%3Aunresolved)

---

## Verification pass (2026-07-28) — what was actually fixed

Each candidate below was checked against HEAD before touching it. The
staleness caveat turned out to matter more than expected: **four of the eight
ranked items were already fixed**, and their events come entirely from stale
builds.

| Item | Outcome |
|---|---|
| Drift `is_fasted` schema drift (cat 3) | **Fixed.** `schemaVersion` 14→15 + a new idempotent `from < 15` step in `app_database.dart`. |
| Schema-version CI guard (cat 3) | **Added.** `test/shared/database/schema_version_guard_test.dart` — 3 tests, all passing. |
| `integrations → users` FK (cat 2b) | **Fixed.** Parent-row guard in `integrations_repository.uploadDirtyRecords`. |
| `get-weather-forecast` 546 noise (cat 4) | **Fixed** client-side; server still needs a timeout. |
| `UnmountedRefException` (cat 1) | **Already fixed** — f65090b6, 2026-07-02. |
| Dead `upsert_user_by_device_id` RPC (cat 9) | **Already fixed** — replaced with a direct upsert. |
| `beforeSend` noise filter (cats 5, 6, 9, 12) | **Already covers** every needle proposed. |
| `events → activities` FK (cat 2a) | **Already fixed** — cfea473d, 2026-07-11. |

Detail on the two that were mis-diagnosed in the original pass:

- **UnmountedRef was not a missing-guard bug and is not open.** `build()` in
  `connect_training_controller.dart:262` already captures the repository before
  any await, in a commit whose comment names MEALVANA-ENDURANCE-A0. The same
  is true of `settingsController` (names DEV-5F) and `dailyMacrosController`.
  The reporting builds — 1.20.0+9 in prod, 1.20.0+95 in dev — predate it. The
  "lazy getter" diagnosis described the *shipped* binary, not HEAD.
- **The `beforeSend` filter was already comprehensive.** `SocketException`,
  `Failed host lookup`, `errno = 8`, `HandshakeException`, `Operation timed
  out`, `Bad file descriptor`, `Invalid login credentials`, `ink splashes may
  be invisible` and `removeChild` are all present. Categories 5, 6 (DEV-56), 9
  (DEV-5Q) and 12 (DEV-57) need nothing.

**Still open and genuinely unfixed:** the N+1 query (DEV-4C),
`startup.version_check` on the critical path, the nutrition-plan generation
anomaly (DEV-62), the `carbs_per_serving > 0` CHECK failure (DEV-65),
`Activity not found` (DEV-5Z), the three large-text-scale RenderFlex overflows,
and the server-side cause of the `get-weather-forecast` 546.

**Deliberately not done:** the `GoError: nothing to pop` sweep. 137 `.pop()`
sites against 4 total events across both projects, with no indication of which
screens are reachable with an empty stack — a blind sweep is more likely to
introduce a regression than fix one. Worth a scoped fix if it recurs on a
current build.

---

## Read this first — the release-staleness caveat

**Most prod issues are being reported by a binary we stopped building six weeks
ago.** Every prod `UnmountedRefException` and every prod 5xx sampled here
carries `release: com.milkman.mealvanaendurance@1.20.0+9` — the shipped App
Store binary. The most recent dev `UnmountedRefException` (today, 14:13) is on
`mealvana_endurance@1.20.0+95`, also stale. develop is on 1.22.x.

Consequence: **an open issue with recent events is not evidence the bug is
still in HEAD.** Before fixing anything below, check whether the fix already
landed and whether the reporting build predates it. Two confirmed cases of
exactly this are called out in category 2.

Two counts appear per issue: the 90-day event count from the issue list, and
the lifetime `Occurrences` from the issue detail. Both are given where known.

---

## Category 1 — Riverpod lifecycle: `UnmountedRefException`

**6 issues · ~200 lifetime events · 16 users · the largest single cluster.**

| Issue | Env | Provider | Events (90d / lifetime) | Users | Last seen |
|---|---|---|---|---|---|
| [MEALVANA-ENDURANCE-A0](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-A0) | prod | `connectTrainingController` | 54 / 95 | 8 | 2d |
| [DEV-45](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-45) | dev | `connectTrainingController` | 29 / 72 | 5 | **today** |
| [DEV-5J](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5J) | dev | `connectTrainingController` | 12 | 2 | 14d |
| [DEV-59](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-59) | dev | `connectTrainingController` | 1 | 1 | 26d |
| [MEALVANA-ENDURANCE-A9](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-A9) | prod | `dailyMacrosController` | 1 | 1 | 8d |
| [DEV-5F](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5F) | dev | `settingsController` | 1 | 1 | 23d |

### Root cause — confirmed, and it is *not* a missing `ref.mounted` check

`connect_training_controller.dart` already has **32** `ref.mounted` guards, so
the obvious diagnosis is wrong. The stack points somewhere else:

```
at ConnectTrainingController.build      (connect_training_controller.dart:339)
at ConnectTrainingController._integrationsRepo (connect_training_controller.dart:204)
at Ref.read                             (ref.dart:479)
at Ref._throwIfInvalidUsage             (ref.dart:177)
```

Line 204 is a **repository getter**:

```dart
IntegrationsRepository get _integrationsRepo => ref.read(integrationsRepositoryProvider);
```

The guards protect the `await` sites. The getters don't. `build()` awaits, the
provider is disposed mid-flight, execution resumes, and the *next getter access*
calls `ref.read` on a dead Ref. Guarding after the await doesn't help when the
throwing call is the getter on the line after it.

### Strategy

1. **Fix the shape, not the site.** Make every repository getter in the
   controller resolve once, eagerly, at the top of `build()` — before any
   `await` — and hold them in fields. A disposed Ref then cannot be touched
   after an async gap because no `ref.read` survives past the first suspension.
2. **Sweep the pattern.** `grep` for `get _[a-zA-Z]* => ref.read(` across
   `lib/features/**/providers/`. Same latent bug wherever a lazy getter is used
   after an await. `dailyMacrosController` and `settingsController` are already
   two more instances.
3. **Cancel the work.** `ref.onDispose` should cancel the in-flight integration
   sync so the continuation never runs at all — belt and braces over (1).
4. **Don't ship a prod fix on its own.** Prod events are all on 1.20.0+9. This
   is Dart-only, so it is Shorebird-patchable onto `release/1.20` — but per
   `project_shorebird_prod_patch_120`, backport onto the release branch, never
   patch from dev.

---

## Category 2 — Referential integrity on sync (Postgres FK 23503)

**3 issues · the highest event volume in the whole dataset.**

| Issue | Env | Constraint | Events (90d / lifetime) | Users |
|---|---|---|---|---|
| [MEALVANA-ENDURANCE-3W](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-3W) | prod | `integrations_user_id_fkey` | 28 / **339** | 2 |
| [DEV-5K](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5K) | dev | `events_activity_id_fkey` | 61 | 3 |
| [DEV-40](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-40) | dev | (same, aggregated) | 3 | 3 |

### 2a. `events → activities` — **already fixed, do not re-fix**

`sync_coordinator.dart:194` carries a comment naming this exact constraint, and
the dependency-ordering fix landed in **cfea473d (2026-07-11)**, which is on
`develop`, `main` *and* `release/1.22.0`. DEV-5K's last event is 2026-07-23 on
`1.21.1+107` — a build that predates the fix.

**Strategy: verify, don't rebuild.** Confirm zero new events on the next dev
build that carries cfea473d, then resolve DEV-5K and DEV-40 in Sentry.

### 2b. `integrations → users` — **live, unfixed, and the real one**

339 lifetime occurrences, still firing 3 days ago on **1.22.0+88**, and the
context is decisive:

- `view_names: ["onboarding"]`
- `user: id:anonymous`
- `url: supabase:integrations:upsert`, `method: UPSERT`
- `level: warning` — so it is **not** surfacing as an error to anyone

The app upserts an `integrations` row during onboarding **before the `users`
row exists remotely**. No guard exists: `grep` for `ensureUserRowExists` /
`_ensureUserExists` returns nothing.

**Strategy:**
1. Register `users` as a hard dependency of `integrations` in
   `SyncCoordinator._dependencies` — the same mechanism that fixed 2a. This is
   the structural fix and it reuses machinery that already works.
2. Until the user row is confirmed remote, keep the integration **local-only**
   with `needs_upload = true` rather than attempting the upsert. Offline-first
   already models this; the onboarding path is just skipping it.
3. Raise the level from `warning` to `error` for FK violations. A 339-event
   integrity failure that nobody saw is a monitoring failure as much as a code
   one.
4. **Check `uploadDirtyRecords()`'s return value** at this call site — per
   CLAUDE.md it swallows exceptions into a silent `UploadResult.failed()`.

---

## Category 3 — Local Drift schema drift → **client-side data loss**

**3 issues · 4 users each · newest cluster · highest severity per user.**

| Issue | Env | What | Users | Last seen |
|---|---|---|---|---|
| [DEV-60](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-60) | dev | `schema_integrity_validation_failed` | 4 | 2d |
| [DEV-61](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-61) | dev | `startup_database_initialization_exception` | 4 | 2d |
| [DEV-65](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-65) | dev | `CHECK constraint failed: carbs_per_serving > 0` | 1 | 21h |

### Root cause — confirmed exactly

DEV-60's context is unambiguous:

```
context: "Table \"activities\" missing columns: is_fasted"
old_schema_version: 14
new_schema_version: 14
```

`isFasted` was added to `activities_table.dart:68`, but
`app_database.dart:248` still reads `int get schemaVersion => 14`, and the
migration ladder ends at `if (from < 14)`. **Drift's `onUpgrade` never runs when
`from == to`**, so any device already at v14 never gets the column. The startup
integrity check catches it and *wipes and rebuilds the local database* — which
is the safety net working, but the user loses unsynced local data.

**This will hit prod the moment `feat/persist-is-fasted` ships.**

### Strategy

1. **Bump `schemaVersion` to 15** and add a `from < 15` step doing an
   idempotent `ALTER TABLE activities ADD COLUMN is_fasted`. Idempotent because
   web Drift re-runs `onUpgrade` (see `project_web_db_migration`).
2. **Add a CI guard.** A test that fails when a Drift table gains a column
   without a `schemaVersion` bump would have caught this at the commit. This is
   the highest-leverage item in this whole document — it converts a class of
   silent data-loss bugs into a red build.
3. DEV-65 (`carbs_per_serving > 0`) is the same family: a CHECK constraint
   rejecting real data. `app_database.dart:490` already documents a deliberate
   in-place CHECK repair without a version bump — extend that pattern here, and
   find out which food is being written with a non-positive carb value.

---

## Category 4 — Edge function failures (5xx / 546)

**9 issues · ~45 events.** All via `FunctionsClient.invoke`.

| Status | Issues | Function / surface |
|---|---|---|
| 502 | [AA](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AA) (9), [AB](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AB) (3), [DEV-47](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-47) (15), [DEV-5P](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5P) (6) | `settings.connected_apps_row` |
| 500 | [AF](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AF) (6), [DEV-5T](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5T) (2) | unspecified invoke |
| 546 | [AH](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AH) (4), [DEV-5D](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5D) (2), [DEV-5C](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5C) (1) | `get-weather-forecast` |

**546 is a Supabase Edge worker limit** — the function exceeded memory or CPU
and was killed. AH's stack is
`WeatherService._fetchWeatherFromAPI → FunctionsClient.invoke`, hitting
`/functions/v1/get-weather-forecast`, with `response.status_code: 546`.

The 502 cluster is concentrated on one surface: the connected-apps row in
Settings, on both environments.

### Strategy

1. **`get-weather-forecast` first** — it's the only one with a named function
   and a reproducible signature. Check its upstream weather-API call for an
   unbounded response or a missing timeout; 546 usually means it hung until the
   worker was reaped. Weather is decorative: **it must degrade silently**, not
   throw into the UI.
2. **Classify 5xx as infrastructure, not app errors.** All nine are
   server-side failures the client can only retry. Add bounded exponential
   retry in the Supabase functions client wrapper, and only report to Sentry
   after retries are exhausted. That will collapse most of this category.
3. **Pull the edge logs** for `settings.connected_apps_row`'s callee over the
   same windows (`supabase functions logs`) — the client-side 502 tells you
   nothing about *why*.

---

## Category 5 — Transient network / offline

**13 issues · ~130 events · almost entirely dev.**

`OSError: nodename nor servname provided` ([DEV-4F](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-4F) 73 events,
[DEV-4B](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-4B) 29) · `AuthRetryableFetchException`
([DEV-4G](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-4G) 11, [DEV-5](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5) 5, [DEV-43](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-43) 1) ·
`HandshakeException` ([DEV-51](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-51), [DEV-52](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-52)) ·
`ClientException: Bad file descriptor` ([DEV-5M](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5M), [DEV-5B](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5B)) ·
`Operation timed out` ([9F](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-9F) prod, [DEV-4W](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-4W)) ·
`Connection closed` ([DEV-54](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-54), [DEV-5N](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5N))

`nodename nor servname provided` is DNS failing outright — a laptop sleeping or
a simulator losing its network. These are **environmental, not defects**.

### Strategy

**This is noise and should be filtered at the SDK, not triaged.** A shared
`beforeSend` filter already exists across all four `main` entrypoints (see
`project_sentry_error_cleanup`); it just doesn't cover these classes. Extend it
to drop `SocketException`, `HandshakeException`, `OSError errno 8`,
`Bad file descriptor`, and `AuthRetryableFetchException` **when the device is
offline**. Keep them when the device is online — an online DNS failure is real.

Two caveats: 9F is **prod**, and `food_preferences` timing out for a real user
is worth a look at that query's shape. And DEV-5N is a 404-ish storage read for
`recipe-images/greek-yogurt-parfait.jpg` — that's a **missing asset**, not a
network blip; verify the recipe image exists in the bucket.

---

## Category 6 — UI layout / render

**4 issues · 162 events · 1–2 users.**

| Issue | What | Events |
|---|---|---|
| [DEV-56](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-56) | `ListTile background color or ink splashes may be invisible` | **113** |
| [DEV-5G](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5G) | `RenderFlex overflowed by 78 pixels on the bottom` | 30 |
| [DEV-5H](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5H) | `RenderFlex overflowed by 6.0 pixels on the bottom` | 16 |
| [DEV-5S](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5S) | `RenderFlex overflowed by 62 pixels on the right` | 3 |

DEV-56 is the single highest event count in either project and is a **debug-mode
assertion** — it cannot fire in release. Note also that DEV-45's reporter has
`text_scale: 1.65` and A0's has `0.94`: the overflows are very likely
**dynamic-type** failures, not fixed-layout bugs.

### Strategy

1. Filter `FlutterError` assertions of the "may be invisible" family out of
   Sentry entirely — they are lints, and 113 events of lint is drowning signal.
2. Fix the three overflows properly: they correlate with large text scale.
   Reproduce at `text_scale: 1.6` before assuming a layout constant is wrong.
   The 78px and 62px ones are user-visible.
3. Add a large-text-scale pass to the widget smoke suite
   (`test/smoke_tests/`) so overflow regressions fail in CI.

---

## Category 7 — Navigation

[8Y](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-8Y) (prod, 1) and
[DEV-5R](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5R) (dev, 3):
`GoError: There is nothing to pop` in `GoRouterDelegate.pop`.

`canPop` guards were added in the Sentry cleanup pass, so these are residual
sites. **Strategy:** find the remaining unguarded `.pop()` calls
(`grep -rn "\.pop()" lib --include="*.dart"` cross-referenced against
`canPop`), and prefer a shared `safePop()` helper over guarding each site — the
per-site approach is what left these behind.

---

## Category 8 — Performance

**12 issues.** Instrumentation firing, not crashes.

Slow spans: `startup.total` ([AP](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AP), [DEV-5W](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5W)) ·
`startup.version_check` ([AQ](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AQ)) ·
`dashboard.integration_sync` ([AK](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AK), [DEV-63](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-63)) ·
`deferred.notifications` ([AJ](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AJ), [DEV-5Y](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5Y)) ·
`daily_macros.calculate_week` ([AR](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AR)) ·
`navigation.first_frame` ([AM](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AM)) ·
`dashboard.activities.background_sync` ([DEV-64](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-64)).
Plus [DEV-4C](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-4C) **N+1 Query** (12 events) and
[DEV-53](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-53) **App Hanging ≥2000ms** (`__psynch_cvwait` — a blocked main thread).

### Strategy

1. **Set thresholds before triaging.** These fire against defaults; a "slow
   operation" with no agreed budget is not a finding. Set explicit budgets
   (e.g. startup.total ≤ 2.5s) and only alert past them.
2. **`startup.version_check` on the startup critical path is the actionable
   one** — a network call gating launch. It belongs in the deferred/recoverable
   phase per the initialization invariant in CLAUDE.md, not in blocking startup.
3. **DEV-4C (N+1) is the real bug here.** Find the loop issuing per-row queries
   and batch it. N+1 is a correctness-of-design issue that gets worse with data
   volume — unlike the span warnings, it will not fix itself.
4. DEV-53 (main-thread hang) — correlate with the MetricKit payloads in
   category 10, which carry hang diagnostics.

---

## Category 9 — Legacy / dead code paths

- [DEV-4](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-4) — `PGRST202: Could not find the function public.upsert_user_by_device_id`.
  4 events, 2 users. **The RPC does not exist.** This is the pre-anonymous-auth
  device-id path still being called. The RLS audit found the same fossil:
  136 device-only user rows, none created since 2025-12-17, and no `x-device-id`
  header is sent by the client any more.
  **Strategy: delete the call site.** Do not recreate the RPC. Also drop the
  now-dead `device_id` branches from the `coaches` and `integrations` RLS
  policies while you're there.
- [DEV-5Q](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5Q) — `AuthApiException: Invalid login credentials`.
  1 event. **Working as designed** — a user mistyped a password. Should never
  have reached Sentry. Add `invalid_credentials` to the `beforeSend` filter.

---

## Category 10 — Diagnostics, not errors

[AN](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-AN) (prod, 10),
[DEV-5V](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5V) (dev, 26, firing continuously),
[DEV-5X](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5X) (dev, 2): **MetricKit** metric and diagnostic payloads.

These are iOS telemetry, not failures. **Strategy:** they should not sit in the
unresolved *issue* stream — route them to performance/diagnostics or disable
MetricKit issue creation. Mine DEV-5X's hang diagnostics once, for category 8.

---

## Category 11 — Domain anomalies (custom instrumentation)

- [DEV-62](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-62) — **Nutrition plan generation anomaly**, 3 events, 2 users,
  last seen *minutes* ago. This is our own probe firing on the rebuilt formula
  engine. **Strategy: highest-value item in this category** — pull the event
  payloads and cross-reference `plan_generation_log` on dev (added during the
  formula-engine rebuild). This is the engine telling us it produced something
  it doesn't believe in.
- [DEV-5Z](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-5Z) — `Exception: Activity not found` in
  `ActivityDetailController.build`. 2 events. Navigating to an activity deleted
  or not-yet-synced. **Strategy:** render an empty/"removed" state rather than
  throwing.

---

## Category 12 — Web only

[DEV-57](https://milkman-24.sentry.io/issues/MEALVANA-ENDURANCE-DEV-57) — `TypeError: Cannot read properties of null (reading 'removeChild')`,
2 events, `HTMLDocument.<anonymous>(main.dart)`. Flutter-web DOM teardown race,
almost always the splash/loader element being removed twice.
**Strategy:** null-check before `removeChild` in `web/index.html`. Low priority
— web is not a shipping surface.

---

## Recommended order of work

Ranked by user harm per unit of effort, not by event count.

| # | Item | Why first |
|---|---|---|
| 1 | **Drift `schemaVersion` 14→15 for `is_fasted`** (cat 3) | Silently wipes local data. Will hit prod the moment that branch ships. Fix is ~10 lines. |
| 2 | **CI guard: table column added without a version bump** (cat 3) | Turns an entire class of data-loss bugs into a red build. |
| 3 | **`integrations → users` FK ordering** (cat 2b) | 339 occurrences, live on 1.22.0+88, and logged at `warning` so nobody saw it. |
| 4 | **Repository-getter fix for `UnmountedRef`** (cat 1) | Largest cluster, 16 users, and the current diagnosis is wrong — worth fixing properly once. |
| 5 | **`beforeSend` filter extension** (cats 5, 6, 9) | Removes ~250 events of noise across ~17 issues. Everything after this is easier to see. |
| 6 | **`get-weather-forecast` 546 + 5xx retry policy** (cat 4) | Collapses 9 issues; weather should degrade silently. |
| 7 | **Nutrition plan generation anomaly** (cat 11) | Firing right now against the new engine. Unknown severity — that's the point. |
| 8 | **N+1 query + startup.version_check** (cat 8) | Real perf defects, distinct from threshold noise. |
| 9 | Overflows at large text scale (cat 6), residual `safePop` (cat 7), dead device-id RPC (cat 9) | Genuine but low blast radius. |

### Two cross-cutting actions

- **Resolve what's already fixed.** DEV-5K and DEV-40 (events FK) are fixed in
  develop/main/release-1.22.0 by cfea473d; their events come from older builds.
  Confirm on the next dev build and close them. Leaving fixed issues open is
  what makes the board untrustworthy.
- **Tag by release and filter stale builds.** Prod issues are dominated by
  1.20.0+9 and dev by 1.20.0+95. Until stale installs are excluded, event
  counts measure *who hasn't updated*, not *what's broken*.
