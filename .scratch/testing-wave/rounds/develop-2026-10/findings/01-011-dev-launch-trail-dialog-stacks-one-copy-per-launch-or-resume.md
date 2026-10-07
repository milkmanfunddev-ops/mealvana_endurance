# 01-011 · Dev 'Launch trail' dialog stacks one copy per launch or resume

- kind: idea
- status: triaged
- ticket: 01
- run: w1-20261007T1103Z
- screen: Welcome
- decision: 

**Steps.**
1. Idea: show the dev "Launch trail (dev)" dialog once per process (or replace the open one) instead of pushing a new copy on every launch/resume.

**Expected.**
One dialog, one Dismiss.

**Actual.**
After a launch that the simulator first left in the background and then resumed, Welcome carried three stacked launch-trail dialogs (different heights, the trail text growing by one "app resumed" line each); it took three Dismiss taps to reach Welcome. Same after the pass C relaunch. It also slows every wave agent that drives a fresh launch.

**Evidence.**
- runs/01/01-welcome.png
- runs/01/02-launch-trail-again.png
- runs/01/39-C-welcome.png

**Decision quote.**
> 

**Triage.**
fix ticket (guards batch): the launch-trail guard matches a real notification payload only and the dialog shows once per process; unit test on the guard
