# `/ssot rewrite <feature> [--category "<name>"]`

Rewrite every live card of a feature so a decider can read it: the answer in plain words with
one worked example, the precise clauses under Details, a picture of the choice, every term of
art defined. Nothing about what was decided changes; a verifier checks that. Runs on Opus
(`/model opus` first). Format and rules: `docs/ssot/decisions/README.md`, File format and
Drawn pictures. Paths and `SYNC` as in `prologue.md`.

## 0. Prologue

Run `prologue.md` in full so no queued verdict is overwritten by a rewrite.

## 1. Inventory

- `SYNC export docs/ssot/decisions/<feature>.md .scratch/<feature>/decisions.md` for the cards.
  Skip `kind: question`, `rejected`, `withdrawn`, and the `Tickets` category (a ticket card is a
  work record, approved in the terminal, never rewritten). `--category` limits the pass to one.
- `SYNC unclear docs/ssot/decisions/<feature>.md .scratch/<feature>/decisions.md --glossary CONTEXT.md`
  for the backticked terms the glossary does not define; each one is either defined in the
  sentence that uses it or becomes a glossary term in this pass.
- Read `CONTEXT.md`'s glossary once; every rewrite uses its words.

## 2. Rewrite, one subagent per category

One subagent per category, at most three at a time, each on Opus, each given: the README's
File format and Drawn pictures sections, the glossary, the category's cards in full (export
JSON), the cards those cards name (`mp-NNN` in any part) in full, the unclear terms for the
category, and mp-503 and mp-504 as the finished examples. It writes one file,
`.scratch/ssot/rewrite/<feature>/<category slug>.json`:

```
{ "cards": { "<id>": { "title"?, "question", "decision", "details"?, "context"?, "why"?,
                       "diagram"?: <spec from diagram.mjs>, "diagram2"?: <spec>, "slot"?: 1 | 2 } },
  "terms": [ { "term", "area", "definition", "avoid"? } ] }
```

Rules the subagent follows, in this order of weight:

1. Every ruling the card makes survives. The clauses a builder needs move to Details verbatim
   under "Precisely:"; nothing is dropped, merged or softened. Status, source, history and
   what-it-touches are never touched.
2. Question: one phrase a newcomer would ask, ending in a question mark.
3. Decision: two to four sentences for Lee, not for the next build agent, ending with one worked
   example that uses real dates, names or numbers. No word the glossary does not define unless
   the sentence defines it. No em-dashes, no hedging, `unslop` applies.
4. Context: what the thing is and what was true before, two to four sentences; may be left as is.
5. Title: a plain sentence saying the ruling, not a label ("The server keeps RevenueCat's end
   date, not the event's").
6. Pictures: two, when the card chose between two ways. Picture one is the other option,
   picture two the card's answer, each a dated `timeline` of the same worked example told
   from the athlete's side (what they did, what they saw), titled "Other option: if …" and
   "This card's answer: …" (mp-503, mp-504). The titles never say "rejected" or "decided":
   most cards are still waiting for a ruling when they are drawn, and the picture outlives
   the status (Lee, 2026-09-23). A `compare`'s two heads follow the same rule. A card that defines a shape or a sequence gets one `flow`
   or `timeline`. A card with a screenshot keeps it in slot one and gets one drawing in slot
   two. The page stacks the pictures in the left column, about 420 px wide, so a step's label
   is at most three short lines. `"diagram"` is picture one, `"diagram2"` picture two.
7. Terms: a word used in three or more cards of the category with no glossary entry becomes a
   term (area = the glossary heading that fits, `Avoid` = the words the record used instead).

The subagent never edits the record, CONTEXT.md, or an SVG; it writes the JSON and stops.

## 3. Verify meaning, one subagent per category

A second Opus subagent gets the old export and the new JSON and answers, per card, "same
rulings?" with a one-line reason for any no, plus any term whose definition contradicts a card.
A card with a no is removed from the JSON and listed in the report with the reason; it is not
retried by the tooling.

## 4. Apply

```
SYNC rewrite-apply .scratch/ssot/rewrite/<feature>/<slug>.json .scratch/<feature>/decisions.md docs/ssot/decisions/<feature>.md --feature <feature> --glossary CONTEXT.md
```

It replaces the parts given, draws every diagram into `docs/ssot/decisions/images/<feature>/`
(`-2.svg` for a second picture) and attaches it, appends new terms under their area, and adds
one history line per card. Read `applied` and `refused`; a refused picture keeps the card's
words. Run `SYNC undrawn` afterwards: every screenless card must still have a picture.

## 5. Epilogue

Run `epilogue.md` from step 1 (prepare with `--glossary CONTEXT.md`, reseed with pinned
versions, re-list and retry on `version_mismatch`; other sessions reseed too). Commit the
record, the proposals, the SVGs, CONTEXT.md and the JSON files together:
`ssot: <feature> rewritten in plain words (<n> cards, <m> pictures, <k> terms) [skip ci]`.

Report:

```
Rewritten: N cards in C categories, P pictures (Q compare), T terms
Held back by the verifier: N (ids and reasons)
Refused by apply: N (ids and reasons)
Page: URL
Clear: yes
Next: read three cards on the page; anything wrong goes through Rewrite or Ask as usual
```
