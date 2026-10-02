# Restructuring Vana: eve on Vercel versus the cheaper routes

Decision report for Lee, 2026-09-28. It builds on `.scratch/vercel-ai/research.md` and does not repeat
that file's sources. Vercel and eve claims cite primary sources (vercel.com, eve.dev, ai-sdk.dev, the
eve 0.67.2 package docs under `node_modules/eve/docs/`, platform.claude.com). **[measured]** means I ran
it in the scratchpad this session. **[inference]** is my reading. **[unverified]** means I could not
confirm it.

## 1. The answer in one paragraph

Take Route A: stay on Supabase and restructure inside the code you have. Of the four pain points, eve
fixes part of #3 (tracing) and some of #2 (it replaces the plumbing it owns). It does not fix #1
better than AI SDK 6/7 does, and it does nothing for #4. It also brings new plumbing that Vana would
need on day one: a `vana_messages` mirror, a bridge for chips and rewind, a Dart client for a
protocol that changed format in August, a stack running in parallel for old app versions, and a
rewrite of `vana-eval`. eve is in public beta and shipped 40 minor versions in 60 days. Route A costs
$0 on Vercel and about 8 to 12 dev days. Revisit eve if Vana needs scheduled or multi-channel
behaviour, or once eve and Workflow 5 reach GA.

## 2. Facts that set the frame

### 2.1 What Vana is today (repo facts)

- `persona.ts` is 31,968 bytes. The sections are CORE (3.8 KB), WRITE_RULES (2.6 KB),
  PLANNING_PROMPT (8.7 KB on top of those two), GENERAL_PROMPT (6.4 KB) and MAKE_IT_THEIRS. It has
  had 27 commits. The `_shared/vana/` folder has had 115 commits since 08-28.
- `tools.ts` defines 46 tools (58,807 bytes, 11.7 KB of descriptions). Tools are already split by
  conversation kind: `makeVanaTools` gives general 30 tools and planning 43
  (`tools.ts:241-248`). Nothing narrows them per step. There is no `activeTools` or `prepareStep`.
- `chat.ts` (583 lines) does everything in one function: rate-limit reservation, context cache,
  opener variants, the Situation line, 40/20 chunked summaries (`replayHistory`), `streamText`, row
  persistence, `vana_calls`/`ai_usage` and budget settlement under `EdgeRuntime.waitUntil`.
- The prompt cache is engineered by hand (`chat.ts:38-59, 342-347`). It uses three markers, gives
  the persona a 1-hour TTL, and pins the Gateway to Anthropic (`only: ['anthropic']`). This conflicts
  with the settled plan of "Gateway fallbacks everywhere". A Bedrock or Vertex fallback serves the
  same model but cannot read a cache written at Anthropic. The cost of allowing fallback is a cold
  prefix during an outage only. Decide this explicitly when the fallbacks land.
- The "unused `onTrace` hook" is no longer unused in plan. eval-v2 (`../mealvana_eval`) streams its
  trace from `onTrace` through a new `vana-eval` function that calls `runChat` directly. Ticket 01
  (per-Run overrides of persona sections, model, tools and descriptions) is built on
  `wave/eval-v2/01-runchat-per-run-overrides` and not merged. **Any route that removes `runChat`
  breaks eval-v2.**
- The Flutter app reads `vana_conversations`/`vana_messages` directly through PostgREST
  (`vana_chat_repository.dart:216-249`). `vana-action` (51 action types) writes chip results into
  `vana_messages` as synthetic tool calls, with no model turn (`chips.ts`, mp-464). It also rewinds
  conversations by deleting rows and restoring `plan_snapshot`. The judging tool
  `eval/tools/capture-transcript.mjs` reads the same tables.
- The 118-008 fix has already started. `context.ts:120` `carbsAgainstTarget` renders "464 g of carbs
  logged, 45 g over today's 419 g target" on the LOGGED TODAY line. Retest 145 is pending. 12-005
  (the reply contradicts itself about which day has the long ride) and the pilot defects IMP-001..004
  (Mark 71.25) are prompt, data and code-enforcement problems.

