# 117-015 · Test Store monthly kept renewing with the account signed out and the app terminated, so a sign-out lapse is not reliable

- kind: idea
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: none
- decision: 

**Steps.**
Idea for the harness (IMPROVEMENTS #80 says a monthly lapses about 5 minutes after sign-out). This run's account A bought Monthly at 11:13:45Z and signed out at 11:20:01Z. Its entitlement ended 11:23:46, then renewed server-side at 11:25:28 (app on Welcome with cleared data), again at 11:29:28 and 11:37:29 with the app terminated, each time backdated to the missed period and after a longer gap (1:42, 0:42, 3:43). RevenueCat's v2 cancel refuses a Test Store subscription ("not a Web Billing subscription"). The run got a Lapsed sign-in only by tapping Log In at 11:38:53, seven seconds after the period ended. Suggest runbook step 5 says the lapse is only a gap between late renewals, and a run that needs Lapsed should poll `user_entitlements.active_until` and sign in inside the gap, or use another way to lapse.

**Expected.**
A dependable way to make a Lapsed Test Store account.

**Actual.**


**Evidence.**
- runs/117/A-renewals-while-signed-out.txt
- runs/117/A-lapsed-check.txt
- runs/117/A-after-lapsed-signin.txt
- runs/117/revenuecat-A-cancel-response.txt

**Decision quote.**
> 

**Triage.**

