# SSOT handoff (written 2026-09-14, before Lee cleared the session)

Read this first in a fresh session. Then re-arm the artifact watch (step 1 below) before doing
anything else, so Lee's Finish button reaches the terminal again.

## Where things are

| What | Where |
|---|---|
| The page (one artifact, keep the URL) | https://claude.ai/code/artifact/2b18d770-da55-443e-8740-483a422db8ac |
| Page template, sync module, asset map, README with the rules | `docs/ssot/decisions/_page/`, `docs/ssot/decisions/README.md` |
| The record (Lee-approved only) | `docs/ssot/decisions/mealplanning.md` (82 approved, 21 rejected as of 09-14 14:00) |
| Proposals waiting on Lee | `.scratch/mealplanning/decisions.md` (18 pending, every one amended or `work: pending`; 6 open questions) |
| Spec for the SSOT tooling itself | `.scratch/ssot/spec.md` (ready-for-agent, five skills incl. `/grill-with-docs-lee`, Pictures and Portability sections; next command is `/to-tickets .scratch/ssot/spec.md`) |
| Fold plans, the batch-4 rewrite script, the preview shim | `.scratch/ssot/folds/`, `.scratch/ssot/preview/build.mjs` (set `SSOT_SCRATCH` to a dir holding `out2/` from `sync.mjs prepare`) |
| Research feeding open question mp-217 | `docs/research/conversation-memory-strategies.md` |
| Glossary shown on the page's Vocabulary section | `CONTEXT.md` (27 terms seeded into the `vocab` collection) |
| Memory | `~/.claude/projects/.../memory/project_ssot_decisions_20260913.md` and `project_ssot_fold_20260914.md` |

Nothing is committed yet (as of 09-14 14:00). All of the above is untracked or modified in the working tree; Lee has not asked for a commit.

## 1. Re-arm the watch

(2026-09-14, ticket 03: sections 1 and 2 are now `/ssot`; read `.claude/skills/ssot/SKILL.md`,
`prologue.md`, `epilogue.md`. The steps below are the hand-run version they came from.)

Call the Artifact tool with `action: "watch"` and the URL above. Confirm with `action: "status"`.
While the watch is connected, Lee pressing Finish on the page republishes a `verdicts.json` file,
and the session gets an `artifact-changed` notification. If the watch is not connected, Lee says
"done" in the terminal instead.

## 2. What to do when a Finish arrives

1. `read_db` on collection `verdicts` with `where applied == false`, `out_dir` to the scratchpad.
2. Split into two piles.
   - Clear-cut: `approve`, `withdraw`, `reject`. Apply at once:
     `node docs/ssot/decisions/_page/sync.mjs apply <verdicts.json> .scratch/mealplanning/decisions.md docs/ssot/decisions/mealplanning.md`
   - Anything carrying Lee's words: `amend`, `change` (accepted change cards), `term` (new
     glossary terms), and a `reject` whose text is really a question. Do NOT apply. Synthesise in
     the terminal first: say what he meant as rewrites, new decisions, open questions, or glossary
     entries, and wait for his yes. Then write it into `.scratch/mealplanning/decisions.md`
     (rewrites: set status amended with Original + Lee said + new Decision; new decisions: next
     `mp-NNN`, status proposed; open questions: `kind: question`, `status: open`, `linked:`;
     terms: `sync.mjs terms <verdicts.json> CONTEXT.md`).
3. Reseed the changed documents: `sync.mjs prepare <ssot.md> <proposals.md> --assets
   docs/ssot/decisions/_page/assets.json --out <dir>` then `write_db` batch (50 per batch) with
   `set` entries by `file_path`, plus `update` on each `verdicts/<id>` with `{applied: true}`.
4. Never write `docs/ssot/decisions/` except through `sync.mjs apply` on Lee's verdicts.

## 3. Rules Lee set (do not relitigate)

- Only Lee edits the SSOT, only through Approve. Proposals live in `.scratch`.
- Synthesis before writing: anything with his words is discussed in the terminal before it lands
  anywhere, including `.scratch` and the page.
- Little copy on the page. Counts and one-word buttons.
- In-page Claude runs on the `quick` tier. Terminal work uses the session model.
- Skills to build: `/to-spec-lee`, `/to-tickets-lee`, `/implement-lee`, `/ssot`. They read Matt's
  SKILL.md from the plugin cache at run time (his are `disable-model-invocation`). No CLAUDE.md
  automation. One CLAUDE.md line carving `docs/ssot/decisions/` out of the never-edit rule.
- Every skill ends with a `Next: /<command>` line.

## 4. What is next

- `/to-tickets .scratch/ssot/spec.md` cuts the tickets for the tooling. Tickets must cover the
  four skills, the sync-module tests, the CLAUDE.md carve-out, and moving what this session did
  by hand into the skills.
