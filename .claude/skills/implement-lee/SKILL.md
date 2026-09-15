---
name: implement-lee
description: "Matt's implement run as waves: every unblocked ticket builds at once, each by its own subagent in its own worktree; the wave merges in ticket order with codegen once, the suite once, one review, visual parity where a design rendering is cited, and its build-time decisions go to the page without blocking the next wave. `/implement-lee <feature>`."
disable-model-invocation: true
---

The decision record, its page and the sync commands: `docs/ssot/decisions/README.md`. Read it
once per session. `SYNC` means `node docs/ssot/decisions/_page/sync.mjs`; `<feature>` is the
slug in the argument; `PROPOSALS` is `.scratch/<feature>/decisions.md`, `RECORD` is
`docs/ssot/decisions/<feature>.md`, `ISSUES` is `.scratch/<feature>/issues/`. CLAUDE.md's rules
on parallel work (no stash, no shared index, codegen after annotation changes) bind every step
below and every subagent.

## 1. Catch up

Run `.claude/skills/ssot/prologue.md` in full. If its step 5 left syntheses waiting for yes,
stop there; a wave starts after the ratifier has answered.

## 2. Find Matt's skill

```
node .claude/skills/ssot/matt.mjs implement
node .claude/skills/ssot/matt.mjs resolving-merge-conflicts
```

Read both files. A non-zero exit is a stop: report the path it looked for and end the turn.
His text stays in his files. Matt's implement is what every subagent follows inside its
worktree (step 4); his merge-conflict skill is what step 5 follows. Neither is quoted into a
prompt: the subagent is told the path and reads it.

## 3. The frontier

```
SYNC wave <feature> ISSUES
```

It reads the ticket files' `Status` and `Blocked by` lines and prints `done`, `building` (a
wave still open), `blocked` (with what each waits on), `uncommitted` (ticket files a worktree
could not see) and `wave`: the frontier, one entry per ticket with its `branch`, `worktree`,
`renderings` and `cites`. Also print `SYNC ticket-plan <feature> PROPOSALS RECORD` when the
tickets came from `/to-tickets-lee`: a ticket whose card is not approved never enters a wave.

- `wave` empty and `blocked` empty: everything is done. Report and end with `Next: /ssot`.
- `wave` empty and `building` not: a wave is open from an earlier session. Read
  `.scratch/<feature>/waves.json`, find its branches (`git branch --list 'wave/<feature>/*'`)
  and continue at step 5 with what merged and what did not.
- `uncommitted` not empty: nothing to do by hand; `--open` below commits them.

Then open the wave:

```
SYNC wave <feature> ISSUES --open
```

It marks each wave ticket `in-progress (wave N, <date>)`, commits every file under `ISSUES`
to the working branch (`wave N opened for <feature>: tickets NN, NN [skip ci]`), so the
worktrees see the tickets and a second `/implement-lee` in another session sees them as
building, and appends the wave to `.scratch/<feature>/waves.json` with that commit as `base`.
Note the wave's `number`, `base` and `startedAt` for the report. The log file itself is
committed at close.

## 4. One subagent per ticket, each in its own worktree

For every entry in `wave`, in one message so they run at once, create the worktree and the
ticket's own simulator, then spawn the agent:

```
git worktree add -b <branch> <worktree> <working branch>
SYNC simulator add <simulator>          # the plan's name, wave-<feature>-NN
```

`simulator add` makes a device of the dev simulator's type and runtime, boots it, installs
the dev app from the dev simulator and copies its data over, so it opens signed in with the
same data (README, Captured pictures). Every agent drives only its own; the dev simulator is
left alone. When `simulator add` fails (no booted dev simulator, no dev app on it), the wave
still runs and every device check is reported as not run.

Spawn with the Agent tool (`subagent_type: "general-purpose"`, `run_in_background`), one per
ticket, with a prompt that carries, verbatim:

- the worktree path, and the rule that every command runs there (`cd <worktree>` in each Bash
  call, or absolute paths under it), never in the main clone;
