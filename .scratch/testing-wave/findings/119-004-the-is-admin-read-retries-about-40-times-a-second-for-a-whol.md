# 119-004 · The is_admin read retries about 40 times a second for a whole offline session

- kind: bug
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: none
- decision: 

**Steps.**
On test@test.com, signed in, first launch with netcut injected.
1. `netcut.sh launch UDID SCRATCH`, then `netcut.sh on SCRATCH --relaunch UDID` (00:36:30Z). The iOS notification prompt shows; tap Allow.
2. Browse Timeline > Settings > Profile & Preferences for about a minute.
3. Read the console.

**Expected.**
One failed `is_admin` read, then one retry when the network comes back or the app resumes (89-010's fix: "reads again once the network comes back or the app next resumes").

**Actual.**
`[IS_ADMIN] is_admin read failed; treating as not admin` 1,734 times from pid 50830 between 19:36:45 and 19:37:26 local (00:36:45Z-00:37:26Z), about 40 a second, each with a failed request to the dev project; it stopped only when I relaunched. The next offline launch (pid 51211, no notification prompt) logged it once. So something re-invalidates `isAdmin` in a tight loop; the first launch's permission prompt (a resign/resume) is the one difference I saw. On a real phone offline this is a busy loop burning battery, and against a server that answers 5xx it would hammer it.

Note: netcut keeps connectivity_plus reading "online", so the offline-to-online listener in `_retryWhenReachable` never saw a change here; the loop is not that listener's first-event case.

**Evidence.**
- runs/119/console-redacted.log: grep "is_admin read failed"; pid 50830, 19:36:45-19:37:26 local
- runs/119/notes.md: the netcut times

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
