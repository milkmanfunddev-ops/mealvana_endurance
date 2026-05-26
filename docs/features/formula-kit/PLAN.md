# Formula Kit — Implementation Plan

> **Branch:** all work lands on a new branch — `feat/formula-kit`, branched from `origin/develop`. We'll create and switch to it as the first step on plan acceptance.

## Status — 2026-05-26

**PR 1 complete. PR 2 substantively done** (substeps 1–3, 5 a/b/b-followup/c, 7, 8, 9, 11 landed; 4 deferred; 6 superseded; 10 N/A under Option B; 12 = status + memory refresh, shipped as `f292cc10` 2026-05-24). PR 2 merged to `develop` (`5a5145c3`, --no-ff). Codemagic dev-ios build `6a15b4c5707ffe0c01b7682f` green (all 13 steps, artifact published).

**PR 3 inserted between PR 2 and personalization (planning landed 2026-05-26).** After-phase parity: extend Browse + Detail + Pins to `post_workout_templates`. Locked scope: filter by `travel_friendliness` only, standard portion (no scaling), pins in scope ("set it and forget it"), no brick-specific UI. Original PR 3–6 renumbered to PR 4–7. **Substep 1 (`TemplateKind.fromWireValue` crash-safety) is load-bearing** — it must ship to prod via a TestFlight cycle before the substep-2 CHECK widening can run on prod, otherwise old binaries crash reading new `'post_system'` pins.

**Substep 11 shipped 2026-05-24** as a cluster of fixes + polish:
- **PinStatusBanner V1 polish** — client-side synthesis of missing pinnable rows so users with mixed pin state across phases see all rows; two-state copy rule ("No pin found" when `pin_set_size == 0`, "Pins fell through" otherwise — forward-compat for V2 fallthrough reasons); CTA "Pin your favorite formula".
- **Onboarding banner state (Path 2)** — zero-pin user with a plan that has pinnable phases now sees a discovery banner. Collapsible (`pin_status_banner.onboarding_header` ValueKey) to keep it from dominating the activity-detail viewport. Naming-collision note: "onboarding" here is the banner's zero-pin mode, NOT the first-time user onboarding flow under `features/onboarding/` (untouched).
- **milkmanfunddev-ops/mealvana_endurance#32 — cross-device pin sync gap.** Two-part fix in `FormulaLibraryController` and `FormulaPinController` — any controller reading a `SyncableRepository` needs its own `isStale() + syncFromRemote()` gate; relying on a sibling controller is racy. Fresh-install sim verified.
- **#18 — edge function pin emission contract.** Server bug: a user with Before pins only would receive a plan where the During section silently omitted `pin_decision`. Fixed by switching `during-phase.ts` from a local-set-size derivation to an orchestrator-supplied `pinsActive` flag ("user has any pin in any scope"). Extracted `initialDuringPinDecision()` as a pure helper, locked the contract with `during-phase-pin-emission.test.ts` (3 Deno tests). Brick path left unchanged (no pin support there in V1).
- **#19 — substep 7 deferred follow-ups.** Analytics phase normalized at the emit site (`before_run` / `during_run` / `after_run` → `before` / `during` / `after`) so substep 7 events join substep 8 events in Mixpanel; `supabase/.temp/` added to `.gitignore` and 7 scratch-state files untracked. Locked with `MacroTargetsController.phaseForSectionId` unit tests in `pin_analytics_test.dart`.

Pre-existing test flake (no-pin parity tie-break in `pre-workout-pinned.test.ts:331`) filed as milkmanfunddev-ops/mealvana_endurance#33 — predates #18, not blocking. Pre-existing food-preferences UI/DB mismatch tracked separately as #30 (does NOT affect honor-pin, which reads DB truth).

### Plan revision — 2026-05-23: substep 7 prod-deploy mishap → wrapper scripts added

While deploying substep 7 edge functions to dev, `supabase functions deploy generate-macros-v4` and `... generate-nutrition-plan-v3` were run with `supabase/.temp/project-ref` pointing at **prod** (`wvmvsodrvbkxfydabqed`), not dev (`vlmtsdzpnjnavdgytcmi`). The functions deployed to prod.

