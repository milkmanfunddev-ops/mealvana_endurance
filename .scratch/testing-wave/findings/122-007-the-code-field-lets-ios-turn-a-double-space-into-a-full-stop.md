# 122-007 · The code field lets iOS turn a double space into a full stop, so a spaced code is refused

- kind: bug
- status: open
- ticket: 122
- run: w38-20260926T0340Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. Paywall ⋯ -> Redeem code; type `  e2e  give  365` followed by spaces (87-004 step 3: a spaced lowercase code filling 32 characters).
2. Read the field back.

**Expected.**
The field keeps what was typed (upper-cased), and the server strips the spaces, so the code redeems.

**Actual.**
The field read `  E2E. GIVE. 365.              `: iOS smart punctuation replaced each double space after a letter with ". ". The server strips spaces, not full stops, so it would answer "We don't recognise that code." Not submitted: I retyped with single spaces, which redeemed (87-004 step 3 passes). The field uses `TextInputType.visiblePassword` but does not turn off smart punctuation (`smartDashesType` / `smartQuotesType`, or an input formatter that drops "."). Low: people rarely type double spaces in a code.

**Evidence.**
- runs/122/23-A-double-space-period.png

**Decision quote.**
> 

**Triage.**

