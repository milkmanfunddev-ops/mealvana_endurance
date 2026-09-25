# 32-007 · Code screens could fill and submit the emailed code themselves

- kind: idea
- status: triaged
- ticket: 32
- run: w9-20260924T1447Z
- screen: Verify your email
- decision: 

**Steps.**
1. On Verify your email and Enter Reset Code, mark the field as a one-time code (`AutofillHints.oneTimeCode`) so iOS offers the code from Mail above the keyboard.
2. Submit on the sixth digit instead of waiting for a tap on Verify.
3. Carry the email typed on onboarding's "Tell us about yourself" into Sign Up with Email, which today starts empty.

**Expected.**
Fewer taps and fewer mistyped codes at the one step every new athlete must pass.

**Actual.**
Today both code screens need the digits typed and a tap on Verify / Verify Code; Sign Up with
Email starts blank although onboarding asked for an email two screens earlier.

**Evidence.**
- runs/32/06-after-create-account-retry.png
- runs/32/18-reset-code-screen.png

**Decision quote.**
> 

**Triage.**
Fix ticket 81 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.

Retest moved to ticket 100 (2026-09-25): ticket 81 added only the autofill hint; auto-submit on the sixth digit is ticket 94.
