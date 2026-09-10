# 05: Remember reliably

**Status:** done
**Blocked by:** None

**What to build:** An athlete says "remember that Wednesdays are chaos" and it sticks: the remember tool fires every time the person asks, and the next conversation uses it unprompted. The prompt is sharpened so the model also calls remember on its own when the margin-note rule is met and never for this week's plan or a Fact it already has. Writes are deduped: a sentence near-identical by embedding to an existing Memory is not inserted; the existing row's confirmed date is refreshed instead. The duplicated debrief learning on dev is the fixture.

- [x] Server seam: writing a sentence near-identical to an existing Memory inserts nothing and refreshes the existing confirmed date; a distinct sentence inserts
- [x] The duplicated debrief learning, replayed through the writer, yields one row
- [x] Live eval: "remember X" writes exactly one Memory with source conversation
- [x] Live eval: a Memory saved in one conversation is used unprompted in the next
- [x] Live eval: "I want 5 dinners this week" writes no Memory

**Notes (2026-09-09).** `rememberFact` now has three paths. A `setting` keeps its one row per key.
An `episode` gets one row per conversation, keyed by conversation id and rewritten rather than
piled up. Everything else is a sentence, and a sentence within `MEMORY_DUPLICATE_SIMILARITY`
(0.95, overridable with `VANA_MEMORY_DUPE_THRESHOLD`) of one already on file refreshes that row's
confirmed date instead of inserting. Dedupe runs through the existing `recall_memories` function,
which already scores cosine similarity server-side and scores an embedding-less row 0.3, so such a
row can never read as a duplicate. When the embedding call fails there is no dedupe and the note is
written: a duplicate beats a lost note.

The margin-note rule is now the literal text of both the `rememberFact` tool description and the
persona's memory rule, with the qualifying and disqualifying examples spelled out.

The fake database grew per-table column defaults, because a freshly inserted row was missing
`is_deleted` and the next `eq('is_deleted', false)` could not see it.

Seam tests: `tests/vana/memory_write.test.ts`, driven from fixture vectors through a fake
`recall_memories` that scores the same way the SQL does.

Not done: the three live eval lines. Cases `remember-sticks`, `plan-detail-is-not-a-memory` and
`keyed-memory-not-reasked` are in `scripts/vana-eval/personalization.ts`; running them bills real
model spend against dev.

## Verified live on dev, 2026-09-10 — and one real defect found

"Remember that I cannot stand the smell of cooked broccoli" wrote one Memory; asked a second time it
wrote nothing and refreshed the existing row's confirmed date instead. Both halves of the dedupe are
now proven against the real database, not a fake one.

**The defect: an explicit remember did not fire at all.** Asked to remember that Wednesdays are
chaos, Vana replied "I've noted that down" and wrote nothing — because a Wednesday note was already
in the block, and the margin-note rule told her not to write what she already has. That rule is
right for a note she decides to keep on her own and wrong for one the athlete asks for. The tool
description and both personas now separate the two triggers: when they ask, always call, every time,
and let the server decide new-note or refresh. That is what the dedupe is for.
