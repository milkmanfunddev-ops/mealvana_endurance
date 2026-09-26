# Decisions

The single source of truth for product decisions, written for Lee and Xuan. It holds approved
decisions only: no proposals, open questions, tickets, spec cards, build notes or rejected cards
(Lee, 2026-09-26). Five files, one per section:

| File | Section | Subsections |
|---|---|---|
| `mealplanning.md` | Meal planning (Vana, recipes) | Vana: who she is and how she talks · What Vana knows · Vana's tools · Planning a week · Plan tab and meals · Recipes and cooking |
| `paywall.md` | Paywall | Price and trial · Existing users · When Pro ends · Coach codes and restore · The paywall screen |
| `shopping-list.md` | Shopping list (Kroger) | Lists · Kroger (no approved Kroger decisions yet) |
| `ai-cost.md` | Cost cutting | Models · Caching · Usage budget |
| `misc.md` | Miscellany | Design system · Data and sync |

A subsection is a card's `category:`. The page shows them in this order (`FEATURE_ORDER` and
`CATEGORY_ORDER` in `_page/index.html`); a new subsection is added there too.

How a decision gets in: a skill puts the question to Lee in the terminal (AskUserQuestion, one
question at a time, recommended answer first). His answer is the approval, and the skill writes
the card straight into the record. Review-queue items Lee has delegated are decided by Claude
from the code, the docs and his earlier rulings, and are marked that way.

On the page every card has Approve, Reject and Rewrite, plus an Ask thread that can draft a
rewrite. Approve is a sign-off on a card that is already approved (for example Xuan confirming
it), and it adds a history line. Reject, Rewrite and accepted change cards reach the terminal on
Finish. The prologue puts each one to Lee, and his answer rewrites the card in place or deletes
it. The record never holds a rejected or pending card. A ruling that changes an existing
card rewrites that card in place (newest ruling wins) with a history line; the old wording stays
in git. Undecided items live in `.scratch/ssot/review-queue.md` until Lee answers them.

Agents write these files only that way (a decision Lee approved in the terminal) or through the
sync module's picture commands (`attach-svg`, `attach-image`, `pictures`, `refresh`), which change
no ruling. The 2026-09-26 overhaul rewrote all five files by hand at Lee's direction, once.

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
3. Open the page: the artifact link below. Whoever opens it picks their name in the header once,
   and every verdict they give carries that name. Finish sends the queued verdicts to the
   terminal (prologue).
4. Reseed the page after the files change:
   `node docs/ssot/decisions/_page/sync.mjs prepare docs/ssot/decisions/{mealplanning,paywall,shopping-list,ai-cost,misc}.md --assets docs/ssot/decisions/_page/assets.json --glossary CONTEXT.md --out <dir>`,
   then `write_db` the batches in `<dir>/_batches.json`, and delete from the `decisions`
   collection any id the files no longer hold. Redeploy `_page/index.html` only when the page's
   design changes, always to the same artifact URL.

## Where things live

| What | Where |
|---|---|
| Approved decisions | `docs/ssot/decisions/<section>.md` (the five files above) |
| Items waiting on Lee | `.scratch/ssot/review-queue.md` |
| New screenshots and drawn diagrams | `docs/ssot/decisions/images/<feature>/` (a capture is `<screen key>.png` beside a `<screen key>.json` sidecar with the commit and app version) |
| Which screen a card's `screen:` line means, and how to reach it | `_page/screens.json` |
| Existing screenshots elsewhere in the repo | referenced by path, never copied |
| The page template and sync module | `docs/ssot/decisions/_page/` |
| The published page | see `Artifact:` below |

Artifact: https://claude.ai/code/artifact/2b18d770-da55-443e-8740-483a422db8ac

## File format

```
# Decisions: <section name>

Feature: <slug>
Feature name: <section name>

## mp-NNN · <The decision, as a short plain statement>
- category: <subsection>
- status: approved
- folded: <older ids this card absorbed, optional>
- image: <repo path> | none
- caption: <one line, optional>
- screen: <which app screen shows this, or "none (algorithm/data)">
- source: <where it came from>

**Context.** One or two sentences: what the thing is and what was true before.

**Question.** The one question this card answers.

**Decision.** One to three plain sentences, with the real numbers or names where they matter.

**Why.** One or two sentences.

**What else was considered.** One sentence, or "none recorded".

> 2026-09-26 approved by Lee
```

