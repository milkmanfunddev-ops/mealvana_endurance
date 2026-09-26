---
name: to-tickets-lee
description: "Matt's to-tickets with the decision record around it: the breakdown is approved in the terminal and written straight to ticket files, each citing the decisions it builds on. Tickets never become cards. `/to-tickets-lee <feature>`."
disable-model-invocation: true
---

The decision record and its rules: `docs/ssot/decisions/README.md`. Read it once per session.
`SYNC` means `node docs/ssot/decisions/_page/sync.mjs`; `<feature>` is the slug in the argument;
`RECORD` is the five record files (`prologue.md`), `SPEC` is `.scratch/<feature>/spec.md`,
`ISSUES` is `.scratch/<feature>/issues/`.

## 1. Catch up

Run `.claude/skills/ssot/prologue.md`.

## 2. Find Matt's skill

```
node .claude/skills/ssot/matt.mjs to-tickets
```

Read the file it prints and follow it. A non-zero exit is a stop: report the path it looked for
and end the turn. His text stays in his file. Gathering context, drafting the vertical slices
with their blockers, presenting the numbered breakdown in the terminal and publishing to the
local tracker all run as he writes them.

## 3. What each ticket carries

Read `SYNC export RECORD` before drafting. Every slice comes from approved decisions and the
spec. Note the tickets already in `ISSUES`: new numbers continue after the highest one.

Each ticket file has the local template's header lines that `sync.mjs wave` reads
(`**Status:** ready-for-agent`, `**Blocked by:**`), plus:

- `**Model:** fable` when the ticket needs judgment beyond its criteria (the fuelling engine or
  `docs/ssot/vectors/`, sync or write consistency); otherwise `opus`;
- `**Decisions:**` the record ids it builds on;
- `**Touches:**` the repo paths it will change. Two tickets touching the same path get a
  blocking edge, the lower number first;
- the acceptance criteria as `- [ ]` lines, and a closing `Next: /implement-lee <feature>`.

## 4. Approval

Lee approves the breakdown in the terminal (Lee, 2026-09-21). Present it as Matt's skill does
and end the turn with:

```
Next: say "good to go" (or what to change), and I write the N ticket files
```

On the go, write the files. Tickets are never cards on the page (Lee, 2026-09-26).

## 5. Hand over

```
Written: N tickets to ISSUES
Next: /implement-lee <feature>
```