### 2.2 What a turn costs today [measured, dev, last 7 days, `vana_calls`]

| | n | input tok | cache read | cache write | steps | mean $ | p50 $ | p90 $ |
|---|---|---|---|---|---|---|---|---|
| `vana.chat` | 56 | 47,063 | 31,243 | 15,812 | 1.95 | 0.0243 | 0.0118 | 0.0622 |
| `vana.opener` | 28 | 16,020 | 6,652 | 9,364 | 1.18 | 0.0176 | 0.0213 | 0.0302 |

At 1k MAU × 20 turns = 20k turns, **tokens cost about $240 (at p50) to $490 (at the mean) a month**,
or $0.24 to $0.49 per athlete against the $4 budget. Dev traffic is sparse, so 5-minute cache
entries expire. Production density should push toward the low end [inference]. Tokens are the same
in every route unless the route changes how many calls are made or what gets cached. That is where
the routes actually differ on cost.

### 2.3 Two caching facts that decide the tool-narrowing question

From platform.claude.com/docs/en/build-with-claude/prompt-caching:
- Cache order is `tools → system → messages`. **Changing tool definitions invalidates the whole
  cache.** Changing `tool_choice` invalidates only the messages.
- The minimum cacheable prompt on Haiku 4.5 is **4,096 tokens**. A write costs 1.25× (5 min) or
  2× (1 h) and a read costs 0.1×.

So per-step `activeTools` changes the tool block mid-turn, and the next step re-writes the whole
~23k-token prefix. That is about 23k × $1.25/M ≈ $0.029 instead of a ≈ $0.002 read, which more than
doubles a $0.024 turn. Narrowing has to be stable per conversation or per intent, never per step.

## 3. Route A: stay on Supabase, restructure with the AI SDK

### What changes, file by file

1. **Persona into intent modules.** Create `_shared/vana/intents/` with one file per concern:
   `interview.ts`, `picking.ts`, `confirm.ts`, `checkin-debrief.ts`, `answering.ts` (general),
   `writes.ts`, `feedback.ts`, `memory.ts`. Each exports `{ prompt: string, tools: string[] }` plus
   its own tests. `persona.ts` shrinks to a composer (`composePrompt(kind, intents)`) and `CORE`.
   Step one is a **golden-bytes test**: the composer must reproduce today's `PLANNING_PROMPT` and
   `GENERAL_PROMPT` exactly, so the refactor ships with zero behaviour change and zero cache change.
   After that, a behaviour change touches one module and its tests. This also lets eval-v2's
   overrides address a module instead of a regex-cut section.
2. **Tools registered by module.** `tools.ts` becomes `tools/` with one file per module, and
   `makeVanaTools(kind)` becomes `toolsFor(kind, intents)`. Narrow **per conversation kind or intent,
   decided once at conversation open**, not per step. The first cut is audit finding #13: take the
   13 write tools and WRITE_RULES (~3,000 tokens) out of planning. Keep each composed prefix above
   4,096 tokens so it stays cacheable. Each extra intent-level prefix is another 1-hour cache entry;
   with 3 or 4 of them expect roughly $10 to $40 a month more in cache writes at 1k MAU [inference].
3. **`prepareStep`, used narrowly.** Use it for message transforms (the runaway guard, dropping
   narration) and for `toolChoice` (it only invalidates messages), not for `activeTools`. It exists
   in AI SDK 6, so none of this waits on v7 (ai-sdk.dev/docs/agents/loop-control).