What makes a card (Lee, 2026-09-26). One broad product decision a newcomer can read: "The
assistant is called Vana", "Existing users get one free month", "We track usage, not credits",
"You can have multiple shopping lists". Not a card: implementation detail (timings, step counts,
which widget reports what), ticket breakdowns, test seams, build order, and behaviour of the app
outside meal planning, Vana, recipes, the paywall, shopping lists, Kroger and cost cutting. Keep
cards few: fold a new ruling into the card it belongs to rather than adding a sibling.

Ids are `mp-NNN` in every file (`sync.mjs next-id` over all five files gives the next one) and are
never reused. `folded:` lists the older ids a card absorbed, so a code comment citing an old id
still finds its card (the page and search resolve it). Every `>` line is a dated history entry.

## Drawn pictures

**Every card gets a picture** (Lee, 2026-09-26): a capture when the card names a screen and one
exists, otherwise a drawing. A good picture explains the card, and it says something the words
alone make harder to see: the numbers laid out against time, the order of steps, or the two
options side by side. A bad picture repeats the card title in boxes. Examples:
- "New signups pay $24.99 a month or $199.99 a year, with founding prices until 30 November"
  → a timeline: 1 Oct, founding $12.49 / $99.99 → 30 Nov, founding plans come off sale →
  after that, $24.99 / $199.99, each with the 7-day trial.
- "A new meal plan starts with a read of the week and one question" → the first turns of the
  conversation in order: Vana's read of the week, her one question, the athlete's answer, the
  first meal picker.
The `ssot-pictures` agent (`.claude/agents/ssot-pictures.md`) draws the missing ones.


A card whose `screen:` starts with `none` has nothing to screenshot, so it gets a drawn picture
of its mechanism instead: boxes and arrows, or a timeline, and one worked example with real
numbers. The skill that proposes the card draws it (epilogue step 0) and `/ssot backfill` draws
one for every screenless card that has none. Nothing draws by hand: a spec in JSON goes through
`sync.mjs draw` (`_page/diagram.mjs`, spec shapes at the top of the file), which writes
`docs/ssot/decisions/images/<feature>/<id>.svg` and refuses anything that is not inline SVG in
the page's colour tokens (`var(--token, fallback)`, no raster, no stock art, no other colour).
`sync.mjs attach-svg` checks the file again and sets the card's `svg:` line (`--slot 2` sets
`svg2:`, a second drawing); `prepare` inlines the files into the page document, where the page
shows up to two pictures stacked in the left column, in both themes: the screenshot when the
card has one, then its drawing(s). A card that chose between two ways gets a `compare` (what was
considered on the left, what was decided on the right, the same worked example on both sides);
a card that defines a shape or a sequence gets a `flow` or a `timeline`. `/ssot rewrite
<feature>` redraws a whole feature this way (`sync.mjs rewrite-apply`); with `--all` it also
rewords questions and rejected or withdrawn cards, keeping their status (the clarity pass, 2026-09-22).
An answered question shows the decision that answered it, and that decision's pictures when it
has none of its own; an open question gets its own drawing of the choice.
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

Every picture carries its age. A capture's sidecar says when it was taken; a reused golden or
design frame has none, so git says instead: the commit that last touched the file, its date, and
the version `pubspec.yaml` held then. `prepare` puts either into the page document as
`captured` (`commit`, `appVersion`, `capturedAt`, `how`, `key`, `stale`, `changed`), and the page
shows "captured at 1.26.0+1, 12 days ago" (or "golden from …") under the picture. Each
`screens.json` entry lists the `code` its screen is drawn from (the screen file and the widgets
it imports, or a presentation folder); a picture is **stale** when a file under those paths
differs between its commit and the working tree (`git diff --name-only <commit> -- <paths>`, so
uncommitted edits count, since that is what the simulator shows). The page marks a stale picture
under its box with what changed, and the Work page counts them per feature. A picture whose
file matches no registry key (a design frame, an old golden named by hand) or whose commit this
clone never had shows its age with no staleness claim (`stale: null`). `sync.mjs stale` prints
every picture in use with its age, its cards and whether a refresh could retake it.

