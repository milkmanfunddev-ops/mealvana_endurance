# Can the AI jobs move to cheaper models, and how do we prove it

Researched 2026-09-20. Companion to `docs/research/vana-cost-and-pricing.md` (2026-09-17), which covers caching, credits and the gateway catalogue. This document covers model substitution only: candidates, a bake-off design, architecture options, and what the harness lacks. Nothing was run, deployed or billed. Prices were fetched today by research agents through a summarising fetcher, so every price should be spot-checked against its source before a decision. Items I could not confirm on a primary page are marked UNVERIFIED.

## 1. Recommendation

Test in this order.

1. **Meal logging (describe-meal, analyze-meal-photo) first.** It is 22 percent of the typical athlete's $2.86, about $0.63 a month, all on Sonnet 4.6. It is a single call with a fixed schema, so a model swap is one env var. Candidates cost 50 to 90 percent less per call. The blocker is not the model. It is that the repo has no ground truth. The July benchmark (`benchmarks/ai-model-benchmark-2026-07/`) compared Haiku, Sonnet and Opus against each other on 11 photos and 20 descriptions with no known-correct macros, and the three models disagreed by 20 to 47 percent on kcal for most photos. The 07-30 revert to Sonnet was a judgement call on that data (commit `2dbd554c`, the comment in `supabase/functions/_shared/ai/model.ts`). Nobody knows whether Sonnet is more accurate than Haiku, only that it differs. Build 60 weighed meals with USDA-derived macros, then test. Expected saving: $0.40 to $0.57 per typical athlete per month (Haiku 4.5 at the low end, Gemini 3.1 Flash-Lite or GPT-5 mini at the high end).
2. **ai-coach insight second.** Small spend (inside the 3 percent remainder), but it shares the judge tooling that job 1 of chat needs, and it is the cheapest place to calibrate the voice judge. Saving: cents.
3. **Vana general turns third, as a router eval, not a wholesale swap.** 55 percent of general turns in dev called no tool. The `needVana` router in the pricing doc (lever 5) is the right shape. Expected saving about 6 percent of the total, roughly $0.10 to $0.17 a month. The point of doing it is less the saving than having a tested second provider, because **Haiku 4.5 is listed as retiring "not sooner than October 15, 2026"** on Anthropic's models page (as read by the research agent today; verify at https://platform.claude.com/docs/en/about-claude/models/overview). A forced migration of the chat model is coming whether or not cost drives it, and the chat eval has to exist before then.
4. **Vana planning turns fourth, and only against two candidates.** Planning is multi-turn tool use with 46 tools. On BFCL v4 (2026-04-12) exactly one cheaper model beats Haiku 4.5 on multi-turn: GLM-4.6 in thinking mode (68.0 percent against 53.6). Kimi K2 is close (50.6). Every mini and nano class proprietary model on the board is far below (GPT-5 mini 27.5, GPT-5 nano 34.5, Gemini 2.5 Flash-Lite low teens). The newer ones (Gemini 3.x Flash, GPT-5.4 mini, GLM 5.x, Qwen 3.8, DeepSeek V4) have no published score I could find, so only our own eval can tell. If GLM-4.6 or a successor holds the voice, the saving is about 45 percent of chat tokens: $0.50 to $0.95 a month depending on whether the caching fix (pricing doc, lever 1) has landed. Risk to voice is high. Fix caching first; it saves more with no quality risk.

Summary of expected saving for the typical athlete, per month, on today's $2.86:

| Step | Line it touches | Saving (estimate) | Confidence |
|---|---|---|---|
| Logging to a cheap vision model | $0.63 | $0.40 to $0.57 | Medium. Depends on the ground-truth eval |
| Insight to Haiku or Flash-Lite | about $0.04 | $0.02 to $0.03 | High on price, unknown on phrasing |
| Router on general turns | about $0.45 of chat | $0.10 to $0.17 | Medium |
| Planning on GLM-class open model | about $1.70 of chat and openers | $0.50 to $0.95 | Low |
| Background jobs and embeddings | about $0.05 | under $0.03 | Not worth testing |

Do not bother with:

