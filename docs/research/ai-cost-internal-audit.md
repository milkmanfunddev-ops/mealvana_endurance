# AI cost: internal audit

Audited 2026-09-20 on branch `mealplanning`. Read-only: code, plus SELECT queries on the DEV project (`vlmtsdzpnjnavdgytcmi`). Nothing was deployed, written or built. Companion to `docs/research/vana-cost-and-pricing.md`; what that document already reports is not repeated here unless there is new detail.

Dev data is thin and test-heavy (8 users, 3 to 6 of them active in chat). Every dollar figure below is an estimate built from the pricing document's prices and its "typical athlete" profile ($2.86 a month today). Token counts from characters use chars / 4 for prose and chars / 3.5 for JSON. Claims I could not check are marked "unverified".

## Ranked summary

Ranked by saving per unit of effort. "Guardrail" means it bounds abuse or a leak, with no saving in normal use.

| # | Finding | Where | Cost effect | Effort | Confidence |
|---|---|---|---|---|---|
| 1 | A meal picker sends 24 extra full meal records to the model, and every later turn replays them | `tools.ts:31,142` | About 10,000 tokens per picker per step. 35 to 45% of planning input tokens since 09-16. $0.17 to $0.34 a month typical | S | High |
| 2 | The loop runs a second model step after `askChoice`, and after a silenced `saveFeedback`, whose output is empty or thrown away | `chat.ts:356` | Every opener pays one wasted step: 10% of opener cost today, about 22% after the caching fix. About $0.05 to $0.10 a month | S | High |
| 3 | A chat turn with an empty message and a `conversation_id` runs the model, debits nothing, and inserts a duplicate user row | `vana-chat/index.ts:53`, `chat.ts:285,325` | Guardrail. Free turns at 4 per 10 s | S | High |
| 4 | `send-nutrition-plan-email` and `upload-all-data` are deployed on dev with `verify_jwt=false` and have no auth in code | function `index.ts` files | Guardrail. Open Resend relay, and service-role writes for any `user_id` | S | High on dev, prod unverified |
| 5 | Day notes regenerate all seven days on any plan edit, the stale poll can start a second generation, and the endpoint regenerates a fresh plan on request | `daynotes.ts:52-66`, `plan.ts:171`, `home_service.dart:53` | Dev: 3.7 calls per user-day, 20 of 63 within two minutes of the one before. About $0.05 to $0.10 a month | S to M | High |
| 6 | All three Food tabs build at app launch: four or more `vana-action` calls, one of which builds the full athlete context and can generate day notes | `tabs_screen.dart:264`, `food_screen.dart:113` | About 30 queries, 2 weather fetches and sometimes a Haiku call per launch, for athletes who never open Food | S to M | High |
| 7 | The rate limiter counts finished calls only, so parallel requests all pass. Four model paths have no limiter at all | `rate-limit.ts:19-27` | Guardrail | S | High |
| 8 | `parse-meal-plan` is live on dev with no source in the repo: Sonnet 4.6, 200,000 characters of input, no output cap | deployed function | Guardrail. Up to about $0.20 a call for one credit | S | High on dev, prod unverified |
| 9 | Plan dumps and day guidance go to the model in full too | `tools.ts` (draftWeek, sameAsLastTime, getBatch, dayGuidance) | 600 to 3,000 tokens per call, replayed. Same fix as #1 | S | Medium |
| 10 | Portrait photos bill a third more vision tokens, and one capture screen still uses 1200 px | `photo_capture_screen.dart:65` and three pickers | About $0.002 per photo, $0.04 a month typical | S | Medium |
| 11 | Picker messages are stored twice (`parts` and `metadata.ui_parts`), now 24 KB compressed each | `chat.ts:370` | Storage and conversation-load payload grew 5x on 09-16 | S | High |
| 12 | `rememberFact`, `saveFeedback` and the write rules are each spelled out two or three times across persona and tool descriptions | `persona.ts:18,19,25-32,59,67`, `tools.ts` | About 1,000 duplicate tokens per step. $0.001 per step today, a tenth of that after the caching fix | M | Medium |
| 13 | Planning turns carry 13 write tools and WRITE_RULES, about 3,000 tokens, never called from planning on dev | `tools.ts:114`, `persona.ts:35` | Same order as #12. Thin sample | M | Low |
| 14 | 82% of database execution time on dev is Realtime WAL polling, for two published tables | `credits_repository.dart:125` | Database CPU, plus one Realtime connection per signed-in user | M | Medium |
| 15 | Per-turn query count: about 30 with a reused context, about 55 with a rebuilt one, and 58 of 67 recent conversations had no stored context | `chat.ts:285-345`, `context.ts:47-98` | Latency and database load, not tokens | M | Medium |
| 16 | Client chatter: one call per shopping checkbox, two calls per shopping read, Kroger match-all uncached, `get_plan` on every sheet open | several, section E | Edge invocations and Kroger's daily budget | S each | High |
| 17 | `DRY_RUN=1` in the changelog script still calls Sonnet. Archived image scripts default to the whole library | `scripts/changelog/generate_and_publish.mjs:105` | Cents per run | S | High |

