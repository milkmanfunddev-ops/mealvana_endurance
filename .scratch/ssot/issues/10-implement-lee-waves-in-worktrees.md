# 10: `/implement-lee`: waves in worktrees

**Status:** done
**Blocked by:** 06, 09.
**Next:** `/ssot`

**What to build:** Lee runs `/implement-lee` and every unblocked ticket builds at once, each in
its own git worktree by its own subagent following Matt's implement from disk (TDD at the ticket's
seams, single tests, commit on its branch). Each subagent verifies its base is current before it
starts. When the wave completes the branches merge in ticket order into the working branch,
conflicts go through the merge-conflict skill, codegen runs once, the full suite once, one code
review on the merged result. Any ticket citing a design rendering gets visual parity: baseline
the rendering, target the simulator, diff verified, any tolerance recorded as a decision. The
wave's build-time decisions are pushed as proposals without blocking the next wave, the screens
each ticket touched are re-captured, and the report says wave size and elapsed time. Stories 30
to 33 and the Pictures section.

Hazards already known: worktree agents can start from a stale base; generated Drift and Riverpod
files collide on merge; never git stash in this repo; parallel sessions never share a git index.

- [x] The frontier is computed from the ticket files' blockers and status lines
- [x] One subagent per frontier ticket, each in its own worktree, each checking its base against the working branch first
- [x] Merge in ticket order, codegen once, full suite once, one review; a red suite stops before the next wave
- [x] Visual parity runs for any ticket citing a design rendering and a tolerance becomes a proposed decision
- [x] Build-time decisions from each agent's report and the diff reach the page after the wave
- [x] Screens the wave touched are re-captured on close
- [x] Device checks within a wave run at once, one simulator per ticket (Lee's ruling, 09-15; the ticket said turns)
- [x] Report: wave size, elapsed time, counts, link, `Next:` line

**Done 2026-09-15.** `.claude/skills/implement-lee/SKILL.md` runs the prologue, reads Matt's
implement and resolving-merge-conflicts from disk, and builds in waves. `sync.mjs wave` computes
the frontier from the ticket files' Status and Blocked-by lines and names a branch and a worktree
beside the clone (`<clone>-waves/<feature>/NN-<slug>`) per ticket; `--open` marks the tickets in
progress, commits the issues dir and logs the wave in `.scratch/<feature>/waves.json` with that
commit as the base every agent checks; `--close` records merged, failed (a wave ticket on
neither list fails), suite colour and elapsed time and sets each ticket's status. Device checks run in
parallel, not in turns: `sync.mjs simulator add wave-<feature>-NN` gives each ticket a simulator
of its own, a copy of the dev one (type, runtime, the dev app, its data container, so it opens
signed in), and every capture command takes `--udid` or `SSOT_SIMULATOR`; Lee ruled out the
lock ("we have the capacity to run several different emulators at once").
`touched-screens --since <base>` maps the wave's diff (committed, uncommitted, untracked) to
registry screens and `refresh --only <keys>` retakes them whether stale or not. Visual parity
runs for a ticket citing `docs/ssot/spec/design/renderings/`, with a tolerance proposed as a
decision carrying the diff png. Eight new `node --test` cases. A smoke worktree on this machine
confirmed the hazard the `uncommitted` list guards against: only the committed ticket files are
visible in a worktree. Matt's code-review (Standards and Spec) ran on the diff; its two
defects (base recorded before the mark commit, unlisted tickets building forever) are fixed.
The skill has not run a real wave yet; the mealplanning tickets that are still `ready` are its
first candidates.