`sync.mjs refresh <feature> <proposals.md> <ssot.md>` retakes every stale picture in one pass,
one capture per screen, for the screens that have a drive: a stale capture is rewritten in place
(same png and sidecar, the cards need nothing), and the cards on a stale golden move to the new
capture with one dated history line, `picture refreshed at 1.26.0+1, 43496fed, replacing
<golden path>`. A stale picture whose screen has no drive is reported and left as it was. The
old picture never stays beside the new one: the asset map then says which artifact asset was
replaced or fell out of use (Assets below), and the epilogue deletes it. `/implement-lee` runs
the same refresh for the screens a wave touched when it closes (`touched-screens --since
<base>` names them from the diff, `refresh --only <keys>` retakes them whether stale or not).

Which simulator: every capture command takes `--udid <udid|name>`, or `SSOT_SIMULATOR` in the
environment, and boots that device if it is shut down; with neither it drives the first booted
one. The Mac carries at most three wave simulators at once (Lee, 2026-09-15), so they are a
pool, not one per ticket. `sync.mjs simulator claim <owner> [--wait <minutes>]` hands the owner
a free pool device (its data container copied from the dev simulator again, so it opens signed
in as the dev account whatever the last owner did on it), creates `wave-pool-N` only when none
is free and fewer than three exist (the dev simulator's type and runtime, the dev app installed
from its bundle container, its data copied over), and otherwise waits, polling every 30 seconds
for the minutes given, then exits 3. `simulator release <name|udid>` gives the device back the
moment the owner's device check is done; `simulator list` shows each pool device with its owner;
`simulator drop <name>` shuts one down and deletes it (a wave drops the whole pool when it
closes); `simulator add <name>` still makes one by hand under the same cap. Claims live in
`mealvana-ssot-simulators.json` in the machine's temp dir, keyed by udid, and a claim on a
device that no longer exists is dropped on the next call. The first launch on a fresh device
shows the notifications prompt, which every drive dismisses before its first step. The dev
simulator is never a pool device and never driven by an agent.

Setup, once per machine: `scripts/ssot-capture-setup.sh` installs the `idb` client (pipx) and
Facebook's prebuilt `idb_companion` under `~/.local` (Homebrew's facebook/fb tap fails to tap
and its formula wants newer Command Line Tools). `sync.mjs capture --check` (it terminates and relaunches the dev app to ask it) then says what is
still missing: idb, the companion, a booted simulator, the dev app on it, or an app that
answers with an empty accessibility tree after a fresh launch. That last one was the 09-14
blocker: a debug session left from the day before had the app painted but deaf, so every tap
"succeeded" and nothing moved. Every capture now starts with terminate + launch, which clears it.

## Vocabulary

The page's Vocabulary section mirrors the glossary in `CONTEXT.md` (seeded into the `vocab`
collection by `prepare --glossary CONTEXT.md`; reseed after editing the glossary). Glossary terms are underlined in every decision
with the definition on hover, and each category page lists the terms it uses. "Add term" on the
page queues a `term` verdict; `sync.mjs terms <verdicts.json> CONTEXT.md` appends accepted terms
under their area heading after Lee confirms them in the terminal.

## Ask on the page

A card's face is the picture, the title, the context, the question, the decision, why and what
else was considered, then Approve, Reject and Rewrite (see "How a decision gets in" above). A drawn pair is titled "Other option: …" and
"This card's answer: …", never "rejected" or "decided". Every card's Ask thread runs on the
default model tier and reads the card, the cards it names, the glossary terms it uses and one
line per sibling, with page tools (read a card, search the cards, look up a term, read a
reference document). The page never writes the repo. If a conversation on the page changes
Lee's mind, the change is made in the terminal.

## Reference

The page's Reference entries show repo documents the decisions were built from, whole, so the
ratifier can read them there: today Xuan's RevenueCat spec (`docs/revenuecat-spec-for-lee.md`,
id `revenuecat-spec`, Lee 2026-09-23). Also **Open tasks** (`docs/ssot/decisions/open-tasks.md`, id `open-tasks`, Lee
2026-09-26): what the decisions wait on from Lee or Xuan. These are tasks, never cards; remove a line when it is done and reseed. Each is one document in the `refs` collection,
`{id, title, summary, source, body, updatedAt}`, built by `sync.mjs reference` and written with
`write_db`; re-run both when the file changes. Every Ask prompt names the reference documents,
and in-page Claude reads one in full with its fifth tool, `read_reference`, when a question
touches it. The page renders the Markdown itself (headings, lists, tables, bold, italic, code)
from escaped text, so nothing in the collection reaches the page as raw HTML.

## Skills

