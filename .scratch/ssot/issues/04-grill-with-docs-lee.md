# 04: `/grill-with-docs-lee`

**Status:** done (2026-09-14); the real grill of mp-267 is the next thing Lee runs
**Blocked by:** 03.
**Next:** `/mattpocock-skills:implement 05`

**What to build:** Lee runs `/grill-with-docs-lee mealplanning` and the grill opens with the
feature's open questions, one at a time in his order, never re-asking what he has already ruled.
For the rest it follows Matt's grill-with-docs read from disk. When he says "done", every ruling
from the transcript is on the page as a proposed decision linked to the question it answers,
every answered question is marked, every unsettled question stays open, and the end report says
how many closed, how many stay open, and how many proposals were pushed. Nothing said in the grill
is lost: a ruling the extractor cannot place becomes an open question in Lee's words. Stories 49 to 51.

- [x] The grill loads approved decisions, open questions, `CONTEXT.md` and the ADRs before its first question (SKILL.md step 3; `sync.mjs questions` lists the open ones, tested)
- [x] Open questions come first, one at a time, in Lee's order (step 4; a question id on the command line goes first, `skip` parks one)
- [x] On "done" each ruling is a proposal with question, decision, why, alternatives, touches and `linked:` to its question (step 5.1 and 5.2)
- [x] Each answered question is marked through `answers`; unanswered ones remain open on the page (step 5.2 and 5.3; `answers` refuses anything but an open question, tested in ticket 01)
- [x] The end report counts closed, still open, pushed, and ends with `Next: /to-spec-lee` (step 5, report block)
- [ ] Verified by grilling the trial move (open question mp-267) for real (needs Lee at the terminal: `/grill-with-docs-lee mealplanning mp-267`)

## Comments

2026-09-14: `sync.mjs` gained `openQuestions` and the `questions` CLI so the skill loads the open
questions from both files in one call and never re-reads them to ask. Matt's grill-with-docs is a
two-line file that calls his `grilling` and `domain-modeling` skills; both are model-invocable, so
the skill reads his file and does what it says rather than copying either. The synthesis-before-
writing rule is not repeated on `done`: the grill is the terminal discussion, and a proposal is
the state that waits for Approve. The grill of mp-267 was not run: it needs Lee's answers.
Review fixes: `openQuestions` reuses `toDocuments` instead of a second field map; the skill no
longer states what Matt's file contains today or restates the card format (README owns both);
`Next:` is always `/to-spec-lee`; the README now records `source: grill <date>` and the rule for
a ruling that reverses an approved decision. Open follow-up from the spec review: `answers` can
mark a question in the record `answered` by a decision that is still proposed, and a later
rejection of that decision leaves the question pointing at a rejected id. No reopen path exists;
raise it with Lee before ticket 05 relies on `linked:`.
