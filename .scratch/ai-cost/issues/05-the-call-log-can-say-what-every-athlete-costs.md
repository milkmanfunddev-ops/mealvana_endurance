# 05: The call log can say what every athlete costs

**Status:** in-progress (wave 3, 2026-09-22)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/chat.ts), 04 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Lee can open one saved view and read, per week: cost per athlete by plan, the first-step cache hit rate, cost per confirmed plan, spend in conversations that never add a meal, and the share of turns that were fixed-label taps. An account that costs more than $1.50 in a day is reported to Sentry the same day. The app says whether each message was tapped or typed.

**Decisions:** mp-420, mp-464; approved as mp-470.

**Touches:** supabase/migrations, supabase/functions/_shared/vana/log.ts, supabase/functions/_shared/vana/chat.ts, lib/features/meal_planning/data/vana_chat_repository.dart, lib/features/meal_planning/application/vana_chat_controller.dart, docs/database

- [x] The call log gains cache-write tokens, step count, the gateway's charge, whether the turn drew the budget, tap or typed, and the subscriber's plan and trial state. Idempotent migration, applied to dev.
- [x] The app sends tap or typed with every message (test through the real chat controller).
- [x] One saved weekly view gives the five figures above.
- [x] A daily check reports any account over $1.50 in a day to Sentry and refuses nothing.
- [x] Raw rows in the three AI log tables are swept after 90 days; weekly rollups are kept.
- [x] A log test asserts every new column is written.

Next: /implement-lee ai-cost
