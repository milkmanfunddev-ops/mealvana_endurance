# 02-001 · Onboarding pre-fills another person's name and email from a TrainingPeaks connection left on the device, and saves that email to the new account

- kind: bug
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Personal Info Onboarding
- decision: 

**Steps.**
1. On pool simulator wave-pool-1 (cloned from another pool device), launch the dev build signed out.
2. Build My Plan → Running → a goal → no pitfalls → Connect training: tap "I don't use training plan apps."
3. Personal info step opens.
4. Continue through onboarding and sign up with email as lee+e2e-02-20260923T1450Z@rightpathprogramming.com.
5. Delete the account from the paywall ⋯ menu, then start onboarding again.

**Expected.**
The personal info fields are empty (the athlete declined every training app on the step before),
and the new account's profile email is the address it signed up with. A deleted account leaves
nothing on the device for the next signup.

**Actual.**
First name "Xuan", last name "Huang" and email "xuan@mealvana.io" are filled in, Female is
selected, and both are tagged "TrainingPeaks" (the prefill note). The plan reveal then greets
"We built your plan, Xuan." After signup, `public.users.email` for the new account
(e7ab5001-…) is `xuan@mealvana.io`, not the signup address. The same prefill appeared again on
the second onboarding, after Delete account had run. The console shows a Riverpod assertion
thrown from the same prefill path (Finding 02-002). This is another person's
data shown to, and stored on, a stranger's account.

**Evidence.**
- runs/02/02-personal-info.png
- runs/02/db-A-before-delete.txt (last line: `email: 'xuan@mealvana.io'`)
- runs/02/console.log: `_PersonalInfoScreenState._applyIntegrationProfile` (personal_info_screen.dart:233) in the stack under "Tried to modify a provider while the widget tree was building"

**Decision quote.**
> 

**Triage.**
Fix ticket 33 (Lee, 2026-09-25). Closed by the retest after it merges.
