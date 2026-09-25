# 116-015 · Two seconds after Delete account the app looked up the deleted account's activity (ACTIVITIES_SERVICE Activity not found)

- kind: followup-test
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: none (after Delete account)
- decision: 

**Steps.**
1. On a new account with an activity and a stored plan, open the activity, go back to the timeline, then Settings > Delete account > Delete.
2. Read the console for the two seconds after the sign-out.
Seen in this run at 23:02:03Z (18:02:03 local), about 2 s after the delete's sign-out and redirect to /welcome: "[ACTIVITIES_SERVICE] Activity not found in database" with userId b4ef9289… (the just-deleted account) and activityId c8dd5732…. Something still held the deleted account's activity and queried it after the account was gone.

**Expected.**
After Delete account nothing queries the deleted account's rows.

**Actual.**


**Evidence.**
- runs/116/console-excerpt-after-delete.txt
- runs/116/db-acct2-after-delete.json

**Decision quote.**
> 

**Triage.**

