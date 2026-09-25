# 111-006 · Kroger screen: with location off, the typed ZIP is gone after a restart; check whether the shopper retypes it every visit

- kind: followup-test
- status: open
- ticket: 111
- run: w30-20260925T2103Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Location Never. Shop with Kroger, Set delivery ZIP 35209 ("Delivery to 35209"). Cold-restart the app and open Shop with Kroger again.
2. Seen in this run: after the restart the screen showed "Set delivery ZIP" again (the controller keeps the area for the session only, per Kroger's Locations terms). Check whether Match all and the cart still work from the stored store, and whether the shopper must retype the ZIP on every visit.

**Expected.**
The stored store keeps matching usable; asking for the ZIP again is acceptable only if nothing already matched is lost.

**Actual.**
Not run beyond step 1 (look-around, ticket 111).

**Evidence.**
- runs/111/14-after-zip-35209.png
- runs/111/27-21-007-offline-connect-retry.png (after the restart: Set delivery ZIP)

**Decision quote.**
> 

**Triage.**