## A. Tokens per turn

### A1. The picker's "Show more" tail goes to the model (rank 1)

`supabase/functions/_shared/vana/tools.ts:31` sets `MORE_TAIL = 24`. `suggestMeals` (`tools.ts:142`) returns `{ kind: 'meal_picker', meals, more, ... }`, where `meals` is 4 to 6 full `MealRef` records and `more` is up to 24 further full records for the app's "Show more" button (commit `2f619269`, 2026-09-16). No tool in the file defines `toModelOutput`, so the model receives exactly what the app receives. `compactMeal` (`tools.ts:42`), whose comment says "What the model sees for a meal", is not applied to this output. Each record carries `photo`, `image`, `imageTiles`, `attribution`, `ingredients`, `swaps`, `allergens`, `dietsOk` and `score`, none of which the model needs to write two sentences.

The output is stored in `vana_messages.parts`, and `conversationMessages` plus `convertToModelMessages` (`chat.ts:154,345`) replay it on every later turn, up to the 40-message verbatim cap.

Evidence:

```sql
select 'with_more' k, count(*) n, round(avg(length((e.p->'output')::text))) avg_total,
       round(avg(length((e.p->'output'->'more')::text))) avg_more,
       round(avg(length((e.p->'output'->'meals')::text))) avg_meals
from vana_messages m, jsonb_array_elements(m.parts) e(p)
where m.role='assistant' and jsonb_typeof(m.parts)='array'
  and e.p->>'type'='tool-suggestMeals' and e.p->'output' ? 'more';
-- with_more: n=15, avg_total 41,381 chars, avg_more 34,719, avg_meals 6,495
-- without_more (before 09-16): n=202, avg_total 3,619 chars
```

A picker result grew from about 3,600 characters to about 41,400, roughly 1,000 tokens to 11,000. Input tokens per planning call, by position in the conversation, since the tail shipped (eval conversations excluded):

```sql
-- vana_calls, function_name like 'vana.%.meal_planning', created_at > '2026-09-16 16:00',
-- row_number() over (partition by conversation_id order by created_at)
-- call 1 (opener): 31,256   call 2: 38,448   call 3: 53,933   call 4: 72,314   (n = 15, 7, 3, 1)
```

Two steps of a bare prompt are about 31,000 tokens, so calls 2 to 4 carry 7,000, 23,000 and 41,000 extra tokens. In a build of one opener and three picker turns, the three pickers appear in nine model steps: about 90,000 tokens out of roughly 196,000. With today's broken cache, six of those nine appearances bill at the write price: about $0.078 a build. At three pickers a week that is $0.34 a month for the typical athlete and double for the heavy one. After the caching fix each picker still costs one 10,000-token write, so the saving stays near $0.17 a month.

Fix: give `suggestMeals` a `toModelOutput` that returns `meals.map(compactMeal)` and `moreCount`, and pass `{ tools }` to `convertToModelMessages` so the replay uses it as well. The app still gets the full part. Effort S. Confidence high on the mechanism and the sizes, medium on the monthly figure.

### A2. Other large tool results (rank 9)

Same query, grouped by tool, since 09-10:

| Tool | n | Avg output chars | Max |
|---|---|---|---|
| suggestMeals | 29 | 24,893 | 44,280 |
| draftWeek | 1 | 11,011 | 11,011 |
| sameAsLastTime | 2 | 4,877 | 4,877 |
| dayGuidance | 25 | 2,506 | 2,583 |
| getBatch | 9 | 1,058 | 4,758 |