- **Fine-tuning an open model on Vana transcripts.** Anthropic's Usage Policy prohibits "Utilization of inputs and outputs to train an AI model (e.g., 'model scraping' or 'model distillation') without prior authorization from Anthropic" (https://www.anthropic.com/legal/aup), and Commercial Terms D.4 bars using the service "to train competing AI models" (https://www.anthropic.com/legal/commercial-terms). Beyond that, neither Together nor Fireworks serves LoRA adapters serverless any more, so hosting is a dedicated GPU at $1,600 to $5,800 a month. At a $1.50 per athlete chat saving that needs 1,100 to 3,900 paying subscribers just to break even.
- **Planner and executor split.** Anthropic's own numbers say multi-agent uses about 15 times the tokens of chat. It buys quality, not cost. No primary source shows a cost saving.
- **Moving background extraction, day notes, ingredient extraction or embeddings.** Together they are a few cents per athlete per month on Haiku. Test them only as a side effect of the harness existing.
- **Sonnet 5 as a Sonnet 4.6 replacement for logging.** List price is a third lower but the newer tokenizer produces about 30 percent more tokens, so the real saving is about 13 percent. Not worth an eval by itself.
- **Groq and Cerebras for the chat agent.** They now serve two or three models each, GPT-OSS has reported tool-call format failures on both, and GPT-OSS has no BFCL entry. Latency is not Vana's problem.

## 2. Price per job

Token volumes are from the brief: planning turn 21,000 in and 170 out, general turn 8,800 in and 137 out, describe-meal 1,300 in and 220 out, photo 2,900 in (image included) and 292 out. Chat columns assume 60 percent of input is a cache read where the provider has a cached price; the dev data today shows 42.6 percent on planning rows that logged a read, so treat 60 percent as the post-fix case. Cache writes are ignored. Image token counts differ by provider, so the photo column is indicative only. Prices are dollars per million tokens.

| Model (gateway slug) | In | Cached in | Out | Planning turn | General turn | Describe | Photo |
|---|---|---|---|---|---|---|---|
| anthropic/claude-sonnet-4.6 (logging today) | 3.00 | 0.30 | 15.00 | $0.0315 | $0.0142 | $0.0072 | $0.0131 |
| anthropic/claude-sonnet-5, adjusted x1.3 for tokenizer | 2.60 | 0.26 | 13.00 | $0.0273 | $0.0123 | $0.0062 | $0.0113 |
| anthropic/claude-haiku-4.5 (chat today) | 1.00 | 0.10 | 5.00 | $0.0105 | $0.0047 | $0.0024 | $0.0044 |
| google/gemini-3.8-flash, until 2026-12-31 | 0.75 | 0.075 | 3.75 | $0.0079 | $0.0035 | $0.0018 | $0.0033 |
| google/gemini-3.8-flash, from 2027-01-01 | 1.50 | 0.15 | 7.50 | $0.0158 | $0.0071 | $0.0036 | $0.0065 |
| google/gemini-3.5-flash-lite | 0.30 | UNVERIFIED | 2.50 | $0.0067 | $0.0030 | $0.0009 | $0.0016 |
| google/gemini-3.1-flash-lite | 0.25 | 0.03 | 1.50 | $0.0027 | $0.0012 | $0.0007 | $0.0012 |
| openai/gpt-5.4-mini | 0.75 | 0.075 | 4.50 | $0.0080 | $0.0037 | $0.0020 | $0.0035 |
| openai/gpt-5-mini | 0.25 | 0.025 | 2.00 | $0.0028 | $0.0013 | $0.0008 | $0.0013 |
| openai/gpt-5.4-nano | 0.20 | 0.02 | 1.25 | $0.0021 | $0.0010 | $0.0005 | $0.0009 |
| openai/gpt-5.6-luna | 0.20 | 0.02 | 1.20 | $0.0021 | $0.0010 | $0.0005 | $0.0009 |
| mistral/mistral-small (Small 4) | 0.15 | 0.015 | 0.60 | $0.0016 | $0.0007 | $0.0003 | $0.0006 (vision UNVERIFIED) |
| zai/glm-4.6, DeepInfra | 0.50 | 0.10 | 2.00 | $0.0058 | $0.0026 | $0.0011 | no vision |
| zai/glm-5.3-flash, DeepInfra | 0.075 | 0.015 | 0.25 | $0.0009 | $0.0004 | $0.0002 | $0.0003 |
| moonshotai/kimi-k2.6, Novita | 0.80 | 0.16 | 3.40 | $0.0093 | $0.0041 | $0.0018 | $0.0033 |
| alibaba/qwen3.8-27b, Runinfra | 0.10 | 0.01 | 0.40 | $0.0010 | $0.0005 | $0.0002 | $0.0004 |
| alibaba/qwen3.7-flash | 0.03 | 0.006 | 0.13 | $0.0003 | $0.0002 | $0.0001 | $0.0001 |
| deepseek/deepseek-v4.1-flash | 0.15 | 0.003 | 0.60 | $0.0014 | $0.0006 | $0.0003 | $0.0006 |
| openai/gpt-oss-120b, Groq | 0.15 | 0.075 | 0.60 | $0.0023 | $0.0010 | $0.0003 | no vision |
| meta/llama-4-maverick, DeepInfra | 0.20 | none | 0.80 | $0.0043 | $0.0019 | $0.0004 | $0.0008 |

