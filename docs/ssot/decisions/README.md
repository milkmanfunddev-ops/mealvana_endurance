# Decisions

The single source of truth for product decisions. One markdown file per feature.
Nothing enters a file here except on Lee's verdict, given on the decisions page.
Agents never edit these files by hand; the sync module in `_page/` applies verdicts.

This folder is app-owned. It sits outside the QA mirror's rsync scope, so a sync
from `../mealvana_endurance_qa` never touches it.

## Where things live

| What | Where |
|---|---|
| Approved, rejected, withdrawn decisions | `docs/ssot/decisions/<feature>.md` |
| Proposals waiting on Lee | `.scratch/<feature>/decisions.md` |
| New screenshots and drawn diagrams | `docs/ssot/decisions/images/<feature>/` |
| Existing screenshots elsewhere in the repo | referenced by path, never copied |
| The page template and sync module | `docs/ssot/decisions/_page/` |
| The published page | see `Artifact:` below |

Artifact: https://claude.ai/code/artifact/2b18d770-da55-443e-8740-483a422db8ac

## File format

```
# Decisions: <feature name>

Feature: <slug>
Feature name: <display name>
Last extracted: <git sha>

## <slug>-001 · <Title in plain words>
- category: <Category>
- status: proposed | approved | rejected | withdrawn | amended | open | answered
- image: <repo path> | none
- caption: <one line, optional>
- screen: <which app screen shows this, or "none (algorithm/data)">
- source: <spec path; ticket NN; ADR; commit>

**Context.** Two to four sentences: what the thing is, where it shows up, what was true before.

**Question.** The one question this section answers, as a phrase. The page shows it first.

**Decision.** One or two sentences, or a numbered list of clauses (`1. …` on its own line each).
A clause list lets Lee tick the clauses he wants dropped in Rewrite instead of rejecting the whole card.

**Why.** One or two sentences.

**What else was considered.** One sentence, or "none recorded".

**What it touches.** Screens and services, one line.

**Details.** Optional. Pixel sizes, timings and other numbers that belong below the fold.

> 2026-09-13 approved
```

Two optional meta lines: `- detail: yes` marks a card as implementation detail (the page sinks it
into a collapsed "Implementation details" block with its own Accept all), and `- work: pending`
marks a decision that reverses or extends what is built and has no ticket yet (the page's Work
page lists these as "Not yet ticketed").

One card per product question. When a build leaves several cards that answer one question, fold
them (`sync.mjs fold`) into one card with a clause list, and put the numbers in Details. The
folded ids are named in the new card's history line and never reused.

An amended section carries two extra parts before the decision, `**Original.**`
and `**Lee said.**`, and its `**Decision.**` is the rewrite awaiting approval.

An open question is a section with `- kind: question`, `- status: open`, and
`- linked: <id>` naming the decision it came from. Its parts are `**Context.**`,
`**Question.**` (Lee's words), `**Why.**` (why it matters), `**What it touches.**`.
It has no Approve button. The next `/to-spec-lee` or grill picks open questions up first.

A question is closed by `sync.mjs answers <question id> <decision id> <proposals.md> <ssot.md>`.
The question becomes `- status: answered` with a history line `> <date> answered by <decision id>`,
and the decision (in either file) gets `- linked: <question id>`, appended after any link it
already carries. Only an open question can be answered; anything else is refused and neither
file is written.

Every verdict may carry `by`, the name of who gave it. The history line then ends with the
name: `> 2026-09-14 approved by Lee`, `> 2026-09-14 rejected by Xuan: too early`. A verdict
without `by` still applies and writes the bare line. Pressing Approve on an approved decision
withdraws it (`> <date> withdrawn`); the earlier `approved` line stays.

Each category has a "Talk this category through" thread. "Suggest changes" asks in-page Claude
to turn that thread into a list of adds, edits and removals. Lee accepts or dismisses each one.
Accepted items are `change` verdicts (`{verdict: 'change', accepted: true, scope, change: {op,
id, title, context, decision, why, reason}}`). `sync.mjs apply` turns an add into a new proposed
section, an edit into an amended section carrying the original, and a removal into a rejection.
Nothing enters the SSOT file until Lee approves the resulting section like any other.

"Finish this category" publishes only that category's queued verdicts and stamps
`meta/state.finished[feature|category]`. "Finish everything" publishes them all.

Applying verdicts is two steps. Clear-cut verdicts (approve, withdraw, reject with a reason)
are applied at once. Anything with Lee's words in it (a rewrite request, a change card, a
rejection that is really a question) is first synthesised in the terminal: the skill says what
it thinks Lee meant, as rewrites, new decisions and open questions, and waits for his yes
before writing any of it to `.scratch` or the page. Nothing from this step ever enters
`docs/ssot/decisions/` directly.

When Lee types into "Rewrite", the skill triages his words into three piles:
a rewrite of that decision, new decisions he just made, and open questions. Each pile
becomes its own section. His words are never pasted into a decision as-is.

Every `>` line is a dated history entry. They are never removed.

## Vocabulary

The page's Vocabulary section mirrors the glossary in `CONTEXT.md` (seeded into the `vocab`
collection; reseed after editing the glossary). Glossary terms are underlined in every decision
with the definition on hover, and each category page lists the terms it uses. "Add term" on the
page queues a `term` verdict; `sync.mjs terms <verdicts.json> CONTEXT.md` appends accepted terms
under their area heading after Lee confirms them in the terminal.

## Work page

The page's Work entry lists, per feature: decisions with `work: pending` (not yet ticketed), open
questions, and the tickets in `.scratch/<feature>/issues/` split into ahead and done. Tickets are
seeded into the `tickets` collection by `prepare --tickets <feature>=<issues dir>`; their status,
blockers and next line come from the three header lines every ticket carries, and every `mp-NNN`
mentioned in a ticket becomes a link back to the decision.

## Sync module

`_page/sync.mjs` exports `parse`, `serialize` (byte-identical round trip), `apply` (verdicts from
the page into the two files), `answers` (close an open question with a decision), `questionFirst`,
`fold`, `clauses` and `ticketDocument`. Tests: `node --test docs/ssot/decisions/_page/sync.test.mjs`;
every case feeds a markdown fixture and checks the markdown that comes out, and the last case
round-trips the real mealplanning record and proposals. CLI:

```
node docs/ssot/decisions/_page/sync.mjs export <decisions.md>...   # page documents as JSON
node docs/ssot/decisions/_page/sync.mjs apply <verdicts.json> <proposals.md> <ssot.md>
node docs/ssot/decisions/_page/sync.mjs answers <question id> <decision id> <proposals.md> <ssot.md>
node docs/ssot/decisions/_page/sync.mjs pending <decisions.md>
node docs/ssot/decisions/_page/sync.mjs question-first <decisions.md>...   # lift "The question was X." into Question
node docs/ssot/decisions/_page/sync.mjs fold <plan.json> <proposals.md> <ssot.md>   # combine proposals per the plan
node docs/ssot/decisions/_page/sync.mjs tickets <feature> <issues dir>   # ticket documents as JSON
node docs/ssot/decisions/_page/sync.mjs prepare <decisions.md>... --assets <assets.json> --tickets <feature>=<dir> --out <dir>
```

A fold plan is `[{from: [ids], into: {title, question, context, decision, why, alternatives, touches, details?, detail?, work?}}]`.
Only proposed or amended cards fold; anything with a verdict is refused. After a fold, delete the
folded ids from the `decisions` collection and set the new ones.

An `amend` verdict may carry `dropped: [n, …]`, the clause numbers Lee ticked. `apply` records
them in **Lee said** ahead of his words.