`draftWeek`, `sameAsLastTime`, `getBatch`, `swapMeal` and `updateBatch` return `{ kind: 'batch', plan }` with full plan meals. The model needs id, name, meal type, servings, servings left and the why-line. The same `toModelOutput` approach covers them. `dayGuidance` is called on 11% of general turns (30 of 272) and its 2,500 characters are replayed for the rest of the day's conversation; check which of its fields the answer uses before trimming it.

### A3. Tool definitions, ranked

Measured by building the tool set locally and serialising each description and JSON schema. Planning sends 43 tools, 29,222 characters (about 7,300 tokens). General sends 30 tools, 20,712 characters (about 5,200 tokens).

| Tool | Description | Schema | Total chars | Calls on dev, all time |
|---|---|---|---|---|
| suggestMeals | 343 | 2,005 | 2,348 | 200 |
| rememberFact | 1,084 | 330 | 1,414 | 11 |
| createEvent | 413 | 986 | 1,399 | 0 |
| updateEvent | 176 | 1,197 | 1,373 | 2 |
| logMeal | 393 | 973 | 1,366 | 0 |
| saveFeedback | 545 | 788 | 1,333 | 34 |
| searchMeals | 137 | 1,028 | 1,165 | 7 |
| handOff (general only) | 671 | 438 | 1,109 | 8 |
| updateActivity | 173 | 895 | 1,068 | 0 |
| createActivity | 364 | 685 | 1,049 | 1 |
| setSetting | 449 | 513 | 962 | 26 |
| deletePlan | 584 | 255 | 839 | 0 |
| recordDebrief | 270 | 481 | 751 | 10 |
| draftWeek | 423 | 306 | 729 | 5 |
| sameAsLastTime | 569 | 114 | 683 | 2 |
| the other 28 | | | under 640 each | |

Call counts come from `vana_messages.metadata->'tool_calls'`:

```sql
select tool, count(*) from vana_messages m, jsonb_array_elements_text(m.metadata->'tool_calls') t(tool)
where role='assistant' group by 1 order by 2 desc;
```

`askChoice` (203) and `suggestMeals` (200) are 60% of all tool calls. Never called on dev: `createEvent`, `logMeal`, `updateActivity`, `deletePlan`, `deleteEvent`, `deleteActivity`, `deleteLoggedMeal`, `startNewPlan`, `listActivities`, `recallConversations`, `recallFacts`, `forgetFact`, `swapMeal`, `updateBatch`, `checkCombination`, `proposeRule`, `shoppingList`. The write tools shipped on 09-16 and only 31 planning turns have run since, so their zero is weak evidence.

Rank 13: planning turns ship 13 write tools (events, activities, logMeal, deleteLoggedMeal, deletePlan, startNewPlan, setHomeLocation), about 9,300 characters, plus `WRITE_RULES`, 2,614 characters. That is about 3,000 tokens a step, and the only one of them a planning turn has ever called is `logFromPlan`, once. Before the caching fix that is about $0.004 a step. After it, about $0.0003. Do this only if the caching fix slips. Do not trim the opener's tool list to save tokens: the general persona alone is under Haiku's 4,096-token cache minimum, and a shorter opener prefix would stop sharing the cached prefix with chat turns.

### A4. Persona duplication (rank 12)

`PLANNING_PROMPT` is 15,094 characters: core voice and hard rules 6,400, `WRITE_RULES` 2,614, planning rules 0 to 11 about 6,100. `GENERAL_PROMPT` is 8,945: intro and tool guide 2,142, rules 6,802 including `WRITE_RULES`. The header comment of `persona.ts:1` still says "~700 tokens each"; they are about 3,800 and 2,200.

The same instruction appears more than once:

- `rememberFact`: the tool description (1,084 characters), `persona.ts:18` in CORE (about 1,150) and `persona.ts:67` in the general prompt (about 1,100). Near-identical wording.
- `saveFeedback`: the tool description (545), `persona.ts:19` (about 800) and `persona.ts:59` (about 750).
- `WRITE_RULES` restates the "when to call" text already in the descriptions of `createEvent` (413), `logMeal` (393), `createActivity` (364), `startNewPlan` (355), `deleteEvent` (347) and `deletePlan` (584).

Keeping each rule in one place removes about 4,000 characters from either prompt, about 1,000 tokens a step. Every persona edit needs an eval run, which is why the effort is M. Low priority once the static prefix is cached.

