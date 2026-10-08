# 30-013 · Verify your email: untried paths (hint's Log in, expired code at 60 min, paste a code, Verify tapped after the sixth-digit auto-submit)

- kind: followup-test
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: Verify your email
- decision: retest ticket 48 (auth, consent, delete), wave 5

**Steps.**
1. Plain signup: tap the hint's Log in (`auth.verify_email.log_in`); check that Log In opens with the address filled and the
   abandoned signup is discarded (`discard-signup` edge log, no unconfirmed auth user left).
2. Keep a code 61+ minutes, then type it: message must say expired (01-014 e, not seen live in this run).
3. Paste a 6-digit code from the clipboard instead of typing.
4. Type six digits (auto-submits) and tap Verify at once: this run saw two `/verify` calls (12:59:58Z, 13:00:01Z) for one
   code; check a right code tapped twice does not show an error after success.

**Expected.**
1 lands on Log In with the address; 2 says expired; 3 verifies; 4 one success, no error line.

**Actual.**
Not run.

**Evidence.**
- runs/30/30a-14-verify.png

**Decision quote.**
> 

**Triage.**
