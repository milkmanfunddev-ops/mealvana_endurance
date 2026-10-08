# 48-004 · Follow-up: delete-user answering a real 500, and the expired code at 60 min

- kind: followup-test
- status: open
- ticket: 48
- run: w5-20261008T1718Z
- screen: Settings
- decision: 

**Steps.**
1. Settings → Delete Account → Delete while `delete-user` answers HTTP 500 (a server answer, not a dropped connection).
   `netcut.sh slow` cannot make it: the app's `functions.invoke('delete-user')` has no timeout (settings_controller.dart:1104-1123),
   so a slowed reply would succeed late and delete the account for real. This run used `netcut.sh on` instead (connection
   refused): message and survival PASS. A real 500 needs a dev-only fault switch in the function, or a local proxy that rewrites the
   reply status; triage picks which.
2. Verify your email: type a code more than 60 minutes after it was sent (not seen live in this run, which lasted 27 min).

**Expected.**
1. "Deleting your account needs a connection. Nothing was deleted; try again when you're online." (or a server-error wording),
   account and rows intact, one Sentry record of the failure.
2. The expired-code line ("error_expired" words), and Resend offered.

**Actual.**
Not run.

**Evidence.**
- runs/48/48-42-delete-offline-message.png
- runs/48/db-48-A-after-offline-delete.txt

**Decision quote.**
> 

**Triage.**
