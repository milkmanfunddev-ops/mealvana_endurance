# Design SSOT — Component: Choice Chips

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** prototype `primitives.tsx`, `vana.tsx` (`ChoiceChips` / `PickerChips`).
**Code:** Dart `choice_chips.dart`.
**What this file owns:** the two chip families below — model chips and picker chips — their shared look, who
decides each, and the contracts (CC-1..CC-9) governing spent state, primary-chip computation, and suppression.

## Families

| Family | Decided by | Options | Where |
|---|---|---|---|
| **model chips** (`choices` part) | `askChoice` — a real fork | 2–4, each optionally with a `detail` trade-off line | after the text, at most one per turn |
| **picker chips** | the CLIENT, deterministically, under every `meal_picker` in a planning chat | primary · Other options · Something else… (+ filter chips once the plan has ≥ 1 meal) | never from the model |

## Contracts

| # | Contract |
|---|---|
| CC-1 | **Tapping a chip sends its label as the next user message** — except the routing labels: "Confirm plan" → Review sheet; "Open shopping list" → the Shopping tab; "Start a meal plan" → a new planning conversation; "Something else…" → focuses the composer (sends nothing). |
| CC-2 | **Spent state.** Once one chip in a group is tapped every other chip in that group disables (the tapped one stays selected); "Something else…" never disables. Only the LAST assistant turn's chips are active. |
| CC-3 | **Primary picker chip is computed:** no tile ticked → "I like these"; some ticked and an uncovered type remains → "Next: <type>" in the fixed walk dinner → lunch → breakfast → snack, skipping any type the draft plan already covers (`vana_chat_screen.dart` `_nextType`, verified 2026-09-03); none remains → "That's my week". |
| CC-4 | **"I like these" picks every unticked tile first** (`pick_meals` for all of them), then sends "I like these. Next: <type>" or "I like these — that's my week." |
| CC-5 | **Filter chips** (No recipe only · Different protein · Under 20 min) appear only while the picker is active and the plan has something in it; each is a plain message the persona maps to search inputs (SG-3). |
| CC-6 | **Detail rows.** When any option carries a `detail`, the group renders as full-width two-line rows (label + trade-off) instead of a wrap of pills (Dart `choice_chips.dart`; the prototype renders labels only — D-012). |
| CC-7 | **A `choices` question of more than one word renders as a bubble above the chips**; a one-word or empty question is suppressed. |
| CC-8 | **Picker chips are suppressed when the model asked a real question after the picker in the same turn.** |
| CC-9 | **A model chip never contains "Confirm plan".** The bar owns confirm (PB-5). |

## Token usage

Resting: electrolyte outline over a faint electrolyte wash; selected: solid electrolyte fill, blackberry
label; disabled: neutral at low alpha. The selection accent means *chosen* (tokens.md).

## Conformance

Goldens: pills (2, 3, 4), detail rows, spent group. Widget: CC-2 spent state; CC-3 primary label across the
walk; CC-4 write test (picks then message); CC-8 suppression. vana-eval: `fork_with_details`, `no_chips`.
