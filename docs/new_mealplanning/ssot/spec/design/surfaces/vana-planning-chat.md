# Design SSOT — Surface: Vana Planning Chat

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Prototype `routes/vana.tsx`
(`mode=meal_planning`); Dart `vana_chat_screen.dart`. Turn-by-turn script: `../../../walkthrough.md` (v2).
**Composition (pinned):** meal-picker v1 · meal-card v1 · plan-bar v1 · choice-chips v1 · staples-card v1 ·
shopping-list v1 (inline card) · `selectable-chip-grid` (pantry, PROPOSED) · `macro-pill-row` (PROPOSED) ·
tokens (Q-TK1 open).
**Numbers authority:** every figure on this surface is a `VanaPart` field or the plan's `coverage`; the surface
invents no arithmetic.

## Surface contracts

| # | Contract |
|---|---|
| VP-1 | **Opens on the most recent planning conversation, or a new one** (`?c=new`), whose first turn is the opener variant (`../../planning/opener-selection.md`). While the opener streams: "Vana is looking at your week…". |
| VP-2 | **A planning turn renders text → widgets → chips**, whatever order the parts were emitted (the model writes after the tool returns; the display order is fixed). |
| VP-3 | **Picker chips are drawn by the client under every picker of the last assistant turn** (choice-chips CC-3…CC-8); a `choices` part after the picker suppresses them. |
| VP-4 | **The plan bar is pinned from the first turn and re-minimizes on every turn** (plan-bar PB-1); every write it makes carries `conversationId` so it lands on this conversation's draft (P-2). |
| VP-5 | **Confirm produces the ConfirmedCard** in the transcript ("Plan confirmed — shopping list is ready, N items. Skipped X — you have it." + Open shopping list) and, on the app, the "you're set" summary with Share and the "Remind me the night before cook day" chip (dark by default). |
| VP-6 | **Tool status lines replace narration:** a pending tool part renders "Finding options that fit your week…" / "Building your shopping list…" / … per tool, with a mini pulsing avatar; unknown tools "Working on it…". |
| VP-7 | **A 429 renders "Vana needs a moment — try again in Ns"**; a stream error renders "Vana is offline — <message>" in the transcript; neither loses the plan bar. |
| VP-8 | **First-run intro card** (app): one line on what Vana already knows (race / anchor from the home payload), three example chips (Plan around my race week · Use what I have · Cheaper this week), dismiss forever — never a gate (⚖️ Q-7). |
| VP-9 | **Edit under an athlete turn** (app, Phase 6): the text returns to the composer with an "Editing" strip; sending calls `rewind` then sends (P-12, C-9). Date dividers when a conversation spans days. |
| VP-10 | **Composer `+`** (app): Snap my fridge / Choose a photo / Use what I have → the pantry part; mic = speech-to-text (hidden on web). |
| VP-11 | **Every plan mutation from this surface invalidates the home, shopping and plan queries** so the Plan tab never shows a stale plan after chat. |

## Scope guards (this iteration)

- **VP-S1** no day grid in chat (the `day` / `week` parts render read-only with "Open Plan tab").
- **VP-S2** no coupons / prices (no data source — D-7).
- **VP-S3** no wizard door (⚖️ Q-2).

## Conformance

Patrol: the plan-build flow (opener → pick → chips → Review → Confirm → ConfirmedCard). Widget:
`vana_part_renderer_test`, `vana_status_copy_test`, `vana_intro_card_test`, `vana_date_divider_test`,
`vana_attach_sheet_test`. Goldens: transcript with picker + chips + minimized bar; confirmed state.
