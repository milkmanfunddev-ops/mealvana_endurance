# 01-009 · Sign-up form ignores the email typed on the personal-info step, and public.users.email then keeps that casing

- kind: idea
- status: triaged
- ticket: 01
- run: w1-20261007T1103Z
- screen: Sign Up with Email
- decision: 

**Steps.**
1. Idea: when the athlete typed an email on onboarding's "Tell us about yourself" page, prefill it on "Sign Up with Email", and store one normalised (lowercase) address in `public.users.email`.

**Expected.**
The athlete types the address once; `public.users.email` matches `auth.users.email`.

**Actual.**
Pass B typed `lee+e2e-01-20261007T110602Z@...` (mixed case) on the personal-info page; the sign-up form still opened empty and the address had to be typed again. After signup `auth.users.email` was lowercase but `public.users.email` kept the mixed case `...T110602Z@...`. In pass A (no email on the personal-info page) `public.users.email` was lowercase. Any lookup that matches `public.users.email` case-sensitively against the auth address misses.

**Evidence.**
- runs/01/31-B-email-signup.png
- runs/01/db-B-after-code.txt
- runs/01/db-A-after-code.txt

**Decision quote.**
> 

**Triage.**
fix ticket: public.users.email is normalised to lowercase at write, plus a one-off dev SQL for existing rows; the personal-info prefill is Xuan's onboarding behaviour and goes to the review queue