Reasoning models (GPT-5 family, GLM thinking mode, Gemini with thinking on) bill hidden reasoning tokens as output. The output counts above are Claude's. Expect 2 to 10 times the output tokens unless reasoning effort is set to minimal, which the bake-off must measure, not assume.

Context, vision and structured output, as far as verified: all Anthropic, Gemini and OpenAI rows support vision, JSON-schema structured output and tool calling, with context of 200K (Haiku 4.5), 400K (GPT-5 family) or 1M (Sonnet, Gemini Flash). Open-weight rows: context 131K to 1M as served, tool calling on all, vision where the table shows a photo price. Structured-output support through the gateway is UNVERIFIED for every open-weight host; the gateway's endpoint data listed only `tools`. Groq's strict JSON schema mode excludes streaming and tool use. Cerebras strict mode requires `additionalProperties: false` on all objects and Qwen 3.8 27B there forbids `pattern`, `minLength` and `maxLength`, which matters for our Zod schemas.

### Published tool-calling evidence

BFCL v4, function-calling mode, leaderboard dated 2026-04-12. I read these rows from `data_overall.csv` directly.

| Model | Rank | Overall | Multi-turn | Multi-turn long context |
|---|---|---|---|---|
| Claude Sonnet 4.5 | 2 | 73.2 | 61.4 | 59.0 |
| GLM-4.6 (thinking) | 4 | 72.4 | 68.0 | 66.5 |
| Claude Haiku 4.5 | 6 | 68.7 | 53.6 | 56.0 |
| Kimi K2 Instruct | 11 | 59.1 | 50.6 | 55.0 |
| GPT-5 mini | 17 | 55.5 | 27.5 | 33.0 |
| DeepSeek V3.2-Exp | 19 | 54.1 | 37.4 | 35.0 |
| GPT-5 nano | 24 | 51.5 | 34.5 | 38.0 |
| Qwen3-32B | 29 | 48.7 | 47.9 | 43.0 |
| Qwen3-235B-2507 | 31 | 48.0 | 45.4 | 55.5 |
| Llama 4 Maverick | 50 | 37.3 | 20.3 | 18.0 |
| Llama 4 Scout | 72 | 28.1 | 9.0 | 9.5 |

Not on the board: Sonnet 4.6, Sonnet 5, any Gemini 3.x, GPT-5.4 mini and nano, GPT-5.6 luna, Mistral Small 4, GLM 5.x, Qwen 3.5 to 3.8, DeepSeek V4, Kimi K2.6, GPT-OSS. tau2-bench small-model scores could not be read (the leaderboard renders in JavaScript). Vendor-card tau-bench numbers found: Kimi K2 tau2 retail 70.6, airline 56.5, telecom 65.8; GLM-4.5 TAU-bench retail 79.7, airline 60.4 (2025-08); GPT-OSS-120b TAU-bench retail 67.8 at high reasoning and 49.4 at low (2025-08); DeepSeek V3.2 tau2 80.3.

### Known weaknesses with 40 plus tools and long prompts

