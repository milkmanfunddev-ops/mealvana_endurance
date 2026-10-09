# 69-013 · AI Credits lists the tester pack as 1 Credits (no singular)

- kind: bug
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: AI Credits
- decision: 

**Steps.**
1. Signed in on a dev build (tester pack visible), open `com.milkman.mealvanaendurance:///buy-credits`.
2. Read the Credit Packs list.

**Expected.**
"1 Credit" for the one-credit pack (follow-up 50-015 asked to check the singular).

**Actual.**
The pack tile reads "1 Credits | $0.99 one-time purchase" (23:44Z). The title is built as `'$credits Credits'` with
no singular branch (`buy_credits_screen.dart:276-281`, from the code map). The other tiles read "50 Credits" and
"250 Credits"; balance "2487 credits". Restore and Buy not tapped. Back (top left) went to the Timeline with the tape
line `back fallback: canPop=false — going home`.

**Evidence.**
- runs/69/m01-ai-credits-signed-in.png the "1 Credits" tile

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 82 (small UI batch: login hint key, singular Credit, empty-search feedback, write-back toggle re-reads its pref, watched_sec counts played time), fix wave 8 · Lee, 2026-10-09
