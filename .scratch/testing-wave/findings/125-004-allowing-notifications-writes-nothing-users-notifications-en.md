# 125-004 · Allowing notifications writes nothing: users.notifications_enabled stays false, and the prompt comes on the second launch, not at sign-in

- kind: bug
- status: open
- ticket: 125
- run: w37-20260926T0221Z
- screen: Timeline
- decision: 

**Steps.**
1. Clear the app's data, log in as test@test.com (email). Note whether the iOS notification prompt shows.
2. Terminate and launch the app. The prompt "Endurance Dev Would Like to Send You Notifications" shows. Tap Allow.
3. SELECT notifications_enabled FROM public.users for the account.

**Expected.**
31-010: the prompt comes at a moment the app chose, and the stored notification setting matches the answer (Allow → true).

**Actual.**
No prompt at the first sign-in (02:23:26Z). It came on the second launch (02:24:20Z), with a restored session. Allow was tapped; at 02:24:42Z `users.notifications_enabled` was still false, and the console shows only OneSignal traffic after it. The column was also still false at the end of the run (02:45:39Z). The code map says OneSignal asks as soon as a user id is attached and that Allow writes no app table; the first half does not match what the app did. After a later data wipe no prompt came again, since iOS keeps the answer across clear-app.sh. Don't Allow was not tried this run (ticket 31 saw false after Don't Allow). Whether the column should follow the OS answer is a product question.

**Evidence.**
- runs/125/05-second-launch.png
- runs/125/06-after-allow.png
- runs/125/db-31-010-after-allow.txt
- runs/125/db-31-012-test-end.txt
- runs/125/02-test-login-3.png

**Decision quote.**
> 

**Triage.**
