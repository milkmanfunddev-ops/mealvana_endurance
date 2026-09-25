# 97: Plans and conversations are easy to tell apart

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Four approved ideas (Lee, 2026-09-25):
1. Meal-plan conversations in Vana > Conversations are titled by week and plan state, for example "Sep 20 week · Draft", "Sep 13 week · Confirmed", "No plan yet". A resumed older conversation is headed by that title, not "New meal plan" (16-006, 18-007).
2. Previous plans: within each week the confirmed plan comes first with a "Confirmed" tag, then the other plans newest first. Ties on `updated_at` break by `created_at` (17-004).
3. Back from an earlier plan returns to the Previous plans sheet at its scroll position (17-007).
4. Review & Log shows a thumbnail of the analyzed photo for a photo log. The timeline card stays as it is (24-007).

**Findings:** 16-006, 18-007, 17-004, 17-007, 24-007. Retest ticket 100 closes them.

**Decisions:** none dispute these; Lee approved each in the terminal. No page writes.

**Touches:** lib/features/meal_planning/presentation/widgets/previous_plans_sheet.dart, the conversations list and planning chat header (lib/features/meal_planning/ or lib/features/ai_coach/), supabase/functions/_shared/vana/chat.ts if the title comes from the server, lib/features/meal_logging/presentation/screens/meal_review_screen.dart, assets/config/content_defaults.json

- [ ] A test for each of the four (title from week and state, sheet order and tag, Back lands on the sheet, thumbnail present for a photo log and absent otherwise).
- [ ] `flutter analyze` clean on touched files; deno tests if chat.ts changed.

Next: /implement-lee testing-wave
