# 15: The next conversation knows the last one, and never waits

**Status:** in-progress (wave 3, 2026-09-15)
**Blocked by:** 13 (touches supabase/functions/_shared/vana/chat.ts), 14 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete closes the sheet at night and opens it in the morning: the opener arrives at once and knows what last night established. The client sends the idle flag on the chat call when the sheet closes, the app backgrounds, or a new conversation starts; the server writes the episode and any missed margin notes once and ignores a repeat. The remember tool's prompt rule is sharpened so durable things are saved as they are said. The read-back-on-open, its wait, the last-words fallback and their helpers are removed. The opener reads what exists.

**Decisions:** mp-277, mp-278, mp-288, mp-024; approved as mp-293.

**Touches:** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/opener.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/_shared/vana/schemas.ts, supabase/functions/tests/vana/personal_openers.test.ts, lib/features/meal_planning/data/vana_chat_repository.dart, lib/features/meal_planning/application/vana_ambient_conversation_controller.dart, lib/features/meal_planning/presentation/widgets/vana_companion.dart, test/features/meal_planning/application/vana_ambient_conversation_test.dart

- [ ] The chat request accepts an idle flag; the first idle for a conversation writes its episode and notes, the second writes nothing, no flag writes nothing (server seam).
- [ ] The client sends idle on sheet close, app background and new conversation (controller test through the real notifier), fire-and-forget.
- [ ] OPENER_READ_BACK_MS, readBackWithin and athleteWordsFrom are gone; the opener path awaits nothing.
- [ ] The remember rule in the persona is sharpened and the eval case "a durable thing said in passing is a Memory by the next turn" passes.
- [ ] Eval: a conversation never signalled idle still opens the next one at once.
- [ ] Dev deploy; simulator: close the sheet, reopen, the opener mentions last time.

Next: /implement-lee mealplanning