- OpenAI's guide: "Aim for fewer than 20 functions available at the start of a turn." Anthropic's tool search doc: "Claude's ability to pick the right tool degrades once you exceed 30 to 50 available tools." Vana's planning mode sends 46. General mode already sends a subset (`makeVanaTools`, `supabase/functions/_shared/vana/tools.ts` line 114).
- A May 2026 paper (arXiv 2605.24660) found a 7-tool shortlist covered 90.3 percent of BFCL cases against 90.8 for 50 tools.
- Same weights differ by host. Moonshot's K2 Vendor Verifier (2025-11) measured tool-call schema accuracy at 100 percent on DeepInfra, Fireworks, Novita and Groq and about 72 percent on Together and Baseten. The gateway picks the host unless the call pins it, and it reports `quantization: null`, so an eval result holds only for the host it ran on.
- GPT-OSS on Groq and Cerebras has open issues where tool-call JSON lands in `content`. Groq allows no parallel tool calls for it.
- DeepInfra serves Qwen3-32B and 235B at 41K context. A 21K planning turn fits, a long conversation may not.
- No source measured small models on a 15 to 20K system prompt. BFCL's long-context multi-turn column is the closest proxy, and the mini and nano models score 33 to 38 there against Haiku's 56.
- Privacy: a second provider receives health data. The pricing doc says to filter the catalogue on `zdr`. Do that before any candidate enters the list.

## 3. The bake-off

One rule for every job: the candidate is compared with the current model on the same cases, at least three repetitions per case, and the question is non-inferiority, not "is it good". The July run showed why repetitions matter: same model, same photo, kcal varied by up to 31 percent run to run.

### Job 2 and 3: describe-meal and analyze-meal-photo

Test set.

