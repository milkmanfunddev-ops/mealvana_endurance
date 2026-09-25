# 87-003 · Delete account routes to /paywall for 0.3 s before Welcome

- kind: followup-test
- status: open
- ticket: 87
- run: w25-20260925T1325Z
- screen: Settings, Delete account
- decision: 

**Steps.**
1. A never-paid account holding Pro from a redeemed giveaway, Settings → Delete account → Delete.
2. Record the screen at 10 fps across the tap and read the console's GoRouter lines.

**Expected.**
The app goes straight to Welcome. No paywall frame shows for an account that is being deleted.

**Actual.**
Not seen on screen (the only screenshot came 8 s later, on Welcome). The console logged `redirecting to RouteMatchList(/paywall)` at 08:32:26.519 local, then `/welcome` at 08:32:26.820: the router sent the deleted account to the paywall for 0.3 s first, probably because the Gate closed before sign-out finished. A recording would show whether a paywall frame is visible. It happened again when account A (a paid store subscription) was deleted: `/paywall` 09:39:32.675, `/welcome` 09:39:33.047 local.

**Evidence.**
- runs/87/12-B-after-delete.png
- runs/87/console-redacted.log (08:32:26.519 and 08:32:26.820 local)

**Decision quote.**
> 

**Triage.**