4. **Day read in the Doll** (`context.ts`). Extend `carbsAgainstTarget` into a `dayRead` block:
   kcal, carbs, protein and fluid logged against target with the comparison already worded ("45 g
   over", "120 g to go"), the pre-session and recovery windows, and a week-to-date line. The model
   quotes it and does no arithmetic. This removes the class of error behind 118-008, and adding
   "Saturday: long ride 3h (Timeline)" lines helps with 12-005.
5. **Tracing.** In v7, `@ai-sdk/otel` goes to Sentry (ai-sdk.dev/docs/ai-sdk-core/telemetry).
   **[unverified]** whether the OTel exporter and Sentry's AI integration work inside Supabase's Deno
   runtime. The fallback is cheap: `onTrace` is already the complete trace. Write a sampled copy to a
   `vana_traces` table, which eval-v2 reads anyway.
6. **Subagents only as tools, and only if eval-v2 shows a need.** An AI SDK agent inside a tool's
   `execute` adds its own calls, about $0.006 to $0.007 per use at Vana's sizes [inference]. It does
   not add a parent notification turn, because the parent was going to take a step after the tool
   anyway. The audit found no step-cap hits and no truncation, and plan building is deterministic
   (`draftWeek`/`planWeek`), so no evidence yet calls for one.
7. **AI SDK 7.** **[measured]** On local Deno 2.7.11, `ai@7.0.118` ran `streamText` with
   `instructions`, `isStepCount` and `prepareStep` → `activeTools`; the tools offered per step
   followed the callback. A real `generateText` through the Gateway with `only: ['anthropic']`
   worked. The hosted Supabase edge runtime is a different Deno build, so the settled spike on a
   deployed dev function is still needed. Everything in 1 to 6 works on v6 if the spike fails.

### Pain points

| # | Fixed? | How |
|---|---|---|
| 1 | Yes, mostly | Modules give separation in code. Per-intent tool sets shrink what the model sees. The one prompt stays one prompt at runtime, which is what the cache needs. |
| 2 | No | The plumbing stays. None of it is broken; it is complicated. Moving it to a platform only moves the complexity (see B). |
| 3 | Yes | One module per behaviour, golden tests, and traces through OTel or `vana_traces`. |
| 4 | Enables it | The day read removes number errors at the source. Voice and judgment get fixed through modules plus eval-v2 rounds. Moving platforms would not help. |

**Size:** 6 to 8 tickets, 8 to 12 dev days. **Vercel cost:** $0. **Tokens:** unchanged, or lower
after trimming planning. **Flutter:** no change. **Old apps (jade-chat):** untouched. **Judging:**
untouched, and eval-v2 overrides get easier. **Risks:** the refactor could shift prompt bytes (the
golden test guards this), and v7 might misbehave in hosted Deno (stay on v6).

## 4. Route B: eve on Vercel Pro

### 4.1 Mapping every piece of Vana

| Vana today | eve equivalent | Verdict |
|---|---|---|
| `persona.ts` one prompt | `agent/instructions.md` (system), skills loaded with `load_skill`, and `defineDynamic` instructions per session or turn | Skills "add instructions, never a new execution surface. Tools stay visible whether a skill is loaded or not" (docs/skills.mdx). Loading one costs a tool-call round trip and appends to history. |
| 46 tools, split by kind | `agent/tools/*.ts` with `defineTool`; `defineDynamic` tools at `session.started`, `turn.started` or `step.started` | `step.started` is `prepareStep`/`activeTools` by another name, with the same cache penalty (dynamic-capabilities.md: "Tools available for: that model call"). |
| (none) subagents | Declared subagents in `agent/subagents/<id>/` with their own prompt and tools | "Every declared local or remote subagent runs as a durable background task." The child "never sees the parent's history", and its result wakes a new parent turn (subagents/index.mdx). |
| The Doll, `context-cache.ts` | `turn.started` dynamic system instructions and `defineState` | Works. A change to the system content still invalidates system and messages, as it does today. |
| Situation line | `clientContext` per turn | Direct fit (guides/client/messages.mdx). |
| `vana_conversations`/`vana_messages`, replay | The durable session, which lasts 30 days and parks between turns | Does not replace the tables; see 4.4. |
| 40/20 rolling summaries | Compaction at `thresholdPercent` of the context window (default 0.9), or `compact()` on demand | Default compaction lets history grow to about 180k tokens on Haiku before summarising. Keeping costs flat means triggering `compact()` yourself, which is today's logic in a new place. |
| `user_memories` + pgvector, rememberFact, idle extraction | Memory slot with a custom provider (`recall` on `turn.started`, `capture` on `turn.completed`, `tools`) | Feasible on our Postgres; see 4.3. |
| $4 wallet reserve/settle | No per-user monthly budget. `limits.maxTokenCostUsdPerSession` is per session, and hooks are "observe-only" | Reserve in the route `AuthFn` or a throwing `turn.started` hook. Settle from `step.completed.usage.costUsd` in a hook. |
| `rate-limit.ts` (vana_calls) | None built in | Same code, called from `AuthFn` or a hook. |
| `idempotency.ts` | n/a (it guards `vana-action`, which stays on Supabase) | Unchanged. |
| NDJSON `stream.ts` | `POST /eve/v1/session` then `GET …/stream` NDJSON | Flutter rewrite; see 4.5. |
| Chips with no model turn, rewind | No API to append to history without a turn, and no rewind; only `compact`, `clear`, `reset` | Bridge chips through a `turn.started` user-role instruction that reads pending chip rows. Rewind becomes clear-and-reseed [inference]. |
| Opener variants, moments | Dynamic instructions on the first turn | Works. |
| Day notes (`vana-day-notes`, claim rows) | Schedules exist (root-only, Vercel Cron) | Not needed: day notes are on-demand and fingerprinted. |
| `onTrace`, Sentry | Agent Runs (beta, "contact your Vercel representative" to enable), OTel export, 100% sampling by default since 0.66.2 | Better tracing out of the box. This is eve's clearest win. |
| eval-v2 `vana-eval` → `runChat` | eve evals drive only eve agents; the judge "does not promise a prose rationale" | `vana-eval` must be rebuilt against the session API. eval-v2 ticket 01 is wasted. |
| Channels | HTTP, Slack, iMessage, SMS and others | Unused today. Only valuable if Vana leaves the app. |

### 4.2 Can skills and subagents give separation of concerns?

In code, yes: files per skill and per subagent directory. Neither reduces what the model carries
the way Lee wants:
- A **skill** narrows the prompt but not the tools, and each load is an extra model step.
- A **declared subagent** narrows both. Each use costs a parent call that emits the delegation,
  one or two child calls on a fresh history, and a new parent turn woken by the task notification.
  At Vana's sizes (first step ~22.6k tokens with ~43% cache read on dev; a child with ~5k of
  instructions and tools plus ~1.5k of packed context) that comes to **about +$0.012 to $0.015 per
  delegated turn, +50 to 60% of a $0.024 turn**, and two extra sequential model calls of latency
  [inference from the measured row above]. If every turn delegated, that would be +$240 to $300 a
  month at 1k MAU. Each child prefix is its own cache entry. It has to be at least 4,096 tokens to
  cache at all, and it starts with no conversation history, so the parent's cached conversation
  does not help.
