# 05: `/to-spec-lee`

**Status:** done (2026-09-14); the first real run waits on a spec-shaped conversation from Lee
**Blocked by:** 03.
**Next:** `/mattpocock-skills:implement 06`

**What to build:** Lee runs `/to-spec-lee` after a grill and gets the spec written per Matt's
to-spec, but approval happens on the page. Decisions linked to answered questions are picked up
first. The test seams and every implementation and testing decision from the draft are pushed as
cards in a "spec" category instead of being confirmed in the terminal. The skill hands over the
link, waits for Finish or "done", applies, and the spec's Implementation Decisions section ends
up citing decision ids with rejected items gone. Stories 25 and 46.

- [x] The skill follows Matt's to-spec from disk and refuses loudly if the file is missing (SKILL.md step 2 through `matt.mjs`, tested in ticket 03)
- [x] Seams and implementation decisions reach the page as `Spec` category cards with the spec's problem statement as context (step 4; category name recorded in the README)
- [x] The skill waits for Finish or "done", then applies through the prologue (step 5)
- [x] After applying, the spec's Implementation Decisions section cites ids and no longer lists rejected items (the spec cites ids from the start; `sync.mjs cite` audits it, tested)
- [x] Ends with `Next: /to-tickets-lee` or `Next: approve N decisions on the page, then /to-tickets-lee` (step 5, gated on no pending `Spec` card)
- [ ] Verified by a real run on mealplanning (needs Lee: a grill or a conversation to write a spec from)

## Comments

2026-09-14: `sync.mjs` gained `answeredLinks` and the `linked` CLI so the skill loads the grill's
rulings (decisions `linked:` to an answered question) in one call, and `specCitations` with the
`cite` CLI so "the spec cites ids and lists no rejected item" is a command's output rather than a
reading. The spec cites a card's id the moment the card is written; after Finish, the prologue's
step 6 removes the paragraphs whose ids were rejected, and `cite` shows `rejected: []`. Ticket
04's open follow-up (a question answered by a later-rejected decision) is not resolved here:
`linked` marks such a pair `stale`, the skill reports it and states nothing from it, and the
README says the ratifier re-asks. A reopen path is Lee's call. Run on the real files, `linked`
lists nothing yet (no grill has run) and `cite` finds 22 decision paragraphs in the mealplanning
spec, 17 cited, 5 uncited, none rejected or unknown.
Review fixes: `cite` now flags a paragraph naming any rejected id (with `gone` saying which),
reads ids on the files' own prefix so prose like sha-256 is not an id, reports `pendingSpec`
(the gate) apart from `pending`, and `unstated` (answered-question decisions the spec never
states); the prologue's step 6 owns the spec rewrite for both decision sections including
amended text, and the skill points at it instead of restating it; card rules point at `/ssot
backfill`; the `Next:` line has only the epilogue's two forms; the CLI reads the two files
through one `readPair`.
