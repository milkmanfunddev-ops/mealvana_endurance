# 03: `/ssot`: the hand-run round trip becomes a skill

**Status:** done (2026-09-14); backfill unexercised on a real feature
**Blocked by:** 01, 02.
**Next:** `/mattpocock-skills:implement 04 ssot`

**What to build:** Lee types `/ssot` and the session re-arms the artifact watch, opens the page,
applies whatever he has already ruled, and tells him how many cards still wait with the link.
`/ssot backfill <feature>` mines that feature's spec, tickets, archived tickets, ADRs and docs
into proposals on the page. Everything the 09-13 and 09-14 sessions did by hand moves into the
skill's prologue and epilogue, which the four -lee skills reuse unchanged.

Prologue: read unapplied verdicts from the database; apply the clear-cut ones (approve, withdraw,
reject with a reason) at once; anything carrying Lee's words (amend, accepted change cards, new
terms, a rejection that is really a question) is synthesised in the terminal as rewrites, new
decisions, open questions and glossary entries, and waits for his yes before any file changes;
rewrite the spec's Implementation Decisions section to cite ids and drop rejected items;
report applied and pending counts with the link.

Epilogue: push new proposals and reseed changed documents; upload new images once, keyed by path
and hash; report counts and the link; send a phone push when a gate now blocks on Lee; end with
one `Next: /<command>` line, or `Next: approve N decisions on the page, then /<command>`.

Matt's skills are read from the plugin cache at run time through a version glob. A missing or
renamed file stops the skill loudly. Nothing in CLAUDE.md triggers a skill.

- [x] `/ssot` with no argument re-arms the watch, prints pending count and link, and applies verdicts already on the page (run by hand this session: watch connected, queue empty, 18 pending)
- [x] Pressing Finish on the page while the skill waits, or typing "done" without a watch, both reach the apply step (SKILL.md, step 3; the notification path was proven on 09-14 by hand)
- [x] A verdict with Lee's words is shown as a synthesis and nothing is written until he says yes (`sync.mjs triage` splits the pile; prologue step 5)
- [ ] `/ssot backfill <feature>` produces proposals on the page from that feature's material, each with question, decision, why, alternatives, touches and source (written; not run, every backfill besides mealplanning is out of scope until Lee names one)
- [ ] A phone push arrives when the skill ends with cards waiting on Lee (epilogue step 4 sends one only when a gate blocks on a verdict, per story 36; the harness tool exists, an arrival has not been observed yet)
- [x] Renaming a Matt skill file makes the locator stop with the path it looked for (`matt.mjs`, tested)
- [x] The skill file does not restate CLAUDE.md rules and points at the README for the format

## Comments

2026-09-14: `.claude/` was wholly gitignored, so no project skill could reach a fresh clone;
`.gitignore` now ignores `.claude/*` except `.claude/skills/`. The prologue's spec step ran for
real on mealplanning: 18 of 19 Implementation Decisions paragraphs now cite ids, three rejected
passages were removed (mp-019, mp-026, mp-050), and "History is capped" stays uncited because
mp-032 is open under mp-217. The assets map is now keyed by path and hash; the first entries stay
bare ids. `sync.mjs` gained `triage`, `next-id`, `images`, `asset`. "Open the page" means
printing its link; a terminal cannot open the browser for the ratifier. Review fixes: `apply`
after a yes takes `rewrites.json` (amend and change only), never `words.json`; the push fires on
a blocked gate, not on any pending count.
