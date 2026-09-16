# SSOT: a decision record Lee approves on a page

Status: ready-for-agent
Feature slug: ssot
Written: 2026-09-13, from the grilling session of 2026-09-12 to 09-13

## Problem Statement

Mealplanning has hundreds of small decisions behind it: how a sheet opens, what Vana says first, when the recovery window closes. They live in specs, tickets, ADRs, commit messages, and memory files. None of those is the place Lee goes to find out what was decided, and none of them records that Lee agreed. When a spec is written, the decisions inside it are approved by reading a wall of markdown in a terminal, or not at all. When a ticket is built, the decisions made during the build are not recorded anywhere Lee can see.

Lee wants one place, a single source of truth, where every product decision is written in plain language, grouped, searchable, illustrated, and carries his verdict. He wants to give that verdict by pressing a button, not by editing markdown. He wants to ask about any decision without going back to the terminal. And he wants this to cost him as few commands as possible, because the existing workflow already takes long enough.

## Solution

A folder in the repo, `docs/ssot/decisions/`, holds one markdown file per feature. Each decision in it was approved by Lee on a page. Nobody writes to that folder except on his verdict.

A published Claude artifact shows every decision as a section in one long column: a picture on the left, plain text on the right, and Approve, Reject, and a free-text box under it. The left side of the page is a nav grouped by feature and category with pending counts. A search box finds anything. A "pending only" filter collapses what is already decided. Each section has an "explain this to me" thread that asks Claude from inside the page. A Finish button tells the terminal Lee is done.

Five skills carry the workflow. Four of them, `/grill-with-docs-lee`, `/to-spec-lee`, `/to-tickets-lee`, and `/implement-lee`, follow Matt Pocock's skills of the same name and add the SSOT steps around them: apply Lee's waiting verdicts, work through the open questions, propose new decisions, push them to the page, and say what to run next. The fifth, `/ssot`, opens the page, applies verdicts, and backfills a feature's history.

The first use is mealplanning: a backfill of every decision made so far, for Lee to approve or reject, which also proves the round trip.

## User Stories