- `step.started` dynamic tools are the only per-step narrowing, and they carry the cache penalty
  from §2.3.

eve's separation-of-concerns tools are the same three the AI SDK gives Route A (prompt composition,
tool sets, agent-as-tool), with a larger runtime around them.

### 4.3 Memory on our Postgres

A custom provider is supported: "Anything that can read and write under that key can be a
provider: a Postgres table, a vector index…" (docs/memory/custom-provider.md). `recall` would run
`recall_memories` (pgvector) on each turn. `tools` would expose rememberFact/forgetFact as
`<slot>__remember`/`<slot>__forget`. Recalled rows enter as user-role messages that are appended
only, so they keep the cache. Three changes against today:
- eve partitions by an opaque `memory.scope.key`. Our rows are keyed by `user_id`, so the provider
  reads `scope.value` from `byPrincipal`.
- Recall runs on every turn: an embedding call plus a query (~100 to 300 ms) that today happens only
  when the model calls `recallFacts`.
- `capture` on `turn.completed` runs after **every** turn. Doing idle extraction there means a
  model call per turn instead of one per conversation (+$0.002 to $0.005 per turn, $40 to $100 a
  month) [inference]. Keeping idle extraction once per conversation needs a custom route, which
  means keeping `extract.ts`.

The built-in file memory stores to Vercel Blob. Our memories would move off Postgres and lose the
Vana settings screen that lists them. Don't use it.