- the base check to run first. `git rev-parse HEAD` must equal `<base>` from the plan. If it
  does not, `git reset --hard <base>` before touching anything (nothing of theirs exists yet);
  if the working branch has moved past `<base>` since the plan (`git rev-parse <working
  branch>` in the main clone), report that and stop rather than build on a stale base;
- the ticket. Its file path and its full text, the decision ids it cites and their **Decision**
  text from `SYNC export RECORD` (the record is what they build against, never the page);
- Matt's implement path from step 2, to read and follow inside the worktree. TDD at the
  ticket's seams (`docs/test/README.md` names the seam rules), single test files as they go,
  `flutter analyze` regularly, codegen in their own tree when they change a Riverpod or Drift
  annotation, and commits on their branch. The full suite and the code review are the wave's,
  not theirs: they run neither;
- the simulator rule. Their device is `<simulator>` and nothing else: `export
  SSOT_SIMULATOR=<simulator>` (or `--udid <simulator>`) on every capture command, and `-d
  <simulator>` on `flutter run` when they put their build on it. The dev simulator and the
  other tickets' simulators are never touched;
- what never happens. `git stash`, any command in the main clone, a push, a merge, editing
  `docs/ssot/decisions/` (proposals go in their report, never in a file), a `flutter build`;
- the report shape. The branch and its last commit, the acceptance criteria ticked with how
  each was verified, every build-time decision they made (question, what they chose, why, what
  else they considered, what it touches, one per line) and every decision they could not make
  (an open question), the screens they touched, whether the device check ran, and whether the
  ticket file's criteria were ticked and its status left alone (the wave sets it).

Wait for every agent. Do not merge while one is still running. Drop each agent's simulator
once its report is in (`SYNC simulator drop <simulator>`), failed or not; a picture the wave
needs is retaken on the dev simulator in step 8. An agent that reports a stale
base, a red test it could not fix, or an unfinished criterion is a failed ticket for this wave:
note it, leave its branch, and go on with the rest.

## 5. Merge in ticket order, then one codegen, one suite, one review

In the main clone, on the working branch, for each successful ticket in ascending number:

```
git merge --no-ff <branch> -m "merge wave N ticket NN: <title> [skip ci]"
```

