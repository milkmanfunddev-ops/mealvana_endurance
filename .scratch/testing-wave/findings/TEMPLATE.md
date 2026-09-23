# NN-SSS · One line saying what happened

<!--
One Finding per file. Make one with
  node scripts/testing-wave/findings.mjs new <ticket> "<title>" --kind <kind> --run <run>
which names it <ticket>-<next number>-<slug>.md, so two agents never write the same file.
The index script (`findings.mjs index`) reads the list lines below; keep them as `- key: value`.

kind:     bug | ssot-conflict | followup-test | idea
status:   open | triaged | fixing | closed | wontfix   (agents always write `open`; triage moves it)
ticket:   the two-digit ticket number, the same as the file name's first part
run:      the run id from the runbook, w<wave>-<UTC time>, e.g. w1-20260923T1405Z
screen:   the screen as the app names it; `none` for a Finding with no screen
decision: ssot-conflict only: the decision id (mp-457). Quote its Decision text under
          "Decision quote" below. Empty for the other kinds.

bug and ssot-conflict need Actual and Evidence. followup-test: Steps is what to try, Expected is
what should happen. idea: Steps is the idea. Delete this comment block when done.
-->

- kind: bug
- status: open
- ticket: NN
- run: 
- screen: 
- decision: 

**Steps.**
1. 

**Expected.**


**Actual.**


**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