### A5. History replay and the context block

Replay is verbatim up to 40 messages and includes every tool output in full, so A1 and A2 are the replay problem. The rolling summary has run twice on dev.

The rendered context block is about 1,500 characters and inside its budget. New detail on the known invalidation problem:

```sql
select kind, count(*) n, count(*) filter (where context is null) no_ctx
from vana_conversations where created_at > '2026-09-15' group by 1;
-- general: 21 of 27 null.  meal_planning: 37 of 40 null.
```

`invalidateContext` (`context-cache.ts:28`) clears the stored context on every conversation the athlete has, not only the one that wrote. In a planning conversation the only line of the block that a picker tap changes is `PLAN ... N servings left` (`context.ts:129`), and `chat.ts:308` overwrites that line from the draft anyway. Leaving the servings count out of the block for planning conversations would stop plan writes from changing the system prompt at all.

## B. Steps per turn

`vana_calls` has no step count, so steps are inferred from stored tool calls:

```sql
select metadata->>'kind', (metadata->>'opener')::boolean, jsonb_array_length(metadata->'tool_calls') n, count(*)
from vana_messages where role='assistant' and metadata ? 'tool_calls' group by 1,2,3;
```

| | 0 tools | 1 | 2 | 3 or more |
|---|---|---|---|---|
| Planning opener | 1 | 178 | 0 | 0 |
| General opener | 0 | 23 | 0 | 0 |
| Planning turn | 32 | 164 | 42 | 7 |
| General turn | 137 | 108 | 15 | 12 |

Every opener is two model steps. 87% of planning turns are two or more.

### B1. A step runs after `askChoice` and produces nothing (rank 2)

`chat.ts:356` stops only on `stepCountIs(6 | 8)`. After any tool call the SDK sends the whole prompt again. For `askChoice` that second step never writes anything:

```sql
-- assistant messages since 09-10 with at least one tool call: is there a text part after the last tool part?
-- final tool askChoice: planning opener 55, general opener 23, planning turn 12, general turn 4.
-- text after the tool: 0 of 94.
```

201 of 202 openers call exactly one tool, and since 09-10 that tool is always `askChoice`. The same holds for `saveFeedback` when `silenceAfterFeedback` is true (`chat.ts:189,205`): the server drops the model's prose, so the second step is paid for and discarded. `saveFeedback` was the final tool on 30 general turns and text survived on 8.

Cost: the wasted step re-reads about 15,700 tokens for a planning opener and 6,700 for a general one, mostly from cache: $0.0016 and $0.0007. That is 10% of an opener today and about 22% once the caching fix brings an opener down to $0.0073. It also roughly halves the time until an opener finishes. With 8 openers a week the saving is $0.05 to $0.10 a month.

Fix: `stopWhen: [stepCountIs(n), hasToolCall('askChoice'), ...(silenceFeedback ? [hasToolCall('saveFeedback')] : [])]`. Rule 4 of the planning persona asks for `setSetting` and then `askChoice` in one turn; `askChoice` is still last there, so the stop is safe. Effort S.

### B2. Picker turns are two steps by design

`suggestMeals` is followed by about 200 characters of text in 28 of 29 cases, because the persona requires a sentence after the widget. That step is needed. A1 is what makes it expensive. For the app's own chips ("Other options", "Next: lunch") the server could run the search itself and skip the first step, but only 3 of 59 recent planning messages were those chips, so there is no evidence yet that it would pay.

### B3. Client double calls

The sheet and the full screen do not double-request an opener: `vana_companion.dart:452`, `vana_chat_screen.dart:686-692` and `vana_chat_controller.dart:239` guard it, and there are no retry loops on any Vana path (`vana_transport.dart:78-147` is single-shot).

One risk, medium confidence: a moment opener is gated by `(widget.momentStart ?? state.messages.length) >= state.messages.length` (`lib/features/meal_planning/presentation/widgets/vana_companion.dart:441-450`). With `momentStart` null the test is always true. It stops re-firing only because `opened(start)` was persisted, and that write is unawaited and swallows errors (`vana_moment_controller.dart:202-220`). A failed write means a free opener, 1 to 1.5 cents, on every sheet open until the moment is answered. Fix: record the moment key before calling `loadOpener` and gate on it.

## C. Background model calls

