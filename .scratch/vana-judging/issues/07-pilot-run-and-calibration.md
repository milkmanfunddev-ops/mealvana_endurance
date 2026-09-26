# 07: Pilot Run and Rubric calibration

**What to build:** The first real judged Run, as the acceptance test for the whole system. The
wave lead (not a worktree agent — this is app-driving and judging) launches the app on the web
build against dev, signs in as the fixed-up test account, runs one converted Scenario
end-to-end as the Examiner — improvised in character within the Scenario's pinned opening and
required beats — captures the transcript, Marks it against the Rubric with a dimension
breakdown and verdict, and writes the round files. Then Lee reads the transcript beside the
verdict and calibrates: do the anchors produce the Mark his eye says that conversation
deserved? Anchor wording adjusts here, before a full round bakes in twenty-odd judgments.

**Blocked by:** 03 (account ready), 04 (Scenario converted), 05 (capture and round files).

**Status:** ready-for-agent

- [ ] One Scenario run end-to-end in the real app on web, screenshots taken as evidence
- [ ] Transcript captured from the server's stored messages, not from memory
- [ ] Mark, dimension breakdown, and verdict written to the round files (prose + JSON)
- [ ] Lee has read transcript and verdict and confirmed the anchors calibrate (or adjusted
      them, recorded in the Rubric's history)
