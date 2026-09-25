# 87-004 · Redeem code sheet: a second tap while a redeem is in flight, closing the sheet mid-request, and a 32-character code with spaces

- kind: followup-test
- status: open
- ticket: 87
- run: w25-20260925T1325Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. Type a code and tap Redeem twice quickly: one request or two, one redemption row.
2. Tap Redeem and close the sheet (×, or a drag down) while the request is in flight: what the athlete sees when the answer lands, and whether the code was spent.
3. Type a real code with spaces and lowercase letters filling all 32 characters (for example `e2e give 365` padded with spaces): the server strips spaces, so it should redeem.

**Expected.**
One redemption per account and code (mp-535); a closed sheet does not lose a spent code without telling the athlete; spacing and case do not matter.

**Actual.**
Not run (look-around, ticket 87).

**Evidence.**
- runs/87/03-B-redeem-sheet.png

**Decision quote.**
> 

**Triage.**
