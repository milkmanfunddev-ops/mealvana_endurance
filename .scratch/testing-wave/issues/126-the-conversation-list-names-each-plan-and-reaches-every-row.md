# 126: The conversation list names each plan and reaches every row

**Status:** in-progress (wave 31, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Two fixes to Conversations > Meal plans, from wave 29.
1. **Row titles (88-002, 89-007).** Every row reads "No plan yet" while the opened chat's header reads "Sep 20 week · Confirmed". `VanaChatRepository.fetchConversations` selects `id, kind, title, summary, last_message_at, created_at` only, so `VanaConversationSummary.plan` is always null and `planConversationTitle` falls back. The list and the header must use the same title (ticket 97's rule). The server already picks a conversation's plan (`listConversations` / `conversationPlans` in `supabase/functions/_shared/vana/chat.ts`: confirmed plan first, else the newest with meals). Either embed `meal_plans(...)` through `meal_plans.conversation_id` and reuse that rule in Dart, or call a `list_conversations` action. Pick one; never keep two pick rules that can disagree.
2. **Paging (88-021).** `fetchConversations({int limit = 50})` and the screen never asks for more, so 30 of test@test.com's 80 conversations cannot be opened. Load the next page when the list scrolls near its end.

**Findings:** 88-002, 89-007, 88-021.

**Decisions:** none; ticket 97's title rule.

**Touches:** lib/features/meal_planning/data/vana_chat_repository.dart, lib/features/meal_planning/application/vana_conversations_controller.dart, lib/features/meal_planning/presentation/screens/vana_conversations_screen.dart, lib/features/meal_planning/domain/ui_action.dart (only if the action route is chosen), supabase/functions/_shared/vana/actions.ts (only if the action route is chosen), supabase/functions/_shared/vana/chat.ts (only if the action route is chosen)

- [x] A repository or controller test fed a producer-shaped row set (confirmed, archived, draft, no plan) gives the same titles the chat header gives.
- [x] A controller test: a second page loads when asked and appends without duplicates; the end of the list stops asking.
- [x] `flutter analyze` clean on touched files; deno tests for touched functions. Deploy: wave lead.

Next: /implement-lee testing-wave
