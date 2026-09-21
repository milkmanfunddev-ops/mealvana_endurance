# 14: Three background jobs on the cheapest model, and the unused coach insight removed

**Status:** done (wave 2, 2026-09-21)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/extract.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Nothing changes for the athlete. The memory extraction, the rolling summary and the saved-meal ingredient list run on the cheapest gateway model that gives the same structured answer. The Formula Kit coach insight, which nothing calls, is removed. Chat stays on Haiku and meal logging on Sonnet.

**Decisions:** mp-465; approved as mp-479.

**Touches:** supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/saved-ingredients.ts, supabase/functions/_shared/vana/env.ts, supabase/functions/ai-coach, supabase/functions/_shared/ai_coach, supabase/functions/_shared/ai/model.ts, lib/features/formula_kit/data/ai_coach_client.dart

- [x] The three jobs read their model from one new setting, apart from the chat model.
- [x] On 20 stored dev conversations the candidate's answers are compared by hand with Haiku's; the comparison and the model chosen are recorded in this ticket. If none matches, the setting stays on Haiku. **No candidate matched; the setting stays on Haiku 4.5.**
- [x] The existing extract and saved-ingredients tests stay green.
- [x] The coach insight route, its dead shared tools and the app's unused client are removed — `ai-coach` was undeployed from dev by the wave lead on 2026-09-21 (the route answers 404).
- [ ] No helper model is called from inside a Vana turn. **NOT met, and not made worse: `addMeal` already awaits the saved-meal ingredient job inside a turn. See Comments.**

Next: /implement-lee ai-cost

## Comments

### The setting

`VANA_BACKGROUND_MODEL`, in `supabase/functions/_shared/vana/env.ts`, read at call time and
defaulting to `anthropic/claude-haiku-4.5`. The memory extraction and the rolling summary
(`extract.ts`) and the saved-meal ingredient list (`saved-ingredients.ts`) read it. `VANA_TOOL_MODEL`
keeps the day notes (clause 5) and the pantry photo; `VANA_CHAT_MODEL` keeps the conversation
(clause 1). Nothing to set on dev: absent, the three stay exactly where they were.

### The model test

`scripts/vana-eval/background-model.ts` sends each candidate the real system prompt, the real prompt
builder and the real Zod schema the edge function sends, at the same `maxOutputTokens`, so a pass is
a pass for the shipped path. Corpus, read read-only from DEV (`vlmtsdzpnjnavdgytcmi`) on 2026-09-21:

- **extract** and **summary**: the 20 longest non-deleted `vana_conversations` (46 down to 11
  messages), with that user's 10 non-episode memories as the EXISTING block. The summary case is the
  opening half of each, the way `writeSummary` chunks an open conversation.
- **ingredients**: dev has only 3 `saved_meals` rows, so the 20 cases are 20 distinct cooked-dish
  `meal_logs`, shaped as the dish-level `saved_meals` row a Describe/photo log becomes. That is
  exactly the input the job sees.

Prices are $/M tokens from the gateway's own catalogue (`https://ai-gateway.vercel.sh/v1/models`,
read 2026-09-21), not from memory. The gateway lists 377 language models; these are the cheapest
that both answer a schema and are general-purpose. Disqualified before the 20 ran, on one probe
case each: `inclusionai/ling-3.0-flash` ($0.021/$0.063) returns Bad Request; `openai/gpt-5-nano`
($0.05/$0.40) and `openai/gpt-oss-20b` ($0.03/$0.14) return "no object generated" — both spend the
400-token budget on reasoning and never emit the object. The genuinely free entries
(`inclusionai/ling-3.0-flash-*`, `poolside/laguna-s-2.1-free`) are domain-specific or free tiers,
not production models.

| model | in/out $/M | schema ok | extract same | summary same | ingredients same | cost, 60 cases |
|---|---|---|---|---|---|---|
| `anthropic/claude-haiku-4.5` (baseline) | 1.00 / 5.00 | 60/60 | — | — | — | $0.1017 |
| `alibaba/qwen3.7-flash` | 0.03 / 0.13 | 12/12 (subset) | 1/6 | 2/2 | 2/4 exact, 2/4 short | $0.0052 (12 cases) |
| `amazon/nova-micro` | 0.035 / 0.140 | 60/60 | 0/20 | 20/20 | 5/20 | $0.0036 |
| `amazon/nova-lite` | 0.06 / 0.24 | 60/60 | 0/20 | 20/20 | 3/20 | $0.0065 |
| `google/gemini-2.5-flash-lite` | 0.10 / 0.40 | 57/60 | 6/17 | 20/20 | 9/20 | $0.0070 |

