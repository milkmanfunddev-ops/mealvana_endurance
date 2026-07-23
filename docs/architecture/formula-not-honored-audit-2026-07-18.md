# Audit: "My formula wasn't honored" — during-workout formula selection

**Date:** 2026-07-18
**Trigger:** Bug report — user created a cycling >90 min formula containing a high-carb drink
mix, then created a ~75 min cycling activity and saw a generic formula instead.
**Scope:** DEV Supabase (`vlmtsdzpnjnavdgytcmi`), `generate-nutrition-plan-v3`, `formula_kit`,
`nutrition_plan`, new-activity → activity-detail navigation.
**Status:** Investigation complete. Recommendation 1 (surface skipped personal formulas) is
implemented and deployed to DEV (`generate-nutrition-plan-v3` v72 → v73); PROD deferred. The
remaining recommendations in §3 are not yet implemented.

---

## 1. What the server data shows

### 1.1 The reported session never reached Supabase

Complete write timeline for 2026-07-17 → 2026-07-18 across `activities`, `personal_formulas`,
and `formula_pins` (all users):

| Time (UTC) | User | Write |
|---|---|---|
| 07-17 09:08:19 | claudia@fit4athletes.com | activity "10 Mile easy Ride", cycling, `duration_minutes` NULL, no plan |
| 07-17 09:08:54 | claudia@fit4athletes.com | identical duplicate, 35s later |
| 07-17 09:46:15 | lee.b.martin | activity "12 mi Run", 108 min, has plan |
| 07-18 00:03:06 | lee.b.martin | formula "Patrol During 1784332980059" (automated Patrol run) |
| 07-18 00:03:07 | lee.b.martin | pin → that formula, immediately soft-deleted |
| 07-18 04:38:39 | lee.b.martin | activity "12 mi Run", 108 min, has plan |

**No personal formula in the entire database — 21 rows, all users, all time — targets cycling
with a high-carb drink mix.** Xuan's (`xh.analytics@gmail.com`) last formula was 07-05 and her
last pin activity was 05-28, so the session was not hers.

Conclusion: the formula from the repro is **local-only on the reporter's device**, or was never
saved. See finding B.

### 1.2 Totals

- `activities`: 1054 — 354 with a persisted `nutrition_plan_data`
- `personal_formulas`: 21
- `formula_pins`: 74

### 1.3 Persisted `pin_decision` values are almost all ephemeral fallbacks

Of 354 stored plans, 32 contain a `pin_decision` and **0 contain `template_metadata`**.
Nearly every stored decision looks like this:

```json
"pin_decision": {
  "used_pin": true,
  "ephemeral": true,
  "pin_set_size": 0,
  "fallthrough_reason": null,
  "pinned_template_id": "82140d8a-…",
  "pinned_template_name": "Banana"
}
```

`pin_set_size: 0` with `used_pin: true` means **the user had no pins at all** and the ephemeral
default-formula safety net produced the result. Only one sampled plan
(`wmjnqmqtpb…`, "Easy", 55 min) shows a genuine pin: `pin_set_size: 1`, no `ephemeral` flag.

This is the strongest signal in the dataset: real user pins are rare, so nearly every plan is a
generic fallback that the UI then reports as "no pin found".

---

## 1.4 Every account active on 7/17 — exhaustive

Enumerated via `auth.audit_log_entries` + `last_sign_in_at`, not just table writes:

| Signed in 7/17–7/18 | Activities | Formulas | Pins |
|---|---|---|---|
| claudia@fit4athletes.com | 2 (the duplicates) | 0 | 0 |
| lee.b.martin@gmail.com | 2 | 1 (Patrol) | 1 (Patrol, deleted) |
| wmjnqmqtpb@privaterelay.appleid.com | 0 | 0 | 0 |
| kkb8y7gvtm@privaterelay.appleid.com — **new Apple signup, created 7/17 17:52** | **0** | **0** | **0** |
| 5 × anonymous sessions (7/17 15:31 → 7/18 07:30) | **0** | **0** | **0** |

