# 09: Pictures carry their age and are refreshed

**Status:** done
**Blocked by:** 08.
**Next:** `/mattpocock-skills:implement 10`

**What to build:** Under every captured picture the page says when it was taken, like "captured at
1.26.0, 12 days ago", and marks it stale when the screen's code has changed since that commit. A
refresh command re-captures every stale image in one pass. Old pictures from earlier builds are
replaced, never kept beside the new one. The Pictures section, third requirement.

- [x] The page shows version and age under each capture from the recorded metadata
- [x] A capture is marked stale when files the card touches changed after its commit
- [x] `refresh` re-captures every stale image in one pass and re-uploads only what changed
- [x] A refreshed picture replaces the old file and asset; nothing old remains referenced
- [x] The Work page lists the stale count per feature

**Done 2026-09-14.** Age comes from the capture's sidecar, or for a golden or design frame from
git (the commit that last touched it, its date, the pubspec version at that commit). Each
`screens.json` entry now lists the `code` its screen is drawn from; a picture is stale when a
file under those paths differs between its commit and the working tree (uncommitted edits
count). `prepare` puts `captured.{how,key,stale,changed}` in the page document; the page shows
"captured at 1.26.0+1, today" or "golden from 1.26.0+1, 3 days ago" under the picture with a
stale mark naming how many files moved, and the Work page counts and lists the stale pictures
per feature with their cards. `sync.mjs stale` reports; `sync.mjs refresh` retakes every stale
picture once (in place for a capture; a stale golden's cards move to the capture with one
history line). `asset` prints the id it replaced, `images` lists unreferenced assets, `asset
--drop` forgets one; the epilogue deletes them. First run: the plan-tab golden (5 cards, 8 files
changed since) was retaken from the simulator and its asset deleted; the two Vana sheet goldens
(10 cards) stay stale because no drive opens the sheet on the simulator. Pictures matched to no
registry key (design frames, hand-picked goldens) show their age with no staleness claim.
`/implement-lee` re-capturing a ticket's screens on close is ticket 10.
