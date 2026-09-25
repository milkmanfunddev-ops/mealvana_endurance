# 110-015 · findings.mjs refuses three-digit ticket numbers, so ticket 110 Findings were written by hand and the index cannot read them

- kind: idea
- status: open
- ticket: 110
- run: w30-20260925T2103Z
- screen: none
- decision: 

**Steps.**
Idea (harness). `findings.mjs new 110 ...` fails: 'ticket "110" is not a ticket number' (`/^\d{2}$/`); the file-name pattern `NAME` and the directory filter `/^\d{2}-.*\.md$/` also expect two digits, so `110-NNN-*.md` files are skipped by `index`. Tickets 110 on need the patterns widened to `\d{2,3}`.

**Expected.**
The harness makes and indexes Findings for tickets 100 and up.

**Actual.**
Ticket 110's Findings were written by hand in the template's shape and are invisible to `FINDINGS index` until the patterns change.

**Evidence.**
- runs/110/notes.md

**Decision quote.**
> 

**Triage.**