```sql
with d as (select user_id, created_at::date d, function_name, count(*) n from vana_calls
  where function_name in ('vana.daynotes','vana.extract','vana.summary','vana.ingredients','vana.embed') group by 1,2,3)
select function_name, count(*) user_days, round(avg(n),1) avg, max(n), percentile_cont(0.5) within group (order by n) p50
from d group by 1;
```

| Call | User-days | Avg per user-day | p50 | Max | Pricing doc assumed |
|---|---|---|---|---|---|
| vana.daynotes | 17 | 3.7 | 2 | 13 | 2 a week |
| vana.extract | 9 | 9.0 | 4 | 39 | 7 a week |
| vana.embed | 35 | 17.7 | 4 | 149 | |
| vana.summary | 1 | 2 | | | |
| vana.ingredients | 1 | 1 | | | |

### C1. Day notes (rank 5)

Four separate problems:

1. `refreshShopping` (`plan.ts:171`) sets `day_notes_stale` on every plan mutation, as do the `confirm_meal_plan` and `plan_set_servings` RPCs. The next `get_home` regenerates all seven days with no check of whether anything a note mentions changed.
2. `ensureDayNotes` (`daynotes.ts:52-57`) calls `refreshDayNotesSoon` on every `get_home` that sees a stale plan. The client polls `get_home` up to three more times at 7 seconds (`lib/features/meal_planning/application/home_service.dart:53-54`). The `inflight` map (`daynotes.ts:21`) only dedupes within one isolate, so a poll that lands before the first generation finishes starts a second. 20 of 63 day-note calls on dev came within two minutes of the previous one for the same user, and 29 within fifteen.
3. `vana-day-notes/index.ts:40-42` calls `generateDayNotes` unconditionally. A direct request regenerates a fresh plan. The limit is 4 a minute, about $12 a day from one Pro account.
4. `have = !!plan.dayNotes[anchorDate]` (`daynotes.ts:54`): a date outside the generated seven waits on a new model call covering that date and the six after it. Moving backwards one day at a time is one call per day. The Plan tab asks for today only, so this needs a caller that passes another date. Unverified whether one exists.

Cost at the dev rate: 3.7 x $0.0022 x about 12 active days = $0.10 a month. The pricing document assumed $0.02.

Fix: claim the regeneration in the database (set `day_notes_at` with a conditional update before calling the model and skip if it moved in the last 60 seconds); have `vana-day-notes` return the stored notes when `day_notes_stale` is false and the anchor date is covered; hash the meal names, servings and the week's sessions into the plan row and skip when the hash is unchanged. Effort S to M.

### C2. Extract at idle

One Haiku call per conversation, guarded by the `read_back_at` claim and `MIN_LINES = 2` (`extract.ts:96-103`). Nine a day on dev reflects many short test conversations. At $0.0016 each this is fine. See "Looked at and found fine" for the client side.

### C3. Embeddings

`writeFact` (`memory.ts:81`) embeds every write before it knows the kind, including settings, which never use the vector for dedupe. Toggling batch cooking calls the embedding model. At $0.0000003 a call the money is nothing; the cost is a gateway round trip on a settings tap. Skip the embed when `kind === 'setting'`. Query embeddings in `searchMeals` (`meals.ts:38`) are not cached either, at the same negligible price.

## D. Model choice per call

| Call site | Model | Output cap | Dev avg out / max |
|---|---|---|---|
| `chat.ts:350` chat and openers | haiku-4-5 | 900 | 163 / 553 |
| `daynotes.ts:34` | haiku-4-5 | 900 | 253 / 367 |
| `extract.ts:58` extract | haiku-4-5 | 400 | 33 / 118 |
| `extract.ts:160` summary | haiku-4-5 | 400 | 205 / 217 |
| `saved-ingredients.ts:96` | haiku-4-5 | 500 | 117 |
| `pantry.ts:41` fridge photo | haiku-4-5 | 400 | |
| `describe-meal/index.ts:151` | sonnet-4.6 | 1,000 | 254 / 383 |
| `analyze-meal-photo/index.ts:202` | sonnet-4.6 | 1,000 | 292 / 613 |
| `ai-coach/index.ts:286` | sonnet-4.6 | 120, temperature 0.5 | 51 / 62 |
| `embeddings.ts:13` | text-embedding-3-small | | |

