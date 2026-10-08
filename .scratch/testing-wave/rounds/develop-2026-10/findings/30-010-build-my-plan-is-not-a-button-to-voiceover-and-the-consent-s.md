# 30-010 · Build My Plan is not a button to VoiceOver, and the consent screen's Share usage data switch has no label

- kind: bug
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: Welcome
- decision: fix ticket 43 (onboarding overflow + VoiceOver semantics)

**Steps.**
1. Welcome, signed out: `idb ui describe-all`.
2. 7(ii): GB geo cache, Build My Plan → Your privacy: `idb ui describe-all`.

**Expected.**
01-017: "Build My Plan" is a Button with its label. The consent switch is a control whose label says what it does.

**Actual.**
1. Welcome lists `StaticText 'Build My Plan'` (no Button trait), next to `Button 'I already have an account'`. On Create account
   "Continue with Apple", "Continue with Google" and "Sign up with email" are StaticText too, only "Continue without an
   account" is a Button.
2. Your privacy lists `CheckBox '' '0'` for the Share usage data switch: no label; the "Share usage data" title is a
   separate StaticText. A VoiceOver user hears an unnamed checkbox on the one screen that asks for consent.

**Evidence.**
- runs/30/30a-01-welcome.png
- runs/30/30a-12-create-account.png
- runs/30/30b7ii-02-consent.png

**Decision quote.**
> 

**Triage.**