**Impact assessment:** wire additions (`pin_set_size`, `pinned_template_name`) are additive and forward-compatible — prod clients on the released app ignore unknown fields (covered by `pin_decision_test.dart`'s forward-compat tests). No functional break observed.

**Required at substep 7 client release time:** before cutting the substep 7 client release, verify prod edge functions are still at substep 7 HEAD (no intervening deploy has overwritten them); otherwise redeploy via `./scripts/deploy_prod.sh generate-macros-v4 generate-nutrition-plan-v3`.

**Prevention:** added `scripts/deploy_dev.sh` and `scripts/deploy_prod.sh` wrappers that read the target ref from `.env.dev.local` / `.env.prod.local` and pass `--project-ref` explicitly, so deploys are independent of whatever `supabase/.temp/project-ref` currently points to. `deploy_prod.sh` requires an interactive `yes` confirmation. Use the wrappers, not raw `supabase functions deploy`. Known follow-up: `supabase/.temp/project-ref` is tracked in git and currently points at prod — should likely move to `.gitignore` so the floating-link state stops drifting into commits.

### Plan revision — 2026-05-24: substep 7 smoke-tested on dev, follow-ups deferred

Verified substep 7 wire end-to-end on dev by reading persisted plan blobs from `activities.nutrition_plan_data` (two fresh plans generated on Rad ~21:15 / 21:17 CDT 2026-05-23). Both Before and During phases emit `pin_decision` with `pin_set_size` populated by the edge function (`pinnedForPhase.length` for pre-workout, `pinInScopeCount` for during). Earlier `pin_set_size: 0` seen in simulator analytics was a stale pre-deploy plan generated against the old edge function — `PinDecision.pinSetSize` defaulted to 0 via the legacy-payload path in `pin_decision.dart:77`. Working as designed.

**Deferred to next session (do NOT block PR 2 landing on these):**

1. ✅ **Normalize `phase` value to `before` / `during`** in the substep 7 analytics emit. _Done 2026-05-24 (`22c962e9`, milkmanfunddev-ops/mealvana_endurance#19)._ Added `MacroTargetsController.phaseForSectionId` (static, `@visibleForTesting`) mapping `before_run` / `during_run` / `after_run` → `before` / `during` / `after`. Unknown IDs pass through unchanged (future brick sub-sections won't silently lose their tag). Docstring on `trackPlanUsedPin.phase` updated to `'before' | 'during' | 'after'`. Locked with two new cases in `pin_analytics_test.dart`.
2. **Casing inconsistency in persisted blob (informational, predates substep 7).** `detailedMacroTargets.preRunSelections[].pin_decision` is snake_case (preserved from edge fn wire) while `sections[].pinDecision` is camelCase (re-serialized by client model). Inner keys are snake_case in both. `PinDecision.fromJson` already accepts both top-level names via dual lookup at lines 68–79. Not a bug, but worth noting if anyone reads the blob raw and is confused.
3. ✅ **`supabase/.temp/project-ref` gitignore** _Done 2026-05-24 (`22c962e9`, #19)._ Added `supabase/.temp/` to `.gitignore`; all 7 previously-tracked scratch files (`cli-latest`, `gotrue-version`, `pooler-url`, `postgres-version`, `project-ref`, `rest-version`, `storage-version`) removed from the index via `git rm --cached`. Working-tree copies preserved.

**Must-fix during substep 11 (blocks PR 2 landing):**

- **milkmanfunddev-ops/mealvana_endurance#32 — cross-device pin sync gap.** ✅ _Fixed 2026-05-24 (two-part fix)._ Discovered mid-smoke-test of substep 8 scenarios: a pin made on Rad last night was honored by the edge function on the simulator today, but invisible in the simulator's Library UI. Root cause: `FormulaLibraryController.build()` synced three repos on load but skipped `formula_pins`. Neither Drift nor Supabase nor the repo was broken — a missing `syncFromRemote` call. Fix part 1: added `pinsRepo.isStale()` + `pinsRepo.syncFromRemote(userId)` alongside the other three syncs (`formula_library_controller.dart:179-207`).

  **Fix part 2 (caught during substep 11 smoke verification 2026-05-24):** fresh-install sim showed 0/0 pins despite Supabase having 5 active. The ★ icon state is driven by `FormulaPinController` (not `FormulaLibraryController`) — these are two separate controllers that each read the pins repo independently and Riverpod doesn't guarantee build order. `FormulaPinController.build()` was racing ahead of `FormulaLibraryController`'s sync, reading an empty Drift cache, and caching the empty state. Workaround was navigating away from Library and back (autoDispose tore down the stale state, rebuild saw the now-populated Drift) — but that's not what a real user does. Fix: added the same `isStale()` + `syncFromRemote()` gate to `FormulaPinController.build()` (`formula_pin_controller.dart:62-84`). Idempotent — SharedPreferences-backed timestamp is shared across all readers of the pins repo, so the second controller's check is a no-op when the first has already synced. Verified by fresh-install smoke: opens Library, sees 2 Before + 4 During matching Supabase, no tab tricks needed.

  **Class-of-bug lesson:** any controller that reads a `SyncableRepository`'s data on `build()` needs its own `isStale() + syncFromRemote()` gate — relying on a sibling controller to have synced first is racy. Audited the other Formula Kit repos (`pre_workout_templates`, `during_workout_templates`, `template_foods`) — only `FormulaLibraryController` reads them, so they're safe. Worth checking other features the next time we touch them.

  **No controller-level regression test added** — sync correctness is exercised by `formula_pins_repository_test.dart` (dirty-preserve + tombstone propagation). A controller test would require mocking 4+ repos for a one-line wiring change; high cost, low signal. Decision documented inline in both controllers. Workaround applied during testing: soft-deleted the orphan pin row in Supabase via Management API.

**PinStatusBanner V1 polish (substep 11):** _Shipped 2026-05-24_

Found mid-smoke-test on scenario 4 (no-pin-for-scope fallthrough). When the user had Before pins but no During pins, the banner showed Snack + Top-Off rows but no During row — because the edge function only emits `pin_decision` on the During section when `pinsSupplied` (≥1 During pin). For users with mixed pin state across phases, the banner read as incomplete.

1. **Client-side synthesis of missing pinnable rows.** `_collectPinBannerRows` (`activity_detail_screen.dart:1409`) is now two-pass:
   - Pass 1: scan plan for ANY real `PinDecision`. If zero, return `const []` so the banner stays hidden (user has no pins — banner adds no value).
   - Pass 2: walk all pinnable phases present in the plan (Before sub_phases ∈ {meal, snack, top_up}, During section). Real decisions render as-is; phases the edge function didn't emit a decision for get a synthesized `PinDecision(usedPin: false, pinSetSize: 0, fallthroughReason: noPinForScope)`. Server-side broader emit considered and deferred — client synthesis covers the UX without an edge fn change.

2. **Two-state copy rule for non-honored rows** (`pin_status_banner.dart:_buildRow`):
   - `pin_set_size == 0` → **"No pin found"** (user has no pins matching this scope — Meal/Snack/Top-Off/During).
   - `pin_set_size > 0 && !usedPin` → **"Pins fell through"** (pins existed but none was selected).
   - In V1 the only fallthrough reason is `no_pin_for_scope`, so almost every non-honored row renders as "No pin found"; the second branch is wired forward-compat for future fallthrough reasons (allergen, season, etc.) and becomes load-bearing without a code change. Synthesized rows always fall into bucket 1 (pinSetSize == 0).

3. **CTA copy change.** `pin_status_banner.dart` text "Browse Formula Library" → "Pin your favorite formula" (the `Icons.arrow_forward` already follows the label, so the in-product render is "Pin your favorite formula →"). Analytics event name `pin_status_banner_formula_library_tapped` kept stable.

### Plan revision — 2026-05-22: schema applied, custom_foods reverted, workflow changed

Lee did a substantial db-cleanup pass on 2026-05-22 (`b2f86b4f`, `2ca58e95`) that materially affects this plan. Summary of what changed and how it propagates:

**Schema is live on dev + prod (not via `db push`).**
- `formula_pins`, `personal_templates` formula-kit columns: applied to dev + prod via DataGrip on 2026-05-22. The `20260520120000_formula_pins.sql` migration was rewritten idempotently (now in `_archived/`) so it's safe to re-paste.
- The `supabase db push` workflow is retired for this repo. Schema changes are written as idempotent SQL into `docs/database/apply_all.sql`, pasted into DataGrip against dev then prod, then moved to `supabase/migrations/_archived/`. See `supabase/migrations/README.md` for the full convention. The deploy-dev / deploy-prod / schema-drift-check GitHub Actions workflows were deleted (they failed on #29 and deployed nothing).
- Issue #29 is no longer a substep 5 blocker — bypassed, not resolved. The CLI migration-history mismatch still exists; we just don't depend on the CLI anymore.

**`custom_foods` is dropped from the plan.**
- `custom_foods` table was applied 2026-05-22 then immediately reverted — it duplicated `user_foods` (which already stores user-created foods with macros, soft-delete, offline sync, and is wired into the app). Formula Kit reuses `user_foods` going forward.
- `personal_templates.custom_food_ids` now references `user_foods.id` (column comment updated in DataGrip).
- If formula components later need allergen/diet/caffeine filtering on user-created foods, add those columns to `user_foods` additively rather than creating a parallel table.
- PR 5 substeps that previously created `custom_foods` table + repo are dropped. The architecture diagram + Drift schema additions + Supabase additions sections below still mention `custom_foods`; they are stale and should be read with this revision overlay. Not deleting them inline since the doc is the running record — propagate when PR 5 actually starts.

**~~PR 5 prerequisite added: `TemplateKind.fromWireValue` crash-safety.~~** ✅ Done 2026-05-26 as PR 3 substep 1 — `fromWireValue` now returns null for unknown wire values (incl. null input), `FormulaPin.fromDriftEntry` returns null and `FormulaPinsRepository._decodePinEntries` skips + logs the row. Locked with `template_kind_test.dart` (8 tests). Same fix retroactively satisfies the PR 5 `'personal_template'` widening.

**Drift schema version is now 11 (not 10).**
- The develop merge that came in with `b2f86b4f` raised the schema version past what PR 2 originally bumped. Substep 1's "v9→v10" in this doc is historically accurate but the actual current version is `schemaVersion = 11`. Any future schema bump increments from 11.

**Substep 5 is now executable.** It still requires writing the edge function — schema being live is the necessary precondition, not the work itself.

## Schema management — actual workflow (effective 2026-05-22)

For any schema work on Formula Kit (or anywhere else) on this branch and forward:

1. Write idempotent SQL into `docs/database/apply_all.sql` (use `CREATE ... IF NOT EXISTS`, `DROP ... IF EXISTS`, guarded `UPDATE`s).
2. Paste `apply_all.sql` into DataGrip and run against dev. Verify.
3. Paste into DataGrip and run against prod. Verify.
4. Save a dated copy as `supabase/migrations/_archived/<YYYYMMDDhhmmss>_<slug>.sql` for the historical record.
5. Clear `apply_all.sql` for the next change.
6. Do **not** run `supabase db push` — it fails on #29 and we don't use it.

Old Status — 2026-05-21
=======================

PR 2 progress:
- Substep 1 ✅ `74e6b1f` — `formula_pins` table on Supabase + Drift mirror + schema v9→v10.
- Substep 2 ✅ `b5bc272` — `FormulaPin` domain + `FormulaPinsRepository` (SyncableRepository mixin with `syncFromRemote`/`uploadDirtyRecords`, soft-delete unpin, idempotent pin, `sync_dependency_graph` registration).
- Substep 3 ✅ `41de5d0` — verification-only. The "sync handler" the plan originally named was a misnomer: the dirty-preserved + remote-upsert pattern lives directly inside the repository (no parallel handler file pattern exists for `personal_templates` either; the project consolidates this into the repo itself). Locked in the sync invariants with `test/features/formula_kit/data/formula_pins_repository_test.dart`:
  - Dirty-preserve: an active sync skips local rows flagged `needs_upload=true`.
  - Tombstone-propagation: a remote `is_deleted=true` row is applied locally without physical delete, and is hidden by `getActivePinsForUser`/`isPinned`/`findActivePin`.
  - Soft-delete unpin: `unpin()` flips `is_deleted=true` and dirties the row; no DELETE.
  - Pin idempotency: a second `pin()` for the same `(user, template, kind)` returns the existing row.

  Exposed `upsertRemotePinsPreservingDirty` via `@visibleForTesting` because the project's repo tests punt on full Supabase mocking (see `test/new_sync/coach_repository_sync_test.dart:116`).
- Substep 4 ⏸ DEFERRED — see Plan revision below.

### Plan revision — 2026-05-21: Substep 4 deferred (client/server template-table mismatch)

While scoping substep 4, two architectural facts surfaced that the original plan did not account for:

**Finding 1 — `client_plan_service` and Formula Library read from different tables.**

| Surface | Table | Schema |
|---|---|---|
| `client_plan_service._tryTemplateBasedBefore` (`templates_repository.dart:99`) | `templates` | denormalized `foods` JSON, `meal_type`, `timing_*_minutes`, `total_*` macros |
| Formula Library + Pins (`pre_workout_templates_repository.dart`, PR 1) | `pre_workout_templates` | `template_type` (food/drink/electrolyte), per-serving macros, joins to `template_foods` |
| Edge function v3 (`generate-nutrition-plan-v3/before-phase-db.ts:19`) | `pre_workout_templates` | (same as Library — server is consistent) |

A pin row stores `template_id` referencing **`pre_workout_templates`**. `_tryTemplateBasedBefore` reads from **`templates`**. The IDs don't match — substep 4 as originally scoped cannot find any pinned candidates without a table migration or a name/slug bridge. The server path (edge function v3/v4) already reads `pre_workout_templates`, so it is unaffected.

**Finding 2 — `client_plan_service` lacks the edge function's hydration/electrolyte stacking.**

The edge function (`before-phase.ts:166-200`) fetches three separate template pools (`food`, `drink`, `electrolyte`) and stacks selections from each. `_tryTemplateBasedBefore` picks only one template and scales linearly — no drink or electrolyte top-up. During-phase has a similar `[POST-PROCESS-DURING]` electrolyte top-up on the server (`during-phase.ts:48-150`) that the client greedy fallback does not replicate. This is a pre-existing client-fallback gap, independent of pins.

**Decision — defer substep 4, document the gap, move to substep 8.** The client fallback path is a degraded experience that already lacks hydration parity; adding pin awareness here is rearranging deck chairs. When the edge function is up (~99% of plan generations), substep 5's v4 will honor pins correctly. When the edge function fails (rare), users get the existing legacy client behavior — no pin awareness, but a working plan. Substep 8 (UX pin toggle) becomes the next active work; the substep ordering after 5 is unchanged. See "Deferred client-side work" subsection near the end of this doc for the follow-up items.

**Locked-in pin policy clarifications from the same session** (codified into "Scope decisions" below):
- For Before phase, an in-scope pin is honored unconditionally — skip allergen/diet/dislike filters, skip the [0.5, 2.0] scale clamp. The pin is the user's explicit override.
- The only "fall through to legacy" condition for Before is **no pin matches the workout's scope** (sub_phase + timing window). All other PLAN-listed `plan_pin_fallthrough` reasons (`allergen`, `dislike`, `scale_out_of_range`) do not fire on the Before client path under this policy.
- Drink/electrolyte templates are **not pinnable in V1**. Pin policy applies to `template_type = 'food'` only.

### Plan revision — 2026-05-20: Pins replace Favorites, move from PR 5 to PR 2

Originally PR 5 added a star/heart "favorites" feature, Drift-only. After product discussion, the feature was rescoped to **pins** — pins are not bookmarks, they are **preference signals consumed by the plan-generation algorithm**. When a pin exists matching a workout's scope, the algorithm uses pinned templates as the candidate set first; if none fit (allergen/dislike/scale/gut-training constraints), it falls through to the existing algorithm.

Why this moved earlier:
- Pins are the user's explicit "use this for this kind of workout" signal — exactly the signal needed to start tuning template assignment empirically.
- Shipping pins early starts data collection (`plan_used_pin`, `plan_pin_fallthrough`) so we have real usage signal by the time later PRs land.
- Pins are orthogonal to edit/personalize/swap/coach work — clean isolated PR.

PR phasing has shifted: new PR 2 is Pins. Old PR 2–5 each move up by one. Favorites (star + favorites-only filter) is **removed** from the plan — pins serve the user-need it was solving.

### Next up — PR 2: Pin a formula as an algorithm signal (planned, not started)

**Goal:** User can toggle a pin on any system formula. When the plan-generation algorithm runs, pinned templates are tried first for the matching scope; fall through to existing logic if none fit. Show transparent fallback to the user.

**Scope decisions (locked):**
- **UX = single-tap toggle.** No scope picker. Scope (sub_phase for Before, activity_type × duration_bracket for During) is inherited from the template's existing metadata.
- **Multiple pins per scope allowed.** Algorithm picks best from pinned set by carb proximity.
- **V1 = system templates only, food templates only.** Personal templates become pinnable in PR 5. Drink/electrolyte templates (`template_type != 'food'`) are not pinnable — they're algorithm internals consumed by the edge function's stacking pass, not a user-facing formula choice.
- **Storage = Drift + Supabase.** Both client-side (`client_plan_service`) and server-side (`generate-nutrition-plan-v*`) need to read pins. Drift-only is not an option.
- **Pin honoring policy (locked 2026-05-21).** An in-scope pin is honored unconditionally:
  - Skip allergen, diet, and dislike filters. The pin is the user's explicit override; if their profile no longer matches, we surface the food anyway and rely on a V2 advisory pill (see "Deferred client-side work") to warn them visually.
  - Skip the [0.5, 2.0] scale clamp that non-pinned candidates obey. If the pinned formula needs 3× to hit carb target, ship 3×.
  - The ONLY condition that causes the algorithm to fall through from pins to legacy logic is "no pin matches the workout's scope." Allergen/dislike/scale fall-through reasons listed in original substep 7 telemetry do not fire under this policy on the Before client path. (Server-side During may still use `gut_train_mismatch` since gut training is a structural fit, not a preference filter — revisit during substep 5.)
- **Fit-failure UX (V1).** Because in-scope pins are unconditionally honored, the "pin didn't fit, used [fallback]" banner planned at substep 9 only fires when **no pin matches the current scope** AND the user has any active pins (for other scopes). For a user with no active pins, the banner doesn't render. Original transparent-fallback copy ("Your pinned formula didn't fit today's target — using [fallback]") is replaced by the simpler "Using your pinned formula ✓ [Name]" / no-banner pair.
- **Pin entry points = (i) card/detail toggle + (iii) activity detail awareness banner.** Skip the workout-settings management surface in V1.

**Substeps (in order, each is a commit):**

1. **Schema** — Supabase migration `formula_pins` table + Drift mirror + schema bump v9→v10 + codegen
2. **Domain + repository** — `FormulaPin` model, `FormulaPinsRepository` (CRUD + sync). Register edge in `sync_dependency_graph`.
3. **Sync handler** — `formula_pins_sync_handler` mirroring `personal_templates_sync_handler` pattern (local-dirty-preserved + remote-upsert).
4. ⏸ **DEFERRED — Client-side algorithm hook.** Original plan: modify `_tryTemplateBasedBefore` in `client_plan_service.dart:307` to check pins first. Deferred 2026-05-21 because the client reads `templates` while pins reference `pre_workout_templates` — see "Plan revision — 2026-05-21" above and "Deferred client-side work" subsection near the end. The client fallback path will not honor pins in V1.
5. **Edge function pin support** — pin-aware plan generation. **Revised 2026-05-22 from the original "new v4 directory" approach to extending v3 in place**, because the algorithm-level change landed as Option B (optional `pinnedTemplateIds: Set<string>` param on shared functions, byte-identical no-pin path proven by 16 parity tests in `pre-workout-pinned.test.ts` and `during-template-pinned.test.ts`). Substep 5 now decomposes into:
   - **5a** ✅ `afbb4e06` — pin override + `bypassScaleClamp` + `pin_decision` payload in shared modules (`generate-macros-v4/pre-workout.ts`, `generate-macros-v4/pre-workout-scoring.ts`, `_shared/nutrition/during-template-solver.ts`) + 16 unit tests.
   - **5b** ✅ `add4bfb0` — wire pins through the v3 orchestrator: new `pins.ts` (device_id → user_id → `formula_pins` → `{ beforePinIds, duringPinIds }`), thread Sets through `before-phase.ts` / `during-phase.ts`, surface `pin_decision` on each `SubPhaseResult` and on `LPPhaseResult`. Brick handler intentionally NOT plumbed in v1 (single-activity is the main pin use case).
   - **5b-followup** ✅ `5daf8017` — wired pins into `generate-macros-v4` (the actual client entry point). 5b's plan-v3 path was inert in production because plan-v3 only runs the pin-aware selector when `input.pre_run_selections` is empty (`before-phase.ts:164`), but the live client flow is Client → `generate-macros-v4` (selection happens here) → `generate-nutrition-plan-v3` (explodes pre-picked selections, skips its own selector). 5b's plan-v3 path stays — it's still correct for the regenerate / direct-plan-call fallback. Done: `pins.ts` lifted to `_shared/nutrition/pins.ts`; pins fetched once in `macros-v4/index.ts`; `pinned.beforePinIds` passed through `selectPreWorkoutFoods`; `pinned.duringPinIds` plumbed through the during selector path; `pin_decision` surfaced on the macros-v4 response.
   - **5c** ✅ `513e4c7b` — live smoke-test against dev + architectural fix to honor-pin component bypass on the During path. Smoke results: (Before) pinned Bagel+Jam template renders bagel in plan output even though `bagel` is on user's dislike list with `preference_level=0`; (During) pinned Energy Chews template selected. While verifying I found that `during-phase.ts` loaded foods through `getTemplateFoodsForDuringWithConstraints` which applied dislike/allergen/diet filters **before** the solver knew which foods belonged to a pin, dropping pinned components silently. Fix: derive `pinnedComponentNames` from in-scope `DuringWorkoutTemplate[]` (sequentialized: templates loaded first, foods loaded with the pinned-names set), and gate the three filters with `!isPinnedComponent` in `_shared/nutrition/template-food-queries.ts`. Pre-workout path was already safe (Before templates carry components inline; no parallel filter call). Pre-existing food-preferences UI/DB mismatch surfaced during smoke testing — UI shows neutral while DB stores dislike, due to `display_name` vs canonical `food_name` key mismatch in `food_preferences_screen.dart` + duplicate `template_foods` rows for `bagel` / `bagel_large`. Does NOT affect plan generation (edge function reads DB truth directly). Filed as milkmanfunddev-ops/mealvana_endurance#30.
   - Rollback story under Option B: `git revert` of additive code. Parity tests guarantee no-pin path unchanged. Future need for a frozen-v3 fallback is still one `cp -r` away — no optionality lost.
6. **Edge function parity test** — superseded by unit-level parity in 5a (16 tests across `pre-workout-pinned.test.ts` + `during-template-pinned.test.ts` prove no-pin behavior is byte-identical). Replace the v3↔v4 integration parity test with one live smoke-test in 5c.
7. ✅ **Telemetry** — `formula_pinned`, `formula_unpinned`, `plan_used_pin`, `plan_pin_fallthrough { reason: 'no_pin_for_scope' }`. Per locked honor-pin policy (2026-05-21, revised 2026-05-22), the ONLY fallthrough reason is `no_pin_for_scope` — both Before and During bypass all preference / diet / dislike / gut-training filters when an in-scope pin is supplied. The original `scale_out_of_range` / `allergen` / `dislike` / `gut_train_mismatch` reasons no longer fire under V1 policy. Hooking Mixpanel is straightforward since the algorithm already returns `pin_decision` on its result shape (5a). Shipped 2026-05-23 (`bac26203`); cleanup (#19) shipped 2026-05-24 (`22c962e9`).
8. **UX (i)** — pin toggle on `FormulaLibraryScreen` cards + Before/During detail screens. State in `FormulaLibraryController` + new `FormulaPinController`.
9. **UX (iii)** ✅ — `activity_detail_screen` banner. Shipped as `PinStatusBanner` (combined collapsible, V3 design): header summary + per-phase rows (meal/snack/top-off/during) showing honored template name or fallthrough state, plus "Browse Formula Library" CTA (pushes route — back returns to activity). `PinDecision` attached per-result on `BeforeSubPhase`/`PlanSection`; wire shape extended with `pinned_template_name` so the banner doesn't need a separate template lookup. Forward-compat decoder (`PinFallthroughReason.fromWireValue` → null on unknown). Analytics: `pin_status_banner_shown` (once per activity, post-frame), `pin_status_banner_expanded` (one-shot), `pin_status_banner_formula_library_tapped`.
10. **Client cutover** — N/A under Option B. The edge-function endpoint name stays `generate-nutrition-plan-v3`; pin awareness is additive in the same function. Client doesn't need to repoint. Old app versions on old binaries naturally don't send pins (the table is server-side; pin-fetcher returns empty sets if device has no user row) and get byte-identical pre-pin output.
11. ✅ **Tests + V1 polish** — `formula_pins_repository_test`, edge function pin-path test (`during-phase-pin-emission.test.ts`), UI tests for pin toggle + banner states (`pin_status_banner_test.dart` covers Status + Onboarding modes; `pin_banner_rows_builder_test.dart` covers Hidden / Onboarding / Status state machine). Shipped 2026-05-24 — see the substep-11 cluster in the Status section above. Also fixed milkmanfunddev-ops/mealvana_endurance#32 (cross-device pin sync gap) two-part: `FormulaLibraryController` (`1a95eb7d`-precursor) and `FormulaPinController` (`1a95eb7d` follow-up). Edge function emission contract fix (#18) shipped as `1537f8a5`. Substep 7 deferred follow-ups (#19) shipped as `22c962e9`. `client_plan_service_pinned_template_test` retired with substep 4 deferral.
12. ⏳ **Status update + memory update** — refresh this Status section, refresh `project_formula_kit.md` memory. _In progress 2026-05-24._

**Out of scope for PR 2 (deferred):**
- Pinning personal formulas (depends on PR 5).
- Workout-settings management surface (V2 if power users ask).
- Coach insight reading pins as context (folded into PR 6 coach insight scope).
- Plan-time formula picker ("use this formula for this specific workout") — V3+.

### Next up — PR 3: After-phase parity (browse + pin), planned, not started

**Goal:** The Formula Library covers all three phases (Before / During / After). Users can browse `post_workout_templates`, view detail, and pin a post-workout formula. The plan-generation algorithm gains a simple after-phase solver that prefers pinned post templates and falls through to `selection_priority` order. After Lee + Sunshine review on 2026-05-26, this PR was inserted between PR 2 and the original PR 3 so personalization work begins on a complete browse+pin surface.

**Scope decisions (locked):**
- **Filter axis = `travel_friendliness` only.** Three values: `in_bag`, `cooler_friendly`, `home_only`. No flavor/effort/protein chips in V1. Default state = all three visible.
- **Standard portion, no scaling target.** Unlike Before/During, after-phase recovery doesn't carry an algorithmic carb/calorie target the user has to hit. The template's `default_servings` is the recommendation. No quantity stepper. No scale clamp.
- **Pins in scope ("set it and forget it").** Single-tap pin toggle on After cards + detail screen. New `template_kind` wire value `'post_system'`. Existing pin honor policy applies (skip allergen/dislike/diet filters when pinned).
- **No brick-specific surface.** Bricks don't change the after-phase recommendation set in V1. After-phase pin is global to the user.
- **Algorithm = simple.** When an in-scope post pin exists, return the pinned template. Otherwise return the highest `selection_priority` template that passes filters. No carb proximity scoring, no scaling, no stacking.
- **System templates only in V1.** Mirrors PR 2's V1 cut. Personal post templates are out of scope (and out of scope for the foreseeable future — there is no design).

**Substeps (in order, each is a commit):**

1. ✅ **`TemplateKind.fromWireValue` crash-safety** — `fromWireValue` now returns `TemplateKind?` (null for unknown / null input). `FormulaPin.fromDriftEntry` returns `FormulaPin?` (null when kind is unrecognized). `FormulaPinsRepository._decodePinEntries` skips null-decoded rows + logs `pin_id` / `template_kind` to logger (warning) + Sentry (warning). Upload path filters unknown-kind rows out of the upsert batch AND leaves their `needs_upload` flag set, so a newer binary can retry. Tests: `test/features/formula_kit/domain/template_kind_test.dart` (8 tests covering the known/unknown/null/empty matrix at both enum and Drift-entry decode level). All 89 existing formula_kit tests still green.
2. ✅ **Schema** — `b1b25139`. Drift `PostWorkoutTemplatesTable` mirror added (full v2 column set: `travel_friendliness`, `flavor_profile`, `prep_effort`, `protein_anchor`, `carb_sources`, `portions`, `selection_priority`, `default_servings`, `allergens`, `excluded_diets`, `component_food_names`, `component_ratios`, `activity_types`, `target_carb_protein_ratio`, `notes`, `is_active`). Schema bump v11 → v12 + codegen. CHECK widening SQL applied to **dev** Supabase via Management API (`docs/database/apply_all.sql` + dated archive at `_archived/20260526120000_formula_pins_template_kind_post_system.sql`). Verified: `formula_pins_template_kind_check CHECK (template_kind IN ('pre_system','during_system','post_system'))`. **Prod CHECK widening deferred** to substep 12 — gated on substep 1 reaching the App Store via a TestFlight cycle, otherwise old binaries crash reading new pins.
3. ✅ **Domain** — `FormulaPhase` extended with `after` (`analyticsValue: 'after'`, `displayLabel: 'After'`). `TemplateKind` extended with `postSystem('post_system')`. New `AfterFormulaView` in `formula_view.dart` (mirrors `DuringFormulaView` shape; standard-portion only, no scaling target; `isPinnable => true` since post templates have no `template_type` segmentation). `formula_pin_controller._phaseForKind` switch updated to map `postSystem → after`. Tests: `template_kind_test.dart` extended — `post_system` now decodes; the unknown-case stand-in is `'personal_template'` (the PR 5 future widening). No separate `PostWorkoutTemplate` domain model was added: the Before/During pattern goes Drift entry → view-model directly with no intermediate domain type, and inventing one for After alone would create asymmetry. All 90 formula_kit tests green.
4. ✅ **Repository** — `PostWorkoutTemplatesRepository` (sibling of `DuringWorkoutTemplatesRepository`): `SyncableRepository` mixin, `isStale()` forces sync on empty cache, `syncFromRemote()` does delete-then-batch-insert from Supabase `post_workout_templates` (filtered `is_active = true`, ordered by `template_number`), `uploadDirtyRecords()` returns `nothingToUpload()` (read-only catalog). `getAll()` + `getById()` query helpers mirror the during repo. `postWorkoutTemplatesRepositoryProvider` Riverpod provider. `sync_dependency_graph` extended with `'post_workout_templates': ['template_foods']` (same dep as during/pre — `component_food_names` references `template_foods.name`). Not yet wired into `FormulaLibraryController` — that happens in substep 5/6 along with the After tab. 90/90 formula_kit tests green; analyzer clean.
5. ✅ **Filter state** — New `TravelFriendliness` enum (`in_bag` / `cooler_friendly` / `home_only`) in `after_filter_options.dart` with `storageValue` / `displayLabel` / `fromStorageValue`. `FormulaFilterState.afterTravelFriendliness: Set<TravelFriendliness>` field defaults to all-three (exposed as `FormulaFilterState.defaultAfterTravelFriendliness`). Multi-select semantics (full set = no filter, strict subset = narrowed, empty = nothing passes). `activeChipFilterCount` returns 0 on After when set equals default, else 1. `copyWith` / `==` / `hashCode` extended. New `FormulaLibraryController.toggleAfterTravelFriendliness()` mirrors the multi-select toggle pattern from `toggleAllergyFilter` and emits `formula_filter_applied { filter_type: 'travel_friendliness' }`. `clearPhaseChipFilters()` resets the After bucket to the default when phase is `after`. Tests: 4 new in `formula_filter_state_test.dart` (default state, After chip count semantics, Before/During ignore After field, `TravelFriendliness` storage round-trip). 94/94 formula_kit tests green; analyzer clean.
6. ✅ **UI browse** — `PhaseTabBar` now renders three equal-width pills (Before/During/After). `FormulaLibraryController` syncs + loads `post_workout_templates` and maps entries → `AfterFormulaView` via `_mapAfter`. `FormulaLibraryState` gains `afterFormulas` + `filteredAfterFormulas` (dietary filter + multi-select travel friendliness; nulls always pass). New `AfterFormulaCard` widget (mirrors `BeforeFormulaCard`: name + formula subtitle + meta pill row showing portions / C:P ratio / protein anchor + travel friendliness pill + pin toggle). `_AfterList` + After branch in `_LibraryEmptyState`. After chip row in the body — a `FilterChipRow<TravelFriendliness>` bound to `toggleAfterTravelFriendliness`. `PinToggleAfter` widget + `FormulaPinController.toggleAfter()`. Detail screen extended with `_AfterDetailBody` (read-only — pill row of all v2 Notion taxonomy fields + Components card + Notes + Dietary tags; no macros, no quantity stepper since post templates are single-portion). New router route `/settings/food-preferences/formula-library/after/:id`. Detail body lives in the same file as Before/During (not a separate `after_formula_detail_screen.dart` as originally planned) to keep the three phases visually symmetric in one place. 94/94 formula_kit tests green; formula_kit + router analyzer clean.
7. **Edge function pin support** — new `after-phase.ts` solver in `_shared/nutrition/`. Pin-aware: if a post pin exists in scope, return it; otherwise return highest `selection_priority` row matching the user's filters. Add `post-template-solver.ts` for the non-pin path. Wire into `generate-nutrition-plan-v3` (the live entry point — same shape as Before/During plumbing in PR 2's 5b-followup). Emit `pin_decision` for the after row on the response.
8. **Pin UX (After)** — pin toggle on `AfterFormulaCard` + after detail screen. Either extend the existing `PinToggle` to handle `TemplateKind.postSystem` or add an `AfterPinToggle` variant. Pin write goes through `FormulaPinsRepository` (no changes needed — table already supports it once substep 2 widens the CHECK).
9. **Banner row (After)** — add an After row to `PinStatusBanner`. Same Hidden / Onboarding / Status state machine. Emits the same `pin_status_banner_*` events as Before/During (just with `phase: 'after'`).
10. **Telemetry** — add `phase: 'after'` to existing `formula_pinned` / `formula_unpinned` / `plan_used_pin` / `plan_pin_fallthrough` events (no new event names). New `pin_decision` reason `no_post_template_matches_filters` for the rare case where every template fails the user's filters. Library browse events extend to After tab (`formula_library_tab_selected { phase: 'after' }`).
11. **Tests + smoke** — `post_workout_templates_repository_test`, `after_phase_solver_test` (edge function, parity + pin path), UI tests for After tab + pin toggle, integration test for the full pin → activity-detail-banner round trip. Live smoke on dev: pin a post template, complete a workout, verify the recovery card matches the pin.
12. **Prod rollout + status + memory** — run substep 2's CHECK widening migration on prod via DataGrip (after substep 1 has been in prod for one TestFlight cycle). Refresh PLAN.md status. Refresh `project_formula_kit.md` memory. Update the 7-PR phasing summary.

**Out of scope for PR 3 (deferred):**
- Personal post-workout templates (no design exists; not planned).
- Brick-specific after-phase recommendations (V2 if data shows brick athletes want different recovery).
- After-phase scaling / quantity stepper (no algorithmic target to hit; reconsider only if athletes ask for it).
- Coach insight on the After tab (folded into PR 6).

### Blocker — dev Supabase migration history out of sync (issue #29) — BYPASSED 2026-05-22

Original blocker (kept for context): dev's `supabase_migrations.schema_migrations` had ~49 phantom timestamps with no matching files, so `supabase db push` failed.

**Resolution (effective 2026-05-22):** the project no longer uses `supabase db push`. Schema is applied by hand via DataGrip from `docs/database/apply_all.sql`. The broken `deploy-dev` / `deploy-prod` / `schema-drift-check` workflows were deleted. `formula_pins` was applied to dev + prod 2026-05-22. Substep 5 is unblocked.

The underlying CLI mismatch is **not fixed** — if someone ever needs `db push` working again, options are documented in `supabase/migrations/README.md` (`migration repair` against the 49 phantom timestamps, or backfilling SQL files from history). Issue #29 remains open as a record but is no longer a blocker for this work.

Committed on `feat/formula-kit`:
- `463cdbc` docs(formula-kit): add implementation plan
- `14adfa5` feat(formula-kit): browse data layer + library screen (PR 1 partial)
  - Drift mirror of `during_workout_templates` + schema bump v7→v8
  - `DuringWorkoutTemplatesRepository` with on-demand sync + dep-graph wiring
  - Domain: `FormulaFilterState`, `FormulaPhase`, `BeforeSubPhase`, `DuringActivity`/`Duration`/`GutLevel`, `FormulaDigestionSpeed`, `BeforeFormulaView`, `DuringFormulaView`
  - `FormulaLibraryController` (@riverpod AsyncNotifier) with full filter mutations + analytics tracking
  - `FormulaLibraryScreen` with phase tabs, per-phase filter chip rows, list cards, empty states
- PR 1 finishing commits (Before table switch, detail screen, router wiring, hub tile, tests, dev runner, debug analytics log) — landed between 14adfa5 and the polish commits below.
- `5efbcd4` feat(formula_kit): render component quantities on Before formula detail
  - Surfaced per-component quantity descriptions on Before detail using `FoodItemData.buildDisplayQuantity` (no new formatter — reused fueling-plan's)
  - `template_foods` now syncs to Drift (added `pre_workout_templates → template_foods` edge to `sync_dependency_graph`)
  - Renamed `componentDisplayNames` → `componentDisplayStrings` and built display string per component (e.g. "1 cup Oats", "0.5 cups Mixed Berries")
- `4953d28` fix(formula_kit): render Before components per-serving, drop max_servings multiplier
  - Earlier code multiplied per-serving macros + component proportions by `max_servings`, which disagreed with the legacy `serving_unit` description (e.g. "Oatmeal + Raisins" rendered 3× too much). Switched to per-serving across the board; scale range is a plan-time concern, not a headline number.
- `49495ed` fix(formula_kit): drop FORMULA #N eyebrow + raw component subtitle from During cards
  - Removed `'FORMULA #${formula.templateNumber}'` eyebrow from During card + detail body (was visual noise).
  - Removed snake_case `componentFoodNames.join(' + ')` subtitle from During card (duplicated and uglified the formula title above it).
  - Before phase untouched.

Verification done (final pass):
- `dart run build_runner build` clean (0 errors)
- `flutter analyze lib` clean
- `flutter test test/features/formula_kit/` — 22/22 passing (incl. updated During card test that asserts the eyebrow + raw-names row are absent)
- Manual smoke test on iPhone simulator with each polish commit. ✅

### Data hygiene issues uncovered during PR 1 polish (filed, not blockers)

- **#27** — `template_foods.serving_unit` missing on some rows causes bare display strings like "1 Jam / Jelly" (no unit token between quantity and food name).
- **#28** — `pre_workout_templates` "Potato + Salt" lists only `baked_potato` as a component, but `sodium_mg = 300` implies ~283 mg from salt that's never structurally referenced. `template_foods.salt` exists (390 mg/serving) but isn't in `component_food_names`. Sibling pattern to #27.
- **(unfiled)** `pre_workout_templates.serving_unit` is vestigial English text; the only consumer is a legacy fallback in `supabase/functions/before-phase-explosion/index.ts:147`. Worth retiring alongside #27.

### Cross-cutting improvements landed during PR 1

These are independent of Formula Kit but were uncovered while smoke-testing it:

1. **`scripts/run_dev.sh`** — `flutter run --flavor dev` alone uses the dev iOS xcconfig BUT defaults to `lib/main.dart`, which loads `.env.prod.local` — so analytics events go to **production** Mixpanel even though the bundle says "dev". The script forces `--target lib/main_dev.dart` so the dev entry point (and `.env.dev.local`) wins. VSCode's `launch.json` was already correct; this brings the terminal experience to parity.
2. **Dev-only analytics debug log** — `MixpanelAnalyticsTracker.track()` now `_logger.info`s `📊 <event_name>` with the properties payload when `config.devModeEnabled` is true. Stripped in prod. Lets us verify event firing without depending on Mixpanel dashboard access.

### Dev Mixpanel project — open question

The dev Mixpanel token (`df6e8dd4f3dc1363fa194a156298b16c` in `.env.dev.local`) is not surfacing events on any Mixpanel board Sunshine has access to. Could be: (a) token belongs to a project that was deleted, (b) project exists but Sunshine doesn't have viewer access, (c) project was never created. Not blocking PR 1 — the debug log gives parallel observability. Worth investigating before we start relying on dev Mixpanel for funnel work in PR 5+.

## Context

**What this is.** Formula Kit is a new UI surface for browsing, personalizing, and creating "formulas" (nutrition templates) for the Before and During phases of endurance workouts. It's been prototyped in HTML/React on [claude.ai/design](https://claude.ai/design) across 5 iteration chats and ships as a 5,657-line standalone HTML prototype + bundle of `.jsx` source files. We need to recreate it in the Flutter app pixel-perfectly while wiring it to real backend infrastructure.

**Why it's being built.** Today, Mealvana has a sophisticated template *backend* (pre/during/post-workout templates in Supabase, mirrored to Drift) but no user-facing browse/personalize UI for templates. Templates are applied silently inside `client_plan_service._tryTemplateBasedBefore()` during plan generation. Athletes can't see the catalog, can't pick from it, can't tweak a template, and can't save personal variants. Formula Kit fills that gap.

**Intended outcome.** Athletes can (a) browse the system formula library on Before/During tabs with filters; (b) tap a template to see its breakdown; (c) "Make this mine" to fork it with quantity tweaks, swaps, removals, and AI coach guidance; (d) create personal formulas from scratch; (e) **pin formulas so the plan-generation algorithm uses them as the preference signal for matching workouts** (replaces the original "favorite" concept — see Plan revision in Status); (f) have all of this persist locally and sync to Supabase like every other Mealvana entity.

## Source material

- **Design bundle:** `/tmp/formula-kit/formula-library-remix-remix/`
  - `README.md` — design handoff guide
  - `chats/chat1-5.md` — five chat transcripts capturing intent and iteration
  - `project/Formula Kit.html` — primary file (standalone offline bundle, the user had this open at handoff)
  - `project/*.jsx` — modular source (app, browser, detail, edit, create, swap, insight, ui, data, tweaks-panel)
  - `project/colors_and_type.css` — Mealvana design tokens
  - `project/screenshots/` — V3 state references
- **Design system reference:** Mealvana Endurance design system at `/projects/c4ad6c0d-189d-4886-888d-d30addf0dfcf/` (referenced in chats but already encoded in current Flutter app)

## Entry point (decided)

**Settings → Food Preferences → Formula Library** (new 4th tile on the Food Preferences Hub).

- Lives at: `lib/features/settings/presentation/screens/food_preferences_hub_screen.dart` — add a new `_buildFormulaLibraryTile()` next to the existing 3 tiles (Dietary Preference, Allergies, Food Likes & Dislikes).
- Route: add `/settings/food-preferences/formula-library` (and its sub-routes for detail + create) to the router config.
- Implication: Formula Kit is treated as a **preferences/configuration surface**, not an inline workout planner. Athletes go there to *manage* their formulas, not to *pick one for today's workout*. This shapes the answer to the two remaining product questions below.

## Plan integration (revised 2026-05-20)

**PR 1 is browse-only (no algorithm coupling). PR 2 introduces pins as the algorithm signal. Browse + manage stays in Settings; the per-workout impact is observed in the existing activity detail screen.**

Reasoning: Settings is the right home for "manage your preferences." The signal those preferences produce flows into plan generation automatically — the user doesn't go to Settings to pick today's formula, they go to Settings to declare their long-standing preferences, then the algorithm honors them.

- **PR 1**: Standalone settings surface, no algorithm coupling. ✅ Shipped.
- **PR 2**: Pins become a first-class algorithm input. Both `client_plan_service._tryTemplateBasedBefore()` and the new `generate-nutrition-plan-v4` edge function check pins for the matching scope before falling through to the existing scoring algorithm.
- **PR 3**: After-phase parity — extend browse + pin machinery to `post_workout_templates`. Still no algorithm change for Before/During; adds a small after-phase solver to v4 that's pin-aware with selection_priority fallthrough.
- **PR 4–6**: Personalize, swap, create, coach — all build on the same Settings surface. Personal formulas become pinnable in PR 5.
- **V3+ (out of scope)**: Plan-time formula picker in New Activity flow ("use this formula for this specific workout") — distinct from pins, which apply across many workouts.

This is what the user reads from the algorithm change: pins say "these are my long-standing preferences for this kind of workout." The plan-time picker (someday) would say "for this particular workout, use this one regardless."

## PR 1 scope (recommended)

**Just V1 — browse + detail, no personalization. Ships visible — no feature flag on the Food Preferences Hub entry point.** Browse-only delivers sufficient value on its own with the existing template catalog.

- Adds the Formula Library tile to Food Preferences Hub.
- New `formula_library_screen.dart` with phase tabs, filter chips, collapsible header on scroll.
- New `formula_detail_screen.dart` (read-only, no "Make this mine" yet).
- New Drift mirror of `during_workout_templates` + `post_workout_templates` (read-only sync).
- No new Supabase migrations (everything browsed is already on develop).
- No edit state, no personal formulas, no swap, no create, no favorites.

This is shippable in ~1-2 days of focused work, immediately useful to athletes (they can finally *see* the catalog), and zero risk to plan generation. PR 2+ add personalization on top.

## Branching strategy

**Recommendation: branch `feat/formula-kit` off `origin/develop`.**

Rationale:
- `develop` is the active integration branch (~60 commits ahead of `main`). Recent feature branches (`feat/macro-iter5-garmin`, `feature/garmin-brand-compliance`) merged here, not into main.
- Formula Kit depends on `during_workout_templates` and `template_foods` tables that exist **only on `develop`** via migrations `20260406320000_during_workout_templates_complete.sql` and dependencies. Branching off `main` would mean reimplementing or backporting those migrations.
- The pre_workout_templates table is already on main; the pending vegan/GF migration (`20260506100100_add_vegan_gf_pre_workout_templates.sql`) is on develop too.

```bash
git fetch origin
git checkout -b feat/formula-kit origin/develop
```

**Do NOT branch off:**
- `main` — missing during/post-workout template tables.
- `feat/patrol-integration-tests` — massive divergence, mid-flight test infrastructure work.
- `fix/preworkout-bundle-may2026` (current branch) — that's a small bugfix branch on its own trajectory.

## Scope (recommended phasing — revised 2026-05-20)

Formula Kit ships across **7 PRs**. New PR 2 (Pins) inserted ahead of personalization. New PR 3 (After-phase parity) inserted ahead of personalization to round out browse+pin coverage of all three phases. All later PRs shift up. Favorites removed (pins serve the user-need).

| PR | Slice | Approx scope |
|----|-------|--------------|
| **PR 1** | V1 Browse + Detail (read-only) ✅ Done | Library screen, phase tabs, filter chips, collapsible header, detail view with components. No personalization. |
| **PR 2** | Pin a formula as algorithm signal ✅ Substantively done | Single-tap pin toggle on cards/detail. Pins drive plan generation: matching pinned templates considered first, fall through to existing algorithm. New `formula_pins` table (Supabase + Drift). New `generate-nutrition-plan-v4` edge function. Transparent fit-failure banner on activity detail. System templates only in V1. |
| **PR 3** | **NEW — After-phase parity (browse + pin)** | Extend Browse + Detail + Pins to the After phase. `post_workout_templates` (v2 Notion-imported) get a Drift mirror, repository, After tab in the library, AfterFormulaCard, detail screen. Filter is `travel_friendliness` only (in_bag / cooler_friendly / home_only) — standard portion, no scaling target. Pins are in scope (post_system pin kind). Edge function gains a simple after-phase solver that prefers pinned templates and falls through to selection_priority order. No brick-specific UI. |
| **PR 4** | V3 iter 1 — "Make this mine" edit state (Before only) | Edit-state UI on Before detail, quantity stepper, placeholder swap sheet, real-time macro recompute. |
| **PR 5** | V3 iter 2 — Real Swap sheet + Your formulas + persistence + During edit + **legacy personal_templates UI deprecation** + **personal formulas become pinnable** | Real swap sheet, Your Formulas section, Drift+Supabase persistence via evolved `personal_templates`, During edit variant. Remove old "My Templates" UI. Extend `formula_pins.template_kind` to include `'personal_template'`. |
| **PR 6** | Coach insight + Add Food | AI-coach guidance panel (multi-mode edge function), Add Food button. Coach insight reads pins as part of structured context. |
| **PR 7** | Create-from-scratch | New formula from blank, "+ New" entry on Your Formulas. Final polish (during-card descriptors). |

PR 1 shipped on its own. PR 2 is the first PR that touches plan generation — it's the riskiest in terms of prod impact, isolated for that reason. PR 3 extends the same browse + pin machinery to the After phase, so the full library matches the IMG_7922 design before personalization work begins.

## Architecture

### New Flutter feature module

```
lib/features/formula_kit/
├── application/
│   ├── formula_library_controller.dart        # @riverpod AsyncNotifier — browses system + personal
│   ├── formula_personalizer_controller.dart   # edit/create draft state machine
│   ├── formula_swap_controller.dart           # wraps existing swap_food infrastructure
│   ├── coach_insight_service.dart             # calls ai-coach edge function
│   └── formula_pin_controller.dart            # NEW (PR 2) — @riverpod AsyncNotifier, single source of truth for pin state
├── data/
│   ├── personal_formulas_repository.dart      # thin wrapper around evolved personal_templates_repository — filters/writes only formula-provenance rows
│   ├── custom_foods_repository.dart           # offline-first writes to CustomFoodsTable, identical sync pattern to personal_templates
│   ├── formula_pins_repository.dart           # NEW (PR 2) — offline-first writes to FormulaPinsTable, syncs to Supabase
│   └── ai_coach_client.dart                   # remote-only edge function client (mode: 'insight' for now)
├── domain/
│   ├── personal_formula.dart                  # value type — provenance: forked | from_scratch (filters from personal_templates rows)
│   ├── custom_food.dart
│   ├── coach_insight.dart                     # { insight, staleMarker }
│   ├── formula_pin.dart                       # NEW (PR 2) — { user_id, template_id, template_kind, created_at }
│   └── formula_filter_state.dart
└── presentation/
    ├── screens/
    │   ├── formula_library_screen.dart        # browser (phase tabs + filter chips + collapsible header)
    │   ├── formula_detail_screen.dart         # read + edit state (single screen, state-driven)
    │   └── formula_create_screen.dart         # create-from-scratch (full-screen)
    └── widgets/
        ├── phase_tab_bar.dart
        ├── formula_card.dart                  # system + personal variants; shows pin toggle (PR 2)
        ├── filter_chip_row.dart
        ├── more_filters_sheet.dart
        ├── collapsible_header.dart
        ├── components_panel.dart              # read + edit (with stepper, swap, remove)
        ├── macros_panel.dart                  # live-updating
        ├── coach_insight_panel.dart
        ├── add_food_button.dart
        ├── delete_confirmation.dart
        ├── pin_toggle.dart                    # NEW (PR 2) — icon button used in card + detail
        └── pin_status_banner.dart             # NEW (PR 2) — used by activity_detail_screen, shows "Using pinned ✓" or fit-failure
```

### Drift schema additions

```
lib/shared/database/tables/
├── personal_templates_table.dart         # EVOLVE — already exists; add formula-kit columns (see below)
├── custom_foods_table.dart               # NEW — mirrors mealvana.kit.custom_foods
├── formula_pins_table.dart               # NEW (PR 2) — mirrors Supabase formula_pins; offline-first, syncs both ways
├── during_workout_templates_table.dart   # NEW (PR 1) ✅ — sync from existing Supabase table
└── post_workout_templates_table.dart     # NEW — sync from existing Supabase table (for later After-phase work)
```

**Personal templates table evolution (not a parallel table).** The existing `personal_templates_table` already stores user-owned saved nutrition plans with offline-first sync. Rather than create a parallel `personal_formulas` table, evolve this one to serve both legacy "saved plan" rows and new Formula Kit rows. Columns to add:

- `provenance` — enum: `legacy_plan` | `forked_formula` | `from_scratch_formula` (default `legacy_plan` for backfill)
- `phase` — enum: `before` | `during` | nullable (only meaningful for formula rows; null for legacy plans)
- `source_template_id` — nullable foreign-key-style reference to `pre_workout_templates.id` or `during_workout_templates.id` (only set when `provenance = forked_formula`)
- `sub_phase` — nullable, mirrors design's Meal / Snack / Top-up for Before formulas
- `digest_speed` — nullable
- `activities` — nullable JSON array (During only)
- `durations` — nullable JSON array (During only)
- `gut_training` — nullable (During only)
- `custom_food_ids` — nullable JSON array (links to `custom_foods` rows used as components)
- ~~`is_pinned_to_workout`~~ — **SUPERSEDED by `formula_pins` table (PR 2).** Originally reserved for V4 plan-time picker; that feature is now distinct from pins. If a plan-time picker ships later, it'll use its own column or join table — do not add `is_pinned_to_workout` in the PR 5 migration.

Old `personal_templates` UI surface continues to work unchanged during PR 2 — the backfill maps every existing row to `provenance = legacy_plan` so nothing breaks. Legacy UI entry points removed in PR 4.

`personal_templates` (the formulas backbone), `custom_foods`, and `formula_pins` all sync to Supabase via the standard offline-first pattern. Pins specifically must sync because both the client (`client_plan_service`) and the edge function (`generate-nutrition-plan-v4`) read them — Drift-only would prevent the server-side path from honoring pins.

### Sync + conflict resolution

Match the existing pattern in `lib/features/personal_templates/data/personal_templates_repository.dart` (`_upsertRemoteTemplatesPreservingDirty`):

- Local writes set `needs_upload = true` and are pushed to Supabase by the existing sync orchestrator.
- On `syncFromRemote`, rows where the local copy has `needs_upload = true` are skipped — local changes are preserved until pushed.
- Otherwise, remote rows upsert over local. Effectively **last-write-wins between users, with local-dirty-protection during the push window.** No vector clocks, no merge.
- `updated_at` is set server-side on insert/update via trigger (existing pattern — confirm in the migration).
- `custom_foods` follows the identical pattern: same `needs_upload` flag, same dirty-preserving upsert.

State this conflict policy explicitly in the new `custom_foods_repository.dart` doc comment so the next engineer doesn't have to spelunk.

### Supabase additions

```
supabase/migrations/
├── 2026MMDDhhmmss_formula_pins.sql                              # NEW (PR 2) — user-owned, RLS scoped to owner
├── 2026MMDDhhmmss_personal_templates_formula_kit_columns.sql   # ALTER TABLE — add columns + backfill (PR 5)
├── 2026MMDDhhmmss_custom_foods.sql                              # user-owned, RLS scoped to owner (PR 5)
└── 2026MMDDhhmmss_llm_usage.sql                                 # token usage log (see Coach Insight section) (PR 6)

supabase/functions/
├── generate-nutrition-plan-v4/                                   # NEW (PR 2) — near-copy of v3 with pin-check; v3 stays alive for old clients
└── ai-coach/                                                     # NEW (PR 6) — multi-mode edge function (insight, chat-future)
```

The `personal_templates_formula_kit_columns.sql` migration (PR 5):
1. Adds the new columns described above to `personal_templates`.
2. Backfills every existing row with `provenance = 'legacy_plan'`, `phase = NULL`.
3. Adds CHECK constraint validating provenance + phase combinations (e.g., `forked_formula` requires `phase NOT NULL` and `source_template_id NOT NULL`).
4. Keeps existing RLS policy unchanged — user-owned, scoped via `user_id`.

The `formula_pins.sql` migration (PR 2):
```sql
create table formula_pins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  template_id uuid not null,
  template_kind text not null check (template_kind in ('pre_system', 'during_system')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);
create unique index formula_pins_active_unique
  on formula_pins (user_id, template_id, template_kind)
  where not is_deleted;
create index formula_pins_user_kind on formula_pins (user_id, template_kind) where not is_deleted;
-- RLS: user can read/write only their own pins
```
Note: `template_kind` is intentionally text, not an FK to either templates table — polymorphic ref. The check constraint can be widened to `('pre_system', 'during_system', 'personal_template')` in PR 5 when personal formulas become pinnable.

### Reused components (do not rebuild)

- **Swap sheet pattern** — `lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart` is the existing source-of-truth for IMG_7922's pattern. Refactor it so Formula Kit can call into the same sheet (with mode=`swap` | `add_food`) rather than building a parallel sheet. If refactor scope is too big in PR 4, build a feature-local sheet and unify later.
- **Templates repository** — `lib/features/nutrition_plan/data/templates_repository.dart` already reads pre_workout_templates from Drift with on-demand sync. Extend (don't replace) to add during_workout_templates.
- **Personal templates pattern** — `lib/features/personal_templates/` has the precedent for user-owned templates that sync to Supabase. Follow the same offline-first + `needsUpload` flag pattern.
- **Food preferences** — `lib/features/food_preferences/` for allergen + dietary filters in More Filters sheet. The filter state must respect the same `excluded_diets`/`allergens` schema that templates already encode.
- **MealvanaSnackbar** — for "Created in Your formulas." / "Swap [component]" toasts. Never raw Flutter SnackBar (per CLAUDE.md).
- **AsyncNotifier + AsyncValue.guard** — every controller, per FOA rules.

### AI coach — multi-mode edge function (`ai-coach`)

The design uses Claude to generate ~15-28 word coach-tone guidance based on current draft macros. Build as a **multi-mode edge function** so the same function can serve future surfaces (MealBuddy chat, etc.) without restructuring.

**Envelope** (request shape):
```jsonc
{
  "mode": "insight",                    // "insight" today; "chat" reserved for MealBuddy
  "context": { /* mode-specific structured payload */ },
  "tools": []                           // empty for insight; reserved for chat tool-calling
}
```

**Coach insight uses pre-computed structured context injection — NOT live tool calling.** All algorithmic outputs (solid:liquid ratio, fiber load, estimated digestion speed, etc.) are computed *inside the edge function* before the LLM call, and injected into the prompt as a structured nutrition state block. The LLM never makes tool calls in `insight` mode. Tool-calling support stays in the envelope (the `tools` array) for future `chat` mode but is unused in PR 5.

**Edge function responsibilities for `mode: "insight"`:**
1. Receive draft components (food id + quantity) + phase + workout duration + user dietary context.
2. **Compute** structured nutrition state:
   - Total carbs / protein / fat / sodium / fluid (sum from `template_foods.*` per quantity)
   - Solid:liquid ratio (g of solid food : mL of fluid)
   - Fiber load (g, summed from food catalog)
   - Estimated digestion speed (derived from `template_foods.digestion_speed` weighted by quantity)
   - Sub-phase fit indicator (does the load match the selected Meal / Snack / Top-up?)
3. Build prompt with system message + structured state block + minimal user message.
4. Call `claude-haiku-4-5-20251001` (latency-sensitive, low-stakes content, cheap).
5. Log token usage to `llm_usage` table (see below).
6. Return `{ "insight": "<15-28 word string>", "stale_marker": "<hash of components>" }`.

**No per-user rate limiting** — Foundational metrics first, abuse protection later. If a user generates thousands of insights, that shows up in `llm_usage`.

**Token usage log (`llm_usage` table):**
```
id | user_id | function | mode | model | input_tokens | output_tokens | cost_usd | created_at
```
- Inserted on every successful LLM call across all future edge functions (foundational metrics, not Formula Kit-specific).
- Index on `(user_id, created_at)` for per-user cost queries.
- Index on `(model, created_at)` for cost-by-model reporting.
- Indexed for analytics SQL but no Supabase realtime / no app-side reads — write-only from edge functions.

### PR 5 prerequisite — coach insight prompt template

Before PR 5 implementation, ship this prompt design (it's part of PR 5's scope but called out as a prerequisite for clarity):

**System prompt (draft):**
```
You are a coach for endurance athletes using the Mealvana Endurance app.
You review a draft nutrition formula and give one short, direct piece of
guidance. Voice: athlete-to-athlete, no fluff, no wellness-influencer tone,
grounded in science. Output 15-28 words, one or two sentences. End with a
period, not an exclamation point. Never use emoji. Reference specific
numbers from the structured state when relevant.

If the formula is well-balanced for its phase and sub-phase, say so plainly.
If something is off — too low sodium for the duration, too much fiber for a
"top-up", solid:liquid skewed for during-workout — name the issue and one
concrete fix ("consider adding a pinch of salt to the oatmeal").
```

**User message template (draft):**
```
PHASE: {before | during}
SUB_PHASE: {meal | snack | top_up}    (before only)
WORKOUT_DURATION_MIN: {n}              (during only)

DRAFT COMPONENTS:
- {food_name}: {quantity} {unit}
- ...

COMPUTED MACROS:
  carbs:     {n} g
  protein:   {n} g
  fat:       {n} g
  sodium:    {n} mg
  fluid:     {n} mL

DERIVED:
  solid_liquid_ratio:    {n}:1
  fiber_load_g:          {n}
  digestion_speed_est:   {fast | medium | slow}
  sub_phase_fit:         {good | warn | poor}

Give your guidance.
```

**Output shape:**
```json
{ "insight": "string, 15-28 words", "stale_marker": "hash" }
```

Client caches `(stale_marker, insight)` per draft. When any component changes, the new local hash differs from the cached `stale_marker`, the panel goes "Outdated — refresh", and a fresh call is triggered on tap.

## Analytics (Mixpanel)

All events follow the existing convention in the codebase: `controller.trackEvent('snake_case_event_name', { ...payload })`. Inspected precedents: `workout_saved`, `workout_completed`, `swap_food_tapped`, `add_food_tapped`, `workout_saved_with_template` (all in `activity_detail_screen.dart`).

Fire from controllers (FOA: not from screens). Add the events listed below in the PR they're introduced — do not stockpile events ahead of features.

**PR 1 — Browse + Detail:**
| Event | Payload |
|---|---|
| `formula_library_opened` | `{ source: 'food_preferences_hub' }` |
| `formula_phase_switched` | `{ from: 'before' \| 'during', to: 'before' \| 'during' }` |
| `formula_filter_applied` | `{ filter_type: 'diet' \| 'allergen' \| 'sub_phase' \| 'activity' \| 'duration' \| 'gut_training', value: <string>, active_filter_count: <int> }` |
| `formula_detail_viewed` | `{ template_id: <string>, phase: 'before' \| 'during', is_personal: false }` |

**PR 2 — Pins + algorithm signal:**
| Event | Payload | Fired from |
|---|---|---|
| `formula_pinned` | `{ template_id, template_kind: 'pre_system' \| 'during_system', phase, sub_phase \| activities, source: 'card' \| 'detail' }` | `FormulaPinController` |
| `formula_unpinned` | `{ template_id, template_kind, phase, source: 'card' \| 'detail' \| 'banner' }` | `FormulaPinController` |
| `plan_used_pin` | `{ template_id, phase, sub_phase \| activity \| duration, pin_set_size: <int>, scaling_factor: <float> }` | client `client_plan_service` + edge fn v4 |
| `plan_pin_fallthrough` | `{ pin_set_size: <int>, reason: 'scale_out_of_range' \| 'allergen' \| 'dislike' \| 'gut_train_mismatch' \| 'all_pins_failed_fit', fallback_template_id: <string> }` | client + edge fn v4 |
| `pin_status_banner_tapped` | `{ template_id, banner_state: 'using_pin' \| 'pin_fallback' }` | `activity_detail_screen` |

**PR 4 — Make this mine (Before):**
| Event | Payload |
|---|---|
| `make_this_mine_tapped` | `{ source_template_id: <string>, phase: 'before' }` |
| `personal_formula_saved` | `{ provenance: 'forked_formula', source_template_id: <string>, phase: 'before', component_count: <int>, edit_duration_sec: <int> }` |
| `personal_formula_edit_cancelled` | `{ source_template_id: <string>, phase: 'before' }` |

**PR 5 — Swap sheet + Your formulas + During edit + pinnable personal formulas:**
| Event | Payload |
|---|---|
| `formula_swap_opened` | `{ phase, component_id, source: 'edit' \| 'add_food' }` |
| `formula_swap_completed` | `{ phase, from_food_id, to_food_id, to_food_source: 'system' \| 'my_foods' \| 'created' }` |
| `custom_food_created` | `{ category: 'solid' \| 'gel' \| 'fluid' \| 'drink_mix' \| 'tablet' }` |
| `personal_formula_deleted` | `{ formula_id, phase, provenance }` |
| `personal_formula_saved` | (extend with `phase: 'during'` rows) |
| `formula_pinned` | (extend with `template_kind: 'personal_template'`) |

**PR 6 — Coach insight + Add Food:**
| Event | Payload |
|---|---|
| `coach_insight_generated` | `{ phase, mode: 'insight', cached: bool, latency_ms: <int>, input_tokens: <int>, output_tokens: <int>, pinned_context_count: <int> }` |
| `coach_insight_refresh_tapped` | `{ phase }` |
| `add_food_tapped` | `{ phase, draft_component_count: <int>, surface: 'formula_kit' }` (note: name collides with existing nutrition-plan event — qualify with `surface`) |

**PR 7 — Create-from-scratch:**
| Event | Payload |
|---|---|
| `formula_created_from_scratch` | `{ phase, sub_phase \| activities, component_count }` |

## Verification

End-to-end test plan, per slice:

**PR 1 (browse):**
- Run `flutter run --flavor dev` on iOS simulator.
- Open Settings → Food Preferences → confirm the new **Formula Library** tile appears as the 4th tile alongside Dietary Preference, Allergies, and Food Likes & Dislikes. Tap it.
- Tap into library, swipe between Before/During tabs, scroll the list, observe collapsed header on scroll.
- Open More Filters, apply diet + allergen filters, confirm list updates.
- Tap a card, see detail with components, hit back.
- Run `flutter test test/features/formula_kit/` (unit + widget tests for filter logic + card rendering).

**PR 2 (Pins + algorithm signal):**
- Pin a Before formula → confirm pin icon toggles → kill app → relaunch → pin still active (Drift) → check Supabase `formula_pins` row exists (sync).
- Create a new workout matching the pinned formula's sub_phase/scope → activity_detail banner reads "Using your pinned formula ✓ [name]".
- Pin a formula whose scaling would exceed 2x for an extreme macro target → trigger plan generation → banner reads "pin didn't fit — using [fallback]" → `plan_pin_fallthrough` event fires with `reason: 'scale_out_of_range'`.
- Pin multiple Before formulas for the same sub_phase → algorithm picks best by carb proximity within pinned set → confirm via `plan_used_pin.template_id`.
- **v3↔v4 parity test:** invoke `generate-nutrition-plan-v3` and `generate-nutrition-plan-v4` with same fixture user (no pins) → diff `phases.*` outputs → confirm byte-identical.
- **Old client safety:** bump app version on simulator A (calls v4) and keep simulator B on prior version (still calls v3) → confirm both produce valid plans, A honors pins, B unaffected.
- Run `flutter test test/features/formula_kit/` (incl. new `formula_pins_repository_test`, `client_plan_service_pinned_template_test`).

**PR 4 (Make this mine):**
- On a Before template detail, tap "Make this mine".
- Tweak quantities, watch macros tween. Save. Confirm a Personal formula appears.
- Verify offline-first: enable airplane mode mid-edit, save, re-enable network, confirm sync.

**PR 5 (real swap + persistence + During + personal pinning):**
- Open swap sheet, add a custom food, save. Confirm it appears in My Foods on next open.
- Pull-to-refresh / quit app / relaunch — confirm everything persists from Drift and reconciles with Supabase.
- Verify During edit variant has no quantity stepper (per spec).
- Pin a personal formula → confirm `formula_pins.template_kind = 'personal_template'` row created → confirm algorithm honors it.
- Run integration tests via Patrol (if the patrol branch has merged by then) or via existing integration_test harness.

**PR 6 (insight + add food):**
- Confirm Coach insight panel renders shimmer → returns text from edge function in <2s.
- Test edge function via `supabase functions invoke ai-coach --body '{"mode":"insight","context":{...}}'`.
- Verify `llm_usage` table has a new row with non-zero input/output tokens after each call.
- Add Food button opens swap sheet in add mode; selecting appends component.
- Confirm coach insight prompt receives `pinned_template_ids[]` in structured context.

**PR 7 (create-from-scratch):**
- Create from scratch, confirm validation (toasts on muted Save), save, confirm landing on detail.

## Risks & open questions

1. **Patrol branch widget keys.** PR 1 will land while `feat/patrol-integration-tests` is in flight. If patrol merges first, Formula Kit screens need ValueKeys for the new test suite. Coordinate timing or add keys preemptively.
2. **Custom food deduplication.** If a user creates "Banana 100g" custom food and we already have a system "Banana" — do they collide? Design defers this. Likely V2 cleanup.
3. **Coach insight cost monitoring.** No per-user rate limiting (intentional — foundational metrics first). Monitor `llm_usage` table for outliers; if any user generates >100 insights/day, that's a signal to revisit. Cost itself is bounded by Haiku pricing × short prompts × short outputs.
4. **PR 2 edge-function risk.** This is the first PR that modifies plan generation. Mitigation: new `generate-nutrition-plan-v4/` directory (don't touch v3); pin-aware behavior is strictly additive (no-pins users get identical output to v3); client gates v3→v4 via app version (old binaries keep calling v3). Always run the v3↔v4 parity test on fixture users with zero pins before merging.
5. **Pinned formula no longer fits user's diet.** Per the honor-pin policy locked 2026-05-21, pins are NOT auto-fallen-through on allergen/diet/dislike conflict — the user's explicit pin wins over their stored profile. The original concern ("the pin will fall through every time") no longer applies. The safety net is the V2 advisory pill (see "Deferred client-side work") that visually flags the conflict in the UI. Auto-pruning pins on dietary changes remains an open V2 question, but is lower priority now that the conflict is surfaced rather than silently dropped.
6. **Pin a personal formula that gets deleted.** PR 5 cleanup: when a personal_templates row is hard-deleted, cascade-delete its pin rows (FK to `personal_templates.id` with `on delete cascade` for the personal-kind subset, OR soft-delete via `is_deleted` on the pin row at the application layer).
7. **Migration backfill correctness.** The `provenance = 'legacy_plan'` backfill (PR 5) must run after the column is added but before any client reads the new column. Test on a Supabase branch first.

## Critical files to read before PR 1

- `lib/features/nutrition_plan/application/client_plan/client_plan_service.dart` — to understand how templates are silently applied today.
- `lib/features/nutrition_plan/data/templates_repository.dart` — sync pattern to extend.
- `lib/features/personal_templates/data/personal_templates_repository.dart` — precedent for user-owned + Supabase-synced data.
- `lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart` — what to reuse / refactor for the design's Swap sheet.
- `supabase/migrations/20260406320000_during_workout_templates_complete.sql` — during-template schema (only on develop).
- `/tmp/formula-kit/formula-library-remix-remix/project/Formula Kit.html` — pixel reference for every PR.

## Deferred client-side work

Captured 2026-05-21 while scoping substep 4. Each item is real follow-up that the V1 plan does not deliver; tracked here so we don't lose them.

1. **Client fallback path: migrate from `templates` to `pre_workout_templates` + pin awareness.** `client_plan_service._tryTemplateBasedBefore` (`client_plan_service.dart:307`) currently reads the legacy `templates` table via `TemplatesRepository`. The Formula Library, pin rows, and edge function v3/v4 all read `pre_workout_templates`. Until the client fallback is migrated, the rare "edge function unreachable" path can't honor pins. Tasks: (a) point the fallback at `PreWorkoutTemplatesRepository`, (b) translate `pre_workout_templates` (per-serving macros + joined `template_foods`) into the FoodItem emissions `client_plan_service` produces today, (c) layer in pin awareness with the locked honor-pin policy (skip filters, no scale clamp, food templates only, V2 advisory pill for diet/allergen conflicts), (d) handle the "pinned formula needs >2× servings" case without clamping. Out of V1 because (i) edge function covers ~99% of plan generations, and (ii) the legacy `templates` table itself is on a deprecation path.

2. **Client-side hydration + electrolyte stacking parity with edge function.** The edge function stacks three template pools (`food`, `drink`, `electrolyte` — see `before-phase.ts:166-200`) and the During phase has a `[POST-PROCESS-DURING]` electrolyte top-up to fill sodium deficits (`during-phase.ts:48-150`). The client fallback picks one food template, scales it linearly, and stops there. Even without pins, this is a behavior gap — when the edge function fails over to client generation, hydration and sodium are unaddressed. Tasks: (a) port the three-pool stacking logic to `client_plan_service`, (b) port the sodium top-up pass, (c) integrate with the table migration above so the same `pre_workout_templates` query supports all three template types. This item is bigger than #1 and should land alongside or after it.

3. **V2 advisory pill: dynamic "violates your profile" indicator.** When a pinned formula conflicts with the user's stored allergen/dietary preferences (because pins now bypass those filters per the locked honor-pin policy), the UI should surface this visually rather than silently honoring the pin. Design intent (from 2026-05-21 session): a pill or alert on the formula card / detail / activity-detail banner that reads something like "Violates your diet" or "Contains [allergen]", dynamically computed from the active user profile. Likely extends to non-conflict advisories too (e.g., "Low sodium for your sweat profile" once sweat-profile data is integrated). Scope: design proposal first, implementation deferred until at least one real user has pinned a profile-conflicting formula. Tracked here so we know the safety net exists before scaling out the honor-pin policy.

## Out of scope (per design)

- After phase (separate work — backend exists, no design)
- AI coach algorithm integration into plan generation (V4 in design)
- Sharing personal formulas with a coach (separate work)
- Importing recipes from external sources
- Photo upload
- Reordering components
- Renaming personal formulas beyond the auto "From [Source]" eyebrow