### 4.4 What happens to `vana_messages`, summaries and history

The eve session is not a replacement for the tables:
- Sessions expire after 30 days by default. Since 0.67.0 they park after each turn instead of
  ending. Workflow data on Pro is kept "7 days after run completion"
  (vercel.com/docs/workflows/pricing), and completion comes when the session expires. A conversation
  reopened a month later therefore has no eve history [inference from the two docs]. eve starts a
  fresh session, and Vana needs today's replay and summary logic to reseed it.
- The app's conversation list, history load, rewind, `vana-action` chip rows,
  `capture-transcript.mjs` and the memory UI all read the tables.
- So Route B needs a hook that mirrors `message.completed`/`action.result` into `vana_messages`
  (keyed on `meta.id`, as sessions-runs-and-streaming.md recommends). That is new plumbing in place
  of the old.

### 4.5 Can our Supabase JWT authenticate? **[measured] yes, with caveats**

- Both Supabase projects sign with the legacy HS256 secret. The JWKS at
  `…/auth/v1/.well-known/jwks.json` returns `{"keys":[]}` on dev and prod, and a real dev token's
  header is `alg: HS256`. eve's `oidc()` against Supabase's discovery URL **rejected** a real token
  (no keys).
- `verifyJwtHmac` **accepted** Supabase's exact claim shape when re-signed with a known secret. It
  tags the caller `principalType: "service"` with `principalId: "<iss>:<sub>"`, so wrap it in an
  `AuthFn` that returns `principalType: "user", principalId: sub`. That needs the Supabase JWT
  secret stored on Vercel.
- A custom `AuthFn` that calls GoTrue `/auth/v1/user` needs no secret. I built a minimal eve 0.67.2
  agent (Node 24, local Workflow world) with that `AuthFn`: no token and a garbage token got 401, a
  real `test@test.com` token opened a session, and a tool read
  `ctx.session.auth.current.principalId` = the Supabase user id. That costs about 100 ms per request.
- The cleaner long-term option is to switch Supabase to asymmetric signing keys, after which
  `jwtEcdsa`/`oidc` work with JWKS.
- **The larger problem is RLS.** Tools get the verified principal, not the raw token. eve's pattern
  is to look up credentials inside `execute` (patterns/multi-tenant-auth.md), and sessions outlive
  the 1-hour JWT. Every tool would have to mint a short-lived user JWT with the HS256 secret, or go
  back to service role with explicit `user_id` filters. The port moved away from that pattern for
  safety (`env.ts` header).

### 4.6 What Flutter must change

- **Transport:** two-step create-then-stream. Create returns 202 with `sessionId` and can then
  return `409 session_not_ready`, which must be retried. Map `conversation_id ↔ sessionId` (store
  the session id on `vana_conversations`). Reconnect with `startIndex`. Validate the
  `x-eve-stream-version` header; stream v25 made appends deltas at 0.50.0 on 09-03, which would
  have broken a hand-written client.
- **Event mapping:** `message.appended` → text, `action.result` output with `kind` → `VanaPart`,
  `actions.requested` → the status line, `turn.failed` codes → the 402/429/503 sheets (they arrive
  mid-stream now, not as HTTP statuses).
- **No Dart client exists.** Official clients cover React, Vue, Svelte and TypeScript only.
- **Old versions:** ≤1.23.x call `jade-chat` and 1.24+ call `vana-chat`. Neither speaks eve. Either
  keep the Supabase `runChat` running until `min_app_version` passes the eve release (two stacks to
  keep in step), or build an NDJSON adapter that translates eve events back to today's lines (more
  plumbing).

### 4.7 Beta risk: breaking changes in the last month (eve CHANGELOG.md, eve.dev/changelog.md)

