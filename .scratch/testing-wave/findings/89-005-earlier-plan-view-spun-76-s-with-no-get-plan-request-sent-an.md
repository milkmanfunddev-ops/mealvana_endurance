# 89-005 · Earlier plan view spun 76 s with no get_plan request sent and no error

- kind: bug
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Earlier plan view (Previous plans > a row)
- decision: 

**Steps.**
1. test@test.com online (netcut off since 19:56:02Z). Plan ⋮ > Previous plans (list_plans 133 ms).
2. At 20:07:31Z tap "Sep 13 – Sep 19 · 6 meals" (f2c0bc78).

**Expected.**
The plan opens in a second or two, or says it could not load.

**Actual.**
The view showed "Previous plans" and a spinner for 76 s, until I tapped Back at 20:08:47Z. GoRouter logged "pushing /food/plans/f2c0bc78…" at 15:07:31 local, and no `get_plan` request reached vana-action (edge function logs: nothing between list_plans 15:07:04 and get_plan 15:08:58, which was the next plan I opened); no Flutter warning or error was logged. Opening Sep 6 then took about a second, and Sep 13 opened in a second on the retry. Seen once. `EarlierPlan.build` awaits `VanaActionClient.run(GetPlanAction)` with no timeout, so a request stuck before it is sent spins forever.

**Evidence.**
- runs/89/37-earlier-plan-sep13.png: the spinner at 5 s.
- runs/89/38-earlier-plan-spinner-2min.png: the spinner at 76 s.
- runs/89/40-earlier-plan-sep13-retry.png: the retry, opened.
- runs/89/edge-function_logs.txt: list_plans 15:07:04, then get_plan only at 15:08:58 and 15:09:10.
- runs/89/console-redacted.log: 15:07:31 "GoRouter: INFO: pushing /food/plans/f2c0bc78-…", nothing after it from the app.

**Decision quote.**
> 

**Triage.**