- 60 text cases and 40 photo cases. Below 60 the confidence intervals are too wide to separate models (Hamel Husain's judge guide makes the same point for labelled sets).
- Build: Lee and Xuan cook or buy 40 meals over two weeks, weigh every component on a kitchen scale, photograph with the app camera at the production 1000px downscale, and compute macros from USDA FoodData Central entries (public domain). Each photo meal also gets a short and a long description written before looking at the numbers, which yields the 60 text cases with 20 more from packaged items with a label (gels, bars, a Chipotle bowl from the published nutrition calculator). Reuse the 11 July photos only if someone can reconstruct weights; otherwise they stay a no-ground-truth smoke set.
- Skew toward what endurance athletes log: oatmeal and rice bowls, pasta, sandwiches, recovery shakes, on-bike fuel, takeout. Include 5 non-food or too-vague inputs to test the `confidence: low` path.
- Public sets as a supplement, not the main set: Nutrition5k (5,006 dishes, per-ingredient mass, licence permits commercial use, labels have known omissions, cafeteria food) for photos; NutriBench (11,857 described meals) for text, but it is CC BY-NC-SA, so check whether internal evaluation is acceptable before using it. UNVERIFIED legal point.

Metrics, per meal and summed per day of 3 to 4 meals.

- Carbohydrate is the macro that drives fuelling decisions, so it gets the tight band. Pass per meal: within 15 g or 20 percent of truth, whichever is larger. Report MAE in grams and the mean signed error. Signed error matters more than absolute error because per-meal noise cancels across a day and bias does not. A model that reads 15 percent low on carbs every meal tells a 400 g/day athlete they are 60 g short when they are not.
- kcal: within 20 percent. Protein: within 10 g. Fat: within 8 g. Sodium: within 40 percent (loose; it is a rough input everywhere).
- Catastrophic errors: share of cases more than 40 percent off on carbs or kcal.
- Item grouping: item count matches the labelled dish count (the July run caught Haiku splitting a burrito bowl into 7 items).
- Schema validity rate, latency p50 and p95, cost per call from the gateway's reported charge.
- Run-to-run coefficient of variation per case.

Context for setting expectations: published studies put frontier-model photo kcal error at 35 to 42 percent MAPE on real phone photos, and GPT-4o text carb MAE at 8.6 g on NutriBench. Supplying the true portion weight cut one model's carb error from 56.6 to 20.2 percent. A cheaper model plus a portion question may beat Sonnet alone.

Pass threshold for a swap: carb MAE no more than 10 percent worse than Sonnet 4.6, absolute mean signed carb error at or under 5 percent, catastrophic-error share no higher than Sonnet's, item-grouping failures no higher, schema validity 100 percent over 3 runs, p95 latency under 8 s.

### Job 1: Vana chat

Test set.

- The 14 scripted conversations in `scripts/vana-eval/conversations.json` (13 planning, 1 general) and the 18 cases in `personalization.ts` are the base. Add 16 general-mode conversations, because general turns are the routing candidate and have one script today. Source them from dev `vana_messages`, anonymised: replace names, places, race names and dates, keep the phrasing. Cover: a no-tool question, `dayGuidance`, log lookup, a write with confirmation (delete asks first), feedback, remember-a-fact, hand-off, weather, a medical question, a weight-loss push, a typo-heavy message, a two-request message.
- Total about 30 conversations, 110 athlete turns plus 30 openers. Three repetitions.

Metrics.

- Code checks first (they exist): no emoji, no narration before tools, sentence caps per register, fork has at most 4 label-only options, one exclamation mark and only on a milestone, picker followed by text, second turn reads the cache.
- Tool selection: for each scripted turn, the expected tool set (add an `expectTools` field; today the script checks UI parts only). Report exact-match rate and the rate of forbidden calls (`confirmPlan` without the word confirm, a delete without `needs_confirmation`, `suggestMeals` in an opener).
- Numbers never from the model: every gram or kcal figure in the text must appear in a tool result or the context block of that turn. This is a code check over the transcript, and it is the most important safety metric. Zero tolerance.
- Steps per turn and input tokens per turn (a weaker model that loops costs more than its price suggests).
- Voice, by LLM judge: binary pass or fail with a one-line critique, one rubric item per call, drawn from `persona.ts`: sounds like a dietitian who read the data, names a real athlete fact, no restating context, targets quoted as minimums, no weight or body talk, text after widgets. Judge with a model from a different family than the candidate. Calibrate first: Lee labels 100 turns pass or fail, and the judge must reach 90 percent true-positive and 90 percent true-negative against him before its numbers count. Judges miss defects more than they invent them (Eugene Yan reports 30 to 60 percent sensitivity), so report both rates. For tone, add a pairwise check: judge sees the Haiku reply and the candidate reply blind and picks the one that better fits the rubric, or a tie.
- Latency to first text and to done. Cost per turn from `vana_calls` plus the gateway charge.

Pass threshold: code-check pass rate within 2 points of Haiku, zero invented numbers, zero forbidden calls, tool exact-match within 3 points, judge voice pass rate within 5 points, pairwise loss rate under 35 percent, mean steps per turn not higher by more than 0.3, cost per turn at least 30 percent lower after counting reasoning tokens. For the router variant the extra metric is escalation: the cheap model must call `needVana` on every turn in the set that needs data (recall 100 percent on the scripted set), and the saving is computed on the turns it kept.

### Job 4: ai-coach insight

40 Formula Kit states replayed from dev `ai_usage` inputs or built by hand to cover the component combinations. Output is 15 to 28 words. Code checks: word count, no emoji, any number present is in the input. Judge: pairwise against Sonnet 4.6, blind, plus Xuan reads 40 pairs once as the human reference. Pass: candidate wins or ties at least 45 percent of pairs and has zero invented numbers.

### Job 5: background extraction, summaries, day notes, ingredients

30 anonymised transcripts with hand-written expected memories (the fixture in `supabase/functions/tests/vana/extract.test.ts` is the template: two durable facts, one plan detail that must not be saved). Metrics: recall of expected facts, false memories, plan-detail leakage, schema validity. Ingredient extraction: 30 recipes with a labelled ingredient list, exact-match F1. Pass: recall within 5 points of Haiku, false-memory rate no higher. Low priority.

### Job 6: embeddings

Not a cost target at $0.02 per million tokens. A swap changes vector dimensions and forces a re-embed of the meal library and memories. Skip. If ever needed: 50 queries with labelled relevant meals, recall at 5.

### Cost to run the whole bake-off once

| Job | Calls | Estimate |
|---|---|---|
| Describe-meal: 60 cases x 3 reps x 6 candidates, plus Sonnet baseline | 1,260 | $3 |
| Photo: 40 cases x 3 reps x 5 vision candidates, plus Sonnet baseline | 720 | $4 |
| Chat: 140 calls x 3 reps on Haiku at the measured $0.03 per planning turn, plus 4 candidates at about half | 2,100 | $35 |
| Chat voice judge: about 2,000 judged turns, 3 rubric calls each, on a mid-tier model | 6,000 | $15 |
| Insight: 40 x 3 x 5 plus pairwise judge | 1,200 | $2 |
| Background: 60 cases x 3 x 4 | 720 | $1 |
| Total | | about $60, under $100 with reruns |

The real cost is people: two weeks of weighing meals, about 3 hours of Lee labelling 100 turns for judge calibration, 1 hour of Xuan on insight pairs, and 2 to 4 days building the harness pieces in section 5. A re-test when prices change is then one command per job and about $15 for a single candidate.

### How the harness switches models

Each job already has its own variable: `VANA_CHAT_MODEL`, `VANA_TOOL_MODEL`, `VANA_EMBED_MODEL` (`_shared/vana/env.ts`), `DESCRIBE_MEAL_MODEL`, `ANALYZE_MEAL_PHOTO_MODEL`, `COACH_INSIGHT_MODEL`, `AI_COACH_MODEL` (`_shared/ai/model.ts`). Keep that: one variable per job, value is a gateway slug. Three changes make a re-test take minutes.

1. Single-call jobs run offline. Export the prompt builder and schema from `describe-meal`, `analyze-meal-photo`, `ai-coach`, `extract.ts`, `daynotes.ts` and `saved-ingredients.ts` as pure functions, and have one Deno script (`scripts/model-bakeoff/run.ts --job describe --models a,b,c --reps 3`) import them and call the gateway directly. No deployed function, no credits, no dev secrets touched. The July Python runner copied the prompts by hand because the env var is read at module load; importing the real prompt removes that drift.
2. Chat runs against a local function process. `supabase functions serve vana-chat --env-file <file with VANA_CHAT_MODEL=candidate>` pointed at the dev database, and `run.ts` gets a `--url` flag. That keeps the shared dev secret untouched, so other sessions and Lee's phone keep Haiku while an eval runs. The alternative, a request header honoured only for `users.is_internal` on the dev project, is quicker but puts an override path in production code.
3. Pin the host. For open-weight slugs pass `providerOptions.gateway.only` (or `order`) from a second variable such as `VANA_CHAT_PROVIDER`, because results do not transfer between hosts. Record model, host, reasoning-effort setting and the gateway's charge on every result row.

`CACHE_PROVIDER_OPTIONS` in `chat.ts` is Anthropic-specific. Other providers ignore it. OpenAI and Gemini cache implicitly (Gemini Flash needs at least 4,096 tokens). Open-weight caching depends on the host. The eval's `cached_second_turn` check should report, not fail, for non-Anthropic candidates until their cache fields are mapped in `cacheReadTokens`.

## 4. Architecture options that make cheap models viable

| Option | What it is | Saving on its line | Effort | Risk to voice and accuracy | Sources |
|---|---|---|---|---|---|
| Router with escalation tool | Cheap model gets persona, Doll, history and one tool, `needVana`. If it calls it, discard and rerun on Haiku with full tools. No classifier call, so mp-002 holds. AI SDK `prepareStep` can swap the model per step | 20 to 25 percent of general-turn cost at a 40 percent routed share; about 6 percent of total | M. Needs the general-turn eval first | Medium. Two voices in one conversation is the main risk; the pairwise judge measures it. A missed escalation gives a from-memory answer, which the persona forbids | Anthropic, Building effective agents (routing); RouteLLM: 85 percent cost cut on MT Bench at 95 percent of GPT-4 quality; FrugalGPT; https://ai-sdk.dev/docs/agents/loop-control |
| Per-mode tool subsets and tool search | Planning sends 46 tools. Split by phase (interview, picking, review, post-confirm) with `activeTools`, or use Anthropic tool search with `defer_loading`, which Haiku 4.5 supports and which keeps the cached prefix intact | Tool definitions are a large share of the 21K input; Anthropic reports 85 percent fewer tool-definition tokens. With caching fixed the dollar saving is small, maybe 5 to 10 percent of planning cost. The bigger gain is that it brings smaller models into range | S to M | Low to medium. A needed tool missing from the subset is a hard failure; the tool exact-match metric catches it. Tool search accuracy numbers exist only for Opus | https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool ; https://www.anthropic.com/engineering/advanced-tool-use ; OpenAI function-calling guide; arXiv 2505.03275, 2411.15399, 2605.24660 |
| Persona distilled to few-shot examples | Replace parts of the 30 KB `persona.ts` rule text with 3 to 5 example turns per register for the cheap model | Input tokens down perhaps 20 to 30 percent on the routed turns only. UNVERIFIED for this prompt | M. A second prompt set to maintain | Medium to high. Memory note applies: copied examples caused the opener sameness bug on 09-16. Examples leak their wording into output. If used, rotate nothing and template nothing; use examples only for format, not phrasing | Anthropic prompting best practices (3 to 5 diverse examples); LLMLingua claims 20x compression but was never tested on voice rules |
| Cheap first, verify, for macros | Run the cheap model 3 times; if carb estimates agree within 15 percent, accept the median, else escalate to Sonnet. Or: cheap model plus one portion-size question when confidence is not high | Cost per log about 3 cheap calls ($0.002 to $0.004) plus Sonnet on the disagreeing share. At 25 percent escalation, 55 to 65 percent saving on logging | S once the eval exists | Low. Agreement is not accuracy: three runs can agree on a wrong portion. The ground-truth set measures how often. Latency rises unless the three calls run in parallel | arXiv 2310.03094 (consistency-gated cascade, 40 percent of strong-model cost); arXiv 2203.11171; the portion-weight result at https://pmc.ncbi.nlm.nih.gov/articles/PMC13401436/ |
| Planner and executor split | Strong model plans once, cheap model executes steps | Negative or unproven. Planning turns are 2 to 3 steps, there is little to split | L | High | Anthropic multi-agent post: about 15x tokens; no primary source shows a saving |
| Fine-tune a small open model on transcripts | LoRA on Qwen or Llama 8B to 27B | Training is cheap ($0.38 to $3.00 per million tokens, a few hundred to a few thousand examples, $50 to $100 a run). Hosting is not: dedicated GPU only, $1,600 to $5,800 a month. Pays back past roughly 1,100 to 3,900 subscribers at a $1.50 saving each | L | High, and contractually blocked without Anthropic's written approval because the transcripts are Claude outputs | Anthropic AUP and Commercial Terms D.4; Together and Fireworks pricing and LoRA docs; Hamel Husain on when to fine-tune |

## 5. What the harness is missing

What exists.

- `scripts/vana-eval/run.ts`: 14 conversations, 8 global regex and structure checks on every turn plus about 30 named checks per scripted turn. Pass or fail per turn, exit code 1 on any failure. Totals input, output and cache-read tokens for the run. Hits the deployed dev `vana-chat`, writes real rows, can confirm a real plan. Model selection: none; it tests whatever `VANA_CHAT_MODEL` the dev project has.
- `scripts/vana-eval/personalization.ts`: 18 cases that read rows back through PostgREST instead of trusting the model. Records input and output tokens per case, which is what mp-018 requires ("Every eval case records its input and output tokens"). mp-018 asks for tokens, not dollars, and no script records dollars.
- `scripts/vana-eval/lifecycle.ts`: check-in and debrief loop, about 4 turns.
- `supabase/functions/tests/vana/`: 23 Deno test files with 26 UI-part fixtures and a fake DB. The model is injected and faked in all of them. They test writing, claiming and contracts, not model judgement. Useful as the source of expected shapes, not as eval cases.
- `benchmarks/ai-model-benchmark-2026-07/`: 11 photos, 20 descriptions, a Python runner that calls the gateway directly, results for Haiku 4.5, Sonnet 4.6 and Opus 5 with 3 repetitions. No ground truth. The describe-meal, photo and ai-coach `index.test.ts` files test handlers with stubbed models.
- `docs/ssot/vectors/` and `test/qa_conformance/`: daily-macros, fuelling, RMR, energy availability, session demand, pre-workout carbs, sodium and hydration. These are ground truth for the deterministic engine, that is for what an athlete should eat. They contain no foods and no meal macros, so they are not usable as ground truth for macro estimation. They do back one chat check: any target Vana quotes can be verified against the engine output for the eval user.

Missing, per job.

| Job | Missing for a fair comparison |
|---|---|
| 1 Vana chat | A way to pick the model per run without changing the shared dev secret. Repetitions. Expected-tool assertions. The invented-number check. An LLM judge and a human-labelled calibration set. General-mode coverage (1 script of 14). Per-turn latency, steps, output tokens and gateway cost in the transcript. A state reset between runs beyond the two settings (plans, memories and shown-meal history leak between runs; the dev account is vegetarian, which narrows pickers). Host pinning. Non-Anthropic cache-read mapping |
| 2 Describe-meal | Ground-truth macros. Importable prompt and schema so the runner cannot drift from production. Scoring script with error bands and signed error. More than 20 cases |
| 3 Photo | Ground-truth macros with weighed portions. More than 11 photos. Same importable prompt. Per-provider image token accounting |
| 4 ai-coach insight | Everything: no cases, no rubric, no runner |
| 5 Background jobs | Labelled transcripts and recipes. The injected `generate` seam in `extract.ts` makes a runner easy to add |
| 6 Embeddings | Labelled query set. Not worth building |
| All | One results format (JSONL: job, case, rep, model, host, reasoning setting, latency, tokens, gateway cost, scores) and one report script, so a price change is a re-run and a diff |

## 6. Sources

Repo: `supabase/functions/_shared/ai/model.ts`; `supabase/functions/_shared/vana/{env,chat,tools,persona,extract,daynotes,saved-ingredients,pantry}.ts`; `scripts/vana-eval/`; `supabase/functions/tests/vana/`; `benchmarks/ai-model-benchmark-2026-07/`; commit `2dbd554c` (2026-07-30, the revert, bundled into an unrelated test commit) and `25c83a1e` (2026-07-23, the move to Haiku); `docs/ssot/decisions/mealplanning.md` mp-018; `docs/research/vana-cost-and-pricing.md`.

Pricing and model docs, fetched 2026-09-20:
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/about-claude/models/overview
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://ai.google.dev/gemini-api/docs/pricing
- https://ai.google.dev/gemini-api/docs/caching
- https://developers.openai.com/api/docs/pricing
- https://developers.openai.com/api/docs/guides/function-calling
- https://mistral.ai/pricing/api
- https://ai-gateway.vercel.sh/v1/models and https://vercel.com/ai-gateway/models
- https://console.groq.com/docs/models , /prompt-caching , /tool-use , /structured-outputs
- https://inference-docs.cerebras.ai/capabilities/tool-use
- https://www.together.ai/pricing , https://docs.together.ai/docs/lora-inference , https://docs.together.ai/docs/fine-tuning-pricing
- https://fireworks.ai/pricing , https://docs.fireworks.ai/fine-tuning/deploying-loras
- https://deepinfra.com/pricing

Tool-calling evidence:
- https://gorilla.cs.berkeley.edu/leaderboard.html and https://gorilla.cs.berkeley.edu/data_overall.csv (v4, 2026-04-12)
- https://github.com/MoonshotAI/K2-Vendor-Verifier , https://github.com/MoonshotAI/Kimi-K2
- https://arxiv.org/html/2508.10925 (GPT-OSS card), https://arxiv.org/html/2508.06471 (GLM-4.5), https://arxiv.org/html/2512.02556 (DeepSeek V3.2)
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
- https://www.anthropic.com/engineering/advanced-tool-use
- https://arxiv.org/abs/2605.24660 , https://arxiv.org/abs/2505.03275 , https://arxiv.org/abs/2411.15399

Architecture and evaluation:
- https://www.anthropic.com/engineering/building-effective-agents
- https://www.anthropic.com/engineering/multi-agent-research-system
- https://lmsys.org/blog/2024-07-01-routellm/ , https://arxiv.org/abs/2305.05176
- https://ai-sdk.dev/docs/agents/loop-control
- https://arxiv.org/abs/2310.03094 , https://arxiv.org/abs/2203.11171 , https://arxiv.org/abs/2310.05736
- https://www.anthropic.com/legal/aup , https://www.anthropic.com/legal/commercial-terms
- https://hamel.dev/blog/posts/llm-judge/ , https://hamel.dev/blog/posts/fine_tuning_valuable.html
- https://eugeneyan.com/writing/llm-evaluators/
- https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
- https://arxiv.org/abs/2405.00732 (LoRA Land)

Macro estimation accuracy and datasets:
- https://arxiv.org/html/2407.12843v3 and https://github.com/DongXzz/NutriBench (CC BY-NC-SA)
- https://github.com/google-research-datasets/Nutrition5k (CC BY 4.0)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC13483877/ (ten-model photo benchmark; best Gemini 3.0 Flash, MAE 80.7 kcal)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC13401436/ (GPT-4.1 kcal MAPE 42.2 percent on iPhone meals)

UNVERIFIED items to check before acting: the Haiku 4.5 retirement date; Gemini cached-input prices for the Flash-Lite models and the implicit-cache discount; every open-weight host's JSON-schema support through the gateway; Mistral Small 4 vision; tool-count limits on Groq and Cerebras; whether NutriBench's licence allows internal evaluation; all tool-calling quality for models released after April 2026.
