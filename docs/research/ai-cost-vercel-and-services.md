# AI and backend running cost: what Vercel and other services offer

Researched 2026-09-20. Read `docs/research/vana-cost-and-pricing.md` first. This document does not repeat its findings (explicit cache breakpoints, byte-stable replay, routing of no-tool turns, batch, on-device models). It covers what that document left out.

Baseline from that document: a typical athlete costs $2.86 a month in AI. Per month that is planning turns $0.83, general turns $0.93, openers $0.36, describe-meal $0.40, meal photo $0.23, coach insight $0.05, background calls $0.07. "Lever 1" below means that document's explicit cache breakpoints, which the code does not have yet: `chat.ts` still sends only `providerOptions.anthropic.cacheControl`.

Sources: I fetched the Vercel AI Gateway docs, the live gateway catalogue, the npm registry, the AI SDK docs and the Anthropic docs myself today. Three research subagents gathered the Supabase pricing, the observability and SaaS pricing, and the benchmark, caching and food database facts from the pages linked. WebFetch summarises most pages through a small model, so a quoted number is what that summary returned. Anything not confirmed on a first-party page is marked unverified.

## Ranked options

Saving is per typical athlete per month against $2.86, unless the row says guardrail.

| # | Option | Saving or guardrail | Effort | Risk | Verdict |
|---|---|---|---|---|---|
| 1 | Try gateway `caching: 'auto'` on chat before building lever 1 | Unmeasured. Could deliver most of lever 1's step-1 saving (lever 1 total is about $1.10) | S | Low | Do first, one line plus a log check |
| 2 | Make the meal prompts cacheable: instructions first, athlete text last, 1 hour breakpoint | About $0.20 to $0.25 (7 to 9%) once traffic passes a few meal logs an hour | S | Low | Do |
| 3 | 1 hour cache TTL on Vana's shared static prefix, after lever 1 | About $0.15 to $0.25 at low traffic, near zero at high traffic | S | Low | Do with lever 1, decide from logs |
| 4 | Gateway budgets and alerts per API key, one key per environment | Guardrail. Caps a runaway script or leaked key at a dollar figure | S | A hit budget returns 402 to athletes | Do |
| 5 | Token ceiling in `stopWhen`, daily opener cap | Guardrail. Bounds the worst turn and the uncapped opener | S | Low | Do (the opener cap is already recommended and still missing) |
| 6 | Meal logging on a cheaper vision model, after an eval | $0.35 to $0.55 (12 to 19%) | M | Macro accuracy | Do the eval. Candidates and prices updated below |
| 7 | Cloud startup credits spent through BYOK on Bedrock or Vertex | Up to the whole AI bill for the credit period | S to M | Unverified eligibility. BYOK spend escapes gateway budgets | One hour of Lee's time to check |
| 8 | Exact-match cache for describe-meal in Postgres | $0.05 to $0.12 | S to M | Low if exact match only | Optional |
| 9 | Anthropic tool search with deferred tools | Under 10% of chat after lever 1, about 35% of a planning turn before it | M | Tool selection changes, extra search step | Test only after lever 1 |
| 10 | Stop sending gateway `user` and `tags` if Custom Reporting is on | About $0.03 (1%), 11% of each coach insight | S | None | Check the team setting |
| 11 | Pin the AI SDK to an exact version | Guardrail. `npm:ai@6` floats to the newest 6.x at each deploy | S | None | Do |
| 12 | Sentry AI spans on the edge functions | $0 to run inside 5M free spans. Finds savings only if `vana_calls` stays thin | M | Deno support inside Supabase unverified | Later, after the `vana_calls` columns |
| 13 | Supabase: long `cacheControl` on `meal-images`, no on-the-fly transforms of user uploads, stay on Micro | Cents today. Avoids an unbounded line later | S | None | Do when touching Storage |

## 1. Gateway `caching: 'auto'` as a first experiment

What it is. A gateway option, `providerOptions.gateway.caching: 'auto'`. For Anthropic it places two cache markers, not one: "On the last message" and "On the message before the last user message (falling back to the system message)" ([Vercel automatic caching](https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching), updated 2026-09-11). The code today uses Anthropic's own top-level automatic mode, which places one marker on the last block.

Why it matters here. The earlier document found that step 1 of almost every real turn reads nothing, because the only cache entries sit at the end of a message list that the next turn rebuilds differently. On an opener there is no message before the last user message, so the gateway's second marker falls on the system message. That writes an entry covering tools, persona and Doll. Anthropic checks earlier block boundaries for hits, so the athlete's next turn should read that entry even though its messages differ. That is my reading of the two documents, not a measured result.

Fit. Works from Deno. The Vercel examples use AI SDK 7. The AI SDK gateway provider page I fetched did not list `caching` among the options, so confirm that `ai@6` passes it through. Unverified: whether it can be combined with the existing `anthropic.cacheControl` option or must replace it.

Saving. Unmeasured. It cannot share the prefix across athletes, because the Doll is inside the system string, so lever 1's persona and Doll split is still the better end state.

Test first. Deploy to dev, run one opener and one follow-up turn, and compare `cacheReadTokens` on step 1 of the follow-up against today's zero.

