# 118-003 · Offline start: is_admin read failed is logged 1397 times in 100 s, a retry loop while the network is cut

- kind: bug
- status: open
- ticket: 118
- run: w36-20260926T0031Z
- screen: none
- decision: 

**Steps.**
1. test@test.com (dev admin) signed in. `netcut.sh on --relaunch` at 00:52:21Z: the app starts with
   its network cut. Stay on Timeline and Settings for about a minute and a half.
2. `netcut.sh off` at 00:54:05Z.

**Expected.**
Fix ticket 130 (89-010) and the wave 31 review ("admin retry only on reconnect"): a failed
`is_admin` read answers false and reads again once, when the network comes back or the app
resumes.

**Actual.**
"[IS_ADMIN] is_admin read failed; treating as not admin" (SocketException, Network is
unreachable) appears 1397 times between 19:52:25 and 19:54:05 local, about every 70 ms, each with
its stack trace, and stops the moment the network is restored. Something re-arms the read in a
tight loop while offline: the connectivity stream or the lifecycle listener firing repeatedly, or
the invalidate rebuilding and failing again at once. Netcut leaves the OS connectivity reading
"online" (runbook), so a device offline may behave differently; the loop is still a request per
70 ms against Supabase for as long as reads fail.

**Evidence.**
- runs/118/console-redacted.log: grep -c "IS_ADMIN" gives 1397; first 19:52:25.129, last 19:54:05.038 local.
- lib/shared/providers/is_admin_provider.dart (`_retryWhenReachable`).

**Decision quote.**
> 

**Triage.**
