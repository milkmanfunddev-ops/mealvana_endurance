# Design SSOT — Surface: Vana Planning Chat

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** prototype `routes/vana.tsx` (`mode=meal_planning`); turn-by-turn script `../../../walkthrough.md`
(v2).
**Code:** Dart `vana_chat_screen.dart`.
**Scope:** composes (pinned) meal-picker v1 · meal-card v1 · plan-bar v1 · choice-chips v1 · staples-card v1 ·
shopping-list v1 (inline card) · `selectable-chip-grid` (pantry, PROPOSED) · `macro-pill-row` (PROPOSED) ·
tokens (Q-TK1 open). Numbers authority: every figure on this surface is a `VanaPart` field or the plan's
`coverage` — the surface invents no arithmetic.

**What this file owns:** the planning-chat surface — turn ordering, the pinned plan bar, tool status lines, and
confirm, under `## Surface contracts` (VP-1..VP-11) and `## Scope guards` (VP-S1..S3); the component contracts
it composes live in their own files.

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
| VP-8 | **No first-run intro card.** Built 2026-09-03 daytime, removed the same evening (Lee: "we don't need that block") once the question-first opener (VP-1, `../../planning/opener-selection.md`) became the first-contact surface — the opener's own 2–3 PRESENTING sentences now do the "prove what Vana knows" work the card's first line duplicated (D-021). Verified 2026-09-04: no `vana_intro_card.dart` or any `*vana_intro*` file exists in `lib/`. First contact is the opener, full stop — ⚖️ Q-7 is now the reversed call, not the original "yes, ship a card" one (see `intake/2026-09-03-q7-intro-card-reversal.md`). |
| VP-9 | **Edit under an athlete turn** (app, Phase 6): the text returns to the composer with an "Editing" strip; sending calls `rewind` then sends (P-12, C-9). Date dividers when a conversation spans days. |
| VP-10 | **Composer `+`** (app): Snap my fridge / Choose a photo / Use what I have → the pantry part; mic = speech-to-text (hidden on web). |
| VP-12 | **Motion (2026-09-04):** streamed prose fades each new chunk in over ~140 ms while earlier text stays put (`StreamedText`); the prose bubble's height animates as it grows (`AnimatedSize`, 180 ms, ease-out-cubic); the typing dots cross-fade INTO the bubble at the same top-left position (200 ms) rather than swapping; parts cascade in after the prose (`PartEntrance`, 320 ms, ~60 ms stagger). Every one of these short-circuits under the platform reduce-motion setting. A rewrite of the prose that is not an extension (rewind, edit) renders at once. |
| VP-11 | **Every plan mutation from this surface invalidates the home, shopping and plan queries** so the Plan tab never shows a stale plan after chat. |
| VP-12 | **"Browse meals" from chat** (added 2026-09-03 evening, Lee: "browse all of our recipes and assign them to the meal plan"): a chip and the `+` sheet's leading row open `../../surfaces/vana-browse.md` (`/vana/browse?c=<conversationId>`) — the Meals-tab catalog, extracted into `MealCatalogBrowser` (`food-meals-catalog.md`), with an Add tick on every card that picks straight into THIS conversation's draft. On return, the chat calls `VanaChatController.refreshDraft()` to re-read the conversation's draft so the plan bar reflects picks made on the browse screen. |

## Scope guards (this iteration)

- **VP-S1** no day grid in chat (the `day` / `week` parts render read-only with "Open Plan tab").
- **VP-S2** no coupons / prices (no data source — D-007).
- **VP-S3** no wizard door (⚖️ Q-2).

## Conformance

Patrol: the plan-build flow (opener → pick → chips → Review → Confirm → ConfirmedCard). Widget:
`vana_part_renderer_test`, `vana_status_copy_test`, `vana_date_divider_test`, `vana_attach_sheet_test` (both
confirmed present under `test/features/meal_planning/presentation/widgets/`, 2026-09-04 — `vana_intro_card_test`
removed from this list: no such file exists, matching VP-8's removal). Goldens: transcript with picker + chips
+ minimized bar; confirmed state. Opener shape: `scripts/vana-eval/run.ts` `presenting` check +
`scripts/vana-eval/lifecycle.ts` line 60 (`../../planning/opener-selection.md`'s Conformance section).