1. As Lee, I want every product decision recorded in one folder in the repo, so that I have a single source of truth I can point anyone at.
2. As Lee, I want decisions written in plain language with no AI tells, so that I can understand what was decided without decoding it.
3. As Lee, I want each decision to say what was decided, why, what else was considered, and what it touches, so that I can judge it without reading the code.
4. As Lee, I want decisions grouped by feature and category in a left nav, so that I can click through prior decisions by area.
5. As Lee, I want a search box that searches across every decision, so that I can find a thing I half remember.
6. As Lee, I want an Approve button on every decision that writes my verdict, so that agreeing is one click.
7. As Lee, I want pressing Approve again to withdraw an approval, so that I can reverse myself without a terminal.
8. As Lee, I want a Reject button with a reason, so that a rejected idea is recorded and never proposed again.
9. As Lee, I want a free-text box where I type what I want instead, so that I can redirect a decision in my own words.
10. As Lee, I want my own words to come back as a rewritten proposal beside the original, so that I can check the rewrite before approving it.
11. As Lee, I want an "approve all" button per category, so that a run of small decisions I agree with costs one click.
12. As Lee, I want a "pending only" filter, so that the column becomes just the things waiting on me.
13. As Lee, I want pending counts in the nav, so that I can see where the work is.
14. As Lee, I want a graphic on the left of every decision, a screenshot of the app where one exists, so that I can see what the decision looks like.
15. As Lee, I want algorithmic decisions illustrated with a worked example and a small diagram, so that decisions with no screen still have a picture.
16. As Lee, I want existing screenshots in the repo reused before any new capture, so that the simulator only runs when nothing fits.
17. As Lee, I want an "explain this to me" thread under every decision that talks to Claude from the page, so that I never return to the terminal to ask a question.
18. As Lee, I want that thread to know the decision, its siblings in the category, and the spec's problem statement, so that "why not the other way" gets a real answer.
19. As Lee, I want those threads saved, so that the next skill run can turn "I want X" into an amendment.
20. As Lee, I want to leave artifact comments sent to Claude, so that "go change the code" reaches a terminal session with repo access.
21. As Lee, I want the page to write my verdicts the moment I click, so that nothing is lost if I close the tab.
22. As Lee, I want a Finish button that wakes the terminal session, so that I do not type anything to hand back my verdicts.
23. As Lee, I want typing "done" in the terminal to work as well, so that a session that was not watching can still pick up my verdicts.
24. As Lee, I want the artifact to keep one URL forever, so that the link in my notes never goes stale.
25. As Lee, I want `/to-spec-lee` to write the spec and put its decisions and test seams on the page in one run, so that spec approval is a page, not a terminal conversation.
26. As Lee, I want `/to-tickets-lee` to refuse while a spec decision is pending, so that tickets are never cut from an unapproved spec.
27. As Lee, I want `/to-tickets-lee` to put the ticket breakdown on the page, one section per ticket with its blockers, so that I approve the breakdown the same way I approve everything else.
28. As Lee, I want every ticket to cite the decision ids it depends on, so that an implementing agent reads the truth and not a memory file.
29. As Lee, I want `/to-tickets-lee` to record what each ticket touches and turn overlaps into blocking edges, so that parallel builds never collide.
30. As Lee, I want `/implement-lee` to build every unblocked ticket at once in its own worktree, so that I do not wait for tickets one by one.
31. As Lee, I want each wave merged in ticket order with codegen once, the full suite once, and one code review, so that parallelism does not cost me green tests.
32. As Lee, I want `/implement-lee` to run visual parity on any ticket that cites a design rendering, so that a built screen matches the design by diff and not by eye.
33. As Lee, I want build-time decisions pushed to the page after each wave without blocking the next, so that the tiny decisions are recorded and I approve them when I want.
34. As Lee, I want every -lee skill to apply my waiting verdicts before it starts, so that the SSOT catches up without a separate command.
35. As Lee, I want every -lee skill to print the pending count and the page link at start and end, so that I know when something waits on me.
36. As Lee, I want a phone push when a gate is blocked on me, so that I do not find out by opening the terminal.
37. As Lee, I want every skill to end with a `Next:` line naming the command to run, so that I never have to ask what comes next.
38. As Lee, I want `/ssot` to open the page and apply verdicts on demand, so that I can look at decisions any time.
39. As Lee, I want `/ssot backfill <feature>` to mine specs, tickets, ADRs, and docs for decisions already made, so that mealplanning's history enters the record.
40. As Lee, I want the -lee skills to follow Matt's skills read from disk at run time, so that his updates flow through and I never keep a copy.
41. As Lee, I want the page and the skills to fail loudly if Matt renames a skill, so that a silent drift never happens.
42. As Lee, I want the CLAUDE.md never-edit rule for `docs/ssot/` amended for `decisions/`, so that agents do not refuse to record my approvals.
43. As Lee, I want proposals kept out of `docs/ssot/decisions/` until I approve, so that the SSOT contains only what I pressed Approve on.
44. As Lee, I want a withdrawn approval to stay in the file with a dated line, so that reversals are part of the record.
45. As an implementing agent, I want to read a feature's decisions as markdown, so that I never depend on the page or its database.
46. As an implementing agent, I want the spec's Implementation Decisions section rewritten to cite decision ids after verdicts, so that the spec and the SSOT never disagree.
47. As Lee, I want categories chosen by the skill from the feature's material, so that I do not have to maintain a taxonomy.
48. As Lee, I want one page for all features with a feature filter, so that search covers everything and each feature still has its own view.
49. As Lee, I want `/grill-with-docs-lee` to start from the page's open questions for the feature and walk them with me one at a time, so that a grill works through what is already waiting before it opens anything new.
50. As Lee, I want every ruling made during a grill to reach the page as a proposed decision when the grill ends, and every question we did not settle to stay open on the page, so that nothing said in a grill is lost.
51. As Lee, I want a grill to tell me at the end which open questions it closed, which it left open, and how many proposals it pushed, so that I know what still waits on me.

