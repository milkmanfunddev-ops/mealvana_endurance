# 05: The model is sent only what it reads

**Status:** ready-for-agent
**Blocked by:** 04 (pins the ai version)
**Next:** `/mattpocock-skills:implement 05 ai-cost`
**Model:** fable
**Due:** before 2026-10-01

**What to build:** Since `2f619269` every picker result carries 24 extra full meal records to the model, about 10,000 tokens, replayed every later turn. And every opener pays for a second model step that writes nothing. Both are small changes with the largest saving after the cache.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-internal-audit.md findings 1, 2; ai-cost-claude-platform.md items 1, 2

**Touches:** supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/contracts.ts, supabase/functions/tests/vana/, scripts/vana-eval/

- [ ] `suggestMeals` defines `toModelOutput`: the shown meals in compact form and a count of the tail. The client part is unchanged (contract test with the frozen fixtures).
- [ ] Every other tool result the audit lists as oversized gets a model-facing form under a stated size budget (one test per tool).
- [ ] `convertToModelMessages` is passed `{ tools }`, so replay uses the compact form. Verify the signature against the pinned `ai@6`.
- [ ] The picker message is stored once.
- [ ] `stopWhen` stops on `askChoice`, `handOff` and a silenced `saveFeedback`. The opener eval asserts one model step.
- [ ] On dev, input tokens on the fourth planning turn of a scripted conversation are recorded before and after in this ticket. Expect roughly 72k to fall under 35k.

Next: /mattpocock-skills:implement 05 ai-cost
