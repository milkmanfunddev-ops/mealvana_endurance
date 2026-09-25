# 09: Nothing calls the server before the athlete taps

**Status:** ready-for-agent
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 09 ai-cost`
**Model:** opus
**Due:** October

**What to build:** The Food tabs build at app launch and fire at least four `vana-action` calls, one of which builds the full athlete context (about 25 queries, two weather fetches) and sometimes calls Haiku.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-internal-audit.md finding 6; running-cost-model.md

**Touches:** lib/features/main/presentation/tabs_screen.dart, lib/features/food/presentation/food_screen.dart, lib/features/ai_credits/application/credits_controller.dart

- [ ] No `vana-action` call fires at launch before the Food tab is opened (widget test).
- [ ] Tab state is still kept once visited.
- [ ] The wallet realtime channel is open only while a credits surface is on screen.
- [ ] An unanswered planning opener is reused for 30 minutes on the same screen instead of drafted again; any reply or a plan change ends the reuse.

Next: /mattpocock-skills:implement 09 ai-cost
