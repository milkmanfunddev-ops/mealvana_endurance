# Decisions

The single source of truth for product decisions. One markdown file per feature.
No ruling enters a file here except on a ratifier's verdict (Lee or Xuan), given on the decisions page.
Agents never edit these files by hand; the sync module in `_page/` applies verdicts, and its
`attach-svg` and `attach-image` commands set a card's picture (Drawn pictures and Captured
pictures below), which changes no ruling.

This folder is app-owned. It sits outside the QA mirror's rsync scope, so a sync
from `../mealvana_endurance_qa` never touches it.

## Fresh clone

Everything here runs from a checkout of this repo. Nothing reads a user name or a session id;
every path is repo-relative, and the page's data lives in the artifact's own database, not on
anyone's laptop. Two things are read from the home directory: Matt Pocock's skills plugin in
Claude Code's plugin cache, which the -lee skills follow at run time (`MATT_SKILLS_ROOT`
points elsewhere if the cache lives elsewhere), and the `idb` tools the capture command
looks for in `~/.local/bin` (Captured pictures below).

1. Install Node 20 or newer. The sync module is plain ESM with no dependencies.
2. Test: `node --test docs/ssot/decisions/_page/sync.test.mjs` (all cases must pass).
3. Apply verdicts: `node docs/ssot/decisions/_page/sync.mjs apply <verdicts.json> .scratch/<feature>/decisions.md docs/ssot/decisions/<feature>.md`.
   `verdicts.json` is the page's queued verdicts: a Claude Code session reads the `verdicts`
   collection with `read_db` (where `applied` is false) and saves it as that file. The Finish
   button only wakes the watching session. `apply` writes only the two named files; the only
   other commands that write a record are `attach-svg` (one `svg:` line) and `attach-image`
   (the `image:` and `caption:` lines plus one dated history line saying where the picture came
   from); `pictures` runs `attach-image` for every card that needs one.
4. Open the page: the artifact link below. Lee shares it with each ratifier from the page's
   share menu. Whoever opens it picks their name in the header once per browser, and every
   verdict they give carries it as `by`. The platform tells the page nothing about the viewer,
   so that chooser is the identity.
5. Reseed the page after the files change:
   `node docs/ssot/decisions/_page/sync.mjs prepare docs/ssot/decisions/<feature>.md .scratch/<feature>/decisions.md --assets docs/ssot/decisions/_page/assets.json --tickets <feature>=.scratch/<feature>/issues --out <dir>`,
   then `write_db` the batches in `<dir>/_batches.json`. Redeploy `_page/index.html` only when
   the page's design changes, always to the same artifact URL.

## Where things live

| What | Where |
|---|---|
| Approved, rejected, withdrawn decisions | `docs/ssot/decisions/<feature>.md` |
| Proposals waiting on Lee | `.scratch/<feature>/decisions.md` |
| New screenshots and drawn diagrams | `docs/ssot/decisions/images/<feature>/` (a capture is `<screen key>.png` beside a `<screen key>.json` sidecar with the commit and app version) |
| Which screen a card's `screen:` line means, and how to reach it | `_page/screens.json` |
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
- svg: <repo path of a drawn diagram; every screenless card has one, see Drawn pictures>
- screen: <which app screen shows this, or "none (algorithm/data)">
- source: <spec path; ticket NN; ADR; commit; grill <date>; Lee on the page <date>>

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

The `Spec` category holds what a spec decides: its test seams and its implementation and
testing decisions, written by `/to-spec-lee` with `source: spec <feature> <date>`. The spec cites
each card's id in parentheses at the end of the paragraph it came from, so `sync.mjs cite` can
say which paragraphs stand, which were rejected, and which name no decision.

The `Tickets` category holds a ticket breakdown waiting for approval, written by
`/to-tickets-lee` with `source: tickets <feature> <date>`. Each card carries three more meta
lines: `- ticket: NN` (the number its file will get), `- blocked: NN, NN` (the blockers the
breakdown declared, optional) and `- depends: <id>, <id>` (the decision ids the ticket relies
on). Its **What it touches** line is a comma-separated list of repo paths; `sync.mjs ticket-plan`
turns two tickets that touch the same path (or a directory one sits in) into a blocking edge,
the lower number blocking the higher; the page shows the card's `blocked:` numbers as a
"Blocked by" line under the Decision. `sync.mjs publish-tickets` writes the approved cards as
ticket files under `.scratch/<feature>/issues/`: the local ticket template with the three header
lines the Work page reads (`**Status:** ready-for-agent`, `**Blocked by:**` with each overlap
edge annotated `(touches <path>)`, `**Next:**`), a `**Decisions:**` line citing the `depends:`
ids and the card's own id, a `**Touches:**` line, the Details as `- [ ]` acceptance criteria,
and a closing `Next:` line. It refuses while a ticket card is pending, a declared blocker is not
a lower number, or a `depends:` id was rejected or withdrawn, and skips a number that already
has a file.

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

