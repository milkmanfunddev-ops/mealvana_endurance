# 22-002 · Kroger hand-off to the cart cannot be seen on dev: certification opens no cart by design
- kind: followup-test
- status: open
- ticket: 22
- run: w18-20260925T0127Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. On a production Kroger connection, and only with Lee's say-so (for example on Lee's phone, since a send fills Lee's real Kroger cart): Shop with Kroger, set a store, Match all, review and approve the matches, Add to Kroger cart.
2. Watch what opens after the send, and press the hand-off button again afterwards.
3. Read the new `kroger_exports` row (status, lines) and compare its UPCs and quantities with the cart kroger.com shows.
4. On certification (dev, after 22-001 is fixed): the same send; expect no cart to open and the hand-off button to say it is unavailable.

**Expected.**
Production: the Kroger app, or the browser where the shopper is signed in, opens `https://www.kroger.com/cart` and the cart holds the matched items at the sent quantities. Certification: `_openKroger` returns false outside production (`kroger_controller.dart`: "Certification's cart is not the one at kroger.com, so that environment hands off nowhere"), so nothing opens after the send and the hand-off button raises `unavailable`. The ticket's last criterion ("The hand-off opens Kroger's cart with the matched items") can only be seen on production.

**Actual.**
Not run: this run stopped at the sign-in (22-001).

**Evidence.**
- runs/22/09-kroger-screen.png

**Decision quote.**
> 

**Triage.**