## Implementation Decisions

### The record

- The single source of truth is `docs/ssot/decisions/`, one markdown file per feature, named by feature slug. It sits outside the QA mirror's rsync scope, so a sync never touches it. The CLAUDE.md rule "never edit `docs/ssot/`" gets one line carving `decisions/` out as app-owned, written only by a skill applying Lee's verdicts. A short README in the folder says the same.
- A decision is one `##` section. Its heading carries a stable id (`<feature>-<nnn>`) and a title. Under it: a category line, a status line (approved, rejected, withdrawn, with date), an image line (a repo path, or none), a source line (spec, ticket, ADR, or commit), then four fixed parts: the decision in one or two sentences, why, what else was considered, what it touches in the app. Withdrawn and re-approved decisions keep a dated history line per change.
- Proposals live in `.scratch/<feature>/decisions.md` in the same format with status proposed or amended. An amended section carries three blocks: the original text, Lee's words, and the rewrite awaiting approval. Approving moves the section into the SSOT file; rejecting moves it there as rejected with the reason.
- Each SSOT file records the commit it was last extracted from, so an extraction run reads the session plus the diff since that commit.
- Categories are free text chosen by the skill from the feature's material, reused where one exists. Feature and category together form the nav.
- Images: existing captures anywhere in the repo are referenced by path and never copied. New captures and drawn diagrams go under `docs/ssot/decisions/images/<feature>/`. Algorithmic decisions get a worked example with real numbers plus a small inline SVG. A decision with no image is allowed and the page flags it.
- All decision text is written through the unslop skill before it reaches a proposals file.

### The page

- One Claude artifact, published once from a template kept in the repo under `docs/ssot/decisions/_page/`, redeployed only when its design changes. Its URL is recorded in the folder README. It declares the artifact database, assets, in-page Claude, and self-republish capabilities.
- The page renders from the artifact database, never from embedded data. Layout: left nav grouped feature then category with pending counts, search box across all text, a feature filter, a "pending only" filter, and one long scrolling column of sections in nav order. No per-decision pages. Each section: graphic left, text right, then Approve (a toggle; approved shows as Withdraw), Reject with a reason field, a free-text box, and an "explain this to me" thread. Approve-all sits on each category heading. A Finish button in the header.
- Every click writes a verdict document immediately. Finish republishes the page with the verdict list embedded, which notifies any terminal session watching the artifact.
- The explain thread sends the decision's full section, its sibling decisions in the same category, and the feature spec's problem statement with each question, and saves every turn. It is billed to Lee's account. It is for explanation; the page says so and points to artifact comments for requests that need the repo.
- The database has four collections. `decisions/<id>`: feature, category, title, status, decision, why, alternatives, touches, image asset id, order, and for amended ones the original and Lee's words. Rebuilt from the markdown every run. `verdicts/<id>`: verdict (approve, withdraw, reject, amend), text, timestamp, applied flag. Written by the page, read and marked by the skills. `chats/<id>/turns/<n>`: role, text, timestamp. `meta/state`: features, categories, last sync commit, artifact URL, and the map from image path and hash to asset id, so an image uploads once and again only when the file changes.
- Nobody reads the database for truth. The markdown is the record; the database is delivery one way and verdicts the other.

### The sync module

- One node module in the page folder with three functions: parse a decisions markdown file into documents, serialise documents back to markdown, and apply a list of verdicts to a proposals file and an SSOT file. The round trip is byte-identical. Apply refuses an unknown id and touches nothing outside the two files. Skills call it through a small command line: export to JSON for the artifact tool, and apply from a verdicts JSON.