A decision that answers a question (`linked:` to a question that is `answered`) is what
`sync.mjs linked` lists; `/to-spec-lee` states these in the spec first. A decision rejected or
withdrawn after it answered leaves the question pointing at a ruling that no longer stands;
`linked` marks it `stale` and the skills report it. There is no reopen path yet: the ratifier
re-asks it on the page or in a grill.

A question is closed by `sync.mjs answers <question id> <decision id> <proposals.md> <ssot.md>`.
The question becomes `- status: answered` with a history line `> <date> answered by <decision id>`,
and the decision (in either file) gets `- linked: <question id>`, appended after any link it
already carries. Only an open question can be answered; anything else is refused and neither
file is written.

Every verdict may carry `by`, the name of who gave it. The history line then ends with the
name: `> 2026-09-14 approved by Lee`, `> 2026-09-14 rejected by Xuan: too early`. A verdict
without `by` still applies and writes the bare line. The page always sets `by` from the name
chosen in its header and refuses a verdict while no name is chosen. A ruled card shows its
newest verdict line as `approved by Lee, 09-14` (page documents carry a `ruled` summary from
`sync.mjs`). Pressing Approve on an approved decision
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

A ruling that reverses an approved decision (in a grill or on the page) is a new proposal whose
Context names the id it reverses. The old card stays approved until a ratifier withdraws it on
the page; nothing in the tooling withdraws it for them.

## Drawn pictures

A card whose `screen:` starts with `none` has nothing to screenshot, so it gets a drawn picture
of its mechanism instead: boxes and arrows, or a timeline, and one worked example with real
numbers. The skill that proposes the card draws it (epilogue step 0) and `/ssot backfill` draws
one for every screenless card that has none. Nothing draws by hand: a spec in JSON goes through
`sync.mjs draw` (`_page/diagram.mjs`, spec shapes at the top of the file), which writes
`docs/ssot/decisions/images/<feature>/<id>.svg` and refuses anything that is not inline SVG in
the page's colour tokens (`var(--token, fallback)`, no raster, no stock art, no other colour).
`sync.mjs attach-svg` checks the file again and sets the card's `svg:` line; `prepare` inlines
the file into the page document, where the page shows it in the picture box in both themes.
The spec files live beside the run that drew them (`.scratch/ssot/diagrams/`) and are not the
source of truth; the SVG is. `sync.mjs undrawn` lists what still needs one. A card that names a
screen is captured, not drawn (ticket 08), unless the ratifier asks for a drawing of its
mechanism as well (mp-266, the trial timeline).

## Captured pictures

