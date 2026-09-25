# 06-006 · Cold relaunch shows one black frame between the startup spinner and the timeline

- kind: followup-test
- status: open
- ticket: 06
- run: w6-20260924T1117Z
- screen: Splash (before Timeline)
- decision: 

**Steps.**
1. Signed-in paid account on the timeline. `simctl terminate`, then `simctl launch`, recorded.

**Expected.**
Splash, startup spinner, then the timeline, on the app's own background throughout.

**Actual.**
Between the last spinner frame and the first timeline frame, one frame at 5 fps (up to 200 ms) is
fully black apart from the testing-tools button. Seen once and not repeated. Low severity. It may
be the route swap from the startup screen to `/main`.

**Evidence.**
- runs/06/21-cold-relaunch-frames-5fps.png (sixth row, second frame)

**Decision quote.**
> 

**Triage.**

Made a follow-up test (Lee, 2026-09-25): seen once, not reproduced. The retest watches a cold relaunch; closed if no black frame shows.
