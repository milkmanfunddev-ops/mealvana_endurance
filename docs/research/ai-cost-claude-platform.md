# AI cost: what the Claude platform offers that the app does not use yet

Researched 2026-09-20. Follows `docs/research/vana-cost-and-pricing.md` (09-17) and does not repeat it. Every platform fact below was read today from the page linked beside it. Usage numbers come from read-only queries on the DEV project (`vana_messages`, `vana_calls`). Nothing was deployed, written or committed.

Baseline used throughout: typical athlete $2.86 a month today, $1.64 after the known caching fix ("lever 1" in the 09-17 report). Chat turns and openers are about 75 percent of that, meal logging about 22 percent.

State of the code at this read: `chat.ts` still sends only the automatic top-level `cacheControl` (`CACHE_PROVIDER_OPTIONS`). There are no explicit breakpoints, no `gateway.only`, no `x-session-affinity`, and chat calls carry no `gateway.user` or `gateway.tags`. Lever 1 is planned, not shipped.

## Two findings that matter more than any platform feature

1. **The model is sent the whole meal picker, including the "Show more" tail it never uses.** A stored `suggestMeals` result averages 39,174 characters (n=16 since 09-14). 34,719 of those are the `more` array of 24 meals (mp-230). The five meals on the tiles are another 6,000 characters because they are full `MealRef`s, not `compactMeal`. No tool defines `toModelOutput`, so the AI SDK serialises the entire `VanaPart` to the model in the next step, and `conversationMessages` replays it on every later turn. That is roughly 10,000 tokens per picker (estimated from characters, not tokenised). It explains why planning chat turns since the evening of 09-16 average 47,694 input tokens (p90 70,841, max 72,314) while planning openers, which call no picker, sit at 31,189.
2. **Almost every opener pays for a second model step that does nothing.** 55 of 56 planning openers and 23 of 23 general openers end with `askChoice`. After a terminal UI tool the loop runs the model again over the full prompt only to stop. The 09-17 report assumed the opener's tool call was a data fetch and proposed pre-fetching. It is `askChoice`, so the fix is a stop condition. 27 percent of planning chat turns and 17 percent of general chat turns also end on `askChoice`, `handOff` or `saveFeedback`.

## Ranked candidates

Ranked by saving per unit of effort. Savings are per typical athlete per month unless stated.

| # | Candidate | Works through gateway + AI SDK today | Saving | Effort | Risk |
|---|---|---|---|---|---|
| 1 | Compact what tools return to the model (`toModelOutput`, drop `more`) | Yes, pure AI SDK | About $0.12 to $0.15 today (14% of planning chat). Without it, lever 1's planning estimate of $0.0116 a turn is wrong for picker turns, which would cost about $0.022 | S | Low |
| 2 | Stop the loop on terminal UI tools (`hasToolCall`) | Yes, pure AI SDK | $0.08 to $0.13 (about 5% of total), 28% of opener cost after lever 1, and one round trip less on every opener | S | Low |
| 3 | 1-hour TTL on the shared tools+persona prefix while traffic is low | AI SDK documents `ttl: '1h'`. Gateway pass-through on the AI SDK path unverified | $0.40 to $0.75 below about 100 subscribers, under $0.05 by about 1,000 | S, after lever 1 | Low |
| 4 | Gateway budgets, `user` and `tags` on chat calls | Yes | None. Caps the worst case and gives cost per athlete | S | Low |
| 5 | Meal logging on Sonnet 5 with thinking off and the photo pinned to 1,000 px | Yes | About $0.10 (3%), only with the three settings below. Without them the photo saving is 6% or negative | M (eval) | Medium |
| 6 | Drop `totals` from the meal schema, add `not_food` to it | Yes | About $0.04 (1.5%) and removes a billed failure path | S | Low |
| 7 | Native structured outputs and `strict` tools | Anthropic GA on all three models. Which mode the gateway uses is unverified | Equal to today's schema-failure rate, which is not logged. Expect under 1% | S to M | Medium (schema limits) |
| 8 | Tool search with `defer_loading` | Unverified through the gateway | At most 8 to 11% of a planning turn after lever 1, negative on any turn that needs a search step | M | Medium to high |

Do 1 and 2 before lever 1 ships or with it. They change the numbers lever 1 was sized on.

## 1. Compact tool results

