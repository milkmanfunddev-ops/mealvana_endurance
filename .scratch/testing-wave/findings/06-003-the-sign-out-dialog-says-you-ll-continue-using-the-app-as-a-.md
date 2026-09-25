# 06-003 · The Sign Out dialog says you'll continue using the app as a guest, but sign-out lands on the welcome screen and there is no guest mode

- kind: bug
- status: triaged
- ticket: 06
- run: w6-20260924T1117Z
- screen: Settings
- decision: 

**Steps.**
1. Signed in (paid account C): Settings → Sign Out.
2. Read the confirm dialog, then tap Sign Out.

**Expected.**
The dialog says what sign-out does now: you go back to the welcome screen and sign in again to
use the app.

**Actual.**
The dialog reads "You'll continue using the app as a guest. Your preferences will be saved on this
device. Sign in again to sync across devices." Sign-out went straight to the welcome screen
(`redirecting to RouteMatchList(/welcome)`). The guest path was removed on 09-16 (paywall and
onboarding reshape). The text is hardcoded in `settings_screen.dart` (title `Sign Out?`, body
above), not in the content system.

**Evidence.**
- runs/06/11-sign-out-dialog.png
- runs/06/12-after-sign-out.png
- runs/06/console.log lines 473-478

**Decision quote.**
> 

**Triage.**
Fix ticket 47 (Lee, 2026-09-25). Closed by the retest after it merges.
