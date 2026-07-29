# Activity-Owned Nutrition Plan Roadmap

*Updated: 2025-11-09*

We are removing the last traces of the “current nutrition plan” concept. Every nutrition plan now lives entirely inside its parent activity record. There is no standalone `nutrition_plans` table and no plan-level identifier that needs to be threaded through the UI. All plan revisions are simply edits to `activities.nutrition_plan_data`.

## Why we are doing this

1. **No more implicit “current plan”.** Athletes can have multiple activities (and therefore plans) on the same day. Treating “the plan” as a global singleton causes the UI to show stale data when the user bounces between workouts.
2. **Simpler sync + storage.** Embedding the full JSON on `activities` means we only track one table in Drift/Supabase, and dirty uploads always operate at the activity level. No more double-writes or joins.
3. **Fully activity-driven UX.** Controllers and edge functions should accept an `activityId` and treat nutrition plans as part of that payload. Regenerating a plan becomes `updateActivity(activityId, newNutritionJson)` rather than `createPlan(planId)` and patching references everywhere else.

## High-level goals

| Area | Outcome |
| --- | --- |
| Database schema | `public.activities` holds `nutrition_plan_data JSONB`; the `nutrition_plan_id` column and the `public.nutrition_plans` table are gone. |
| Edge functions | `save-calendar-activity`, `generate-nutrition-plan`, and any helpers only read/write the activity. No other table insert/upsert. |
| Flutter repositories/services | All plan operations receive an `activityId`, update the activity row via Drift, and stop exposing `plan.id`. |
| UI/controllers | Screens fetch nutrition data by loading the activity. Feedback, journaling, and analytics rely on `activityId` (and timestamps) rather than `planId`. |
| Docs/tests | Roadmaps, schema docs, and automated tests describe the activity-owned model and fail if any code resurrects the old table. |

## Workstream breakdown

### 1. Supabase schema
- [x] Update `supabase/migrations/20251109000000_embed_nutrition_plan_on_activities.sql` to *drop* `nutrition_plan_id` (keep only `nutrition_plan_data JSONB`).
- [x] Remove any downstream indexes or views using `nutrition_plan_id`.
- [ ] Clean up `docs/database/supabase/schema.sql` and related docs to reflect the simplified column set.

### 2. Edge functions
- [ ] `save-calendar-activity`: stop normalizing/returning `nutritionPlanId`; only accept `activity.nutrition_plan_data` (JSON). Ensure deletes/updates operate solely on activity IDs.
- [ ] `generate-nutrition-plan` & `create-nutrition-plan`: return the generated sections but do **not** write to Supabase. The Flutter client invokes them and then saves the result onto the activity.
- [ ] Update any legacy edge tests that still call or clear `nutrition_plans`.

### 3. Flutter data layer
- [x] `NutritionPlanRepository`: remove `cachePlanLocally(planId, ...)` patterns. Replace with `setActivityPlan(activityId, planJson)` and delete `findActivityByPlanId`.
- [ ] `AppDatabase`: drop helper methods that accept `planId`; expose only activity-based getters.
- [ ] `NutritionPlanService` & controllers: require an `activityId` for generate/update/delete flows. When the user regenerates a plan, just call `activitiesRepository.updateActivity()` with the new JSON.
- [ ] `FeedbackService`, journaling, and analytics: reference `activityId` + `nutrition_plan_data?.updatedAt` instead of `planId`.

### 4. UI + state management
- [ ] Activity detail, macro adjustment, and onboarding screens load the relevant `Activity` and read `activity.nutritionPlan`. No `plan.id` state in the providers.
- [ ] Delete any Riverpod providers that expose “current plan” without the activity context.
- [ ] Ensure multi-activity scenarios (e.g., two workouts in one day) render correctly because state is tied to activity IDs.

### 5. Tests & tooling
- [ ] Remove the deleted table from test helpers (e.g., cleanup routines) and snapshots.
- [ ] Add regression tests that fail if any Supabase RPC tries to touch `nutrition_plans`.
- [ ] Update analyzer/lint configs to flag references to `nutrition_plan_id`.

### 6. Documentation
- [ ] Update `COMPLETE-MIGRATION-ROADMAP.md`, `PHASE-0-CLIENT-ROADMAP.md`, and `database_status.md` to describe the activity-owned model.
- [ ] Add a short “activities store plan JSON directly” blurb to CLAUDE.md and drift docs so new engineers understand the pattern.

## Rollout considerations

1. Ship the Supabase migration first (drops the table/column).
2. Deploy the updated edge functions.
3. Release the Flutter changes that rely solely on activity IDs.
4. Confirm no background task or analytics pipeline still expects a plan table.

Once all steps land, the system no longer has a “current plan” concept—everything runs through the activity lifecycle. This keeps nutrition planning consistent with the rest of the calendar architecture and simplifies future multi-activity features.
