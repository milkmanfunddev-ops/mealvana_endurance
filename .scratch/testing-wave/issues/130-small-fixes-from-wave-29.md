# 130: Small fixes from wave 29

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** A batch of small fixes from wave 29, one agent, as a list.
1. **Plan tab buttons clear the tab bar (88-008).** Add meal and New meal plan sit under the floating tab bar with a 4-meal plan (a tap hit Learn). `plan_tab.dart:70`'s ListView gets `HomeShellChrome.bottomChromeClearancePx` bottom padding like other shell screens; check `shopping_tab.dart:61`, which has the same pattern.
2. **Browse cards at large text (88-014).** Every card overflows (7-37 px) at accessibility-large: `meal_rail.dart:90` fixes the rail at 132 px. Let the rail grow with the text scale or let the card's tags wrap or clip cleanly; no overflow stripe.
3. **The Plan tab's Vana note follows the plan (88-023).** After a confirm the note names the old plan's meal until the app restarts: `_DayNoteCard` reads `homeControllerProvider()`, which stays alive and is not refreshed after `confirmPlan` or other plan writes. Refresh it when the plan changes (and again when the server's rewritten notes land). Also "aim for 835C carbs": `context.ts:121-129` writes carbs as `${carbsG}C` and the model copies it; tell `DAY_NOTE_SYSTEM` to write "g carbs", or write the context in words.
4. **Shared list counts what is left to buy (89-002).** "9 items to buy" while 6 are ticked: the share text counts rows neither checked nor had.
5. **The admin read retries (89-010).** One failed `is_admin` read at an offline start hides Team review for the session (`isAdminProvider` is keepAlive, re-reads only on a user change). Keep returning false on failure (`pro_gate.dart:38` awaits it) and re-read when the network returns or on the next app resume.
6. **Previous plans drops a plan it found gone (89-013).** When the earlier plan view gets null ("This plan is no longer here."), invalidate `previousPlansProvider` so Back shows the sheet without that row.
7. **Team reviews carry the app version (89-014).** `MealReview.toRow` never sends `app_version`; send `PackageInfo` version and build (as `app_startup_service.dart:521` reads it).
8. **Previous lists names (89-015, Lee: all four).** A rename to a name another list has gets a " (2)" suffix (next free number); the row menu's Delete dialog names the list and its date; Save is disabled for an empty name; list names cap at 60 characters like plan names (`PLAN_NAME_MAX`), in the app and on the server.

**Findings:** 88-008, 88-014, 88-023, 89-002, 89-010, 89-013, 89-014, 89-015.

**Decisions:** none on the page; Lee's ruling in the terminal (89-015).

**Touches:** lib/features/meal_planning/presentation/screens/plan_tab.dart, lib/features/meal_planning/presentation/screens/shopping_tab.dart, lib/features/meal_planning/presentation/widgets/meal_rail.dart, lib/features/meal_planning/presentation/widgets/meal_rail_card.dart, lib/features/meal_planning/application/meal_plan_controller.dart, lib/features/meal_planning/application/home_service.dart, supabase/functions/_shared/vana/daynotes.ts, supabase/functions/_shared/vana/context.ts, lib/features/meal_planning/presentation/widgets/shopping_share_button.dart, lib/features/meal_planning/application/shopping_list_controller.dart, lib/shared/providers/is_admin_provider.dart, lib/features/meal_planning/application/previous_plans.dart, lib/features/meal_planning/data/meal_review_repository.dart, lib/features/meal_planning/application/meal_detail_controller.dart, supabase/functions/_shared/vana/shopping.ts, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

Rename and Delete for Previous lists live in `shopping_tab.dart` (`_renameList`, `_deleteList`) and `shopping_list_controller.dart` (`renameList`).

- [ ] Widget tests: Plan tab buttons are hit-testable above the tab bar with 4 meals; a rail card at text scale 2.0 lays out without overflow; the Delete dialog names the list; Save is disabled for an empty name.
- [ ] Controller or unit tests: the share count leaves out ticked rows; a failed admin read is retried; a duplicate list name gets the suffix (server and app agree); a review row carries `app_version`.
- [ ] Deno test: the day-note context writes no "NC" carb shorthand.
- [ ] `flutter analyze` clean on touched files; deno vana tests. Deploy (vana-action, vana-day-notes and the functions sharing `_shared/vana`): wave lead.

Next: /implement-lee testing-wave