A card that names a screen is pictured from the app, not drawn. `sync.mjs pictures <feature>
<proposals.md> <ssot.md>` (epilogue step 0b) takes every card with a screen and `image: none`,
looks the screen up in `_page/screens.json`, and either reuses the golden or design frame the
entry names (story 16: an existing picture of exactly that screen comes first) or drives the
booted simulator there and photographs it. One capture per screen per run, however many cards
name it. The image is `docs/ssot/decisions/images/<feature>/<screen key>.png`; its sidecar
`<screen key>.json` records the screen, the commit, the app version (`pubspec.yaml`), the device
and the runtime, and `prepare` carries it into the page document as `captured`. `attach-image`
sets the card's `image:` line and appends one dated history line, `picture captured at
1.26.0+1, 43496fed` or `picture reused from <path>`, so the record says where every picture came
from. A screen with no drive and no reuse (the paywall: only a Pro-required error reaches it,
and the dev account is Pro) is reported and left as it was.

`screens.json` is the registry: one entry per screen with `match` (the phrases a card's
`screen:` line may use; each comma-separated part is tried, exact first, then the longest
phrase it contains), optionally `reuse` (a repo path: an existing picture of exactly that screen,
named by hand, since a golden's file name says nothing certain about what it shows) and `drive` (steps from a fresh launch: `{"tap": "<label>", "type"?}` taps the
element with that accessibility label, first line exact, then substring; `{"tapAfter":
"<label>", "type"}` taps the next element of a type after the labelled one; `{"wait": ms}`;
`settle` on a step overrides the pause after it). Every drive starts from terminate + launch. On
the simulator the dev wrench overlaps the Vana launcher, so the Vana drives go in through the
Plan tab's Vana card, not the launcher. `sync.mjs capture <feature> <screen>` takes one picture
by hand, following the drive even when the entry also names a `reuse` (re-capturing a screen
rewrites its png and sidecar in place; the cards that point at it need nothing).

Setup, once per machine: `scripts/ssot-capture-setup.sh` installs the `idb` client (pipx) and
Facebook's prebuilt `idb_companion` under `~/.local` (Homebrew's facebook/fb tap fails to tap
and its formula wants newer Command Line Tools). `sync.mjs capture --check` (it terminates and relaunches the dev app to ask it) then says what is
still missing: idb, the companion, a booted simulator, the dev app on it, or an app that
answers with an empty accessibility tree after a fresh launch. That last one was the 09-14
blocker: a debug session left from the day before had the app painted but deaf, so every tap
"succeeded" and nothing moved. Every capture now starts with terminate + launch, which clears it.

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

## Skills

`/ssot` in `.claude/skills/ssot/` opens the page and applies verdicts; `/ssot backfill <feature>`
mines a feature's spec, tickets, ADRs and docs into proposals. Its `prologue.md` and `epilogue.md`
are the steps every -lee skill runs before and after Matt Pocock's skill of the same name, and
`matt.mjs <name>` prints the path of Matt's skill in the plugin cache (newest version; a missing
file exits 1 with the path it looked for). Tests: `node --test .claude/skills/ssot/matt.test.mjs`.
`/grill-with-docs-lee <feature> [<question id>]` in `.claude/skills/grill-with-docs-lee/` runs the
prologue, follows Matt's grill-with-docs, and walks the feature's open questions first, one per
round, in the ratifier's order; on `done` every ruling becomes a proposal, every answered question
is closed through `answers`, and a ruling that fits no card becomes an open question in their
words. `/to-spec-lee <feature>` in `.claude/skills/to-spec-lee/` runs the prologue, follows
Matt's to-spec, and puts the spec's test seams and every new implementation and testing decision
on the page as `Spec` category cards (Context opens with the spec's problem statement) instead of
confirming them in the terminal; the spec cites each card's id from the start, and after the
ratifier's Finish the prologue drops the rejected paragraphs. It ends with `Next: /to-tickets-lee`
only when no `Spec` card is pending. `/to-tickets-lee <feature>` in `.claude/skills/to-tickets-lee/`
runs the prologue, stops while any `Spec` card is proposed or amended (`sync.mjs pending
<proposals.md> Spec`), follows Matt's to-tickets, and puts the breakdown on the page as one
`Tickets` card per ticket with its blockers, its touches and the decision ids it depends on,
instead of quizzing in the terminal; touches that overlap become blocking edges
(`ticket-plan`), and the ticket files are written (`publish-tickets`) only once every card is
approved, each with the three header lines the Work page reads, a `**Decisions:**` line citing
its ids, and a closing `Next:` line. `/implement-lee` arrives with ticket 10 in
`.scratch/ssot/issues/`.

## Sync module

`_page/sync.mjs` exports `parse`, `serialize` (byte-identical round trip), `apply` (verdicts from
the page into the two files), `answers` (close an open question with a decision), `openQuestions`, `questionFirst`,
`answeredLinks` (decisions that answered a question), `specCitations` (what a spec's decision
sections cite), `pendingIn` (the pending cards of one category), `ticketPlan` (ticket cards with
their blocking edges), `publishTickets` (approved ticket cards to files), `fold`, `clauses` and
`ticketDocument`, `svgCheck`, `checkedSvg`, `undrawn`, `attachSvg`, `uncaptured`, `attachImage` and `readSidecar`; `_page/diagram.mjs` exports `draw` and the token list; `_page/capture.mjs` exports `loadScreens`, `matchScreen`, `findElement`, `runDrive`, `capture`, `sidecar`, `simulatorIo`, `bootedUdid`, `stamp` and `doctor`. Tests: `node --test docs/ssot/decisions/_page/sync.test.mjs`;
every case feeds a markdown fixture, a spec or an svg string and checks what comes out, never
how the parser walks lines; one case round-trips the real mealplanning record and proposals. CLI:

```
node docs/ssot/decisions/_page/sync.mjs export <decisions.md>...   # page documents as JSON
node docs/ssot/decisions/_page/sync.mjs apply <verdicts.json> <proposals.md> <ssot.md>
node docs/ssot/decisions/_page/sync.mjs answers <question id> <decision id> <proposals.md> <ssot.md>
node docs/ssot/decisions/_page/sync.mjs questions <proposals.md> [<ssot.md>]   # the open questions as JSON, file order, nothing written
node docs/ssot/decisions/_page/sync.mjs linked <proposals.md> [<ssot.md>]   # decisions that answered a question, as JSON; `stale` when later rejected or withdrawn
node docs/ssot/decisions/_page/sync.mjs cite <spec.md> <proposals.md> [<ssot.md>]   # what the spec's Implementation and Testing Decisions cite: statuses, paragraphs naming a rejected id, uncited paragraphs, unknown, pending and pendingSpec ids, unstated answers
node docs/ssot/decisions/_page/sync.mjs pending <decisions.md> [<category>]   # a count; with a category, {category, count, ids} of its proposed and amended cards
node docs/ssot/decisions/_page/sync.mjs ticket-plan <feature> <proposals.md> [<ssot.md>]   # the ticket cards with declared blockers, touches overlaps and the resulting edges, as JSON; nothing written
node docs/ssot/decisions/_page/sync.mjs publish-tickets <feature> <proposals.md> <ssot.md> <issues dir> --next <command>   # one file per approved ticket card; refuses (with why) while one is pending, blocked by a later number, or built on a rejected id; skips numbers that have a file
node docs/ssot/decisions/_page/sync.mjs question-first <decisions.md>...   # lift "The question was X." into Question
node docs/ssot/decisions/_page/sync.mjs fold <plan.json> <proposals.md> <ssot.md>   # combine proposals per the plan
node docs/ssot/decisions/_page/sync.mjs tickets <feature> <issues dir>   # ticket documents as JSON
node docs/ssot/decisions/_page/sync.mjs prepare <decisions.md>... --assets <assets.json> --tickets <feature>=<dir> --out <dir>
node docs/ssot/decisions/_page/sync.mjs triage <verdicts.json> --out <dir>   # clear.json to apply now, words.json to synthesise first, rewrites.json to apply after the yes
node docs/ssot/decisions/_page/sync.mjs next-id <proposals.md> <ssot.md>     # the next free id across both files
node docs/ssot/decisions/_page/sync.mjs images <assets.json> <_images.json>  # images still to upload: new, changed, file missing
node docs/ssot/decisions/_page/sync.mjs asset <assets.json> <path> <asset id> # record one upload, keyed by path and hash
node docs/ssot/decisions/_page/sync.mjs undrawn <proposals.md> [<ssot.md>]   # screenless cards with no drawn picture, as JSON; questions and ruled-out cards are skipped
node docs/ssot/decisions/_page/sync.mjs draw <spec.json> [<out.svg>]         # draw a diagram from a spec; refuses one that fails the check
node docs/ssot/decisions/_page/sync.mjs attach-svg <decisions.md> <id> <svg path>  # check the file, set the card's svg line
node docs/ssot/decisions/_page/sync.mjs uncaptured <proposals.md> [<ssot.md>]   # screen cards with no picture and how each would get one (reuse, capture, none), as JSON
node docs/ssot/decisions/_page/sync.mjs capture --check                        # what stands between this machine and a capture
node docs/ssot/decisions/_page/sync.mjs capture <feature> <screen>             # drive the booted simulator to the screen; png + sidecar under images/<feature>/
node docs/ssot/decisions/_page/sync.mjs attach-image <decisions.md> <id> <png> [--caption <text>]  # set the image line, record where the picture came from
node docs/ssot/decisions/_page/sync.mjs pictures <feature> <proposals.md> <ssot.md>   # uncaptured -> reuse or capture -> attach, one capture per screen
```

`triage` sorts the page's verdicts the way the skills apply them: approve, withdraw and reject with
a plain reason go to `clear.json`; a rewrite, an accepted change card, a new term, and a rejection
whose reason contains a question mark go to `words.json`; anything else (a dismissed change card)
is only counted. `rewrites.json` is the amend and change subset of `words.json`, the only part
`apply` ever takes, and only after the ratifier has said yes to the synthesis.

`_page/assets.json` maps a repo image path to the artifact asset it was uploaded as. Entries are
`{"id", "sha256"}` (the first entries are bare ids and still resolve). `prepare` writes
`_images.json` beside its output; `images` lists which of those need an upload, and `asset`
records one after `upload_asset` returns its id. An image is uploaded again only when its hash
changed.

A fold plan is `[{from: [ids], into: {title, question, context, decision, why, alternatives, touches, details?, detail?, work?}}]`.
Only proposed or amended cards fold; anything with a verdict is refused. After a fold, delete the
folded ids from the `decisions` collection and set the new ones.

An `amend` verdict may carry `dropped: [n, …]`, the clause numbers Lee ticked. `apply` records
them in **Lee said** ahead of his words.
