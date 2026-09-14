# 01: The sync module proves the spec's cases and learns `answers`

**Status:** done (2026-09-14)
**Blocked by:** None (can start immediately).
**Next:** `/mattpocock-skills:implement 02`

**What to build:** An agent in a fresh clone runs the sync module's tests and sees every case the
spec promises pass, then uses one command to close an open question with the decision that answers
it. Every verdict from now on says who gave it, so the record can tell Lee's ruling from Xuan's.

Cases the tests must cover, each fed a markdown fixture and checked on the markdown or documents
that come out, never on how the parser walks lines:

- parse a feature file to documents, serialise back byte-identical (exists; keep)
- approve moves a section from proposals to the record with a dated status line
- approve on an already-approved id marks it withdrawn and keeps the earlier history line
- reject records the reason in the record file
- amend produces a proposal carrying the original, Lee's words, and the rewrite
- an unknown id is refused and nothing is written
- files outside the two named are untouched
- a verdict carrying `by` puts the name in the history line; one without `by` still applies
- `answers`: an open question gets `status: answered` and a history line naming the decision;
  the decision's `linked:` points back; refuses a question that is not open

- [x] `node --test` on the module runs every case above green
- [x] `sync.mjs answers <question id> <decision id> <proposals.md> <ssot.md>` writes the link both ways
- [x] The README's format section documents `status: answered` and the `by` field
- [x] The existing mealplanning record and proposals still round-trip byte-identical
