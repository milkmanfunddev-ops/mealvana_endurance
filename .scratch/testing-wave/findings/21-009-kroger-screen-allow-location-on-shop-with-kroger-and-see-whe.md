# 21-009 · Kroger screen: allow location on Shop with Kroger and see whether the delivery area fills
- kind: followup-test
- status: open
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Fresh app data, open Shop with Kroger, tap Allow While Using App on the location prompt (simulator location set with `simctl location`).
2. Then in iOS Settings turn location off and reopen the screen.

**Expected.**
Allowed: the delivery area fills from the device ("Delivery to <ZIP>") and Match all appears once a store resolves. Denied later: "Set delivery ZIP" returns, no error.

**Actual.**
Not run; this run tapped Don't Allow (connect does not need an area).

**Evidence.**
- runs/21/09-location-prompt-on-shop-with-kroger.png

**Decision quote.**
> 

**Triage.**
