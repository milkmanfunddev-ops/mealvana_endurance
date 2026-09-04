type: ruling-request
bundle: design@v1

## Why this matters
The intro card was built under Xuan's own interim call (Q-7: "yes — a one-time dismissible intro card"), then
removed the same evening on Lee's judgment alone ("we don't need that block") once the question-first opener
landed. That is exactly the kind of reversal this register exists to flag for a cheap veto — DEVIATIONS D-021.

## The question
Q-7's original interim call was "yes, ship a one-time dismissible intro card with three example chips." That
card was built, then removed hours later because the new question-first opener (see the opener-reversal ruling
request) does the same "prove what Vana knows" work as the card's first line, making the card feel redundant.
Was removing it the right call — is the question-first opener itself now the complete answer to Test Theme 1
("no user starts with chat unprompted")? Or does some one-time explainer (even a lighter one than what was
built) still earn a place, e.g. to introduce example prompts the opener's own question doesn't surface (Cheaper
this week / More variety)?

## Options
- **Confirm removal (current build).** The opener's context sentences + one question is the complete first-
  contact experience; a card in front of it adds a tap without adding information the opener doesn't already
  carry.
- **Reinstate a lighter version.** Keep the opener as first contact, but still surface 2–3 example prompts
  somewhere low-commitment (e.g. under the composer, not blocking the transcript) for athletes who want to type
  something other than what the opener's chips offer.
- **Reinstate the original card.** Revert to the built-then-removed shape.

## Recommendation
Confirm removal for now; the opener's chips (Batch-cook staples / Quick weeknights / Something new / Use what I
have) plus always-available free text already cover the example-prompt need the card's chips served.

## Gates
Whether `lib/features/meal_planning/presentation/screens/vana_chat_screen.dart` grows any first-contact UI
beyond the opener.

## Suggested spec home
`OPEN-QUESTIONS.md` Q-7; `DEVIATIONS.md` D-021; `spec/design/surfaces/vana-planning-chat.md` VP-8 (already
updated to remove the intro-card contract, 2026-09-03 evening).