`test@test.com` last signed in **06-30**; `xh.analytics@gmail.com` last signed in **07-08**.
Neither was active. No account remains unchecked.

A brand-new Apple user signed up, signed in three minutes later, and wrote **zero rows** — no
profile, no activity, no formula, no pin. Combined with five anonymous sessions that also wrote
nothing, this is consistent with either an unfinished onboarding or a silent sync failure
(cause B).

---

## 2. Live reproduction — CONFIRMED

Reproduced against the deployed DEV function. Read-only: `generate-nutrition-plan-v3` contains no
`insert`/`upsert`/`update`/`delete` calls (verified by grep across the function and
`_shared/nutrition/`), so no rows were written.

Test user (existing DEV data, read-only lookup): `device_id 4e9e7e38-3e97-4a4f-8acb-7296d4adb5ee`,
with a **pinned** during personal formula `760e93c7-…` "Carb Drink Mix + Stroopwafel + Water"
(`activities: ["cycling","triathlon_bike"]`, `durations: ["90-150 min","150-240 min","> 240 min"]`)
**and** a `during_system` pin `037500d6-…` "Sports Drink Only".

Only `duration_minutes` varied; everything else held constant (`activity_type: cycling`,
`gut_training_level: moderate`, identical `macro_targets`).

| `duration_minutes` | `pin_decision` | Result |
|---|---|---|
| **75** | `used_pin: true`, `pinned_template_name: "Sports Drink Only"`, `fallthrough_reason: null`, `pin_set_size: 1` | ❌ personal formula dropped |
| **89** | same — "Sports Drink Only" | ❌ dropped |
| **90** | `used_pin: true`, `pinned_template_name: "Carb Drink Mix + Stroopwafel + Water"` | ✅ honored |
| **100** | same — honored | ✅ honored |
| **omitted** | honored (identical to 100) | ✅ honored |
| **explicit `null`** | `used_pin: false`, `fallthrough_reason: "no_pin_for_scope"`, `pin_set_size: 0` | ❌ dropped |

**The boundary is exactly 90.** 89 → dropped, 90 → honored.

### 2.1 The actual defect: the response lies about what happened ⭐⭐

At 75 minutes the function returns **`used_pin: true` with `fallthrough_reason: null`, naming a
different pin** — the user's unrelated `during_system` pin, which fired at
`during-phase.ts:556-569`.

