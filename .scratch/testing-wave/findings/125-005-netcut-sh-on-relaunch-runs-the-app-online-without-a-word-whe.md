# 125-005 · netcut.sh on --relaunch runs the app online without a word when netcut.dylib was never built

- kind: idea
- status: closed
- ticket: 125
- run: w37-20260926T0221Z
- screen: none
- decision: 

**Steps.**
`scripts/testing-wave/netcut/netcut.sh on <scratch> --relaunch <udid>` relaunches the app with `DYLD_INSERT_LIBRARIES=<scratch>/netcut.dylib` even when that file does not exist, and prints "relaunched offline". Only `netcut.sh launch` builds the library. When a run skips `launch`, dyld ignores the missing library, no `netcut.log` is written and the app is fully online while the run believes it is offline. This run lost two checks to it (02:33 and 02:35) before noticing that an "offline" login succeeded. Idea: `on --relaunch` builds the library if it is missing (or refuses), and `on` checks `netcut.log` gets a line within a few seconds and warns if not.

**Expected.**


**Actual.**


**Evidence.**
- runs/125/notes.md

**Decision quote.**
> 

**Triage.**

Fixed by the wave 37 lead: `netcut.sh on` now exits 1 with "Still online" when the scratch folder holds no `netcut.dylib` (IMPROVEMENTS #90).