40 minor versions shipped from 07-30 to 09-28, and 21 between 08-27 and 09-26 (npm publish dates;
the changelog itself has no dates). Changes that would have hit Vana:
- **0.67.0 (09-26):** conversation/task modes removed; `outputSchema` removed from
  `defineAgent`/subagents/channels; sessions park after every turn; CLI split.
- **0.66.0 (09-23):** `ctx.getSkill()`/`SkillHandle` removed; the `eve/client` Zod schemas are
  dropped.
- **0.65.0:** `ctx.ask()` result shape changed; `ask_question` is no longer a default tool.
- **0.63.0:** background tools must use `defineWorkflowTool`; task status `pending→working`.
- **0.62.0:** instrumentation split into files; the evals judge API changed.
- **0.60.0:** span export policy reshaped.
- **0.59.0:** eval session API changed.
- **0.58.0:** named agents moved to `/eve/<name>/v1/*`.
- **0.57.0 (09-16):** turns moved into the owning workflow. "Do not roll back across this version"
  and keep the old deployment running until imported sessions end.
- **0.50.0:** stream deltas.
- **0.54.0:** trace schema v3→v4.

eve pins `@workflow/*` at `5.0.0-beta.x`, and Workflow 5 is beta. The engine requirement is
`node >= 24`. eve is "subject to the Vercel beta terms" (vercel.com/docs/eve).

### 4.8 Cost at 1k MAU × 20 turns

- **Pro plan:** $20/month including $20 of usage credit (vercel.com/docs/plans/pro-plan). If eval-v2
  already runs on the same Pro team, this is shared.
- **Workflow events:** **[measured locally]** a one-tool, two-step first turn including session
  creation wrote 22 events and 54 KB. A plain follow-up turn wrote 7 events and 25 KB. Assuming
  12 to 20 events per Vana turn gives 240k to 400k events at $0.02 per 1k, so **$5 to $8**. Local
  event counts may differ from what Vercel's world bills [unverified].
- **Data written:** Vana's tool outputs are larger (a picker is 6.5 KB, 41 KB with the "Show more"
  tail), so assume 100 to 200 KB per turn: 2 to 4 GB at $0.50/GB = **$1 to $2**.
- **Data retained:** parked sessions keep data for 30 days plus 7, about 2 to 4 GB-month at
  $0.50 = **$1 to $2**.
- **Functions** (Fluid): about **$2** (research.md §9C). **Queues:** under **$1** [unverified].
- **Always-on Tracing** at 100% sampling: 0.4 to 0.8M span units at $0.50/M = **$0.20 to $0.40**.
- **Platform total ≈ $30 to $35/month.** That fits under $50 but leaves little room for eval-v2 and
  growth.
- **Token deltas:**
  - eve's default tools added about 2,700 tokens per call [measured: 3,334 input tokens with the
    defaults versus 659 with `defaultTools: false` for a two-sentence prompt and one tool]. Turn
    them off.
  - eve's own cache handling is Gateway `caching: 'auto'` or three Anthropic markers
    (`dist/src/harness/prompt-cache.js`). It does not keep today's 1-hour persona TTL [inference
    from source].
  - Subagents add +50 to 60% per delegated turn (§4.2).
  - Per-turn memory capture with a model adds $40 to $100 a month (§4.3).
- **Hard-cap caveat:** Spend Management's pause "only affects production deployments. It does not
  stop AI Gateway API key usage … which continue to count toward your spend amount"
  (vercel.com/docs/spend-management). **[unverified]** whether prepaid Gateway credit spend counts
  toward a $50 on-demand budget. If it does, $240 to $490 of tokens would trip the cap. With Vana
  hosted on Vercel, the pause would then take Vana down. Today a pause cannot touch Supabase.

### Pain points

