# SSOT — Conversation (kinds, ownership, openers, persistence)

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** N/A — recorded from the shipped code (see Code); no dedicated Xuan intent artifact addresses
conversation ownership/persistence directly.
**Code:** `vana_conversations` / `vana_messages` / `vana_calls` (`20260827120000` jade→vana; `jade_*`
are compat views); prototype `server/vana/chat.ts`, edge `_shared/vana/chat.ts` (+ `stream.ts`); Dart
`vana_chat_repository.dart`, `vana_conversations_controller.dart`.
**Scope:** the two conversation kinds, who owns history and persistence, opener wiring, and what each kind
gives the model.

**What this file owns:** the two conversation kinds (`meal_planning` / `general`), who owns turn history and
persistence, how an opener is wired in, and what a kind determines about what the model sees. It owns no
calculation (the opener-selection *algorithm* is [`../planning/opener-selection.md`](../planning/opener-selection.md))
and no tool inventory ([`../agent/tools.md`](../agent/tools.md)).

## Definitions

- **Kind** — `meal_planning` (the planning persona, the CONTEXT block, an opener, a plan bar, its own draft) or
  `general` (the Q&A persona, name + date only, no opener, no plan bar, tools pull what a question needs).
- **Turn** — one user message → one assistant message; an assistant message is an ordered list of **parts**
  (`text`, `tool-<name>` with `state: output-available` and a `VanaPart` output).

## Rules

- **C-1 · History is server-owned.** The client sends only the new message (+ `conversation_id`, `kind`,
  `timezone`, `opener?`, `anchor_date?`); the server loads the rows, appends, runs the model, persists both rows
  (`content` = the first text block; `parts`; `metadata {ui_parts, tool_calls, duration_ms, opener,
  opener_variant, kind, plan_snapshot}`), touches `last_message_at` and sets the title from the first user
  text (≤ 60 chars) or "This week's plan" / "Quick question".
- **C-2 · A foreign or stale `conversation_id` silently becomes a fresh conversation** (RLS makes it invisible);
  the real id always comes back in `x-conversation-id` / `x-vana-conversation`.
- **C-3 · Kinds differ in what the model gets.** Planning: full CONTEXT block + the planning tool set + an
  opener turn (synthetic user message, never stored). General: no context, the general tool set, no opener —
  the athlete speaks first; a general request with no message is `400 message_required`. General Vana creates
  no server row until the first message.
- **C-4 · One draft plan per planning conversation** ([`plan.md`](plan.md) P-2); the context's PLAN line
  describes that draft.
- **C-5 · "Other options" memory is the transcript.** `shownMealIds` is rebuilt from the persisted
  `meal_picker` / `staples` parts every turn ([`../selection/meal-suggestion.md`](../selection/meal-suggestion.md) SG-2).
- **C-6 · The opener is a variant** — plan · check-in · debrief ([`../planning/opener-selection.md`](../planning/opener-selection.md)).
- **C-7 · Reading history prefers `parts`;** legacy rows (content + `metadata.ui_parts`) are rehydrated as
  `tool-legacy` parts. Unknown part kinds are dropped by the Dart parser (forward compatibility).
- **C-8 · General turns drop pre-tool narration** — a text block < 160 chars that precedes a tool call in the
  same turn is not persisted (and hidden live); planning turns render text → widgets → chips regardless of
  emission order.
- **C-9 · Edit = rewind + resend** (edge, Phase 6). An edited athlete turn triggers `rewind(messageId)`
  ([`plan.md`](plan.md) P-12) and the edited text is then sent as a normal message.
- **C-10 · Every model call is logged and rate-limited** through `vana_calls` (`function_name`
  `vana.chat.<kind>` · `vana.opener.<kind>` · `vana.brief` · `vana.daynotes` · `vana.embed`) and, on the edge,
  `ai_usage` — [`../agent/wire-protocol.md`](../agent/wire-protocol.md) limits.
- **C-11 · The list shows one kind at a time** (`/vana/conversations?mode=`), newest `last_message_at` first;
  `/vana` opens the most recent of the requested kind, `?c=new` starts one, `?c=<id>` reopens one.

## Invariants

1. For every assistant row: `parts` non-empty; if it contains a UI tool part, `metadata.ui_parts` lists the same
   parts in order.
2. The opener's synthetic user message is never a `vana_messages` row (`opener: true` on the assistant row is
   the only trace).
3. A `general` conversation never has a `plan_snapshot`.

## Conformance

`tests/contract.test.ts` (opener + general_turn NDJSON fixtures), Dart `vana_chat_repository_test`,
`vana_stream_event_test`, `vana_chat_controller_test`; the Patrol chat flow. No pure vectors.
