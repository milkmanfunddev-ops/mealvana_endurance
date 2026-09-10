# 08: What Vana knows

**Status:** done
**Blocked by:** None

**What to build:** An athlete opens Vana settings and sees everything she remembers as one flat list of sentences, each with its source and date, newest first. Keyed Memories (batch cooking, coverage, budget, pantry) appear as sentences like any other. Swiping or tapping delete removes a Memory in place and Vana stops using it from the next turn. Facts are not listed here; they are edited where they already live.

- [x] Vana settings shows a flat list of Memories with source and date, newest first, using shared design widgets and content-system strings
- [x] Delete goes through the real notifier with a seam test: the row is soft-deleted locally first with upload tracking and reaches the server
- [x] A deleted Memory is absent from the next turn's block, proven at the server seam
- [x] Empty state reads sensibly for a new user
- [x] Golden for the list on the glass shell

**Notes (2026-09-09).** Most of this already existed; what changed is what the athlete sees.

- The kind tag is gone from each row. The kinds stay in code — for the keyed settings mechanism and
  the episode summaries — and the list is now what the spec asked for: a sentence, where it came
  from, and when it was last confirmed.
- `watchMemories` used to exclude settings, so a keyed Memory was invisible. It now includes them
  and excludes episodes instead, because an episode is one conversation's own summary rather than a
  fact about the person; episodes surface in the conversation list through the summary column.
- Seam test through the real notifier: delete leaves a local tombstone flagged for upload, the state
  the screen renders drops the row, and the upsert reaches the server carrying `is_deleted`.
- Server seam: a deleted Memory is absent from the next turn's context block, and the row is still
  on file as a tombstone rather than hard-deleted.
- Goldens: `memory_list` and `memory_list_empty`, light and dark, on the glass shell.

97/97 local edge-function tests and 418 meal-planning Flutter tests pass.