| # | Fixed? | How |
|---|---|---|
| 1 | Partly | File-per-tool and file-per-skill layout, and subagent directories. Runtime separation costs extra calls or cache misses (§4.2). |
| 2 | Swapped, not removed | Deletes `stream.ts`, part of `chat.ts` (the streamText orchestration), `context-cache.ts` and the `onTrace` plumbing. Adds an auth adapter, a user-JWT minter, a memory provider, budget and rate-limit hooks, a `vana_messages` mirror, a chip/rewind bridge, session mapping, a Dart client, an old-client adapter, a `vana-eval` rewrite and manual compaction triggers. |
| 3 | Yes for "why did she do that" | Agent Runs and OTel with 100% sampling. Behaviour changes still touch many files. |
| 4 | No | [measured] The same fact ("464 g logged, 45 g over 419 g") produced "consider moderating your carb intake" and "bring that back in line with your target!" from a bare eve agent. That breaks Vana's "never talk about cutting" and "no exclamation marks" rules. Quality lives in the prompt and data. |

**Size:** 18 to 25 tickets, about 4 to 6 weeks, plus a period running two stacks for old clients.

## 5. Route C: AI SDK 7 `ToolLoopAgent` on Vercel Node Functions, no eve

Move `runChat` to a Node 22+ Vercel Function (Fluid compute) and keep Supabase for the data, RLS
(verify the JWT or call GoTrue), `vana-action` and everything else. Do Route A's restructure there
as `ToolLoopAgent` with `prepareStep`. `WorkflowAgent` stays optional, and it is beta
(`@ai-sdk/workflow` requires Workflow 5 beta; ai-sdk.dev/docs/agents/workflow-agent).

- **Gains over A:** v7's supported runtime (Node ≥ 22) with no Deno question; Vercel
  observability; room for `WorkflowAgent` later; one host with the eval-v2 Next.js app.
- **Costs over A:**
  - The 38 `_shared/vana/*.ts` modules are Deno-flavoured (`npm:` specifiers, `Deno.env`,
    `EdgeRuntime.waitUntil`) and shared with `vana-action`, which stays in Deno. Either keep a dual
    build or fork the code.
  - Flutter needs a second base URL.
  - Old clients keep calling Supabase, so `runChat` stays deployed there too.
  - The Supabase service-role key moves to Vercel.
  - The same Spend Management caveat as B applies.
- **Pain points:** the same as A, plus somewhat better tracing tooling. Nothing on #2 or #4.
- **Size:** A plus 5 to 8 days.
- **Cost:** $20/month Pro, with ~$2 of Functions inside the credit. $0 marginal if eval-v2's Pro
  team already exists. Tokens are unchanged.

## 6. Side by side

| | A: Supabase + AI SDK | C: Vercel Node + AI SDK 7 | B: eve on Vercel Pro |
|---|---|---|---|
| #1 separation | Modules + per-intent tools | Same | Files, skills, subagents; runtime narrowing costs calls or cache |
| #2 plumbing | Stays | Stays, plus a second runtime | Swapped for new plumbing |
| #3 reason about it | Modules + OTel/`vana_traces` | Same + Vercel logs | Agent Runs (beta), OTel |
| #4 quality | Day read + eval-v2 loop | Same | Same work, no help |
| Dev effort | 8–12 days | 13–20 days | 4–6 weeks + dual stack |
| Vercel $/month | $0 | $20 (shared with eval-v2) | ~$30–35 |
| Token delta | 0 to −10% | 0 to −10% | +0% to +60% depending on subagents and capture |
| Flutter | None | Base URL | New transport and session mapping |
| Old clients | Untouched | Keep Supabase `runChat` | Keep Supabase `runChat` or build an adapter |
| Judging (eval-v2, capture-transcript) | Untouched | `vana-eval` moves or stays | Rewrite `vana-eval`; mirror `vana_messages` |
| Beta exposure | None | Workflow only if used | eve + Workflow 5 |

## 7. Where Vercel does not help