### The skills

- Five project skills under `.claude/skills/`: `grill-with-docs-lee`, `to-spec-lee`, `to-tickets-lee`, `implement-lee`, `ssot`. They are project-level because they hardcode `docs/ssot/`. None restates CLAUDE.md rules.
- `/grill-with-docs-lee` (added 2026-09-14): prologue, then load the feature's approved decisions and open questions from `docs/ssot/decisions/<feature>.md` and `.scratch/<feature>/decisions.md` alongside `CONTEXT.md` and the ADRs, so the grill never re-asks what Lee has already ruled. Walk the open questions first, one at a time, in Lee's order, before Matt's grill opens anything new. Follow Matt's grill-with-docs from disk for the rest. On "done": extract every ruling from the transcript into proposed decisions (question, decision, why, alternatives, touches; `linked:` to the open question it answers), mark each answered question's section `status: answered` with a `> ` history line naming the new decision id, leave every unanswered question open, push the proposals to the page, and end with counts (closed, still open, pushed) and `Next: /to-spec-lee`. Nothing said in a grill is lost: a ruling that the extractor cannot place becomes an open question in Lee's words rather than being dropped. The sync module gains `status: answered` for questions and an `answers` command that writes the link both ways.
- The four -lee skills locate Matt's skill of the same name under the plugin cache with a version glob, read it at run time, follow it, and add the SSOT steps. Matt's skills are flagged user-only, so a wrapper cannot invoke them; reading the file is the mechanism. A missing file is a loud stop, not a fallback.
- Every -lee skill and `/ssot` runs the same prologue and epilogue. Prologue: read unapplied verdicts from the database, apply them through the sync module, rewrite the spec's Implementation Decisions section to cite ids and drop rejected items, re-propose amended ones, report applied and pending counts with the link. Epilogue: push new proposals to the database, upload new images as assets, report counts and link, send a phone push if a gate now blocks on Lee, and end with a single `Next: /<command>` line, or `Next: approve N decisions on the page, then /<command>`.
- `/to-spec-lee`: pick up decisions with `linked:` to answered questions first. Follow to-spec, but instead of confirming test seams in the terminal, write the seams as decisions in a "spec" category alongside every implementation and testing decision from the draft. Push, hand over the link, then wait for Finish or "done" and apply.
- `/to-tickets-lee`: refuse if any spec-category decision is proposed or amended. Follow to-tickets, but instead of quizzing in the terminal, push the breakdown as one section per ticket, with blockers and a touches list, and publish the ticket files only once every ticket section is approved. Overlapping touches become blocking edges. Each ticket cites the decision ids it depends on and ends with a `Next:` line.
- `/implement-lee`: compute the frontier, every ticket whose blockers are done. Spawn one subagent per frontier ticket in its own git worktree, each verifying its base is current, then following implement (TDD at the ticket's seams, single tests, commit on its branch). No cap on wave size; device checks within a wave take turns on the one simulator. When the wave completes: merge in ticket order into the working branch, resolve conflicts with the merge-conflict skill, run codegen once, the full suite once, one code review on the merged result, then visual parity for any ticket that cites a design rendering, baseline the rendering, target the simulator, diff verified, any tolerance recorded as a decision. Extract the wave's build-time decisions from each agent's report and the diff, push as proposals, never block on them, then start the next wave. Report wave size and elapsed time.
- `/ssot`: prologue, then with no argument open the page; with `backfill <feature>` mine the feature's spec, tickets, archived tickets, ADRs, and docs for decisions already made and push them as proposals.
- Nothing runs without Lee typing a command. There are no hooks, no automatic triggers, and no rules added to CLAUDE.md beyond the carve-out.

### First use

- Before the skills exist, this session builds the page by hand and backfills mealplanning from its spec, twelve tickets, archived tickets, the two ADRs, the Vana chat lineage, and the implement docs. Lee approves on the page. The verdicts are applied by hand once, which proves the round trip and produces `docs/ssot/decisions/mealplanning.md`. That page becomes the template.

## Testing Decisions

- A good test here feeds a markdown fixture in and checks the documents or the markdown that come out. It never inspects how the parser walks lines.
- The only module under test is the sync module. Cases: parse a feature file to documents; serialise back byte-identical; approve moves a section from proposals to SSOT with a dated status; approve on an approved id marks withdrawn and keeps the history line; reject records the reason in the SSOT file; amend produces a proposal carrying original, Lee's words, and the rewrite; an unknown id is refused; files outside the two named are untouched.
- Prior art: the node tests beside the meal-images scripts, plain `node --test` with fixtures.
- The skills are verified by running them on the mealplanning sample. The page is verified on the real artifact with one full round trip: click Approve, run the apply step, see the section in the SSOT file.

## Pictures (Lee, 2026-09-14, after the first review pass)

Too many cards say "No picture yet", some pictures are from an older build of the app, and there is
no way to keep them current. Three requirements, all in scope for the tooling tickets:

- **A drawn graphic for screenless decisions.** When a decision has no screen (a paywall rule, a
  sync rule, a window calculation), the skill that proposes it also draws a small, plain diagram
  that shows the mechanism: boxes, arrows, one worked example. The paywall is Lee's example: what a
  new account sees on day one, day seven and day eight. Inline SVG in the `svg` field, drawn in the
  page's own tokens, never a stock illustration. Matches user story 15.
- **Simulator screenshots taken while the SSOT is written.** When a decision names a screen, the
  skill drives the simulator to that screen and captures it, rather than leaving a placeholder.
  Existing goldens and design frames are reused first (story 16); the simulator runs for the rest.
  Blocker to clear first: `mobile-mcp` taps time out and `idb` is not installed (HANDOFF §5).
- **Screenshots carry their age and are refreshed.** Every captured image records the commit and
  app version it was taken at. The page shows a "captured at 1.26.0, 12 days ago" line under each
  and marks one stale when the screen's code has changed since. A refresh command re-captures every
  stale image in one pass, and `/implement-lee` re-captures the screens a ticket touched when it
  closes. Old pictures from earlier builds are replaced, never kept beside the new one.

## Portability and a second ratifier (Lee, 2026-09-14, mp-262)

- Lee and Xuan both ratify. The page and the sync module must work for either of them: the
  artifact is shared with Xuan, verdicts record who gave them, and nothing in the tooling assumes
  Lee's machine, home directory or session. A fresh clone plus the skills is enough to run every
  command; the README says how.
- Specs and the decision record stay under `docs/ssot/` in the app repo for now.

## Out of Scope

- Editing categories on the page.
- Writing to the QA repo or its mirror. A decision may cite an intake ruling by path; it never creates one.
- Automatic triggers after Matt's skills, CLAUDE.md rules that run skills, and copying Matt's skill text anywhere.
- Live application of verdicts while no session is open.
- Kroger and meal-imagery backfills. They run later with the same skill.
- A headless-browser harness for the page.

## Further Notes

- Facts that shaped this: `docs/ssot/` is a verbatim rsync mirror of the QA repo over a fixed subtree list, so a sibling folder survives; Matt's to-spec, to-tickets, and implement are flagged user-only so a wrapper must read them from disk; a browser page cannot write to Lee's disk, so verdicts travel through the artifact database; the visual-parity skill is at `~/.claude/skills/visual-parity/`.
- Known hazards for parallel builds, already in memory: worktree agents can start from a stale base; generated Drift and Riverpod files collide on merge; never git stash in this repo; parallel sessions must never share a git index.
- Lee's phrasing worth keeping: "you should NEVER edit it without my explicit pressing of Approve", and "let's have a unified process" for tiny build-time decisions.

Next: /to-tickets
