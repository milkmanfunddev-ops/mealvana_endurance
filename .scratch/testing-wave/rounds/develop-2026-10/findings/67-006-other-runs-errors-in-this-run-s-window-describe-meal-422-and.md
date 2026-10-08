# 67-006 · Other runs' errors in this run's window: describe-meal 422 and 400, and 'onesignal init skipped: no app id' warnings

- kind: bug
- status: open
- ticket: 67
- run: w7-20261008T2308Z
- screen: none
- decision: 

**Steps.**
1. Read dev `function_edge_logs` and dev Sentry for 23:08Z-23:31Z.

**Expected.**
No server errors or D9 warnings that no run accounts for.

**Actual.**
Not caused by run 67 (it made no AI calls and its user ids are e482a890 and f514bc05); filed so the lead can match them (#49):
- `POST 422 describe-meal` 23:20:02.796Z and `POST 400 describe-meal` 23:22:19.691Z; Sentry warning 23:22:19Z
  `FunctionException(status: 400 … description is too long (max 2000 characters))`, user 607f9dd5.
- Sentry warning "onesignal init skipped: no app id configured yet" at 23:14:16Z (user 607f9dd5) and 23:23:03Z (user 81D07A23…),
  the CLAUDE.md D9 case. Also a Sentry warning camera_access_denied 23:23:22Z and a fatal FlutterError "Tried to modify a provider while
  the widget tree was building" 23:28:38Z, both user 607f9dd5.
- A `delete-user` 200 at 23:21:50Z and `analyze-meal-photo` 200 at 23:24:45Z, also another run's.

**Evidence.**
- runs/67/edge-67-2308-2331.txt
- runs/67/sentry-67.md

**Decision quote.**
> 

**Triage.**