- The memory question (mp-217) is a separate grill for mealplanning: `/grill-with-docs` with the
  research file loaded, then `/to-spec-lee` once it exists (or `/to-spec` plus a manual push).

## 5. Known gotchas from this session

- Page objects from the database are frozen: clone before appending.
- Never put a NUL or other control character in the page source; grep treats the file as binary
  and the Bash heredoc refuses it. Use `|` as a separator.
- A publish after the page's own Finish is refused once as a conflict. Read the artifact, then
  publish again. Do not use force.
- `mobile-mcp` taps timed out on the simulator; `idb` is not installed. Screenshots come from
  goldens and design frames unless that is fixed.
- The db caps at 5,000 documents. Chats are one document per thread with a turns array.

## 6. 2026-09-14, second session: the fold

- The proposals pile was folded from 168 to 69 pending: 132 cards became 45 (`mp-219` to `mp-263`),
  each a clause list. Plan and result: this session's scratchpad `fold-plan.json`, `fold-result.json`;
  backups of both files before the fold in `scratchpad/backup/`.
- Every card now has a **Question** part (lifted from the end of Context) and the page shows it
  first; Context, alternatives, touches and Details sit under "More".
- Page: Rewrite on a clause-list card lets Lee tick clauses to drop (`amend` verdict carries
  `dropped`). `detail: yes` cards sink into a collapsed block per category. A Work page lists
  `work: pending` decisions, open questions, and the tickets (seeded from `.scratch/mealplanning/issues`).
- 12 clear-cut approvals were applied (mp-020, 043 to 048, 051, 058, 061, 062, 218): SSOT now 47 approved.
- Lee said yes to all three syntheses. Applied: 12 rejections entered the record with his reasons
  (SSOT now 47 approved, 16 rejected); three new `work: pending` cards mp-264 (Vana on three
  screens), mp-265 (one sheet height, full screen only by its button), mp-266 (7-day trial, no
  free or Pro tier); open question mp-267 (what the trial move requires). 55 pending, 6 open.
  The three Pro cards mp-254 to mp-256 still describe free and Pro and wait on mp-267.
- Phone layout: nav is a drawer behind a ☰ button, cards single-column, clause ticking, detail
  block and Work page all verified at 390 px in a local preview (`scratchpad/preview/build.mjs`
  wraps the page in a fake `claude` runtime fed from the prepared JSON; the real artifact needs a
  sign-in the test browser lacks).
- Finish batch 12:59: mp-219 rejected (chip), mp-220/221/264 approved (record 50 approved, 17
  rejected). mp-265 amended from Lee's words: clause 4 is now "every deterministic action is a
  hand-off" (meal plan, new activity, event, carb loading, every flow the app owns); awaiting his
  Approve on the page.
- Page fixes 13:45: render() now snapshots and restores every draft, open form, ticked clause,
  focus, caret and scroll across the re-render every db change triggers (Lee: "it clears what I
  am writing"). Finish buttons show Sending… then Sent ✓, and the status line says how many went
  to the terminal and when. Both verified in the local preview.
- Lee's picture asks (too many "No picture yet", outdated screenshots, simulator capture, refresh
  cadence) are recorded in `.scratch/ssot/spec.md` § Pictures for `/to-tickets` to cut.
- Finish batch 13:31 (44 verdicts): 32 approved + mp-249 rejected applied at once (record 82
  approved). Lee said "ok" to the eleven syntheses; written: amended mp-144 (admin recipe
  comments), 145 (icons stored, not drawn), 230 (show-more picker, semantic search), 231 (cooking
  period, batch servings, liked-first), 244 (tap back to recipe), 245 (Wiredash via the tool),
  255 (no entitlements table), 262 (both ratify, portable); rejected 237/240/250 with new cards
  mp-268 (opener reads the screen), 269 (week start and period are settings), 270 (no meal
  planning without the trial). Record 82 approved, 21 rejected; 18 pending, all `work: pending`
  or amended for Lee's Approve. Portability added to `.scratch/ssot/spec.md`.
- Lee added a fifth skill, `/grill-with-docs-lee` (spec stories 49-51 and the Implementation
  Decisions bullet): open questions first, one at a time; every ruling pushed as a proposal on
  "done", unanswered questions stay open, nothing lost. Agreed order: cut tooling tickets, build
  `/ssot` and `/grill-with-docs-lee` first, then grill the trial move (mp-267), then the unblocked
  meal-planning batch, then grill memory (mp-217).
- Next: `/to-tickets .scratch/ssot/spec.md` (Lee said he is ready).
- Ticket 04 done 09-14 (`/grill-with-docs-lee`, `.claude/skills/grill-with-docs-lee/SKILL.md`,
  `sync.mjs questions`). Next: `/mattpocock-skills:implement 05 ssot`, or Lee grills mp-267 for
  real with `/grill-with-docs-lee mealplanning mp-267`.
