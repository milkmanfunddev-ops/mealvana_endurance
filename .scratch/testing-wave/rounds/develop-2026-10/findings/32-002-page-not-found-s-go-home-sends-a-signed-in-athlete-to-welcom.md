# 32-002 · Page Not Found's Go Home sends a signed-in athlete to Welcome, not the Timeline (retest of 08-022)

- kind: bug
- status: triaged
- ticket: 32
- run: w3-20261008T1256Z
- screen: Page Not Found
- decision: fix ticket 46 (Go Home, AI Credits close, credits copy)

**Steps.**
1. Signed in as test@test.com, open any archived or unknown path, e.g.
   `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///pro"` or the two-slash
   `com.milkman.mealvanaendurance://athlete/feedback`, or `/jade`.
2. Page Not Found shows; tap Go Home; wait 5 s and 25 s.

**Expected.**
Go Home settles on the Timeline for a signed-in athlete (08-022's expectation; ticket 26 item 10 says a
stale link lands on the errorBuilder, from where Home is the way back).

**Actual.**
It settles on Welcome ("Get more out of every session.", Build My Plan / I already have an account) and
stays there (checked at 5 s and 25 s), for all nine ticket 26 paths, `/jade` and the two-slash form. The
session is intact: a `/settings` link right after shows "Signed in with Email test@test.com". Cause from
code: the errorBuilder's button is `onPressed: () => context.go('/welcome')`
(`lib/shared/core/app_router.dart:1111`); `/welcome` is a public route, so the redirect never moves a
signed-in athlete on. A signed-in athlete is then on Welcome with Build My Plan in front of them.
Signed out, the two-slash form goes straight to Welcome through the session check, which is fine.

**Evidence.**
- runs/32/i01-pro.png Page Not Found for /pro
- runs/32/i02-pro-go-home-5s.png Welcome 5 s after Go Home
- runs/32/i05-after-go-home-25s.png still Welcome at 25 s
- runs/32/i06-settings-deeplink-after-go-home.png still signed in
- runs/32/i08-two-slash-go-home-5s.png two-slash form, same landing
- runs/32/k02-jade-go-home-5s.png /jade, same landing

**Decision quote.**
> 

**Triage.**
