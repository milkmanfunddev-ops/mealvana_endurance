# Design SSOT — Component: Plan Card

**Status: PROPOSED v1 (Lee, 2026-09-22) — authored app-side, awaiting Xuan.** Written from paywall
ticket 15 (decisions mp-493 §3 and §6, mp-453 §2, mp-497 §4, approved as mp-499). No reference
rendering yet.

**Component contract** — one subscription plan a person picks before a single action buys it, and
the tray that pins the plans above that action. The card owns the layout of a plan's words and its
selected state. It never owns the words or the prices (the store and the content system do), never
computes a saving or a per-month price (the caller does, from store prices), and never buys.

**Tokens / material:** [`../tokens.md`](../tokens.md) — ink and secondary ink for the words,
`electrolyte` for the badge fill and (dark) the trial note, `surfaceLight` / `surfaceDark` for the
card. §Materials: the card is a content card, solid fill and border, never glass; the tray that
holds the cards is `glass` chrome with the sheet's 24 px top radius.

## Contracts

- **PC-1 — one plan.** A card shows the plan's title and the billed price with its period. The
  caller may add: the normal price struck through beside it (founding prices, mp-453 §2), a
  per-month line, a trial note, and a badge beside the title ("Save 33%").
- **PC-2 — select, never buy.** A tap selects the card. The selected card has the ink border and a
  filled check; the other has the ink border at 20 % and an empty ring. The border is 2 px in both
  states, so selecting moves nothing.
- **PC-3 — the billed price leads.** The billed price is the largest price on the card; the
  per-month line sits under it, smaller and in secondary ink (the store rule that the amount billed
  is the most prominent pricing element).
- **PC-4 — one item to a screen reader.** A card reads as one selectable button in a mutually
  exclusive group: title, badge, price, then the lines under it. The check glyph is excluded.
- **PC-5 — the pinned tray.** The tray sits at the foot of the page and does not scroll: an
  optional header (the "Founding member" line), the cards stacked with 8 px between them, then one
  action. The page scrolls above it. Its bottom padding clears the home indicator.

## Implementation

`lib/shared/widgets/kyle_design/cards/plan_card.dart` — `PlanCard`, `PlanCardTray`.
Tests: `test/shared/widgets/kyle_design/plan_card_test.dart`.

## Open questions for Xuan

- **Q-PC1** — the trial note is `electrolyte` on the dark ground, as the paywall's old intro line
  was. On the white light-mode card `electrolyte` is too faint to read, so v1 sets the note in ink
  there. Is there a light-ground accent for it?
- **Q-PC2** — the tray's `glass` recipe is dark-first; on the cream light ground its fill and rim
  barely show (the light variant is deferred, §Materials). v1 accepts that: the solid cards carry
  the tray in light mode.
- **Q-PC3** — stacked full-width cards (v1) or two cards side by side? Stacked keeps the struck
  founding price, per-month line and trial note on one card without wrapping at 320 px.
