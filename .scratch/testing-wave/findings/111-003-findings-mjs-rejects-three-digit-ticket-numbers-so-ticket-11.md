# 111-003 · findings.mjs rejects three-digit ticket numbers, so ticket 111 cannot make or index its Findings

- kind: bug
- status: closed
- ticket: 111
- run: w30-20260925T2103Z
- screen: none
- decision: 

**Steps.**
1. `node scripts/testing-wave/findings.mjs new 111 "<title>" --kind bug --run w30-20260925T2103Z`.

**Expected.**
A Finding file `111-001-….md`, and `findings.mjs index` reads it.

**Actual.**
`Error: ticket "111" is not a ticket number`: `newFinding` checks `/^\d{2}$/`, `NAME` is `/^(\d{2})-(\d{3})-…/` and `readFindings` filters `/^\d{2}-.*\.md$/`, so a three-digit ticket (110 on) can neither make a Finding nor have one indexed. This run made its files with a scratch copy of the script that accepts `\d{2,3}` in those three places (not committed; the harness is unchanged), and checked them with that copy's `index`. The committed `index` skips every `111-*` file until the script is fixed. Ticket 110 hits the same.

**Evidence.**
- runs/111/notes.md (the line on findings.mjs)

**Decision quote.**
> 

**Triage.**

Closed (2026-09-26 triage): fixed by `f8ea7233`; `findings.mjs` takes three-digit tickets and the index reads every 1xx file.