- Reply quality (#4) comes from the prompt, the data in the Doll, and what code enforces. IMP-001
  (walnuts suggested to a tree-nut-allergic athlete) is a filter bug in `searchMeals`/`suggestMeals`
  (the allergen list must include tree nuts from the same field), not a framework gap.
- Token cost is 90%+ of the bill in every route. The levers are the prompt, the cache, tool-output
  size and step count. Vercel adds zero markup but cannot lower that cost.
- The $4 wallet stays ours in every route. Gateway budgets cannot cap per app user (research.md §2).

## 8. Recommendation and phased path (≤ $50/month)

**Route A.** Keep eve as an option to revisit, not a migration.

1. **Phase 0, this week, $0.**
   - Run the settled AI SDK 7 spike on a deployed dev function. The local Deno 2.7 check passed; the
     hosted runtime is what is left to test.
   - Merge eval-v2 ticket 01 and make eval-v2 rounds the quality gauge.
   - Decide whether chat allows a Gateway fallback (cold cache during an outage) or keeps the
     Anthropic pin.
2. **Phase 1, about 3 days.**
   - Upgrade to v7 (or stay on v6 if the spike fails).
   - Add telemetry: `@ai-sdk/otel`→Sentry if it works in Deno, else sampled `onTrace` rows into
     `vana_traces`.
3. **Phase 2, about 5 days.**
   - Split the persona into intent modules behind the golden-bytes test.
   - Register tools per module.
   - Narrow per kind and intent (planning drops the write tools first).
   - Add the full `dayRead` block to the Doll.
   - Measure the first-step cache-read rate before and after each change (`vana_calls`).
4. **Phase 3, ongoing.**
   - Fix IMP-001..004 and 12-005 against eval-v2 Scenarios, one module at a time, until a round
     passes (average ≥ 90, none below 80).
5. **Phase 4, optional.**
   - Try one agent-as-tool (for example a planning specialist) only if an eval-v2 Scenario shows a
     failure that prompt work cannot fix. Compare Mark and cost per turn against the baseline.

Vercel spend for Vana in this path is $0. eval-v2 on Pro ($20 with $20 credit) leaves about $30 of
headroom under the $50 cap.

## 9. What would change this recommendation

- **Vana needs to act outside the app:** proactive scheduled nudges, SMS/iMessage/Slack, or
  multi-hour tasks that must survive restarts. eve's schedules, channels and durability are real
  advantages there, and building them in Route A would recreate eve.
- **eve and Workflow 5 reach GA** with a stable protocol that versions breaking changes, plus a
  maintained non-TypeScript client or a documented compatibility guarantee. Also Supabase moves to
  asymmetric signing keys, which removes the shared-secret and RLS problems.
- **The v7 spike fails in hosted Deno and v6 blocks something needed** (for example a v7-only
  telemetry path). Then C is the way to get v7 without eve.
- **Measured eve event counts on Vercel come out far above 20 per turn.** That pushes B past the
  cap. If they come out lower, B's platform cost is not the obstacle; the engineering cost still is.
- **eval-v2 shows a structural quality ceiling** (for example planning Marks stuck below 80 after
  prompt work) that a separately-prompted specialist fixes in an agent-as-tool trial. That would
  justify subagents, and they are cheaper in A or C than as eve background tasks.
- **Prepaid Gateway spend turns out not to count toward Spend Management**, and eval-v2 does not
  use the Pro team. That makes B's cap risk smaller but does not change its effort or beta exposure.

## Appendix: experiments run (scratchpad only, nothing in the repo changed)

- `scratchpad/evespike/`: eve 0.67.2 on Node 24.21.0 (`npm install node@24`), local Workflow world,
  just-bash sandbox, custom Supabase `AuthFn`, one `dayRead` tool, `anthropic/claude-haiku-4.5`
  through the dev Gateway key. Three sessions cost under $0.01. The files are `authtest.mjs`
  (verifier results), `hmactest.mjs` (claim mapping), `stream*.ndjson` and
  `.eve/.workflow-data` (event and byte counts).
- `scratchpad/deno7/`: `spike.ts` (AI SDK 7 `prepareStep`/`activeTools` with a mock model on Deno
  2.7.11) and `real.ts` (a real Gateway call from Deno).
- A read-only SELECT on dev `vana_calls` through the Management API (§2.2), and one GoTrue password
  sign-in for `test@test.com` on dev to get a real JWT.