**What differed.** The memory extraction is where every candidate fails, and it fails the one rule
the prompt is written around. Haiku writes **zero** memories on all 20 conversations — the correct
answer: the margin-note rule says "zero memories is the normal outcome", and every durable fact
these conversations contain is already in the EXISTING block the prompt says never to repeat. The
candidates invent instead: nova-micro 32 memories across the 20 (6 of them restating an EXISTING
fact), nova-lite 26 (13 restating one), gemini-flash-lite 14 (3 restating one), qwen 7 on 6
conversations. The embedding dedupe in `rememberFact` would swallow the near-restatements, but the
rest — "Sister is named Chantelle.", "Prefers to be addressed as sir.", "Trains most evenings." —
land as real rows. That is the athlete's file filling with noise the rule exists to keep out, and it
is invisible: extracted Memories produce no card and no mention.

Gemini also broke the schema outright on 3 of 20 extract cases ("response did not match schema"), on
a job with no retry.

The **rolling summary** is the one job every candidate does match: all 20 land inside the 150-word
instruction (Haiku's median 105 words, nova-micro's 65, gemini's 86) and carry the same specifics.

The **ingredient list** diverges on substance, not shape. Everyone returns a well-formed 2-12 line
list, but the lines are different food: for "Burrito with meat and sauce" Haiku writes ground beef,
flour tortilla, cooked rice, black beans, cheddar, salsa, sour cream, onion, bell pepper, olive oil;
gemini writes ground turkey, whole-wheat tortilla, black beans, avocado, shredded lettuce, salsa.
Both are plausible burritos. Neither is the same shopping list, and this list is what Kroger matches
against, so "plausible" is not the bar. nova-lite is the worst: 12 lines where Haiku writes 3,
adding chia seeds and flax to a bagel with peanut butter and banana.

qwen3.7-flash is the most interesting near-miss — its ingredient lists match or are clean subsets of
Haiku's, and its invented memories at least do not restate the EXISTING list. It is disqualified on
cost-shape and latency rather than on price: it is a reasoning model that spends ~2,980 output
tokens per call (Haiku spends ~105) and took **396s for 12 calls, 33s each**, with some calls past a
60s budget. These three jobs run in the background of an edge-function request with no retry.

**Chosen: no candidate. `VANA_BACKGROUND_MODEL` stays on `anthropic/claude-haiku-4.5`** — the
criterion's own fallback. The setting is still worth having: it is the seam that makes the next
candidate a secret change rather than a code change, and the model test is committed and reruns in
minutes.

Total gateway spend on this comparison, on the evals key: about $0.25 (the baseline pass was paid
twice — a first run stalled on a qwen call before the per-call timeout existed).

### Criterion 5, honestly

Two of the three hold. The idle extraction (`background(writeOnIdle(...))`) and the rolling summary
(`deps.background(writeSummary(...))`) are scheduled and the turn returns without them;
`compaction.test.ts` and `personal_openers.test.ts` drive both through the real code.

The third does not, and it did not before this ticket either: `plan.ts` **awaits**
`ensureSavedMealIngredients` in `addMeal` and its sibling, so adding a dish-level saved meal to a
plan calls the model inside the turn. It is awaited on purpose — the shopping list `addMeal` returns
in the same turn is built from those ingredients (playtest 2026-09-16 §5), and
`saved_ingredients.test.ts` asserts that. mp-465 clause 6 says "for now" and was read as no work, so
this was left alone rather than changed behind Lee's back. It is now pinned by a test in
`background_model.test.ts` so it cannot drift silently. **Open for Lee: leave it in the turn, or
move it to the background and accept that the first shopping list after an add shows the dish line
until a rebuild?**

### The coach insight removal

Proof nothing called it, before deleting: `AiCoachClient` had no production importer in `lib/`
(only its own test); no other edge function imported `_shared/coach_insight/` or
`_shared/ai_coach/tools.ts`; `ai-coach` has no `supabase/config.toml` entry, no mention in
`scripts/`, `codemagic.yaml` or `.github/`. Removed: the route and its tests,
`_shared/coach_insight/`, `_shared/ai_coach/{tools,in_season}.ts`, `COACH_INSIGHT_MODEL`, the stale
`'ai-coach'` row in the credit cost map (`creditCost` returns 1 either way), the Dart client, its
generated part and its test.

Kept on purpose: `_shared/ai_coach/persona.ts` (Jade's prompt; `jade-chat/index.test.ts` still reads
it), `AI_COACH_MODEL` (now importerless but Jade-named, so deleting it is a separate call — noted in
`model.ts`), the `CoachInsight` domain types and the `personal_formulas.coach_insight_*` columns, and
every other AI surface: Describe, Photo capture, Jade, Vana.

## Wave 2 close (2026-09-21)

- `ai-coach` is undeployed from dev. Paywall ticket 02 had gated it in the same hour; the merge kept the removal and dropped `ai-coach` from the paywall gate test and the function audit.
- `VANA_BACKGROUND_MODEL` is left unset on dev, so the three jobs stay on Haiku 4.5, the comparison's verdict.
