# 30-014 · Consent and Create account: untried paths (toggle ON, Privacy Policy/Terms links, Back from Your privacy, Log in from anonymous Settings migrating data)

- kind: followup-test
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: Your privacy
- decision: retest ticket 48 (auth, consent, delete), wave 5

**Steps.**
1. GB geo cache (as 7(ii)): on Your privacy turn Share usage data ON, Continue: prefs `analytics_consent_status=granted`,
   regime strict; Settings → Privacy shows ON; Mixpanel events flow.
2. Tap Privacy Policy and Terms on Your privacy: they open and come back to the same screen with the toggle unchanged.
3. Back/edge swipe on Your privacy (no Back button is shown): where does it go, and is consent left unknown?
4. Anonymous athlete → Settings → "Log into an existing account" → log in to a real account: console said
   `email_sign_in_success {migrated_data: true}` (13:21:18Z, B). Check what moved from the anonymous user into the
   real account (meal logs, targets) and whether the real account's own data was overwritten.
5. Settings → Privacy → turn usage data ON after a Decline at signup, then OFF again: prefs and `analytics_consent_at`
   change each time. Note `analytics_consent_at` is stored as local naive time (`2026-10-08T08:23:49.007833`, no offset).

**Expected.**
Each path keeps the stored consent and the screen in step.

**Actual.**
Not run.

**Evidence.**
- runs/30/30b7ii-02-consent.png
- runs/30/prefs-30b7ii-after-decline.txt

**Decision quote.**
> 

**Triage.**
