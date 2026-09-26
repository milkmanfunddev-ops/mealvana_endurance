# 131: Confirm shows the "you're set" card on Shopping

**Status:** done (wave 35, 2026-09-26)
**Blocked by:** 129 (both change the Review sheet's confirm path and the Shopping tab).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Build the rest of mp-235 (88-016, ssot-conflict). Confirm today lands on Food > Shopping (ticket 72) but the "you're set" card never shows: the chat is left straight from the Review sheet, and the Plan tab's "Confirm plan · build shopping list" stays on Plan with no card. The card already exists (`lib/features/meal_planning/presentation/widgets/confirmed_card.dart`: week and meal count, cooking sessions, list size, where things live, Share, and the "remind me the night before cook day" chip through `plan_reminder_service.dart`), drawn today only as a chat part.

Lee's ruling (2026-09-25): **both confirms land on Food > Shopping with the tab bar, and the card sits at the top of the new list, once, dismissable**, carrying Share, the reminder chip, Lay it across the week and Adjust (mp-235 details 1-3). The Plan tab's confirm moves to Shopping too. The card shows for the plan just confirmed, not again on the next open once dismissed or after the athlete leaves. The tab bar shows expanded, not the small Food bubble 88-016 saw.

**Findings:** 88-016.

**Decisions:** mp-235 (quoted in 88-016).

**Touches:** lib/features/meal_planning/presentation/widgets/confirmed_card.dart, lib/features/meal_planning/presentation/screens/shopping_tab.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/screens/plan_tab.dart, lib/features/meal_planning/presentation/screens/previous_plan_screen.dart (its Confirm, if it lands the same way), lib/features/meal_planning/application/meal_plan_controller.dart, lib/features/meal_planning/application/plan_reminder_service.dart, lib/features/meal_planning/application/plan_share_service.dart, lib/features/meal_planning/presentation/widgets/vana_part_renderer.dart, lib/features/meal_planning/presentation/screens/food_screen.dart (`goToFoodTab`; callers vana_chat_screen.dart:465, :467, :1111 and plan_tab.dart:130, :170), lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [x] Widget tests: after a confirm from the Review sheet and from the Plan tab, Food > Shopping shows the card at the top with Share, the reminder chip, Lay it across the week and Adjust; dismissing it keeps it gone.
- [x] Seam test through the real notifier for the "just confirmed" state the card reads.
- [x] The tab bar is present and expanded on landing.
- [x] No hardcoded strings; `flutter analyze` clean on touched files.

Next: /implement-lee testing-wave

## Build notes (wave 35)

Open for Lee (no page writes during a fix wave):
- Adjust on the card opens the plan's own Vana conversation (or a new planning one) without sending anything, and closes the card.
- The earlier-plan screen's Confirm now lands on Food > Shopping too, instead of popping back to Plan.
- "Open shopping list" is dropped from the card on Shopping (the athlete is already there).
- The Vana moment pill still collapses the tab bar on purpose. If 88-016's small bubble was the pill rather than a scroll, landing can still show it collapsed; only a device retest tells.

Review follow-ups not fixed (minor): a Lay-it-across tap on plan B's card can join plan A's in-flight request and silently show nothing; a slow Plan-tab or earlier-plan confirm lands on Shopping even if the athlete backed out meanwhile.
