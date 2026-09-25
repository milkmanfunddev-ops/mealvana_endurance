# Vana cost and pricing

Feeds the rejected card mp-341 and the approved cards mp-281, mp-340, mp-342, plus the open caching question mp-316. Researched 2026-09-17. Prices come from the Anthropic pricing page and the Vercel AI Gateway model catalogue, both read today. Usage numbers come from read-only queries on the DEV project's `vana_calls`, `ai_usage`, `vana_messages` and `vana_conversations`. Nothing was deployed or written.

## The question

Lee, on mp-341: at a fixed monthly price, how do athletes get the most use of Vana while the app keeps a healthy profit? Is one credit per turn too tight? Which cost cuts are real?

## Short answer

1. The meter is not the main problem. The cost per turn is. A meal-planning turn costs about 3.2 cents today, three times the 1.5 cents mp-340 assumed, because a turn is 2 to 3 model calls and the first call of almost every real turn reads nothing from the prompt cache.
2. Three defects in prompt assembly cause that, and one explicit cache breakpoint removes most of the damage. Estimated saving: 55 to 65 percent of chat cost.
3. With that fix in, 600 credits a month at one credit per action covers the heavy profile below, costs about $3.90 for that athlete, and keeps blended AI cost near 13 percent of net revenue at the founding monthly price.
4. Openers are free to the athlete, cost 1 to 1.5 cents each, and have no daily cap. That is the largest abuse exposure in the current code.
5. Cheap models on the gateway are 10 to 30 times cheaper per token than Haiku 4.5 but score far lower on multi-turn tool calling. They fit turns that need no tools. Apple's on-device model fits almost nothing Vana does today.

## How thin the data is

Everything below is dev and test traffic. Eight users, of whom three produced general chat and six produced planning chat. Two conversations are the eval script (`scripts/vana-eval/run.ts`) firing a turn every 3 seconds, and I excluded them from cost means. Cache reads have been logged only since 2026-09-15, so the cost figures rest on 120 calls over three days. The brief's figure of "2,126 cached of 21,302" averaged rows from before 09-15 as if they were zero reads. On rows that log a cache read, planning turns read 42.6 percent of input. Treat every usage profile below as an assumption to replace with October data.

## Prices used

