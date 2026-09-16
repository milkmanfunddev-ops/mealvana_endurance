# 06: `/to-tickets-lee`

**Status:** done (2026-09-14); the first real run waits on a feature with an approved spec
**Blocked by:** 03.
**Next:** `/mattpocock-skills:implement 07`

**What to build:** Lee runs `/to-tickets-lee` and it refuses if any "spec" category card is still
proposed or amended. Otherwise it follows Matt's to-tickets, but the breakdown goes to the page as
one section per ticket with its blockers and a touches list, not to the terminal. Where two
tickets touch the same code the overlap becomes a blocking edge. Ticket files are written only
once every ticket section is approved; each cites the decision ids it depends on, carries the
three header lines the Work page reads, and ends with a `Next:` line. Stories 26 to 29.

- [x] A pending spec-category card makes the skill stop with the count and the link
- [x] The breakdown appears on the page as ticket sections with blockers and touches
- [x] Overlapping touches produce blocking edges in the published files
- [x] Files are written under `.scratch/<feature>/issues/` only after every section is approved, and are seeded to the Work page
- [x] Every ticket cites decision ids and ends with `Next:`
- [x] Ends with `Next: /implement-lee`

## Comments

2026-09-14, built. Skill at `.claude/skills/to-tickets-lee/SKILL.md`; `sync.mjs` gained `pendingIn`
(`pending <file> <category>`), `ticketPlan` (`ticket-plan`) and `publishTickets` (`publish-tickets`);
36 tests pass. Ticket cards are `category: Tickets` with `ticket:`, `blocked:` and `depends:` meta;
the page shows the blockers under the Decision. Not run on a real feature yet: no feature has an
approved spec with Spec cards. Code review asked for and got: forward edges refused, rejected
`depends` ids refused, overlap evidence kept when an edge is also declared, no default `Next:`.