What it is: AI SDK tools accept `toModelOutput({ toolCallId, input, output })`, which sets what the model sees while the UI still receives the full `output` ([AI SDK tool reference](https://ai-sdk.dev/docs/reference/ai-sdk-core/tool)). `convertToModelMessages(messages, { tools })` applies the same function to replayed history ([reference](https://ai-sdk.dev/docs/reference/ai-sdk-ui/convert-to-model-messages)). Both pages describe AI SDK 7. The repo imports `npm:ai@6`, so check the v6 signature before writing it. Anthropic's tool guidance says the same thing: return only high-signal fields, and a concise response format cut one example from 206 tokens to 72 ([Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)).

How it applies:
- `tools.ts`, `suggestMeals`: model output = `{ kind, mealType, meals: meals.map(compactMeal), defaultServings }`. Never `more`.
- Same treatment for `draftWeek` (11,011 chars), `sameAsLastTime` (4,877), `dayGuidance` (2,499), `getBatch`, `diagnoseStaples`, `askPantry`, `confirmPlan`, `shoppingList`.
- `chat.ts` line 345: pass `tools` to `convertToModelMessages` so history replays the compact form. Without this the saving is lost from the second turn on.
- The compact form must be a pure function of the stored output, or the replay stops being byte-stable and the cache breaks (known lever 2).

Saving: about 10,000 tokens per picker call. Today those tokens are written to cache once at $1.25/M ($0.0125) and re-sent on every later step and turn. At one picker in every three planning turns (16 of 48 in the sample) and 26 planning turns a month, that is $0.12 to $0.15 for the typical athlete and about $0.25 for the heavy one. It also cuts time to first token on the step after a picker.

Risk: the model loses fields it may have been leaning on (ingredients, for example). `compactMeal` already exists for `searchMeals` and carries `why`, macros and prep time. Run `scripts/vana-eval` before and after.

## 2. Stop on terminal UI tools

What it is: `stopWhen` takes a list, and `hasToolCall(...names)` ends the loop after the step that called one of them ([AI SDK tool calling](https://ai-sdk.dev/docs/ai-sdk-core/tools-and-tool-calling)). Tools in that step still execute.

How it applies: `chat.ts` line 356, `stopWhen: [stepCountIs(general ? 8 : 6), hasToolCall('askChoice', 'handOff', 'saveFeedback')]`. The persona already requires text first, then `askChoice`, and `saveFeedback` is documented as "let that call be the whole turn". `partsFromSteps` needs no change.

Measured share of turns ending on one of those three tools (DEV, since 09-10): planning openers 55/56, general openers 23/23, planning chat 13/48, general chat 42/249.

Saving: the dropped step reads the full prompt from cache and writes a few hundred tokens, about $0.002. That is 28 percent of an opener after lever 1 and 15 percent today. Across the typical month, $0.08 after lever 1 and $0.13 today.

Risk: low. The next turn replays an assistant message that ends in a tool result with no closing text. Anthropic accepts that. Check the byte-stable replay test covers it. Do not add picker tools to the list: the persona writes its two sentences after `suggestMeals`.

## 3. 1-hour TTL economics at low traffic

Facts: a 5-minute write costs 1.25x input, a 1-hour write 2x, a read 0.1x, and "the cache is refreshed for no additional cost each time the cached content is used". 1-hour entries must sit before 5-minute ones in the prompt. Haiku 4.5 needs 4,096 tokens to cache at all. Cache reads do not count against input-token rate limits. Caches are isolated per workspace ([prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), [pricing](https://platform.claude.com/docs/en/about-claude/pricing)).

Break-even: the shared prefix (tools + persona, about 13,500 tokens for planning, 6,200 for general) is hit by every athlete. With turns arriving at rate L per hour on one prefix (Poisson, my assumption), the expected extra cost per turn is `(W5 - R) x e^(-L/12)` on 5 minutes and `(W1 - R) x e^(-L)` on 1 hour. One hour wins when L is above 0.55 turns an hour, which is any hour in which the app is in use at all.

| Subscribers (typical mix, 16 waking hours) | Planning turns/hour | 5-min miss rate | Cold-write penalty per planning turn, 5 min | Same, 1 hour | Typical athlete saves per month (both prefixes) |
|---|---|---|---|---|---|
| 25 | 1.6 | 88% | $0.0136 | $0.0054 | about $0.75 |
| 100 | 6.3 | 59% | $0.0092 | about $0 | about $0.40 |
| 1,000 | 63 | 0.5% | about $0 | about $0 | under $0.05 |

At launch size the cold write is as large as the whole post-fix planning turn ($0.0116), so lever 1's estimate only holds with the 1-hour TTL on the shared prefix. Put `ttl: '1h'` on the persona breakpoint only. Keep 5 minutes on the Doll and the conversation tail until `vana_calls` logs cache-write tokens and turn gaps. Anthropic's cost guide says to move a tail to 1 hour when about 1 turn in 20 follows a 5 to 60 minute pause ([cost guide](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)).

Gateway: the AI SDK Anthropic provider documents `cacheControl: { type: 'ephemeral', ttl: '1h' }` ([provider docs](https://ai-sdk.dev/providers/ai-sdk-providers/anthropic)). The gateway documents a 1-hour lifetime only as `cache_ttl` on its Responses API with `caching: 'auto'` ([gateway caching](https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching)). Whether a manual `ttl` on the AI SDK path reaches Anthropic is unverified. Probe: send one request twice 10 minutes apart and read `cacheReadTokens`.

Optional, smaller: an hourly pre-warm. Anthropic supports `max_tokens: 0` to write a cache without output, rejected when streaming or inside batches. One hourly read of the planning prefix costs $0.97 a month. It only pays while cold 1-hour writes ($0.027 each) happen more than about 36 times a month. Not worth a cron job yet. Whether the AI SDK and gateway accept a zero output limit is unverified.

## 4. Guardrails: usage API, workspaces, gateway budgets

Anthropic side: the Usage and Cost Admin API (`/v1/organizations/usage_report/messages`, `/v1/organizations/cost_report`) splits uncached input, cache reads, 5-minute and 1-hour cache writes and output by model, API key and workspace, with data about 5 minutes behind. It needs an Admin API key and "is unavailable for individual accounts" ([usage and cost API](https://platform.claude.com/docs/en/manage-claude/usage-cost-api)). Workspaces take a monthly spend limit with alerts and their own rate limits. The Default Workspace cannot have limits ([workspaces](https://platform.claude.com/docs/en/manage-claude/workspaces)).

None of that applies today. The app calls Anthropic on Vercel's credentials, so there is no Anthropic organisation of ours to report on or cap. It applies only with BYOK or a direct key. With BYOK the gateway adds no markup, falls back to its own credentials if ours fail, and "spend through your own credentials isn't counted in budgets" ([BYOK](https://vercel.com/docs/ai-gateway/authentication-and-byok/byok)). So choose one guardrail system.

Recommended now, on the gateway ([budgets](https://vercel.com/docs/ai-gateway/observability-and-spend/budgets)):
- One gateway API key per environment, each with a budget. Refresh can be daily, weekly or monthly. A daily budget is the abuse stop the 09-17 report asked for. Exceeding it returns HTTP 402 `quota_for_entity_exceeded`. It is a soft cap: the request that crosses the line completes.
- Email alerts at 50, 75 and 100 percent.
- In `chat.ts`, `extract.ts` and `daynotes.ts` add `providerOptions.gateway.user` and `tags` as `analyze-meal-photo` already does. The gateway's custom reporting groups spend by user and tag, which gives cost per athlete without a new table.
- `runChat` must turn a 402 into a clear message in the chat (the mp-342 empty-wallet strip is the nearest existing surface), not a generic error. The AI SDK may surface it as `GatewayInternalServerError`, so match on the quota text.

If the app later moves to BYOK (own cache namespace, Admin API, token counting): one Anthropic workspace for prod and one for dev, a monthly spend limit on each. Caches are per workspace, so dev traffic will not warm prod.

## 5. Model tiers available now

Read today ([models](https://platform.claude.com/docs/en/about-claude/models/overview), [pricing](https://platform.claude.com/docs/en/about-claude/pricing), [deprecations](https://platform.claude.com/docs/en/about-claude/model-deprecations)):

| Model | Input | Output | Cache read | Notes |
|---|---|---|---|---|
| Haiku 4.5 | $1 | $5 | $0.10 | Cheapest Claude. No newer Haiku exists. Haiku 3 and 3.5 are retired on the Anthropic API. Retirement "not sooner than October 15, 2026", no deprecation announced, 60 days' notice is promised |
| Sonnet 4.6 | $3 | $15 | $0.30 | Legacy. Old tokenizer. Retirement not sooner than 2027-02-17 |
| Sonnet 5 | $2 | $10 | $0.20 | Price is now permanent. New tokenizer, "approximately 30% more tokens for the same text" |

Chat stays on Haiku 4.5. Sonnet 5 costs about 2.6x Haiku per turn once the tokenizer is counted. When a Haiku successor ships, expect the new tokenizer and re-measure (my expectation, unverified).

Meal logging on Sonnet 5 saves money only with three settings the 09-17 report did not have:
1. **Thinking.** On Sonnet 4.6 a request with no `thinking` field runs without thinking. On Sonnet 5 it runs adaptive thinking, billed as output at $10/M, and `maxOutputTokens: 1000` then caps thinking plus the JSON together. Set `providerOptions.anthropic.thinking: { type: 'disabled' }` or `effort: 'low'` in `describe-meal` and `analyze-meal-photo`, and test for truncated objects.
2. **Image resolution.** An image costs `ceil(w/28) x ceil(h/28)` tokens. Models before 4.7 cap an image at 1,568 tokens and 1,568 px. Sonnet 5 caps at 4,784 tokens and 2,576 px ([vision](https://platform.claude.com/docs/en/build-with-claude/vision)). The app uploads 1,000 or 1,200 px wide (`log_meal_screen.dart`, `edit_meal_log_screen.dart`, `photo_capture_screen.dart`) with no `maxHeight`. A 1,200 x 1,600 portrait is 2,494 tokens on Sonnet 5 against about 1,565 today. Set `maxWidth` and `maxHeight` to 1,000 on all three screens first.
3. **Sampling.** Sonnet 5 rejects non-default `temperature` with a 400. `ai-coach/index.ts` line 293 sets 0.5. Remove it before switching that function.

Computed cost per call, my arithmetic from the measured token counts:

| Call | Sonnet 4.6 today | Sonnet 5, thinking off, photo as uploaded today (1,200 px) | Sonnet 5, thinking off, photo at 1,000 x 1,333 | Sonnet 5, 896 x 1,195 |
|---|---|---|---|---|
| describe-meal | $0.0077 | $0.0067 (13% less) | | |
| analyze-meal-photo | $0.0130 | $0.0122 (6% less) | $0.0106 (18% less) | $0.0099 (24% less) |

Typical athlete: about $0.10 a month, 3 percent of total. Haiku 4.5 on the same calls is still the larger cut (65 percent, measured on 07-23) if the 50-meal eval ever passes it. Both need that eval.

## 6. Image downscaling on today's model

On Sonnet 4.6 the photo already hits the 1,568-token cap, so it costs about 1,565 tokens whether the phone sends 1,000 or 1,200 px. Dropping `photo_capture_screen.dart` from 1,200 to 1,000 changes upload time, not tokens. Going below the cap does save: 768 x 1,024 is 1,036 tokens, which is $0.0016 a photo, 12 percent of the photo call, about $0.03 a month. Portion estimates depend on detail, so leave it. The real value of the pin is item 5.

## 7. Meal schema: `totals` and `not_food`

Output is half of a describe-meal call (254 tokens x $15/M = $0.0038 of $0.0077). `MealAnalysisSchema.totals` asks the model to add up numbers it just wrote, about 40 to 45 output tokens. Compute totals in the edge function and return the same response shape. Saves about 8 percent of describe-meal and 5 percent of the photo call, $0.04 a month, and the sums become exact.

`analyze-meal-photo` signals a non-food photo by telling the model to return `{ "not_food": true }`, which fails the Zod parse and is caught by string-matching the error. That call is billed and never logged. If the gateway ever enforces the schema by constrained decoding (item 8), the model cannot emit that object and will invent a meal. Add `not_food: z.boolean()` to the schema now.

## 8. Structured outputs and strict tools

What it is: `output_config.format` with a JSON schema uses constrained decoding so the response always parses, and `strict: true` on a tool guarantees its input validates. GA on Haiku 4.5, Sonnet 4.6 and Sonnet 5. It injects an extra system prompt (more input tokens), compiles a grammar on first use that is cached 24 hours, and changing the schema invalidates the prompt cache. Unsupported: `minimum`, `maximum`, `minLength`, `maxLength`, `minItems` above 1, recursion ([structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)).

Through the gateway: the AI SDK provider has `structuredOutputMode: 'outputFormat' | 'jsonTool' | 'auto'`. Which one the gateway's server-side provider picks is undocumented. Unverified.

How it applies: the saving equals the share of `generateObject` calls that fail to parse today, and nothing logs that. `MealAnalysisSchema` uses `.int()`, `.nonnegative()` and `.min(1).max(12)`, all outside the supported subset, so the SDK would strip them or the API would return 400. For chat, `strict` on the write tools (`createEvent`, `logMeal` and the rest) would remove the occasional invalid-input retry step, but their schemas use regex and numeric bounds too. First log parse failures in the meal functions and invalid tool inputs in `chat.ts`. Build only if either is above about 2 percent.

## 9. Tool search and deferred loading

What it is: mark tools `defer_loading: true` and add `tool_search_tool_bm25_20251119` or the regex variant. Deferred definitions stay out of the prompt until the model searches, then load inline as `tool_reference` blocks. Haiku 4.5 is supported. "The prefix is untouched, so prompt caching is preserved." A deferred tool cannot carry `cache_control`. It is not billed separately ([tool search](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool), [tool use with caching](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-use-with-prompt-caching)).

Anthropic's thresholds: use it above 10 tools or above 10,000 tokens of definitions, keep the 3 to 5 most-used tools loaded, and expect little from it when "all tools used frequently" or the library is small ([advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use)). Their measured win was at 502 tools. Vana has 43 tools at about 8,000 tokens.

For this code: deferring about 25 rare tools (event and activity CRUD, `recordDebrief`, `planWeek`, `setHomeLocation`, `recallConversations`) removes about 5,000 tokens. After lever 1 those tokens cost $0.10/M, so the saving is 5,000 x 2.6 steps x $0.10/M = $0.0013 a turn, 11 percent of a planning turn at best. Any turn that needs a deferred tool pays a whole extra step (about $0.002 to $0.004) and a second of latency, and Haiku has to realise it should search. "Add a ride on Saturday" answered with "I can't do that" is a worse failure than the saving is worth. Cold 1-hour writes would shrink by $0.01 each, which item 3 already mostly removes.

Through the gateway: the AI SDK exposes `deferLoading` on tools and `anthropic.tools.toolSearchBm25_20251119()`, but the gateway docs say provider-executed tools "may not work through AI Gateway" and do not mention tool-level Anthropic options ([AI SDK gateway provider](https://ai-sdk.dev/providers/ai-sdk-providers/ai-gateway)). Unverified.

Verdict: not now. Revisit if tool definitions pass 10,000 tokens. Until then never vary the tool list per turn: a changed tool definition invalidates the entire cache. The cheaper route to the same end is fewer, merged tools, which Anthropic's tool guidance recommends anyway.

## 10. Fewer agent steps

- Parallel tool calls are on by default and the AI SDK runs them in one step. Nothing to enable. Do not set `disableParallelToolUse`: changing it also invalidates the messages cache.
- The remaining multi-step pattern is list-then-act (`listActivities` then `updateActivity`, `listEvents` then `deleteEvent`). Letting the write tools accept a date plus a title fragment and resolve the id server-side removes one step (about $0.0045 after lever 1) from those turns. They are rare. Do it when those tools are next touched.
- Programmatic tool calling does not apply: "Claude Haiku 4.5 ... doesn't support programmatic tool calling", it needs the server-side code execution tool, and it is not ZDR eligible ([docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/programmatic-tool-calling)).

## Not worth doing

| Feature | Why not |
|---|---|
| Context editing (`clear_tool_uses_20250919`) | Available on all models and exposed by the AI SDK, but every clear "invalidates cached prompt prefixes". Anthropic's own measurement: on a 20-issue run it "saved nothing, and context editing cost 74% more". The default trigger is 100,000 input tokens and a Vana turn peaks near 70,000. Item 1 removes the bulk at the source with no cache break |
| Compaction (`compact_20260112`) | Not offered on Haiku 4.5. `chat.ts` already rolls history into summaries every 20 messages |
| Memory tool | A client-side file tool. The app has its own memory table and `rememberFact`. No token saving |
| Programmatic tool calling | No Haiku 4.5 support, needs a server tool the gateway may not pass, not ZDR eligible |
| Token-efficient tool use | The old beta page now redirects to the migration guides. It is built into Claude 4 models. Nothing to switch on |
| Extended thinking budgets, effort | Haiku 4.5 does not think unless asked and does not accept `effort`. The only action is switching thinking off if meal logging moves to Sonnet 5 |
| Priority Tier | "No longer available for purchase", and it bought availability, not a discount |
| Fast mode | Opus only, at double price |
| `inference_geo: "us"` | A 1.1x surcharge on every token. Leave it unset |
| Batch API | Known. 50 percent off $0.07 a month, and the 24-hour window breaks the opener |
| Hourly cache pre-warm | About $1 a month per prefix, pays only above about 36 cold writes a month. Revisit with real traffic |
| Token counting endpoint | Free and exact, but needs a direct Anthropic key. Worth one manual run to replace the character-based estimates of the tool block and persona |

## Verify before building

1. `toModelOutput` and `hasToolCall` signatures in `ai@6`. The pages read describe v7.
2. Whether a manual `cacheControl.ttl: '1h'` survives the gateway on the AI SDK path.
3. Which structured-output mode the gateway uses for `generateObject` on Anthropic models.
4. Whether `deferLoading` and provider-defined Anthropic tools pass through the gateway.
5. The token size of a picker result. 10,000 is from characters. One `count_tokens` call or one logged step settles it.
6. Log `cacheWriteTokens`, step count and parse failures. Items 3, 7 and 8 cannot be confirmed without them.

## Sources

Anthropic, all read 2026-09-20:
- Pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Models overview: https://platform.claude.com/docs/en/about-claude/models/overview
- Model deprecations: https://platform.claude.com/docs/en/about-claude/model-deprecations
- Optimizing for cost and intelligence: https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence
- Prompt caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Tool use with prompt caching: https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-use-with-prompt-caching
- Tool search tool: https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
- Programmatic tool calling: https://platform.claude.com/docs/en/agents-and-tools/tool-use/programmatic-tool-calling
- Context editing: https://platform.claude.com/docs/en/build-with-claude/context-editing
- Structured outputs: https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- Vision: https://platform.claude.com/docs/en/build-with-claude/vision
- Service tiers: https://platform.claude.com/docs/en/api/service-tiers
- Usage and Cost API: https://platform.claude.com/docs/en/manage-claude/usage-cost-api
- Workspaces: https://platform.claude.com/docs/en/manage-claude/workspaces
- Advanced tool use: https://www.anthropic.com/engineering/advanced-tool-use
- Writing tools for agents: https://www.anthropic.com/engineering/writing-tools-for-agents
- Effective context engineering: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Sonnet 5 migration notes (thinking default, tokenizer, sampling, high-resolution vision): the `claude-api` skill bundled with Claude Code, `shared/model-migration.md`. Pricing and vision pages above confirm the tokenizer and resolution figures. The thinking default was not re-read on the live migration page.

Vercel and AI SDK, read 2026-09-20:
- AI SDK Anthropic provider: https://ai-sdk.dev/providers/ai-sdk-providers/anthropic
- AI SDK gateway provider: https://ai-sdk.dev/providers/ai-sdk-providers/ai-gateway
- AI SDK `tool()`: https://ai-sdk.dev/docs/reference/ai-sdk-core/tool
- AI SDK `convertToModelMessages`: https://ai-sdk.dev/docs/reference/ai-sdk-ui/convert-to-model-messages
- AI SDK tool calling: https://ai-sdk.dev/docs/ai-sdk-core/tools-and-tool-calling
- Gateway provider options: https://vercel.com/docs/ai-gateway/models-and-providers/provider-options
- Gateway automatic caching: https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching
- Gateway BYOK: https://vercel.com/docs/ai-gateway/authentication-and-byok/byok
- Gateway budgets: https://vercel.com/docs/ai-gateway/observability-and-spend/budgets

Repo and DEV data:
- `supabase/functions/_shared/vana/chat.ts`, `tools.ts`, `persona.ts`, `context-cache.ts`, `env.ts`
- `supabase/functions/_shared/ai/model.ts`, `_shared/meal_analysis/schema.ts`, `analyze-meal-photo/index.ts`, `describe-meal/index.ts`, `ai-coach/index.ts`
- `lib/features/meal_logging/presentation/screens/{log_meal_screen,edit_meal_log_screen,photo_capture_screen}.dart`
- Read-only SQL on DEV: tool-call endings per assistant message since 09-10, stored tool output sizes since 09-14, `vana_calls` for planning since 2026-09-16 18:00 UTC. Small samples (9 to 249 rows), dev and test traffic only.

Unverified, stated as such above: gateway pass-through of `ttl`, `deferLoading`, provider-defined tools, the structured-output mode and `max_tokens: 0`; the token size of a picker result; the Poisson arrival assumption behind the TTL table; the tokenizer of any future Haiku.