`/ssot` in `.claude/skills/ssot/` reseeds the page from the five files. Its `prologue.md` and
`epilogue.md` are the steps every -lee skill runs before and after Matt Pocock's skill of the
same name, and `matt.mjs <name>` prints the path of Matt's skill in the plugin cache.
`/grill-with-docs-lee` puts each decision to Lee one at a time and writes the approved ones into
the record. `/to-spec-lee` and `/to-tickets-lee` write the spec and the ticket files only; test
seams, ship order and tickets are approved in the terminal and never become cards.
`/implement-lee` builds tickets in waves (`sync.mjs wave`, below); a product decision that comes
up during a build is asked of Lee in the terminal, or added to the review queue when he is not
there, never written as a card on its own.

## Sync module

`_page/sync.mjs` exports `parse`, `serialize` (byte-identical round trip), `apply` (verdicts from
the page into the two files), `glossary` (CONTEXT.md terms as vocab documents), `addTerms`, `unclear` (undefined
backticked terms on card faces), `rewriteApply` (a plain-words rewrite pass), `answers` (close an open question with a decision), `openQuestions`, `questionFirst`,
`answeredLinks` (decisions that answered a question), `specCitations` (what a spec's decision
sections cite), `pendingIn` (the pending cards of one category), `ticketPlan` (ticket cards with
their blocking edges), `publishTickets` (approved ticket cards to files), `fold`, `clauses` and
`ticketDocument`, `referenceDocument`, `svgCheck`, `checkedSvg`, `undrawn`, `attachSvg`, `uncaptured`, `attachImage`, `readSidecar`, `changedSince`, `imageOrigin`, `captureStatus`, `stalePictures`, `refreshPictures` (with `only` for the screens a wave touched), `ticketFrontier`, `designRenderings`, `touchedScreens`, `setTicketStatus`, `wavePlan`, `waveOpen`, `waveClose`, `elapsed`, `dropAsset` and `unreferencedAssets`; `_page/diagram.mjs` exports `draw` and the token list; `_page/capture.mjs` exports `loadScreens`, `matchScreen`, `findElement`, `runDrive`, `capture`, `sidecar`, `simulatorIo`, `bootedUdid`, `createSimulator`, `deleteSimulator`, `listSimulators`, `claimSimulator`, `releaseSimulator`, `simulatorClaims`, `stamp` and `doctor`. Tests: `node --test docs/ssot/decisions/_page/sync.test.mjs`;
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
node docs/ssot/decisions/_page/sync.mjs reference <doc.md> --id <id> [--title <t>] [--summary <s>] [--out <file.json>]   # one `refs` document for the page's Reference section; with --out prints the write_db entry
node docs/ssot/decisions/_page/sync.mjs prepare <decisions.md>... --assets <assets.json> --tickets <feature>=<dir> --out <dir>
node docs/ssot/decisions/_page/sync.mjs triage <verdicts.json> --out <dir>   # clear.json to apply now, words.json to synthesise first, rewrites.json to apply after the yes
node docs/ssot/decisions/_page/sync.mjs next-id <proposals.md> <ssot.md>     # the next free id across both files
node docs/ssot/decisions/_page/sync.mjs images <assets.json> <_images.json>  # images still to upload: new, changed, file missing; plus unreferenced assets under the prepared features' folders
node docs/ssot/decisions/_page/sync.mjs asset <assets.json> <path> <asset id> # record one upload, keyed by path and hash; prints {path, id, replaced}
node docs/ssot/decisions/_page/sync.mjs asset <assets.json> <path> --drop     # forget a path; prints {path, dropped} with the asset id to delete
node docs/ssot/decisions/_page/sync.mjs undrawn <proposals.md> [<ssot.md>]   # screenless cards with no drawn picture, as JSON; questions and ruled-out cards are skipped
node docs/ssot/decisions/_page/sync.mjs draw <spec.json> [<out.svg>]         # draw a diagram from a spec; refuses one that fails the check
node docs/ssot/decisions/_page/sync.mjs attach-svg <decisions.md> <id> <svg path>  # check the file, set the card's svg line
node docs/ssot/decisions/_page/sync.mjs uncaptured <proposals.md> [<ssot.md>]   # screen cards with no picture and how each would get one (reuse, capture, none), as JSON
node docs/ssot/decisions/_page/sync.mjs capture --check                        # what stands between this machine and a capture
node docs/ssot/decisions/_page/sync.mjs capture <feature> <screen> [--udid <udid|name>]   # drive the simulator to the screen; png + sidecar under images/<feature>/. --udid or SSOT_SIMULATOR names the simulator (booted if shut down), else the first booted one; pictures and refresh take the same
node docs/ssot/decisions/_page/sync.mjs attach-image <decisions.md> <id> <png> [--caption <text>]  # set the image line, record where the picture came from
node docs/ssot/decisions/_page/sync.mjs pictures <feature> <proposals.md> <ssot.md>   # uncaptured -> reuse or capture -> attach, one capture per screen
node docs/ssot/decisions/_page/sync.mjs stale <proposals.md> [<ssot.md>] [--screens <screens.json>]   # every picture in use: age, cards, stale and what changed; nothing written
node docs/ssot/decisions/_page/sync.mjs refresh <feature> <proposals.md> <ssot.md> [--screens <screens.json>] [--only <key,key>]   # retake every stale picture once, in place; cards on a stale golden move to the capture; --only retakes those screens whether stale or not and nothing else
node docs/ssot/decisions/_page/sync.mjs wave <feature> <issues dir> [--branch <b>]   # the frontier as JSON: done, building, blocked (with what on), uncommitted ticket files, and one entry per wave ticket with branch, worktree, renderings, cites; nothing written
node docs/ssot/decisions/_page/sync.mjs wave <feature> <issues dir> --only NN,NN | --max N   # only those frontier tickets (a name off the frontier is refused), or the lowest N; `frontier` still lists them all; combines with --open
node docs/ssot/decisions/_page/sync.mjs wave <feature> <issues dir> --open           # the same, then marks its tickets in-progress, commits the issues dir and logs the wave in <feature>/waves.json with that commit as base
node docs/ssot/decisions/_page/sync.mjs wave <feature> <issues dir> --close <n> [--merged NN,NN] [--failed NN,NN] [--suite green|red]   # closes the wave with elapsed time; merged tickets become done, every other wave ticket ready-for-agent again
node docs/ssot/decisions/_page/sync.mjs touched-screens --since <commit> [<file>...]   # registry screens drawn from the files changed since the commit (committed, uncommitted or untracked), as JSON
node docs/ssot/decisions/_page/sync.mjs simulator claim <owner> [--wait <minutes>] | release <name|udid> | add <name> [--from <udid|name>] | drop <name|udid> | list [<prefix>]   # a pool of at most three wave simulators (dev simulator's type, runtime, app and data): claim one when a device is needed, release it right after; claim waits at the cap
```

Retired with the page's ruling buttons (2026-09-26), kept only so old verdicts and tests still
run: `apply`, `triage`, `answers`, `questions`, `linked`, `cite`, `pending`, `ticket-plan`,
`publish-tickets`, `fold`, `fold-ruled`, `rewrite-apply`, `terms`. No skill calls them.

`triage` sorts the page's verdicts the way the skills apply them: approve, withdraw and reject with
a plain reason go to `clear.json`; a rewrite, an accepted change card, a new term, and a rejection
whose reason contains a question mark go to `words.json`; anything else (a dismissed change card)
is only counted. `rewrites.json` is the amend and change subset of `words.json`, the only part
`apply` ever takes, and only after the ratifier has said yes to the synthesis.

`_page/assets.json` maps a repo image path to the artifact asset it was uploaded as. Entries are
`{"id", "sha256"}` (the first entries are bare ids and still resolve). `prepare` writes
`_images.json` and `_features.json` beside its output; `images` lists which of those need an
upload, plus every asset under a prepared feature's image folder that no document references
any more (`unreferenced`, with its id), and `asset` records one after `upload_asset` returns
its id, printing the id it replaced (`{path, id, replaced}`; a first upload replaces `""`).
`asset <assets.json> <path> --drop` forgets a path and prints its id. A replaced or dropped
asset is deleted from the artifact with `delete_asset`, so no old picture stays behind. An
image is uploaded again only when its hash changed.

A fold plan is `[{from: [ids], into: {title, question, context, decision, why, alternatives, touches, details?, detail?, work?}}]`.
Only proposed or amended cards fold; anything with a verdict is refused. After a fold, delete the
folded ids from the `decisions` collection and set the new ones.

An `amend` verdict may carry `dropped: [n, …]`, the clause numbers Lee ticked. `apply` records
them in **Lee said** ahead of his words.
