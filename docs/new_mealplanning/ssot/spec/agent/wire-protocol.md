# SSOT — Wire Protocol, Models and Limits

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** `../../../implement_mealplanning/02-contract.md` (the frozen `contract-v1`, decided 2026-09-01) —
this file digests its §5–§7 into contract rows and adds the cost posture.
**Code:** prototype `POST /api/vana/chat-ndjson` (reference implementation) and `/api/vana/chat` (AI SDK UI
stream, web only); edge `vana-chat` (+ the `jade-chat` alias for 1.23.x clients), `vana-action`,
`vana-day-notes`; `stream.ts`.
**Scope:** the NDJSON envelope, models, limits, rate limits and persistence rules riding on `contract-v1`.

**What this file owns:** the NDJSON wire envelope, which models serve which role, the cost posture and the
rate-limit buckets. It owns no tool inventory ([`tools.md`](tools.md)) and no copy/register rules
([`voice.md`](voice.md)); the frozen types themselves live in `02-contract.md`, not here.

## Envelope (NDJSON — what both clients speak)

Request `{message?, conversation_id?, kind: meal_planning | general, timezone?, opener?: bool, anchor_date?: YYYY-MM-DD}`.
Response headers `x-conversation-id`, `x-vana-conversation` (alias), `x-vana-kind`; body
`application/x-ndjson`, one JSON object per line:

| `type` | payload | when |
|---|---|---|
| `text` | `{delta}` | streamed text; a `"\n"` delta separates text blocks (one per step) |
| `ui` | `{part: VanaPart}` | a UI tool returned |
| `status` | `{tool}` | a tool's input started streaming — drives the status line (V-4) |
| `done` | `{usage: {input_tokens, output_tokens}}` | end of turn |
| `error` | `{message}` | a stream error; the line replaces the turn |

Pre-stream errors: `401 {error: unauthenticated}` · `400 {error: message_required}` · `403 {error: pro_required}`
(edge only — the Pro gate) · `429 {error: rate_limited, retry_after_seconds}`.
Actions: `POST vana-action {type, payload}` → `{parts: VanaPart[], ...extras}`; payload keys accepted in camelCase
(the contract) and snake_case (older clients); every plan write returns a `batch` part the client folds in.

## Models and cost posture

| Role | Env | Default (edge) | Default (prototype) |
|---|---|---|---|
| chat | `VANA_CHAT_MODEL` | `anthropic/claude-haiku-4-5` | `anthropic/claude-sonnet-4-6` (D-018 — the walkthrough says Haiku; Sonnet "only by env override") |
| tool jobs (day notes, pantry vision) | `VANA_TOOL_MODEL` | `anthropic/claude-haiku-4-5` | same |
| embeddings | `VANA_EMBED_MODEL` | `openai/text-embedding-3-small` | same |

All through the Vercel AI Gateway (`AI_GATEWAY_API_KEY`). Context block ~250 tokens; compact tool outputs;
`maxOutputTokens` 700 (edge, both kinds; prototype: 400 planning / 700 general — D-014); steps 6 / 8.

## Rate limits (`vana_calls` is the bucket store; prefix-matched; fail open on DB error)

| Bucket | Window | Max | Covers |
|---|---|---|---|
| `vana.chat` | 10 s | 4 | `vana.chat.meal_planning`, `vana.chat.general` |
| `vana.opener` | 60 s | 3 | new conversations |
| `vana.brief` | 60 s | 2 | the (retired from UI) weekly brief |
| `vana.daynotes` | 60 s | 4 | one call writes all seven days |
| `vana.embed` | 60 s | 30 | every embedding |

## Rules

- **W-1 · Additive only.** `contract-v1` types change in three places at once (prototype TS, edge TS, Dart) or
  not at all; new `VanaPart` kinds are additive and unknown kinds are dropped by the parser (C-7).
- **W-2 · One `vana_calls` row per model call and, on the edge, one `ai_usage` row** — chat, opener, day notes,
  brief, embeddings, pantry vision. Meal planning does **not** debit AI credits; Pro is the price (decision 4,
  2026-09-01). Photo detection is metered, never disabled to save cost.
- **W-3 · The Pro gate is server-side.** `requirePro`: passes when `PRO_GATE_ENABLED=false` (dev), or
  `has_entitlement(user, 'pro')`, or `users.is_internal`; a missing secret gates ON everywhere except the dev
  project; a missing `user_entitlements` table is *not entitled* (never fail open).
- **W-4 · RLS does the filtering on the edge.** Every user-owned read/write goes through the caller's JWT client;
  the service role is reserved for `vana_calls`, macro back-fills and the pairs refresh. The prototype uses the
  service role with an explicit `user_id` filter on every query (the structural difference between twins —
  accepted, not a deviation).
- **W-5 · Persistence is off the response path** (edge: `EdgeRuntime.waitUntil` in `onFinish`); the assistant
  row, usage rows and `afterFinish` (credit debit for the alias) never delay the stream.

## Conformance

`tests/contract.test.ts` writes the NDJSON fixtures (`opener.json`, `general_turn.json`) from live dev;
`schemas.ts` `NdjsonLineZ` / `NdjsonExchangeZ` validate them in the edge contract test; the Dart parser tests
consume them verbatim. Rate limits: `rate-limit` has no unit test — Q-WP1.