The same page documents `cache_ttl: '1h'` and `cache_anchor_items`, but only on the Responses API. From the AI SDK the 1 hour lifetime comes from `cacheControl: { type: 'ephemeral', ttl: '1h' }` on a message, system part or tool ([AI SDK Anthropic provider](https://ai-sdk.dev/providers/ai-sdk-providers/anthropic)).

## 2. Cacheable meal prompts

What it is. `describe-meal` sends one user message that starts with the athlete's description and then about 1,200 tokens of instructions. `analyze-meal-photo` has the same shape with about 1,900 tokens of text. Because the variable text comes first, no prefix ever repeats, and neither call uses prompt caching. The instructions are identical for every athlete.

Change. Move the instructions to a system message with `cacheControl: { type: 'ephemeral', ttl: '1h' }`, and put the description and the image in the user message after it. The `generateObject` schema renders before the system prompt, so the marker covers it too.

Fit. Sonnet 4.6 and Sonnet 5 cache from 1,024 tokens, Haiku 4.5 only from 4,096 ([Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)). The describe prefix is near the 1,024 floor, so measure it. If the meal calls move to Haiku, this option stops working. On Gemini and OpenAI models the same layout gets implicit caching with no marker.

Saving. A read costs $0.30 per million against $3.00. Describe saves about 1,200 x $2.70 / 1M = $0.0032 of $0.0077 (42%). Photo saves about $0.005 of $0.013 (39%). At 52 describes and 17 photos a month that is $0.17 + $0.09 = $0.26. A 1 hour write costs 2x input, so a miss costs $0.0036 more than today. The prefix is shared by all athletes, so the hit rate depends on total traffic. 100 typical athletes make about 14 meal logs an hour while awake, which keeps a 1 hour entry warm. Below roughly 2 logs an hour this loses money.

This overlaps with section 6. If the meal calls move to a model at a tenth of the price, the same layout still helps but the saving shrinks to about $0.03 a month. Do this one now because it needs no eval, and keep the layout when the model changes.

Risk. Anthropic advises putting images before text. Here the image would follow the instructions. Check the 50-meal eval set from the earlier document's lever 3 before and after.

## 3. 1 hour TTL on Vana's shared prefix

Only meaningful after lever 1 splits persona from Doll. The 13,500 static tokens cost $0.0169 to write at the 5 minute rate, $0.027 at the 1 hour rate, and $0.00135 to read. With 100 active athletes and about 10 conversation starts an hour, a 5 minute entry is warm for a little over half of the starts and a 1 hour entry for nearly all of them. That saves about $0.0067 per conversation start, around $0.23 a month per athlete at 35 starts, less the 16 or so dearer writes a day shared across everyone. The gain disappears once traffic keeps a 5 minute entry warm. Anthropic requires longer-lived entries to come before shorter ones, so the 1 hour marker goes on the persona and the 5 minute automatic marker stays on the tail. Decide from the cache-write column the earlier document asks for.

## 4. Budgets and spend limits

What exists ([Vercel budgets](https://vercel.com/docs/ai-gateway/observability-and-spend/budgets), updated 2026-09-10). Budgets at four scopes: team, project, API key, and team member. Refresh daily, weekly, monthly or never. Email alerts at 50, 75 and 100 percent. An exhausted budget returns HTTP 402 with type `quota_for_entity_exceeded`. "A budget is a soft cap": the request that crosses the line completes. Changes take up to about 5 minutes. No charge for budgets appears on the pricing page.

What does not exist. A per-athlete budget. "User" means a Vercel team member, and the project scope needs Vercel OIDC, which Supabase functions do not have. The `user` field on a request is a reporting label and caps nothing. The per-athlete ceiling stays in our own wallet and `rate-limit.ts`.

Recommendation. One gateway key each for prod functions, dev functions and `scripts/vana-eval`, each with a monthly budget and alerts. Prod at about 3x expected spend, dev and eval at a few dollars. A leaked or looping key then stops at a known figure. The chat function must map a 402 from the gateway to the same athlete-facing message as an empty wallet, or the athlete sees a raw error. The docs warn that the AI SDK can surface it as `GatewayInternalServerError`.

Paid-tier gateway requests have no gateway rate limit, and there is no per-end-user rate limiting feature ([rate limits](https://vercel.com/docs/ai-gateway/rate-limits)).

## 5. Loop guardrails in the AI SDK

`stopWhen` takes custom conditions that receive each step's usage ([AI SDK loop control](https://ai-sdk.dev/docs/agents/loop-control)). Add a condition that stops when cumulative input tokens pass a ceiling such as 120,000, next to the existing `stepCountIs`. A planning turn averages 40,786. This bounds the p99 turn. It saves nothing on the mean.

The daily opener cap from the earlier document is still absent: `rate-limit.ts` has `'vana.opener': { seconds: 60, max: 3 }` and no daily window.

## 6. Cheaper models for meal logging, prices as of today

Catalogue read 2026-09-20, 376 models ([gateway catalogue](https://ai-gateway.vercel.sh/v1/models)). It has changed since 09-17: new Gemini Flash versions cost more, not less.

| Model | Input $/M | Output $/M | Cache read $/M | Context | Vision | ZDR endpoint | Describe call | Photo call |
|---|---|---|---|---|---|---|---|---|
| anthropic/claude-sonnet-4.6 (today) | 3.00 | 15.00 | 0.30 | 1M | yes | all | $0.0077 | $0.0130 |
| anthropic/claude-sonnet-5 | 2.00 | 10.00 | 0.20 | 1M | yes | all | about $0.0067 (30% more tokens) | about $0.0113 |
| anthropic/claude-haiku-4.5 | 1.00 | 5.00 | 0.10 | 200K | yes | all | $0.0026 | $0.0043 |
| google/gemini-3.8-flash, 3.7, 3.6 | 0.75 | 3.75 | 0.075 | 1M | yes | Vertex | $0.0019 | $0.0032 |
| google/gemini-3-flash | 0.50 | 3.00 | 0.05 | 1M | yes | Vertex | $0.0014 | $0.0023 |
| google/gemini-3.5-flash-lite | 0.30 | 2.50 | 0.03 | 1M | yes | some | $0.0010 | $0.0016 |
| google/gemini-3.1-flash-lite | 0.25 | 1.50 | 0.03 | 1M | yes | Vertex | $0.0007 | $0.0012 |
| openai/gpt-5.4-mini | 0.75 | 4.50 | 0.075 | 400K | yes | some | $0.0021 | $0.0035 |
| openai/gpt-5.4-nano | 0.20 | 1.25 | 0.02 | 400K | yes | Azure | $0.0006 | $0.0009 |
| openai/gpt-5.6-luna | 0.20 | 1.20 | 0.02 | 1.05M | yes | Azure | $0.0006 | $0.0009 |
| alibaba/qwen3.8-flash | 0.15 | 0.47 | 0.016 | 991K | yes | all | $0.0003 | $0.0006 |
| deepseek/deepseek-v4.1-flash | 0.30 | 1.20 | 0.03 | 1M | yes | some | $0.0007 | $0.0012 |

Call costs use the measured 1,291 in and 254 out for describe, 2,866 in and 292 out for photo. Image token counts differ by vendor, so the photo column is rough. All of the cheap models are reasoning models. Hidden reasoning tokens bill as output, so set the effort to `none` or `minimal` and measure real output tokens before trusting the column. For health data, pin the ZDR endpoint with `only` (for example `['vertex']` or `['azure']`). Per-request ZDR costs nothing extra on Vercel Pro and Enterprise; the team-wide switch costs $0.10 per 1,000 requests ([gateway pricing](https://vercel.com/docs/ai-gateway/pricing)).

Moving both meal calls to Gemini 3 Flash would cut the $0.63 meal line to about $0.11, a saving of $0.52. Haiku 4.5 cuts it to $0.21. Haiku was tried and reverted on 07-30 for quality, so nothing moves without the labelled eval. The tool-calling benchmark section below covers chat, not this job. See the food database section for a lookup before the model.

Service tiers. `serviceTier: 'flex'` gives Gemini and OpenAI models about half price with slower, best-effort service ([service tiers](https://vercel.com/docs/ai-gateway/models-and-providers/service-tiers), [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing)). Anthropic has no flex tier. An athlete waits on a meal log, so flex fits only background jobs, and those cost $0.07 a month. Not worth it.

## 7. BYOK and cloud credits

Facts ([Vercel BYOK](https://vercel.com/docs/ai-gateway/authentication-and-byok/byok), [pricing](https://vercel.com/docs/ai-gateway/pricing)). The gateway charges "no markup and no platform fee on tokens" with its own credentials, and "With BYOK, there is no markup or fee". So our own Anthropic key changes no price and unlocks no feature. It needs a paid-tier credit balance, failed BYOK requests fall back to system credentials and bill credits, and "Spend through your own credentials isn't counted in budgets." With request-level ZDR on, the gateway skips BYOK keys unless the key is marked ZDR-compliant.

The one reason to use it: the BYOK page says it is "useful for using credits provided by the AI provider". BYOK supports Anthropic, Bedrock and Vertex credentials. If Mealvana can get AWS Activate, Google for Startups or Anthropic startup credits, BYOK spends them without code changes beyond the credential and an `only` filter. Unverified: whether those programmes cover Claude on Bedrock or Vertex today, and whether Mealvana qualifies. Prompt caching works on all three Anthropic routes per the automatic caching page. Test first: a cached two-turn conversation through the BYOK route, checking cache reads and the fallback behaviour when the key is wrong.

## 8. Exact-match cache for describe-meal

The describe prompt contains nothing about the athlete, so the same normalised text always deserves the same answer. A table keyed on a hash of the lowercased, whitespace-collapsed description, plus model id and prompt version, returns the stored `MealAnalysis` with no model call. The AI SDK's language model middleware does the same job in code (`wrapLanguageModel`, see the caching section), but a plain lookup before `generateObject` is simpler in an edge function.

Saving depends on how often athletes retype a meal word for word. Unknown. At 15 to 30 percent repeats it is $0.06 to $0.12 a month. Query `ai_usage` or the meal log for duplicate descriptions before building it. Do not make it semantic: "2 eggs and toast" and "3 eggs and toast" embed almost identically and need different macros.

## 9. Anthropic tool search and deferred tools

What it is. Mark rarely used tools `defer_loading: true` and add Anthropic's tool search tool. Deferred definitions stay out of the context until the model searches for them. "The prefix is untouched, so prompt caching is preserved" ([Anthropic tool search](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool)). Haiku 4.5 is on Anthropic's supported list. The AI SDK exposes it as `toolSearchBm25_20251119` and `providerOptions.anthropic.deferLoading`; the summary of that page said "Sonnet 4.5+", which conflicts with Anthropic's table, so check. Anthropic also says tool selection "degrades once you exceed 30-50 available tools". Planning sends 43.

Saving. Tools are about 8,000 of the 15,500 tokens in a planning step. Deferring 35 of 43 removes about 6,500 tokens a step. Before lever 1 that is about $0.012 of a $0.032 planning turn. After lever 1 those tokens are cache reads at $0.10 per million, so the saving falls to about $0.0017 a turn, and each search adds a model round trip. Unverified: that Anthropic provider-defined tools pass through the gateway from `ai@6`.

Verdict. Lever 1 first. Then run `scripts/vana-eval` with and without deferral and compare tool choice, step count and cost. Do not vary the tool list with `activeTools` instead: a changed tool list invalidates the Anthropic cache, as the earlier document says.

## 10. Reporting tags that may be billing

`describe-meal`, `analyze-meal-photo` and `ai-coach` send `providerOptions.gateway.user` and three or two tags. If Custom Reporting is enabled for the team, each unique tag or user id on a request is a write at "$0.075 / 1,000" ([custom reporting](https://vercel.com/docs/ai-gateway/observability-and-spend/custom-reporting)). That is $0.0003 per meal log and $0.000225 per coach insight, 11 percent on top of a $0.0021 call. The reporting endpoint needs Vercel Pro and costs $5 per 1,000 queries. `ai_usage` and `vana_calls` already hold the same per-athlete data. Check the team's AI Gateway settings. If the feature is on and nobody queries it, turn it off or drop the fields. Unverified: whether writes bill when the fields are sent with the feature off. The pricing page says capabilities are "off by default".

Extending tags to Vana chat would cost about $0.11 per athlete a month at roughly 470 gateway requests. Not worth it.

## 11. AI SDK version and unused features

Versions. Every function imports `npm:ai@6` and `npm:zod@3` with no lockfile entry I could find, so each deploy resolves the newest 6.x (6.0.286 today). `latest` on npm is 7.0.107. Pin an exact version so a deploy cannot change SDK behaviour.

AI SDK 7 ([migration guide](https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0)). Renames (`system` to `instructions`, `onFinish` to `onEnd`, `fullStream` to `stream`), ESM only, Node 22, telemetry moved to `@ai-sdk/otel`, and multi-step results that accumulate across steps. Nothing in it lowers token use. It would touch every call site and the NDJSON stream. Do not upgrade for cost.

| Feature | Use here | Verdict |
|---|---|---|
| `prepareStep` with `activeTools` | Fewer tools per step | No. Changes the tool block and breaks the cache |
| `prepareStep` switching model per step | Cheap model for the final reply | No. Caches are per model, and the voice is tuned on Haiku |
| `prepareStep` or `pruneMessages` trimming history | Smaller later steps | No. Conversations run 2 to 3 turns and trimming breaks the prefix |
| Custom `stopWhen` on usage | Token ceiling | Yes, section 5 |
| `experimental_repairToolCall` | Fix a malformed tool call without a wasted step | Only if logs show invalid tool calls. Count `tool-error` parts first |
| Tool input streaming | Latency only | No cost effect |
| `generateObject` | Already used for extract, day notes, meal calls | Nothing to gain |
| `embedMany` | Already used in `tools.ts` | Embeddings cost $0.0000003 a call. Ignore |
| Reranking (`cohere/rerank-v4-fast`, `voyage/rerank-2.5-lite` at $0.02/M) | Rerank `search_meals` | Adds cost. No |
| Provider-executed web search | $10 per 1,000 searches | Adds cost. No |
| Anthropic context editing (`clear_tool_uses_20250919`) | Drop old tool results | No. Conversations are short, and an edit invalidates the cache from that point |
| Opener data fetched before the call | One step, not two | Already in the earlier document as October item 5. Still the best step reduction |

## 12. Response and semantic caching

The Vercel gateway has no response cache. `caching: 'auto'` manages provider prompt-cache markers only. The options that do exist:

| Option | What it does | Price | Fit |
|---|---|---|---|
| AI SDK middleware (`wrapLanguageModel` with `wrapGenerate` and `wrapStream`) | Exact-match cache keyed on the serialised call parameters. The cookbook replays a cached stream with `simulateReadableStream` ([middleware](https://ai-sdk.dev/docs/ai-sdk-core/middleware), [cookbook](https://ai-sdk.dev/cookbook/next/caching-middleware), which says it is "not yet updated to v5") | Free, plus a store | Works in Deno. Section 8 is the same idea with less code |
| A Postgres table we build | Exact match on a hash | Free on the current database | Best fit. No new vendor |
| Cloudflare AI Gateway | Exact-match response cache, TTL 60 seconds to 1 month, free ([Cloudflare](https://developers.cloudflare.com/ai-gateway/features/caching/)) | Free | Would replace or chain in front of the Vercel gateway. No |
| Upstash semantic cache | `@upstash/semantic-cache` on Upstash Vector. Last release 1.0.5 on 2024-11-21, Deno undocumented. Vector is free to 10,000 requests a day, then $0.40 per 100,000 ([Upstash](https://upstash.com/pricing/vector)) | Cheap | No, see below |
| Portkey semantic cache | 0.95 cosine threshold, and it ignores the system prompt ([Portkey](https://portkey.ai/docs/product/ai-gateway/cache-simple-and-semantic)) | $49 a month or Enterprise, the pages disagree | No |

Semantic caching reports 57 to 69 percent hit rates on FAQ-style traffic ([GPT Semantic Cache](https://arxiv.org/abs/2411.05276), [vCache](https://arxiv.org/pdf/2502.03771)). The known failure is a wrong answer served because two prompts read alike: InstCache measures GPTCache wrong-match rates of 30 to 34 percent at thresholds of 0.9 to 0.95 (from a search snippet of [the paper](https://arxiv.org/pdf/2411.13820), not read in full). Vana's prompts differ per athlete by design.

What in Vana's traffic is cacheable:

| Traffic | Cacheable | Why |
|---|---|---|
| Chat turns | No | Doll, Situation and history are in every prompt |
| Openers | No | Drafted per athlete from the Doll, by ruling |
| Day notes | Already stored | Precomputed on `meal_plans.day_notes`, regenerated only when a plan changes |
| Describe-meal | Yes, exact match | The prompt holds nothing about the athlete. Section 8 |
| Meal photo | No | Every image is new |
| Coach insight | Maybe, exact match on the input hash | The line costs $0.05 a month. Only worth it if it is ten lines of code |
| Extract, summary | No | Each reads a new transcript |

## 13. Tool-calling benchmarks for cheap chat models

The earlier document's conclusion stands: keep planning on Haiku 4.5. Nothing published since changes it, mostly because nothing has been published. BFCL is still V4, "last updated 2026-04-12", and lists none of the 2026 models ([leaderboard](https://gorilla.cs.berkeley.edu/leaderboard.html)). tau3-bench launched in March 2026 with few cheap-model submissions ([taubench.com](https://taubench.com)). Google's and DeepSeek's current model cards report neither benchmark.

| Model | Input / output / cache read $/M | Context | Public tool-calling score | Source quality |
|---|---|---|---|---|
| anthropic/claude-haiku-4.5 (today) | 1.00 / 5.00 / 0.10 | 200K | BFCL v4 68.7%, multi-turn 53.6%. tau2 retail 83.2, telecom 83.0 | BFCL first-party. tau2 from an aggregator, unverified |
| google/gemini-3-flash | 0.50 / 3.00 / 0.05 | 1M | tau2 airline 82.5, retail 76.8, telecom 91.2, tau3 banking 27.3, high reasoning | Sierra's own submission file |
| google/gemini-3.1-flash-lite | 0.25 / 1.50 / 0.03 | 1M | tau2 telecom 31.3 | Aggregator only. The model card has no tool-use rows |
| google/gemini-3.5-flash-lite, 3.6 to 3.8 flash | 0.30 / 2.50 / 0.03 and 0.75 / 3.75 / 0.075 | 1M | None found | |
| openai/gpt-5.4-mini | 0.75 / 4.50 / 0.075 | 400K | tau2 telecom 93.4 | Aggregator, unverified. OpenAI's post returned 403 |
| openai/gpt-5.4-nano | 0.20 / 1.25 / 0.02 | 400K | tau2 telecom 92.5 | Same |
| openai/gpt-5.6-luna | 0.20 / 1.20 / 0.02 | 1.05M | None found | |
| openai/gpt-5-mini | 0.25 / 2.00 / 0.025 | 400K | BFCL v4 55.5%, multi-turn 27.5% | BFCL |
| openai/gpt-5-nano | 0.05 / 0.40 / 0.005 | 400K | BFCL v4 51.5%, multi-turn 34.5% | BFCL |
| spacexai/grok-4.1-fast | 0.20 / 0.50 / 0.05 | 1M | BFCL v4 69.6% with reasoning, 58.3% without. tau3 banking 13.1 | BFCL and Sierra |
| xiaomi/mimo-v2.5 | 0.14 / 0.28 / 0.003 | 1.05M | tau2 telecom 90.6 | Aggregator |
| minimax/minimax-m3 | 0.30 / 1.20 / 0.06 | 512K | tau2 telecom 88.9 | Aggregator |
| moonshotai/kimi-k2.6 | 0.95 / 4.00 / 0.16 | 262K | tau2 telecom about 96 | Aggregator |
| deepseek/deepseek-v4-flash | 0.13 / 0.26 / 0.028 | 1M | No BFCL or tau. Toolathlon-Verified 70.3 on its model card | Vendor |
| alibaba/qwen3.7-flash, qwen3.8-flash, zai/glm-5.3-flash | 0.03 to 0.15 / 0.13 to 0.50 | 1M | None found | |

Read these with care. tau2 telecom is close to saturated and vendors tune for it, so a 90 there says little about a 43-tool meal planner with a tuned voice. The scores that come from Sierra or Berkeley directly are Haiku 4.5, Gemini 3 Flash, Grok 4.1 Fast and the GPT-5 mini and nano pair. Of those, Gemini 3 Flash and Grok 4.1 Fast are the two worth running through `scripts/vana-eval` as the cheap route for no-tool general turns, at half and a fifth of Haiku's input price. Grok's 58 percent without reasoning, and the latency reasoning adds, count against it for chat. Gemini 3 Flash on Vertex has a ZDR endpoint. The catalogue marks Grok 4.1 Fast `zdr: all`.

## 14. Food database before the model

The repo already has the non-model path for packaged food: `lookup-product` checks the product catalogue, a nutrition cache and USDA by barcode. The open question is free text and photos.

| API | Price | Text to macros | Note |
|---|---|---|---|
| USDA FoodData Central | Free, 1,000 requests an hour, CC0 | Search only, no parser | Already used |
| Open Food Facts | Free, 15 product reads a minute per IP, ODbL | No | Barcode only |
| Edamam Nutrition Analysis | $29 a month for 10,000 text lines, $299 for 100,000. No caching on the $29 plan ([Edamam](https://developer.edamam.com/edamam-nutrition-api)) | Yes | About $0.003 a line. A describe call averages several lines, so it costs about the same as Haiku and more than Gemini Flash |
| FatSecret | Basic free at 5,000 calls a day, US only. Natural language is a paid add-on ([FatSecret](https://platform.fatsecret.com/api-editions)) | Add-on | Attribution required |
| CalorieNinjas | $8 a month for 100,000 calls ([CalorieNinjas](https://calorieninjas.com/pricing)) | Yes | Cheapest. Accuracy on mixed dishes unknown |
| Nutritionix | Unverified. Pricing pages returned an error. Third-party posts say about $1,850 a month | Yes | No |
| Passio | $99 a month for 1M tokens, a photo uses 20,000 to 30,000 ([Passio](https://www.passio.ai/pricing)) | Yes | About $2.50 a photo at that rate. No |

A parser API does not beat a cheap model on price, and "one item per dish" grouping with a suggested meal slot is what the current prompt is tuned for. Not worth adding a vendor.

On photo accuracy across model tiers, the one study with current-ish tiers is a Nutrition5k evaluation of 505 images ([PMC13401436](https://pmc.ncbi.nlm.nih.gov/articles/PMC13401436/)). Calorie error (MAPE) was 34.6% for GPT-4.1, 32.7% for GPT-4.1 mini, 43.9% for GPT-4.1 nano and 42.9% for Gemini 2.5 Flash. Carbohydrate error was 33.0%, 36.7%, 83.9% and 60.3%. The mid tier matched the large model and the smallest tier fell apart on carbs. On a second dataset, giving the model the true portion weight cut Gemini 2.5 Flash's carb error from 56.6% to 20.2%. Two conclusions for the eval in section 6. Test the mid tier (Haiku 4.5, Gemini 3 Flash, GPT-5.4 mini), not the nano tier. And a portion prompt or a confirm-the-portion step in the app buys more accuracy than the model tier does. No 2026 study compares today's models.

## 15. Embeddings

`text-embedding-3-small` at $0.02 per million costs $0.0000003 per call here. 616 calls in the dev log cost under a fifth of a cent. The gateway lists cheaper models (`perplexity/pplx-embed-v1-0.6b` at $0.004, `alibaba/qwen3-embedding-0.6b` at $0.01, `voyage/voyage-4-lite` at $0.02). Supabase's built-in `gte-small` has no listed price, but it "exclusively caters to English texts", truncates at 512 tokens, is 384-dimensional (unverified, from the model card), and runs against the 2 second CPU limit ([Supabase AI models](https://supabase.com/docs/guides/functions/ai-models)). Any switch means re-embedding every row and changing the `vector(1536)` columns. Not worth doing at any scale Mealvana will reach soon.

## 16. Supabase

Prices from [supabase.com/pricing](https://supabase.com/pricing) and the linked docs.

| Item | Price | Exposure here |
|---|---|---|
| Base | Pro $25 plus compute, with a $10 compute credit. Two Micro projects total $35 a month | Fixed |
| Edge Functions | 2M invocations included, then $2 per million. Billed per invocation only. A 30 second stream costs the same as a 50 ms call | About 1,300 invocations per athlete a month at 1,500 athletes. Fine |
| Function limits | 256 MB, 2 s CPU, 400 s wall clock, 150 s idle timeout ([limits](https://supabase.com/docs/guides/functions/limits)) | Limits, not costs |
| Egress | 250 GB uncached then $0.09/GB, 250 GB cached then $0.03/GB | 250 GB is about 800,000 views of a 300 KB image. Unsplash and Pexels hotlinks never touch Supabase |
| Storage | 100 GB then $0.0213/GB | Negligible |
| Image transformations | 100 origin images included, then $5 per 1,000 | The unbounded one. 1,000 library photos cost about $4.50 a month. Athlete uploads transformed on the fly grow without limit |
| Compute | Micro about $10, Small $15, Medium $60, Large $110 | Supabase's pgvector guide puts 15,000 1536-dim HNSW vectors on Micro, 50,000 on Small, 100,000 on Medium ([compute sizing](https://supabase.com/docs/guides/ai/choosing-compute-addon)). Those are high-QPS benchmarks. 1,000 meals plus memory rows fit Micro |
| Auth, Realtime, Supavisor, pg_cron, Queues | 100,000 MAU included, 500 realtime connections included, no line item for the rest | $0 |
| Spend cap | On by default on Pro. Covers egress, invocations, storage, transformations, MAU. Does not cover compute | With the cap on, passing a quota stops the service until the next cycle |

What to do. Upload `meal-images` with a long `cacheControl` (the default is about 1 hour) and keep dish photos in the public bucket, because each signed URL is its own CDN entry ([Smart CDN](https://supabase.com/docs/guides/storage/cdn/smart-cdn)). Resize once at upload and store the sizes you serve, so transformations never run on athlete uploads. `sharp` does not run in edge functions, so resizing stays on the device as it is now. Let `pg_cron` run SQL and call a function only when there is work: the automatic embeddings guide's 10 second cron is about 260,000 invocations a month on its own. Know the spend-cap behaviour before launch. Nothing else in Supabase costs real money below several thousand athletes. The first step up is compute, when memory vectors pass 50,000.

Moving dev to a free organisation saves $10 a month, but free projects pause after a week idle and cap at 500 MB. Not worth it.

## 17. Observability tools

| Tool | Price | Fit with Deno functions and the gateway | Verdict |
|---|---|---|---|
| Gateway dashboard, logs, generation lookup | No listed charge | Already there. Per-request cost, provider attempts, cache tokens. Routing detail kept 30 days | Use it now for the cache experiments |
| Gateway Custom Reporting | $0.075 per 1,000 writes, $5 per 1,000 queries, Vercel Pro | Works | No. Duplicates `vana_calls` |
| Gateway Trace Drains | $0.05 per 1,000 traces plus $0.50/GB, Vercel Pro, no free allowance. Traces exclude prompt text | Sentry and Braintrust are native destinations | Only with Sentry below, about $5 per 100,000 requests |
| Sentry AI monitoring | Bills as spans. 5M spans included on every plan including free, then $2 per million on Team ([Sentry pricing](https://sentry.io/pricing/)) | `vercelAIIntegration` is documented for `@sentry/deno` with `ai` 3 to 7, and needs `experimental_telemetry` on every call ([Sentry Deno docs](https://docs.sentry.io/platforms/javascript/guides/deno/configuration/integrations/vercelai/)). Unverified inside Supabase's runtime | Best fit if per-step traces are wanted. Sentry is already a vendor |
| Langfuse | Hobby free 50,000 units, Core $29 with 100,000 then $8 per 100,000. A tool-calling turn is 5 to 20 units ([Langfuse pricing](https://langfuse.com/pricing)) | OpenTelemetry exporter. Deno and edge are not documented | Not now |
| Helicone | Free 10,000 requests, Pro $79 | Acquired by Mintlify on 2026-03-03. "Helicone's services will remain live for the foreseeable future in maintenance mode" ([Helicone](https://www.helicone.ai/blog/joining-mintlify)) | No |
| Braintrust | Free starter, Pro $249 | Eval product | No |
| PostHog LLM analytics | 100,000 events free | Deno unverified | No |

The cheapest tool that finds savings is the five extra `vana_calls` columns the earlier document lists (cache writes, step count, gateway cost, debit flag, chip or typed). Add those before any vendor.

## 18. Other running costs in the repo

| Service | Where it scales | At Mealvana's size |
|---|---|---|
| Codemagic | $0.095 a minute on the `mac_mini_m2` every workflow uses, 500 free minutes a month, $49 per extra concurrency. Fixed plans start at $3,990 a year ([Codemagic pricing](https://codemagic.io/pricing/)) | Scales with pushes. A 30 minute iOS build is $2.85. The CLAUDE.md batching rule is the control |
| RevenueCat | Free to $2,500 monthly tracked revenue, then 1% of tracked revenue ([RevenueCat pricing](https://www.revenuecat.com/pricing/)) | About 1% of gross once past roughly 100 subscribers at $24.99. Count it in the margin table |
| OneSignal | Free push to 1,000 monthly active users. Growth $19 plus $0.012 per MAU ([OneSignal pricing](https://onesignal.com/pricing)) | 3,000 MAU is about $55 a month. The first non-AI line to grow with users |
| Mixpanel | 1M events a month free, then $0.00028 per event | Free below about 300 events per athlete a month at 3,000 athletes. Audit event volume before launch |
| Sentry | Developer $0 with 5,000 errors, Team $26 with 50,000. Overage $0.0003625 per error | Errors run out first. Spans have room |
| Wiredash | Free Indie tier, Growth EUR 29. Device caps unverified | Free or EUR 29 |
| Shorebird | Free 5,000 patch installs a month with no overage, Pro $20 for 50,000 then $1 per 2,500 ([Shorebird pricing](https://shorebird.dev/pricing/)) | Installs are athletes times patches. 2,000 athletes and 3 patches a month needs Pro |
| Vercel | Pro plan needed for per-request ZDR, Custom Reporting, Trace Drains. Price unverified here | Only if per-request ZDR is wanted |

## Not worth doing

- Our own Anthropic key through BYOK with no credits behind it. Same price, and the spend leaves the gateway budgets.
- AI SDK 7 upgrade for cost reasons. No token saving.
- `activeTools`, per-step model switching and history pruning. Each breaks the Anthropic cache and costs more than it saves once lever 1 is in.
- Anthropic context editing. Conversations are too short.
- Semantic caching of any Vana chat traffic, through Upstash, Portkey or a pgvector table. Every prompt carries the athlete's Doll and Situation, so a near match is a wrong answer.
- Caching openers. Lee's ruling is that Vana drafts every opener from the Doll.
- Flex tier and batch for background jobs. They cost $0.07 a month.
- `gte-small` or any other embedding change.
- Reranking and provider-executed web search. Both add cost.
- Shrinking meal photos below 1,000 px. Anthropic charges one token per 28 x 28 pixel patch ([Anthropic vision](https://platform.claude.com/docs/en/build-with-claude/vision)). 1,000 x 750 is 972 tokens and 768 x 576 is 588, a saving of $0.0012 a photo, $0.02 a month, against a real accuracy risk.
- Free gateway models such as `inclusionai/ling-3.0-flash-vl-free`. The catalogue marks them `zdr: none`, and free slugs change without notice.
- Model fallbacks (`providerOptions.gateway.models`) as a cost tool. They are for availability. A fallback to another model also misses the cache and changes the voice.
- Gateway Custom Reporting, Helicone, Langfuse, Braintrust, for now.
- Moving dev to a free Supabase organisation.
- Supabase image transformations for athlete uploads.

## One thing to check in the code

`env.ts` defaults `CHAT_MODEL` and `TOOL_MODEL` to `anthropic/claude-haiku-4-5`. The catalogue id is `anthropic/claude-haiku-4.5`. The calls work, so the gateway accepts the dashed form, but confirm in the gateway logs which model and price the alias resolves to. Unverified either way.

## Sources

- Vercel AI Gateway pricing: https://vercel.com/docs/ai-gateway/pricing
- Vercel automatic prompt caching: https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching
- Vercel BYOK: https://vercel.com/docs/ai-gateway/authentication-and-byok/byok
- Vercel budgets: https://vercel.com/docs/ai-gateway/observability-and-spend/budgets
- Vercel custom reporting: https://vercel.com/docs/ai-gateway/observability-and-spend/custom-reporting
- Vercel rate limits: https://vercel.com/docs/ai-gateway/rate-limits
- Vercel service tiers: https://vercel.com/docs/ai-gateway/models-and-providers/service-tiers
- Vercel discounts: https://vercel.com/docs/ai-gateway/pricing/discounts
- Vercel trace drains: https://vercel.com/docs/ai-gateway/observability-and-spend/trace-drains
- Gateway catalogue (JSON) and per-model endpoints: https://ai-gateway.vercel.sh/v1/models
- AI SDK gateway provider: https://ai-sdk.dev/providers/ai-sdk-providers/ai-gateway
- AI SDK Anthropic provider: https://ai-sdk.dev/providers/ai-sdk-providers/anthropic
- AI SDK 7 migration guide: https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0
- AI SDK loop control: https://ai-sdk.dev/docs/agents/loop-control
- npm registry, `ai` dist-tags: https://registry.npmjs.org/ai
- Anthropic prompt caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Anthropic tool search tool: https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
- Anthropic vision: https://platform.claude.com/docs/en/build-with-claude/vision
- Gemini API pricing: https://ai.google.dev/gemini-api/docs/pricing
- Supabase pricing: https://supabase.com/pricing
- Supabase function pricing and limits: https://supabase.com/docs/guides/functions/pricing, https://supabase.com/docs/guides/functions/limits
- Supabase egress: https://supabase.com/docs/guides/platform/manage-your-usage/egress
- Supabase image transformations: https://supabase.com/docs/guides/storage/serving/image-transformations
- Supabase Smart CDN: https://supabase.com/docs/guides/storage/cdn/smart-cdn
- Supabase compute and pgvector sizing: https://supabase.com/docs/guides/platform/compute-and-disk, https://supabase.com/docs/guides/ai/choosing-compute-addon
- Supabase AI models in functions: https://supabase.com/docs/guides/functions/ai-models
- Supabase automatic embeddings: https://supabase.com/docs/guides/ai/automatic-embeddings
- Supabase cost control: https://supabase.com/docs/guides/platform/cost-control
- Helicone: https://www.helicone.ai/pricing, https://www.helicone.ai/blog/joining-mintlify
- Langfuse: https://langfuse.com/pricing
- Sentry: https://sentry.io/pricing/, https://docs.sentry.io/platforms/javascript/guides/deno/configuration/integrations/vercelai/
- Braintrust: https://www.braintrust.dev/pricing
- PostHog: https://posthog.com/pricing
- Codemagic: https://codemagic.io/pricing/
- RevenueCat: https://www.revenuecat.com/pricing/
- OneSignal: https://onesignal.com/pricing
- Mixpanel: https://mixpanel.com/pricing/
- Wiredash: https://wiredash.com/pricing
- Shorebird: https://shorebird.dev/pricing/
- Berkeley Function Calling Leaderboard v4: https://gorilla.cs.berkeley.edu/leaderboard.html
- tau-bench leaderboard and submissions: https://taubench.com, https://github.com/sierra-research/tau2-bench/tree/main/web/leaderboard/public/submissions
- BenchLM tau2 aggregator (secondary): https://benchlm.ai/benchmarks/tau2-bench
- AI SDK middleware and caching cookbook: https://ai-sdk.dev/docs/ai-sdk-core/middleware, https://ai-sdk.dev/cookbook/next/caching-middleware
- Cloudflare AI Gateway caching: https://developers.cloudflare.com/ai-gateway/features/caching/
- Upstash: https://github.com/upstash/semantic-cache, https://upstash.com/pricing/vector
- Portkey cache: https://portkey.ai/docs/product/ai-gateway/cache-simple-and-semantic
- Semantic cache papers: https://arxiv.org/abs/2411.05276, https://arxiv.org/pdf/2502.03771, https://arxiv.org/pdf/2411.13820
- Nutrition APIs: https://fdc.nal.usda.gov/api-guide/, https://openfoodfacts.github.io/openfoodfacts-server/api/, https://developer.edamam.com/edamam-nutrition-api, https://platform.fatsecret.com/api-editions, https://calorieninjas.com/pricing, https://www.passio.ai/pricing
- LLM food photo accuracy on Nutrition5k: https://pmc.ncbi.nlm.nih.gov/articles/PMC13401436/
