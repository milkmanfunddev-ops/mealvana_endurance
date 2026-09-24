# 07-005 · simulator claim crashes with EEXIST when another agent holds the claims lock for more than about 10 s

- kind: idea
- status: open
- ticket: 07
- run: w6-20260924T1118Z
- screen: none
- decision: 

**Steps.**
1. Ticket 06 claims a simulator (`sync.mjs simulator claim testing-wave-06`), which boots and clones a pool device while holding the claims lock.
2. At 11:18:19Z ticket 07 runs `node docs/ssot/decisions/_page/sync.mjs simulator claim testing-wave-07 --wait 90`.

**Expected.**
The second claim waits its turn (it has `--wait 90`), as the lock's comment says: "two agents claiming at once take turns".

**Actual.**
The claim threw at once: `Error: could not lock …/mealvana-ssot-simulators.json.lock: EEXIST: file already exists` (exit 1). `withClaims` in capture.mjs retries the mkdir lock 100 times at 100 ms, about 10 s, but the other agent holds it for the whole boot and clone, which takes longer. `--wait 90` does not cover this. The run worked around it with a shell loop that waited for the lock directory to go (claimed at 11:20:50Z, 2.5 min later). Idea: make the lock wait follow `--wait`, or do the boot and clone outside the lock (mark the device claimed first). Repo tooling, not app code; not changed.

**Evidence.**
- runs/07/notes.md, "Setup" (the error and the times)
- docs/ssot/decisions/_page/capture.mjs, `withClaims` (`i > 100`)

**Decision quote.**
> 

**Triage.**
