# 120-009 · Offline and signed in, the is_admin read fails and re-reads about 45 times a second until sign-out

- kind: bug
- status: open
- ticket: 120
- run: w39-20260926T1013Z
- screen: Timeline
- decision: 

**Steps.**
1. Signed in as test@test.com, `netcut.sh on SCRATCH --relaunch UDID` (every new connect fails at once; the connectivity plugin still reads online).
2. Stay signed in about two minutes (Timeline, Log a Meal → Manual, Settings), then sign out.
3. Count `[IS_ADMIN] is_admin read failed; treating as not admin` in the console.

**Expected.**
One failed read, then one retry when the network comes back or the app resumes (is_admin_provider.dart doc, Finding 89-010).

**Actual.**
4,421 failed reads from 05:22:06 to 05:24:00 local, about 45 a second (one every ~25 ms) for the whole offline signed-in stretch, stopping only at sign-out. The network-change listener cannot be the trigger here (netcut keeps connectivity reading online), so something rebuilds `isAdminProvider` straight after each failure. On a device offline this is a busy loop of failing requests and log lines for as long as the app stays open. Not checked on a real device's offline mode.

**Evidence.**
- runs/120/console-redacted.log (05:22:06-05:24:00 local, the IS_ADMIN warnings)
- runs/120/notes.md

**Decision quote.**
> 

**Triage.**