| Model (gateway id) | Input | Cache write 5 min | Cache read | Output | Source |
|---|---|---|---|---|---|
| anthropic/claude-haiku-4.5 | $1.00 | $1.25 | $0.10 | $5.00 | [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing) |
| anthropic/claude-sonnet-4.6 | $3.00 | $3.75 | $0.30 | $15.00 | same |
| anthropic/claude-sonnet-5 | $2.00 | $2.50 | $0.20 | $10.00 | same. Newer tokenizer, about 30 percent more tokens for the same text |
| openai/text-embedding-3-small | $0.02 | | | | [gateway catalogue](https://ai-gateway.vercel.sh/v1/models) |

Prices are per million tokens. The gateway adds nothing: "AI Gateway charges no markup and no platform fee on tokens" ([Vercel pricing](https://vercel.com/docs/ai-gateway/pricing)). The ledger confirms it. `ai_usage.cost_usd` for describe-meal averages $0.00769, and list price for its 1,291 input and 254 output tokens is 1,291 x $3 / 1M + 254 x $15 / 1M = $0.00768.

## Unit economics

### What a call costs today

A `vana_calls` row is one athlete turn, not one model call. `chat.ts` logs `totalUsage`, which sums every step of the tool loop (up to 6 steps in planning, 8 in general). Planning turns average one tool call, so a typical turn sends the whole prompt two or three times. `input_tokens` includes cached tokens.

Cost formula per row, upper bound: `(input - cache_read) x $1.25/M + cache_read x $0.10/M + output x $5/M`. It prices every unread token as a cache write, which automatic caching makes true for almost all of them. Pricing them at $1.00 instead gives figures about 18 percent lower.

| Function | n | Mean input | Mean cache read | Mean output | Mean cost | p50 | p90 | Same call with no cache |
|---|---|---|---|---|---|---|---|---|
| vana.chat.meal_planning | 30 | 40,786 | 17,360 | 190 | $0.0320 | $0.0332 | $0.0525 | $0.0417 |
| vana.opener.meal_planning | 40 | 28,115 | 18,218 | 216 | $0.0153 | $0.0163 | $0.0226 | $0.0292 |
| vana.chat.general | 35 | 13,975 | 6,515 | 154 | $0.0107 | $0.0091 | $0.0170 | $0.0147 |
| vana.opener.general | 15 | 13,470 | 7,032 | 162 | $0.0096 | $0.0095 | $0.0133 | $0.0143 |
| describe-meal (Sonnet 4.6) | 34 | 1,291 | | 254 | $0.0077 | | | gateway-reported |
| analyze-meal-photo (Sonnet 4.6) | 24 | 2,866 | | 292 | $0.0130 | | | gateway-reported |
| ai-coach insight (Sonnet 4.6) | 7 | 430 | | 51 | $0.0021 | | | gateway-reported |
| vana.daynotes | 63 | 912 | | 253 | $0.0022 | | $0.0026 | |
| vana.extract | 81 | 1,423 | | 33 | $0.0016 | | $0.0018 | |
| vana.summary | 2 | 1,609 | | 205 | $0.0026 | | | |
| vana.embed | 616 | 13 | | | $0.0000003 | | | |

One step of a planning call was about 9,800 tokens on 09-15 and is about 15,500 tokens since the afternoon of 09-16, after the write tools and opener changes landed. The prompt grew 58 percent in two days.

### How athletes use it (dev traffic)

| Measure | n | Mean | p50 | p90 | Max |
|---|---|---|---|---|---|
| Athlete turns per planning conversation | 124 | 2.0 | 1 | 4 | 6 |
| Athlete turns per planning conversation that produced a plan | 52 | 2.7 | about 3 | about 5 | 6 |
| Athlete turns per general conversation | 145 | 1.8 | 1 | 2 | 23 |
| Chat turns per user per active day | 25 | 20.4 | 6 | 63 | 120 |
| Chat turns per user per active week | 13 | 39.2 | 13 | 128 | 169 |
| General turns that called no tool | 242 | 55% | | | |

A plan build is one opener plus 3 to 5 turns, so $0.11 to $0.18 today. There were 194 planning openers against 245 planning turns. Openers are close to half of planning calls and none of them debit a credit.

### Three athlete profiles (assumptions)

Counts per week. The typical profile is the mp-340 person with openers and background calls added.

| Profile | Planning turns | Planning openers | General turns | General openers | Describe | Photo | Insights | Extracts | Day notes | Credits per month |
|---|---|---|---|---|---|---|---|---|---|---|
| Light | 3 | 1 | 5 | 3 | 5 | 1 | 2 | 3 | 1 | 69 |
| Typical | 6 | 1 | 20 | 7 | 12 | 4 | 5 | 7 | 2 | 204 |
| Heavy | 12 | 2 | 60 | 14 | 21 | 14 | 7 | 14 | 4 | 494 |

Monthly cost = sum of (count x mean cost) x 52 / 12.

| Profile | Today | After caching fix (lever 1, estimate) | Plus logging on Haiku 4.5 (lever 3, measured price, unproven quality) |
|---|---|---|---|
| Light | $1.11 | $0.62 | $0.46 |
| Typical | $2.86 | $1.64 | $1.20 |
| Heavy | $6.85 | $3.93 | $2.90 |
| Blended 50 / 40 / 10 (assumed mix) | $2.38 | $1.36 | $1.00 |

300 credits spent in the worst way, all on planning turns: 300 x $0.0320 = $9.60 at the mean and 300 x $0.0525 = $15.75 at p90. The mp-340 card says $3.60 against a $9.99 subscription. Both halves of that sentence are out of date. The heavy profile needs 494 credits, so at 300 it runs dry around day 18.

### Revenue per subscriber per month

Apple pays 85 percent under the Small Business Program and otherwise 70 percent in a subscriber's first year, 85 percent after ([Apple](https://developer.apple.com/app-store/small-business-program/), [Apple subscriptions](https://developer.apple.com/app-store/subscriptions/)). Google Play takes 15 percent on auto-renewing subscriptions ([Google](https://support.google.com/googleplay/android-developer/answer/112622)). Net = price x 0.85 or x 0.70. Annual plans are divided by 12.

| Plan | Gross per month | Net at 15% | Net at 30% | Blended AI cost today, share of net (15% / 30%) | After lever 1 | Heavy athlete today, at 15% |
|---|---|---|---|---|---|---|
| $24.99 monthly | $24.99 | $21.24 | $17.49 | 11% / 14% | 6% / 8% | 32% |
| $199.99 annual | $16.67 | $14.17 | $11.67 | 17% / 20% | 10% / 12% | 48% |
| Founding $12.49 monthly | $12.49 | $10.62 | $8.74 | 22% / 27% | 13% / 16% | 65% |
| Founding $99.99 annual | $8.33 | $7.08 | $5.83 | 34% / 41% | 19% / 23% | 97% |
| Coach tier $20.99 | $20.99 | $17.84 | $14.69 | 13% / 16% | 8% / 9% | 38% |
| Coach tier $17.49 | $17.49 | $14.87 | $12.24 | 16% / 19% | 9% / 11% | 46% |

The founding annual plan is the tight one, and those subscribers keep the price for life. RevenueCat's 2026 report puts 68 percent of Health and Fitness subscriptions on annual plans ([RevenueCat](https://www.revenuecat.com/state-of-subscription-apps)), so expect most founders there.

### What margin to aim for

| Source | Figure |
|---|---|
| Aleph and Benchmarkit, 342 B2B SaaS companies, 2026 | Median software gross margin 80%, usage-priced products 62% ([Aleph](https://www.getaleph.com/answers/saas-gross-margin-2026)) |
| ICONIQ State of AI 2026 | AI product gross margin 45% in 2025, 53% projected for 2026 ([ICONIQ](https://www.iconiq.com/growth/reports/state-of-ai-2026)) |
| Bessemer AI pricing playbook, Feb 2026 | AI products 50 to 60%, against 80 to 90% for SaaS ([Bessemer](https://www.bvp.com/atlas/the-ai-pricing-and-monetization-playbook)) |
| Duolingo FY25 letter | 72.2% for the year, guided to about 69% "driven primarily by expanding access to AI-powered features for all users" ([SEC](https://www.sec.gov/Archives/edgar/data/1562088/000162828026012513/q4fy25duolingo12-31x25shar.htm)) |

A consumer subscription app with AI inside should aim for 65 to 75 percent gross margin after store fees. Hosting, RevenueCat, Sentry and support take some of the remainder (not measured here, assume 5 to 10 percent of net). That leaves an AI budget of 15 to 20 percent of net revenue blended, with no single athlete above 50 percent. At founding annual that budget is $1.06 to $1.42 a month. Today's blended $2.38 misses it. After lever 1 the estimate of $1.36 fits.

## Why the cache reads so little

`chat.ts` sets Anthropic's automatic caching for the whole call (`CACHE_PROVIDER_OPTIONS`, mp-311). Automatic mode puts one breakpoint on the last block of the request. A later request hits only if its prefix matches an entry some earlier request wrote: "It is looking for prior writes, not for stable content" ([Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)). No entry is ever written at the end of the tools or the persona. When anything in the messages changes, the miss covers the entire prompt, including the 13,000 or so tokens that are identical for every athlete.

The log shows the pattern. A cold planning opener reads 15,543 of 31,390 input tokens. That is step 2 reading what step 1 wrote, and step 1 reading nothing. The same is true of most mid-conversation turns: conversation `1a24f2bf` read 15,204 of 32,421 one minute after its opener. The eval conversations, which send plain text with no Situation and call no tools, read 98 percent. Caching works. The prefix is what breaks, in three places.

1. The Situation line. `withSituation` appends `[SITUATION ...]` to the newest user message at send time. The stored row holds the message without it. On the next turn that message is replayed without the line, so every entry the last turn wrote has a different hash. Real-device conversation `2ceb03` shows it: 12,890 input and 6,342 read, 46 seconds after the previous turn.
2. The opener's synthetic user message is never stored. The opener sends `[user: opener text]`. Turn 1 replays `[assistant: opener reply, user: message]`. Nothing after the system prompt matches.
3. Context invalidation. Every plan write calls `invalidateContext`, the next turn rebuilds the Doll, and the system prompt is one string holding persona and Doll. A changed Doll changes the system block and everything after it. Planning turns write on nearly every turn.

A smaller fourth cause: `conversationMessages` rebuilds assistant messages from stored `parts`, so the replay differs from what the tool loop sent. In mp-311's own sample, turn 2 read 4,980 tokens, turn 1's first step, not the 5,906 of its second.

The gateway passes `cache_control` through. Manual markers on messages, system parts and tools are supported ([Vercel automatic caching](https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching), [AI SDK Anthropic provider](https://ai-sdk.dev/providers/ai-sdk-providers/anthropic)). Cache reads bill at $0.10 with no markup (catalogue). Haiku 4.5 needs at least 4,096 tokens before a breakpoint or it caches nothing and reports no error.

## Metering options

| Option | For | Against | Abuse exposure | Wallet code |
|---|---|---|---|---|
| (a) One credit per action, bigger allowance | One env var. Sheet copy stays true ("1 token"). Athletes already understand it | A chip tap costs the same as a question. The number is arbitrary | Bounded by the allowance. Worst case = allowance x dearest action | None. `AI_MONTHLY_ALLOWANCE` |
| (b) Cost-weighted credits (planning 3, photo 2, general 1) | Tracks real cost | Charges most for planning, the feature the subscription sells. Breaks the "each analysis costs 1 token" copy. Weights go stale as costs fall | Same as (a), tighter | `creditCost` already takes `AI_COST_<FN>`, but chat has one function name for both kinds, so it needs a code change |
| (c) No visible meter, fair-use cap, slow down or downgrade at the cap | What ChatGPT and Gemini do. Athletes never count | Needs a cheaper model to fall back to, which does not exist yet. A hidden cap that stops someone mid-plan feels worse than a visible one | Bounded by the cap | Wallet stays as the counter. New: fallback path, copy |
| (d) Unlimited, rate limits only | Simplest message | `rate-limit.ts` allows 4 turns per 10 seconds, which is 34,560 a day. No monthly bound | Unbounded. One script on a $0 trial could spend hundreds of dollars | Remove debits |

No fitness or nutrition app I checked publishes an AI cap: MacroFactor ([help](https://help.macrofactorapp.com/en/articles/258-ai-food-logging)), Fuelin at $29 a month ([pricing](https://fuelin.superwall.app/sw-web-pricingpage)), Strava Athlete Intelligence ([support](https://support.strava.com/en-us/articles/15401629-athlete-intelligence-on-strava)), MyFitnessPal Premium+ at $24.99 ([pricing](https://www.myfitnesspal.com/premium)), Oura Advisor ([support](https://support.ouraring.com/hc/en-us/articles/39512345699219-Oura-Advisor)). Most of those are one-shot features, not open chat. The chat products do cap, and differ on what happens next. Gemini: "If you have a Google AI subscription and reach your limit, you can continue your conversation with Flash-Lite" ([Google](https://support.google.com/gemini/answer/16275805)). Claude Pro resets a session limit every five hours, adds a weekly limit, shows a usage meter, and stops until reset or paid credits ([Anthropic support](https://support.claude.com/en/articles/8325606-what-is-the-pro-plan)). Secondary sources say ChatGPT Plus drops to a mini model at its limit.

Vana is already close to (c). The token pill appears only on the meal-logging screens. The chat shows nothing until the wallet is empty, then the mp-342 strip. The recommendation is (a) sized so almost nobody reaches it, moving to (c) once a fallback model exists.

## Cost levers, ranked by saving per unit of effort

Savings are against today's blended $2.38. For the typical athlete, chat turns and openers are about 75 percent of cost and meal logging about 22 percent.

| # | Lever | Saving on its line | Saving on total | Effort | Confidence |
|---|---|---|---|---|---|
| 1 | Explicit cache breakpoints on the static prefix and the Doll | 55 to 65% of chat | about 40% | S to M | High. Pricing is fixed and the eval conversations already show 98% reads |
| 2 | Make the replay byte-stable (store the Situation line and the opener message, replay assistant steps as sent) | a further 8% of today's chat cost | about 6% | M | Medium |
| 3 | Meal logging off Sonnet 4.6 | 65% on Haiku 4.5 (measured $0.0027 and $0.0043), 80% on Gemini 3 Flash (computed), 13% on Sonnet 5 (computed) | 10 to 20% | M, mostly the eval | Low until an eval exists. Haiku was tried and reverted on 07-30 for quality |
| 4 | Fewer steps and a smaller prompt | 5 to 15% of chat after lever 1 | about 5% | M | Medium |
| 5 | Rule-based routing of no-tool general turns to a cheap model | about 25% of general chat | about 6% | M to L | Low. Voice risk |
| 6 | Apple on-device model | under 5% of total | under 5% | L | Low |
| 7 | Batch API for background calls | 50% of $0.07 a month | about 1% | M | High, and not worth doing |

### Lever 1: cache the static prefix

Split the system prompt into two system messages, persona then Doll, and put `cacheControl` on each. Tools render before the system prompt, so the persona marker covers both. Keep automatic mode for the tail. That uses three of the four breakpoint slots. Pin the provider with `providerOptions.gateway.only: ['anthropic']` and send an `x-session-affinity` header per conversation, because a request the gateway routes to Bedrock or Vertex cannot read a cache written at Anthropic.

Estimate for a planning turn, using the measured 40,786 input tokens over about 2.6 steps. After the fix, step 1 reads the static 13,500 and writes the Doll and history, about 2,500. Each later step reads everything before it and writes about 2,000 of tool output. Written about 5,700, read about 35,100. Cost = 5,700 x $1.25/M + 35,100 x $0.10/M + 190 x $5/M = $0.0071 + $0.0035 + $0.0010 = $0.0116, down 64 percent from $0.0320. The same method gives $0.0073 for a planning opener (down 52 percent), $0.0050 for a general turn (down 53 percent) and $0.0045 for a general opener.

Two cautions. The static prefix is shared across athletes, so it stays warm only while someone uses Vana every five minutes. With few subscribers, the first turn of many conversations will pay the 1.25x write, $0.017 for planning. A 1 hour TTL costs 2x to write and pays back after two reads. Decide on TTL from October traffic. The general prefix is near Haiku's 4,096-token floor. If general reads come back zero, mark only the end of the Doll for that kind.

### Lever 4: what is in the 15,500 tokens

Measured by running `makeVanaTools` and serialising each schema: planning sends 43 tools, 29,500 characters of JSON, led by `suggestMeals` at 2,404 and five others near 1,400. General sends 30 tools, 20,900 characters. The planning persona is 15,100 characters and the general one 8,900. The stored Doll is about 1,500 characters rendered, inside its mp-314 budget. Anthropic adds 496 tokens of tool-use system prompt. My split of the 15,500, not tokenised: tools about 8,000, persona about 3,800, Doll and opener text and Situation about 3,200, system overhead 500.

The Doll is small. Tools and persona are the bulk, and after lever 1 they cost a tenth as much, so trimming them is worth about 5 percent. Do not vary the tool list per turn to save tokens. Anthropic's invalidation table says a changed tool definition invalidates the whole cache. The better saving is steps. Every opener makes one tool call, so it sends the prompt twice. Fetching that data on the server before the call and putting it in the opener message halves opener cost.

### Lever 5: cheaper models on the gateway

The catalogue lists 231 tool-calling language models today. The cheapest credible ones:

| Model | Input | Output | Cache read | Vision | BFCL v4 overall | BFCL multi-turn |
|---|---|---|---|---|---|---|
| anthropic/claude-haiku-4.5 (today) | $1.00 | $5.00 | $0.10 | yes | 68.7%, rank 6 | 53.6% |
| google/gemini-3-flash | $0.50 | $3.00 | $0.05 | yes | not listed | |
| google/gemini-3.1-flash-lite | $0.25 | $1.50 | $0.03 | yes | not listed | |
| openai/gpt-5-mini | $0.25 | $2.00 | $0.025 | yes | 55.5% | 27.5% |
| openai/gpt-5.6-luna | $0.20 | $1.20 | $0.02 | yes | not listed | |
| deepseek/deepseek-v4-flash | $0.13 | $0.26 | $0.028 | no | not listed | |
| google/gemini-2.5-flash-lite | $0.10 | $0.40 | $0.01 | yes | 36.9% | 13.5% |
| openai/gpt-4.1-nano | $0.10 | $0.40 | $0.025 | yes | 33.1% | 23.6% |
| openai/gpt-5-nano | $0.05 | $0.40 | $0.005 | yes | 51.5% | 34.5%, 10 s mean latency |
| amazon/nova-2-lite | $0.30 | $2.50 | $0.075 | yes | 27.1% | 2.1% |
| alibaba/qwen3.7-flash | $0.03 | $0.13 | $0.006 | yes | not listed | |
| anthropic/claude-3-haiku | $0.25 | $1.25 | $0.03 | yes | not listed | |

Prices from the [gateway catalogue](https://ai-gateway.vercel.sh/v1/models), read 2026-09-17. Scores from the [Berkeley Function Calling Leaderboard](https://gorilla.cs.berkeley.edu/leaderboard.html) v4, last updated 2026-04-12, function-calling mode. Models released after April are not on it.

Haiku 4.5 is sixth on that board overall and well ahead of every cheap model on multi-turn tool use. A planning turn is multi-turn tool use. Keep planning on Haiku.

mp-002 forbids a classifier call before a turn, so the router decides from facts the server already has:

1. Kind is `general`. Planning never routes.
2. The message is under 200 characters and matches no write or plan verb from a fixed list (log, add, change, delete, plan, swap, move, remember, forget, cancel).
3. The Situation is not a screen where the athlete is editing something.
4. The previous assistant turn in this conversation called no tool.

If all four hold, call the cheap model with the persona, the Doll, the history, and one tool, `needVana`, whose description says to call it whenever the answer needs the athlete's data, an app change, or anything the model is unsure of. If the model calls it, discard the step and rerun on Haiku with the full tools. The wasted cheap call costs about $0.002. 55 percent of general turns in dev called no tool, which is the ceiling on the routed share. At a 40 percent routed share and gemini-3.1-flash-lite prices, a routed turn costs about $0.0019 (7,000 input tokens at $0.25/M plus 150 output at $1.50/M), so the average general turn falls from $0.0050 after lever 1 to 0.6 x $0.0050 + 0.4 x $0.0019 = $0.0038.

The risks are voice and privacy. The persona is tuned on Haiku. Run `scripts/vana-eval` with `VANA_CHAT_MODEL` set to each candidate before building anything. Health data would go to a second provider, so filter on the catalogue's `zdr` field. This lever also gives option (c) its fallback model.

### Levers 6 and 7: on-device models and batch

On-device models have their own section below. They cannot run a Vana chat turn, and the calls they could take cost about $0.07 a month per athlete.

The gateway exposes batch at 50 percent off with up to 24 hours of latency ([Vercel batch](https://vercel.com/docs/ai-gateway/models-and-providers/batch-processing)). Extract, day notes and summaries cost the typical athlete about $0.07 a month in total. The extract feeds the next opener, which can open minutes later (mp-278, mp-288), so a 24 hour window breaks it. Skip.

## On-device models

### Apple Foundation Models

| Topic | Fact | Source |
|---|---|---|
| Devices | "iPhone 16 models or later, iPhone 15 Pro, iPhone 15 Pro Max, iPhone Air", plus iPads and Macs with M1 or later. The person must have Apple Intelligence turned on | [Apple support](https://support.apple.com/en-us/121115) |
| OS | iOS 26.0 or later. Press reports say iOS 27 shipped on 2026-09-14 | [framework docs](https://developer.apple.com/documentation/foundationmodels) |
| Model | "a large language model with 3 billion parameters, each quantized to 2 bits" | [WWDC25 session 286](https://developer.apple.com/videos/play/wwdc2025/286/) |
| Context | 4,096 tokens per session, prompt and reply together. WWDC26 sample code shows 8,192 on iOS 27 "newer devices", which Apple does not define | [TN3193](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window), [WWDC26 session 319](https://developer.apple.com/videos/play/wwdc2026/319/) |
| Tools and structured output | The `Tool` protocol and `@Generable` both work. Apple advises 3 to 5 tools, and tool schemas count against the context | TN3193 |
| What it is for | "It's not designed for world knowledge or advanced reasoning, which are tasks you might typically use server-scale LLMs for" | WWDC25 session 286 |
| Cost and limits | No token fee. Unlimited in the foreground, rate limited in the background | framework docs |
| Availability check | `SystemLanguageModel.default.availability`, with reasons `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`. "Always verify model availability first, and plan for a fallback experience" | [Apple](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) |
| Private Cloud Compute, new in iOS 27 | A server model with a "larger 32K-token context size and stronger reasoning". No API key and no token cost to the developer. Each person "gets a daily request limit" and can raise it with iCloud+. Needs a managed entitlement with eligibility rules, a network connection, and an Apple Intelligence device | [Apple PCC doc](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute) |

How many athletes qualify is unknown. Counterpoint counts over 450 million capable iPhones shipped through Q1 2026 ([Counterpoint](https://counterpointresearch.com/en/insights/apple-has-shipped-over-450-million-apple-intelligence-capable-iphones)). Against roughly 1.4 to 1.5 billion active iPhones that is near 30 percent, and that division is mine, not a published figure. TelemetryDeck's indie-app sample shows eligible models at about 70 percent of its top ten models in August 2026 ([TelemetryDeck](https://telemetrydeck.com/survey/apple/iPhone/models/)), which is an upper bound. No source says how many people switch Apple Intelligence on. The app's own analytics by device model is the number to use.

Flutter has no mature wrapper. The most used package is `flutter_local_ai` (0.0.16, 48 likes). `apple_foundation_models` (0.3.2) and `foundation_models_framework` (0.2.1) are smaller, all are pre-1.0, and none mentions iOS 27. The realistic path is a Swift plugin of our own: a `LanguageModelSession` behind a Pigeon or MethodChannel API, an EventChannel for streaming, and tool calls routed back to Dart.

What fits in 4,096 tokens:

| Vana call | Input today | Fits on device | Note |
|---|---|---|---|
| Planning turn or opener | 15,500 per step, 43 tools | No | Four times the window before history |
| General turn | 6,200 per step, 30 tools | No | The persona and Doll alone are about 3,000 tokens |
| Day notes | 912 in, 253 out | Yes | Athlete-facing copy, so voice quality matters |
| Extract, episode, summary | 1,400 to 1,600 in | Yes, tight | They run on the server after the client goes idle. Moving them means the phone must do the work before it sleeps, and the rows must sync up |
| Describe-meal | 1,291 in | Fits, wrong job | Estimating macros from a description is world knowledge, which Apple says the model is not for |
| Photo analysis | image | No on iOS 26. iOS 27 adds image input, untested | Same objection |

The calls that fit cost the typical athlete about $0.07 a month on Haiku. Moving them needs a Swift plugin, a second prompt set, a fallback for every other device, and evals. That is weeks of work to save cents.

Private Cloud Compute is the part worth watching. 32K tokens would hold a general turn with a trimmed tool list, at no token cost. It needs iOS 27, an Apple Intelligence device, an entitlement Apple grants, and a per-person daily limit Apple sets and does not publish. It cannot be the only path, so it would sit behind the same router as lever 5 as one more cheap route. Revisit in Q1 2027 once iOS 27 adoption is known.

### Android

Gemini Nano through ML Kit GenAI is in beta, "not subject to any SLA". Input must be under 4,000 tokens, inference runs only while the app is in the foreground, and per-app battery quotas apply ([Google ML Kit GenAI](https://developers.google.com/ml-kit/genai)). The Prompt API covers Pixel 9 and later and a few Galaxy flagships. The first-party docs describe no tool calling. No source gives a device share. A flagship-only list suggests single digits. Not worth building for.

## Recommendation

### Ship on Oct 1

1. `AI_MONTHLY_ALLOWANCE=600` on prod if lever 1 is deployed by then, 400 if not. One credit per debiting action, as now. 600 covers the heavy profile (494) with 20 percent headroom and the typical athlete uses a third of it. Worst case, all planning: 600 x $0.0116 = $6.96 after lever 1, against 600 x $0.0320 = $19.20 before it. Env only.
2. Trial grant of 150 credits instead of the full allowance. `handler.ts` already has `period_type` where it calls `monthlyAllowance`. A Day 0 canceller, 55 percent of trial cancellations per RevenueCat, then costs at most 150 x $0.032 = $4.80 and realistically under $1. Effort S. This amends mp-281 clause 3.
3. Daily opener cap. Openers cost $0.0096 to $0.0153, debit nothing, and the only limit is 3 a minute, which is 4,320 a day and $41 to $66 a day from one account. Add a 24 hour window of 40 to `rate-limit.ts`. Effort S.
4. Daily chat ceiling of 150 turns through the same mechanism, as a script guard. Dev p90 is 63.
5. Keep the chat meter invisible until empty, as mp-342 built it.
6. Correct mp-340's text: $0.032 per planning turn, and the price is $24.99 or $12.49, not $9.99.

### October cost work, in order

| Order | Work | Expected saving on total AI cost | Effort |
|---|---|---|---|
| 1 | Log what is missing (list below) | none, it measures the rest | S |
| 2 | Lever 1, explicit breakpoints, provider pin, session affinity. Answers mp-316 with yes | about 40% | S to M |
| 3 | Opener and chat daily caps, trial grant | bounds the worst case | S |
| 4 | Lever 2, byte-stable replay | about 6% | M |
| 5 | Openers fetch their data before the call, one step instead of two | about 5% | M |
| 6 | Meal logging eval on 50 labelled meals, then move to the cheapest model that passes | 10 to 20% | M |
| 7 | Router eval with `scripts/vana-eval`, then build if the voice holds | about 6%, and it enables option (c) | M to L |

### Safe to decide now, and what needs production data

Safe now: levers 1 and 2, the caps, the trial grant, the logging, keeping planning on Haiku, skipping batch and on-device.

Needs October data: the allowance number after the first month, 5 minute against 1 hour cache TTL, whether to route, the real mix of light, typical and heavy athletes, and whether a dollar ceiling per athlete should replace the credit count.

### Log from day one

`vana_calls` lacks five things. Cache write tokens (`inputTokenDetails.cacheWriteTokens`). Step count (`steps.length`, already in the console log). The gateway's own charge (`gatewayCostUsd(providerMetadata)`, which the meal functions record and chat does not). Whether the turn debited a credit. Whether the message was a chip tap or typed. Add the subscriber's plan and trial state at call time, so cost per athlete joins to revenue per athlete. With those, one query a week gives cost per subscriber by plan, the cache hit rate on step 1, and the share of turns a router could take.

## Open questions for Lee

1. Allowance on Oct 1. (a) 600 with lever 1 deployed first. (b) 400 now, raise to 600 when lever 1 ships. (c) stay at 300.
2. Trial week grant. (a) 150 credits. (b) the full allowance, as mp-281 clause 3 says. (c) 300.
3. Openers. (a) free with a daily cap of 40. (b) free with no cap, as now. (c) debit a credit after the first 5 a day.
4. At an empty wallet, once a cheap model has passed the eval. (a) keep the hard stop and top-up strip. (b) general chat continues on the cheap model, planning stops. (c) everything continues on the cheap model.
5. Top-up packs of 50 and 250. (a) keep both. (b) keep only 250. (c) remove packs and rely on the allowance.
6. AI cost target as a share of net revenue. (a) 15%. (b) 20%. (c) 25%.
7. Meal logging model. (a) run the eval, move if it passes. (b) stay on Sonnet 4.6 whatever the eval says. (c) move to Sonnet 5 now for 13% with no eval.
8. Founding annual at $99.99 nets $7.08 a month and lasts for life. (a) keep it. (b) keep it, with a 400 credit allowance on that plan. (c) raise the founding annual price before Oct 1.

## Sources

- Anthropic pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Anthropic prompt caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Vercel AI Gateway pricing: https://vercel.com/docs/ai-gateway/pricing
- Vercel AI Gateway model catalogue (JSON): https://ai-gateway.vercel.sh/v1/models
- Vercel automatic caching: https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching
- Vercel batch processing: https://vercel.com/docs/ai-gateway/models-and-providers/batch-processing
- Vercel cost-aware routing guide: https://vercel.com/kb/guide/cost-aware-model-routing-with-ai-gateway
- AI SDK Anthropic provider, cache control: https://ai-sdk.dev/providers/ai-sdk-providers/anthropic
- Berkeley Function Calling Leaderboard v4: https://gorilla.cs.berkeley.edu/leaderboard.html
- Apple Small Business Program: https://developer.apple.com/app-store/small-business-program/
- Apple subscriptions: https://developer.apple.com/app-store/subscriptions/
- Google Play service fees: https://support.google.com/googleplay/android-developer/answer/112622
- RevenueCat State of Subscription Apps 2026: https://www.revenuecat.com/state-of-subscription-apps
- RevenueCat 2026 trends (Day 0 cancellations): https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026
- ICONIQ State of AI 2026: https://www.iconiq.com/growth/reports/state-of-ai-2026
- Bessemer AI pricing playbook: https://www.bvp.com/atlas/the-ai-pricing-and-monetization-playbook
- Aleph SaaS gross margin 2026: https://www.getaleph.com/answers/saas-gross-margin-2026
- Duolingo Q4 FY25 shareholder letter: https://www.sec.gov/Archives/edgar/data/1562088/000162828026012513/q4fy25duolingo12-31x25shar.htm
- Google Gemini app limits: https://support.google.com/gemini/answer/16275805
- Claude Pro plan: https://support.claude.com/en/articles/8325606-what-is-the-pro-plan
- Apple Intelligence device requirements: https://support.apple.com/en-us/121115
- Apple Foundation Models framework: https://developer.apple.com/documentation/foundationmodels
- Apple TN3193, context window: https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window
- Apple Private Cloud Compute for apps: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- WWDC25 session 286: https://developer.apple.com/videos/play/wwdc2025/286/
- WWDC26 session 319: https://developer.apple.com/videos/play/wwdc2026/319/
- Counterpoint, Apple Intelligence capable iPhones: https://counterpointresearch.com/en/insights/apple-has-shipped-over-450-million-apple-intelligence-capable-iphones
- TelemetryDeck iPhone models: https://telemetrydeck.com/survey/apple/iPhone/models/
- Google ML Kit GenAI: https://developers.google.com/ml-kit/genai

Not verified from a first-party page: ChatGPT message limits, WHOOP Coach, Runna and Duolingo Max caps, the share of iPhone owners with Apple Intelligence on, the share of Android devices with Gemini Nano, and Apple's daily Private Cloud Compute limit. The Apple on-device rows other than Private Cloud Compute, the comparable-app survey and the margin benchmarks were gathered by two research subagents from the pages linked. I opened the Private Cloud Compute page, the Anthropic and Vercel pages, the gateway catalogue and the leaderboard data myself.
