# 07: The cache reads everything that repeats

**Status:** done (wave 5, 2026-09-22)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/chat.ts), 04 (touches supabase/functions/_shared/vana/chat.ts), 05 (touches supabase/functions/_shared/vana/chat.ts), 06 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** Nothing changes for the athlete. A planning turn reads 80% or more of its input from the cache, against 43% today, and costs about a cent.

**Decisions:** mp-420, mp-276, mp-290; approved as mp-472.

**Touches:** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/context-cache.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/prompt_cache.test.ts

- [x] First, the one-line dev experiment with the gateway's automatic caching on ten planning turns; first-step cached tokens are recorded in this ticket.
- [x] The system prompt is two system messages, persona then athlete context. A context rebuild leaves the first byte-identical (extends the prompt cache test). Each gets an explicit marker where automatic caching does not mark it.
- [x] Calls are pinned to Anthropic and carry a session id per conversation. The tool list never varies per turn.
- [x] The screen line and the opener's hidden first message are stored with the transcript; a stored conversation replays byte-for-byte as first sent (test).
- [x] The shared prefix uses the one-hour lifetime if the setting survives the gateway; the dev result is recorded either way.
- [x] The opener's start-time test stays at 3.5 seconds.
- [x] Dev, after: the read share on ten planning turns is recorded in this ticket. Target 80% or better.

Next: /implement-lee ai-cost

## Results (2026-09-22, wave 5)

Measured with `scripts/vana-eval/cache-probe.ts` on the evals gateway key: ten planning turns in one conversation
straight at the gateway, the real tool list and persona, a realistic athlete context, the real opener as the first
user message and the screen line on the newest message. The context is rebuilt before turns 4, 6 and 8, the way a
plan write rebuilds it in production. Each turn is capped at two model steps and 400 output tokens; the figures
below are the FIRST step's, the only one that can read the shared prefix (the same ratio `vana_calls` logs as
`first_step_cache_read_tokens / first_step_input_tokens`). Raw output: `.scratch/ai-cost/probe/*.json`. Nothing
was deployed.

**Experiment 1 (criterion 1): today's shape plus the gateway's automatic caching** (`gateway.caching: 'auto'` on
top of Anthropic's automatic marker; one system string, persona and context together).

| turn | context | first-step input | cache read | cache write | read share | cost |
|---|---|---|---|---|---|---|
| 1 | built | 15,182 | 0 | 15,179 | 0% | $0.0220 |
| 2 | reused | 15,508 | 15,457 | 48 | 99.7% | $0.0042 |
| 3 | reused | 15,785 | 15,697 | 85 | 99.4% | $0.0046 |
| 4 | **rebuilt** | 16,123 | **0** | 16,120 | **0%** | $0.0224 |
| 5 | reused | 16,296 | 16,255 | 38 | 99.7% | $0.0047 |
| 6 | **rebuilt** | 16,611 | **0** | 16,608 | **0%** | $0.0231 |
| 7 | reused | 16,790 | 16,743 | 44 | 99.7% | $0.0045 |
| 8 | **rebuilt** | 17,157 | **0** | 17,154 | **0%** | $0.0244 |
| 9 | reused | 17,561 | 17,335 | 223 | 98.7% | $0.0026 |
| 10 | reused | 17,707 | 17,558 | 146 | 99.2% | $0.0023 |

Ten turns: **60.1%** read (the nine follow-ups 66.2%); $0.1145 for the ten, $0.0115 a turn. The gateway's
automatic mode changes nothing about a rebuild: every rebuilt turn reads zero and rewrites the whole 16,000-token
prefix, tools and persona included — the 43%/0% the audit and ticket 06 saw, with one block for everything.

**Experiment 2 (criterion 7): the shape this ticket ships.** Two system messages (persona at `ttl: '1h'`, context
at five minutes), Anthropic's automatic marker kept for the tail, `gateway.only: ['anthropic']`, an
`x-session-affinity` header carrying the conversation id.

| turn | context | first-step input | cache read | cache write | read share | cost |
|---|---|---|---|---|---|---|
| 1 | built | 15,181 | 0 | 15,178 | 0% | $0.0321 |
| 2 | reused | 15,472 | 15,421 | 48 | 99.7% | $0.0038 |
| 3 | reused | 15,663 | 15,614 | 46 | 99.7% | $0.0044 |
| 4 | **rebuilt** | 15,979 | **13,688** | 2,288 | **85.7%** | $0.0066 |
| 5 | reused | 16,181 | 16,140 | 38 | 99.7% | $0.0043 |
| 6 | **rebuilt** | 16,458 | **13,688** | 2,767 | **83.2%** | $0.0082 |
| 7 | reused | 16,897 | 16,823 | 71 | 99.6% | $0.0046 |
| 8 | **rebuilt** | 17,277 | **13,688** | 3,586 | **79.2%** | $0.0083 |
| 9 | reused | 17,530 | 17,456 | 71 | 99.6% | $0.0025 |
| 10 | reused | 17,695 | 17,527 | 165 | 99.1% | $0.0023 |

Ten turns: **85.2%** read (the nine follow-ups **93.9%**); $0.0770 for the ten, **$0.0077 a turn** — 33% less
than experiment 1 on the same turns, and a warm turn is $0.002 to $0.005. A rebuilt turn now reads the 13,688
tokens of tools and persona and rewrites only the context and the history after it; its share falls as the
history grows (85.7 → 83.2 → 79.2%), which is what a marker placed before the messages can give. Turn 8 is a
hair under 80% on its own; the ten-turn figure the criterion names is 85.2%.

**Does the one-hour lifetime survive the gateway? Yes.** Anthropic's raw usage comes back through the gateway
untouched: turn 1 of experiment 2 reports `cache_creation: { ephemeral_1h_input_tokens: 13688,
ephemeral_5m_input_tokens: 1490 }` (experiment 1: `ephemeral_1h_input_tokens: 0`), and the first turn's charge is
$0.0321 against $0.0220 — the 2× write, as priced. The setting stays on (`PERSONA_CACHE_TTL` in chat.ts); every
read refreshes the entry free, so the dearer write is paid once an hour at most across every athlete.

**Is the call pinned?** Yes. The gateway's own routing metadata says `Provider set restricted to: anthropic`, and
without the pin it lists claudeaws, bedrock and vertexAnthropic as live fallbacks for the same model id — a
request moved there reads nothing.

**The session id.** The header goes out; the gateway echoes nothing about it in its response headers or metadata,
so it is asked for and not proven. The provider pin is what the cache rests on.

The opener start-time check is unchanged: `scripts/vana-eval/personalization.ts` still fails an opener whose
headers take 3,500 ms or more.
