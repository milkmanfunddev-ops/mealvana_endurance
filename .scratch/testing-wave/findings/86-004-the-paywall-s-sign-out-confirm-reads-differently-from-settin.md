# 86-004 · The paywall's sign-out confirm reads differently from Settings' sign-out confirm

- kind: idea
- status: closed
- ticket: 86
- run: w25-20260925T1324Z
- screen: Paywall
- decision: 

**Steps.**
Idea. Settings → Sign Out asks "Sign out?" / "You'll need to sign in again to use Mealvana. Your data stays
with your account." The paywall's ⋯ → Sign out asks "Sign out?" / "Your data stays with your account. Sign in
again any time." Use one text for both, as ticket 47 did for the two delete confirms (02-006).

**Expected.**
The two sign-out confirms read the same, the way the two delete confirms now do.

**Actual.**
They differ (content keys `sign_out_confirm_body` in two sections of content_defaults.json). Both are
content-system strings and neither mentions a guest, so mp-508 holds for both.

**Evidence.**
- runs/86/10-settings-signout-dialog.png
- runs/86/25-paywall-signout-confirm.png

**Decision quote.**
> 

**Triage.**
Fix ticket 104 (Lee, 2026-09-25): both sign-out confirms use Settings' text. Closed by retest ticket 107 after it merges.
Moved to retest ticket 121 when 107 was split (Lee, 2026-09-25).

Run by retest ticket 121 (run w34-20260925T2320Z, build e3367d2c): pass.
