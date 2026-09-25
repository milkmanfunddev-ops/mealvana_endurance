# 86-009 · Verify your email: Use a different email, and Resend then the superseded code

- kind: followup-test
- status: open
- ticket: 86
- run: w25-20260925T1324Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up by email, reach Verify your email, tap Use a different email, sign up with a second address.
2. For the first address, check what dev holds (an unconfirmed auth user left behind?).
3. Separately: Resend code, then type the first (superseded) code.

**Expected.**
1-2: the abandoned address leaves no half-made account that blocks a later signup. 3: a message that sends
the athlete to the newest code.

**Actual.**
Not run. A wrong code now reads "That code is wrong or has expired. Check the digits, or tap Resend for a new
one." (32-001 passes).

**Evidence.**
- runs/86/21-wrong-code.png

**Decision quote.**
> 

**Triage.**
