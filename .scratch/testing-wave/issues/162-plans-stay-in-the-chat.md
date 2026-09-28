# 162: Plans stay in the chat

**Status:** in-progress (wave 44, 2026-09-28)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Lee's 2026-09-28 rulings (`review-20260928-rulings.md`): a draft lives only in its Vana chat and never shows anywhere else. "You either confirm or you don't." Five fixes:
1. **Use this plan again confirms at once (89-006).** Today it copies an earlier plan into this week as a draft with no conversation, and after Back that draft can't be reached. From now on it asks "Replace this week's plan with this one?" (content system). On Yes the copy becomes this week's confirmed plan, the old confirmed plan is archived as on any confirm, and the shopping list is rebuilt. No draft row is ever created. If this week has no confirmed plan, confirm without asking. Server action in `_shared/vana/actions.ts`, app side in `previous_plans.dart`, `meal_plan_controller.dart` and `vana_chat_screen.dart`. Update `plan_list.test.ts` and `draft_lists.test.ts`.
2. **One general conversation per day (88-001).** On a new install, Ask Vana starts a second general conversation for today and pays for a second opener. It should continue the day's conversation (VS-5). Today's conversation id is kept only on the device (`vana_ambient_store.dart`). When the store has none, look up the athlete's general conversation for today's `context_day` on the server before creating one.
3. **A replaced draft's chat is read-only (88-005, mp-675).** Browse and card actions in a conversation whose draft was replaced wrote into the archived plan and showed "In your plan". Refuse the write both on the server (an archived plan takes no meal adds) and in the app (Browse and card adds are disabled in that chat, with the existing replaced-plan note).
4. **Plan tab menu with no plan (89-012).** `PlanOverflowMenu` is built only when this week's plan has meals (`plan_tab.dart`), so at the start of a week Previous plans can't be opened. Show the menu whenever the athlete has earlier plans. Items that need a current plan are hidden.
5. **No offline shopping copy for a draft (item 17, from 133).** A draft's offline shopping copy still shows its lines when the week has no confirmed plan. Show only a confirmed plan's list (`shopping_list_controller.dart`, `shopping_tick_store.dart`).

88-018 (a half-built draft can't be found from the Plan tab) needs no fix under the ruling: the draft is reached through its conversation, which fix 126 labels.

**Findings:** 89-006, 88-001, 88-005, 89-012, 88-018 (closed by ruling), plus review item 17.

**Decisions:** Lee in the terminal, 2026-09-28. This changes mp-675 ("Use this plan again copies it into this week as a new draft"). Record it with `/ssot` after the build.

**Touches:** supabase/functions/_shared/vana/actions.ts, supabase/functions/_shared/vana/contracts.ts, supabase/functions/tests/vana/plan_list.test.ts, supabase/functions/tests/vana/draft_lists.test.ts, lib/features/meal_planning/application/previous_plans.dart, lib/features/meal_planning/application/meal_plan_controller.dart, lib/features/meal_planning/application/vana_ambient_conversation_controller.dart, lib/features/meal_planning/data/vana_ambient_store.dart, lib/features/meal_planning/data/vana_chat_repository.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/presentation/screens/vana_browse_screen.dart, lib/features/meal_planning/presentation/screens/plan_tab.dart, lib/features/meal_planning/presentation/widgets/plan_overflow_menu.dart, lib/features/meal_planning/application/shopping_list_controller.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

These files were located by grep, not traced. Follow each flow from its screen before editing. Deploy the changed edge functions to dev per the playbook.

- [ ] Deno tests: use-again confirms and archives the previous confirmed plan with no draft left. A meal add to an archived plan is refused.
- [ ] Seam tests through the real notifiers: use-again yields a confirmed plan and a rebuilt list. With an empty ambient store and a server-side conversation for today, no new conversation is created. A replaced draft's chat refuses an add.
- [ ] Widget tests: the Plan tab shows its menu with no plan this week when earlier plans exist. The Shopping tab shows no lines for a draft.
- [ ] `flutter analyze` clean on touched files.