A conflict goes through Matt's resolving-merge-conflicts (step 2's second path). The two
tickets' intents come from their files and their commits. He does not cover one case.
Generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`) are not resolved
by hand. Take either side (`git checkout --theirs -- <file>`), stage, and let the codegen
below regenerate them once. Never `--abort`; never `git stash`.

After the last merge, once for the wave:

1. `dart run build_runner build --delete-conflicting-outputs`, and commit what it changed.
2. `flutter analyze`, then the full suite: `flutter test` (the CI gate is exactly `test/`,
   `docs/test/README.md`). Red is a stop. Fix what the merge broke, re-run, and if it stays red
   close the wave with `--suite red` (the command below, so the record says so), then
   end the turn with the failing files listed and `Next: /diagnosing-bugs`, no next wave.
3. One review of the merged result: `/mattpocock-skills:code-review` from the wave's `base`
   commit (Standards and Spec axes; the Spec axis reads every ticket of the wave). Fix what it
   finds that blocks; note the rest in the report.

Then close the wave:

```
SYNC wave <feature> ISSUES --close N --merged 02,04 --failed 06 --suite green
```

It records what merged and failed, the suite's colour and the elapsed time, marks each merged
ticket `done (wave N, <date>)` and every other wave ticket `ready-for-agent (wave N failed,
<date>)`, so the next run puts it back on the frontier. `--failed` is only for the record's
sake; a ticket left off both lists fails. Remove the worktrees and the merged branches:

```
git worktree remove <worktree>        # each
git branch -d <branch>                # merged ones only; a failed ticket keeps its branch
```

Commit the ticket files and `waves.json` with the merge (`[skip ci]` in the title when the
wave changed only docs). Pushing is the ratifier's act, not the wave's.

## 6. Visual parity for every ticket that cites a rendering

For each merged ticket whose plan entry lists `renderings`, run `visual-parity` (the user
skill in `~/.claude/skills/visual-parity/`; its "control skill" is `sync.mjs capture` here):

1. Baseline: render each cited file under `docs/ssot/spec/design/renderings/` in a browser
   sized to the simulator's logical size and screenshot it into
   `<scratch dir>/parity/<NN>/design-<name>.png`. The rendering is the spec; it is never edited.
2. Target: `SYNC capture <feature> <screen>` on the dev simulator (the merged code is what it
   must show, so the dev app is run on it first) for the screen the ticket built (its
   `screens.json` entry; add one with a drive when the screen is new, README Captured pictures).
3. Diff: the repo has no image-diff library, so use the one the machine has (ImageMagick's
   `compare -metric AE`, or Pillow's `ImageChops.difference`) and read the count of differing
   pixels. Zero is parity. Investigate a nonzero count pixel by pixel. The fix goes in the app,
   never in the baseline or the harness.
4. A tolerance the ratifier must rule on (a font the simulator lacks, a status bar, a rendering
   that is itself out of date) is not silently accepted: it becomes a proposed decision in
   step 7 with the diff image as its picture (copy the diff png to
   `docs/ssot/decisions/images/<feature>/parity-<NN>-<name>.png`, then `SYNC attach-image
   PROPOSALS <id> <png> --caption "<count> px differ from <rendering>"`) and the count in Details.

No booted simulator, or no drive for the screen: report "parity for NN not run: <why>", and
the ticket stays done. The wave never blocks on a picture.

## 7. The wave's decisions go to the page

From each agent's report and the merged diff (`git diff <base>..HEAD --stat`, then the files
that matter), write one card per build-time decision in `PROPOSALS`, the way `/ssot backfill`
step 3 and 4 write one (README parts, id from `SYNC next-id` one at a time, `unslop`), with
`source: wave <feature> N ticket NN`, the category the decision belongs to (reuse one from
`SYNC export RECORD`; `Build` when none fits), a `screen:` line when it changed a screen (else
`screen: none (...)`), and `linked:` to an open question it answers. A decision an agent could
not make is an open question in the agent's words (`kind: question`, `status: open`). A parity
tolerance from step 6 is a card with its diff picture. Nothing here waits. The cards are pushed
and the next wave starts whether or not anyone has ruled.

## 8. Re-capture what the wave touched, push, report

```
SYNC touched-screens --since <base>
SYNC refresh <feature> PROPOSALS RECORD --only <the keys it printed, comma-separated>
```

The first lists the registry screens drawn from any file the wave changed (committed since
`base` or still in the working tree). The second retakes every picture on those screens
whether stale or not, since their code changed, and leaves every other picture alone. No keys
means nothing to retake. Then run `.claude/skills/ssot/epilogue.md`
in full: it draws the screenless cards from step 7, captures the ones that name a screen,
uploads what changed, reseeds the page and reports. This skill's `Next:` line is never the
"approve N decisions" form, so the epilogue sends no push.

The report, before the epilogue's lines:

```
Wave N: T tickets (NN, NN, NN), M merged, F failed, elapsed <from waves.json>
Suite: green (P passed) | red (files)     Review: K findings, J fixed
Parity: NN zero-diff | NN <count> px, tolerance proposed as <id> | NN not run (<why>)
Pushed: D decisions, Q open questions, I pictures retaken
Next frontier: NN, NN (or: none, everything done)
```

Then end the turn with the epilogue's `Clear:` line and one `Next:` line:

- another wave waits: `Next: /implement-lee <feature> (builds tickets NN, NN in wave N+1)`;
- a red suite stopped the wave: `Next: /diagnosing-bugs (the suite is red after wave N: <files>)`;
- nothing left: `Next: /ssot (N decisions from the waves wait on the page)`.