Nothing new here beyond the pricing document's lever 3. Output caps do not bill, and measured outputs sit well under them. No call site shows a retry or repair loop. `maxRetries` is never set, so the SDK default of 2 applies, but it retries only transport and 5xx errors, which are not billed. `ai-coach` runs on Sonnet for a 50-token line, but nothing in the app calls it (section H).

## E. Client-side waste

### E1. Food tabs build at launch (rank 6)

`lib/shared/widgets/tabs_screen.dart:264` is an `IndexedStack` ("Every tab is built; only one is on screen"), and `lib/features/meal_planning/presentation/screens/food_screen.dart:113-116` is a second one over `PlanTab`, `MealsTab` and `ShoppingTab`. Reaching `/main` therefore fires, before any tap:

- `get_home` (`plan_tab.dart:47`). On the server `homePayload` (`actions.ts:137-147`) runs `buildAthleteContext` (about 25 queries and two Open-Meteo fetches), `dayGuidance`, `getPlan`, `listMemories`, and `ensureDayNotes`, which calls Haiku when today has no note or the plan is stale. The response also returns the whole context and memory list.
- `recent_meals` and two `search_meals` RPCs (`meal_catalog_controller.dart:141`).
- `get_shopping_list` and `list_shopping_lists` (`shopping_list_controller.dart:154-156`).

Every Pro athlete pays this on every launch, including launches where they only look at the Timeline. Fix: build each Food sub-tab on first selection. Effort S to M.

### E2. Photos (rank 10)

Photos are uploaded to Storage and the function gets the path, which is right. Picker settings are `imageQuality: 85, maxWidth: 1000` in `log_meal_screen.dart:1696`, `edit_meal_log_screen.dart:192` and `vana_attach_sheet.dart:70`, but `lib/features/meal_logging/presentation/screens/photo_capture_screen.dart:65` still has `maxWidth: 1200`. None sets `maxHeight`. Anthropic bills about width x height / 750 tokens: a portrait photo at 1000 x 1333 is about 1,780 tokens against 1,000 for 750 x 1000. On Sonnet that is $0.0023 a photo, 18% of the $0.013 call. Fix: `maxWidth: 1000, maxHeight: 1000` on all four. Check the change against the meal-logging eval planned in lever 3, because it shrinks portrait photos. The server does not enforce a size, but Anthropic downsizes anything over 1,568 px, so the worst case is bounded.

### E3. Describe and analyze

`describe-meal` runs only on an explicit Analyze tap (`describe_meal_screen.dart:74`, `log_meal_screen.dart:1608`). There is no keystroke path, and reopening a logged meal does not re-analyse. `_isAnalyzing` is set inside `setState` after validation, so a double tap within one frame can fire two Sonnet calls. `if (_isAnalyzing) return;` as the first line of `_analyze()` closes it.

### E4. Invocation chatter (rank 16)

None of these calls a model. They cost edge invocations and database reads, and the Kroger one spends a shared daily API budget.

- `shopping_list_controller.dart:218-228`: one `vana-action` per checkbox. A 25-line list ticked in the aisle is 25 invocations. Coalesce over 500 ms.
- `shopping_list_controller.dart:135,153-158`: watches the whole plan, so any plan edit re-reads the list with two calls, one of which (`list_shopping_lists`) is only needed when the history sheet opens. Watch the plan id only.
- `kroger_controller.dart:509-510`: "Match all" searches every unapproved line again on each run, with no session cache by (query, store, modality).
- `vana_chat_controller.dart:155,185`: every sheet open runs `get_plan`, including general conversations that have no draft.
- `vana_chat_screen.dart:785`: `refreshDraft()` runs after Browse even when nothing was picked.

## F. Database and edge-function cost

### F1. Realtime polling is most of the database's work (rank 14)

```sql
select round(sum(total_exec_time)) all_ms,
       round(sum(total_exec_time) filter (where query like 'SELECT wal->>%')) realtime_ms
from extensions.pg_stat_statements;
-- 23,081,327 ms total, 19,031,629 ms Realtime (82%), over 4.1 million calls
select string_agg(tablename, ', ') from pg_publication_tables where pubname='supabase_realtime';
-- coach_messages, token_wallets
```

