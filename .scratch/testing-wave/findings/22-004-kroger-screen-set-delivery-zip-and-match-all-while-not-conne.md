# 22-004 · Kroger screen: Set delivery ZIP and Match all while not connected, on certification
- kind: followup-test
- status: open
- ticket: 22
- run: w18-20260925T0127Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. On dev (certification), with no certification connection: Shop with Kroger, Set delivery ZIP (e.g. 35209, the Birmingham store earlier drafts used), pick the store.
2. Match all. For every list line record the row (name, need) and the product matched (name, UPC, size, price, package count), as ticket 22 asks.
3. Try Add to Kroger cart without a connection.

**Expected.**
Catalog reads run on the application token (`client.ts`: "The shopper's own token pays for the cart write and for nothing else"), so the store search and matching work before any Kroger sign-in, and the draft for plan 173cebb2 gets a store and matched lines (`save_kroger_draft`). Add to Kroger cart asks the shopper to connect first. This lets ticket 22's matching criterion ("Unmatched items and wrong matches are each a Finding") run while 22-001 is open.

**Actual.**
Not run: the wave lead's instruction for ticket 22 was to stop on a refused certification sign-in.

**Evidence.**
- runs/22/19-after-closing-sheet.png

**Decision quote.**
> 

**Triage.**
