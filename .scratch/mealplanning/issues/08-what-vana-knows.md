# 08: What Vana knows

**What to build:** An athlete opens Vana settings and sees everything she remembers as one flat list of sentences, each with its source and date, newest first. Keyed Memories (batch cooking, coverage, budget, pantry) appear as sentences like any other. Swiping or tapping delete removes a Memory in place and Vana stops using it from the next turn. Facts are not listed here; they are edited where they already live.

**Blocked by:** 05 Remember reliably

**Status:** ready-for-agent

- [ ] Vana settings shows a flat list of Memories with source and date, newest first, using shared design widgets and content-system strings
- [ ] Delete goes through the real notifier with a seam test: the row is soft-deleted locally first with upload tracking and reaches the server
- [ ] A deleted Memory is absent from the next turn's block, proven at the server seam
- [ ] Empty state reads sensibly for a new user
- [ ] Golden for the list on the glass shell