`CreditsController` is `keepAlive` and subscribes to `token_wallets` for every signed-in user (`lib/features/ai_credits/data/credits_repository.dart:125-131`). The wallet changes only after a call the app itself made, or after a purchase the app also knows about. Each signed-in user holds a Realtime connection for it; Supabase Pro includes 500 concurrent connections and bills beyond that. Fix: read the wallet after each debiting call and on foreground, which `refresh()` already does, and drop the subscription. Keep Realtime for coach messages. Unverified: how much of the polling cost scales with subscribers rather than being a fixed per-project loop, and dev's numbers include idle simulators left connected.

### F2. Queries per chat turn (rank 15)

A planning turn with a reused context runs about 30 queries: authenticate, `requirePro`, the credit check, the rate-limit count, `conversationMessages` (2), `ensureConversation`, the context read, `conversationIsNewPlan`, Situation and in-view reads, the user-row insert, `touch` (2), then after the stream `snapshotPlan`, the assistant insert, `touch`, `logCall`, `logAiUsage` and the debit. `loadOpenerInput` (`chat.ts:53-60,335`) adds `getPlanPeriod`, two `getPlan` reads and two stamp reads on every planning turn, only to learn whether a debrief is pending. A rebuilt context adds about 25 more queries and two weather fetches, and A5 shows that rebuilding is the common case. This is latency and connection load, not tokens. Fix: run `loadOpenerInput` on openers only and keep the pending-debrief flag on the conversation row; read `kind`, `context` and `new_plan` in one select.

### F3. Stored messages (rank 11)

`chat.ts:370` writes tool outputs into `parts` and again into `metadata.ui_parts`:

```sql
-- assistant messages whose tool_calls include suggestMeals
-- before the tail: parts 2,619 B + metadata 2,343 B compressed (n = 192)
-- after:           parts 12,400 B + metadata 12,138 B (n = 8); 41,297 and 40,726 chars uncompressed
```

A picker message is now about 24 KB on disk, and about 82,000 characters when the client loads the conversation over PostgREST. `conversationMessages` reads `ui_parts` only for legacy rows that have no `parts`. Stop writing `ui_parts` when `parts` exists. Effort S.

### F4. Retention and indexes

No retention job covers `vana_calls` (1,528 rows, 672 kB), `ai_usage`, `vana_messages` (3.1 MB) or `plan_generation_log` (4,695 rows, 8.7 MB, the largest log). The only cron job is `raw-retention-sweep`. At these row sizes this is not a cost for a year or more; F3 is what makes `vana_messages` grow fast. The rate limiter's count query is served by `jade_calls_user (user_id, created_at desc)`. `carb_loading_plans` shows 7,224 sequential scans and `saved_meals` 2,390, both on tables under 50 rows. No index is missing on any chat path.

## G. Abuse and leak paths

### G1. A free chat turn (rank 3)

`supabase/functions/vana-chat/index.ts:53`: `charged` needs a non-empty message. In `runChat`, a body with a `conversation_id` and no message loads the stored history (`chat.ts:285`), is not an opener because `messages.length > 0`, and runs the model on it. No credit check, no debit. `chat.ts:325` then inserts the last stored user message a second time. The only limit is 4 per 10 seconds. Fix: return 400 when the body is neither an opener nor carries a message. Effort S.

### G2. Open endpoints (rank 4)

The deployed state on dev, read through the management API:

- `send-nutrition-plan-email`: `verify_jwt=false`, and no `getUser` anywhere in `index.ts`. Recipient, subject, body and attachment come from the request (`index.ts:51-52`) and go straight to Resend (`:109-113`). Anyone with the function URL can send mail from the Mealvana domain on the Resend bill.
- `upload-all-data`: `verify_jwt=false`, takes `user_id` from the body (`index.ts:40`) and writes through the service role (`:76-79`). Nothing in `lib/` calls it.

Prod was not inspected. Fix: verify the caller in code in the first, and remove the second from both projects once Lee confirms, since a deletion is not reversible.

### G3. The rate limiter (rank 7)

`rate-limit.ts:19-27` counts `vana_calls` rows, and `chat.ts:374` writes the row in `onFinish`, after the stream ends. Requests sent in parallel all see a count of zero and all pass: twenty at once means twenty model calls. The limiter also fails open on any database error. `pantry_photo` (`actions.ts:89`, Haiku vision, no credit debit), `describe-meal`, `analyze-meal-photo` and `ai-coach` have no limiter at all. Fix: claim a row before the model call and fill in its tokens afterwards, and put the four unmetered paths in buckets. The daily caps the pricing document recommends need the same change to hold.

