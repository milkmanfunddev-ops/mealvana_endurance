# 04: Convert the 22 Scenarios to the new format

**What to build:** Reshape all 22 scenarios from the old corpus JSON into individual markdown
files in `/eval/scenarios/`, one per Scenario, each standing alone: account + persona, the goal
the conversation must achieve, the pinned opening turn, required beats (things that must
happen for the Scenario to pass), and Examiner notes (things to watch, not hard requirements).
Preserve the old corpus's dimensions — Task, athlete situation, query character, seed flags
(existing plan, awaiting debrief, new-plan opener) — as goal/beats/notes content. Index all 22
in the README's corpus index. The old JSON stays on disk until ticket 06 deletes it, so the
conversion can be diffed against the source.

**Blocked by:** 01 (scaffold — scenarios/ and the index live there).

**Status:** ready-for-agent

- [ ] 22 markdown Scenario files exist, named with their scenario ids, indexed in the README
- [ ] Every file carries account/persona, goal, opening turn, and at least one required beat
- [ ] Seed semantics from the old JSON (existing plan, awaiting debrief, new plan) survive as
      setup notes or beats
- [ ] No meaning lost: a reader who never saw the JSON understands what each Scenario tests
