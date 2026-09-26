# 125-001 · Signing out a Test Store-paid account routes to the paywall before Welcome; offline, a full paywall frame shows

- kind: bug
- status: open
- ticket: 125
- run: w37-20260926T0221Z
- screen: Settings
- decision: 

**Steps.**
1. Sign in as an account paid through the Test Store (B, Annual). Relaunch it offline with `netcut.sh on --relaunch` (after `netcut.sh launch` has built the library).
2. Settings → Sign Out → Sign out. Take 10 screenshots straight after the tap and read the console's GoRouter lines.
3. For comparison, sign out online, for this account and for test@test.com (Pro from a code).

**Expected.**
06-007: the app lands on Welcome (local sign-out, `SignOutScope.local`) and never on the paywall.

**Actual.**
Offline (02:36:14Z) frame 1 of 10 shows the paywall's hero mockup ("Today, September 21" marketing phone) sliding in over Settings, then Welcome. Console, local time: `settings_sign_out_tapped` 21:36:15.175, `redirecting to RouteMatchList(/paywall)` 21:36:15.233, `Signing out user with scope: SignOutScope.local` 21:36:15.880, `/welcome` 21:36:15.927. The same `/paywall` redirect precedes every sign-out of a Test Store-paid account online too (A 21:30:11.982, B 21:33:18.319). Online it lasts about 0.6 s and no frame caught it. It never happened for test@test.com (21:25:03, 21:26:38), whose Pro comes from a code. The Gate appears to close as soon as sign-out starts clearing Pro, before the auth session ends. 87-003 is the same redirect on Delete account; this is the Sign out path. The offline delete (64-B-offline-delete-frames.png, frame 2) shows a whole paywall frame too.

**Evidence.**
- runs/125/40-real-offline-signout-frames.png
- runs/125/39-B-after-real-offline-signout.png
- runs/125/64-B-offline-delete-frames.png
- runs/125/console-redacted.log (21:36:15.175-21:36:15.927, 21:30:11.954-21:30:12.669, 21:33:18.267-21:33:18.961, 21:25:03-21:25:04 local)
- runs/125/notes.md

**Decision quote.**
> 

**Triage.**