### G4. Spend visibility

All 673 `vana-chat` rows in `ai_usage` have `cost_usd` null, and `ai_usage` has no rows for extract, day notes, summary, ingredients or embeddings (only `vana_calls` has them), so cost per athlete per day needs a union of two tables with two naming schemes. The pricing document's logging list covers the missing columns. Add: write background calls to `ai_usage` too, or make `vana_calls` the single ledger.

## H. Other waste

### H1. `parse-meal-plan` (rank 8)

Deployed on dev (version 14, `verify_jwt=true`), and the source is not in the repo; its only trace is commit `12005548`. Read through the management API: it takes up to 200,000 characters of text (about 50,000 tokens), sends it to `JADE_MODEL` (Sonnet 4.6) with no `maxOutputTokens`, checks credits but not Pro, and has no rate limit. One call can cost $0.15 of input plus uncapped output, for one credit, from any signed-in account. Nothing in `lib/` calls it. Unverified whether it exists on prod. Fix: delete it from the project, or bring the source back under the same gates as the others.

### H2. Dead client code that still has live endpoints

- `ai-coach`: `AiCoachClient.fetchInsight` (`lib/features/formula_kit/data/ai_coach_client.dart:64-76`) has no callers. The last `ai_usage` row is 2026-09-05. The function is deployed with `verify_jwt=false` and checks the user in code.
- `jade-chat`: `/jade` redirects to `/vana?mode=general` (`app_router.dart:1212-1214`) and `AiCoachChatScreen` is never constructed, but dev shows three `jade-chat` calls in September, the last on 09-14, so an older build or a test still reaches it. Its opener regenerates on every fresh open by design (`ai_coach_chat_repository.dart:242-256`). Retire it on the schedule in `jade-chat/index.ts:5`.

### H3. Scripts (rank 17)

- `scripts/changelog/generate_and_publish.mjs:105` checks `DRY_RUN` after `generateNotes()` has called Sonnet. A dry run costs the same as a real one, a cent or two.
- `scripts/_archived/meal-images/05`, `07`, `08` and `10` run Sonnet 5 or Haiku vision over the whole meal library unless `LIMIT` is set, and print the spend only at the end. They sit under `FROZEN.md` and assert the dev ref.
- `scripts/vana-eval/*` call the real `vana-chat` on dev, assert the dev ref, honour 429s and are never in CI. The pricing document already excludes their conversations.

Shared code: `_shared/vana` is about 4,700 lines. No function imports a large JSON file at module load, and `makeVanaTools` builds its schemas per request. `vana-day-notes` does not import `tools.ts`. Nothing to fix.

## Looked at and found fine

- The client sends only the new message, the conversation id and Situation ids each turn (`vana_chat_repository.dart:130-142`). History is read on the server.
- No Vana path retries automatically and nothing polls a model endpoint. The one timer chain is the bounded stale poll in C1.
- The idle signal: `vana_ambient_conversation_controller.dart:85,140,152` posts `{ idle: true }` on every sheet close and app hide, and re-arms on every open (`:155`). The server claims `read_back_at` and releases conversations under two lines, so a repeat costs an edge invocation and three queries, never a model call.
- `ensure-credits` runs at most once per user per month per device (`credits_controller.dart:136-154`). The balance is never polled.
- `search-catalog` is debounced 300 ms with a two-character minimum (`food_search_controller.dart:273-278`). Meal search is debounced 350 ms and is a PostgREST RPC.
- `get_meal` is `keepAlive` per meal id (`meal_detail_controller.dart:27`).
- `saved-ingredients.ts:110,133`: ingredients are extracted once per saved meal, with a conditional write.
- `extract.ts:225-238`: the rolling summary is keyed by `summary_index` and re-checked after the model returns.
- `requirePro` fails closed (`entitlement.ts:26-38`). `kroger` authenticates in code although `verify_jwt=false`. `meal-photo` re-reads `users.is_internal` on every action. `analyze-meal-photo:134` and `pantry.ts:36` check that the photo path belongs to the caller.
- Output caps: measured outputs are well under every cap.
- The context block's rendered size (about 1,500 characters) and the in-view section.
- `vana_calls` has the index the rate limiter needs.