So the wire response affirmatively tells the client *"a pin was honored"*. The pin banner renders
its green "pinned formula used" state while the user's personal formula was silently discarded.
From the user's side this is indistinguishable from the app ignoring their formula outright —
**which matches the reported symptom precisely** ("I got the same formula as before, or some
formula that didn't have high carb drink mix in it").

There is a `personal_formula_empty` fallthrough reason (`during-phase.ts:466-472`) for the
"matched but rendered zero components" case, but **no equivalent for "a personal formula exists
for this phase but was excluded by duration or activity scope."** That missing signal is the
single highest-value fix in this document.

### 2.2 `null` and `undefined` diverge — a live trap

`personal-formula-pins.ts:93-98`:

```ts
if (durs !== null && durs.length > 0 && durationMinutes !== undefined) {
  if (!durs.includes(durationBracket(durationMinutes))) continue;
}
```

- `undefined` → guard is false → duration check **skipped entirely**, formula matches any duration
- `null` → `null !== undefined` is **true** → check runs; `durationBracket(null)` coerces null→0 →
  `"< 90 min"`. **A JSON `null` silently means "under 90 minutes."**
- `0` → same as null

Meanwhile the template solver gate (`during-phase.ts:477`) treats `null`, `undefined`, and `0` as
uniformly falsy. The two gates disagree about what a missing duration means.

The Flutter client currently omits the key rather than sending null
(`nutrition_plan_service.dart:196`), so this is latent — but any other caller that sends an
explicit null gets every duration-scoped formula rejected.

### 2.3 Request contract

`PlanInputV2` — `generate-nutrition-plan-v3/types.ts:16-89`. Required (`index.ts:107-115`):
`device_id`, `macro_targets`, `hours_before >= 0`. Effectively required for the during path:
`macro_targets.during_run` (absent → `index.ts:271` short-circuits during to `{foods: []}`),
`activity_type` (defaults to `"running"` at `index.ts:118`), `duration_minutes`,
`gut_training_level`. Note `duration_minutes` is a **top-level sibling** of `macro_targets`, not
nested inside it.

---

## 3. Root causes

### A. Saving a formula does not pin it — and only *pinned* formulas are ever matched ⭐

`formula_editor_controller.dart:255-300` constructs the `PersonalFormula` and saves it. There is
**no pin logic anywhere in that file**; the only mention of pins is a doc comment at line 60.

The edge function only ever sees pinned formulas:
`generate-nutrition-plan-v3/index.ts:220-223` calls `fetchUserPinnedTemplateIds`
(`_shared/nutrition/pins.ts:97`), which reads `formula_pins` and hydrates `personal_formulas`
from those rows (`pins.ts:161-205`).

**A saved-but-unpinned formula is completely inert.** This reproduces the report exactly and is
independent of sport, duration, or navigation. Corroborated by §1.3 (`pin_set_size: 0`).

### B. Formula/pin sync is fire-and-forget and fails silently

`personal_formulas_repository.dart:264-300` — offline-first write with `needs_upload = true`,
followed by a **non-blocking** upload. Per the standing project rule, `uploadDirtyRecords()`
swallows exceptions into a silent `UploadResult.failed()`. A formula can sit in Drift with
`needs_upload = true` indefinitely with no user-visible error and no server row. Consistent with
§1.1.

### C. Duration is a hard gate, not a score

`_shared/nutrition/personal-formula-pins.ts:62-67`:

```ts
function durationBracket(durationMinutes: number): string {
  if (durationMinutes < 90)  return "< 90 min";
  if (durationMinutes <= 150) return "90-150 min";
  if (durationMinutes <= 240) return "150-240 min";
  return "> 240 min";
}
```

and the gate at `:95` — `if (!durs.includes(durationBracket(durationMinutes))) continue;`

A 75-minute ride buckets to `< 90 min`, so a `> 90 min` formula is skipped outright and the
generic `< 90 min` system template is used. There is **no partial-honor or scaled-quantity
path** — the decision is binary. This is working as designed but contradicts the user's mental
model ("my formula, scaled to this ride"). **Confirmed live — see §2.**

### C2. Complete list of silent-drop conditions

A pinned during personal formula is skipped when **any** of these hold
(`personal-formula-pins.ts:89-101`):

1. **Duration bracket miss** — the reported case. 75 min → `"< 90 min"`, not selected by the user.
2. **Activity miss** — `activities` non-empty with no overlap against `mapActivity(activity_type)`
   (`:69-76`). Note `mapActivity` does **not** map `cycling` → `triathlon_bike`, so a formula
   scoped only to `triathlon_bike` never fires on a plain cycling workout.
3. **Explicit `duration_minutes: null`** — coerces to the `< 90 min` bracket (§2.2).
4. **Not pinned**, or `formula_pins.is_deleted = true`, or the `device_id` fails to resolve to a
   `users` row (`pins.ts:104-114`, logs `[PINS] No user found for device_id`) — the formula is
   never loaded at all.
5. **Ordering** — `matchPersonalFormulaPin` returns the *first* in-scope match by
   `personal_formulas.updated_at DESC`. If two formulas are both in scope, the older one is
   permanently unreachable with no indication.

Cases 1 and 2 emit **no telemetry whatsoever**, and per §2.1 the response actively reports a
different pin as honored.

### D. Draft activities are never deleted

Tapping **Generate Plan** writes a real row with `status: draft` before the edge function is
called — `macro_targets_controller.dart:627-643`, repeated per sport at `:843`, `:1119`, `:1347`.

Cleanup is registered on `ref.onDispose` in `MacroTargetsController.build()` (`:295-306`), but
that controller is `@Riverpod(keepAlive: true)` (`:236`), so `onDispose` never fires on
navigation. The only invalidation sites are sign-out paths
(`settings_controller.dart:332`, `:406`; `auth_listener_service.dart:202`).

Even at logout it bails: `_scheduleCleanupIfNeeded` (`:2291-2302`) requires `_lastKnownUserId`,
which is only assigned inside `createNutritionPlan()` — so a draft abandoned *before* Create Plan
is skipped unconditionally.

`DraftActivityCleanupService` (`draft_activity_cleanup_service.dart:35-104`) is correct and
well-written. **It is simply never invoked.** No list query filters `status: draft`, so abandoned
drafts render as normal activities. This is the likely cause of Claudia's two identical rows
35 seconds apart.

### E. Sport controllers are `keepAlive` while the coordinator is `autoDispose`

`cycling_input_controller.dart:173` (and running/swimming/brick) are `keepAlive`;
`newActivityCoordinatorProvider` is `autoDispose`. On a second activity the tab and date reset
while distance/pace/title persist.

The codebase already hand-patches this in `initState` (`new_activity_screen.dart:304-314`, with a
comment explaining the staleness) — but **`initState` does not re-run on back-navigation**,
because `NewActivityScreen` stays mounted beneath the pushed routes. This matches the reported
repro path (back to new-activity rather than to the dashboard).

### F. The global un-keyed macro cache defeats its own sport guard

`macro_repository.dart:282-289` writes `macro_targets.cached` with no activity scoping. The keyed
read has a sport guard at `:353-366` whose comment describes this exact bug class ("a Run created
right after a Cycling plan would inherit cycling templates") — but
`macro_targets_controller.dart:1785` bypasses it:

```dart
macroTargets ??= await repository.getCachedMacroTargets();  // global, sport-agnostic
```

On a keyed miss, the previous activity's targets are used verbatim. A direct mechanism for
"I got the same formula as before".

### G. The UI structurally cannot report which formula was used

`template_metadata` (template id, number, name, formula) is emitted by the edge function
(`index.ts:363-365`, built at `during-phase.ts:645-650`) and **never parsed** —
`nutrition_plan_mapper.dart:138-162` reads only `foods`, `by_hour_data`, and `pin_decision`.
`PlanSection` has no `templateName` field. A grep for `template_metadata` across `lib/` returns
zero hits, and §1.3 confirms it appears in 0 of 354 stored plans. Same for `after_metadata` and
during-phase `shortfalls` (`index.ts:366-371`).

Worse, `pin_banner_rows_builder.dart:68-69` discards ephemeral decisions outright:

```dart
PinDecision? realDecision(PinDecision? d) => (d != null && !d.ephemeral) ? d : null;
```

So the During header is a hardcoded `'During'` literal
(`nutrition_sections_builder.dart:682-687`) and the banner reads *"No pin found."* Neither the
user nor a triager can tell what happened. Analytics suppresses it too
(`macro_targets_controller.dart:2177`).

### H. Two duration bugs adjacent to this one

- `during-phase.ts:477` gates the entire template path on
  `if (gutTrainingLevel && durationMinutes && durationMinutes > 0)`. Claudia's activities have
  `duration_minutes = NULL`, so they fall past template selection straight to the rule solver.
- `personal-formula-pins.ts:95`: when `durationMinutes` is undefined the duration check is
  **skipped entirely**, so a `> 90 min` formula fires on *any* duration — the exact inverse of the
  system-template path, which demands an exact bracket match.

### I. Empty targeting silently means "match everything"

`activityInScope` (`personal-formula-pins.ts`) returns `true` when `activities` is null or empty,
and the duration gate is skipped when `durations` is null/empty:

```ts
if (formulaActivities === null || formulaActivities.length === 0) return true;
```

A during-phase formula saved without tapping any chips becomes a **universal wildcard** that
outranks everything (first match wins, ordered `updated_at DESC`). No validation, no default.

All 5 `from_scratch_formula` rows have NULL `activities` and `durations`. Mostly benign —
before-phase formulas render no chips (`formula_editor_screen.dart:405-460`) — but the Patrol
*during* formula is a live wildcard.

### J. The offline client fallback contradicts the server

`client_plan_service.dart:463-481` — `_personalFormulaInScope` takes no duration parameter,
documented as intentional at `:394-396`. Offline, a `> 90 min` formula **would** fire on a 75-min
ride. Same user, same data, opposite result depending on connectivity, and no `pinDecision` is
emitted either way.

### K. Minor

- `activityDetailControllerProvider` is a family keyed on `(activityId, isNewActivity)` rather
  than `activityId` alone (`activity_detail_controller.dart:64-67`) — one activity becomes two
  independent cached provider instances.
- `clearCachedMacroTargets()` (`macro_repository.dart:514-517`) clears only global keys;
  per-activity SharedPreferences keys leak permanently.
- The mapper calls `fromEdgeFunctionJson` without `activityType`, defaulting to
  `ActivityType.running` (`plan_section.dart:314`), so a cycling plan renders as **"During Run"**.
- `activities.created_at` is `timestamp WITHOUT time zone` while `personal_formulas.created_at`
  and `formula_pins.created_at` are `timestamptz`. Cross-table time correlation is silently wrong.
  This actively obstructed this investigation.

---

## 3. Recommendations

### ✅ IMPLEMENTED — recommendation 1 (2026-07-18)

`skipped_personal_formulas` now rides alongside the rest of `pin_decision`, so a
scope-excluded personal formula stays visible no matter which template ultimately wins.

**Edge function**
- `_shared/nutrition/personal-formula-pins.ts` — new `collectPersonalFormulaSkips()`, mirroring
  the scope gates in `matchPersonalFormulaPin` exactly (verified at the 90-minute boundary by
  test). Purely additive; the matcher is untouched.
- `generate-nutrition-plan-v3/types.ts` — `skipped_personal_formulas?` added to `pin_decision`.
- `generate-nutrition-plan-v3/during-phase.ts` — skips computed when no formula matches, then
  **preserved across all four decision-overwrite sites** (system pin, ephemeral default,
  unrenderable downgrade, set-size refinement). The system-pin site was the specific overwrite
  that produced the reported symptom.

**Client**
- `formula_kit/domain/pin_decision.dart` — `SkippedPersonalFormula` + `SkippedFormulaReason`,
  parsed forward-compatibly (an unknown reason degrades to a generic line rather than throwing).
- `nutrition_plan/presentation/utils/pin_banner_rows_builder.dart` — an ephemeral decision
  carrying skips is no longer filtered out. This mattered: the ephemeral default-formula path is
  the most common way to hit the bug, and the old filter swallowed it entirely.
- `formula_kit/presentation/widgets/pin_status_banner.dart` — header can no longer read
  "Using your pinned formulas" when a formula was skipped; a "?" affordance opens a sheet naming
  the formula, what it targets, what this workout was, and a CTA to edit its targeting.

**Tests** — 8 new Deno tests, 11 new Dart tests, all green; 101 Dart + 30 Deno in the surrounding
suites still pass.

**Deployed to DEV** 2026-07-18 18:30 UTC — `generate-nutrition-plan-v3` v72 → **v73**.
PROD deferred (dev verification first).

`generate-macros-v4` transitively bundles `personal-formula-pins.ts` but never calls the new
export, so its behavior is unchanged and it was intentionally not redeployed.

Verified live against the deployed function, same user, only `duration_minutes` varied:

- **75 min** → `used_pin: true` ("Sports Drink Only") **plus** `skipped_personal_formulas`
  naming "Carb Drink Mix + Stroopwafel + Water" as `duration_out_of_scope`
  (`formula_durations: ["150-240 min","> 240 min","90-150 min"]`, `workout_bracket: "< 90 min"`).
  A second formula, "Gel + Water", is correctly reported as `activity_out_of_scope`.
  **This is the reported bug, now self-reporting on the wire.**
- **100 min** → formula honored, `skipped_personal_formulas` absent. No noise when it works.

### Fix now

1. ~~**Stop reporting a different pin as honored.**~~ ✅ Done — see above. When a personal formula exists for the phase but
   is excluded by duration or activity scope, emit a dedicated `fallthrough_reason`
   (`personal_formula_out_of_scope`) carrying the formula name and the reason. Today the response
   says `used_pin: true` and names an unrelated system pin, so the UI shows a green "pinned
   formula used" state for a formula the user never chose. This is the defect that makes the bug
   invisible to both the user and to triage. (Cause §2.1)
2. **Auto-pin on formula create**, or block the save with an explicit "Pin this formula to use
   it?" step. A saved-but-unpinned formula is inert. (Cause A)
3. **Surface the honored formula name** in the During section header — stop discarding
   `template_metadata`. Converts every future report of this class from guesswork into a
   screenshot. (Cause G)
4. **Wire up draft cleanup.** The service is already correct; move the hook off the `keepAlive`
   provider onto a route-aware observer, or filter `status: draft` from all list queries. Fix the
   `_lastKnownUserId` early-bail. (Cause D)
5. **Make formula upload failures visible** — check the `UploadResult` and surface a retry.
   (Cause B)
6. **Normalize the null/undefined duration semantics** — treat `null`, `undefined`, and `0`
   identically in both gates. Today an explicit `null` silently means "under 90 minutes" in one
   gate and "no duration" in the other. (Cause §2.2)

### Fix next

7. Make out-of-band a *visible* outcome in the UI: "Your Carb Drink Mix formula targets 90+ min
   rides — this ride is 75 min, so we used X instead." Depends on fix 1. (Cause C)
8. Delete the global un-keyed macro cache fallback at `macro_targets_controller.dart:1785`, or
   make it respect the sport guard. (Cause F)
9. Reconcile the three duration semantics — server pin, server template, client fallback — into
   one shared helper. (Causes C, H, J)
10. Re-seed sport controllers on screen re-entry, not just `initState`; or make them `autoDispose`
    to match the coordinator. (Cause E)
11. Decide whether `mapActivity` should map `cycling` → `triathlon_bike`. Today a formula scoped
    only to `triathlon_bike` never fires on a plain cycling workout. (Cause C2.2)
12. Surface or resolve the ordering ambiguity when two formulas are both in scope — today the
    older one is permanently unreachable. (Cause C2.5)
13. Normalize `activities.created_at` to `timestamptz`. (Cause K)

### Product decisions required

10. Should an empty-targeting formula be a wildcard or invalid? Today it is a silent wildcard,
    which is probably not intended. (Cause I)
11. Should duration be a **score** rather than a hard gate — honor the user's formula and scale
    quantities, flagging the mismatch? This matches the stated expectation: *"if you ask for high
    carb drink mix, your formula has it in it."* (Cause C)

---

## 4. Open questions

1. Which account and device ran the 7/17 repro? Nothing on the server matches it. If it was a
   simulator or local build, the formula is likely still in Drift with `needs_upload = true`.
2. Was the formula pinned after creation? Highest-value single answer — confirms or eliminates
   cause A.
3. Was the 75 minutes typed, or derived from distance ÷ speed? Claudia's rows have
   `duration_minutes` NULL with 10.5 mi at 15.75 mph, which computes to 40 min, not 75. If
   duration is derived at render and never persisted, that is a separate bug.
4. Are Claudia's two duplicate rides part of this report or unrelated? Either way they are a clean
   instance of cause D.
5. Design intent on out-of-band formulas — hard exclude (today) or honor-and-scale?
